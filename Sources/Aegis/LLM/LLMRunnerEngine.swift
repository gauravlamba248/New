import Foundation
import Combine

/// Thread-safe accumulator conforming to Swift 6 Sendable requirements
private final class OutputCollector: @unchecked Sendable {
    private var text = ""
    private var tokenCount = 0
    private var isDone = false
    private let lock = NSLock()

    func append(_ chunk: String) -> (accumulated: String, tokens: Int) {
        lock.lock()
        defer { lock.unlock() }
        text += chunk
        tokenCount += max(1, chunk.count / 4)
        return (text, tokenCount)
    }

    func finishOnce(result: Result<String, Error>, handler: (Result<String, Error>) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !isDone else { return }
        isDone = true
        handler(result)
    }

    func getFinalText() -> String {
        lock.lock()
        defer { lock.unlock() }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
public final class LLMRunnerEngine: ObservableObject {
    public static let shared = LLMRunnerEngine()

    @Published public var state: LLMRunnerState = .idle
    @Published public var activeModelName: String = ""
    @Published public var liveTokensPerSecond: Double = 0.0
    @Published public var totalTokensGenerated: Int = 0
    @Published public var currentOutputText: String = ""
    @Published public var estimatedMemoryUsedMB: Double = 0.0

    private var activeProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var startTime: Date?

    public init() {}

    /// Locates the local standalone llama/aegis LLM engine binary
    public static func findLlamaBinary() -> String? {
        var bundleCandidates: [String] = []
        if let res = Bundle.main.resourceURL?.appendingPathComponent("bin/aegis-llm-engine").path {
            bundleCandidates.append(res)
        }
        bundleCandidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/bin/aegis-llm-engine").path)
        bundleCandidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/aegis-llm-engine").path)

        for path in bundleCandidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallbacks for direct development / CLI invocation
        let fallbackCandidates = [
            "/opt/homebrew/bin/llama-cli",
            "/usr/local/bin/llama-cli",
            "/usr/bin/llama-cli"
        ]
        for path in fallbackCandidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// Calculates optimal Metal GPU offload layers based on model size and user's max memory allocation
    public static func calculateGPULayers(config: LLMModelConfig, modelFileSizeBytes: Int64) -> Int {
        let modelMB = Double(modelFileSizeBytes) / (1024 * 1024)

        // If the user's allocated memory is less than model size, limit GPU layers to prevent VRAM overflow
        if Double(config.maxMemoryMB) < modelMB * 0.8 {
            return 0 // Keep strictly on CPU
        } else if Double(config.maxMemoryMB) < modelMB * 1.5 {
            return min(config.gpuOffloadLayers, 16) // Partial Metal offload
        } else {
            return min(config.gpuOffloadLayers, 99) // Full Apple Silicon Metal acceleration
        }
    }

    /// Executes generation locally inside the app using user-customized hardware settings
    public func generate(
        model: LLMModelItem,
        config: LLMModelConfig,
        prompt: String,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        // Stop any running generation
        stopGeneration()

        guard let binaryPath = Self.findLlamaBinary() else {
            let err = "llama-cli engine not found. Please install llama.cpp via Homebrew or bundle."
            self.state = .error(err)
            throw NSError(domain: "LLMRunner", code: 404, userInfo: [NSLocalizedDescriptionKey: err])
        }

        guard FileManager.default.fileExists(atPath: model.localFileURL.path) else {
            let err = "Model file does not exist locally: \(model.fileName)"
            self.state = .error(err)
            throw NSError(domain: "LLMRunner", code: 404, userInfo: [NSLocalizedDescriptionKey: err])
        }

        self.activeModelName = model.name
        self.state = .loadingModel(model.name)
        self.liveTokensPerSecond = 0.0
        self.totalTokensGenerated = 0
        self.currentOutputText = ""
        self.estimatedMemoryUsedMB = min(Double(config.maxMemoryMB), Double(model.fileSizeBytes) / (1024 * 1024) * 1.2)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)

        let calculatedNGL = Self.calculateGPULayers(config: config, modelFileSizeBytes: model.fileSizeBytes)

        // Build hardware & inference arguments
        let args: [String] = [
            "-m", model.localFileURL.path,
            "-p", prompt,
            "-t", "\(max(1, config.cpuThreads))",
            "-c", "\(max(512, config.contextSize))",
            "-ngl", "\(calculatedNGL)",
            "--temp", String(format: "%.2f", config.temperature),
            "--top-p", String(format: "%.2f", config.topP),
            "-st", // single turn
            "--no-display-prompt", // stream generated response only
            "--log-disable", // suppress debug header logs
            "--simple-io"
        ]

        process.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        self.activeProcess = process
        self.outputPipe = outPipe
        self.errorPipe = errPipe
        self.startTime = Date()

        let collector = OutputCollector()
        let genStartTime = Date()

        return try await withCheckedThrowingContinuation { continuation in
            let continuationGate = ContinuationGate()

            outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                guard let textChunk = String(data: data, encoding: .utf8) else { return }

                let (accumulated, totalTokens) = collector.append(textChunk)

                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.currentOutputText = accumulated
                    self.totalTokensGenerated = totalTokens

                    let elapsed = Date().timeIntervalSince(genStartTime)
                    if elapsed > 0.1 {
                        self.liveTokensPerSecond = Double(totalTokens) / elapsed
                    }

                    self.state = .generating(
                        tokensGenerated: totalTokens,
                        currentSpeed: self.liveTokensPerSecond
                    )

                    onToken(textChunk)
                }
            }

            process.terminationHandler = { [weak self] proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil

                // Read any remainder
                let remainingData = outPipe.fileHandleForReading.readDataToEndOfFile()
                if let rem = String(data: remainingData, encoding: .utf8), !rem.isEmpty {
                    _ = collector.append(rem)
                }

                let cleaned = collector.getFinalText()

                collector.finishOnce(result: proc.terminationStatus == 0 || !cleaned.isEmpty ? .success(cleaned) : .failure(NSError(domain: "LLMRunner", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Process exited with status \(proc.terminationStatus)"]))) { result in
                    continuationGate.once {
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let output):
                                self?.state = .completed
                                continuation.resume(returning: output)
                            case .failure(let error):
                                self?.state = .error(error.localizedDescription)
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                }

                DispatchQueue.main.async {
                    self?.activeProcess = nil
                    self?.outputPipe = nil
                    self?.errorPipe = nil
                }
            }

            do {
                try process.run()
            } catch {
                continuationGate.once {
                    DispatchQueue.main.async {
                        self.state = .error(error.localizedDescription)
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Stops any actively running generation immediately
    public func stopGeneration() {
        if let proc = activeProcess, proc.isRunning {
            proc.terminate()
        }
        activeProcess = nil
        outputPipe = nil
        errorPipe = nil
        state = .cancelled
    }
}
