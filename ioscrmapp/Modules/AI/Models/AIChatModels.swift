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
        case .processing:
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

// MARK: - Itinerary Models

enum ItinerarySegmentType: String, Codable, Sendable {
    case flight, hotel, activity
}

enum ItineraryStatus: String, Codable, Sendable {
    case confirmed, pending, completed, cancelled
}

struct FlightSegment: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let flightNumber: String
    let airline: String
    let airlineCode: String?
    let departureAirport: String
    let departureCity: String
    let arrivalAirport: String
    let arrivalCity: String
    let departureTime: Date
    let arrivalTime: Date
    let durationMinutes: Int?
    let seatNumber: String?
    let terminal: String?
    let gate: String?
    let baggage: String?
    let meal: String?

    enum CodingKeys: String, CodingKey {
        case id, flightNumber, airline, airlineCode
        case departureAirport, departureCity, arrivalAirport, arrivalCity
        case departureTime, arrivalTime, durationMinutes
        case seatNumber, terminal, gate, baggage, meal
    }
}

struct HotelBooking: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let hotelName: String
    let address: String
    let city: String?
    let checkInDate: Date
    let checkOutDate: Date
    let roomType: String
    let guests: Int
    let nights: Int?
    let confirmationNumber: String?

    enum CodingKeys: String, CodingKey {
        case id, hotelName, address, city
        case checkInDate, checkOutDate, roomType, guests, nights
        case confirmationNumber
    }
}

struct ActivityTicket: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let activityName: String
    let venue: String
    let city: String?
    let date: Date
    let time: String
    let ticketCount: Int
    let confirmationNumber: String?

    enum CodingKeys: String, CodingKey {
        case id, activityName, venue, city, date, time
        case ticketCount, confirmationNumber
    }
}

struct AIChatItineraryCard: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let bookingReference: String
    let travelerName: String
    let flightSegments: [FlightSegment]
    let hotelBookings: [HotelBooking]
    let activityTickets: [ActivityTicket]
    let totalPrice: Decimal?
    let currency: String?
    let status: ItineraryStatus
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, bookingReference, travelerName
        case flightSegments, hotelBookings, activityTickets
        case totalPrice, currency, status, createdAt
    }
}

enum AIChatSender: String, Codable, Sendable, Equatable {
    case user
    case assistant
}

enum AIChatViewStep: Equatable {
    case home
    case offersList
    case answer
    case offerDetails(AIChatOffer)
    case success
}

struct BoltInfoLine: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let value: String

    init(id: String = UUID().uuidString, title: String, value: String) {
        self.id = id
        self.title = title
        self.value = value
    }
}

struct BoltInfoCard: Equatable, Sendable {
    let title: String
    let accentValue: String
    let accentCaption: String
    let detailLines: [BoltInfoLine]
    let footnote: String?
}

struct BoltOfferFlowContext: Equatable, Sendable {
    let title: String
    let message: String
    let offers: [AIChatOffer]
    let allowExternalNavigation: Bool
    let isRoaming: Bool
}

struct BoltRechargeFlowContext: Equatable, Sendable {
    let title: String
    let message: String
    let paymentCard: AIChatPaymentCard
    let serviceNumber: String
    let balanceText: String
}

struct BoltBillingFlowContext: Equatable, Sendable {
    let title: String
    let message: String
    let summary: BillingSummarySnapshot
}

struct BoltPaymentFlowContext: Equatable, Sendable {
    let title: String
    let message: String
    let paymentCard: AIChatPaymentCard
    let invoice: BillingInvoice?
    let summary: BillingSummarySnapshot?
}

enum BoltTravelTransportMode: String, Codable, Equatable, Sendable {
    case flight
    case train
}

struct BoltTravelFlowContext: Equatable, Sendable {
    let title: String
    let message: String
    let destination: String?
    let transportMode: BoltTravelTransportMode?
    let departureDateText: String?
    let returnDateText: String?
    let passengerCount: Int?
    let priceRange: BoltTravelPriceRange?
    let followUpQuestion: String?
    let suggestedReplies: [String]
    let ticketPageURL: URL?
    let isResolvingTicketPage: Bool
    let ticketPageErrorMessage: String?
}

struct BoltTravelPriceRange: Equatable, Sendable {
    let min: Double
    let max: Double
    let currency: String
}

