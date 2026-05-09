// ioscrmapp/ioscrmapp/Modules/Onboarding/Models/OnboardingModels.swift
import Foundation

/// User's entry intent when opening the app unauthenticated.
/// - onboarding: New user wants to create account
/// - login: Existing user wants to sign in
enum EntryIntent: String, Codable, Equatable, Sendable, CaseIterable {
    case onboarding = "onboarding"
    case login = "login"
}

/// Acquisition path for new users - how they obtain their mobile number.
/// - newNumber: Get a new number from du
/// - portIn: Keep existing number (port-in from another carrier)
enum AcquisitionPath: String, Codable, Equatable, Sendable, CaseIterable {
    case newNumber = "new_number"
    case portIn = "port_in"
}

/// Authentication path for existing users.
/// Currently only UAE Pass is supported for login.
enum AuthPath: String, Codable, Equatable, Sendable, CaseIterable {
    case uaePassLogin = "uae_pass_login"
}

/// Complete entry routing state persisted for downstream consumption.
struct EntryRoutingState: Codable, Equatable, Sendable {
    let entryIntent: EntryIntent
    let acquisitionPath: AcquisitionPath?
    let authPath: AuthPath?
    let createdAt: Date

    init(
        entryIntent: EntryIntent,
        acquisitionPath: AcquisitionPath? = nil,
        authPath: AuthPath? = nil,
        createdAt: Date = Date()
    ) {
        self.entryIntent = entryIntent
        self.acquisitionPath = acquisitionPath
        self.authPath = authPath
        self.createdAt = createdAt
    }

    /// Factory for onboarding entry with acquisition path
    static func onboarding(path: AcquisitionPath) -> EntryRoutingState {
        EntryRoutingState(
            entryIntent: .onboarding,
            acquisitionPath: path,
            authPath: nil
        )
    }

    /// Factory for login entry via UAE Pass
    static func login() -> EntryRoutingState {
        EntryRoutingState(
            entryIntent: .login,
            acquisitionPath: nil,
            authPath: .uaePassLogin
        )
    }
}