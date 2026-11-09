import Foundation
import Combine

@MainActor
public final class DataCollectorManager: ObservableObject {
    public static let shared = DataCollectorManager()

    @Published public var queryInputText: String = ""
    @Published public var selectedWebsiteCount: WebsiteCollectionCount = .four
    @Published public var useLLM: Bool = false
    @Published public var selectedModelId: String = ""

    @Published public var state: CollectionState = .idle
    @Published public var activeDossier: SortedDossier? = nil
    @Published public var rawWebsitesData: [RawWebsiteData] = []
    @Published public var gatheredCleanedItems: [CleanedInfoItem] = []
    @Published public var dossierHistory: [SortedDossier] = []
    @Published public var activeTab: Int = 0 // 0: Sorted Dossier, 1: Gathered Data, 2: Raw Data Archive, 3: Source Ledger & Lineage

    private let resolver = EntityResolver.shared
    private let crawler = WebDataCrawler.shared
    private let gatherer = InformationGatherer.shared
    private let sorter = InformationSorter.shared

    public init() {
        if let first = LLMManager.shared.downloadedModels.first {
            self.selectedModelId = first.id
        }
    }

    public var selectedLLMModel: LLMModelItem? {
        return LLMManager.shared.allModels.first(where: { $0.id == selectedModelId }) ?? LLMManager.shared.downloadedModels.first
    }

    public func executeCollection(query: String? = nil) async {
        let q = (query ?? queryInputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        self.queryInputText = q
        self.rawWebsitesData = []
        self.gatheredCleanedItems = []

        let model = selectedLLMModel

        // 1. Pre-Query Step: Refine query and extract intent
        if useLLM, let m = model, m.isDownloaded {
            self.state = .refiningQueryWithLLM(model: m.name)
        } else {
            self.state = .resolvingEntity(query: q)
        }

        let (refinedSearch, detectedIntent) = await sorter.refineQuery(
            rawQuery: q,
            selectedModel: model,
            useLLM: useLLM
        )

        // 2. Strict Entity Resolution & Non-Substitution Verification Guard
        self.state = .resolvingEntity(query: refinedSearch)
        let entity = await resolver.resolve(rawQuery: refinedSearch)

        guard entity.isVerified else {
            let reason = entity.unverifiedReason ?? "Entity could not be verified from reliable sources."
            self.state = .entityUnverified(reason)
            let refusalDossier = await sorter.sortAndSynthesizeForEntity(
                query: q,
                refinedQuery: refinedSearch != q ? refinedSearch : nil,
                intentCategory: "Unverified Entity Refusal",
                entity: entity,
                gatheringResult: GatheringResult(rawTotalBytes: 0, garbageBytesStripped: 0, cleanedItems: []),
                ledger: SourceLedger()
            )
            self.activeDossier = refusalDossier
            self.dossierHistory.insert(refusalDossier, at: 0)
            self.activeTab = 0
            return
        }

        // 3. Entity-Scoped Multi-Source Discovery & Crawl
        self.state = .discoveringWebsites(query: entity.canonicalTitle)

        do {
            let (extractedWebsites, initialLedger) = try await crawler.crawlForEntity(
                entity: entity,
                countLimit: selectedWebsiteCount.limit
            ) { [weak self] current, total, host in
                Task { @MainActor in
                    self?.state = .extractingRawData(current: current, total: total, site: host)
                }
            }

            self.rawWebsitesData = extractedWebsites

            // 4. Information Gathering Step: Strip garbage, extract provenanced facts & detect conflicts
            self.state = .gatheringAndFilteringGarbage(sitesCount: extractedWebsites.count)
            let gatheringResult = gatherer.gatherUsefulInformationForEntity(
                from: extractedWebsites,
                entity: entity,
                userQuery: q
            )
            self.gatheredCleanedItems = gatheringResult.cleanedItems

            // 5. Synthesis with Source Ledger & Data Lineage
            self.state = .sortingAndSynthesizing(isLLM: useLLM && model != nil && (model?.isDownloaded ?? false))
            let dossier = await sorter.sortAndSynthesizeForEntity(
                query: q,
                refinedQuery: refinedSearch != q ? refinedSearch : nil,
                intentCategory: detectedIntent,
                entity: entity,
                gatheringResult: gatheringResult,
                ledger: initialLedger
            )

            self.activeDossier = dossier
            self.dossierHistory.insert(dossier, at: 0)
            self.state = .completed
            self.activeTab = 0

        } catch {
            self.state = .failed(error.localizedDescription)
        }
    }

    public func clear() {
        self.queryInputText = ""
        self.state = .idle
        self.activeDossier = nil
        self.rawWebsitesData = []
        self.gatheredCleanedItems = []
    }
}
