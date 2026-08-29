import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    private var heartRateType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .heartRate)
    }

    @Published private(set) var isHealthDataAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    @Published private(set) var authorizationStatus: HKAuthorizationStatus = .notDetermined

    func updateAuthorizationStatus() {
        guard let heartRateType else { return }
        authorizationStatus = healthStore.authorizationStatus(for: heartRateType)
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else { throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Health data not available on this device"]) }
        guard let heartRateType else { throw NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Heart rate type unavailable"]) }

        let toShare: Set<HKSampleType> = [] // heart rate is read-only
        let toRead: Set<HKObjectType> = [heartRateType]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: toShare, read: toRead) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume() }
                else { continuation.resume(throwing: NSError(domain: "HealthKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "Authorization failed"])) }
            }
        }

        updateAuthorizationStatus()
    }
}