struct BoltServiceSubmissionResult: Equatable, Sendable {
    let title: String
    let message: String
    let reference: String?
}

struct BoltServiceFlowContext: Equatable, Sendable {
    let title: String
    let message: String
    let followUpQuestion: String?
    let suggestedReplies: [String]
    let submissionResult: BoltServiceSubmissionResult?
}

/// 多意图选择上下文，用于用户输入包含多个意图时的选择场景
struct BoltMultiIntentSelectionContext: Equatable, Sendable {
    let title: String
    let message: String
    let selectionPrompt: String
    let intentOptions: [BoltIntentOption]
    let originalUserText: String
}

/// 单个意图选项
struct BoltIntentOption: Equatable, Sendable, Identifiable {
    let id = UUID()
    let intentType: String
    let displayName: String
    let description: String?
    let confidence: Double
}

enum BoltUIPrimitiveKind: String, Equatable, Sendable {
    case answerCard
    case listCard
    case detailCard
    case formCard
    case actionGroup
    case paymentCard
    case resultCard
    case followUpCard
}

enum BoltDomainFlow: Equatable, Sendable {
    case offers(BoltOfferFlowContext)
    case roaming(BoltOfferFlowContext)
    case recharge(BoltRechargeFlowContext)
    case billing(BoltBillingFlowContext)
    case payment(BoltPaymentFlowContext)
    case travel(BoltTravelFlowContext)
    case balance(BoltInfoCard)
    case usage(BoltInfoCard)
    case serviceRequest(BoltServiceFlowContext)
    case multiIntentSelection(BoltMultiIntentSelectionContext)

    var assistantText: String {
        switch self {
        case .offers(let context),
             .roaming(let context):
            return context.message
        case .recharge(let context):
            return context.message
        case .billing(let context):
            return context.message
        case .payment(let context):
            return context.message
        case .travel(let context):
            return context.message
        case .balance(let card),
             .usage(let card):
            return card.footnote ?? card.title
        case .serviceRequest(let context):
            return context.message
        case .multiIntentSelection(let context):
            return context.selectionPrompt
        }
    }

    var primitiveKinds: [BoltUIPrimitiveKind] {
        switch self {
        case .offers, .roaming:
            return [.listCard, .detailCard, .actionGroup, .resultCard]
        case .recharge:
            return [.formCard, .paymentCard, .resultCard]
        case .billing:
            return [.detailCard, .listCard]
        case .payment:
            return [.detailCard, .paymentCard, .resultCard]
        case .travel(let context):
            if context.ticketPageURL != nil {
                return [.detailCard, .resultCard]
            }
            if context.followUpQuestion != nil {
                return [.followUpCard, .detailCard]
            }
            return [.detailCard, .actionGroup]
        case .balance, .usage:
            return [.answerCard, .resultCard]
        case .serviceRequest(let context):
            if context.submissionResult == nil {
                return [.followUpCard, .formCard]
            }
            return [.resultCard]
        case .multiIntentSelection:
            return [.actionGroup, .followUpCard]
        }
    }
}

enum AIChatNavigationTarget: String, Equatable, Codable, Sendable {
    case home
    case service
    case mall
    case offers
    case billing
    case recharge
    case tickets
    case me
    case external

    /// 临时存储 external case 关联的 URL
    private static var _externalURL: URL?

    /// 辅助方法：创建带 URL 的 external case
    static func externalURL(_ url: URL) -> AIChatNavigationTarget {
        _externalURL = url
        return .external
    }

    /// 获取关联的 URL（如果存在）
    var associatedURL: URL? {
        if self == .external {
            return AIChatNavigationTarget._externalURL
        }
        return nil
    }
}

