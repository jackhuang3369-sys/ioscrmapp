import Foundation
import OSLog

private let intentRecognitionLogger = Logger(
    subsystem: "com.inspur.ioscrmapp",
    category: "IntentRecognition"
)

// MARK: - Intent Recognition Service Protocol

protocol IntentRecognitionServicing: Sendable {
    /// 本地快速匹配（第一层）
    func localMatch(text: String, language: AppLanguage) async -> IntentRecognitionResult?

    /// AI 语义理解（第二层）
    func aiSemanticMatch(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage]
    ) async throws -> IntentRecognitionResult

    /// 综合意图识别（多层融合）
    func recognizeIntent(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async throws -> IntentRecognitionResult
}

// MARK: - Default Implementation

extension IntentRecognitionServicing {
    /// 默认实现：三层意图识别流程
    func recognizeIntent(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async throws -> IntentRecognitionResult {
        intentRecognitionLogger.debug("Starting intent recognition for text: \(text)")

        // 第一层：本地快速匹配
        if let localResult = await localMatch(text: text, language: language),
           localResult.isHighConfidence {
            intentRecognitionLogger.info("Local match succeeded with confidence: \(localResult.confidence)")
            return localResult
        }

        // 第二层：AI 语义理解
        do {
            let aiResult = try await aiSemanticMatch(
                text: text,
                context: context,
                conversationHistory: conversationHistory
            )
            intentRecognitionLogger.info("AI match succeeded with confidence: \(aiResult.confidence)")
            return aiResult
        } catch {
            intentRecognitionLogger.error("AI match failed: \(error.localizedDescription)")

            // 降级处理：返回本地匹配结果或未知意图
            if let localResult = await localMatch(text: text, language: language) {
                intentRecognitionLogger.info("Falling back to local match result")
                return localResult
            }

            return IntentRecognitionResult(
                intentType: .unknown,
                confidence: 0.0,
                requiresConfirmation: true
            )
        }
    }
}

// MARK: - Default Intent Recognition Service

final class DefaultIntentRecognitionService: IntentRecognitionServicing {
    private let aiChatService: any AIChatServicing
    private let localMatcher: LocalIntentMatcher
    private let confidenceCalculator: IntentConfidenceCalculator
    private let classifier: (any IntentClassifierServicing)?
    private let fusion: IntentSignalFusion
    private let configuration: IntentClassifierConfiguration
    private let onbFusionService: ONBIntentFusionService?

    init(
        aiChatService: any AIChatServicing,
        localMatcher: LocalIntentMatcher = LocalIntentMatcher(),
        confidenceCalculator: IntentConfidenceCalculator = IntentConfidenceCalculator(),
        classifier: (any IntentClassifierServicing)? = nil,
        configuration: IntentClassifierConfiguration = .default,
        fusion: IntentSignalFusion? = nil,
        onbFusionService: ONBIntentFusionService? = nil
    ) {
        self.aiChatService = aiChatService
        self.localMatcher = localMatcher
        self.confidenceCalculator = confidenceCalculator
        self.classifier = classifier
        self.configuration = configuration
        self.fusion = fusion ?? IntentSignalFusion(configuration: configuration)
        self.onbFusionService = onbFusionService
    }

    func localMatch(text: String, language: AppLanguage) async -> IntentRecognitionResult? {
        let result = await localMatcher.match(text: text, language: language)
        guard let result else {
            return nil
        }

        return IntentRecognitionResult(
            intentType: result.intentType,
            confidence: result.confidence,
            navigationTarget: result.navigationTarget,
            businessParameters: result.businessParameters,
            requiresConfirmation: result.requiresConfirmation,
            suggestedActions: result.suggestedActions,
            alternativeIntents: result.alternativeIntents,
            source: result.source ?? .rule
        )
    }

