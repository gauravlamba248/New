import SwiftUI

public struct BypassWallStatusPopover: View {
    @ObservedObject var manager: BypassWallManager

    public init(manager: BypassWallManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: manager.buttonState.iconName)
                    .foregroundColor(manager.buttonState.badgeColor)
                    .font(.system(size: 16, weight: .bold))

                Text("Bypass Wall — Diagnostic Report")
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                Button(action: { manager.isStatusPopoverOpen = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }

            Divider()

            if let res = manager.lastResult {
                VStack(alignment: .leading, spacing: 8) {
                    // Status row
                    HStack(alignment: .top, spacing: 6) {
                        Text("Status:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(res.status)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(res.isRefusal ? .red : .primary)
                    }

                    // Action row
                    HStack(alignment: .top, spacing: 6) {
                        Text("Action:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(res.actionTaken)
                            .font(.system(size: 11))
                    }

                    // Content Source row
                    HStack(alignment: .top, spacing: 6) {
                        Text("Content:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(res.contentSource)
                            .font(.system(size: 11))
                    }

                    // Security Affirmation
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Security & Access Control:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Text(res.securityAffirmation)
                            .font(.system(size: 11))
                            .foregroundColor(res.isRefusal ? .red : .green)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(res.isRefusal ? Color.red.opacity(0.08) : Color.green.opacity(0.08))
                            .cornerRadius(6)
                    }
                }
            } else {
                Text("Analyzing webpage structure...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            if manager.activeCleanedArticle != nil {
                Divider()
                HStack {
                    Button(action: {
                        manager.isCleanReaderActive.toggle()
                        manager.isStatusPopoverOpen = false
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: manager.isCleanReaderActive ? "doc.plaintext" : "book.fill")
                            Text(manager.isCleanReaderActive ? "Hide Clean Reader" : "Open Clean Reading View")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
