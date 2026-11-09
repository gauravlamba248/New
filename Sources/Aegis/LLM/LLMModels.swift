import Foundation

/// Supported Quantization profiles for local LLMs
public enum QuantizationType: String, CaseIterable, Codable, Identifiable, Sendable {
    case q4_k_m = "Q4_K_M (Balanced - Recommended)"
    case q4_0 = "Q4_0 (Fastest 4-bit)"
    case q5_k_m = "Q5_K_M (High Quality 5-bit)"
    case q8_0 = "Q8_0 (Near Lossless 8-bit)"
    case fp16 = "FP16 (Full Precision 16-bit)"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .q4_k_m: return "Q4_K_M"
        case .q4_0: return "Q4_0"
        case .q5_k_m: return "Q5_K_M"
        case .q8_0: return "Q8_0"
        case .fp16: return "FP16"
        }
    }

    public var description: String {
        switch self {
        case .q4_k_m: return "Optimal balance of high response quality, low memory footprint and high generation speed."
        case .q4_0: return "Lowest memory overhead and maximum generation speed."
        case .q5_k_m: return "Higher mathematical and coding fidelity with slight memory overhead."
        case .q8_0: return "Near-lossless precision for critical reasoning tasks."
        case .fp16: return "Full 16-bit uncompressed floating point precision."
        }
    }
}

/// Category classification for LLM models
public enum LLMCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case all = "All Models"
    case ultraLight = "Ultra-Light (<1GB)"
    case balanced = "Balanced (1-3GB)"
    case reasoning = "Reasoning & Math"
    case coding = "Code & Tech"
    case newReleases = "New Releases"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .ultraLight: return "bolt.fill"
        case .balanced: return "scale.3d"
        case .reasoning: return "brain.head.profile"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .newReleases: return "sparkles"
        }
    }
}

/// Per-model hardware resource allocation and inference configuration
public struct LLMModelConfig: Codable, Equatable, Sendable {
    public var modelId: String
    /// Maximum RAM/VRAM budget allocated by the user in Megabytes (e.g. 1024, 2048, 4096)
    public var maxMemoryMB: Int
    /// Number of CPU threads/cores dedicated to this model (1 to physical core count)
    public var cpuThreads: Int
    /// Desired quantization mode
    public var quantization: QuantizationType
    /// Context window size in tokens (e.g. 2048, 4096, 8192)
    public var contextSize: Int
    /// Sampling temperature (0.0 = deterministic, 1.0 = highly creative)
    public var temperature: Double
    /// Nucleus top-p sampling
    public var topP: Double
    /// Metal GPU offload layers (calculated dynamically based on maxMemoryMB or customized)
    public var gpuOffloadLayers: Int

    public init(
        modelId: String,
        maxMemoryMB: Int = 2048,
        cpuThreads: Int = max(2, ProcessInfo.processInfo.processorCount / 2),
        quantization: QuantizationType = .q4_k_m,
        contextSize: Int = 4096,
        temperature: Double = 0.7,
        topP: Double = 0.9,
        gpuOffloadLayers: Int = 99
    ) {
        self.modelId = modelId
        self.maxMemoryMB = maxMemoryMB
        self.cpuThreads = cpuThreads
        self.quantization = quantization
        self.contextSize = contextSize
        self.temperature = temperature
        self.topP = topP
        self.gpuOffloadLayers = gpuOffloadLayers
    }

    public static func defaultFor(modelId: String, parameterSize: String) -> LLMModelConfig {
        let totalRAM_MB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
        let availableThreads = ProcessInfo.processInfo.activeProcessorCount
        let targetThreads = max(2, min(availableThreads, 4))

        if parameterSize.contains("0.3") || parameterSize.contains("0.5") || parameterSize.contains("360M") {
            return LLMModelConfig(
                modelId: modelId,
                maxMemoryMB: min(1024, totalRAM_MB / 4),
                cpuThreads: targetThreads,
                quantization: .q4_k_m,
                contextSize: 2048,
                temperature: 0.7,
                topP: 0.9,
                gpuOffloadLayers: 99
            )
        } else if parameterSize.contains("1") || parameterSize.contains("1.5") || parameterSize.contains("1.7") {
            return LLMModelConfig(
                modelId: modelId,
                maxMemoryMB: min(2048, totalRAM_MB / 3),
                cpuThreads: targetThreads,
                quantization: .q4_k_m,
                contextSize: 4096,
                temperature: 0.7,
                topP: 0.9,
                gpuOffloadLayers: 99
            )
        } else {
            return LLMModelConfig(
                modelId: modelId,
                maxMemoryMB: min(4096, totalRAM_MB / 2),
                cpuThreads: targetThreads,
                quantization: .q4_k_m,
                contextSize: 4096,
                temperature: 0.7,
                topP: 0.9,
                gpuOffloadLayers: 99
            )
        }
    }
}

/// Download status for a model
public enum DownloadStatus: Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double, speedMBs: Double, downloadedBytes: Int64, totalBytes: Int64)
    case paused
    case ready
    case error(String)
}

/// An open-weights LLM model available in Aegis Model Hub
public struct LLMModelItem: Identifiable, Codable, Sendable {
    public var id: String
    public var name: String
    public var creator: String
    public var category: LLMCategory
    public var parameterSize: String
    public var quantization: QuantizationType
    public var fileSizeBytes: Int64
    public var downloadURL: URL
    public var fileName: String
    public var isNewRelease: Bool
    public var description: String
    public var tags: [String]
    public var lastModified: Date?

    public init(
        id: String,
        name: String,
        creator: String,
        category: LLMCategory,
        parameterSize: String,
        quantization: QuantizationType,
        fileSizeBytes: Int64,
        downloadURL: URL,
        fileName: String,
        isNewRelease: Bool = false,
        description: String,
        tags: [String] = [],
        lastModified: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.creator = creator
        self.category = category
        self.parameterSize = parameterSize
        self.quantization = quantization
        self.fileSizeBytes = fileSizeBytes
        self.downloadURL = downloadURL
        self.fileName = fileName
        self.isNewRelease = isNewRelease
        self.description = description
        self.tags = tags
        self.lastModified = lastModified
    }

    public var localFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Aegis/LLM/Models", isDirectory: true)
        return dir.appendingPathComponent(fileName)
    }

    public var isDownloaded: Bool {
        return FileManager.default.fileExists(atPath: localFileURL.path)
    }

    public var formattedFileSize: String {
        let mb = Double(fileSizeBytes) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}

/// Roles for in-app chat interactions
public enum LLMRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

/// Single message in the local runner chat stream
public struct LLMChatMessage: Identifiable, Codable, Sendable {
    public var id: UUID
    public var role: LLMRole
    public var content: String
    public var timestamp: Date
    public var tokensPerSecond: Double?
    public var durationSeconds: Double?

    public init(
        id: UUID = UUID(),
        role: LLMRole,
        content: String,
        timestamp: Date = Date(),
        tokensPerSecond: Double? = nil,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.tokensPerSecond = tokensPerSecond
        self.durationSeconds = durationSeconds
    }
}

/// Operational state of the in-app local LLM runner
public enum LLMRunnerState: Equatable, Sendable {
    case idle
    case loadingModel(String)
    case generating(tokensGenerated: Int, currentSpeed: Double)
    case completed
    case cancelled
    case error(String)
}
