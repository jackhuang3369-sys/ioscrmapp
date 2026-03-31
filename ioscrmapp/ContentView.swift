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
    let aiChatService: any AIChatServicing
    let homeService: any HomeServicing
    let mallService: any MallServicing
    let videoService: any VideoServicing
    let offersService: any OffersServicing
    let billingService: any BillingServicing
    let rechargeService: any RechargeServicing
    let ticketsService: any TicketsServicing
    let badgeCenterService: any BadgeCenterServicing
    let meService: any MeServicing
    let notificationService: any NotificationServicing
    let authServerURL: URL?

    var body: some View {
        Group {
            if authServerURL != nil && (sessionStore.isRestoringAuthentication || sessionStore.shouldRestoreAuthenticationOnLaunch) {
                ProgressView()
            } else if let custSubInfo = sessionStore.authenticatedCustSubInfo {
                HomeView(
                    custSubInfo: custSubInfo,
                    sessionStore: sessionStore,
                    authService: authService,
                    aiChatService: aiChatService,
                    homeService: homeService,
                    mallService: mallService,
                    videoService: videoService,
                    offersService: offersService,
                    billingService: billingService,
                    rechargeService: rechargeService,
                    ticketsService: ticketsService,
                    badgeCenterService: badgeCenterService,
                    meService: meService,
                    notificationService: notificationService
                )
            } else {
                AuthLoginContainerView(sessionStore: sessionStore, authService: authService)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: sessionStore.isAuthenticated)
        .task {
            await sessionStore.restoreAuthenticationIfNeeded(baseURL: authServerURL)
        }
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
                aiChatService: previewServices.aiChatService,
                homeService: previewServices.homeService,
                mallService: previewServices.mallService,
                videoService: previewServices.videoService,
                offersService: previewServices.offersService,
                billingService: previewServices.billingService,
                rechargeService: previewServices.rechargeService,
                ticketsService: previewServices.ticketsService,
                badgeCenterService: previewServices.badgeCenterService,
                meService: previewServices.meService,
                notificationService: previewServices.notificationService,
                authServerURL: previewServices.configuration.mode == .remote ? previewServices.configuration.serverURL : nil
            )
            .environmentObject(languageStore)
            .previewDisplayName("Login")

            ContentView(
                sessionStore: SessionStore.previewAuthenticated,
                authService: previewServices.authService,
                aiChatService: previewServices.aiChatService,
                homeService: previewServices.homeService,
                mallService: previewServices.mallService,
                videoService: previewServices.videoService,
                offersService: previewServices.offersService,
                billingService: previewServices.billingService,
                rechargeService: previewServices.rechargeService,
                ticketsService: previewServices.ticketsService,
                badgeCenterService: previewServices.badgeCenterService,
                meService: previewServices.meService,
                notificationService: previewServices.notificationService,
                authServerURL: previewServices.configuration.mode == .remote ? previewServices.configuration.serverURL : nil
            )
            .environmentObject(languageStore)
            .previewDisplayName("Home")
        }
    }
}
