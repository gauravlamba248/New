import Foundation

public final class FactExtractor: @unchecked Sendable {
    public static let shared = FactExtractor()

    public init() {}

    /// Extracts structured facts with complete 13-field provenance from raw website data
    public func extractFacts(
        from site: RawWebsiteData,
        entity: EntityIdentity
    ) -> [ProvenancedFact] {
        var facts: [ProvenancedFact] = []
        let raw = site.rawHTMLPayload
        let trimmedRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. JSON DATA EXTRACTION (SEC XBRL or Market Chart Quotes)
        if trimmedRaw.hasPrefix("{") || trimmedRaw.hasPrefix("[") {
            if let jsonData = raw.data(using: .utf8),
               let jsonObj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

                // A. Market Quote JSON (Yahoo Finance Chart API)
                if let chart = jsonObj["chart"] as? [String: Any],
                   let results = chart["result"] as? [[String: Any]],
                   let firstResult = results.first,
                   let meta = firstResult["meta"] as? [String: Any] {

                    let currency = meta["currency"] as? String ?? (entity.jurisdiction == "India" ? "INR" : "USD")
                    let price = meta["regularMarketPrice"] as? Double ?? 0.0
                    let volume = meta["regularMarketVolume"] as? Int ?? 0
                    let high52 = meta["fiftyTwoWeekHigh"] as? Double ?? 0.0
                    let low52 = meta["fiftyTwoWeekLow"] as? Double ?? 0.0

                    if price > 0 {
                        facts.append(ProvenancedFact(
                            entityID: entity.cleanEntityName,
                            variableKey: "currentPrice",
                            numericValue: price,
                            stringValue: String(format: "%.2f", price),
                            unit: currency,
                            fiscalPeriod: "Current Session",
                            sourceURL: site.url,
                            sourceTitle: site.title,
                            documentSection: "Real-Time Exchange Execution",
                            retrievalDate: site.fetchTimestamp,
                            confidence: 0.99,
                            extractionMethod: "JSON Real-Time Market Parser",
                            factuality: .verifiedFact
                        ))
                    }

                    if volume > 0 {
                        facts.append(ProvenancedFact(
                            entityID: entity.cleanEntityName,
                            variableKey: "tradingVolume",
                            numericValue: Double(volume),
                            stringValue: "\(volume)",
                            unit: "shares",
                            fiscalPeriod: "Current Session",
                            sourceURL: site.url,
                            sourceTitle: site.title,
                            documentSection: "Real-Time Exchange Execution",
                            retrievalDate: site.fetchTimestamp,
                            confidence: 0.98,
                            extractionMethod: "JSON Real-Time Market Parser",
                            factuality: .verifiedFact
                        ))
                    }

                    if high52 > 0 {
                        facts.append(ProvenancedFact(
                            entityID: entity.cleanEntityName,
                            variableKey: "fiftyTwoWeekHigh",
                            numericValue: high52,
                            stringValue: String(format: "%.2f", high52),
                            unit: currency,
                            fiscalPeriod: "52-Week Range",
                            sourceURL: site.url,
                            sourceTitle: site.title,
                            documentSection: "Real-Time Exchange Execution",
                            retrievalDate: site.fetchTimestamp,
                            confidence: 0.95,
                            extractionMethod: "JSON Real-Time Market Parser",
                            factuality: .verifiedFact
                        ))
                    }
                }

                // B. Audited Statutory XBRL Facts (SEC EDGAR)
                if let factsObj = jsonObj["facts"] as? [String: Any],
                   let usGaap = factsObj["us-gaap"] as? [String: Any] {

                    let extractConcept: (String) -> (val: Double?, fy: Int?) = { concept in
                        guard let obj = usGaap[concept] as? [String: Any],
                              let units = obj["units"] as? [String: Any] else { return (nil, nil) }
                        let list = (units["USD"] as? [[String: Any]]) ?? (units["shares"] as? [[String: Any]]) ?? []
                        guard let last = list.last else { return (nil, nil) }
                        return (last["val"] as? Double, last["fy"] as? Int)
                    }

                    let concepts: [(key: String, concept: String, sec: String, unit: String)] = [
                        ("revenue", "Revenues", "Consolidated Statements of Operations", "USD"),
                        ("revenue", "RevenueFromContractWithCustomerExcludingAssessedTax", "Consolidated Statements of Operations", "USD"),
                        ("netIncome", "NetIncomeLoss", "Consolidated Statements of Operations", "USD"),
                        ("operatingIncome", "OperatingIncomeLoss", "Consolidated Statements of Operations", "USD"),
                        ("grossProfit", "GrossProfit", "Consolidated Statements of Operations", "USD"),
                        ("totalAssets", "Assets", "Consolidated Balance Sheets", "USD"),
                        ("totalLiabilities", "Liabilities", "Consolidated Balance Sheets", "USD"),
                        ("stockholdersEquity", "StockholdersEquity", "Consolidated Balance Sheets", "USD"),
                        ("currentAssets", "AssetsCurrent", "Consolidated Balance Sheets", "USD"),
                        ("currentLiabilities", "LiabilitiesCurrent", "Consolidated Balance Sheets", "USD"),
                        ("cashAndEquivalents", "CashAndCashEquivalentsAtCarryingValue", "Consolidated Balance Sheets", "USD"),
                        ("operatingCashFlow", "NetCashProvidedByUsedInOperatingActivities", "Consolidated Statements of Cash Flows", "USD"),
                        ("longTermDebt", "LongTermDebtNoncurrent", "Consolidated Balance Sheets", "USD"),
                        ("sharesOutstanding", "CommonStockSharesOutstanding", "Consolidated Statements of Stockholders Equity", "shares")
                    ]

                    for item in concepts {
                        if facts.contains(where: { $0.variableKey == item.key }) { continue }
                        let (val, fy) = extractConcept(item.concept)
                        if let v = val {
                            let periodStr = fy != nil ? "FY\(fy!)" : "Latest Filing"
                            facts.append(ProvenancedFact(
                                entityID: entity.cleanEntityName,
                                variableKey: item.key,
                                numericValue: v,
                                stringValue: String(format: "%.0f", v),
                                unit: item.unit,
                                fiscalPeriod: periodStr,
                                sourceURL: site.url,
                                sourceTitle: site.title,
                                documentSection: item.sec,
                                retrievalDate: site.fetchTimestamp,
                                confidence: 1.0,
                                extractionMethod: "SEC EDGAR Audited XBRL Ingestion",
                                factuality: .verifiedFact
                            ))
                        }
                    }
                }
            }
        }

