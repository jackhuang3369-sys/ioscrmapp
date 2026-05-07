import Foundation
import Testing

@testable import du_App

@Suite("Intent Signal Fusion Tests")
struct IntentSignalFusionTests {

    @Test("Rule and CoreML agreement produces fused result")
    func testAgreementFusion() throws {
        let fusion = IntentSignalFusion(configuration: .default)
        let ruleResult = IntentRecognitionResult(
            intentType: .viewOffers,
            confidence: 0.72,
            navigationTarget: .offers,
            source: .rule
        )
        let coreMLCandidate = IntentClassificationCandidate(
            intentType: .viewOffers,
            confidence: 0.88,
            source: .coreml,
            navigationTarget: .offers
        )

        let result = fusion.fuse(ruleResult: ruleResult, coreMLCandidate: coreMLCandidate)

        #expect(result.finalResult?.intentType == .viewOffers)
        #expect(result.finalSource == .fused)
        #expect(result.conflictDetected == false)
        #expect(result.requiresRemoteFallback == false)
    }

    @Test("Rule and CoreML conflict requests remote fallback")
    func testConflictFusion() throws {
        let fusion = IntentSignalFusion(configuration: .default)
        let ruleResult = IntentRecognitionResult(
            intentType: .viewBill,
            confidence: 0.7,
            navigationTarget: .billing,
            source: .rule
        )
        let coreMLCandidate = IntentClassificationCandidate(
            intentType: .viewOffers,
            confidence: 0.9,
            source: .coreml,
            navigationTarget: .offers
        )

        let result = fusion.fuse(ruleResult: ruleResult, coreMLCandidate: coreMLCandidate)

        #expect(result.finalSource == .fused)
        #expect(result.conflictDetected)
        #expect(result.requiresRemoteFallback)
        #expect(result.finalResult?.requiresConfirmation == true)
        #expect(result.finalResult?.alternativeIntents.isEmpty == false)
    }

    @Test("Explicit or structured rule signal stays authoritative")
    func testStructuredRuleWins() throws {
        let fusion = IntentSignalFusion(configuration: .default)
        let ruleResult = IntentRecognitionResult(
            intentType: .navigationIntent,
            confidence: 0.66,
            navigationTarget: .offers,
            businessParameters: ["explicit_navigation": "true"],
            source: .rule
        )
        let coreMLCandidate = IntentClassificationCandidate(
            intentType: .generalQuestion,
            confidence: 0.94,
            source: .coreml
        )

        let result = fusion.fuse(ruleResult: ruleResult, coreMLCandidate: coreMLCandidate)

        #expect(result.finalSource == .rule)
        #expect(result.requiresRemoteFallback == false)
        #expect(result.finalResult?.intentType == .navigationIntent)
    }

    @Test("High-certainty local rule stays authoritative over CoreML conflict")
    func testHighCertaintyRuleWinsOverCoreMLConflict() throws {
        let fusion = IntentSignalFusion(configuration: .default)
        let ruleResult = IntentRecognitionResult(
            intentType: .dataUsageQuery,
            confidence: 0.92,
            navigationTarget: .home,
            source: .rule
        )
        let coreMLCandidate = IntentClassificationCandidate(
            intentType: .viewOffers,
            confidence: 0.91,
            source: .coreml,
            navigationTarget: .offers
        )

        let result = fusion.fuse(ruleResult: ruleResult, coreMLCandidate: coreMLCandidate)

        #expect(result.finalSource == .rule)
        #expect(result.finalResult?.intentType == .dataUsageQuery)
        #expect(result.conflictDetected == false)
        #expect(result.requiresRemoteFallback == false)
    }

    @Test("Low-confidence CoreML only result requires remote fallback")
    func testLowConfidenceCoreMLFallsBack() throws {
        let fusion = IntentSignalFusion(configuration: .default)
        let coreMLCandidate = IntentClassificationCandidate(
            intentType: .itineraryQuery,
            confidence: 0.45,
            source: .coreml
        )

        let result = fusion.fuse(ruleResult: nil, coreMLCandidate: coreMLCandidate)

        #expect(result.finalSource == .coreml)
        #expect(result.finalResult?.intentType == .itineraryQuery)
        #expect(result.requiresRemoteFallback)
    }
}
