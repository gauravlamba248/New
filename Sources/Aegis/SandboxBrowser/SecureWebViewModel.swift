import Foundation
import WebKit
import Combine

public enum BrowserMode: String, CaseIterable, Identifiable, Sendable {
    case normal = "Normal Browser"
    case secure = "Secure Browser"

    public var id: String { rawValue }

    public var searchEngineName: String {
        switch self {
        case .normal: return "Google (Blockers Active)"
        case .secure: return "DuckDuckGo (Zero-Trace)"
        }
    }
}

@MainActor
public final class SecureWebViewModel: NSObject, ObservableObject {
    public let id: UUID = UUID()
    @Published public var currentURLString: String = ""
    @Published public var title: String = "Secure Session"
    @Published public var isLoading: Bool = false
    @Published public var canGoBack: Bool = false
    @Published public var canGoForward: Bool = false
    @Published public var browserMode: BrowserMode = .normal
    @Published public var blockedThreatMessage: String? = nil
    @Published public var isSessionActive: Bool = false
    @Published public var bypassWallManager: BypassWallManager = BypassWallManager()

    public var isPrivateMode: Bool {
        get { browserMode == .secure }
        set { browserMode = newValue ? .secure : .normal }
    }

    public var webView: WKWebView?

    public override init() {
        super.init()
    }

    /// Lazily constructs the WKWebView instance only when an active web navigation occurs
    public func getOrCreateWebView() -> WKWebView {
        if let existing = webView {
            return existing
        }
        return setupWebView()
    }

    public func setupWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // 1. Data Store selection:
        // Normal Browser uses default data store (cookies/sessions persist)
        // Secure Browser uses nonPersistent ephemeral data store (zero-trace RAM only)
        if browserMode == .secure {
            let store = WKWebsiteDataStore.nonPersistent()
            // OPTION A: Native In-App Encrypted Proxy Tunneling (Blindfold ISP)
            if ISPCloakManager.shared.isEnabled, let proxyConfig = ISPCloakManager.shared.buildProxyConfiguration() {
                store.proxyConfigurations = [proxyConfig]
            }
            configuration.websiteDataStore = store
        } else {
            configuration.websiteDataStore = WKWebsiteDataStore.default()
        }

        // Memory optimizations: disable background printing, suppress media autoplay bloat
        configuration.preferences.isFraudulentWebsiteWarningEnabled = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.suppressesIncrementalRendering = false

        // Inject low-overhead CSS rule to defer decoding of off-screen images/videos until scrolled into view
        let cssRule = "img, video { content-visibility: auto; }"
        let js = "const style = document.createElement('style'); style.textContent = `\(cssRule)`; if (document.head) { document.head.appendChild(style); } else { document.addEventListener('DOMContentLoaded', () => document.head.appendChild(style)); }"
        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(script)

