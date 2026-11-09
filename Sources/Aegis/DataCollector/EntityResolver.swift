import Foundation

public final class EntityResolver: @unchecked Sendable {
    public static let shared = EntityResolver()

    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 AegisInvestmentAnalysis/1.0"

    public init() {}

    // MARK: - Query Normalization, Intent Decoupling & Fluff Stripping

    public func cleanEntityQuery(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let fluffPrefixes = [
            "what is the financial performance of the ", "what is the financial performance of ",
            "what is the financial health of the ", "what is the financial health of ",
            "what is the financial status of the ", "what is the financial status of ",
            "what is the financial report of the ", "what is the financial report of ",
            "what is the performance of the ", "what is the performance of ",
            "what is the revenue of the ", "what is the revenue of ",
            "what is the market cap of the ", "what is the market cap of ",
            "what is the stock price of the ", "what is the stock price of ",
            "what is the share price of the ", "what is the share price of ",
            "financial performance of the ", "financial performance of ",
            "financial analysis of the ", "financial analysis of ",
            "financial report of the ", "financial report of ",
            "financial statements of the ", "financial statements of ",
            "financial health of the ", "financial health of ",
            "financial stability of the ", "financial stability of ",
            "financials of the ", "financials of ",
            "annual report of the ", "annual report of ",
            "revenue of the ", "revenue of ",
            "balance sheet of the ", "balance sheet of ",
            "income statement of the ", "income statement of ",
            "cash flow statement of the ", "cash flow statement of ",
            "cash flow of the ", "cash flow of ",
            "analyze stock of the ", "analyze stock of ", "analyze stock ",
            "analyze brand of the ", "analyze brand of ", "analyze brand ",
            "analyze project of the ", "analyze project of ", "analyze project ",
            "analyze company of the ", "analyze company of ", "analyze company ",
            "analyze the ", "analyze ",
            "analysis of the ", "analysis of ",
            "valuation of the ", "valuation of ",
            "ratios of the ", "ratios of ",
            "earnings transcript of the ", "earnings transcript of ",
            "earnings call of the ", "earnings call of ",
            "forward guidance of the ", "forward guidance of ",
            "supply chain map of the ", "supply chain map of ",
            "supply chain of the ", "supply chain of ",
            "suppliers of the ", "suppliers of ",
            "news sentiment of the ", "news sentiment of ",
            "regulatory radar of the ", "regulatory radar of ",
            "price of 1 ", "price of ",
            "stock price of the ", "stock price of ",
            "share price of the ", "share price of ",
            "market cap of the ", "market cap of ",
            "who is the ", "who is ", "what is the ", "what is ",
            "tell me about the ", "tell me about ", "tell me in brief about ",
            "search about the ", "search about "
        ]

        let fluffSuffixes = [
            " financial analysis", " financial report", " financial statements",
            " financial performance", " financial health", " financial stability",
            " financial status", " annual report", " balance sheet", " income statement",
            " cash flow statement", " cash flow", " market cap", " revenue",
            " earnings transcript", " earnings call", " forward guidance",
            " supply chain map", " supply chain", " news sentiment", " regulatory radar",
            " valuation", " ratios", " quote", " stock analysis", " stock price",
            " share price", " financials", " stock", " analysis", " report"
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
            if !stripped {
                for s in fluffSuffixes {
                    if lower.hasSuffix(s) {
                        text = String(text.dropLast(s.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                        stripped = true
                        break
                    }
                }
            }
        }

        // Clean trailing punctuation and question marks
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "?!.,;:\"'()"))
        return text
    }

    // MARK: - Curated Verified Entity Directory (US, Indian & Global Multi-Registry)

