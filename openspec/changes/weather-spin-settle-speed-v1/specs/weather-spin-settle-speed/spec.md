## ADDED Requirements

### Requirement: Settle destination SHALL follow a shared 180-degree threshold rule
The weather spin release logic SHALL determine settle destination from normalized yaw angle using one threshold rule for both first-screen and second-screen flows.

#### Scenario: Under-threshold release settles to 0 degrees
- **WHEN** the absolute normalized release angle is less than 180 degrees
- **THEN** settle destination MUST be 0 degrees

#### Scenario: At-or-over-threshold release settles to 360 degrees in current direction
- **WHEN** the absolute normalized release angle is greater than or equal to 180 degrees
- **THEN** settle destination MUST be 360 degrees in the current release direction

#### Scenario: Exact 180-degree boundary settles forward
- **WHEN** the absolute normalized release angle is exactly 180 degrees
- **THEN** settle destination MUST resolve to the forward 360-degree target in the current release direction

### Requirement: Settle duration SHALL use one shared angular-speed model
The weather spin release logic SHALL compute settle duration from angular distance and one shared target angular speed model for return and forward outcomes.

#### Scenario: Return and forward use the same duration formula
- **WHEN** a settle destination has been selected (0 or 360)
- **THEN** both outcomes MUST use duration = clamp(distanceRadians / targetAngularSpeedRadPerSec, minimumSettleDuration, maximumSettleDuration)

#### Scenario: Shared v1 parameters are applied
- **WHEN** settle duration is calculated in this change
- **THEN** the system MUST use targetAngularSpeedRadPerSec=4.8, minimumSettleDuration=0.48, and maximumSettleDuration=1.45

### Requirement: Settle easing SHALL be unified across return and forward outcomes
The weather spin release logic SHALL use the same yaw easing curve for return-to-0 and forward-to-360 settle motions.

#### Scenario: Reverse settle uses shared decay easing
- **WHEN** release resolves to return-to-0 settle
- **THEN** yaw easing MUST use easeOutDecay with k=3.0

#### Scenario: Forward settle uses shared decay easing
- **WHEN** release resolves to forward-to-360 settle
- **THEN** yaw easing MUST use easeOutDecay with k=3.0

### Requirement: Cross-screen settle consistency SHALL be preserved
Second-screen sun release settle behavior SHALL use the same destination threshold and duration/easing model as first-screen settle behavior.

#### Scenario: First-screen and second-screen produce equivalent settle policy
- **WHEN** first-screen and second-screen releases have equivalent normalized angle and direction
- **THEN** both flows MUST resolve destination and duration using the same threshold and speed model
