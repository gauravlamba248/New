import Foundation

/// Ultra-lightweight, 100% offline Intent Router and Natural Language Parser.
/// Operates via compiled regular expressions, keyword tokenization, and morphological rules.
public final class OfflineIntentRouter: Sendable {
    public static let shared = OfflineIntentRouter()

    private let urlRegex: NSRegularExpression
    private let ipRegex: NSRegularExpression

    private init() {
        // High-speed compiled patterns
        self.urlRegex = try! NSRegularExpression(
            pattern: #"\b(?:https?:\/\/)?(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?::\d+)?(?:\/[^\s]*)?\b"#,
            options: .caseInsensitive
        )
        self.ipRegex = try! NSRegularExpression(
            pattern: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#,
            options: []
        )
    }

    /// Primary entry point: parses raw user string and produces an executable intent.
    public func resolve(query: String) -> IntentResolution {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return IntentResolution(
                intent: .unknown(raw: query),
                confidence: 0.0,
                rawQuery: query,
                explanation: "Empty input received."
            )
        }

        let lowercased = trimmed.lowercased()
        let isPrivate = lowercased.contains("private") ||
                        lowercased.contains("incognito") ||
                        lowercased.contains("stealth") ||
                        lowercased.contains("secure browser") ||
                        lowercased.contains("secret")

        // 0. Reset to Initial State / Empty Browser
        if lowercased == "home" ||
           lowercased == "reset" ||
           lowercased == "reset browser" ||
           lowercased == "initial state" ||
           lowercased == "empty browser" ||
           lowercased == "clear browser" ||
           lowercased == "new session" {
            return IntentResolution(
                intent: .resetBrowser,
                confidence: 0.99,
                rawQuery: query,
                explanation: "Resetting browser to clean initial empty state & freeing memory"
            )
        }

        // 1. Air-Gap & Sandbox Isolation Commands
        if lowercased.contains("air gap") || lowercased.contains("airgap") || lowercased.contains("isolate") {
            let enable = !(lowercased.contains("off") || lowercased.contains("disable") || lowercased.contains("stop"))
            return IntentResolution(
                intent: .toggleAirGap(enable: enable),
                confidence: 0.95,
                rawQuery: query,
                explanation: "Detected air-gap toggle command: \(enable ? "Enable isolation" : "Disable isolation")"
            )
        }

        // 1.5 ISP Cloak / Proxy Tunnel commands
        if lowercased.contains("cloak") || lowercased.contains("blindfold isp") || lowercased.contains("hide from isp") || lowercased.contains("proxy tunnel") {
            let enable = !(lowercased.contains("off") || lowercased.contains("disable") || lowercased.contains("stop"))
            return IntentResolution(
                intent: .toggleISPCloak(enable: enable),
                confidence: 0.95,
                rawQuery: query,
                explanation: "Detected ISP Cloak toggle command: \(enable ? "Enable encrypted tunnel" : "Disable encrypted tunnel")"
            )
        }

        // 2. Vault / Device Desert commands
        if lowercased.contains("vault") || lowercased.contains("desert") || lowercased.contains("quarantine") {
            // Check if there is a file path argument
            let pathPrefixes = ["quarantine file ", "isolate file ", "quarantine ", "lock "]
            for prefix in pathPrefixes {
                if let range = lowercased.range(of: prefix) {
                    let path = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !path.isEmpty {
                        return IntentResolution(
                            intent: .quarantineFile(path: path),
                            confidence: 0.92,
                            rawQuery: query,
                            explanation: "Detected request to quarantine target file: \(path)"
                        )
                    }
                }
            }

            return IntentResolution(
                intent: .inspectVault,
                confidence: 0.92,
                rawQuery: query,
                explanation: "Detected navigation to Device Desert Secure Download Vault"
            )
        }

