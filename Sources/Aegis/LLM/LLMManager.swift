import Foundation
import SwiftUI
import Combine

@MainActor
public final class LLMManager: ObservableObject {
    public static let shared = LLMManager()

    @Published public var allModels: [LLMModelItem] = []
    @Published public var configs: [String: LLMModelConfig] = [:]
    @Published public var selectedModelId: String = ""
    @Published public var chatMessages: [LLMChatMessage] = []
    @Published public var isSyncingNewModels: Bool = false
    @Published public var syncErrorMessage: String? = nil
    @Published public var activeSettingsModel: LLMModelItem? = nil

    public let downloadManager = LLMDownloadManager.shared
    public let runnerEngine = LLMRunnerEngine.shared
    private let registry = LLMRegistry.shared

    private var cancellables = Set<AnyCancellable>()

    public init() {
        // Load initial curated models
        self.allModels = registry.getCuratedModels()

        // Load persisted per-model configs from disk
        loadConfigsFromDisk()

        // Select the first downloaded model or the first model
        if let firstDownloaded = downloadedModels.first {
            self.selectedModelId = firstDownloaded.id
        } else if let first = allModels.first {
            self.selectedModelId = first.id
        }

        // Subscribe to download manager updates to refresh model list state
        downloadManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        runnerEngine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Filtered Models

    public var downloadedModels: [LLMModelItem] {
        return allModels.filter { $0.isDownloaded }
    }

    public var selectedModel: LLMModelItem? {
        return allModels.first(where: { $0.id == selectedModelId }) ?? downloadedModels.first
    }

    // MARK: - Per-Model Hardware Configuration Management

    public func config(for model: LLMModelItem) -> LLMModelConfig {
        if let existing = configs[model.id] {
            return existing
        }
        let def = LLMModelConfig.defaultFor(modelId: model.id, parameterSize: model.parameterSize)
        configs[model.id] = def
        saveConfigsToDisk()
        return def
    }

    public func updateConfig(for modelId: String, mutate: (inout LLMModelConfig) -> Void) {
        var current = configs[modelId] ?? LLMModelConfig.defaultFor(modelId: modelId, parameterSize: "1B")
        mutate(&current)
        configs[modelId] = current
        saveConfigsToDisk()
        objectWillChange.send()
    }

    public func saveConfig(_ config: LLMModelConfig) {
        configs[config.modelId] = config
        saveConfigsToDisk()
        objectWillChange.send()
    }

    public func resetConfig(for model: LLMModelItem) {
        let def = LLMModelConfig.defaultFor(modelId: model.id, parameterSize: model.parameterSize)
        configs[model.id] = def
        saveConfigsToDisk()
        objectWillChange.send()
    }

    private var configsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Aegis/LLM", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("configs.json")
    }

    private func saveConfigsToDisk() {
        do {
            let data = try JSONEncoder().encode(configs)
            try data.write(to: configsFileURL, options: .atomic)
        } catch {
            print("Failed to save LLM configs: \(error)")
        }
    }

    private func loadConfigsFromDisk() {
        guard FileManager.default.fileExists(atPath: configsFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: configsFileURL)
            let loaded = try JSONDecoder().decode([String: LLMModelConfig].self, from: data)
            self.configs = loaded
        } catch {
            print("Failed to load LLM configs: \(error)")
        }
    }

    // MARK: - Dynamic Model Discovery

    /// Fetches newly created models from Hugging Face hub in real-time
    public func syncNewModels() async {
        guard !isSyncingNewModels else { return }
        isSyncingNewModels = true
        syncErrorMessage = nil

        do {
            let newModels = try await registry.fetchNewModelsFromHuggingFace(limit: 20)
            for model in newModels {
                if !allModels.contains(where: { $0.id == model.id }) {
                    allModels.append(model)
                }
            }
        } catch {
            syncErrorMessage = "Could not sync new models: \(error.localizedDescription)"
        }

        isSyncingNewModels = false
    }

    // MARK: - Interactive Local Chat & Inference

    public func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let model = selectedModel, model.isDownloaded else {
            chatMessages.append(LLMChatMessage(
                role: .system,
                content: "Please download or select a downloaded model to run inference."
            ))
            return
        }

        let userMsg = LLMChatMessage(role: .user, content: trimmed)
        chatMessages.append(userMsg)

        // Placeholder for streaming assistant response
        let assistantMsgId = UUID()
        let placeholderMsg = LLMChatMessage(id: assistantMsgId, role: .assistant, content: "")
        chatMessages.append(placeholderMsg)

        let modelConfig = config(for: model)
        let startTime = Date()

        do {
            let response = try await runnerEngine.generate(
                model: model,
                config: modelConfig,
                prompt: trimmed
            ) { [weak self] chunk in
                Task { @MainActor in
                    guard let self = self else { return }
                    if let idx = self.chatMessages.firstIndex(where: { $0.id == assistantMsgId }) {
                        self.chatMessages[idx].content += chunk
                    }
                }
            }

            let duration = Date().timeIntervalSince(startTime)
            if let idx = chatMessages.firstIndex(where: { $0.id == assistantMsgId }) {
                chatMessages[idx].content = response
                chatMessages[idx].durationSeconds = duration
                chatMessages[idx].tokensPerSecond = runnerEngine.liveTokensPerSecond
            }
        } catch {
            if let idx = chatMessages.firstIndex(where: { $0.id == assistantMsgId }) {
                chatMessages[idx].content = "⚠️ Inference Error: \(error.localizedDescription)"
            }
        }
    }

    public func clearChat() {
        chatMessages.removeAll()
    }
}