    func aiSemanticMatch(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage]
    ) async throws -> IntentRecognitionResult {
        // 构建意图识别请求元数据
        let metadata = AIChatRequestMetadata(
            scene: "intent_recognition",
            eventName: "intent_recognition_request",
            intentCategory: "intent_analysis",
            classificationPrompt: buildIntentClassificationPrompt(),
            sourcePage: "ai_chat_input",
            selectedOffer: nil,
            businessParameters: ["enable_intent_recognition": "true"]
        )

        // 发送 AI 请求
        let reply = try await aiChatService.sendMessage(
            text,
            conversationID: nil,
            context: context,
            metadata: metadata
        )

        // 解析 AI 响应为意图识别结果
        return parseAIReplyToIntentResult(reply, originalText: text)
    }

    private func buildIntentClassificationPrompt() -> String {
        """
        You are an intent classifier for a telecom mobile app. Analyze the user's message SEMANTICALLY to understand what they want to DO NOW.

        CRITICAL RULES:
        1. Return ONLY the intent the user EXPLICITLY expressed. Do NOT guess what they MIGHT want later.
        2. A QUERY intent (checking/viewing) is ALWAYS a SINGLE intent. Do NOT attach purchase/subscribe intents.
        3. Multiple intents ONLY apply when user EXPLICITLY requests MULTIPLE ACTIONS in one message.
        4. Keywords matching is forbidden - understand the ACTION intent:
           - "我短信还有多少" → sms_usage_query (intent is VIEW, not subscribe)
           - "我想买短信套餐" → subscribe_offer (intent is PURCHASE)
           - "帮我看看有什么优惠" → view_offers (intent is EXPLORE, not purchase)

        Intent definitions:
        - balance_inquiry: VIEW current balance/credit
        - data_usage_query: VIEW remaining data
        - voice_usage_query: VIEW remaining voice minutes
        - sms_usage_query: VIEW remaining SMS count
        - recharge_account: ADD credit to account (top-up)
        - view_offers: EXPLORE available packages (browsing only)
        - subscribe_offer: PURCHASE/ACTIVATE a specific package
        - make_payment: PAY a bill

        EXAMPLES:
        | User message | Correct Result | Wrong Result |
        | "我短信还有多少" | [sms_usage_query] ONLY | NOT [sms_usage_query, subscribe_offer] |
        | "我数据用完了，要买套餐" | [data_usage_query, subscribe_offer] | Correct - TWO explicit actions |
        | "我要充值" | [recharge_account] ONLY | NOT [recharge_account, view_offers] |
        | "看看有什么语音套餐" | [view_offers] ONLY | NOT [view_offers, subscribe_offer] |
        | "我在沙特，要充值买漫游包" | [itinerary_query, recharge_account, subscribe_offer] | Correct - THREE actions |

        JSON Response Format (always return array with ONE primary intent for simple queries):
        {
          "intents": [{"intent_type": "<intent>", "confidence": <0.0-1.0>, "business_parameters": {}}],
          "primary_intent_index": 0,
          "requires_user_selection": false,
          "selection_prompt": null
        }

        Return raw JSON only. No markdown fences.
        """
    }

