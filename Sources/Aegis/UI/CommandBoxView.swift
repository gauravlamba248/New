import SwiftUI

public struct CommandBoxView: View {
    @ObservedObject var appState: AppState

    private let suggestionPills: [String] = [
        "Search Google: swift concurrency",
        "Initial state",
        "Open apple.com",
        "Search privately: zero day",
        "Enable air gap",
        "Inspect desert vault",
        "Block IP 185.220.101.5",
        "Show threat logs"
    ]

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Intent Router Feedback Badge (if available)
            if let resolution = appState.lastResolution {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.badge.shield.half.filled")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 11, weight: .semibold))

                    Text("Offline Intent:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    Text(resolution.explanation)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 4)

                    Text(String(format: "%.0f%% Match", resolution.confidence * 100))
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                .cornerRadius(6)
            }

            // Command Input Box with comfortable click targets
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))

                TextField("Enter local command or web request (e.g., 'search swift', 'open github.com', 'initial state')...", text: $appState.commandInputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .onSubmit {
                        submitCommand()
                    }

                if !appState.commandInputText.isEmpty {
                    Button(action: { appState.commandInputText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .padding(4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Button(action: submitCommand) {
                    HStack(spacing: 4) {
                        Text("Execute")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "return")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7) // Slightly increased click target
                    .contentShape(Rectangle())
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(appState.commandInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                // Hide / Collapse Bottom Bar Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.isBottomBarVisible = false
                    }
                }) {
                    Image(systemName: "chevron.down.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Hide bottom command bar (can be toggled from top bar anytime)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )

            // Dynamic wrapping suggestion pills using flexible layout with increased click target
            ViewThatFits(in: .horizontal) {
                // Expanded view with all suggestions
                HStack(spacing: 6) {
                    ForEach(suggestionPills, id: \.self) { pill in
                        pillButton(text: pill)
                    }
                }

                // Compact view with fewer suggestions
                HStack(spacing: 6) {
                    ForEach(suggestionPills.prefix(4), id: \.self) { pill in
                        pillButton(text: pill)
                    }
                }

                // Ultra compact view
                HStack(spacing: 6) {
                    ForEach(suggestionPills.prefix(2), id: \.self) { pill in
                        pillButton(text: pill)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func pillButton(text: String) -> some View {
        Button(action: {
            appState.commandInputText = text
            submitCommand()
        }) {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5) // Slightly increased click area
                .contentShape(Rectangle())
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func submitCommand() {
        let cmd = appState.commandInputText
        appState.executeCommand(cmd)
    }
}
