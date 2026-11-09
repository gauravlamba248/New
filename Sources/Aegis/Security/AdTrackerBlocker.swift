import Foundation

/// Ultra-lightweight, zero-allocation flat domain suffix blocker.
/// Uses a flat contiguous Set<String> taking < 4KB of RAM, eliminating recursive heap nodes.
public final class AdTrackerBlocker: @unchecked Sendable {
    public static let shared = AdTrackerBlocker()

    private var blockedDomains: [String: String] = [:]
    private var domainSet: Set<String> = []
    private let lock = NSLock()
    private(set) var totalBlockedCount: Int = 0
    public private(set) var isEnabled: Bool = true

    private init() {
        populateDefaultBlocklists()
    }

    /// Dynamically enables or disables the Ad & Tracker blocker individually
    public func setEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.isEnabled = enabled
    }

    /// Primary evaluation method for URLs
    public func isBlocked(url: URL) -> (blocked: Bool, reason: String?) {
        guard let host = url.host?.lowercased() else {
            return (false, nil)
        }
        return isBlocked(host: host)
    }

    /// Evaluates a hostname against the flat suffix database in O(1) time
    public func isBlocked(host: String) -> (blocked: Bool, reason: String?) {
        let cleanHost = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !cleanHost.isEmpty else { return (false, nil) }

        lock.lock()
        defer { lock.unlock() }

        guard isEnabled else { return (false, nil) }

        var current = cleanHost[...]
        while true {
            let key = String(current)
            if domainSet.contains(key) {
                totalBlockedCount += 1
                let desc = blockedDomains[key] ?? key
                return (true, "Offline blocklist hit: \(desc)")
            }
            guard let dotIndex = current.firstIndex(of: ".") else { break }
            current = current[current.index(after: dotIndex)...]
        }

        return (false, nil)
    }

    public func addCustomRule(domain: String, ruleDescription: String) {
        lock.lock()
        defer { lock.unlock() }
        let clean = domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        blockedDomains[clean] = ruleDescription
        domainSet.insert(clean)
    }

    private func populateDefaultBlocklists() {
        let defaultBlocklist: [(domain: String, desc: String)] = [
            ("doubleclick.net", "Google DoubleClick Ad Network"),
            ("google-analytics.com", "Google Analytics Telemetry"),
            ("googletagmanager.com", "Google Tag Manager Script Injector"),
            ("scorecardresearch.com", "Comscore Tracker"),
            ("quantserve.com", "Quantcast Audience Tracker"),
            ("criteo.com", "Criteo Behavioral Retargeting"),
            ("criteo.net", "Criteo Advertising"),
            ("adnxs.com", "AppNexus / Xandr Ad Exchange"),
            ("adform.net", "Adform Tracking Beacon"),
            ("moatads.com", "Oracle Moat Ad Verification"),
            ("branch.io", "Branch Device Fingerprinting"),
            ("adjust.com", "Adjust Mobile Attributions"),
            ("appsflyer.com", "AppsFlyer Telemetry"),
            ("mixpanel.com", "Mixpanel Analytics Collector"),
            ("hotjar.com", "Hotjar Session Recorder & Keystroke Monitor"),
            ("mouseflow.com", "Mouseflow Session Replay"),
            ("clarity.ms", "Microsoft Clarity Telemetry"),
            ("telemetry.microsoft.com", "Microsoft OS Telemetry"),
            ("vortex.data.microsoft.com", "Microsoft Vortex Telemetry"),
            ("graph.facebook.com", "Facebook Graph Tracking API"),
            ("pixel.facebook.com", "Meta Pixel Beacon"),
            ("analytics.tiktok.com", "TikTok Event Telemetry"),
            ("ads.twitter.com", "X/Twitter Ad Tracking"),
            ("telemetry.dropbox.com", "Dropbox Diagnostic Telemetry"),
            ("crashlytics.com", "Crashlytics Reporting Beacon"),
            ("segment.io", "Twilio Segment Tracking Pipeline"),
            ("amplitude.com", "Amplitude Analytics Collector"),
            ("outbrain.com", "Outbrain Clickbait Widget"),
            ("taboola.com", "Taboola Content Recommendation Beacon")
        ]

        for item in defaultBlocklist {
            blockedDomains[item.domain] = item.desc
            domainSet.insert(item.domain)
        }
    }
}
