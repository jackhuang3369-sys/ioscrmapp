import Foundation

// MARK: - User Intent Type Enumeration

/// 用户意图类型枚举，覆盖电信业务、支付、行程和通用场景
enum UserIntentType: String, Codable, Sendable, Equatable, CaseIterable {
    // Telecom Business Intents
    case balanceInquiry = "balance_inquiry"
    case dataUsageQuery = "data_usage_query"  // 查询流量/数据使用情况
    case voiceUsageQuery = "voice_usage_query"  // 查询语音通话分钟数/用量
    case smsUsageQuery = "sms_usage_query"  // 查询短信/彩信条数/用量
    case rechargeAccount = "recharge_account"
    case viewOffers = "view_offers"
    case subscribeOffer = "subscribe_offer"
    case viewBill = "view_bill"
    case accountHelp = "account_help"

    // Payment Related Intents
    case makePayment = "make_payment"
    case paymentHistory = "payment_history"
    case paymentStatus = "payment_status"

    // Itinerary Related Intents (保留现有功能)
    case itineraryQuery = "itinerary_query"
    case flightInfo = "flight_info"
    case hotelInfo = "hotel_info"

    // General Intents
    case generalQuestion = "general_question"
    case navigationIntent = "navigation_intent"
    case unknown = "unknown"

    /// 意图类型显示名称（用于 UI）
    func displayName(for language: AppLanguage) -> String {
        switch (self, language) {
        // Telecom Business
        case (.balanceInquiry, .english):
            return "Balance Inquiry"
        case (.balanceInquiry, .simplifiedChinese):
            return "查询余额"
        case (.balanceInquiry, .arabic):
            return "استعلام الرصيد"

        case (.dataUsageQuery, .english):
            return "Data Usage Query"
        case (.dataUsageQuery, .simplifiedChinese):
            return "查询流量"
        case (.dataUsageQuery, .arabic):
            return "استخدام البيانات"

        case (.voiceUsageQuery, .english):
            return "Voice Usage Query"
        case (.voiceUsageQuery, .simplifiedChinese):
            return "查询语音用量"
        case (.voiceUsageQuery, .arabic):
            return "استخدام المكالمات"

        case (.smsUsageQuery, .english):
            return "SMS Usage Query"
        case (.smsUsageQuery, .simplifiedChinese):
            return "查询短信用量"
        case (.smsUsageQuery, .arabic):
            return "استخدام الرسائل"

        case (.rechargeAccount, .english):
            return "Recharge Account"
        case (.rechargeAccount, .simplifiedChinese):
            return "账户充值"
        case (.rechargeAccount, .arabic):
            return "شحن الحساب"

        case (.viewOffers, .english):
            return "View Offers"
        case (.viewOffers, .simplifiedChinese):
            return "查看优惠"
        case (.viewOffers, .arabic):
            return "عرض العروض"

        case (.subscribeOffer, .english):
            return "Subscribe Offer"
        case (.subscribeOffer, .simplifiedChinese):
            return "订阅套餐"
        case (.subscribeOffer, .arabic):
            return "اشتراك عرض"

        case (.viewBill, .english):
            return "View Bill"
        case (.viewBill, .simplifiedChinese):
            return "查看账单"
        case (.viewBill, .arabic):
            return "عرض الفاتورة"

        case (.accountHelp, .english):
            return "Account Help"
        case (.accountHelp, .simplifiedChinese):
            return "账户帮助"
        case (.accountHelp, .arabic):
            return "مساعدة الحساب"

        // Payment
        case (.makePayment, .english):
            return "Make Payment"
        case (.makePayment, .simplifiedChinese):
            return "进行支付"
        case (.makePayment, .arabic):
            return "إجراء الدفع"

        case (.paymentHistory, .english):
            return "Payment History"
        case (.paymentHistory, .simplifiedChinese):
            return "支付历史"
        case (.paymentHistory, .arabic):
            return "تاريخ الدفع"

        case (.paymentStatus, .english):
            return "Payment Status"
        case (.paymentStatus, .simplifiedChinese):
            return "支付状态"
        case (.paymentStatus, .arabic):
            return "حالة الدفع"

        // Itinerary
        case (.itineraryQuery, .english):
            return "Itinerary Query"
        case (.itineraryQuery, .simplifiedChinese):
            return "行程查询"
        case (.itineraryQuery, .arabic):
            return "استعلام الرحلة"

        case (.flightInfo, .english):
            return "Flight Information"
        case (.flightInfo, .simplifiedChinese):
            return "航班信息"
        case (.flightInfo, .arabic):
            return "معلومات الطيران"

        case (.hotelInfo, .english):
            return "Hotel Information"
        case (.hotelInfo, .simplifiedChinese):
            return "酒店信息"
        case (.hotelInfo, .arabic):
            return "معلومات الفندق"

        // General
        case (.generalQuestion, .english):
            return "General Question"
        case (.generalQuestion, .simplifiedChinese):
            return "一般问题"
        case (.generalQuestion, .arabic):
            return "سؤال عام"

        case (.navigationIntent, .english):
            return "Navigation Intent"
        case (.navigationIntent, .simplifiedChinese):
            return "导航意图"
        case (.navigationIntent, .arabic):
            return "قصد التنقل"

        case (.unknown, .english):
            return "Unknown Intent"
        case (.unknown, .simplifiedChinese):
            return "未知意图"
        case (.unknown, .arabic):
            return "قصد غير معروف"
        }
    }

