import SwiftUI

enum DUMotion {
    static let fastDuration: Double = 0.16
    static let standardDuration: Double = 0.22
    static let slowDuration: Double = 0.34

    static let fast = Animation.easeInOut(duration: fastDuration)
    static let standard = Animation.easeInOut(duration: standardDuration)
    static let slow = Animation.easeInOut(duration: slowDuration)
}
