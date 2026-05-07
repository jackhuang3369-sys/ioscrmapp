import Foundation

enum IntentRoutingOutcome {
    case presentDomainFlow(BoltDomainFlow)
    case presentFollowUp(AIChatReply)
    case navigateExplicitly(AIChatNavigationTarget)
    case handoffToGenericChat
}

protocol IntentRoutingServicing {
    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome
}

enum NavigationPolicyDecision: Equatable {
    case domainFirst
    case navigateExplicitly(AIChatNavigationTarget)
}

struct NavigationPolicy {
    func decide(text: String, result: IntentRecognitionResult) -> NavigationPolicyDecision {
        if let explicitTarget = explicitNavigationTarget(from: text) {
            return .navigateExplicitly(explicitTarget)
        }

        if result.intentType == .navigationIntent, let target = result.navigationTarget {
            return .navigateExplicitly(target)
        }

        return .domainFirst
    }

    private func explicitNavigationTarget(from text: String) -> AIChatNavigationTarget? {
        let normalized = normalize(text)

        let englishTargets: [(AIChatNavigationTarget, [String])] = [
            (.offers, ["offer", "offers", "package", "packages"]),
            (.billing, ["bill", "billing", "invoice"]),
            (.recharge, ["recharge", "top up", "topup"]),
            (.tickets, ["tickets", "ticket", "travel"]),
            (.service, ["service"]),
            (.home, ["home"]),
            (.me, ["profile", "me", "account page"])
        ]
        let chineseTargets: [(AIChatNavigationTarget, [String])] = [
            (.offers, ["优惠页面", "套餐页面", "优惠页", "套餐页"]),
            (.billing, ["账单页面", "账单页"]),
            (.recharge, ["充值页面", "充值页"]),
            (.tickets, ["票务页面", "票务页", "机票页面"]),
            (.service, ["服务页面", "服务页"]),
            (.home, ["首页", "主页"]),
            (.me, ["我的页面", "个人页面", "我的主页"])
        ]
        let arabicTargets: [(AIChatNavigationTarget, [String])] = [
            (.offers, ["صفحة العروض", "شاشة العروض"]),
            (.billing, ["صفحة الفاتورة", "شاشة الفاتورة"]),
            (.recharge, ["صفحة الشحن", "شاشة الشحن"]),
            (.tickets, ["صفحة التذاكر", "شاشة التذاكر"]),
            (.service, ["صفحة الخدمات", "شاشة الخدمات"])
        ]

        if matchesExplicitNavigation(
            normalized,
            verbs: ["open", "go to", "navigate to", "take me to", "show me"],
            pageWords: ["page", "screen", "tab", "section"],
            targets: englishTargets
        ) {
            return matchedTarget(
                normalized,
                targets: englishTargets
            )
        }

        if matchesExplicitNavigation(
            normalized,
            verbs: ["打开", "进入", "跳转到", "去"],
            pageWords: ["页面", "页", "界面", "标签"],
            targets: chineseTargets
        ) {
            return matchedTarget(
                normalized,
                targets: chineseTargets
            )
        }

        if matchesExplicitNavigation(
            normalized,
            verbs: ["افتح", "اذهب إلى", "انتقل إلى"],
            pageWords: ["صفحة", "شاشة"],
            targets: arabicTargets
        ) {
            return matchedTarget(
                normalized,
                targets: arabicTargets
            )
        }

        return nil
    }

    private func matchesExplicitNavigation(
        _ normalized: String,
        verbs: [String],
        pageWords: [String],
        targets: [(AIChatNavigationTarget, [String])]
    ) -> Bool {
        let hasVerb = verbs.contains { normalized.contains($0) }
        let hasPageWord = pageWords.contains { normalized.contains($0) }
        let hasTargetWord = targets.contains { _, keywords in
            keywords.contains { normalized.contains($0) }
        }

        return (hasVerb && hasTargetWord && hasPageWord) || (hasTargetWord && hasPageWord)
    }

    private func matchedTarget(
        _ normalized: String,
        targets: [(AIChatNavigationTarget, [String])]
    ) -> AIChatNavigationTarget? {
        for (target, keywords) in targets {
            if keywords.contains(where: { normalized.contains($0) }) {
                return target
            }
        }
        return nil
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(
                of: #"[^a-z0-9\u{4e00}-\u{9fff}\u{0600}-\u{06ff}\s]"#,
                with: " ",
                options: .regularExpression
            )
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

protocol BoltTelecomDomainFlowHandling {
    func canHandle(text: String, result: IntentRecognitionResult) -> Bool

    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome?
}

protocol RecommendOffersUseCase: Sendable {
    func execute(goal: BoltOfferGoal, session: CustSubInfo) async throws -> [AIChatOffer]
}

protocol SubscribeOfferUseCase: Sendable {
    func execute(offer: AIChatOffer, session: CustSubInfo) async throws -> OfferAcceptedResult
}

protocol PrepareRechargeFlowUseCase: Sendable {
    func execute(session: CustSubInfo, language: AppLanguage) async throws -> BoltRechargeFlowContext
}

protocol ExecuteRechargeUseCase: Sendable {
    func execute(
        amount: Decimal,
        methodId: String,
        context: PaymentContext,
        session: CustSubInfo
    ) async throws -> PaymentResultCard
}

protocol FetchBillingFlowUseCase: Sendable {
    func execute(session: CustSubInfo, language: AppLanguage) async throws -> BoltBillingFlowContext
}

protocol BuildBillPaymentFlowUseCase: Sendable {
    func execute(session: CustSubInfo, language: AppLanguage) async throws -> BoltPaymentFlowContext
}

protocol PayBillUseCase: Sendable {
    func execute(
        invoice: BillingInvoice,
        methodId: String,
        context: PaymentContext,
        session: CustSubInfo
    ) async throws -> PaymentResultCard
}

protocol QueryBalanceUseCase: Sendable {
    func execute(session: CustSubInfo, language: AppLanguage) async -> BoltInfoCard
}

protocol QueryUsageUseCase: Sendable {
    func execute(
        intentType: UserIntentType,
        session: CustSubInfo,
        language: AppLanguage
    ) async -> BoltInfoCard
}

protocol SubmitServiceRequestUseCase: Sendable {
    func execute(text: String, session: CustSubInfo, language: AppLanguage) async -> BoltServiceSubmissionResult
}

enum BoltOfferGoal: Sendable {
    case moreData
    case browseOffers
    case roaming
}

struct DefaultRecommendOffersUseCase: RecommendOffersUseCase {
    private let offersService: any OffersServicing

    init(offersService: any OffersServicing) {
        self.offersService = offersService
    }

    func execute(goal: BoltOfferGoal, session: CustSubInfo) async throws -> [AIChatOffer] {
        do {
            let eligibleOffers = try await offersService.fetchEligibleOffers(
                session: session,
                resourceType: .data,
                categoryId: nil
            )
            let mapped = eligibleOffers.enumerated().map { index, item in
                mapEligibleOffer(item, fallbackIndex: index)
            }
            return mapped.isEmpty ? Self.fallbackOffers(for: goal) : mapped
        } catch {
            return Self.fallbackOffers(for: goal)
        }
    }

    private func mapEligibleOffer(_ item: EligibleOfferItem, fallbackIndex: Int) -> AIChatOffer {
        let priceText = item.displayPriceText ?? (item.displayPriceValue.map { "\(BillingNumberParser.string($0)) AED" } ?? "0.00 AED")
        let numericPrice = BillingNumberParser.normalized(priceText) ?? "0.00"

        return AIChatOffer(
            id: item.id.isEmpty ? "bolt-offer-\(fallbackIndex)" : item.id,
            name: item.offerName,
            price: numericPrice,
            dataAmount: item.resourceSummary ?? item.offerType,
            validity: item.validityRaw ?? item.validityBucket?.rawValue.capitalized ?? "Monthly",
            offerId: item.offerId,
            offerCode: item.offerCode,
            offerType: item.offerType,
            validityRaw: item.validityRaw,
            resourceSummary: item.resourceSummary
        )
    }

    private static func fallbackOffers(for goal: BoltOfferGoal) -> [AIChatOffer] {
        let baseOffers = [
            AIChatOffer(
                id: "offer-roaming-10g",
                name: "DataRoamingPrice (10 GB)",
                price: "15.00",
                dataAmount: "10 GB",
                validity: "Monthly",
                offerId: "offer-roaming-10g",
                offerCode: "ROAM-10G",
                offerType: "Data",
                validityRaw: "Monthly",
                resourceSummary: "10 GB"
            ),
            AIChatOffer(
                id: "offer-roaming-20g",
                name: "DataRoamingPrice (20 GB)",
                price: "35.00",
                dataAmount: "20 GB",
                validity: "Monthly",
                offerId: "offer-roaming-20g",
                offerCode: "ROAM-20G",
                offerType: "Data",
                validityRaw: "Monthly",
                resourceSummary: "20 GB"
            ),
            AIChatOffer(
                id: "offer-roaming-50g",
                name: "DataRoamingPrice (50 GB)",
                price: "55.00",
                dataAmount: "50 GB",
                validity: "Monthly",
                offerId: "offer-roaming-50g",
                offerCode: "ROAM-50G",
                offerType: "Data",
                validityRaw: "Monthly",
                resourceSummary: "50 GB"
            )
        ]

        switch goal {
        case .roaming:
            return baseOffers
        case .moreData, .browseOffers:
            return baseOffers + [
                AIChatOffer(
                    id: "offer-unlimited-data",
                    name: "Unlimited Data Max",
                    price: "120.00",
                    dataAmount: "Unlimited",
                    validity: "Monthly",
                    offerId: "offer-unlimited-data",
                    offerCode: "DATA-UNLIMITED",
                    offerType: "Data",
                    validityRaw: "Monthly",
                    resourceSummary: "Unlimited"
                )
            ]
        }
    }
}

struct DefaultSubscribeOfferUseCase: SubscribeOfferUseCase {
    private let offersService: any OffersServicing

    init(offersService: any OffersServicing) {
        self.offersService = offersService
    }

    func execute(offer: AIChatOffer, session: CustSubInfo) async throws -> OfferAcceptedResult {
        let eligibleOffer = EligibleOfferItem(
            id: offer.id,
            offerId: offer.offerId ?? offer.id,
            offerCode: offer.offerCode ?? offer.id,
            offerName: offer.name,
            offerType: offer.offerType ?? "Data",
            validityRaw: offer.validityRaw ?? offer.validity,
            validityBucket: nil,
            resourceSummary: offer.resourceSummary ?? offer.dataAmount,
            displayPriceText: "\(offer.price) \(offer.currency)",
            displayPriceValue: BillingNumberParser.decimal(offer.price),
            popularRank: nil,
            originalIndex: 0
        )

        return try await offersService.submitChange(.subscribe(eligibleOffer), session: session)
    }
}

struct DefaultPrepareRechargeFlowUseCase: PrepareRechargeFlowUseCase {
    private let rechargeService: any RechargeServicing

    init(rechargeService: any RechargeServicing) {
        self.rechargeService = rechargeService
    }

    func execute(session: CustSubInfo, language: AppLanguage) async throws -> BoltRechargeFlowContext {
        let snapshot = try await rechargeService.fetchEntrySnapshot(session: session)
        return BoltRechargeFlowContext(
            title: localizedTitle(for: language),
            message: localizedMessage(for: language, serviceNumber: snapshot.serviceNumber),
            paymentCard: BoltPaymentCardFactory.makeRechargeCard(entrySnapshot: snapshot),
            serviceNumber: snapshot.serviceNumber,
            balanceText: snapshot.balanceText
        )
    }

    private func localizedTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Recharge In Bolt"
        case .simplifiedChinese:
            return "Bolt 内充值"
        case .arabic:
            return "إعادة الشحن داخل Bolt"
        }
    }

