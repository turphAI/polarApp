import SwiftUI

struct HealthMetricsView: View {
    @State private var selectedMetric: MetricType = .heartRate

    enum MetricType: String, CaseIterable {
        case heartRate = "Heart Rate"
        case steps = "Steps"
        case sleep = "Sleep"
        case activity = "Activity"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Metric Selector
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(MetricType.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Metrics Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Current Value Card
                        VStack(spacing: 12) {
                            Text("Current")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(currentValue(for: selectedMetric))
                                    .font(.system(size: 60, weight: .bold))

                                Text(unit(for: selectedMetric))
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }

                            Text("Last updated: Just now")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)

                        // Chart Placeholder
                        VStack(alignment: .leading, spacing: 12) {
                            Text("7-Day Trend")
                                .font(.headline)

                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .frame(height: 200)

                                Text("Chart visualization coming soon")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Stats Summary
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Statistics")
                                .font(.headline)

                            VStack(spacing: 12) {
                                StatRow(label: "Average", value: averageValue(for: selectedMetric))
                                StatRow(label: "Minimum", value: minValue(for: selectedMetric))
                                StatRow(label: "Maximum", value: maxValue(for: selectedMetric))
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
            }
            .navigationTitle("Health Metrics")
        }
    }

    private func currentValue(for metric: MetricType) -> String {
        switch metric {
        case .heartRate: return "72"
        case .steps: return "8,432"
        case .sleep: return "7.5"
        case .activity: return "450"
        }
    }

    private func unit(for metric: MetricType) -> String {
        switch metric {
        case .heartRate: return "bpm"
        case .steps: return "steps"
        case .sleep: return "hours"
        case .activity: return "cal"
        }
    }

    private func averageValue(for metric: MetricType) -> String {
        switch metric {
        case .heartRate: return "70 bpm"
        case .steps: return "7,850 steps"
        case .sleep: return "7.2 hours"
        case .activity: return "425 cal"
        }
    }

    private func minValue(for metric: MetricType) -> String {
        switch metric {
        case .heartRate: return "58 bpm"
        case .steps: return "5,200 steps"
        case .sleep: return "6.0 hours"
        case .activity: return "300 cal"
        }
    }

    private func maxValue(for metric: MetricType) -> String {
        switch metric {
        case .heartRate: return "95 bpm"
        case .steps: return "12,000 steps"
        case .sleep: return "8.5 hours"
        case .activity: return "650 cal"
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    HealthMetricsView()
}
