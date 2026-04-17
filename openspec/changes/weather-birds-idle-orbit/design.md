## Context

Birds in the weather main scene are already attached under the sun root, which means they naturally inherit whole-system rotation when the sun and its parent group rotate. What is missing is an idle-state motion layer for the main screen: before any user interaction, the birds should slowly orbit around the sun to make the scene feel alive. Once the user begins dragging, that idle orbit must stop so the birds and sun continue as one hand-driven system.

## Goals / Non-Goals

**Goals:**
- Add a slow idle bird orbit around the sun on the main weather screen.
- Stop idle orbit as soon as interaction begins so birds and sun rotate together during manual control.
- Preserve bird local animation content from the imported asset.
- Keep second-screen sun detail behavior unchanged.

**Non-Goals:**
- No redesign of weather spin physics or gesture thresholds.
- No change to bird asset content, mesh, or imported animation clips.
- No new idle orbit behavior for the sun detail screen.

## Decisions

- Keep birds as children under the sun root.
  - Rationale: This preserves the existing guarantee that birds move with the sun during drag and settle.
  - Alternative considered: Reparent birds under a separate group. Rejected because it risks drift between bird and sun motion.
- Add idle orbit as a container-level motion layer on the bird container in main mode only.
  - Rationale: Container-level orbit can coexist with the bird asset's internal flapping/clip playback without rewriting imported animation data.
  - Alternative considered: Rotate the bird mesh directly. Rejected because it mixes local bird motion with system-level orbit.
- Cancel idle orbit when user interaction starts.
  - Rationale: Prevents animation stacking and ensures hand-driven interaction has a single source of truth.
  - Alternative considered: Blend idle orbit with gesture rotation. Rejected because it produces ambiguous motion and makes the bird feel detached.
- Do not auto-resume idle orbit after drag for this change.
  - Rationale: Matches the selected interaction rule: initial idle liveliness only, then full synchronization with the sun once the user takes control.

## Risks / Trade-offs

- [Orbit radius or speed feels too decorative] -> Keep orbit subtle and tune with small amplitude and long duration.
- [Imported bird animation plus orbit feels visually busy] -> Apply orbit only at the container level and leave second screen unchanged.
- [Interaction start fails to cancel orbit cleanly] -> Cancel on the same interaction-start path that already pauses automatic spin.

## Migration Plan

- Add idle orbit only in main scene setup where birds are attached.
- Cancel bird idle orbit in the gesture interaction begin path.
- Verify: initial main screen shows slow orbit; slow drag and fast drag keep bird and sun aligned; second screen remains unchanged.
- Rollback path: remove idle orbit attachment and cancellation hook.

## Open Questions

- None for this change.
