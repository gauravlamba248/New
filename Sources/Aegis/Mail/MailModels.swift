import Foundation

/// Thread-safe one-shot execution gate preventing double-resumption of CheckedContinuation in Swift 6 concurrency
public final class ContinuationGate: @unchecked Sendable {
    private var isResumed = false
    private let lock = NSLock()

    public init() {}

    public func once(_ block: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !isResumed else { return }
        isResumed = true
        block()
    }
}

public enum MailProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case gmail = "Gmail"
    case outlook = "Outlook"
    case apple = "Apple"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .gmail: return "envelope.fill"
        case .outlook: return "tray.full.fill"
        case .apple: return "applelogo"
        }
    }

    public var brandColorHex: String {
        switch self {
        case .gmail: return "#EA4335" // Google Red
        case .outlook: return "#0078D4" // Microsoft Blue
        case .apple: return "#999999" // Apple Graphite
        }
    }

    public var imapHost: String {
        switch self {
        case .gmail: return "imap.gmail.com"
        case .outlook: return "outlook.office365.com"
        case .apple: return "imap.mail.me.com"
        }
    }

    public var imapPort: UInt16 {
        return 993 // Implicit TLS for all three providers
    }

    public var smtpHost: String {
        switch self {
        case .gmail: return "smtp.gmail.com"
        case .outlook: return "smtp.office365.com"
        case .apple: return "smtp.mail.me.com"
        }
    }

    public var smtpPort: UInt16 {
        switch self {
        case .gmail: return 465 // SSL/TLS
        case .outlook: return 587 // STARTTLS
        case .apple: return 587 // STARTTLS
        }
    }

    public var twoStepAuthDocUrl: String {
        switch self {
        case .gmail: return "https://myaccount.google.com/apppasswords"
        case .outlook: return "https://account.live.com/proofs/manage/additional"
        case .apple: return "https://appleid.apple.com/account/manage"
        }
    }

    public var twoStepAuthTitle: String {
        switch self {
        case .gmail: return "Google 2-Step Verification"
        case .outlook: return "Microsoft 2-Step Verification"
        case .apple: return "Apple ID Two-Factor Authentication"
        }
    }
}

public enum MailFolder: String, CaseIterable, Identifiable, Codable, Sendable {
    case inbox = "Inbox"
    case starred = "Starred"
    case sent = "Sent"
    case drafts = "Drafts"
    case trash = "Trash"
    case archive = "Archive"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .inbox: return "tray.fill"
        case .starred: return "star.fill"
        case .sent: return "paperplane.fill"
        case .drafts: return "doc.fill"
        case .trash: return "trash.fill"
        case .archive: return "archivebox.fill"
        }
    }
}

public struct MailAccount: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var provider: MailProvider
    public var email: String
    public var displayName: String
    public var password: String // Stored securely locally
    public var is2FAEnabled: Bool
    public var twoFactorCode: String?
    public var createdAt: Date
    public var lastSyncDate: Date?

    public init(
        id: UUID = UUID(),
        provider: MailProvider,
        email: String,
        displayName: String = "",
        password: String,
        is2FAEnabled: Bool = false,
        twoFactorCode: String? = nil,
        createdAt: Date = Date(),
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.provider = provider
        self.email = email
        self.displayName = displayName.isEmpty ? email : displayName
        self.password = password
        self.is2FAEnabled = is2FAEnabled
        self.twoFactorCode = twoFactorCode
        self.createdAt = createdAt
        self.lastSyncDate = lastSyncDate
    }
}

public struct EmailMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let accountId: UUID
    public var uid: UInt32
    public var subject: String
    public var from: String
    public var to: [String]
    public var cc: [String]
    public var date: Date
    public var bodyText: String
    public var bodyHTML: String?
    public var isRead: Bool
    public var isStarred: Bool
    public var folder: MailFolder

    public init(
        id: UUID = UUID(),
        accountId: UUID,
        uid: UInt32 = 0,
        subject: String,
        from: String,
        to: [String] = [],
        cc: [String] = [],
        date: Date = Date(),
        bodyText: String,
        bodyHTML: String? = nil,
        isRead: Bool = false,
        isStarred: Bool = false,
        folder: MailFolder = .inbox
    ) {
        self.id = id
        self.accountId = accountId
        self.uid = uid
        self.subject = subject
        self.from = from
        self.to = to
        self.cc = cc
        self.date = date
        self.bodyText = bodyText
        self.bodyHTML = bodyHTML
        self.isRead = isRead
        self.isStarred = isStarred
        self.folder = folder
    }

    public var previewSnippet: String {
        let clean = bodyText.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count > 100 {
            return String(clean.prefix(100)) + "..."
        }
        return clean.isEmpty ? "(No content)" : clean
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }
}
