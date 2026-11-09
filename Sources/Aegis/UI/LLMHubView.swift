import SwiftUI

@MainActor
public final class LLMHubViewState: ObservableObject {
    @Published public var searchText: String = ""
    @Published public var selectedCategory: LLMCategory = .all
    @Published public var configuringModel: LLMModelItem? = nil

    public init() {}
}

public struct LLMHubView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var llmManager = LLMManager.shared
    @ObservedObject private var downloadManager = LLMDownloadManager.shared
    @StateObject private var state = LLMHubViewState()

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            Divider()

            // Filter Chips & Search Bar
            filterAndSearchBar
            Divider()

            // Content Area: Grid of Models
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let syncErr = llmManager.syncErrorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text(syncErr)
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(6)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 330, maximum: 440), spacing: 14)], spacing: 14) {
                        ForEach(filteredModels) { model in
                            modelCard(model: model)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(item: $state.configuringModel) { model in
            LLMModelSettingsSheet(model: model)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.8), Color.indigo.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("LLM Model Hub")
                        .font(.system(size: 14, weight: .bold))
                    Text("• In-App Downloads & Discovery")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Text("Explore local open-weights LLMs. Newly created models appear here dynamically via live Hugging Face sync.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Dynamic Sync Button: Fetches newly created models from Hugging Face
            Button(action: {
                Task {
                    await llmManager.syncNewModels()
                }
            }) {
                HStack(spacing: 6) {
                    if llmManager.isSyncingNewModels {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                        Text("Syncing Models...")
                            .font(.system(size: 11, weight: .bold))
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                        Text("Check for New Models")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.18))
                .foregroundColor(.purple)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(llmManager.isSyncingNewModels)
            .help("Query Hugging Face for newly created and released GGUF models")

            // Go to Runner button
            Button(action: {
                appState.openLLMRunner()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "play.circle.fill")
                    Text("Model Runner")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Switch to the in-app Model Runner")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Filter and Search Bar

    private var filterAndSearchBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("Search LLM models by name, creator, tags...", text: $state.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))

                if !state.searchText.isEmpty {
                    Button(action: { state.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 260)

            Divider()
                .frame(height: 18)

            // Category Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(LLMCategory.allCases) { cat in
                        Button(action: {
                            self.state.selectedCategory = cat
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 10))
                                Text(cat.rawValue)
                                    .font(.system(size: 11, weight: state.selectedCategory == cat ? .bold : .medium))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(state.selectedCategory == cat ? Color.accentColor : Color.secondary.opacity(0.12))
                            .foregroundColor(state.selectedCategory == cat ? .white : .primary)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Model Card

    private func modelCard(model: LLMModelItem) -> some View {
        let isDownloaded = model.isDownloaded
        let status = downloadManager.status(for: model.id)
        let config = llmManager.config(for: model)

        return VStack(alignment: .leading, spacing: 10) {
            // Card Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(model.name)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)

                        if model.isNewRelease {
                            Text("NEW")
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.pink)
                                .foregroundColor(.white)
                                .cornerRadius(3)
                        }
                    }

                    Text("By \(model.creator) • \(model.parameterSize)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Parameter Size Badge
                Text(model.parameterSize)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }

            // Description
            Text(model.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(minHeight: 28, alignment: .topLeading)

            // Hardware Specs Badges
            HStack(spacing: 6) {
                // Quantization
                HStack(spacing: 3) {
                    Image(systemName: "square.3.layers.3d.down.right")
                        .font(.system(size: 9))
                    Text(model.quantization.shortLabel)
                        .font(.system(size: 9, weight: .semibold))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)

                // File Size
                HStack(spacing: 3) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 9))
                    Text(model.formattedFileSize)
                        .font(.system(size: 9, weight: .semibold))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)

                // Memory Allocation Budget
                HStack(spacing: 3) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 9))
                    Text("\(config.maxMemoryMB)MB RAM")
                        .font(.system(size: 9, weight: .semibold))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .cornerRadius(4)

                // CPU Threads
                HStack(spacing: 3) {
                    Image(systemName: "cpu")
                        .font(.system(size: 9))
                    Text("\(config.cpuThreads)C")
                        .font(.system(size: 9, weight: .semibold))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.12))
                .foregroundColor(.green)
                .cornerRadius(4)
            }

            // Live Download Progress Bar if downloading
            if case .downloading(let progress, let speed, let downloaded, let total) = status {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)

                    HStack {
                        Text(String(format: "%.1f%% • %.1f MB/s", progress * 100.0, speed))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.accentColor)
                        Spacer()
                        Text("\(formatBytes(downloaded)) / \(formatBytes(total))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(6)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(6)
            }

            Divider()

            // Card Bottom Actions
            HStack {
                if isDownloaded {
                    // Ready state badge
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 11))
                        Text("Installed")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    }

                    Spacer()

                    // Configure Hardware Button
                    Button(action: {
                        self.state.configuringModel = model
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Hardware")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Customize memory, CPU threads & quantization for this model")

                    // Open in Runner Button
                    Button(action: {
                        llmManager.selectedModelId = model.id
                        appState.openLLMRunner()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                            Text("Run")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                } else {
                    // Not downloaded state
                    if case .downloading = status {
                        Button(action: {
                            downloadManager.cancelDownload(for: model.id)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle")
                                Text("Cancel")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Hardware settings can also be pre-configured before downloading
                        Button(action: {
                            self.state.configuringModel = model
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "slider.horizontal.3")
                                Text("Hardware")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help("Pre-configure hardware allocation (RAM, CPU, context) before downloading")

                        Spacer()

                        Button(action: {
                            downloadManager.startDownload(model: model)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Download (\(model.formattedFileSize))")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDownloaded ? Color.green.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var filteredModels: [LLMModelItem] {
        var list = llmManager.allModels

        if state.selectedCategory != .all {
            switch state.selectedCategory {
            case .ultraLight:
                list = list.filter { $0.category == .ultraLight || $0.fileSizeBytes < 500_000_000 }
            case .balanced:
                list = list.filter { $0.category == .balanced }
            case .reasoning:
                list = list.filter { $0.category == .reasoning }
            case .coding:
                list = list.filter { $0.category == .coding }
            case .newReleases:
                list = list.filter { $0.isNewRelease || $0.category == .newReleases }
            default:
                break
            }
        }

        if !state.searchText.isEmpty {
            let q = state.searchText.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(q) ||
                $0.creator.lowercased().contains(q) ||
                $0.description.lowercased().contains(q) ||
                $0.tags.contains(where: { $0.lowercased().contains(q) })
            }
        }

        return list
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}
