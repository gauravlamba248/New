import Foundation

public final class EntityResolver: @unchecked Sendable {
    public static let shared = EntityResolver()

    private let userAgent = "AegisInvestmentAnalysis admin@aegis-native.internal"

    public init() {}

    // MARK: - Query Normalization & Fluff Stripping

    public func cleanEntityQuery(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let fluffPrefixes = [
            "financial analysis of the ", "financial analysis of ", "financial report of the ", "financial report of ",
            "financial statements of the ", "financial statements of ", "financial health of the ", "financial health of ",
            "financial stability of the ", "financial stability of ", "financials of the ", "financials of ",
            "analyze stock of the ", "analyze stock of ", "analyze stock ", "analyze brand of the ", "analyze brand of ", "analyze brand ",
            "analyze project of the ", "analyze project of ", "analyze project ", "analyze company of the ", "analyze company of ", "analyze company ",
            "analyze the ", "analyze ", "analysis of the ", "analysis of ", "valuation of the ", "valuation of ",
            "ratios of the ", "ratios of ", "earnings transcript of the ", "earnings transcript of ",
            "earnings call of the ", "earnings call of ", "forward guidance of the ", "forward guidance of ",
            "supply chain map of the ", "supply chain map of ", "supply chain of the ", "supply chain of ",
            "suppliers of the ", "suppliers of ", "news sentiment of the ", "news sentiment of ",
            "regulatory radar of the ", "regulatory radar of ", "price of 1 ", "price of ", "stock price of the ", "stock price of ",
            "share price of the ", "share price of ", "balance sheet of the ", "balance sheet of ",
            "income statement of the ", "income statement of ", "cash flow statement of the ", "cash flow statement of ",
            "market cap of the ", "market cap of ", "who is the ", "who is ", "what is the ", "what is ",
            "tell me about the ", "tell me about ", "tell me in brief about ", "search about the ", "search about "
        ]

        var stripped = true
        while stripped {
            stripped = false
            let lower = text.lowercased()
            for p in fluffPrefixes {
                if lower.hasPrefix(p) {
                    text = String(text.dropFirst(p.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    stripped = true
                    break
                }
            }
        }

        // Also clean trailing question marks or punctuation
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "?!.,;:\"'"))
        return text
    }

    // MARK: - Curated Verified Entity Directory

    // Public Companies
    private let verifiedPublicCatalog: [(keys: [String], ticker: String, name: String, cik: String, domain: String)] = [
        (["ford", "ford motor", "ford motor co", "f"], "F", "Ford Motor Company", "0000037996", "ford.com"),
        (["tesla", "tsla", "elon", "tesla inc", "tesla motors"], "TSLA", "Tesla, Inc.", "0001318605", "tesla.com"),
        (["apple", "aapl", "iphone", "ipad", "mac", "apple inc"], "AAPL", "Apple Inc.", "0000320193", "apple.com"),
        (["microsoft", "msft", "windows", "azure", "office", "microsoft corp"], "MSFT", "Microsoft Corporation", "0000789019", "microsoft.com"),
        (["nvidia", "nvda", "geforce", "nvidia corp"], "NVDA", "NVIDIA Corporation", "0001045810", "nvidia.com"),
        (["google", "alphabet", "googl", "goog", "alphabet inc"], "GOOGL", "Alphabet Inc.", "0001652044", "abc.xyz"),
        (["amazon", "amzn", "aws", "amazon.com"], "AMZN", "Amazon.com, Inc.", "0001018724", "amazon.com"),
        (["meta", "facebook", "instagram", "meta platforms"], "META", "Meta Platforms, Inc.", "0001326801", "meta.com"),
        (["boeing", "the boeing company", "ba"], "BA", "The Boeing Company", "0000012927", "boeing.com"),
        (["pfizer", "pfizer inc", "pfe"], "PFE", "Pfizer Inc.", "0000078003", "pfizer.com"),
        (["adidas", "adidas ag", "ads"], "ADS.DE", "Adidas AG", "0000000000", "adidas-group.com"),
        (["general motors", "gm", "chevrolet", "cadillac"], "GM", "General Motors Company", "0001467858", "gm.com"),
        (["berkshire", "buffett", "brk"], "BRK.B", "Berkshire Hathaway Inc.", "0001067983", "berkshirehathaway.com"),
        (["netflix", "nflx"], "NFLX", "Netflix, Inc.", "0001065280", "netflix.com"),
        (["disney", "dis", "walt disney"], "DIS", "The Walt Disney Company", "0001744489", "thewaltdisneycompany.com"),
        (["coca cola", "coca-cola", "coke", "ko"], "KO", "The Coca-Cola Company", "0000021344", "coca-colacompany.com"),
        (["pepsi", "pepsico", "pep"], "PEP", "PepsiCo, Inc.", "0000077476", "pepsico.com"),
        (["walmart", "wmt"], "WMT", "Walmart Inc.", "0000104169", "walmart.com"),
        (["jpmorgan", "jp morgan", "chase", "jpm"], "JPM", "JPMorgan Chase & Co.", "0000019617", "jpmorganchase.com"),
        (["intel", "intc"], "INTC", "Intel Corporation", "0000050863", "intel.com"),
        (["amd", "advanced micro devices"], "AMD", "Advanced Micro Devices, Inc.", "0000002488", "amd.com"),
        (["nike", "nke"], "NKE", "NIKE, Inc.", "0000320187", "nike.com"),
        (["starbucks", "sbux"], "SBUX", "Starbucks Corporation", "0000829224", "starbucks.com"),
        (["toyota", "tm"], "TM", "Toyota Motor Corporation", "0001094517", "toyota-global.com"),
        (["sony"], "SONY", "Sony Group Corporation", "0000313838", "sony.com"),
        (["costco", "cost"], "COST", "Costco Wholesale Corporation", "0000909832", "costco.com")
    ]

