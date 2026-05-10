import Foundation

enum EKYCMethod: String, CaseIterable, Identifiable, Sendable, Codable {
    case uaepass = "UAE Pass"
    case deviceBiometrics = "Device Biometrics"
    case documentScan = "Document Scan"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .uaepass:
            return "checkmark.shield.fill"
        case .deviceBiometrics:
            return "faceid"
        case .documentScan:
            return "person.text.rectangle"
        }
    }

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .uaepass:
            return "Fast verification for UAE mobile onboarding."
        case .deviceBiometrics:
            return "Confirm the current device holder with Face ID or Touch ID."
        case .documentScan:
            return "Scan Emirates ID or Passport for manual processing."
        }
    }
}

enum EKYCMethodStatus: Equatable, Sendable {
    case ready
    case comingSoon
    case unavailable(reason: String)
}

enum EKYCPermission: String, Equatable, Sendable, Codable {
    case camera
    case biometrics
    case uaepassApp
}

enum RiskLevel: String, Codable, Sendable {
    case low
    case medium
    case high
    case critical
}

enum DocumentType: String, Codable, CaseIterable, Sendable {
    case emiratesID = "Emirates ID"
    case passport = "Passport"
}

struct EKYCEnhancedRequirements: Equatable, Sendable, Codable {
    let deviceBiometricRequired: Bool
    let faceLivenessRequired: Bool
    let documentScanRequired: Bool
    let documentTypes: [DocumentType]
    let isRegulatoryMandatory: Bool
    let riskLevel: RiskLevel

    static let none = EKYCEnhancedRequirements(
        deviceBiometricRequired: false,
        faceLivenessRequired: false,
        documentScanRequired: false,
        documentTypes: [],
        isRegulatoryMandatory: false,
        riskLevel: .low
    )
}

struct EKYCMetadata: Equatable, Sendable, Codable {
    let fullName: String?
    let phoneNumber: String?
    let documentType: String?
    let documentNumber: String?
    let documentExpiryDate: String?
}

struct ScannedDocument: Equatable, Sendable, Codable {
    let type: DocumentType
    let extractedData: EKYCMetadata
    let scanTimestamp: Date
}

struct EKYCEnhancedResults: Equatable, Sendable, Codable {
    let deviceBiometricPassed: Bool
    let faceLivenessPassed: Bool
    let documentScanPassed: Bool
    let scannedDocuments: [ScannedDocument]
}

struct EKYCResult: Equatable, Sendable, Codable {
    let method: EKYCMethod
    let identityID: String
    let verifiedAt: Date
    let metadata: EKYCMetadata?
    let enhancedResults: EKYCEnhancedResults?
}

struct EncryptedPayload: Sendable, Codable, Equatable {
    let algorithm: String
    let keyId: String?
    let ciphertext: String
}

struct DeviceContext: Sendable, Codable, Equatable {
    let deviceId: String
    let deviceModel: String
    let osVersion: String
    let appVersion: String
}

struct RiskAssessmentRequest: Sendable, Codable, Equatable {
    let primaryVerificationResult: EKYCResult
    let encryptedDeviceContext: EncryptedPayload
    let networkInfo: NetworkInfo
    let businessScenario: BusinessScenario

    struct NetworkInfo: Sendable, Codable, Equatable {
        let connectionType: String
        let carrierName: String?
    }

    enum BusinessScenario: String, Sendable, Codable {
        case newESIMActivation
        case portIn
        case simReplacement
        case highValueTransaction
    }
}

struct RiskAssessmentResponse: Sendable, Codable, Equatable {
    let riskLevel: RiskLevel
    let enhancedRequirements: EKYCEnhancedRequirements
    let assessmentId: String
    let assessedAt: Date
}

struct EKYCFlowContext: Equatable, Sendable, Codable {
    let primaryResult: EKYCResult
    let riskAssessment: RiskAssessmentResponse
}

enum EKYCError: Error, Equatable, LocalizedError {
    case uaepassFailed(reason: String)
    case deviceBiometricFailed(reason: String)
    case faceLivenessFailed(reason: String)
    case documentScanFailed(reason: String)
    case riskAssessmentFailed(reason: String)
    case networkUnavailable
    case permissionDenied(permission: String)
    case timeout
    case userCancelled
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case let .uaepassFailed(reason):
            return "UAE Pass verification failed: \(reason)"
        case let .deviceBiometricFailed(reason):
            return "Device biometric verification failed: \(reason)"
        case let .faceLivenessFailed(reason):
            return "Face liveness verification failed: \(reason)"
        case let .documentScanFailed(reason):
            return "Document scan failed: \(reason)"
        case let .riskAssessmentFailed(reason):
            return "Risk assessment failed: \(reason)"
        case .networkUnavailable:
            return "Network unavailable"
        case let .permissionDenied(permission):
            return "Permission denied: \(permission)"
        case .timeout:
            return "Verification timeout"
        case .userCancelled:
            return "User cancelled verification"
        case let .unknown(message):
            return message
        }
    }
}

enum EKYCViewState: Equatable {
    case idle
    case preparing(method: EKYCMethod, permission: EKYCPermission?)
    case verifying(method: EKYCMethod)
    case assessing(primaryResult: EKYCResult)
    case enhancedRequired(context: EKYCFlowContext)
    case performingEnhanced(context: EKYCFlowContext)
    case submitting(context: EKYCFlowContext, finalResult: EKYCResult)
    case success(result: EKYCResult)
    case failure(error: EKYCError)
}
