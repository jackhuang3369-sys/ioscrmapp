import XCTest
@testable import du_App

final class IntentModelsXCTests: XCTestCase {
    func testUserIntentTypeSerialization() throws {
        // 测试所有意图类型的序列化和反序列化
        for intentType in UserIntentType.allCases {
            let encoded = try JSONEncoder().encode(intentType)
            let decoded = try JSONDecoder().decode(UserIntentType.self, from: encoded)

            XCTAssertEqual(decoded, intentType, "Intent type should serialize correctly")
            XCTAssertEqual(decoded.rawValue, intentType.rawValue, "Raw value should match")
        }
    }

    func testUserIntentTypeDisplayNames() throws {
        let intentType = UserIntentType.balanceInquiry

        // 测试英文显示名称
        XCTAssertEqual(intentType.displayName(for: .english), "Balance Inquiry")

        // 测试中文显示名称
        XCTAssertEqual(intentType.displayName(for: .simplifiedChinese), "查询余额")

        // 测试阿拉伯语显示名称
        XCTAssertEqual(intentType.displayName(for: .arabic), "استعلام الرصيد")
    }

    func testUserIntentTypeClassificationPrompts() throws {
        for intentType in UserIntentType.allCases {
            let prompt = intentType.classificationPrompt
            XCTAssertFalse(prompt.isEmpty, "Classification prompt should not be empty")
        }
    }

    func testUserIntentTypeDefaultNavigationTargets() throws {
        // 测试有明确导航目标的意图类型
        XCTAssertEqual(UserIntentType.balanceInquiry.defaultNavigationTarget, .home)
        XCTAssertEqual(UserIntentType.rechargeAccount.defaultNavigationTarget, .recharge)
        XCTAssertEqual(UserIntentType.viewOffers.defaultNavigationTarget, .offers)

        // 测试没有明确导航目标的意图类型
        XCTAssertNil(UserIntentType.generalQuestion.defaultNavigationTarget)
    }

    func testIntentActionSerialization() throws {
        let action = IntentAction(
            id: "action_123",
            title: "View Balance",
            actionType: .navigate,
            parameters: ["target": "home"]
        )

        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(IntentAction.self, from: encoded)

        XCTAssertEqual(decoded.id, action.id)
        XCTAssertEqual(decoded.title, action.title)
        XCTAssertEqual(decoded.actionType, action.actionType)
        XCTAssertEqual(decoded.parameters, action.parameters)
    }

    func testIntentCategoryCategorization() throws {
        // 测试电信业务意图分类
        XCTAssertEqual(IntentCategory.category(for: .balanceInquiry), .telecomBusiness)
        XCTAssertEqual(IntentCategory.category(for: .rechargeAccount), .telecomBusiness)

        // 测试支付意图分类
        XCTAssertEqual(IntentCategory.category(for: .makePayment), .payment)

        // 测试行程意图分类
        XCTAssertEqual(IntentCategory.category(for: .itineraryQuery), .itinerary)

        // 测试通用意图分类
        XCTAssertEqual(IntentCategory.category(for: .generalQuestion), .general)
    }
}

final class IntentClassificationModelsXCTests: XCTestCase {
    func testAlternativeIntentSerialization() throws {
        let alternative = AlternativeIntent(
            intentType: .accountHelp,
            confidence: 0.25,
            description: "Account assistance"
        )

        let encoded = try JSONEncoder().encode(alternative)
        let decoded = try JSONDecoder().decode(AlternativeIntent.self, from: encoded)

        XCTAssertEqual(decoded.intentType, alternative.intentType)
        XCTAssertEqual(decoded.confidence, alternative.confidence)
        XCTAssertEqual(decoded.description, alternative.description)
    }

    func testIntentRecognitionResultConfidenceLevels() throws {
        // 高置信度（≥ 0.85）
        let highConfidenceResult = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.92)
        XCTAssertTrue(highConfidenceResult.isHighConfidence)
        XCTAssertFalse(highConfidenceResult.needsUserConfirmation)

