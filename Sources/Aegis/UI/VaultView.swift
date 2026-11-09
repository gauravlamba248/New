import SwiftUI

public struct VaultView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with Desert Model explanation
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)

                        Text("Device Desert: Secure Download Vault")
                            .font(.system(size: 16, weight: .bold))
                    }

                    Text("Files in the Desert Vault are completely isolated. All POSIX execution permissions (chmod 0600) are permanently stripped upon arrival, zero network egress is permitted, and Apple Quarantine flags are attached.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(action: {
                    let demoPayload = "Zero-privilege quarantined payload generated at \(Date())".data(using: .utf8)!
                    _ = try? DeviceDesertVault.shared.quarantineData(demoPayload, suggestedFileName: "sample_payload_\(Int(Date().timeIntervalSince1970)).bin", source: "Demo Quarantine")
                    appState.refreshAllData()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.shield")
                        Text("Simulate Vault Quarantine")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(Color.orange.opacity(0.18))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if let status = appState.vaultRetrievalStatus {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(status)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button(action: { appState.vaultRetrievalStatus = nil }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(6)
                .padding(.horizontal, 16)
            }

            Divider()

            // Files Grid / List
            if appState.vaultFiles.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("The Desert Vault is currently empty.")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("Files downloaded during browsing sessions or manually quarantined are stored here without execution rights.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(appState.vaultFiles) { file in
                            vaultFileCard(file: file)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func vaultFileCard(file: QuarantinedFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Image(systemName: "doc.zipper")
                    .font(.system(size: 22))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        Text(file.formattedSize)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)

                        Text("Quarantined: \(file.quarantinedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Security badges
                HStack(spacing: 6) {
                    if file.isExecutableStripped {
                        badgeView(title: "chmod 0600 (-rw-------)", color: .green)
                    }
                    if file.hasQuarantineXattr {
                        badgeView(title: "Gatekeeper xattr", color: .blue)
                    }
                }
            }

            // Low-level Integrity Details
            HStack {
                Text("SHA-256:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                Text(file.sha256)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Action buttons
                HStack(spacing: 8) {
                    Button(action: {
                        DeviceDesertVault.shared.deleteQuarantinedFile(id: file.id)
                        appState.refreshAllData()
                    }) {
                        Text("Delete")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        DeviceDesertVault.shared.retrieveFromVault(file: file) { success in
                            if success {
                                appState.vaultRetrievalStatus = "Successfully retrieved '\(file.name)' to local disk."
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.doc")
                            Text("Retrieve from Vault...")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func badgeView(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