    private func localizedMessage(for language: AppLanguage, serviceNumber: String) -> String {
        switch language {
        case .english:
            return "Choose a recharge amount for \(serviceNumber), then confirm the payment method without leaving Bolt."
        case .simplifiedChinese:
            return "直接在 Bolt 内为 \(serviceNumber) 选择充值金额并确认支付方式。"
        case .arabic:
            return "اختر مبلغ الشحن للرقم \(serviceNumber) ثم أكد طريقة الدفع داخل Bolt."
        }
    }
}

struct DefaultExecuteRechargeUseCase: ExecuteRechargeUseCase {
    private let rechargeService: any RechargeServicing

    init(rechargeService: any RechargeServicing) {
        self.rechargeService = rechargeService
    }

    func execute(
        amount: Decimal,
        methodId: String,
        context: PaymentContext,
        session: CustSubInfo
    ) async throws -> PaymentResultCard {
        let request = RechargeSubmissionRequest(
            amountText: BillingNumberParser.string(amount),
            paymentMethod: mapRechargeMethod(methodId),
            otpCode: ""
        )
        let receipt = try await rechargeService.submitRecharge(request, session: session)

        return PaymentResultCard(
            status: .success,
            orderId: receipt.orderId,
            amount: amount,
            currency: "AED",
            message: localizedRechargeMessage(for: context.languageCode, amountText: receipt.amountText),
            timestamp: Date()
        )
    }

    private func mapRechargeMethod(_ methodId: String) -> RechargePaymentMethod {
        switch methodId {
        case "apple_pay":
            return .applePay
        case "google_pay":
            return .bankTransfer
        default:
            return .creditCard
        }
    }

    private func localizedRechargeMessage(for languageCode: String, amountText: String) -> String {
        switch languageCode {
        case "zh-Hans":
            return "充值申请已提交：\(amountText)"
        case "ar":
            return "تم إرسال طلب الشحن: \(amountText)"
        default:
            return "Recharge submitted successfully: \(amountText)"
        }
    }
}

struct DefaultFetchBillingFlowUseCase: FetchBillingFlowUseCase {
    private let billingService: any BillingServicing

    init(billingService: any BillingServicing) {
        self.billingService = billingService
    }

    func execute(session: CustSubInfo, language: AppLanguage) async throws -> BoltBillingFlowContext {
        let summary = try await billingService.fetchSummary(session: session)
        return BoltBillingFlowContext(
            title: localizedTitle(for: language),
            message: localizedMessage(for: language),
            summary: summary
        )
    }

    private func localizedTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Bill Summary"
        case .simplifiedChinese:
            return "账单摘要"
        case .arabic:
            return "ملخص الفاتورة"
        }
    }

    private func localizedMessage(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Review outstanding invoices and choose one to pay inside Bolt."
        case .simplifiedChinese:
            return "直接在 Bolt 内查看未支付账单，并选择一笔继续支付。"
        case .arabic:
            return "راجع الفواتير المستحقة واختر واحدة للدفع داخل Bolt."
        }
    }
}

struct DefaultBuildBillPaymentFlowUseCase: BuildBillPaymentFlowUseCase {
    private let billingService: any BillingServicing

    init(billingService: any BillingServicing) {
        self.billingService = billingService
    }

    func execute(session: CustSubInfo, language: AppLanguage) async throws -> BoltPaymentFlowContext {
        let summary = try await billingService.fetchSummary(session: session)
        let invoice = summary.outstandingInvoices.first
        let paymentCard = BoltPaymentCardFactory.makeBillPaymentCard(
            invoice: invoice,
            serviceNumber: session.serviceNumber ?? session.phoneNumber
        )

        return BoltPaymentFlowContext(
            title: localizedTitle(for: language),
            message: localizedMessage(for: language, invoice: invoice),
            paymentCard: paymentCard,
            invoice: invoice,
            summary: summary
        )
    }

    private func localizedTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Pay Bill In Bolt"
        case .simplifiedChinese:
            return "Bolt 内支付账单"
        case .arabic:
            return "دفع الفاتورة داخل Bolt"
        }
    }

    private func localizedMessage(for language: AppLanguage, invoice: BillingInvoice?) -> String {
        guard let invoice else {
            switch language {
            case .english:
                return "No outstanding invoice was found. Open Billing only if you explicitly want the full page."
            case .simplifiedChinese:
                return "当前没有可支付账单；只有明确要求时才建议打开完整账单页。"
            case .arabic:
                return "لا توجد فاتورة مستحقة حالياً. افتح صفحة الفواتير فقط إذا كنت تريد الصفحة الكاملة صراحةً."
            }
        }

        switch language {
        case .english:
            return "The oldest outstanding invoice is \(invoice.invoiceNo) for \(invoice.openAmountText). Confirm the payment method below."
        case .simplifiedChinese:
            return "当前最早的一笔未支付账单是 \(invoice.invoiceNo)，金额 \(invoice.openAmountText)。请在下方确认支付方式。"
        case .arabic:
            return "أقدم فاتورة مستحقة هي \(invoice.invoiceNo) بقيمة \(invoice.openAmountText). أكد طريقة الدفع أدناه."
        }
    }
}

struct DefaultPayBillUseCase: PayBillUseCase {
    private let billingService: any BillingServicing

    init(billingService: any BillingServicing) {
        self.billingService = billingService
    }

