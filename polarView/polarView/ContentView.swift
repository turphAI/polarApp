//
//  ContentView.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var oauthHandler: OAuthCallbackHandler
    @StateObject private var authViewModel: AuthenticationViewModel

    init() {
        let oauthHandler = OAuthCallbackHandler()
        _authViewModel = StateObject(wrappedValue: AuthenticationViewModel(oauthHandler: oauthHandler))
    }

    var body: some View {
        if authViewModel.isAuthenticated {
            // Show main app
            DashboardContainerView(viewModel: authViewModel)
        } else {
            // Show login screen
            LoginView(viewModel: authViewModel)
        }
    }
}

// MARK: - Dashboard Container View

struct DashboardContainerView: View {
    @ObservedObject var viewModel: AuthenticationViewModel

    var body: some View {
        TabView {
            DashboardView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square.fill")
                }

            HealthMetricsView()
                .tabItem {
                    Label("Metrics", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(OAuthCallbackHandler())
}
