import Foundation
import Testing

@testable import du_App

@Suite("Intent Recognition Integration Tests")
struct IntentRecognitionIntegrationTests {

    @Test("Local matcher returns correct intent for balance inquiry")
    func testLocalMatcherBalanceInquiry() async throws {
        let matcher = LocalIntentMatcher()

        // 测试英文
        let englishResult = await matcher.match(text: "How can I check my balance?", language: .english)
        #expect(englishResult?.intentType == .balanceInquiry, "English balance inquiry should be recognized")
        #expect(englishResult?.isHighConfidence == true, "Balance inquiry should have high confidence")

        // 测试中文
        let chineseResult = await matcher.match(text: "查看余额", language: .simplifiedChinese)
        #expect(chineseResult?.intentType == .balanceInquiry, "Chinese balance inquiry should be recognized")

        // 测试阿拉伯语
        let arabicResult = await matcher.match(text: "الرصيد", language: .arabic)
        #expect(arabicResult?.intentType == .balanceInquiry, "Arabic balance inquiry should be recognized")
    }

    @Test("Local matcher returns correct intent for recharge")
    func testLocalMatcherRecharge() async throws {
        let matcher = LocalIntentMatcher()

        // 测试英文
        let englishResult = await matcher.match(text: "Recharge my account", language: .english)
        #expect(englishResult?.intentType == .rechargeAccount, "English recharge should be recognized")
        #expect(englishResult?.navigationTarget == .recharge, "Recharge should navigate to recharge page")

        // 测试中文
        let chineseResult = await matcher.match(text: "充值", language: .simplifiedChinese)
        #expect(chineseResult?.intentType == .rechargeAccount, "Chinese recharge should be recognized")
    }

    @Test("Local matcher returns nil for unrecognized text")
    func testLocalMatcherUnrecognized() async throws {
        let matcher = LocalIntentMatcher()

        let result = await matcher.match(text: "Random unrecognized text", language: .english)
        #expect(result == nil, "Unrecognized text should return nil")
    }

    @Test("Data package status wording stays data usage")
    func testDataPackageStatusWordingStaysDataUsage() async throws {
        let matcher = LocalIntentMatcher()

        let usageTexts = [
            "what about my data package",
            "what about my data",
            "how is my data package",
            "current data package status"
        ]

        for text in usageTexts {
            let result = await matcher.match(text: text, language: .english)
            #expect(result?.intentType == .dataUsageQuery, "\(text) should be data usage")
        }

        let offerResult = await matcher.match(text: "what offers are available", language: .english)
        #expect(offerResult?.intentType == .viewOffers)

        let subscribeResult = await matcher.match(text: "i need a bigger data package", language: .english)
        #expect(subscribeResult?.intentType == .subscribeOffer)
    }

    @Test("Confidence calculator evaluates high confidence result")
    func testConfidenceCalculatorHighConfidence() throws {
        let calculator = IntentConfidenceCalculator()

        let highConfidenceResult = IntentRecognitionResult(
            intentType: .balanceInquiry,
            confidence: 0.9,
            navigationTarget: .home
        )

        let evaluated = calculator.evaluate(aiResult: highConfidenceResult, localResult: nil)
        #expect(evaluated.isHighConfidence, "High confidence result should remain high")
        #expect(!evaluated.needsUserConfirmation, "High confidence should not need confirmation")
    }

    @Test("Confidence calculator adjusts high-risk intent confidence")
    func testConfidenceCalculatorHighRiskIntent() throws {
        let calculator = IntentConfidenceCalculator()

        // 高风险意图（订阅套餐）即使置信度高也需要确认
        let subscribeResult = IntentRecognitionResult(
            intentType: .subscribeOffer,
            confidence: 0.95,
            navigationTarget: .offers
        )

        let evaluated = calculator.evaluate(aiResult: subscribeResult, localResult: nil)
        #expect(evaluated.needsUserConfirmation, "Subscribe offer should need confirmation")
    }

    @Test("Confidence calculator merges AI and local results")
    func testConfidenceCalculatorMergeResults() throws {
        let calculator = IntentConfidenceCalculator()

        let aiResult = IntentRecognitionResult(
            intentType: .balanceInquiry,
            confidence: 0.75,
            navigationTarget: .home
        )

        let localResult = IntentRecognitionResult(
            intentType: .balanceInquiry,
            confidence: 0.9,
            navigationTarget: .home
        )

        let merged = calculator.evaluate(aiResult: aiResult, localResult: localResult)
        #expect(merged.intentType == .balanceInquiry, "Merged result should keep same intent type")
        #expect(merged.confidence > aiResult.confidence, "Merged confidence should be higher than AI alone")
    }

    @Test("Mock intent recognition service returns valid result")
    func testMockIntentRecognitionService() async throws {
        let mockService = MockIntentRecognitionService()

        // 测试本地匹配
        let localResult = await mockService.localMatch(text: "check balance", language: .english)
        #expect(localResult?.intentType == .balanceInquiry, "Mock service local match should work")

        // 测试 AI 匹配
        let context = AIChatContext(
            accessToken: "test",
            authorization: "Bearer test",
            userID: "user_123",
            serviceNumber: "12345678",
            subscriberKey: "sub_key",
            languageCode: "en",
            displayName: "Test User"
        )

        let aiResult = try await mockService.aiSemanticMatch(
            text: "general question",
            context: context,
            conversationHistory: []
        )
        #expect(aiResult.intentType == .generalQuestion, "Mock AI match should return general question")
    }

