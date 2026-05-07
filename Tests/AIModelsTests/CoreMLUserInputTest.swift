import Foundation
import Testing

@testable import du_App

@Suite("CoreML User Input Test")
struct CoreMLUserInputTest {

    @Test("CoreML classifies 'check my data package is enough'")
    func testUserInputCheckDataPackage() async throws {
        let classifier = CoreMLIntentClassifier(
            modelProvider: BundleIntentModelProvider()
        )

        let userInput = "i want to check my data package is enough or not"
        let result = await classifier.classify(
            text: userInput,
            language: .english
        )

        print("=== Core ML Classification Result ===")
        print("Input: \(userInput)")
        print("Intent Type: \(result?.intentType.rawValue ?? "nil")")
        print("Confidence: \(result?.confidence ?? 0)")
        print("Requires Confirmation: \(result?.requiresConfirmation ?? true)")
        print("Source: \(result?.source.rawValue ?? "nil")")

        #expect(result != nil, "Core ML should return a result")
    }

    @Test("CoreML hypotheses for data usage queries")
    func testDataUsageHypotheses() async throws {
        let classifier = CoreMLIntentClassifier(
            modelProvider: BundleIntentModelProvider()
        )

        let testCases = [
            "check my data package is enough or not",
            "what about my data package",
            "how much data do i have left",
            "my data usage",
            "remaining data",
            "data left",
            "check my data balance",
            "is my data package enough"
        ]

        print("\n=== Core ML Hypotheses Comparison ===")
        for text in testCases {
            let result = await classifier.classify(text: text, language: .english)
            print("Input: '\(text)'")
            print("  → Intent: \(result?.intentType.rawValue ?? "nil")")
            print("  → Confidence: \(result?.confidence ?? 0)")
            print("")
        }
    }

    @Test("Compare CoreML vs Rule-based for user input")
    func testCompareCoreMLVsRule() async throws {
        let classifier = CoreMLIntentClassifier(
            modelProvider: BundleIntentModelProvider()
        )
        let matcher = LocalIntentMatcher()

        let userInput = "i want to check my data package is enough or not"

        // Core ML result
        let coreMLResult = await classifier.classify(text: userInput, language: .english)

        // Rule-based result
        let ruleResult = await matcher.match(text: userInput, language: .english)

        print("\n=== Comparison for: '\(userInput)' ===")
        print("Core ML:")
        print("  Intent: \(coreMLResult?.intentType.rawValue ?? "nil")")
        print("  Confidence: \(coreMLResult?.confidence ?? 0)")
        print("")
        print("Rule-based:")
        print("  Intent: \(ruleResult?.intentType.rawValue ?? "nil")")
        print("  Confidence: \(ruleResult?.confidence ?? 0)")
        print("")

        #expect(coreMLResult != nil, "Core ML should classify")
    }
}
