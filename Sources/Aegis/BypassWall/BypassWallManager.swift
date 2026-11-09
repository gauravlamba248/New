import Foundation
import WebKit
import Combine
import SwiftUI

@MainActor
public final class BypassWallManager: ObservableObject {
    @Published public var buttonState: BypassButtonState = .idle
    @Published public var activeClassification: WallClassification = .none
    @Published public var activeCleanedArticle: CleanedArticle? = nil
    @Published public var isCleanReaderActive: Bool = false
    @Published public var isStatusPopoverOpen: Bool = false
    @Published public var lastResult: ExplainableBypassResult? = nil
    @Published public var isAnalyzing: Bool = false

    public weak var activeWebView: WKWebView?

    private let detector = BypassWallDetector.shared
    private let decisionEngine = BypassDecisionEngine.shared
    private let extractor = BypassWallExtractor.shared

    public init() {}

    /// Evaluates the current page asynchronously
    public func analyzeCurrentPage(webView: WKWebView?, url: URL?) async {
        guard let wv = webView, (url ?? wv.url) != nil else {
            self.buttonState = .unsupported
            self.activeClassification = .unsupported(reason: "No active webpage to analyze")
            return
        }

        self.activeWebView = wv
        self.isAnalyzing = true
        self.buttonState = .analyzing

        do {
            let scriptResult = try await wv.evaluateJavaScript(detector.domInspectionScript)
            guard let jsonString = scriptResult as? String,
                  let data = jsonString.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(DOMInspectionPayload.self, from: data) else {
                self.isAnalyzing = false
                self.buttonState = .nothingToBypass
                self.activeClassification = .none
                return
            }

            let classification = detector.classify(payload: payload)
            self.activeClassification = classification

            switch classification {
            case .none:
                self.buttonState = .nothingToBypass
            case .presentationBarrier(_, let isFullAvailable):
                self.buttonState = isFullAvailable ? .contentAvailable : .wallDetected
            case .accessControlBarrier(let type, _):
                switch type {
                case .paidSubscriptionPaywall:
                    self.buttonState = .blockedByPaywall
                case .authenticationRequired:
                    self.buttonState = .blockedByAuthentication
                case .captchaChallenge:
                    self.buttonState = .blockedByCAPTCHA
                case .privateAccount:
                    self.buttonState = .blockedByAuthentication
                }
            case .redirectInterstitial:
                self.buttonState = .wallDetected
            case .unsupported:
                self.buttonState = .unsupported
            }

            self.isAnalyzing = false
        } catch {
            self.isAnalyzing = false
            self.buttonState = .nothingToBypass
            self.activeClassification = .none
        }
    }

    /// User clicks the [ Bypass Wall ] button
    public func triggerBypassAction(webView: WKWebView?, url: URL?) async {
        guard let wv = webView else { return }

        // If not yet analyzed or idle, run analysis first
        if activeClassification == .none && buttonState == .idle {
            await analyzeCurrentPage(webView: wv, url: url)
        }

        // Fetch fresh DOM state
        guard let scriptResult = try? await wv.evaluateJavaScript(detector.domInspectionScript),
              let jsonString = scriptResult as? String,
              let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(DOMInspectionPayload.self, from: data) else {
            let fallbackResult = ExplainableBypassResult(
                status: "Analysis Unavailable",
                actionTaken: "Unable to inspect webpage DOM.",
                contentSource: "Document unavailable",
                securityAffirmation: "No changes made.",
                isRefusal: true
            )
            self.lastResult = fallbackResult
            self.isStatusPopoverOpen = true
            return
        }

        let classification = detector.classify(payload: payload)
        self.activeClassification = classification

        let decision = decisionEngine.decide(classification: classification, payload: payload, sourceURL: url ?? wv.url)

        switch decision {
        case .allowCleanView(let article, let selectors, let result):
            self.activeCleanedArticle = article
            self.lastResult = result
            // 1. Remove overlays in-place on the DOM
            removeOverlaysInDOM(webView: wv, selectors: selectors)
            // 2. Open clean reader view
            self.isCleanReaderActive = true
            self.buttonState = .contentAvailable
            self.isStatusPopoverOpen = true

        case .refuseAccessControl(let result):
            self.lastResult = result
            self.isStatusPopoverOpen = true
            if case .accessControlBarrier(let type, _) = classification {
                switch type {
                case .paidSubscriptionPaywall: self.buttonState = .blockedByPaywall
                case .authenticationRequired: self.buttonState = .blockedByAuthentication
                case .captchaChallenge: self.buttonState = .blockedByCAPTCHA
                case .privateAccount: self.buttonState = .blockedByAuthentication
                }
            }

        case .noActionNeeded(let result):
            self.lastResult = result
            self.buttonState = .nothingToBypass
            self.isStatusPopoverOpen = true

        case .followSafeRedirect(let targetURL, let result):
            self.lastResult = result
            self.isStatusPopoverOpen = true
            wv.load(URLRequest(url: targetURL))

        case .unsupported(let result):
            self.lastResult = result
            self.buttonState = .unsupported
            self.isStatusPopoverOpen = true
        }
    }

    /// Removes obstructive DOM elements and restores document scrolling
    public func removeOverlaysInDOM(webView: WKWebView, selectors: [String]) {
        let joinedSelectors = selectors.map { "'\($0)'" }.joined(separator: ", ")
        let removalScript = """
        (function() {
            try {
                const selectors = [\(joinedSelectors)];
                for (const sel of selectors) {
                    try {
                        const els = document.querySelectorAll(sel);
                        for (const el of els) {
                            el.style.display = 'none';
                            el.style.visibility = 'hidden';
                            if (el.parentNode) el.parentNode.removeChild(el);
                        }
                    } catch(e) {}
                }
                // Restore body scrolling
                document.body.style.overflow = 'auto';
                document.body.style.position = 'static';
                document.documentElement.style.overflow = 'auto';
                // Remove blur filter
                document.querySelectorAll('*').forEach(el => {
                    if (window.getComputedStyle(el).filter.includes('blur')) {
                        el.style.filter = 'none';
                    }
                });
            } catch(e) {}
        })();
        """
        webView.evaluateJavaScript(removalScript, completionHandler: nil)
    }

    public func closeCleanReader() {
        self.isCleanReaderActive = false
    }

    /// Evaluates destination link before navigation
    public func classifyLink(url: URL) async -> LinkClassification {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return .unsupported
        }

        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 4.0

        guard let (_, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse else {
            return .unsupported
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            return .loginRequired
        }

        // Fetch first 32KB of HTML
        var getReq = URLRequest(url: url)
        getReq.setValue("bytes=0-32768", forHTTPHeaderField: "Range")
        getReq.timeoutInterval = 4.0

        if let (data, _) = try? await URLSession.shared.data(for: getReq),
           let htmlSnippet = String(data: data, encoding: .utf8) {
            let classif = detector.inspectHTMLString(htmlSnippet, url: url)
            switch classif {
            case .none: return .publicContent
            case .presentationBarrier: return .publicWithPresentationWall
            case .accessControlBarrier(let type, _):
                switch type {
                case .paidSubscriptionPaywall: return .paywall
                case .authenticationRequired: return .loginRequired
                case .captchaChallenge: return .captcha
                case .privateAccount: return .loginRequired
                }
            case .redirectInterstitial: return .publicContent
            case .unsupported: return .unsupported
            }
        }

        return .publicContent
    }
}
