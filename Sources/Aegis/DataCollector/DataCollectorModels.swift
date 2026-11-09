import Foundation

// MARK: - Website Collection Count

/// Selector for the number of websites to collect data from
public enum WebsiteCollectionCount: String, CaseIterable, Identifiable, Codable, Sendable {
    case two = "2 Websites"
    case four = "4 Websites"
    case six = "6 Websites"
    case eight = "8 Websites"
    case all = "All Websites (16)"

    public var id: String { rawValue }

    public var limit: Int {
        switch self {
        case .two: return 2
        case .four: return 4
        case .six: return 6
        case .eight: return 8
        case .all: return 16
        }
    }
}

// MARK: - Entity Classification & Identity

public enum EntityType: String, Codable, Sendable {
    case publicCompany      // Listed stock with ticker & exchange
    case privateCompany     // Unlisted corporate entity / startup
    case techProject        // Open-source software / specification / standard
    case nonProfitOrg       // Foundation / NGO / research institution
    case generalTopic       // Scientific concept / historical event
    case unverified         // Cannot be verified with confidence
}

public enum AnalysisType: String, Codable, Sendable {
    case financialEquity       // SEC Filings, Balance Sheet, Intrinsic Valuation
    case corporateOperational  // Private firm operations, funding, products
    case technicalProject      // Repository, releases, architecture, license
    case universalTopic        // Encyclopedic knowledge, definitions
}

public struct EntityIdentity: Identifiable, Codable, Sendable {
    public var id: UUID
    public var rawQuery: String
    public var cleanEntityName: String
    public var entityType: EntityType
    public var analysisType: AnalysisType
    public var primaryIdentifier: String   // Ticker (e.g. "F"), CIK ("0000037996"), Domain ("ford.com"), GitHub ("kubernetes/kubernetes")
    public var canonicalTitle: String      // "Ford Motor Company"
    public var officialDomain: String?
    public var jurisdiction: String        // "India", "US", "Germany", "Japan", "South Korea", "UK", "Global"
    public var confidenceScore: Double     // 0.0 to 1.0
    public var verificationSources: [String]
    public var isVerified: Bool
    public var unverifiedReason: String?

    public init(
        id: UUID = UUID(),
        rawQuery: String,
        cleanEntityName: String,
        entityType: EntityType,
        analysisType: AnalysisType,
        primaryIdentifier: String,
        canonicalTitle: String,
        officialDomain: String? = nil,
        jurisdiction: String = "Global",
        confidenceScore: Double = 1.0,
        verificationSources: [String] = [],
        isVerified: Bool = true,
        unverifiedReason: String? = nil
    ) {
        self.id = id
        self.rawQuery = rawQuery
        self.cleanEntityName = cleanEntityName
        self.entityType = entityType
        self.analysisType = analysisType
        self.primaryIdentifier = primaryIdentifier
        self.canonicalTitle = canonicalTitle
        self.officialDomain = officialDomain
        self.jurisdiction = jurisdiction
        self.confidenceScore = confidenceScore
        self.verificationSources = verificationSources
        self.isVerified = isVerified
        self.unverifiedReason = unverifiedReason
    }

    public static func unverified(query: String, reason: String) -> EntityIdentity {
        return EntityIdentity(
            rawQuery: query,
            cleanEntityName: query,
            entityType: .unverified,
            analysisType: .universalTopic,
            primaryIdentifier: "UNVERIFIED",
            canonicalTitle: "Unverified Entity: \(query)",
            jurisdiction: "Unknown",
            confidenceScore: 0.0,
            verificationSources: [],
            isVerified: false,
            unverifiedReason: reason
        )
    }
}

// MARK: - Source Ledger & Provenance Types

public enum SourceLifecycleStage: String, Codable, Sendable {
    case discovered
    case candidate
    case selected
    case accessed
    case extracted
    case validated
    case usedInCalculations
    case rejected
}

public enum SourceCategory: String, Codable, Sendable {
    case regulatoryFiling    // SEC 10-K, 10-Q, 8-K
    case officialEntityDoc   // Official investor relations, official project documentation
    case primaryRepository   // Official GitHub/GitLab repository
    case marketExchangeData  // NASDAQ, NYSE, Yahoo Finance, Google Finance
    case reputableNewsMedia  // Reuters, Bloomberg, FT, WSJ
    case academicJournal     // ArXiv, CrossRef, IEEE
    case encyclopedic        // Wikipedia, Wikidata
    case secondaryWeb        // General web
}

