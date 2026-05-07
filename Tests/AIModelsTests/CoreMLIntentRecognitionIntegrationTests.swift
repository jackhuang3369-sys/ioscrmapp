import Foundation
import Testing

@testable import du_App

@Suite("CoreML Intent Recognition Integration Tests")
struct CoreMLIntentRecognitionIntegrationTests {

    @Test("Fused-authoritative mode uses high-confidence CoreML result")
    func testFusedAuthoritativeUsesCoreML() async throws {
        let aiService = CountingAIChatService(
            replyText: #"{"intent_type":"general_question","confidence":0.4}"#
        )
        let service = DefaultIntentRecognitionService(
            aiChatService: aiService,
            classifier: StubIntentClassifier(
                candidate: IntentClassificationCandidate(
                    intentType: .itineraryQuery,
                    confidence: 0.92,
                    source: .coreml
                )
            ),
            configuration: IntentClassifierConfiguration(
                rolloutMode: .fusedAuthoritative,
                minimumAcceptedCoreMLConfidence: 0.8,
                minimumAcceptedFusedConfidence: 0.75,
                enableRemoteFallbackOnConflict: true
            )
        )

        let result = try await service.recognizeIntent(
            text: "please arrange a hongkong vacation for me",
            context: sampleContext(),
            conversationHistory: [],
            language: .english
        )

        #expect(result.intentType == .itineraryQuery)
        #expect(result.source == .coreml || result.source == .fused)
        #expect(await aiService.calls() == 0)
    }

    @Test("Shadow mode preserves remote authoritative path")
    func testShadowModePreservesRemotePath() async throws {
        let aiService = CountingAIChatService(
            replyText: #"{"intent_type":"view_offers","confidence":0.91}"#
        )
        let service = DefaultIntentRecognitionService(
            aiChatService: aiService,
            classifier: StubIntentClassifier(
                candidate: IntentClassificationCandidate(
                    intentType: .balanceInquiry,
                    confidence: 0.93,
                    source: .coreml
                )
            ),
            configuration: IntentClassifierConfiguration(
                rolloutMode: .shadow,
                minimumAcceptedCoreMLConfidence: 0.8,
                minimumAcceptedFusedConfidence: 0.75,
                enableRemoteFallbackOnConflict: true
            )
        )

        let result = try await service.recognizeIntent(
            text: "which offer is right for me today",
            context: sampleContext(),
            conversationHistory: [],
            language: .english
        )

        #expect(result.intentType == .viewOffers)
        #expect(result.source == .remoteAI)
        #expect(await aiService.calls() == 1)
    }

    @Test("High-risk CoreML result still requires confirmation")
    func testHighRiskCoreMLStillRequiresConfirmation() async throws {
        let aiService = CountingAIChatService(
            replyText: #"{"intent_type":"subscribe_offer","confidence":0.95}"#
        )
        let service = DefaultIntentRecognitionService(
            aiChatService: aiService,
            classifier: StubIntentClassifier(
                candidate: IntentClassificationCandidate(
                    intentType: .subscribeOffer,
                    confidence: 0.95,
                    source: .coreml
                )
            ),
            configuration: IntentClassifierConfiguration(
                rolloutMode: .fusedAuthoritative,
                minimumAcceptedCoreMLConfidence: 0.8,
                minimumAcceptedFusedConfidence: 0.75,
                enableRemoteFallbackOnConflict: true
            )
        )

        let result = try await service.recognizeIntent(
            text: "activate this bundle for me now",
            context: sampleContext(),
            conversationHistory: [],
            language: .english
        )

        #expect(result.intentType == .subscribeOffer)
        #expect(result.requiresConfirmation)
    }

    private func sampleContext() -> AIChatContext {
        AIChatContext(
            accessToken: "test",
            authorization: "Bearer test",
            userID: "user_123",
            serviceNumber: "12345678",
            subscriberKey: "sub_key",
            languageCode: "en",
            displayName: "Test User"
        )
    }
}

private actor CountingAIChatService: AIChatServicing {
    private let replyText: String
    private var callCount = 0

    init(replyText: String) {
        self.replyText = replyText
    }

    func sendMessage(
        _ text: String,
        conversationID: String?,
        context: AIChatContext,
        metadata: AIChatRequestMetadata?
    ) async throws -> AIChatReply {
        callCount += 1
        return AIChatReply(
            conversationID: conversationID ?? "coreml-test-conv",
            text: replyText,
            thinkingText: "",
            actions: []
        )
    }

    func calls() -> Int {
        callCount
    }
}

private struct StubIntentClassifier: IntentClassifierServicing {
    let candidate: IntentClassificationCandidate?

    func classify(text: String, language: AppLanguage) async -> IntentClassificationCandidate? {
        candidate
    }
}
