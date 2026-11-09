import Foundation

public struct DOMInspectionPayload: Codable, Sendable {
    public let hasPaywallIndicators: Bool
    public let paywallMatchedKeywords: [String]
    public let isAccessibleForFreeFalse: Bool
    public let hasCaptchaIndicators: Bool
    public let captchaMatchedKeywords: [String]
    public let hasLoginPrompt: Bool
    public let hasSignupPrompt: Bool
    public let hasNewsletterPrompt: Bool
    public let hasCookieConsentPrompt: Bool
    public let hasOverlayElements: Bool
    public let overlaySelectors: [String]
    public let substantiveParagraphsCount: Int
    public let totalTextLength: Int
    public let metaRefreshTarget: String?
    public let documentTitle: String
    public let articleHeadline: String?
    public let bylineAuthor: String?
    public let datePublished: String?
    public let extractedArticleHTML: String?

    public init(
        hasPaywallIndicators: Bool = false,
        paywallMatchedKeywords: [String] = [],
        isAccessibleForFreeFalse: Bool = false,
        hasCaptchaIndicators: Bool = false,
        captchaMatchedKeywords: [String] = [],
        hasLoginPrompt: Bool = false,
        hasSignupPrompt: Bool = false,
        hasNewsletterPrompt: Bool = false,
        hasCookieConsentPrompt: Bool = false,
        hasOverlayElements: Bool = false,
        overlaySelectors: [String] = [],
        substantiveParagraphsCount: Int = 0,
        totalTextLength: Int = 0,
        metaRefreshTarget: String? = nil,
        documentTitle: String = "",
        articleHeadline: String? = nil,
        bylineAuthor: String? = nil,
        datePublished: String? = nil,
        extractedArticleHTML: String? = nil
    ) {
        self.hasPaywallIndicators = hasPaywallIndicators
        self.paywallMatchedKeywords = paywallMatchedKeywords
        self.isAccessibleForFreeFalse = isAccessibleForFreeFalse
        self.hasCaptchaIndicators = hasCaptchaIndicators
        self.captchaMatchedKeywords = captchaMatchedKeywords
        self.hasLoginPrompt = hasLoginPrompt
        self.hasSignupPrompt = hasSignupPrompt
        self.hasNewsletterPrompt = hasNewsletterPrompt
        self.hasCookieConsentPrompt = hasCookieConsentPrompt
        self.hasOverlayElements = hasOverlayElements
        self.overlaySelectors = overlaySelectors
        self.substantiveParagraphsCount = substantiveParagraphsCount
        self.totalTextLength = totalTextLength
        self.metaRefreshTarget = metaRefreshTarget
        self.documentTitle = documentTitle
        self.articleHeadline = articleHeadline
        self.bylineAuthor = bylineAuthor
        self.datePublished = datePublished
        self.extractedArticleHTML = extractedArticleHTML
    }
}

public final class BypassWallDetector: Sendable {
    public static let shared = BypassWallDetector()

    public init() {}

