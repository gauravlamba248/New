import Foundation

public final class BypassWallSanitizer: Sendable {
    public static let shared = BypassWallSanitizer()

    public init() {}

    /// Thoroughly sanitizes untrusted HTML extracted from a webpage to prevent XSS, script injection, and privilege escalation.
    public func sanitizeHTML(_ rawHTML: String) -> String {
        var clean = rawHTML

        // 1. Remove dangerous active elements completely
        let dangerousTags = [
            "(?is)<script[^>]*>.*?</script>",
            "(?is)<script[^>]*/>",
            "(?is)<style[^>]*>.*?</style>",
            "(?is)<iframe[^>]*>.*?</iframe>",
            "(?is)<iframe[^>]*/>",
            "(?is)<object[^>]*>.*?</object>",
            "(?is)<embed[^>]*>.*?</embed>",
            "(?is)<applet[^>]*>.*?</applet>",
            "(?is)<form[^>]*>.*?</form>",
            "(?is)<input[^>]*>",
            "(?is)<button[^>]*>.*?</button>",
            "(?is)<textarea[^>]*>.*?</textarea>",
            "(?is)<select[^>]*>.*?</select>",
            "(?is)<base[^>]*>",
            "(?is)<link[^>]*>",
            "(?is)<meta[^>]*>",
            "(?is)<svg[^>]*>.*?</svg>",
            "(?is)<canvas[^>]*>.*?</canvas>"
        ]

        for pattern in dangerousTags {
            clean = clean.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        // 2. Strip all inline JavaScript event handlers (e.g., onload, onclick, onerror, onmouseover)
        let eventHandlerPattern = "(?i)\\s+on[a-z0-9_-]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)"
        clean = clean.replacingOccurrences(of: eventHandlerPattern, with: "", options: .regularExpression)

        // 3. Neutralize dangerous pseudo-protocols in href/src (javascript:, vbscript:, data:, file:)
        let dangerousProtocols = [
            "(?i)\\s+href\\s*=\\s*(\"\\s*(javascript|vbscript|data|file|about):[^\"]*\"|'\\s*(javascript|vbscript|data|file|about):[^']*'|\\s*(javascript|vbscript|data|file|about):[^\\s>]+)",
            "(?i)\\s+src\\s*=\\s*(\"\\s*(javascript|vbscript|data|file|about):[^\"]*\"|'\\s*(javascript|vbscript|data|file|about):[^']*'|\\s*(javascript|vbscript|data|file|about):[^\\s>]+)"
        ]
        for dp in dangerousProtocols {
            clean = clean.replacingOccurrences(of: dp, with: "", options: .regularExpression)
        }

        // 4. Strip style attributes to prevent CSS expression() injection and UI spoofing
        let stylePattern = "(?i)\\s+style\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)"
        clean = clean.replacingOccurrences(of: stylePattern, with: "", options: .regularExpression)

        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strips all HTML tags to produce pure plain text
    public func stripToPlainText(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "(?is)<br\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)</p>", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)</h[1-6]>", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)</li>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<[^>]+>", with: "", options: .regularExpression)

        // Decode common HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&mdash;", with: "—")
        text = text.replacingOccurrences(of: "&ndash;", with: "–")

        // Collapse multiple blank lines
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
