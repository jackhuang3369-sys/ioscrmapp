## Context

The weather spin interaction already computes a deterministic settle decision at release time, including mode and target turn count. Visual behavior (reverse return, single-turn completion, momentum multi-turn settle) is therefore stable and predictable. Audio behavior is currently selected using a separate raw velocity threshold, which can diverge from the visual settle outcome.

## Goals / Non-Goals

**Goals:**
- Align spin release audio with the same settle decision used by the visual animation.
- Ensure slow release audio represents single-turn completion behavior.
- Ensure fast release audio represents momentum multi-turn behavior.
- Define explicit behavior for reverse return-to-front outcomes.

**Non-Goals:**
- No redesign of spin gesture physics, settle math, or turn tuning constants.
- No new audio assets required for this change.
- No changes to non-spin weather sounds (detail enter, shape tap, timeline tick).

## Decisions

- Use settle decision as the source of truth for spin audio mapping.
  - Rationale: This guarantees what users hear matches what they see.
  - Alternative considered: Keep velocity threshold only. Rejected because it can disagree with resulting turns.
- Map by target turn count with deterministic rules.
  - Rationale: Turn count directly encodes whether the release resolves into a single-turn or momentum multi-turn outcome.
  - Mapping direction:
    - 0-turn reverse return: suppress spin loop audio (no spin loop playback).
    - 1-turn completion: play slow variant.
    - 2+ turns: play fast variant.
  - Alternative considered: Map by mode only. Equivalent semantically in many cases but turn-count mapping is simpler to audit.
- Scope boundary: deterministic spin-audio remapping applies to horizontal spin release flow. Non-horizontal release handling remains unchanged in this change.
- Trigger audio immediately after settle decision is computed in release handling.
  - Rationale: Keeps audio timing synchronized to the chosen settle path without adding additional state.

## Risks / Trade-offs

- [Suppressing 0-turn audio may feel too quiet for some users] -> Validate by smoke interaction and, if needed, add a light non-spin click in a follow-up change.
- [Turn-count mapping may sound abrupt near the 1-turn/2-turn boundary] -> Keep boundary deterministic in this change and tune spin thresholds separately if needed.
- [Future tuning changes could alter distribution of slow vs fast sounds] -> Document mapping contract in specs so tuning updates remain intentional.

## Migration Plan

- Implement mapping in the spin release handling path that already computes settle decision.
- Run weather spin smoke interaction to validate audible/visual coherence for: short slow drag, half-screen drag, high-velocity multi-turn drag, and reverse return.
- Rollback path: revert audio mapping call site to the previous velocity-threshold behavior.

## Open Questions

- None for this change. Follow-up product exploration for a subtle non-spin cue on reverse return can be proposed separately.
