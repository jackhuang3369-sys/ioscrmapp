## Context
`Clear Sky` is currently rendered in `WeatherMainView`, while bubble visibility and anchor are computed inside `WeatherHourlyStrip`. To avoid repeated regressions, this change keeps behavior localized and data-driven.

## Goals / Non-Goals
**Goals:**
- Lift `Clear Sky` only when bubble is visible.
- Position lift target at bubble-top minus 3pt.
- Add temporary 1pt white outline in lifted state.
- Prevent layout movement for non-title elements.

**Non-Goals:**
- No changes to strip data, scene temperature logic, or feedback channels.
- No header redesign.

## Decisions
- Introduce a lightweight upward signal from strip to parent (`bubbleVisible` + bubble anchor Y).
- Compute title offset in parent using bubble anchor from the same coordinate context.
- Use explicit mapping in the parent coordinate space: `titleBaselineY = bubbleTopY - 3pt`.
- Apply outline only in lifted state using a reversible text-styling wrapper.
- Keep animation short and unilateral (title-only), with no container-wide layout animation.
- Animation policy: non-spring easing only (`easeOut`, target duration 0.10s, acceptable range 0.08s-0.14s).

## Risks / Trade-offs
- [Cross-view timing drift] → Use one visibility source of truth from strip.
- [Outline fidelity variance] → Prefer deterministic 1pt effect and verify visually on target simulator.
- [Jitter under fast drag] → Avoid spring on drag path; use direct updates with minimal easing.

## Migration Plan
- Implement behind the existing weather strip interaction path.
- Validate with drag interaction checks and smoke build.
- Rollback is reverting title-lift wiring and style wrapper.

## Implementation Note
- Outline implementation priority: use pure 1pt stroke first; if font rendering constraints block it, use a documented near-equivalent fallback and keep visual width at 1pt.
