## Why

Current weather spin settling uses split speed models: reverse return-to-front and forward-complete paths do not share the same duration logic or easing profile. This causes visible speed inconsistency, especially when rotation returns to 0 degrees faster than forward settle to 360 degrees. The second-screen sun snap path also uses a separate duration model, which creates cross-screen mismatch.

## What Changes

- Define one deterministic angle-threshold settle rule for weather spin release:
  - absolute normalized angle < 180 degrees settles to 0 degrees
  - absolute normalized angle >= 180 degrees settles forward to 360 degrees in the current direction
- Introduce a shared v1 settle speed model for both return-to-0 and complete-to-360 outcomes.
- Unify settle easing across both outcomes to eliminate reverse-only front-loaded motion.
- Align second-screen sun release settle to the same threshold and speed model used by first-screen settle.
- Keep existing gesture classification and interaction entry thresholds unchanged in this change.

## Capabilities

### New Capabilities
- `weather-spin-settle-speed`: Consistent threshold-based settle destination and speed behavior across first-screen and second-screen weather spin release.

### Modified Capabilities
None.

## Impact

- Affects weather SceneKit release-settle behavior in first-screen and second-screen spin flows.
- Expected touch points:
  - `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift`
  - `ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift`
- No SceneKit asset, lighting, or model hierarchy changes.
- No external API changes.
