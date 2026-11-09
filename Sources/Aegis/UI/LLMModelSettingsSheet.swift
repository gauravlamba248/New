import SwiftUI

@MainActor
public final class LLMModelSettingsState: ObservableObject {
    @Published public var maxMemoryMB: Double
    @Published public var cpuThreads: Double
    @Published public var quantization: QuantizationType
    @Published public var contextSize: Double
    @Published public var temperature: Double
    @Published public var topP: Double

    public init(config: LLMModelConfig) {
        self.maxMemoryMB = Double(config.maxMemoryMB)
        self.cpuThreads = Double(config.cpuThreads)
        self.quantization = config.quantization
        self.contextSize = Double(config.contextSize)
        self.temperature = config.temperature
        self.topP = config.topP
    }
}

public struct LLMModelSettingsSheet: View {
    public let model: LLMModelItem
    @ObservedObject private var llmManager = LLMManager.shared
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var state: LLMModelSettingsState

    private let maxCores: Int = ProcessInfo.processInfo.activeProcessorCount
    private let totalSystemRAM_MB: Int = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))

    public init(model: LLMModelItem) {
        self.model = model
        let currentConfig = LLMManager.shared.config(for: model)
        _state = StateObject(wrappedValue: LLMModelSettingsState(config: currentConfig))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.purple.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.name) — Hardware Governance")
                        .font(.system(size: 13, weight: .bold))
                    Text("Per-model memory cap, CPU allocation, quantization & context length")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Section 1: Memory Allocation (RAM / VRAM Cap)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "memorychip")
                                .foregroundColor(.blue)
                            Text("Memory Provider (RAM / VRAM Allocation)")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text(formatMemory(Int(state.maxMemoryMB)))
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(.blue)
                        }

                        Slider(
                            value: $state.maxMemoryMB,
                            in: 512...Double(min(32768, totalSystemRAM_MB)),
                            step: 256
                        )
                        .accentColor(.blue)

                        HStack {
                            Text("Min: 512 MB")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("System Total: \(formatMemory(totalSystemRAM_MB))")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                        Text("Aegis dynamically governs Apple Silicon Metal GPU offload layers to ensure execution stays strictly within your selected \(formatMemory(Int(state.maxMemoryMB))) allocation limit.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.06))
                    .cornerRadius(8)

                    // Section 2: CPU Threads Allocation
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.green)
                            Text("CPU Threads Allocation")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text("\(Int(state.cpuThreads)) Cores")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(.green)
                        }

                        Slider(
                            value: $state.cpuThreads,
                            in: 1...Double(maxCores),
                            step: 1
                        )
                        .accentColor(.green)

                        HStack {
                            Text("1 Core (Low Power)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(maxCores) Cores (Maximum Speed)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                        Text("Dedicate exact CPU cores to this model. Keep lower for quiet background tasks or higher for maximum generation throughput.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.06))
                    .cornerRadius(8)

                    // Section 3: Quantization Mode
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "square.3.layers.3d.down.right")
                                .foregroundColor(.purple)
                            Text("Quantization Mode")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text(state.quantization.shortLabel)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.18))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }

                        Picker("", selection: $state.quantization) {
                            ForEach(QuantizationType.allCases) { q in
                                Text(q.rawValue).tag(q)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()

                        Text(state.quantization.description)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.purple.opacity(0.06))
                    .cornerRadius(8)

                    // Section 4: Context Window Size
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "character.book.closed")
                                .foregroundColor(.orange)
                            Text("Context Window Size")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text("\(Int(state.contextSize)) tokens")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(.orange)
                        }

                        Slider(
                            value: $state.contextSize,
                            in: 1024...8192,
                            step: 1024
                        )
                        .accentColor(.orange)

                        HStack {
                            Text("1024 (Minimal RAM)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("8192 (Long Context)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.06))
                    .cornerRadius(8)

                    // Section 5: Creativity & Sampling
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sampling & Creativity Parameters")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack {
                            Text("Temperature: \(String(format: "%.2f", state.temperature))")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                            Slider(value: $state.temperature, in: 0.0...1.2, step: 0.05)
                                .frame(width: 180)
                        }

                        HStack {
                            Text("Top-P: \(String(format: "%.2f", state.topP))")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                            Slider(value: $state.topP, in: 0.1...1.0, step: 0.05)
                                .frame(width: 180)
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
                }
                .padding(16)
            }

            Divider()

            // Footer Buttons
            HStack {
                Button("Reset Defaults") {
                    let def = LLMModelConfig.defaultFor(modelId: model.id, parameterSize: model.parameterSize)
                    state.maxMemoryMB = Double(def.maxMemoryMB)
                    state.cpuThreads = Double(def.cpuThreads)
                    state.quantization = def.quantization
                    state.contextSize = Double(def.contextSize)
                    state.temperature = def.temperature
                    state.topP = def.topP
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

                Spacer()

                Button("Save Settings") {
                    let updatedConfig = LLMModelConfig(
                        modelId: model.id,
                        maxMemoryMB: Int(state.maxMemoryMB),
                        cpuThreads: Int(state.cpuThreads),
                        quantization: state.quantization,
                        contextSize: Int(state.contextSize),
                        temperature: state.temperature,
                        topP: state.topP
                    )
                    llmManager.saveConfig(updatedConfig)
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(6)
                .font(.system(size: 12, weight: .bold))
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 480, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func formatMemory(_ mb: Int) -> String {
        if mb >= 1024 {
            let gb = Double(mb) / 1024.0
            return String(format: "%.1f GB", gb)
        } else {
            return "\(mb) MB"
        }
    }
}
