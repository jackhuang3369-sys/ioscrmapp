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

## 4. Feedback and UX Validation

- [x] 4.1 Add haptic feedback on focused-hour index changes.
- [x] 4.2 Reuse weather tap audio on focused-hour index changes.
- [x] 4.3 Tune spacing and label legibility on small and large iPhone simulators.

## 5. Verification, Review, and Lifecycle

- [x] 5.1 Run weather smoke tests and capture pass evidence.
- [x] 5.2 Run app build on at least one small and one large simulator target.
- [x] 5.3 Perform focused code review on regressions (interaction, performance, accessibility).
- [ ] 5.4 Sync/archive the change after acceptance.