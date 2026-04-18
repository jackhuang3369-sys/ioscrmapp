# Component Inventory

## Styles

`duCardStyle()`

- Purpose: shared card background, radius, and elevation.
- Token dependencies: `DUComponentTokens.CardTokens`.
- Boundary: business-neutral visual shell only.

`duFieldShell(isError:)`

- Purpose: shared input field chrome.
- Token dependencies: `DUComponentTokens.FieldTokens`.
- Boundary: layout and validation chrome, not field-specific business rules.

`duSurfaceStyle(_:)`

- Purpose: canvas, surface, raised, and sheet backgrounds.
- Token dependencies: `DUThemeColors`.
- Boundary: background only.

`duControlShadow(_:)`

- Purpose: shared control elevation helper.
- Token dependencies: `DUElevation`.
- Boundary: visual effect only.

## Components

`DUButton`

- Variants: primary, secondary, danger.
- States: enabled, disabled, loading.
- Token dependencies: button component tokens and brand gradient.
- Boundary: no business action semantics.

`DUTextButton`

- Variants: default semantic action color or caller-provided color.
- States: normal.
- Token dependencies: `theme.colors.action.primary`.
- Boundary: light inline action only.

`DUIconButton`

- Variants: optional title, caller-provided icon slot.
- States: normal.
- Token dependencies: semantic background and text tokens by default.
- Boundary: caller owns icon content.

`DUSplashSkipButton` and `DUSplashAudioButton`

- Variants: skip progress and audio icon.
- States: enabled/disabled chrome for skip.
- Token dependencies: chrome and primitive inverse text tokens.
- Boundary: splash controls only, no launch page layout migration.

`DUTextField`

- Variants: secure or plain text.
- States: default and error.
- Token dependencies: field component tokens.
- Boundary: caller owns validation and keyboard type.

`DUPhoneField`

- Variants: country code and normalized phone binding.
- States: default and error.
- Token dependencies: field component tokens.
- Boundary: caller owns phone validation rules.

`DUListItem`

- Variants: chevron, badge, selection, none.
- States: selected/unselected for selection accessory.
- Token dependencies: list item component tokens.
- Boundary: generic list row only; uses `chevron.forward` for RTL-safe direction.

`DUSectionCard`

- Variants: optional title and trailing text action.
- States: normal.
- Token dependencies: card style and text tokens.
- Boundary: generic section container.

`DUStateView`

- Variants: optional action and footer.
- States: empty, error, or success depending on caller content.
- Token dependencies: text tokens and `DUButton`.
- Boundary: caller owns copy and icon color.

`DUFeaturePlaceholderView`

- Variants: localized title/message and icon string.
- States: placeholder.
- Token dependencies: text and canvas tokens.
- Boundary: feature-unavailable presentation only.

`duBottomSheet`

- Variants: iOS 16 sheet detent and iOS 15 UIKit fallback.
- States: presented/dismissed.
- Token dependencies: sheet surface style and sheet radius.
- Boundary: presentation wrapper only.