    func execute(
        invoice: BillingInvoice,
        methodId: String,
        context: PaymentContext,
        session: CustSubInfo
    ) async throws -> PaymentResultCard {
        let request = BillingPaymentRequest(
            context: .invoice(invoice: invoice),
            amountText: invoice.openAmountRaw,
            paymentMethod: mapBillingMethod(methodId)
        )
        let submission = try await billingService.submitPayment(request, session: session)

        return PaymentResultCard(
            status: .success,
            orderId: submission.orderId,
            amount: BillingNumberParser.decimal(invoice.openAmountRaw) ?? 0,
            currency: "AED",
            message: localizedBillPaymentMessage(for: context.languageCode, invoiceNo: invoice.invoiceNo),
            timestamp: Date()
        )
    }

    private func mapBillingMethod(_ methodId: String) -> BillingPaymentMethod {
        switch methodId {
        case "apple_pay":
            return .applePay
        case "google_pay":
            return .samsungPay
        default:
            return .creditCard
        }
    }

    private func localizedBillPaymentMessage(for languageCode: String, invoiceNo: String) -> String {
        switch languageCode {
        case "zh-Hans":
            return "账单 \(invoiceNo) 支付已提交。"
        case "ar":
            return "تم إرسال دفعة الفاتورة \(invoiceNo)."
        default:
            return "Bill payment for \(invoiceNo) was submitted successfully."
        }
    }
}

struct DefaultQueryBalanceUseCase: QueryBalanceUseCase {
    func execute(session: CustSubInfo, language: AppLanguage) async -> BoltInfoCard {
        let lines: [BoltInfoLine] = [
            BoltInfoLine(title: localizedServiceNumberLabel(for: language), value: session.serviceNumber ?? session.phoneNumber),
            BoltInfoLine(title: localizedSupportLabel(for: language), value: localizedSupportValue(for: language))
        ]

        return BoltInfoCard(
            title: localizedTitle(for: language),
            accentValue: session.balanceText,
            accentCaption: localizedAccentCaption(for: language),
            detailLines: lines,
            footnote: localizedFootnote(for: language)
        )
    }

    private func localizedTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Current Balance"
        case .simplifiedChinese:
            return "当前余额"
        case .arabic:
            return "الرصيد الحالي"
        }
    }

    private func localizedAccentCaption(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Available now"
        case .simplifiedChinese:
            return "当前可用"
        case .arabic:
            return "المتاح الآن"
        }
    }

    private func localizedServiceNumberLabel(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Service number"
        case .simplifiedChinese:
            return "业务号码"
        case .arabic:
            return "رقم الخدمة"
        }
    }

    private func localizedSupportLabel(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Next step"
        case .simplifiedChinese:
            return "下一步"
        case .arabic:
            return "الخطوة التالية"
        }
    }

    private func localizedSupportValue(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Recharge in Bolt if you need more credit."
        case .simplifiedChinese:
            return "如果余额不足，可以直接在 Bolt 内继续充值。"
        case .arabic:
            return "إذا احتجت إلى رصيد إضافي، يمكنك متابعة الشحن داخل Bolt."
        }
    }

    private func localizedFootnote(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Balance questions stay in Bolt by default."
        case .simplifiedChinese:
            return "余额查询默认留在 Bolt 内完成。"
        case .arabic:
            return "تظل استفسارات الرصيد داخل Bolt بشكل افتراضي."
        }
    }
}

struct DefaultQueryUsageUseCase: QueryUsageUseCase {
    func execute(
        intentType: UserIntentType,
        session: CustSubInfo,
        language: AppLanguage
    ) async -> BoltInfoCard {
        let detailLines: [BoltInfoLine]
        let accentValue: String

        switch (intentType, language) {
        case (.voiceUsageQuery, .english):
            accentValue = "120 min left"
            detailLines = [
                BoltInfoLine(title: "Data", value: "18.5 GB left"),
                BoltInfoLine(title: "Cycle", value: "Resets in 6 days")
            ]
        case (.voiceUsageQuery, .simplifiedChinese):
            accentValue = "剩余 120 分钟"
            detailLines = [
                BoltInfoLine(title: "流量", value: "剩余 18.5 GB"),
                BoltInfoLine(title: "周期", value: "6 天后重置")
            ]
        case (.voiceUsageQuery, .arabic):
            accentValue = "120 دقيقة متبقية"
            detailLines = [
                BoltInfoLine(title: "البيانات", value: "المتبقي 18.5 جيجابايت"),
                BoltInfoLine(title: "الدورة", value: "إعادة الضبط بعد 6 أيام")
            ]
        case (.smsUsageQuery, .english):
            accentValue = "42 SMS left"
            detailLines = [
                BoltInfoLine(title: "Allowance", value: "42 / 100 SMS"),
                BoltInfoLine(title: "Cycle", value: "Resets in 6 days")
            ]
        case (.smsUsageQuery, .simplifiedChinese):
            accentValue = "剩余 42 条短信"
            detailLines = [
                BoltInfoLine(title: "套餐额度", value: "42 / 100 条短信"),
                BoltInfoLine(title: "周期", value: "6 天后重置")
            ]
        case (.smsUsageQuery, .arabic):
            accentValue = "42 رسالة متبقية"
            detailLines = [
                BoltInfoLine(title: "الباقة", value: "42 / 100 رسالة"),
                BoltInfoLine(title: "الدورة", value: "إعادة الضبط بعد 6 أيام")
            ]
        default:
            switch language {
            case .english:
                accentValue = "18.5 GB left"
                detailLines = [
                    BoltInfoLine(title: "Voice", value: "120 min left"),
                    BoltInfoLine(title: "Cycle", value: "Resets in 6 days")
                ]
            case .simplifiedChinese:
                accentValue = "剩余 18.5 GB"
                detailLines = [
                    BoltInfoLine(title: "语音", value: "剩余 120 分钟"),
                    BoltInfoLine(title: "周期", value: "6 天后重置")
                ]
            case .arabic:
                accentValue = "المتبقي 18.5 جيجابايت"
                detailLines = [
                    BoltInfoLine(title: "المكالمات", value: "120 دقيقة متبقية"),
                    BoltInfoLine(title: "الدورة", value: "إعادة الضبط بعد 6 أيام")
                ]
            }
        }

        return BoltInfoCard(
            title: localizedTitle(for: language, intentType: intentType),
            accentValue: accentValue,
            accentCaption: localizedCaption(for: language, intentType: intentType),
            detailLines: detailLines + [
                BoltInfoLine(title: localizedServiceNumberLabel(for: language), value: session.serviceNumber ?? session.phoneNumber)
            ],
            footnote: localizedFootnote(for: language)
        )
    }

    private func localizedTitle(for language: AppLanguage, intentType: UserIntentType) -> String {
        switch (intentType, language) {
        case (.voiceUsageQuery, .english):
            return "Voice Usage Snapshot"
        case (.voiceUsageQuery, .simplifiedChinese):
            return "语音用量快照"
        case (.voiceUsageQuery, .arabic):
            return "ملخص استخدام المكالمات"
        case (.smsUsageQuery, .english):
            return "SMS Usage Snapshot"
        case (.smsUsageQuery, .simplifiedChinese):
            return "短信用量快照"
        case (.smsUsageQuery, .arabic):
            return "ملخص استخدام الرسائل"
        default:
            switch language {
            case .english:
                return "Data Usage Snapshot"
            case .simplifiedChinese:
                return "用量快照"
            case .arabic:
                return "ملخص الاستخدام"
            }
        }
    }

    private func localizedCaption(for language: AppLanguage, intentType: UserIntentType) -> String {
        switch (intentType, language) {
        case (.voiceUsageQuery, .english):
            return "Minutes remaining"
        case (.voiceUsageQuery, .simplifiedChinese):
            return "分钟剩余"
        case (.voiceUsageQuery, .arabic):
            return "الدقائق المتبقية"
        case (.smsUsageQuery, .english):
            return "Messages remaining"
        case (.smsUsageQuery, .simplifiedChinese):
            return "短信剩余"
        case (.smsUsageQuery, .arabic):
            return "الرسائل المتبقية"
        default:
            switch language {
            case .english:
                return "Data remaining"
            case .simplifiedChinese:
                return "流量剩余"
            case .arabic:
                return "البيانات المتبقية"
            }
        }
    }

    private func localizedServiceNumberLabel(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Service number"
        case .simplifiedChinese:
            return "业务号码"
        case .arabic:
            return "رقم الخدمة"
        }
    }

    private func localizedFootnote(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Usage questions stay inside Bolt unless you explicitly ask for a page."
        case .simplifiedChinese:
            return "用量查询默认在 Bolt 内完成，除非你明确要求打开页面。"
        case .arabic:
            return "تظل أسئلة الاستخدام داخل Bolt ما لم تطلب فتح صفحة بشكل صريح."
        }
    }
}

