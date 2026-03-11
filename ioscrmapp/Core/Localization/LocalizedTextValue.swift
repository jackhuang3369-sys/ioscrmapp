import Foundation

enum LocalizedTextValue: Equatable, Sendable {
    case localized(String, [String])
    case literal(String)

    static func key(_ key: String, arguments: [String] = []) -> Self {
        .localized(key, arguments)
    }
}
