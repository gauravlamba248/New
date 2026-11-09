import Foundation

public enum ConnectionVerdict: Sendable {
    case permitted(host: String, port: Int)
    case blocked(host: String, port: Int, reason: String, severity: ThreatSeverity)
}

public enum ThreatSeverity: String, Codable, Sendable {
    case info = "INFO"
    case warning = "WARNING"
    case high = "HIGH"
    case critical = "CRITICAL"
}

/// Global singleton to intercept and neutralize anomalous outbound socket activity,
/// unauthorized telemetry exfiltration, and air-gap leaks.
public final class LeakConnectionBlocker: @unchecked Sendable {
    public static let shared = LeakConnectionBlocker()

    private let suspiciousPorts: Set<Int> = [
        23,    // Telnet (unencrypted terminal leak)
        25,    // SMTP (direct spam/exfiltration mailer)
        135,   // RPC
        139,   // NetBIOS
        445,   // SMB
        1337,  // Common Trojan/Backdoor
        31337, // Back Orifice / Metasploit payload
        4444,  // Metasploit default listener
        5555,  // ADB remote exploit port
        6667,  // IRC Botnet command channel
        8888,  // Alternate proxy/backdoor
        9001   // Tor Default relay / backdoor
    ]

    private let lock = NSLock()
    private(set) var totalBlockedLeaks: Int = 0
    public private(set) var isEnabled: Bool = true

    private init() {}

    /// Dynamically enables or disables the Outbound Leak / Port blocker individually
    public func setEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.isEnabled = enabled
    }

    /// Inspects an outbound connection attempt against zero-trust leak policies.
    public func evaluateOutboundConnection(
        host: String,
        port: Int,
        isAirGapped: Bool
    ) -> ConnectionVerdict {
        // Rule 1: Strict Air-Gap isolation mode (hardware-level isolation supersedes individual toggles)
        if isAirGapped {
            recordBlockedLeak()
            return .blocked(
                host: host,
                port: port,
                reason: "Air-Gapped Sandbox Enforced: Zero network egress permitted.",
                severity: .critical
            )
        }

        lock.lock()
        guard isEnabled else {
            lock.unlock()
            return .permitted(host: host, port: port)
        }
        lock.unlock()

        // Rule 2: Suspicious backdoor / exfiltration target port
        if suspiciousPorts.contains(port) {
            recordBlockedLeak()
            return .blocked(
                host: host,
                port: port,
                reason: "Blocked known exfiltration/malware backdoor port: \(port)",
                severity: .high
            )
        }

        // Rule 3: DNS Tunneling and Base64 Exfiltration Detection
        if isPotentialDNSTunnel(host: host) {
            recordBlockedLeak()
            return .blocked(
                host: host,
                port: port,
                reason: "Heuristic match: High-entropy anomalous subdomain indicates DNS data exfiltration attempt.",
                severity: .critical
            )
        }

        // Rule 4: Query Ad/Tracker Blocker
        let (trackerBlocked, trackerReason) = AdTrackerBlocker.shared.isBlocked(host: host)
        if trackerBlocked {
            recordBlockedLeak()
            return .blocked(
                host: host,
                port: port,
                reason: trackerReason ?? "Telemetry/Tracker destination",
                severity: .warning
            )
        }

        // Rule 5: Query IP Blocker
        let (ipBlocked, ipReason) = IPBlocker.shared.isBlocked(ipString: host)
        if ipBlocked {
            recordBlockedLeak()
            return .blocked(
                host: host,
                port: port,
                reason: ipReason ?? "Blacklisted host/IP range",
                severity: .high
            )
        }

        return .permitted(host: host, port: port)
    }

    /// Detects signs of DNS tunneling (e.g. data exfiltration encoded as a base32/hex subdomain label > 30 chars)
    private func isPotentialDNSTunnel(host: String) -> Bool {
        let labels = host.split(separator: ".")
        for label in labels {
            if label.count >= 32 {
                // High Shannon entropy / alphanumeric ratio characteristic of hex/base64 exfiltration
                let alphanumericCount = label.filter { $0.isLetter || $0.isNumber }.count
                if Double(alphanumericCount) / Double(label.count) > 0.9 {
                    return true
                }
            }
        }
        return false
    }

    private func recordBlockedLeak() {
        lock.lock()
        totalBlockedLeaks += 1
        lock.unlock()
    }
}