    @Test("Default intent recognition service fallback to local match")
    func testDefaultServiceFallback() async throws {
        let mockAIChatService = MockAIChatService()
        let service = DefaultIntentRecognitionService(aiChatService: mockAIChatService)

        let context = AIChatContext(
            accessToken: "test",
            authorization: "Bearer test",
            userID: "user_123",
            serviceNumber: "12345678",
            subscriberKey: "sub_key",
            languageCode: "en",
            displayName: "Test User"
        )

        // 测试识别流程（本地匹配优先）
        let result = try await service.recognizeIntent(
            text: "check my balance",
            context: context,
            conversationHistory: [],
            language: .english
        )

        #expect(result.intentType == .balanceInquiry, "Service should recognize balance inquiry")
        #expect(result.isHighConfidence, "Service should return high confidence result")
    }

    @Test("Implicit offer request stays inside Bolt")
    func testImplicitOfferRoutingStaysInsideBolt() async throws {
        let routingService = makeRoutingService()
        let outcome = await routingService.resolve(
            text: "my data is not enough",
            result: IntentRecognitionResult(
                intentType: .viewOffers,
                confidence: 0.95,
                navigationTarget: .offers
            ),
            context: sampleContext(),
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let flow) = outcome else {
            Issue.record("Implicit offer request should stay in Bolt")
            return
        }

        guard case .offers(let context) = flow else {
            Issue.record("Implicit offer request should map to offer flow")
            return
        }

        #expect(!context.offers.isEmpty, "Offer flow should provide in-chat offers")
    }

    @Test("Explicit offers page request keeps external navigation")
    func testExplicitOffersPageNavigation() async throws {
        let routingService = makeRoutingService()
        let outcome = await routingService.resolve(
            text: "open offers page",
            result: IntentRecognitionResult(
                intentType: .viewOffers,
                confidence: 0.95,
                navigationTarget: .offers
            ),
            context: sampleContext(),
            conversationHistory: [],
            language: .english
        )

        guard case .navigateExplicitly(let target) = outcome else {
            Issue.record("Explicit offers page request should navigate explicitly")
            return
        }

        #expect(target == .offers, "Explicit request should preserve offers navigation")
    }

    @Test("Explicit billing and recharge page requests keep external navigation")
    func testExplicitBillingAndRechargeNavigation() async throws {
        let routingService = makeRoutingService()
        let context = sampleContext()

        let billingOutcome = await routingService.resolve(
            text: "open billing page",
            result: IntentRecognitionResult(
                intentType: .viewBill,
                confidence: 0.93,
                navigationTarget: .billing
            ),
            context: context,
            conversationHistory: [],
            language: .english
        )

        guard case .navigateExplicitly(let billingTarget) = billingOutcome else {
            Issue.record("Explicit billing page request should navigate explicitly")
            return
        }
        #expect(billingTarget == .billing)

        let rechargeOutcome = await routingService.resolve(
            text: "open recharge page",
            result: IntentRecognitionResult(
                intentType: .rechargeAccount,
                confidence: 0.93,
                navigationTarget: .recharge
            ),
            context: context,
            conversationHistory: [],
            language: .english
        )

        guard case .navigateExplicitly(let rechargeTarget) = rechargeOutcome else {
            Issue.record("Explicit recharge page request should navigate explicitly")
            return
        }
        #expect(rechargeTarget == .recharge)
    }

    @Test("Recharge, billing, payment, balance and usage route to Bolt flows")
    func testTelecomFlowsRouteInsideBolt() async throws {
        let routingService = makeRoutingService()
        let context = sampleContext()

        let rechargeOutcome = await routingService.resolve(
            text: "recharge my account",
            result: IntentRecognitionResult(
                intentType: .rechargeAccount,
                confidence: 0.92,
                navigationTarget: .recharge
            ),
            context: context,
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let rechargeFlow) = rechargeOutcome,
              case .recharge(let rechargeContext) = rechargeFlow
        else {
            Issue.record("Recharge should route to Bolt recharge flow")
            return
        }
        #expect(rechargeContext.paymentCard.transactionType == .recharge)

        let billingOutcome = await routingService.resolve(
            text: "view my bill",
            result: IntentRecognitionResult(
                intentType: .viewBill,
                confidence: 0.93,
                navigationTarget: .billing
            ),
            context: context,
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let billingFlow) = billingOutcome,
              case .billing(let billingContext) = billingFlow
        else {
            Issue.record("Billing should route to Bolt billing flow")
            return
        }
        #expect(!billingContext.summary.outstandingInvoices.isEmpty, "Billing flow should expose outstanding invoices")

        let paymentOutcome = await routingService.resolve(
            text: "pay my bill",
            result: IntentRecognitionResult(
                intentType: .makePayment,
                confidence: 0.9,
                navigationTarget: .billing
            ),
            context: context,
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let paymentFlow) = paymentOutcome,
              case .payment(let paymentContext) = paymentFlow
        else {
            Issue.record("Payment should route to Bolt payment flow")
            return
        }
        #expect(paymentContext.paymentCard.transactionType == .billPayment)

        let balanceOutcome = await routingService.resolve(
            text: "check my balance",
            result: IntentRecognitionResult(
                intentType: .balanceInquiry,
                confidence: 0.95,
                navigationTarget: .home
            ),
            context: context,
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let balanceFlow) = balanceOutcome,
              case .balance(let balanceCard) = balanceFlow
        else {
            Issue.record("Balance should route to Bolt balance flow")
            return
        }
        #expect(!balanceCard.accentValue.isEmpty)

        let usageOutcome = await routingService.resolve(
            text: "how much data do i have left",
            result: IntentRecognitionResult(
                intentType: .generalQuestion,
                confidence: 0.72
            ),
            context: context,
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let usageFlow) = usageOutcome,
              case .usage(let usageCard) = usageFlow
        else {
            Issue.record("Usage should route to Bolt usage flow")
            return
        }
        #expect(!usageCard.accentValue.isEmpty)

        let dataPackageOutcome = await routingService.resolve(
            text: "what about my data package",
            result: IntentRecognitionResult(
                intentType: .viewOffers,
                confidence: 0.88,
                navigationTarget: .offers
            ),
            context: context,
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let dataPackageFlow) = dataPackageOutcome,
              case .usage(let dataPackageCard) = dataPackageFlow
        else {
            Issue.record("Existing data package status should route to Bolt usage flow even if classified as offers")
            return
        }
        #expect(dataPackageCard.title.localizedCaseInsensitiveContains("Data"))
    }

