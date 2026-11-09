import SwiftUI

@MainActor
public final class DataCollectorViewState: ObservableObject {
    @Published public var customPromptInput: String = ""
    @Published public var isViewingRawPayload: Bool = false
    @Published public var selectedRawItem: RawWebsiteData? = nil
    @Published public var selectedMetricLineage: MetricLineageRecord? = nil

    public init() {}
}

public struct DataCollectorView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var manager = DataCollectorManager.shared
    @ObservedObject private var llmManager = LLMManager.shared
    @StateObject private var state = DataCollectorViewState()

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            Divider()

            // Query Input & Extraction Governance Controls
            queryAndControlsBar
            Divider()

            // Quick Query Starter Chips
            quickQueryChipsBar
            Divider()

            // Execution Progress HUD
            if manager.state != .idle {
                pipelineHUDView
                Divider()
            }

            // Results Content Area (Tabbed: Sorted Dossier, Gathered Data, Raw Archive, Source Ledger & Lineage)
            if let dossier = manager.activeDossier {
                resultsContainerView(dossier: dossier)
            } else {
                emptyStateWelcomeView
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(item: $state.selectedRawItem) { item in
            rawPayloadDetailSheet(item: item)
        }
        .sheet(item: $state.selectedMetricLineage) { item in
            metricLineageDetailSheet(item: item)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.teal.opacity(0.8), Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: "square.stack.3d.forward.dottedline.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Data Collector & Deep Intel")
                        .font(.system(size: 14, weight: .bold))
                    Text("• Strict Non-Substitution & Traceable Lineage")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Text("Entity-scoped multi-source extraction with transparent source ledger, quality scoring, and zero synthetic fallbacks.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if manager.activeDossier != nil {
                Button(action: {
                    manager.clear()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("New Search")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Query Input and Controls Bar

    private var queryAndControlsBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Main Query Input Field with Search Button
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))

                    TextField("Enter company, stock, brand, or project (e.g. financial analysis of Ford, Boeing, Kubernetes, Stripe)...", text: $manager.queryInputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit {
                            submitQuery()
                        }

                    if !manager.queryInputText.isEmpty {
                        Button(action: { manager.queryInputText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.12), lineWidth: 1))

                Button(action: {
                    submitQuery()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.pull")
                        Text("Collect & Sort")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(manager.queryInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(manager.queryInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // Options Bar: Website Limit & Use LLM Toggle
            HStack(spacing: 16) {
                // 1. Websites Limit Selector
                HStack(spacing: 6) {
                    Text("Collect from:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    Picker("", selection: $manager.selectedWebsiteCount) {
                        ForEach(WebsiteCollectionCount.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 150)
                }

                Divider()
                    .frame(height: 16)

                // 2. Use LLM Toggle
                Toggle(isOn: $manager.useLLM) {
                    HStack(spacing: 5) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(manager.useLLM ? .purple : .secondary)
                            .font(.system(size: 11))
                        Text("Use Local LLM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(manager.useLLM ? .primary : .secondary)
                    }
                }
                .toggleStyle(.checkbox)

                Spacer()
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Quick Query Chips Bar

    private var quickQueryChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Try:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                chipButton("financial analysis of Ford")
                chipButton("financial analysis of Tesla")
                chipButton("financial analysis of Boeing")
                chipButton("financial analysis of Pfizer")
                chipButton("financial analysis of Stripe")
                chipButton("Analyze Kubernetes project")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func chipButton(_ text: String) -> some View {
        Button(action: {
            manager.queryInputText = text
            submitQuery()
        }) {
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pipeline HUD View

    private var pipelineHUDView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                if manager.state == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                } else if case .entityUnverified = manager.state {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                }

                Text(manager.state.statusDescription)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(manager.state == .completed ? .green : .primary)

                Spacer()

                if let dossier = manager.activeDossier {
                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Text("Websites:")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(dossier.websitesVisitedCount)")
                                .font(.system(size: 10, weight: .bold))
                        }

                        HStack(spacing: 3) {
                            Text("Raw Extracted:")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(formatBytes(dossier.rawBytesExtracted))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.blue)
                        }

                        if let eq = dossier.evidenceQuality {
                            HStack(spacing: 3) {
                                Text("Quality:")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(eq.overallEvidenceStatus.rawValue)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(eq.overallEvidenceStatus == .high ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                    .foregroundColor(eq.overallEvidenceStatus == .high ? .green : .orange)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Results Container View

    private func resultsContainerView(dossier: SortedDossier) -> some View {
        VStack(spacing: 0) {
            // Tab Picker Bar
            HStack(spacing: 16) {
                resultTabButton(index: 0, title: "Sorted Intel (Dossier)", icon: "doc.plaintext.fill", count: nil)
                resultTabButton(index: 1, title: "Information Gatherer", icon: "tray.full.fill", count: manager.gatheredCleanedItems.count)
                resultTabButton(index: 2, title: "Raw Data Archive", icon: "cylinder.split.1x2.fill", count: manager.rawWebsitesData.count)
                resultTabButton(index: 3, title: "Source Ledger & Lineage", icon: "list.bullet.clipboard.fill", count: dossier.sourceLedger?.entries.count)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch manager.activeTab {
                    case 0:
                        sortedDossierTab(dossier: dossier)
                    case 1:
                        gatheredItemsTab()
                    case 2:
                        rawDataArchiveTab()
                    case 3:
                        sourceLedgerAndLineageTab(dossier: dossier)
                    default:
                        EmptyView()
                    }
                }
                .padding(16)
            }
        }
    }

    private func resultTabButton(index: Int, title: String, icon: String, count: Int?) -> some View {
        Button(action: {
            manager.activeTab = index
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: manager.activeTab == index ? .bold : .medium))
                if let c = count {
                    Text("\(c)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(manager.activeTab == index ? Color.white.opacity(0.3) : Color.secondary.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(manager.activeTab == index ? Color.accentColor : Color.clear)
            .foregroundColor(manager.activeTab == index ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 1: Sorted Dossier

    private func sortedDossierTab(dossier: SortedDossier) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Refusal / Non-Substitution Banner
            if dossier.isRefusal {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Absolute Non-Substitution Policy Enforced")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Aegis refused to synthesize false data or substitute another entity. The analysis was safely halted.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.2), lineWidth: 1))
            }

            // Executive Summary Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.quote")
                        .foregroundColor(.accentColor)
                    Text("Executive Summary")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    if let ent = dossier.entityIdentity {
                        Text("\(ent.entityType.rawValue.capitalized): \(ent.canonicalTitle)")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                }

                Text(dossier.executiveSummary)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))

            // Structured Records Table
            if !dossier.structuredRecords.isEmpty && !dossier.tableHeaders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "tablecells.fill")
                            .foregroundColor(.purple)
                        Text("Structured Findings & Verified Analysis")
                            .font(.system(size: 12, weight: .bold))
                    }

                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            ForEach(dossier.tableHeaders, id: \.self) { header in
                                Text(header)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))

                        Divider()

                        ForEach(Array(dossier.structuredRecords.enumerated()), id: \.offset) { index, record in
                            HStack(spacing: 8) {
                                ForEach(dossier.tableHeaders, id: \.self) { header in
                                    Text(record[header] ?? "—")
                                        .font(.system(size: 11))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(8)
                            .background(index % 2 == 0 ? Color.clear : Color.secondary.opacity(0.04))

                            if index < dossier.structuredRecords.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            // Key Findings
            if !dossier.keyFindings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "list.bullet.circle.fill")
                            .foregroundColor(.green)
                        Text("Key Factual Takeaways")
                            .font(.system(size: 12, weight: .bold))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(dossier.keyFindings, id: \.self) { finding in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                    .font(.system(size: 11))
                                    .padding(.top, 2)
                                Text(finding)
                                    .font(.system(size: 12))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.06))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Tab 2: Information Gatherer

    private func gatheredItemsTab() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Substantive Chunks Retained by Information Gatherer (Boilerplate Stripped)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)

            ForEach(manager.gatheredCleanedItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.sourceTitle)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                        Spacer()
                        Text(item.category)
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(3)
                    }

                    Text(item.extractedSnippet)
                        .font(.system(size: 11))
                        .lineSpacing(2)
                        .textSelection(.enabled)

                    Text(item.sourceURL.absoluteString)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Tab 3: Raw Data Archive

    private func rawDataArchiveTab() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Raw Website Data Archive (Stored As-Is)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)

            ForEach(manager.rawWebsitesData) { item in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                        Text(item.url.absoluteString)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(item.formattedSize)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                    Button("Inspect Raw") {
                        self.state.selectedRawItem = item
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(4)
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Tab 4: Source Ledger & Lineage ("Why This Result?")

    private func sourceLedgerAndLineageTab(dossier: SortedDossier) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Pipeline Counts Banner
            if let ledger = dossier.sourceLedger {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "list.number")
                            .foregroundColor(.blue)
                        Text("Internal Source Ledger (Strict Count Accounting)")
                            .font(.system(size: 12, weight: .bold))
                    }

                    HStack(spacing: 8) {
                        countBadge(label: "Requested", value: "\(ledger.requestedCount)", color: .primary)
                        countBadge(label: "Discovered", value: "\(ledger.discoveredCount)", color: .blue)
                        countBadge(label: "Selected", value: "\(ledger.selectedCount)", color: .teal)
                        countBadge(label: "Accessed", value: "\(ledger.accessedCount)", color: .purple)
                        countBadge(label: "Actually Used", value: "\(ledger.actuallyUsedCount)", color: .green)
                        countBadge(label: "Rejected", value: "\(ledger.rejectedCount)", color: .orange)
                    }

                    Text("Independent Publisher Clusters: \(ledger.independentGroupsCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Source Ledger Entries Table
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source Evaluation & Provenance Ledger")
                        .font(.system(size: 12, weight: .bold))

                    ForEach(ledger.entries) { entry in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.domain)
                                    .font(.system(size: 11, weight: .bold))
                                Text(entry.url.absoluteString)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(entry.qualityTier.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(entry.qualityTier == .primaryAuthoritative ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                                .foregroundColor(entry.qualityTier == .primaryAuthoritative ? .green : .blue)
                                .cornerRadius(4)

                            Text(entry.stage.rawValue.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(3)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.04))
                        .cornerRadius(6)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            // "Why This Result?" Lineage Table
            if !dossier.lineageRecords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("Why This Result? — Formula & Fact Traceability")
                            .font(.system(size: 12, weight: .bold))
                    }

                    ForEach(dossier.lineageRecords) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(record.metricName)
                                    .font(.system(size: 11, weight: .bold))
                                Spacer()
                                Text(record.calculatedValue)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(record.calculationStatus == .dataUnavailable ? .orange : .green)
                            }
                            Text("Formula: \(record.formulaRepresentation)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)

                            if !record.inputVariables.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(record.inputVariables, id: \.variableName) { v in
                                        Text("\(v.variableName): \(v.resolvedValue) [\(v.factuality.rawValue)]")
                                            .font(.system(size: 9))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(3)
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.04))
                        .cornerRadius(6)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    private func countBadge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(6)
    }

    // MARK: - Sheets

    private func rawPayloadDetailSheet(item: RawWebsiteData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Raw Payload Inspection: \(item.title)")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button("Done") { state.selectedRawItem = nil }
            }
            .padding(12)

            Divider()

            ScrollView {
                Text(item.rawHTMLPayload)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(12)
                    .textSelection(.enabled)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func metricLineageDetailSheet(item: MetricLineageRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Lineage: \(item.metricName)")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button("Done") { state.selectedMetricLineage = nil }
            }
            .padding(12)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Calculated Output: \(item.calculatedValue)")
                    .font(.system(size: 12, weight: .bold))
                Text("Mathematical Formula: \(item.formulaRepresentation)")
                    .font(.system(size: 11, design: .monospaced))
            }
            .padding(12)
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func submitQuery() {
        let q = manager.queryInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        Task {
            await manager.executeCollection(query: q)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb >= 1024 {
            return String(format: "%.2f MB", kb / 1024.0)
        } else {
            return String(format: "%.1f KB", kb)
        }
    }

    private var emptyStateWelcomeView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.forward.dottedline")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("Aegis Intel & Traceable Analysis")
                .font(.system(size: 15, weight: .bold))
            Text("Enter any company, stock, or technical project to extract verified facts, inspect the source ledger, and audit data lineage.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
