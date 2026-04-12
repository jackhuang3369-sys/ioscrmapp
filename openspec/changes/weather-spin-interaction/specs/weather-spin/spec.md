## ADDED Requirements

### Requirement: Front-facing weather rest state
The weather main scene SHALL present the sun assembly and temperature digits in a front-facing pose at rest.

#### Scenario: Initial weather entry
- **WHEN** the weather main scene appears
- **THEN** the visible rotation is front-facing and the sun and digits appear visually still

#### Scenario: Rest after settle
- **WHEN** a drag interaction finishes settling
- **THEN** the visible pose is front-facing

### Requirement: Drag-to-turn mapping
The weather main scene SHALL map one horizontal screen-width drag to one full 360-degree turn of the shared rotating assembly.

#### Scenario: Full-width drag
- **WHEN** the user slowly drags horizontally across one full screen width
- **THEN** the shared rotating assembly completes one full turn and ends front-facing

#### Scenario: Live drag follow
- **WHEN** the user drags horizontally in the weather main scene
- **THEN** the shared rotating assembly follows the drag with yaw-first motion

### Requirement: Deterministic release behavior
The weather main scene SHALL resolve drag release using distance-aware and speed-aware settle rules.

#### Scenario: Slow drag under half screen
- **WHEN** the user performs a slow drag shorter than half a screen width and releases
- **THEN** the scene settles backward to the front-facing pose

#### Scenario: Slow drag over half screen
- **WHEN** the user performs a slow drag longer than half a screen width but shorter than one full screen width and releases
- **THEN** the scene settles forward to the next front-facing pose

#### Scenario: Slow drag over one full screen
- **WHEN** the user performs a slow drag longer than one full screen width and releases
- **THEN** the scene settles to the nearest forward front-facing pose from the completed full-turn progress

#### Scenario: Fast drag under quarter screen with low speed
- **WHEN** the user performs a drag shorter than one quarter of the screen width and releases at low speed
- **THEN** the scene settles backward to the front-facing pose

#### Scenario: Fast drag under quarter screen with high speed
- **WHEN** the user performs a drag shorter than one quarter of the screen width and releases at high speed
- **THEN** the scene commits forward momentum turns and settles front-facing

#### Scenario: Fast drag between quarter and half screen
- **WHEN** the user performs a fast drag between one quarter and one half of the screen width and releases
- **THEN** the scene commits one forward full turn before stopping front-facing

#### Scenario: Fast drag over half screen
- **WHEN** the user performs a fast drag longer than half of the screen width and releases
- **THEN** the scene commits forward turns from projected travel and SHALL cap total turns in that settle at eight

### Requirement: Controlled settle easing
The weather main scene SHALL use controlled ease-out behavior before reaching the front-facing stop pose.

#### Scenario: Multi-turn settle
- **WHEN** the scene settles from a single-turn or multi-turn forward commit
- **THEN** the settle motion eases down smoothly before the final front-facing stop

#### Scenario: Final micro-stop
- **WHEN** the final front-facing stop begins
- **THEN** the last visible angular segment eases more softly than earlier settle motion

### Requirement: Bird animation continuity
The weather main scene SHALL preserve bird local animation while the shared rotating assembly turns.

#### Scenario: Resting bird animation
- **WHEN** the weather main scene is idle
- **THEN** the bird keeps its local animation while the assembly remains front-facing

#### Scenario: Rotating bird animation
- **WHEN** the user drags or the scene settles through turns
- **THEN** the bird follows the shared rotating assembly and keeps local animation active

### Requirement: Front-facing detail entry
The weather main scene SHALL align to a front-facing pose before entering sun detail.

#### Scenario: Detail entry from rotated state
- **WHEN** the user requests sun detail while the weather assembly is not front-facing
- **THEN** the scene aligns to front-facing before starting the sun detail transition
