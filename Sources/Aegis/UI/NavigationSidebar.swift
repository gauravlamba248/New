import SwiftUI

public struct NavigationSidebar: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // App Branding & Architecture Badge
            HStack(spacing: 10) {
                if let iconUrl = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
                   let nsImg = NSImage(contentsOf: iconUrl) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .cornerRadius(6)
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 4, x: 0, y: 1)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("AEGIS")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                    Text("macOS Platform Hub")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.isSidebarVisible = false
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Hide Sidebar")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)

            Divider()
                .padding(.bottom, 6)

            // 1. Home / System Overview (Default screen at launch - 0% WebKit)
            moduleNavButton(
                module: .dashboard,
                title: "System Overview",
                icon: "square.stack.3d.up.fill",
                color: .accentColor
            )

            // 2. Expandable "Browser" Group Accordion
            browserAccordionGroup()

            // 3. Data Collector & Deep Intel Gathering
            moduleNavButton(
                module: .dataCollector,
                title: "Data Collector",
                icon: "square.stack.3d.forward.dottedline.fill",
                color: .teal
            )

            // 4. Expandable "Mail" Group Accordion (Gmail, Outlook, Apple)
            mailAccordionGroup()

            // 4. Expandable "LLM" Group Accordion (LLM Models & Model Runner)
            llmAccordionGroup()

            // 5. Desert Vault
            moduleNavButton(
                module: .vault,
                title: "Desert Vault",
                icon: "lock.trianglebadge.exclamationmark",
                color: .orange,
                badgeCount: appState.vaultFiles.count
            )

            // 4. Expandable "Logs" Group Accordion (Threat Log & Activity Log)
            logsAccordionGroup()

            // 5. Diagnostics Module
            moduleNavButton(
                module: .diagnostics,
                title: "Diagnostics",
                icon: "cpu",
                color: .green
            )

            // 6. Expandable "Defense Shields" with Direct Inline Toggles
            shieldsAccordionGroup()

            Spacer()

            Divider()

            // Theme Appearance Selector (System Default, Dark Mode, Light Mode)
            HStack(spacing: 6) {
                Image(systemName: appState.selectedTheme.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)

                Text("Theme:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Picker("", selection: $appState.selectedTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .font(.system(size: 10))
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            // System Shield Status & Live Memory Pill
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.isAirGapped ? Color.red : Color.green)
                        .frame(width: 7, height: 7)

                    Text(appState.isAirGapped ? "AIR-GAPPED (Strict)" : "FIREWALL (Active)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(appState.isAirGapped ? .red : .green)

                    Spacer()

                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                        Text("LIVE")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundColor(.green)
                    }
                }

                HStack {
                    Text("RAM:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f MB", appState.memoryUsageMB))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(tierSidebarColor)

                    Spacer()

                    Text("RSS: \(Int(appState.residentSetSizeMB))M")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(8)
        }
        .frame(minWidth: 200, maxWidth: 235)
        .background(Color(NSColor.windowBackgroundColor))
    }

    /// Expandable Browser Accordion: Clicking toggles showing/hiding all browser options
    private func browserAccordionGroup() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    appState.isBrowserMenuExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "safari")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 20)
                        .foregroundColor(.accentColor)

                    Text("Browser")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: appState.isBrowserMenuExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9) // Enhanced click area
                .contentShape(Rectangle()) // Entire row is interactive
                .background(isAnyBrowserActive ? Color.accentColor.opacity(0.12) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Sub-options revealed only when expanded
            if appState.isBrowserMenuExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    // Normal Browser (Google + Blockers)
                    Button(action: {
                        appState.openBrowser(mode: .normal)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.system(size: 11))
                                .frame(width: 16)
                            Text("Normal Browser")
                                .font(.system(size: 11, weight: appState.activeModule == .normalBrowser ? .bold : .medium))
                            Spacer()
                            Text("Google")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 26)
                        .padding(.trailing, 10)
                        .padding(.vertical, 7) // Enhanced click area
                        .contentShape(Rectangle())
                        .background(appState.activeModule == .normalBrowser ? Color.accentColor : Color.clear)
                        .foregroundColor(appState.activeModule == .normalBrowser ? .white : .primary)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    // Secure Browser (DuckDuckGo + Air-Gap Zero-Trace)
                    Button(action: {
                        appState.openBrowser(mode: .secure)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 11))
                                .frame(width: 16)
                            Text("Secure Browser")
                                .font(.system(size: 11, weight: appState.activeModule == .secureBrowser ? .bold : .medium))
                            Spacer()
                            Text("Zero-Trace")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(appState.activeModule == .secureBrowser ? .white : .purple)
                        }
                        .padding(.leading, 26)
                        .padding(.trailing, 10)
                        .padding(.vertical, 7) // Enhanced click area
                        .contentShape(Rectangle())
                        .background(appState.activeModule == .secureBrowser ? Color.purple : Color.clear)
                        .foregroundColor(appState.activeModule == .secureBrowser ? .white : .primary)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    // Reset / Initial State action button
                    Button(action: {
                        appState.browserVM.resetToInitialState()
                        appState.addressInputText = ""
                        appState.refreshAllData()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "house")
                                .font(.system(size: 10))
                                .frame(width: 16)
                            Text("Initial State")
                                .font(.system(size: 10, weight: .medium))
                            Spacer()
                        }
                        .padding(.leading, 26)
                        .padding(.trailing, 10)
                        .padding(.vertical, 6) // Enhanced click area
                        .contentShape(Rectangle())
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reset browser to clean empty state and immediately free RAM")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var isAnyMailActive: Bool {
        appState.activeModule == .gmail || appState.activeModule == .outlook || appState.activeModule == .appleMail
    }

    /// Expandable Mail Accordion: Groups Gmail, Outlook, and Apple Mail
    private func mailAccordionGroup() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    appState.isMailMenuExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 20)
                        .foregroundColor(.blue)

                    Text("Mail")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    let totalUnread = MailManager.shared.messages.filter { !$0.isRead }.count
                    if totalUnread > 0 {
                        Text("\(totalUnread)")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    Image(systemName: appState.isMailMenuExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
                .background(isAnyMailActive ? Color.blue.opacity(0.12) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Sub-options revealed when expanded: Gmail, Outlook, Apple Mail
            if appState.isMailMenuExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    // 1. Gmail
                    mailProviderNavButton(
                        provider: .gmail,
                        module: .gmail,
                        title: "Gmail",
                        icon: "envelope.fill",
                        color: .red
                    )

                    // 2. Outlook
                    mailProviderNavButton(
                        provider: .outlook,
                        module: .outlook,
                        title: "Outlook",
                        icon: "tray.full.fill",
                        color: .blue
                    )

                    // 3. Apple Mail
                    mailProviderNavButton(
                        provider: .apple,
                        module: .appleMail,
                        title: "Apple Mail",
                        icon: "applelogo",
                        color: .primary
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func mailProviderNavButton(
        provider: MailProvider,
        module: ActiveModule,
        title: String,
        icon: String,
        color: Color
    ) -> some View {
        let isSelected = appState.activeModule == module
        let unread = MailManager.shared.messages.filter { msg in
            let accs = MailManager.shared.accounts.filter { $0.provider == provider }
            return accs.contains { $0.id == msg.accountId } && !msg.isRead
        }.count

        return Button(action: {
            MailManager.shared.selectedProvider = provider
            appState.activeModule = module
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 16)
                    .foregroundColor(isSelected ? .white : color)

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))

                Spacer()

                if unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.3) : color.opacity(0.2))
                        .foregroundColor(isSelected ? .white : color)
                        .cornerRadius(6)
                }
            }
            .padding(.leading, 26)
            .padding(.trailing, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(isSelected ? (color == .primary ? Color.secondary.opacity(0.3) : color) : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }

    private var isAnyLLMActive: Bool {
        appState.activeModule == .llmHub || appState.activeModule == .llmRunner
    }

    /// Expandable LLM Accordion: Groups LLM Models (Hub & Downloads) and Model Runner (Local in-app runner)
    private func llmAccordionGroup() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    appState.isLLMMenuExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 20)
                        .foregroundColor(.purple)

                    Text("LLM")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    let downloadedCount = LLMManager.shared.downloadedModels.count
                    if downloadedCount > 0 {
                        Text("\(downloadedCount)")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(8)
                    }

                    Image(systemName: appState.isLLMMenuExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
                .background(isAnyLLMActive ? Color.purple.opacity(0.12) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            if appState.isLLMMenuExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    // LLM Models (Model Hub / Downloads)
                    Button(action: {
                        appState.openLLMHub()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 11))
                                .frame(width: 16)
                            Text("LLM Models")
                                .font(.system(size: 11, weight: appState.activeModule == .llmHub ? .bold : .medium))
                            Spacer()
                            Text("Hub")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 26)
                        .padding(.trailing, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .background(appState.activeModule == .llmHub ? Color.purple : Color.clear)
                        .foregroundColor(appState.activeModule == .llmHub ? .white : .primary)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    // Model Runner (Local In-App Runner)
                    Button(action: {
                        appState.openLLMRunner()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 11))
                                .frame(width: 16)
                            Text("Model Runner")
                                .font(.system(size: 11, weight: appState.activeModule == .llmRunner ? .bold : .medium))
                            Spacer()
                            Text("Local")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 26)
                        .padding(.trailing, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .background(appState.activeModule == .llmRunner ? Color.purple : Color.clear)
                        .foregroundColor(appState.activeModule == .llmRunner ? .white : .primary)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 2)
            }
        }
    }

    /// Expandable Logs Accordion: Keeps Threat Log and Activity Log neatly hidden until expanded
    private func logsAccordionGroup() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    appState.isLogsMenuExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 20)
                        .foregroundColor(.red)

                    Text("Logs")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    if !appState.threatLogs.isEmpty {
                        badgeText("\(appState.threatLogs.count)", isSelected: false, color: .red)
                    }

                    Image(systemName: appState.isLogsMenuExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9) // Enhanced click area
                .contentShape(Rectangle())
                .background(isAnyLogActive ? Color.secondary.opacity(0.12) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Sub-options revealed only when expanded
            if appState.isLogsMenuExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    // Threat Log sub-button
                    Button(action: {
                        appState.activeModule = .threatLogs
                        appState.selectedAuditTab = 0
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.shield")
                                .font(.system(size: 11))
                                .frame(width: 16)
                            Text("Threat Log")
                                .font(.system(size: 11, weight: appState.activeModule == .threatLogs ? .bold : .medium))
                            Spacer()
                            if !appState.threatLogs.isEmpty {
                                badgeText("\(appState.threatLogs.count)", isSelected: appState.activeModule == .threatLogs, color: .red)
                            }
                        }
                        .padding(.leading, 26)
                        .padding(.trailing, 10)
                        .padding(.vertical, 7) // Enhanced click area
                        .contentShape(Rectangle())
                        .background(appState.activeModule == .threatLogs ? Color.red : Color.clear)
                        .foregroundColor(appState.activeModule == .threatLogs ? .white : .primary)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    // Activity Log sub-button
                    Button(action: {
                        appState.activeModule = .sessionLogs
                        appState.selectedAuditTab = 1
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 11))
                                .frame(width: 16)
                            Text("Activity Log")
                                .font(.system(size: 11, weight: appState.activeModule == .sessionLogs ? .bold : .medium))
                            Spacer()
                            if !appState.activityLogs.isEmpty {
                                badgeText("\(appState.activityLogs.count)", isSelected: appState.activeModule == .sessionLogs, color: .blue)
                            }
                        }
                        .padding(.leading, 26)
                        .padding(.trailing, 10)
                        .padding(.vertical, 7) // Enhanced click area
                        .contentShape(Rectangle())
                        .background(appState.activeModule == .sessionLogs ? Color.blue : Color.clear)
                        .foregroundColor(appState.activeModule == .sessionLogs ? .white : .primary)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Expandable Defense Shields Accordion with direct inline toggles
    private func shieldsAccordionGroup() -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    appState.isShieldsMenuExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: (appState.isAdTrackerBlockerEnabled && appState.isIPBlockerEnabled && appState.isLeakBlockerEnabled) ? "shield.fill" : "shield.lefthalf.filled")
                        .foregroundColor((appState.isAdTrackerBlockerEnabled && appState.isIPBlockerEnabled && appState.isLeakBlockerEnabled) ? .green : .orange)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 18)

                    Text("Defense Shields")
                        .font(.system(size: 12, weight: .semibold))

                    Spacer()

                    let activeCount = (appState.isAdTrackerBlockerEnabled ? 1 : 0) +
                                      (appState.isIPBlockerEnabled ? 1 : 0) +
                                      (appState.isLeakBlockerEnabled ? 1 : 0) +
                                      (appState.isISPCloakEnabled ? 1 : 0)

                    Text("\(activeCount)/4")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(3)

                    Image(systemName: appState.isShieldsMenuExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if appState.isShieldsMenuExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // 1. Ad Blocker
                    Toggle(isOn: Binding(
                        get: { appState.isAdTrackerBlockerEnabled },
                        set: { appState.setAdTrackerBlockerEnabled($0) }
                    )) {
                        Text("Ad & Tracker")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                    // 2. IP Blocker
                    Toggle(isOn: Binding(
                        get: { appState.isIPBlockerEnabled },
                        set: { appState.setIPBlockerEnabled($0) }
                    )) {
                        Text("Hostile IP")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                    // 3. Leak Blocker
                    Toggle(isOn: Binding(
                        get: { appState.isLeakBlockerEnabled },
                        set: { appState.setLeakBlockerEnabled($0) }
                    )) {
                        Text("Leak & Port")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                    // 4. ISP Cloak Tunnel (Option A) - Only appears in Secure Browser; hidden in Normal Browser
                    if appState.browserVM.browserMode == .secure {
                        Toggle(isOn: Binding(
                            get: { appState.isISPCloakEnabled },
                            set: { appState.setISPCloakEnabled($0) }
                        )) {
                            HStack(spacing: 4) {
                                Text("ISP Cloak")
                                    .font(.system(size: 11, weight: .medium))
                                if appState.isISPCloakEnabled {
                                    Text("CLOAKED")
                                        .font(.system(size: 7, weight: .heavy))
                                        .padding(.horizontal, 3)
                                        .padding(.vertical, 1)
                                        .background(Color.purple.opacity(0.2))
                                        .foregroundColor(.purple)
                                        .cornerRadius(2)
                                }
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.mini)

                        if appState.isISPCloakEnabled {
                            VStack(alignment: .leading, spacing: 4) {
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
                                .controlSize(.mini)

                                if appState.selectedCloakPresetId == "tor_local" {
                                    if !appState.isTorRunning {
                                        Button(action: {
                                            appState.startTor()
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 8))
                                                Text("Run Tor")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 3)
                                            .background(Color.purple)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack {
                                                Circle()
                                                    .fill(appState.torBootstrapProgress >= 100 ? Color.green : Color.orange)
                                                .frame(width: 5, height: 5)
                                                Text(appState.torBootstrapProgress >= 100 ? "Tor Connected" : "Tor: \(appState.torBootstrapProgress)%")
                                                    .font(.system(size: 9, weight: .semibold))
                                                    .foregroundColor(appState.torBootstrapProgress >= 100 ? .green : .orange)
                                            }

                                            Button(action: {
                                                appState.stopTor()
                                            }) {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 8))
                                                    Text("Stop Tor")
                                                        .font(.system(size: 9, weight: .bold))
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 2)
                                                .background(Color.red.opacity(0.15))
                                                .foregroundColor(.red)
                                                .cornerRadius(3)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding(5)
                            .background(Color.purple.opacity(0.08))
                            .cornerRadius(5)
                            .padding(.vertical, 2)
                        }
                    }

                    // 5. Air-Gap
                    Toggle(isOn: Binding(
                        get: { appState.isAirGapped },
                        set: { appState.setAirGapEnabled($0) }
                    )) {
                        Text("Air-Gap Isolation")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(appState.isAirGapped ? .red : .primary)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
                .padding(.leading, 26)
                .padding(.trailing, 12)
                .padding(.vertical, 4)
            }
        }
    }

    private var isAnyBrowserActive: Bool {
        appState.activeModule == .normalBrowser || appState.activeModule == .secureBrowser
    }

    private var isAnyLogActive: Bool {
        appState.activeModule == .threatLogs || appState.activeModule == .sessionLogs
    }

    private func moduleNavButton(
        module: ActiveModule,
        title: String,
        icon: String,
        color: Color,
        badgeCount: Int? = nil
    ) -> some View {
        Button(action: {
            appState.activeModule = module
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 20)
                    .foregroundColor(appState.activeModule == module ? .white : color)

                Text(title)
                    .font(.system(size: 12, weight: appState.activeModule == module ? .bold : .medium))
                    .foregroundColor(appState.activeModule == module ? .white : .primary)

                Spacer()

                if let count = badgeCount, count > 0 {
                    badgeText("\(count)", isSelected: appState.activeModule == module, color: color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9) // Enhanced click area (comfortable touch/click targets)
            .contentShape(Rectangle()) // Ensures entire row width is clickable
            .background(appState.activeModule == module ? Color.accentColor : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func badgeText(_ text: String, isSelected: Bool, color: Color = .accentColor) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(isSelected ? Color.white.opacity(0.25) : color.opacity(0.2))
            .foregroundColor(isSelected ? .white : color)
            .cornerRadius(8)
    }

    private var tierSidebarColor: Color {
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
}
