import Foundation
import Security

struct RegistrationRequestEncryptor {
    private static let publicKey = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDbOYMwE7f6MkYk4n7SA5iqB9AujpregwW7bAmhXTZcE0zqYCvOjxNMj4THkll00MzJL0HahBcvlacFMqEz77xnxoNnUTlMC2j6z/ui5PGjnKVpjgK7DHJRsTSp8zl/aX6NUTJhxxk2Poc887/h3EDbzKS4pt7l+J0rZmPmoOcnewIDAQAB"

    init() {}

    func encryptPassword(_ password: String) async throws -> String {
        let encryptedPassword = try encryptRSA(data: Data(password.utf8), publicKey: Self.publicKey)
        return encryptedPassword.base64EncodedString()
    }

    private func encryptRSA(data: Data, publicKey: String) throws -> Data {
        guard let publicKeyData = Data(base64Encoded: publicKey) else {
            throw HTTPClient.ClientError.invalidResponse
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 1024
        ]

        var keyError: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(
            publicKeyData as CFData,
            attributes as CFDictionary,
            &keyError
        ) else {
            throw HTTPClient.ClientError.invalidResponse
        }

        guard SecKeyIsAlgorithmSupported(secKey, .encrypt, .rsaEncryptionPKCS1) else {
            throw HTTPClient.ClientError.invalidResponse
        }

        var encryptionError: Unmanaged<CFError>?
        guard let encryptedKey = SecKeyCreateEncryptedData(
            secKey,
            .rsaEncryptionPKCS1,
            data as CFData,
            &encryptionError
        ) as Data? else {
            throw HTTPClient.ClientError.invalidResponse
        }

        return encryptedKey
    }
}
