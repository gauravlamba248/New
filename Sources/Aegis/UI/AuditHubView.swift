import SwiftUI

public struct AuditHubView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState, initialTab: Int = 0) {
        self.appState = appState
        if initialTab != appState.selectedAuditTab {
            appState.selectedAuditTab = initialTab
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Logging & Audit Hub")
                        .font(.system(size: 16, weight: .bold))

                    Text("High-speed offline audit trails stored exclusively in local JSON buffers.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Tab Switcher
                Picker("", selection: $appState.selectedAuditTab) {
                    Text("Security & Threat Log (\(appState.threatLogs.count))").tag(0)
                    Text("Session & Activity Log (\(appState.activityLogs.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 380)

                Button(action: {
                    SecurityAuditLogger.shared.clearAllLogs()
                    appState.refreshAllData()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                        Text("Clear Logs")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Strict Privacy Rule Banner
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.shield.fill")
                    .foregroundColor(.purple)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Strict Zero-Trace Privacy Policy Enforced")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.purple)

                    Text("During private browsing and air-gapped sessions, zero navigation history, cache, or telemetry is ever stored or persisted to disk. All ephemeral artifacts are strictly wiped.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 16)

            Divider()

            // Main Log List
            if appState.selectedAuditTab == 0 {
                threatLogList()
            } else {
                activityLogList()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func threatLogList() -> some View {
        Group {
            if appState.threatLogs.isEmpty {
                emptyStateView(icon: "shield.checkered", message: "Zero threats detected.", detail: "The local firewall and network interception layers have not intercepted hostile events.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.threatLogs) { threat in
                            threatRow(threat: threat)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private func activityLogList() -> some View {
        Group {
            if appState.activityLogs.isEmpty {
                emptyStateView(icon: "clock.arrow.circlepath", message: "No standard activity recorded.", detail: "Activity logs only accumulate during non-private sessions. Private mode discards 100% of telemetry.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.activityLogs) { item in
                            activityRow(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private func threatRow(threat: ThreatLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                severityBadge(threat.severity)

                Text(threat.threatType)
                    .font(.system(size: 12, weight: .bold))

                Spacer()

                Text(threat.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 4) {
                Text("Target:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(threat.target)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Text(threat.reason)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack {
                Text("Mitigation:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text(threat.mitigation)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(severityColor(threat.severity).opacity(0.3), lineWidth: 1)
        )
    }

    private func activityRow(item: ActivityLogEntry) -> some View {
        HStack {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.module)
                        .font(.system(size: 12, weight: .bold))
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(item.action)
                        .font(.system(size: 12, weight: .medium))
                }

                if !item.metadata.isEmpty {
                    Text(item.metadata)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(item.timestamp.formatted(date: .omitted, time: .standard))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }

    private func severityBadge(_ severity: ThreatSeverity) -> some View {
        Text(severity.rawValue)
            .font(.system(size: 9, weight: .heavy))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(severityColor(severity).opacity(0.2))
            .foregroundColor(severityColor(severity))
            .cornerRadius(4)
    }

    private func severityColor(_ severity: ThreatSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .warning: return .yellow
        case .info: return .blue
        }
    }

    private func emptyStateView(icon: String, message: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 38))
                .foregroundColor(.secondary.opacity(0.5))
            Text(message)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