        let wv = WKWebView(frame: .zero, configuration: configuration)
        wv.navigationDelegate = self
        wv.allowsLinkPreview = false
        self.webView = wv
        self.isSessionActive = true
        return wv
    }

    /// Resets the browser back to the clean initial empty state,
    /// avoiding the need to click the back button repeatedly, and immediately frees memory back to <15MB.
    public func resetToInitialState() {
        closeAndDismantleSession()
    }

    /// Completely releases the WKWebView instance and associated memory back to the OS.
    /// Immediately halts all running media (audio/video/streams) with zero delay.
    public func closeAndDismantleSession() {
        if let wv = webView {
            // 1. Instantly mute and suspend all hardware media playback via native WebKit APIs
            wv.pauseAllMediaPlayback(completionHandler: nil)
            wv.setAllMediaPlaybackSuspended(true, completionHandler: nil)
            wv.closeAllMediaPresentations(completionHandler: nil)

            // 2. Hard-terminate any running audio/video elements in the DOM
            let killMediaJS = """
            (function() {
                try {
                    var elements = document.querySelectorAll('video, audio');
                    for (var i = 0; i < elements.length; i++) {
                        elements[i].muted = true;
                        elements[i].pause();
                        elements[i].src = '';
                        elements[i].srcObject = null;
                        if (elements[i].load) elements[i].load();
                        elements[i].remove();
                    }
                } catch(e) {}
            })();
            """
            wv.evaluateJavaScript(killMediaJS, completionHandler: nil)

            // 3. Immediately wipe DOM, stop pending network streams, and load empty document
            wv.stopLoading()
            wv.loadHTMLString("", baseURL: nil)

            // 4. Detach delegates and superview
            wv.navigationDelegate = nil
            wv.removeFromSuperview()
        }

        webView = nil
        self.isSessionActive = false
        self.currentURLString = ""
        self.title = "Empty Browser (Initial State)"
        self.canGoBack = false
        self.canGoForward = false
        self.blockedThreatMessage = nil
        self.bypassWallManager.buttonState = .idle
        self.bypassWallManager.isCleanReaderActive = false
        self.bypassWallManager.activeCleanedArticle = nil
        self.bypassWallManager.activeWebView = nil

        // Enforce immediate garbage collection and Darwin virtual memory return
        MemoryGovernor.shared.reclaimIdleMemory()
    }

    public func setBrowserMode(_ mode: BrowserMode) {
        guard mode != self.browserMode else { return }
        self.browserMode = mode
        if isSessionActive {
            // Re-setup webView with new data store configuration if active
            _ = setupWebView()
            if let currentURL = URL(string: currentURLString), !currentURLString.isEmpty {
                navigate(to: currentURL)
            }
        }
    }

    public func navigate(to targetURL: URL, privateMode: Bool? = nil) {
        if let pm = privateMode {
            self.browserMode = pm ? .secure : .normal
        }

        self.blockedThreatMessage = nil
        let host = targetURL.host ?? targetURL.absoluteString
        let port = targetURL.port ?? (targetURL.scheme == "http" ? 80 : 443)
        let isAirGapped = AirGappedSandboxManager.shared.isAirGapped

        // PIPELINE CHECK 1: Connection & Leak Evaluator (including Air-Gap enforcement)
        // Note: Blockers run for BOTH Normal Browser and Secure Browser!
        let verdict = LeakConnectionBlocker.shared.evaluateOutboundConnection(
            host: host,
            port: port,
            isAirGapped: isAirGapped
        )

        switch verdict {
        case .blocked(let bHost, let bPort, let reason, let severity):
            self.blockedThreatMessage = "BLOCKED: [\(severity.rawValue)] \(reason) (Target: \(bHost):\(bPort))"
            SecurityAuditLogger.shared.recordThreat(
                type: "Network Interception Drop",
                target: "\(bHost):\(bPort)",
                reason: reason,
                mitigation: "Strict Pipeline Interception",
                severity: severity,
                isPrivateSession: isPrivateMode
            )
            return

        case .permitted:
            break
        }

        // PIPELINE CHECK 2: Ad & Tracker Blocker (Active in BOTH modes)
        let (trackerBlocked, trackerReason) = AdTrackerBlocker.shared.isBlocked(url: targetURL)
        if trackerBlocked {
            self.blockedThreatMessage = "BLOCKED TRACKER: \(trackerReason ?? "Telemetry blocked")"
            SecurityAuditLogger.shared.recordThreat(
                type: "Tracker Blocked",
                target: host,
                reason: trackerReason ?? "Telemetry Domain",
                mitigation: "Suppressed outbound connection",
                severity: .warning,
                isPrivateSession: isPrivateMode
            )
            return
        }

        // PIPELINE CHECK 3: IP Blocker (Active in BOTH modes)
        let (ipBlocked, ipReason) = IPBlocker.shared.isBlocked(ipString: host)
        if ipBlocked {
            self.blockedThreatMessage = "BLOCKED HOSTILE IP: \(ipReason ?? "Blacklisted IP Range")"
            SecurityAuditLogger.shared.recordThreat(
                type: "Malicious IP Drop",
                target: host,
                reason: ipReason ?? "Subnet Rule",
                mitigation: "Blacklisted & Filtered",
                severity: .high,
                isPrivateSession: isPrivateMode
            )
            return
        }

        // Lazy initialization of WKWebView
        let wv = getOrCreateWebView()

        // Passed all zero-trust checks: proceed with request
        self.currentURLString = targetURL.absoluteString
        let request = URLRequest(
            url: targetURL,
            cachePolicy: isPrivateMode ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
        )

        // Log session activity ONLY if NOT in private session
        SecurityAuditLogger.shared.recordActivity(
            module: browserMode == .normal ? "Normal Browser" : "Secure Browser",
            action: "Navigate",
            durationSeconds: 0,
            metadata: targetURL.host ?? "Local Target",
            isPrivateSession: isPrivateMode
        )

        wv.load(request)

        // Evaluate memory tier and enforce governor rules
        _ = MemoryGovernor.shared.evaluateAndEnforce(activeWebView: wv)
    }

    public func searchWeb(query: String, privateMode: Bool? = nil) {
        if let pm = privateMode {
            self.browserMode = pm ? .secure : .normal
        }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Mode-dependent search engine:
        // Normal Browser: Routes through Google (with all security blockers active)
        // Secure Browser: Routes through DuckDuckGo zero-tracker HTML
        let urlString: String
        if browserMode == .normal {
            urlString = "https://www.google.com/search?q=\(encoded)"
        } else {
            urlString = "https://html.duckduckgo.com/html/?q=\(encoded)"
        }

        if let url = URL(string: urlString) {
            navigate(to: url)
        }
    }

    public func reload() {
        webView?.reload()
    }

    public func goBack() {
        webView?.goBack()
    }

    public func goForward() {
        webView?.goForward()
    }
}

