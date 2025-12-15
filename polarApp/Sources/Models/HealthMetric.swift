import Foundation

struct HealthMetric: Identifiable, Codable {
    let id: UUID
    let type: MetricType
    let value: Double
    let unit: String
    let timestamp: Date

    enum MetricType: String, Codable {
        case heartRate
        case steps
        case sleep
        case calories
        case weight
        case bloodPressure
    }

    init(
        id: UUID = UUID(),
        type: MetricType,
        value: Double,
        unit: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
    }
}