public enum SourceQualityTier: String, Codable, Sendable {
    case primaryAuthoritative = "PRIMARY / AUTHORITATIVE"
    case highQuality = "HIGH QUALITY"
    case mediumQuality = "MEDIUM QUALITY"
    case lowQuality = "LOW QUALITY"
    case rejected = "REJECTED"
}

// MARK: - Granular Source Type (Section 12 Hierarchy)

public enum GranularSourceType: String, Codable, Sendable {
    case officialCompany     = "OFFICIAL_COMPANY"
    case regulator           = "REGULATOR"
    case stockExchange       = "STOCK_EXCHANGE"
    case governmentRegistry  = "GOVERNMENT_REGISTRY"
    case financialDatabase   = "FINANCIAL_DATABASE"
    case specialistFinancial = "SPECIALIST_FINANCIAL"
    case reputableNews       = "REPUTABLE_NEWS"
    case industryPublication = "INDUSTRY_PUBLICATION"
    case research            = "RESEARCH"
    case generalReference    = "GENERAL_REFERENCE"
    case lowValue            = "LOW_VALUE"
    case irrelevant          = "IRRELEVANT"

    public var tierNumber: Int {
        switch self {
        case .officialCompany: return 1
        case .regulator, .stockExchange, .governmentRegistry: return 2
        case .financialDatabase, .specialistFinancial: return 3
        case .reputableNews, .industryPublication: return 4
        case .research, .generalReference: return 5
        case .lowValue, .irrelevant: return 6
        }
    }

    public var tierDescription: String {
        switch tierNumber {
        case 1: return "Tier 1: Official Company Primary Source"
        case 2: return "Tier 2: Regulatory & Stock Exchange Repository"
        case 3: return "Tier 3: Specialist Financial Database"
        case 4: return "Tier 4: Reputable News & Industry Publication"
        case 5: return "Tier 5: General Reference / Encyclopedic"
        case 6: return "Tier 6: Low Value / Rejected"
        default: return "Unknown Tier"
        }
    }
}

public enum DiagnosticFailureMode: String, Codable, Sendable {
    case none                                    = "NONE"
    case noEntityResolved                        = "NO_ENTITY_RESOLVED"
    case noAuthoritativeSourcesDiscovered        = "NO_AUTHORITATIVE_SOURCES_DISCOVERED"
    case sourcesRejectedDueToEntityMismatch      = "SOURCES_REJECTED_DUE_TO_ENTITY_MISMATCH"
    case networkRetrievalFailed                  = "NETWORK_RETRIEVAL_FAILED"
    case extractionFailed                        = "EXTRACTION_FAILED"

    public var diagnosticTitle: String {
        switch self {
        case .none: return "Normal Operation"
        case .noEntityResolved: return "No Entity Resolved (Query Ambiguous or Unrecognized)"
        case .noAuthoritativeSourcesDiscovered: return "Entity Resolved, but No Authoritative Sources Discovered"
        case .sourcesRejectedDueToEntityMismatch: return "Sources Discovered but Rejected (Entity Mismatch Protection)"
        case .networkRetrievalFailed: return "Network Retrieval Failed (Offline or Host Unreachable)"
        case .extractionFailed: return "Data Extraction Failed (Payload Obfuscated or Unstructured)"
        }
    }
}

public struct SourceLedgerEntry: Identifiable, Codable, Sendable {
    public var id: UUID
    public var url: URL
    public var domain: String
    public var category: SourceCategory
    public var qualityTier: SourceQualityTier
    public var stage: SourceLifecycleStage
    public var authorityScore: Double      // Weight: 0.0 to 1.0
    public var freshnessDate: Date?
    public var httpStatus: Int?
    public var extractedFactsCount: Int
    public var independenceGroupID: String // Identifies syndicated / duplicate content clusters
    public var underlyingSource: String?   // e.g. "Reuters Wire", "PR Newswire", "SEC EDGAR"
    public var rejectionReason: String?

    // Granular Provenance & Explainability (Section 11, 12 & 23)
    public var sourceType: GranularSourceType
    public var authorityLevel: String
    public var jurisdiction: String
    public var entityMatchScore: Double
    public var informationTypes: [String]
    public var publicationDate: Date?
    public var retrievalDate: Date
    public var qualityScore: Double
    public var selectionReason: String
    public var whyThisSource: String