struct AIChatOffer: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let price: String
    let dataAmount: String
    let validity: String
    let currency: String
    let unit: String
    let offerId: String?
    let offerCode: String?
    let offerType: String?
    let validityRaw: String?
    let resourceSummary: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        price: String,
        dataAmount: String,
        validity: String,
        currency: String = "AED",
        unit: String = "Month",
        offerId: String? = nil,
        offerCode: String? = nil,
        offerType: String? = nil,
        validityRaw: String? = nil,
        resourceSummary: String? = nil
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.dataAmount = dataAmount
        self.validity = validity
        self.currency = currency
        self.unit = unit
        self.offerId = offerId
        self.offerCode = offerCode
        self.offerType = offerType
        self.validityRaw = validityRaw
        self.resourceSummary = resourceSummary
    }

    var eventPayload: [String: Any] {
        var payload: [String: Any] = [
            "display_id": id,
            "name": name,
            "price": price,
            "currency": currency,
            "unit": unit,
            "data_amount": dataAmount,
            "validity": validityRaw ?? validity
        ]

        if let offerId, !offerId.isEmpty {
            payload["offer_id"] = offerId
        }
        if let offerCode, !offerCode.isEmpty {
            payload["offer_code"] = offerCode
        }
        if let offerType, !offerType.isEmpty {
            payload["offer_type"] = offerType
        }
        if let resourceSummary, !resourceSummary.isEmpty {
            payload["resource_summary"] = resourceSummary
        }

        return payload
    }
}

struct AIChatAction: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let target: AIChatNavigationTarget?
    let rawValue: String?
}

struct AIChatMessage: Identifiable, Equatable {
    let id: UUID
    let sender: AIChatSender
    var text: String
    var htmlContent: String?
    var richText: AttributedString?
    var thinkingText: String
    var recommendedOffers: [AIChatOffer]
    var actions: [AIChatAction]
    let createdAt: Date
    var isLoading: Bool

    init(
        id: UUID = UUID(),
        sender: AIChatSender,
        text: String,
        thinkingText: String = "",
        recommendedOffers: [AIChatOffer] = [],
        actions: [AIChatAction] = [],
        createdAt: Date = Date(),
        isLoading: Bool = false
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        htmlContent = nil
        richText = nil
        self.thinkingText = thinkingText
        self.recommendedOffers = recommendedOffers
        self.actions = actions
        self.createdAt = createdAt
        self.isLoading = isLoading
    }
}

struct AIChatContext: Codable, Sendable, Equatable {
    let accessToken: String
    let authorization: String
    let userID: String
    let serviceNumber: String
    let subscriberKey: String
    let languageCode: String
    let displayName: String
}

enum AIChatOfferAgentEvent: String {
    case recommendationSelected = "offer_recommendation_selected"
    case subscriptionRequested = "offer_subscription_requested"

    var scene: String { "offers_ai_assistant" }

    var intentCategory: String {
        switch self {
        case .recommendationSelected:
            return "package_selection"
        case .subscriptionRequested:
            return "package_subscription"
        }
    }

    var sourcePage: String {
        switch self {
        case .recommendationSelected:
            return "ai_offer_recommendation_list"
        case .subscriptionRequested:
            return "ai_offer_detail_process_immediately"
        }
    }

    var classificationPrompt: String {
        switch self {
        case .recommendationSelected:
            return "You are a telecom offer intent classifier. When the user taps a recommended package card, classify it as package_selection, extract the selected offer identity, and keep the response concise."
        case .subscriptionRequested:
            return "You are a telecom offer subscription assistant. When the user taps Process Immediately, classify it as package_subscription, validate the selected offer payload, and confirm the flow can continue to the real subscription API."
        }
    }
}

struct AIChatRequestMetadata {
    let scene: String
    let eventName: String
    let intentCategory: String
    let classificationPrompt: String
    let sourcePage: String
    let selectedOffer: AIChatOffer?
    let businessParameters: [String: String]

    func serializedVariables() -> [String: Any] {
        var variables: [String: Any] = [
            "interaction_scene": scene,
            "event_name": eventName,
            "intent_category": intentCategory,
            "classification_prompt": classificationPrompt,
            "source_page": sourcePage
        ]

        if let selectedOffer {
            variables["selected_offer"] = selectedOffer.eventPayload
        }

        if !businessParameters.isEmpty {
            variables["business_parameters"] = businessParameters
        }

        return variables
    }

    static func offerEvent(_ event: AIChatOfferAgentEvent, offer: AIChatOffer) -> AIChatRequestMetadata {
        AIChatRequestMetadata(
            scene: event.scene,
            eventName: event.rawValue,
            intentCategory: event.intentCategory,
            classificationPrompt: event.classificationPrompt,
            sourcePage: event.sourcePage,
            selectedOffer: offer,
            businessParameters: [
                "requires_real_subscription_success": "true",
                "success_page_strategy": "show_after_offers_api_success"
            ]
        )
    }
}

