//
//  polarViewApp.swift
//  polarView
//
//  Created by Tom Murphy on 12/16/25.
//

import SwiftUI

@main
struct PolarApp: App {
    @StateObject private var oauthHandler = OAuthCallbackHandler()
    @StateObject private var healthKit = HealthKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(oauthHandler)
                .environmentObject(healthKit)
                .onOpenURL { url in
                    oauthHandler.handle(url: url)
                }
                .task {
                    healthKit.updateAuthorizationStatus()
                }
        }
    }
}
