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

/// Number inventory category returned by the Journey 03 inventory API.
enum NumberCategory: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case standard = "standard"
    case premium = "premium"

    var id: String { rawValue }
}

/// Commercial tier for Premium Numbers. Pricing is mocked until inventory pricing is finalized.
enum PremiumNumberTier: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case royal = "royal"
    case elite = "elite"
    case gold = "gold"
    case platinum = "platinum"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .royal:
            return "Royal"
        case .elite:
            return "Elite"
        case .gold:
            return "Gold"
        case .platinum:
            return "Platinum"
        }
    }
}

/// Reservation status used by the number inventory and lock-status APIs.
enum NumberReservationStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case available
    case reserved
    case lockedByMe
    case sold
    case expired
}

/// A number row returned by inventory/search endpoints.
struct NumberInventoryItem: Identifiable, Codable, Equatable, Sendable {
    let msisdn: String
    let category: NumberCategory
    let premiumTier: PremiumNumberTier?
    let vanityScore: Int
    let price: Decimal
    let currency: String
    let reservationStatus: NumberReservationStatus

    var id: String { msisdn }

    var isFree: Bool {
        price == 0
    }
}

/// Paged inventory response. The current mock uses this shape to mirror future backend paging.
struct NumberInventoryPage: Codable, Equatable, Sendable {
    let items: [NumberInventoryItem]
    let nextPage: Int?
}

/// Journey 03 output consumed by plan selection, order summary, payment, and activation.
struct NumberSelection: Codable, Equatable, Sendable {
    let numberType: NumberCategory
    let selectedMsisdn: String
    let premiumTier: PremiumNumberTier?
    let premiumFee: Decimal
    let lockId: String
    let portInProvider: String?
    let portInAuthorizationStatus: String?
    let createdAt: Date

    init(
        numberType: NumberCategory,
        selectedMsisdn: String,
        premiumTier: PremiumNumberTier? = nil,
        premiumFee: Decimal = 0,
        lockId: String,
        portInProvider: String? = nil,
        portInAuthorizationStatus: String? = nil,
        createdAt: Date = Date()
    ) {
        self.numberType = numberType
        self.selectedMsisdn = selectedMsisdn
        self.premiumTier = premiumTier
        self.premiumFee = premiumFee
        self.lockId = lockId
        self.portInProvider = portInProvider
        self.portInAuthorizationStatus = portInAuthorizationStatus
        self.createdAt = createdAt
    }
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
