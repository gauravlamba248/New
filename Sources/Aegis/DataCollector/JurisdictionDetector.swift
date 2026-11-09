import Foundation

public struct JurisdictionProfile: Sendable {
    public let country: String
    public let regulatorName: String
    public let regulatorDomain: String
    public let exchangeNames: [String]
    public let exchangeDomains: [String]
    public let corporateRegistryName: String
    public let corporateRegistryDomain: String
    public let searchKeywords: [String]
}

public final class JurisdictionDetector: @unchecked Sendable {
    public static let shared = JurisdictionDetector()

    public init() {}

    /// Detects the regulatory and exchange jurisdiction for an entity
    public func detect(entity: EntityIdentity) -> JurisdictionProfile {
        let ticker = entity.primaryIdentifier.uppercased()
        let name = entity.cleanEntityName.lowercased()
        let juris = entity.jurisdiction.lowercased()

        // 1. INDIA
        if juris.contains("india") || ticker.hasSuffix(".NS") || ticker.hasSuffix(".BO") ||
           name.contains("tata") || name.contains("reliance") || name.contains("infosys") ||
           name.contains("hdfc") || name.contains("icici") || name.contains("larsen") ||
           name.contains("wipro") || name.contains("bharti") || name.contains("aditya birla") {
            return JurisdictionProfile(
                country: "India",
                regulatorName: "Securities and Exchange Board of India (SEBI)",
                regulatorDomain: "sebi.gov.in",
                exchangeNames: ["National Stock Exchange of India (NSE)", "Bombay Stock Exchange (BSE)"],
                exchangeDomains: ["nseindia.com", "bseindia.com"],
                corporateRegistryName: "Ministry of Corporate Affairs (MCA) / RoC",
                corporateRegistryDomain: "mca.gov.in",
                searchKeywords: ["NSE", "BSE", "SEBI", "MCA", "Annual Report", "Financial Results", "Investor Relations"]
            )
        }

        // 2. GERMANY / EUROPE
        if juris.contains("germany") || ticker.hasSuffix(".DE") || name.contains("siemens") || name.contains("adidas") || name.contains("sap") || name.contains("bayer") || name.contains("bmw") {
            return JurisdictionProfile(
                country: "Germany",
                regulatorName: "Federal Financial Supervisory Authority (BaFin)",
                regulatorDomain: "bafin.de",
                exchangeNames: ["Frankfurt Stock Exchange (XETRA)"],
                exchangeDomains: ["boerse-frankfurt.de"],
                corporateRegistryName: "Handelsregister (Unternehmensregister)",
                corporateRegistryDomain: "unternehmensregister.de",
                searchKeywords: ["XETRA", "BaFin", "Geschäftsbericht", "Annual Report", "Investor Relations"]
            )
        }

        // 3. JAPAN
        if juris.contains("japan") || ticker.hasSuffix(".T") || name.contains("toyota") || name.contains("sony") || name.contains("honda") || name.contains("panasonic") {
            return JurisdictionProfile(
                country: "Japan",
                regulatorName: "Financial Services Agency (FSA)",
                regulatorDomain: "fsa.go.jp",
                exchangeNames: ["Tokyo Stock Exchange (JPX)"],
                exchangeDomains: ["jpx.co.jp"],
                corporateRegistryName: "EDINET (Electronic Disclosure for Investors' NETwork)",
                corporateRegistryDomain: "disclosure2.edinet-fsa.go.jp",
                searchKeywords: ["Tokyo Stock Exchange", "JPX", "EDINET", "Financial Results", "Investor Relations"]
            )
        }

        // 4. SOUTH KOREA
        if juris.contains("korea") || ticker.hasSuffix(".KS") || name.contains("samsung") || name.contains("hyundai") || name.contains("lg electronics") || name.contains("sk hynix") {
            return JurisdictionProfile(
                country: "South Korea",
                regulatorName: "Financial Supervisory Service (FSS)",
                regulatorDomain: "fss.or.kr",
                exchangeNames: ["Korea Exchange (KRX)"],
                exchangeDomains: ["krx.co.kr"],
                corporateRegistryName: "DART (Data Analysis, Retrieval and Transfer System)",
                corporateRegistryDomain: "dart.fss.or.kr",
                searchKeywords: ["KRX", "DART", "Financial Statements", "Quarterly Report"]
            )
        }

        // 5. UNITED KINGDOM
        if juris.contains("uk") || juris.contains("united kingdom") || ticker.hasSuffix(".L") || name.contains("shell") || name.contains("bp") || name.contains("astrazeneca") || name.contains("unilever") {
            return JurisdictionProfile(
                country: "United Kingdom",
                regulatorName: "Financial Conduct Authority (FCA)",
                regulatorDomain: "fca.org.uk",
                exchangeNames: ["London Stock Exchange (LSE)"],
                exchangeDomains: ["londonstockexchange.com"],
                corporateRegistryName: "Companies House",
                corporateRegistryDomain: "find-and-update.company-information.service.gov.uk",
                searchKeywords: ["LSE", "Companies House", "Annual Report", "Regulatory News Service"]
            )
        }

        // 6. CHINA / HONG KONG
        if juris.contains("china") || ticker.hasSuffix(".HK") || name.contains("alibaba") || name.contains("tencent") || name.contains("bytedance") {
            return JurisdictionProfile(
                country: "China / Hong Kong",
                regulatorName: "Securities and Futures Commission (SFC) / CSRC",
                regulatorDomain: "sfc.hk",
                exchangeNames: ["Hong Kong Stock Exchange (HKEX)"],
                exchangeDomains: ["hkex.com.hk"],
                corporateRegistryName: "Companies Registry Hong Kong",
                corporateRegistryDomain: "cr.gov.hk",
                searchKeywords: ["HKEX", "Annual Report", "Interim Results", "Regulatory Filings"]
            )
        }

        // 7. DEFAULT: UNITED STATES
        return JurisdictionProfile(
            country: "United States",
            regulatorName: "Securities and Exchange Commission (SEC)",
            regulatorDomain: "sec.gov",
            exchangeNames: ["New York Stock Exchange (NYSE)", "NASDAQ"],
            exchangeDomains: ["nyse.com", "nasdaq.com"],
            corporateRegistryName: "SEC EDGAR / Delaware Division of Corporations",
            corporateRegistryDomain: "sec.gov/edgar",
            searchKeywords: ["SEC", "Form 10-K", "Form 10-Q", "Form 8-K", "Investor Relations", "Annual Report"]
        )
    }
}
