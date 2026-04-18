import SwiftUI

enum DUComponentTokens {
    struct Resolved {
        let button: ButtonTokens
        let field: FieldTokens
        let card: CardTokens
        let listItem: ListItemTokens
        let sheet: SheetTokens
    }

    struct ButtonTokens {
        let height: CGFloat
        let cornerRadius: CGFloat
        let primary: ButtonVariantTokens
        let secondary: ButtonVariantTokens
        let danger: ButtonVariantTokens
    }

    struct ButtonVariantTokens {
        let foreground: Color
        let background: Color
        let disabledForeground: Color
        let disabledBackground: Color
        let shadowColor: Color
    }

    struct FieldTokens {
        let height: CGFloat
        let cornerRadius: CGFloat
        let label: Color
        let text: Color
        let placeholder: Color
        let background: Color
        let border: Color
        let errorBorder: Color
        let errorText: Color
        let divider: Color
    }

    struct CardTokens {
        let background: Color
        let border: Color
        let cornerRadius: CGFloat
        let elevation: DUElevationStyle
    }

    struct ListItemTokens {
        let title: Color
        let subtitle: Color
        let accessory: Color
        let selected: Color
        let badgeText: Color
        let badgeBackground: Color
    }

    struct SheetTokens {
        let background: Color
        let cornerRadius: CGFloat
    }

    enum Button {
        enum Primary {
            static let foreground = DUColorToken(light: .white, dark: .white)
            static let disabledForeground = DUColorToken(light: .white, dark: DUColorPrimitives.Neutral.gray400)
            static let disabledBackground = DUColorTokens.Text.disabled
            static let shadow = DUColorToken(
                light: DUColorPrimitives.Brand.cyan.opacity(0.28),
                dark: DUColorPrimitives.Brand.cyan.opacity(0.18)
            )
        }

        enum Secondary {
            static let foreground = DUColorTokens.Action.primary
            static let background = DUColorTokens.Action.primaryBackground
            static let disabledForeground = DUColorTokens.Text.disabled
            static let disabledBackground = DUColorTokens.Background.secondary
        }

        enum Danger {
            static let foreground = DUColorToken(light: .white, dark: .white)
            static let background = DUColorTokens.Status.error
            static let disabledBackground = DUColorTokens.Text.disabled
        }
    }

    static func resolve(for colorScheme: ColorScheme, colors: DUThemeColors) -> Resolved {
        Resolved(
            button: ButtonTokens(
                height: 52,
                cornerRadius: DURadius.button,
                primary: ButtonVariantTokens(
                    foreground: Button.Primary.foreground.resolve(for: colorScheme),
                    background: colors.brand.primary,
                    disabledForeground: Button.Primary.disabledForeground.resolve(for: colorScheme),
                    disabledBackground: Button.Primary.disabledBackground.resolve(for: colorScheme),
                    shadowColor: Button.Primary.shadow.resolve(for: colorScheme)
                ),
                secondary: ButtonVariantTokens(
                    foreground: Button.Secondary.foreground.resolve(for: colorScheme),
                    background: Button.Secondary.background.resolve(for: colorScheme),
                    disabledForeground: Button.Secondary.disabledForeground.resolve(for: colorScheme),
                    disabledBackground: Button.Secondary.disabledBackground.resolve(for: colorScheme),
                    shadowColor: .clear
                ),
                danger: ButtonVariantTokens(
                    foreground: Button.Danger.foreground.resolve(for: colorScheme),
                    background: Button.Danger.background.resolve(for: colorScheme),
                    disabledForeground: Button.Primary.disabledForeground.resolve(for: colorScheme),
                    disabledBackground: Button.Danger.disabledBackground.resolve(for: colorScheme),
                    shadowColor: .clear
                )
            ),
            field: FieldTokens(
                height: 52,
                cornerRadius: DURadius.field,
                label: colors.text.secondary,
                text: colors.text.primary,
                placeholder: colors.text.tertiary,
                background: colors.surface.card,
                border: colors.border.default,
                errorBorder: colors.status.error,
                errorText: colors.status.error,
                divider: colors.border.subtle
            ),
            card: CardTokens(
                background: colors.surface.card,
                border: colors.border.subtle,
                cornerRadius: DURadius.card,
                elevation: DUElevation.card(for: colorScheme)
            ),
            listItem: ListItemTokens(
                title: colors.text.primary,
                subtitle: colors.text.tertiary,
                accessory: colors.text.disabled,
                selected: colors.action.primary,
                badgeText: colors.status.warning,
                badgeBackground: colors.status.warningBackground
            ),
            sheet: SheetTokens(
                background: colors.surface.sheet,
                cornerRadius: DURadius.sheet
            )
        )
    }
}