    public init(
        id: UUID = UUID(),
        url: URL,
        domain: String,
        category: SourceCategory,
        qualityTier: SourceQualityTier,
        stage: SourceLifecycleStage,
        authorityScore: Double,
        freshnessDate: Date? = nil,
        httpStatus: Int? = nil,
        extractedFactsCount: Int = 0,
        independenceGroupID: String,
        underlyingSource: String? = nil,
        rejectionReason: String? = nil,
        sourceType: GranularSourceType = .generalReference,
        authorityLevel: String = "Tier 5: General Reference",
        jurisdiction: String = "Global",
        entityMatchScore: Double = 1.0,
        informationTypes: [String] = [],
        publicationDate: Date? = nil,
        retrievalDate: Date = Date(),
        qualityScore: Double = 0.5,
        selectionReason: String = "",
        whyThisSource: String = ""
    ) {
        self.id = id
        self.url = url
        self.domain = domain
        self.category = category
        self.qualityTier = qualityTier
        self.stage = stage
        self.authorityScore = authorityScore
        self.freshnessDate = freshnessDate
        self.httpStatus = httpStatus
        self.extractedFactsCount = extractedFactsCount
        self.independenceGroupID = independenceGroupID
        self.underlyingSource = underlyingSource
        self.rejectionReason = rejectionReason
        self.sourceType = sourceType
        self.authorityLevel = authorityLevel
        self.jurisdiction = jurisdiction
        self.entityMatchScore = entityMatchScore
        self.informationTypes = informationTypes
        self.publicationDate = publicationDate
        self.retrievalDate = retrievalDate
        self.qualityScore = qualityScore
        self.selectionReason = selectionReason
        self.whyThisSource = whyThisSource
    }
}

public struct SourceLedger: Codable, Sendable {
    public var requestedCount: Int
    public var discoveredCount: Int
    public var candidateCount: Int
    public var selectedCount: Int
    public var accessedCount: Int
    public var extractedCount: Int
    public var validatedCount: Int
    public var actuallyUsedCount: Int
    public var rejectedCount: Int
    public var independentGroupsCount: Int
    public var diagnosticFailureMode: DiagnosticFailureMode
    public var diagnosticExplanation: String?
    public var entries: [SourceLedgerEntry]

    public init(
        requestedCount: Int = 0,
        discoveredCount: Int = 0,
        candidateCount: Int = 0,
        selectedCount: Int = 0,
        accessedCount: Int = 0,
        extractedCount: Int = 0,
        validatedCount: Int = 0,
        actuallyUsedCount: Int = 0,
        rejectedCount: Int = 0,
        independentGroupsCount: Int = 0,
        diagnosticFailureMode: DiagnosticFailureMode = .none,
        diagnosticExplanation: String? = nil,
        entries: [SourceLedgerEntry] = []
    ) {
        self.requestedCount = requestedCount
        self.discoveredCount = discoveredCount
        self.candidateCount = candidateCount
        self.selectedCount = selectedCount
        self.accessedCount = accessedCount
        self.extractedCount = extractedCount
        self.validatedCount = validatedCount
        self.actuallyUsedCount = actuallyUsedCount
        self.rejectedCount = rejectedCount
        self.independentGroupsCount = independentGroupsCount
        self.diagnosticFailureMode = diagnosticFailureMode
        self.diagnosticExplanation = diagnosticExplanation
        self.entries = entries
    }
}

// MARK: - Provenanced Facts & Lineage

public enum FactFactuality: String, Codable, Sendable {
    case verifiedFact   = "VERIFIED_FACT"
    case derivedValue   = "DERIVED_VALUE"
    case estimate       = "ESTIMATE"
    case assumption     = "ASSUMPTION"
    case unknownFact    = "UNKNOWN"
}

public struct ProvenancedFact: Identifiable, Codable, Sendable {
    public var id: UUID
    public var entityID: String
    public var variableKey: String          // e.g. "revenue", "netIncome", "operatingCashFlow", "sharesOutstanding", "repoStars"
    public var numericValue: Double?
    public var stringValue: String?
    public var unit: String?                // "USD", "shares", "ratio", "stars"
    public var fiscalPeriod: String?        // "FY2025", "Q3 2026", "Current"
    public var sourceURL: URL
    public var sourceTitle: String
    public var documentSection: String      // e.g. "Consolidated Statements of Operations", "Release Notes v1.31"
    public var publicationDate: Date?
    public var retrievalDate: Date
    public var confidence: Double
    public var extractionMethod: String     // "XBRL Parser", "HTML Table Extractor", "Regex Metric Scanner", "JSON API"
    public var factuality: FactFactuality

