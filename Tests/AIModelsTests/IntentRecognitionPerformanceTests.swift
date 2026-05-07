import Foundation
import Testing

@testable import du_App

@Suite("Intent Recognition Performance Tests")
struct IntentRecognitionPerformanceTests {

    @Test("Local matcher response time under 50ms")
    func testLocalMatcherPerformance() async throws {
        let matcher = LocalIntentMatcher()
        let testText = "How can I check my balance?"

        let startTime = Date()
        let _ = await matcher.match(text: testText, language: .english)
        let elapsed = Date().timeIntervalSince(startTime) * 1000 // 毫秒

        #expect(elapsed < 50, "Local matcher should respond in under 50ms: actual \(elapsed)ms")
    }

    @Test("Confidence calculator response time under 10ms")
    func testConfidenceCalculatorPerformance() throws {
        let calculator = IntentConfidenceCalculator()

        let aiResult = IntentRecognitionResult(
            intentType: .balanceInquiry,
            confidence: 0.75
        )

        let localResult = IntentRecognitionResult(
            intentType: .balanceInquiry,
            confidence: 0.9
        )

        let startTime = Date()
        let _ = calculator.evaluate(aiResult: aiResult, localResult: localResult)
        let elapsed = Date().timeIntervalSince(startTime) * 1000 // 毫秒

        #expect(elapsed < 10, "Confidence calculator should respond in under 10ms: actual \(elapsed)ms")
    }

    @Test("Batch local matching performance")
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

        let elapsed = Date().timeIntervalSince(startTime) * 1000 // 毫秒

        #expect(elapsed < 100, "Batch matching 8 cases should complete in under 100ms: actual \(elapsed)ms")
    }

    @Test("Mock AI service response time under 1s")
    func testMockAIServicePerformance() async throws {
        let mockService = MockIntentRecognitionService()

        let context = AIChatContext(
            accessToken: "test",
            authorization: "Bearer test",
            userID: "user_123",
            serviceNumber: "12345678",
            subscriberKey: "sub_key",
            languageCode: "en",
            displayName: "Test User"
        )

        let startTime = Date()
        let _ = try await mockService.aiSemanticMatch(
            text: "general question",
            context: context,
            conversationHistory: []
        )
        let elapsed = Date().timeIntervalSince(startTime) * 1000 // 毫秒

        #expect(elapsed < 1000, "Mock AI service should respond in under 1s: actual \(elapsed)ms")
    }
}
