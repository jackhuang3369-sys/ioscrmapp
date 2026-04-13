## Problem
The hourly strip bubble now overlays the weather title area. When the bubble appears during drag, `Clear Sky` can visually collide with the bubble and reduce readability.

## Goal
Add a deterministic, low-risk title avoidance behavior so `Clear Sky` lifts only while the bubble is visible, then returns exactly to its baseline state.

## Scope
- New capability: `weather-clear-sky-bubble-shift`.
- During strip drag (bubble visible), move `Clear Sky` to bubble-top minus 3pt in the same coordinate space.
- Add a 1pt white outline to `Clear Sky` only in lifted state.
- Non-drag hour selection (for example, tap selection without bubble) does not trigger title lift or lifted outline.
- Keep all other elements fixed (no layout shifts for city, strip, or scene).
- Restore title position/style with a short non-spring easing animation when bubble hides (target duration: 0.10s, acceptable range: 0.08s-0.14s).

### New Capabilities
- `weather-clear-sky-bubble-shift`: Dynamic title avoidance and temporary outline tied to strip bubble visibility.

### Modified Capabilities
- None.

## Non-goals
- No changes to strip generation, temperatures, haptics, or audio logic.
- No redesign of weather header typography.

## Risks
- Coordinate mismatch between bubble anchor and title anchor can cause jitter.
- Text outline implementation may vary across devices if done via layered text effects.
