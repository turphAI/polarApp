import SwiftUI

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var darkModeEnabled = false
    @State private var healthKitEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                }

                Section("Health Data") {
                    Toggle("Sync with HealthKit", isOn: $healthKitEnabled)

                    NavigationLink {
                        Text("Data Sources")
                    } label: {
                        Label("Data Sources", systemImage: "externaldrive.badge.icloud")
                    }

                    NavigationLink {
                        Text("Privacy Settings")
                    } label: {
                        Label("Privacy", systemImage: "hand.raised.fill")
                    }
                }

                Section("Goals") {
                    NavigationLink {
                        Text("Daily Goals")
                    } label: {
                        Label("Daily Goals", systemImage: "target")
                    }

                    NavigationLink {
                        Text("Reminders")
                    } label: {
                        Label("Reminders", systemImage: "bell.fill")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    NavigationLink {
                        Text("Privacy Policy")
                    } label: {
                        Label("Privacy Policy", systemImage: "doc.text.fill")
                    }

                    NavigationLink {
                        Text("Terms of Service")
                    } label: {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
