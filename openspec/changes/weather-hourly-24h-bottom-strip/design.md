## Context
The weather main view currently renders a short, discrete timeline strip and updates selected temperature by tap/drag index. The new behavior requires a 24-hour strip with continuous scrubbing, dynamic bar emphasis around the center, and synchronized feedback. Constraints: SwiftUI-first, keep existing WeatherScene temperature sync, preserve current visual language, and support small/large iPhone layouts.

## Goals / Non-Goals
**Goals:**
- Deliver a 24-hour hourly strip starting from current hour.
- Expose min/max temperature and selected-hour bubble.
- Use grayscale mapping where higher temperature is lighter.
- Provide drag-centered height profile and hour-to-hour feedback (haptic + tap).
- Keep fixed 24-hour HH:00 bubble formatting and acceptable frame-time on iPhone 17 class devices.

**Non-Goals:**
- SceneKit weather model changes.
- New backend API contracts.
- Redesign of upper weather hero/header.

## Decisions
- Build a dedicated hourly-strip view model to generate 24 hourly entries from current local hour; alternative (hard-coded list) rejected for poor realism.
- Keep WeatherMainView as single source of selected hour; strip emits focused hour updates to existing temperature pipeline.
- Use normalized temperature-to-gray mapping for block fill; alternative categorical buckets rejected because it loses relative temperature cues.
- Trigger feedback only when focused hour index changes; alternative per-frame triggering rejected for noise and battery cost.
- Keep focused-hour bubble text in fixed 24-hour HH:00 format to match target visual behavior across locales.
- Use fixed baseline rail with upward-only protrusion during drag to match reference motion language.
- Reduce protrusion amplitude to half profile for better legibility and less visual jitter on fast scrubs.
- Compute protrusion with directional bias using drag direction, so movement reads as progressive rise/fall on leading/trailing sides.
- Drive bubble anchor from continuous drag position and protrusion top; bubble center Y is pinned to protrusion-top minus offset (+5 above top edge).
- Remove drag-path transition animation for scene temperature updates to prevent digit flicker and overlap under high-frequency scrubbing.
- Bubble visual style uses wider neumatic-compressed bold font, larger type and larger circle for readability.

## Risks / Trade-offs
- [Dense layout on small screens] → Use adaptive bar width/spacing and horizontal clipping rules.
- [Over-frequent feedback] → Gate by index transition and debounce ultra-fast oscillation.
- [Animation cost] → Keep bar count fixed at 24 and avoid expensive effects.
- [Timing desync between protrusion and bubble] → Keep drag-path updates immediate (no selected-ID spring on drag path).
- [Fast scrub instability] → Prefer queue-based audio/haptic reuse and minimal main-thread animation work.

## Migration Plan
Roll out behind the weather module path only. Validate snapshots + interaction smoke on small/large simulators, then enable by default. Rollback is file-level revert of strip + view-model wiring.

## Open Questions
None blocking; only subjective polish remains (final typography weight and bubble opacity tuning).