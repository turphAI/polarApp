//
//  OAuthCallbackHandler.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import Foundation
import Combine
import Security

@MainActor
final class OAuthCallbackHandler: ObservableObject {
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

    // MARK: - Token Storage (Keychain)

    private func saveToken(_ token: String) {
        let data = token.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

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
            return token
        }

        return nil
    }

    private func clearToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey
        ]

        SecItemDelete(query as CFDictionary)
    }

    func signOut() {
        authToken = nil
        authError = nil
        isAuthenticating = false
    }

    var isAuthenticated: Bool {
        authToken != nil
    }
}