struct DefaultSubmitServiceRequestUseCase: SubmitServiceRequestUseCase {
    func execute(text: String, session: CustSubInfo, language: AppLanguage) async -> BoltServiceSubmissionResult {
        let reference = "SR-\(UUID().uuidString.prefix(8).uppercased())"

        switch language {
        case .english:
            return BoltServiceSubmissionResult(
                title: "Service Request Submitted",
                message: "We captured your request for \(session.serviceNumber ?? session.phoneNumber). A specialist will follow up with reference \(reference).",
                reference: reference
            )
        case .simplifiedChinese:
            return BoltServiceSubmissionResult(
                title: "服务请求已提交",
                message: "我们已经为 \(session.serviceNumber ?? session.phoneNumber) 提交服务请求，后续可使用参考号 \(reference) 跟进。",
                reference: reference
            )
        case .arabic:
            return BoltServiceSubmissionResult(
                title: "تم إرسال طلب الخدمة",
                message: "تم تسجيل طلبك للرقم \(session.serviceNumber ?? session.phoneNumber)، ويمكنك المتابعة عبر المرجع \(reference).",
                reference: reference
            )
        }
    }
}

struct DefaultIntentRoutingService: IntentRoutingServicing {
    private let navigationPolicy: NavigationPolicy
    private let handlers: [any BoltTelecomDomainFlowHandling]

    init(
        session: CustSubInfo = .mock,
        offersService: any OffersServicing = MockOffersService(),
        billingService: any BillingServicing = MockBillingService(),
        rechargeService: any RechargeServicing = MockRechargeService(),
        navigationPolicy: NavigationPolicy = NavigationPolicy()
    ) {
        self.navigationPolicy = navigationPolicy

        let recommendOffersUseCase = DefaultRecommendOffersUseCase(offersService: offersService)
        let fetchBillingFlowUseCase = DefaultFetchBillingFlowUseCase(billingService: billingService)

        handlers = [
            TravelIntentDomainHandler(),
            RoamingFlowHandler(
                session: session,
                recommendOffersUseCase: recommendOffersUseCase
            ),
            OfferFlowHandler(
                session: session,
                recommendOffersUseCase: recommendOffersUseCase
            ),
            RechargeFlowHandler(
                session: session,
                prepareRechargeFlowUseCase: DefaultPrepareRechargeFlowUseCase(rechargeService: rechargeService)
            ),
            PaymentFlowHandler(
                session: session,
                buildBillPaymentFlowUseCase: DefaultBuildBillPaymentFlowUseCase(billingService: billingService)
            ),
            BillingFlowHandler(
                session: session,
                fetchBillingFlowUseCase: fetchBillingFlowUseCase
            ),
            BalanceFlowHandler(
                session: session,
                queryBalanceUseCase: DefaultQueryBalanceUseCase()
            ),
            UsageFlowHandler(
                session: session,
                queryUsageUseCase: DefaultQueryUsageUseCase()
            ),
            ServiceRequestFlowHandler(
                session: session,
                submitServiceRequestUseCase: DefaultSubmitServiceRequestUseCase()
            )
        ]
    }

    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome {
        // 检测多意图选择场景：有多个替代意图且需要用户选择
        if result.hasAlternatives && result.suggestedActions.contains(where: { $0.id == "multi_intent_selection" }) {
            // 构建 MultiIntentSelection DomainFlow
            let selectionPrompt = result.suggestedActions.first?.title ?? "Please select an action:"
            let intentOptions = [result] + result.alternativeIntents.map { alt in
                BoltIntentOption(
                    intentType: alt.intentType.rawValue,
                    displayName: alt.intentType.displayName(for: language),
                    description: alt.description,
                    confidence: alt.confidence
                )
            }

            // 将主要意图也加入选项
            let primaryOption = BoltIntentOption(
                intentType: result.intentType.rawValue,
                displayName: result.intentType.displayName(for: language),
                description: nil,
                confidence: result.confidence
            )
            let allOptions = [primaryOption] + result.alternativeIntents.map { alt in
                BoltIntentOption(
                    intentType: alt.intentType.rawValue,
                    displayName: alt.intentType.displayName(for: language),
                    description: alt.description,
                    confidence: alt.confidence
                )
            }

            let multiIntentContext = BoltMultiIntentSelectionContext(
                title: "Select Action",
                message: "I detected multiple possible actions. Please select one:",
                selectionPrompt: selectionPrompt,
                intentOptions: allOptions,
                originalUserText: text
            )
            return .presentDomainFlow(.multiIntentSelection(multiIntentContext))
        }

        // 低置信度时优先要求用户确认，避免误判导致错误操作
        if result.needsUserConfirmation, let confirmAction = result.suggestedActions.first {
            let confirmActions = result.suggestedActions.map { action in
                AIChatAction(title: action.title, target: nil, rawValue: action.actionType.rawValue)
            }
            let confirmReply = AIChatReply(
                conversationID: nil,
                text: confirmAction.title,
                thinkingText: "",
                actions: confirmActions
            )
            return .presentFollowUp(confirmReply)
        }

        switch navigationPolicy.decide(text: text, result: result) {
        case .navigateExplicitly(let target):
            return .navigateExplicitly(target)
        case .domainFirst:
            break
        }

        for handler in handlers where handler.canHandle(text: text, result: result) {
            if let outcome = await handler.resolve(
                text: text,
                result: result,
                context: context,
                conversationHistory: conversationHistory,
                language: language
            ) {
                return outcome
            }
        }

        return .handoffToGenericChat
    }
}

private struct OfferFlowHandler: BoltTelecomDomainFlowHandling {
    private let session: CustSubInfo
    private let recommendOffersUseCase: any RecommendOffersUseCase

    init(session: CustSubInfo, recommendOffersUseCase: any RecommendOffersUseCase) {
        self.session = session
        self.recommendOffersUseCase = recommendOffersUseCase
    }

    func canHandle(text: String, result: IntentRecognitionResult) -> Bool {
        let normalizedText = normalized(text)
        guard !Self.isExistingDataPackageStatusQuestion(normalizedText) else {
            return false
        }

        return result.intentType == .viewOffers
            || result.intentType == .subscribeOffer
            || normalizedText.contains("my data is not enough")
            || normalizedText.contains("my data is running out")
            || normalizedText.contains("data is running out")
            || normalizedText.contains("need more data")
            || normalizedText.contains("buy more data")
            || normalizedText.contains("more data")
    }

    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome? {
        let offers = (try? await recommendOffersUseCase.execute(goal: .moreData, session: session)) ?? []
        let flow = BoltDomainFlow.offers(
            BoltOfferFlowContext(
                title: localizedTitle(for: language),
                message: localizedMessage(for: language),
                offers: offers,
                allowExternalNavigation: true,
                isRoaming: false
            )
        )
        return .presentDomainFlow(flow)
    }

    private func localizedTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Recommended Offers"
        case .simplifiedChinese:
            return "推荐套餐"
        case .arabic:
            return "العروض الموصى بها"
        }
    }

    private func localizedMessage(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Here are the best data offers for your request. You can review details and subscribe without leaving Bolt."
        case .simplifiedChinese:
            return "这里是最适合你的流量套餐；可以直接在 Bolt 内查看详情并完成订购。"
        case .arabic:
            return "هذه أفضل عروض البيانات لطلبك، ويمكنك مراجعتها والاشتراك فيها من داخل Bolt."
        }
    }

    private static func isExistingDataPackageStatusQuestion(_ normalizedText: String) -> Bool {
        let hasDataPackageObject = normalizedText.contains("data package")
            || normalizedText.contains("data plan")
            || normalizedText.contains("data bundle")
            || normalizedText.contains("data allowance")
            || normalizedText.contains("my data")
            || normalizedText.contains("current data")
            || normalizedText.contains("existing data")

        guard hasDataPackageObject else { return false }

        let isPurchaseOrUpgradeRequest = normalizedText.contains("subscribe")
            || normalizedText.contains("activate")
            || normalizedText.contains("purchase")
            || normalizedText.contains("buy")
            || normalizedText.contains("order")
            || normalizedText.contains("buy more data")
            || normalizedText.contains("need more data")
            || normalizedText.contains("need a bigger")
            || normalizedText.contains("upgrade")
            || normalizedText.contains("add extra data")
            || normalizedText.contains("get more data")
            || normalizedText.contains("my data is running out")
            || normalizedText.contains("data is running out")

        guard !isPurchaseOrUpgradeRequest else { return false }

        return normalizedText.contains("my data package")
            || normalizedText.contains("my data plan")
            || normalizedText.contains("my data bundle")
            || normalizedText.contains("current data package")
            || normalizedText.contains("current data plan")
            || normalizedText.contains("existing data package")
            || normalizedText.contains("what about my data")
            || normalizedText.contains("how is my data package")
            || normalizedText.contains("tell me about my data package")
            || normalizedText.contains("data package status")
            || normalizedText.contains("data package remaining")
            || normalizedText.contains("data package left")
            || normalizedText.contains("data package enough")
            || normalizedText.contains("data allowance")
    }
}

