//
//  SettingsView.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var showingSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Polar Account")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected")
                                .font(.subheadline)
                        }
                    }

                    Button(role: .destructive) {
                        showingSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "arrow.backward.circle.fill")
                    }
                }

                Section("Heart Rate Thresholds") {
                    HStack {
                        Label("High Threshold", systemImage: "arrow.up")
                        Spacer()
                        Text("--").foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Low Threshold", systemImage: "arrow.down")
                        Spacer()
                        Text("--").foregroundColor(.secondary)
                    }

                    Text("Set your target heart rate range for alerts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Notifications") {
                    Toggle("Enable Alerts", isOn: .constant(true))
                    Toggle("Haptic Feedback", isOn: .constant(true))
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://polar.com/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }

                    Link(destination: URL(string: "https://polar.com/terms")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Sign Out",
                isPresented: $showingSignOutConfirmation,
                actions: {
                    Button("Sign Out", role: .destructive) {
                        viewModel.signOut()
                    }
                    Button("Cancel", role: .cancel) { }
                },
                message: {
                    Text("Are you sure you want to sign out? You'll need to sign in again to access your heart rate data.")
                }
            )
        }
    }
}

#Preview {
    SettingsView(viewModel: AuthenticationViewModel(oauthHandler: OAuthCallbackHandler()))
}

