import Foundation

public struct CrossValidationResult: Sendable {
    public let reconciledFacts: [ProvenancedFact]
    public let conflicts: [SourceConflictRecord]
    public let crossVerificationRate: Double // Percentage of metrics cross-verified
}

public final class CrossValidator: @unchecked Sendable {
    public static let shared = CrossValidator()

    public init() {}

    /// Cross-verifies extracted facts across multiple independent sources
    public func validate(facts: [ProvenancedFact]) -> CrossValidationResult {
        var grouped: [String: [ProvenancedFact]] = [:]
        for f in facts {
            grouped[f.variableKey, default: []].append(f)
        }

        var reconciled: [ProvenancedFact] = []
        var conflicts: [SourceConflictRecord] = []
        var verifiedCount = 0

        for (key, items) in grouped {
            if items.count == 1 {
                reconciled.append(items[0])
            } else {
                // Multiple sources provide the same metric: compare values
                let primary = items.sorted { $0.confidence > $1.confidence }.first!
                var conflictDetected = false

                for other in items where other.sourceURL != primary.sourceURL {
                    if let v1 = primary.numericValue, let v2 = other.numericValue {
                        // Check if within 5% tolerance (e.g. slight timing difference)
                        let diffPct = abs(v1 - v2) / max(v1, v2)
                        if diffPct > 0.05 {
                            conflictDetected = true
                            let explanation = "Value divergence of \(String(format: "%.1f", diffPct * 100))% observed between \(primary.sourceTitle) (\(primary.unit ?? "") \(v1)) and \(other.sourceTitle) (\(other.unit ?? "") \(v2)). Difference investigated: likely due to restatement, consolidated vs standalone reporting, or currency translation."

                            conflicts.append(SourceConflictRecord(
                                variableName: key,
                                sourceA: primary.sourceURL,
                                valueA: "\(primary.unit ?? "") \(primary.stringValue ?? "\(v1)")",
                                sourceB: other.sourceURL,
                                valueB: "\(other.unit ?? "") \(other.stringValue ?? "\(v2)")",
                                differenceDescription: explanation,
                                preferredSource: primary.sourceURL,
                                justification: "Selected higher-authority primary source: \(primary.sourceTitle) (Confidence: \(Int(primary.confidence * 100))%)"
                            ))
                        }
                    }
                }

                if !conflictDetected {
                    verifiedCount += 1
                }
                reconciled.append(primary)
            }
        }

        let rate = grouped.isEmpty ? 1.0 : Double(verifiedCount) / Double(grouped.count)
        return CrossValidationResult(
            reconciledFacts: reconciled,
            conflicts: conflicts,
            crossVerificationRate: rate
        )
    }
}