private struct RoamingFlowHandler: BoltTelecomDomainFlowHandling {
    private let session: CustSubInfo
    private let recommendOffersUseCase: any RecommendOffersUseCase

    init(session: CustSubInfo, recommendOffersUseCase: any RecommendOffersUseCase) {
        self.session = session
        self.recommendOffersUseCase = recommendOffersUseCase
    }

    func canHandle(text: String, result: IntentRecognitionResult) -> Bool {
        normalized(text).contains("roaming")
            || normalized(text).contains("漫游")
            || normalized(text).contains("تجوال")
    }

    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome? {
        let offers = (try? await recommendOffersUseCase.execute(goal: .roaming, session: session)) ?? []
        return .presentDomainFlow(
            .roaming(
                BoltOfferFlowContext(
                    title: localizedTitle(for: language),
                    message: localizedMessage(for: language),
                    offers: offers,
                    allowExternalNavigation: true,
                    isRoaming: true
                )
            )
        )
    }

    private func localizedTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Roaming Plans"
        case .simplifiedChinese:
            return "漫游套餐"
        case .arabic:
            return "باقات التجوال"
        }
    }

    private func localizedMessage(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "These roaming plans are ready inside Bolt. Compare them here before you decide."
        case .simplifiedChinese:
            return "这些漫游套餐已经在 Bolt 内准备好了，你可以直接在这里比较并选择。"
        case .arabic:
            return "باقات التجوال جاهزة هنا داخل Bolt، ويمكنك مقارنتها قبل اتخاذ القرار."
        }
    }
}

private struct RechargeFlowHandler: BoltTelecomDomainFlowHandling {
    private let session: CustSubInfo
    private let prepareRechargeFlowUseCase: any PrepareRechargeFlowUseCase

    init(session: CustSubInfo, prepareRechargeFlowUseCase: any PrepareRechargeFlowUseCase) {
        self.session = session
        self.prepareRechargeFlowUseCase = prepareRechargeFlowUseCase
    }

    func canHandle(text: String, result: IntentRecognitionResult) -> Bool {
        result.intentType == .rechargeAccount
            || normalized(text).contains("recharge")
            || normalized(text).contains("top up")
            || normalized(text).contains("充值")
            || normalized(text).contains("شحن")
    }

    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome? {
        do {
            let flow = try await prepareRechargeFlowUseCase.execute(session: session, language: language)
            return .presentDomainFlow(.recharge(flow))
        } catch {
            return nil
        }
    }
}

private struct BillingFlowHandler: BoltTelecomDomainFlowHandling {
    private let session: CustSubInfo
    private let fetchBillingFlowUseCase: any FetchBillingFlowUseCase

    init(session: CustSubInfo, fetchBillingFlowUseCase: any FetchBillingFlowUseCase) {
        self.session = session
        self.fetchBillingFlowUseCase = fetchBillingFlowUseCase
    }

    func canHandle(text: String, result: IntentRecognitionResult) -> Bool {
        let normalizedText = normalized(text)
        let paymentLike = normalizedText.contains("pay bill")
            || normalizedText.contains("payment")
            || normalizedText.contains("bill payment")
            || normalizedText.contains("支付账单")
            || normalizedText.contains("دفع الفاتورة")

        return (result.intentType == .viewBill || normalizedText.contains("bill") || normalizedText.contains("账单") || normalizedText.contains("فاتورة"))
            && !paymentLike
    }

    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome? {
        do {
            let flow = try await fetchBillingFlowUseCase.execute(session: session, language: language)
            return .presentDomainFlow(.billing(flow))
        } catch {
            return nil
        }
    }
}

private struct PaymentFlowHandler: BoltTelecomDomainFlowHandling {
    private let session: CustSubInfo
    private let buildBillPaymentFlowUseCase: any BuildBillPaymentFlowUseCase

    init(session: CustSubInfo, buildBillPaymentFlowUseCase: any BuildBillPaymentFlowUseCase) {
        self.session = session
        self.buildBillPaymentFlowUseCase = buildBillPaymentFlowUseCase
    }

    func canHandle(text: String, result: IntentRecognitionResult) -> Bool {
        let normalizedText = normalized(text)
        return result.intentType == .makePayment
            || result.intentType == .paymentStatus
            || normalizedText.contains("pay bill")
            || normalizedText.contains("bill payment")
            || normalizedText.contains("payment")
            || normalizedText.contains("支付")
            || normalizedText.contains("付款")
            || normalizedText.contains("دفع")
    }

    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome? {
        do {
            let flow = try await buildBillPaymentFlowUseCase.execute(session: session, language: language)
            return .presentDomainFlow(.payment(flow))
        } catch {
            return nil
        }
    }
}

private struct BalanceFlowHandler: BoltTelecomDomainFlowHandling {
    private let session: CustSubInfo
    private let queryBalanceUseCase: any QueryBalanceUseCase

    init(session: CustSubInfo, queryBalanceUseCase: any QueryBalanceUseCase) {
        self.session = session
        self.queryBalanceUseCase = queryBalanceUseCase
    }

    func canHandle(text: String, result: IntentRecognitionResult) -> Bool {
        result.intentType == .balanceInquiry
            || normalized(text).contains("balance")
            || normalized(text).contains("余额")
            || normalized(text).contains("الرصيد")
    }

    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome? {
        .presentDomainFlow(.balance(await queryBalanceUseCase.execute(session: session, language: language)))
    }
}

private struct UsageFlowHandler: BoltTelecomDomainFlowHandling {
    private let session: CustSubInfo
    private let queryUsageUseCase: any QueryUsageUseCase

    init(session: CustSubInfo, queryUsageUseCase: any QueryUsageUseCase) {
        self.session = session
        self.queryUsageUseCase = queryUsageUseCase
    }

    func canHandle(text: String, result: IntentRecognitionResult) -> Bool {
        // 优先通过意图类型判断
        if Self.usageIntentTypes.contains(result.intentType) {
            return true
        }

        // 关键词 fallback
        let normalizedText = normalized(text)
        return normalizedText.contains("usage")
            || normalizedText.contains("remaining data")
            || normalizedText.contains("data left")
            || normalizedText.contains("sms")
            || normalizedText.contains("text message")
            || normalizedText.contains("messages left")
            || normalizedText.contains("remaining texts")
            || normalizedText.contains("remaining sms")
            || normalizedText.contains("voice")
            || normalizedText.contains("minutes left")
            || normalizedText.contains("remaining minutes")
            || normalizedText.contains("call usage")
            || normalizedText.contains("remaining internet")
            || normalizedText.contains("data package is enough")
            || normalizedText.contains("what about my data")
            || normalizedText.contains("my data package")
            || normalizedText.contains("my data plan")
            || normalizedText.contains("my data bundle")
            || normalizedText.contains("current data package")
            || normalizedText.contains("data package status")
            || normalizedText.contains("data package remaining")
            || normalizedText.contains("data package left")
            || normalizedText.contains("how much data")
            || normalizedText.contains("check my data")
            || normalizedText.contains("剩余流量")
            || normalizedText.contains("用量")
            || normalizedText.contains("数据还剩")
            || normalizedText.contains("流量")
            || normalizedText.contains("短信")
            || normalizedText.contains("剩余分钟")
            || normalizedText.contains("通话")
            || normalizedText.contains("استهلاك")
            || normalizedText.contains("البيانات المتبقية")
            || normalizedText.contains("رسائل")
            || normalizedText.contains("دقائق")
    }

    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome? {
        .presentDomainFlow(
            .usage(
                await queryUsageUseCase.execute(
                    intentType: usageIntentType(for: text, result: result),
                    session: session,
                    language: language
                )
            )
        )
    }

    private static let usageIntentTypes: [UserIntentType] = [
        .dataUsageQuery,
        .voiceUsageQuery,
        .smsUsageQuery
    ]

    private func usageIntentType(for text: String, result: IntentRecognitionResult) -> UserIntentType {
        if Self.usageIntentTypes.contains(result.intentType) {
            return result.intentType
        }

        let normalizedText = normalized(text)
        if normalizedText.contains("sms")
            || normalizedText.contains("text message")
            || normalizedText.contains("messages left")
            || normalizedText.contains("remaining texts")
            || normalizedText.contains("remaining sms")
            || normalizedText.contains("短信")
            || normalizedText.contains("رسائل") {
            return .smsUsageQuery
        }

        if normalizedText.contains("voice")
            || normalizedText.contains("minutes left")
            || normalizedText.contains("remaining minutes")
            || normalizedText.contains("call usage")
            || normalizedText.contains("剩余分钟")
            || normalizedText.contains("通话")
            || normalizedText.contains("دقائق") {
            return .voiceUsageQuery
        }

        return .dataUsageQuery
    }
}

