//
//  DashboardView.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: AuthenticationViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Your heart rate recovery companion")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()

                    // Current Heart Rate Card
                    VStack(spacing: 12) {
                        Text("Current Heart Rate")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("--")
                                .font(.system(size: 48, weight: .bold))

                            Text("bpm")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }

                        Text("Tap to refresh")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    .padding(.horizontal)

                    // Today's Summary (Coming Soon)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Summary")
                            .font(.headline)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("High")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("--")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Low")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("--")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Avg")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("--")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()

                    // Status
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected to Polar")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text("Last sync: Just now")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)

                    Spacer()
                        .frame(height: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    DashboardView(viewModel: AuthenticationViewModel(oauthHandler: OAuthCallbackHandler()))
}

