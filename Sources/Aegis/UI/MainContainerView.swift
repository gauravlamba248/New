import SwiftUI

public struct MainContainerView: View {
    @StateObject private var appState = AppState()

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 750

            VStack(spacing: 0) {
                if isCompact {
                    // Compact header layout for narrow windows
                    compactHeaderView
                    Divider()
                } else if appState.activeModule != .normalBrowser && appState.activeModule != .secureBrowser {
                    // Top Global Control Bar for non-browser views (BrowserView has its own unified toolbar)
                    topGlobalControlBar
                    Divider()
                }

                HStack(spacing: 0) {
                    if !isCompact && appState.isSidebarVisible {
                        // Standard Sidebar with collapsible Browser group
                        NavigationSidebar(appState: appState)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        Divider()
                    }

                    // Dynamic Center Module Content Area
                    VStack(spacing: 0) {
                        contentModuleView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if appState.isBottomBarVisible {
                            Divider()

                            // Persistent Initial Chat / Command Box at bottom
                            CommandBoxView(appState: appState)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 580, minHeight: 480)
        .preferredColorScheme(appState.selectedTheme.colorScheme)
        .background(WindowConfigurator())
    }

    private var topGlobalControlBar: some View {
        HStack(spacing: 8) {
            // 1. Sidebar Toggle Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.isSidebarVisible.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: appState.isSidebarVisible ? "sidebar.left" : "sidebar.leading")
                        .foregroundColor(appState.isSidebarVisible ? .accentColor : .secondary)
                }
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help(appState.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")

            if !appState.isSidebarVisible {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 13, weight: .bold))
                    Text("AEGIS")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                    Text("• \(appState.activeModule.rawValue)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if appState.isTorRunning {
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.torBootstrapProgress >= 100 ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(appState.torBootstrapProgress >= 100 ? "Tor Active" : "Tor: \(appState.torBootstrapProgress)%")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(appState.torBootstrapProgress >= 100 ? .green : .orange)

                    Button(action: {
                        appState.stopTor()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Close Tor")
                                .font(.system(size: 10, weight: .heavy))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Terminate Tor daemon immediately")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.12))
                .cornerRadius(5)
            }

            // 2. Theme Selector Menu (Dark, Light, System)
            Menu {
                ForEach(AppTheme.allCases) { theme in
                    Button(action: { appState.setTheme(theme) }) {
                        HStack {
                            Text(theme.rawValue)
                            if appState.selectedTheme == theme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: appState.selectedTheme.iconName)
                        .font(.system(size: 11))
                    Text(appState.selectedTheme.rawValue)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(5)
            }
            .menuStyle(.borderlessButton)
            .help("Theme Appearance (System Default, Dark Mode, Light Mode)")

            // 4. Bottom Command Box Toggle Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.isBottomBarVisible.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: appState.isBottomBarVisible ? "rectangle.bottomthird.inset.filled" : "rectangle")
                        .font(.system(size: 11))
                        .foregroundColor(appState.isBottomBarVisible ? .accentColor : .secondary)
                    Text("Terminal")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .background(appState.isBottomBarVisible ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                .foregroundColor(appState.isBottomBarVisible ? .accentColor : .secondary)
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help(appState.isBottomBarVisible ? "Hide Bottom Command Box" : "Show Bottom Command Box")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private var contentModuleView: some View {
        switch appState.activeModule {
        case .dashboard:
            DashboardView(appState: appState)
        case .normalBrowser, .secureBrowser:
            BrowserView(appState: appState)
        case .dataCollector:
            DataCollectorView(appState: appState)
        case .gmail, .outlook, .appleMail:
            MailClientView(appState: appState)
        case .llmHub:
            LLMHubView(appState: appState)
        case .llmRunner:
            LLMRunnerView(appState: appState)
        case .vault:
            VaultView(appState: appState)
        case .threatLogs:
            AuditHubView(appState: appState, initialTab: 0)
        case .sessionLogs:
            AuditHubView(appState: appState, initialTab: 1)
        case .diagnostics:
            DiagnosticsView(appState: appState)
        }
    }

    private var compactHeaderView: some View {
        HStack(spacing: 8) {
            Button(action: { appState.toggleSidebar() }) {
                Image(systemName: appState.isSidebarVisible ? "sidebar.left" : "sidebar.leading")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: "shield.checkered")
                .foregroundColor(.accentColor)
                .font(.system(size: 14, weight: .bold))

            Text("AEGIS")
                .font(.system(size: 13, weight: .black, design: .rounded))

            Spacer()

            if appState.isTorRunning {
                Button(action: { appState.stopTor() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                        Text("Close Tor")
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            Picker("", selection: $appState.activeModule) {
                ForEach(ActiveModule.allCases) { mod in
                    Text(mod.rawValue).tag(mod)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 160)

            Circle()
                .fill(appState.isAirGapped ? Color.red : Color.green)
                .frame(width: 8, height: 8)

            Menu {
                ForEach(AppTheme.allCases) { theme in
                    Button(action: { appState.setTheme(theme) }) {
                        Text(theme.rawValue)
                    }
                }
            } label: {
                Image(systemName: appState.selectedTheme.iconName)
                    .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

/// Lightweight AppKit bridge configuring the window backing store for minimum VRAM/RAM consumption
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                // Force standard 8-bit sRGB and opaque surface.
                // Eliminates 16-bit Float Display P3 wide-gamut framebuffer allocation in WindowServer.
                window.colorSpace = .sRGB
                window.isOpaque = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
