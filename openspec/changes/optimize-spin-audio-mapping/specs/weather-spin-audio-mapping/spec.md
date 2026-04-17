## ADDED Requirements

### Requirement: Spin release audio SHALL follow settle outcome
The system SHALL derive weather spin release audio from the computed settle decision in the same release event that starts settle animation.

#### Scenario: Single-turn settle uses slow spin sound
- **WHEN** a horizontal spin release resolves to a settle decision with target turn count equal to 1
- **THEN** the system MUST play the slow spin release variant

#### Scenario: Multi-turn settle uses fast spin sound
- **WHEN** a horizontal spin release resolves to a settle decision with target turn count greater than or equal to 2
- **THEN** the system MUST play the fast spin release variant

#### Scenario: Reverse return does not play spin loop sound
- **WHEN** a horizontal spin release resolves to a reverse return-to-front settle decision with target turn count equal to 0
- **THEN** the system MUST NOT play a spin loop release sound

### Requirement: Audio decision SHALL be deterministic from settle decision
The system SHALL avoid independent velocity-only audio classification for horizontal spin release once settle decision is available.

#### Scenario: Velocity-only branch is not used when settle decision exists
- **WHEN** settle decision has been computed for a horizontal spin release
- **THEN** audio variant selection MUST be based on settle decision fields rather than a separate raw-speed threshold

### Requirement: Horizontal scope SHALL be explicit
The deterministic settle-driven spin audio mapping SHALL apply to horizontal spin release handling only in this change.

#### Scenario: Non-horizontal release behavior remains unchanged
- **WHEN** release handling is in non-horizontal interaction mode
- **THEN** the system MUST preserve existing non-horizontal release audio behavior in this change
