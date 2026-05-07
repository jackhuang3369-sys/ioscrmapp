import Foundation
import Testing

@testable import du_App

@Suite("Intent Classification Models Tests")
struct IntentClassificationModelsTests {

    @Test("AlternativeIntent serialization and properties")
    func testAlternativeIntentSerialization() throws {
        let alternative = AlternativeIntent(
            intentType: .accountHelp,
            confidence: 0.25,
            description: "Account assistance"
        )

        let encoded = try JSONEncoder().encode(alternative)
        let decoded = try JSONDecoder().decode(AlternativeIntent.self, from: encoded)

        #expect(decoded.intentType == alternative.intentType, "Intent type should match")
        #expect(decoded.confidence == alternative.confidence, "Confidence should match")
        #expect(decoded.description == alternative.description, "Description should match")
    }

    @Test("AlternativeIntent significance check")
    func testAlternativeIntentSignificance() throws {
        let significantIntent = AlternativeIntent(intentType: .balanceInquiry, confidence: 0.6)
        #expect(significantIntent.isSignificant, "Confidence > 0.5 should be significant")

        let insignificantIntent = AlternativeIntent(intentType: .balanceInquiry, confidence: 0.3)
        #expect(!insignificantIntent.isSignificant, "Confidence <= 0.5 should not be significant")
    }

    @Test("IntentRecognitionResult serialization")
    func testIntentRecognitionResultSerialization() throws {
        let result = IntentRecognitionResult(
            intentType: .balanceInquiry,
            confidence: 0.92,
            navigationTarget: .home,
            businessParameters: ["action": "view_balance"],
            requiresConfirmation: false,
            suggestedActions: [
                IntentAction(title: "View Balance", actionType: .navigate)
            ],
            alternativeIntents: [
                AlternativeIntent(intentType: .accountHelp, confidence: 0.15)
            ]
        )

        let encoded = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(IntentRecognitionResult.self, from: encoded)

        #expect(decoded.intentType == result.intentType, "Intent type should match")
        #expect(decoded.confidence == result.confidence, "Confidence should match")
        #expect(decoded.navigationTarget == result.navigationTarget, "Navigation target should match")
        #expect(decoded.businessParameters == result.businessParameters, "Business parameters should match")
        #expect(decoded.requiresConfirmation == result.requiresConfirmation, "Requires confirmation flag should match")
        #expect(decoded.suggestedActions.count == result.suggestedActions.count, "Suggested actions count should match")
        #expect(decoded.alternativeIntents.count == result.alternativeIntents.count, "Alternative intents count should match")
    }

    @Test("IntentRecognitionResult confidence levels")
    func testIntentRecognitionResultConfidenceLevels() throws {
        // 高置信度（≥ 0.85）
        let highConfidenceResult = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.92)
        #expect(highConfidenceResult.isHighConfidence, "Confidence ≥ 0.85 should be high")
        #expect(!highConfidenceResult.isMediumConfidence, "High confidence should not be medium")
        #expect(!highConfidenceResult.isLowConfidence, "High confidence should not be low")
        #expect(!highConfidenceResult.needsUserConfirmation, "High confidence should not need confirmation")

