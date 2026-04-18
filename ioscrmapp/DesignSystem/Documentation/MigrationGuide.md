# Migration Guide

## Preferred New Usage

Use runtime theme values in shared components and newly migrated views:

```swift
@Environment(\.duTheme) private var theme

Text(title)
    .foregroundColor(theme.colors.text.primary)
```

Use styles for repeated chrome:

```swift
content.duCardStyle()
fieldContent.duFieldShell(isError: error != nil)
```

Use `DUThemeMode` and `AppThemeStore` for user appearance preference.

## Legacy Usage

Existing business pages may continue using:

```swift
DUTheme.ink
DUTheme.background
DUTheme.panel
DUSpacing.lg
Font.du(16, weight: .semibold)
duCardStyle()
```

The static `DUTheme.*` aliases resolve to light values for migration compatibility. They are not the dynamic theme API.

## Excluded And Deferred Modules

Do not modify these source paths in this change:

- `Modules/Weather`
- `Modules/AI`

Record only, do not fix page-level visual issues in:

- `Modules/Auth`
- `Modules/Billing`
- `Modules/Offers`
- `Modules/BadgeCenter`
- `Modules/MessageCenter`
- `Modules/Launch`
- `Modules/Home`
- `Modules/Mall`
- `Modules/Video`

## Suggested Follow-up Splits

1. Auth and Launch: login forms, splash controls, onboarding surfaces.
2. Home and Mall: carousel indicators, product cards, tab chrome, search surfaces.
3. Billing and Offers: transactional forms, status chips, summary cards.
4. BadgeCenter and MessageCenter: list states, badges, detail surfaces.
5. Video: media cards, live/premium labels, player overlays.

Each follow-up should migrate one or two feature areas and add screenshots or smoke evidence for light, dark, English, Chinese, Arabic, and RTL where relevant.
