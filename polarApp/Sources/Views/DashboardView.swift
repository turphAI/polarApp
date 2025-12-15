import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome to Polar")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Your health monitoring dashboard")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()

                    // Quick Stats
                    VStack(spacing: 16) {
                        HealthStatCard(
                            title: "Heart Rate",
                            value: "72",
                            unit: "bpm",
                            icon: "heart.fill",
                            color: .red
                        )

                        HealthStatCard(
                            title: "Steps Today",
                            value: "8,432",
                            unit: "steps",
                            icon: "figure.walk",
                            color: .blue
                        )

                        HealthStatCard(
                            title: "Sleep",
                            value: "7.5",
                            unit: "hours",
                            icon: "bed.double.fill",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct HealthStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(color)
                .frame(width: 60, height: 60)
                .background(color.opacity(0.2))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    DashboardView()
}
