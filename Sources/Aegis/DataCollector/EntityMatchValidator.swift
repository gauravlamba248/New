import Foundation

public struct EntityMatchResult: Sendable {
    public let matchScore: Double       // 0.0 to 1.0
    public let isAcceptable: Bool       // true if matchScore >= 0.60
    public let explanation: String
    public let detectedEntityName: String?
}

public final class EntityMatchValidator: @unchecked Sendable {
    public static let shared = EntityMatchValidator()

    public init() {}

    /// Evaluates if a retrieved webpage or document matches the exact target entity without sibling contamination
    public func validateMatch(
        url: URL,
        pageTitle: String,
        pageSnippet: String,
        entity: EntityIdentity
    ) -> EntityMatchResult {
        let lowerTitle = pageTitle.lowercased()
        let lowerSnippet = pageSnippet.lowercased()
        let lowerURL = url.absoluteString.lowercased()
        let targetName = entity.cleanEntityName.lowercased()
        let targetTicker = entity.primaryIdentifier.lowercased()

        // 1. Direct Domain Verification
        if let dom = entity.officialDomain?.lowercased(), !dom.isEmpty {
            if lowerURL.contains(dom) {
                return EntityMatchResult(
                    matchScore: 1.0,
                    isAcceptable: true,
                    explanation: "Direct match on official verified domain: \(dom)",
                    detectedEntityName: entity.cleanEntityName
                )
            }
        }

        // 2. Direct Ticker / CIK Verification for Public Stocks
        if entity.entityType == .publicCompany && !targetTicker.isEmpty && targetTicker != "unverified" {
            if lowerURL.contains(targetTicker) || lowerTitle.contains(targetTicker) {
                return EntityMatchResult(
                    matchScore: 0.98,
                    isAcceptable: true,
                    explanation: "Authoritative ticker symbol match for \(targetTicker.uppercased())",
                    detectedEntityName: entity.cleanEntityName
                )
            }
        }

        // 3. Sibling Confusion Guard for Conglomerates & Corporate Families
        // Example: Tata Industries vs Tata Motors vs Tata Steel vs TCS
        if targetName.contains("tata industries") {
            let forbiddenSiblings = ["tata motors", "tata steel", "tcs", "tata consultancy", "tata power", "titan industries", "tata tea"]
            for sibling in forbiddenSiblings {
                if (lowerTitle.contains(sibling) || lowerURL.contains(sibling.replacingOccurrences(of: " ", with: ""))) &&
                   !lowerTitle.contains("tata industries") && !lowerSnippet.contains("tata industries") {
                    return EntityMatchResult(
                        matchScore: 0.20,
                        isAcceptable: false,
                        explanation: "REJECTED: Entity mismatch. Source explicitly discusses sibling entity '\(sibling.capitalized)', not 'Tata Industries Limited'.",
                        detectedEntityName: sibling.capitalized
                    )
                }
            }
        }

        // Example: Reliance Industries vs Reliance Power vs Reliance Infra
        if targetName.contains("reliance industries") {
            let forbiddenSiblings = ["reliance power", "reliance infrastructure", "reliance capital", "rcom", "reliance communications"]
            for sibling in forbiddenSiblings {
                if lowerTitle.contains(sibling) && !lowerTitle.contains("reliance industries") {
                    return EntityMatchResult(
                        matchScore: 0.20,
                        isAcceptable: false,
                        explanation: "REJECTED: Entity mismatch. Source discusses sibling entity '\(sibling.capitalized)', not 'Reliance Industries Limited'.",
                        detectedEntityName: sibling.capitalized
                    )
                }
            }
        }

        // 4. Name Matching Score
        if lowerTitle.contains(targetName) || lowerSnippet.contains(targetName) {
            return EntityMatchResult(
                matchScore: 0.95,
                isAcceptable: true,
                explanation: "Exact corporate name match in primary text: '\(entity.cleanEntityName)'",
                detectedEntityName: entity.cleanEntityName
            )
        }

        // Core Stem Matching (e.g., "Apple" inside "Apple Inc.")
        let cleanCandidate = EntityResolver.shared.cleanEntityQuery(targetName).lowercased()
        if lowerTitle.contains(cleanCandidate) || lowerSnippet.contains(cleanCandidate) {
            return EntityMatchResult(
                matchScore: 0.85,
                isAcceptable: true,
                explanation: "Clean core stem match: '\(cleanCandidate)'",
                detectedEntityName: entity.cleanEntityName
            )
        }

        // Low / Irrelevant Match
        return EntityMatchResult(
            matchScore: 0.35,
            isAcceptable: false,
            explanation: "Candidate page lacks definitive corporate identifier for '\(entity.cleanEntityName)'",
            detectedEntityName: nil
        )
    }
}
