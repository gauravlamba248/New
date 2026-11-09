import Foundation

public final class BypassWallExtractor: Sendable {
    public static let shared = BypassWallExtractor()

    private let sanitizer = BypassWallSanitizer.shared

    public init() {}

    /// Extracts clean article from DOMInspectionPayload
    public func extractArticle(
        from payload: DOMInspectionPayload,
        sourceURL: URL?,
        isPartial: Bool = false
    ) -> CleanedArticle {
        let title = payload.articleHeadline ?? payload.documentTitle
        let author = payload.bylineAuthor?.isEmpty == false ? payload.bylineAuthor : nil
        let date = payload.datePublished?.isEmpty == false ? payload.datePublished : nil
        let siteName = sourceURL?.host ?? "Web Article"

        var rawBodyHTML = payload.extractedArticleHTML ?? ""

        // If article HTML is empty or too short, synthesize from plain paragraphs
        if rawBodyHTML.trimmingCharacters(in: .whitespacesAndNewlines).count < 100 {
            rawBodyHTML = "<p>\(title)</p>"
        }

        // Sanitize extracted HTML
        let sanitizedHTML = sanitizer.sanitizeHTML(rawBodyHTML)
        let plainText = sanitizer.stripToPlainText(sanitizedHTML)

        let words = plainText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let wordCount = words.count
        let readingTime = max(1, Int(ceil(Double(wordCount) / 220.0)))

        let partialNotice = isPartial ? "Publicly accessible portion extracted. Additional content is restricted by subscription or authentication." : nil

        return CleanedArticle(
            title: title.isEmpty ? "Clean Reading View" : title,
            author: author,
            publicationDate: date,
            siteName: siteName,
            sourceURL: sourceURL,
            sanitizedHTML: sanitizedHTML,
            plainText: plainText,
            wordCount: wordCount,
            estimatedReadingMinutes: readingTime,
            isPartialContent: isPartial,
            partialNotice: partialNotice
        )
    }

    /// Extracts clean article from raw HTML string
    public func extractArticleFromRawHTML(
        _ html: String,
        sourceURL: URL?,
        isPartial: Bool = false
    ) -> CleanedArticle {
        // Extract Title
        var title = "Article"
        if let titleRange = html.range(of: "(?i)<title[^>]*>(.*?)</title>", options: .regularExpression) {
            let matched = String(html[titleRange])
            title = matched
                .replacingOccurrences(of: "(?i)<title[^>]*>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "(?i)</title>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract Author
        var author: String? = nil
        if let authorRange = html.range(of: "(?i)<meta[^>]+name=[\"']author[\"'][^>]+content=[\"']([^\"']+)[\"']", options: .regularExpression) {
            let matched = String(html[authorRange])
            if let contentRange = matched.range(of: "content=[\"']([^\"']+)[\"']", options: .regularExpression) {
                author = String(matched[contentRange])
                    .replacingOccurrences(of: "content=", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
            }
        }

        // Extract Body paragraphs & headings
        var bodyHTML = ""
        let tagRegex = try? NSRegularExpression(pattern: "(?is)<(p|h1|h2|h3|h4|blockquote|li)[^>]*>(.*?)</\\1>", options: [])
        let ns = html as NSString
        let matches = tagRegex?.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length)) ?? []

        for m in matches {
            let chunk = ns.substring(with: m.range)
            // Skip short boilerplate/scripts
            if chunk.count > 30 && !chunk.contains("cookie") && !chunk.contains("copyright") && !chunk.contains("all rights reserved") {
                bodyHTML += chunk + "\n"
            }
        }

        if bodyHTML.isEmpty {
            bodyHTML = "<p>\(title)</p>"
        }

        let sanitized = sanitizer.sanitizeHTML(bodyHTML)
        let plainText = sanitizer.stripToPlainText(sanitized)
        let wordCount = plainText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let readingTime = max(1, Int(ceil(Double(wordCount) / 220.0)))

        return CleanedArticle(
            title: title,
            author: author,
            publicationDate: nil,
            siteName: sourceURL?.host ?? "Web Article",
            sourceURL: sourceURL,
            sanitizedHTML: sanitized,
            plainText: plainText,
            wordCount: wordCount,
            estimatedReadingMinutes: readingTime,
            isPartialContent: isPartial,
            partialNotice: isPartial ? "Publicly available content extracted. Additional content requires authorization/subscription." : nil
        )
    }
}
