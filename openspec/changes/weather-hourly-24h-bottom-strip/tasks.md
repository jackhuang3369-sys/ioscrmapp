## 1. Test and Spike

- [x] 1.1 Add/extend weather strip smoke tests for 24-hour generation and hour-order correctness.
- [x] 1.2 Add interaction-focused tests for center-tall profile and side falloff behavior.
- [x] 1.3 Add feedback gating test to ensure one haptic + one tap per focused-hour transition.

## 2. Data and Mapping

- [x] 2.1 Create 24-hour timeline generator starting from current local hour.
- [x] 2.2 Compute window high/low temperatures for strip display.
- [x] 2.3 Add normalized temperature-to-grayscale mapping utility.

## 3. UI and Interaction

- [x] 3.1 Replace current hourly strip layout with 24 rectangle blocks.
- [x] 3.2 Implement drag-centered height profile (center highest, two-step side falloff).
- [x] 3.3 Add focused-hour circular time bubble using HH:00 formatting.
- [x] 3.4 Wire focused-hour updates to existing scene temperature selection pipeline.
- [x] 3.5 Switch to fixed-baseline upward-only protrusion and align end-cap baseline.
- [x] 3.6 Tune protrusion to half profile and add direction-aware rise/fall sequence.
- [x] 3.7 Synchronize bubble timing with protrusion and anchor bubble at protrusion-top +5.
- [x] 3.8 Track bubble X by continuous drag position to remove step-jump.
- [x] 3.9 Apply bubble typography/style updates (wider neumatic-compressed bold, +5 size, black text, +5 diameter).

## 4. Feedback and UX Validation

- [x] 4.1 Add haptic feedback on focused-hour index changes.
- [x] 4.2 Reuse weather tap audio on focused-hour index changes.
- [x] 4.3 Tune spacing and label legibility on small and large iPhone simulators.
- [x] 4.4 Remove drag-path scene-temperature fade transition to prevent flicker under fast scrubbing.
- [x] 4.5 Optimize high-frequency drag stability (audio queue reuse and lighter drag-time animation path).

## 5. Verification, Review, and Lifecycle

- [x] 5.1 Run weather smoke tests and capture pass evidence.
- [x] 5.2 Run app build on at least one small and one large simulator target.
- [x] 5.3 Perform focused code review on regressions (interaction, performance, accessibility).
- [ ] 5.4 Sync/archive the change after acceptance.