    public init(
        id: UUID = UUID(),
        entityID: String,
        variableKey: String,
        numericValue: Double? = nil,
        stringValue: String? = nil,
        unit: String? = nil,
        fiscalPeriod: String? = nil,
        sourceURL: URL,
        sourceTitle: String,
        documentSection: String,
        publicationDate: Date? = nil,
        retrievalDate: Date = Date(),
        confidence: Double = 1.0,
        extractionMethod: String = "Direct Ingestion",
        factuality: FactFactuality = .verifiedFact
    ) {
        self.id = id
        self.entityID = entityID
        self.variableKey = variableKey
        self.numericValue = numericValue
        self.stringValue = stringValue
        self.unit = unit
        self.fiscalPeriod = fiscalPeriod
        self.sourceURL = sourceURL
        self.sourceTitle = sourceTitle
        self.documentSection = documentSection
        self.publicationDate = publicationDate
        self.retrievalDate = retrievalDate
        self.confidence = confidence
        self.extractionMethod = extractionMethod
        self.factuality = factuality
    }
}

public struct SourceConflictRecord: Identifiable, Codable, Sendable {
    public var id: UUID
    public var variableName: String
    public var sourceA: URL
    public var valueA: String
    public var sourceB: URL
    public var valueB: String
    public var differenceDescription: String
    public var preferredSource: URL
    public var justification: String

    public init(
        id: UUID = UUID(),
        variableName: String,
        sourceA: URL,
        valueA: String,
        sourceB: URL,
        valueB: String,
        differenceDescription: String,
        preferredSource: URL,
        justification: String
    ) {
        self.id = id
        self.variableName = variableName
        self.sourceA = sourceA
        self.valueA = valueA
        self.sourceB = sourceB
        self.valueB = valueB
        self.differenceDescription = differenceDescription
        self.preferredSource = preferredSource
        self.justification = justification
    }
}

public struct VariableLineage: Codable, Sendable {
    public var variableName: String
    public var resolvedValue: String
    public var factuality: FactFactuality
    public var factReference: ProvenancedFact?
    public var isUnavailable: Bool

    public init(
        variableName: String,
        resolvedValue: String,
        factuality: FactFactuality,
        factReference: ProvenancedFact? = nil,
        isUnavailable: Bool = false
    ) {
        self.variableName = variableName
        self.resolvedValue = resolvedValue
        self.factuality = factuality
        self.factReference = factReference
        self.isUnavailable = isUnavailable
    }
}

public enum MetricStatus: String, Codable, Sendable {
    case verifiedFromSources = "VERIFIED"
    case partiallyAvailable  = "PARTIAL"
    case dataUnavailable     = "UNAVAILABLE"
}

public struct MetricLineageRecord: Identifiable, Codable, Sendable {
    public var id: UUID
    public var metricName: String           // e.g. "Altman Z-Score"
    public var calculatedValue: String      // e.g. "3.21"
    public var formulaRepresentation: String// "1.2*X1 + 1.4*X2 + 3.3*X3 + 0.6*X4 + 0.999*X5"
    public var inputVariables: [VariableLineage]
    public var confidenceScore: Double
    public var calculationStatus: MetricStatus

    public init(
        id: UUID = UUID(),
        metricName: String,
        calculatedValue: String,
        formulaRepresentation: String,
        inputVariables: [VariableLineage] = [],
        confidenceScore: Double = 1.0,
        calculationStatus: MetricStatus = .verifiedFromSources
    ) {
        self.id = id
        self.metricName = metricName
        self.calculatedValue = calculatedValue
        self.formulaRepresentation = formulaRepresentation
        self.inputVariables = inputVariables
        self.confidenceScore = confidenceScore
        self.calculationStatus = calculationStatus
    }
}

// MARK: - Evidence Quality Summary

public enum OverallEvidenceStatus: String, Codable, Sendable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    case insufficient = "INSUFFICIENT"
}

public struct EvidenceQualitySummary: Codable, Sendable {
    public var primarySourcesCount: Int
    public var highQualityCount: Int
    public var mediumQualityCount: Int
    public var rejectedCount: Int
    public var independentGroupsCount: Int
    public var dataCompletenessPct: Double
    public var conflictCount: Int
    public var overallEvidenceStatus: OverallEvidenceStatus
    public var notes: [String]