    private func parseAIReplyToIntentResult(_ reply: AIChatReply, originalText: String) -> IntentRecognitionResult {
        // 尝试从响应文本解析 JSON
        if let jsonData = extractJSONFromReply(reply.text) {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            // 优先尝试新的多意图格式
            if let multiPayload = try? decoder.decode(AIRemoteMultiIntentPayload.self, from: jsonData) {
                // 如果有多个意图且需要用户选择，返回主要意图并在 alternativeIntents 中携带次要意图
                let primary = multiPayload.primaryIntent.toIntentRecognitionResult()
                if multiPayload.requiresUserSelection && multiPayload.intents.count > 1 {
                    let alternatives = multiPayload.secondaryIntents.map { item in
                        AlternativeIntent(
                            intentType: item.intentType,
                            confidence: item.confidence,
                            description: multiPayload.selectionPrompt ?? "Multiple intents detected"
                        )
                    }
                    return IntentRecognitionResult(
                        intentType: primary.intentType,
                        confidence: primary.confidence,
                        navigationTarget: primary.navigationTarget,
                        businessParameters: primary.businessParameters,
                        requiresConfirmation: true,
                        suggestedActions: [IntentAction(
                            id: "multi_intent_selection",
                            title: multiPayload.selectionPrompt ?? "Please select an action",
                            actionType: .showConfirmationDialog,
                            parameters: ["requires_selection": "true"]
                        )],
                        alternativeIntents: alternatives,
                        source: .remoteAI
                    )
                }
                return primary
            }

            // 兼容旧的单意图格式
            if let intentResult = try? decoder.decode(IntentRecognitionResult.self, from: jsonData) {
                return IntentRecognitionResult(
                    intentType: intentResult.intentType,
                    confidence: intentResult.confidence,
                    navigationTarget: intentResult.navigationTarget ?? intentResult.intentType.defaultNavigationTarget,
                    businessParameters: intentResult.businessParameters,
                    requiresConfirmation: intentResult.requiresConfirmation,
                    suggestedActions: intentResult.suggestedActions,
                    alternativeIntents: intentResult.alternativeIntents,
                    source: .remoteAI
                )
            }
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let fallbackCandidate = try decoder.decode(RemoteIntentPayload.self, from: extractJSONFromReply(reply.text) ?? Data())
            return IntentRecognitionResult(
                intentType: fallbackCandidate.intentType,
                confidence: fallbackCandidate.confidence,
                navigationTarget: fallbackCandidate.navigationTarget ?? fallbackCandidate.intentType.defaultNavigationTarget,
                businessParameters: fallbackCandidate.businessParameters,
                requiresConfirmation: fallbackCandidate.requiresConfirmation,
                suggestedActions: fallbackCandidate.suggestedActions,
                alternativeIntents: fallbackCandidate.alternativeIntents,
                source: .remoteAI
            )
        } catch {
            // 降级处理：基于关键词匹配
            return fallbackIntentResult(from: reply, originalText: originalText)
        }
    }

    /// 解析 AI 响应为多意图结果
    private func parseAIReplyToMultiIntentResult(_ reply: AIChatReply) -> MultiIntentRecognitionResult? {
        guard let jsonData = extractJSONFromReply(reply.text) else { return nil }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let payload = try? decoder.decode(AIRemoteMultiIntentPayload.self, from: jsonData) else {
            return nil
        }

        return payload.toMultiIntentResult()
    }

