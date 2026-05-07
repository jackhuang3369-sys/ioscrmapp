## ADDED Requirements

### Requirement: OpenSpec is the source of truth for repository governance
The project SHALL store new repository-wide engineering governance updates as OpenSpec change artifacts instead of standalone unmanaged markdown files.

#### Scenario: Add a new governance baseline
- **WHEN** the team introduces or revises project-level development rules
- **THEN** the change MUST be stored under `openspec/changes/<change-name>/`
- **AND** the change MUST include proposal, design, tasks, and at least one capability spec

#### Scenario: Replace a duplicate standalone document
- **WHEN** the same governance content exists in both `docs/` and an OpenSpec change
- **THEN** the repository MUST keep one canonical source
- **AND** duplicate unmanaged copies MUST be removed or explicitly redirected

### Requirement: Feature ownership boundaries are explicit
The project SHALL assign each new business capability to a single owning feature area and SHALL avoid direct cross-feature access to internal view state or feature-private models.

#### Scenario: Add a new feature
- **WHEN** a new user-facing business capability is introduced
- **THEN** the change MUST define an owning feature under `Modules/<Feature>/`

#### Scenario: Cross-feature integration
- **WHEN** one feature needs another feature's behavior
- **THEN** the integration MUST use explicit inputs, shared core utilities, or service contracts
- **AND** it MUST NOT directly depend on another feature's internal view state

### Requirement: Route and local state growth is controlled
The project SHALL treat root-screen state sprawl as a constrained resource and SHALL require explicit route or state extraction when a screen grows beyond agreed thresholds.

#### Scenario: Screen exceeds route or state threshold
- **WHEN** a screen accumulates excessive modal flags, route booleans, or local state
- **THEN** the change MUST extract a route enum, navigation state object, coordinator, or child component boundary

### Requirement: Service contracts stay environment-safe
The project SHALL keep mock and remote service contracts aligned and SHALL NOT silently substitute mock behavior in remote-targeted flows.

#### Scenario: Service protocol changes
- **WHEN** a service protocol adds, removes, or changes a method
- **THEN** the corresponding mock and remote implementations MUST be updated together

#### Scenario: Remote mode execution
- **WHEN** the app runs in a remote-targeted path
- **THEN** the flow MUST use remote behavior consistently
- **AND** it MUST NOT silently fall back to mock behavior without explicit documentation

### Requirement: Configuration and secret handling is reviewable
The project SHALL keep environment switching testable and SHALL NOT hardcode secrets, temporary credentials, or hidden internal endpoints in source files.

#### Scenario: Introduce configuration values
- **WHEN** a change adds environment-dependent configuration
- **THEN** the configuration source MUST be explicit and reviewable

#### Scenario: Handle sensitive values
- **WHEN** a change needs API keys, tokens, or private endpoints
- **THEN** those values MUST be sourced from approved configuration mechanisms
- **AND** they MUST NOT be committed as hardcoded literals

### Requirement: Non-trivial changes include verification evidence
The project SHALL require non-trivial changes to describe affected areas, verification evidence, and known delivery risks.

#### Scenario: Submit a non-trivial change
- **WHEN** a change affects architecture, services, navigation, authentication, billing, or other core flows
- **THEN** the submission MUST describe the impacted subsystem
- **AND** it MUST include verification evidence or explicit manual validation steps
