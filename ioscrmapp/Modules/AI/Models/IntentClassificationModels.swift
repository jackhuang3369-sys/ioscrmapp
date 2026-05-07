import Foundation

enum IntentResolutionSource: String, Codable, Sendable, Equatable {
    case rule
    case coreml
    case fused
    case remoteAI = "remote_ai"
    case fallback
}

struct IntentClassificationCandidate: Codable, Sendable, Equatable {
    let intentType: UserIntentType
    let confidence: Double
    let source: IntentResolutionSource
    let navigationTarget: AIChatNavigationTarget?
    let businessParameters: [String: String]
    let requiresConfirmation: Bool

    init(
        intentType: UserIntentType,
        confidence: Double,
        source: IntentResolutionSource,
        navigationTarget: AIChatNavigationTarget? = nil,
        businessParameters: [String: String] = [:],
        requiresConfirmation: Bool = false
    ) {
        self.intentType = intentType
        self.confidence = confidence
        self.source = source
        self.navigationTarget = navigationTarget
        self.businessParameters = businessParameters
        self.requiresConfirmation = requiresConfirmation
    }
}

struct IntentSignalFusionResult: Sendable, Equatable {
    let finalResult: IntentRecognitionResult?
    let finalSource: IntentResolutionSource?
    let ruleCandidate: IntentClassificationCandidate?
    let coreMLCandidate: IntentClassificationCandidate?
    let requiresRemoteFallback: Bool
    let conflictDetected: Bool

    init(
        finalResult: IntentRecognitionResult?,
        finalSource: IntentResolutionSource?,
        ruleCandidate: IntentClassificationCandidate?,
        coreMLCandidate: IntentClassificationCandidate?,
        requiresRemoteFallback: Bool,
        conflictDetected: Bool
    ) {
        self.finalResult = finalResult
        self.finalSource = finalSource
        self.ruleCandidate = ruleCandidate
        self.coreMLCandidate = coreMLCandidate
        self.requiresRemoteFallback = requiresRemoteFallback
        self.conflictDetected = conflictDetected
    }
}

// MARK: - Alternative Intent

/// 替代意图模型，表示次要意图选项
struct AlternativeIntent: Codable, Sendable, Equatable {
    let intentType: UserIntentType
    let confidence: Double
    let description: String

    init(
        intentType: UserIntentType,
        confidence: Double,
        description: String = ""
    ) {
        self.intentType = intentType
        self.confidence = confidence
        self.description = description
    }

    /// 置信度是否显著（> 0.5）
    var isSignificant: Bool {
        confidence > 0.5
    }
}

// MARK: - Intent Recognition Result

/// 意图识别结果模型，包含主要意图、置信度、导航目标和建议动作
struct IntentRecognitionResult: Codable, Sendable, Equatable {
    let intentType: UserIntentType
    let confidence: Double // 0.0 ~ 1.0
    let navigationTarget: AIChatNavigationTarget?
    let businessParameters: [String: String]
    let requiresConfirmation: Bool
    let suggestedActions: [IntentAction]
    let alternativeIntents: [AlternativeIntent]
    let source: IntentResolutionSource?

    init(
        intentType: UserIntentType,
        confidence: Double,
        navigationTarget: AIChatNavigationTarget? = nil,
        businessParameters: [String: String] = [:],
        requiresConfirmation: Bool = false,
        suggestedActions: [IntentAction] = [],
        alternativeIntents: [AlternativeIntent] = [],
        source: IntentResolutionSource? = nil
    ) {
        self.intentType = intentType
        self.confidence = confidence
        self.navigationTarget = navigationTarget
        self.businessParameters = businessParameters
        self.requiresConfirmation = requiresConfirmation
        self.suggestedActions = suggestedActions
        self.alternativeIntents = alternativeIntents
        self.source = source
    }

    /// 高置信度阈值（≥ 0.85）
    var isHighConfidence: Bool {
        confidence >= 0.85
    }

    /// 中置信度区间（0.7 ~ 0.85）
    var isMediumConfidence: Bool {
        confidence >= 0.7 && confidence < 0.85
    }

    /// 低置信度（< 0.7）
    var isLowConfidence: Bool {
        confidence < 0.7
    }

    /// 是否需要用户确认（低置信度或强制要求确认）
    var needsUserConfirmation: Bool {
        confidence < 0.7 || requiresConfirmation
    }

