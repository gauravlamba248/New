import Foundation
import Network

public enum IMAPError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed(String)
    case twoFactorRequired(String)
    case commandFailed(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "IMAP Connection Error: \(msg)"
        case .authenticationFailed(let msg): return "Authentication Failed: \(msg)"
        case .twoFactorRequired(let msg): return "2-Step Verification is active on this account: \(msg). An App-Specific Password is required for direct IMAP access."
        case .commandFailed(let msg): return "IMAP Protocol Error: \(msg)"
        case .timeout: return "IMAP Server timed out."
        }
    }
}

/// Native zero-dependency IMAP client implemented on Apple Network.framework (NWConnection).
/// Provides secure TLS synchronization and real-time push (IMAP IDLE) for Gmail, Outlook, and Apple Mail.
public final class NativeIMAPClient: @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private let queue = DispatchQueue(label: "com.aegis.imap", qos: .userInitiated)

    private var tagIndex: Int = 1
    private var activeConnection: NWConnection?
    private var isIdling: Bool = false

    public var onNewMailPushed: (@Sendable () -> Void)?

    public init(host: String, port: UInt16 = 993) {
        self.host = host
        self.port = port
    }

    private func nextTag() -> String {
        let tag = "A\(String(format: "%04d", tagIndex))"
        tagIndex += 1
        return tag
    }

    /// Tests connection and validates credentials against Gmail, Outlook, or Apple Mail.
    /// Detects if 2-Step Verification requires an App Password.
    public func authenticate(username: String, password: String) async throws -> Bool {
        let conn = try await createTLSConnection()
        defer { conn.cancel() }

        // Read server greeting
        _ = try await readResponse(from: conn)

        // Send LOGIN command
        let tag = nextTag()
        let cleanUser = escapeIMAP(username)
        let cleanPass = escapeIMAP(password)
        let loginCmd = "\(tag) LOGIN \(cleanUser) \(cleanPass)\r\n"

        try await write(loginCmd, to: conn)
        let response = try await readResponseUntil(tag: tag, from: conn)

        if response.contains("\(tag) OK") {
            return true
        } else if response.contains("AUTHENTICATIONFAILED") ||
                  response.contains("Application-specific password") ||
                  response.contains("2-Step Verification") ||
                  response.contains("Invalid credentials") {
            if response.contains("Application-specific password") ||
               response.contains("2-Step") ||
               host.contains("gmail.com") ||
               host.contains("mail.me.com") {
                throw IMAPError.twoFactorRequired("Google and Apple require a 16-character App Password for native desktop email clients. Your regular password is valid for web login, but providers block direct IMAP login with account passwords.")
            }
            throw IMAPError.authenticationFailed(response)
        } else {
            throw IMAPError.commandFailed(response)
        }
    }

    /// Fetches the latest emails from INBOX
    public func fetchInbox(
        username: String,
        password: String,
        limit: Int = 25
    ) async throws -> [EmailMessage] {
        let conn = try await createTLSConnection()
        defer { conn.cancel() }

        _ = try await readResponse(from: conn)

        // 1. LOGIN
        let loginTag = nextTag()
        try await write("\(loginTag) LOGIN \(escapeIMAP(username)) \(escapeIMAP(password))\r\n", to: conn)
        let loginRes = try await readResponseUntil(tag: loginTag, from: conn)
        guard loginRes.contains("\(loginTag) OK") else {
            if loginRes.contains("Application-specific") || loginRes.contains("2-Step") {
                throw IMAPError.twoFactorRequired(loginRes)
            }
            throw IMAPError.authenticationFailed(loginRes)
        }

        // 2. SELECT INBOX
        let selectTag = nextTag()
        try await write("\(selectTag) SELECT \"INBOX\"\r\n", to: conn)
        let selectRes = try await readResponseUntil(tag: selectTag, from: conn)
        guard selectRes.contains("\(selectTag) OK") else {
            throw IMAPError.commandFailed(selectRes)
        }

        // 3. SEARCH ALL
        let searchTag = nextTag()
        try await write("\(searchTag) UID SEARCH ALL\r\n", to: conn)
        let searchRes = try await readResponseUntil(tag: searchTag, from: conn)

        let uids = parseUIDs(from: searchRes)
        if uids.isEmpty {
            return []
        }

        // Get the most recent N message UIDs
        let recentUIDs = Array(uids.suffix(limit))
        var messages: [EmailMessage] = []

        // 4. Fetch headers and body for recent UIDs
        for uid in recentUIDs.reversed() {
            let fetchTag = nextTag()
            let fetchCmd = "\(fetchTag) UID FETCH \(uid) (UID FLAGS RFC822.HEADER BODY[TEXT])\r\n"
            try await write(fetchCmd, to: conn)
            let fetchRes = try await readResponseUntil(tag: fetchTag, from: conn)

            if let msg = parseEmailMessage(uid: uid, rawResponse: fetchRes) {
                messages.append(msg)
            }
        }

        // 5. LOGOUT
        let logoutTag = nextTag()
        try await write("\(logoutTag) LOGOUT\r\n", to: conn)

        return messages
    }

    /// Starts real-time push listener via IMAP IDLE (RFC 2177).
    /// As soon as a message arrives, onNewMailPushed is called immediately!
    public func startRealTimePushListener(username: String, password: String) {
        guard !password.isEmpty else { return }
        stopRealTimePushListener()

        Task {
            do {
                let conn = try await createTLSConnection()
                self.activeConnection = conn

                _ = try await readResponse(from: conn)

                // Login
                let loginTag = nextTag()
                try await write("\(loginTag) LOGIN \(escapeIMAP(username)) \(escapeIMAP(password))\r\n", to: conn)
                let loginRes = try await readResponseUntil(tag: loginTag, from: conn)
                guard loginRes.contains("\(loginTag) OK") else {
                    self.activeConnection = nil
                    conn.cancel()
                    return
                }

                // Select INBOX
                let selectTag = nextTag()
                try await write("\(selectTag) SELECT \"INBOX\"\r\n", to: conn)
                let selectRes = try await readResponseUntil(tag: selectTag, from: conn)
                guard selectRes.contains("\(selectTag) OK") else {
                    self.activeConnection = nil
                    conn.cancel()
                    return
                }

                // Send IDLE command
                let idleTag = nextTag()
                try await write("\(idleTag) IDLE\r\n", to: conn)
                self.isIdling = true

                // Continuously listen for real-time pushed packets (* X EXISTS)
                while self.isIdling {
                    let event = try await readResponse(from: conn)
                    if event.contains("EXISTS") || event.contains("RECENT") {
                        // Immediately notify listener of incoming mail!
                        self.onNewMailPushed?()
                    }
                }
            } catch {
                self.isIdling = false
                self.activeConnection = nil
            }
        }
    }

    public func stopRealTimePushListener() {
        self.isIdling = false
        if let conn = activeConnection {
            let done = "DONE\r\n"
            if let data = done.data(using: .utf8) {
                conn.send(content: data, completion: .contentProcessed { _ in
                    conn.cancel()
                })
            } else {
                conn.cancel()
            }
        }
        self.activeConnection = nil
    }

    // MARK: - Low-Level TLS Socket Helpers

    private func createTLSConnection() async throws -> NWConnection {
        let endpointHost = NWEndpoint.Host(host)
        let endpointPort = NWEndpoint.Port(rawValue: port)!

        let tlsOptions = NWProtocolTLS.Options()
        let params = NWParameters(tls: tlsOptions)

        let connection = NWConnection(host: endpointHost, port: endpointPort, using: params)

        return try await withCheckedThrowingContinuation { continuation in
            let gate = ContinuationGate()

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    gate.once {
                        continuation.resume(returning: connection)
                    }
                case .failed(let err):
                    connection.stateUpdateHandler = nil
                    gate.once {
                        continuation.resume(throwing: IMAPError.connectionFailed(err.localizedDescription))
                    }
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    gate.once {
                        continuation.resume(throwing: IMAPError.connectionFailed("Connection cancelled"))
                    }
                default:
                    break
                }
            }
            connection.start(queue: self.queue)
        }
    }

    private func write(_ text: String, to connection: NWConnection) async throws {
        guard let data = text.data(using: .utf8) else { return }
        return try await withCheckedThrowingContinuation { continuation in
            let gate = ContinuationGate()
            connection.send(content: data, completion: .contentProcessed { error in
                gate.once {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            })
        }
    }

    private func readResponse(from connection: NWConnection) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let gate = ContinuationGate()
            connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, _, error in
                gate.once {
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let str = String(data: data ?? Data(), encoding: .utf8) ?? ""
                    continuation.resume(returning: str)
                }
            }
        }
    }

    private func readResponseUntil(tag: String, from connection: NWConnection) async throws -> String {
        var accumulated = ""
        while !accumulated.contains("\(tag) OK") &&
              !accumulated.contains("\(tag) NO") &&
              !accumulated.contains("\(tag) BAD") {
            let chunk = try await readResponse(from: connection)
            if chunk.isEmpty { break }
            accumulated += chunk
        }
        return accumulated
    }

    private func escapeIMAP(_ str: String) -> String {
        let escaped = str.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func parseUIDs(from searchOutput: String) -> [UInt32] {
        var result: [UInt32] = []
        let lines = searchOutput.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("* SEARCH") {
                let parts = line.replacingOccurrences(of: "* SEARCH", with: "")
                    .components(separatedBy: .whitespaces)
                for part in parts {
                    if let uid = UInt32(part.trimmingCharacters(in: .whitespaces)) {
                        result.append(uid)
                    }
                }
            }
        }
        return result
    }

    private func parseEmailMessage(uid: UInt32, rawResponse: String) -> EmailMessage? {
        var subject = "(No Subject)"
        var from = "Unknown Sender"
        var to: [String] = []
        var date = Date()
        var body = ""

        let lines = rawResponse.components(separatedBy: .newlines)
        var isHeader = true
        var rawBodyLines: [String] = []

        for line in lines {
            if isHeader {
                let lower = line.lowercased()
                if lower.hasPrefix("subject:") {
                    subject = line.dropFirst(8).trimmingCharacters(in: .whitespaces)
                } else if lower.hasPrefix("from:") {
                    from = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                } else if lower.hasPrefix("to:") {
                    let toStr = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    to = toStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                } else if lower.hasPrefix("date:") {
                    let dateStr = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    let df = DateFormatter()
                    df.locale = Locale(identifier: "en_US_POSIX")
                    df.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
                    if let parsed = df.date(from: dateStr) {
                        date = parsed
                    }
                } else if line.isEmpty || line == "\r" {
                    isHeader = false
                }
            } else {
                if !line.contains(") OK") && !line.hasPrefix("A") {
                    rawBodyLines.append(line)
                }
            }
        }

        body = rawBodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty {
            body = "This message has no plain text content."
        }

        return EmailMessage(
            id: UUID(),
            accountId: UUID(), // Overwritten by caller with matching account
            uid: uid,
            subject: subject,
            from: from,
            to: to,
            date: date,
            bodyText: body
        )
    }
}
