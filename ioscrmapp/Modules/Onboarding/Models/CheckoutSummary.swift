import Foundation

/// 套餐结账摘要：由套餐选择流程填充，传入结账页用于展示和支付。
struct CheckoutSummary: Equatable, Sendable {
    let planTitle: String
    let msisdn: String
    let dataText: String        // e.g. "150 GB"
    let voiceText: String       // e.g. "300 mins"
    let billingPeriod: String   // "Monthly" | "Yearly"
    let basePriceAED: Double    // 税前价格
    let totalPriceAED: Double   // 含税总价
    let vatRate: Double         // 0.05 = 5%

    var vatAmountAED: Double { totalPriceAED - basePriceAED }

    var formattedBasePriceAED: String { String(format: "%.2f", basePriceAED) }
    var formattedVATAmountAED: String { String(format: "%.2f", vatAmountAED) }
    var formattedTotalAED: String { String(format: "%.2f", totalPriceAED) }
}