struct AIChatReply {
    let conversationID: String?
    let text: String
    let htmlContent: String?
    let richText: AttributedString?
    let thinkingText: String
    let recommendedOffers: [AIChatOffer]
    let actions: [AIChatAction]
    let paymentCard: AIChatPaymentCard?
    let paymentResult: PaymentResultCard?
    let itineraryCard: AIChatItineraryCard?

    init(
        conversationID: String?,
        text: String,
        htmlContent: String? = nil,
        richText: AttributedString? = nil,
        thinkingText: String,
        recommendedOffers: [AIChatOffer] = [],
        actions: [AIChatAction] = [],
        paymentCard: AIChatPaymentCard? = nil,
        paymentResult: PaymentResultCard? = nil,
        itineraryCard: AIChatItineraryCard? = nil
    ) {
        self.conversationID = conversationID
        self.text = text
        self.htmlContent = htmlContent
        self.richText = richText
        self.thinkingText = thinkingText
        self.recommendedOffers = recommendedOffers
        self.actions = actions
        self.paymentCard = paymentCard
        self.paymentResult = paymentResult
        self.itineraryCard = itineraryCard
    }
}

enum AIChatServiceError: Error {
    case missingConfiguration
    case invalidResponse
    case backend(String)
    case network(underlying: Error)
}

