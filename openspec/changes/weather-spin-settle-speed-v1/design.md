## Context

Weather spin release settle behavior currently has three different timing paths: first-screen reverse settle, first-screen forward settle, and second-screen snap-back settle. Because these paths use different duration formulas and easing curves, users perceive return-to-0 as faster and more abrupt than forward settle-to-360. The change goal is to unify destination decision and motion timing while preserving existing gesture classification and non-requested visual systems.

## Goals / Non-Goals

**Goals:**
- Standardize release destination with a single 180-degree threshold rule.
- Use one shared speed model for both return-to-0 and forward-to-360 settle outcomes.
- Use one shared easing profile for both outcomes to remove reverse-only front-loading.
- Apply the same settle policy to second-screen sun release behavior.
- Keep current gesture classification thresholds unchanged in this iteration.

**Non-Goals:**
- Reworking drag classification thresholds for slow/fast branches.
- Introducing new haptics, audio remapping, or model/lighting asset changes.
- Refactoring unrelated weather transition flows.

## Decisions

- Destination decision will be normalized-angle based:
  - If abs(normalizedAngle) < 180 degrees, settle target is 0 degrees.
  - If abs(normalizedAngle) >= 180 degrees, settle target is 360 degrees in release direction.
- A shared v1 settle speed model will be used for both outcomes:
  - targetAngularSpeedRadPerSec = 4.8
  - minimumSettleDuration = 0.48
  - maximumSettleDuration = 1.45
  - duration = clamp(distanceRadians / targetAngularSpeedRadPerSec, min, max)
- A shared easing curve will be used for both outcomes:
  - yawCurve = easeOutDecay (k = 3.0)
- First-screen and second-screen settle paths will consume the same destination + duration calculation utility to avoid drift.
- Existing classification thresholds and release branch detection remain as-is in this change to isolate tuning risk.

## Risks / Trade-offs

- [Perceived too slow on short distances] With min duration raised to 0.42, tiny-angle settles may feel heavy; can be tuned after device validation.
- [Perceived too long at full turn] 360-degree settle may approach the max-duration envelope on slower swipes; capped by 1.25s to control tail latency.
- [Behavioral regression risk] Moving second-screen snap to shared logic may change muscle memory; requires focused validation on both small and large devices.
- [Parameter coupling] Shared model improves consistency but reduces per-screen artistic freedom; trade-off is intentional for interaction coherence.

## Migration Plan

- Implement the shared destination + duration utility behind existing release branches first, then switch first-screen and second-screen call sites to the new helper in one change.
- Keep current gesture classification thresholds untouched so behavior deltas are isolated to settle destination, duration, and easing only.
- Validate on at least one small and one large device profile using weather spin smoke/build checks and manual swipe-release checks around 180-degree boundary cases.
- Rollback strategy: restore previous reverse and second-screen settle duration paths while keeping helper wiring in place, so regression recovery is a single-file logic revert.

## Open Questions

- None for this artifact. If manual validation shows heavy feel at tiny angles, tune minimumSettleDuration as a follow-up parameter-only change.
