//
//  ContentView.swift
//  ioscrmapp
//
//  Created by scaler on 2026/3/9.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var sessionStore: SessionStore
    let authService: any AuthServicing
    let meService: any MeServicing

    var body: some View {
        Group {
            if let session = sessionStore.session {
                HomeView(session: session, sessionStore: sessionStore, meService: meService)
            } else {
                AuthLoginContainerView(sessionStore: sessionStore, authService: authService)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: sessionStore.isAuthenticated)
    }
}

struct ContentView_Previews: PreviewProvider {
    private static let previewServices = AppServices(configuration: AppConfig.preview.serviceConfiguration)

    static var previews: some View {
        let languageStore = AppLanguageStore(initialLanguage: .english)

        Group {
            ContentView(
                sessionStore: SessionStore(),
                authService: previewServices.authService,
                meService: previewServices.meService
            )
            .environmentObject(languageStore)
            .previewDisplayName("Login")

            ContentView(
                sessionStore: SessionStore.previewAuthenticated,
                authService: previewServices.authService,
                meService: previewServices.meService
            )
            .environmentObject(languageStore)
            .previewDisplayName("Home")
        }
    }
}
