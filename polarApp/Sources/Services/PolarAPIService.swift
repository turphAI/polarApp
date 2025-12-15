import Foundation

/// Service to fetch data from Polar AccessLink API
/// Documentation: https://www.polar.com/accesslink-api/
class PolarAPIService {
    static let shared = PolarAPIService()
    
    private let config = ConfigurationService.shared
    private let auth = PolarAuthService.shared
    
    private init() {}
    
    // MARK: - API Request Helper
    
    private func makeAuthenticatedRequest(url: URL, method: String = "GET") async throws -> Data {
        guard let accessToken = auth.getStoredAccessToken() else {
            throw PolarAPIError.notAuthenticated
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolarAPIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw PolarAPIError.unauthorized
        case 403:
            throw PolarAPIError.forbidden
        case 404:
            throw PolarAPIError.notFound
        case 429:
            throw PolarAPIError.rateLimited
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PolarAPIError.requestFailed(httpResponse.statusCode, message)
        }
    }
    
    // MARK: - Pull Notifications
    
    /// Check for available data (exercises, activity, sleep, etc.)
    func getAvailableData() async throws -> AvailableData {
        guard let userID = auth.getStoredUserID(),
              let url = URL(string: config.apiBaseURL + "/v3/users/\(userID)/available-data") else {
            throw PolarAPIError.invalidURL
        }
        
        let data = try await makeAuthenticatedRequest(url: url)
        return try JSONDecoder().decode(AvailableData.self, from: data)
    }
    
    // MARK: - Exercises
    
    /// List all exercises
    func getExercises() async throws -> [Exercise] {
        guard let url = URL(string: config.fullURL(for: .exercises)) else {
            throw PolarAPIError.invalidURL
        }
        
        let data = try await makeAuthenticatedRequest(url: url)
        let response = try JSONDecoder().decode(ExercisesResponse.self, from: data)
        return response.exercises
    }
    
    /// Get a specific exercise by ID
    func getExercise(id: String) async throws -> Exercise {
        guard let url = URL(string: config.fullURL(for: .exercises) + "/\(id)") else {
            throw PolarAPIError.invalidURL
        }
        
        let data = try await makeAuthenticatedRequest(url: url)
        return try JSONDecoder().decode(Exercise.self, from: data)
    }
    
    // MARK: - Daily Activity
    
    /// Get daily activity summary for past 28 days
    func getDailyActivities() async throws -> [DailyActivity] {
        guard let userID = auth.getStoredUserID(),
              let url = URL(string: config.apiBaseURL + "/v3/users/\(userID)/activity") else {
            throw PolarAPIError.invalidURL
        }
        
        let data = try await makeAuthenticatedRequest(url: url)
        let response = try JSONDecoder().decode(DailyActivitiesResponse.self, from: data)
        return response.activityLog
    }
    
    /// Get activity for a specific date
    func getDailyActivity(date: Date) async throws -> DailyActivity {
        guard let userID = auth.getStoredUserID() else {
            throw PolarAPIError.notAuthenticated
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        guard let url = URL(string: config.apiBaseURL + "/v3/users/\(userID)/activity/\(dateString)") else {
            throw PolarAPIError.invalidURL
        }
        
        let data = try await makeAuthenticatedRequest(url: url)
        return try JSONDecoder().decode(DailyActivity.self, from: data)
    }
    
    // MARK: - Continuous Heart Rate
    
    /// Get continuous heart rate data
    func getContinuousHeartRate(date: Date) async throws -> ContinuousHeartRate {
        guard let userID = auth.getStoredUserID() else {
            throw PolarAPIError.notAuthenticated
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        guard let url = URL(string: config.apiBaseURL + "/v3/users/\(userID)/continuous-heart-rate/\(dateString)") else {
            throw PolarAPIError.invalidURL
        }
        
        let data = try await makeAuthenticatedRequest(url: url)
        return try JSONDecoder().decode(ContinuousHeartRate.self, from: data)
    }
    
    // MARK: - Sleep
    
    /// Get sleep data for the past 28 nights
    func getSleepData() async throws -> [SleepData] {
        guard let userID = auth.getStoredUserID(),
              let url = URL(string: config.apiBaseURL + "/v3/users/\(userID)/sleep") else {
            throw PolarAPIError.invalidURL
        }
        
        let data = try await makeAuthenticatedRequest(url: url)
        let response = try JSONDecoder().decode(SleepResponse.self, from: data)
        return response.nights
    }
    
    /// Get sleep data for a specific date
    func getSleepData(date: Date) async throws -> SleepData {
        guard let userID = auth.getStoredUserID() else {
            throw PolarAPIError.notAuthenticated
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        guard let url = URL(string: config.apiBaseURL + "/v3/users/\(userID)/sleep/\(dateString)") else {
            throw PolarAPIError.invalidURL
        }
        
        let data = try await makeAuthenticatedRequest(url: url)
        return try JSONDecoder().decode(SleepData.self, from: data)
    }
    
    // MARK: - Nightly Recharge
    
    /// Get nightly recharge data
    func getNightlyRecharge() async throws -> [NightlyRecharge] {
        guard let userID = auth.getStoredUserID(),
              let url = URL(string: config.apiBaseURL + "/v3/users/\(userID)/nightly-recharge") else {
            throw PolarAPIError.invalidURL
        }
        
        let data = try await makeAuthenticatedRequest(url: url)
        let response = try JSONDecoder().decode(NightlyRechargeResponse.self, from: data)
        return response.recharges
    }
    
    // MARK: - Cardio Load
    
    /// Get cardio load data
    func getCardioLoad() async throws -> [CardioLoad] {
        guard let userID = auth.getStoredUserID(),
              let url = URL(string: config.apiBaseURL + "/v3/users/\(userID)/cardio-load") else {
            throw PolarAPIError.invalidURL
        }
        
        let data = try await makeAuthenticatedRequest(url: url)
        let response = try JSONDecoder().decode(CardioLoadResponse.self, from: data)
        return response.cardioLoads
    }
}

// MARK: - API Response Models

struct AvailableData: Codable {
    let availableUserData: [String]?
    
    enum CodingKeys: String, CodingKey {
        case availableUserData = "available-user-data"
    }
}

struct ExercisesResponse: Codable {
    let exercises: [Exercise]
}

struct Exercise: Codable, Identifiable {
    let id: String
    let uploadTime: String?
    let polarUser: String?
    let device: String?
    let deviceId: String?
    let startTime: String?
    let startTimeUtcOffset: Int?
    let duration: String?
    let calories: Int?
    let distance: Double?
    let heartRate: HeartRateData?
    let trainingLoad: Double?
    let sport: String?
    let hasRoute: Bool?
    let detailedSportInfo: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case uploadTime = "upload-time"
        case polarUser = "polar-user"
        case device
        case deviceId = "device-id"
        case startTime = "start-time"
        case startTimeUtcOffset = "start-time-utc-offset"
        case duration
        case calories
        case distance
        case heartRate = "heart-rate"
        case trainingLoad = "training-load"
        case sport
        case hasRoute = "has-route"
        case detailedSportInfo = "detailed-sport-info"
    }
}

struct HeartRateData: Codable {
    let average: Int?
    let maximum: Int?
    let minimum: Int?
}

struct DailyActivitiesResponse: Codable {
    let activityLog: [DailyActivity]
    
    enum CodingKeys: String, CodingKey {
        case activityLog = "activity-log"
    }
}

struct DailyActivity: Codable, Identifiable {
    let id: String?
    let date: String?
    let createdAt: String?
    let calories: Int?
    let activeCalories: Int?
    let duration: String?
    let activeSteps: Int?
    let dailyActivityGoal: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case createdAt = "created-at"
        case calories
        case activeCalories = "active-calories"
        case duration
        case activeSteps = "active-steps"
        case dailyActivityGoal = "daily-activity-goal"
    }
}

struct ContinuousHeartRate: Codable {
    let date: String?
    let samples: [HeartRateSample]?
}

struct HeartRateSample: Codable {
    let heartRate: Int?
    let sampleTime: String?
    