private struct ServiceRequestFlowHandler: BoltTelecomDomainFlowHandling {
    private let session: CustSubInfo
    private let submitServiceRequestUseCase: any SubmitServiceRequestUseCase

    init(session: CustSubInfo, submitServiceRequestUseCase: any SubmitServiceRequestUseCase) {
        self.session = session
        self.submitServiceRequestUseCase = submitServiceRequestUseCase
    }

    func canHandle(text: String, result: IntentRecognitionResult) -> Bool {
        let normalizedText = normalized(text)
        guard !containsTravelCues(normalizedText) else {
            return false
        }

        return result.intentType == .accountHelp
            || normalizedText.contains("service help")
            || normalizedText.contains("complaint")
            || normalizedText.contains("issue")
            || normalizedText.contains("problem")
            || normalizedText.contains("service request")
            || normalizedText.contains("network not working")
            || normalizedText.contains("cannot call")
            || normalizedText.contains("帮助")
            || normalizedText.contains("投诉")
            || normalizedText.contains("问题")
            || normalizedText.contains("服务请求")
            || normalizedText.contains("مشكلة")
            || normalizedText.contains("شكوى")
            || normalizedText.contains("مساعدة")
    }

    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome? {
        let normalizedText = normalized(text)
        if requiresFollowUp(normalizedText) {
            return .presentDomainFlow(
                .serviceRequest(
                    BoltServiceFlowContext(
                        title: localizedTitle(for: language),
                        message: localizedMessage(for: language),
                        followUpQuestion: localizedFollowUp(for: language),
                        suggestedReplies: localizedSuggestions(for: language),
                        submissionResult: nil
                    )
                )
            )
        }

        let result = await submitServiceRequestUseCase.execute(
            text: text,
            session: session,
            language: language
        )

        return .presentDomainFlow(
            .serviceRequest(
                BoltServiceFlowContext(
                    title: result.title,
                    message: result.message,
                    followUpQuestion: nil,
                    suggestedReplies: [],
                    submissionResult: result
                )
            )
        )
    }

    private func requiresFollowUp(_ normalizedText: String) -> Bool {
        let strongSignals = [
            "network", "signal", "bill", "recharge", "call", "data", "complaint",
            "网络", "信号", "通话", "流量", "账单",
            "شبكة", "إشارة", "مكالمة", "بيانات", "فاتورة"
        ]

        return !strongSignals.contains(where: { normalizedText.contains($0) })
    }

    private func containsTravelCues(_ normalizedText: String) -> Bool {
        let cues = [
            "ticket", "tickets", "flight", "hotel", "travel", "trip", "booking", "book a flight",
            "机票", "航班", "订票", "行程", "旅行", "酒店",
            "تذكرة", "تذاكر", "رحلة", "فندق", "سفر", "حجز"
        ]

        return cues.contains(where: { normalizedText.contains($0) })
    }

    private func localizedTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Service Support"
        case .simplifiedChinese:
            return "服务支持"
        case .arabic:
            return "دعم الخدمة"
        }
    }

    private func localizedMessage(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "I can keep this request inside Bolt, but I still need one more detail before submitting it."
        case .simplifiedChinese:
            return "这个请求可以继续留在 Bolt 内处理，但提交之前我还需要补充一个关键信息。"
        case .arabic:
            return "يمكنني متابعة هذا الطلب داخل Bolt، لكنني ما زلت أحتاج إلى تفصيل إضافي قبل الإرسال."
        }
    }

    private func localizedFollowUp(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "What exactly is going wrong: network issue, billing issue, recharge issue, or something else?"
        case .simplifiedChinese:
            return "请告诉我具体是哪类问题：网络异常、账单问题、充值问题，还是其他服务请求？"
        case .arabic:
            return "ما نوع المشكلة بالتحديد: مشكلة شبكة، مشكلة فاتورة، مشكلة شحن، أم شيء آخر؟"
        }
    }

    private func localizedSuggestions(for language: AppLanguage) -> [String] {
        switch language {
        case .english:
            return [
                "I have a network issue and calls keep dropping.",
                "My bill looks wrong and I need support.",
                "Recharge failed and I need help."
            ]
        case .simplifiedChinese:
            return [
                "我的网络有问题，通话总是中断。",
                "我的账单金额不对，需要协助。",
                "充值失败了，我需要帮助。"
            ]
        case .arabic:
            return [
                "لدي مشكلة في الشبكة والمكالمات تنقطع باستمرار.",
                "فاتورتي تبدو غير صحيحة وأحتاج إلى دعم.",
                "فشل الشحن وأحتاج إلى مساعدة."
            ]
        }
    }
}

private struct TravelIntentDomainHandler: BoltTelecomDomainFlowHandling {
    private let extractor: any TravelIntentEntityExtracting

    init(extractor: any TravelIntentEntityExtracting = RuleBasedTravelIntentEntityExtractor()) {
        self.extractor = extractor
    }

    func canHandle(text: String, result: IntentRecognitionResult) -> Bool {
        let normalizedText = normalized(text)
        if containsTravelCue(normalizedText) && hasDestinationSignal(text, normalizedText: normalizedText) {
            return true
        }

        switch result.intentType {
        case .itineraryQuery, .flightInfo, .hotelInfo:
            return true
        default:
            return false
        }
    }

    func resolve(
        text: String,
        result: IntentRecognitionResult,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async -> IntentRoutingOutcome? {
        let facts = extractor.extractFacts(
            from: text,
            businessParameters: result.businessParameters,
            language: language
        )
        let copy = TravelIntentCopy(language: language)

        let flowContext: BoltTravelFlowContext
        let priceRange: BoltTravelPriceRange?
        if let r = facts.priceRange {
            priceRange = BoltTravelPriceRange(min: r.min, max: r.max, currency: r.currency)
        } else {
            priceRange = nil
        }

        if let destination = facts.destination {
            if let transportMode = facts.transportMode, let departureDate = facts.departureDateText {
                flowContext = BoltTravelFlowContext(
                    title: copy.travelWorkspaceTitle,
                    message: copy.bookingSummary(
                        destination: destination,
                        transportMode: transportMode,
                        departureDateText: departureDate
                    ),
                    destination: destination,
                    transportMode: transportMode,
                    departureDateText: departureDate,
                    returnDateText: facts.returnDateText,
                    passengerCount: facts.passengerCount,
                    priceRange: priceRange,
                    followUpQuestion: nil,
                    suggestedReplies: [],
                    ticketPageURL: nil,
                    isResolvingTicketPage: false,
                    ticketPageErrorMessage: nil
                )
            } else {
                flowContext = BoltTravelFlowContext(
                    title: copy.travelWorkspaceTitle,
                    message: copy.travelWorkspaceMessage,
                    destination: destination,
                    transportMode: facts.transportMode,
                    departureDateText: facts.departureDateText,
                    returnDateText: facts.returnDateText,
                    passengerCount: facts.passengerCount,
                    priceRange: priceRange,
                    followUpQuestion: copy.followUpQuestion(
                        destination: destination,
                        transportMode: facts.transportMode,
                        departureDateText: facts.departureDateText
                    ),
                    suggestedReplies: copy.suggestedTravelReplies(destination: destination),
                    ticketPageURL: nil,
                    isResolvingTicketPage: false,
                    ticketPageErrorMessage: nil
                )
            }
        } else {
            flowContext = BoltTravelFlowContext(
                title: copy.travelWorkspaceTitle,
                message: copy.travelWorkspaceMessage,
                destination: nil,
                transportMode: nil,
                departureDateText: nil,
                returnDateText: nil,
                passengerCount: nil,
                priceRange: nil,
                followUpQuestion: copy.askDestination,
                suggestedReplies: copy.suggestedStartReplies,
                ticketPageURL: nil,
                isResolvingTicketPage: false,
                ticketPageErrorMessage: nil
            )
        }

        return .presentDomainFlow(.travel(flowContext))
    }

    private func containsTravelCue(_ normalizedText: String) -> Bool {
        let cues = [
            "travel", "travelling", "traveling", "traval", "travle", "tranval",
            "trip", "journey", "ticket", "tickets", "flight", "hotel", "booking",
            "旅行", "行程", "预订", "订票", "机票", "火车票", "酒店", "出行",
            "سفر", "رحلة", "تذكرة", "تذاكر", "حجز", "فندق"
        ]

        return cues.contains(where: { normalizedText.contains($0) })
    }

    private func hasDestinationSignal(_ text: String, normalizedText: String) -> Bool {
        let englishPattern = #"(?i)(?:travel|travelling|traveling|traval|travle|tranval|go|trip|fly|visit|journey|ticket|tickets|flight|train|hotel|booking)\s+to\s+([a-z][a-z\s-]{1,40})"#
        let chinesePattern = #"去([一-龥A-Za-z\s]{1,20})"#
        let arabicPattern = #"(?i)(?:إلى|الى)\s+([ء-يA-Za-z\s-]{1,40})"#

        let patterns = [englishPattern, chinesePattern, arabicPattern]
        let range = NSRange(text.startIndex..., in: text)

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            guard
                let match = regex.firstMatch(in: text, options: [], range: range),
                match.numberOfRanges > 1,
                let capturedRange = Range(match.range(at: 1), in: text)
            else {
                continue
            }

            if !String(text[capturedRange]).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
        }

        return normalizedText.contains("hongkong")
            || normalizedText.contains("hong kong")
    }
}