    // Public Companies: US, Indian (NSE/BSE), European, Asian
    private let verifiedPublicCatalog: [(keys: [String], ticker: String, name: String, cik: String, domain: String, country: String)] = [
        // US Equities
        (["ford", "ford motor", "ford motor co", "f"], "F", "Ford Motor Company", "0000037996", "ford.com", "US"),
        (["tesla", "tsla", "elon", "tesla inc", "tesla motors"], "TSLA", "Tesla, Inc.", "0001318605", "tesla.com", "US"),
        (["apple", "aapl", "iphone", "ipad", "mac", "apple inc"], "AAPL", "Apple Inc.", "0000320193", "apple.com", "US"),
        (["microsoft", "msft", "windows", "azure", "office", "microsoft corp"], "MSFT", "Microsoft Corporation", "0000789019", "microsoft.com", "US"),
        (["nvidia", "nvda", "geforce", "nvidia corp"], "NVDA", "NVIDIA Corporation", "0001045810", "nvidia.com", "US"),
        (["google", "alphabet", "googl", "goog", "alphabet inc"], "GOOGL", "Alphabet Inc.", "0001652044", "abc.xyz", "US"),
        (["amazon", "amzn", "aws", "amazon.com"], "AMZN", "Amazon.com, Inc.", "0001018724", "amazon.com", "US"),
        (["meta", "facebook", "instagram", "meta platforms"], "META", "Meta Platforms, Inc.", "0001326801", "meta.com", "US"),
        (["boeing", "the boeing company", "ba"], "BA", "The Boeing Company", "0000012927", "boeing.com", "US"),
        (["pfizer", "pfizer inc", "pfe"], "PFE", "Pfizer Inc.", "0000078003", "pfizer.com", "US"),
        (["general motors", "gm", "chevrolet", "cadillac"], "GM", "General Motors Company", "0001467858", "gm.com", "US"),
        (["berkshire", "buffett", "brk"], "BRK.B", "Berkshire Hathaway Inc.", "0001067983", "berkshirehathaway.com", "US"),
        (["netflix", "nflx"], "NFLX", "Netflix, Inc.", "0001065280", "netflix.com", "US"),
        (["disney", "dis", "walt disney"], "DIS", "The Walt Disney Company", "0001744489", "thewaltdisneycompany.com", "US"),
        (["coca cola", "coca-cola", "coke", "ko"], "KO", "The Coca-Cola Company", "0000021344", "coca-colacompany.com", "US"),
        (["pepsi", "pepsico", "pep"], "PEP", "PepsiCo, Inc.", "0000077476", "pepsico.com", "US"),
        (["walmart", "wmt"], "WMT", "Walmart Inc.", "0000104169", "walmart.com", "US"),
        (["jpmorgan", "jp morgan", "chase", "jpm"], "JPM", "JPMorgan Chase & Co.", "0000019617", "jpmorganchase.com", "US"),
        (["intel", "intc"], "INTC", "Intel Corporation", "0000050863", "intel.com", "US"),
        (["amd", "advanced micro devices"], "AMD", "Advanced Micro Devices, Inc.", "0000002488", "amd.com", "US"),
        (["nike", "nke"], "NKE", "NIKE, Inc.", "0000320187", "nike.com", "US"),
        (["starbucks", "sbux"], "SBUX", "Starbucks Corporation", "0000829224", "starbucks.com", "US"),
        (["costco", "cost"], "COST", "Costco Wholesale Corporation", "0000909832", "costco.com", "US"),

        // Indian Public Equities (NSE/BSE Listed)
        (["reliance", "reliance industries", "reliance industries ltd", "reliance industries limited", "ril", "reliance.ns"], "RELIANCE.NS", "Reliance Industries Limited", "0000000000", "ril.com", "India"),
        (["infosys", "infosys ltd", "infosys limited", "infy", "infy.ns"], "INFY.NS", "Infosys Limited", "0001065837", "infosys.com", "India"),
        (["tcs", "tata consultancy services", "tata consultancy services ltd", "tata consultancy services limited", "tcs.ns"], "TCS.NS", "Tata Consultancy Services Limited", "0000000000", "tcs.com", "India"),
        (["tata motors", "tata motors ltd", "tata motors limited", "tatamotors.ns"], "TATAMOTORS.NS", "Tata Motors Limited", "0000926042", "tatamotors.com", "India"),
        (["tata steel", "tata steel ltd", "tata steel limited", "tatasteel.ns"], "TATASTEEL.NS", "Tata Steel Limited", "0000000000", "tatasteel.com", "India"),
        (["hdfc bank", "hdfc bank ltd", "hdfc bank limited", "hdfcbank.ns", "hdb"], "HDFCBANK.NS", "HDFC Bank Limited", "0001144967", "hdfcbank.com", "India"),
        (["icici bank", "icici bank ltd", "icici bank limited", "icicibank.ns", "ibn"], "ICICIBANK.NS", "ICICI Bank Limited", "0001103838", "icicibank.com", "India"),
        (["itc", "itc ltd", "itc limited", "itc.ns"], "ITC.NS", "ITC Limited", "0000000000", "itcportal.com", "India"),
        (["larsen & toubro", "larsen and toubro", "l&t", "lt", "lt.ns"], "LT.NS", "Larsen & Toubro Limited", "0000000000", "larsentoubro.com", "India"),
        (["state bank of india", "sbi", "sbin.ns"], "SBIN.NS", "State Bank of India", "0000000000", "sbi.co.in", "India"),
        (["bharti airtel", "airtel", "bhartiartl.ns"], "BHARTIARTL.NS", "Bharti Airtel Limited", "0000000000", "airtel.in", "India"),
        (["wipro", "wipro ltd", "wipro limited", "wipro.ns", "wit"], "WIPRO.NS", "Wipro Limited", "0001123799", "wipro.com", "India"),

        // European & Asian Multinationals
        (["adidas", "adidas ag", "ads"], "ADS.DE", "Adidas AG", "0000000000", "adidas-group.com", "Germany"),
        (["siemens", "siemens ag", "sie", "sie.de"], "SIE.DE", "Siemens AG", "0000000000", "siemens.com", "Germany"),
        (["toyota", "tm"], "TM", "Toyota Motor Corporation", "0001094517", "toyota-global.com", "Japan"),
        (["sony", "sony group"], "SONY", "Sony Group Corporation", "0000313838", "sony.com", "Japan"),
        (["samsung", "samsung electronics", "samsung electronics co", "005930.ks"], "005930.KS", "Samsung Electronics Co., Ltd.", "0000000000", "samsung.com", "South Korea"),
        (["alibaba", "alibaba group", "baba"], "BABA", "Alibaba Group Holding Limited", "0001577552", "alibabagroup.com", "China"),
        (["shell", "shell plc", "shel"], "SHEL", "Shell plc", "0001306965", "shell.com", "UK")
    ]

