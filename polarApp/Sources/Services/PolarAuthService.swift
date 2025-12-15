import Foundation
import AuthenticationServices

/// Service to handle Polar AccessLink OAuth2 authentication
/// Documentation: https://www.polar.com/accesslink-api/#authentication
class PolarAuthService: NSObject, ObservableObject {
    static let shared = PolarAuthService()
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: PolarAuthError?
    @Published var currentUser: PolarUser?
    
    // MARK: - Private Properties
    
    private let config = ConfigurationService.shared
    private var webAuthSession: ASWebAuthenticationSession?
    
    // Token storage keys
    private let accessTokenKey = "polar_access_token"
    private let userIDKey = "polar_user_id"
    
    private override init() {
        super.init()
        loadStoredCredentials()
    }
    
    // MARK: - Public Methods
    
    /// Start the OAuth2 authorization flow
    func authorize() async throws {
        guard config.isConfigurationValid else {
            throw PolarAuthError.invalidConfiguration
        }
        
        let state = UUID().uuidString
        
        guard let authURL = config.buildAuthorizationURL(state: state) else {
            throw PolarAuthError.invalidAuthorizationURL
        }
        
        // Perform the web authentication
        let callbackURLScheme = URL(string: config.redirectURI)?.scheme ?? "polarapp"
        
        // Capture state in closure to prevent race conditions if authorize() is called multiple times
        let expectedState = state
        
        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: PolarAuthError.invalidConfiguration)
                    return
                }
                
                self.webAuthSession = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: callbackURLScheme
                ) { [expectedState] callbackURL, error in
                    if let error = error {
                        if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                            continuation.resume(throwing: PolarAuthError.userCancelled)
                        } else {
                            continuation.resume(throwing: PolarAuthError.authenticationFailed(error.localizedDescription))
                        }
                        return
                    }
                    
                    guard let callbackURL = callbackURL,
                          let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                        continuation.resume(throwing: PolarAuthError.invalidResponse)
                        return
                    }
                    
                    // Validate state parameter (CSRF protection)
                    // Uses captured expectedState to prevent race conditions
                    let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value
                    guard returnedState == expectedState else {
                        continuation.resume(throwing: PolarAuthError.stateMismatch)
                        return
                    }
                    
                    // Extract authorization code
                    guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                        continuation.resume(throwing: PolarAuthError.noAuthorizationCode)
                        return
                    }
                    
                    continuation.resume(returning: code)
                }
                
                self.webAuthSession?.presentationContextProvider = self
                self.webAuthSession?.prefersEphemeralWebBrowserSession = false
                self.webAuthSession?.start()
            }
        }
        
        // Exchange authorization code for access token
        try await exchangeCodeForToken(code: code)
    }
    
    /// Exchange authorization code for access token
    private func exchangeCodeForToken(code: String) async throws {
        guard let tokenURL = URL(string: config.tokenURL) else {
            throw PolarAuthError.invalidTokenURL
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Create Basic Auth header
        let credentials = "\(config.clientID):\(config.clientSecret)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw PolarAuthError.invalidConfiguration
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Create request body with proper URL encoding
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI)
        ]
        
        // URLComponents.query automatically percent-encodes the values
        guard let bodyString = components.query else {
            throw PolarAuthError.invalidConfiguration
        }
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolarAuthError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PolarAuthError.tokenExchangeFailed(httpResponse.statusCode, errorMessage)
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        // Store the access token and user ID
        storeCredentials(accessToken: tokenResponse.accessToken, userID: String(tokenResponse.xUserId))
        
        // Register the user with AccessLink
        try await registerUser(accessToken: tokenResponse.accessToken)
        
        await MainActor.run {
            self.isAuthenticated = true
        }
    }
    
    /// Register user with Polar AccessLink
    private func registerUser(accessToken: String) async throws {
        guard let registerURL = URL(string: config.fullURL(for: .users)) else {
            throw PolarAuthError.invalidURL
        }
        
        var request = URLRequest(url: registerURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Empty JSON body for registration
        request.httpBody = "{}".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolarAuthError.invalidResponse
        }
        
        // 200 = New registration, 409 = Already registered (both are OK)
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 409 {
            // Try to decode user info
            if let user = try? JSONDecoder().decode(PolarUser.self, from: data) {
                await MainActor.run {
                    self.currentUser = user
                }
            }
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PolarAuthError.registrationFailed(httpResponse.statusCode, errorMessage)
        }
    }
    
    /// Get current user information
    func getUserInfo() async throws -> PolarUser {
        guard let accessToken = getStoredAccessToken(),
              let userID = getStoredUserID() else {
            throw PolarAuthError.notAuthenticated
        }
        
        let userURL = config.fullURL(for: .users) + "/\(userID)"
        guard let url = URL(string: userURL) else {
            throw PolarAuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PolarAuthError.invalidResponse
        }
        
        let user = try JSONDecoder().decode(PolarUser.self, from: data)
        
        await MainActor.run {
            self.currentUser = user
        }
        
        return user
    }
    
    /// Sign out and delete user registration
    func signOut() async throws {
        guard let accessToken = getStoredAccessToken(),
              let userID = getStoredUserID() else {
            clearCredentials()
            return
        }
        
        // Delete user from AccessLink
        let deleteURL = config.fullURL(for: .users) + "/\(userID)"
        guard let url = URL(string: deleteURL) else {
            clearCredentials()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        _ = try? await URLSession.shared.data(for: request)
        
        clearCredentials()
        
        await MainActor.run {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
    
    // MARK: - Credential Storage
    
    private func storeCredentials(accessToken: String, userID: String) {
        UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        UserDefaults.standard.set(userID, forKey: userIDKey)
    }
    
    func getStoredAccessToken() -> String? {
        return UserDefaults.standard.string(forKey: accessTokenKey)
    }
    
    func getStoredUserID() -> String? {
        return UserDefaults.standard.string(forKey: userIDKey)
    }
    
    private func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: userIDKey)
    }
    
    private func loadStoredCredentials() {
        if getStoredAccessToken() != nil && getStoredUserID() != nil {
            isAuthenticated = true
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension PolarAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - Response Models

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let xUserId: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case xUserId = "x_user_id"
    }
}

struct PolarUser: Codable, Identifiable {
    let polarUserId: String
    let memberId: String?
    let registrationDate: String?
    let firstName: String?
    let lastName: String?
    let birthdate: String?
    let gender: String?
    let weight: Double?
    let height: Double?
    
    var id: String { polarUserId }
    
    enum CodingKeys: String, CodingKey {
        case polarUserId = "polar-user-id"
        case memberId = "member-id"
        case registrationDate = "registration-date"
        case firstName = "first-name"
        case lastName = "last-name"
        case birthdate
        case gender
        case weight
        case height
    }
}

// MARK: - Errors

enum PolarAuthError: LocalizedError {
    case invalidConfiguration
    case invalidAuthorizationURL
    case invalidTokenURL
    case invalidURL
    case userCancelled
    case noAuthorizationCode
    case stateMismatch
    case authenticationFailed(String)
    case tokenExchangeFailed(Int, String)
    case registrationFailed(Int, String)
    case invalidResponse
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "API configuration is invalid. Please check .api-config.plist"
        case .invalidAuthorizationURL:
            return "Could not build authorization URL"
        case .invalidTokenURL:
            return "Invalid token URL"
        case .invalidURL:
            return "Invalid URL"
        case .userCancelled:
            return "Authentication was cancelled"
        case .noAuthorizationCode:
            return "No authorization code received"
        case .stateMismatch:
            return "Security validation failed: state parameter mismatch (possible CSRF attack)"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .tokenExchangeFailed(let code, let message):
            return "Token exchange failed (\(code)): \(message)"
        case .registrationFailed(let code, let message):
            return "User registration failed (\(code)): \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .notAuthenticated:
            return "User is not authenticated"
        }
    }
}

