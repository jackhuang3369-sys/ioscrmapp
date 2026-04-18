# Validation Checklist

## Build And Scope

- `openspec validate land-app-design-system --strict` passes.
- iOS app target builds after adding new Swift files.
- `git diff --name-only` contains no `Modules/Weather` or `Modules/AI` files.
- Deferred feature modules contain no page-level visual source migration in this change.

## Theme

- `.system` follows current SwiftUI `ColorScheme` for Design System tokens.
- `.light` resolves Design System tokens as light without forcing `preferredColorScheme`.
- `.dark` resolves Design System tokens as dark without forcing `preferredColorScheme`.
- Theme setting persists after relaunch through `app.themeMode`.
- Back without saving keeps the previous theme mode.

## Localization And RTL

- Theme entry and page strings exist in English, Simplified Chinese, and Arabic.
- Arabic layout uses right-to-left direction.
- `chevron.forward` remains correct in RTL.
- Long localized text does not truncate critical actions.

## Components

- Buttons: primary, secondary, danger, disabled, and loading states remain readable.
- Fields: default and error states have visible text, border, and error labels.
- List items: whole row is tappable and selection/accessory states are readable.
- Cards and sheets use semantic surfaces and retain enough contrast.
- State views and placeholders use semantic text colors.

## Accessibility

- Interactive rows keep full hit areas.
- Dynamic Type does not overlap critical labels in settings pages.
- Contrast is checked for light and dark representative paths.

## Validation Evidence

- `ruby -rjson` parsed English, Simplified Chinese, and Arabic localization JSON files successfully.
- `plutil -lint ioscrmapp.xcodeproj/project.pbxproj` passed after adding Swift files to the app target.
- `swiftc -parse-as-library SmokeTests/ThemeStoreSmokeTests.swift ioscrmapp/DesignSystem/Tokens/Runtime/DUThemeMode.swift ioscrmapp/Core/Preferences/AppThemeStore.swift -o /tmp/theme-store-smoke && /tmp/theme-store-smoke` passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp-Develop -destination 'generic/platform=iOS Simulator' build` passed.
- `openspec validate land-app-design-system --strict` passed.
- Hardcoded style scan findings in touched foundation scope are token definitions, compatibility aliases, semantic token examples in docs, `Color.clear` header spacer, caller-provided icon color support, and tokenized shadow application. No new business-page hardcoded style migration was introduced.
- Final scope guard found no diffs under `ioscrmapp/Modules/Weather/` or `ioscrmapp/Modules/AI/`, and no page-level source diffs under deferred Auth, Billing, Offers, BadgeCenter, MessageCenter, Launch, Home, Mall, or Video modules.
- Remaining manual visual check: authenticated in-app navigation to Me > Appearance across light/dark and Arabic RTL should be exercised on a simulator or device before release.