    // Private Companies, Conglomerates & Unlisted Subsidiaries
    private let verifiedPrivateCatalog: [(keys: [String], name: String, domain: String, canonicalTitle: String, country: String, description: String, sources: [String])] = [
        // Indian Conglomerates & Unlisted Subsidiaries
        (
            ["tata industries", "tata industries ltd", "tata industries limited", "tata group company tata industries", "til"],
            "Tata Industries Limited",
            "tata.com",
            "Tata Industries Limited (Tata Group Subsidiary)",
            "India",
            "Pioneer investment and business incubator subsidiary of Tata Group (Incorporated 1945, CIN: U74999MH1945PLC004558)",
            ["Corporate Registry (RoC-Mumbai CIN: U74999MH1945PLC004558)", "Tata Sons Promoter & Incubator Directory", "Official Domain: tata.com"]
        ),
        (
            ["tata sons", "tata sons pvt ltd", "tata sons private limited"],
            "Tata Sons Private Limited",
            "tata.com",
            "Tata Sons Private Limited (Principal Holding Company)",
            "India",
            "Principal investment holding company and promoter of Tata Group enterprises (CIN: U99999MH1917PTC000478)",
            ["Corporate Registry (RoC-Mumbai CIN: U99999MH1917PTC000478)", "Tata Trusts Governance", "Official Domain: tata.com"]
        ),
        (
            ["tata group", "tata conglomerate", "tata enterprise"],
            "Tata Group",
            "tata.com",
            "Tata Group (Conglomerate Holding)",
            "India",
            "Global enterprise comprising 30 companies across 10 verticals operating in 100+ countries",
            ["Tata Sons Corporate Governance", "Official Domain: tata.com"]
        ),
        (
            ["reliance retail", "reliance retail ventures", "reliance retail ventures ltd"],
            "Reliance Retail Ventures Limited",
            "relianceretail.com",
            "Reliance Retail Ventures Limited (RIL Subsidiary)",
            "India",
            "Largest retail subsidiary enterprise of Reliance Industries Limited",
            ["Corporate Registry (RoC-Mumbai)", "RIL Annual Disclosures", "Official Domain: relianceretail.com"]
        ),
        (
            ["reliance jio", "jio infocomm", "jio"],
            "Reliance Jio Infocomm Limited",
            "jio.com",
            "Reliance Jio Infocomm Limited (Jio Platforms Subsidiary)",
            "India",
            "Indian telecommunications and digital services subsidiary of Jio Platforms and Reliance Industries",
            ["DoT India Licensing", "RIL Digital Ecosystem Filings", "Official Domain: jio.com"]
        ),
        (
            ["aditya birla", "aditya birla group"],
            "Aditya Birla Group",
            "adityabirla.com",
            "Aditya Birla Group (Conglomerate)",
            "India",
            "Indian multinational conglomerate active in metals, pulp, chemicals, and financial services",
            ["Corporate Group Registry", "Official Domain: adityabirla.com"]
        ),
        (
            ["serum institute", "serum institute of india"],
            "Serum Institute of India Pvt. Ltd.",
            "seruminstitute.com",
            "Serum Institute of India Pvt. Ltd. (Private)",
            "India",
            "World's largest vaccine manufacturer by volume and private biotechnology enterprise",
            ["DCGI Corporate Licensing", "Official Domain: seruminstitute.com"]
        ),

        // Global Private Technology Leaders
        (
            ["stripe", "stripe inc", "stripe payments"],
            "Stripe, Inc.",
            "stripe.com",
            "Stripe, Inc. (Private)",
            "US",
            "Financial infrastructure and payment processing software",
            ["Delaware Corporate Registry", "Official Domain: stripe.com", "Crunchbase Profile"]
        ),
        (
            ["openai", "openai inc", "openai opco", "chatgpt"],
            "OpenAI, Inc.",
            "openai.com",
            "OpenAI, Inc. (Private)",
            "US",
            "Artificial intelligence research and deployment company",
            ["Delaware Corporate Registry", "Official Domain: openai.com"]
        ),
        (
            ["spacex", "space exploration technologies"],
            "Space Exploration Technologies Corp. (SpaceX)",
            "spacex.com",
            "SpaceX (Private)",
            "US",
            "Commercial aerospace manufacturer and space transportation services",
            ["Federal Aviation Administration Registry", "Official Domain: spacex.com"]
        ),
        (
            ["anthropic", "anthropic pbc", "claude"],
            "Anthropic PBC",
            "anthropic.com",
            "Anthropic PBC (Public Benefit Corp)",
            "US",
            "AI safety and public-benefit intelligence research",
            ["Delaware Corporate Registry", "Official Domain: anthropic.com"]
        ),
        (
            ["bytedance", "tiktok"],
            "ByteDance Ltd.",
            "bytedance.com",
            "ByteDance Ltd. (Private)",
            "China",
            "Global internet technology and content platform developer",
            ["Corporate Registry", "Official Domain: bytedance.com"]
        ),
        (
            ["databricks"],
            "Databricks, Inc.",
            "databricks.com",
            "Databricks, Inc. (Private)",
            "US",
            "Data lakehouse, Apache Spark, and enterprise AI platform",
            ["Delaware Corporate Registry", "Official Domain: databricks.com"]
        )
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

    // MARK: - Synchronous Resolution Pipeline

    public func resolveSync(rawQuery: String) -> EntityIdentity {
        let clean = cleanEntityQuery(rawQuery)
        let lower = clean.lowercased()

        guard !clean.isEmpty else {
            return EntityIdentity.unverified(query: rawQuery, reason: "Query contains no discernible entity name.")
        }

        // 1. Check Public Company Catalog (US, Indian & Global)
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
                        verificationSources: [
                            "Exchange Directory: \(item.ticker) [\(item.country)]",
                            item.cik != "0000000000" ? "SEC EDGAR CIK \(item.cik)" : "National Exchange Registry",
                            "Official Domain: \(item.domain)"
                        ],
                        isVerified: true
                    )
                }
            }
        }

        // 2. Check Private Company Catalog (Conglomerates, Subsidiaries & Unicorns)
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
                        canonicalTitle: item.canonicalTitle,
                        officialDomain: item.domain,
                        confidenceScore: 0.95,
                        verificationSources: item.sources,
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

    // MARK: - Asynchronous Multi-Stage Resolution Pipeline

    public func resolve(rawQuery: String) async -> EntityIdentity {
        let clean = cleanEntityQuery(rawQuery)
        let lower = clean.lowercased()

        guard !clean.isEmpty else {
            return EntityIdentity.unverified(query: rawQuery, reason: "Query contains no discernible entity name.")
        }

        // 1. Check Public Company Catalog (US, Indian & Global)
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
                        verificationSources: [
                            "Exchange Directory: \(item.ticker) [\(item.country)]",
                            item.cik != "0000000000" ? "SEC EDGAR CIK \(item.cik)" : "National Exchange Registry",
                            "Official Domain: \(item.domain)"
                        ],
                        isVerified: true
                    )
                }
            }
        }

        // 2. Check Private Company Catalog (Conglomerates, Subsidiaries & Unicorns)
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
                        canonicalTitle: item.canonicalTitle,
                        officialDomain: item.domain,
                        confidenceScore: 0.95,
                        verificationSources: item.sources,
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

        // 5. Dynamic SEC EDGAR Ticker Lookup (for US public equities)
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

        // 7. Dynamic Wikipedia Knowledge Graph Disambiguation (Global Corporate & Technical Entities)
        if let wikiLive = await lookupWikipediaEntityLive(cleanCandidate: clean) {
            return EntityIdentity(
                rawQuery: rawQuery,
                cleanEntityName: wikiLive.title,
                entityType: wikiLive.entityType,
                analysisType: wikiLive.entityType == .publicCompany ? .financialEquity : (wikiLive.entityType == .privateCompany ? .corporateOperational : .universalTopic),
                primaryIdentifier: wikiLive.slug,
                canonicalTitle: wikiLive.title,
                officialDomain: wikiLive.officialDomain,
                confidenceScore: 0.85,
                verificationSources: wikiLive.sources,
                isVerified: true
            )
        }

        // 8. Dynamic GitHub Repository Lookup for Open-Source Projects
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
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Aegis/1.0", forHTTPHeaderField: "User-Agent")
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

    private func lookupWikipediaEntityLive(cleanCandidate: String) async -> (title: String, slug: String, entityType: EntityType, officialDomain: String?, sources: [String])? {
        // Strip out common corporate suffixes to search for core entity name if needed
        let lowerTarget = cleanCandidate.lowercased()
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
              !searchList.isEmpty else {
            return nil
        }

        // Scan search list items to find the most accurate match
        for item in searchList.prefix(8) {
            guard let title = item["title"] as? String else { continue }
            let lowerTitle = title.lowercased()
            let rawSnippet = item["snippet"] as? String ?? ""
            let cleanSnippet = rawSnippet
                .replacingOccurrences(of: "(?i)<[^>]+>", with: "", options: .regularExpression)
                .lowercased()

            let isDirectMatch = lowerTitle == lowerTarget || lowerTitle.contains(lowerTarget) || lowerTarget.contains(lowerTitle)
            let isContextMatch = cleanSnippet.contains(lowerTarget) && (
                cleanSnippet.contains("company") || cleanSnippet.contains("corporation") ||
                cleanSnippet.contains("subsidiary") || cleanSnippet.contains("incubator") ||
                cleanSnippet.contains("group") || cleanSnippet.contains("ventures") ||
                cleanSnippet.contains("enterprise")
            )

            if isDirectMatch || isContextMatch {
                let chosenTitle = isDirectMatch ? title : cleanCandidate
                let slug = chosenTitle.replacingOccurrences(of: " ", with: "_")

                // Determine entity type based on snippet keywords
                var type: EntityType = .generalTopic
                if cleanSnippet.contains("company") || cleanSnippet.contains("corporation") ||
                   cleanSnippet.contains("subsidiary") || cleanSnippet.contains("conglomerate") ||
                   cleanSnippet.contains("manufacturer") || cleanSnippet.contains("bank") ||
                   cleanSnippet.contains("firm") || cleanSnippet.contains("incubator") {
                    if cleanSnippet.contains("public company") || cleanSnippet.contains("stock exchange") ||
                       cleanSnippet.contains("listed on") || cleanSnippet.contains("nasdaq") ||
                       cleanSnippet.contains("nyse") || cleanSnippet.contains("nse") {
                        type = .publicCompany
                    } else {
                        type = .privateCompany
                    }
                } else if cleanSnippet.contains("software") || cleanSnippet.contains("open-source") ||
                          cleanSnippet.contains("framework") || cleanSnippet.contains("library") ||
                          cleanSnippet.contains("programming language") {
                    type = .techProject
                }

                return (
                    title: chosenTitle,
                    slug: slug,
                    entityType: type,
                    officialDomain: "en.wikipedia.org/wiki/\(slug)",
                    sources: ["Wikimedia Foundation Knowledge Graph: \(title)", "Encyclopedic Index Record"]
                )
            }
        }
        return nil
    }
}