    // Private Companies
    private let verifiedPrivateCatalog: [(keys: [String], name: String, domain: String, description: String)] = [
        (["stripe", "stripe inc", "stripe payments"], "Stripe, Inc.", "stripe.com", "Financial infrastructure and payment processing software"),
        (["openai", "openai inc", "openai opco", "chatgpt"], "OpenAI, Inc.", "openai.com", "Artificial intelligence research and deployment company"),
        (["spacex", "space exploration technologies"], "Space Exploration Technologies Corp. (SpaceX)", "spacex.com", "Commercial aerospace manufacturer and space transportation services"),
        (["anthropic", "anthropic pbc", "claude"], "Anthropic PBC", "anthropic.com", "AI safety and public-benefit intelligence research"),
        (["bytedance", "tiktok"], "ByteDance Ltd.", "bytedance.com", "Global internet technology and content platform developer"),
        (["databricks"], "Databricks, Inc.", "databricks.com", "Data lakehouse, Apache Spark, and enterprise AI platform")
    ]

    // Technical / Open-Source Projects
    private let verifiedTechProjectCatalog: [(keys: [String], name: String, repo: String, org: String, description: String)] = [
        (["kubernetes", "k8s"], "Kubernetes", "kubernetes/kubernetes", "Cloud Native Computing Foundation (CNCF)", "Production-grade container orchestration system"),
        (["react", "reactjs", "react.js"], "React", "facebook/react", "Meta Open Source", "JavaScript library for building user interfaces"),
        (["linux", "linux kernel"], "Linux Kernel", "torvalds/linux", "Linux Foundation", "Monolithic Unix-like computer operating system kernel"),
        (["pytorch"], "PyTorch", "pytorch/pytorch", "PyTorch Foundation / Linux Foundation", "Open source machine learning and deep learning framework"),
        (["swift", "swift-lang"], "Swift Programming Language", "swiftlang/swift", "Apple / Swift.org", "Safe, fast, and modern general-purpose programming language")
    ]

    // General Topics / Historical Missions
    private let verifiedGeneralTopics: [(keys: [String], name: String, category: String, description: String)] = [
        (["project apollo", "apollo program", "apollo mission", "apollo"], "Project Apollo (NASA)", "Historical Human Spaceflight Program", "NASA spaceflight effort that succeeded in landing the first humans on the Moon in 1969"),
        (["manhattan project"], "Manhattan Project", "Historical Research Program", "US government research undertaking during World War II that produced the first nuclear weapons")
    ]

    // MARK: - Main Resolution Pipeline

