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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(oauthHandler)
                .onOpenURL { url in
                    oauthHandler.handle(url: url)
                }
        }
    }
}