    @Test("SMS and voice usage intents route to Bolt usage flow")
    func testSmsAndVoiceUsageRouteInsideBolt() async throws {
        let routingService = makeRoutingService()
        let context = sampleContext()

        let smsOutcome = await routingService.resolve(
            text: "Check my sms",
            result: IntentRecognitionResult(
                intentType: .smsUsageQuery,
                confidence: 0.88,
                navigationTarget: .home
            ),
            context: context,
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let smsFlow) = smsOutcome,
              case .usage(let smsCard) = smsFlow
        else {
            Issue.record("SMS usage should route to Bolt usage flow")
            return
        }
        #expect(smsCard.title.localizedCaseInsensitiveContains("SMS"))
        #expect(smsCard.accentValue.localizedCaseInsensitiveContains("SMS"))

        let voiceOutcome = await routingService.resolve(
            text: "check my remaining minutes",
            result: IntentRecognitionResult(
                intentType: .voiceUsageQuery,
                confidence: 0.88,
                navigationTarget: .home
            ),
            context: context,
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let voiceFlow) = voiceOutcome,
              case .usage(let voiceCard) = voiceFlow
        else {
            Issue.record("Voice usage should route to Bolt usage flow")
            return
        }
        #expect(voiceCard.title.localizedCaseInsensitiveContains("Voice"))
        #expect(voiceCard.accentValue.localizedCaseInsensitiveContains("min"))
    }

    @MainActor
    @Test("Check my sms stays inside Bolt overlay")
    func testCheckMySmsStaysInsideBoltOverlay() async throws {
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService(),
            intentRecognitionService: StubIntentRecognitionService(
                result: IntentRecognitionResult(
                    intentType: .smsUsageQuery,
                    confidence: 0.88,
                    navigationTarget: .home
                )
            ),
            intentRoutingService: makeRoutingService()
        )

        viewModel.processPotentialNavigation(for: "Check my sms") {
            Issue.record("SMS usage should not hand off to generic chat")
        }

        for _ in 0..<20 {
            if case .usage = viewModel.activeDomainFlow, viewModel.currentStep == .answer {
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        #expect(viewModel.currentStep == .answer)
        guard case .usage(let card) = viewModel.activeDomainFlow else {
            Issue.record("SMS query should activate Bolt usage flow")
            return
        }
        #expect(card.title.localizedCaseInsensitiveContains("SMS"))
    }

    @MainActor
    @Test("Ordinary telecom requests do not dismiss Bolt overlay")
    func testOrdinaryTelecomRequestDoesNotNavigateExternally() async throws {
        let aiChatService = MockAIChatService()
        let offersService = MockOffersService()
        let billingService = MockBillingService()
        let rechargeService = MockRechargeService()

        var navigationTargets: [AIChatNavigationTarget] = []
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: aiChatService,
            offersService: offersService,
            billingService: billingService,
            rechargeService: rechargeService,
            onNavigate: { target in
                navigationTargets.append(target)
            }
        )

        viewModel.processPotentialNavigation(for: "check my balance") {
            Issue.record("Balance query should not hand off to generic chat")
        }

        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(navigationTargets.isEmpty, "Implicit telecom request should keep Bolt overlay active")
        #expect(viewModel.currentStep == .answer, "Balance query should resolve inside the answer shell")

        guard case .balance = viewModel.activeDomainFlow else {
            Issue.record("Balance query should activate Bolt balance flow")
            return
        }
    }