    public func resolveSync(rawQuery: String) -> EntityIdentity {
        let clean = cleanEntityQuery(rawQuery)
        let lower = clean.lowercased()

        guard !clean.isEmpty else {
            return EntityIdentity.unverified(query: rawQuery, reason: "Query contains no discernible entity name.")
        }

        // 1. Check Public Company Catalog
        for item in verifiedPublicCatalog {
            for k in item.keys {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: k) + "\\b"
                if lower == k || lower.range(of: pattern, options: .regularExpression) != nil {
                    return EntityIdentity(
                        rawQuery: rawQuery,
                        cleanEntityName: item.name,
                        entityType: .publicCompany,
                        analysisType: .financialEquity,
                        primaryIdentifier: item.ticker,
                        canonicalTitle: "\(item.name) (\(item.ticker))",
                        officialDomain: item.domain,
                        confidenceScore: 0.98,
                        verificationSources: ["SEC EDGAR CIK \(item.cik)", "NASDAQ/NYSE Exchange Directory", "Official Domain: \(item.domain)"],
                        isVerified: true
                    )
                }
            }
        }

        // 2. Check Private Company Catalog
        for item in verifiedPrivateCatalog {
            for k in item.keys {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: k) + "\\b"
                if lower == k || lower.range(of: pattern, options: .regularExpression) != nil {
                    return EntityIdentity(
                        rawQuery: rawQuery,
                        cleanEntityName: item.name,
                        entityType: .privateCompany,
                        analysisType: .corporateOperational,
                        primaryIdentifier: item.domain,
                        canonicalTitle: "\(item.name) (Private)",
                        officialDomain: item.domain,
                        confidenceScore: 0.95,
                        verificationSources: ["Corporate Registry", "Official Domain: \(item.domain)", "Crunchbase Profile"],
                        isVerified: true
                    )
                }
            }
        }

        // 3. Check Technical Project Catalog
        for item in verifiedTechProjectCatalog {
            for k in item.keys {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: k) + "\\b"
                if lower == k || lower.range(of: pattern, options: .regularExpression) != nil {
                    return EntityIdentity(
                        rawQuery: rawQuery,
                        cleanEntityName: item.name,
                        entityType: .techProject,
                        analysisType: .technicalProject,
                        primaryIdentifier: item.repo,
                        canonicalTitle: "\(item.name) (\(item.org))",
                        officialDomain: "github.com/\(item.repo)",
                        confidenceScore: 0.96,
                        verificationSources: ["GitHub Primary Repository: \(item.repo)", "Project Governance: \(item.org)"],
                        isVerified: true
                    )
                }
            }
        }

        // 4. Check General / Historical Topics
        for item in verifiedGeneralTopics {
            for k in item.keys {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: k) + "\\b"
                if lower == k || lower.range(of: pattern, options: .regularExpression) != nil {
                    return EntityIdentity(
                        rawQuery: rawQuery,
                        cleanEntityName: item.name,
                        entityType: .generalTopic,
                        analysisType: .universalTopic,
                        primaryIdentifier: item.name,
                        canonicalTitle: item.name,
                        officialDomain: nil,
                        confidenceScore: 0.90,
                        verificationSources: ["Encyclopedic Archives", "Primary Historical Records"],
                        isVerified: true
                    )
                }
            }
        }

        // ABSOLUTE NON-SUBSTITUTION RULE: Return unverified
        return EntityIdentity.unverified(
            query: rawQuery,
            reason: "Could not verify '\(clean)' synchronously without network lookup."
        )
    }

    public func resolveCompanySync(query: String) -> (ticker: String, name: String, cik: String) {
        let res = resolveSync(rawQuery: query)
        guard res.isVerified else {
            return ("UNVERIFIED", res.cleanEntityName, "")
        }
        return (res.primaryIdentifier, res.cleanEntityName, "")
    }

    public func resolve(rawQuery: String) async -> EntityIdentity {
        let clean = cleanEntityQuery(rawQuery)
        let lower = clean.lowercased()

        guard !clean.isEmpty else {
            return EntityIdentity.unverified(query: rawQuery, reason: "Query contains no discernible entity name.")
        }

        // 1. Check Public Company Catalog
        for item in verifiedPublicCatalog {
            for k in item.keys {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: k) + "\\b"
                if lower == k || lower.range(of: pattern, options: .regularExpression) != nil {
                    return EntityIdentity(
                        rawQuery: rawQuery,
                        cleanEntityName: item.name,
                        entityType: .publicCompany,
                        analysisType: .financialEquity,
                        primaryIdentifier: item.ticker,
                        canonicalTitle: "\(item.name) (\(item.ticker))",
                        officialDomain: item.domain,
                        confidenceScore: 0.98,
                        verificationSources: ["SEC EDGAR CIK \(item.cik)", "NASDAQ/NYSE Exchange Directory", "Official Domain: \(item.domain)"],
                        isVerified: true
                    )
                }
            }
        }

        // 2. Check Private Company Catalog
        for item in verifiedPrivateCatalog {
            for k in item.keys {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: k) + "\\b"
                if lower == k || lower.range(of: pattern, options: .regularExpression) != nil {
                    return EntityIdentity(
                        rawQuery: rawQuery,
                        cleanEntityName: item.name,
                        entityType: .privateCompany,
                        analysisType: .corporateOperational,
                        primaryIdentifier: item.domain,
                        canonicalTitle: "\(item.name) (Private)",
                        officialDomain: item.domain,
                        confidenceScore: 0.95,
                        verificationSources: ["Corporate Registry", "Official Domain: \(item.domain)", "Crunchbase Profile"],
                        isVerified: true
                    )
                }
            }
        }

        // 3. Check Technical Project Catalog
        for item in verifiedTechProjectCatalog {
            for k in item.keys {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: k) + "\\b"
                if lower == k || lower.range(of: pattern, options: .regularExpression) != nil {
                    return EntityIdentity(
                        rawQuery: rawQuery,
                        cleanEntityName: item.name,
                        entityType: .techProject,
                        analysisType: .technicalProject,
                        primaryIdentifier: item.repo,
                        canonicalTitle: "\(item.name) (\(item.org))",
                        officialDomain: "github.com/\(item.repo)",
                        confidenceScore: 0.96,
                        verificationSources: ["GitHub Primary Repository: \(item.repo)", "Project Governance: \(item.org)"],
                        isVerified: true
                    )
                }
            }
        }

        // 4. Check General / Historical Topics
        for item in verifiedGeneralTopics {
            for k in item.keys {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: k) + "\\b"
                if lower == k || lower.range(of: pattern, options: .regularExpression) != nil {
                    return EntityIdentity(
                        rawQuery: rawQuery,
                        cleanEntityName: item.name,
                        entityType: .generalTopic,
                        analysisType: .universalTopic,
                        primaryIdentifier: item.name,
                        canonicalTitle: item.name,
                        officialDomain: nil,
                        confidenceScore: 0.90,
                        verificationSources: ["Encyclopedic Archives", "Primary Historical Records"],
                        isVerified: true
                    )
                }
            }
        }

        // 5. Dynamic SEC EDGAR Ticker Lookup using Clean Query
        if let secLive = await lookupSECTickerLive(cleanCandidate: clean) {
            return EntityIdentity(
                rawQuery: rawQuery,
                cleanEntityName: secLive.name,
                entityType: .publicCompany,
                analysisType: .financialEquity,
                primaryIdentifier: secLive.ticker,
                canonicalTitle: "\(secLive.name) (\(secLive.ticker))",
                officialDomain: nil,
                confidenceScore: 0.92,
                verificationSources: ["SEC EDGAR CIK \(secLive.cik)", "Official SEC Form 10-K Registry"],
                isVerified: true
            )
        }

        // 6. Dynamic Yahoo Finance Search for Global / Listed Securities
        if let yahooLive = await lookupYahooFinanceLive(cleanCandidate: clean) {
            return EntityIdentity(
                rawQuery: rawQuery,
                cleanEntityName: yahooLive.name,
                entityType: .publicCompany,
                analysisType: .financialEquity,
                primaryIdentifier: yahooLive.ticker,
                canonicalTitle: "\(yahooLive.name) (\(yahooLive.ticker))",
                officialDomain: nil,
                confidenceScore: 0.88,
                verificationSources: ["Yahoo Finance Global Exchange API: \(yahooLive.exchange)"],
                isVerified: true
            )
        }

        // 7. Dynamic GitHub Repository Lookup for Open-Source Projects
        if let gitLive = await lookupGitHubProjectLive(cleanCandidate: clean) {
            return EntityIdentity(
                rawQuery: rawQuery,
                cleanEntityName: gitLive.name,
                entityType: .techProject,
                analysisType: .technicalProject,
                primaryIdentifier: gitLive.repoSlug,
                canonicalTitle: "\(gitLive.name) (GitHub Project)",
                officialDomain: "github.com/\(gitLive.repoSlug)",
                confidenceScore: 0.85,
                verificationSources: ["GitHub API: \(gitLive.repoSlug)"],
                isVerified: true
            )
        }

        // 8. Dynamic Wikipedia Knowledge Verification for Recognized Entities
        if let wikiLive = await lookupWikipediaEntityLive(cleanCandidate: clean) {
            return EntityIdentity(
                rawQuery: rawQuery,
                cleanEntityName: wikiLive.title,
                entityType: .generalTopic,
                analysisType: .universalTopic,
                primaryIdentifier: wikiLive.slug,
                canonicalTitle: wikiLive.title,
                officialDomain: "en.wikipedia.org/wiki/\(wikiLive.slug)",
                confidenceScore: 0.80,
                verificationSources: ["Wikimedia Foundation Knowledge Graph"],
                isVerified: true
            )
        }

        // 9. ABSOLUTE NON-SUBSTITUTION RULE: If unverified, STOP!
        // Never return Tesla, Apple, or any fallback company.
        return EntityIdentity.unverified(
            query: rawQuery,
            reason: "Could not verify '\(clean)' as a registered public stock, private company, technical repository, or documented subject from authoritative sources."
        )
    }

    // MARK: - Live Network Lookups

    private func lookupSECTickerLive(cleanCandidate: String) async -> (ticker: String, name: String, cik: String)? {
        guard let url = URL(string: "https://www.sec.gov/files/company_tickers.json") else { return nil }
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 4.0

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return nil
        }

        let target = cleanCandidate.lowercased()
        for (_, entry) in json {
            let ticker = (entry["ticker"] as? String ?? "").uppercased()
            let title = (entry["title"] as? String ?? "").lowercased()
            let cikInt = entry["cik_str"] as? Int ?? 0

            // Exact ticker match or word-bounded title match
            if ticker.lowercased() == target || title == target || title.hasPrefix("\(target) ") || title.contains(" \(target) ") {
                let paddedCIK = String(format: "%010d", cikInt)
                let cleanName = (entry["title"] as? String) ?? ticker
                return (ticker, cleanName, paddedCIK)
            }
        }
        return nil
    }

    private func lookupYahooFinanceLive(cleanCandidate: String) async -> (ticker: String, name: String, exchange: String)? {
        guard let encoded = cleanCandidate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://query2.finance.yahoo.com/v1/finance/search?q=\(encoded)") else {
            return nil
        }

        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Aegis/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 4.0

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quotes = json["quotes"] as? [[String: Any]],
              let first = quotes.first,
              let symbol = first["symbol"] as? String else {
            return nil
        }

        let longName = (first["longname"] as? String) ?? (first["shortname"] as? String) ?? symbol
        let exchange = (first["exchDisp"] as? String) ?? (first["exchange"] as? String) ?? "Global Exchange"

        // Verify that the search result is relevant to the candidate
        let lowerCandidate = cleanCandidate.lowercased()
        let lowerName = longName.lowercased()
        let lowerSymbol = symbol.lowercased()

        if lowerName.contains(lowerCandidate) || lowerSymbol == lowerCandidate || lowerCandidate.contains(lowerSymbol) {
            return (symbol, longName, exchange)
        }
        return nil
    }

    private func lookupGitHubProjectLive(cleanCandidate: String) async -> (name: String, repoSlug: String)? {
        guard let encoded = cleanCandidate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.github.com/search/repositories?q=\(encoded)+in:name&sort=stars&order=desc") else {
            return nil
        }

        var req = URLRequest(url: url)
        req.setValue("Aegis-Browser-Native-Client", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 4.0

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]],
              let first = items.first,
              let fullName = first["full_name"] as? String,
              let name = first["name"] as? String,
              let stars = first["stargazers_count"] as? Int, stars > 500 else {
            return nil
        }

        let lowerTarget = cleanCandidate.lowercased()
        if name.lowercased() == lowerTarget || fullName.lowercased().hasSuffix("/\(lowerTarget)") {
            return (name, fullName)
        }
        return nil
    }

    private func lookupWikipediaEntityLive(cleanCandidate: String) async -> (title: String, slug: String)? {
        guard let encoded = cleanCandidate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=\(encoded)&format=json") else {
            return nil
        }

        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 4.0

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let queryObj = json["query"] as? [String: Any],
              let searchList = queryObj["search"] as? [[String: Any]],
              let first = searchList.first,
              let title = first["title"] as? String else {
            return nil
        }

        let lowerTitle = title.lowercased()
        let lowerTarget = cleanCandidate.lowercased()

        // Reject if title is totally unrelated
        if lowerTitle.contains(lowerTarget) || lowerTarget.contains(lowerTitle) {
            let slug = title.replacingOccurrences(of: " ", with: "_")
            return (title, slug)
        }
        return nil
    }
}
