//
//  ioscrmappApp.swift
//  ioscrmapp
//
//  Created by scaler on 2026/3/9.
//

import SwiftUI
import AVFoundation

@main
struct ioscrmappApp: App {
    @StateObject private var sessionStore: SessionStore
    @StateObject private var languageStore: AppLanguageStore
    @StateObject private var themeStore: AppThemeStore
    private let services = AppServices()

    init() {
        _sessionStore = StateObject(wrappedValue: SessionStore())
        _languageStore = StateObject(wrappedValue: AppLanguageStore())
        _themeStore = StateObject(wrappedValue: AppThemeStore())
        
        do {
            // 保留 .mixWithOthers 避免中断其他音频
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default,options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        
        } catch {
            print("音频设置成功")
        }
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environmentObject(languageStore)
                .environmentObject(themeStore)
                .environment(\.locale, languageStore.locale)
                .environment(\.layoutDirection, languageStore.layoutDirection)
                .duTheme(mode: themeStore.currentMode)
                .preferredColorScheme(preferredColorScheme)
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        AppLaunchContainerView(splashAdService: services.splashAdService) {
            ContentView(
                sessionStore: sessionStore,
                authService: services.authService,
                aiChatService: services.aiChatService,
                homeService: services.homeService,
                mallService: services.mallService,
                videoService: services.videoService,
                offersService: services.offersService,
                billingService: services.billingService,
                rechargeService: services.rechargeService,
                ticketsService: services.ticketsService,
                badgeCenterService: services.badgeCenterService,
                meService: services.meService,
                notificationService: services.notificationService,
                authServerURL: services.configuration.mode == .remote ? services.configuration.serverURL : nil
            )
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch themeStore.currentMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
