import Foundation
import Combine

public struct Bookmark: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var url: String
    public let createdAt: Date

    public init(id: UUID = UUID(), title: String, url: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.url = url
        self.createdAt = createdAt
    }
}

/// Global thread-safe Bookmark manager for Aegis.
/// Stores bookmarks in local JSON storage inside ~/Library/Application Support/Aegis/bookmarks.json
@MainActor
public final class BookmarkManager: ObservableObject {
    public static let shared = BookmarkManager()

    @Published public private(set) var bookmarks: [Bookmark] = []
    @Published public var searchText: String = ""

    private let bookmarksFileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let aegisDir = appSupport.appendingPathComponent("Aegis", isDirectory: true)
        try? FileManager.default.createDirectory(at: aegisDir, withIntermediateDirectories: true)
        self.bookmarksFileURL = aegisDir.appendingPathComponent("bookmarks.json")

        loadBookmarks()
    }

    /// Loads bookmarks from disk, or seeds default privacy-first bookmarks if first run
    public func loadBookmarks() {
        if let data = try? Data(contentsOf: bookmarksFileURL),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) {
            self.bookmarks = decoded
        } else {
            // Default built-in bookmarks
            let defaults = [
                Bookmark(title: "DuckDuckGo (Zero-Trace)", url: "https://html.duckduckgo.com"),
                Bookmark(title: "Google Search", url: "https://www.google.com"),
                Bookmark(title: "GitHub", url: "https://github.com"),
                Bookmark(title: "Apple Developer", url: "https://developer.apple.com"),
                Bookmark(title: "Hacker News", url: "https://news.ycombinator.com"),
                Bookmark(title: "Wikipedia", url: "https://www.wikipedia.org"),
                Bookmark(title: "EFF Privacy", url: "https://www.eff.org")
            ]
            self.bookmarks = defaults
            saveBookmarks()
        }
    }

    public func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            try? data.write(to: bookmarksFileURL, options: .atomic)
        }
    }

    public func isBookmarked(url: String) -> Bool {
        guard let target = cleanURL(url) else { return false }
        return bookmarks.contains { cleanURL($0.url) == target }
    }

    @discardableResult
    public func addBookmark(title: String, url: String) -> Bookmark? {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, trimmedURL != "about:blank" else { return nil }

        if let existing = bookmarks.first(where: { cleanURL($0.url) == cleanURL(trimmedURL) }) {
            return existing
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = cleanTitle.isEmpty ? (URL(string: trimmedURL)?.host ?? trimmedURL) : cleanTitle

        let newBookmark = Bookmark(title: finalTitle, url: trimmedURL)
        bookmarks.insert(newBookmark, at: 0)
        saveBookmarks()
        return newBookmark
    }

    public func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        saveBookmarks()
    }

    public func removeBookmark(url: String) {
        guard let target = cleanURL(url) else { return }
        bookmarks.removeAll { cleanURL($0.url) == target }
        saveBookmarks()
    }

    public func toggleBookmark(title: String, url: String) {
        if isBookmarked(url: url) {
            removeBookmark(url: url)
        } else {
            addBookmark(title: title, url: url)
        }
    }

    private func cleanURL(_ urlStr: String) -> String? {
        let trimmed = urlStr.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        // Strip trailing slash
        if trimmed.hasSuffix("/") {
            return String(trimmed.dropLast())
        }
        return trimmed
    }
}
