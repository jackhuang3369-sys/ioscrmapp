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
        let micro: DUTypographyToken
        let microStrong: DUTypographyToken
        let tiny: DUTypographyToken
        let tinyRegular: DUTypographyToken
        let tinyStrong: DUTypographyToken
        let tinyEmphasized: DUTypographyToken
        let caption: DUTypographyToken
        let captionRegular: DUTypographyToken
        let captionStrong: DUTypographyToken
        let captionEmphasized: DUTypographyToken
        let meta: DUTypographyToken
        let metaStrong: DUTypographyToken
        let metaEmphasized: DUTypographyToken
        let labelRegular: DUTypographyToken
        let label: DUTypographyToken
        let labelStrong: DUTypographyToken
        let labelEmphasized: DUTypographyToken
        let bodySmall: DUTypographyToken
        let bodySmallStrong: DUTypographyToken
        let bodySmallEmphasized: DUTypographyToken
        let body: DUTypographyToken
        let bodyStrong: DUTypographyToken
        let bodyEmphasized: DUTypographyToken
        let bodyLarge: DUTypographyToken
        let bodyLargeSemibold: DUTypographyToken
        let bodyLargeStrong: DUTypographyToken
        let titleSmall: DUTypographyToken
        let titleSmallStrong: DUTypographyToken
        let title: DUTypographyToken
        let titleStrong: DUTypographyToken
        let titleStrongSemibold: DUTypographyToken
        let headline: DUTypographyToken
        let headlineStrong: DUTypographyToken
        let hero: DUTypographyToken
        let heroStrong: DUTypographyToken
        let screenTitle: DUTypographyToken
        let featureHero: DUTypographyToken
        let display: DUTypographyToken
        let resultDisplay: DUTypographyToken
    }

    static let standard = Resolved(
        micro: DUTypographyToken(size: 9, weight: .medium),
        microStrong: DUTypographyToken(size: 9, weight: .bold),
        tiny: DUTypographyToken(size: 10, weight: .medium),
        tinyRegular: DUTypographyToken(size: 10, weight: .regular),
        tinyStrong: DUTypographyToken(size: 10, weight: .semibold),
        tinyEmphasized: DUTypographyToken(size: 10, weight: .bold),
        caption: DUTypographyToken(size: 11, weight: .medium),
        captionRegular: DUTypographyToken(size: 11, weight: .regular),
        captionStrong: DUTypographyToken(size: DUTypographyPrimitives.Size.caption, weight: .semibold),
        captionEmphasized: DUTypographyToken(size: DUTypographyPrimitives.Size.caption, weight: .bold),
        meta: DUTypographyToken(size: 12, weight: .medium),
        metaStrong: DUTypographyToken(size: 12, weight: .semibold),
        metaEmphasized: DUTypographyToken(size: 12, weight: .bold),
        labelRegular: DUTypographyToken(size: 13, weight: .regular),
        label: DUTypographyToken(size: 13, weight: .medium),
        labelStrong: DUTypographyToken(size: 13, weight: .semibold),
        labelEmphasized: DUTypographyToken(size: 13, weight: .bold),
        bodySmall: DUTypographyToken(size: DUTypographyPrimitives.Size.footnote, weight: .medium),
        bodySmallStrong: DUTypographyToken(size: DUTypographyPrimitives.Size.footnote, weight: .semibold),
        bodySmallEmphasized: DUTypographyToken(size: DUTypographyPrimitives.Size.footnote, weight: .bold),
        body: DUTypographyToken(size: DUTypographyPrimitives.Size.body, weight: .medium),
        bodyStrong: DUTypographyToken(size: DUTypographyPrimitives.Size.body, weight: .semibold),
        bodyEmphasized: DUTypographyToken(size: DUTypographyPrimitives.Size.body, weight: .bold),
        bodyLarge: DUTypographyToken(size: DUTypographyPrimitives.Size.bodyLarge, weight: .medium),
        bodyLargeSemibold: DUTypographyToken(size: DUTypographyPrimitives.Size.bodyLarge, weight: .semibold),
        bodyLargeStrong: DUTypographyToken(size: DUTypographyPrimitives.Size.bodyLarge, weight: .bold),
        titleSmall: DUTypographyToken(size: 17, weight: .bold),
        titleSmallStrong: DUTypographyToken(size: 18, weight: .bold),
        title: DUTypographyToken(size: DUTypographyPrimitives.Size.title, weight: .bold),
        titleStrong: DUTypographyToken(size: 22, weight: .bold),
        titleStrongSemibold: DUTypographyToken(size: 22, weight: .semibold),
        headline: DUTypographyToken(size: DUTypographyPrimitives.Size.hero, weight: .bold),
        headlineStrong: DUTypographyToken(size: 26, weight: .bold),
        hero: DUTypographyToken(size: 28, weight: .bold),
        heroStrong: DUTypographyToken(size: 30, weight: .bold),
        screenTitle: DUTypographyToken(size: 32, weight: .bold),
        featureHero: DUTypographyToken(size: 34, weight: .bold),
        display: DUTypographyToken(size: 42, weight: .bold),
        resultDisplay: DUTypographyToken(size: 56, weight: .bold)
    )
}

