//
//  PolarAuthService.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import Foundation
import AuthenticationServices

class PolarAuthService: NSObject {
    static let shared = PolarAuthService()

    private let config = ConfigurationService.shared
    
    enum PolarAuthError: Error {
        case invalidURL
        case stateMismatch
        case noAuthorizationCode
        case tokenExchangeFailed
        case invalidResponse
    }

    // MARK: - OAuth2 Flow

    /// Initiates OAuth2 authorization flow
    func authorize(presentationAnchor: ASPresentationAnchor, completion: @escaping (Result<String, PolarAuthError>) -> Void) {
        guard let authURL = config.buildAuthorizationURL(state: UUID().uuidString) else {
            completion(.failure(.invalidURL))
            return
        }

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
    private func exchangeCodeForToken(code: String, completion: @escaping (Result<String, PolarAuthError>) -> Void) {
        guard let tokenURL = URL(string: config.tokenURL) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Use URLComponents to properly URL-encode form parameters
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "client_secret", value: config.clientSecret),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI)
        ]

        // Encode as form data
        if let query = components.percentEncodedQuery {
            request.httpBody = query.data(using: .utf8)
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Token exchange error: \(error.localizedDescription)")
                completion(.failure(.tokenExchangeFailed))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let accessToken = json?["access_token"] as? String {
                    completion(.success(accessToken))
                } else {
                    completion(.failure(.invalidResponse))
                }
            } catch {
                print("JSON parsing error: \(error.localizedDescription)")
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

