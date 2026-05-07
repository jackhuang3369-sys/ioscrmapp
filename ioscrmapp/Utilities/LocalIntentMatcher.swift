import Foundation

// MARK: - Local Intent Matcher

/// 本地意图匹配器，基于词集 Jaccard 相似度的快速意图识别。
/// 从精确子串匹配升级为词粒度的相似度计算，覆盖更多用户表达变体。
final class LocalIntentMatcher: Sendable {
    private typealias IntentProfile = (
        intentType: UserIntentType,
        tokensByLanguage: [AppLanguage: Set<String>]
    )

    private let intentProfiles: [IntentProfile]
    private let minimumMatchScore: Double = 0.08

    init() {
        intentProfiles = Self.buildIntentProfiles()
    }

    func match(text: String, language: AppLanguage) async -> IntentRecognitionResult? {
        let normalized = normalizeText(text)
        let inputTokens = tokenize(normalized, language: language)

        guard !inputTokens.isEmpty else { return nil }

        // 行程启发式匹配保持优先级（有正则验证目的地）
        if let heuristicResult = itineraryHeuristicMatch(
            text: text, normalized: normalized, language: language
        ) {
            return heuristicResult
        }

        // 对高确定性短句优先走边界规则，减少套餐/支付/账单等相邻意图互相吞并。
        if let highCertaintyResult = highCertaintyMatch(normalized: normalized, language: language) {
            return highCertaintyResult
        }

        var bestScore: Double = 0
        var bestIntent: UserIntentType?

        for profile in intentProfiles {
            guard let intentTokens = profile.tokensByLanguage[language] else { continue }

            let intersect = inputTokens.intersection(intentTokens).count
            let union = inputTokens.union(intentTokens).count
            let jaccardScore = union > 0 ? Double(intersect) / Double(union) : 0

            // 加权：输入中的命中比例
            let inputHitRatio = inputTokens.count > 0
                ? Double(intersect) / Double(inputTokens.count)
                : 0

            // 综合得分 = Jaccard(0.5) + 输入命中率(0.5)
            let combinedScore = jaccardScore * 0.5 + inputHitRatio * 0.5

            if combinedScore > bestScore {
                bestScore = combinedScore
                bestIntent = profile.intentType
            }
        }

        guard let bestIntent, bestScore >= minimumMatchScore else {
            return nil
        }

        guard isViableScoredIntent(
            bestIntent,
            normalized: normalized,
            language: language
        ) else {
            return nil
        }

        // 调整公式：确保 minimumMatchScore(0.08) 对应约 0.85+ 置信度
        // 公式: confidence = 0.40 + bestScore * 5.0，范围 [0.40, 0.92]
        let confidence = min(0.40 + bestScore * 5.0, 0.92)
        return IntentRecognitionResult(
            intentType: bestIntent,
            confidence: confidence,
            navigationTarget: bestIntent.defaultNavigationTarget,
            requiresConfirmation: confidence < 0.80
        )
    }

    // MARK: - Tokenization

    private func tokenize(_ text: String, language: AppLanguage) -> Set<String> {
        switch language {
        case .english:
            // 英文按空格分词，保留 1-gram 和 2-gram
            let words = text.split(separator: " ").map(String.init).filter { $0.count >= 2 }
            var tokens = Set(words)
            // 添加 bigram 提高匹配精度
            for i in 0..<(words.count - 1) {
                tokens.insert("\(words[i]) \(words[i + 1])")
            }
            return tokens

        case .simplifiedChinese, .arabic:
            // 中文/阿拉伯语：字符级 bigram，同时保留完整词
            var tokens = Set<String>()
            let chars = Array(text).map(String.init).filter { $0 != " " }
            for char in chars where char.count > 0 {
                tokens.insert(char)
            }
            for i in 0..<(chars.count - 1) {
                tokens.insert("\(chars[i])\(chars[i + 1])")
            }
            return tokens
        }
    }

    // MARK: - High Certainty Boundaries

    private func highCertaintyMatch(
        normalized: String,
        language: AppLanguage
    ) -> IntentRecognitionResult? {
        switch language {
        case .english:
            return highCertaintyEnglishMatch(normalized: normalized)
        case .simplifiedChinese:
            return highCertaintyChineseMatch(normalized: normalized)
        case .arabic:
            return highCertaintyArabicMatch(normalized: normalized)
        }
    }