        // 2. HTML TABLE & PATTERN FACT EXTRACTION
        // Scan for explicit financial reporting statements (e.g., "Revenue: $X billion", "₹X crore")
        let regexPatterns: [(key: String, pattern: String, section: String)] = [
            ("revenue", "(?i)(?:revenue|turnover)[\\s:]+(?:₹|\\$|EUR|GBP)?\\s*([0-9,.]+)\\s*(billion|million|crore|trillion)?", "Operations"),
            ("netIncome", "(?i)(?:net income|profit after tax|pat)[\\s:]+(?:₹|\\$|EUR|GBP)?\\s*([0-9,.]+)\\s*(billion|million|crore|trillion)?", "Operations"),
            ("operatingIncome", "(?i)(?:operating income|ebit|operating profit)[\\s:]+(?:₹|\\$|EUR|GBP)?\\s*([0-9,.]+)\\s*(billion|million|crore|trillion)?", "Operations")
        ]

        for p in regexPatterns {
            if facts.contains(where: { $0.variableKey == p.key }) { continue }
            if let regex = try? NSRegularExpression(pattern: p.pattern, options: []) {
                let nsString = raw as NSString
                let matches = regex.matches(in: raw, options: [], range: NSRange(location: 0, length: min(raw.count, 200_000)))
                if let firstMatch = matches.first, firstMatch.numberOfRanges >= 2 {
                    let numStr = nsString.substring(with: firstMatch.range(at: 1)).replacingOccurrences(of: ",", with: "")
                    var scale: Double = 1.0
                    var unit = entity.jurisdiction == "India" ? "INR" : "USD"

                    if firstMatch.numberOfRanges >= 3 && firstMatch.range(at: 2).location != NSNotFound {
                        let scaleStr = nsString.substring(with: firstMatch.range(at: 2)).lowercased()
                        if scaleStr.contains("billion") { scale = 1e9 }
                        else if scaleStr.contains("million") { scale = 1e6 }
                        else if scaleStr.contains("crore") { scale = 1e7; unit = "INR" }
                        else if scaleStr.contains("trillion") { scale = 1e12 }
                    }

                    if let baseNum = Double(numStr) {
                        let total = baseNum * scale
                        facts.append(ProvenancedFact(
                            entityID: entity.cleanEntityName,
                            variableKey: p.key,
                            numericValue: total,
                            stringValue: String(format: "%.1f", total),
                            unit: unit,
                            fiscalPeriod: "Reported Statement",
                            sourceURL: site.url,
                            sourceTitle: site.title,
                            documentSection: p.section,
                            retrievalDate: site.fetchTimestamp,
                            confidence: 0.85,
                            extractionMethod: "HTML Table & Metric Pattern Scanner",
                            factuality: .verifiedFact
                        ))
                    }
                }
            }
        }

        return facts
    }
}
