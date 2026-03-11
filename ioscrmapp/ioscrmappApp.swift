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
    private let services = AppServices()

    var body: some Scene {
        WindowGroup {
            ContentView(
                sessionStore: sessionStore,
                authService: services.authService,
                meService: services.meService
            )
        }
    }
}
