import Foundation

/// Service to read API configuration from .api-config.plist file
class ConfigurationService {
    static let shared = ConfigurationService()

    private var config: [String: Any]?

    private init() {
        loadConfiguration()
    }

    /// Load the configuration from .api-config.plist
    private func loadConfiguration() {
        // Try to load from the root directory
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

    // MARK: - API Configuration

    /// Base URL for the API
    var apiBaseURL: String {
        if let apiDict = config?["API"] as? [String: Any],
           let baseURL = apiDict["BaseURL"] as? String {
            return baseURL
        }
        return "https://api.example.com"
    }

    /// API Key
    var apiKey: String {
        if let apiDict = config?["API"] as? [String: Any],
           let key = apiDict["APIKey"] as? String {
            return key
        }
        return ""
    }

    /// API Secret
    var apiSecret: String {
        if let apiDict = config?["API"] as? [String: Any],
           let secret = apiDict["APISecret"] as? String {
            return secret
        }
        return ""
    }

    // MARK: - Service Specific Configuration

    /// Get endpoint for a specific service
    func endpoint(for service: String) -> String {
        if let servicesDict = config?["Services"] as? [String: Any],
           let serviceDict = servicesDict[service] as? [String: Any],
           let endpoint = serviceDict["Endpoint"] as? String {
            return endpoint
        }
        return ""
    }

    /// Get token for a specific service
    func token(for service: String) -> String {
        if let servicesDict = config?["Services"] as? [String: Any],
           let serviceDict = servicesDict[service] as? [String: Any],
           let token = serviceDict["Token"] as? String {
            return token
        }
        return ""
    }

    /// Full URL for a service endpoint
    func fullURL(for service: String) -> String {
        return apiBaseURL + endpoint(for: service)
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
        return true // Default to mock data if not configured
    }

    // MARK: - Convenience Methods

    /// Get a custom value from the config
    func value<T>(forKeyPath keyPath: String) -> T? {
        guard let config = config else { return nil }

        let keys = keyPath.components(separatedBy: ".")
        var current: Any = config

        for key in keys {
            guard let dict = current as? [String: Any],
                  let value = dict[key] else {
                return nil
            }
            current = value
        }

        return current as? T
    }
}

// MARK: - Usage Examples

/*
 Usage:

 // Access API credentials
 let baseURL = ConfigurationService.shared.apiBaseURL
 let apiKey = ConfigurationService.shared.apiKey

 // Access service-specific configuration
 let healthEndpoint = ConfigurationService.shared.endpoint(for: "HealthDataAPI")
 let healthToken = ConfigurationService.shared.token(for: "HealthDataAPI")
 let fullURL = ConfigurationService.shared.fullURL(for: "HealthDataAPI")

 // Check feature flags
 if ConfigurationService.shared.isDebugModeEnabled {
     print("Debug mode is enabled")
 }

 // Get custom values
 let customValue: String? = ConfigurationService.shared.value(forKeyPath: "API.BaseURL")
 */
