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
    @Published var currentItineraryCard: AIChatItineraryCard?
    @Published var activeDomainFlow: BoltDomainFlow?
    @Published var selectedBillingInvoice: BillingInvoice?

    // Intent Recognition State
    @Published var pendingIntentResult: IntentRecognitionResult?
    @Published var isRecognizingIntent = false
    @Published var intentConfirmationPresented = false

    let language: AppLanguage
    let title: String
    let subtitle: String
    let suggestedPrompts: [String]

    private let custSubInfo: CustSubInfo
    private let aiChatService: any AIChatServicing
    private let offersService: any OffersServicing
    private let billingService: any BillingServicing
    private let rechargeService: any RechargeServicing
    private let ticketsService: any TicketsServicing
    private let intentRecognitionService: (any IntentRecognitionServicing)?
    private let intentRoutingService: any IntentRoutingServicing
    private let subscribeOfferUseCase: any SubscribeOfferUseCase
    private let rechargeExecutionUseCase: any ExecuteRechargeUseCase
    private let payBillUseCase: any PayBillUseCase
    private let onNavigate: (AIChatNavigationTarget) -> Void
    private(set) var conversationID: String?
    private var activeAssistantMessageID: UUID?

    init(
        custSubInfo: CustSubInfo,
        language: AppLanguage,
        aiChatService: any AIChatServicing,
        offersService: (any OffersServicing)? = nil,
        billingService: (any BillingServicing)? = nil,
        rechargeService: (any RechargeServicing)? = nil,
        ticketsService: (any TicketsServicing)? = nil,
        intentRecognitionService: (any IntentRecognitionServicing)? = nil,
        intentRoutingService: (any IntentRoutingServicing)? = nil,
        subscribeOfferUseCase: (any SubscribeOfferUseCase)? = nil,
        rechargeExecutionUseCase: (any ExecuteRechargeUseCase)? = nil,
        payBillUseCase: (any PayBillUseCase)? = nil,
        onNavigate: @escaping (AIChatNavigationTarget) -> Void = { _ in }
    ) {
        let services = AppServices()
        self.custSubInfo = custSubInfo
        self.language = language
        self.aiChatService = aiChatService
        self.offersService = offersService ?? services.offersService
        self.billingService = billingService ?? services.billingService
        self.rechargeService = rechargeService ?? services.rechargeService
        self.ticketsService = ticketsService ?? services.ticketsService
        self.intentRecognitionService = intentRecognitionService ?? AppServices.makeIntentRecognitionService(
            aiChatService: aiChatService,
            configuration: services.configuration
        )
        self.intentRoutingService = intentRoutingService ?? DefaultIntentRoutingService(
            session: custSubInfo,
            offersService: self.offersService,
            billingService: self.billingService,
            rechargeService: self.rechargeService
        )
        self.subscribeOfferUseCase = subscribeOfferUseCase ?? DefaultSubscribeOfferUseCase(offersService: self.offersService)
        self.rechargeExecutionUseCase = rechargeExecutionUseCase ?? DefaultExecuteRechargeUseCase(rechargeService: self.rechargeService)
        self.payBillUseCase = payBillUseCase ?? DefaultPayBillUseCase(billingService: self.billingService)
        self.onNavigate = onNavigate
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
        return legacyDirectNavigationTarget(for: text)
    }

    func processPotentialNavigation(
        for text: String,
        fallbackToChat: @escaping @MainActor () -> Void
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        if let intentRecognitionService {
            recognizeIntentAndNavigate(
                text: trimmed,
                service: intentRecognitionService,
                fallbackToChat: fallbackToChat
            )
            return
        }

        if let target = legacyDirectNavigationTarget(for: trimmed) {
            navigateToTarget(target)
        } else {
            fallbackToChat()
        }
    }

    /// 新系统：意图识别并导航
    private func recognizeIntentAndNavigate(
        text: String,
        service: any IntentRecognitionServicing,
        fallbackToChat: @escaping @MainActor () -> Void
    ) {
        Task {
            isRecognizingIntent = true

            do {
                let result = try await service.recognizeIntent(
                    text: text,
                    context: buildContext(),
                    conversationHistory: messages,
                    language: language
                )

                isRecognizingIntent = false
                let outcome = await intentRoutingService.resolve(
                    text: text,
                    result: result,
                    context: buildContext(),
                    conversationHistory: messages,
                    language: language
                )

                handleIntentRoutingOutcome(
                    outcome,
                    originalText: text,
                    recognizedResult: result,
                    fallbackToChat: fallbackToChat
                )
            } catch {
                isRecognizingIntent = false
                intentConfirmationPresented = false
                pendingIntentResult = nil

                if let fallbackTarget = legacyDirectNavigationTarget(for: text) {
                    navigateToTarget(fallbackTarget)
                } else {
                    fallbackToChat()
                }
            }
        }
    }

    /// 导航到目标页面（外部回调）
    private func navigateToTarget(_ target: AIChatNavigationTarget) {
        onNavigate(target)
    }

    private func handleIntentRoutingOutcome(
        _ outcome: IntentRoutingOutcome,
        originalText: String,
        recognizedResult: IntentRecognitionResult,
        fallbackToChat: @escaping @MainActor () -> Void
    ) {
        switch outcome {
        case .navigateExplicitly(let target):
            if recognizedResult.needsUserConfirmation && !recognizedResult.isHighConfidence {
                pendingIntentResult = IntentRecognitionResult(
                    intentType: recognizedResult.intentType,
                    confidence: recognizedResult.confidence,
                    navigationTarget: target,
                    businessParameters: recognizedResult.businessParameters,
                    requiresConfirmation: recognizedResult.requiresConfirmation,
                    suggestedActions: recognizedResult.suggestedActions,
                    alternativeIntents: recognizedResult.alternativeIntents
                )
                intentConfirmationPresented = true
            } else {
                intentConfirmationPresented = false
                pendingIntentResult = nil
                navigateToTarget(target)
            }
        case .presentDomainFlow(let flow):
            intentConfirmationPresented = false
            pendingIntentResult = nil
            presentDomainFlow(flow, for: originalText)
        case .presentFollowUp(let reply):
            intentConfirmationPresented = false
            pendingIntentResult = nil
            presentIntentResolvedReply(for: originalText, reply: reply)
        case .handoffToGenericChat:
            intentConfirmationPresented = false
            pendingIntentResult = nil
            fallbackToChat()
        }
    }

    private func presentDomainFlow(_ flow: BoltDomainFlow, for userText: String) {
        messages.append(
            AIChatMessage(
                sender: .user,
                text: userText
            )
        )

        clearInteractiveArtifacts()
        activeDomainFlow = flow

        let assistantText = flow.assistantText
        if !assistantText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let assistantMessage = AIChatMessage(
                sender: .assistant,
                text: assistantText
            )
            messages.append(assistantMessage)
            activeAssistantMessageID = assistantMessage.id
        } else {
            activeAssistantMessageID = nil
        }

        switch flow {
        case .offers(let context),
             .roaming(let context):
            offers = context.offers
            selectedOffer = nil
            currentStep = .offersList
        case .travel:
            currentStep = .answer
        case .recharge(let context):
            currentPaymentCard = context.paymentCard
            currentStep = .answer
        case .billing(let context):
            selectedBillingInvoice = context.summary.outstandingInvoices.first
            currentStep = .answer
        case .payment(let context):
            currentPaymentCard = context.paymentCard
            selectedBillingInvoice = context.invoice
            currentStep = .answer
        case .balance,
             .usage,
             .serviceRequest,
             .multiIntentSelection:
            currentStep = .answer
        }
    }

    private func presentIntentResolvedReply(for userText: String, reply: AIChatReply) {
        messages.append(
            AIChatMessage(
                sender: .user,
                text: userText
            )
        )

        conversationID = reply.conversationID ?? conversationID
        activeDomainFlow = nil
        applyReplyMetadata(reply)
        currentPaymentCard = reply.paymentResult == nil ? reply.paymentCard : nil
        currentItineraryCard = reply.itineraryCard
        selectedBillingInvoice = nil

        let assistantMessage = AIChatMessage(
            sender: .assistant,
            text: resolvedReplyText(reply),
            thinkingText: reply.thinkingText,
            recommendedOffers: reply.recommendedOffers,
            actions: reply.actions
        )
        messages.append(assistantMessage)
        activeAssistantMessageID = assistantMessage.id
        offers = reply.recommendedOffers
        selectedOffer = nil
        acceptedResult = nil
        subscriptionErrorMessage = nil

        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            currentStep = reply.recommendedOffers.isEmpty ? .answer : .offersList
        }
    }

    private func clearInteractiveArtifacts() {
        currentPaymentCard = nil
        currentItineraryCard = nil
        selectedBillingInvoice = nil
        subscriptionErrorMessage = nil
    }

    /// 原有硬编码关键词匹配逻辑（fallback）
    private func legacyDirectNavigationTarget(for text: String) -> AIChatNavigationTarget? {
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

    /// 用户确认意图后执行导航
    func confirmIntentAndNavigate() {
        guard let result = pendingIntentResult, let target = result.navigationTarget else {
            return
        }

        intentConfirmationPresented = false
        pendingIntentResult = nil
        navigateToTarget(target)
    }

    /// 用户拒绝意图确认
    func dismissIntentConfirmation() {
        intentConfirmationPresented = false
        pendingIntentResult = nil
    }

    func sendDraft() {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return
        }

        draft = ""
        send(message)
    }

    func sendMessageText(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        send(trimmed)
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
        activeDomainFlow = nil
        selectedOffer = nil
        selectedBillingInvoice = nil
        offers = []
        acceptedResult = nil
        subscriptionErrorMessage = nil
        activeAssistantMessageID = nil
        currentPaymentCard = nil
        currentItineraryCard = nil
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

        guard hasExecutableOfferIdentity(selectedOffer) else {
            subscriptionErrorMessage = missingOfferConfigurationMessage()
            return
        }

        subscriptionErrorMessage = nil
        isProcessingSubscription = true

        Task {
            do {
                let executionResult = try await subscribeOfferUseCase.execute(
                    offer: selectedOffer,
                    session: custSubInfo
                )
                _ = try? await notifyOfferEvent(.subscriptionRequested, offer: selectedOffer)

                await MainActor.run {
                    acceptedResult = executionResult
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
                if let billingFlow = restoreBillingFlowFromPayment() {
                    activeDomainFlow = .billing(billingFlow)
                    currentPaymentCard = nil
                } else {
                    activeDomainFlow = nil
                    currentPaymentCard = nil
                    selectedBillingInvoice = nil
                    currentStep = .home
                }
            case .offersList:
                activeDomainFlow = nil
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

        activeDomainFlow = nil
        currentPaymentCard = nil
        selectedBillingInvoice = nil

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
                    currentPaymentCard = reply.paymentResult == nil ? reply.paymentCard : nil
                    currentItineraryCard = reply.itineraryCard
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
        activeDomainFlow = nil
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

        if let paymentResult = reply.paymentResult, !paymentResult.message.isEmpty {
            return paymentResult.message
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

    func submitFollowUpSuggestion(_ suggestion: String) {
        let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        processPotentialNavigation(for: trimmed) {
            self.sendMessageText(trimmed)
        }
    }

    /// 用户选择多意图中的一个后提交处理
    func submitIntentSelection(_ intentType: String, originalText: String) {
        guard let selectedIntent = UserIntentType(rawValue: intentType) else {
            // 无法解析意图类型，直接提交原文重新处理
            sendMessageText(originalText)
            return
        }

        // 根据选择的意图创建对应的 DomainFlow
        let flow = createDomainFlowForIntent(selectedIntent, originalText: originalText)
        activeDomainFlow = flow
        currentStep = .answer
    }

    private func createDomainFlowForIntent(_ intentType: UserIntentType, originalText: String) -> BoltDomainFlow? {
        // 通用占位卡片，后续会通过服务获取真实数据
        let placeholderInfoCard = BoltInfoCard(
            title: intentType.displayName(for: language),
            accentValue: "--",
            accentCaption: "Loading...",
            detailLines: [],
            footnote: nil
        )

        // 通用占位支付卡，后续会通过服务获取真实数据
        let placeholderPaymentCard = AIChatPaymentCard(
            transactionType: .recharge,
            amountOptions: PaymentAmountOptions(
                min: 10.0,
                max: 500.0,
                defaultAmount: 50.0,
                quickAmounts: [10, 20, 50, 100],
                currency: "AED"
            ),
            paymentMethods: [
                PaymentMethodOption(
                    id: "tabby",
                    name: "Tabby BNPL",
                    description: "Split in 4 installments",
                    iconType: .tabby,
                    installmentOptions: nil,
                    isDefault: true
                ),
                PaymentMethodOption(
                    id: "apple_pay",
                    name: "Apple Pay",
                    description: "Instant payment",
                    iconType: .apple,
                    installmentOptions: nil,
                    isDefault: false
                )
            ],
            subscriberInfo: nil
        )

        switch intentType {
        case .rechargeAccount:
            // 充值需要真实的服务号和余额，这里用占位值
            return .recharge(BoltRechargeFlowContext(
                title: "Recharge",
                message: "How would you like to recharge your account?",
                paymentCard: placeholderPaymentCard,
                serviceNumber: "",
                balanceText: ""
            ))
        case .viewOffers, .subscribeOffer:
            return .offers(BoltOfferFlowContext(
                title: "Offers",
                message: "Here are available offers for you",
                offers: [],
                allowExternalNavigation: true,
                isRoaming: false
            ))
        case .balanceInquiry:
            return .balance(placeholderInfoCard)
        case .dataUsageQuery:
            return .usage(BoltInfoCard(
                title: "Data Usage",
                accentValue: "-- GB",
                accentCaption: "Remaining Data",
                detailLines: [],
                footnote: nil
            ))
        case .voiceUsageQuery:
            return .usage(BoltInfoCard(
                title: "Voice Usage",
                accentValue: "-- min",
                accentCaption: "Remaining Minutes",
                detailLines: [],
                footnote: nil
            ))
        case .itineraryQuery, .flightInfo, .hotelInfo:
            return .travel(BoltTravelFlowContext(
                title: "Travel",
                message: "Planning your trip",
                destination: nil,
                transportMode: nil,
                departureDateText: nil,
                returnDateText: nil,
                passengerCount: nil,
                priceRange: nil,
                followUpQuestion: "Where would you like to go?",
                suggestedReplies: [],
                ticketPageURL: nil,
                isResolvingTicketPage: false,
                ticketPageErrorMessage: nil
            ))
        default:
            return nil
        }
    }

    func openTravelTicketsInBolt() {
        guard case .travel(let travelFlow) = activeDomainFlow else {
            return
        }

        activeDomainFlow = .travel(
            BoltTravelFlowContext(
                title: travelFlow.title,
                message: travelFlow.message,
                destination: travelFlow.destination,
                transportMode: travelFlow.transportMode,
                departureDateText: travelFlow.departureDateText,
                returnDateText: travelFlow.returnDateText,
                passengerCount: travelFlow.passengerCount,
                priceRange: travelFlow.priceRange,
                followUpQuestion: nil,
                suggestedReplies: [],
                ticketPageURL: nil,
                isResolvingTicketPage: true,
                ticketPageErrorMessage: nil
            )
        )

        Task {
            do {
                let url = try await ticketsService.fetchTicketURL()
                await MainActor.run {
                    guard case .travel(let latestFlow) = self.activeDomainFlow else {
                        return
                    }

                    self.activeDomainFlow = .travel(
                        BoltTravelFlowContext(
                            title: latestFlow.title,
                            message: self.localizedTravelBookingReadyMessage(for: latestFlow),
                            destination: latestFlow.destination,
                            transportMode: latestFlow.transportMode,
                            departureDateText: latestFlow.departureDateText,
                            returnDateText: latestFlow.returnDateText,
                            passengerCount: latestFlow.passengerCount,
                            priceRange: latestFlow.priceRange,
                            followUpQuestion: nil,
                            suggestedReplies: [],
                            ticketPageURL: url,
                            isResolvingTicketPage: false,
                            ticketPageErrorMessage: nil
                        )
                    )
                    self.currentStep = .answer
                }
            } catch {
                await MainActor.run {
                    guard case .travel(let latestFlow) = self.activeDomainFlow else {
                        return
                    }

                    self.activeDomainFlow = .travel(
                        BoltTravelFlowContext(
                            title: latestFlow.title,
                            message: latestFlow.message,
                            destination: latestFlow.destination,
                            transportMode: latestFlow.transportMode,
                            departureDateText: latestFlow.departureDateText,
                            returnDateText: latestFlow.returnDateText,
                            passengerCount: latestFlow.passengerCount,
                            priceRange: latestFlow.priceRange,
                            followUpQuestion: latestFlow.followUpQuestion,
                            suggestedReplies: latestFlow.suggestedReplies,
                            ticketPageURL: nil,
                            isResolvingTicketPage: false,
                            ticketPageErrorMessage: self.localizedTravelTicketLoadError()
                        )
                    )
                }
            }
        }
    }

    func openTravelOffersInBolt() {
        submitFollowUpSuggestion(localizedTravelOffersPrompt())
    }

    func beginBillingPayment(for invoice: BillingInvoice) {
        guard case .billing(let billingFlow) = activeDomainFlow else {
            return
        }

        selectedBillingInvoice = invoice
        activeDomainFlow = .payment(
            BoltPaymentFlowContext(
                title: billingFlow.title,
                message: localizedBillPaymentPrompt(for: invoice),
                paymentCard: makeBillPaymentCard(for: invoice),
                invoice: invoice,
                summary: billingFlow.summary
            )
        )
        currentPaymentCard = makeBillPaymentCard(for: invoice)
        currentStep = .answer
    }

    func currentPaymentService() -> PaymentServicing {
        if case .payment(let paymentFlow) = activeDomainFlow, let invoice = paymentFlow.invoice {
            return BillingDomainPaymentService(
                session: custSubInfo,
                invoice: invoice,
                useCase: payBillUseCase
            )
        }

        return RechargeDomainPaymentService(
            session: custSubInfo,
            useCase: rechargeExecutionUseCase
        )
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
        guard result.status == .success else {
            return
        }

        currentPaymentCard = nil
        let message = paymentSuccessMessage(for: result)

        if case .payment(let paymentFlow) = activeDomainFlow, let summary = paymentFlow.summary {
            activeDomainFlow = .billing(
                BoltBillingFlowContext(
                    title: paymentFlow.title,
                    message: localizedBillingReturnMessage(),
                    summary: summary
                )
            )
        } else {
            activeDomainFlow = nil
        }

        let resultMessage = AIChatMessage(
            sender: .assistant,
            text: message
        )
        messages.append(resultMessage)
        activeAssistantMessageID = resultMessage.id
        currentStep = .answer
    }

    private func paymentSuccessMessage(for result: PaymentResultCard) -> String {
        if case .payment(let paymentFlow) = activeDomainFlow, let invoice = paymentFlow.invoice {
            switch language {
            case .english:
                return "Payment successful for invoice \(invoice.invoiceNo).\nOrder ID: \(result.orderId ?? "-")"
            case .simplifiedChinese:
                return "账单 \(invoice.invoiceNo) 支付成功。\n订单号：\(result.orderId ?? "-")"
            case .arabic:
                return "تم سداد الفاتورة \(invoice.invoiceNo) بنجاح.\nرقم الطلب: \(result.orderId ?? "-")"
            }
        }

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

    private func makeBillPaymentCard(for invoice: BillingInvoice) -> AIChatPaymentCard {
        let amount = BillingNumberParser.decimal(invoice.openAmountRaw) ?? 0
        return AIChatPaymentCard(
            transactionType: .billPayment,
            amountOptions: PaymentAmountOptions(
                min: amount,
                max: amount,
                defaultAmount: amount,
                quickAmounts: [amount],
                currency: "AED"
            ),
            paymentMethods: [
                PaymentMethodOption(
                    id: "tabby",
                    name: "Tabby BNPL",
                    description: "Split in 4 installments • No interest",
                    iconType: .tabby,
                    installmentOptions: [
                        InstallmentOption(
                            installments: 4,
                            amountPerInstallment: amount / Decimal(4)
                        )
                    ],
                    isDefault: true
                ),
                PaymentMethodOption(
                    id: "apple_pay",
                    name: "Apple Pay",
                    description: "Instant payment",
                    iconType: .apple,
                    installmentOptions: nil,
                    isDefault: false
                ),
                PaymentMethodOption(
                    id: "google_pay",
                    name: "Google Pay",
                    description: "Instant payment",
                    iconType: .google,
                    installmentOptions: nil,
                    isDefault: false
                )
            ],
            subscriberInfo: PaymentSubscriberInfo(
                serviceNumber: custSubInfo.serviceNumber ?? custSubInfo.phoneNumber,
                currentBalance: nil
            )
        )
    }

    private func localizedBillPaymentPrompt(for invoice: BillingInvoice) -> String {
        switch language {
        case .english:
            return "Pay invoice \(invoice.invoiceNo) for \(invoice.openAmountText) directly inside Bolt."
        case .simplifiedChinese:
            return "直接在 Bolt 内支付账单 \(invoice.invoiceNo)，金额 \(invoice.openAmountText)。"
        case .arabic:
            return "ادفع الفاتورة \(invoice.invoiceNo) بقيمة \(invoice.openAmountText) مباشرة داخل Bolt."
        }
    }

    private func localizedBillingReturnMessage() -> String {
        switch language {
        case .english:
            return "You can review the remaining billing summary below."
        case .simplifiedChinese:
            return "你可以继续在下方查看账单摘要。"
        case .arabic:
            return "يمكنك متابعة مراجعة ملخص الفاتورة أدناه."
        }
    }

    private func localizedTravelBookingReadyMessage(for travelFlow: BoltTravelFlowContext) -> String {
        guard
            let destination = travelFlow.destination,
            let transportMode = travelFlow.transportMode,
            let departureDateText = travelFlow.departureDateText
        else {
            switch language {
            case .english:
                return "The ticket page is now ready inside Bolt."
            case .simplifiedChinese:
                return "票务页面已经在 Bolt 内打开。"
            case .arabic:
                return "تم فتح صفحة التذاكر داخل Bolt."
            }
        }

        switch language {
        case .english:
            return "Continuing your \(transportMode.rawValue) booking to \(destination) on \(departureDateText) inside Bolt."
        case .simplifiedChinese:
            return "正在 Bolt 内继续处理你在 \(departureDateText) 前往 \(destination) 的\(transportMode == .flight ? "机票" : "火车票")预订。"
        case .arabic:
            return "يتم الآن متابعة حجز \(transportMode == .flight ? "تذاكر الطيران" : "تذاكر القطار") إلى \(destination) بتاريخ \(departureDateText) داخل Bolt."
        }
    }

    private func localizedTravelTicketLoadError() -> String {
        switch language {
        case .english:
            return "The ticket page could not be loaded inside Bolt right now. You can try again without leaving the chat."
        case .simplifiedChinese:
            return "当前无法在 Bolt 内加载票务页面，你可以直接在聊天框内重试。"
        case .arabic:
            return "تعذر تحميل صفحة التذاكر داخل Bolt حالياً، ويمكنك إعادة المحاولة دون مغادرة الدردشة."
        }
    }

    private func localizedTravelOffersPrompt() -> String {
        switch language {
        case .english:
            return "show me roaming offers for this trip"
        case .simplifiedChinese:
            return "给我看看这次出行相关的漫游优惠"
        case .arabic:
            return "اعرض علي عروض التجوال لهذه الرحلة"
        }
    }

    private func restoreBillingFlowFromPayment() -> BoltBillingFlowContext? {
        guard case .payment(let paymentFlow) = activeDomainFlow, let summary = paymentFlow.summary else {
            return nil
        }

        return BoltBillingFlowContext(
            title: paymentFlow.title,
            message: localizedBillingReturnMessage(),
            summary: summary
        )
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

    private func hasExecutableOfferIdentity(_ offer: AIChatOffer) -> Bool {
        let offerIdValid = !(offer.offerId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let offerCodeValid = !(offer.offerCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return offerIdValid && offerCodeValid
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
