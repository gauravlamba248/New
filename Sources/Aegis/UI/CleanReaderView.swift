import SwiftUI

@MainActor
final class CleanReaderViewState: ObservableObject {
    @Published var fontSize: CGFloat = 15.0
}

public struct CleanReaderView: View {
    let article: CleanedArticle
    let onClose: () -> Void

    @StateObject private var state = CleanReaderViewState()

    public init(article: CleanedArticle, onClose: @escaping () -> Void) {
        self.article = article
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Clean Reader Top Control Bar
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "book.fill")
                        .foregroundColor(.accentColor)
                    Text("Clean Reading Mode")
                        .font(.system(size: 12, weight: .bold))
                }

                Spacer()

                // Typography Controls (A- / A+)
                HStack(spacing: 4) {
                    Button(action: { if state.fontSize > 12 { state.fontSize -= 1 } }) {
                        Text("A-")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 26, height: 22)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: { if state.fontSize < 24 { state.fontSize += 1 } }) {
                        Text("A+")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 26, height: 22)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                Divider().frame(height: 16)

                // Close Button
                Button(action: onClose) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Exit Reader")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Scrollable Article Reader
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Headline
                    Text(article.title)
                        .font(.system(size: state.fontSize + 10, weight: .bold))
                        .lineSpacing(4)
                        .padding(.top, 24)

                    // Byline & Metadata
                    HStack(spacing: 12) {
                        if let author = article.author {
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle.fill")
                                Text(author)
                            }
                        }

                        if let date = article.publicationDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(date)
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text("\(article.estimatedReadingMinutes) min read (\(article.wordCount) words)")
                        }

                        Spacer()
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                    Divider()

                    // Main Article Body
                    Text(article.plainText)
                        .font(.system(size: state.fontSize, design: .serif))
                        .lineSpacing(6)
                        .textSelection(.enabled)

                    // Partial Content Cutoff Notice (Section 10)
                    if article.isPartialContent {
                        VStack(spacing: 8) {
                            Divider()
                            HStack(spacing: 6) {
                                Image(systemName: "lock.shield")
                                    .foregroundColor(.orange)
                                Text("Publicly available content extracted.")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            Text("Access restriction detected. Additional content requires server-side authorization or subscription.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(8)
                        .padding(.top, 16)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, max(24, (NSScreen.main?.frame.width ?? 900) * 0.15))
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }
}
