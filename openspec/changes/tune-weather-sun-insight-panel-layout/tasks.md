## 1. Spec And Baseline Alignment

- [x] 1.1 Confirm target scope is limited to sun insight panel outer width and vertical placement on iPhone 15/16
- [x] 1.2 Capture baseline screenshots (before change) for sun detail screen on iPhone 15/16

## 2. Layout Implementation

- [x] 2.1 Set `WeatherSunInsightPanel` width in `WeatherMainView` to approximately two-thirds of screen width for iPhone 15/16 portrait (target ratio 0.67, allowed range 0.64 to 0.70)
- [x] 2.2 Add steady-state panel Y adjustment in `WeatherMainView` within -6pt to -10pt (target -8pt) while keeping existing transition offset formula unchanged
- [x] 2.3 Ensure `WeatherSunInteractionSurface` layout and behavior remain unchanged

## 3. Verification

- [ ] 3.1 Re-capture screenshots (after change) on iPhone 15/16 and compare against baseline/reference
- [x] 3.2 Run weather-related smoke tests to ensure no layout regression in sun detail interactions
- [ ] 3.3 Perform manual check that panel content (UV row through Day/Week toggle) is fully visible without clipping/overlap