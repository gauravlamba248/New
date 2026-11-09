import SwiftUI

@MainActor
public final class LLMRunnerViewState: ObservableObject {
    @Published public var inputPrompt: String = ""
    @Published public var isShowingSettings: Bool = false

    public init() {}
}

public struct LLMRunnerView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var llmManager = LLMManager.shared
    @ObservedObject private var runnerEngine = LLMRunnerEngine.shared
    @StateObject private var state = LLMRunnerViewState()

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Runner Header & Model Switcher
            topHeaderBar
            Divider()

            // Performance & Hardware HUD Bar
            performanceHUDBar
            Divider()

            // Main Chat Stream or Empty State
            if llmManager.downloadedModels.isEmpty {
                emptyStateNoModelsView
            } else {
                chatStreamView
                Divider()
                quickPromptChips
                promptInputBar
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $state.isShowingSettings) {
            if let model = llmManager.selectedModel {
                LLMModelSettingsSheet(model: model)
            }
        }
    }

    // MARK: - Top Header Bar

    private var topHeaderBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: "terminal.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Model Runner")
                        .font(.system(size: 14, weight: .bold))
                    Text("• In-App Local Inference")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Text("100% offline, zero-latency Apple Silicon Metal GPU acceleration with custom hardware governance.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !llmManager.downloadedModels.isEmpty {
                // Model Selector Picker
                HStack(spacing: 6) {
                    Text("Model:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Picker("", selection: $llmManager.selectedModelId) {
                        ForEach(llmManager.downloadedModels) { m in
                            Text("\(m.name) (\(m.parameterSize))").tag(m.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 220)
                }

                // Per-Model Hardware Settings Button
                Button(action: {
                    state.isShowingSettings = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Hardware Config")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Adjust memory allocation, CPU cores, and context length for this model")

                // Clear Chat Button
                Button(action: {
                    llmManager.clearChat()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Clear conversation")
            }

            // Link to Model Hub
            Button(action: {
                appState.openLLMHub()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text("Model Hub")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.18))
                .foregroundColor(.accentColor)
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Download more models in the Model Hub")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Performance HUD Bar

    private var performanceHUDBar: some View {
        let activeModel = llmManager.selectedModel
        let activeConfig = activeModel != nil ? llmManager.config(for: activeModel!) : nil

        return HStack(spacing: 16) {
            // Generation Speed
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 11))
                Text("Speed:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f tok/s", runnerEngine.liveTokensPerSecond))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Divider()
                .frame(height: 14)

            // Allocated Memory Budget
            HStack(spacing: 5) {
                Image(systemName: "memorychip")
                    .foregroundColor(.blue)
                    .font(.system(size: 11))
                Text("Memory Cap:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("\(activeConfig?.maxMemoryMB ?? 2048) MB")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
            }

            Divider()
                .frame(height: 14)

            // CPU Thread Governance
            HStack(spacing: 5) {
                Image(systemName: "cpu")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text("CPU Cores:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("\(activeConfig?.cpuThreads ?? 4) Cores")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }

            Divider()
                .frame(height: 14)

            // Context Window
            HStack(spacing: 5) {
                Image(systemName: "character.book.closed")
                    .foregroundColor(.orange)
                    .font(.system(size: 11))
                Text("Context:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("\(activeConfig?.contextSize ?? 4096) tokens")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            }

            Spacer()

            // Status Indicator
            HStack(spacing: 5) {
                switch runnerEngine.state {
                case .idle:
                    Circle().fill(Color.secondary).frame(width: 6, height: 6)
                    Text("IDLE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                case .loadingModel:
                    ProgressView().scaleEffect(0.5).frame(width: 8, height: 8)
                    Text("LOADING").font(.system(size: 9, weight: .bold)).foregroundColor(.blue)
                case .generating:
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("GENERATING").font(.system(size: 9, weight: .bold)).foregroundColor(.green)
                case .completed:
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("READY").font(.system(size: 9, weight: .bold)).foregroundColor(.green)
                case .cancelled:
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                    Text("STOPPED").font(.system(size: 9, weight: .bold)).foregroundColor(.orange)
                case .error:
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("ERROR").font(.system(size: 9, weight: .bold)).foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Chat Stream View

    private var chatStreamView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if llmManager.chatMessages.isEmpty {
                        welcomeBanner
                    }

                    ForEach(llmManager.chatMessages) { msg in
                        messageBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: llmManager.chatMessages.count) { _ in
                if let last = llmManager.chatMessages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var welcomeBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 28))
                .foregroundColor(.accentColor.opacity(0.8))
                .padding(.top, 20)

            Text("Aegis In-App Local LLM Runner")
                .font(.system(size: 15, weight: .bold))

            Text("Active Model: \(llmManager.selectedModel?.name ?? "None") • Quantization: \(llmManager.selectedModel?.quantization.shortLabel ?? "Q4_K_M")")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("All tokens generate 100% on your Mac's Apple Silicon Metal GPU with strict memory budget enforcement. Type a prompt below to begin.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func messageBubble(message: LLMChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(12)

                    Text(formatTimestamp(message.timestamp))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Circle()
                    .fill(Color.accentColor.opacity(0.4))
                    .frame(width: 26, height: 26)
                    .overlay(Image(systemName: "person.fill").font(.system(size: 11)).foregroundColor(.accentColor))

            } else if message.role == .assistant {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 26, height: 26)
                    .overlay(Image(systemName: "sparkles").font(.system(size: 11)).foregroundColor(.purple))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(llmManager.selectedModel?.name ?? "Assistant")
                            .font(.system(size: 11, weight: .bold))

                        if let speed = message.tokensPerSecond, speed > 0 {
                            Text(String(format: "• %.1f tok/s", speed))
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.green)
                        }

                        if let duration = message.durationSeconds {
                            Text(String(format: "• %.1fs", duration))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy Response")
                    }

                    if message.content.isEmpty {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                            Text("Thinking & Generating...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                    } else {
                        Text(message.content)
                            .font(.system(size: 13))
                            .lineSpacing(3)
                            .textSelection(.enabled)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06), lineWidth: 1))
                    }
                }

                Spacer(minLength: 40)

            } else {
                // System message
                HStack {
                    Spacer()
                    Text(message.content)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Quick Prompt Chips

    private var quickPromptChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickChip("Explain quantum physics simply")
                quickChip("Write a fast Swift sorting algorithm")
                quickChip("Why is local on-device AI private?")
                quickChip("Summarize how LLM quantization works")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func quickChip(_ text: String) -> some View {
        Button(action: {
            self.state.inputPrompt = text
        }) {
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Prompt Input Bar

    private var promptInputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask anything to local model...", text: $state.inputPrompt)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(10)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                .onSubmit {
                    submitPrompt()
                }

            if case .generating = runnerEngine.state {
                Button(action: {
                    runnerEngine.stopGeneration()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {
                    submitPrompt()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(width: 34, height: 34)
                    .background(state.inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(state.inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func submitPrompt() {
        let text = state.inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        state.inputPrompt = ""

        Task {
            await llmManager.sendMessage(text)
        }
    }

    // MARK: - Empty State (No Models Downloaded)

    private var emptyStateNoModelsView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.purple)
            }

            VStack(spacing: 6) {
                Text("No Local LLM Models Installed Yet")
                    .font(.system(size: 16, weight: .bold))

                Text("Aegis Model Runner requires a local GGUF model to execute inference natively on your Mac. You can browse, discover, and download models with one click.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Button(action: {
                appState.openLLMHub()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Go to LLM Models Hub")
                        .font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        return df.string(from: date)
    }
}
