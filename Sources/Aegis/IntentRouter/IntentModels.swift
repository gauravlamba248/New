import Foundation

/// Core semantic intentions supported by the local offline engine.
public enum AppIntent: Equatable, Sendable {
    case navigate(url: URL, isPrivate: Bool)
    case search(query: String, isPrivate: Bool)
    case resetBrowser
    case toggleAirGap(enable: Bool)
    case toggleISPCloak(enable: Bool)
    case inspectVault
    case quarantineFile(path: String)
    case blockIP(ip: String)
    case blockDomain(domain: String)
    case runDiagnostics
    case viewLogs(category: LogCategoryFilter)
    case clearLogs
    case unknown(raw: String)
}

public enum LogCategoryFilter: String, Sendable {
    case threats = "Threats"
    case activity = "Activity"
    case all = "All"
}

/// Execution payload produced by the offline Intent Router.
public struct IntentResolution: Sendable {
    public let intent: AppIntent
    public let confidence: Double
    public let rawQuery: String
    public let explanation: String
    public let timestamp: Date

    public init(
        intent: AppIntent,
        confidence: Double,
        rawQuery: String,
        explanation: String,
        timestamp: Date = Date()
    ) {
        self.intent = intent
        self.confidence = confidence
        self.rawQuery = rawQuery
        self.explanation = explanation
        self.timestamp = timestamp
    }
}
