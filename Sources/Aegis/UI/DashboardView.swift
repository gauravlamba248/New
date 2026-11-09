import SwiftUI

public struct DashboardView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Hero Banner
                HStack(alignment: .center, spacing: 14) {
                    if let iconUrl = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
                       let nsImg = NSImage(contentsOf: iconUrl) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .cornerRadius(10)
                            .shadow(color: Color.accentColor.opacity(0.4), radius: 6, x: 0, y: 2)
                    } else {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Aegis Platform Core")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))

                        Text("Modular Native Engine • Zero Cloud APIs • Real-time Hardware Governance")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Energy & RAM Efficiency Badge
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("LIVE KERNEL SAMPLER")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.green)
                        }

                        Text("RAM: \(String(format: "%.1f", appState.memoryUsageMB)) MB")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.primary)

                        Text("RSS: \(String(format: "%.0f", appState.residentSetSizeMB)) MB • CPU: 0.0%")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 20)

                // Quick Launch Action Cards
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select a Module to Launch")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: 14) {
                        launchCard(
                            title: "Normal Browser",
                            subtitle: "Google search engine with offline ad, tracker, and outbound leak blockers fully active.",
                            icon: "globe",
                            color: .blue,
                            badge: "Default / Google"
                        ) {
                            appState.openBrowser(mode: .normal)
                        }

                        launchCard(
                            title: "Secure Browser",
                            subtitle: "Air-gapped zero-trace browsing via DuckDuckGo. No disk caching, zero history, volatile RAM only.",
                            icon: "lock.shield.fill",
                            color: .purple,
                            badge: "Air-Gapped / Zero-Trace"
                        ) {
                            appState.openBrowser(mode: .secure)
                        }

                        launchCard(
                            title: "Device Desert Vault",
                            subtitle: "Quarantined download containment with stripped POSIX execution bits (chmod 0600).",
                            icon: "lock.trianglebadge.exclamationmark",
                            color: .orange,
                            badge: "\(appState.vaultFiles.count) Quarantined"
                        ) {
                            appState.activeModule = .vault
                        }

                        launchCard(
                            title: "Security Diagnostics",
                            subtitle: "Real-time Mach task resident memory governor, PID inspection, and firewall rules.",
                            icon: "cpu",
                            color: .green,
                            badge: "Memory Governor"
                        ) {
                            appState.activeModule = .diagnostics
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Live Shield Security Telemetry
                VStack(alignment: .leading, spacing: 10) {
                    Text("Live Local Security Telemetry")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        telemetryPill(
                            label: "Trackers Blocked",
                            value: "\(appState.trackersBlocked)",
                            icon: "eye.slash",
                            color: .purple
                        )

                        telemetryPill(
                            label: "Hostile IPs Screened",
                            value: "\(appState.ipsBlocked)",
                            icon: "network.badge.shield.half.filled",
                            color: .orange
                        )

                        telemetryPill(
                            label: "Data Leaks Blocked",
                            value: "\(appState.leaksPrevented)",
                            icon: "antenna.radiowaves.left.and.right.slash",
                            color: .red
                        )

                        telemetryPill(
                            label: "Air-Gap Kill Switch",
                            value: appState.isAirGapped ? "ENFORCED" : "READY",
                            icon: "lock.fill",
                            color: appState.isAirGapped ? .red : .blue
                        )
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .padding(.bottom, 20)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func launchCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        badge: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(color)

                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    Text(badge)
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.15))
                        .foregroundColor(color)
                        .cornerRadius(4)
                }

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack {
                    Text("Open Module")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(color)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(color)
                }
                .padding(.top, 4)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func telemetryPill(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