    enum CodingKeys: String, CodingKey {
        case heartRate = "heart-rate"
        case sampleTime = "sample-time"
    }
}

struct SleepResponse: Codable {
    let nights: [SleepData]
}

struct SleepData: Codable, Identifiable {
    let id: String?
    let date: String?
    let sleepStartTime: String?
    let sleepEndTime: String?
    let deviceId: String?
    let continuity: Double?
    let continuityClass: Int?
    let lightSleep: Int?
    let deepSleep: Int?
    let remSleep: Int?
    let unrecognizedSleepStage: Int?
    let sleepScore: Int?
    let totalInterruptionDuration: Int?
    let sleepCharge: Int?
    let sleepRating: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case sleepStartTime = "sleep_start_time"
        case sleepEndTime = "sleep_end_time"
        case deviceId = "device_id"
        case continuity
        case continuityClass = "continuity_class"
        case lightSleep = "light_sleep"
        case deepSleep = "deep_sleep"
        case remSleep = "rem_sleep"
        case unrecognizedSleepStage = "unrecognized_sleep_stage"
        case sleepScore = "sleep_score"
        case totalInterruptionDuration = "total_interruption_duration"
        case sleepCharge = "sleep_charge"
        case sleepRating = "sleep_rating"
    }
}

struct NightlyRechargeResponse: Codable {
    let recharges: [NightlyRecharge]
}

struct NightlyRecharge: Codable, Identifiable {
    let id: String?
    let date: String?
    let heartRateVariability: HRVData?
    let ansCharge: Double?
    let ansChargeStatus: Int?
    let sleepCharge: Int?
    let sleepChargeStatus: Int?
    let nightlyRechargeStatus: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case heartRateVariability = "heart-rate-variability"
        case ansCharge = "ans-charge"
        case ansChargeStatus = "ans-charge-status"
        case sleepCharge = "sleep-charge"
        case sleepChargeStatus = "sleep-charge-status"
        case nightlyRechargeStatus = "nightly-recharge-status"
    }
}

struct HRVData: Codable {
    let average: Int?
    let maximum: Int?
    let minimum: Int?
}

struct CardioLoadResponse: Codable {
    let cardioLoads: [CardioLoad]
    
    enum CodingKeys: String, CodingKey {
        case cardioLoads = "cardio-loads"
    }
}

struct CardioLoad: Codable, Identifiable {
    let id: String?
    let date: String?
    let cardioLoad: Double?
    let cardioLoadRatio: Double?
    let cardioLoadStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case cardioLoad = "cardio-load"
        case cardioLoadRatio = "cardio-load-ratio"
        case cardioLoadStatus = "cardio-load-status"
    }
}

// MARK: - Errors

enum PolarAPIError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case requestFailed(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated. Please sign in first."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Access token is invalid or expired. Please sign in again."
        case .forbidden:
            return "Access denied. User may not have given required consents."
        case .notFound:
            return "Requested resource not found"
        case .rateLimited:
            return "Rate limit exceeded. Please try again later."
        case .requestFailed(let code, let message):
            return "Request failed (\(code)): \(message)"
        }
    }
}