    @Test("Ticket request with help wording still routes to travel follow-up")
    func testTicketHelpRequestPrefersTravelFlow() async throws {
        let routingService = makeRoutingService()
        let outcome = await routingService.resolve(
            text: "Help me to get the ticket",
            result: IntentRecognitionResult(
                intentType: .itineraryQuery,
                confidence: 0.95
            ),
            context: sampleContext(),
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let flow) = outcome,
              case .travel(let context) = flow
        else {
            Issue.record("Ticket help request should route to travel flow")
            return
        }

        #expect(
            (context.followUpQuestion ?? context.message).localizedCaseInsensitiveContains("ticket")
                || (context.followUpQuestion ?? context.message).localizedCaseInsensitiveContains("travel")
        )
        #expect(context.ticketPageURL == nil)
    }

    @Test("Travel typo phrase still routes to travel flow")
    func testTravelTypoRoutesToTravelFlow() async throws {
        let routingService = makeRoutingService()
        let outcome = await routingService.resolve(
            text: "I want to tranval to hongkong",
            result: IntentRecognitionResult(
                intentType: .generalQuestion,
                confidence: 0.55
            ),
            context: sampleContext(),
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let flow) = outcome,
              case .travel(let context) = flow
        else {
            Issue.record("Travel typo should route to travel flow")
            return
        }

        #expect(context.destination?.lowercased().contains("hongkong") == true)
    }

    @MainActor
    @Test("Continue Ticket Booking stays inside Bolt")
    func testContinueTicketBookingStaysInsideBolt() async throws {
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService(),
            ticketsService: StubTicketsService(url: URL(string: "https://example.com/tickets")!)
        )
        viewModel.activeDomainFlow = .travel(
            BoltTravelFlowContext(
                title: "Travel Planning",
                message: "Ready to continue in Bolt",
                destination: "Hongkong",
                transportMode: .flight,
                departureDateText: "tomorrow",
                returnDateText: nil,
                passengerCount: nil,
                priceRange: nil,
                followUpQuestion: nil,
                suggestedReplies: [],
                ticketPageURL: nil,
                isResolvingTicketPage: false,
                ticketPageErrorMessage: nil
            )
        )

        viewModel.openTravelTicketsInBolt()
        try await settle()

        guard case .travel(let updatedFlow) = viewModel.activeDomainFlow else {
            Issue.record("Travel flow should remain active inside Bolt")
            return
        }

        #expect(updatedFlow.ticketPageURL?.absoluteString == "https://example.com/tickets")
        #expect(updatedFlow.isResolvingTicketPage == false)
    }

    @MainActor
    @Test("Low-confidence intent prompts confirmation instead of immediate navigation")
    func testLowConfidenceIntentPromptsConfirmation() async throws {
        var navigationTargets: [AIChatNavigationTarget] = []
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService(),
            intentRecognitionService: StubIntentRecognitionService(
                result: IntentRecognitionResult(
                    intentType: .viewOffers,
                    confidence: 0.45,
                    navigationTarget: .offers,
                    requiresConfirmation: true
                )
            ),
            intentRoutingService: StubIntentRoutingService(
                outcome: .navigateExplicitly(.offers)
            ),
            onNavigate: { target in
                navigationTargets.append(target)
            }
        )

        viewModel.processPotentialNavigation(for: "show me offers") {
            Issue.record("Low-confidence intent should not hand off to generic chat immediately")
        }

        try await settle()

        #expect(viewModel.intentConfirmationPresented)
        #expect(viewModel.pendingIntentResult?.navigationTarget == .offers)
        #expect(navigationTargets.isEmpty)
    }

    @MainActor
    @Test("Intent recognition failure falls back to legacy navigation keywords")
    func testIntentRecognitionFailureFallsBackToLegacyNavigation() async throws {
        var navigationTargets: [AIChatNavigationTarget] = []
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService(),
            intentRecognitionService: ThrowingIntentRecognitionService(),
            intentRoutingService: StubIntentRoutingService(outcome: .handoffToGenericChat),
            onNavigate: { target in
                navigationTargets.append(target)
            }
        )

        viewModel.processPotentialNavigation(for: "check my balance") {
            Issue.record("Legacy keyword fallback should navigate before generic chat")
        }

        try await settle()

        #expect(navigationTargets == [.home])
    }

    @MainActor
    @Test("presentDomainFlow updates top-level flow state correctly")
    func testPresentDomainFlowUpdatesState() async throws {
        let offersFlow = BoltDomainFlow.offers(
            BoltOfferFlowContext(
                title: "Offers",
                message: "Offer flow",
                offers: [sampleAIChatOffer()],
                allowExternalNavigation: true,
                isRoaming: false
            )
        )
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService(),
            intentRecognitionService: StubIntentRecognitionService(
                result: IntentRecognitionResult(intentType: .viewOffers, confidence: 0.95)
            ),
            intentRoutingService: StubIntentRoutingService(outcome: .presentDomainFlow(offersFlow))
        )

        viewModel.processPotentialNavigation(for: "buy more data") {
            Issue.record("Offer flow should not hand off to generic chat")
        }
        try await settle()

        guard case .offers = viewModel.activeDomainFlow else {
            Issue.record("Offer flow should become activeDomainFlow")
            return
        }
        #expect(viewModel.currentStep == .offersList)

        let rechargeFlow = BoltDomainFlow.recharge(
            BoltRechargeFlowContext(
                title: "Recharge",
                message: "Recharge flow",
                paymentCard: sampleRechargePaymentCard(),
                serviceNumber: "12345678",
                balanceText: "AED 20.00"
            )
        )
        let rechargeViewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService(),
            intentRecognitionService: StubIntentRecognitionService(
                result: IntentRecognitionResult(intentType: .rechargeAccount, confidence: 0.95)
            ),
            intentRoutingService: StubIntentRoutingService(outcome: .presentDomainFlow(rechargeFlow))
        )

        rechargeViewModel.processPotentialNavigation(for: "recharge my account") {
            Issue.record("Recharge flow should not hand off to generic chat")
        }
        try await settle()

        guard case .recharge = rechargeViewModel.activeDomainFlow else {
            Issue.record("Recharge flow should become activeDomainFlow")
            return
        }
        #expect(rechargeViewModel.currentStep == .answer)
    }

    @MainActor
    @Test("send clears active flow state before generic AI chat")
    func testSendClearsActiveFlowState() async throws {
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: DelayedAIChatService()
        )
        viewModel.activeDomainFlow = .balance(sampleBalanceCard())
        viewModel.currentPaymentCard = sampleRechargePaymentCard()
        viewModel.selectedBillingInvoice = sampleBillingInvoice()

        viewModel.sendMessageText("hello")

        #expect(viewModel.activeDomainFlow == nil)
        #expect(viewModel.currentPaymentCard == nil)
        #expect(viewModel.selectedBillingInvoice == nil)
    }

    @MainActor
    @Test("goBack transitions remain consistent across flow states")
    func testGoBackTransitions() async throws {
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService()
        )

        let offer = sampleAIChatOffer()
        viewModel.selectedOffer = offer
        viewModel.currentStep = .success
        viewModel.goBack()
        #expect(viewModel.currentStep == .offerDetails(offer))

        viewModel.currentStep = .offerDetails(offer)
        viewModel.goBack()
        #expect(viewModel.currentStep == .offersList)

        viewModel.activeDomainFlow = .offers(
            BoltOfferFlowContext(
                title: "Offers",
                message: "Offer flow",
                offers: [offer],
                allowExternalNavigation: true,
                isRoaming: false
            )
        )
        viewModel.currentStep = .offersList
        viewModel.goBack()
        #expect(viewModel.currentStep == .home)
        #expect(viewModel.activeDomainFlow == nil)

        let billingSummary = sampleBillingSummary()
        let invoice = billingSummary.outstandingInvoices[0]
        viewModel.activeDomainFlow = .payment(
            BoltPaymentFlowContext(
                title: "Pay Bill",
                message: "Pay bill",
                paymentCard: sampleBillPaymentCard(invoice: invoice),
                invoice: invoice,
                summary: billingSummary
            )
        )
        viewModel.currentStep = .answer
        viewModel.goBack()
        guard case .billing(let restoredBillingFlow) = viewModel.activeDomainFlow else {
            Issue.record("goBack from payment answer should restore billing flow")
            return
        }
        #expect(restoredBillingFlow.summary == billingSummary)

        viewModel.currentStep = .home
        let stateBefore = viewModel.currentStep
        viewModel.goBack()
        #expect(viewModel.currentStep == stateBefore)
    }

    @MainActor
    @Test("payment success returns to billing flow or clears recharge flow")
    func testPaymentSuccessFlowRestoration() async throws {
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService()
        )

        let billingSummary = sampleBillingSummary()
        let invoice = billingSummary.outstandingInvoices[0]
        viewModel.activeDomainFlow = .payment(
            BoltPaymentFlowContext(
                title: "Pay Bill",
                message: "Pay bill",
                paymentCard: sampleBillPaymentCard(invoice: invoice),
                invoice: invoice,
                summary: billingSummary
            )
        )
        viewModel.currentPaymentCard = sampleBillPaymentCard(invoice: invoice)
        viewModel.handlePaymentResult(
            PaymentResultCard(
                status: .success,
                orderId: "BILL-1",
                amount: 120,
                currency: "AED",
                message: "ok",
                timestamp: Date()
            )
        )

        guard case .billing(let restoredBillingFlow) = viewModel.activeDomainFlow else {
            Issue.record("Bill payment success should restore billing flow")
            return
        }
        #expect(restoredBillingFlow.summary == billingSummary)
        #expect(viewModel.currentPaymentCard == nil)

        viewModel.activeDomainFlow = .recharge(
            BoltRechargeFlowContext(
                title: "Recharge",
                message: "Recharge",
                paymentCard: sampleRechargePaymentCard(),
                serviceNumber: "12345678",
                balanceText: "AED 20.00"
            )
        )
        viewModel.currentPaymentCard = sampleRechargePaymentCard()
        viewModel.handlePaymentResult(
            PaymentResultCard(
                status: .success,
                orderId: "RCH-1",
                amount: 50,
                currency: "AED",
                message: "ok",
                timestamp: Date()
            )
        )

        #expect(viewModel.activeDomainFlow == nil)
    }

    @MainActor
    @Test("payment failure keeps payment card and payment flow for retry")
    func testPaymentFailureRetainsState() async throws {
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService()
        )
        let billingSummary = sampleBillingSummary()
        let invoice = billingSummary.outstandingInvoices[0]
        let paymentCard = sampleBillPaymentCard(invoice: invoice)

        viewModel.activeDomainFlow = .payment(
            BoltPaymentFlowContext(
                title: "Pay Bill",
                message: "Pay bill",
                paymentCard: paymentCard,
                invoice: invoice,
                summary: billingSummary
            )
        )
        viewModel.currentPaymentCard = paymentCard
        viewModel.handlePaymentResult(
            PaymentResultCard(
                status: .failed,
                orderId: nil,
                amount: 120,
                currency: "AED",
                message: "failed",
                timestamp: Date()
            )
        )

        #expect(viewModel.currentPaymentCard == paymentCard)
        guard case .payment = viewModel.activeDomainFlow else {
            Issue.record("Failed payment should remain in payment flow")
            return
        }
    }

    @MainActor
    @Test("confirmNewChat clears conversation and orchestration state")
    func testConfirmNewChatClearsConversationState() async throws {
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService(conversationID: "conv-1")
        )

        viewModel.sendMessageText("hello")
        try await settle()
        #expect(viewModel.conversationID == "conv-1")

        viewModel.activeDomainFlow = .balance(sampleBalanceCard())
        viewModel.currentPaymentCard = sampleRechargePaymentCard()
        viewModel.confirmNewChat()

        #expect(viewModel.conversationID == nil)
        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.activeDomainFlow == nil)
        #expect(viewModel.currentPaymentCard == nil)
        #expect(viewModel.currentStep == .home)
    }

    @MainActor
    @Test("billing to payment flow transition carries invoice context")
    func testBillingToPaymentTransitionCarriesInvoiceContext() async throws {
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService()
        )
        let summary = sampleBillingSummary()
        let invoice = summary.outstandingInvoices[0]
        viewModel.activeDomainFlow = .billing(
            BoltBillingFlowContext(
                title: "Billing",
                message: "Billing summary",
                summary: summary
            )
        )

        viewModel.beginBillingPayment(for: invoice)

        #expect(viewModel.selectedBillingInvoice == invoice)
        guard case .payment(let paymentFlow) = viewModel.activeDomainFlow else {
            Issue.record("Billing transition should switch to payment flow")
            return
        }
        #expect(paymentFlow.invoice == invoice)
        #expect(viewModel.currentPaymentCard?.transactionType == .billPayment)
    }

    @Test("my data is running out routes to offer flow")
    func testMyDataRunningOutRoutesToOfferFlow() async throws {
        let routingService = makeRoutingService()
        let outcome = await routingService.resolve(
            text: "my data is running out",
            result: IntentRecognitionResult(
                intentType: .generalQuestion,
                confidence: 0.74
            ),
            context: sampleContext(),
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let flow) = outcome,
              case .offers = flow
        else {
            Issue.record("Running out of data should route to offer flow")
            return
        }
    }

    @MainActor
    @Test("processImmediately preserves flow when offer identity is incomplete")
    func testProcessImmediatelyWithMissingOfferIdentityPreservesState() async throws {
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService()
        )
        let incompleteOffer = AIChatOffer(
            id: "offer-1",
            name: "Broken Offer",
            price: "10.00",
            dataAmount: "1 GB",
            validity: "Monthly",
            offerId: nil,
            offerCode: nil,
            offerType: "Data",
            validityRaw: "Monthly",
            resourceSummary: "1 GB"
        )
        viewModel.selectedOffer = incompleteOffer
        viewModel.currentStep = .offerDetails(incompleteOffer)

        viewModel.processImmediately()

        #expect(viewModel.subscriptionErrorMessage != nil)
        #expect(viewModel.currentStep == .offerDetails(incompleteOffer))
        #expect(!viewModel.isProcessingSubscription)
    }

    @MainActor
    @Test("presentFollowUp clears active flow and keeps timeline-driven interaction")
    func testPresentFollowUpClearsFlowState() async throws {
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService(),
            intentRecognitionService: StubIntentRecognitionService(
                result: IntentRecognitionResult(intentType: .itineraryQuery, confidence: 0.95)
            ),
            intentRoutingService: StubIntentRoutingService(
                outcome: .presentFollowUp(
                    AIChatReply(
                        conversationID: "follow-up-conv",
                        text: "Which city are you travelling to?",
                        thinkingText: "",
                        actions: [
                            AIChatAction(
                                title: "Open Tickets",
                                target: .tickets,
                                rawValue: "app://tickets"
                            )
                        ]
                    )
                )
            )
        )
        viewModel.activeDomainFlow = .balance(sampleBalanceCard())

        viewModel.processPotentialNavigation(for: "help me get a ticket") {
            Issue.record("Travel follow-up should not hand off to generic chat")
        }
        try await settle()

        #expect(viewModel.activeDomainFlow == nil)
        #expect(viewModel.currentAssistantMessage?.text == "Which city are you travelling to?")
        #expect(viewModel.currentStep == .answer)
    }

    @MainActor
    @Test("handoffToGenericChat clears flow and uses generic timeline path")
    func testHandoffToGenericChatClearsFlowState() async throws {
        let viewModel = AIChatViewModel(
            custSubInfo: .mock,
            language: .english,
            aiChatService: StubAIChatService(replyText: "Generic AI reply"),
            intentRecognitionService: StubIntentRecognitionService(
                result: IntentRecognitionResult(intentType: .generalQuestion, confidence: 0.6)
            ),
            intentRoutingService: StubIntentRoutingService(outcome: .handoffToGenericChat)
        )
        viewModel.activeDomainFlow = .balance(sampleBalanceCard())

        viewModel.processPotentialNavigation(for: "tell me something else") {
            viewModel.sendMessageText("tell me something else")
        }
        try await settle()

        #expect(viewModel.activeDomainFlow == nil)
        #expect(viewModel.currentAssistantMessage?.text == "Generic AI reply")
    }

    @Test("mock and production-like services preserve offer flow contract")
    func testUseCaseSubstitutionPreservesOfferFlowContract() async throws {
        let mockRoutingService = makeRoutingService()
        let prodLikeRoutingService = DefaultIntentRoutingService(
            session: .mock,
            offersService: DeterministicOffersService(),
            billingService: MockBillingService(),
            rechargeService: MockRechargeService()
        )

        let mockOutcome = await mockRoutingService.resolve(
            text: "buy more data",
            result: IntentRecognitionResult(intentType: .viewOffers, confidence: 0.95),
            context: sampleContext(),
            conversationHistory: [],
            language: .english
        )
        let prodLikeOutcome = await prodLikeRoutingService.resolve(
            text: "buy more data",
            result: IntentRecognitionResult(intentType: .viewOffers, confidence: 0.95),
            context: sampleContext(),
            conversationHistory: [],
            language: .english
        )

        guard case .presentDomainFlow(let mockFlow) = mockOutcome,
              case .presentDomainFlow(let prodFlow) = prodLikeOutcome,
              case .offers = mockFlow,
              case .offers = prodFlow
        else {
            Issue.record("Offer contract should remain stable across service substitution")
            return
        }

        #expect(mockFlow.primitiveKinds == prodFlow.primitiveKinds)
    }

    @Test("UI primitive matrix remains stable for each flow type")
    func testUIPrimitiveMatrix() throws {
        let offerFlow = BoltDomainFlow.offers(
            BoltOfferFlowContext(
                title: "Offers",
                message: "Offer flow",
                offers: [sampleAIChatOffer()],
                allowExternalNavigation: true,
                isRoaming: false
            )
        )
        #expect(offerFlow.primitiveKinds == [.listCard, .detailCard, .actionGroup, .resultCard])

        let rechargeFlow = BoltDomainFlow.recharge(
            BoltRechargeFlowContext(
                title: "Recharge",
                message: "Recharge flow",
                paymentCard: sampleRechargePaymentCard(),
                serviceNumber: "12345678",
                balanceText: "AED 20.00"
            )
        )
        #expect(rechargeFlow.primitiveKinds == [.formCard, .paymentCard, .resultCard])

        let balanceFlow = BoltDomainFlow.balance(sampleBalanceCard())
        #expect(balanceFlow.primitiveKinds == [.answerCard, .resultCard])

        let serviceFollowUpFlow = BoltDomainFlow.serviceRequest(
            BoltServiceFlowContext(
                title: "Service Support",
                message: "Need one more detail",
                followUpQuestion: "What issue is this?",
                suggestedReplies: ["Network"],
                submissionResult: nil
            )
        )
        #expect(serviceFollowUpFlow.primitiveKinds == [.followUpCard, .formCard])
    }

    @MainActor
    private func settle() async throws {
        try await Task.sleep(nanoseconds: 350_000_000)
    }

    private func makeRoutingService() -> DefaultIntentRoutingService {
        DefaultIntentRoutingService(
            session: .mock,
            offersService: MockOffersService(),
            billingService: MockBillingService(),
            rechargeService: MockRechargeService()
        )
    }

    private func sampleContext() -> AIChatContext {
        AIChatContext(
            accessToken: "test",
            authorization: "Bearer test",
            userID: "user_123",
            serviceNumber: "12345678",
            subscriberKey: "sub_key",
            languageCode: "en",
            displayName: "Test User"
        )
    }

    private func sampleAIChatOffer() -> AIChatOffer {
        AIChatOffer(
            id: "offer-1",
            name: "Data Booster 10 GB",
            price: "25.00",
            dataAmount: "10 GB",
            validity: "Monthly",
            offerId: "offer-1",
            offerCode: "DATA-10G",
            offerType: "Data",
            validityRaw: "Monthly",
            resourceSummary: "10 GB"
        )
    }

    private func sampleRechargePaymentCard() -> AIChatPaymentCard {
        AIChatPaymentCard(
            transactionType: .recharge,
            amountOptions: PaymentAmountOptions(
                min: 10,
                max: 500,
                defaultAmount: 50,
                quickAmounts: [10, 20, 50, 100],
                currency: "AED"
            ),
            paymentMethods: samplePaymentMethods(),
            subscriberInfo: PaymentSubscriberInfo(
                serviceNumber: "12345678",
                currentBalance: "AED 20.00"
            )
        )
    }

    private func sampleBillPaymentCard(invoice: BillingInvoice) -> AIChatPaymentCard {
        let amount = BillingNumberParser.decimal(invoice.openAmountRaw) ?? 120
        return AIChatPaymentCard(
            transactionType: .billPayment,
            amountOptions: PaymentAmountOptions(
                min: amount,
                max: amount,
                defaultAmount: amount,
                quickAmounts: [amount],
                currency: "AED"
            ),
            paymentMethods: samplePaymentMethods(),
            subscriberInfo: PaymentSubscriberInfo(
                serviceNumber: "12345678",
                currentBalance: nil
            )
        )
    }

    private func samplePaymentMethods() -> [PaymentMethodOption] {
        [
            PaymentMethodOption(
                id: "tabby",
                name: "Tabby BNPL",
                description: "Split in 4 installments",
                iconType: .tabby,
                installmentOptions: [
                    InstallmentOption(installments: 4, amountPerInstallment: 12.50)
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
            )
        ]
    }

    private func sampleBillingSummary() -> BillingSummarySnapshot {
        BillingSummarySnapshot(
            summary: BillingSummary(
                totalDueAmountRaw: "120.00",
                totalDueAmountText: "120.00 AED",
                dueDateText: "2026-05-10",
                unbilledAmountRaw: "30.00",
                unbilledAmountText: "30.00 AED",
                remainingCreditText: "180.00 AED",
                totalUsageText: "310.00 AED",
                totalCreditText: "500.00 AED",
                accountCode: "ACC-1"
            ),
            outstandingInvoices: [
                sampleBillingInvoice()
            ]
        )
    }

    private func sampleBillingInvoice() -> BillingInvoice {
        BillingInvoice(
            id: "invoice-1",
            invoiceId: "invoice-1",
            invoiceNo: "INV-20260501",
            billCycleID: "cycle-1",
            currencyId: "AED",
            invoiceAmountRaw: "120.00",
            openAmountRaw: "120.00",
            taxAmountRaw: "0.00",
            invoiceAmountText: "120.00 AED",
            openAmountText: "120.00 AED",
            taxAmountText: "0.00 AED",
            invoiceDateText: "2026-05-01",
            dueDateText: "2026-05-10",
            billCycleBeginText: "2026-04-01",
            statusCode: "O",
            status: .outstanding
        )
    }

    private func sampleBalanceCard() -> BoltInfoCard {
        BoltInfoCard(
            title: "Current Balance",
            accentValue: "AED 100.00",
            accentCaption: "Available now",
            detailLines: [
                BoltInfoLine(title: "Service number", value: "12345678")
            ],
            footnote: "Balance questions stay in Bolt by default."
        )
    }
}

