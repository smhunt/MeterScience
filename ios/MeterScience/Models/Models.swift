import Foundation
import SwiftUI
import CoreLocation

// MARK: - User & Gamification

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var displayName: String
    var avatarEmoji: String
    var joinedAt: Date
    var totalReadings: Int
    var verifiedReadings: Int
    var verificationsPerformed: Int
    var streakDays: Int
    var lastReadingDate: Date?
    var level: Int
    var xp: Int
    var badges: [Badge]
    var trustScore: Int
    var subscriptionTier: SubscriptionTier
    var referralCode: String
    var referralCount: Int
    
    init(displayName: String = "Reader") {
        self.id = UUID()
        self.displayName = displayName
        self.avatarEmoji = "📊"
        self.joinedAt = Date()
        self.totalReadings = 0
        self.verifiedReadings = 0
        self.verificationsPerformed = 0
        self.streakDays = 0
        self.level = 1
        self.xp = 0
        self.badges = []
        self.trustScore = 50
        self.subscriptionTier = .free
        self.referralCode = String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
        self.referralCount = 0
    }
    
    var xpForNextLevel: Int { level * 100 + 50 }
    
    mutating func addXP(_ amount: Int) {
        xp += amount
        while xp >= xpForNextLevel {
            xp -= xpForNextLevel
            level += 1
        }
    }
}

struct Badge: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let earnedAt: Date
}

enum SubscriptionTier: String, Codable, CaseIterable {
    case free, neighbor, block, district
    
    var monthlyPrice: Decimal {
        switch self {
        case .free: return 0
        case .neighbor: return 2.99
        case .block: return 4.99
        case .district: return 9.99
        }
    }
    
    var dataRadiusKm: Double? {
        switch self {
        case .free: return nil
        case .neighbor: return 0
        case .block: return 5
        case .district: return 25
        }
    }
}

struct MeterConfig: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var name: String
    var meterType: MeterType
    var digitCount: Int
    var hasDecimalPoint: Bool
    var boundingBox: NormalizedRect?
    var sampleReadings: [String]
    var averageConfidence: Float
    var postalCode: String?
    var country: String?
    var createdAt: Date
    var lastReadAt: Date?
    var isActive: Bool
    
    init(userId: UUID, name: String = "My Meter", meterType: MeterType = .electric) {
        self.id = UUID()
        self.userId = userId
        self.name = name
        self.meterType = meterType
        self.digitCount = 6
        self.hasDecimalPoint = false
        self.sampleReadings = []
        self.averageConfidence = 0
        self.createdAt = Date()
        self.isActive = true
    }
}

enum MeterType: String, Codable, CaseIterable {
    case electric, gas, water, solar, other
    
    var icon: String {
        switch self {
        case .electric: return "bolt.fill"
        case .gas: return "flame.fill"
        case .water: return "drop.fill"
        case .solar: return "sun.max.fill"
        case .other: return "gauge"
        }
    }
    
    var unit: String {
        switch self {
        case .electric, .solar: return "kWh"
        case .gas: return "m³"
        case .water: return "gal"
        case .other: return "units"
        }
    }
    
    var color: Color {
        switch self {
        case .electric: return .yellow
        case .gas: return .orange
        case .water: return .blue
        case .solar: return .green
        case .other: return .gray
        }
    }
    
    var expectedDigitRange: ClosedRange<Int> {
        switch self {
        case .electric: return 5...8
        case .gas: return 4...6
        case .water: return 5...8
        case .solar: return 5...10
        case .other: return 4...10
        }
    }
}

struct NormalizedRect: Codable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    
    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
    
    init(from cgRect: CGRect) {
        self.x = cgRect.origin.x
        self.y = cgRect.origin.y
        self.width = cgRect.size.width
        self.height = cgRect.size.height
    }
}

struct MeterReading: Codable, Identifiable {
    let id: UUID
    let meterId: UUID
    let userId: UUID
    let rawValue: String
    let normalizedValue: String
    let numericValue: Double?
    let confidence: Float
    let allCandidates: [ReadingCandidate]
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    let timestamp: Date
    let timezoneOffset: Int
    let captureMethod: CaptureMethod
    var verificationStatus: VerificationStatus
    var verificationVotes: [VerificationVote]
    var flaggedForReview: Bool
    var flagReason: String?
    var usageSinceLast: Double?
    var daysSinceLast: Double?
}

struct ReadingCandidate: Codable, Identifiable {
    let id: UUID
    let text: String
    let digitsOnly: String
    let confidence: Float
    let boundingBox: NormalizedRect
}

enum CaptureMethod: String, Codable {
    case live, photo, gallery, meterpi
}

enum VerificationStatus: String, Codable {
    case pending, verified, disputed, rejected
}

struct VerificationVote: Codable, Identifiable {
    let id: UUID
    let verifierId: UUID
    let verifierTrustScore: Int
    let vote: VoteType
    let suggestedValue: String?
    let timestamp: Date
}

enum VoteType: String, Codable {
    case correct, incorrect, unclear
}

struct VerificationTask: Codable, Identifiable {
    let id: UUID
    let readingId: UUID
    let meterId: UUID
    let meterType: MeterType
    let imageData: Data?
    let detectedValue: String
    let confidence: Float
    let digitCount: Int
    let previousReading: String?
    let daysSincePrevious: Double?
    let createdAt: Date
    let expiresAt: Date
    var votesReceived: Int
    var votesNeeded: Int
}

struct Campaign: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String
    var organizerId: UUID
    var organizerName: String
    var inviteCode: String
    var targetMeterCount: Int
    var participantCount: Int
    var metersRegistered: Int
    var totalReadings: Int
    var startDate: Date
    var endDate: Date
    var xpBonus: Int
    var isActive: Bool
    var isPublic: Bool
}

struct LeaderboardEntry: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let displayName: String
    let avatarEmoji: String
    let level: Int
    let totalReadings: Int
    let streakDays: Int
    let trustScore: Int
    let rank: Int
}
