import SwiftUI

struct DUTypographyToken {
    let size: CGFloat
    let weight: Font.Weight

    var font: Font {
        .du(size, weight: weight)
    }
}

enum DUTypographyTokens {
    struct Resolved {
        let caption: DUTypographyToken
        let footnote: DUTypographyToken
        let body: DUTypographyToken
        let bodyEmphasized: DUTypographyToken
        let title: DUTypographyToken
        let hero: DUTypographyToken
    }

    static let standard = Resolved(
        caption: DUTypographyToken(size: DUTypographyPrimitives.Size.caption, weight: .medium),
        footnote: DUTypographyToken(size: DUTypographyPrimitives.Size.footnote, weight: .semibold),
        body: DUTypographyToken(size: DUTypographyPrimitives.Size.body, weight: .medium),
        bodyEmphasized: DUTypographyToken(size: DUTypographyPrimitives.Size.bodyLarge, weight: .semibold),
        title: DUTypographyToken(size: DUTypographyPrimitives.Size.title, weight: .bold),
        hero: DUTypographyToken(size: DUTypographyPrimitives.Size.hero, weight: .bold)
    )
}
