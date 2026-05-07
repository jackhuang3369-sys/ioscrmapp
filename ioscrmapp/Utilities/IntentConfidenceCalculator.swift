import Foundation

// MARK: - Intent Confidence Calculator

/// 意图置信度计算器，评估和调整意图识别结果的置信度
final class IntentConfidenceCalculator: Sendable {
    /// 最小置信度阈值（低于此值需要用户确认）
    static let minimumConfidenceThreshold: Double = 0.7

    /// 高置信度阈值（高于此值可直接执行）
    static let highConfidenceThreshold: Double = 0.85

    /// 评估意图识别结果的置信度
    func evaluate(
        aiResult: IntentRecognitionResult,
        localResult: IntentRecognitionResult?
    ) -> IntentRecognitionResult {
        // 如果有本地匹配结果，进行融合评估
        if let localResult {
            return adjustConfidence(mergeResults(aiResult: aiResult, localResult: localResult))
        }

        // 单独评估 AI/本地融合结果，统一应用高风险和 unknown 策略
        return adjustConfidence(aiResult)
    }

    /// 融合 AI 和本地匹配结果
    private func mergeResults(
        aiResult: IntentRecognitionResult,
        localResult: IntentRecognitionResult
    ) -> IntentRecognitionResult {
        // 如果两者意图类型相同，加权融合置信度
        if aiResult.intentType == localResult.intentType {
            let mergedConfidence = weightedAverage(
                aiConfidence: aiResult.confidence,
                localConfidence: localResult.confidence,
                aiWeight: 0.6,
                localWeight: 0.4
            )

            return IntentRecognitionResult(
                intentType: aiResult.intentType,
                confidence: mergedConfidence,
                navigationTarget: aiResult.navigationTarget ?? localResult.navigationTarget,
                businessParameters: aiResult.businessParameters,
                requiresConfirmation: mergedConfidence < Self.minimumConfidenceThreshold,
                suggestedActions: aiResult.suggestedActions,
                alternativeIntents: aiResult.alternativeIntents
            )
        }

        // 意图类型不同，选择置信度更高的结果
        let higherConfidenceResult = aiResult.confidence > localResult.confidence ? aiResult : localResult

        // 添加另一个作为替代意图
        let lowerConfidenceResult = aiResult.confidence <= localResult.confidence ? aiResult : localResult
        let alternativeIntent = AlternativeIntent(
            intentType: lowerConfidenceResult.intentType,
            confidence: lowerConfidenceResult.confidence,
            description: "Alternative interpretation"
        )

        return IntentRecognitionResult(
            intentType: higherConfidenceResult.intentType,
            confidence: higherConfidenceResult.confidence * 0.9, // 略微降低置信度
            navigationTarget: higherConfidenceResult.navigationTarget,
            businessParameters: higherConfidenceResult.businessParameters,
            requiresConfirmation: true, // 意图冲突时需要确认
            suggestedActions: higherConfidenceResult.suggestedActions,
            alternativeIntents: [alternativeIntent]
        )
    }

    /// 调整置信度（基于业务规则）
    private func adjustConfidence(_ result: IntentRecognitionResult) -> IntentRecognitionResult {
        var adjustedConfidence = result.confidence

        // 高风险意图类型（订阅、支付）降低置信度，强制确认
        let highRiskIntentTypes: [UserIntentType] = [.subscribeOffer, .makePayment]
        if highRiskIntentTypes.contains(result.intentType) {
            adjustedConfidence = min(adjustedConfidence, 0.75)
        }

        // 未知意图降低置信度
        if result.intentType == .unknown {
            adjustedConfidence = 0.0
        }

        return IntentRecognitionResult(
            intentType: result.intentType,
            confidence: adjustedConfidence,
            navigationTarget: result.navigationTarget,
            businessParameters: result.businessParameters,
            requiresConfirmation: adjustedConfidence < Self.minimumConfidenceThreshold || highRiskIntentTypes.contains(result.intentType),
            suggestedActions: result.suggestedActions,
            alternativeIntents: result.alternativeIntents
        )
    }

    /// 加权平均置信度
    private func weightedAverage(
        aiConfidence: Double,
        localConfidence: Double,
        aiWeight: Double,
        localWeight: Double
    ) -> Double {
        return (aiConfidence * aiWeight + localConfidence * localWeight) / (aiWeight + localWeight)
    }

    /// 计算多意图场景的综合置信度
    func calculateMultiIntentConfidence(results: [IntentRecognitionResult]) -> Double {
        guard !results.isEmpty else {
            return 0.0
        }

        // 加权平均（主要意图权重更高）
        let weights = results.enumerated().map { index, _ in
            index == 0 ? 0.6 : 0.4 / Double(results.count - 1)
        }

        let totalWeight = weights.reduce(0, +)
        let weightedSum = results.enumerated().reduce(0.0) { sum, pair in
            let (index, result) = pair
            return sum + result.confidence * weights[index]
        }

        return weightedSum / totalWeight
    }

    /// 判断是否需要用户确认
    func needsConfirmation(_ result: IntentRecognitionResult) -> Bool {
        // 置信度低于阈值
        if result.confidence < Self.minimumConfidenceThreshold {
            return true
        }

        // 高风险意图类型
        let highRiskIntentTypes: [UserIntentType] = [.subscribeOffer, .makePayment]
        if highRiskIntentTypes.contains(result.intentType) {
            return true
        }

        // 意图冲突（有替代意图）
        if result.hasAlternatives && result.alternativeIntents.contains(where: { $0.confidence > 0.5 }) {
            return true
        }

        return false
    }
}
