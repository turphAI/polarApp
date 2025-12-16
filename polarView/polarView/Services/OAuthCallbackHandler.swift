//
//  OAuthCallbackHandler.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import Foundation
import Combine
import Security

/// Credentials returned from Polar OAuth2 flow
struct PolarCredentials: Codable {
    let accessToken: String
    let userID: Int
    let tokenType: String?
    let expiresIn: Int?
}

@MainActor
final class OAuthCallbackHandler: ObservableObject {
    @Published var authToken: String? {
        didSet {
            if authToken != nil {
                saveCredentials()
            } else {
                clearCredentials()
            }
        }
    }
    
    @Published var userID: Int?

    @Published var isAuthenticating = false
    @Published var authError: String?

    private let credentialsKey = "polarViewCredentials"
    private let keychainService = "com.turphai.polarView"

    init() {
        // Try to load existing credentials on startup
        loadCredentials()
    }
    
    /// Set credentials from auth response
    func setCredentials(token: String, userID: Int) {
        self.authToken = token
        self.userID = userID
        print("💾 Credentials stored - User ID: \(userID)")
    }

    /// Handle OAuth callback from deep link
    func handle(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            authError = "Invalid callback URL"
            return
        }

        if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
            authError = "Authorization failed: \(error)"
            return
        }

        // You can parse code/state here if needed and kick off token exchange
    }

    // MARK: - Credentials Storage (Keychain)

    private func saveCredentials() {
        guard let token = authToken, let uid = userID else { return }
        
        let credentials = PolarCredentials(
            accessToken: token,
            userID: uid,
            tokenType: "bearer",
            expiresIn: nil
        )
        
        guard let data = try? JSONEncoder().encode(credentials) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: credentialsKey,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            print("✅ Credentials saved to Keychain")
        }
    }

    private func loadCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: credentialsKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let credentials = try? JSONDecoder().decode(PolarCredentials.self, from: data) {
            self.authToken = credentials.accessToken
            self.userID = credentials.userID
            print("✅ Credentials loaded - User ID: \(credentials.userID)")
        }
    }

    private func clearCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: credentialsKey
        ]

        SecItemDelete(query as CFDictionary)
        userID = nil
        print("🗑️ Credentials cleared")
    }

    func signOut() {
        authToken = nil
        userID = nil
        authError = nil
        isAuthenticating = false
    }

    var isAuthenticated: Bool {
        authToken != nil && userID != nil
    }
}

