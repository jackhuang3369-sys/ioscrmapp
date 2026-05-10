import Foundation
import LocalAuthentication

protocol DeviceBiometricServicing: Sendable {
    func checkAvailability() async -> DeviceBiometricAvailability
    func authenticate(reason: String) async throws -> Bool
    func supportedBiometricType() -> BiometricType
}

enum DeviceBiometricAvailability: Equatable, Sendable {
    case available
    case notEnrolled
    case notAvailable
    case lockedOut
    case restricted
}

enum BiometricType: Equatable, Sendable {
    case faceID
    case touchID
    case none
}

struct DeviceBiometricService: DeviceBiometricServicing {
    private func makeContext() -> LAContext {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"
        return context
    }

    func checkAvailability() async -> DeviceBiometricAvailability {
        let context = makeContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error {
                switch error.code {
                case LAError.biometryNotEnrolled.rawValue:
                    return .notEnrolled
                case LAError.biometryNotAvailable.rawValue:
                    return .notAvailable
                case LAError.biometryLockout.rawValue:
                    return .lockedOut
                case LAError.notInteractive.rawValue:
                    return .restricted
                default:
                    return .notAvailable
                }
            }
            return .notAvailable
        }
        return .available
    }

    func authenticate(reason: String) async throws -> Bool {
        let context = makeContext()
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if let error {
                    // Switch on LAError.Code (not LAError?) — LAError members are .Code in current SDK
                    let authError = (error as? LAError)?.code
                    switch authError {
                    case .userCancel, .userFallback:
                        continuation.resume(throwing: EKYCError.userCancelled)
                    case .biometryNotEnrolled:
                        continuation.resume(throwing: EKYCError.permissionDenied(permission: "Device Biometrics not enrolled"))
                    case .biometryLockout:
                        continuation.resume(throwing: EKYCError.deviceBiometricFailed(reason: "Device Biometrics locked out"))
                    default:
                        continuation.resume(throwing: EKYCError.deviceBiometricFailed(reason: error.localizedDescription))
                    }
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    func supportedBiometricType() -> BiometricType {
        let context = makeContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }
}
