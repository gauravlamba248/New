import Foundation

public enum SandboxAirGapState: String, Sendable {
    case standardProtected = "Connected (Blockers Active)"
    case airGappedStrict = "Air-Gapped (Zero Egress Isolation)"
}

/// Manages runtime air-gap enforcement, process isolation verification, and sandbox lockdown.
public final class AirGappedSandboxManager: @unchecked Sendable {
    public static let shared = AirGappedSandboxManager()

    private let lock = NSLock()
    private var state: SandboxAirGapState = .standardProtected

    private init() {}

    public var currentState: SandboxAirGapState {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    public var isAirGapped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return state == .airGappedStrict
    }

    public func setAirGap(enabled: Bool) {
        lock.lock()
        state = enabled ? .airGappedStrict : .standardProtected
        lock.unlock()

        SecurityAuditLogger.shared.recordThreat(
            type: "Air-Gap Policy Changed",
            target: "Core Network Stack",
            reason: "Air-gap mode set to: \(enabled ? "STRICT_ISOLATION" : "STANDARD_PROTECTED")",
            mitigation: enabled ? "Killed all socket egress" : "Standard firewall resumed",
            severity: .info,
            isPrivateSession: false
        )
    }

    /// Low-level audit: queries current process memory and sandbox boundaries
    public func queryProcessDiagnostics() -> (memoryMB: Double, isSandboxed: Bool, pid: Int32) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)

        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let memoryMB: Double
        if kerr == KERN_SUCCESS {
            memoryMB = Double(info.resident_size) / (1024.0 * 1024.0)
        } else {
            memoryMB = 0.0
        }

        let home = getenv("HOME").map { String(cString: $0) } ?? ""
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil ||
                          home.contains("Containers")

        return (memoryMB: memoryMB, isSandboxed: isSandboxed, pid: ProcessInfo.processInfo.processIdentifier)
    }
}