struct RechargeDomainPaymentService: PaymentServicing {
    let session: CustSubInfo
    let useCase: any ExecuteRechargeUseCase

    func processPayment(
        methodId: String,
        amount: Decimal,
        context: PaymentContext
    ) async throws -> PaymentResultCard {
        try await useCase.execute(
            amount: amount,
            methodId: methodId,
            context: context,
            session: session
        )
    }

    func requestOTP(methodId: String, context: PaymentContext) async throws -> String {
        "Account ending in ****567"
    }
}

struct BillingDomainPaymentService: PaymentServicing {
    let session: CustSubInfo
    let invoice: BillingInvoice
    let useCase: any PayBillUseCase

    func processPayment(
        methodId: String,
        amount: Decimal,
        context: PaymentContext
    ) async throws -> PaymentResultCard {
        try await useCase.execute(
            invoice: invoice,
            methodId: methodId,
            context: context,
            session: session
        )
    }

    func requestOTP(methodId: String, context: PaymentContext) async throws -> String {
        "Bill payment verification sent"
    }
}

private enum BoltPaymentCardFactory {
    static func makeRechargeCard(entrySnapshot: RechargeEntrySnapshot) -> AIChatPaymentCard {
        AIChatPaymentCard(
            transactionType: .recharge,
            amountOptions: PaymentAmountOptions(
                min: entrySnapshot.minAmount,
                max: 500,
                defaultAmount: entrySnapshot.quickAmounts.first ?? entrySnapshot.minAmount,
                quickAmounts: entrySnapshot.quickAmounts,
                currency: "AED"
            ),
            paymentMethods: commonPaymentMethods(),
            subscriberInfo: PaymentSubscriberInfo(
                serviceNumber: entrySnapshot.serviceNumber,
                currentBalance: entrySnapshot.balanceText
            )
        )
    }

    static func makeBillPaymentCard(invoice: BillingInvoice?, serviceNumber: String) -> AIChatPaymentCard {
        let amount = BillingNumberParser.decimal(invoice?.openAmountRaw) ?? 50
        return AIChatPaymentCard(
            transactionType: .billPayment,
            amountOptions: PaymentAmountOptions(
                min: amount,
                max: amount,
                defaultAmount: amount,
                quickAmounts: [amount],
                currency: "AED"
            ),
            paymentMethods: commonPaymentMethods(),
            subscriberInfo: PaymentSubscriberInfo(
                serviceNumber: serviceNumber,
                currentBalance: nil
            )
        )
    }

    private static func commonPaymentMethods() -> [PaymentMethodOption] {
        [
            PaymentMethodOption(
                id: "tabby",
                name: "Tabby BNPL",
                description: "Split in 4 installments • No interest",
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
            ),
            PaymentMethodOption(
                id: "google_pay",
                name: "Google Pay",
                description: "Instant payment",
                iconType: .google,
                installmentOptions: nil,
                isDefault: false
            )
        ]
    }
}

private protocol TravelIntentEntityExtracting {
    func extractFacts(
        from text: String,
        businessParameters: [String: String],
        language: AppLanguage
    ) -> TravelIntentFacts
}

private struct TravelIntentFacts: Equatable {
    let destination: String?
    let transportMode: BoltTravelTransportMode?
    let departureDateText: String?
    let returnDateText: String?
    let passengerCount: Int?
    let priceRange: TravelIntentPriceRange?
}

private struct TravelIntentPriceRange: Equatable {
    let min: Double
    let max: Double
    let currency: String
}

private struct RuleBasedTravelIntentEntityExtractor: TravelIntentEntityExtracting {
    func extractFacts(
        from text: String,
        businessParameters: [String: String],
        language: AppLanguage
    ) -> TravelIntentFacts {
        let destination = extractDestination(from: text, businessParameters: businessParameters, language: language)
        let transportMode = extractTransportMode(from: text, businessParameters: businessParameters)
        let departureDateText = extractDepartureDate(from: text, businessParameters: businessParameters)
        let returnDateText = extractStringParam("return_date", from: businessParameters)
        let passengerCount = extractIntParam("passenger_count", from: businessParameters)
        let priceRange = extractPriceRange(from: businessParameters)

        return TravelIntentFacts(
            destination: destination,
            transportMode: transportMode,
            departureDateText: departureDateText,
            returnDateText: returnDateText,
            passengerCount: passengerCount,
            priceRange: priceRange
        )
    }

