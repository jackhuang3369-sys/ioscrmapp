import SwiftUI

enum DUTypographyPrimitives {
    enum Size {
        static let caption: CGFloat = 12
        static let footnote: CGFloat = 14
        static let body: CGFloat = 15
        static let bodyLarge: CGFloat = 16
        static let title: CGFloat = 20
        static let hero: CGFloat = 24
    }

    static let defaultDesign: Font.Design = .rounded
}

extension Font {
    static func du(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: DUTypographyPrimitives.defaultDesign)
    }
}
