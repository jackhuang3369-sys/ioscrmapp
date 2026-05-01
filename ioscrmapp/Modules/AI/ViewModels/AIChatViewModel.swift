import Foundation
import SwiftUI

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [AIChatMessage] = []
    @Published var draft = ""
    @Published var isSending = false
    @Published var confirmResetPresented = false
    @Published var currentStep: AIChatViewStep = .home
    @Published var selectedOffer: AIChatOffer?
    @Published var offers: [AIChatOffer] = []
    @Published var isProcessingSubscription = false
    @Published var subscriptionErrorMessage: String?
    @Published var acceptedResult: OfferAcceptedResult?
    @Published var currentPaymentCard: AIChatPaymentCard?

    let language: AppLanguage
    let title: String
    let subtitle: String
    let suggestedPrompts: [String]

    private let custSubInfo: CustSubInfo
    private let aiChatService: any AIChatServicing
    private let offersService: any OffersServicing
    private var conversationID: String?
    private var activeAssistantMessageID: UUID?

    init(
        custSubInfo: CustSubInfo,
        language: AppLanguage,
        aiChatService: any AIChatServicing,
        offersService: (any OffersServicing)? = nil
    ) {
        self.custSubInfo = custSubInfo
        self.language = language
        self.aiChatService = aiChatService
        self.offersService = offersService ?? AppServices().offersService
        title = AIChatLocalizedCopy.title(for: language)
        subtitle = AIChatLocalizedCopy.subtitle(for: language)
        suggestedPrompts = AIChatLocalizedCopy.suggestedPrompts(for: language)
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var currentAssistantMessage: AIChatMessage? {
        if let activeAssistantMessageID {
            return messages.first(where: { $0.id == activeAssistantMessageID })
        }

        return messages.last(where: { $0.sender == .assistant && !$0.isLoading })
    }

    func directNavigationTarget(for text: String) -> AIChatNavigationTarget? {
        let normalized = normalizedIntentText(text)
        guard !normalized.isEmpty else {
            return nil
        }

        let balanceHints = [
            "how can i check my balance",
            "how do i check my balance",
            "check my balance",
            "view my balance",
            "my balance",
            "balance inquiry",
            "查看余额",
            "查余额",
            "余额",
            "الرصيد"
        ]

        if balanceHints.contains(where: { normalized.contains($0) }) {
            return .home
        }

        let rechargeHints = [
            "how do i recharge my account",
            "how can i recharge my account",
            "recharge my account",
            "recharge account",
            "top up my account",
            "top up",
            "充值",
            "充话费",
            "重新充值",
            "اعادة شحن",
            "شحن الحساب"
        ]

        if rechargeHints.contains(where: { normalized.contains($0) }) {
            return .recharge
        }

        return nil
    }

    func sendDraft() {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return
        }

        draft = ""
        send(message)
    }

    func sendSuggestedPrompt(_ prompt: String) {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        send(prompt)
    }

    func requestNewChat() {
        guard !messages.isEmpty || !draft.isEmpty else {
            clearConversation()
            return
        }
        confirmResetPresented = true
    }

    func confirmNewChat() {
        clearConversation()
        confirmResetPresented = false
    }

    private func clearConversation() {
        conversationID = nil
        messages.removeAll()
        draft = ""
        isSending = false
        isProcessingSubscription = false
        currentStep = .home
        selectedOffer = nil
        offers = []
        acceptedResult = nil
        subscriptionErrorMessage = nil
        activeAssistantMessageID = nil
    }

    func selectOffer(_ offer: AIChatOffer) {
        selectedOffer = offer
        acceptedResult = nil
        subscriptionErrorMessage = nil
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = .offerDetails(offer)
        }

        Task {
            try? await notifyOfferEvent(.recommendationSelected, offer: offer)
        }
    }

    func processImmediately() {
        guard !isProcessingSubscription else {
            return
        }

        guard let selectedOffer else {
            subscriptionErrorMessage = missingOfferConfigurationMessage()
            return
        }

        subscriptionErrorMessage = nil
        isProcessingSubscription = true

        Task {
            do {
                _ = try await notifyOfferEvent(.subscriptionRequested, offer: selectedOffer)

                await MainActor.run {
                    acceptedResult = nil
                    isProcessingSubscription = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentStep = .success
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessingSubscription = false
                    subscriptionErrorMessage = errorMessage(for: error)
                }
            }
        }
    }

    func goBack() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            switch currentStep {
            case .success:
                if let offer = selectedOffer {
                    currentStep = .offerDetails(offer)
                } else {
                    currentStep = .offersList
                }
            case .offerDetails:
                currentStep = .offersList
            case .answer:
                currentStep = .home
            case .offersList:
                currentStep = .home
            case .home:
                break
            }
        }
    }

    private func send(_ message: String) {
        guard !isSending else {
            return
        }

        let placeholderID = UUID()
        messages.append(
            AIChatMessage(
                sender: .user,
                text: message
            )
        )
        messages.append(
            AIChatMessage(
                id: placeholderID,
                sender: .assistant,
                text: "",
                isLoading: true
            )
        )
        isSending = true

        Task {
            do {
                let reply = try await aiChatService.sendMessage(
                    message,
                    conversationID: conversationID,
                    context: buildContext()
                )

                await MainActor.run {
                    conversationID = reply.conversationID ?? conversationID
                    applyReplyMetadata(reply)
                    if let paymentCard = reply.paymentCard {
                        currentPaymentCard = paymentCard
                    }
                    updateAssistantPlaceholder(
                        placeholderID: placeholderID,
                        text: resolvedReplyText(reply),
                        htmlContent: reply.htmlContent,
                        richText: reply.richText,
                        thinkingText: reply.thinkingText,
                        recommendedOffers: reply.recommendedOffers,
                        actions: reply.actions
                    )
                }
            } catch let error as AIChatServiceError {
                await MainActor.run {
                    updateAssistantPlaceholder(
                        placeholderID: placeholderID,
                        text: AIChatLocalizedCopy.errorMessage(for: language, error: error),
                        htmlContent: nil,
                        richText: nil,
                        thinkingText: "",
                        recommendedOffers: [],
                        actions: []
                    )
                }
            } catch {
                await MainActor.run {
                    updateAssistantPlaceholder(
                        placeholderID: placeholderID,
                        text: AIChatLocalizedCopy.errorMessage(
                            for: language,
                            error: .network(underlying: error)
                        ),
                        htmlContent: nil,
                        richText: nil,
                        thinkingText: "",
                        recommendedOffers: [],
                        actions: []
                    )
                }
            }
        }
    }

    private func applyReplyMetadata(_ reply: AIChatReply) {
        guard !reply.recommendedOffers.isEmpty else {
            return
        }

        offers = reply.recommendedOffers

        if case .offerDetails(let currentSelection) = currentStep,
           let updatedSelection = reply.recommendedOffers.first(where: { $0.name == currentSelection.name })
        {
            selectedOffer = updatedSelection
            currentStep = .offerDetails(updatedSelection)
            return
        }

        if currentStep == .home || currentStep == .offersList {
            currentStep = .offersList
        }
    }

    private func updateAssistantPlaceholder(
        placeholderID: UUID,
        text: String,
        htmlContent: String?,
        richText: AttributedString?,
        thinkingText: String,
        recommendedOffers: [AIChatOffer],
        actions: [AIChatAction]
    ) {
        guard let index = messages.firstIndex(where: { $0.id == placeholderID }) else {
            isSending = false
            return
        }

        messages[index].text = text
        messages[index].htmlContent = htmlContent
        messages[index].richText = richText
        messages[index].thinkingText = thinkingText
        messages[index].recommendedOffers = recommendedOffers
        messages[index].actions = actions
        messages[index].isLoading = false
        activeAssistantMessageID = placeholderID
        offers = recommendedOffers
        selectedOffer = nil
        acceptedResult = nil
        subscriptionErrorMessage = nil
        isSending = false

        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            currentStep = recommendedOffers.isEmpty ? .answer : .offersList
        }
    }

    private func resolvedReplyText(_ reply: AIChatReply) -> String {
        if !reply.text.isEmpty {
            return reply.text
        }

        if reply.htmlContent != nil || reply.richText != nil || !reply.actions.isEmpty || !reply.recommendedOffers.isEmpty {
            return ""
        }

        return AIChatLocalizedCopy.emptyReply(for: language)
    }

    private func normalizedIntentText(_ text: String) -> String {
        let lowercased = text.lowercased()
        let sanitized = lowercased.replacingOccurrences(
            of: #"[^a-z0-9\u{4e00}-\u{9fff}\u{0600}-\u{06ff}]+"#,
            with: " ",
            options: .regularExpression
        )

        return sanitized
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func buildPaymentContext() -> PaymentContext {
        let tokenStore = KeychainAuthTokenStore()
        let accessToken = tokenStore.loadTokens()?.currentAuthorizationToken() ?? ""
        return PaymentContext(
            serviceNumber: custSubInfo.serviceNumber ?? custSubInfo.phoneNumber,
            accessToken: accessToken,
            languageCode: language.rawValue,
            subscriberKey: custSubInfo.subscriberKey ?? ""
        )
    }

    func handlePaymentResult(_ result: PaymentResultCard) {
        currentPaymentCard = nil

        if result.status == .success {
            let successMessage = paymentSuccessMessage(for: result)
            let resultMessage = AIChatMessage(
                sender: .assistant,
                text: successMessage
            )
            messages.append(resultMessage)
        }
    }

    private func paymentSuccessMessage(for result: PaymentResultCard) -> String {
        switch language {
        case .english:
            let amountText = formatPaymentAmount(result.amount, currency: result.currency)
            if let orderId = result.orderId {
                return "Payment successful! You've recharged \(amountText).\nOrder ID: \(orderId)"
            }
            return "Payment successful! You've recharged \(amountText)."
        case .simplifiedChinese:
            let amountText = formatPaymentAmount(result.amount, currency: result.currency)
            if let orderId = result.orderId {
                return "支付成功！已充值 \(amountText)。\n订单号：\(orderId)"
            }
            return "支付成功！已充值 \(amountText)。"
        case .arabic:
            let amountText = formatPaymentAmount(result.amount, currency: result.currency)
            if let orderId = result.orderId {
                return "تم الدفع بنجاح! تم شحن \(amountText).\nرقم الطلب: \(orderId)"
            }
            return "تم الدفع بنجاح! تم شحن \(amountText)."
        }
    }

    private func formatPaymentAmount(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountString = formatter.string(from: amount as NSNumber) ?? "\(amount)"
        return "\(amountString) \(currency)"
    }

    private func buildContext() -> AIChatContext {
        let tokenStore = KeychainAuthTokenStore()
        let accessToken = tokenStore.loadTokens()?.currentAuthorizationToken() ?? ""
        let serviceNumber = custSubInfo.serviceNumber ?? custSubInfo.phoneNumber

        return AIChatContext(
            accessToken: accessToken,
            authorization: accessToken.isEmpty ? "" : "Bearer \(accessToken)",
            userID: custSubInfo.userID ?? "",
            serviceNumber: serviceNumber,
            subscriberKey: custSubInfo.subscriberKey ?? "",
            languageCode: language.rawValue,
            displayName: custSubInfo.displayName
        )
    }

    private func notifyOfferEvent(
        _ event: AIChatOfferAgentEvent,
        offer: AIChatOffer
    ) async throws -> AIChatReply {
        let context = buildContext()
        let prompt = buildOfferEventPrompt(event: event, offer: offer)
        let metadata = AIChatRequestMetadata.offerEvent(event, offer: offer)

        return try await aiChatService.sendMessage(
            prompt,
            conversationID: nil,
            context: context,
            metadata: metadata
        )
    }

    private func buildOfferEventPrompt(
        event: AIChatOfferAgentEvent,
        offer: AIChatOffer
    ) -> String {
        [
            event.classificationPrompt,
            "event_name: \(event.rawValue)",
            "intent_category: \(event.intentCategory)",
            "source_page: \(event.sourcePage)",
            "offer_name: \(offer.name)",
            "offer_id: \(offer.offerId ?? "")",
            "offer_code: \(offer.offerCode ?? "")",
            "offer_type: \(offer.offerType ?? "")",
            "price: \(offer.price)",
            "currency: \(offer.currency)",
            "unit: \(offer.unit)",
            "data_amount: \(offer.dataAmount)",
            "validity: \(offer.validityRaw ?? offer.validity)"
        ]
        .joined(separator: "\n")
    }

    private func resolveEligibleOffer(from offer: AIChatOffer) async throws -> EligibleOfferItem {
        if let mapped = mappedEligibleOffer(from: offer) {
            return mapped
        }

        let fetchedOffers = try await offersService.fetchEligibleOffers(
            session: custSubInfo,
            resourceType: .all,
            categoryId: nil
        )

        if let matched = fetchedOffers.first(where: { eligibleOffer in
            matches(eligibleOffer, to: offer)
        }) {
            return matched
        }

        throw OffersServiceError.featureUnavailable(message: missingOfferConfigurationMessage())
    }

    private func mappedEligibleOffer(from offer: AIChatOffer) -> EligibleOfferItem? {
        let resolvedOfferId = offer.offerId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !resolvedOfferId.isEmpty else {
            return nil
        }

        let resolvedOfferType = resolvedOfferType(for: offer)

        return EligibleOfferItem(
            id: resolvedOfferId,
            offerId: resolvedOfferId,
            offerCode: offer.offerCode ?? resolvedOfferId,
            offerName: offer.name,
            offerType: resolvedOfferType,
            validityRaw: offer.validityRaw ?? offer.validity,
            validityBucket: validityBucket(for: offer.validityRaw ?? offer.validity),
            resourceSummary: offer.resourceSummary ?? offer.dataAmount,
            displayPriceText: offer.price,
            displayPriceValue: decimalValue(from: offer.price),
            popularRank: nil,
            originalIndex: 0
        )
    }

    private func matches(_ eligibleOffer: EligibleOfferItem, to offer: AIChatOffer) -> Bool {
        let normalizedSelectedOfferName = normalizedOfferName(offer.name)
        let normalizedEligibleOfferName = normalizedOfferName(eligibleOffer.offerName)

        if let offerId = offer.offerId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !offerId.isEmpty,
           eligibleOffer.offerId == offerId
        {
            return true
        }

        if let offerCode = offer.offerCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !offerCode.isEmpty,
           eligibleOffer.offerCode == offerCode
        {
            return true
        }

        guard normalizedSelectedOfferName == normalizedEligibleOfferName else {
            return false
        }

        if let eligiblePrice = eligibleOffer.displayPriceValue,
           let selectedPrice = decimalValue(from: offer.price),
           eligiblePrice != selectedPrice
        {
            return false
        }

        return true
    }

    private func normalizedOfferName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(
                of: #"[^a-z0-9\u{4e00}-\u{9fff}\u{0600}-\u{06ff}]+"#,
                with: "",
                options: .regularExpression
            )
    }

    private func resolvedOfferType(for offer: AIChatOffer) -> String {
        if let offerType = offer.offerType?.trimmingCharacters(in: .whitespacesAndNewlines),
           !offerType.isEmpty
        {
            return offerType
        }

        if offer.dataAmount != "--" {
            return "Data"
        }

        return ""
    }

    private func validityBucket(for rawValue: String?) -> OffersValidityBucket? {
        let normalized = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        if normalized.contains("daily") {
            return .daily
        }
        if normalized.contains("weekly") {
            return .weekly
        }
        if normalized.contains("monthly") {
            return .monthly
        }

        return nil
    }

    private func decimalValue(from rawValue: String?) -> Decimal? {
        guard let rawValue else {
            return nil
        }

        let allowedScalars = CharacterSet(charactersIn: "0123456789.,")
        let normalized = rawValue.unicodeScalars
            .filter { allowedScalars.contains($0) }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: ",", with: "")

        guard !normalized.isEmpty else {
            return nil
        }

        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func missingOfferConfigurationMessage() -> String {
        switch language {
        case .english:
            return "The selected package is missing backend identifiers. Please configure the AI agent to return offerId, offerCode, and offerType."
        case .simplifiedChinese:
            return "当前选中套餐缺少后端标识，请给 AI 智能体返回 `offerId`、`offerCode`、`offerType`。"
        case .arabic:
            return "الحزمة المحددة تفتقد معرّفات الخلفية. يرجى تهيئة الوكيل لإرجاع offerId و offerCode و offerType."
        }
    }

    private func errorMessage(for error: Error) -> String {
        if let aiError = error as? AIChatServiceError {
            return AIChatLocalizedCopy.errorMessage(for: language, error: aiError)
        }

        if let offersError = error as? OffersServiceError {
            switch offersError {
            case let .featureUnavailable(message):
                return message
            case .tooManyRequests:
                switch language {
                case .english:
                    return "Too many requests. Please try again later."
                case .simplifiedChinese:
                    return "请求过于频繁，请稍后重试。"
                case .arabic:
                    return "الطلبات كثيرة جدًا. حاول مرة أخرى لاحقًا."
                }
            case .missingIdentity, .networkUnavailable, .requestCancelled:
                break
            }
        }

        switch language {
        case .english:
            return "Subscription failed. Please try again."
        case .simplifiedChinese:
            return "订阅失败，请稍后重试。"
        case .arabic:
            return "فشل الاشتراك. حاول مرة أخرى."
        }
    }

    var processImmediatelyButtonTitle: String {
        switch (language, isProcessingSubscription) {
        case (.english, true):
            return "Processing..."
        case (.english, false):
            return "Process Immediately"
        case (.simplifiedChinese, true):
            return "办理中..."
        case (.simplifiedChinese, false):
            return "立即办理"
        case (.arabic, true):
            return "جارٍ التنفيذ..."
        case (.arabic, false):
            return "تنفيذ فوري"
        }
    }

    var subscriptionSuccessTitle: String {
        switch language {
        case .english:
            return "Subscription successful"
        case .simplifiedChinese:
            return "订阅成功"
        case .arabic:
            return "تم الاشتراك بنجاح"
        }
    }

    var subscriptionSuccessDetail: String {
        let offerName = acceptedResult?.offerName ?? selectedOffer?.name ?? ""
        let orderId = acceptedResult?.orderId ?? ""

        switch language {
        case .english:
            if orderId.isEmpty {
                return "\(offerName) has been submitted successfully."
            }
            return "\(offerName) has been submitted successfully.\nOrder ID: \(orderId)"
        case .simplifiedChinese:
            if orderId.isEmpty {
                return "\(offerName) 已提交成功。"
            }
            return "\(offerName) 已提交成功。\n订单号：\(orderId)"
        case .arabic:
            if orderId.isEmpty {
                return "تم تقديم \(offerName) بنجاح."
            }
            return "تم تقديم \(offerName) بنجاح.\nرقم الطلب: \(orderId)"
        }
    }
}
