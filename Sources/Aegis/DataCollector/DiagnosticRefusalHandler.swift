import Foundation

public final class DiagnosticRefusalHandler: @unchecked Sendable {
    public static let shared = DiagnosticRefusalHandler()

    public init() {}

    /// Diagnoses the exact cause of an analysis halt or zero-source result
    public func diagnose(
        entity: EntityIdentity,
        discoveredCount: Int,
        qualifyingCount: Int,
        accessedCount: Int,
        extractedCount: Int,
        networkError: String? = nil
    ) -> (failureMode: DiagnosticFailureMode, explanation: String, suggestedAction: String) {

        // Mode 1: Entity Not Resolved
        if !entity.isVerified {
            return (
                failureMode: .noEntityResolved,
                explanation: "Entity could not be verified: \(entity.unverifiedReason ?? "Unrecognized token"). Under the Absolute Non-Substitution Policy, analysis was halted to prevent false data synthesis.",
                suggestedAction: "Verify entity spelling or provide ticker, exchange, or jurisdiction."
            )
        }

        // Mode 2: Network Fetch Failure
        if let err = networkError, !err.isEmpty {
            return (
                failureMode: .networkRetrievalFailed,
                explanation: "Network fetch failed during source access: \(err). The target servers were unreachable or blocked connection.",
                suggestedAction: "Check network connectivity or air-gap settings."
            )
        }

        // Mode 3: Zero Sources Discovered
        if discoveredCount == 0 {
            return (
                failureMode: .noAuthoritativeSourcesDiscovered,
                explanation: "Targeted source discovery generated zero qualifying regulatory or corporate endpoints for '\(entity.cleanEntityName)'.",
                suggestedAction: "Provide company official website or exchange ticker."
            )
        }

        // Mode 4: All Discovered Sources Rejected Due to Entity Mismatch
        if qualifyingCount == 0 && discoveredCount > 0 {
            return (
                failureMode: .sourcesRejectedDueToEntityMismatch,
                explanation: "All \(discoveredCount) discovered candidate sources were evaluated and rejected due to entity mismatch (e.g. source discussed sibling or parent entity, rather than '\(entity.cleanEntityName)').",
                suggestedAction: "Specify precise legal entity name or subsidiary division."
            )
        }

        // Mode 5: Extraction Failed
        if accessedCount > 0 && extractedCount == 0 {
            return (
                failureMode: .extractionFailed,
                explanation: "\(accessedCount) sources were accessed, but no usable facts or structured statements could be extracted (content empty, blocked, or non-text).",
                suggestedAction: "Check if sources require interactive session or authentication."
            )
        }

        return (
            failureMode: .none,
            explanation: "Normal operation: \(accessedCount) sources accessed and verified.",
            suggestedAction: "None"
        )
    }
}
