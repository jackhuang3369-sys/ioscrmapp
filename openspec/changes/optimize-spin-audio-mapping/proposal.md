## Why

Current spin release audio is selected by a raw velocity threshold, while visual settle behavior is determined by spin settle decision and target turn count. This mismatch causes audible feedback that does not reliably match what users see, especially when release velocity and resulting turns diverge.

## What Changes

- Define spin release audio selection from settle outcome instead of raw release speed only.
- Map slow audible feedback to single-turn completion and fast audible feedback to momentum multi-turn completion.
- Define behavior for reverse return-to-front (0-turn) outcomes to avoid misleading spin sounds.
- Align timing so spin audio triggers at release decision time and reflects the same decision used for settle animation.

## Capabilities

### New Capabilities
- `weather-spin-audio-mapping`: Specifies deterministic mapping between horizontal spin settle decisions and release audio variants for this change.

### Modified Capabilities
- None.

## Impact

- Affected modules: weather SceneKit interaction and weather audio playback integration.
- Affected file (expected): `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift` release-handling path where settle decision and spin audio trigger are coordinated.
- Affected file (expected): `ioscrmapp/Modules/Weather/SceneKit/WeatherAudioPlayer.swift` spin release audio variant entry points.
- Affected file (expected): `ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift` settle decision contract consumed by audio mapping.
- No external API changes.
- No new dependency required.