    public init(
        primarySourcesCount: Int = 0,
        highQualityCount: Int = 0,
        mediumQualityCount: Int = 0,
        rejectedCount: Int = 0,
        independentGroupsCount: Int = 0,
        dataCompletenessPct: Double = 100.0,
        conflictCount: Int = 0,
        overallEvidenceStatus: OverallEvidenceStatus = .high,
        notes: [String] = []
    ) {
        self.primarySourcesCount = primarySourcesCount
        self.highQualityCount = highQualityCount
        self.mediumQualityCount = mediumQualityCount
        self.rejectedCount = rejectedCount
        self.independentGroupsCount = independentGroupsCount
        self.dataCompletenessPct = dataCompletenessPct
        self.conflictCount = conflictCount
        self.overallEvidenceStatus = overallEvidenceStatus
        self.notes = notes
    }
}

// MARK: - Isolated Analysis Context

public struct AnalysisContext: Identifiable, Codable, Sendable {
    public var id: UUID
    public var entityID: String
    public var entityIdentity: EntityIdentity
    public var analysisType: AnalysisType
    public var requestedSources: Int
    public var ledger: SourceLedger
    public var facts: [ProvenancedFact]
    public var lineageRecords: [MetricLineageRecord]
    public var conflicts: [SourceConflictRecord]
    public var evidenceQuality: EvidenceQualitySummary

    public init(
        id: UUID = UUID(),
        entityID: String,
        entityIdentity: EntityIdentity,
        analysisType: AnalysisType,
        requestedSources: Int,
        ledger: SourceLedger,
        facts: [ProvenancedFact] = [],
        lineageRecords: [MetricLineageRecord] = [],
        conflicts: [SourceConflictRecord] = [],
        evidenceQuality: EvidenceQualitySummary = EvidenceQualitySummary()
    ) {
        self.id = id
        self.entityID = entityID
        self.entityIdentity = entityIdentity
        self.analysisType = analysisType
        self.requestedSources = requestedSources
        self.ledger = ledger
        self.facts = facts
        self.lineageRecords = lineageRecords
        self.conflicts = conflicts
        self.evidenceQuality = evidenceQuality
    }
}

// MARK: - Raw Website & Cleaned Info Data

/// Stores raw extracted website data as-is without leaving anything out
public struct RawWebsiteData: Identifiable, Codable, Sendable {
    public var id: UUID
    public var url: URL
    public var title: String
    public var httpStatus: Int
    public var fetchTimestamp: Date
    public var rawHTMLPayload: String
    public var byteSize: Int
    public var storageFilePath: String?

    public init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        httpStatus: Int = 200,
        fetchTimestamp: Date = Date(),
        rawHTMLPayload: String,
        byteSize: Int,
        storageFilePath: String? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.httpStatus = httpStatus
        self.fetchTimestamp = fetchTimestamp
        self.rawHTMLPayload = rawHTMLPayload
        self.byteSize = byteSize
        self.storageFilePath = storageFilePath
    }

    public var formattedSize: String {
        let kb = Double(byteSize) / 1024.0
        if kb >= 1024 {
            return String(format: "%.2f MB", kb / 1024.0)
        } else {
            return String(format: "%.1f KB", kb)
        }
    }
}

/// A substantive content chunk extracted by the Information Gatherer after stripping garbage
public struct CleanedInfoItem: Identifiable, Codable, Sendable {
    public var id: UUID
    public var sourceURL: URL
    public var sourceTitle: String
    public var sectionTitle: String
    public var extractedSnippet: String
    public var relevanceScore: Double
    public var category: String

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        sourceTitle: String,
        sectionTitle: String,
        extractedSnippet: String,
        relevanceScore: Double = 1.0,
        category: String = "General"
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.sourceTitle = sourceTitle
        self.sectionTitle = sectionTitle
        self.extractedSnippet = extractedSnippet
        self.relevanceScore = relevanceScore
        self.category = category
    }
}

// MARK: - Final Executive Dossier

