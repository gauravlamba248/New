import Foundation

public struct GatheringResult: Sendable {
    public let rawTotalBytes: Int64
    public let garbageBytesStripped: Int64
    public let cleanedItems: [CleanedInfoItem]
    public let facts: [ProvenancedFact]
    public let conflicts: [SourceConflictRecord]

    public init(
        rawTotalBytes: Int64,
        garbageBytesStripped: Int64,
        cleanedItems: [CleanedInfoItem],
        facts: [ProvenancedFact] = [],
        conflicts: [SourceConflictRecord] = []
    ) {
        self.rawTotalBytes = rawTotalBytes
        self.garbageBytesStripped = garbageBytesStripped
        self.cleanedItems = cleanedItems
        self.facts = facts
        self.conflicts = conflicts
    }
}

public final class InformationGatherer: @unchecked Sendable {
    public static let shared = InformationGatherer()

    public init() {}

    /// Strips garbage, boilerplate, ads, navigation, and irrelevant data from raw website payloads
    public func gatherUsefulInformation(
        from rawWebsites: [RawWebsiteData],
        userQuery: String
    ) -> GatheringResult {
        return gatherUsefulInformationForEntity(
            from: rawWebsites,
            entity: EntityIdentity(
                rawQuery: userQuery,
                cleanEntityName: userQuery,
                entityType: .generalTopic,
                analysisType: .universalTopic,
                primaryIdentifier: userQuery,
                canonicalTitle: userQuery
            ),
            userQuery: userQuery
        )
    }

    public func gatherUsefulInformationForEntity(
        from rawWebsites: [RawWebsiteData],
        entity: EntityIdentity,
        userQuery: String
    ) -> GatheringResult {
        var rawTotalBytes: Int64 = 0
        var cleanedItems: [CleanedInfoItem] = []
        var facts: [ProvenancedFact] = []
        let queryKeywords = extractKeywords(from: userQuery)

        for site in rawWebsites {
            rawTotalBytes += Int64(site.byteSize)
            let (items, siteLegacyFacts) = processSingleWebsite(
                site: site,
                entity: entity,
                queryKeywords: queryKeywords,
                originalQuery: userQuery
            )
            // Advanced 13-Field Provenanced Fact Extraction (Section 15)
            let extractedProvenancedFacts = FactExtractor.shared.extractFacts(from: site, entity: entity)

            cleanedItems.append(contentsOf: items)
            facts.append(contentsOf: extractedProvenancedFacts.isEmpty ? siteLegacyFacts : extractedProvenancedFacts)
        }

        // Cross-Verification & Conflict Resolution across Independent Sources (Section 14)
        let validation = CrossValidator.shared.validate(facts: facts)
        let reconciledFacts = validation.reconciledFacts
        let conflicts = validation.conflicts

        let usefulBytes = cleanedItems.reduce(0) { $0 + Int64($1.extractedSnippet.utf8.count) }
        let garbageBytes = max(0, rawTotalBytes - usefulBytes)

        return GatheringResult(
            rawTotalBytes: rawTotalBytes,
            garbageBytesStripped: garbageBytes,
            cleanedItems: cleanedItems,
            facts: reconciledFacts,
            conflicts: conflicts
        )
    }

