import Foundation

public struct SourceQualityAssessment: Sendable {
    public let finalScore: Double              // 0.0 to 1.0 (clamped)
    public let qualityTier: SourceQualityTier
    public let authorityScore: Double
    public let entityMatchScore: Double
    public let relevanceScore: Double
    public let depthScore: Double
    public let freshnessScore: Double
    public let primarySourceBonus: Double
    public let jurisdictionBonus: Double
    public let penalties: Double
    public let selectionJustification: String
}

public final class SourceQualityEvaluator: @unchecked Sendable {
    public static let shared = SourceQualityEvaluator()

    public init() {}

    /// Evaluates a candidate source based on the multi-factor mathematical authority model
    public func evaluate(
        url: URL,
        sourceType: GranularSourceType,
        entityMatch: EntityMatchResult,
        entity: EntityIdentity,
        jurisdiction: JurisdictionProfile,
        contentByteSize: Int = 0,
        isPDF: Bool = false
    ) -> SourceQualityAssessment {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()

        // 1. Base Authority by Source Tier
        var authority: Double = 0.50
        switch sourceType.tierNumber {
        case 1: authority = 0.98   // Official Company Primary Source
        case 2: authority = 0.96   // Regulatory & Stock Exchange Repository
        case 3: authority = 0.88   // Specialist Financial Database
        case 4: authority = 0.80   // Reputable Business Journalism
        case 5: authority = 0.65   // General Reference / Encyclopedic
        case 6: authority = 0.15   // Low Value / Rejected
        default: authority = 0.50
        }

        // 2. Entity Match Score
        let entityMatchScore = entityMatch.matchScore

        // 3. Data Relevance Score
        var relevance: Double = 0.60
        if path.contains("investor") || path.contains("annual") || path.contains("financial") || path.contains("10-k") || path.contains("results") {
            relevance = 1.0
        } else if path.contains("quote") || path.contains("chart") || path.contains("stock") {
            relevance = 0.90
        } else if path.contains("governance") || path.contains("about") {
            relevance = 0.80
        } else if path.contains("news") || path.contains("press") {
            relevance = 0.75
        }

        // 4. Information Depth Score
        var depth: Double = 0.50
        if isPDF || path.hasSuffix(".pdf") {
            depth = 0.95 // Primary disclosures in PDFs have very high information density
        } else if contentByteSize > 50_000 {
            depth = 0.85
        } else if contentByteSize > 10_000 {
            depth = 0.70
        }

        // 5. Freshness
        let freshness: Double = 0.90

        // 6. Primary Source Bonus
        let primaryBonus: Double = (sourceType == .officialCompany || sourceType == .regulator || sourceType == .stockExchange) ? 0.15 : 0.0

        // 7. Jurisdiction Match Bonus
        let jurisdictionBonus: Double = host.contains(jurisdiction.regulatorDomain) ||
                                       jurisdiction.exchangeDomains.contains(where: { host.contains($0) }) ? 0.10 : 0.0

        // 8. Penalties
        var penalties: Double = 0.0

        // Penalty A: Content Farm / Aggregator / SEO Blog
        if sourceType == .lowValue || sourceType == .irrelevant {
            penalties += 0.50
        }

        // Penalty B: Generic Reference Penalty for Numerical Financial Analysis
        // Wikipedia and general references should not dominate quantitative financials (Section 7)
        if sourceType == .generalReference && entity.analysisType == .financialEquity {
            penalties += 0.20
        }

        // Penalty C: Entity Mismatch Penalty
        if !entityMatch.isAcceptable {
            penalties += 0.60
        }

        // Mathematical Synthesis
        let weightedSum = (authority * 0.35) +
                          (entityMatchScore * 0.25) +
                          (relevance * 0.20) +
                          (depth * 0.10) +
                          (freshness * 0.10) +
                          primaryBonus +
                          jurisdictionBonus -
                          penalties

        let finalScore = max(0.0, min(1.0, weightedSum))

        // Determine Quality Tier
        let tier: SourceQualityTier
        if finalScore >= 0.85 && entityMatch.isAcceptable {
            tier = .primaryAuthoritative
        } else if finalScore >= 0.70 && entityMatch.isAcceptable {
            tier = .highQuality
        } else if finalScore >= 0.50 && entityMatch.isAcceptable {
            tier = .mediumQuality
        } else if finalScore >= 0.30 {
            tier = .lowQuality
        } else {
            tier = .rejected
        }

        let justification = "Evaluated via \(sourceType.rawValue) tier. Authority: \(String(format: "%.2f", authority)), EntityMatch: \(String(format: "%.2f", entityMatchScore)), Relevance: \(String(format: "%.2f", relevance)), FinalScore: \(String(format: "%.2f", finalScore))"

        return SourceQualityAssessment(
            finalScore: finalScore,
            qualityTier: tier,
            authorityScore: authority,
            entityMatchScore: entityMatchScore,
            relevanceScore: relevance,
            depthScore: depth,
            freshnessScore: freshness,
            primarySourceBonus: primaryBonus,
            jurisdictionBonus: jurisdictionBonus,
            penalties: penalties,
            selectionJustification: justification
        )
    }
}