    /// 意图分类提示词（用于 AI 识别）
    var classificationPrompt: String {
        switch self {
        case .balanceInquiry:
            return "Classify user queries about checking account balance, remaining credit, or current balance status."
        case .dataUsageQuery:
            return "Classify user queries about checking data usage, remaining data, data balance, or data consumption status."
        case .voiceUsageQuery:
            return "Classify user queries about checking voice call usage, remaining minutes, call balance, or voice consumption status. CRITICAL: Queries containing '订购/subscribe/buy/purchase/购买/开通/activate' combined with 'voice/语音/minutes' should be classified as subscribe_offer, NOT voice_usage_query."
        case .smsUsageQuery:
            return "Classify user queries about checking SMS/MMS usage, remaining messages, message balance, or sms consumption status. Keywords: sms, text, message, messages, mms."
        case .rechargeAccount:
            return "Classify user queries about topping up account, recharging credit, or adding balance to account."
        case .viewOffers:
            return "Classify user queries about available packages, offers, promotions, or deals."
        case .subscribeOffer:
            return "Classify user queries about subscribing to a specific package, activating an offer, or purchasing a plan. CRITICAL: This includes ANY query expressing intent to BUY/订购/购买/subscribe/activate a package (data, voice, sms, roaming, etc.). Keywords: subscribe, buy, purchase, 订购, 购买, 开通, activate, 套餐, package, plan."
        case .viewBill:
            return "Classify user queries about viewing billing statements, invoice details, or payment history."
        case .accountHelp:
            return "Classify user queries about account settings, profile management, or general account assistance."
        case .makePayment:
            return "Classify user queries about making payments, paying bills, or settling dues."
        case .paymentHistory:
            return "Classify user queries about past payment records, transaction history, or payment receipts."
        case .paymentStatus:
            return "Classify user queries about checking payment status, verifying payment completion, or payment tracking."
        case .itineraryQuery:
            return "Classify user queries about travel itinerary, trip details, or booking information."
        case .flightInfo:
            return "Classify user queries about flight schedules, flight status, or airline details."
        case .hotelInfo:
            return "Classify user queries about hotel bookings, accommodation details, or reservation information."
        case .generalQuestion:
            return "Classify general questions that don't fit specific business categories."
        case .navigationIntent:
            return "Classify user requests to navigate to specific app sections or features."
        case .unknown:
            return "Fallback classification for unrecognizable intents."
        }
    }

    /// 对应的导航目标（可选）
    var defaultNavigationTarget: AIChatNavigationTarget? {
        switch self {
        case .balanceInquiry:
            return .home
        case .dataUsageQuery:
            return .home  // 流量查询显示在首页
        case .voiceUsageQuery:
            return .home  // 语音用量查询显示在首页
        case .smsUsageQuery:
            return .home  // 短信用量查询显示在首页
        case .rechargeAccount:
            return .recharge
        case .viewOffers:
            return .offers
        case .subscribeOffer:
            return .offers
        case .viewBill:
            return .billing
        case .accountHelp:
            return .me
        case .makePayment:
            return .billing
        case .paymentHistory:
            return .billing
        case .paymentStatus:
            return .billing
        case .itineraryQuery, .flightInfo, .hotelInfo:
            return nil // 行程相关意图不直接导航
        case .generalQuestion, .navigationIntent, .unknown:
            return nil // 需要进一步处理
        }
    }
}

// MARK: - Intent Action Type

/// 意图动作类型枚举
enum IntentActionType: String, Codable, Sendable, Equatable {
    case navigate = "navigate"
    case executeBusinessFlow = "execute_business_flow"
    case requestMoreInfo = "request_more_info"
    case showConfirmationDialog = "show_confirmation_dialog"
}

// MARK: - Intent Action

/// 意图动作模型，定义用户可执行的动作
struct IntentAction: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let actionType: IntentActionType
    let parameters: [String: String]

    init(
        id: String = UUID().uuidString,
        title: String,
        actionType: IntentActionType,
        parameters: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.actionType = actionType
        self.parameters = parameters
    }
}

// MARK: - Intent Category

/// 意图分类枚举，用于意图分组和统计
enum IntentCategory: String, Codable, Sendable, Equatable {
    case telecomBusiness = "telecom_business"
    case payment = "payment"
    case itinerary = "itinerary"
    case general = "general"
    case navigation = "navigation"

    /// 意图类型所属分类
    static func category(for intentType: UserIntentType) -> IntentCategory {
        switch intentType {
        case .balanceInquiry, .dataUsageQuery, .voiceUsageQuery, .smsUsageQuery, .rechargeAccount, .viewOffers, .subscribeOffer, .viewBill, .accountHelp:
            return .telecomBusiness
        case .makePayment, .paymentHistory, .paymentStatus:
            return .payment
        case .itineraryQuery, .flightInfo, .hotelInfo:
            return .itinerary
        case .generalQuestion:
            return .general
        case .navigationIntent:
            return .navigation
        case .unknown:
            return .general
        }
    }
}