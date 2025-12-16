//
//  PolarAPIService.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import Foundation

/// Service for fetching data from Polar AccessLink API
class PolarAPIService {
    static let shared = PolarAPIService()
    
    private let config = ConfigurationService.shared
    private let baseURL = "https://www.polaraccesslink.com"
    
    enum APIError: Error, LocalizedError {
        case notAuthenticated
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case httpError(Int, String?)
        case decodingError(Error)
        case userNotRegistered
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Not authenticated. Please sign in."
            case .invalidURL:
                return "Invalid URL"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let code, let message):
                return "HTTP \(code): \(message ?? "Unknown error")"
            case .decodingError(let error):
                return "Failed to parse response: \(error.localizedDescription)"
            case .userNotRegistered:
                return "User not registered with Polar AccessLink"
            }
        }
    }
    
    // MARK: - User Registration
    
    /// Register user with Polar AccessLink (required before fetching data)
    /// This only needs to be done once per user
    func registerUser(token: String, userID: Int) async throws -> PolarUser {
        let url = URL(string: "\(baseURL)/v3/users")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Body contains member-id (your app's identifier for the user)
        let body = ["member-id": "user-\(userID)"]
        request.httpBody = try? JSONEncoder().encode(body)
        
        print("📝 Registering user with Polar AccessLink...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📊 Register Response Status: \(httpResponse.statusCode)")
        
        // 200 = already registered, 201 = newly registered
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("📨 Response: \(responseString)")
            }
            
            let user = try JSONDecoder().decode(PolarUser.self, from: data)
            print("✅ User registered: \(user.polarUserId)")
            return user
        } else if httpResponse.statusCode == 409 {
            // User already registered - this is fine, fetch their info
            print("ℹ️ User already registered")
            // Return a minimal user object
            return PolarUser(
                polarUserId: "\(userID)",
                memberID: "user-\(userID)",
                registrationDate: nil,
                firstName: nil,
                lastName: nil,
                birthdate: nil,
                gender: nil,
                weight: nil,
                height: nil
            )
        } else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.httpError(httpResponse.statusCode, errorMessage)
        }
    }
    
    // MARK: - Continuous Heart Rate
    
    /// Fetch continuous heart rate data for a specific date
    func getContinuousHeartRate(token: String, userID: Int, date: Date) async throws -> ContinuousHeartRate? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let url = URL(string: "\(baseURL)/v3/users/continuous-heart-rate/\(dateString)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("❤️ Fetching heart rate for \(dateString)...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📊 HR Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("📨 HR Data: \(responseString.prefix(200))...")
            }
            
            let hrData = try JSONDecoder().decode(ContinuousHeartRate.self, from: data)
            return hrData
        } else if httpResponse.statusCode == 204 {
            // No data available for this date
            print("ℹ️ No heart rate data for \(dateString)")
            return nil
        } else if httpResponse.statusCode == 401 {
            throw APIError.notAuthenticated
        } else if httpResponse.statusCode == 403 {
            throw APIError.userNotRegistered
        } else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.httpError(httpResponse.statusCode, errorMessage)
        }
    }
    
    // MARK: - Daily Activity
    
    /// Fetch daily activity summary
    func getDailyActivity(token: String, userID: Int, date: Date) async throws -> DailyActivity? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let url = URL(string: "\(baseURL)/v3/users/activity-transactions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("🏃 Fetching activity for \(dateString)...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let activity = try JSONDecoder().decode(DailyActivity.self, from: data)
            return activity
        } else if httpResponse.statusCode == 204 {
            return nil
        } else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.httpError(httpResponse.statusCode, errorMessage)
        }
    }
    
    // MARK: - Available Data
    
    /// Check what data is available for the user
    func getAvailableData(token: String) async throws -> AvailableData {
        let url = URL(string: "\(baseURL)/v3/notifications")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("📋 Checking available data...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📊 Available Data Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("📨 Available: \(responseString)")
            }
            let available = try JSONDecoder().decode(AvailableData.self, from: data)
            return available
        } else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.httpError(httpResponse.statusCode, errorMessage)
        }
    }
    
    // MARK: - Helper: Fetch Heart Rate Summary
    
    /// Convenience method to get heart rate summary for today
    func getTodayHeartRateSummary(token: String, userID: Int) async throws -> HeartRateSummary? {
        let hrData = try await getContinuousHeartRate(token: token, userID: userID, date: Date())
        
        guard let samples = hrData?.samples, !samples.isEmpty else {
            return nil
        }
        
        return HeartRateSummary.from(samples: samples, date: Date())
    }
}