    /// 是否有替代意图选项
    var hasAlternatives: Bool {
        !alternativeIntents.isEmpty
    }

    /// 是否有建议动作
    var hasSuggestedActions: Bool {
        !suggestedActions.isEmpty
    }

    /// 主要意图分类
    var intentCategory: IntentCategory {
        IntentCategory.category(for: intentType)
    }

    /// 置信度等级描述（用于日志和调试）
    var confidenceLevelDescription: String {
        if isHighConfidence {
            return "High (≥ 0.85)"
        } else if isMediumConfidence {
            return "Medium (0.7 ~ 0.85)"
        } else {
            return "Low (< 0.7)"
        }
    }
}

// MARK: - Multi Intent Recognition Result

/// 多意图识别结果模型，处理用户输入包含多个意图的场景
struct MultiIntentRecognitionResult: Codable, Sendable, Equatable {
    let primaryIntent: IntentRecognitionResult
    let secondaryIntents: [IntentRecognitionResult]
    let combinedNavigationTargets: [AIChatNavigationTarget]

    init(
        primaryIntent: IntentRecognitionResult,
        secondaryIntents: [IntentRecognitionResult] = [],
        combinedNavigationTargets: [AIChatNavigationTarget] = []
    ) {
        self.primaryIntent = primaryIntent
        self.secondaryIntents = secondaryIntents
        self.combinedNavigationTargets = combinedNavigationTargets
    }

    /// 是否有多个意图
    var hasMultipleIntents: Bool {
        !secondaryIntents.isEmpty
    }

    /// 所有意图列表（主要 + 次要）
    var allIntents: [IntentRecognitionResult] {
        [primaryIntent] + secondaryIntents
    }

    /// 平均置信度
    var averageConfidence: Double {
        guard !allIntents.isEmpty else {
            return 0.0
        }
        return allIntents.map { $0.confidence }.reduce(0, +) / Double(allIntents.count)
    }

    /// 最高置信度意图
    var highestConfidenceIntent: IntentRecognitionResult {
        allIntents.max(by: { $0.confidence < $1.confidence }) ?? primaryIntent
    }

    /// 是否有任何意图需要用户确认
    var anyNeedsConfirmation: Bool {
        allIntents.contains { $0.needsUserConfirmation }
    }

    /// 合并的业务参数
    var mergedBusinessParameters: [String: String] {
        var merged: [String: String] = [:]
        for intent in allIntents {
            for (key, value) in intent.businessParameters {
                // 如果键冲突，保留主要意图的值
                if merged[key] == nil {
                    merged[key] = value
                }
            }
        }
        return merged
    }
}

// MARK: - AI Remote Multi Intent Payload

/// AI 远端返回的多意图响应解析模型
struct AIRemoteMultiIntentPayload: Codable, Sendable, Equatable {
    let intents: [AIRemoteIntentItem]
    let primaryIntentIndex: Int
    let requiresUserSelection: Bool
    let selectionPrompt: String?

    var primaryIntent: AIRemoteIntentItem {
        if primaryIntentIndex >= 0 && primaryIntentIndex < intents.count {
            return intents[primaryIntentIndex]
        }
        return intents.first ?? AIRemoteIntentItem(intentType: .unknown, confidence: 0.0, businessParameters: [:])
    }

    var secondaryIntents: [AIRemoteIntentItem] {
        intents.enumerated()
            .filter { $0.offset != primaryIntentIndex }
            .map { $0.element }
    }

    /// 转换为 MultiIntentRecognitionResult
    func toMultiIntentResult() -> MultiIntentRecognitionResult {
        let primary = primaryIntent.toIntentRecognitionResult()
        let secondary = secondaryIntents.map { $0.toIntentRecognitionResult() }
        let targets = [primary.intentType.defaultNavigationTarget] + secondary.compactMap { $0.intentType.defaultNavigationTarget }

        return MultiIntentRecognitionResult(
            primaryIntent: primary,
            secondaryIntents: secondary,
            combinedNavigationTargets: targets.compactMap { $0 }
        )
    }
}

/// AI 远端返回的单个意图项
struct AIRemoteIntentItem: Codable, Sendable, Equatable {
    let intentType: UserIntentType
    let confidence: Double
    let businessParameters: [String: String]

