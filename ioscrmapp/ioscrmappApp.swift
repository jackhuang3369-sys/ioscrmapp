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
                    homeService: services.homeService,
                    mallService: services.mallService,
                    offersService: services.offersService,
                    billingService: services.billingService,
                    rechargeService: services.rechargeService,
                    meService: services.meService,
                    notificationService: services.notificationService,
                    authServerURL: services.configuration.mode == .remote ? services.configuration.serverURL : nil
                )
            }
            .environmentObject(languageStore)
            .environment(\.locale, languageStore.locale)
            .environment(\.layoutDirection, languageStore.layoutDirection)
        }
    }
}
