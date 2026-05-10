import Foundation
import Testing
@testable import du_App

@Suite("eKYC Models Tests")
struct EKYCModelsTests {
    @Test("EKYCMethod exposes expected onboarding methods")
    func ekycMethodCases() {
        #expect(EKYCMethod.allCases == [.uaepass, .deviceBiometrics, .documentScan])
        #expect(EKYCMethod.uaepass.title == "UAE Pass")
        #expect(EKYCMethod.deviceBiometrics.icon == "faceid")
        #expect(EKYCMethod.documentScan.subtitle.contains("Emirates ID"))
    }

    @Test("EKYCEnhancedRequirements none disables all enhancements")
    func enhancedRequirementsNone() {
        let requirements = EKYCEnhancedRequirements.none
        #expect(requirements.deviceBiometricRequired == false)
        #expect(requirements.faceLivenessRequired == false)
        #expect(requirements.documentScanRequired == false)
        #expect(requirements.documentTypes.isEmpty)
        #expect(requirements.riskLevel == .low)
    }

    @Test("EKYCFlowContext is Codable")
    func flowContextIsCodable() throws {
        let risk = RiskAssessmentResponse(
            riskLevel: .medium,
            enhancedRequirements: .none,
            assessmentId: "assessment-1",
            assessedAt: Date(timeIntervalSince1970: 10)
        )
        let result = EKYCResult(
            method: .uaepass,
            identityID: "user-1",
            verifiedAt: Date(timeIntervalSince1970: 20),
            metadata: EKYCMetadata(
                fullName: "Test User",
                phoneNumber: "+971501234567",
                documentType: nil,
                documentNumber: nil,
                documentExpiryDate: nil
            ),
            enhancedResults: nil
        )
        let original = EKYCFlowContext(primaryResult: result, riskAssessment: risk)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EKYCFlowContext.self, from: encoded)
        #expect(decoded == original)
    }

    @Test("EncryptedPayload stores encrypted request metadata")
    func encryptedPayloadShape() {
        let payload = EncryptedPayload(
            algorithm: "rsa-pkcs1-v1_5",
            keyId: "registration-public-key-v1",
            ciphertext: "abc123"
        )
        #expect(payload.algorithm == "rsa-pkcs1-v1_5")
        #expect(payload.keyId == "registration-public-key-v1")
        #expect(payload.ciphertext == "abc123")
    }
}
