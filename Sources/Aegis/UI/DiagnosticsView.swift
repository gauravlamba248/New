import SwiftUI

public struct DiagnosticsView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "cpu")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                    Text("Low-Level macOS Security & Memory Governance")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button("Reclaim Heap Memory") {
                        MemoryGovernor.shared.reclaimIdleMemory()
                        appState.refreshMetricsOnly()
                    }
                    .buttonStyle(.bordered)

                    Button("Refresh Metrics") {
                        appState.refreshMetricsOnly()
                    }
                    .buttonStyle(.borderedProminent)
                }

                // Strict Memory Tier Status Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "gauge.with.needle.fill")
                            .foregroundColor(tierColor)
                            .font(.system(size: 15))

                        Text("Active Memory Tier:")
                            .font(.system(size: 13, weight: .bold))

                        Text(appState.currentMemoryTier.rawValue)
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundColor(tierColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(tierColor.opacity(0.15))
                            .cornerRadius(5)

                        Spacer()

                        Text("Strict Max Limit: 100MB")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    // Memory Progress Bar (Capped at 100MB)
                    GeometryReader { geom in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(tierColor)
                                .frame(width: max(4, min(geom.size.width, geom.size.width * CGFloat(appState.memoryUsageMB / 100.0))), height: 8)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("0 MB")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("15 MB (Idle Budget)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("50 MB (Normal Budget)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100 MB (Hard Max Ceiling)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tierColor.opacity(0.25), lineWidth: 1)
                )

                // Memory Breakdown Explanation Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("macOS Kernel Memory Metrics Explanation")
                            .font(.system(size: 12, weight: .bold))
                    }

                    Text("• **Activity Monitor Physical Footprint (\(String(format: "%.1f", appState.memoryUsageMB)) MB):** The true private physical RAM used by Aegis. Governed to stay < 15MB at idle, < 50MB in normal use, and strictly within 100MB at heavy use.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("• **BSD Resident Set Size (\(String(format: "%.1f", appState.residentSetSizeMB)) MB):** Includes ~75MB of shared read-only dyld library pages (__OBJC_RO, __AUTH_CONST) mapped by macOS for system frameworks. These pages are shared system-wide across all macOS apps.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(8)

                // Metric Cards Grid (Adaptive layout)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                    metricCard(
                        title: "RAM (Physical Footprint)",
                        value: String(format: "%.1f MB", appState.memoryUsageMB),
                        status: memoryStatusText,
                        color: tierColor,
                        icon: "memorychip"
                    )

                    metricCard(
                        title: "Air-Gap Sandbox",
                        value: appState.isAirGapped ? "ENFORCED" : "CONNECTED",
                        status: appState.isAirGapped ? "Zero Egress" : "Firewall Screened",
                        color: appState.isAirGapped ? .red : .blue,
                        icon: "lock.shield"
                    )

                    metricCard(
                        title: "Trackers Blocked",
                        value: "\(appState.trackersBlocked)",
                        status: "Offline Trie Rules",
                        color: .purple,
                        icon: "eye.slash"
                    )

                    metricCard(
                        title: "Hostile IPs Intercepted",
                        value: "\(appState.ipsBlocked)",
                        status: "Bitwise CIDR Subnets",
                        color: .orange,
                        icon: "network.badge.shield.half.filled"
                    )

                    metricCard(
                        title: "Data Leaks Dropped",
                        value: "\(appState.leaksPrevented)",
                        status: "Zero Outbound Leaks",
                        color: .red,
                        icon: "antenna.radiowaves.left.and.right.slash"
                    )
                }

                // Raw System Audit Console
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Subsystem State Report")
                        .font(.system(size: 13, weight: .bold))

                    Text(appState.diagnosticReport)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
            }
            .padding(16)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var memoryStatusText: String {
        if appState.memoryUsageMB < 15.0 {
            return "IDLE (<15MB) OPTIMAL"
        } else if appState.memoryUsageMB < 50.0 {
            return "NORMAL USE (<50MB)"
        } else if appState.memoryUsageMB < 100.0 {
            return "HEAVY USE (<100MB)"
        } else {
            return "CEILING REACHED (PURGING)"
        }
    }

    private var tierColor: Color {
        if appState.memoryUsageMB < 15.0 {
            return .green
        } else if appState.memoryUsageMB < 50.0 {
            return .blue
        } else if appState.memoryUsageMB < 100.0 {
            return .orange
        } else {
            return .red
        }
    }

    private func metricCard(title: String, value: String, status: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
            }

            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.primary)

            Text(status)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
