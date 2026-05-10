import Foundation
import Testing
@testable import du_App

@Suite("eKYC Service Protocol Tests")
struct EKYCServiceTests {
    @Test("MockUAEPassOAuthHandler returns deterministic customer info")
    func mockOAuthReturnsCustomer() async throws {
        let handler = MockUAEPassOAuthHandler()
        let customer = try await handler.performOAuth(
            config: UAEPassConfig(
                authorizeURL: "https://example.com/auth",
                clientId: "client-id",
                redirectUri: "duapp://uaepass/callback",
                language: "en",
                environment: "staging",
                scope: "openid profile",
                installedFlowAcrValues: "installed",
                fallbackFlowAcrValues: "fallback",
                state: "state-1"
            )
        )
        #expect(customer.displayName == "Mock User")
        #expect(customer.userID == "mock-user-id")
    }

    @Test("MockEKYCRiskEngine returns none requirements for low risk")
    func mockRiskEngineLowRisk() async throws {
        let engine = MockEKYCRiskEngine()
        await engine.setScenario(riskLevel: .low)
        let response = try await engine.assessRisk(request: makeRiskRequest())
        #expect(response.riskLevel == .low)
        #expect(response.enhancedRequirements == .none)
    }

    @Test("MockDeviceContextEncryptor encodes payload as mock base64 json")
    func mockEncryptorReturnsPayload() async throws {
        let encryptor = MockEKYCDeviceContextEncryptor()
        let payload = try await encryptor.encrypt(
            DeviceContext(deviceId: "device-1", deviceModel: "iPhone", osVersion: "18.0", appVersion: "1.0")
        )
        #expect(payload.algorithm == "mock-base64-json")
        #expect(payload.keyId == "mock")
        #expect(payload.ciphertext.isEmpty == false)
    }

    @Test("MockDeviceBiometricService reports notAvailable when configured")
    func deviceBiometricMockAvailability() async {
        let service = MockDeviceBiometricService(availability: .notAvailable)
        let availability = await service.checkAvailability()
        #expect(availability == .notAvailable)
    }

    @Test("MockDocumentOCRService returns a scanned document for each requested type")
    func mockDocumentScanReturnsRequestedTypes() async throws {
        let service = MockDocumentOCRService()
        let documents = try await service.scanDocuments(types: [.emiratesID, .passport])
        #expect(documents.count == 2)
        #expect(documents.map(\.type) == [.emiratesID, .passport])
    }

    @Test("EKYCDeviceContextEncryptor returns RSA payload metadata")
    func deviceContextEncryptorReturnsRsaMetadata() async throws {
        let encryptor = EKYCDeviceContextEncryptor()
        let payload = try await encryptor.encrypt(
            DeviceContext(deviceId: "device-1", deviceModel: "iPhone 16", osVersion: "18.0", appVersion: "1.0")
        )
        #expect(payload.algorithm == "rsa-pkcs1-v1_5")
        #expect(payload.keyId == "registration-public-key-v1")
        #expect(payload.ciphertext.isEmpty == false)
    }

    @Test("MockUAEPassOAuthHandler conforms to shared OAuth abstraction")
    func oauthHandlerConformsToProtocol() async throws {
        let handler: any UAEPassOAuthHandling = MockUAEPassOAuthHandler()
        let customer = try await handler.performOAuth(
            config: UAEPassConfig(
                authorizeURL: "https://example.com/auth",
                clientId: "client-id",
                redirectUri: "duapp://uaepass/callback",
                language: "en",
                environment: "staging",
                scope: "openid profile",
                installedFlowAcrValues: "installed",
                fallbackFlowAcrValues: "fallback",
                state: "state-2"
            )
        )
        #expect(customer.phoneNumber == "+971501234567")
    }

    @Test("EKYCService maps OAuth customer into UAE Pass ekyc result")
    func ekycServiceMapsOAuthCustomer() async throws {
        let service = EKYCService(
            uaePassService: MockUAEPassService(),
            oauthHandler: MockUAEPassOAuthHandler(),
            deviceBiometricService: MockDeviceBiometricService(),
            documentOCRService: MockDocumentOCRService()
        )

        let result = try await service.verifyWithUAEPass()
        #expect(result.method == .uaepass)
        #expect(result.identityID == "mock-user-id")
        #expect(result.metadata?.fullName == "Mock User")
    }

    @Test("EKYCService delegates device biometrics to capability service")
    func ekycServiceDelegatesDeviceBiometrics() async throws {
        let service = EKYCService(
            uaePassService: MockUAEPassService(),
            oauthHandler: MockUAEPassOAuthHandler(),
            deviceBiometricService: MockDeviceBiometricService(),
            documentOCRService: MockDocumentOCRService()
        )

        let verified = try await service.verifyWithDeviceBiometrics()
        #expect(verified == true)
    }

    @Test("EKYCService scans every requested document type")
    func ekycServiceScansDocuments() async throws {
        let service = EKYCService(
            uaePassService: MockUAEPassService(),
            oauthHandler: MockUAEPassOAuthHandler(),
            deviceBiometricService: MockDeviceBiometricService(),
            documentOCRService: MockDocumentOCRService()
        )

        let documents = try await service.scanDocuments(types: [.emiratesID, .passport])
        #expect(documents.count == 2)
        #expect(documents.map(\.type) == [.emiratesID, .passport])
    }

    @Test("EKYCService returns successful submit response")
    func ekycServiceSubmitReturnsSuccess() async throws {
        let service = EKYCService(
            uaePassService: MockUAEPassService(),
            oauthHandler: MockUAEPassOAuthHandler(),
            deviceBiometricService: MockDeviceBiometricService(),
            documentOCRService: MockDocumentOCRService()
        )

        let response = try await service.submitVerificationResult(
            EKYCResult(method: .uaepass, identityID: "user-1", verifiedAt: Date(), metadata: nil, enhancedResults: nil),
            assessmentId: "assessment-1"
        )
        #expect(response.success == true)
        #expect(response.nextStep == "personalization")
    }

    private func makeRiskRequest() -> RiskAssessmentRequest {
        RiskAssessmentRequest(
            primaryVerificationResult: EKYCResult(
                method: .uaepass,
                identityID: "user-1",
                verifiedAt: Date(timeIntervalSince1970: 1),
                metadata: nil,
                enhancedResults: nil
            ),
            encryptedDeviceContext: EncryptedPayload(
                algorithm: "mock",
                keyId: "mock",
                ciphertext: "ciphertext"
            ),
            networkInfo: RiskAssessmentRequest.NetworkInfo(connectionType: "wifi", carrierName: "du"),
            businessScenario: .newESIMActivation
        )
    }
}
