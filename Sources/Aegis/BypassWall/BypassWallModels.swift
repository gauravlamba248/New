import Foundation
import SwiftUI

/// Dynamic user-facing states for the Bypass Wall button in the browser toolbar
public enum BypassButtonState: String, Sendable, Equatable {
    case idle = "Bypass Wall"
    case analyzing = "Analyzing…"
    case wallDetected = "Wall Detected"
    case contentAvailable = "Content Available"
    case nothingToBypass = "Nothing to Bypass"
    case blockedByAuthentication = "Blocked by Authentication"
    case blockedByPaywall = "Blocked by Paywall"
    case blockedByCAPTCHA = "Blocked by CAPTCHA"
    case unsupported = "Unsupported"

    public var title: String { rawValue }

    public var iconName: String {
        switch self {
        case .idle: return "eye.slash.circle"
        case .analyzing: return "waveform.and.magnifyingglass"
        case .wallDetected: return "exclamationmark.shield.fill"
        case .contentAvailable: return "doc.text.image.fill"
        case .nothingToBypass: return "checkmark.circle"
        case .blockedByAuthentication: return "lock.fill"
        case .blockedByPaywall: return "creditcard.fill"
        case .blockedByCAPTCHA: return "hand.raised.fill"
        case .unsupported: return "questionmark.circle"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .idle: return .secondary
        case .analyzing: return .blue
        case .wallDetected: return .orange
        case .contentAvailable: return .green
        case .nothingToBypass: return .secondary
        case .blockedByAuthentication: return .red
        case .blockedByPaywall: return .purple
        case .blockedByCAPTCHA: return .red
        case .unsupported: return .gray
        }
    }
}

/// Types of presentation-level cosmetic overlays (client-side DOM obstacles)
public enum PresentationBarrierType: String, Sendable, Codable {
    case loginModalOverlay = "Login / Sign In Modal Overlay"
    case signupModalOverlay = "Registration / Account Creation Overlay"
    case newsletterPrompt = "Newsletter / Email Capture Interstitial"
    case cookieConsentOverlay = "Consent / Cookie Wall Banner"
    case promotionalModal = "Promotional / Commercial Pop-up"
    case interstitialInformational = "Informational Interstitial Screen"
}

/// Types of genuine server-enforced access controls
public enum AccessControlBarrierType: String, Sendable, Codable {
    case paidSubscriptionPaywall = "Paid / Subscription Paywall"
    case authenticationRequired = "Account Authorization Required"
    case captchaChallenge = "CAPTCHA / Anti-Bot Challenge"
    case privateAccount = "Private / Protected Resource"
}

/// Comprehensive classification produced by the detection subsystem
public enum WallClassification: Sendable, Equatable {
    case none
    case presentationBarrier(type: PresentationBarrierType, isFullContentAvailable: Bool)
    case accessControlBarrier(type: AccessControlBarrierType, reason: String)
    case redirectInterstitial(targetURL: URL)
    case unsupported(reason: String)

    public var isPresentationOnly: Bool {
        if case .presentationBarrier = self { return true }
        return false
    }

    public var isAccessControlled: Bool {
        if case .accessControlBarrier = self { return true }
        return false
    }
}

/// Semantic article extracted from DOM for clean reader presentation
public struct CleanedArticle: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let author: String?
    public let publicationDate: String?
    public let siteName: String?
    public let sourceURL: URL?
    public let sanitizedHTML: String
    public let plainText: String
    public let wordCount: Int
    public let estimatedReadingMinutes: Int
    public let isPartialContent: Bool
    public let partialNotice: String?

    public init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        publicationDate: String? = nil,
        siteName: String? = nil,
        sourceURL: URL? = nil,
        sanitizedHTML: String,
        plainText: String,
        wordCount: Int,
        estimatedReadingMinutes: Int,
        isPartialContent: Bool = false,
        partialNotice: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.publicationDate = publicationDate
        self.siteName = siteName
        self.sourceURL = sourceURL
        self.sanitizedHTML = sanitizedHTML
        self.plainText = plainText
        self.wordCount = wordCount
        self.estimatedReadingMinutes = estimatedReadingMinutes
        self.isPartialContent = isPartialContent
        self.partialNotice = partialNotice
    }
}

/// Transparent, explainable audit record presented to the user
public struct ExplainableBypassResult: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let status: String
    public let actionTaken: String
    public let contentSource: String
    public let securityAffirmation: String
    public let isRefusal: Bool
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        status: String,
        actionTaken: String,
        contentSource: String,
        securityAffirmation: String,
        isRefusal: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.status = status
        self.actionTaken = actionTaken
        self.contentSource = contentSource
        self.securityAffirmation = securityAffirmation
        self.isRefusal = isRefusal
        self.timestamp = timestamp
    }
}

/// Link-level pre-navigation classification
public enum LinkClassification: String, Sendable {
    case publicContent = "PUBLIC"
    case publicWithPresentationWall = "PUBLIC + PRESENTATION WALL"
    case loginRequired = "LOGIN REQUIRED"
    case paywall = "PAYWALL"
    case captcha = "CAPTCHA"
    case unsupported = "UNSUPPORTED"
}
