import Foundation

struct IntentSignalFusion {
    private let configuration: IntentClassifierConfiguration

    init(configuration: IntentClassifierConfiguration = .default) {
        self.configuration = configuration
    }

    func fuse(
        ruleResult: IntentRecognitionResult?,
        coreMLCandidate: IntentClassificationCandidate?
    ) -> IntentSignalFusionResult {
        let ruleCandidate = ruleResult.map {
            IntentClassificationCandidate(
                intentType: $0.intentType,
                confidence: $0.confidence,
                source: $0.source ?? .rule,
                navigationTarget: $0.navigationTarget,
                businessParameters: $0.businessParameters,
                requiresConfirmation: $0.requiresConfirmation
            )
        }

        switch (ruleCandidate, coreMLCandidate) {
        case (nil, nil):
            return IntentSignalFusionResult(
                finalResult: nil,
                finalSource: nil,
                ruleCandidate: nil,
                coreMLCandidate: nil,
                requiresRemoteFallback: true,
                conflictDetected: false
            )

        case (let rule?, nil):
            return finalizeSingle(candidate: rule, requiresRemoteFallback: !isAccepted(rule.confidence))

        case (nil, let coreml?):
            return finalizeSingle(candidate: coreml, requiresRemoteFallback: !isAccepted(coreml.confidence))

        case (let rule?, let coreml?):
            if isExplicitOrStructured(rule) || isHighCertaintyRule(rule) {
                return finalizeSingle(candidate: rule, requiresRemoteFallback: false)
            }

            if rule.intentType == coreml.intentType {
                let mergedConfidence = weightedAverage(
                    lhs: rule.confidence,
                    rhs: coreml.confidence,
                    lhsWeight: 0.4,
                    rhsWeight: 0.6
                )
                let merged = IntentRecognitionResult(
                    intentType: rule.intentType,
                    confidence: mergedConfidence,
                    navigationTarget: rule.navigationTarget ?? coreml.navigationTarget ?? rule.intentType.defaultNavigationTarget,
                    businessParameters: rule.businessParameters.isEmpty ? coreml.businessParameters : rule.businessParameters,
                    requiresConfirmation: mergedConfidence < configuration.minimumAcceptedFusedConfidence || rule.requiresConfirmation || coreml.requiresConfirmation,
                    suggestedActions: [],
                    alternativeIntents: [],
                    source: .fused
                )

                return IntentSignalFusionResult(
                    finalResult: merged,
                    finalSource: .fused,
                    ruleCandidate: rule,
                    coreMLCandidate: coreml,
                    requiresRemoteFallback: mergedConfidence < configuration.minimumAcceptedFusedConfidence,
                    conflictDetected: false
                )
            }

            // 冲突处理策略：区分高风险意图和普通意图
            let highRiskIntentTypes: [UserIntentType] = [.subscribeOffer, .makePayment]
            let isHighRisk = highRiskIntentTypes.contains(rule.intentType) || highRiskIntentTypes.contains(coreml.intentType)

            let preferred: IntentClassificationCandidate
            let alternative: IntentClassificationCandidate

            if isHighRisk {
                // 高风险意图：选择置信度更高的一方，但强制触发确认
                preferred = rule.confidence >= coreml.confidence ? rule : coreml
                alternative = rule.confidence < coreml.confidence ? rule : coreml
            } else {
                // 普通意图：CoreML 置信度 ≥ 0.7 时优先使用 CoreML 结果
                if coreml.confidence >= IntentConfidenceCalculator.minimumConfidenceThreshold {
                    preferred = coreml
                    alternative = rule
                } else {
                    preferred = rule.confidence >= coreml.confidence ? rule : coreml
                    alternative = rule.confidence < coreml.confidence ? rule : coreml
                }
            }

            let conflictResult = IntentRecognitionResult(
                intentType: preferred.intentType,
                confidence: min(preferred.confidence, configuration.minimumAcceptedFusedConfidence - 0.01),
                navigationTarget: preferred.navigationTarget ?? preferred.intentType.defaultNavigationTarget,
                businessParameters: preferred.businessParameters,
                requiresConfirmation: true,
                suggestedActions: [],
                alternativeIntents: [
                    AlternativeIntent(
                        intentType: alternative.intentType,
                        confidence: alternative.confidence,
                        description: "Conflicting local interpretation"
                    )
                ],
                source: .fused
            )

            return IntentSignalFusionResult(
                finalResult: conflictResult,
                finalSource: .fused,
                ruleCandidate: rule,
                coreMLCandidate: coreml,
                requiresRemoteFallback: configuration.enableRemoteFallbackOnConflict,
                conflictDetected: true
            )
        }
    }

    private func finalizeSingle(
        candidate: IntentClassificationCandidate,
        requiresRemoteFallback: Bool
    ) -> IntentSignalFusionResult {
        let result = IntentRecognitionResult(
            intentType: candidate.intentType,
            confidence: candidate.confidence,
            navigationTarget: candidate.navigationTarget ?? candidate.intentType.defaultNavigationTarget,
            businessParameters: candidate.businessParameters,
            requiresConfirmation: candidate.requiresConfirmation,
            suggestedActions: [],
            alternativeIntents: [],
            source: candidate.source
        )

        return IntentSignalFusionResult(
            finalResult: result,
            finalSource: candidate.source,
            ruleCandidate: candidate.source == .rule || candidate.source == .fallback ? candidate : nil,
            coreMLCandidate: candidate.source == .coreml ? candidate : nil,
            requiresRemoteFallback: requiresRemoteFallback,
            conflictDetected: false
        )
    }

    private func isExplicitOrStructured(_ candidate: IntentClassificationCandidate) -> Bool {
        if candidate.navigationTarget != nil && candidate.intentType == .navigationIntent {
            return true
        }

        return !candidate.businessParameters.isEmpty
    }

    private func isHighCertaintyRule(_ candidate: IntentClassificationCandidate) -> Bool {
        candidate.source == .rule
            && candidate.confidence >= IntentConfidenceCalculator.highConfidenceThreshold
    }

    private func isAccepted(_ confidence: Double) -> Bool {
        confidence >= configuration.minimumAcceptedCoreMLConfidence
    }

    private func weightedAverage(lhs: Double, rhs: Double, lhsWeight: Double, rhsWeight: Double) -> Double {
        (lhs * lhsWeight + rhs * rhsWeight) / (lhsWeight + rhsWeight)
    }
}
