## ADDED Requirements

### Requirement: 24-hour hourly temperature strip
The system SHALL render exactly 24 hourly temperature items starting from the current local hour, and SHALL show the period high and low temperatures within the same strip context. Each hourly item SHALL be rendered as a rectangular bar.

#### Scenario: Build 24-hour window from current hour
- **WHEN** the weather main screen is displayed at local time H
- **THEN** the first hourly item MUST represent hour H and the strip MUST contain 24 consecutive hourly items

#### Scenario: Show high and low temperatures for the 24-hour window
- **WHEN** the 24-hour strip data is available
- **THEN** the UI MUST expose highest and lowest temperatures from that 24-hour window

#### Scenario: Render hourly item shape
- **WHEN** the hourly strip is displayed
- **THEN** each hourly item MUST be shown as a rectangular bar

### Requirement: Temperature grayscale encoding
The system SHALL encode each hourly block using grayscale, where higher temperature maps to a lighter gray and lower temperature maps to a darker gray.

#### Scenario: Compare two hourly temperatures
- **WHEN** hour A has a higher temperature than hour B
- **THEN** hour A's block MUST appear lighter than hour B's block

### Requirement: Drag-centered bar height profile
The system SHALL support horizontal finger scrubbing across hourly blocks, and SHALL render the focused center block as the tallest, with the nearest two blocks on each side progressively shorter.

#### Scenario: Center emphasis during scrub
- **WHEN** the user drags across the strip and hour X is focused at center
- **THEN** block X MUST be tallest and the two adjacent levels on both sides MUST step down in height

### Requirement: Focus feedback and time bubble
The system SHALL emit haptic feedback and tap audio when the focused hour changes, and SHALL display a circular time bubble on the tallest focused block using fixed 24-hour HH:00 formatting.

#### Scenario: Focus transition feedback
- **WHEN** focused hour changes from A to B during drag
- **THEN** the system MUST trigger one haptic event and one tap audio event for that transition

#### Scenario: Show focused hour bubble
- **WHEN** an hour is focused in the strip
- **THEN** a circular bubble MUST be displayed above the tallest focused block with the focused time text in HH:00 format

#### Scenario: Keep time bubble format fixed
- **WHEN** device locale uses a 12-hour convention
- **THEN** the focused-hour bubble MUST still display time in 24-hour HH:00 format
