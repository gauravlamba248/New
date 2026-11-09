import Foundation

public final class WebDataCrawler: @unchecked Sendable {
    public static let shared = WebDataCrawler()

    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Aegis/1.0"

    public init() {}

    /// Directory where raw website extractions are stored as-is without leaving anything out
    public var rawStorageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Aegis/DataCollector/raw_extracted", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Entity-Scoped Multi-Source Discovery & Crawl

    public func crawlForEntity(
        entity: EntityIdentity,
        countLimit: Int,
        onProgress: @escaping @Sendable (Int, Int, String) -> Void
    ) async throws -> (websites: [RawWebsiteData], ledger: SourceLedger) {
        // 1. Discover Entity-Specific Candidate URLs
        let candidateURLs = await discoverCandidateURLs(for: entity, limit: max(countLimit * 2, 10))
        let discoveredCount = candidateURLs.count

        // 2. Evaluate Sources: Quality, Authority & Independence
        var candidateEntries: [SourceLedgerEntry] = []
        var seenDomains: [String: Int] = [:]

        for u in candidateURLs {
            let host = u.host ?? "open-web"
            let domainGroup = cleanDomainGroup(host)
            let groupCount = (seenDomains[domainGroup] ?? 0) + 1
            seenDomains[domainGroup] = groupCount

            let (cat, quality, authScore) = evaluateSourceQuality(url: u, entity: entity)

            let entry = SourceLedgerEntry(
                url: u,
                domain: host,
                category: cat,
                qualityTier: quality,
                stage: .candidate,
                authorityScore: authScore,
                freshnessDate: Date(),
                httpStatus: nil,
                extractedFactsCount: 0,
                independenceGroupID: "\(domainGroup)_cluster_\(groupCount)",
                underlyingSource: domainGroup,
                rejectionReason: quality == .rejected ? "Domain below minimum authority threshold" : nil
            )
            candidateEntries.append(entry)
        }

        let qualifyingCandidates = candidateEntries.filter { $0.qualityTier != .rejected }
        let candidateCount = qualifyingCandidates.count

        // 3. Select Qualifying Candidates up to User-Requested Limit
        let selectedCount = min(qualifyingCandidates.count, countLimit)
        let selectedCandidates = Array(qualifyingCandidates.prefix(selectedCount))

        var results: [RawWebsiteData] = []
        var updatedEntries: [SourceLedgerEntry] = []
        var accessedCount = 0

        // 4. Fetch Each Selected Website
        for (index, targetEntry) in selectedCandidates.enumerated() {
            let targetURL = targetEntry.url
            let host = targetURL.host ?? targetURL.absoluteString
            onProgress(index + 1, selectedCount, host)

            var entryCopy = targetEntry
            entryCopy.stage = .selected

            do {
                let rawData = try await fetchCompleteRawWebsite(url: targetURL)
                results.append(rawData)
                accessedCount += 1

                entryCopy.stage = .accessed
                entryCopy.httpStatus = rawData.httpStatus
                updatedEntries.append(entryCopy)
            } catch {
                let fallback = RawWebsiteData(
                    url: targetURL,
                    title: "Source: \(host)",
                    httpStatus: 500,
                    rawHTMLPayload: "<!-- Failed to fetch \(targetURL.absoluteString): \(error.localizedDescription) -->",
                    byteSize: 0
                )
                results.append(fallback)
                entryCopy.stage = .rejected
                entryCopy.httpStatus = 500
                entryCopy.rejectionReason = "Network fetch failed: \(error.localizedDescription)"
                updatedEntries.append(entryCopy)
            }
        }

        // Add remaining non-selected candidates to the ledger for transparent tracking
        for entry in candidateEntries where !selectedCandidates.contains(where: { $0.url == entry.url }) {
            var copy = entry
            if copy.qualityTier == .rejected {
                copy.stage = .rejected
            } else {
                copy.stage = .discovered
                copy.rejectionReason = "Candidate available but budget limit reached (Requested: \(countLimit))"
            }
            updatedEntries.append(copy)
        }

        let rejectedCount = updatedEntries.filter { $0.stage == .rejected }.count
        let independentGroups = Set(selectedCandidates.map { $0.independenceGroupID }).count

        let ledger = SourceLedger(
            requestedCount: countLimit,
            discoveredCount: discoveredCount,
            candidateCount: candidateCount,
            selectedCount: selectedCount,
            accessedCount: accessedCount,
            extractedCount: 0,
            validatedCount: 0,
            actuallyUsedCount: 0,
            rejectedCount: rejectedCount,
            independentGroupsCount: independentGroups,
            entries: updatedEntries
        )

        return (results, ledger)
    }

