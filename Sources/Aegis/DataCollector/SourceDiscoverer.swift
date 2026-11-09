import Foundation

public final class SourceDiscoverer: @unchecked Sendable {
    public static let shared = SourceDiscoverer()

    public init() {}

    /// Discovers candidate URLs through targeted, company-specific, and jurisdiction-aware strategies
    public func discoverSources(
        for entity: EntityIdentity,
        jurisdiction: JurisdictionProfile,
        requestedLimit: Int
    ) async -> [URL] {
        var discovered: [URL] = []
        let ticker = entity.primaryIdentifier
        let name = entity.cleanEntityName
        let cleanSlug = name.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name

        // =========================================================================
        // STRATEGY 1: DEEP OFFICIAL COMPANY WEBSITE DISCOVERY (Section 9)
        // =========================================================================
        if let dom = entity.officialDomain, !dom.isEmpty {
            let baseHost = dom.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            // 1. Homepage
            if let u = URL(string: "https://\(baseHost)") { discovered.append(u) }

            // 2. Deep Investor Relations / Financials Paths
            let irPaths = [
                "/investors",
                "/investor-relations",
                "/investors/financial-results",
                "/investors/annual-reports",
                "/investors/quarterly-results",
                "/about-us",
                "/business",
                "/governance",
                "/newsroom/press-releases"
            ]
            for p in irPaths {
                if let u = URL(string: "https://\(baseHost)\(p)") { discovered.append(u) }
            }
        }

        // =========================================================================
        // STRATEGY 2: REGULATORY & EXCHANGE DISCOVERY (Section 4 & 8)
        // =========================================================================
        switch entity.entityType {
        case .publicCompany:
            // A. United States SEC EDGAR
            if jurisdiction.country == "United States" || ticker.count <= 5 && !ticker.contains(".") {
                let cik = await resolveCIKForTicker(ticker)
                if !cik.isEmpty {
                    if let u = URL(string: "https://data.sec.gov/api/xbrl/companyfacts/CIK\(cik).json") { discovered.append(u) }
                    if let u = URL(string: "https://data.sec.gov/submissions/CIK\(cik).json") { discovered.append(u) }
                    if let u = URL(string: "https://www.sec.gov/edgar/browse/?CIK=\(cik)") { discovered.append(u) }
                }
            }

            // B. Indian Exchanges (NSE & BSE)
            if jurisdiction.country == "India" {
                let cleanSym = ticker.replacingOccurrences(of: ".NS", with: "").replacingOccurrences(of: ".BO", with: "")
                if let u = URL(string: "https://www.nseindia.com/companies-listing/corporate-filings-financial-results?symbol=\(cleanSym)") { discovered.append(u) }
                if let u = URL(string: "https://www.bseindia.com/stock-share-price/\(cleanSym.lowercased())/") { discovered.append(u) }
                if let u = URL(string: "https://query2.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d") { discovered.append(u) }
            }

            // C. European / German Exchanges (XETRA)
            if jurisdiction.country == "Germany" {
                let sym = ticker.replacingOccurrences(of: ".DE", with: "")
                if let u = URL(string: "https://www.boerse-frankfurt.de/equity/\(sym.lowercased())") { discovered.append(u) }
                if let u = URL(string: "https://query2.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d") { discovered.append(u) }
            }

            // D. Japanese Exchanges (JPX / TSE)
            if jurisdiction.country == "Japan" {
                if let u = URL(string: "https://query2.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d") { discovered.append(u) }
            }

            // E. South Korean Exchanges (KRX)
            if jurisdiction.country == "South Korea" {
                if let u = URL(string: "https://query2.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d") { discovered.append(u) }
            }

            // =========================================================================
            // STRATEGY 3: SPECIALIST FINANCIAL DATA SOURCES (Section 5)
            // =========================================================================
            // Yahoo Chart API (Real-time intraday quote, currency, 52-week range)
            if let u = URL(string: "https://query2.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d") { discovered.append(u) }

            // Google Finance
            if let u = URL(string: "https://www.google.com/finance/quote/\(ticker):NASDAQ") { discovered.append(u) }
            else if let u = URL(string: "https://www.google.com/finance/quote/\(ticker):NYSE") { discovered.append(u) }
            else if let u = URL(string: "https://www.google.com/finance/quote/\(ticker):NSE") { discovered.append(u) }

            // MarketWatch / Reuters Key Statistics
            if let u = URL(string: "https://www.marketwatch.com/investing/stock/\(ticker.lowercased())") { discovered.append(u) }
            if let u = URL(string: "https://www.reuters.com/markets/companies/\(ticker)") { discovered.append(u) }

            // =========================================================================
            // STRATEGY 4: REPUTABLE SECONDARY & ACADEMIC SOURCES (Section 6)
            // =========================================================================
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://api.crossref.org/works?query=\(enc)&rows=4") { discovered.append(u) }

            // =========================================================================
            // STRATEGY 5: GENERAL REFERENCE & CONTEXT (Section 7: Low/Medium Priority)
            // =========================================================================
            if let u = URL(string: "https://en.wikipedia.org/wiki/\(cleanSlug)") { discovered.append(u) }

        case .privateCompany:
            // 1. Official Corporate Domain Disclosures & News
            if let dom = entity.officialDomain, !dom.isEmpty {
                let baseHost = dom.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let corporatePaths = [
                    "/about-us",
                    "/business",
                    "/business/overview",
                    "/our-businesses",
                    "/subsidiaries",
                    "/companies",
                    "/governance",
                    "/leadership",
                    "/news"
                ]
                for p in corporatePaths {
                    if let u = URL(string: "https://\(baseHost)\(p)") { discovered.append(u) }
                }
            }

            // 2. Jurisdiction Corporate Registry Search (Section 4 & 8)
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                if jurisdiction.country == "India" {
                    if let u = URL(string: "https://www.zaubacorp.com/companysearchresults/\(enc)") { discovered.append(u) }
                } else if jurisdiction.country == "United Kingdom" {
                    if let u = URL(string: "https://find-and-update.company-information.service.gov.uk/search/companies?q=\(enc)") { discovered.append(u) }
                }
            }

            // 3. Peer-Reviewed Academic & Technical Papers (CrossRef)
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://api.crossref.org/works?query=\(enc)&rows=4") { discovered.append(u) }

            // 4. Wikidata Entity API (Section 7)
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://www.wikidata.org/w/api.php?action=wbsearchentities&search=\(enc)&language=en&format=json") { discovered.append(u) }

            // 5. Wikipedia Corporate Profile (Context Only - Section 7)
            if let u = URL(string: "https://en.wikipedia.org/wiki/\(cleanSlug)") { discovered.append(u) }

        case .techProject:
            let repoSlug = entity.primaryIdentifier
            if let u = URL(string: "https://api.github.com/repos/\(repoSlug)") { discovered.append(u) }
            if let u = URL(string: "https://api.github.com/repos/\(repoSlug)/releases?per_page=5") { discovered.append(u) }
            if let u = URL(string: "https://raw.githubusercontent.com/\(repoSlug)/master/README.md") { discovered.append(u) }
            if let dom = entity.officialDomain, !dom.contains("github.com"), let u = URL(string: "https://\(dom)") { discovered.append(u) }
            if let u = URL(string: "https://en.wikipedia.org/wiki/\(cleanSlug)") { discovered.append(u) }
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://api.crossref.org/works?query=\(enc)+system+architecture&rows=4") { discovered.append(u) }

        case .generalTopic, .nonProfitOrg:
            if let u = URL(string: "https://en.wikipedia.org/wiki/\(cleanSlug)") { discovered.append(u) }
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://www.wikidata.org/w/api.php?action=wbsearchentities&search=\(enc)&language=en&format=json") { discovered.append(u) }
            if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let u = URL(string: "https://api.crossref.org/works?query=\(enc)&rows=6") { discovered.append(u) }

        case .unverified:
            return []
        }

        // Deduplicate discovered URLs while preserving discovery order
        var distinct: [URL] = []
        for u in discovered where !distinct.contains(u) {
            distinct.append(u)
        }
        return distinct
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
            "COST": "0000909832",
            "INFY": "0001065837",
            "INFY.NS": "0001065837",
            "HDB": "0001144967",
            "HDFCBANK.NS": "0001144967",
            "IBN": "0001103838",
            "ICICIBANK.NS": "0001103838",
            "WIT": "0001123799",
            "WIPRO.NS": "0001123799",
            "BABA": "0001577552",
            "SHEL": "0001306965"
        ]
        return catalog[ticker] ?? ""
    }
}
