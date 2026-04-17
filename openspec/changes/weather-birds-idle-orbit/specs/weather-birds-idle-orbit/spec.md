## ADDED Requirements

### Requirement: Main-screen birds SHALL orbit the sun while idle
The system SHALL present the bird container in the main weather screen with a slow idle orbit around the sun before user interaction begins.

#### Scenario: Main screen starts with idle bird orbit
- **WHEN** the main weather scene is presented and no drag interaction has started
- **THEN** the bird container MUST move in a slow orbit around the sun

### Requirement: Birds SHALL stay synchronized with the sun during drag
The system SHALL stop idle bird orbit when user interaction begins so bird and sun motion remain aligned during slow and fast manual rotation.

#### Scenario: Slow drag keeps bird aligned with sun
- **WHEN** the user begins a slow drag on the main weather scene
- **THEN** idle bird orbit MUST stop and the bird container MUST rotate with the sun as one system

#### Scenario: Fast drag keeps bird aligned with sun
- **WHEN** the user begins a fast drag on the main weather scene
- **THEN** idle bird orbit MUST stop and the bird container MUST rotate with the sun as one system

### Requirement: Sun-detail screen SHALL remain unchanged
This change SHALL not add idle bird orbit behavior to the sun-detail screen.

#### Scenario: Sun detail has no idle bird orbit
- **WHEN** the sun-detail screen is shown
- **THEN** the system MUST preserve existing bird behavior without adding main-screen idle orbit