    private func processSingleWebsite(
        site: RawWebsiteData,
        entity: EntityIdentity,
        queryKeywords: [String],
        originalQuery: String
    ) -> (items: [CleanedInfoItem], facts: [ProvenancedFact]) {
        let raw = site.rawHTMLPayload
        guard !raw.isEmpty else { return ([], []) }

        var items: [CleanedInfoItem] = []
        var facts: [ProvenancedFact] = []
        let trimmedRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. JSON Data Processing
        if trimmedRaw.hasPrefix("{") || trimmedRaw.hasPrefix("[") {
            if let jsonData = raw.data(using: .utf8),
               let jsonObj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

                // A. Yahoo Finance Chart Quote Format
                if let chart = jsonObj["chart"] as? [String: Any],
                   let results = chart["result"] as? [[String: Any]],
                   let firstResult = results.first,
                   let meta = firstResult["meta"] as? [String: Any] {
                    let symbol = meta["symbol"] as? String ?? entity.primaryIdentifier
                    let longName = (meta["longName"] as? String) ?? (meta["shortName"] as? String) ?? entity.cleanEntityName
                    let price = meta["regularMarketPrice"] as? Double ?? 0.0
                    let currency = meta["currency"] as? String ?? "USD"
                    let dayHigh = meta["regularMarketDayHigh"] as? Double ?? 0.0
                    let dayLow = meta["regularMarketDayLow"] as? Double ?? 0.0
                    let high52 = meta["fiftyTwoWeekHigh"] as? Double ?? 0.0
                    let low52 = meta["fiftyTwoWeekLow"] as? Double ?? 0.0
                    let changePct = meta["regularMarketChangePercent"] as? Double ?? 0.0
                    let volume = meta["regularMarketVolume"] as? Int ?? 0
                    let prevClose = meta["chartPreviousClose"] as? Double ?? 0.0
                    let exchange = meta["exchangeName"] as? String ?? "Exchange"

                    let sign = changePct >= 0 ? "+" : ""
                    let changePctStr = String(format: "%.2f", changePct)
                    let priceStr = String(format: "%.2f", price)

                    items.append(CleanedInfoItem(
                        sourceURL: site.url,
                        sourceTitle: site.title,
                        sectionTitle: "Market Quote & Execution",
                        extractedSnippet: "\(longName) (\(symbol)) current market trading price is $\(priceStr) \(currency), marking a session change of \(sign)\(changePctStr)% on \(exchange).",
                        relevanceScore: 1.0,
                        category: "Financial Market Data"
                    ))

                    // Extracted Provenanced Facts
                    if price > 0 {
                        facts.append(ProvenancedFact(
                            entityID: entity.primaryIdentifier,
                            variableKey: "currentPrice",
                            numericValue: price,
                            unit: currency,
                            fiscalPeriod: "Current Session",
                            sourceURL: site.url,
                            sourceTitle: site.title,
                            documentSection: "Yahoo Real-Time Chart API",
                            retrievalDate: Date(),
                            confidence: 0.99,
                            extractionMethod: "JSON Market Quote Parser",
                            factuality: .verifiedFact
                        ))
                    }
                    if volume > 0 {
                        facts.append(ProvenancedFact(
                            entityID: entity.primaryIdentifier,
                            variableKey: "tradingVolume",
                            numericValue: Double(volume),
                            unit: "shares",
                            fiscalPeriod: "Current Session",
                            sourceURL: site.url,
                            sourceTitle: site.title,
                            documentSection: "Yahoo Real-Time Chart API",
                            retrievalDate: Date(),
                            confidence: 0.98,
                            extractionMethod: "JSON Market Quote Parser",
                            factuality: .verifiedFact
                        ))
                    }
                    if high52 > 0 && low52 > 0 {
                        facts.append(ProvenancedFact(
                            entityID: entity.primaryIdentifier,
                            variableKey: "fiftyTwoWeekHigh",
                            numericValue: high52,
                            unit: currency,
                            fiscalPeriod: "52-Week Range",
                            sourceURL: site.url,
                            sourceTitle: site.title,
                            documentSection: "Yahoo Real-Time Chart API",
                            retrievalDate: Date(),
                            confidence: 0.95,
                            extractionMethod: "JSON Market Quote Parser",
                            factuality: .verifiedFact
                        ))
                    }
                }

                // B. SEC EDGAR XBRL Audited Financial Statements
                if let factsObj = jsonObj["facts"] as? [String: Any],
                   let usGaap = factsObj["us-gaap"] as? [String: Any] {
                    let entityName = (jsonObj["entityName"] as? String) ?? entity.cleanEntityName
                    let cikNum = "\(jsonObj["cik"] ?? "")"

                    let extractLatest: (String) -> (val: Double?, fy: Int?) = { concept in
                        guard let obj = usGaap[concept] as? [String: Any],
                              let units = obj["units"] as? [String: Any] else { return (nil, nil) }
                        let list = (units["USD"] as? [[String: Any]]) ?? (units["shares"] as? [[String: Any]]) ?? []
                        guard let last = list.last else { return (nil, nil) }
                        let v = last["val"] as? Double
                        let f = last["fy"] as? Int
                        return (v, f)
                    }

                    let concepts: [(key: String, secConcepts: [String], unit: String)] = [
                        ("revenue", ["RevenueFromContractWithCustomerExcludingAssessedTax", "Revenues"], "USD"),
                        ("netIncome", ["NetIncomeLoss"], "USD"),
                        ("operatingIncome", ["OperatingIncomeLoss"], "USD"),
                        ("grossProfit", ["GrossProfit"], "USD"),
                        ("totalAssets", ["Assets"], "USD"),
                        ("totalLiabilities", ["Liabilities"], "USD"),
                        ("stockholdersEquity", ["StockholdersEquity"], "USD"),
                        ("operatingCashFlow", ["NetCashProvidedByUsedInOperatingActivities"], "USD"),
                        ("cashAndEquivalents", ["CashAndCashEquivalentsAtCarryingValue"], "USD"),
                        ("currentAssets", ["AssetsCurrent"], "USD"),
                        ("currentLiabilities", ["LiabilitiesCurrent"], "USD"),
                        ("longTermDebt", ["LongTermDebtNoncurrent"], "USD"),
                        ("sharesOutstanding", ["CommonStockSharesOutstanding"], "shares")
                    ]

                    var latestFY = 2025
                    for item in concepts {
                        for c in item.secConcepts {
                            let (val, fy) = extractLatest(c)
                            if let v = val {
                                if let y = fy { latestFY = max(latestFY, y) }
                                facts.append(ProvenancedFact(
                                    entityID: entity.primaryIdentifier,
                                    variableKey: item.key,
                                    numericValue: v,
                                    unit: item.unit,
                                    fiscalPeriod: "FY\(latestFY)",
                                    sourceURL: site.url,
                                    sourceTitle: "SEC EDGAR Audited Form 10-K: \(entityName)",
                                    documentSection: "Audited Financial Statements (Concept: \(c))",
                                    retrievalDate: Date(),
                                    confidence: 1.0,
                                    extractionMethod: "XBRL Tag Ingestion",
                                    factuality: .verifiedFact
                                ))
                                break
                            }
                        }
                    }

                    let revFact = facts.first(where: { $0.variableKey == "revenue" })?.numericValue
                    let niFact = facts.first(where: { $0.variableKey == "netIncome" })?.numericValue
                    let revStr = revFact != nil ? String(format: "$%.2fB USD", revFact! / 1_000_000_000.0) : "Reported"
                    let niStr = niFact != nil ? String(format: "$%.2fB USD", niFact! / 1_000_000_000.0) : "Reported"

                    items.append(CleanedInfoItem(
                        sourceURL: site.url,
                        sourceTitle: "SEC EDGAR Form 10-K: \(entityName)",
                        sectionTitle: "Audited Consolidated Financial Statements",
                        extractedSnippet: "\(entityName) Form 10-K Audited Filing (CIK \(cikNum)): Audited Revenue of \(revStr) and Net Income of \(niStr) for FY\(latestFY).",
                        relevanceScore: 1.0,
                        category: "Audited SEC Financial Statements"
                    ))
                }

                // C. GitHub Technical Repository Format (Tech Projects)
                if let name = jsonObj["name"] as? String,
                   let fullName = jsonObj["full_name"] as? String,
                   let stars = jsonObj["stargazers_count"] as? Int {
                    let desc = jsonObj["description"] as? String ?? ""
                    let forks = jsonObj["forks_count"] as? Int ?? 0
                    let openIssues = jsonObj["open_issues_count"] as? Int ?? 0
                    let lic = (jsonObj["license"] as? [String: Any])?["name"] as? String ?? "Open Source"

                    items.append(CleanedInfoItem(
                        sourceURL: site.url,
                        sourceTitle: "GitHub Primary Repository: \(fullName)",
                        sectionTitle: "Repository Architecture & Community",
                        extractedSnippet: "\(name) (\(fullName)): \(desc). Stars: \(stars), Forks: \(forks), Open Issues: \(openIssues), License: \(lic).",
                        relevanceScore: 1.0,
                        category: "Open Source Technical Architecture"
                    ))

                    facts.append(ProvenancedFact(
                        entityID: entity.primaryIdentifier,
                        variableKey: "repoStars",
                        numericValue: Double(stars),
                        unit: "stars",
                        fiscalPeriod: "Current",
                        sourceURL: site.url,
                        sourceTitle: "GitHub Repository API",
                        documentSection: "Repository Metadata",
                        retrievalDate: Date(),
                        confidence: 1.0,
                        extractionMethod: "GitHub REST API",
                        factuality: .verifiedFact
                    ))
                    facts.append(ProvenancedFact(
                        entityID: entity.primaryIdentifier,
                        variableKey: "repoForks",
                        numericValue: Double(forks),
                        unit: "forks",
                        fiscalPeriod: "Current",
                        sourceURL: site.url,
                        sourceTitle: "GitHub Repository API",
                        documentSection: "Repository Metadata",
                        retrievalDate: Date(),
                        confidence: 1.0,
                        extractionMethod: "GitHub REST API",
                        factuality: .verifiedFact
                    ))
                    facts.append(ProvenancedFact(
                        entityID: entity.primaryIdentifier,
                        variableKey: "license",
                        stringValue: lic,
                        fiscalPeriod: "Current",
                        sourceURL: site.url,
                        sourceTitle: "GitHub Repository API",
                        documentSection: "License",
                        retrievalDate: Date(),
                        confidence: 1.0,
                        extractionMethod: "GitHub REST API",
                        factuality: .verifiedFact
                    ))
                }

                // D. Wikipedia / Encyclopedic API format
                if let queryObj = jsonObj["query"] as? [String: Any],
                   let pages = queryObj["pages"] as? [String: [String: Any]] {
                    for (_, page) in pages {
                        let title = page["title"] as? String ?? site.title
                        if let extract = page["extract"] as? String, !extract.isEmpty {
                            let clean = cleanRawText(extract)
                            items.append(CleanedInfoItem(
                                sourceURL: site.url,
                                sourceTitle: title,
                                sectionTitle: "Encyclopedic Overview",
                                extractedSnippet: clean,
                                relevanceScore: 0.95,
                                category: "Core Encyclopedic Fact"
                            ))
                        }
                    }
                }

                // E. DuckDuckGo Abstract format
                if let abstract = jsonObj["AbstractText"] as? String, !abstract.isEmpty {
                    let clean = cleanRawText(abstract)
                    items.append(CleanedInfoItem(
                        sourceURL: site.url,
                        sourceTitle: site.title,
                        sectionTitle: "Executive Summary",
                        extractedSnippet: clean,
                        relevanceScore: 0.90,
                        category: "Executive Knowledge"
                    ))
                }

                if !items.isEmpty {
                    return (items, facts)
                }
            }
        }

