import Foundation

// MARK: - ONB Persona Intent Type

/// ONB 人格画像意图类型，与 ONBIntentClassifier.mlmodel 的标签对齐
enum ONBPersonaIntent: String, Codable, Sendable, Equatable, CaseIterable {
    // ONB-02 Lifestyle Profiles
    case travelFrequent = "travel_frequent"
    case businessUsage = "business_usage"
    case gamingHeavy = "gaming_heavy"
    case videoStreamingHeavy = "video_streaming_heavy"
    case socialCommunicationHeavy = "social_communication_heavy"
    case budgetSensitive = "budget_sensitive"
    case studentUsage = "student_usage"
    case familyUsage = "family_usage"

    // ONB-03 Plan Selection
    case highDataUsage = "high_data_usage"
    case unlimitedPreference = "unlimited_preference"
    case highVoiceUsage = "high_voice_usage"
    case roamingRequired = "roaming_required"
    case budgetOptimization = "budget_optimization"
    case flexiblePlanPreference = "flexible_plan_preference"

    // ONB-06 Post-Activation Support
    case activationIssue = "activation_issue"
    case networkIssue = "network_issue"
    case billingQuery = "billing_query"
    case esimSetup = "esim_setup"
    case planChange = "plan_change"
    case dataUsageQuery = "data_usage_query"
    case roamingSupport = "roaming_support"
    case addFamilyMember = "add_family_member"

    /// 显示名称
    var displayName: String {
        switch self {
        case .travelFrequent: return "Frequent Traveler"
        case .businessUsage: return "Business User"
        case .gamingHeavy: return "Heavy Gamer"
        case .videoStreamingHeavy: return "Video Streaming Heavy"
        case .socialCommunicationHeavy: return "Social Communicator"
        case .budgetSensitive: return "Budget Sensitive"
        case .studentUsage: return "Student"
        case .familyUsage: return "Family User"
        case .highDataUsage: return "High Data User"
        case .unlimitedPreference: return "Unlimited Plan Preference"
        case .highVoiceUsage: return "High Voice User"
        case .roamingRequired: return "Roaming Required"
        case .budgetOptimization: return "Budget Optimizer"
        case .flexiblePlanPreference: return "Flexible Plan Preference"
        case .activationIssue: return "Activation Issue"
        case .networkIssue: return "Network Issue"
        case .billingQuery: return "Billing Query"
        case .esimSetup: return "eSIM Setup"
        case .planChange: return "Plan Change"
        case .dataUsageQuery: return "Data Usage Query"
        case .roamingSupport: return "Roaming Support"
        case .addFamilyMember: return "Add Family Member"
        }
    }

    /// ONB 阶段
    var stage: String {
        switch self {
        case .travelFrequent, .businessUsage, .gamingHeavy, .videoStreamingHeavy,
             .socialCommunicationHeavy, .budgetSensitive, .studentUsage, .familyUsage:
            return "ONB-02"
        case .highDataUsage, .unlimitedPreference, .highVoiceUsage, .roamingRequired,
             .budgetOptimization, .flexiblePlanPreference:
            return "ONB-03"
        case .activationIssue, .networkIssue, .billingQuery, .esimSetup,
             .planChange, .dataUsageQuery, .roamingSupport, .addFamilyMember:
            return "ONB-06"
        }
    }

    /// 分类
    var category: String {
        switch self {
        case .travelFrequent, .businessUsage, .gamingHeavy, .videoStreamingHeavy,
             .socialCommunicationHeavy, .budgetSensitive, .studentUsage, .familyUsage:
            return "lifestyle"
        case .highDataUsage, .unlimitedPreference, .highVoiceUsage, .roamingRequired,
             .budgetOptimization, .flexiblePlanPreference:
            return "plan"
        case .activationIssue, .networkIssue, .billingQuery, .esimSetup,
             .planChange, .dataUsageQuery, .roamingSupport, .addFamilyMember:
            return "service"
        }
    }
}

// MARK: - ONB Persona Result

struct ONBPersonaResult: Sendable, Equatable {
    let persona: ONBPersonaIntent
    let confidence: Double

    /// 转换为推荐动作
    var recommendedActions: [String] {
        switch persona {
        case .travelFrequent, .businessUsage:
            return ["recommend_roaming_plan", "prioritize_high_data", "show_international_minutes_addon"]
        case .gamingHeavy:
            return ["recommend_high_data_plan", "prioritize_low_latency", "show_unlimited_data_if_available"]
        case .videoStreamingHeavy, .highDataUsage, .unlimitedPreference:
            return ["recommend_unlimited_plan", "show_entertainment_addon"]
        case .budgetSensitive, .budgetOptimization:
            return ["recommend_best_value_plan", "show_price_saving_copy"]
        case .studentUsage:
            return ["show_student_offer_if_available", "recommend_budget_data_plan"]
        case .familyUsage, .addFamilyMember:
            return ["recommend_family_plan", "show_additional_sim_option"]
        case .activationIssue:
            return ["start_activation_status_check"]
        case .networkIssue:
            return ["start_network_troubleshooting_flow"]
        case .billingQuery:
            return ["open_billing_summary"]
        case .esimSetup:
            return ["open_esim_setup_guide"]
        case .planChange:
            return ["open_plan_change_flow"]
        case .dataUsageQuery:
            return ["open_data_usage_screen"]
        case .roamingSupport, .roamingRequired:
            return ["open_roaming_support_flow"]
        case .highVoiceUsage:
            return ["recommend_high_voice_plan", "show_international_call_addon"]
        case .flexiblePlanPreference:
            return ["show_flexible_plan_options"]
        case .socialCommunicationHeavy:
            return ["recommend_social_data_bundle"]
        }
    }

    /// 推荐提示
    var recommendationHint: String {
        switch persona {
        case .travelFrequent, .businessUsage:
            return "International roaming + reliable data + business communication benefits"
        case .gamingHeavy:
            return "High data, stable network, low latency"
        case .videoStreamingHeavy, .highDataUsage, .unlimitedPreference:
            return "Unlimited or high data plan with streaming benefits"
        case .budgetSensitive, .budgetOptimization:
            return "Best value and lower monthly fee"
        case .studentUsage:
            return "Student-friendly price with sufficient data"
        case .familyUsage, .addFamilyMember:
            return "Family sharing, additional SIM, shared data"
        case .activationIssue, .networkIssue, .billingQuery, .esimSetup, .planChange, .dataUsageQuery, .roamingSupport:
            return "Provide service support and next best action"
        default:
            return persona.displayName
        }
    }
}

// MARK: - ONB Model Descriptor

struct ONBModelDescriptor: Sendable, Equatable {
    let resourceName: String
    let version: String

    static let current = ONBModelDescriptor(
        resourceName: "ONBIntentClassifier",
        version: "1.0"
    )
}

// MARK: - ONB Classification Candidate

struct ONBPersonaCandidate: Sendable, Equatable {
    let persona: ONBPersonaIntent
    let confidence: Double
    let stage: String
    let category: String
}