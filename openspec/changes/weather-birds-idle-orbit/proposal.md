## Why

The weather home scene needs a clearer idle motion cue for the birds: at rest they should orbit around the sun, but once the user starts dragging, they must move as part of the same solar system without drifting independently. This improves first-frame liveliness while preserving consistent hand-driven motion.

## What Changes

- Add an idle bird-orbit behavior for the main weather screen only.
- Stop idle bird orbit when user interaction begins so birds and sun rotate together during slow and fast drags.
- Keep second-screen sun detail behavior unchanged for this change.
- Preserve existing bird local animation content while changing only the container-level motion behavior.

## Capabilities

### New Capabilities
- `weather-birds-idle-orbit`: Defines idle bird orbit around the sun on the main screen and the transition to hand-driven synchronized rotation during interaction.

### Modified Capabilities
- None.

## Impact

- Affected modules: weather SceneKit scene composition and interaction handoff behavior.
- Affected file (expected): `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneManager.swift` for bird node composition and idle orbit lifecycle.
- Affected file (expected): `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift` for interaction start handoff if orbit cancellation must happen with gesture begin.
- No external API changes.
- No new dependency required.
