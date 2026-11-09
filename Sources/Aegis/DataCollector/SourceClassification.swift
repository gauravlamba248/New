import Foundation

public final class SourceClassifier: @unchecked Sendable {
    public static let shared = SourceClassifier()

    public init() {}

    /// Classifies a candidate URL into a GranularSourceType and initial quality tier
    public func classify(url: URL, entity: EntityIdentity) -> (sourceType: GranularSourceType, qualityTier: SourceQualityTier, baseAuthority: Double, infoTypes: [String]) {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        var infoTypes: [String] = []

        // 1. TIER 1: OFFICIAL COMPANY SOURCES
        if let dom = entity.officialDomain?.lowercased(), !dom.isEmpty && (host == dom || host.hasSuffix(".\(dom)") || dom.contains(host)) {
            if path.contains("investor") || path.contains("ir") || path.contains("annual") || path.contains("financial") || path.contains("result") {
                infoTypes.append("Official Financial Statements")
                infoTypes.append("Investor Relations Report")
                return (.officialCompany, .primaryAuthoritative, 1.0, infoTypes)
            } else if path.contains("governance") || path.contains("about") || path.contains("leadership") {
                infoTypes.append("Corporate Governance & Leadership")
                return (.officialCompany, .primaryAuthoritative, 0.95, infoTypes)
            } else if path.contains("news") || path.contains("press") || path.contains("release") {
                infoTypes.append("Official Corporate Announcements")
                return (.officialCompany, .primaryAuthoritative, 0.92, infoTypes)
            } else {
                infoTypes.append("Official Entity Portal")
                return (.officialCompany, .primaryAuthoritative, 0.90, infoTypes)
            }
        }

        // 2. TIER 2: REGULATORS & STOCK EXCHANGES & GOVERNMENT REGISTRIES
        // A. Regulators
        let regulatorDomains = ["sec.gov", "sebi.gov.in", "mca.gov.in", "fca.org.uk", "bafin.de", "fsa.go.jp", "csrc.gov.cn", "esma.europa.eu"]
        if regulatorDomains.contains(where: { host.contains($0) }) {
            infoTypes.append("Audited Statutory Filings")
            infoTypes.append("Regulatory Disclosure")
            return (.regulator, .primaryAuthoritative, 1.0, infoTypes)
        }

        // B. Stock Exchanges
        let exchangeDomains = ["nseindia.com", "bseindia.com", "nasdaq.com", "nyse.com", "londonstockexchange.com", "boerse-frankfurt.de", "jpx.co.jp", "krx.co.kr", "hkex.com.hk"]
        if exchangeDomains.contains(where: { host.contains($0) }) {
            infoTypes.append("Official Market Trading Data")
            infoTypes.append("Exchange Shareholding Patterns")
            return (.stockExchange, .primaryAuthoritative, 0.96, infoTypes)
        }

        // C. Government Corporate Registries
        let registryDomains = ["gov.uk/companieshouse", "find-and-update.company-information.service.gov.uk", "mca.gov.in/content/mca", "delaware.gov"]
        if registryDomains.contains(where: { host.contains($0) }) {
            infoTypes.append("Statutory Incorporation & Registration")
            return (.governmentRegistry, .primaryAuthoritative, 0.98, infoTypes)
        }

        // 3. TIER 3: FINANCIAL DATABASES & SPECIALIST DATA PROVIDERS
        let financialDatabaseDomains = [
            "query2.finance.yahoo.com", "finance.yahoo.com", "google.com/finance",
            "bloomberg.com/quote", "reuters.com/markets/companies", "morningstar.com",
            "tradingview.com", "marketwatch.com/investing/stock"
        ]
        if financialDatabaseDomains.contains(where: { host.contains($0) || url.absoluteString.contains($0) }) {
            infoTypes.append("Market Quotation & Intraday Trading")
            infoTypes.append("Normalized Financial Metrics")
            return (.financialDatabase, .highQuality, 0.88, infoTypes)
        }

        let specialistFinancialDomains = [
            "macrotrends.net", "gurufocus.com", "seekingalpha.com", "finviz.com",
            "screener.in", "moneycontrol.com", "trendlyne.com", "tikr.com"
        ]
        if specialistFinancialDomains.contains(where: { host.contains($0) }) {
            infoTypes.append("Specialist Ratio Modeling")
            infoTypes.append("Historical Valuation Multiples")
            return (.specialistFinancial, .highQuality, 0.82, infoTypes)
        }

        // 4. TIER 4: REPUTABLE NEWS MEDIA & INDUSTRY PUBLICATIONS
        let reputableNewsDomains = [
            "reuters.com", "bloomberg.com", "wsj.com", "ft.com", "economist.com",
            "economictimes.indiatimes.com", "livemint.com", "business-standard.com",
            "cnbc.com", "nikkei.com", "handelsblatt.com"
        ]
        if reputableNewsDomains.contains(where: { host.contains($0) }) {
            infoTypes.append("Industry Analysis & Business Journalism")
            infoTypes.append("Executive Commentary & Market Events")
            return (.reputableNews, .highQuality, 0.80, infoTypes)
        }

        let industryPubDomains = ["techcrunch.com", "theverge.com", "wired.com", "zdnet.com", "autonews.com", "aviationweek.com"]
        if industryPubDomains.contains(where: { host.contains($0) }) {
            infoTypes.append("Specialized Industry Reporting")
            return (.industryPublication, .mediumQuality, 0.75, infoTypes)
        }

        // 5. TIER 5: RESEARCH & GENERAL REFERENCE
        let researchDomains = ["crossref.org", "arxiv.org", "ieee.org", "sciencedirect.com", "nature.com"]
        if researchDomains.contains(where: { host.contains($0) }) {
            infoTypes.append("Peer-Reviewed Scientific & Technical Literature")
            return (.research, .highQuality, 0.85, infoTypes)
        }

        let referenceDomains = ["wikipedia.org", "wikidata.org", "britannica.com"]
        if referenceDomains.contains(where: { host.contains($0) }) {
            infoTypes.append("Encyclopedic Background & Historical Context")
            return (.generalReference, .mediumQuality, 0.65, infoTypes)
        }

        // 6. TIER 6: LOW VALUE / CONTENT FARMS / REJECTED
        let lowValueIndicators = [
            "blogspot", "wordpress.com", "pinterest", "tiktok.com", "buzzfeed",
            "medium.com", "quora.com", "reddit.com", "facebook.com", "instagram.com",
            "crunchbase.com/person", "zoominfo.com", "lead411.com", "owler.com"
        ]
        if lowValueIndicators.contains(where: { host.contains($0) }) {
            infoTypes.append("Unverified Social / Aggregator Web")
            return (.lowValue, .rejected, 0.20, infoTypes)
        }

        infoTypes.append("General Secondary Web")
        return (.generalReference, .lowQuality, 0.50, infoTypes)
    }
}
