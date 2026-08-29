//
//  DashboardView.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var noDataAvailable = false  // True when API returns no data (not an error)
    @State private var heartRateSummary: HeartRateSummary?
    @State private var lastHeartRate: Int?
    @State private var lastSyncTime: Date?
    @State private var isUserRegistered = false
    
    private let apiService = PolarAPIService.shared

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
                    
                    // Info/Error Banner
                    if noDataAvailable {
                        // No data available - informational message
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("No heart rate data yet")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Text("Sync your Polar watch with the Polar Flow app to see your heart rate data here.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    } else if let error = errorMessage {
                        // Actual error
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                            Spacer()
                            Button("Retry") {
                                Task { await fetchHeartRateData() }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }

                    // Current Heart Rate Card
                    Button(action: {
                        Task { await fetchHeartRateData() }
                    }) {
                        VStack(spacing: 12) {
                            Text("Latest Heart Rate")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            if isLoading {
                                ProgressView()
                                    .frame(height: 48)
                            } else {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(lastHeartRate != nil ? "\(lastHeartRate!)" : "--")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(heartRateColor)

                                    Text("bpm")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Text(isLoading ? "Loading..." : "Tap to refresh")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Today's Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Summary")
                            .font(.headline)

                        HStack(spacing: 12) {
                            SummaryCard(
                                title: "High",
                                value: heartRateSummary?.high,
                                color: .red
                            )
                            
                            SummaryCard(
                                title: "Low",
                                value: heartRateSummary?.low,
                                color: .blue
                            )
                            
                            SummaryCard(
                                title: "Avg",
                                value: heartRateSummary?.average,
                                color: .green
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()

                    // Status
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: isUserRegistered ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundColor(isUserRegistered ? .green : .orange)
                            Text(isUserRegistered ? "Connected to Polar" : "Connecting...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if let syncTime = lastSyncTime {
                            Text("Last sync: \(syncTime, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not synced yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(isUserRegistered ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)

                    Spacer()
                        .frame(height: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await fetchHeartRateData()
            }
            .task {
                await setupAndFetchData()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var heartRateColor: Color {
        guard let hr = lastHeartRate else { return .primary }
        if hr < 60 { return .blue }
        if hr > 100 { return .red }
        return .green
    }
    
    // MARK: - Data Fetching
    
    private func setupAndFetchData() async {
        guard let token = viewModel.authToken,
              let userID = viewModel.userID else {
            errorMessage = "Not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Step 1: Register user (if not already done)
        do {
            _ = try await apiService.registerUser(token: token, userID: userID)
            isUserRegistered = true
        } catch PolarAPIService.APIError.httpError(409, _) {
            // Already registered - this is fine
            isUserRegistered = true
        } catch {
            print("⚠️ User registration failed: \(error)")
            // Continue anyway - user might already be registered
            isUserRegistered = true
        }
        
        // Step 2: Check what data is available (debug)
        await checkAvailableData()
        
        // Step 3: Fetch heart rate data (try today and last few days)
        await fetchHeartRateData()
    }
    
    /// Debug function to check what data is available via the API
    private func checkAvailableData() async {
        guard let token = viewModel.authToken,
              let userID = viewModel.userID else { return }
        
        print("\n" + String(repeating: "=", count: 50))
        print("🔍 CHECKING AVAILABLE DATA")
        print(String(repeating: "=", count: 50))
        
        // Check notifications/available data
        do {
            let available = try await apiService.getAvailableData(token: token)
            if let resources = available.availableData {
                print("📦 Available resources: \(resources.count)")
                for resource in resources {
                    print("   - \(resource.resourceType): \(resource.url ?? "no url")")
                }
            } else {
                print("📭 No pending data notifications")
            }
        } catch {
            print("⚠️ Could not check available data: \(error)")
        }
        
        // Try fetching heart rate for the last 7 days to find any data
        print("\n🔍 Checking heart rate data for last 7 days...")
        let calendar = Calendar.current
        
        for daysAgo in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateStr = formatter.string(from: date)
            
            do {
                let hrData = try await apiService.getContinuousHeartRate(token: token, userID: userID, date: date)
                if let samples = hrData?.samples, !samples.isEmpty {
                    print("✅ \(dateStr): Found \(samples.count) heart rate samples!")
                    if let first = samples.first, let last = samples.last {
                        print("   First: \(first.heartRate) bpm at \(first.sampleTime)")
                        print("   Last: \(last.heartRate) bpm at \(last.sampleTime)")
                    }
                } else {
                    print("📭 \(dateStr): No data")
                }
            } catch {
                print("📭 \(dateStr): No data")
            }
        }
        
        print(String(repeating: "=", count: 50) + "\n")
    }
    
    private func fetchHeartRateData() async {
        guard let token = viewModel.authToken,
              let userID = viewModel.userID else {
            errorMessage = "Not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        noDataAvailable = false
        
        do {
            let summary = try await apiService.getTodayHeartRateSummary(token: token, userID: userID)
            
            await MainActor.run {
                self.heartRateSummary = summary
                self.lastHeartRate = summary?.samples.last?.heartRate
                self.lastSyncTime = Date()
                self.isLoading = false
                self.noDataAvailable = (summary == nil)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Failed to fetch heart rate: \(error)")
        }
    }
}

// MARK: - Summary Card Component

struct SummaryCard: View {
    let title: String
    let value: Int?
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let value = value {
                Text("\(value)")
                    .font(.headline)
                    .foregroundColor(color)
            } else {
                Text("--")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    DashboardView(viewModel: AuthenticationViewModel(oauthHandler: OAuthCallbackHandler()))
}