enum AIChatLocalizedCopy {
    static func title(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "How may I help\nyou today?"
        case .simplifiedChinese:
            return "我能帮你\n做什么？"
        case .arabic:
            return "كيف يمكنني\nمساعدتك اليوم؟"
        }
    }

    static func subtitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Ask about bills, offers, recharge, or account help."
        case .simplifiedChinese:
            return "可以咨询账单、优惠、充值和账户问题。"
        case .arabic:
            return "يمكنك السؤال عن الفواتير والعروض وإعادة الشحن والحساب."
        }
    }

    static func recommendedTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Recommended Questions"
        case .simplifiedChinese:
            return "推荐问题"
        case .arabic:
            return "أسئلة مقترحة"
        }
    }

    static func inputPlaceholder(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Enter the content you want to consult"
        case .simplifiedChinese:
            return "请输入你想咨询的内容"
        case .arabic:
            return "أدخل المحتوى الذي تريد الاستفسار عنه"
        }
    }

    static func voiceHoldTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Hold to Talk ~"
        case .simplifiedChinese:
            return "按住说话~"
        case .arabic:
            return "اضغط للتحدث ~"
        }
    }

    static func voiceListeningTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Listening..."
        case .simplifiedChinese:
            return "正在聆听..."
        case .arabic:
            return "جارٍ الاستماع..."
        }
    }

    static func voiceEntryTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Voice input"
        case .simplifiedChinese:
            return "语音输入"
        case .arabic:
            return "إدخال صوتي"
        }
    }

    static func keyboardEntryTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Keyboard input"
        case .simplifiedChinese:
            return "键盘输入"
        case .arabic:
            return "إدخال لوحة المفاتيح"
        }
    }

    static func sendButtonTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Send"
        case .simplifiedChinese:
            return "发送"
        case .arabic:
            return "إرسال"
        }
    }

    static func newChatTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "New Chat"
        case .simplifiedChinese:
            return "新对话"
        case .arabic:
            return "محادثة جديدة"
        }
    }

    static func closeTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Close"
        case .simplifiedChinese:
            return "关闭"
        case .arabic:
            return "إغلاق"
        }
    }

    static func thinkingTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Thinking"
        case .simplifiedChinese:
            return "思考过程"
        case .arabic:
            return "التفكير"
        }
    }

    static func loadingTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Generating reply..."
        case .simplifiedChinese:
            return "正在生成回复..."
        case .arabic:
            return "جارٍ إنشاء الرد..."
        }
    }

    static func offersResultTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Here are the recommended package options for you~"
        case .simplifiedChinese:
            return "这里是为你推荐的套餐选项~"
        case .arabic:
            return "هذه هي الباقات المقترحة المناسبة لك~"
        }
    }

    static func questionSectionTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Your Question"
        case .simplifiedChinese:
            return "你的问题"
        case .arabic:
            return "سؤالك"
        }
    }

    static func answerSectionTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Assistant Reply"
        case .simplifiedChinese:
            return "智能体回复"
        case .arabic:
            return "رد المساعد"
        }
    }

    static func suggestedActionsTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Suggested Actions"
        case .simplifiedChinese:
            return "建议操作"
        case .arabic:
            return "إجراءات مقترحة"
        }
    }

    static func continueAskingHint(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "You can continue asking questions, or choose one of the actions below."
        case .simplifiedChinese:
            return "你可以继续提问，或选择下面的操作。"
        case .arabic:
            return "يمكنك متابعة طرح الأسئلة أو اختيار أحد الإجراءات أدناه."
        }
    }

    static func emptyReply(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "I didn't receive a usable reply this time. Please try again."
        case .simplifiedChinese:
            return "这次没有拿到可用回复，请再试一次。"
        case .arabic:
            return "لم أتلقَّ ردًا صالحًا هذه المرة. حاول مرة أخرى."
        }
    }

    static func errorMessage(for language: AppLanguage, error: AIChatServiceError) -> String {
        switch error {
        case .missingConfiguration:
            switch language {
            case .english:
                return "AI assistant configuration is missing."
            case .simplifiedChinese:
                return "AI 助手配置缺失。"
            case .arabic:
                return "إعدادات المساعد الذكي غير مكتملة."
            }
        case .invalidResponse:
            switch language {
            case .english:
                return "The assistant returned an invalid response."
            case .simplifiedChinese:
                return "智能体返回了无效响应。"
            case .arabic:
                return "أعاد المساعد استجابة غير صالحة."
            }
        case let .backend(message):
            return message
        case .network:
            switch language {
            case .english:
                return "Network error. Please check your connection and try again."
            case .simplifiedChinese:
                return "网络异常，请检查连接后重试。"
            case .arabic:
                return "حدث خطأ في الشبكة. تحقق من الاتصال ثم حاول مرة أخرى."
            }
        }
    }

    static func suggestedPrompts(for language: AppLanguage) -> [String] {
        switch language {
        case .english:
            return [
                "How can I check my balance?",
                "What offers are available for me?",
                "How do I recharge my account?",
                "How can I view my bill?"
            ]
        case .simplifiedChinese:
            return [
                "我怎么查看余额？",
                "我有哪些可用优惠？",
                "我怎么给账户充值？",
                "我怎么查看账单？"
            ]
        case .arabic:
            return [
                "كيف أتحقق من الرصيد؟",
                "ما العروض المتاحة لي؟",
                "كيف أعيد شحن الحساب؟",
                "كيف أعرض الفاتورة؟"
            ]
        }
    }

    static func actionTitle(for target: AIChatNavigationTarget, language: AppLanguage) -> String {
        switch (target, language) {
        case (.billing, .english):
            return "Open Billing"
        case (.billing, .simplifiedChinese):
            return "打开账单"
        case (.billing, .arabic):
            return "فتح الفواتير"
        case (.recharge, .english):
            return "Open Recharge"
        case (.recharge, .simplifiedChinese):
            return "打开充值"
        case (.recharge, .arabic):
            return "فتح إعادة الشحن"
        case (.tickets, .english):
            return "Open Tickets"
        case (.tickets, .simplifiedChinese):
            return "打开票务"
        case (.tickets, .arabic):
            return "فتح التذاكر"
        case (.offers, .english):
            return "Open Offers"
        case (.offers, .simplifiedChinese):
            return "打开优惠"
        case (.offers, .arabic):
            return "فتح العروض"
        case (.mall, .english):
            return "Open Mall"
        case (.mall, .simplifiedChinese):
            return "打开商城"
        case (.mall, .arabic):
            return "فتح المتجر"
        case (.home, .english):
            return "Open Home"
        case (.home, .simplifiedChinese):
            return "打开首页"
        case (.home, .arabic):
            return "فتح الرئيسية"
        case (.service, .english):
            return "Open Service"
        case (.service, .simplifiedChinese):
            return "打开服务"
        case (.service, .arabic):
            return "فتح الخدمات"
        case (.me, .english):
            return "Open Me"
        case (.me, .simplifiedChinese):
            return "打开我的"
        case (.me, .arabic):
            return "فتح حسابي"
        case (.external, .english):
            return "Open Link"
        case (.external, .simplifiedChinese):
            return "打开链接"
        case (.external, .arabic):
            return "فتح الرابط"
        }
    }
}