    /// Backward-compatible crawlWebsites routing through EntityResolver
    public func crawlWebsites(
        query: String,
        countLimit: Int,
        onProgress: @escaping @Sendable (Int, Int, String) -> Void
    ) async throws -> [RawWebsiteData] {
        let entity = await EntityResolver.shared.resolve(rawQuery: query)
        let (sites, _) = try await crawlForEntity(entity: entity, countLimit: countLimit, onProgress: onProgress)
        return sites
    }

    /// Fetches the complete website data as it is without leaving anything out
    public func fetchCompleteRawWebsite(url: URL) async throws -> RawWebsiteData {
        var request = URLRequest(url: url)
        if url.host?.contains("sec.gov") == true {
            request.setValue("AegisInvestmentAnalysis admin@aegis-native.internal", forHTTPHeaderField: "User-Agent")
        } else if url.host?.contains("github.com") == true {
            request.setValue("Aegis-Browser-Native-Client", forHTTPHeaderField: "User-Agent")
        } else {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 12.0

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let status = httpResponse?.statusCode ?? 200

        let rawString = String(data: data, encoding: .utf8) ??
                        String(data: data, encoding: .ascii) ??
                        String(data: data, encoding: .isoLatin1) ??
                        String(decoding: data, as: UTF8.self)

        // Extract title
        var title = url.host ?? url.absoluteString
        if let titleRange = rawString.range(of: "(?i)<title[^>]*>(.*?)</title>", options: .regularExpression) {
            let rawTitle = String(rawString[titleRange])
            title = rawTitle
                .replacingOccurrences(of: "(?i)<title[^>]*>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "(?i)</title>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Store as-is to raw disk archive
        let safeHost = (url.host ?? "site").replacingOccurrences(of: "[^a-zA-Z0-9.-]", with: "_", options: .regularExpression)
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(timestamp)_\(safeHost).html"
        let fileURL = rawStorageDirectory.appendingPathComponent(filename)
        try? data.write(to: fileURL, options: .atomic)

        return RawWebsiteData(
            url: url,
            title: title,
            httpStatus: status,
            fetchTimestamp: Date(),
            rawHTMLPayload: rawString,
            byteSize: data.count,
            storageFilePath: fileURL.path
        )
    }

    // MARK: - Dynamic Candidate Source Discovery

    public func discoverCandidateURLs(for entity: EntityIdentity, limit: Int) async -> [URL] {
        var urls: [URL] = []

        switch entity.entityType {
        case .publicCompany:
            let ticker = entity.primaryIdentifier
            let name = entity.cleanEntityName
            let cleanSlug = name.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ticker

            // 1. Live Market Quote (Yahoo Chart API)
            if let u = URL(string: "https://query2.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d") { urls.append(u) }

            // 2. SEC EDGAR Audited XBRL Facts (Resolve CIK)
            let cik = await resolveCIKForTicker(ticker)
            if !cik.isEmpty, let u = URL(string: "https://data.sec.gov/api/xbrl/companyfacts/CIK\(cik).json") { urls.append(u) }

            // 3. Google Finance Quote
            if let u = URL(string: "https://www.google.com/finance/quote/\(ticker):NASDAQ") { urls.append(u) }
            else if let u = URL(string: "https://www.google.com/finance/quote/\(ticker):NYSE") { urls.append(u) }

            // 4. Official Company Domain / Investor Relations (if available)
            if let dom = entity.officialDomain, let u = URL(string: "https://\(dom)") { urls.append(u) }

            // 5. Wikipedia Corporate Overview
            if let u = URL(string: "https://en.wikipedia.org/wiki/\(cleanSlug)") { urls.append(u) }

            // 6. MarketWatch Stock Overview
            if let u = URL(string: "https://www.marketwatch.com/investing/stock/\(ticker.lowercased())") { urls.append(u) }

            // 7. Yahoo Finance Key Statistics
            if let u = URL(string: "https://finance.yahoo.com/quote/\(ticker)/key-statistics") { urls.append(u) }

            // 8. SEC EDGAR Submissions Index
            if !cik.isEmpty, let u = URL(string: "https://data.sec.gov/submissions/CIK\(cik).json") { urls.append(u) }

            // 9. SEC EDGAR Browse Directory
            if !cik.isEmpty, let u = URL(string: "https://www.sec.gov/edgar/browse/?CIK=\(cik)") { urls.append(u) }

            // 10. DuckDuckGo Financial Knowledge Card
            if let enc = ticker.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://api.duckduckgo.com/?q=\(enc)+stock+quote&format=json") { urls.append(u) }

            // 11. Reuters Company Profile
            if let u = URL(string: "https://www.reuters.com/markets/companies/\(ticker)") { urls.append(u) }

            // 12. CrossRef Corporate Research
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://api.crossref.org/works?query=\(enc)&rows=4") { urls.append(u) }

        case .privateCompany:
            let name = entity.cleanEntityName
            let cleanSlug = name.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name

            // 1. Official Corporate Domain
            if let dom = entity.officialDomain, let u = URL(string: "https://\(dom)") { urls.append(u) }

            // 2. Official News / Press
            if let dom = entity.officialDomain, let u = URL(string: "https://\(dom)/news") { urls.append(u) }

            // 3. Wikipedia Corporate Profile
            if let u = URL(string: "https://en.wikipedia.org/wiki/\(cleanSlug)") { urls.append(u) }

            // 4. Wikidata Entity API
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://www.wikidata.org/w/api.php?action=wbsearchentities&search=\(enc)&language=en&format=json") { urls.append(u) }

            // 5. DuckDuckGo Corporate Intelligence Card
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://api.duckduckgo.com/?q=\(enc)+company+profile&format=json") { urls.append(u) }

            // 6. CrossRef Publications
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://api.crossref.org/works?query=\(enc)&rows=4") { urls.append(u) }

        case .techProject:
            let repoSlug = entity.primaryIdentifier // e.g. "kubernetes/kubernetes"
            let name = entity.cleanEntityName
            let cleanSlug = name.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name

            // 1. GitHub Repository API
            if let u = URL(string: "https://api.github.com/repos/\(repoSlug)") { urls.append(u) }

            // 2. GitHub Releases API
            if let u = URL(string: "https://api.github.com/repos/\(repoSlug)/releases?per_page=5") { urls.append(u) }

            // 3. Official Documentation Website
            if let dom = entity.officialDomain, !dom.contains("github.com"), let u = URL(string: "https://\(dom)") { urls.append(u) }

            // 4. Wikipedia Technical Architecture Overview
            if let u = URL(string: "https://en.wikipedia.org/wiki/\(cleanSlug)") { urls.append(u) }

            // 5. GitHub README Raw
            if let u = URL(string: "https://raw.githubusercontent.com/\(repoSlug)/master/README.md") { urls.append(u) }

            // 6. DuckDuckGo Project Card
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://api.duckduckgo.com/?q=\(enc)+software+architecture&format=json") { urls.append(u) }

            // 7. CrossRef Technical Papers
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://api.crossref.org/works?query=\(enc)+system+architecture&rows=4") { urls.append(u) }

        case .generalTopic, .nonProfitOrg:
            let name = entity.cleanEntityName
            let cleanSlug = name.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name

            // 1. Wikipedia Deep Article
            if let u = URL(string: "https://en.wikipedia.org/wiki/\(cleanSlug)") { urls.append(u) }

            // 2. Wikidata Knowledge Entity
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://www.wikidata.org/w/api.php?action=wbsearchentities&search=\(enc)&language=en&format=json") { urls.append(u) }

            // 3. CrossRef Academic Research
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://api.crossref.org/works?query=\(enc)&rows=6") { urls.append(u) }

            // 4. DuckDuckGo Instant Answer
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://api.duckduckgo.com/?q=\(enc)&format=json") { urls.append(u) }

        case .unverified:
            return []
        }

        // Return distinct URLs up to limit
        var distinct: [URL] = []
        for u in urls where !distinct.contains(u) {
            distinct.append(u)
        }
        return Array(distinct.prefix(limit))
    }

    // MARK: - Source Evaluation & Quality Scoring

    public func evaluateSourceQuality(url: URL, entity: EntityIdentity) -> (category: SourceCategory, tier: SourceQualityTier, authorityScore: Double) {
        let host = (url.host ?? "").lowercased()

        // 1. Regulatory Filings (SEC EDGAR)
        if host.contains("sec.gov") {
            return (.regulatoryFiling, .primaryAuthoritative, 1.0)
        }

        // 2. Primary GitHub Repositories for Tech Projects
        if host.contains("github.com") && entity.entityType == .techProject {
            return (.primaryRepository, .primaryAuthoritative, 0.98)
        }

        // 3. Official Entity Domain
        if let dom = entity.officialDomain?.lowercased(), !dom.isEmpty && (host == dom || host.hasSuffix(".\(dom)")) {
            return (.officialEntityDoc, .primaryAuthoritative, 0.95)
        }

        // 4. Primary Market Exchanges & Official Quotation Endpoints
        if host.contains("query2.finance.yahoo.com") || host.contains("google.com/finance") || host.contains("nasdaq.com") || host.contains("nyse.com") {
            return (.marketExchangeData, .highQuality, 0.90)
        }

        // 5. Academic Journals & DOI Repositories
        if host.contains("crossref.org") || host.contains("arxiv.org") || host.contains("ieee.org") {
            return (.academicJournal, .highQuality, 0.88)
        }

        // 6. Reputable Financial & News Media
        if host.contains("reuters.com") || host.contains("bloomberg.com") || host.contains("marketwatch.com") || host.contains("wsj.com") || host.contains("ft.com") {
            return (.reputableNewsMedia, .highQuality, 0.85)
        }

        // 7. Encyclopedic & Knowledge Bases
        if host.contains("wikipedia.org") || host.contains("wikidata.org") {
            return (.encyclopedic, .mediumQuality, 0.75)
        }

        // 8. DuckDuckGo Knowledge API
        if host.contains("duckduckgo.com") {
            return (.secondaryWeb, .mediumQuality, 0.70)
        }

        // Low Quality / Rejected Filter (Unknown Scrapers / Ads)
        let lowQualityIndicators = ["buzzfeed", "blogspot", "wordpress", "pinterest", "tiktok"]
        if lowQualityIndicators.contains(where: { host.contains($0) }) {
            return (.secondaryWeb, .rejected, 0.20)
        }

        return (.secondaryWeb, .lowQuality, 0.50)
    }

    private func cleanDomainGroup(_ host: String) -> String {
        let parts = host.components(separatedBy: ".")
        if parts.count >= 2 {
            return parts.suffix(2).joined(separator: ".")
        }
        return host
    }

    private func resolveCIKForTicker(_ ticker: String) async -> String {
        let catalog: [String: String] = [
            "F": "0000037996",
            "TSLA": "0001318605",
            "AAPL": "0000320193",
            "MSFT": "0000789019",
            "NVDA": "0001045810",
            "GOOGL": "0001652044",
            "AMZN": "0001018724",
            "META": "0001326801",
            "BA": "0000012927",
            "PFE": "0000078003",
            "GM": "0001467858",
            "DIS": "0001744489",
            "KO": "0000021344",
            "PEP": "0000077476",
            "WMT": "0000104169",
            "JPM": "0000019617",
            "INTC": "0000050863",
            "AMD": "0000002488",
            "NKE": "0000320187",
            "SBUX": "0000829224",
            "TM": "0001094517",
            "SONY": "0000313838",
            "COST": "0000909832"
        ]
        return catalog[ticker] ?? ""
    }

    // MARK: - Query Intent Classifier Helpers

    public static func isTimeZoneOrTimeQuery(_ lower: String) -> Bool {
        let timeKeywords = [
            "what time is it", "what time is", "time in ", "current time", "time difference",
            "what is the time", "am what time", "pm what time", "time zone", "timezone",
            "hours behind", "hours ahead", "time now in", "what time in"
        ]
        for kw in timeKeywords {
            if lower.contains(kw) { return true }
        }
        if (lower.contains("am") || lower.contains("pm") || lower.contains("o'clock") || lower.contains(":")) &&
           (lower.contains("time") && (lower.contains("in ") || lower.contains("at "))) {
            return true
        }
        return false
    }

    public static func isFinancialOrStockQuery(_ lower: String) -> Bool {
        let stockKeywords = [
            "financial analysis", "financial report", "analyze stock", "analyze brand",
            "balance sheet", "income statement", "piotroski", "altman z", "dcf valuation",
            "graham number", "dupont", "valuation of", "financial health", "financial stability",
            "ratios of", "financials of", "stock analysis", "company analysis", "analyze financials",
            "pe ratio of", "market cap of", "revenue of", "net income of", "profitability of",
            "price of 1", "stock price", "share price",
            "earnings transcript", "earnings call", "forward guidance", "supply chain",
            "supply chain map", "suppliers of", "news sentiment", "regulatory radar", "splc",
            "chokepoints", "antitrust risk", "guidance of", "nasdaq", "nyse", "ticker", "equity"
        ]
        for kw in stockKeywords {
            if lower.contains(kw) { return true }
        }
        return false
    }
}
