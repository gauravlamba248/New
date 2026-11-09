import Foundation
import Network

public enum SMTPError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed(String)
    case sendFailed(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "SMTP Connection Error: \(msg)"
        case .authenticationFailed(let msg): return "SMTP Authentication Failed: \(msg). Check password or 2-Step Verification App Password."
        case .sendFailed(let msg): return "SMTP Delivery Error: \(msg)"
        case .timeout: return "SMTP Server timed out."
        }
    }
}

/// Native zero-dependency SMTP client built directly on Apple Network.framework (NWConnection).
/// Sends emails securely over TLS directly to Gmail, Outlook, or Apple Mail servers.
public final class NativeSMTPClient: @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private let queue = DispatchQueue(label: "com.aegis.smtp", qos: .userInitiated)

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    public func sendEmail(
        from: String,
        password: String,
        to: [String],
        cc: [String] = [],
        subject: String,
        body: String
    ) async throws {
        let endpointHost = NWEndpoint.Host(host)
        let endpointPort = NWEndpoint.Port(rawValue: port)!

        let tlsOptions = NWProtocolTLS.Options()
        let params = NWParameters(tls: tlsOptions)

        let connection = NWConnection(host: endpointHost, port: endpointPort, using: params)
        defer { connection.cancel() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = ContinuationGate()

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    Task {
                        do {
                            try await self.executeSMTPTransaction(
                                connection: connection,
                                from: from,
                                password: password,
                                to: to,
                                cc: cc,
                                subject: subject,
                                body: body
                            )
                            gate.once {
                                continuation.resume()
                            }
                        } catch {
                            gate.once {
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                case .failed(let err):
                    connection.stateUpdateHandler = nil
                    gate.once {
                        continuation.resume(throwing: SMTPError.connectionFailed(err.localizedDescription))
                    }
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    gate.once {
                        continuation.resume(throwing: SMTPError.connectionFailed("SMTP connection cancelled"))
                    }
                default:
                    break
                }
            }
            connection.start(queue: self.queue)
        }
    }

    private func executeSMTPTransaction(
        connection: NWConnection,
        from: String,
        password: String,
        to: [String],
        cc: [String],
        subject: String,
        body: String
    ) async throws {
        // 1. Read Greeting (220)
        let greeting = try await readLine(from: connection)
        guard greeting.hasPrefix("220") else {
            throw SMTPError.connectionFailed("Invalid server greeting: \(greeting)")
        }

        // 2. Send EHLO
        try await write("EHLO aegis.local\r\n", to: connection)
        _ = try await readMultiLine(from: connection)

        // 3. Authenticate with AUTH LOGIN
        try await write("AUTH LOGIN\r\n", to: connection)
        let authPrompt = try await readLine(from: connection)
        guard authPrompt.hasPrefix("334") else {
            throw SMTPError.authenticationFailed("Server did not accept AUTH LOGIN: \(authPrompt)")
        }

        // Send base64 Username
        let userBase64 = Data(from.utf8).base64EncodedString() + "\r\n"
        try await write(userBase64, to: connection)
        let passPrompt = try await readLine(from: connection)
        guard passPrompt.hasPrefix("334") else {
            throw SMTPError.authenticationFailed("Invalid username: \(passPrompt)")
        }

        // Send base64 Password / App Password
        let passBase64 = Data(password.utf8).base64EncodedString() + "\r\n"
        try await write(passBase64, to: connection)
        let authResult = try await readLine(from: connection)
        guard authResult.hasPrefix("235") else {
            throw SMTPError.authenticationFailed("Login rejected: \(authResult)")
        }

        // 4. MAIL FROM
        try await write("MAIL FROM:<\(from)>\r\n", to: connection)
        let mailFromRes = try await readLine(from: connection)
        guard mailFromRes.hasPrefix("250") else {
            throw SMTPError.sendFailed("MAIL FROM rejected: \(mailFromRes)")
        }

        // 5. RCPT TO for each recipient
        let allRecipients = to + cc
        for rcpt in allRecipients {
            let cleanRcpt = rcpt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanRcpt.isEmpty {
                try await write("RCPT TO:<\(cleanRcpt)>\r\n", to: connection)
                let rcptRes = try await readLine(from: connection)
                guard rcptRes.hasPrefix("250") || rcptRes.hasPrefix("251") else {
                    throw SMTPError.sendFailed("Recipient rejected (\(cleanRcpt)): \(rcptRes)")
                }
            }
        }

        // 6. DATA command
        try await write("DATA\r\n", to: connection)
        let dataPrompt = try await readLine(from: connection)
        guard dataPrompt.hasPrefix("354") else {
            throw SMTPError.sendFailed("DATA command rejected: \(dataPrompt)")
        }

        // 7. Compose RFC 5322 MIME message
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let dateStr = dateFormatter.string(from: Date())
        let messageId = "<\(UUID().uuidString)@aegis.client>"

        var payload = ""
        payload += "From: \(from)\r\n"
        payload += "To: \(to.joined(separator: ", "))\r\n"
        if !cc.isEmpty {
            payload += "Cc: \(cc.joined(separator: ", "))\r\n"
        }
        payload += "Subject: \(subject)\r\n"
        payload += "Date: \(dateStr)\r\n"
        payload += "Message-ID: \(messageId)\r\n"
        payload += "MIME-Version: 1.0\r\n"
        payload += "Content-Type: text/plain; charset=UTF-8\r\n"
        payload += "Content-Transfer-Encoding: 8bit\r\n"
        payload += "\r\n"
        payload += body.replacingOccurrences(of: "\n.", with: "\n..") // Dot-stuffing
        payload += "\r\n.\r\n"

        try await write(payload, to: connection)
        let sendResult = try await readLine(from: connection)
        guard sendResult.hasPrefix("250") else {
            throw SMTPError.sendFailed("Server did not accept message body: \(sendResult)")
        }

        // 8. QUIT
        try await write("QUIT\r\n", to: connection)
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

    private func readLine(from connection: NWConnection) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let gate = ContinuationGate()
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                gate.once {
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let data = data, let str = String(data: data, encoding: .utf8) else {
                        continuation.resume(throwing: SMTPError.connectionFailed("No data received"))
                        return
                    }
                    continuation.resume(returning: str.trimmingCharacters(in: .newlines))
                }
            }
        }
    }

    private func readMultiLine(from connection: NWConnection) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let gate = ContinuationGate()
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, error in
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
}
