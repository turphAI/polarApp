import Foundation

/// Service to read Polar AccessLink API configuration from .api-config.plist file
/// Documentation: https://www.polar.com/accesslink-api/
class ConfigurationService {
    static let shared = ConfigurationService()

    private var config: [String: Any]?

    private init() {
        loadConfiguration()
    }

    /// Load the configuration from .api-config.plist
    private func loadConfiguration() {
        let fileManager = FileManager.default

        // Get the project root path (assuming the plist is at the root)
        if let projectPath = Bundle.main.resourcePath?.replacingOccurrences(of: "/build/", with: "/"),
           let configPath = fileManager.contents(atPath: projectPath + "/.api-config.plist") {
            config = try? PropertyListSerialization.propertyList(from: configPath, format: nil) as? [String: Any]
        }

        // Alternative: Try to load from bundle resources if added to Xcode project
        if config == nil,
           let path = Bundle.main.path(forResource: ".api-config", ofType: "plist"),
           let data = fileManager.contents(atPath: path) {
            config = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        }

        if config == nil {
            print("⚠️ Warning: .api-config.plist not found. Using default values.")
            print("📝 Please copy api-config.example.plist to .api-config.plist and fill in your API credentials.")
        }
    }

    // MARK: - OAuth2 Configuration (Polar AccessLink)

    /// OAuth2 Client ID from admin.polaraccesslink.com
    var clientID: String {
        if let oauth = config?["OAuth2"] as? [String: Any],
           let clientID = oauth["ClientID"] as? String {
            return clientID
        }
        return ""
    }

    /// OAuth2 Client Secret from admin.polaraccesslink.com
    var clientSecret: String {
        if let oauth = config?["OAuth2"] as? [String: Any],
           let secret = oauth["ClientSecret"] as? String {
            return secret
        }
        return ""
    }

    /// OAuth2 Authorization URL (Polar Flow)
    var authorizationURL: String {
        if let oauth = config?["OAuth2"] as? [String: Any],
           let url = oauth["AuthorizationURL"] as? String {
            return url
        }
        return "https://flow.polar.com/oauth2/authorization"
    }

    /// OAuth2 Token URL
    var tokenURL: String {
        if let oauth = config?["OAuth2"] as? [String: Any],
           let url = oauth["TokenURL"] as? String {
            return url
        }
        return "https://polarremote.com/v2/oauth2/token"
    }

    /// OAuth2 Redirect URI for your app
    var redirectURI: String {
        if let oauth = config?["OAuth2"] as? [String: Any],
           let uri = oauth["RedirectURI"] as? String {
            return uri
        }
        return "polarapp://callback"
    }

    /// OAuth2 Scopes
    var scopes: [String] {
        if let oauth = config?["OAuth2"] as? [String: Any],
           let scopes = oauth["Scopes"] as? [String] {
            return scopes
        }
        return ["accesslink.read_all"]
    }

    // MARK: - API Configuration

    /// Base URL for Polar AccessLink API
    var apiBaseURL: String {
        if let apiDict = config?["API"] as? [String: Any],
           let baseURL = apiDict["BaseURL"] as? String {
            return baseURL
        }
        return "https://www.polaraccesslink.com"
    }

    /// API Version
    var apiVersion: String {
        if let apiDict = config?["API"] as? [String: Any],
           let version = apiDict["Version"] as? String {
            return version
        }
        return "v3"
    }

    // MARK: - Endpoint Configuration

    /// Get endpoint path for a specific resource
    func endpoint(for resource: PolarEndpoint) -> String {
        if let endpoints = config?["Endpoints"] as? [String: Any],
           let path = endpoints[resource.rawValue] as? String {
            return path
        }
        return resource.defaultPath
    }

    /// Full URL for a resource endpoint
    func fullURL(for resource: PolarEndpoint) -> String {
        return apiBaseURL + endpoint(for: resource)
    }

    /// Full URL for a resource endpoint with user ID
    func fullURL(for resource: PolarEndpoint, userID: String) -> String {
        let path = endpoint(for: resource).replacingOccurrences(of: "{user-id}", with: userID)
        return apiBaseURL + path
    }

    // MARK: - Feature Flags

    /// Check if debug mode is enabled
    var isDebugModeEnabled: Bool {
        if let featuresDict = config?["Features"] as? [String: Any],
           let enabled = featuresDict["EnableDebugMode"] as? Bool {
            return enabled
        }
        return false
    }

    /// Check if mock data is enabled
    var isMockDataEnabled: Bool {
        if let featuresDict = config?["Features"] as? [String: Any],
           let enabled = featuresDict["EnableMockData"] as? Bool {
            return enabled
        }
        return false
    }

    // MARK: - OAuth2 URL Builders

    /// Build the authorization URL for OAuth2 flow
    func buildAuthorizationURL(state: String? = nil) -> URL? {
        var components = URLComponents(string: authorizationURL)
        var queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " "))
        ]
        
        if let state = state {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
        
        components?.queryItems = queryItems
        return components?.url
    }

    // MARK: - Validation

    /// Check if the configuration is valid
    var isConfigurationValid: Bool {
        return !clientID.isEmpty &&
               !clientSecret.isEmpty &&
               clientID != "YOUR_CLIENT_ID_HERE" &&
               clientSecret != "YOUR_CLIENT_SECRET_HERE"
    }
}

// MARK: - Polar API Endpoints

enum PolarEndpoint: String {
    case users = "Users"
    case pullNotifications = "PullNotifications"
    case exercises = "Exercises"
    case dailyActivity = "DailyActivity"
    case sleep = "Sleep"
    case nightlyRecharge = "NightlyRecharge"
    case continuousHeartRate = "ContinuousHeartRate"
    case cardioLoad = "CardioLoad"
    case physicalInfo = "PhysicalInfo"

    var defaultPath: String {
        switch self {
        case .users:
            return "/v3/users"
        case .pullNotifications:
            return "/v3/notifications"
        case .exercises:
            return "/v3/exercises"
        case .dailyActivity:
            return "/v3/users/{user-id}/activity-transactions"
        case .sleep:
            return "/v3/users/{user-id}/sleep"
        case .nightlyRecharge:
            return "/v3/users/{user-id}/nightly-recharge"
        case .continuousHeartRate:
            return "/v3/users/{user-id}/continuous-heart-rate"
        case .cardioLoad:
            return "/v3/users/{user-id}/cardio-load"
        case .physicalInfo:
            return "/v3/users/{user-id}/physical-information-transactions"
        }
    }
}

// MARK: - Usage Examples

/*
 Polar AccessLink API Usage:
 
 // 1. Check if configuration is valid
 guard ConfigurationService.shared.isConfigurationValid else {
     print("Please configure your API credentials in .api-config.plist")
     return
 }
 
 // 2. Get OAuth2 credentials
 let clientID = ConfigurationService.shared.clientID
 let clientSecret = ConfigurationService.shared.clientSecret
 
 // 3. Build authorization URL for OAuth2 flow
 if let authURL = ConfigurationService.shared.buildAuthorizationURL(state: UUID().uuidString) {
     // Open authURL in browser for user to authorize
 }
 
 // 4. Get API endpoints
 let usersURL = ConfigurationService.shared.fullURL(for: .users)
 let exercisesURL = ConfigurationService.shared.fullURL(for: .exercises)
 
 // 5. Get user-specific endpoints
 let userID = "123456"
 let sleepURL = ConfigurationService.shared.fullURL(for: .sleep, userID: userID)
 let heartRateURL = ConfigurationService.shared.fullURL(for: .continuousHeartRate, userID: userID)
 */
