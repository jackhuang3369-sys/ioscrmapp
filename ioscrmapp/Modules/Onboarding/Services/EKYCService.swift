import Foundation

actor EKYCService: EKYCServicing {
    private let uaePassService: UAEPassServicing
    private let oauthHandler: any UAEPassOAuthHandling
    private let deviceBiometricService: any DeviceBiometricServicing
    private let documentOCRService: any DocumentOCRServicing

    init(
        uaePassService: UAEPassServicing,
        oauthHandler: any UAEPassOAuthHandling,
        deviceBiometricService: any DeviceBiometricServicing,
        documentOCRService: any DocumentOCRServicing
    ) {
        self.uaePassService = uaePassService
        self.oauthHandler = oauthHandler
        self.deviceBiometricService = deviceBiometricService
        self.documentOCRService = documentOCRService
    }

    func verifyWithUAEPass() async throws -> EKYCResult {
        let config = try await uaePassService.getConfig()
        let customer = try await oauthHandler.performOAuth(config: config)
        return EKYCResult(
            method: .uaepass,
            identityID: customer.userID ?? customer.phoneNumber,
            verifiedAt: Date(),
            metadata: EKYCMetadata(
                fullName: customer.displayName,
                phoneNumber: customer.phoneNumber,
                documentType: nil,
                documentNumber: nil,
                documentExpiryDate: nil
            ),
            enhancedResults: nil
        )
    }

    func verifyWithDeviceBiometrics() async throws -> Bool {
        let availability = await deviceBiometricService.checkAvailability()
        switch availability {
        case .available:
            return try await deviceBiometricService.authenticate(reason: "Verify your identity for eSIM activation")
        case .notEnrolled:
            throw EKYCError.permissionDenied(permission: "Device Biometrics not enrolled")
        case .notAvailable:
            throw EKYCError.deviceBiometricFailed(reason: "Device does not support Device Biometrics")
        case .lockedOut:
            throw EKYCError.deviceBiometricFailed(reason: "Device Biometrics is locked out")
        case .restricted:
            throw EKYCError.permissionDenied(permission: "Device Biometrics is restricted")
        }
    }

    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument] {
        let hasPermission = await documentOCRService.checkCameraPermission()
        if hasPermission == false {
            let granted = await documentOCRService.requestCameraPermission()
            if granted == false {
                throw EKYCError.permissionDenied(permission: "Camera")
            }
        }
        return try await documentOCRService.scanDocuments(types: types)
    }

    func submitVerificationResult(_ result: EKYCResult, assessmentId: String?) async throws -> EKYCSubmitResponse {
        try await Task.sleep(nanoseconds: 50_000_000)
        return EKYCSubmitResponse(
            success: true,
            verificationId: UUID().uuidString,
            nextStep: "personalization"
        )
    }
}