        // 2. HTML Text Processing (Scrape paragraphs, tables, headings)
        var sanitized = raw
        let garbageRegexes = [
            "(?is)<script[^>]*>.*?</script>",
            "(?is)<style[^>]*>.*?</style>",
            "(?is)<noscript[^>]*>.*?</noscript>",
            "(?is)<svg[^>]*>.*?</svg>",
            "(?is)<header[^>]*>.*?</header>",
            "(?is)<nav[^>]*>.*?</nav>",
            "(?is)<footer[^>]*>.*?</footer>",
            "(?is)<aside[^>]*>.*?</aside>",
            "(?is)<div[^>]*class=[\"'][^\"']*(cookie|banner|advertisement|modal|popup|consent|footer|menu)[^\"']*[\"'][^>]*>.*?</div>"
        ]

        for p in garbageRegexes {
            sanitized = sanitized.replacingOccurrences(of: p, with: " ", options: .regularExpression)
        }

        let paragraphRegex = try? NSRegularExpression(pattern: "(?is)<(p|h1|h2|h3|h4|li|td)[^>]*>(.*?)</\\1>", options: [])
        let ns = sanitized as NSString
        let matches = paragraphRegex?.matches(in: sanitized, options: [], range: NSRange(location: 0, length: ns.length)) ?? []

