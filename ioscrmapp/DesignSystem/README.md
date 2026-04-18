# Design System

This directory is the iOS consumption layer for app-wide visual decisions. It separates raw values, semantic meaning, runtime theme resolution, style recipes, preview coverage, and governance docs.

## Scope

Allowed implementation scope for `land-app-design-system`:

- `DesignSystem/`
- `Common/Components/`
- `Core/Preferences/AppThemeStore.swift`
- `ioscrmappApp.swift`
- `ContentView.swift`
- `Modules/Me` theme settings entry and `ThemeSettingsView`
- localization resources
- OpenSpec and Design System documentation

Deferred page-level visual migration:

- `Modules/Auth`
- `Modules/Billing`
- `Modules/Offers`
- `Modules/BadgeCenter`
- `Modules/MessageCenter`
- `Modules/Launch`
- `Modules/Home`
- `Modules/Mall`
- `Modules/Video`

Excluded source paths:

- `Modules/Weather`
- `Modules/AI`

## Layers

- `Tokens/Primitives`: raw color, typography, spacing, radius, elevation, and motion values.
- `Tokens/Semantics`: semantic text, background, surface, border, status, action, and component tokens.
- `Tokens/Runtime`: `DUThemeMode`, resolved `DUTheme`, and SwiftUI environment injection.
- `Tokens/Compatibility`: legacy static aliases for existing `DUTheme.*` call sites.
- `Styles`: business-neutral view modifiers and shared chrome recipes.
- `Common/Components`: reusable structures and interaction behavior that consume semantic/component tokens.
- `Generated`: reserved for future generated Swift token output.
- `Documentation`: inventory, migration, and validation governance.
- `Previews`: representative preview catalog for token and component verification.

## Existing Token Assets

`Assets.xcassets/DesignTokens` is retained as a platform asset namespace. Current color set directories are empty placeholders, so Swift token files are the active consumption layer in this change.

`DesignSystem/Generated` is retained as the future generated output location. It is intentionally documentation-only in this phase; no token generator, Figma export, or JSON-to-Swift script is introduced.

## Runtime Theme

`AppThemeStore` persists a non-sensitive `DUThemeMode` raw value in `UserDefaults` under `app.themeMode`. `.system` follows SwiftUI `ColorScheme`; `.light` and `.dark` only affect Design System semantic token resolution through `duTheme(mode:)`. The app does not set a global `preferredColorScheme` in this change.