enum DUTextStyle {
    case micro
    case microStrong
    case tiny
    case tinyRegular
    case tinyStrong
    case tinyEmphasized
    case caption
    case captionRegular
    case captionStrong
    case captionEmphasized
    case meta
    case metaStrong
    case metaEmphasized
    case labelRegular
    case label
    case labelStrong
    case labelEmphasized
    case bodySmall
    case bodySmallStrong
    case bodySmallEmphasized
    case body
    case bodyStrong
    case bodyEmphasized
    case bodyLarge
    case bodyLargeSemibold
    case bodyLargeStrong
    case titleSmall
    case titleSmallStrong
    case title
    case titleStrongSemibold
    case titleStrong
    case headline
    case headlineStrong
    case hero
    case heroStrong
    case screenTitle
    case featureHero
    case display
    case resultDisplay

    fileprivate var token: DUTypographyToken {
        let tokens = DUTypographyTokens.standard

        switch self {
        case .micro:
            return tokens.micro
        case .microStrong:
            return tokens.microStrong
        case .tiny:
            return tokens.tiny
        case .tinyRegular:
            return tokens.tinyRegular
        case .tinyStrong:
            return tokens.tinyStrong
        case .tinyEmphasized:
            return tokens.tinyEmphasized
        case .caption:
            return tokens.caption
        case .captionRegular:
            return tokens.captionRegular
        case .captionStrong:
            return tokens.captionStrong
        case .captionEmphasized:
            return tokens.captionEmphasized
        case .meta:
            return tokens.meta
        case .metaStrong:
            return tokens.metaStrong
        case .metaEmphasized:
            return tokens.metaEmphasized
        case .labelRegular:
            return tokens.labelRegular
        case .label:
            return tokens.label
        case .labelStrong:
            return tokens.labelStrong
        case .labelEmphasized:
            return tokens.labelEmphasized
        case .bodySmall:
            return tokens.bodySmall
        case .bodySmallStrong:
            return tokens.bodySmallStrong
        case .bodySmallEmphasized:
            return tokens.bodySmallEmphasized
        case .body:
            return tokens.body
        case .bodyStrong:
            return tokens.bodyStrong
        case .bodyEmphasized:
            return tokens.bodyEmphasized
        case .bodyLarge:
            return tokens.bodyLarge
        case .bodyLargeSemibold:
            return tokens.bodyLargeSemibold
        case .bodyLargeStrong:
            return tokens.bodyLargeStrong
        case .titleSmall:
            return tokens.titleSmall
        case .titleSmallStrong:
            return tokens.titleSmallStrong
        case .title:
            return tokens.title
        case .titleStrongSemibold:
            return tokens.titleStrongSemibold
        case .titleStrong:
            return tokens.titleStrong
        case .headline:
            return tokens.headline
        case .headlineStrong:
            return tokens.headlineStrong
        case .hero:
            return tokens.hero
        case .heroStrong:
            return tokens.heroStrong
        case .screenTitle:
            return tokens.screenTitle
        case .featureHero:
            return tokens.featureHero
        case .display:
            return tokens.display
        case .resultDisplay:
            return tokens.resultDisplay
        }
    }
}

extension Font {
    static func du(_ style: DUTextStyle) -> Font {
        style.token.font
    }
}
