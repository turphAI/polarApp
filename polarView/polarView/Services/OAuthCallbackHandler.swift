//
//  OAuthCallbackHandler.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import Foundation

/// Handles OAuth2 callback deep links and manages token storage
class OAuthCallbackHandler: ObservableObject {
    @Published var authToken: String? {
        didSet {
            if let token = authToken {
                saveToken(token)
            } else {
                clearToken()
            }
        }
    }

    @Published var isAuthenticating = false
    @Published var authError: String?

    private let tokenKey = "polarViewAuthToken"
    private let keychainService = "com.turphai.polarView"

    init() {
        // Try to load existing token on startup
        authToken = loadToken()
    }

    /// Handle OAuth callback from deep link
    func handle(url: URL) {
        print("🔗 Deep link received: \(url)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            authError = "Invalid callback URL"
            return
        }

        // Check for error response
        if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
            authError = "Authorization failed: \(error)"
            print("❌ OAuth error: \(error)")
            return
        }

        // Note: The actual token exchange happens in PolarAuthService
        // This handler is here for future enhanced deep link handling
        print("✅ Callback processed successfully")
    }

    // MARK: - Token Storage (Keychain)

    /// Save token to Keychain
    private func saveToken(_ token: String) {
        let data = token.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]

        // Delete existing token first
        SecItemDelete(query as CFDictionary)

        // Add new token
        SecItemAdd(query as CFDictionary, nil)
        print("✅ Token saved to Keychain")
    }

    /// Load token from Keychain
    private func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            print("✅ Token loaded from Keychain")
            return token
        }

        return nil
    }

    /// Clear token from Keychain
    private func clearToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey
        ]

        SecItemDelete(query as CFDictionary)
        print("✅ Token cleared from Keychain")
    }

    /// Sign out and clear authentication
    func signOut() {
        authToken = nil
        authError = nil
        isAuthenticating = false
        print("👋 User signed out")
    }

    /// Check if user is authenticated
    var isAuthenticated: Bool {
        authToken != nil
    }
}

