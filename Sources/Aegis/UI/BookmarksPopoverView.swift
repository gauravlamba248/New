import SwiftUI

public struct BookmarksPopoverView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var bookmarkManager = BookmarkManager.shared

    public init(appState: AppState) {
        self.appState = appState
    }

    private var filteredBookmarks: [Bookmark] {
        if bookmarkManager.searchText.isEmpty {
            return bookmarkManager.bookmarks
        }
        return bookmarkManager.bookmarks.filter {
            $0.title.localizedCaseInsensitiveContains(bookmarkManager.searchText) ||
            $0.url.localizedCaseInsensitiveContains(bookmarkManager.searchText)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 13, weight: .bold))

                Text("Bookmarks")
                    .font(.system(size: 13, weight: .heavy))

                Spacer()

                Text("\(bookmarkManager.bookmarks.count) saved")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                Button(action: {
                    appState.toggleCurrentBookmark()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: appState.isCurrentPageBookmarked() ? "star.fill" : "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text(appState.isCurrentPageBookmarked() ? "Bookmarked" : "Add Page")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(appState.isCurrentPageBookmarked() ? Color.yellow.opacity(0.18) : Color.accentColor.opacity(0.15))
                    .foregroundColor(appState.isCurrentPageBookmarked() ? .yellow : .accentColor)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Bookmark current active page")
            }

            // Search Filter
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))

                TextField("Filter bookmarks...", text: $bookmarkManager.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))

                if !bookmarkManager.searchText.isEmpty {
                    Button(action: { bookmarkManager.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )

            Divider()

            // Bookmark List
            if filteredBookmarks.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text(bookmarkManager.searchText.isEmpty ? "No bookmarks saved yet" : "No matching bookmarks")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredBookmarks) { bookmark in
                            bookmarkRow(bookmark)
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .foregroundColor(.accentColor)
                .font(.system(size: 11))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(bookmark.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(bookmark.url)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Open in New Tab Button
            Button(action: {
                if let url = URL(string: bookmark.url) {
                    appState.openNewTab(url: url)
                    appState.isBookmarksPopoverOpen = false
                }
            }) {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open in New Tab")

            // Delete Bookmark Button
            Button(action: {
                bookmarkManager.removeBookmark(id: bookmark.id)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Delete bookmark")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(5)
        .onTapGesture {
            if let url = URL(string: bookmark.url) {
                appState.browserVM.navigate(to: url)
                appState.isBookmarksPopoverOpen = false
            }
        }
    }
}
