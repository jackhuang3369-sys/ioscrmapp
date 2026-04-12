## Context

The current weather scene already has the right SceneKit hierarchy: a shared rotating group, a sun assembly, temperature digits, and bird content attached to the sun. The problem is the interaction model. Current release behavior is coarse, momentum-heavy, and not tied to distance thresholds.

## Goals / Non-Goals

**Goals:**
- Keep SceneKit and the current scene graph
- Make one screen-width drag equal one full turn
- Add deterministic slow and fast release rules
- Keep bird local animation while the assembly rotates
- Force front-facing alignment before sun detail entry

**Non-Goals:**
- RealityKit migration
- Asset or lighting redesign
- New bird choreography

## Decisions

- Keep `WeatherSceneManager` as the owner of scene graph and transition alignment because node ownership is already stable there.
- Move gesture classification and settle decisions out of the current coarse momentum path into a dedicated spin interaction layer in `WeatherSceneView`.
- Add a shared tuning object for thresholds, turn caps, durations, and debug switches.
- Use yaw-first drag mapping with minimal decorative pitch and roll. This keeps the product interaction readable and avoids generic freeform model handling.
- Cap each fast projected settle at a bounded maximum turn count (currently eight) and use smooth settle easing to create a controlled stop instead of a raw inertial finish.

## Risks / Trade-offs

- [Fast classification feels too eager] → Tune velocity and duration weights with on-screen debug metrics.
- [Multi-turn settle feels excessive] → Keep a bounded cap and expose thresholds for tuning.
- [Front-facing detail entry feels delayed] → Use a small alignment tolerance and short pre-entry snap.
- [Too little pitch or roll feels flat] → Keep a small decorative tilt ratio instead of full freeform rotation.

## Migration Plan

- Ship the behavior only in the weather main scene and keep the existing SceneKit hierarchy unchanged.
- Validate with debug metrics on at least one small device and one large device before treating tuning values as final.
- Keep a narrow rollback path by preserving the current scene graph and limiting changes to interaction mapping, settle logic, and detail-entry alignment.

## Open Questions

- None at the artifact level. Tuning values remain adjustable during implementation, but the interaction contract is now fixed.
