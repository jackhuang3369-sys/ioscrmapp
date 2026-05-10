import Foundation

protocol EKYCDeviceContextEncrypting: Sendable {
    func encrypt(_ context: DeviceContext) async throws -> EncryptedPayload
}

struct EKYCDeviceContextEncryptor: EKYCDeviceContextEncrypting {
    private let registrationEncryptor = RegistrationRequestEncryptor()

    func encrypt(_ context: DeviceContext) async throws -> EncryptedPayload {
        let data = try JSONEncoder().encode(context)
        let plaintext = String(decoding: data, as: UTF8.self)
        let ciphertext = try await registrationEncryptor.encryptPassword(plaintext)
        return EncryptedPayload(
            algorithm: "rsa-pkcs1-v1_5",
            keyId: "registration-public-key-v1",
            ciphertext: ciphertext
        )
    }
}