    /// High-efficiency client-side JavaScript snippet to inspect the rendered DOM in WKWebView
    public var domInspectionScript: String {
        return """
        (function() {
            try {
                const bodyText = (document.body ? document.body.innerText : "").toLowerCase();
                const htmlContent = document.documentElement ? document.documentElement.innerHTML.toLowerCase() : "";

                // 1. Paywall Detection
                const paywallKeywords = [
                    "subscription required", "subscribe to continue", "subscribe to read",
                    "paid membership", "premium content", "article limit reached",
                    "you have reached your free article limit", "payment required",
                    "members only", "exclusive to subscribers", "subscribe now for",
                    "unlock this article", "start your free trial to read"
                ];
                let matchedPaywall = [];
                for (const kw of paywallKeywords) {
                    if (bodyText.includes(kw)) matchedPaywall.push(kw);
                }

                // Check JSON-LD isAccessibleForFree standard
                let isAccessibleForFreeFalse = false;
                const scripts = document.querySelectorAll('script[type="application/ld+json"]');
                for (const s of scripts) {
                    try {
                        const json = JSON.parse(s.textContent);
                        if (json.isAccessibleForFree === false || json.isAccessibleForFree === "False") {
                            isAccessibleForFreeFalse = true;
                        }
                    } catch(e) {}
                }

                // Check content_tier meta tag
                const tierMeta = document.querySelector('meta[property="article:content_tier"], meta[name="article:content_tier"]');
                if (tierMeta && (tierMeta.content === "locked" || tierMeta.content === "metered")) {
                    isAccessibleForFreeFalse = true;
                }

                // 2. CAPTCHA & Anti-Bot Detection
                const captchaKeywords = [
                    "cf-turnstile", "g-recaptcha", "h-captcha", "cf-browser-verification",
                    "verify you are human", "checking your browser before accessing",
                    "please complete the security check", "challenge-running"
                ];
                let matchedCaptcha = [];
                for (const ck of captchaKeywords) {
                    if (htmlContent.includes(ck) || bodyText.includes(ck)) matchedCaptcha.push(ck);
                }

                // 3. Login / Signup Prompts
                const loginKeywords = ["sign in to continue", "log in to continue", "sign in to read", "log in to read"];
                const hasLogin = loginKeywords.some(k => bodyText.includes(k));

                const signupKeywords = ["create an account to continue", "create an account to read", "sign up to continue", "register to read"];
                const hasSignup = signupKeywords.some(k => bodyText.includes(k));

                // 4. Newsletter & Consent Overlays
                const newsletterKeywords = ["sign up for our newsletter", "join our newsletter", "enter your email to read", "subscribe to our mailing list"];
                const hasNewsletter = newsletterKeywords.some(k => bodyText.includes(k));

                const cookieKeywords = ["we use cookies", "cookie consent", "accept all cookies", "manage cookie preferences"];
                const hasCookie = cookieKeywords.some(k => bodyText.includes(k));

                // 5. Detect Obstructive Overlays (fixed/absolute with high z-index)
                let overlaySelectors = [];
                const allElements = document.querySelectorAll('div, section, aside, modal, dialog');
                for (const el of allElements) {
                    const style = window.getComputedStyle(el);
                    const pos = style.position;
                    const zIndex = parseInt(style.zIndex, 10);
                    if ((pos === 'fixed' || pos === 'absolute') && zIndex >= 90) {
                        const rect = el.getBoundingClientRect();
                        if (rect.width >= window.innerWidth * 0.4 && rect.height >= window.innerHeight * 0.3) {
                            if (el.id) {
                                overlaySelectors.push('#' + el.id);
                            } else if (el.className && typeof el.className === 'string') {
                                const firstClass = el.className.trim().split(/\\s+/)[0];
                                if (firstClass) overlaySelectors.push('.' + firstClass);
                            }
                        }
                    }
                }

                // 6. Substantive Content Analysis
                const paragraphs = Array.from(document.querySelectorAll('article p, main p, .article-body p, .story-body p, p'));
                const substantiveP = paragraphs.filter(p => p.innerText.trim().length >= 40);
                let totalPText = substantiveP.map(p => p.innerText).join(" ");

                // 7. Extract Main Article Element
                let articleElement = document.querySelector('article') || document.querySelector('main') || document.querySelector('.article-body') || document.querySelector('.entry-content');
                let articleHTML = articleElement ? articleElement.innerHTML : "";

                // Metadata
                const metaTitle = document.querySelector('meta[property="og:title"]') || document.querySelector('meta[name="twitter:title"]');
                const title = metaTitle ? metaTitle.content : document.title;

                const metaAuthor = document.querySelector('meta[name="author"]') || document.querySelector('meta[property="article:author"]');
                const author = metaAuthor ? metaAuthor.content : "";

                const metaDate = document.querySelector('meta[property="article:published_time"]') || document.querySelector('time');
                const date = metaDate ? (metaDate.content || metaDate.getAttribute('datetime') || metaDate.innerText) : "";

                // Meta refresh
                const metaRefresh = document.querySelector('meta[http-equiv="refresh"]');
                let refreshTarget = null;
                if (metaRefresh && metaRefresh.content) {
                    const parts = metaRefresh.content.split('url=');
                    if (parts.length > 1) refreshTarget = parts[1].trim();
                }

                return JSON.stringify({
                    hasPaywallIndicators: matchedPaywall.length > 0,
                    paywallMatchedKeywords: matchedPaywall,
                    isAccessibleForFreeFalse: isAccessibleForFreeFalse,
                    hasCaptchaIndicators: matchedCaptcha.length > 0,
                    captchaMatchedKeywords: matchedCaptcha,
                    hasLoginPrompt: hasLogin,
                    hasSignupPrompt: hasSignup,
                    hasNewsletterPrompt: hasNewsletter,
                    hasCookieConsentPrompt: hasCookie,
                    hasOverlayElements: overlaySelectors.length > 0,
                    overlaySelectors: overlaySelectors.slice(0, 10),
                    substantiveParagraphsCount: substantiveP.length,
                    totalTextLength: totalPText.length,
                    metaRefreshTarget: refreshTarget,
                    documentTitle: title,
                    articleHeadline: title,
                    bylineAuthor: author,
                    datePublished: date,
                    extractedArticleHTML: articleHTML
                });
            } catch(e) {
                return JSON.stringify({ error: e.toString() });
            }
        })();
        """
    }

