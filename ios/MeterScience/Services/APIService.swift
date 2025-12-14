import Foundation

/// MeterScience API Service
/// Connects to the FastAPI backend at http://10.10.10.24:3090
actor APIService {
    static let shared = APIService()

    private let baseURL = "http://10.10.10.24:3090/api/v1"
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - HTTP Methods

    private func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let token = await AuthManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try decoder.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 400...499:
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.badRequest(errorResponse.detail)
            }
            throw APIError.badRequest("Request failed")
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    private func requestNoContent(
        _ endpoint: String,
        method: String,
        body: Encodable? = nil
    ) async throws {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await AuthManager.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }

    // MARK: - Auth

    func register(email: String?, displayName: String, password: String?) async throws -> AuthResponse {
        let body = RegisterRequest(email: email, displayName: displayName, password: password)
        return try await request("/users/register", method: "POST", body: body, authenticated: false)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let body = LoginRequest(email: email, password: password)
        return try await request("/users/login", method: "POST", body: body, authenticated: false)
    }

    // MARK: - Users

    func getCurrentUser() async throws -> UserResponse {
        try await request("/users/me")
    }

    func updateProfile(displayName: String?, avatarEmoji: String?, postalCode: String?) async throws -> UserResponse {
        let body = UpdateProfileRequest(displayName: displayName, avatarEmoji: avatarEmoji, postalCode: postalCode)
        return try await request("/users/me", method: "PATCH", body: body)
    }

    func getLeaderboard(scope: String = "global", limit: Int = 50) async throws -> [LeaderboardEntryResponse] {
        try await request("/users/leaderboard?scope=\(scope)&limit=\(limit)")
    }

    func applyReferral(code: String) async throws -> MessageResponse {
        try await request("/users/referral/\(code)", method: "POST")
    }

    // MARK: - Meters

    func getMeters() async throws -> [MeterResponse] {
        try await request("/meters/")
    }

    func createMeter(name: String, meterType: String, postalCode: String?) async throws -> MeterResponse {
        let body = CreateMeterRequest(name: name, meterType: meterType, postalCode: postalCode)
        return try await request("/meters/", method: "POST", body: body)
    }

    func getMeter(id: UUID) async throws -> MeterResponse {
        try await request("/meters/\(id)")
    }

    func updateMeter(id: UUID, name: String?, postalCode: String?) async throws -> MeterResponse {
        let body = UpdateMeterRequest(name: name, postalCode: postalCode)
        return try await request("/meters/\(id)", method: "PATCH", body: body)
    }

    func deleteMeter(id: UUID) async throws {
        try await requestNoContent("/meters/\(id)", method: "DELETE")
    }

    // MARK: - Readings

    func getReadings(meterId: UUID? = nil, page: Int = 1) async throws -> ReadingsListResponse {
        var endpoint = "/readings/?page=\(page)"
        if let meterId = meterId {
            endpoint += "&meter_id=\(meterId)"
        }
        return try await request(endpoint)
    }

    func createReading(meterId: UUID, rawValue: String, normalizedValue: String, confidence: Float, source: String = "manual") async throws -> ReadingResponse {
        let body = CreateReadingRequest(meterId: meterId, rawValue: rawValue, normalizedValue: normalizedValue, confidence: confidence, source: source)
        return try await request("/readings/", method: "POST", body: body)
    }

    func getReading(id: UUID) async throws -> ReadingResponse {
        try await request("/readings/\(id)")
    }

    // MARK: - Stats

    func getMyStats() async throws -> UserStatsResponse {
        try await request("/stats/me")
    }

    func getPlatformStats() async throws -> PlatformStatsResponse {
        try await request("/stats/platform")
    }

    func getMeterStats(id: UUID) async throws -> MeterStatsResponse {
        try await request("/stats/meters/\(id)")
    }

    // MARK: - Campaigns

    func getCampaigns() async throws -> CampaignsListResponse {
        try await request("/campaigns/")
    }

    func joinCampaign(id: UUID) async throws -> CampaignParticipantResponse {
        try await request("/campaigns/\(id)/join", method: "POST")
    }

    func leaveCampaign(id: UUID) async throws {
        try await requestNoContent("/campaigns/\(id)/leave", method: "POST")
    }

    // MARK: - Verification

    func getVerificationQueue(limit: Int = 10) async throws -> VerificationQueueResponse {
        try await request("/verify/queue?limit=\(limit)")
    }

    func voteOnReading(readingId: UUID, vote: String, suggestedValue: String? = nil) async throws -> VoteResponse {
        let body = VoteRequest(vote: vote, suggestedValue: suggestedValue)
        return try await request("/verify/\(readingId)/vote", method: "POST", body: body)
    }

    func getVerificationHistory() async throws -> VerificationHistoryResponse {
        try await request("/verify/history")
    }
}

// MARK: - Request/Response Models

struct RegisterRequest: Encodable {
    let email: String?
    let displayName: String
    let password: String?
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct AuthResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let user: UserResponse
}