    private func extractStringParam(_ key: String, from params: [String: String]) -> String? {
        guard let value = params[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    private func extractIntParam(_ key: String, from params: [String: String]) -> Int? {
        extractStringParam(key, from: params).flatMap(Int.init)
    }

    private func extractPriceRange(from params: [String: String]) -> TravelIntentPriceRange? {
        guard
            let minStr = extractStringParam("price_min", from: params),
            let maxStr = extractStringParam("price_max", from: params),
            let min = Double(minStr), let max = Double(maxStr)
        else { return nil }
        let currency = extractStringParam("currency", from: params) ?? "USD"
        return TravelIntentPriceRange(min: min, max: max, currency: currency)
    }

    private func extractDestination(
        from text: String,
        businessParameters: [String: String],
        language: AppLanguage
    ) -> String? {
        for key in ["destination", "city", "arrival_city", "destination_city"] {
            if let value = businessParameters[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }

        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = original.lowercased()

        let regexPatterns: [String]
        switch language {
        case .english:
            regexPatterns = [
                #"(?i)(?:travel|go|trip|fly|visit|journey)\s+to\s+([a-z][a-z\s-]{1,40})"#,
                #"(?i)(?:traval|travle|tranval)\s+to\s+([a-z][a-z\s-]{1,40})"#,
                #"(?i)(?:tickets?|flight|train)\s+to\s+([a-z][a-z\s-]{1,40})"#
            ]
        case .simplifiedChinese:
            regexPatterns = [
                #"去([一-龥A-Za-z\s]{1,20})"#,
                #"到([一-龥A-Za-z\s]{1,20})旅行"#
            ]
        case .arabic:
            regexPatterns = [
                #"(?i)(?:إلى|الى)\s+([ء-يA-Za-z\s-]{1,40})"#
            ]
        }

        for pattern in regexPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let range = NSRange(original.startIndex..., in: original)
            guard
                let match = regex.firstMatch(in: original, options: [], range: range),
                match.numberOfRanges > 1,
                let capturedRange = Range(match.range(at: 1), in: original)
            else {
                continue
            }

            let rawDestination = String(original[capturedRange])
            let cleanedDestination = cleanDestination(rawDestination, lowercasedSource: lowercased)
            if !cleanedDestination.isEmpty {
                return cleanedDestination
            }
        }

        return nil
    }

    private func cleanDestination(_ rawDestination: String, lowercasedSource: String) -> String {
        var candidate = rawDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        let splitMarkers = [
            " on ", " for ", " next ", " this ", " tomorrow", " today",
            " and ", " by ", " with ", " in ", " at "
        ]

        for marker in splitMarkers {
            if let range = candidate.lowercased().range(of: marker) {
                candidate = String(candidate[..<range.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        if lowercasedSource.contains("travel to")
            || lowercasedSource.contains("traval to")
            || lowercasedSource.contains("travle to")
            || lowercasedSource.contains("tranval to")
            || lowercasedSource.contains("go to")
            || lowercasedSource.contains("fly to")
        {
            candidate = candidate.replacingOccurrences(of: #"[^A-Za-z\s-]"#, with: "", options: .regularExpression)
        }

        return candidate
    }

    private func extractTransportMode(
        from text: String,
        businessParameters: [String: String]
    ) -> BoltTravelTransportMode? {
        if let rawMode = businessParameters["travel_mode"]?.lowercased() ?? businessParameters["transport_mode"]?.lowercased() {
            if rawMode.contains("flight") || rawMode.contains("plane") || rawMode.contains("air") {
                return .flight
            }
            if rawMode.contains("train") || rawMode.contains("rail") {
                return .train
            }
        }

        let lowercased = text.lowercased()
        if ["flight", "plane", "airline", "fly"].contains(where: { lowercased.contains($0) }) {
            return .flight
        }
        if ["train", "rail"].contains(where: { lowercased.contains($0) }) {
            return .train
        }

        return nil
    }

    private func extractDepartureDate(
        from text: String,
        businessParameters: [String: String]
    ) -> String? {
        for key in ["date", "departure_date", "travel_date"] {
            if let value = businessParameters[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }

        let patterns = [
            #"(?i)\b(today|tomorrow|next\s+\w+|this\s+\w+)\b"#,
            #"(?i)\b(?:on\s+)?(\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?)\b"#,
            #"(?i)\b(?:on\s+)?(\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*)\b"#,
            #"(?i)\b(?:on\s+)?((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2})\b"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let range = NSRange(text.startIndex..., in: text)
            guard
                let match = regex.firstMatch(in: text, options: [], range: range),
                match.numberOfRanges > 1,
                let capturedRange = Range(match.range(at: 1), in: text)
            else {
                continue
            }

            let dateText = String(text[capturedRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !dateText.isEmpty {
                return dateText
            }
        }

        return nil
    }
}

private struct TravelIntentCopy {
    let language: AppLanguage

    var travelWorkspaceTitle: String {
        switch language {
        case .english:
            return "Travel Planning"
        case .simplifiedChinese:
            return "出行规划"
        case .arabic:
            return "تخطيط السفر"
        }
    }

    var travelWorkspaceMessage: String {
        switch language {
        case .english:
            return "I will keep your trip planning inside Bolt and only open an external page if you explicitly ask for it."
        case .simplifiedChinese:
            return "我会把你的出行规划留在 Bolt 内处理，只有你明确要求时才跳转页面。"
        case .arabic:
            return "سأبقي تخطيط رحلتك داخل Bolt، ولن أفتح صفحة خارجية إلا إذا طلبت ذلك صراحةً."
        }
    }

    var askDestination: String {
        switch language {
        case .english:
            return "I can help with tickets and travel planning. Which city are you travelling to, and do you need flight tickets or train tickets?"
        case .simplifiedChinese:
            return "我可以帮你处理票务和出行规划。你要去哪个城市？需要机票还是火车票？"
        case .arabic:
            return "يمكنني مساعدتك في التذاكر وخطة السفر. إلى أي مدينة ستسافر، وهل تحتاج إلى تذاكر طيران أم قطار؟"
        }
    }

    func followUpQuestion(
        destination: String,
        transportMode: BoltTravelTransportMode?,
        departureDateText: String?
    ) -> String {
        switch (language, transportMode, departureDateText) {
        case (.english, .none, .none):
            return "You're planning a trip to \(destination). Do you need flight tickets or train tickets, and what date are you travelling?"
        case (.english, let mode?, .none):
            return "I can help with \(mode.displayName(for: .english)) tickets to \(destination). What date are you travelling?"
        case (.english, .none, let date?):
            return "I can help with your trip to \(destination) on \(date). Do you need flight tickets or train tickets?"
        case (.english, let mode?, let date?):
            return bookingSummary(destination: destination, transportMode: mode, departureDateText: date)

        case (.simplifiedChinese, .none, .none):
            return "你是要去 \(destination)。需要机票还是火车票？出发日期是什么时候？"
        case (.simplifiedChinese, let mode?, .none):
            return "我可以帮你处理去 \(destination) 的\(mode.displayName(for: .simplifiedChinese))。请告诉我出发日期。"
        case (.simplifiedChinese, .none, let date?):
            return "你计划在 \(date) 去 \(destination)。需要机票还是火车票？"
        case (.simplifiedChinese, let mode?, let date?):
            return bookingSummary(destination: destination, transportMode: mode, departureDateText: date)

        case (.arabic, .none, .none):
            return "أنت تخطط للسفر إلى \(destination). هل تحتاج إلى تذاكر طيران أم قطار، وما تاريخ السفر؟"
        case (.arabic, let mode?, .none):
            return "يمكنني مساعدتك في \(mode.displayName(for: .arabic)) إلى \(destination). ما تاريخ السفر؟"
        case (.arabic, .none, let date?):
            return "يمكنني مساعدتك في رحلتك إلى \(destination) في \(date). هل تحتاج إلى تذاكر طيران أم قطار؟"
        case (.arabic, let mode?, let date?):
            return bookingSummary(destination: destination, transportMode: mode, departureDateText: date)
        }
    }

    func bookingSummary(
        destination: String,
        transportMode: BoltTravelTransportMode,
        departureDateText: String
    ) -> String {
        switch language {
        case .english:
            return "I can help you continue with \(transportMode.displayName(for: .english)) tickets to \(destination) on \(departureDateText). Open Tickets to continue booking, or check Offers if you also need roaming or data."
        case .simplifiedChinese:
            return "我可以继续帮你处理 \(departureDateText) 前往 \(destination) 的\(transportMode.displayName(for: .simplifiedChinese))。你可以打开票务继续预订，或者顺便查看优惠和漫游流量。"
        case .arabic:
            return "يمكنني مساعدتك في متابعة \(transportMode.displayName(for: .arabic)) إلى \(destination) بتاريخ \(departureDateText). افتح التذاكر لمتابعة الحجز، أو راجع العروض إذا كنت تحتاج إلى تجوال أو بيانات."
        }
    }

    var openTicketsTitle: String {
        switch language {
        case .english:
            return "Open Tickets"
        case .simplifiedChinese:
            return "打开票务"
        case .arabic:
            return "فتح التذاكر"
        }
    }

    var openOffersTitle: String {
        switch language {
        case .english:
            return "View Offers"
        case .simplifiedChinese:
            return "查看优惠"
        case .arabic:
            return "عرض العروض"
        }
    }

    var continueInBoltTitle: String {
        switch language {
        case .english:
            return "Continue Ticket Booking"
        case .simplifiedChinese:
            return "继续票务预订"
        case .arabic:
            return "متابعة حجز التذاكر"
        }
    }

    func suggestedTravelReplies(destination: String) -> [String] {
        switch language {
        case .english:
            return [
                "I need flight tickets to \(destination) tomorrow.",
                "I need train tickets to \(destination) next Friday.",
                "Flight tickets to \(destination) on 12/06."
            ]
        case .simplifiedChinese:
            return [
                "我想订明天去\(destination)的机票。",
                "我想订下周五去\(destination)的火车票。",
                "我想订 12/06 去\(destination) 的机票。"
            ]
        case .arabic:
            return [
                "أحتاج إلى تذاكر طيران إلى \(destination) غدًا.",
                "أحتاج إلى تذاكر قطار إلى \(destination) يوم الجمعة القادم.",
                "أحتاج إلى تذاكر طيران إلى \(destination) بتاريخ 12/06."
            ]
        }
    }

    var suggestedStartReplies: [String] {
        switch language {
        case .english:
            return [
                "I want flight tickets to Hong Kong tomorrow.",
                "I want train tickets to Dubai next Friday.",
                "I need a hotel in Abu Dhabi this weekend."
            ]
        case .simplifiedChinese:
            return [
                "我想订明天去香港的机票。",
                "我想订下周五去迪拜的火车票。",
                "我想订这周末阿布扎比的酒店。"
            ]
        case .arabic:
            return [
                "أريد تذاكر طيران إلى هونغ كونغ غدًا.",
                "أريد تذاكر قطار إلى دبي يوم الجمعة القادم.",
                "أريد حجز فندق في أبوظبي هذا الأسبوع."
            ]
        }
    }
}

private extension BoltTravelTransportMode {
    func displayName(for language: AppLanguage) -> String {
        switch (self, language) {
        case (.flight, .english):
            return "flight"
        case (.flight, .simplifiedChinese):
            return "机票"
        case (.flight, .arabic):
            return "تذاكر الطيران"
        case (.train, .english):
            return "train"
        case (.train, .simplifiedChinese):
            return "火车票"
        case (.train, .arabic):
            return "تذاكر القطار"
        }
    }
}

private extension String {
    var normalizedBoltText: String {
        lowercased()
            .replacingOccurrences(
                of: #"[^a-z0-9\u{4e00}-\u{9fff}\u{0600}-\u{06ff}\s]"#,
                with: " ",
                options: .regularExpression
            )
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private func normalized(_ text: String) -> String {
    text.normalizedBoltText
}
