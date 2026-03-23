import Foundation

enum BillingTab: String, CaseIterable, Identifiable {
    case summary
    case list

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .summary:
            return "billing.tab.summary"
        case .list:
            return "billing.tab.list"
        }
    }
}

enum BillingInvoiceStatus: Hashable, Sendable {
    case outstanding
    case completed
    case unknown(String)

    init(code: String) {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "O":
            self = .outstanding
        case "C":
            self = .completed
        default:
            self = .unknown(code)
        }
    }

    var titleKey: String {
        switch self {
        case .outstanding:
            return "billing.status.outstanding"
        case .completed:
            return "billing.status.completed"
        case .unknown:
            return "billing.status.unknown"
        }
    }
}

enum BillingPaymentMethod: String, CaseIterable, Identifiable {
    case creditCard
    case applePay
    case samsungPay

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .creditCard:
            return "billing.payment.method.creditCard"
        case .applePay:
            return "billing.payment.method.applePay"
        case .samsungPay:
            return "billing.payment.method.samsungPay"
        }
    }

    var backendValue: String {
        "MobileMoney"
    }
}

struct BillingSummary: Equatable, Sendable {
    let totalDueAmountRaw: String
    let totalDueAmountText: String
    let dueDateText: String
    let unbilledAmountText: String
    let remainingCreditText: String
    let totalUsageText: String
    let totalCreditText: String
    let accountCode: String
}

struct BillingInvoice: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let invoiceId: String
    let invoiceNo: String
    let billCycleID: String
    let currencyId: String
    let invoiceAmountRaw: String
    let openAmountRaw: String
    let taxAmountRaw: String
    let invoiceAmountText: String
    let openAmountText: String
    let taxAmountText: String
    let invoiceDateText: String
    let dueDateText: String
    let billCycleBeginText: String
    let statusCode: String
    let status: BillingInvoiceStatus

    var isPayable: Bool {
        status == .outstanding
    }
}

struct BillingSummarySnapshot: Equatable, Sendable {
    let summary: BillingSummary
    let outstandingInvoices: [BillingInvoice]
}

struct BillingListSnapshot: Equatable, Sendable {
    let invoices: [BillingInvoice]
    let pageIndex: Int?
    let pageSize: Int?
}

struct BillingPaymentRequest: Sendable {
    enum Context: Sendable {
        case summary(oldestInvoice: BillingInvoice)
        case invoice(invoice: BillingInvoice)
    }

    let context: Context
    let amountText: String
    let paymentMethod: BillingPaymentMethod
}

struct BillingPaymentSubmission: Identifiable, Equatable, Sendable {
    enum ReturnTarget: Sendable {
        case summary
        case list
    }

    let id = UUID()
    let orderId: String
    let statusText: String
    let returnTarget: ReturnTarget
}

struct BillingPreviewDocument: Identifiable {
    let id = UUID()
    let url: URL
}

struct BillingVisualBreakdown: Equatable, Sendable {
    let monthlyFeeText: String
    let otherChargesText: String
}