    func recognizeIntent(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage],
        language: AppLanguage
    ) async throws -> IntentRecognitionResult {
        let localResult = await localMatch(text: text, language: language)

        // CoreML 只在 shadow 或 fusedAuthoritative 模式下运行
        // disabled 模式下 classifier 为 nil，不运行
        let coreMLCandidate: IntentClassificationCandidate?
        if configuration.rolloutMode == .fusedAuthoritative || configuration.rolloutMode == .shadow {
            coreMLCandidate = await classifier?.classify(text: text, language: language)
        } else {
            coreMLCandidate = nil
        }

        let fusionResult = fusion.fuse(ruleResult: localResult, coreMLCandidate: coreMLCandidate)
        logFusion(text: text, fusionResult: fusionResult)

        var finalResult: IntentRecognitionResult

        switch configuration.rolloutMode {
        case .disabled:
            // 完全不使用 CoreML，只用 local 匹配
            if let localResult, localResult.isHighConfidence {
                finalResult = localResult
            } else {
                finalResult = IntentRecognitionResult(
                    intentType: .unknown,
                    confidence: 0.0,
                    requiresConfirmation: true,
                    source: .fallback
                )
            }

        case .shadow:
            // CoreML 运行但结果只打日志，决策逻辑与 disabled 相同
            if let localResult, localResult.isHighConfidence {
                finalResult = localResult
            } else {
                finalResult = IntentRecognitionResult(
                    intentType: .unknown,
                    confidence: 0.0,
                    requiresConfirmation: true,
                    source: .fallback
                )
            }

        case .fusedAuthoritative:
            if let result = fusionResult.finalResult, !fusionResult.requiresRemoteFallback {
                // 融合已完成 local+coreml 加权，不再二次加权
                finalResult = applyBusinessConfidencePolicies(result, localResult: nil)
            } else {
                finalResult = IntentRecognitionResult(
                    intentType: .unknown,
                    confidence: 0.0,
                    requiresConfirmation: true,
                    source: .fallback
                )
            }
        }

        // AI fallback path
        if finalResult.intentType == .unknown || fusionResult.requiresRemoteFallback {
            do {
                let remoteResult = try await aiSemanticMatch(
                    text: text,
                    context: context,
                    conversationHistory: conversationHistory
                )
                finalResult = applyBusinessConfidencePolicies(
                    IntentRecognitionResult(
                        intentType: remoteResult.intentType,
                        confidence: remoteResult.confidence,
                        navigationTarget: remoteResult.navigationTarget,
                        businessParameters: remoteResult.businessParameters,
                        requiresConfirmation: remoteResult.requiresConfirmation,
                        suggestedActions: remoteResult.suggestedActions,
                        alternativeIntents: remoteResult.alternativeIntents,
                        source: .remoteAI
                    ),
                    localResult: localResult
                )
            } catch {
                intentRecognitionLogger.error("AI match failed: \(error.localizedDescription)")

                if let fused = fusionResult.finalResult {
                    finalResult = applyBusinessConfidencePolicies(fused, localResult: nil)
                } else if let local = localResult {
                    intentRecognitionLogger.info("Falling back to local match result")
                    finalResult = applyBusinessConfidencePolicies(local, localResult: nil)
                }
            }
        }

        // Apply ONB persona fusion to enhance business parameters
        if let onbService = onbFusionService {
            let fused = await onbService.fuse(intentResult: finalResult, userText: text)
            finalResult = IntentRecognitionResult(
                intentType: finalResult.intentType,
                confidence: finalResult.confidence,
                navigationTarget: finalResult.navigationTarget,
                businessParameters: fused.enhancedBusinessParameters,
                requiresConfirmation: finalResult.requiresConfirmation,
                suggestedActions: finalResult.suggestedActions,
                alternativeIntents: finalResult.alternativeIntents,
                source: finalResult.source
            )
        }

        return finalResult
    }

    private func applyBusinessConfidencePolicies(
        _ result: IntentRecognitionResult,
        localResult: IntentRecognitionResult?
    ) -> IntentRecognitionResult {
        let normalizedLocal = localResult.map {
            IntentRecognitionResult(
                intentType: $0.intentType,
                confidence: $0.confidence,
                navigationTarget: $0.navigationTarget,
                businessParameters: $0.businessParameters,
                requiresConfirmation: $0.requiresConfirmation,
                suggestedActions: $0.suggestedActions,
                alternativeIntents: $0.alternativeIntents,
                source: $0.source
            )
        }

        let evaluated = confidenceCalculator.evaluate(
            aiResult: result,
            localResult: normalizedLocal
        )

        // 低置信度时注入确认机制
        let needsConfirmation = evaluated.confidence < 0.70 || evaluated.requiresConfirmation
        let confirmationActions: [IntentAction] = needsConfirmation
            ? buildConfirmationActions(for: evaluated.intentType, confidence: evaluated.confidence)
            : evaluated.suggestedActions

        return IntentRecognitionResult(
            intentType: evaluated.intentType,
            confidence: evaluated.confidence,
            navigationTarget: evaluated.navigationTarget,
            businessParameters: evaluated.businessParameters,
            requiresConfirmation: needsConfirmation,
            suggestedActions: needsConfirmation ? confirmationActions : evaluated.suggestedActions,
            alternativeIntents: evaluated.alternativeIntents,
            source: result.source ?? evaluated.source
        )
    }

    private func buildConfirmationActions(
        for intentType: UserIntentType,
        confidence: Double
    ) -> [IntentAction] {
        let question = confirmationQuestion(for: intentType)
        let confidencePercent = Int(confidence * 100)
        let title = "\(question) (匹配度 \(confidencePercent)%)"

        return [
            IntentAction(
                id: "confirm_\(intentType.rawValue)",
                title: title,
                actionType: .showConfirmationDialog,
                parameters: [
                    "intent_type": intentType.rawValue,
                    "confidence": String(format: "%.2f", confidence),
                    "action": "confirm"
                ]
            )
        ]
    }

    private func confirmationQuestion(for intentType: UserIntentType) -> String {
        switch intentType {
        case .dataUsageQuery:
            return "您想查看当前流量使用情况吗？"
        case .voiceUsageQuery:
            return "您想查看当前语音通话使用情况吗？"
        case .smsUsageQuery:
            return "您想查看当前短信使用情况吗？"
        case .balanceInquiry:
            return "您想查询账户余额吗？"
        case .rechargeAccount:
            return "您想为账户充值吗？"
        case .viewOffers:
            return "您想浏览可用的套餐优惠吗？"
        case .subscribeOffer:
            return "您想订购此套餐吗？"
        case .viewBill:
            return "您想查看账单吗？"
        case .accountHelp:
            return "您需要账户相关帮助吗？"
        case .makePayment:
            return "您想进行支付吗？"
        case .paymentHistory:
            return "您想查看支付记录吗？"
        case .paymentStatus:
            return "您想查询支付状态吗？"
        case .itineraryQuery:
            return "您想查询行程信息吗？"
        case .flightInfo:
            return "您想查询航班信息吗？"
        case .hotelInfo:
            return "您想查询酒店信息吗？"
        case .generalQuestion, .navigationIntent, .unknown:
            return "您能再详细描述一下您的需求吗？"
        }
    }

    private func logFusion(text: String, fusionResult: IntentSignalFusionResult) {
        let ruleIntent = fusionResult.ruleCandidate?.intentType.rawValue ?? "nil"
        let coreMLIntent = fusionResult.coreMLCandidate?.intentType.rawValue ?? "nil"
        let finalIntent = fusionResult.finalResult?.intentType.rawValue ?? "nil"
        let finalSource = fusionResult.finalSource?.rawValue ?? "nil"

        intentRecognitionLogger.debug(
            "Intent fusion completed. rule=\(ruleIntent, privacy: .public) coreml=\(coreMLIntent, privacy: .public) final=\(finalIntent, privacy: .public) source=\(finalSource, privacy: .public) text_length=\(text.count)"
        )
    }

    private func extractJSONFromReply(_ text: String) -> Data? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        var candidate = trimmed
        if candidate.hasPrefix("```") {
            candidate = candidate
                .replacingOccurrences(of: #"^```(?:json)?"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"```$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if candidate.first == "{" || candidate.first == "[" {
            return candidate.data(using: .utf8)
        }

        guard
            let start = candidate.firstIndex(where: { $0 == "{" || $0 == "[" }),
            let end = candidate.lastIndex(where: { $0 == "}" || $0 == "]" }),
            start < end
        else {
            return nil
        }

        return String(candidate[start ... end]).data(using: .utf8)
    }

    private func fallbackIntentResult(from reply: AIChatReply, originalText: String) -> IntentRecognitionResult {
        if let paymentCard = reply.paymentCard {
            let intentType: UserIntentType
            switch paymentCard.transactionType {
            case .recharge:
                intentType = .rechargeAccount
            case .subscription:
                intentType = .subscribeOffer
            case .billPayment:
                intentType = .makePayment
            }

            return IntentRecognitionResult(
                intentType: intentType,
                confidence: 0.82,
                navigationTarget: intentType.defaultNavigationTarget,
                requiresConfirmation: false
            )
        }

        if reply.paymentResult != nil {
            return IntentRecognitionResult(
                intentType: .paymentStatus,
                confidence: 0.8,
                navigationTarget: .billing,
                requiresConfirmation: false
            )
        }

        if reply.itineraryCard != nil {
            return IntentRecognitionResult(
                intentType: .itineraryQuery,
                confidence: 0.8,
                requiresConfirmation: false
            )
        }

        // 基于响应中的 actions 推断意图
        if let action = reply.actions.first, let target = action.target {
            let intentType = mapNavigationTargetToIntentType(target)
            return IntentRecognitionResult(
                intentType: intentType,
                confidence: 0.75, // 中置信度
                navigationTarget: target,
                requiresConfirmation: false
            )
        }

        // 基于推荐套餐推断意图
        if !reply.recommendedOffers.isEmpty {
            return IntentRecognitionResult(
                intentType: .viewOffers,
                confidence: 0.8,
                navigationTarget: .offers,
                requiresConfirmation: false
            )
        }

        // 未知意图
        return IntentRecognitionResult(
            intentType: .unknown,
            confidence: 0.3,
            requiresConfirmation: true
        )
    }

    private func mapNavigationTargetToIntentType(_ target: AIChatNavigationTarget) -> UserIntentType {
        switch target {
        case .home:
            return .balanceInquiry
        case .recharge:
            return .rechargeAccount
        case .offers:
            return .viewOffers
        case .billing:
            return .viewBill
        case .tickets:
            return .itineraryQuery
        case .me:
            return .accountHelp
        case .service:
            return .accountHelp
        case .mall:
            return .generalQuestion
        case .external:
            return .navigationIntent
        }
    }
}

