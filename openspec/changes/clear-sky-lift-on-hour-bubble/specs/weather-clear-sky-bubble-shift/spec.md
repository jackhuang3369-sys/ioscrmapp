## ADDED Requirements

### Requirement: Clear Sky lifts while bubble is visible
The system SHALL move the `Clear Sky` title to a lifted position when the hourly bubble is visible during strip drag.

#### Scenario: Bubble-visible lift
- **WHEN** the user drags the hourly strip and the time bubble is visible
- **THEN** `Clear Sky` MUST move to a position above the bubble by 3pt
- **AND** `Clear Sky` MUST use the same coordinate reference as the bubble anchor
- **AND** the vertical mapping MUST be `titleBaselineY = bubbleTopY - 3pt`

#### Scenario: Bubble-hidden restore
- **WHEN** strip dragging ends and the bubble is hidden
- **THEN** `Clear Sky` MUST return to its exact baseline position with a short non-spring easing animation
- **AND** animation target duration SHOULD be 0.10s
- **AND** animation duration MUST be within 0.08s-0.14s

#### Scenario: Non-drag selection does not lift title
- **WHEN** the user changes hour selection without showing the bubble (for example, tap selection)
- **THEN** `Clear Sky` MUST remain at its baseline position
- **AND** lifted-state outline MUST NOT be applied

### Requirement: Lifted state styling is isolated
The system SHALL apply temporary styling only to `Clear Sky` while lifted and SHALL keep other elements unchanged.

#### Scenario: White outline in lifted state
- **WHEN** `Clear Sky` is in lifted state
- **THEN** `Clear Sky` MUST render with a white outline of width 1pt

#### Scenario: No side effects on other elements
- **WHEN** `Clear Sky` enters or exits lifted state
- **THEN** other weather elements MUST keep their original positions

### Requirement: Motion must be stable
The system SHALL avoid jumpy title movement while bubble position updates.

#### Scenario: Continuous drag motion
- **WHEN** the user drags continuously across the strip
- **THEN** `Clear Sky` movement MUST be smooth and MUST NOT step-jump or flicker
- **AND** no single-frame title-y jump greater than 2pt is allowed during continuous drag sampling
