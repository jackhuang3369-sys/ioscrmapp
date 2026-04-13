## Problem
The weather bottom panel does not match the intended !Weather behavior. It currently uses a short discrete timeline with icon taps, so users cannot scrub a full 24-hour window or get rich hour-by-hour temperature context.

## Goal
Redesign the bottom weather information area to a 24-hour, gesture-driven hourly strip with clear min/max cues, temperature-weighted grayscale blocks, and tactile/audio feedback.

## Scope
- New capability: `weather-hourly-24h-strip`.
- Capability mapping: New = `weather-hourly-24h-strip`; Modified = none.
- Replace the current bottom strip with 24 consecutive hourly rectangles starting at the current hour.
- Show temperatures, daily high/low, and selected-hour time bubble (e.g., 11:00).
- Drive focus by horizontal drag: center block highest, two neighbors on each side progressively lower.
- Apply grayscale by temperature (higher temp = lighter block).
- Trigger haptic + tap sound when focused hour changes.

## Non-goals
- No SceneKit weather model redesign.
- No backend/weather provider integration changes.
- No redesign of upper hero/header layout.

## Risks
- Gesture smoothness and feedback cadence may require per-device tuning.
- Dense 24-hour layout may reduce readability on small screens without careful spacing.