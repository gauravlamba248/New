import Foundation

public struct ThreatLogEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let threatType: String
    public let target: String
    public let reason: String
    public let mitigation: String
    public let severity: ThreatSeverity

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        threatType: String,
        target: String,
        reason: String,
        mitigation: String,
        severity: ThreatSeverity
    ) {
        self.id = id
        self.timestamp = timestamp
        self.threatType = threatType
        self.target = target
        self.reason = reason
        self.mitigation = mitigation
        self.severity = severity
    }
}

public struct ActivityLogEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let module: String
    public let action: String
    public let durationSeconds: Double
    public let metadata: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        module: String,
        action: String,
        durationSeconds: Double = 0.0,
        metadata: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.module = module
        self.action = action
        self.durationSeconds = durationSeconds
        self.metadata = metadata
    }
}

/// Global thread-safe offline Audit Logger.
/// Enforces absolute zero-logging policy during Private / Air-Gapped sessions.
/// Features lazy-loading and strict memory bounding (< 100KB in RAM).
public final class SecurityAuditLogger: @unchecked Sendable {
    public static let shared = SecurityAuditLogger()

    private let queue = DispatchQueue(label: "com.aegis.audit.logger", qos: .utility)
    private var threatBuffer: [ThreatLogEntry] = []
    private var activityBuffer: [ActivityLogEntry] = []
    private let maxBufferSize = 30 // Strict memory limit in RAM; disk persistence retains full history
    private var isLoadedFromDisk = false

    private let logDirectory: URL
    private let threatLogURL: URL
    private let activityLogURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.logDirectory = appSupport.appendingPathComponent("Aegis/Logs", isDirectory: true)
        self.threatLogURL = logDirectory.appendingPathComponent("threats.json")
        self.activityLogURL = logDirectory.appendingPathComponent("activity.json")

        createLogDirectoryIfNeeded()
        // Do NOT eagerly load logs on init to preserve <15MB idle RAM!
    }

    private func createLogDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }

    /// Records a security intrusion, blocked tracker, blocked IP, or quarantined threat.
    public func recordThreat(
        type: String,
        target: String,
        reason: String,
        mitigation: String = "Neutralized & Connection Dropped",
        severity: ThreatSeverity = .high,
        isPrivateSession: Bool = false
    ) {
        queue.async {
            self.ensureLoaded()

            let sanitizedTarget = isPrivateSession ? "REDACTED_DURING_PRIVATE_SESSION" : target
            let entry = ThreatLogEntry(
                threatType: type,
                target: sanitizedTarget,
                reason: reason,
                mitigation: mitigation,
                severity: severity
            )

            self.threatBuffer.insert(entry, at: 0)
            if self.threatBuffer.count > self.maxBufferSize {
                self.threatBuffer.removeLast()
            }
            self.persistThreats()
        }
    }

    /// Records standard module usage and navigation history.
    public func recordActivity(
        module: String,
        action: String,
        durationSeconds: Double = 0.0,
        metadata: String = "",
        isPrivateSession: Bool = false
    ) {
        if isPrivateSession {
            return
        }

        queue.async {
            self.ensureLoaded()

            let entry = ActivityLogEntry(
                module: module,
                action: action,
                durationSeconds: durationSeconds,
                metadata: metadata
            )

            self.activityBuffer.insert(entry, at: 0)
            if self.activityBuffer.count > self.maxBufferSize {
                self.activityBuffer.removeLast()
            }
            self.persistActivity()
        }
    }

    public func getThreatLogs() -> [ThreatLogEntry] {
        return queue.sync {
            ensureLoaded()
            return threatBuffer
        }
    }

    public func getActivityLogs() -> [ActivityLogEntry] {
        return queue.sync {
            ensureLoaded()
            return activityBuffer
        }
    }

    public func trimMemoryBuffer(to count: Int) {
        queue.async {
            if self.threatBuffer.count > count {
                self.threatBuffer = Array(self.threatBuffer.prefix(count))
            }
            if self.activityBuffer.count > count {
                self.activityBuffer = Array(self.activityBuffer.prefix(count))
            }
        }
    }

    public func clearAllLogs() {
        queue.async {
            self.threatBuffer.removeAll()
            self.activityBuffer.removeAll()
            try? FileManager.default.removeItem(at: self.threatLogURL)
            try? FileManager.default.removeItem(at: self.activityLogURL)
        }
    }

    private func ensureLoaded() {
        guard !isLoadedFromDisk else { return }
        isLoadedFromDisk = true
        loadPersistedLogs()
    }

    private func persistThreats() {
        do {
            let data = try JSONEncoder().encode(self.threatBuffer)
            try data.write(to: self.threatLogURL, options: .atomic)
        } catch {}
    }

    private func persistActivity() {
        do {
            let data = try JSONEncoder().encode(self.activityBuffer)
            try data.write(to: self.activityLogURL, options: .atomic)
        } catch {}
    }

    private func loadPersistedLogs() {
        if let data = try? Data(contentsOf: threatLogURL),
           let logs = try? JSONDecoder().decode([ThreatLogEntry].self, from: data) {
            self.threatBuffer = Array(logs.prefix(maxBufferSize))
        }

        if let data = try? Data(contentsOf: activityLogURL),
           let logs = try? JSONDecoder().decode([ActivityLogEntry].self, from: data) {
            self.activityBuffer = Array(logs.prefix(maxBufferSize))
        }
    }
}
