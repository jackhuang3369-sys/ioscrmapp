## 1. Test and Spike

- [x] 1.1 Add/extend smoke coverage for title lifted/restored state transitions.
- [x] 1.2 Add a focused interaction check for smooth drag-time title motion using title y-position samples from the UI update path (no step-jump/flicker; no single-frame title-y jump > 2pt under at least 2s of continuous drag at display-frame cadence).
- [x] 1.3 Add a reverse-path interaction check: non-drag hour selection must not trigger title lift or lifted outline.

## 2. Data and Coordination

- [x] 2.1 Expose bubble visibility and anchor data from strip to parent in a single source of truth.
- [x] 2.2 Map bubble anchor to `Clear Sky` lift target (bubbleTopY - 3pt) in parent coordinate context.

## 3. UI Implementation

- [x] 3.1 Implement `Clear Sky` lift-on-bubble-visible behavior.
- [x] 3.2 Implement `Clear Sky` restore-to-baseline with short non-spring easing (0.08s-0.14s) when bubble hides.
- [x] 3.3 Add temporary 1pt white outline for lifted state only.
- [x] 3.4 Ensure other weather elements remain position-stable during title transitions.

## 4. Verification and Lifecycle

- [x] 4.1 Run weather smoke tests and capture evidence.
- [x] 4.2 Run simulator build validation.
- [ ] 4.3 Perform focused review for timing jitter and style side effects (record drag video/snapshots and sampled title-y traces showing stable motion under the defined threshold and no side effects on non-title elements).
- [ ] 4.4 Sync/archive this change after acceptance.