    private func highCertaintyEnglishMatch(normalized: String) -> IntentRecognitionResult? {
        if isExistingDataPackageStatusQuestion(normalized) {
            return fixedMatch(intentType: .dataUsageQuery, confidence: 0.92)
        }

        if isBalanceQuestion(normalized) {
            return fixedMatch(intentType: .balanceInquiry, confidence: 0.9)
        }

        let hasSubscriptionVerb = containsAny(
            in: normalized,
            phrases: ["subscribe", "activate", "purchase", "buy", "order", "get"]
        )
        let hasOfferObject = containsAny(
            in: normalized,
            phrases: ["offer", "plan", "package", "bundle", "data plan", "gb"]
        )

        if normalized.contains("buy more data")
            || normalized.contains("need a bigger data package")
            || normalized.contains("need more data plan")
            || (hasSubscriptionVerb && hasOfferObject) {
            return fixedMatch(intentType: .subscribeOffer, confidence: 0.9)
        }

        if (containsAny(in: normalized, phrases: ["pay", "payment", "settle"])
            && containsAny(in: normalized, phrases: ["bill", "invoice", "statement", "due"]))
            || normalized.contains("pay my bill") {
            return fixedMatch(intentType: .makePayment, confidence: 0.9)
        }

        if (normalized.contains("invoice") || normalized.contains("billing statement")
            || normalized.contains("monthly bill") || normalized.contains("view my bill")
            || normalized.contains("show my bill"))
            && !containsAny(in: normalized, phrases: ["pay", "payment", "settle"]) {
            return fixedMatch(intentType: .viewBill, confidence: 0.88)
        }

        if (containsAny(
            in: normalized,
            phrases: ["offer", "offers", "promotion", "promotions", "deal", "deals", "plan", "plans", "package", "packages"]
        ) && containsAny(
            in: normalized,
            phrases: ["what", "any", "available", "show", "view", "current"]
        )) || normalized == "promotions" {
            return fixedMatch(intentType: .viewOffers, confidence: 0.88)
        }

        if normalized.contains("how much credit do i have")
            || (normalized.contains("credit")
                && containsAny(in: normalized, phrases: ["how much", "remaining", "current", "check"])) {
            return fixedMatch(intentType: .balanceInquiry, confidence: 0.88)
        }

        if containsAny(in: normalized, phrases: ["voice", "call", "calls", "minutes", "talk time"])
            && containsAny(in: normalized, phrases: ["check", "remaining", "left", "usage", "balance", "how many"]) {
            return fixedMatch(intentType: .voiceUsageQuery, confidence: 0.88)
        }

        if containsAny(in: normalized, phrases: ["sms", "text", "texts", "message", "messages", "mms"])
            && containsAny(in: normalized, phrases: ["check", "remaining", "left", "usage", "balance", "how many"]) {
            return fixedMatch(intentType: .smsUsageQuery, confidence: 0.88)
        }

        return nil
    }

    private func isExistingDataPackageStatusQuestion(_ normalized: String) -> Bool {
        let hasDataPackageObject = containsAny(
            in: normalized,
            phrases: [
                "data package", "data plan", "data bundle", "data allowance",
                "my data", "current data", "existing data"
            ]
        )
        guard hasDataPackageObject else { return false }

        let isPurchaseOrUpgradeRequest = containsAny(
            in: normalized,
            phrases: [
                "subscribe", "activate", "purchase", "buy", "order",
                "buy more data", "need more data", "need a bigger",
                "upgrade", "add extra data", "get more data",
                "my data is running out", "data is running out"
            ]
        )
        guard !isPurchaseOrUpgradeRequest else { return false }

        return containsAny(
            in: normalized,
            phrases: [
                "my data package", "my data plan", "my data bundle",
                "current data package", "current data plan", "existing data package",
                "what about my data", "what about my data package",
                "how is my data package", "tell me about my data package",
                "data package status", "data package remaining", "data package left",
                "data package enough", "data allowance"
            ]
        )
    }

