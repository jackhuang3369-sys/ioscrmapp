## Why

The current weather spin feels like a generic 3D model gesture, not a controlled product interaction. It needs predictable front-facing rest behavior, distance-aware release rules, and a tunable motion system.

## What Changes

- Redesign the weather main scene horizontal spin interaction around deterministic distance and speed rules.
- Keep the sun and temperature digits front-facing at rest while preserving bird local animation.
- Map one full screen-width drag to one full 360-degree turn.
- Add a shared tuning layer for thresholds, turn caps, timing, and debug controls.
- Require front-facing alignment before entering sun detail.

## Capabilities

### New Capabilities
- `weather-spin`: Controlled weather scene spin interaction with front-facing rest state, drag-based turn mapping, deterministic settle rules, and tunable debug support.

### Modified Capabilities

None.

## Impact

- Affects Weather SceneKit interaction and sun-detail entry behavior.
- Touches gesture handling, settle animation, and detail-entry alignment.
- Keeps existing SceneKit assets, hierarchy, and rendering stack.