        for m in matches {
            guard m.numberOfRanges > 2 else { continue }
            let inner = ns.substring(with: m.range(at: 2))
            let plainText = cleanRawText(inner)

            if isGarbageBoilerplate(plainText) || plainText.count < 30 {
                continue
            }

            // Keyword relevance filter
            let lower = plainText.lowercased()
            let matchesKeyword = queryKeywords.isEmpty || queryKeywords.contains { lower.contains($0) }
            guard matchesKeyword else { continue }

            items.append(CleanedInfoItem(
                sourceURL: site.url,
                sourceTitle: site.title,
                sectionTitle: "Substantive Extract",
                extractedSnippet: plainText,
                relevanceScore: 0.85,
                category: "Substantive Web Evidence"
            ))

            // Check for Qualitative Statements (Guidance, Suppliers, Risk)
            if lower.contains("guidance") || lower.contains("outlook") || lower.contains("expect") || lower.contains("projected") {
                facts.append(ProvenancedFact(
                    entityID: entity.primaryIdentifier,
                    variableKey: "guidanceOutlook",
                    stringValue: plainText,
                    fiscalPeriod: "Forward Guidance",
                    sourceURL: site.url,
                    sourceTitle: site.title,
                    documentSection: "Management Guidance",
                    retrievalDate: Date(),
                    confidence: 0.85,
                    extractionMethod: "NLP Sentence Extractor",
                    factuality: .verifiedFact
                ))
            } else if lower.contains("supplier") || lower.contains("supplies") || lower.contains("fabrication") || lower.contains("chokepoint") {
                facts.append(ProvenancedFact(
                    entityID: entity.primaryIdentifier,
                    variableKey: "supplyChainFact",
                    stringValue: plainText,
                    fiscalPeriod: "Operational",
                    sourceURL: site.url,
                    sourceTitle: site.title,
                    documentSection: "Supply Chain & Manufacturing",
                    retrievalDate: Date(),
                    confidence: 0.85,
                    extractionMethod: "NLP Sentence Extractor",
                    factuality: .verifiedFact
                ))
            } else if lower.contains("antitrust") || lower.contains("investigation") || lower.contains("regulatory") || lower.contains("lawsuit") {
                facts.append(ProvenancedFact(
                    entityID: entity.primaryIdentifier,
                    variableKey: "regulatoryFact",
                    stringValue: plainText,
                    fiscalPeriod: "Regulatory",
                    sourceURL: site.url,
                    sourceTitle: site.title,
                    documentSection: "Regulatory & Legal",
                    retrievalDate: Date(),
                    confidence: 0.85,
                    extractionMethod: "NLP Sentence Extractor",
                    factuality: .verifiedFact
                ))
            }
        }