struct UserResponse: Decodable {
    let id: UUID
    let email: String?
    let displayName: String
    let avatarEmoji: String
    let level: Int
    let xp: Int
    let totalReadings: Int
    let verifiedReadings: Int
    let verificationsPerformed: Int
    let streakDays: Int
    let trustScore: Int
    let badges: [BadgeResponse]
    let subscriptionTier: String
    let referralCode: String?
    let referralCount: Int
    let createdAt: Date
}

struct BadgeResponse: Decodable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let earnedAt: Date
}

struct UpdateProfileRequest: Encodable {
    let displayName: String?
    let avatarEmoji: String?
    let postalCode: String?
}

struct LeaderboardEntryResponse: Decodable, Identifiable {
    let rank: Int
    let userId: String
    let displayName: String
    let avatarEmoji: String
    let level: Int
    let totalReadings: Int
    let streakDays: Int
    let trustScore: Int

    var id: String { userId }
}

struct MessageResponse: Decodable {
    let message: String
}

struct MeterResponse: Decodable, Identifiable {
    let id: UUID
    let userId: UUID
    let name: String
    let meterType: String
    let utilityProvider: String?
    let postalCode: String?
    let digitCount: Int
    let isActive: Bool
    let lastReadAt: Date?
    let createdAt: Date
}

struct CreateMeterRequest: Encodable {
    let name: String
    let meterType: String
    let postalCode: String?
}

struct UpdateMeterRequest: Encodable {
    let name: String?
    let postalCode: String?
}

struct ReadingsListResponse: Decodable {
    let readings: [ReadingResponse]
    let total: Int
    let page: Int
    let perPage: Int
}

struct ReadingResponse: Decodable, Identifiable {
    let id: UUID
    let meterId: UUID
    let userId: UUID
    let rawValue: String
    let normalizedValue: String
    let numericValue: Double?
    let confidence: Float
    let verificationStatus: String
    let usageSinceLast: Double?
    let daysSinceLast: Double?
    let capturedAt: Date
    let createdAt: Date
}

struct CreateReadingRequest: Encodable {
    let meterId: UUID
    let rawValue: String
    let normalizedValue: String
    let confidence: Float
    let source: String
}

struct UserStatsResponse: Decodable {
    let userId: UUID
    let displayName: String
    let level: Int
    let xp: Int
    let xpToNextLevel: Int
    let totalReadings: Int
    let verifiedReadings: Int
    let verificationsPerformed: Int
    let streakDays: Int
    let trustScore: Int
    let badges: [BadgeResponse]
    let subscriptionTier: String
    let metersCount: Int
    let readingsThisMonth: Int
    let readingsThisWeek: Int
    let averageConfidence: Float
    let memberSince: Date
    let rank: Int?
}

struct PlatformStatsResponse: Decodable {
    let totalUsers: Int
    let totalMeters: Int
    let totalReadings: Int
    let readingsToday: Int
    let readingsThisWeek: Int
    let readingsThisMonth: Int
    let activeCampaigns: Int
    let countriesRepresented: Int
}

struct MeterStatsResponse: Decodable {
    let meterId: UUID
    let meterName: String
    let meterType: String
    let totalReadings: Int
    let verifiedReadings: Int
    let averageConfidence: Float
    let averageDailyUsage: Double?
    let usageThisMonth: Double?
    let usageLastMonth: Double?
    let firstReadingAt: Date?
    let lastReadingAt: Date?
}

struct CampaignsListResponse: Decodable {
    let campaigns: [CampaignResponse]
    let total: Int
}

struct CampaignResponse: Decodable, Identifiable {
    let id: UUID
    let organizerId: UUID
    let name: String
    let description: String?
    let participantCount: Int
    let totalReadings: Int
    let startDate: Date
    let endDate: Date
    let isActive: Bool
    let isPublic: Bool
    let xpBonus: Int
    let isOrganizer: Bool
    let isParticipant: Bool
    let progressPercent: Float
}

struct CampaignParticipantResponse: Decodable {
    let id: UUID
    let userId: UUID
    let displayName: String
    let readingsSubmitted: Int
    let joinedAt: Date
}

struct VerificationQueueResponse: Decodable {
    let readings: [VerificationReadingResponse]
    let totalAvailable: Int
}

struct VerificationReadingResponse: Decodable, Identifiable {
    let id: UUID
    let meterType: String
    let rawValue: String
    let normalizedValue: String
    let confidence: Float
    let imageUrl: String?
    let capturedAt: Date
    let votesCount: Int
    let postalCodePrefix: String?
}

struct VoteRequest: Encodable {
    let vote: String
    let suggestedValue: String?
}

struct VoteResponse: Decodable {
    let id: UUID
    let readingId: UUID
    let verifierId: UUID
    let vote: String
    let suggestedValue: String?
    let createdAt: Date
}

struct VerificationHistoryResponse: Decodable {
    let totalVerifications: Int
    let verificationsThisWeek: Int
    let consensusMatches: Int
    let consensusRate: Float
    let xpEarned: Int
    let recentVotes: [VoteResponse]
}

struct APIErrorResponse: Decodable {
    let detail: String
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case badRequest(String)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .unauthorized: return "Please log in again"
        case .notFound: return "Resource not found"
        case .badRequest(let message): return message
        case .serverError(let code): return "Server error (\(code))"
        }
    }
}

// MARK: - Helpers

struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}
