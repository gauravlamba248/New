import SwiftUI

/// Popover panel presenting individual on/off controls for every security blocker.
public struct ShieldsPopoverView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14, weight: .bold))

                Text("Aegis Defense Shields")
                    .font(.system(size: 13, weight: .heavy))

                Spacer()

                let activeCount = (appState.isAdTrackerBlockerEnabled ? 1 : 0) +
                                  (appState.isIPBlockerEnabled ? 1 : 0) +
                                  (appState.isLeakBlockerEnabled ? 1 : 0)

                Text("\(activeCount)/3 Active")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(activeCount == 3 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundColor(activeCount == 3 ? .green : .orange)
                    .cornerRadius(4)
            }

            Divider()

            // 1. Ad & Tracker Blocker
            Toggle(isOn: Binding(
                get: { appState.isAdTrackerBlockerEnabled },
                set: { appState.setAdTrackerBlockerEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ad & Tracker Blocker")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Strips tracking scripts and telemetry domains")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            // 2. Malicious IP Blocker
            Toggle(isOn: Binding(
                get: { appState.isIPBlockerEnabled },
                set: { appState.setIPBlockerEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hostile IP & CIDR Blocker")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Filters malicious subnets, bogons, and C2 ranges")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            // 3. Outbound Leak Blocker
            Toggle(isOn: Binding(
                get: { appState.isLeakBlockerEnabled },
                set: { appState.setLeakBlockerEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Outbound Leak & Port Blocker")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Intercepts backdoor ports and DNS tunneling")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            // 4. Native In-App Encrypted Proxy (ISP Cloak) - Only appears in Secure Browser; hidden in Normal Browser
            if appState.browserVM.browserMode == .secure {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: Binding(
                        get: { appState.isISPCloakEnabled },
                        set: { appState.setISPCloakEnabled($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("ISP Cloak Tunnel")
                                    .font(.system(size: 12, weight: .bold))
                                if appState.isISPCloakEnabled {
                                    Text("BLINDFOLDED")
                                        .font(.system(size: 8, weight: .heavy))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.purple.opacity(0.2))
                                        .foregroundColor(.purple)
                                        .cornerRadius(3)
                                }
                            }
                            Text("Hides visited websites from ISP via encrypted tunnel")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    if appState.isISPCloakEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Tunnel:")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)

                                Picker("", selection: Binding(
                                    get: { appState.selectedCloakPresetId },
                                    set: { newId in
                                        if let match = ISPCloakManager.availablePresets.first(where: { $0.id == newId }) {
                                            appState.selectCloakPreset(match)
                                        }
                                    }
                                )) {
                                    ForEach(ISPCloakManager.availablePresets) { preset in
                                        Text(preset.name).tag(preset.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .controlSize(.small)
                            }

                            Text("Target: \(ISPCloakManager.shared.proxyHost):\(ISPCloakManager.shared.proxyPort) (\(ISPCloakManager.shared.proxyType.rawValue))")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)

                            // If Tor SOCKS5 Loopback is selected, reveal the "Run Tor" controller
                            if appState.selectedCloakPresetId == "tor_local" {
                                VStack(alignment: .leading, spacing: 6) {
                                    if !appState.isTorRunning {
                                        Button(action: {
                                            appState.startTor()
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 10))
                                                Text("Run Tor")
                                                    .font(.system(size: 11, weight: .bold))
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                            .background(Color.purple)
                                            .foregroundColor(.white)
                                            .cornerRadius(5)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Launch embedded Tor onion routing daemon on 127.0.0.1:9050")
                                    } else {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Circle()
                                                    .fill(appState.torBootstrapProgress >= 100 ? Color.green : Color.orange)
                                                    .frame(width: 7, height: 7)

                                                Text(appState.torStatusMessage)
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(appState.torBootstrapProgress >= 100 ? .green : .orange)

                                                Spacer()

                                                if appState.torBootstrapProgress < 100 {
                                                    Text("\(appState.torBootstrapProgress)%")
                                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                        .foregroundColor(.orange)
                                                }
                                            }

                                            if appState.torBootstrapProgress < 100 {
                                                ProgressView(value: Double(appState.torBootstrapProgress), total: 100)
                                                    .progressViewStyle(.linear)
                                                    .scaleEffect(x: 1, y: 0.6, anchor: .center)
                                            }

                                            Button(action: {
                                                appState.stopTor()
                                            }) {
                                                HStack(spacing: 5) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 10))
                                                    Text("Stop Tor")
                                                        .font(.system(size: 10, weight: .bold))
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 4)
                                                .background(Color.red.opacity(0.15))
                                                .foregroundColor(.red)
                                                .cornerRadius(4)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .help("Terminate Tor daemon immediately")
                                        }
                                        .padding(6)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(6)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(8)
                        .background(Color.purple.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
            }

            Divider()

            // 5. Strict Air-Gap Isolation
            Toggle(isOn: Binding(
                get: { appState.isAirGapped },
                set: { appState.setAirGapEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Air-Gap Isolation")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(appState.isAirGapped ? .red : .primary)
                        if appState.isAirGapped {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.red)
                        }
                    }
                    Text("Complete zero-egress hardware kill switch")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
        .padding(14)
        .frame(width: 310)
    }
}