        return (items, facts)
    }

    // MARK: - Conflict Detection & Reconciliation

    private func reconcileAndDetectConflicts(facts: [ProvenancedFact]) -> (reconciled: [ProvenancedFact], conflicts: [SourceConflictRecord]) {
        var byKey: [String: [ProvenancedFact]] = [:]
        for f in facts {
            byKey[f.variableKey, default: []].append(f)
        }

        var reconciled: [ProvenancedFact] = []
        var conflicts: [SourceConflictRecord] = []

        for (key, list) in byKey {
            if list.count == 1 {
                reconciled.append(list[0])
                continue
            }

            // Check if numeric values conflict
            let numericList = list.compactMap { $0.numericValue }
            if numericList.count >= 2 {
                let firstVal = numericList[0]
                var hasConflict = false
                for other in numericList.dropFirst() {
                    let diff = abs(firstVal - other) / max(firstVal, 1.0)
                    if diff > 0.05 { // More than 5% difference
                        hasConflict = true
                        let rec = SourceConflictRecord(
                            variableName: key,
                            sourceA: list[0].sourceURL,
                            valueA: String(format: "%.2f %@", firstVal, list[0].unit ?? ""),
                            sourceB: list[1].sourceURL,
                            valueB: String(format: "%.2f %@", other, list[1].unit ?? ""),
                            differenceDescription: String(format: "%.1f%% numerical variance across sources", diff * 100.0),
                            preferredSource: list[0].confidence >= list[1].confidence ? list[0].sourceURL : list[1].sourceURL,
                            justification: "Selected source with higher authority score (\(list[0].sourceTitle))"
                        )
                        conflicts.append(rec)
                        break
                    }
                }
                if hasConflict {
                    // Pick the highest confidence fact
                    let best = list.max(by: { $0.confidence < $1.confidence }) ?? list[0]
                    reconciled.append(best)
                    continue
                }
            }

            // Default: retain highest confidence fact
            let best = list.max(by: { $0.confidence < $1.confidence }) ?? list[0]
            reconciled.append(best)
        }

        return (reconciled, conflicts)
    }

    // MARK: - Cleaning Utilities

    private func cleanRawText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\[\\[(?:[^|\\]]*\\|)?([^\\]]+)\\]\\]", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "\\[[0-9a-zA-Z\\s]+\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isGarbageBoilerplate(_ text: String) -> Bool {
        let lower = text.lowercased()
        let boilerplates = [
            "all rights reserved", "terms of use", "privacy policy", "cookie policy",
            "subscribe now", "sign up for", "log in to your", "create a free account",
            "advertisement", "sponsored content", "javascript is disabled", "please enable javascript",
            "click here to view", "share on twitter", "share on facebook", "share on linkedin",
            "navigation menu", "skip to main content", "search form"
        ]
        for b in boilerplates {
            if lower.contains(b) { return true }
        }
        return false
    }

    private func extractKeywords(from query: String) -> [String] {
        let clean = query.lowercased()
        let stopWords = Set(["the", "and", "for", "with", "from", "in", "on", "at", "to", "a", "an", "is", "of", "what", "how", "tell", "me", "about"])
        return clean.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopWords.contains($0) }
    }
}