private struct RemoteIntentPayload: Decodable {
    let intentType: UserIntentType
    let confidence: Double
    let navigationTarget: AIChatNavigationTarget?
    let businessParameters: [String: String]
    let requiresConfirmation: Bool
    let suggestedActions: [IntentAction]
    let alternativeIntents: [AlternativeIntent]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intentType = try container.decode(UserIntentType.self, forKey: .intentType)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        navigationTarget = try container.decodeIfPresent(AIChatNavigationTarget.self, forKey: .navigationTarget)
        businessParameters = try container.decodeIfPresent([String: String].self, forKey: .businessParameters) ?? [:]
        requiresConfirmation = try container.decodeIfPresent(Bool.self, forKey: .requiresConfirmation) ?? false
        suggestedActions = try container.decodeIfPresent([IntentAction].self, forKey: .suggestedActions) ?? []
        alternativeIntents = try container.decodeIfPresent([AlternativeIntent].self, forKey: .alternativeIntents) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case intentType
        case confidence
        case navigationTarget
        case businessParameters
        case requiresConfirmation
        case suggestedActions
        case alternativeIntents
    }
}

// MARK: - Mock Intent Recognition Service

struct MockIntentRecognitionService: IntentRecognitionServicing {
    func localMatch(text: String, language: AppLanguage) async -> IntentRecognitionResult? {
        let normalized = text.lowercased()

        // 模拟本地匹配逻辑
        if normalized.contains("balance") || normalized.contains("余额") {
            return IntentRecognitionResult(
                intentType: .balanceInquiry,
                confidence: 0.9,
                navigationTarget: .home
            )
        }

        if normalized.contains("recharge") || normalized.contains("充值") {
            return IntentRecognitionResult(
                intentType: .rechargeAccount,
                confidence: 0.9,
                navigationTarget: .recharge
            )
        }

        if normalized.contains("offer") || normalized.contains("优惠") {
            return IntentRecognitionResult(
                intentType: .viewOffers,
                confidence: 0.85,
                navigationTarget: .offers
            )
        }

        return nil
    }

    func aiSemanticMatch(
        text: String,
        context: AIChatContext,
        conversationHistory: [AIChatMessage]
    ) async throws -> IntentRecognitionResult {
        // 模拟 AI 匹配延迟
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒

        return IntentRecognitionResult(
            intentType: .unknown,
            confidence: 0.3,
            requiresConfirmation: true
        )
    }
}