    private func isBalanceQuestion(_ normalized: String) -> Bool {
        guard normalized.contains("balance") else { return false }
        guard !containsAny(
            in: normalized,
            phrases: ["data balance", "sms balance", "voice balance", "call balance"]
        ) else {
            return false
        }

        return containsAny(
            in: normalized,
            phrases: ["check", "my", "current", "remaining", "how much", "what is", "show", "view"]
        )
    }

    private func highCertaintyChineseMatch(normalized: String) -> IntentRecognitionResult? {
        if normalized == "余额"
            || normalized.contains("查看余额")
            || normalized.contains("查询余额")
            || normalized.contains("查余额")
            || (normalized.contains("余额")
                && (normalized.contains("查") || normalized.contains("看") || normalized.contains("查询"))) {
            return fixedMatch(intentType: .balanceInquiry, confidence: 0.9)
        }

        if (normalized.contains("支付") || normalized.contains("付款"))
            && (normalized.contains("账单") || normalized.contains("发票")) {
            return fixedMatch(intentType: .makePayment, confidence: 0.9)
        }

        if normalized.contains("查看账单") || normalized.contains("月账单") || normalized.contains("发票") {
            return fixedMatch(intentType: .viewBill, confidence: 0.88)
        }

        if normalized.contains("订阅套餐") || normalized.contains("购买套餐")
            || normalized.contains("办理套餐") || normalized.contains("开通套餐") {
            return fixedMatch(intentType: .subscribeOffer, confidence: 0.9)
        }

        if normalized.contains("有什么优惠") || normalized.contains("可用套餐")
            || normalized.contains("查看优惠") {
            return fixedMatch(intentType: .viewOffers, confidence: 0.88)
        }

        if normalized.contains("查余额") || normalized.contains("查询余额")
            || normalized.contains("话费余额") {
            return fixedMatch(intentType: .balanceInquiry, confidence: 0.88)
        }

        if normalized.contains("查语音") || normalized.contains("剩余分钟")
            || normalized.contains("通话还剩多少") {
            return fixedMatch(intentType: .voiceUsageQuery, confidence: 0.88)
        }

        if normalized.contains("查短信") || normalized.contains("剩余短信")
            || normalized.contains("短信还剩多少") {
            return fixedMatch(intentType: .smsUsageQuery, confidence: 0.88)
        }

        return nil
    }

    private func highCertaintyArabicMatch(normalized: String) -> IntentRecognitionResult? {
        if containsAny(in: normalized, phrases: ["رصيد", "الرصيد"]) {
            return fixedMatch(intentType: .balanceInquiry, confidence: 0.9)
        }

        if containsAny(in: normalized, phrases: ["دفع", "الدفع"])
            && containsAny(in: normalized, phrases: ["فاتورة", "الفاتورة"]) {
            return fixedMatch(intentType: .makePayment, confidence: 0.9)
        }

        if containsAny(in: normalized, phrases: ["فاتورة", "الفاتورة"])
            && !containsAny(in: normalized, phrases: ["دفع", "الدفع"]) {
            return fixedMatch(intentType: .viewBill, confidence: 0.88)
        }

        if containsAny(in: normalized, phrases: ["اشتراك", "تفعيل", "شراء"])
            && containsAny(in: normalized, phrases: ["عرض", "باقة", "باقات"]) {
            return fixedMatch(intentType: .subscribeOffer, confidence: 0.9)
        }

        if containsAny(in: normalized, phrases: ["عروض", "العروض", "باقات"])
            && containsAny(in: normalized, phrases: ["ما", "عرض", "متاحة"]) {
            return fixedMatch(intentType: .viewOffers, confidence: 0.88)
        }

        if containsAny(in: normalized, phrases: ["رصيد", "الرصيد"])
            && containsAny(in: normalized, phrases: ["كم", "تحقق", "متبقي"]) {
            return fixedMatch(intentType: .balanceInquiry, confidence: 0.88)
        }

        if containsAny(in: normalized, phrases: ["مكالمات", "دقائق", "صوت"])
            && containsAny(in: normalized, phrases: ["كم", "متبقية", "استخدام"]) {
            return fixedMatch(intentType: .voiceUsageQuery, confidence: 0.88)
        }

        if containsAny(in: normalized, phrases: ["رسائل", "رسالة", "اس ام اس", "نص"])
            && containsAny(in: normalized, phrases: ["كم", "متبقية", "استخدام"]) {
            return fixedMatch(intentType: .smsUsageQuery, confidence: 0.88)
        }

        return nil
    }