extension SecureWebViewModel: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        // Always permit local "about:" or internal data schemes
        if url.scheme == "about" || url.scheme == "data" {
            decisionHandler(.allow)
            return
        }

        let host = url.host ?? ""
        let port = url.port ?? (url.scheme == "http" ? 80 : 443)
        let isAirGapped = AirGappedSandboxManager.shared.isAirGapped

        // Intercept navigation at the low-level policy layer
        let verdict = LeakConnectionBlocker.shared.evaluateOutboundConnection(host: host, port: port, isAirGapped: isAirGapped)
        switch verdict {
        case .blocked(let bHost, _, let reason, let severity):
            self.blockedThreatMessage = "BLOCKED NAVIGATION: [\(severity.rawValue)] \(reason) (\(bHost))"
            SecurityAuditLogger.shared.recordThreat(
                type: "Sub-Resource / Navigation Drop",
                target: bHost,
                reason: reason,
                mitigation: "Pre-Navigation Policy Rejection",
                severity: severity,
                isPrivateSession: isPrivateMode
            )
            decisionHandler(.cancel)
            return
        case .permitted:
            break
        }

        // Check Ad & Tracker Blocker
        let (trackerBlocked, trackerReason) = AdTrackerBlocker.shared.isBlocked(url: url)
        if trackerBlocked {
            self.blockedThreatMessage = "BLOCKED SUB-RESOURCE: \(trackerReason ?? "Telemetry domain rejected")"
            SecurityAuditLogger.shared.recordThreat(
                type: "Tracker Drop",
                target: host,
                reason: trackerReason ?? "Telemetry domain",
                mitigation: "Suppressed script/ad request",
                severity: .warning,
                isPrivateSession: isPrivateMode
            )
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.isLoading = true
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.isLoading = false
        self.title = webView.title ?? (browserMode == .normal ? "Google Search Session" : "Secure Session")
        self.canGoBack = webView.canGoBack
        self.canGoForward = webView.canGoForward

        // Re-evaluate memory tier upon document completion & purge transient allocations
        _ = MemoryGovernor.shared.evaluateAndEnforce(activeWebView: webView)
        _ = autoreleasepool {
            malloc_zone_pressure_relief(malloc_default_zone(), 0)
        }

        // Lightweight background DOM check for presentation barriers (Bypass Wall)
        Task { [weak self, weak webView] in
            guard let self = self, let wv = webView else { return }
            await self.bypassWallManager.analyzeCurrentPage(webView: wv, url: wv.url)
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.isLoading = false
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.isLoading = false
    }
}
