import Foundation
import Combine
import SwiftUI

/// Global manager orchestrating Mail accounts, native IMAP/SMTP synchronization,
/// real-time push listeners (IMAP IDLE), folder management, and local offline persistence.
@MainActor
public final class MailManager: ObservableObject {
    public static let shared = MailManager()

    @Published public private(set) var accounts: [MailAccount] = []
    @Published public private(set) var messages: [EmailMessage] = []

    @Published public var selectedProvider: MailProvider = .gmail
    @Published public var selectedFolder: MailFolder = .inbox
    @Published public var selectedMessage: EmailMessage? = nil
    @Published public var searchQuery: String = ""

    @Published public var isSyncing: Bool = false
    @Published public var syncStatusMessage: String = "Ready"
    @Published public var isComposePresented: Bool = false
    @Published public var isAddAccountPresented: Bool = false
    @Published public var accountToRemove: MailAccount? = nil
    @Published public var isConfirmingRemove: Bool = false

    @Published public var addMailForm: AddMailFormState = AddMailFormState()
    @Published public var composeMailForm: ComposeMailFormState = ComposeMailFormState(initialAccountId: UUID())

    public func confirmAccountRemoval(_ account: MailAccount) {
        self.accountToRemove = account
        self.isConfirmingRemove = true
    }

    public func presentAddAccount(for provider: MailProvider) {
        self.addMailForm = AddMailFormState(initialProvider: provider)
        self.isAddAccountPresented = true
    }

    public func presentCompose(
        for accountId: UUID? = nil,
        to: String = "",
        subject: String = "",
        body: String = ""
    ) {
        let accId = accountId ?? providerAccounts.first?.id ?? UUID()
        self.composeMailForm = ComposeMailFormState(
            initialAccountId: accId,
            initialTo: to,
            initialSubject: subject,
            initialBody: body
        )
        self.isComposePresented = true
    }

    private let mailDirURL: URL
    private let accountsFileURL: URL
    private let messagesFileURL: URL