    private func fixedMatch(intentType: UserIntentType, confidence: Double) -> IntentRecognitionResult {
        IntentRecognitionResult(
            intentType: intentType,
            confidence: confidence,
            navigationTarget: intentType.defaultNavigationTarget,
            requiresConfirmation: confidence < 0.80
        )
    }

    private func containsAny(in text: String, phrases: [String]) -> Bool {
        phrases.contains { text.contains($0) }
    }

    private func isViableScoredIntent(
        _ intentType: UserIntentType,
        normalized: String,
        language: AppLanguage
    ) -> Bool {
        guard language == .english, intentType == .smsUsageQuery else {
            return true
        }

        if containsAny(in: normalized, phrases: ["sms", "mms", "message", "messages"]) {
            return true
        }

        if containsAny(in: normalized, phrases: ["text", "texts"]) {
            return containsAny(
                in: normalized,
                phrases: ["check", "remaining", "left", "usage", "balance", "how many"]
            )
        }

        return false
    }

    // MARK: - Normalization

    private func normalizeText(_ text: String) -> String {
        let lowercased = text.lowercased()
        let typoCorrected = Self.commonEnglishTypoPatterns.reduce(lowercased) { partial, pair in
            partial.replacingOccurrences(of: pair.key, with: pair.value, options: .regularExpression)
        }
        let sanitized = typoCorrected.replacingOccurrences(
            of: #"[^a-z0-9\u{4e00}-\u{9fff}\u{0600}-\u{06ff}\s]"#,
            with: "",
            options: .regularExpression
        )
        return sanitized
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Itinerary Heuristic (unchanged)

    private func itineraryHeuristicMatch(
        text: String,
        normalized: String,
        language: AppLanguage
    ) -> IntentRecognitionResult? {
        switch language {
        case .english:
            let travelTypos = [
                "travel", "travelling", "traveling",
                "traval", "travle", "tranval",
                "trip", "journey", "ticket", "tickets",
                "flight", "hotel", "booking"
            ]
            let hasTravelCue = travelTypos.contains { normalized.contains($0) }
            let range = NSRange(text.startIndex..., in: text)
            let hasDestinationPhrase = Self.englishDestinationRegex?
                .firstMatch(in: text, options: [], range: range)
                .flatMap { Range($0.range(at: 1), in: text) }
                .map { !String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                ?? false
            guard hasTravelCue && hasDestinationPhrase else { return nil }
            return IntentRecognitionResult(
                intentType: .itineraryQuery, confidence: 0.9, requiresConfirmation: false
            )
        case .simplifiedChinese:
            guard normalized.contains("去"),
                  normalized.contains("机票") || normalized.contains("火车票")
                    || normalized.contains("旅行") || normalized.contains("出行")
            else { return nil }
            return IntentRecognitionResult(
                intentType: .itineraryQuery, confidence: 0.9, requiresConfirmation: false
            )
        case .arabic:
            guard normalized.contains("إلى") || normalized.contains("الى") else { return nil }
            guard normalized.contains("سفر") || normalized.contains("رحلة")
                    || normalized.contains("تذكرة") || normalized.contains("حجز")
            else { return nil }
            return IntentRecognitionResult(
                intentType: .itineraryQuery, confidence: 0.9, requiresConfirmation: false
            )
        }
    }

    // MARK: - Intent Profiles

    /// 每个意图类型用一组核心词来定义（不是精确关键词，而是语义相关的词集）。
    /// 匹配时计算输入词集与意图词集的 Jaccard 相似度，找到最匹配的意图。
    private static func buildIntentProfiles() -> [IntentProfile] {
        [
            (
                intentType: .flightInfo,
                tokensByLanguage: [
                    .english: Set([
                        "flight", "tickets", "ticket", "airline", "fly", "airport",
                        "book flight", "flight to", "fly to"
                    ]),
                    .simplifiedChinese: Set([
                        "机票", "航班", "飞机", "订机票", "航空", "飞"
                    ]),
                    .arabic: Set([
                        "طيران", "تذكرة", "رحلة", "مطار"
                    ])
                ]
            ),
            (
                intentType: .hotelInfo,
                tokensByLanguage: [
                    .english: Set([
                        "hotel", "book hotel", "accommodation", "room", "stay", "resort",
                        "hotel in", "hotel booking"
                    ]),
                    .simplifiedChinese: Set([
                        "酒店", "宾馆", "住宿", "订酒店", "房间", "民宿"
                    ]),
                    .arabic: Set([
                        "فندق", "حجز", "إقامة", "غرفة"
                    ])
                ]
            ),
            (
                intentType: .itineraryQuery,
                tokensByLanguage: [
                    .english: Set([
                        "travel", "trip", "itinerary", "visit", "tour", "journey",
                        "go to", "travel to", "trip to", "booking", "ticket"
                    ]),
                    .simplifiedChinese: Set([
                        "旅行", "行程", "出行", "旅游", "预订", "订票", "去"
                    ]),
                    .arabic: Set([
                        "سفر", "رحلة", "تذكرة", "حجز", "زيارة"
                    ])
                ]
            ),
            (
                intentType: .dataUsageQuery,
                tokensByLanguage: [
                    .english: Set([
                        "data", "usage", "consumption", "remaining", "left", "internet",
                        "gb", "mb", "package", "enough", "running", "low",
                        "check data", "data usage", "data left", "data package",
                        "how much data", "my data", "data balance", "data consumption",
                        "running out", "data remaining", "internet data",
                        "how much", "have left", "much data", "data enough"
                    ]),
                    .simplifiedChinese: Set([
                        "流量", "数据", "剩余", "使用", "消耗", "还有", "多少",
                        "不够", "本月", "当前", "流", "量", "剩", "用",
                        "查流量", "剩余流量", "流量使用", "流量查询", "流量还剩",
                        "查询流量", "流量不够", "流量消耗"
                    ]),
                    .arabic: Set([
                        "بيانات", "استخدام", "استهلاك", "متبقية", "متبقي",
                        "إنترنت", "جيجابايت", "كم"
                    ])
                ]
            ),
            (
                intentType: .voiceUsageQuery,
                tokensByLanguage: [
                    .english: Set([
                        "voice", "call", "calls", "minutes", "min", "talk",
                        "talk time", "voice usage", "check voice", "check my voice",
                        "check calls", "check my calls", "remaining minutes",
                        "how many minutes", "minutes left", "call balance",
                        "call usage", "how much call", "voice balance",
                        "phone calls", "dial", "calling"
                    ]),
                    .simplifiedChinese: Set([
                        "语音", "通话", "分钟", "话", "查语音", "查通话",
                        "剩余分钟", "通话时长", "还有多少分钟", "通话记录",
                        "查询语音", "查询通话", "通话用量", "分钟还剩"
                    ]),
                    .arabic: Set([
                        "مكالمات", "صوت", "دقيقة", "دقائق", "اتصال", "مدة"
                    ])
                ]
            ),
            (
                intentType: .smsUsageQuery,
                tokensByLanguage: [
                    .english: Set([
                        "sms", "text", "texts", "message", "messages", "mms",
                        "check sms", "check my sms", "check texts", "check my texts",
                        "message balance", "sms balance", "remaining texts",
                        "how many texts", "texts left", "message usage",
                        "sms usage", "how much sms", "send message"
                    ]),
                    .simplifiedChinese: Set([
                        "短信", "彩信", "条", "查短信", "查彩信", "剩余短信",
                        "还有多少条", "短信条数", "短信记录", "查询短信",
                        "查询彩信", "短信用量", "短信还剩"
                    ]),
                    .arabic: Set([
                        "رسالة", "رسائل", "رسالة نصية", "اس ام اس", "نص"
                    ])
                ]
            ),
            (
                intentType: .balanceInquiry,
                tokensByLanguage: [
                    .english: Set([
                        "balance", "credit", "wallet", "account balance", "check balance",
                        "my balance", "remaining balance", "current balance",
                        "remaining credit", "credit balance"
                    ]),
                    .simplifiedChinese: Set([
                        "余额", "查余额", "查询余额", "账户余额", "当前余额",
                        "话费", "剩多少钱"
                    ]),
                    .arabic: Set([
                        "رصيد", "الرصيد", "حساب", "متبقي"
                    ])
                ]
            ),
            (
                intentType: .rechargeAccount,
                tokensByLanguage: [
                    .english: Set([
                        "recharge", "top", "up", "top up", "refill", "add credit",
                        "recharge account", "top up account", "recharge my",
                        "my account", "topup"
                    ]),
                    .simplifiedChinese: Set([
                        "充值", "充话费", "充钱", "缴费", "重新充值", "我要充值",
                        "我要", "要充值"
                    ]),
                    .arabic: Set([
                        "شحن", "إعادة", "تعبئة"
                    ])
                ]
            ),
            (
                intentType: .viewOffers,
                tokensByLanguage: [
                    .english: Set([
                        "offer", "offers", "promotions", "deals", "plans", "packages",
                        "available", "view offers", "show offers", "roaming",
                        "what offers", "deals", "plan"
                    ]),
                    .simplifiedChinese: Set([
                        "优惠", "套餐", "活动", "资费", "查看优惠", "可用套餐",
                        "有什么优惠"
                    ]),
                    .arabic: Set([
                        "عروض", "باقات", "العروض", "متاحة"
                    ])
                ]
            ),
            (
                intentType: .subscribeOffer,
                tokensByLanguage: [
                    .english: Set([
                        "subscribe", "activate", "purchase", "buy", "order",
                        "subscribe offer", "buy offer", "activate package",
                        "want buy", "need bigger", "data plan", "buy data"
                    ]),
                    .simplifiedChinese: Set([
                        "订阅", "办理", "激活", "购买", "订购", "开通", "订阅套餐"
                    ]),
                    .arabic: Set([
                        "اشتراك", "تفعيل", "شراء"
                    ])
                ]
            ),
            (
                intentType: .viewBill,
                tokensByLanguage: [
                    .english: Set([
                        "bill", "billing", "invoice", "statement", "charges",
                        "view bill", "my bill", "billing statement", "monthly bill"
                    ]),
                    .simplifiedChinese: Set([
                        "账单", "发票", "月账单", "查看账单", "消费明细", "查看", "账单"
                    ]),
                    .arabic: Set([
                        "فاتورة", "الفاتورة", "حساب"
                    ])
                ]
            ),
            (
                intentType: .accountHelp,
                tokensByLanguage: [
                    .english: Set([
                        "help", "support", "account", "profile", "settings",
                        "service", "complaint", "network issue", "account help",
                        "account settings"
                    ]),
                    .simplifiedChinese: Set([
                        "帮助", "客服", "设置", "账户", "反馈", "问题", "投诉"
                    ]),
                    .arabic: Set([
                        "مساعدة", "دعم", "إعدادات", "حساب", "شكوى"
                    ])
                ]
            ),
            (
                intentType: .makePayment,
                tokensByLanguage: [
                    .english: Set([
                        "pay", "payment", "pay now", "make payment", "settle", "due",
                        "pay bill", "make", "pay my"
                    ]),
                    .simplifiedChinese: Set([
                        "支付", "付款", "缴费", "立即支付", "我要支付", "付", "款"
                    ]),
                    .arabic: Set([
                        "دفع", "الدفع", "إجراء الدفع"
                    ])
                ]
            ),
            (
                intentType: .paymentHistory,
                tokensByLanguage: [
                    .english: Set([
                        "history", "past payments", "payment records", "transaction",
                        "payment history", "receipts"
                    ]),
                    .simplifiedChinese: Set([
                        "历史", "记录", "支付记录", "交易记录", "付款历史"
                    ]),
                    .arabic: Set([
                        "تاريخ", "سجل", "سابقة"
                    ])
                ]
            )
        ]
    }

    private static let englishDestinationRegex = try? NSRegularExpression(
        pattern: #"(?i)(?:travel|travelling|traveling|traval|travle|tranval|go|trip|fly|visit|journey|ticket|tickets|flight|hotel|booking)\s+to\s+([a-z][a-z\s-]{1,40})"#
    )

    private static let commonEnglishTypoPatterns: [String: String] = [
        #"\bpakage\b"#: "package",
        #"\benuff\b"#: "enough",
        #"\benogh\b"#: "enough",
        #"\binterent\b"#: "internet",
        #"\bremaing\b"#: "remaining",
        #"\blef\b"#: "left"
    ]
}
