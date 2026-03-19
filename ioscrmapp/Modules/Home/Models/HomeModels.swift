import Foundation

enum HomeDisplayValue {
    static let unavailable: LocalizedTextValue = .literal("-.--")
}

enum HomePaymentType: Equatable, Sendable {
    case prepaid
    case postpaid
    case hybrid
    case unknown(String)

    init(code: String) {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "0":
            self = .prepaid
        case "1":
            self = .postpaid
        case "2":
            self = .hybrid
        default:
            self = .unknown(code)
        }
    }
}

enum HomeNetworkStatus: Equatable, Sendable {
    case fourG
    case fiveG
    case wifi

    var textValue: LocalizedTextValue {
        switch self {
        case .fourG:
            return .key("home.network.4g")
        case .fiveG:
            return .key("home.network.5g")
        case .wifi:
            return .key("home.network.wifi")
        }
    }
}

struct HomePackageName: Equatable, Sendable {
    let defaultName: String
    let arabicName: String?

    func localizedName(for language: AppLanguage) -> String {
        if language == .arabic {
            let fallbackArabic = arabicName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !fallbackArabic.isEmpty {
                return fallbackArabic
            }
        }

        return defaultName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct HomeProfileSection: Equatable, Sendable {
    let displayName: String
    let packageName: HomePackageName?
    let serviceNumber: String
    let networkStatus: HomeNetworkStatus?
}

struct HomeCreditLimitSection: Equatable, Sendable {
    let totalValue: LocalizedTextValue
    let usedValue: LocalizedTextValue
    let remainingValue: LocalizedTextValue
}

struct HomeSummarySection: Equatable, Sendable {
    let paymentType: HomePaymentType
    let balanceValue: LocalizedTextValue
    let currentBillValue: LocalizedTextValue
    let dueDateValue: LocalizedTextValue
    let creditLimit: HomeCreditLimitSection?
    let inlineMessage: LocalizedTextValue?

    var primaryTitleKey: String {
        switch paymentType {
        case .postpaid:
            return "home.header.currentBillTitle"
        case .prepaid, .hybrid, .unknown:
            return "home.header.accountBalanceTitle"
        }
    }

    var primaryValue: LocalizedTextValue {
        switch paymentType {
        case .postpaid:
            return currentBillValue
        case .prepaid, .hybrid, .unknown:
            return balanceValue
        }
    }

    var showsBalanceDetails: Bool {
        switch paymentType {
        case .prepaid, .hybrid, .unknown:
            return true
        case .postpaid:
            return false
        }
    }

    var showsPostpaidDetails: Bool {
        switch paymentType {
        case .postpaid, .hybrid:
            return true
        case .prepaid, .unknown:
            return false
        }
    }
}

struct HomeUsageCard: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case data
        case voice
        case sms
    }

    let kind: Kind
    let value: LocalizedTextValue
    let progress: Double

    var id: String {
        kind.rawValue
    }

    var title: LocalizedTextValue {
        switch kind {
        case .data:
            return .key("home.usage.data.title")
        case .voice:
            return .key("home.usage.voice.title")
        case .sms:
            return .key("home.usage.sms.title")
        }
    }
}

struct HomeUsageSection: Equatable, Sendable {
    let cards: [HomeUsageCard]
    let inlineMessage: LocalizedTextValue?
}

struct HomeDashboardSnapshot: Equatable, Sendable {
    let profile: HomeProfileSection
    let summary: HomeSummarySection
    let usage: HomeUsageSection
}
