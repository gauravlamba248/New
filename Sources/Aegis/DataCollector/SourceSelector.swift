import Foundation

public final class SourceSelector: @unchecked Sendable {
    public static let shared = SourceSelector()

    public init() {}

    /// Selects qualifying diverse sources up to the user-requested budget limit
    public func selectSources(
        candidates: [SourceLedgerEntry],
        budgetLimit: Int
    ) -> (selected: [SourceLedgerEntry], fullLedgerEntries: [SourceLedgerEntry]) {
        // 1. Separate Qualifying vs Non-Qualifying Candidates
        let qualifying = candidates.filter { $0.qualityTier != .rejected && $0.entityMatchScore >= 0.60 }
        let rejectedCandidates = candidates.filter { $0.qualityTier == .rejected || $0.entityMatchScore < 0.60 }

        // 2. Sort Qualifying Candidates by Quality Score Descending
        let sortedQualifying = qualifying.sorted { $0.qualityScore > $1.qualityScore }

        // 3. Select Diverse Sources Across Categories up to budgetLimit
        var selected: [SourceLedgerEntry] = []
        var domainUsage: [String: Int] = [:]

        // Pass 1: Select top source from each distinct domain / publisher group to ensure source diversity
        for entry in sortedQualifying {
            if selected.count >= budgetLimit { break }
            let count = domainUsage[entry.domain] ?? 0
            if count == 0 {
                var copy = entry
                copy.stage = .selected
                copy.selectionReason = generateSelectionReason(entry: copy, rank: selected.count + 1)
                copy.whyThisSource = copy.selectionReason
                selected.append(copy)
                domainUsage[entry.domain] = 1
            }
        }

        // Pass 2: If budget remains, fill with remaining highest-scoring qualifying sources
        if selected.count < budgetLimit {
            for entry in sortedQualifying where !selected.contains(where: { $0.url == entry.url }) {
                if selected.count >= budgetLimit { break }
                let count = domainUsage[entry.domain] ?? 0
                if count < 2 { // Allow at most 2 URLs per domain in second pass to balance diversity
                    var copy = entry
                    copy.stage = .selected
                    copy.selectionReason = generateSelectionReason(entry: copy, rank: selected.count + 1)
                    copy.whyThisSource = copy.selectionReason
                    selected.append(copy)
                    domainUsage[entry.domain] = count + 1
                }
            }
        }

        // Pass 3: If budget still remains, allow additional qualifying deep paths from official / primary domains up to budget limit
        if selected.count < budgetLimit {
            for entry in sortedQualifying where !selected.contains(where: { $0.url == entry.url }) {
                if selected.count >= budgetLimit { break }
                var copy = entry
                copy.stage = .selected
                copy.selectionReason = generateSelectionReason(entry: copy, rank: selected.count + 1)
                copy.whyThisSource = copy.selectionReason
                selected.append(copy)
                let count = domainUsage[entry.domain] ?? 0
                domainUsage[entry.domain] = count + 1
            }
        }

        // 4. Update the Complete Ledger with Full Transparency
        var fullList: [SourceLedgerEntry] = []

        // Add selected entries
        for s in selected {
            fullList.append(s)
        }

        // Add unselected qualifying candidates (budget limit reached)
        for q in sortedQualifying where !selected.contains(where: { $0.url == q.url }) {
            var copy = q
            copy.stage = .discovered
            copy.selectionReason = "Discovered & qualified (Score: \(String(format: "%.2f", copy.qualityScore))), but user budget limit of \(budgetLimit) sources was filled by higher-ranking sources."
            copy.whyThisSource = "Candidate available; ranked below top \(budgetLimit) selected sources."
            fullList.append(copy)
        }

        // Add rejected candidates
        for r in rejectedCandidates {
            var copy = r
            copy.stage = .rejected
            if copy.entityMatchScore < 0.60 && copy.rejectionReason == nil {
                copy.rejectionReason = "REJECTED: Entity mismatch. Source content does not verify target entity identity."
            }
            fullList.append(copy)
        }

        return (selected, fullList)
    }

    private func generateSelectionReason(entry: SourceLedgerEntry, rank: Int) -> String {
        let scorePct = Int(entry.qualityScore * 100)
        let tierDesc = entry.sourceType.tierDescription
        return "Selected [Rank #\(rank)] (Quality: \(scorePct)%): \(tierDesc) on '\(entry.domain)'. Matched entity with \(Int(entry.entityMatchScore * 100))% confidence. Contains: \(entry.informationTypes.joined(separator: ", "))."
    }
}
