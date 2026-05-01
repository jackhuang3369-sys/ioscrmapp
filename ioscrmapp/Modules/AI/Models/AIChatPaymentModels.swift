import Foundation

// MARK: - Payment Transaction Type

enum PaymentTransactionType: String, Codable, Sendable, Equatable {
    case recharge = "recharge"
    case subscription = "subscription"
    case billPayment = "bill_payment"
}

// MARK: - Payment Icon Type

enum PaymentIconType: String, Codable, Sendable, Equatable {
    case tabby
    case apple
    case google

    var emoji: String {
        switch self {
        case .tabby: return "💳"
        case .apple: return "🍎"
        case .google: return "🌐"
        }
    }
}

// MARK: - Installment Option

struct InstallmentOption: Codable, Sendable, Equatable {
    let installments: Int
    let amountPerInstallment: Decimal

    enum CodingKeys: String, CodingKey {
        case installments
        case amountPerInstallment = "amount_per_installment"
    }
}

// MARK: - Payment Method Option

struct PaymentMethodOption: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let description: String
    let iconType: PaymentIconType
    let installmentOptions: [InstallmentOption]?
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case iconType = "icon_type"
        case installmentOptions = "installment_options"
        case isDefault = "is_default"
    }
}

// MARK: - Payment Amount Options

struct PaymentAmountOptions: Codable, Sendable, Equatable {
    let min: Decimal
    let max: Decimal
    let defaultAmount: Decimal
    let quickAmounts: [Decimal]
    let currency: String

    enum CodingKeys: String, CodingKey {
        case min
        case max
        case defaultAmount = "default"
        case quickAmounts = "quick_amounts"
        case currency
    }

    func isValidAmount(_ amount: Decimal) -> Bool {
        return amount >= min && amount <= max
    }
}

// MARK: - Payment Subscriber Info

struct PaymentSubscriberInfo: Codable, Sendable, Equatable {
    let serviceNumber: String
    let currentBalance: String?

    enum CodingKeys: String, CodingKey {
        case serviceNumber = "service_number"
        case currentBalance = "current_balance"
    }
}

// MARK: - AI Chat Payment Card

struct AIChatPaymentCard: Codable, Sendable, Equatable {
    let transactionType: PaymentTransactionType
    let amountOptions: PaymentAmountOptions
    let paymentMethods: [PaymentMethodOption]
    let subscriberInfo: PaymentSubscriberInfo?

    enum CodingKeys: String, CodingKey {
        case transactionType = "transaction_type"
        case amountOptions = "amount_options"
        case paymentMethods = "payment_methods"
        case subscriberInfo = "subscriber_info"
    }

    func defaultPaymentMethod() -> PaymentMethodOption? {
        return paymentMethods.first { $0.isDefault } ?? paymentMethods.first
    }
}

// MARK: - Payment Result Status

enum PaymentResultStatus: String, Codable, Sendable, Equatable {
    case success = "success"
    case failed = "failed"
    case pending = "pending"
}

// MARK: - Payment Result Card

struct PaymentResultCard: Codable, Sendable, Equatable {
    let status: PaymentResultStatus
    let orderId: String?
    let amount: Decimal
    let currency: String
    let message: String
    let timestamp: Date?

    enum CodingKeys: String, CodingKey {
        case status
        case orderId = "order_id"
        case amount
        case currency
        case message
        case timestamp
    }
}

// MARK: - Payment Flow State

enum PaymentFlowState: Equatable, Sendable {
    case idle
    case selectingAmount(Decimal)
    case selectingMethod(selectedMethodId: String, amount: Decimal)
    case processing(methodId: String, amount: Decimal)
    case otpRequired(methodId: String, amount: Decimal, maskedAccount: String)
    case success(orderId: String, amount: Decimal)
    case failed(errorMessage: String, amount: Decimal)

    var isProcessing: Bool {
        switch self {
        case .processing, .otpRequired:
            return true
        default:
            return false
        }
    }

    var currentAmount: Decimal? {
        switch self {
        case .selectingAmount(let amount):
            return amount
        case .selectingMethod(_, let amount):
            return amount
        case .processing(_, let amount):
            return amount
        case .otpRequired(_, let amount, _):
            return amount
        case .success(_, let amount):
            return amount
        case .failed(_, let amount):
            return amount
        default:
            return nil
        }
    }
}

// MARK: - Payment Context

struct PaymentContext: Sendable, Equatable {
    let serviceNumber: String
    let accessToken: String
    let languageCode: String
    let subscriberKey: String
}