        // 3. IP Blacklisting & Filtering Commands
        if lowercased.contains("block ip") || lowercased.contains("blacklist ip") || lowercased.contains("ban ip") {
            if let ip = extractFirstMatch(pattern: ipRegex, in: trimmed) {
                return IntentResolution(
                    intent: .blockIP(ip: ip),
                    confidence: 0.98,
                    rawQuery: query,
                    explanation: "Extracted target IPv4 address for dynamic blacklisting: \(ip)"
                )
            }
        }

        // 4. Domain Blacklisting
        if lowercased.contains("block domain") || lowercased.contains("blacklist domain") {
            let tokens = trimmed.split(separator: " ")
            if let domainToken = tokens.last {
                let domain = String(domainToken).trimmingCharacters(in: CharacterSet(charactersIn: " '\""))
                return IntentResolution(
                    intent: .blockDomain(domain: domain),
                    confidence: 0.90,
                    rawQuery: query,
                    explanation: "Extracted domain for offline ad/tracker blocker: \(domain)"
                )
            }
        }

        // 5. Diagnostics & System Scan
        if lowercased.contains("diagnostics") || lowercased.contains("scan") || lowercased.contains("threat check") || lowercased.contains("status") {
            return IntentResolution(
                intent: .runDiagnostics,
                confidence: 0.91,
                rawQuery: query,
                explanation: "Invoking native security subsystem audit and memory diagnostic"
            )
        }

        // 6. Audit & Threat Logs
        if lowercased.contains("clear log") || lowercased.contains("delete log") {
            return IntentResolution(
                intent: .clearLogs,
                confidence: 0.96,
                rawQuery: query,
                explanation: "Request to purge local audit logs"
            )
        }

        if lowercased.contains("log") || lowercased.contains("audit") || lowercased.contains("threat history") {
            let category: LogCategoryFilter = lowercased.contains("threat") ? .threats : (lowercased.contains("activity") ? .activity : .all)
            return IntentResolution(
                intent: .viewLogs(category: category),
                confidence: 0.93,
                rawQuery: query,
                explanation: "Navigating to Audit Hub filtered by: \(category.rawValue)"
            )
        }

        // 7. Direct URL Navigation
        let navPrefixes = ["open ", "goto ", "go to ", "visit ", "browse ", "load "]
        var candidateURLString = trimmed
        for prefix in navPrefixes {
            if lowercased.hasPrefix(prefix) {
                candidateURLString = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Check if candidate matches a URL domain structure
        if let matchedURL = extractFirstMatch(pattern: urlRegex, in: candidateURLString) {
            let formattedString = matchedURL.contains("://") ? matchedURL : "https://" + matchedURL
            if let url = URL(string: formattedString) {
                return IntentResolution(
                    intent: .navigate(url: url, isPrivate: isPrivate),
                    confidence: 0.94,
                    rawQuery: query,
                    explanation: "Resolved destination URL: \(url.absoluteString) [Private: \(isPrivate)]"
                )
            }
        }

        // 8. Explicit or Default Web Search
        var searchQuery = trimmed
        let searchPrefixes = ["search for ", "search ", "find ", "lookup ", "google ", "duckduckgo "]
        for prefix in searchPrefixes {
            if lowercased.hasPrefix(prefix) {
                searchQuery = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Remove private modifiers from the actual search terms
        searchQuery = searchQuery
            .replacingOccurrences(of: "privately", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "in incognito", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return IntentResolution(
            intent: .search(query: searchQuery, isPrivate: isPrivate),
            confidence: 0.88,
            rawQuery: query,
            explanation: "Interpreted as local search request: '\(searchQuery)' [Private: \(isPrivate)]"
        )
    }

    private func extractFirstMatch(pattern: NSRegularExpression, in text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = pattern.firstMatch(in: text, options: [], range: range) else {
            return nil
        }
        if let swiftRange = Range(match.range, in: text) {
            return String(text[swiftRange])
        }
        return nil
    }
}