private struct StubIntentRecognitionService: IntentRecognitionServicing {
    let result: IntentRecognitionResult

    func localMatch(text: String, language: AppLanguage) async -> IntentRecognitionResult? {
        result
    }

    func aiSemanticMatch(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage]
    ) async throws -> IntentRecognitionResult {
        result
    }

    func recognizeIntent(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async throws -> IntentRecognitionResult {
        result
    }
}

private struct ThrowingIntentRecognitionService: IntentRecognitionServicing {
    enum Error: Swift.Error {
        case failed
    }

    func localMatch(text: String, language: AppLanguage) async -> IntentRecognitionResult? {
        nil
    }

    func aiSemanticMatch(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage]
    ) async throws -> IntentRecognitionResult {
        throw Error.failed
    }

    func recognizeIntent(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async throws -> IntentRecognitionResult {
        throw Error.failed
    }
}

private struct StubIntentRoutingService: IntentRoutingServicing {
    let outcome: IntentRoutingOutcome

    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome {
        outcome
    }
}

private struct StubAIChatService: AIChatServicing {
    var conversationID: String = UUID().uuidString
    var replyText: String = "Generic reply"

    func sendMessage(
        _ text: String,
        conversationID: String?,
        context: AIChatContext,
        metadata: AIChatRequestMetadata?
    ) async throws -> AIChatReply {
        AIChatReply(
            conversationID: self.conversationID,
            text: replyText,
            thinkingText: "",
            actions: []
        )
    }
}

