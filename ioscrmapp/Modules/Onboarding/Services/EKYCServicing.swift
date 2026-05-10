import Foundation

protocol EKYCServicing: Sendable {
    func verifyWithUAEPass() async throws -> EKYCResult
    func verifyWithDeviceBiometrics() async throws -> Bool
    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument]
    func submitVerificationResult(_ result: EKYCResult, assessmentId: String?) async throws -> EKYCSubmitResponse
}

struct EKYCSubmitResponse: Equatable, Sendable, Codable {
    let success: Bool
    let verificationId: String
    let nextStep: String
}