        // 中置信度（0.7 ~ 0.85）
        let mediumConfidenceResult = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.75)
        XCTAssertFalse(mediumConfidenceResult.isHighConfidence)
        XCTAssertFalse(mediumConfidenceResult.needsUserConfirmation)

        // 低置信度（< 0.7）
        let lowConfidenceResult = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.5)
        XCTAssertFalse(lowConfidenceResult.isHighConfidence)
        XCTAssertTrue(lowConfidenceResult.needsUserConfirmation)
    }

    func testMultiIntentRecognitionResult() throws {
        let primaryIntent = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.9)
        let secondaryIntents = [
            IntentRecognitionResult(intentType: .accountHelp, confidence: 0.2)
        ]

        let multiResult = MultiIntentRecognitionResult(
            primaryIntent: primaryIntent,
            secondaryIntents: secondaryIntents
        )

        XCTAssertTrue(multiResult.hasMultipleIntents)
        XCTAssertEqual(multiResult.allIntents.count, 2)
        XCTAssertEqual(multiResult.averageConfidence, 0.55)
    }

    func testIntentConfidenceLevelFromValue() throws {
        XCTAssertEqual(IntentConfidenceLevel.from(confidence: 0.9), .high)
        XCTAssertEqual(IntentConfidenceLevel.from(confidence: 0.75), .medium)
        XCTAssertEqual(IntentConfidenceLevel.from(confidence: 0.5), .low)
        XCTAssertEqual(IntentConfidenceLevel.from(confidence: -0.1), .unknown)
    }
}

final class IntentRecognitionIntegrationXCTests: XCTestCase {
    func testLocalMatcherBalanceInquiry() async throws {
        let matcher = LocalIntentMatcher()

        // 测试英文
        let englishResult = await matcher.match(text: "How can I check my balance?", language: .english)
        XCTAssertEqual(englishResult?.intentType, .balanceInquiry)
        XCTAssertTrue(englishResult?.isHighConfidence ?? false)

        // 测试中文
        let chineseResult = await matcher.match(text: "查看余额", language: .simplifiedChinese)
        XCTAssertEqual(chineseResult?.intentType, .balanceInquiry)
    }

    func testLocalMatcherRecharge() async throws {
        let matcher = LocalIntentMatcher()

        // 测试英文
        let englishResult = await matcher.match(text: "Recharge my account", language: .english)
        XCTAssertEqual(englishResult?.intentType, .rechargeAccount)
        XCTAssertEqual(englishResult?.navigationTarget, .recharge)

        // 测试中文
        let chineseResult = await matcher.match(text: "充值", language: .simplifiedChinese)
        XCTAssertEqual(chineseResult?.intentType, .rechargeAccount)
    }

    func testConfidenceCalculatorHighConfidence() throws {
        let calculator = IntentConfidenceCalculator()

        let highConfidenceResult = IntentRecognitionResult(
            intentType: .balanceInquiry,
            confidence: 0.9
        )

        let evaluated = calculator.evaluate(aiResult: highConfidenceResult, localResult: nil)
        XCTAssertTrue(evaluated.isHighConfidence)
        XCTAssertFalse(evaluated.needsUserConfirmation)
    }

    func testConfidenceCalculatorHighRiskIntent() throws {
        let calculator = IntentConfidenceCalculator()

        // 高风险意图（订阅套餐）需要确认
        let subscribeResult = IntentRecognitionResult(
            intentType: .subscribeOffer,
            confidence: 0.95
        )

        let evaluated = calculator.evaluate(aiResult: subscribeResult, localResult: nil)
        XCTAssertTrue(evaluated.needsUserConfirmation)
    }

    func testMockIntentRecognitionService() async throws {
        let mockService = MockIntentRecognitionService()

        // 测试本地匹配
        let localResult = await mockService.localMatch(text: "check balance", language: .english)
        XCTAssertEqual(localResult?.intentType, .balanceInquiry)

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
        XCTAssertEqual(aiResult.intentType, .generalQuestion)
    }
}

final class IntentRecognitionPerformanceXCTests: XCTestCase {
    func testLocalMatcherPerformance() async throws {
        let matcher = LocalIntentMatcher()
        let testText = "How can I check my balance?"

        let startTime = Date()
        let _ = await matcher.match(text: testText, language: .english)
        let elapsed = Date().timeIntervalSince(startTime) * 1000

        XCTAssertLessThan(elapsed, 50, "Local matcher should respond in under 50ms")
    }

    func testConfidenceCalculatorPerformance() throws {
        let calculator = IntentConfidenceCalculator()

        let aiResult = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.75)
        let localResult = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.9)

        let startTime = Date()
        let _ = calculator.evaluate(aiResult: aiResult, localResult: localResult)
        let elapsed = Date().timeIntervalSince(startTime) * 1000

        XCTAssertLessThan(elapsed, 10, "Confidence calculator should respond in under 10ms")
    }

    func testBatchLocalMatchingPerformance() async throws {
        let matcher = LocalIntentMatcher()
        let testCases = [
            "check balance",
            "recharge account",
            "view offers",
            "subscribe package",
            "view bill",
            "random text 1",
            "random text 2",
            "random text 3"
        ]

        let startTime = Date()

        for text in testCases {
            _ = await matcher.match(text: text, language: .english)
        }

        let elapsed = Date().timeIntervalSince(startTime) * 1000

        XCTAssertLessThan(elapsed, 100, "Batch matching should complete in under 100ms")
    }
}