private struct DelayedAIChatService: AIChatServicing {
    func sendMessage(
        _ text: String,
        conversationID: String?,
        context: AIChatContext,
        metadata: AIChatRequestMetadata?
    ) async throws -> AIChatReply {
        try await Task.sleep(nanoseconds: 500_000_000)
        return AIChatReply(
            conversationID: "delayed-conv",
            text: "Delayed reply",
            thinkingText: "",
            actions: []
        )
    }
}

private struct StubTicketsService: TicketsServicing {
    let url: URL

    func fetchTicketURL() async throws -> URL {
        url
    }
}

private actor DeterministicOffersService: OffersServicing {
    func fetchLanding(session: CustSubInfo) async throws -> OffersLandingSnapshot {
        OffersLandingSnapshot(
            primaryOffer: PrimaryOfferSummary(
                offerId: "primary",
                offerCode: "PRIMARY",
                offerName: "Primary",
                effectiveDate: "2026-05-01",
                expiryDate: "2026-06-01"
            ),
            subscribedOffers: []
        )
    }

    func fetchSubscribedOffers(session: CustSubInfo) async throws -> [SubscribedOfferItem] { [] }
    func fetchCategories(session: CustSubInfo) async throws -> [OfferCategoryItem] { [] }
    func fetchDIYBootstrap(session: CustSubInfo) async throws -> DIYOfferBootstrap {
        DIYOfferBootstrap(periods: [], currencyCode: "AED", currencyName: "AED", cbsAccuracy: 2)
    }

    func calculateDIYPrice(
        _ request: DIYOfferPricingRequest,
        session: CustSubInfo
    ) async throws -> DIYOfferPricing {
        DIYOfferPricing(
            totalAmount: "10.00",
            currencyName: "AED",
            items: []
        )
    }

    func submitDIYOffer(
        _ request: DIYOfferSubmissionRequest,
        session: CustSubInfo
    ) async throws -> OfferAcceptedResult {
        OfferAcceptedResult(orderId: "DIY-1", offerName: "DIY", operationType: .subscribe)
    }

    func fetchOrders(
        session: CustSubInfo,
        filter: OffersOrderFilter,
        pageIndex: Int,
        pageSize: Int
    ) async throws -> OffersOrderPageSnapshot {
        OffersOrderPageSnapshot(records: [], pageIndex: 1, pageSize: 20, totalCount: 0, totalPages: 1)
    }

    func fetchEligibleOffers(
        session: CustSubInfo,
        resourceType: OffersResourceType,
        categoryId: String?
    ) async throws -> [EligibleOfferItem] {
        [
            EligibleOfferItem(
                id: "det-1",
                offerId: "det-1",
                offerCode: "DET-1",
                offerName: "Deterministic Data 5 GB",
                offerType: "Data",
                validityRaw: "Monthly",
                validityBucket: .monthly,
                resourceSummary: "5 GB",
                displayPriceText: "15.00 AED",
                displayPriceValue: 15,
                popularRank: 1,
                originalIndex: 0
            )
        ]
    }

    func submitChange(_ request: OfferChangeRequest, session: CustSubInfo) async throws -> OfferAcceptedResult {
        OfferAcceptedResult(orderId: "SUB-1", offerName: "Deterministic Data 5 GB", operationType: .subscribe)
    }
}