    /// Evaluates the DOM payload to classify wall type adhering strictly to access-control guidelines
    public func classify(payload: DOMInspectionPayload) -> WallClassification {
        // 1. CAPTCHA / Bot Gate Detection -> Strict non-circumvention
        if payload.hasCaptchaIndicators {
            let matched = payload.captchaMatchedKeywords.joined(separator: ", ")
            return .accessControlBarrier(type: .captchaChallenge, reason: "Anti-bot CAPTCHA challenge detected (\(matched)). Bypass Wall cannot circumvent security challenges.")
        }

        // 2. Genuine Paid Paywall Detection -> Strict non-circumvention
        // If content is marked as paid/not accessible for free OR paywall keywords exist without substantive content delivered
        if payload.isAccessibleForFreeFalse || (payload.hasPaywallIndicators && payload.totalTextLength < 400) {
            let reason = payload.isAccessibleForFreeFalse ? "Document metadata flags resource as paid/subscription required (schema.org isAccessibleForFree: false)." : "Subscription paywall barrier detected."
            return .accessControlBarrier(type: .paidSubscriptionPaywall, reason: reason)
        }

        // 3. True Authentication Wall Detection
        // If login/signup is required AND underlying content is NOT delivered in DOM
        if (payload.hasLoginPrompt || payload.hasSignupPrompt) && payload.totalTextLength < 300 {
            return .accessControlBarrier(type: .authenticationRequired, reason: "Account authentication is required to access this resource. Underlying content is not delivered to browser.")
        }

        // 4. Presentation-Level Overlays (Content is delivered and present in DOM, but obstructed by cosmetic UI)
        let hasSubstantiveContent = payload.totalTextLength >= 300 || payload.substantiveParagraphsCount >= 2

        if payload.hasNewsletterPrompt && hasSubstantiveContent {
            return .presentationBarrier(type: .newsletterPrompt, isFullContentAvailable: true)
        }

        if payload.hasSignupPrompt && hasSubstantiveContent {
            return .presentationBarrier(type: .signupModalOverlay, isFullContentAvailable: true)
        }

        if payload.hasLoginPrompt && hasSubstantiveContent {
            return .presentationBarrier(type: .loginModalOverlay, isFullContentAvailable: true)
        }

        if payload.hasOverlayElements && hasSubstantiveContent {
            return .presentationBarrier(type: .promotionalModal, isFullContentAvailable: true)
        }

        if payload.hasCookieConsentPrompt && hasSubstantiveContent && payload.hasOverlayElements {
            return .presentationBarrier(type: .cookieConsentOverlay, isFullContentAvailable: true)
        }

        // 5. Paywall where partial teaser content is delivered
        if payload.hasPaywallIndicators && hasSubstantiveContent {
            return .presentationBarrier(type: .promotionalModal, isFullContentAvailable: false)
        }

        // 6. Redirect Interstitial
        if let target = payload.metaRefreshTarget, let url = URL(string: target) {
            return .redirectInterstitial(targetURL: url)
        }

        // 7. Normal Public Webpage
        return .none
    }

    /// Evaluates raw HTML string directly (for link-level inspection, pre-navigation checks, and test harnesses)
    public func inspectHTMLString(_ html: String, url: URL? = nil) -> WallClassification {
        let lower = html.lowercased()

        // CAPTCHA
        if lower.contains("cf-turnstile") || lower.contains("g-recaptcha") || lower.contains("h-captcha") || lower.contains("verify you are human") {
            return .accessControlBarrier(type: .captchaChallenge, reason: "CAPTCHA challenge detected.")
        }

        // Paywall metadata
        if lower.contains("\"isaccessibleforfree\": false") || lower.contains("\"isaccessibleforfree\":\"false\"") {
            return .accessControlBarrier(type: .paidSubscriptionPaywall, reason: "Document metadata declares paid subscription required.")
        }

        let paywallKeywords = ["subscription required", "subscribe to continue", "subscribe to read", "premium content", "article limit reached"]
        let hasPaywallKw = paywallKeywords.contains { lower.contains($0) }

        // Paragraph extraction
        let pMatches = html.components(separatedBy: "</p>")
        let substantial = pMatches.filter { $0.count >= 40 }
        let totalPTextLen = substantial.reduce(0) { $0 + $1.count }

        if hasPaywallKw && totalPTextLen < 400 {
            return .accessControlBarrier(type: .paidSubscriptionPaywall, reason: "Paid subscription required.")
        }

        let hasLoginPrompt = lower.contains("sign in to continue") || lower.contains("log in to continue") || lower.contains("sign in to read") || lower.contains("log in to read") || lower.contains("login-modal")
        let hasSignupPrompt = lower.contains("create an account to continue") || lower.contains("create an account to read") || lower.contains("create an account") || lower.contains("sign up to continue") || lower.contains("sign up to read") || lower.contains("register to read") || lower.contains("signup-wall")

        if (hasLoginPrompt || hasSignupPrompt) && totalPTextLen < 300 {
            return .accessControlBarrier(type: .authenticationRequired, reason: "Account authentication required to view content.")
        }

        if (hasLoginPrompt || hasSignupPrompt) && totalPTextLen >= 300 {
            return .presentationBarrier(type: hasLoginPrompt ? .loginModalOverlay : .signupModalOverlay, isFullContentAvailable: true)
        }

        if (lower.contains("join our newsletter") || lower.contains("sign up for our newsletter")) && totalPTextLen >= 300 {
            return .presentationBarrier(type: .newsletterPrompt, isFullContentAvailable: true)
        }

        if hasPaywallKw && totalPTextLen >= 400 {
            return .presentationBarrier(type: .promotionalModal, isFullContentAvailable: false)
        }

        return .none
    }
}