    private var pushListeners: [UUID: NativeIMAPClient] = [:]
    private var syncTimer: Timer?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Aegis/Mail", isDirectory: true)
        self.mailDirURL = dir
        self.accountsFileURL = dir.appendingPathComponent("accounts.json")
        self.messagesFileURL = dir.appendingPathComponent("messages.json")

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        loadPersistedData()
        startPeriodicSync()
    }

    // MARK: - Filtered Messages for Provider & Folder
    public var providerAccounts: [MailAccount] {
        accounts.filter { $0.provider == selectedProvider }
    }

    public var filteredMessages: [EmailMessage] {
        let matchingAccountIds = Set(providerAccounts.map { $0.id })
        var list = messages.filter { matchingAccountIds.contains($0.accountId) }

        if selectedFolder == .starred {
            list = list.filter { $0.isStarred }
        } else {
            list = list.filter { $0.folder == selectedFolder }
        }

        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            list = list.filter {
                $0.subject.lowercased().contains(q) ||
                $0.from.lowercased().contains(q) ||
                $0.bodyText.lowercased().contains(q)
            }
        }

        return list.sorted { $0.date > $1.date }
    }

    // MARK: - Account Management (Add / Remove)

    /// Authenticates credentials with provider over native TLS and registers the account
    public func addAccount(
        provider: MailProvider,
        email: String,
        displayName: String,
        password: String,
        is2FA: Bool = false,
        twoFactorCode: String? = nil
    ) async throws -> MailAccount {
        isSyncing = true
        syncStatusMessage = "Connecting to \(provider.rawValue) IMAP over TLS..."

        let imap = NativeIMAPClient(host: provider.imapHost, port: provider.imapPort)
        _ = try await imap.authenticate(username: email, password: password)

        let newAccount = MailAccount(
            provider: provider,
            email: email,
            displayName: displayName.isEmpty ? email : displayName,
            password: password,
            is2FAEnabled: is2FA,
            twoFactorCode: twoFactorCode,
            lastSyncDate: Date()
        )

        accounts.append(newAccount)
        savePersistedData()

        syncStatusMessage = "Account added. Fetching messages..."

        // Start Real-Time IMAP IDLE push listener so new emails arrive immediately!
        startPushListener(for: newAccount)

        // Fetch initial messages
        await fetchInbox(for: newAccount)

        isSyncing = false
        syncStatusMessage = "Connected"
        return newAccount
    }

    /// Removes an account locally from the Aegis app (does NOT delete account on provider's server)
    public func removeAccount(id: UUID) {
        // Stop push listener
        stopPushListener(for: id)

        // Remove from list
        accounts.removeAll { $0.id == id }

        // Remove all cached messages for this account
        messages.removeAll { $0.accountId == id }

        if selectedMessage?.accountId == id {
            selectedMessage = nil
        }

        savePersistedData()
        syncStatusMessage = "Account removed from Aegis"
    }

    // MARK: - Immediate Sending & Receiving

    /// Sends an email immediately via provider SMTP over TLS
    public func sendEmail(
        fromAccount: MailAccount,
        to: [String],
        cc: [String] = [],
        subject: String,
        body: String
    ) async throws {
        isSyncing = true
        syncStatusMessage = "Sending email via \(fromAccount.provider.rawValue) SMTP..."

        let smtp = NativeSMTPClient(host: fromAccount.provider.smtpHost, port: fromAccount.provider.smtpPort)
        try await smtp.sendEmail(
            from: fromAccount.email,
            password: fromAccount.password,
            to: to,
            cc: cc,
            subject: subject,
            body: body
        )

        // Add to Sent folder locally
        let sentMessage = EmailMessage(
            accountId: fromAccount.id,
            subject: subject,
            from: fromAccount.email,
            to: to,
            cc: cc,
            date: Date(),
            bodyText: body,
            isRead: true,
            folder: .sent
        )
        messages.insert(sentMessage, at: 0)
        savePersistedData()

        isSyncing = false
        syncStatusMessage = "Email sent successfully"
    }

    /// Fetches latest messages from inbox over IMAP
    public func fetchInbox(for account: MailAccount) async {
        guard !account.password.isEmpty else { return }
        isSyncing = true
        syncStatusMessage = "Syncing \(account.email)..."

        let imap = NativeIMAPClient(host: account.provider.imapHost, port: account.provider.imapPort)
        do {
            var fetched = try await imap.fetchInbox(username: account.email, password: account.password, limit: 30)

            for i in 0..<fetched.count {
                fetched[i] = EmailMessage(
                    id: fetched[i].id,
                    accountId: account.id,
                    uid: fetched[i].uid,
                    subject: fetched[i].subject,
                    from: fetched[i].from,
                    to: fetched[i].to,
                    cc: fetched[i].cc,
                    date: fetched[i].date,
                    bodyText: fetched[i].bodyText,
                    bodyHTML: fetched[i].bodyHTML,
                    isRead: fetched[i].isRead,
                    isStarred: fetched[i].isStarred,
                    folder: .inbox
                )
            }

            // Merge with existing messages, deduplicating by UID or Subject+Date
            for newMsg in fetched {
                if !messages.contains(where: { $0.accountId == account.id && $0.uid == newMsg.uid && newMsg.uid != 0 }) {
                    messages.insert(newMsg, at: 0)
                }
            }

            if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
                accounts[idx].lastSyncDate = Date()
            }

            savePersistedData()
            syncStatusMessage = "Sync completed"
        } catch {
            syncStatusMessage = "Sync notice: \(error.localizedDescription)"
        }
        isSyncing = false
    }

    /// Syncs all accounts belonging to the currently selected provider
    public func syncCurrentProvider() {
        Task {
            for account in providerAccounts {
                await fetchInbox(for: account)
            }
        }
    }

    // MARK: - Real-Time Push Listeners (IMAP IDLE)

    private func startPushListener(for account: MailAccount) {
        stopPushListener(for: account.id)
        guard !account.password.isEmpty else { return }

        let client = NativeIMAPClient(host: account.provider.imapHost, port: account.provider.imapPort)
        client.onNewMailPushed = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Instant sync as soon as push packet arrives!
                Task {
                    await self.fetchInbox(for: account)
                }
            }
        }
        client.startRealTimePushListener(username: account.email, password: account.password)
        pushListeners[account.id] = client
    }

    private func stopPushListener(for accountId: UUID) {
        if let client = pushListeners[accountId] {
            client.stopRealTimePushListener()
            pushListeners.removeValue(forKey: accountId)
        }
    }

    private func startPeriodicSync() {
        // High-cadence fallback sync timer (every 45s) for providers without active IDLE
        syncTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                for acc in self.accounts where !acc.password.isEmpty {
                    await self.fetchInbox(for: acc)
                }
            }
        }
    }

    // MARK: - Message Actions (Star, Trash, Read)

    public func toggleStar(for messageId: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages[idx].isStarred.toggle()
            if selectedMessage?.id == messageId {
                selectedMessage?.isStarred = messages[idx].isStarred
            }
            savePersistedData()
        }
    }

    public func markAsRead(messageId: UUID, isRead: Bool = true) {
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages[idx].isRead = isRead
            if selectedMessage?.id == messageId {
                selectedMessage?.isRead = isRead
            }
            savePersistedData()
        }
    }

    public func moveToTrash(messageId: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            if messages[idx].folder == .trash {
                // Permanent deletion from local app
                messages.remove(at: idx)
                if selectedMessage?.id == messageId {
                    selectedMessage = nil
                }
            } else {
                messages[idx].folder = .trash
            }
            savePersistedData()
        }
    }

    // MARK: - Local Persistence

    private func loadPersistedData() {
        if let data = try? Data(contentsOf: accountsFileURL),
           let decoded = try? JSONDecoder().decode([MailAccount].self, from: data) {
            self.accounts = decoded
            for acc in self.accounts {
                startPushListener(for: acc)
            }
        }

        if let data = try? Data(contentsOf: messagesFileURL),
           let decoded = try? JSONDecoder().decode([EmailMessage].self, from: data) {
            self.messages = decoded
        }

        // Seed demo welcome emails if first launch
        if accounts.isEmpty && messages.isEmpty {
            seedInitialDemoState()
        }
    }

    private func savePersistedData() {
        if let data = try? JSONEncoder().encode(accounts) {
            try? data.write(to: accountsFileURL, options: .atomic)
        }
        if let data = try? JSONEncoder().encode(messages) {
            try? data.write(to: messagesFileURL, options: .atomic)
        }
    }

    private func seedInitialDemoState() {
        // Pre-create standard initial accounts so the user can immediately test UI even before entering real credentials
        let gmailAcc = MailAccount(
            provider: .gmail,
            email: "user@gmail.com",
            displayName: "Gmail Account",
            password: "",
            is2FAEnabled: true,
            lastSyncDate: Date()
        )
        let outlookAcc = MailAccount(
            provider: .outlook,
            email: "user@outlook.com",
            displayName: "Outlook Account",
            password: "",
            is2FAEnabled: false,
            lastSyncDate: Date()
        )
        let appleAcc = MailAccount(
            provider: .apple,
            email: "user@icloud.com",
            displayName: "Apple iCloud Mail",
            password: "",
            is2FAEnabled: true,
            lastSyncDate: Date()
        )

        self.accounts = [gmailAcc, outlookAcc, appleAcc]

        // Seed welcome messages
        let gMsg = EmailMessage(
            accountId: gmailAcc.id,
            subject: "Welcome to Gmail on Aegis",
            from: "Google Security <no-reply@accounts.google.com>",
            to: ["user@gmail.com"],
            date: Date().addingTimeInterval(-3600),
            bodyText: """
            Welcome to your native Gmail client on Aegis!

            Key Features Active:
            • Zero WebPage Embeds — 100% native Swift & Darwin sockets.
            • Real-time IMAP IDLE push notifications for immediate delivery.
            • Full 2-Step Verification & App Password support.
            • Provider Isolation: Only Gmail accounts appear under this view.

            Click 'Compose' at the top to send a real email anytime.
            """,
            isRead: false,
            isStarred: true
        )

        let oMsg = EmailMessage(
            accountId: outlookAcc.id,
            subject: "Your Microsoft Outlook Mail is Ready",
            from: "Microsoft Outlook <outlook@microsoft.com>",
            to: ["user@outlook.com"],
            date: Date().addingTimeInterval(-7200),
            bodyText: """
            Your Microsoft Outlook mailbox is configured in Aegis.

            • TLS encrypted IMAP & SMTP direct routing.
            • Isolated data store strictly local on your Mac.
            """,
            isRead: true,
            isStarred: false
        )

        let aMsg = EmailMessage(
            accountId: appleAcc.id,
            subject: "Apple iCloud Mail Protected on Aegis",
            from: "Apple <news@insideicloud.icloud.com>",
            to: ["user@icloud.com"],
            date: Date().addingTimeInterval(-14400),
            bodyText: """
            Welcome to iCloud Mail on Aegis.

            • Connects via Apple IMAP (imap.mail.me.com:993).
            • 2FA App-Specific Password compatible.
            """,
            isRead: false,
            isStarred: true
        )

        self.messages = [gMsg, oMsg, aMsg]
        savePersistedData()
    }
}
