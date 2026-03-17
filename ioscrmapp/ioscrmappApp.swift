//
//  ioscrmappApp.swift
//  ioscrmapp
//
//  Created by scaler on 2026/3/9.
//

import SwiftUI

@main
struct ioscrmappApp: App {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var languageStore = AppLanguageStore()
    private let services = AppServices()

    var body: some Scene {
        WindowGroup {
            AppLaunchContainerView(splashAdService: services.splashAdService) {
                ContentView(
                    sessionStore: sessionStore,
                    authService: services.authService,
                    meService: services.meService
                )
            }
            .environmentObject(languageStore)
            .environment(\.locale, languageStore.locale)
            .environment(\.layoutDirection, languageStore.layoutDirection)
        }
    }
}
