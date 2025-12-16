//
//  HeartRateModels.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import Foundation

// MARK: - Polar User Registration

/// User registration response from Polar API
struct PolarUser: Codable {
    let polarUserId: String
    let memberID: String?
    let registrationDate: String?
    let firstName: String?
    let lastName: String?
    let birthdate: String?
    let gender: String?
    let weight: Double?
    let height: Double?
    
    enum CodingKeys: String, CodingKey {
        case polarUserId = "polar-user-id"
        case memberID = "member-id"
        case registrationDate = "registration-date"
        case firstName = "first-name"
        case lastName = "last-name"
        case birthdate
        case gender
        case weight
        case height
    }
}

// MARK: - Continuous Heart Rate

/// Continuous heart rate data for a day
struct ContinuousHeartRate: Codable {
    let date: String
    let heartRateVariability: HeartRateVariability?
    let samples: [HeartRateSample]?
    
    enum CodingKeys: String, CodingKey {
        case date
        case heartRateVariability = "heart_rate_variability"
        case samples
    }
}

/// Heart rate variability data
struct HeartRateVariability: Codable {
    let hrv: Int?
}

/// Individual heart rate sample
struct HeartRateSample: Codable, Identifiable {
    let id = UUID()
    let sampleTime: String
    let heartRate: Int
    
    enum CodingKeys: String, CodingKey {
        case sampleTime = "sample_time"
        case heartRate = "heart_rate"
    }
}

// MARK: - Daily Activity Summary

/// Daily activity data including heart rate zones
struct DailyActivity: Codable {
    let id: Int?
    let date: String
    let createdAt: String?
    let activeCalories: Int?
    let activeSteps: Int?
    let duration: String?
    let zones: [ActivityZone]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case createdAt = "created-at"
        case activeCalories = "active-calories"
        case activeSteps = "active-steps"
        case duration
        case zones
    }
}

/// Activity zone with heart rate info
struct ActivityZone: Codable {
    let index: Int?
    let inZone: String?  // Duration in zone (ISO 8601)
    let heartRateMin: Int?
    let heartRateMax: Int?
    
    enum CodingKeys: String, CodingKey {
        case index
        case inZone = "in-zone"
        case heartRateMin = "heart-rate-min"
        case heartRateMax = "heart-rate-max"
    }
}

// MARK: - Heart Rate Summary

/// Computed summary of heart rate data for display
struct HeartRateSummary {
    let date: Date
    let high: Int
    let low: Int
    let average: Int
    let samples: [HeartRateSample]
    
    /// Create summary from samples
    static func from(samples: [HeartRateSample], date: Date) -> HeartRateSummary? {
        guard !samples.isEmpty else { return nil }
        
        let heartRates = samples.map { $0.heartRate }
        let high = heartRates.max() ?? 0
        let low = heartRates.min() ?? 0
        let average = heartRates.reduce(0, +) / heartRates.count
        
        return HeartRateSummary(
            date: date,
            high: high,
            low: low,
            average: average,
            samples: samples
        )
    }
}

// MARK: - Available Data Response

/// Response for checking available data
struct AvailableData: Codable {
    let availableData: [DataResource]?
    
    enum CodingKeys: String, CodingKey {
        case availableData = "available-data"
    }
}

struct DataResource: Codable {
    let resourceType: String
    let url: String?
    
    enum CodingKeys: String, CodingKey {
        case resourceType = "resource-type"
        case url
    }
}

