import SwiftUI

public struct MailClientView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var mailManager = MailManager.shared

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        HStack(spacing: 0) {
            // PANE 1: Mail Folders & Accounts (Sidebar)
            folderSidebarPane
                .frame(width: 210)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // PANE 2: Message List
            messageListPane
                .frame(width: 320)
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // PANE 3: Reading Pane / Detail View
            messageDetailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
        }
        .sheet(isPresented: $mailManager.isComposePresented) {
            ComposeMailView(appState: appState, form: mailManager.composeMailForm)
        }
        .sheet(isPresented: $mailManager.isAddAccountPresented) {
            AddMailAccountView(appState: appState, form: mailManager.addMailForm)
        }
        .alert(
            "Remove Account from Aegis?",
            isPresented: $mailManager.isConfirmingRemove,
            presenting: mailManager.accountToRemove
        ) { acc in
            Button("Remove from Aegis", role: .destructive) {
                mailManager.removeAccount(id: acc.id)
                mailManager.accountToRemove = nil
            }
            Button("Cancel", role: .cancel) {
                mailManager.accountToRemove = nil
            }
        } message: { acc in
            Text("This will remove \(acc.email) and its cached messages from Aegis. Your real email on \(acc.provider.rawValue) will NOT be deleted.")
        }
    }

    // MARK: - Pane 1: Folders & Accounts Sidebar
    private var folderSidebarPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Provider Header & Active Tag
            HStack(spacing: 8) {
                Image(systemName: mailManager.selectedProvider.iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(providerColor)

                Text(mailManager.selectedProvider.rawValue)
                    .font(.system(size: 14, weight: .heavy))

                Spacer()

                Button(action: {
                    mailManager.presentAddAccount(for: mailManager.selectedProvider)
                }) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 13))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Add another \(mailManager.selectedProvider.rawValue) account")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Compose Button (Gmail Style Pill)
            Button(action: {
                mailManager.presentCompose()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13, weight: .bold))
                    Text("Compose")
                        .font(.system(size: 12, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(20)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            Divider()

            // Folders List
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(MailFolder.allCases) { folder in
                        folderRow(folder)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // ACCOUNTS Section
                    HStack {
                        Text("ACCOUNTS (\(mailManager.providerAccounts.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)

                    if mailManager.providerAccounts.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No \(mailManager.selectedProvider.rawValue) account logged in yet.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Button(action: {
                                mailManager.presentAddAccount(for: mailManager.selectedProvider)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("Log In Now")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                    } else {
                        ForEach(mailManager.providerAccounts) { acc in
                            accountRow(acc)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()

            // Bottom Real-Time Push Status
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("IMAP IDLE Push Active")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
    }

    private func folderRow(_ folder: MailFolder) -> some View {
        let isSelected = mailManager.selectedFolder == folder
        let unreadCount = mailManager.filteredMessages.filter { !$0.isRead }.count

        return Button(action: {
            mailManager.selectedFolder = folder
        }) {
            HStack(spacing: 8) {
                Image(systemName: folder.iconName)
                    .font(.system(size: 11))
                    .frame(width: 16)
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                Text(folder.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Spacer()

                if folder == .inbox && unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    private func accountRow(_ acc: MailAccount) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 5, height: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text(acc.email)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if acc.is2FAEnabled {
                    Text("2FA Secured")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Remove Account Button
            Button(action: {
                mailManager.confirmAccountRemoval(acc)
            }) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Remove account from Aegis")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(5)
        .padding(.horizontal, 6)
    }

    // MARK: - Pane 2: Message List
    private var messageListPane: some View {
        VStack(spacing: 0) {
            // Search & Instant Refresh
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))

                TextField("Search \(mailManager.selectedFolder.rawValue)...", text: $mailManager.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))

                // Instant Refresh Button
                Button(action: {
                    mailManager.syncCurrentProvider()
                }) {
                    Image(systemName: mailManager.isSyncing ? "arrow.clockwise" : "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(mailManager.isSyncing ? .accentColor : .secondary)
                        .rotationEffect(.degrees(mailManager.isSyncing ? 360 : 0))
                }
                .buttonStyle(.plain)
                .help("Check mail immediately")
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            .padding(10)

            Divider()

            // Message List
            if mailManager.filteredMessages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: mailManager.selectedFolder.iconName)
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No messages in \(mailManager.selectedFolder.rawValue)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("Emails received under your \(mailManager.selectedProvider.rawValue) accounts will appear here immediately.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(mailManager.filteredMessages) { msg in
                            messageRow(msg)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func messageRow(_ msg: EmailMessage) -> some View {
        let isSelected = mailManager.selectedMessage?.id == msg.id

        return HStack(alignment: .top, spacing: 8) {
            // Unread Blue Dot
            Circle()
                .fill(msg.isRead ? Color.clear : Color.blue)
                .frame(width: 6, height: 6)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(msg.from)
                        .font(.system(size: 11, weight: msg.isRead ? .medium : .bold))
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    Spacer()

                    Text(msg.formattedDate)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Text(msg.subject)
                    .font(.system(size: 11, weight: msg.isRead ? .regular : .bold))
                    .lineLimit(1)
                    .foregroundColor(msg.isRead ? .secondary : .primary)

                Text(msg.previewSnippet)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(2)
            }

            // Star Button
            Button(action: {
                mailManager.toggleStar(for: msg.id)
            }) {
                Image(systemName: msg.isStarred ? "star.fill" : "star")
                    .font(.system(size: 10))
                    .foregroundColor(msg.isStarred ? .yellow : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            mailManager.selectedMessage = msg
            mailManager.markAsRead(messageId: msg.id, isRead: true)
        }
    }

    // MARK: - Pane 3: Reading Pane / Detail View
    private var messageDetailPane: some View {
        VStack(spacing: 0) {
            if let msg = mailManager.selectedMessage {
                VStack(alignment: .leading, spacing: 0) {
                    // Action Bar
                    HStack(spacing: 12) {
                        Button(action: {
                            mailManager.presentCompose(
                                for: msg.accountId,
                                to: msg.from,
                                subject: msg.subject.hasPrefix("Re:") ? msg.subject : "Re: \(msg.subject)",
                                body: "\n\n--- Original Message ---\nFrom: \(msg.from)\nDate: \(msg.formattedDate)\n\n\(msg.bodyText)"
                            )
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                Text("Reply")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            mailManager.presentCompose(
                                for: msg.accountId,
                                to: "",
                                subject: msg.subject.hasPrefix("Fwd:") ? msg.subject : "Fwd: \(msg.subject)",
                                body: "\n\n---------- Forwarded message ---------\nFrom: \(msg.from)\nDate: \(msg.formattedDate)\nSubject: \(msg.subject)\nTo: \(msg.to.joined(separator: ", "))\n\n\(msg.bodyText)"
                            )
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.right.fill")
                                Text("Forward")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            mailManager.toggleStar(for: msg.id)
                        }) {
                            Image(systemName: msg.isStarred ? "star.fill" : "star")
                                .foregroundColor(msg.isStarred ? .yellow : .secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help("Star message")

                        Button(action: {
                            mailManager.markAsRead(messageId: msg.id, isRead: !msg.isRead)
                        }) {
                            Image(systemName: msg.isRead ? "envelope.badge" : "envelope.open")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help(msg.isRead ? "Mark as unread" : "Mark as read")

                        Spacer()

                        Button(action: {
                            mailManager.moveToTrash(messageId: msg.id)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.8))
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help("Move to Trash")
                    }
                    .padding(12)
                    .background(Color(NSColor.windowBackgroundColor))

                    Divider()

                    // Message Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(msg.subject)
                            .font(.system(size: 16, weight: .bold))

                        HStack(spacing: 10) {
                            Circle()
                                .fill(providerColor)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(String(msg.from.prefix(1)).uppercased())
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(msg.from)
                                        .font(.system(size: 12, weight: .bold))
                                    Spacer()
                                    Text(msg.formattedDate)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }

                                if !msg.to.isEmpty {
                                    Text("to \(msg.to.joined(separator: ", "))")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(16)

                    Divider()

                    // Message Body
                    ScrollView {
                        Text(msg.bodyText)
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Select a message to read")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var providerColor: Color {
        switch mailManager.selectedProvider {
        case .gmail: return .red
        case .outlook: return .blue
        case .apple: return .primary
        }
    }
}
