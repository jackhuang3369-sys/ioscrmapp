## ADDED Requirements

### Requirement: Sun insight panel width matches reference on iPhone 15/16
The system SHALL render the sun insight panel (from the UV row to the Day/Week toggle) at approximately two-thirds of screen width on iPhone 15 and iPhone 16 portrait screens, with a target width ratio of 0.67 and allowed range of 0.64 to 0.70.

#### Scenario: Panel width aligns with reference screenshot
- **WHEN** the user opens the sun detail screen on iPhone 15 or iPhone 16
- **THEN** the measured panel width ratio against full screen width MUST be within 0.64 to 0.70
- **THEN** the panel width MUST be wider than the pre-change 28pt-per-side margin implementation

### Requirement: Sun insight panel vertical placement matches reference on iPhone 15/16
The system SHALL apply a steady-state Y adjustment of -8pt (allowed tuning range: -6pt to -10pt) to the sun insight panel container while preserving the existing transition offset formula.

#### Scenario: Panel block sits at expected vertical band
- **WHEN** the sun detail screen is presented on iPhone 15 or iPhone 16
- **THEN** the panel block MUST render within the approved vertical reference band without clipping or overlap with scene content
- **THEN** the transition animation formula `offset(y: (1 - interfaceOpacity) * 180)` MUST remain unchanged
- **THEN** the steady-state Y adjustment MUST be configured within -6pt to -10pt

### Requirement: Interaction surface remains unchanged for this layout tuning
The system SHALL keep the WeatherSunInteractionSurface layout and behavior unchanged during this change.

#### Scenario: Interaction surface parameters are preserved
- **WHEN** the layout tuning for the sun insight panel is applied
- **THEN** WeatherSunInteractionSurface horizontal padding and touch behavior MUST remain unchanged from the pre-change implementation