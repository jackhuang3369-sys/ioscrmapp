import Foundation
import Testing

@testable import du_App

@Suite("Intent Models Tests")
struct IntentModelsTests {

    @Test("UserIntentType enumeration serialization")
    func testUserIntentTypeSerialization() throws {
        // 测试所有意图类型的序列化和反序列化
        for intentType in UserIntentType.allCases {
            let encoded = try JSONEncoder().encode(intentType)
            let decoded = try JSONDecoder().decode(UserIntentType.self, from: encoded)

            #expect(decoded == intentType, "Intent type should serialize and deserialize correctly")
            #expect(decoded.rawValue == intentType.rawValue, "Raw value should match")
        }
    }

    @Test("UserIntentType display names for all languages")
    func testUserIntentTypeDisplayNames() throws {
        let intentType = UserIntentType.balanceInquiry

        // 测试英文显示名称
        let englishName = intentType.displayName(for: .english)
        #expect(englishName == "Balance Inquiry", "English display name should match")

        // 测试中文显示名称
        let chineseName = intentType.displayName(for: .simplifiedChinese)
        #expect(chineseName == "查询余额", "Chinese display name should match")

        // 测试阿拉伯语显示名称
        let arabicName = intentType.displayName(for: .arabic)
        #expect(arabicName == "استعلام الرصيد", "Arabic display name should match")
    }

    @Test("UserIntentType classification prompts")
    func testUserIntentTypeClassificationPrompts() throws {
        for intentType in UserIntentType.allCases {
            let prompt = intentType.classificationPrompt
            #expect(!prompt.isEmpty, "Classification prompt should not be empty for \(intentType.rawValue)")
        }
    }

    @Test("UserIntentType default navigation targets")
    func testUserIntentTypeDefaultNavigationTargets() throws {
        // 测试有明确导航目标的意图类型
        let balanceIntent = UserIntentType.balanceInquiry
        #expect(balanceIntent.defaultNavigationTarget == .home, "Balance inquiry should navigate to home")

        let rechargeIntent = UserIntentType.rechargeAccount
        #expect(rechargeIntent.defaultNavigationTarget == .recharge, "Recharge should navigate to recharge")

        let offersIntent = UserIntentType.viewOffers
        #expect(offersIntent.defaultNavigationTarget == .offers, "View offers should navigate to offers")

        // 测试没有明确导航目标的意图类型
        let generalIntent = UserIntentType.generalQuestion
        #expect(generalIntent.defaultNavigationTarget == nil, "General question should have no default navigation")
    }

    @Test("IntentAction serialization and properties")
    func testIntentActionSerialization() throws {
        let action = IntentAction(
            id: "action_123",
            title: "View Balance",
            actionType: .navigate,
            parameters: ["target": "home"]
        )

        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(IntentAction.self, from: encoded)

        #expect(decoded.id == action.id, "Action ID should match")
        #expect(decoded.title == action.title, "Action title should match")
        #expect(decoded.actionType == action.actionType, "Action type should match")
        #expect(decoded.parameters == action.parameters, "Action parameters should match")
    }

    @Test("IntentCategory categorization")
    func testIntentCategoryCategorization() throws {
        // 测试电信业务意图分类
        #expect(IntentCategory.category(for: .balanceInquiry) == .telecomBusiness)
        #expect(IntentCategory.category(for: .rechargeAccount) == .telecomBusiness)
        #expect(IntentCategory.category(for: .viewOffers) == .telecomBusiness)

        // 测试支付意图分类
        #expect(IntentCategory.category(for: .makePayment) == .payment)
        #expect(IntentCategory.category(for: .paymentHistory) == .payment)

        // 测试行程意图分类
        #expect(IntentCategory.category(for: .itineraryQuery) == .itinerary)
        #expect(IntentCategory.category(for: .flightInfo) == .itinerary)

        // 测试通用意图分类
        #expect(IntentCategory.category(for: .generalQuestion) == .general)
        #expect(IntentCategory.category(for: .unknown) == .general)
    }

    @Test("UserIntentType unknown intent handling")
    func testUnknownIntentHandling() throws {
        let unknownIntent = UserIntentType.unknown

        #expect(unknownIntent.rawValue == "unknown", "Unknown intent raw value should be 'unknown'")
        #expect(unknownIntent.defaultNavigationTarget == nil, "Unknown intent should have no default navigation")
        #expect(unknownIntent.displayName(for: .english) == "Unknown Intent", "Unknown intent should have appropriate display name")
    }
}
