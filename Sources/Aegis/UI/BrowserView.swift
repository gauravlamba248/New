import SwiftUI

public struct BrowserView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var browserVM: SecureWebViewModel

    public init(appState: AppState) {
        self.appState = appState
        self.browserVM = appState.browserVM
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Sleek macOS Multi-Tab Strip
            tabStripView
            Divider()

            // 2. Responsive Browser Navigation Bar
            navigationBarView

            // 3. Compact Bookmarks Bar (Toggleable)
            if appState.isBookmarksBarVisible {
                Divider()
                bookmarksBarView
            }

            Divider()

            // 4. Main Content Area with isolated WebKit rendering
            ZStack {
                if browserVM.isSessionActive {
                    SecureWebView(viewModel: browserVM)
                        .id(browserVM.id)
                } else {
                    initialEmptyStateView
                }

                if let threatMessage = browserVM.blockedThreatMessage {
                    threatOverlayView(message: threatMessage)
                }

                // Clean Reading Mode (Bypass Wall Output)
                if browserVM.bypassWallManager.isCleanReaderActive, let article = browserVM.bypassWallManager.activeCleanedArticle {
                    CleanReaderView(article: article) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            browserVM.bypassWallManager.closeCleanReader()
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .onReceive(browserVM.$currentURLString) { newURL in
            if !newURL.isEmpty {
                self.appState.addressInputText = newURL
            }
        }
    }

    // MARK: - Multi-Tab Strip
    private var tabStripView: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(appState.tabs) { tab in
                        tabItemView(tab: tab)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
                .padding(.bottom, 2)
            }

            // New Tab (+) Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    appState.openNewTab()
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Open New Tab (⌘T)")
            .padding(.trailing, 8)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }

    private func tabItemView(tab: BrowserTab) -> some View {
        let isActive = appState.activeTabId == tab.id

        return HStack(spacing: 4) {
            // Tab Selection Button (Title, Icon, Loading Indicator)
            Button(action: {
                appState.selectTab(id: tab.id)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: tab.viewModel.browserMode == .secure ? "lock.shield.fill" : "globe")
                        .foregroundColor(tab.viewModel.browserMode == .secure ? .purple : .accentColor)
                        .font(.system(size: 10))

                    Text(tab.title)
                        .font(.system(size: 11, weight: isActive ? .bold : .medium))
                        .foregroundColor(isActive ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 130, alignment: .leading)

                    if tab.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 3)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Independent Close Tab Button (Cross) - Guaranteed zero gesture interference
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    appState.closeTab(id: tab.id)
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Circle())
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 5)
            .help("Close Tab (⌘W)")
        }
        .background(isActive ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Navigation Bar
    private var navigationBarView: some View {
        HStack(spacing: 8) {
            // Sidebar Toggle Button
            Button(action: { appState.toggleSidebar() }) {
                Image(systemName: appState.isSidebarVisible ? "sidebar.left" : "sidebar.leading")
                    .font(.system(size: 12))
                    .foregroundColor(appState.isSidebarVisible ? .accentColor : .secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help(appState.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")

            // Navigation controls (Back, Forward, Reload, Initial State)
            HStack(spacing: 4) {
                Button(action: { browserVM.goBack() }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 24, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!browserVM.canGoBack || !browserVM.isSessionActive)
                .help("Previous page")

                Button(action: { browserVM.goForward() }) {
                    Image(systemName: "chevron.right")
                        .frame(width: 24, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!browserVM.canGoForward || !browserVM.isSessionActive)
                .help("Next page")

                Button(action: { browserVM.reload() }) {
                    Image(systemName: browserVM.isLoading ? "xmark" : "arrow.clockwise")
                        .frame(width: 24, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!browserVM.isSessionActive)
                .help("Reload page")

                // Initial State / Reset Button (resets session & frees memory)
                Button(action: {
                    browserVM.resetToInitialState()
                    appState.addressInputText = ""
                    appState.refreshAllData()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill")
                        Text("Initial State")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Reset immediately to empty initial state & free memory (<15MB)")
            }
            .font(.system(size: 12, weight: .medium))

            // Omnibox / Address bar
            HStack(spacing: 6) {
                Image(systemName: browserVM.browserMode == .secure ? "lock.shield.fill" : "globe")
                    .foregroundColor(browserVM.browserMode == .secure ? .purple : .accentColor)
                    .font(.system(size: 12))

                TextField(
                    browserVM.browserMode == .normal ? "Search Google or enter address..." : "Search DuckDuckGo (Zero-Trace) or enter address...",
                    text: $appState.addressInputText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .onSubmit {
                    let text = appState.addressInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        if text.contains("://") || text.contains(".") {
                            appState.executeCommand("open " + text)
                        } else {
                            appState.executeCommand("search " + text)
                        }
                    }
                }

                // Bookmark Star Button inside Omnibox
                Button(action: {
                    appState.toggleCurrentBookmark()
                }) {
                    Image(systemName: appState.isCurrentPageBookmarked() ? "star.fill" : "star")
                        .foregroundColor(appState.isCurrentPageBookmarked() ? .yellow : .secondary)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help(appState.isCurrentPageBookmarked() ? "Remove Bookmark" : "Bookmark this Page")

                if browserVM.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )

            // Bookmarks Hub Button
            Button(action: {
                appState.isBookmarksPopoverOpen.toggle()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 11))
                    Text("Bookmarks")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $appState.isBookmarksPopoverOpen, arrowEdge: .bottom) {
                BookmarksPopoverView(appState: appState)
            }
            .help("View and manage saved Bookmarks")

            // Bookmarks Bar Toggle Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    appState.isBookmarksBarVisible.toggle()
                }
            }) {
                Image(systemName: appState.isBookmarksBarVisible ? "star.square.fill" : "star.square")
                    .foregroundColor(appState.isBookmarksBarVisible ? .yellow : .secondary)
                    .font(.system(size: 11))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help(appState.isBookmarksBarVisible ? "Hide Bookmarks Bar" : "Show Bookmarks Bar")

            // Dynamic [ Bypass Wall ] Button
            Button(action: {
                Task {
                    await browserVM.bypassWallManager.triggerBypassAction(webView: browserVM.webView, url: browserVM.webView?.url)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: browserVM.bypassWallManager.buttonState.iconName)
                        .foregroundColor(browserVM.bypassWallManager.buttonState.badgeColor)
                        .font(.system(size: 11))

                    Text(browserVM.bypassWallManager.buttonState.title)
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
                .background(browserVM.bypassWallManager.buttonState == .wallDetected || browserVM.bypassWallManager.buttonState == .contentAvailable ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $browserVM.bypassWallManager.isStatusPopoverOpen, arrowEdge: .bottom) {
                BypassWallStatusPopover(manager: browserVM.bypassWallManager)
            }
            .help("Bypass presentation overlays and open clean reading view (does not bypass paywalls/auth)")

            // Air-Gap Status Indicator
            if appState.isAirGapped {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    Text("AIR-GAP")
                        .font(.system(size: 9, weight: .heavy))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.18))
                .foregroundColor(.red)
                .cornerRadius(4)
            }

            // ISP Cloak Status Indicator (Option A Active in Secure Browser)
            if browserVM.browserMode == .secure && appState.isISPCloakEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 9))
                    Text("CLOAKED")
                        .font(.system(size: 9, weight: .heavy))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.18))
                .foregroundColor(.purple)
                .cornerRadius(4)
                .help("ISP Cloak Active: All requests encrypted through SOCKS5 tunnel. Your ISP cannot see any website you visit.")
            }

            // Dynamic Top Bar Tor Controller ("Close Tor")
            if appState.isTorRunning {
                HStack(spacing: 6) {
                    if appState.torBootstrapProgress < 100 {
                        ProgressView()
                            .scaleEffect(0.55)
                            .frame(width: 12, height: 12)
                        Text("\(appState.torBootstrapProgress)%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    } else {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("TOR")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.green)
                    }

                    Button(action: {
                        appState.stopTor()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Close Tor")
                                .font(.system(size: 11, weight: .heavy))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Terminate Tor daemon completely and close network tunnel")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.purple.opacity(0.15))
                .cornerRadius(5)
            }

            // Individual Shields / Blockers Button with Popover
            Button(action: {
                appState.isBrowserShieldsOpen.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: (appState.isAdTrackerBlockerEnabled && appState.isIPBlockerEnabled && appState.isLeakBlockerEnabled) ? "shield.fill" : "shield.lefthalf.filled")
                        .foregroundColor((appState.isAdTrackerBlockerEnabled && appState.isIPBlockerEnabled && appState.isLeakBlockerEnabled) ? .green : .orange)
                        .font(.system(size: 11))
                    Text("Shields")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $appState.isBrowserShieldsOpen, arrowEdge: .bottom) {
                ShieldsPopoverView(appState: appState)
            }
            .help("Individual Blocker Controls (Ad Blocker, IP Blocker, Leak Blocker, Air-Gap)")

            // Mode Dropdown (Normal Google vs Secure Zero-Trace)
            Menu {
                Button(action: {
                    browserVM.setBrowserMode(.normal)
                    appState.activeModule = .normalBrowser
                }) {
                    Label("Normal (Google Search + Blockers)", systemImage: "globe")
                }
                Button(action: {
                    browserVM.setBrowserMode(.secure)
                    appState.activeModule = .secureBrowser
                }) {
                    Label("Secure (Zero-Trace DuckDuckGo)", systemImage: "lock.shield.fill")
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: browserVM.browserMode == .secure ? "lock.shield.fill" : "globe")
                        .foregroundColor(browserVM.browserMode == .secure ? .purple : .accentColor)
                        .font(.system(size: 11))

                    Text(browserVM.browserMode == .normal ? "Google" : "Zero-Trace")
                        .font(.system(size: 11, weight: .bold))

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(browserVM.browserMode == .secure ? Color.purple.opacity(0.15) : Color.accentColor.opacity(0.12))
                .cornerRadius(5)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Click to switch search engine: Google vs Zero-Trace DuckDuckGo")

            // Terminal / Bottom Bar Toggle Button
            Button(action: { appState.toggleBottomBar() }) {
                Image(systemName: appState.isBottomBarVisible ? "rectangle.bottomthird.inset.filled" : "rectangle")
                    .font(.system(size: 11))
                    .foregroundColor(appState.isBottomBarVisible ? .accentColor : .secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help(appState.isBottomBarVisible ? "Hide Terminal" : "Show Terminal")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Bookmarks Bar
    private var bookmarksBarView: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 9))
                .padding(.leading, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(BookmarkManager.shared.bookmarks) { bookmark in
                        Button(action: {
                            if let url = URL(string: bookmark.url) {
                                browserVM.navigate(to: url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                Text(bookmark.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Open in Active Tab") {
                                if let url = URL(string: bookmark.url) {
                                    browserVM.navigate(to: url)
                                }
                            }
                            Button("Open in New Tab") {
                                if let url = URL(string: bookmark.url) {
                                    appState.openNewTab(url: url)
                                }
                            }
                            Divider()
                            Button("Delete Bookmark", role: .destructive) {
                                BookmarkManager.shared.removeBookmark(id: bookmark.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 3)
            }

            Spacer()
        }
        .frame(height: 24)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }

    // MARK: - Initial Empty State
    private var initialEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: browserVM.browserMode == .normal ? "globe.americas.fill" : "lock.shield.fill")
                .font(.system(size: 44))
                .foregroundColor(browserVM.browserMode == .normal ? .blue : .purple)

            VStack(spacing: 5) {
                Text(browserVM.browserMode == .normal ? "Normal Browser (Google + Security Blockers)" : "Secure Browser (Air-Gapped Zero-Trace)")
                    .font(.system(size: 15, weight: .bold))

                Text(
                    browserVM.browserMode == .normal
                        ? "Normal browser continues by default through Google search. Ad & Tracker Blocker, Malicious IP Filter, and Outbound Leak Blocker are continuously active."
                        : "Secure browser isolates the session with zero disk cookies, zero history, zero cache, and DuckDuckGo search. Egress is permanently trapped."
                )
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
            }

            // Quick Access Bookmarks Grid
            VStack(alignment: .leading, spacing: 8) {
                Text("FAVORITES & BOOKMARKS")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    quickNavButton(title: "DuckDuckGo", urlString: "https://html.duckduckgo.com")
                    quickNavButton(title: "Google", urlString: "https://www.google.com")
                    quickNavButton(title: "GitHub", urlString: "https://github.com")
                    quickNavButton(title: "Apple Dev", urlString: "https://developer.apple.com")
                }
            }
            .padding(.top, 4)

            // Quick search action pills
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    quickSearchButton(title: "Search Google: Swift Concurrency", query: "Swift Concurrency macOS")
                    quickSearchButton(title: "Search Google: Apple Silicon Architecture", query: "Apple Silicon Architecture")
                }

                // Mode toggle shortcut button
                Button(action: {
                    let newMode: BrowserMode = (browserVM.browserMode == .normal) ? .secure : .normal
                    browserVM.setBrowserMode(newMode)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(browserVM.browserMode == .normal ? "Switch to Secure Browser (Zero-Trace)" : "Switch to Normal Browser (Google)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // Memory guarantee notice
            HStack(spacing: 5) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 10))
                Text("Idle memory footprint: < 15MB. Click 'Initial State' or 'Close Tab' at any time to free memory.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func quickSearchButton(title: String, query: String) -> some View {
        Button(action: {
            appState.executeCommand("search " + query)
        }) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func quickNavButton(title: String, urlString: String) -> some View {
        Button(action: {
            appState.executeCommand("open " + urlString)
        }) {
            HStack(spacing: 5) {
                Image(systemName: "link")
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func threatOverlayView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Connection Intercepted & Neutralized")
                .font(.system(size: 18, weight: .bold))

            Text(message)
                .font(.system(size: 13, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .foregroundColor(.secondary)

            Text("The local security firewall prevented data egress. Blockers are strictly active across both Normal and Secure browsing modes.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 12) {
                Button(action: {
                    browserVM.resetToInitialState()
                    appState.addressInputText = ""
                }) {
                    Text("Return to Initial State")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: {
                    appState.activeModule = .threatLogs
                }) {
                    Text("Inspect Threat In Audit Hub")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .frame(maxWidth: 550)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 12)
    }
}
