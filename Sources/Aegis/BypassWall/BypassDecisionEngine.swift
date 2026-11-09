import Foundation

public enum BypassDecision: Sendable, Equatable {
    case allowCleanView(article: CleanedArticle, overlaySelectors: [String], result: ExplainableBypassResult)
    case refuseAccessControl(result: ExplainableBypassResult)
    case noActionNeeded(result: ExplainableBypassResult)
    case followSafeRedirect(targetURL: URL, result: ExplainableBypassResult)
    case unsupported(result: ExplainableBypassResult)
}

public final class BypassDecisionEngine: Sendable {
    public static let shared = BypassDecisionEngine()

    public init() {}

    /// Evaluates the classified state against strict access-control policies
    public func decide(
        classification: WallClassification,
        payload: DOMInspectionPayload,
        sourceURL: URL?
    ) -> BypassDecision {
        switch classification {
        case .none:
            let explain = ExplainableBypassResult(
                status: "Normal Webpage",
                actionTaken: "No bypass needed.",
                contentSource: "Content is already directly accessible.",
                securityAffirmation: "✅ Webpage has no active presentation or access barriers.",
                isRefusal: false
            )
            return .noActionNeeded(result: explain)

        case .presentationBarrier(let type, let isFullAvailable):
            let article = BypassWallExtractor.shared.extractArticle(
                from: payload,
                sourceURL: sourceURL,
                isPartial: !isFullAvailable
            )
            let actionText = isFullAvailable
                ? "Removed \(type.rawValue) and exposed public content in Clean Reading View."
                : "Extracted publicly available portion. Obstructive overlay suppressed."
            let sourceText = isFullAvailable
                ? "Public content was already delivered to browser DOM."
                : "Publicly available teaser section extracted. Subsequent content is gated."

            let explain = ExplainableBypassResult(
                status: "Presentation Barrier Detected (\(type.rawValue))",
                actionTaken: actionText,
                contentSource: sourceText,
                securityAffirmation: "✅ Verified: No authentication, subscription, paywall, or access-control mechanism was circumvented.",
                isRefusal: false
            )
            return .allowCleanView(article: article, overlaySelectors: payload.overlaySelectors, result: explain)

        case .accessControlBarrier(let type, _):
            let explain = ExplainableBypassResult(
                status: "Access-Control Barrier (\(type.rawValue))",
                actionTaken: "No bypass performed.",
                contentSource: "The requested content requires authorization/subscription.",
                securityAffirmation: "🛑 Non-Circumvention Policy: True access-control mechanisms (authentication, paywalls, CAPTCHA) are never bypassed.",
                isRefusal: true
            )
            return .refuseAccessControl(result: explain)

        case .redirectInterstitial(let targetURL):
            // Validate scheme: Only safe http or https
            guard let scheme = targetURL.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
                let explain = ExplainableBypassResult(
                    status: "Unsafe Redirect Target",
                    actionTaken: "Redirect cancelled.",
                    contentSource: "Untrusted or unsupported protocol (\(targetURL.scheme ?? "none")).",
                    securityAffirmation: "🛑 Blocked unsafe protocol redirect.",
                    isRefusal: true
                )
                return .unsupported(result: explain)
            }

            let explain = ExplainableBypassResult(
                status: "Public Redirect Interstitial",
                actionTaken: "Navigating to destination: \(targetURL.host ?? targetURL.absoluteString)",
                contentSource: "Public destination URL.",
                securityAffirmation: "✅ Safe public navigation.",
                isRefusal: false
            )
            return .followSafeRedirect(targetURL: targetURL, result: explain)

        case .unsupported(let reason):
            let explain = ExplainableBypassResult(
                status: "Unsupported Webpage",
                actionTaken: "No action taken.",
                contentSource: reason,
                securityAffirmation: "⚠️ Page structure or scheme is not supported for extraction.",
                isRefusal: true
            )
            return .unsupported(result: explain)
        }
    }
}