/// Final executive dossier produced by the Information Sorter
public struct SortedDossier: Identifiable, Codable, Sendable {
    public var id: UUID
    public var originalQuery: String
    public var refinedQueryByLLM: String?
    public var intentCategory: String
    public var timestamp: Date
    public var websitesVisitedCount: Int
    public var rawBytesExtracted: Int64
    public var garbageBytesFiltered: Int64
    public var usefulDataRatio: Double
    public var executiveSummary: String
    public var keyFindings: [String]
    public var structuredRecords: [[String: String]] // Table records (e.g. product/price/RAM, weather readings, scheme details)
    public var tableHeaders: [String]
    public var citations: [URL]
    public var llmSynthesized: Bool
    public var llmModelUsed: String?

    // Upgraded Architecture Provenance Fields
    public var entityIdentity: EntityIdentity?
    public var sourceLedger: SourceLedger?
    public var evidenceQuality: EvidenceQualitySummary?
    public var lineageRecords: [MetricLineageRecord]
    public var conflicts: [SourceConflictRecord]
    public var isRefusal: Bool

    public init(
        id: UUID = UUID(),
        originalQuery: String,
        refinedQueryByLLM: String? = nil,
        intentCategory: String = "General Knowledge",
        timestamp: Date = Date(),
        websitesVisitedCount: Int = 0,
        rawBytesExtracted: Int64 = 0,
        garbageBytesFiltered: Int64 = 0,
        usefulDataRatio: Double = 0.0,
        executiveSummary: String,
        keyFindings: [String] = [],
        structuredRecords: [[String: String]] = [],
        tableHeaders: [String] = [],
        citations: [URL] = [],
        llmSynthesized: Bool = false,
        llmModelUsed: String? = nil,
        entityIdentity: EntityIdentity? = nil,
        sourceLedger: SourceLedger? = nil,
        evidenceQuality: EvidenceQualitySummary? = nil,
        lineageRecords: [MetricLineageRecord] = [],
        conflicts: [SourceConflictRecord] = [],
        isRefusal: Bool = false
    ) {
        self.id = id
        self.originalQuery = originalQuery
        self.refinedQueryByLLM = refinedQueryByLLM
        self.intentCategory = intentCategory
        self.timestamp = timestamp
        self.websitesVisitedCount = websitesVisitedCount
        self.rawBytesExtracted = rawBytesExtracted
        self.garbageBytesFiltered = garbageBytesFiltered
        self.usefulDataRatio = usefulDataRatio
        self.executiveSummary = executiveSummary
        self.keyFindings = keyFindings
        self.structuredRecords = structuredRecords
        self.tableHeaders = tableHeaders
        self.citations = citations
        self.llmSynthesized = llmSynthesized
        self.llmModelUsed = llmModelUsed
        self.entityIdentity = entityIdentity
        self.sourceLedger = sourceLedger
        self.evidenceQuality = evidenceQuality
        self.lineageRecords = lineageRecords
        self.conflicts = conflicts
        self.isRefusal = isRefusal
    }
}

// MARK: - Pipeline States

/// Live collection pipeline states
public enum CollectionState: Equatable, Sendable {
    case idle
    case refiningQueryWithLLM(model: String)
    case resolvingEntity(query: String)
    case discoveringWebsites(query: String)
    case extractingRawData(current: Int, total: Int, site: String)
    case gatheringAndFilteringGarbage(sitesCount: Int)
    case sortingAndSynthesizing(isLLM: Bool)
    case completed
    case entityUnverified(String)
    case insufficientData(String)
    case failed(String)

    public var statusDescription: String {
        switch self {
        case .idle:
            return "Ready for query"
        case .refiningQueryWithLLM(let model):
            return "Local LLM (\(model)) refining query & extracting intent..."
        case .resolvingEntity(let q):
            return "Resolving & verifying entity identity for '\(q)'..."
        case .discoveringWebsites(let q):
            return "Discovering target websites for '\(q)'..."
        case .extractingRawData(let cur, let tot, let site):
            return "Extracting complete raw website data (\(cur)/\(tot)): \(site)..."
        case .gatheringAndFilteringGarbage(let count):
            return "Information Gatherer stripping garbage & boilerplate from \(count) websites..."
        case .sortingAndSynthesizing(let isLLM):
            return isLLM ? "Information Sorter & LLM structuring final dossier..." : "Information Sorter organizing structured results..."
        case .completed:
            return "Data collection and synthesis complete"
        case .entityUnverified(let reason):
            return "Entity Unverified: \(reason)"
        case .insufficientData(let reason):
            return "Insufficient Data: \(reason)"
        case .failed(let err):
            return "Collection error: \(err)"
        }
    }
}
