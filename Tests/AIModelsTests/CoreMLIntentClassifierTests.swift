import Foundation
import Testing

@testable import du_App

@Suite("CoreML Intent Classifier Tests")
struct CoreMLIntentClassifierTests {

    @Test("Missing model provider fails safely")
    func testMissingModelProvider() async throws {
        let classifier = CoreMLIntentClassifier(
            modelProvider: MissingIntentModelProvider()
        )

        let result = await classifier.classify(
            text: "check my balance",
            language: .english
        )

        #expect(result == nil)
    }

    @Test("Empty input returns nil")
    func testEmptyInput() async throws {
        let classifier = CoreMLIntentClassifier(
            modelProvider: MissingIntentModelProvider()
        )

        let result = await classifier.classify(
            text: "   ",
            language: .english
        )

        #expect(result == nil)
    }

    @Test("CoreML classifier recognizes representative multilingual phrases")
    func testCoreMLClassifierRecognizesRepresentativePhrases() async throws {
        let classifier = CoreMLIntentClassifier(
            modelProvider: BundleIntentModelProvider()
        )

        let balance = await classifier.classify(
            text: "check my balance",
            language: .english
        )
        #expect(balance?.intentType == .balanceInquiry)

        let typoTravel = await classifier.classify(
            text: "I want to tranval to hongkong",
            language: .english
        )
        #expect(typoTravel?.intentType == .itineraryQuery)

        let chineseBill = await classifier.classify(
            text: "查看账单",
            language: .simplifiedChinese
        )
        #expect(chineseBill?.intentType == .viewBill)

        let voiceUsage = await classifier.classify(
            text: "check my remaining minutes",
            language: .english
        )
        #expect(voiceUsage?.intentType == .voiceUsageQuery)

        let offers = await classifier.classify(
            text: "show me prepaid offers",
            language: .english
        )
        #expect(offers?.intentType == .viewOffers)

        let payment = await classifier.classify(
            text: "pay my telecom bill",
            language: .english
        )
        #expect(payment?.intentType == .makePayment)

        let smsUsage = await classifier.classify(
            text: "查短信",
            language: .simplifiedChinese
        )
        #expect(smsUsage?.intentType == .smsUsageQuery)

        let arabicRecharge = await classifier.classify(
            text: "شحن الحساب",
            language: .arabic
        )
        #expect(arabicRecharge?.intentType == .rechargeAccount)
    }
}

private struct MissingIntentModelProvider: IntentModelProviding {
    let descriptor: IntentModelDescriptor = .current

    func compiledModelURL() -> URL? {
        nil
    }
}
