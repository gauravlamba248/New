import Foundation
import Darwin

/// Represents an IPv4 CIDR subnet (e.g. 198.51.100.0/24) using bitwise integer math.
public struct IPv4CIDR: Sendable, Hashable {
    public let baseIP: UInt32
    public let mask: UInt32
    public let rawCIDR: String
    public let label: String

    public init?(cidr: String, label: String = "Malicious/Suspicious Subnet") {
        let components = cidr.split(separator: "/")
        guard components.count == 2,
              let prefix = UInt32(components[1]),
              prefix <= 32 else {
            return nil
        }

        var addr = in_addr()
        guard inet_pton(AF_INET, String(components[0]), &addr) == 1 else {
            return nil
        }

        let ip = UInt32(bigEndian: addr.s_addr)
        let mask = prefix == 0 ? UInt32(0) : (~UInt32(0)) << (32 - prefix)
        self.baseIP = ip & mask
        self.mask = mask
        self.rawCIDR = cidr
        self.label = label
    }

    public func contains(ip: UInt32) -> Bool {
        return (ip & mask) == baseIP
    }
}

/// Global singleton for ultra-low latency, offline IP evaluation and CIDR filtering.
public final class IPBlocker: @unchecked Sendable {
    public static let shared = IPBlocker()

    private var ipv4Subnets: [IPv4CIDR] = []
    private var explicitBlockedIPs: Set<String> = []
    private let lock = NSLock()
    private(set) var totalBlockedCount: Int = 0
    public private(set) var isEnabled: Bool = true

    private init() {
        populateDefaultBlockedRanges()
    }

    /// Dynamically enables or disables the Hostile IP blocker individually
    public func setEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.isEnabled = enabled
    }

    /// Evaluates if an IP string (IPv4/IPv6) or resolved endpoint is forbidden.
    public func isBlocked(ipString: String) -> (blocked: Bool, reason: String?) {
        let cleanIP = ipString.trimmingCharacters(in: .whitespacesAndNewlines)

        lock.lock()
        defer { lock.unlock() }

        guard isEnabled else { return (false, nil) }

        if explicitBlockedIPs.contains(cleanIP) {
            totalBlockedCount += 1
            return (true, "Explicit blacklist entry: \(cleanIP)")
        }

        // Test against IPv4 CIDR ranges
        var addr = in_addr()
        if inet_pton(AF_INET, cleanIP, &addr) == 1 {
            let hostIP = UInt32(bigEndian: addr.s_addr)
            for subnet in ipv4Subnets {
                if subnet.contains(ip: hostIP) {
                    totalBlockedCount += 1
                    return (true, "Subnet block rule [\(subnet.rawCIDR)]: \(subnet.label)")
                }
            }
        }

        return (false, nil)
    }

    public func block(cidr: String, label: String) {
        lock.lock()
        defer { lock.unlock() }
        if let rule = IPv4CIDR(cidr: cidr, label: label) {
            ipv4Subnets.append(rule)
        }
    }

    public func block(ip: String) {
        lock.lock()
        defer { lock.unlock() }
        explicitBlockedIPs.insert(ip)
    }

    private func populateDefaultBlockedRanges() {
        // High-risk known botnet C2 ranges, RFC 5735 documentation/testnets attempting egress, and bogons
        let defaultSubnets: [(cidr: String, label: String)] = [
            ("198.51.100.0/24", "RFC 5735 TEST-NET-2 - Potential Spoofing/Bogon"),
            ("203.0.113.0/24", "RFC 5735 TEST-NET-3 - Potential Spoofing/Bogon"),
            ("192.0.2.0/24", "RFC 5735 TEST-NET-1 - Suspicious Documentation Egress"),
            ("100.64.0.0/10", "Carrier-grade NAT Anomalous Egress"),
            ("185.220.101.0/24", "Known Tor Malicious Exit / C2 Infrastructure"),
            ("194.26.29.0/24", "Known Bulletproof Hosting Malicious CIDR"),
            ("45.154.255.0/24", "Hostile Botnet Command & Control Range"),
            ("185.196.8.0/24", "Darknet Stealer Infrastructure Subnet")
        ]

        for item in defaultSubnets {
            if let rule = IPv4CIDR(cidr: item.cidr, label: item.label) {
                ipv4Subnets.append(rule)
            }
        }

        // Explicit known malicious C2 IP addresses
        let maliciousC2s = [
            "185.220.101.5",
            "194.26.29.112",
            "45.154.255.88",
            "185.196.8.12",
            "185.244.25.187",
            "193.106.191.162"
        ]
        for c2 in maliciousC2s {
            explicitBlockedIPs.insert(c2)
        }
    }
}
