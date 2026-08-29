//
//  LoginView.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @Environment(\.displayScale) var displayScale

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.15, blue: 0.25),
                    Color(red: 0.1, green: 0.2, blue: 0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top spacer
                Spacer()
                    .frame(height: 80)

                // Heart icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .padding(.bottom, 24)

                // Title
                VStack(spacing: 12) {
                    Text("Polar View")
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .foregroundColor(.white)

                    Text("Heart Rate Recovery Companion")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)

                // Description
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Real-time Monitoring")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Track your heart rate throughout the day")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recovery Focused")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Designed for post-ablation monitoring")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Secure Connection")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Safely synced with your Polar watch")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 60)

                Spacer()

                // Error message
                if let error = viewModel.authError {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sign In Failed")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)

                                Text(error)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                // Sign in button
                Button(action: startSignIn) {
                    if viewModel.isAuthenticating {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)

                            Text("Signing In...")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 18))

                            Text("Sign In with Polar")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundColor(.white)
                .background(Color.red)
                .cornerRadius(12)
                .disabled(viewModel.isAuthenticating)
                .opacity(viewModel.isAuthenticating ? 0.8 : 1.0)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // Privacy notice
                VStack(spacing: 8) {
                    Text("By signing in, you agree to")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))

                    HStack(spacing: 16) {
                        Link("Privacy Policy", destination: URL(string: "https://polar.com/privacy")!)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)

                        Divider()
                            .frame(height: 12)

                        Link("Terms of Service", destination: URL(string: "https://polar.com/terms")!)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func startSignIn() {
        // Get the current window scene for presentation anchor
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            viewModel.authError = "Unable to present sign in"
            return
        }

        viewModel.signIn(presentationAnchor: window)
    }
}

#Preview {
    LoginView(viewModel: AuthenticationViewModel(oauthHandler: OAuthCallbackHandler()))
}

