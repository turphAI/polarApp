//
//  PolarAuthService.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import Foundation
import AuthenticationServices

/// Result of successful authentication
struct AuthResult {
    let accessToken: String
    let userID: Int
}

class PolarAuthService: NSObject {
    static let shared = PolarAuthService()

    private let config = ConfigurationService.shared
    
    enum PolarAuthError: Error {
        case invalidURL
        case stateMismatch
        case noAuthorizationCode
        case tokenExchangeFailed
        case invalidResponse
        case missingUserID
    }

    // MARK: - OAuth2 Flow

    /// Initiates OAuth2 authorization flow
    func authorize(presentationAnchor: ASPresentationAnchor, completion: @escaping (Result<AuthResult, PolarAuthError>) -> Void) {
        guard let authURL = config.buildAuthorizationURL(state: UUID().uuidString) else {
            completion(.failure(.invalidURL))
            return
        }

        // Debug logging
        print("🔐 OAuth2 Authorization URL: \(authURL.absoluteString)")
        print("📋 Client ID: \(config.clientID)")
        print("🔄 Redirect URI: \(config.redirectURI)")
        print("🎯 Scopes: \(config.scopes)")

        // Capture state in closure to prevent race conditions
        let expectedState = authURL.queryParameters?["state"] ?? ""

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "polarapp"
        ) { [weak self, expectedState] callbackURL, error in
            guard let self = self else { return }

            if let error = error {
                print("Authentication error: \(error.localizedDescription)")
                completion(.failure(.tokenExchangeFailed))
                return
            }

            guard let callbackURL = callbackURL else {
                completion(.failure(.noAuthorizationCode))
                return
            }

            // Extract authorization code and state
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                  let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value else {
                completion(.failure(.noAuthorizationCode))
                return
            }

            // Validate state to prevent CSRF attacks
            guard returnedState == expectedState else {
                print("⚠️ State mismatch! Potential CSRF attack detected.")
                completion(.failure(.stateMismatch))
                return
            }

            // Exchange code for token
            self.exchangeCodeForToken(code: code, completion: completion)
        }

        session.presentationContextProvider = self
        session.start()
    }

    /// Exchanges authorization code for access token
    private func exchangeCodeForToken(code: String, completion: @escaping (Result<AuthResult, PolarAuthError>) -> Void) {
        guard let tokenURL = URL(string: config.tokenURL) else {
            completion(.failure(.invalidURL))
            return
        }

        print("🔄 Token Exchange Starting...")
        print("📍 Token URL: \(config.tokenURL)")
        print("📝 Authorization Code: \(code.prefix(10))...")

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Polar AccessLink requires Basic Authentication for token exchange
        let credentials = "\(config.clientID):\(config.clientSecret)"
        if let credentialsData = credentials.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            print("🔑 Using Basic Auth")
        }

        // Body only needs grant_type, code, and redirect_uri
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI)
        ]

        // Encode as form data
        if let query = components.percentEncodedQuery {
            request.httpBody = query.data(using: .utf8)
            print("📦 Request Body: \(query)")
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Token exchange network error: \(error.localizedDescription)")
                completion(.failure(.tokenExchangeFailed))
                return
            }

            // Log HTTP response status
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Token Response Status: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                print("❌ No data received from token endpoint")
                completion(.failure(.invalidResponse))
                return
            }

            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📨 Token Response: \(responseString)")
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Check for error response
                if let errorMsg = json?["error"] as? String {
                    print("❌ OAuth Error: \(errorMsg)")
                    if let errorDescription = json?["error_description"] as? String {
                        print("   Description: \(errorDescription)")
                    }
                    completion(.failure(.tokenExchangeFailed))
                    return
                }
                
                if let accessToken = json?["access_token"] as? String,
                   let userID = json?["x_user_id"] as? Int {
                    print("✅ Access token received!")
                    print("👤 User ID: \(userID)")
                    let result = AuthResult(accessToken: accessToken, userID: userID)
                    completion(.success(result))
                } else if json?["access_token"] != nil {
                    print("❌ No x_user_id in response")
                    completion(.failure(.missingUserID))
                } else {
                    print("❌ No access_token in response")
                    completion(.failure(.invalidResponse))
                }
            } catch {
                print("❌ JSON parsing error: \(error.localizedDescription)")
                completion(.failure(.invalidResponse))
            }
        }

        task.resume()
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension PolarAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let window = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return ASPresentationAnchor()
        }
        return window.windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - Helper Extension

extension URL {
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            return nil
        }
        var parameters = [String: String]()
        for item in queryItems {
            parameters[item.name] = item.value
        }
        return parameters
    }
}

