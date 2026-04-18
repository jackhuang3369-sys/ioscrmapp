# Token Contract

The token contract keeps future Figma Variables or Token JSON aligned with Swift names.

## Token Source Ownership

- Source token contract: this document.
- Active iOS consumption: Swift files under `DesignSystem/Tokens`.
- Platform asset namespace: `Assets.xcassets/DesignTokens`.
- Future generated output: `DesignSystem/Generated`.

This phase does not add token scripts or a Figma-to-JSON pipeline. When generation is introduced later, generated Swift should land in `Generated` or replace files under `Tokens` through a documented build step.

## Naming

Token names use dot-separated source names and map to Swift namespaces:

```text
color.primitive.brand.cyan -> DUColorPrimitives.Brand.cyan
color.semantic.text.primary -> DUColorTokens.Text.primary
color.semantic.background.canvas -> DUColorTokens.Background.canvas
color.semantic.surface.card -> DUColorTokens.Surface.card
color.semantic.border.default -> DUColorTokens.Border.default
component.button.primary.background -> DUComponentTokens.Button.Primary
component.field.border.error -> DUComponentTokens.FieldTokens.errorBorder
radius.semantic.card -> DURadius.card
typography.semantic.body.medium -> DUTypographyTokens.standard.body
motion.semantic.standard -> DUMotion.standard
```

Swift names use PascalCase namespaces and lower camel case members.

## Color Contract

Each semantic and component color has a light and dark value through `DUColorToken`.

```swift
DUColorToken(light: lightValue, dark: darkValue)
```

Runtime resolution happens in `DUTheme.resolve(mode:systemColorScheme:)`. New component code should read colors from `@Environment(\.duTheme)` instead of using legacy static aliases.

## Theme Modes

- `system`: resolve from SwiftUI `ColorScheme`.
- `light`: resolve Design System tokens as light.
- `dark`: resolve Design System tokens as dark.

Explicit modes do not call `.preferredColorScheme`; they only change Design System token resolution.

## Compatibility

`DULegacyThemeAliases.swift` maps existing `DUTheme.cyan`, `DUTheme.ink`, `DUTheme.background`, `DUTheme.panel`, `DUTheme.brandGradient`, and related aliases to light token values so unmigrated feature pages continue compiling. Dynamic theme behavior belongs to the environment-driven `DUTheme` runtime.

## Asset Catalog Strategy

The existing `Assets.xcassets/DesignTokens` directories are retained as platform asset placeholders. They are not the active source of truth in this phase because the color sets are empty. A future change may populate them from the same token source, but must define how conflicts with Swift tokens are resolved.
