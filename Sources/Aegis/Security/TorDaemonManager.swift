import Foundation
import Darwin

public enum TorDaemonState: String, Sendable {
    case stopped = "Stopped"
    case starting = "Starting..."
    case bootstrapping = "Connecting to Onion Network..."
    case connected = "Connected (100%)"
    case failed = "Failed"
}

/// Global singleton managing the local Tor daemon lifecycle.
/// Spawns, bootstraps, and terminates Tor on-demand strictly within Aegis.
public final class TorDaemonManager: @unchecked Sendable {
    public static let shared = TorDaemonManager()

    private let lock = NSLock()
    private var process: Process?
    private var outputPipe: Pipe?

    public private(set) var state: TorDaemonState = .stopped
    public private(set) var bootstrapPercentage: Int = 0
    public private(set) var statusMessage: String = "Tor Stopped"
    public private(set) var isRunning: Bool = false

    private let torDataDirURL: URL
    private let torPidFileURL: URL

    public var onStateChange: (@Sendable () -> Void)?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let torDir = appSupport.appendingPathComponent("Aegis/Tor", isDirectory: true)
        self.torDataDirURL = torDir.appendingPathComponent("data", isDirectory: true)
        self.torPidFileURL = torDir.appendingPathComponent("tor.pid")

        try? FileManager.default.createDirectory(at: torDataDirURL, withIntermediateDirectories: true)
    }

    /// Discovers Tor binary location: Bundled in Aegis.app, Homebrew, or user directory.
    public func findTorBinaryPath() -> String? {
        // 1. Check inside Aegis.app bundle
        if let bundleResource = Bundle.main.resourceURL?.appendingPathComponent("tor").path,
           FileManager.default.isExecutableFile(atPath: bundleResource) {
            return bundleResource
        }
        let bundleMacOS = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/tor").path
        if FileManager.default.isExecutableFile(atPath: bundleMacOS) {
            return bundleMacOS
        }

        // 2. Check Homebrew default paths
        let brewPaths = [
            "/opt/homebrew/opt/tor/bin/tor",
            "/opt/homebrew/bin/tor",
            "/usr/local/opt/tor/bin/tor",
            "/usr/local/bin/tor"
        ]
        for path in brewPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // 3. Fallback to PATH lookup
        let pipe = Pipe()
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["tor"]
        which.standardOutput = pipe
        try? which.run()
        which.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !str.isEmpty, FileManager.default.isExecutableFile(atPath: str) {
            return str
        }

        return nil
    }

    public var isTorAvailable: Bool {
        return findTorBinaryPath() != nil
    }

    /// Launches Tor daemon process listening strictly on 127.0.0.1:9050
    public func startTor() {
        lock.lock()
        if isRunning {
            lock.unlock()
            return
        }

        guard let binaryPath = findTorBinaryPath() else {
            self.state = .failed
            self.statusMessage = "Tor binary not found"
            lock.unlock()
            notifyChange()
            return
        }

        // Kill any previous lingering PID
        killStalePID()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = [
            "--SocksPort", "127.0.0.1:9050",
            "--DataDirectory", torDataDirURL.path,
            "--PidFile", torPidFileURL.path,
            "--Log", "notice stdout"
        ]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        self.process = proc
        self.outputPipe = pipe
        self.state = .starting
        self.statusMessage = "Starting Tor daemon..."
        self.bootstrapPercentage = 5
        self.isRunning = true
        lock.unlock()
        notifyChange()

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            self?.parseTorOutput(output)
        }

        do {
            try proc.run()
            SecurityAuditLogger.shared.recordActivity(
                module: "Tor Daemon",
                action: "Start Tor Process",
                metadata: "PID: \(proc.processIdentifier), Port: 9050"
            )
        } catch {
            lock.lock()
            self.state = .failed
            self.statusMessage = "Launch error: \(error.localizedDescription)"
            self.isRunning = false
            self.process = nil
            lock.unlock()
            notifyChange()
        }
    }

    /// Completely terminates the Tor daemon process and frees all resources
    public func stopTor() {
        lock.lock()
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil

        if let proc = process {
            if proc.isRunning {
                proc.terminate()
            }
            process = nil
        }

        killStalePID()

        self.isRunning = false
        self.state = .stopped
        self.bootstrapPercentage = 0
        self.statusMessage = "Tor Stopped"
        lock.unlock()
        notifyChange()

        SecurityAuditLogger.shared.recordActivity(
            module: "Tor Daemon",
            action: "Stop Tor Process",
            metadata: "Terminated cleanly"
        )
    }

    private func parseTorOutput(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Bootstrapped ") {
                if let range = line.range(of: "Bootstrapped ") {
                    let substring = line[range.upperBound...]
                    if let percentIndex = substring.firstIndex(of: "%") {
                        let percentStr = substring[..<percentIndex].trimmingCharacters(in: .whitespaces)
                        if let percent = Int(percentStr) {
                            lock.lock()
                            self.bootstrapPercentage = percent
                            if percent >= 100 {
                                self.state = .connected
                                self.statusMessage = "Connected to Onion Network (100%)"
                            } else {
                                self.state = .bootstrapping
                                self.statusMessage = "Connecting: \(percent)%"
                            }
                            lock.unlock()
                            notifyChange()
                        }
                    }
                }
            }
        }
    }

    private func killStalePID() {
        if let pidStr = try? String(contentsOf: torPidFileURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           let pid = pid_t(pidStr), pid > 0 {
            kill(pid, SIGTERM)
            try? FileManager.default.removeItem(at: torPidFileURL)
        }
    }

    private func notifyChange() {
        onStateChange?()
    }
}
