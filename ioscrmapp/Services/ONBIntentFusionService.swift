import Foundation

// MARK: - ONB Intent Fusion Service

/// 将 ONB 人格画像与标准意图识别结果融合
/// 用途：在标准意图识别基础上，增加个性化推荐信号
final class ONBIntentFusionService: Sendable {
    private let personaClassifier: any ONBPersonaClassifying

    init(personaClassifier: any ONBPersonaClassifying = MockONBPersonaClassifier()) {
        self.personaClassifier = personaClassifier
    }

    /// 融合标准意图 + ONB 人格画像
    func fuse(
        intentResult: IntentRecognitionResult,
        userText: String
    ) async -> IntentFusionResult {
        // 并行执行意图识别和人格画像分类
        async let personaTask = personaClassifier.classifyPersona(text: userText)

        // 等待人格分类结果
        let personaResult = await personaTask

        return IntentFusionResult(
            intentResult: intentResult,
            personaResult: personaResult,
            // 注入推荐动作（如果有人格匹配）
            enhancedBusinessParameters: buildEnhancedParams(
                intent: intentResult,
                persona: personaResult
            )
        )
    }

    private func buildEnhancedParams(
        intent: IntentRecognitionResult,
        persona: ONBPersonaResult?
    ) -> [String: String] {
        var params = intent.businessParameters

        if let persona = persona {
            params["onb_persona"] = persona.persona.rawValue
            params["onb_stage"] = persona.persona.stage
            params["persona_confidence"] = String(format: "%.2f", persona.confidence)
            params["recommendation_hint"] = persona.recommendationHint

            // 添加推荐动作
            let actions = persona.recommendedActions.joined(separator: ",")
            params["recommended_actions"] = actions
        }

        return params
    }
}

// MARK: - Fusion Result

struct IntentFusionResult: Sendable, Equatable {
    let intentResult: IntentRecognitionResult
    let personaResult: ONBPersonaResult?
    let enhancedBusinessParameters: [String: String]

    var hasPersona: Bool { personaResult != nil }

    var primaryIntent: UserIntentType { intentResult.intentType }
    var primaryConfidence: Double { intentResult.confidence }

    var persona: ONBPersonaIntent? { personaResult?.persona }
    var personaConfidence: Double? { personaResult?.confidence }

    var recommendationActions: [String] {
        personaResult?.recommendedActions ?? []
    }

    var recommendationHint: String? {
        personaResult?.recommendationHint
    }
}

// MARK: - ONB Persona Intent Router

/// 基于 ONB 人格画像的路由决策
/// 当标准意图路由无法处理时，参考人格画像做推荐
final class ONBPersonaRouter: Sendable {
    func recommendedAction(for persona: ONBPersonaIntent) -> ONBPersonaAction {
        switch persona {
        case .travelFrequent, .businessUsage:
            return .recommendRoamingPlan
        case .gamingHeavy:
            return .recommendHighDataLowLatency
        case .videoStreamingHeavy, .unlimitedPreference:
            return .recommendUnlimitedPlan
        case .budgetSensitive, .budgetOptimization:
            return .recommendBestValue
        case .studentUsage:
            return .showStudentOffer
        case .familyUsage:
            return .recommendFamilyPlan
        case .highVoiceUsage:
            return .recommendHighVoicePlan
        case .highDataUsage:
            return .recommendHighDataPlan
        case .activationIssue:
            return .startActivationCheck
        case .networkIssue:
            return .startNetworkTroubleshooting
        case .billingQuery:
            return .openBillingSummary
        case .esimSetup:
            return .openESIMGuide
        case .planChange:
            return .openPlanChangeFlow
        case .dataUsageQuery:
            return .openDataUsageScreen
        case .roamingSupport, .roamingRequired:
            return .openRoamingSupport
        case .addFamilyMember:
            return .openFamilyMemberAddFlow
        case .flexiblePlanPreference:
            return .showFlexiblePlanOptions
        case .socialCommunicationHeavy:
            return .recommendSocialDataBundle
        }
    }
}

enum ONBPersonaAction: String, Sendable {
    case recommendRoamingPlan = "recommend_roaming_plan"
    case recommendHighDataLowLatency = "recommend_high_data_low_latency"
    case recommendUnlimitedPlan = "recommend_unlimited_plan"
    case recommendBestValue = "recommend_best_value"
    case showStudentOffer = "show_student_offer"
    case recommendFamilyPlan = "recommend_family_plan"
    case recommendHighVoicePlan = "recommend_high_voice_plan"
    case recommendHighDataPlan = "recommend_high_data_plan"
    case startActivationCheck = "start_activation_status_check"
    case startNetworkTroubleshooting = "start_network_troubleshooting_flow"
    case openBillingSummary = "open_billing_summary"
    case openESIMGuide = "open_esim_setup_guide"
    case openPlanChangeFlow = "open_plan_change_flow"
    case openDataUsageScreen = "open_data_usage_screen"
    case openRoamingSupport = "open_roaming_support_flow"
    case openFamilyMemberAddFlow = "open_family_member_add_flow"
    case showFlexiblePlanOptions = "show_flexible_plan_options"
    case recommendSocialDataBundle = "recommend_social_data_bundle"
}