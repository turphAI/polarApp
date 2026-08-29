//
//  AuthenticationViewModel.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import Foundation
import AuthenticationServices

class AuthenticationViewModel: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var authError: String?
    @Published var authToken: String?
    @Published var userID: Int?

    private let authService = PolarAuthService.shared
    private let oauthHandler: OAuthCallbackHandler

    init(oauthHandler: OAuthCallbackHandler) {
        self.oauthHandler = oauthHandler
        super.init()

        // Sync with OAuth handler state
        self.isAuthenticated = oauthHandler.isAuthenticated
        self.authToken = oauthHandler.authToken
        self.userID = oauthHandler.userID

        // Observe changes from OAuth handler
        oauthHandler.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async {
                    self?.isAuthenticated = oauthHandler.isAuthenticated
                    self?.authToken = oauthHandler.authToken
                    self?.userID = oauthHandler.userID
                    self?.authError = oauthHandler.authError
                    self?.isAuthenticating = oauthHandler.isAuthenticating
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Authentication Methods

    /// Initiates sign in with Polar Flow
    func signIn(presentationAnchor: ASPresentationAnchor) {
        isAuthenticating = true
        authError = nil

        authService.authorize(presentationAnchor: presentationAnchor) { [weak self] result in
            DispatchQueue.main.async {
                self?.isAuthenticating = false

                switch result {
                case .success(let authResult):
                    print("✅ Authentication successful")
                    self?.authToken = authResult.accessToken
                    self?.userID = authResult.userID
                    self?.oauthHandler.setCredentials(token: authResult.accessToken, userID: authResult.userID)
                    self?.isAuthenticated = true

                case .failure(let error):
                    let errorMessage = self?.errorMessage(for: error) ?? "Unknown error"
                    self?.authError = errorMessage
                    print("❌ Authentication failed: \(errorMessage)")
                }
            }
        }
    }

    /// Sign out
    func signOut() {
        oauthHandler.signOut()
        isAuthenticated = false
        authToken = nil
        authError = nil
        print("👋 Signed out")
    }

    // MARK: - Helper Methods

    private func errorMessage(for error: PolarAuthService.PolarAuthError) -> String {
        switch error {
        case .invalidURL:
            return "Invalid authorization URL"
        case .stateMismatch:
            return "Security validation failed. Please try again."
        case .noAuthorizationCode:
            return "Failed to get authorization code"
        case .tokenExchangeFailed:
            return "Token exchange failed. Please try again."
        case .invalidResponse:
            return "Invalid server response"
        case .missingUserID:
            return "User ID not received from Polar"
        }
    }
}

// MARK: - Combine Integration

import Combine

extension AuthenticationViewModel {
    var authTokenPublisher: AnyPublisher<String?, Never> {
        $authToken.eraseToAnyPublisher()
    }

    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> {
        $isAuthenticated.eraseToAnyPublisher()
    }
}