    init(intentType: UserIntentType, confidence: Double, businessParameters: [String: String]) {
        self.intentType = intentType
        self.confidence = confidence
        self.businessParameters = businessParameters
    }

    func toIntentRecognitionResult() -> IntentRecognitionResult {
        IntentRecognitionResult(
            intentType: intentType,
            confidence: confidence,
            navigationTarget: intentType.defaultNavigationTarget,
            businessParameters: businessParameters,
            requiresConfirmation: confidence < 0.7,
            source: .remoteAI
        )
    }
}

// MARK: - Intent Recognition Request

/// 意图识别请求模型，发送给 AI 服务端
struct IntentRecognitionRequest: Codable, Sendable, Equatable {
    let text: String
    let language: AppLanguage
    let context: AIChatContext
    let conversationHistory: [AIChatMessageSummary]
    let options: IntentRecognitionOptions

    init(
        text: String,
        language: AppLanguage,
        context: AIChatContext,
        conversationHistory: [AIChatMessageSummary] = [],
        options: IntentRecognitionOptions = IntentRecognitionOptions()
    ) {
        self.text = text
        self.language = language
        self.context = context
        self.conversationHistory = conversationHistory
        self.options = options
    }
}

// MARK: - Intent Recognition Options

/// 意图识别选项配置
struct IntentRecognitionOptions: Codable, Sendable, Equatable {
    let enableMultiIntent: Bool
    let confidenceThreshold: Double
    let enableLocalMatchFallback: Bool
    let maxAlternativeIntents: Int

    init(
        enableMultiIntent: Bool = true,
        confidenceThreshold: Double = 0.7,
        enableLocalMatchFallback: Bool = true,
        maxAlternativeIntents: Int = 3
    ) {
        self.enableMultiIntent = enableMultiIntent
        self.confidenceThreshold = confidenceThreshold
        self.enableLocalMatchFallback = enableLocalMatchFallback
        self.maxAlternativeIntents = maxAlternativeIntents
    }
}

// MARK: - AI Chat Message Summary

/// AI 聊天消息摘要（用于意图识别请求，避免传输大量数据）
struct AIChatMessageSummary: Codable, Sendable, Equatable {
    let sender: AIChatSender
    let text: String
    let timestamp: Date

    init(sender: AIChatSender, text: String, timestamp: Date = Date()) {
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
    }

    /// 从完整消息创建摘要
    static func from(message: AIChatMessage) -> AIChatMessageSummary {
        AIChatMessageSummary(
            sender: message.sender,
            text: message.text,
            timestamp: message.createdAt
        )
    }
}

// MARK: - Intent Recognition Error

/// 意图识别错误类型
enum IntentRecognitionError: Error, Codable, Sendable, Equatable {
    case serviceUnavailable
    case invalidResponse
    case timeout
    case lowConfidence(confidence: Double)
    case multipleIntentsConflict
    case processingFailed(reason: String)

    var localizedDescription: String {
        switch self {
        case .serviceUnavailable:
            return "Intent recognition service is unavailable."
        case .invalidResponse:
            return "Received invalid response from intent recognition service."
        case .timeout:
            return "Intent recognition request timed out."
        case .lowConfidence(let confidence):
            return "Intent recognition confidence is too low: \(confidence)."
        case .multipleIntentsConflict:
            return "Multiple intents detected with conflicting actions."
        case .processingFailed(let reason):
            return "Intent recognition processing failed: \(reason)"
        }
    }
}

// MARK: - Intent Confidence Level

/// 置信度等级枚举，用于快速判断
enum IntentConfidenceLevel: String, Codable, Sendable, Equatable {
    case high = "high"       // ≥ 0.85
    case medium = "medium"   // 0.7 ~ 0.85
    case low = "low"         // < 0.7
    case unknown = "unknown" // 无法计算

    /// 从置信度数值判断等级
    static func from(confidence: Double) -> IntentConfidenceLevel {
        if confidence >= 0.85 {
            return .high
        } else if confidence >= 0.7 {
            return .medium
        } else if confidence >= 0.0 {
            return .low
        } else {
            return .unknown
        }
    }

    /// 是否可以直接执行
    var canExecuteDirectly: Bool {
        self == .high
    }

    /// 是否需要用户确认
    var needsConfirmation: Bool {
        self == .low || self == .unknown
    }
}
