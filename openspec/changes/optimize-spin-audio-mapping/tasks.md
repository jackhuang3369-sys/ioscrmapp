## 1. Spin Release Mapping

- [x] 1.1 Replace velocity-only spin audio classification with settle-decision-driven mapping in weather spin release handling
- [x] 1.2 Implement deterministic mapping rules: 0-turn reverse return -> no spin loop audio, 1-turn -> slow spin audio, 2+ turns -> fast spin audio
- [x] 1.3 Ensure audio trigger timing occurs after settle decision computation and before/with settle animation start

## 2. Regression Safety

- [x] 2.1 Keep existing settle physics and turn tuning constants unchanged while applying audio mapping changes
- [x] 2.2 Keep non-horizontal release audio behavior unchanged; limit deterministic remapping to horizontal release flow
- [x] 2.3 Verify non-spin weather audio call sites (detail enter, shape tap, timeline tick) are unaffected by this change

## 3. Validation

- [x] 3.1 Run spin interaction smoke checks for slow single-turn, fast multi-turn, and reverse return cases to confirm audio-visual consistency
- [x] 3.2 Confirm no velocity-only fallback branch remains for horizontal spin release audio when settle decision is available
- [x] 3.3 Verify non-horizontal release path behavior is unchanged