        // 中置信度（0.7 ~ 0.85）
        let mediumConfidenceResult = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.75)
        #expect(!mediumConfidenceResult.isHighConfidence, "Medium confidence should not be high")
        #expect(mediumConfidenceResult.isMediumConfidence, "Confidence 0.7 ~ 0.85 should be medium")
        #expect(!mediumConfidenceResult.isLowConfidence, "Medium confidence should not be low")
        #expect(!mediumConfidenceResult.needsUserConfirmation, "Medium confidence should not need confirmation")

        // 低置信度（< 0.7）
        let lowConfidenceResult = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.5)
        #expect(!lowConfidenceResult.isHighConfidence, "Low confidence should not be high")
        #expect(!lowConfidenceResult.isMediumConfidence, "Low confidence should not be medium")
        #expect(lowConfidenceResult.isLowConfidence, "Confidence < 0.7 should be low")
        #expect(lowConfidenceResult.needsUserConfirmation, "Low confidence should need confirmation")

        // 强制要求确认的情况
        let forcedConfirmationResult = IntentRecognitionResult(
            intentType: .subscribeOffer,
            confidence: 0.95,
            requiresConfirmation: true
        )
        #expect(forcedConfirmationResult.needsUserConfirmation, "Forced confirmation should override confidence")
    }

    @Test("IntentRecognitionResult utility properties")
    func testIntentRecognitionResultUtilityProperties() throws {
        let resultWithAlternatives = IntentRecognitionResult(
            intentType: .balanceInquiry,
            confidence: 0.85,
            alternativeIntents: [
                AlternativeIntent(intentType: .accountHelp, confidence: 0.1)
            ]
        )
        #expect(resultWithAlternatives.hasAlternatives, "Result with alternatives should return true")

        let resultWithoutAlternatives = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.85)
        #expect(!resultWithoutAlternatives.hasAlternatives, "Result without alternatives should return false")

        let resultWithActions = IntentRecognitionResult(
            intentType: .balanceInquiry,
            confidence: 0.85,
            suggestedActions: [IntentAction(title: "View Balance", actionType: .navigate)]
        )
        #expect(resultWithActions.hasSuggestedActions, "Result with actions should return true")

        let resultWithoutActions = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.85)
        #expect(!resultWithoutActions.hasSuggestedActions, "Result without actions should return false")
    }

    @Test("IntentRecognitionResult intent category")
    func testIntentRecognitionResultIntentCategory() throws {
        let telecomResult = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.9)
        #expect(telecomResult.intentCategory == .telecomBusiness, "Balance inquiry should be telecom business category")

        let paymentResult = IntentRecognitionResult(intentType: .makePayment, confidence: 0.9)
        #expect(paymentResult.intentCategory == .payment, "Make payment should be payment category")

        let itineraryResult = IntentRecognitionResult(intentType: .itineraryQuery, confidence: 0.9)
        #expect(itineraryResult.intentCategory == .itinerary, "Itinerary query should be itinerary category")
    }

    @Test("MultiIntentRecognitionResult serialization")
    func testMultiIntentRecognitionResultSerialization() throws {
        let primaryIntent = IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.9)
        let secondaryIntents = [
            IntentRecognitionResult(intentType: .accountHelp, confidence: 0.2)
        ]

        let multiResult = MultiIntentRecognitionResult(
            primaryIntent: primaryIntent,
            secondaryIntents: secondaryIntents,
            combinedNavigationTargets: [.home, .me]
        )

        let encoded = try JSONEncoder().encode(multiResult)
        let decoded = try JSONDecoder().decode(MultiIntentRecognitionResult.self, from: encoded)

        #expect(decoded.primaryIntent == multiResult.primaryIntent, "Primary intent should match")
        #expect(decoded.secondaryIntents.count == multiResult.secondaryIntents.count, "Secondary intents count should match")
        #expect(decoded.combinedNavigationTargets.count == multiResult.combinedNavigationTargets.count, "Combined navigation targets count should match")
    }

    @Test("MultiIntentRecognitionResult utility properties")
    func testMultiIntentRecognitionResultUtilityProperties() throws {
        let singleIntentResult = MultiIntentRecognitionResult(
            primaryIntent: IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.9)
        )
        #expect(!singleIntentResult.hasMultipleIntents, "Single intent should not be multi-intent")
        #expect(singleIntentResult.allIntents.count == 1, "All intents count should be 1")

        let multiIntentResult = MultiIntentRecognitionResult(
            primaryIntent: IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.9),
            secondaryIntents: [
                IntentRecognitionResult(intentType: .accountHelp, confidence: 0.2)
            ]
        )
        #expect(multiIntentResult.hasMultipleIntents, "Multi intent should be detected")
        #expect(multiIntentResult.allIntents.count == 2, "All intents count should be 2")
    }

    @Test("MultiIntentRecognitionResult average confidence")
    func testMultiIntentRecognitionResultAverageConfidence() throws {
        let multiResult = MultiIntentRecognitionResult(
            primaryIntent: IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.9),
            secondaryIntents: [
                IntentRecognitionResult(intentType: .accountHelp, confidence: 0.3)
            ]
        )

        let averageConfidence = multiResult.averageConfidence
        #expect(averageConfidence == 0.6, "Average confidence should be (0.9 + 0.3) / 2 = 0.6")
    }

    @Test("MultiIntentRecognitionResult highest confidence intent")
    func testMultiIntentRecognitionResultHighestConfidenceIntent() throws {
        let multiResult = MultiIntentRecognitionResult(
            primaryIntent: IntentRecognitionResult(intentType: .balanceInquiry, confidence: 0.7),
            secondaryIntents: [
                IntentRecognitionResult(intentType: .accountHelp, confidence: 0.9)
            ]
        )

        let highestConfidence = multiResult.highestConfidenceIntent
        #expect(highestConfidence.intentType == .accountHelp, "Highest confidence intent should be account help")
        #expect(highestConfidence.confidence == 0.9, "Highest confidence should be 0.9")
    }

    @Test("IntentRecognitionRequest serialization")
    func testIntentRecognitionRequestSerialization() throws {
        let context = AIChatContext(
            accessToken: "test_token",
            authorization: "Bearer test_token",
            userID: "user_123",
            serviceNumber: "12345678",
            subscriberKey: "sub_key",
            languageCode: "en",
            displayName: "Test User"
        )

        let request = IntentRecognitionRequest(
            text: "How can I check my balance?",
            language: .english,
            context: context,
            conversationHistory: [
                AIChatMessageSummary(sender: .user, text: "Previous message")
            ],
            options: IntentRecognitionOptions(enableMultiIntent: true, confidenceThreshold: 0.7)
        )

        let encoded = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(IntentRecognitionRequest.self, from: encoded)

        #expect(decoded.text == request.text, "Text should match")
        #expect(decoded.language == request.language, "Language should match")
        #expect(decoded.context.accessToken == request.context.accessToken, "Context access token should match")
        #expect(decoded.options.enableMultiIntent == request.options.enableMultiIntent, "Options should match")
    }

    @Test("IntentRecognitionOptions default values")
    func testIntentRecognitionOptionsDefaultValues() throws {
        let defaultOptions = IntentRecognitionOptions()

        #expect(defaultOptions.enableMultiIntent == true, "Default multi-intent should be enabled")
        #expect(defaultOptions.confidenceThreshold == 0.7, "Default confidence threshold should be 0.7")
        #expect(defaultOptions.enableLocalMatchFallback == true, "Default local match fallback should be enabled")
        #expect(defaultOptions.maxAlternativeIntents == 3, "Default max alternative intents should be 3")
    }

    @Test("IntentConfidenceLevel from confidence value")
    func testIntentConfidenceLevelFromValue() throws {
        #expect(IntentConfidenceLevel.from(confidence: 0.9) == .high, "0.9 should be high confidence")
        #expect(IntentConfidenceLevel.from(confidence: 0.85) == .high, "0.85 should be high confidence")
        #expect(IntentConfidenceLevel.from(confidence: 0.75) == .medium, "0.75 should be medium confidence")
        #expect(IntentConfidenceLevel.from(confidence: 0.7) == .medium, "0.7 should be medium confidence")
        #expect(IntentConfidenceLevel.from(confidence: 0.5) == .low, "0.5 should be low confidence")
        #expect(IntentConfidenceLevel.from(confidence: -0.1) == .unknown, "Negative confidence should be unknown")
    }

    @Test("IntentConfidenceLevel execution decision")
    func testIntentConfidenceLevelExecutionDecision() throws {
        #expect(IntentConfidenceLevel.high.canExecuteDirectly, "High confidence can execute directly")
        #expect(!IntentConfidenceLevel.medium.canExecuteDirectly, "Medium confidence cannot execute directly")
        #expect(!IntentConfidenceLevel.low.canExecuteDirectly, "Low confidence cannot execute directly")

        #expect(!IntentConfidenceLevel.high.needsConfirmation, "High confidence does not need confirmation")
        #expect(!IntentConfidenceLevel.medium.needsConfirmation, "Medium confidence does not need confirmation")
        #expect(IntentConfidenceLevel.low.needsConfirmation, "Low confidence needs confirmation")
        #expect(IntentConfidenceLevel.unknown.needsConfirmation, "Unknown needs confirmation")
    }
}
