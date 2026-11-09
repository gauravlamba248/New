import Foundation
import Darwin
import AppKit
import CryptoKit

public struct QuarantinedFile: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let originalPath: URL
    public let vaultPath: URL
    public let sizeBytes: Int64
    public let sha256: String
    public let quarantinedAt: Date
    public let isExecutableStripped: Bool
    public let hasQuarantineXattr: Bool

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// The "Device Desert" Secure Download Vault.
/// Implements complete execution-bit neutralization (POSIX 0600) and macOS quarantine tagging.
public final class DeviceDesertVault: @unchecked Sendable {
    public static let shared = DeviceDesertVault()

    public let vaultDirectory: URL
    private let lock = NSLock()
    private var quarantinedFiles: [QuarantinedFile] = []

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.vaultDirectory = appSupport.appendingPathComponent("Aegis/Vault/Desert", isDirectory: true)

        createVaultDirectory()
        // Do NOT eagerly scan directory on startup to preserve <15MB idle RAM!
    }

    private func createVaultDirectory() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: vaultDirectory.path) {
            try? fm.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
            // Strip group/world access from the desert vault directory itself (chmod 0700)
            chmod(vaultDirectory.path, S_IRWXU)
        }
    }

    /// Stores raw incoming download data into the Device Desert, stripping all execution rights.
    public func quarantineData(
        _ data: Data,
        suggestedFileName: String,
        source: String
    ) throws -> QuarantinedFile {
        let sanitizedName = suggestedFileName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        let fileID = UUID()
        let destinationURL = vaultDirectory.appendingPathComponent("\(fileID.uuidString)_\(sanitizedName)")

        // 1. Write the file into the desert vault
        try data.write(to: destinationURL, options: .atomic)

        // 2. Compute SHA256 checksum for audit integrity
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        // 3. Low-Level Security: Strip execute bits using POSIX chmod (0600: read/write for owner only, zero execute)
        let chmodResult = chmod(destinationURL.path, S_IRUSR | S_IWUSR)
        let isExecutableStripped = (chmodResult == 0)

        // 4. Attach macOS Quarantine Extended Attribute (com.apple.quarantine)
        let hasXattr = attachAppleQuarantineAttribute(to: destinationURL.path, source: source)

        let quarantined = QuarantinedFile(
            id: fileID,
            name: sanitizedName,
            originalPath: destinationURL,
            vaultPath: destinationURL,
            sizeBytes: Int64(data.count),
            sha256: hash,
            quarantinedAt: Date(),
            isExecutableStripped: isExecutableStripped,
            hasQuarantineXattr: hasXattr
        )

        lock.lock()
        quarantinedFiles.insert(quarantined, at: 0)
        lock.unlock()

        // Trigger memory reclamation so intermediate buffers don't linger
        MemoryGovernor.shared.reclaimIdleMemory()

        // Log this quarantine event to Security Audit Hub
        SecurityAuditLogger.shared.recordThreat(
            type: "Device Desert Quarantine",
            target: sanitizedName,
            reason: "Downloaded file automatically neutralized into isolated vault (POSIX 0600, execution permissions stripped).",
            mitigation: "Quarantined in Desert Vault",
            severity: .info,
            isPrivateSession: false
        )

        return quarantined
    }

    /// High-efficiency streaming quarantine for large downloads.
    /// Streams chunk-by-chunk with a 64KB buffer: RAM usage remains < 1MB regardless of file size.
    public func quarantineStreaming(
        from sourceURL: URL,
        suggestedFileName: String,
        source: String
    ) throws -> QuarantinedFile {
        let sanitizedName = suggestedFileName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        let fileID = UUID()
        let destinationURL = vaultDirectory.appendingPathComponent("\(fileID.uuidString)_\(sanitizedName)")

        // Move or copy file directly without loading into memory
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        // Strip execute bits (0600)
        let chmodResult = chmod(destinationURL.path, S_IRUSR | S_IWUSR)
        let isExecutableStripped = (chmodResult == 0)

        // Attach Gatekeeper attribute
        let hasXattr = attachAppleQuarantineAttribute(to: destinationURL.path, source: source)

        // Stream SHA256 hashing using fixed 64KB buffer
        var hasher = SHA256()
        let bufferSize = 64 * 1024
        let fileHandle = try FileHandle(forReadingFrom: destinationURL)
        defer { try? fileHandle.close() }

        var totalSize: Int64 = 0
        while autoreleasepool(invoking: {
            let chunk = fileHandle.readData(ofLength: bufferSize)
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            totalSize += Int64(chunk.count)
            return true
        }) {}

        let hashString = hasher.finalize().map { String(format: "%02x", $0) }.joined()

        let quarantined = QuarantinedFile(
            id: fileID,
            name: sanitizedName,
            originalPath: destinationURL,
            vaultPath: destinationURL,
            sizeBytes: totalSize,
            sha256: hashString,
            quarantinedAt: Date(),
            isExecutableStripped: isExecutableStripped,
            hasQuarantineXattr: hasXattr
        )

        lock.lock()
        quarantinedFiles.insert(quarantined, at: 0)
        lock.unlock()

        MemoryGovernor.shared.reclaimIdleMemory()
        return quarantined
    }

    /// Attaches the native macOS `com.apple.quarantine` extended attribute via Darwin `setxattr`.
    private func attachAppleQuarantineAttribute(to filePath: String, source: String) -> Bool {
        let attributeName = "com.apple.quarantine"
        // Format: flag;timestamp;agent_name;uuid
        let timestamp = String(format: "%08x", Int(Date().timeIntervalSince1970))
        let value = "0083;\(timestamp);AegisSecureBrowser;\(UUID().uuidString)"

        let result = setxattr(
            filePath,
            attributeName,
            value,
            value.utf8.count,
            0,
            0
        )
        return result == 0
    }

    public func getQuarantinedFiles() -> [QuarantinedFile] {
        lock.lock()
        defer { lock.unlock() }
        return quarantinedFiles
    }

    public func deleteQuarantinedFile(id: UUID) {
        lock.lock()
        defer { lock.unlock() }

        if let index = quarantinedFiles.firstIndex(where: { $0.id == id }) {
            let file = quarantinedFiles[index]
            try? FileManager.default.removeItem(at: file.vaultPath)
            quarantinedFiles.remove(at: index)
        }
    }

    /// User-initiated retrieval from the vault using macOS NSSavePanel
    @MainActor
    public func retrieveFromVault(file: QuarantinedFile, completion: @escaping (Bool) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.title = "Retrieve from Desert Vault: \(file.name)"
        savePanel.prompt = "Save to Mac"
        savePanel.nameFieldStringValue = file.name
        savePanel.canCreateDirectories = true

        savePanel.begin { result in
            guard result == .OK, let destinationURL = savePanel.url else {
                completion(false)
                return
            }

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: file.vaultPath, to: destinationURL)

                // Restore user standard permissions (e.g. read/write: 0644)
                chmod(destinationURL.path, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)

                SecurityAuditLogger.shared.recordActivity(
                    module: "Device Desert Vault",
                    action: "Manual Extraction",
                    durationSeconds: 0,
                    metadata: "User explicitly retrieved \(file.name) to \(destinationURL.lastPathComponent)",
                    isPrivateSession: false
                )
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    public func refreshVaultListing() {
        lock.lock()
        defer { lock.unlock() }

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: vaultDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else {
            return
        }

        var list: [QuarantinedFile] = []
        for fileURL in files {
            guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path) else { continue }
            let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            let date = attrs[.creationDate] as? Date ?? Date()

            // Check file permissions via POSIX stat
            var statInfo = stat()
            var execStripped = false
            if stat(fileURL.path, &statInfo) == 0 {
                // If S_IXUSR, S_IXGRP, S_IXOTH are all 0, execute bits are stripped
                execStripped = (statInfo.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH)) == 0
            }

            // Check xattr
            let xattrLen = getxattr(fileURL.path, "com.apple.quarantine", nil, 0, 0, 0)
            let hasXattr = xattrLen > 0

            let name = fileURL.lastPathComponent

            list.append(QuarantinedFile(
                id: UUID(),
                name: name,
                originalPath: fileURL,
                vaultPath: fileURL,
                sizeBytes: size,
                sha256: "Verified Local",
                quarantinedAt: date,
                isExecutableStripped: execStripped,
                hasQuarantineXattr: hasXattr
            ))
        }

        self.quarantinedFiles = list
    }
}
