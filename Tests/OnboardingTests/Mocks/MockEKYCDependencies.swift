import Foundation
@testable import du_App

actor MockUAEPassOAuthHandler: UAEPassOAuthHandling {
    func performOAuth(config: UAEPassConfig) async throws -> CustSubInfo {
        CustSubInfo(
            displayName: "Mock User",
            phoneNumber: "+971501234567",
            greeting: "Good Morning",
            balanceText: "0 AED",
            userID: "mock-user-id",
            serviceNumber: "971501234567",
            subscriberKey: nil
        )
    }
}

actor MockEKYCDeviceContextEncryptor: EKYCDeviceContextEncrypting {
    func encrypt(_ context: DeviceContext) async throws -> EncryptedPayload {
        let data = try JSONEncoder().encode(context)
        return EncryptedPayload(
            algorithm: "mock-base64-json",
            keyId: "mock",
            ciphertext: data.base64EncodedString()
        )
    }
}

actor MockDeviceBiometricService: DeviceBiometricServicing {
    private let availability: DeviceBiometricAvailability

    init(availability: DeviceBiometricAvailability = .available) {
        self.availability = availability
    }

    func checkAvailability() async -> DeviceBiometricAvailability {
        availability
    }

    func authenticate(reason: String) async throws -> Bool {
        guard availability == .available else {
            throw EKYCError.deviceBiometricFailed(reason: "Device biometrics unavailable")
        }
        return true
    }

    // nonisolated — availability is 'let' so safe to read without actor hop
    nonisolated func supportedBiometricType() -> BiometricType {
        availability == .available ? .faceID : .none
    }
}

actor MockDocumentOCRService: DocumentOCRServicing {
    func scanDocument(type: DocumentType) async throws -> ScannedDocument {
        ScannedDocument(
            type: type,
            extractedData: EKYCMetadata(
                fullName: "Mock User",
                phoneNumber: nil,
                documentType: type.rawValue,
                documentNumber: "MOCK-123",
                documentExpiryDate: "2030-01-01"
            ),
            scanTimestamp: Date()
        )
    }

    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument] {
        var documents: [ScannedDocument] = []
        for type in types {
            documents.append(try await scanDocument(type: type))
        }
        return documents
    }

    func checkCameraPermission() async -> Bool { true }
    func requestCameraPermission() async -> Bool { true }
}

actor MockEKYCService: EKYCServicing {
    func verifyWithUAEPass() async throws -> EKYCResult {
        try await Task.sleep(nanoseconds: 50_000_000)
        return EKYCResult(
            method: .uaepass,
            identityID: "mock-user-id",
            verifiedAt: Date(),
            metadata: EKYCMetadata(
                fullName: "Mock User",
                phoneNumber: "+971501234567",
                documentType: nil,
                documentNumber: nil,
                documentExpiryDate: nil
            ),
            enhancedResults: nil
        )
    }

    func verifyWithDeviceBiometrics() async throws -> Bool {
        true
    }

    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument] {
        types.map { type in
            ScannedDocument(
                type: type,
                extractedData: EKYCMetadata(
                    fullName: "Mock User",
                    phoneNumber: nil,
                    documentType: type.rawValue,
                    documentNumber: "MOCK-123",
                    documentExpiryDate: "2030-01-01"
                ),
                scanTimestamp: Date()
            )
        }
    }

    func submitVerificationResult(_ result: EKYCResult, assessmentId: String?) async throws -> EKYCSubmitResponse {
        EKYCSubmitResponse(
            success: true,
            verificationId: "mock-verification-id",
            nextStep: "personalization"
        )
    }
}
