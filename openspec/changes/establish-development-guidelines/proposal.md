## Why

The project has grown around feature directories, protocol-based services, and a central app container, but it has no authoritative governance artifact for architecture boundaries, state growth, service parity, or verification expectations. A standalone docs file is not enough because the repository already uses OpenSpec as the change system.

## What Changes

- Add an OpenSpec change that defines project-level development guidelines.
- Define normative requirements for feature ownership, route and state growth control, service parity, configuration hygiene, and delivery verification.
- Record current architectural limits so they are treated as constraints, not target design.
- Make OpenSpec the single source of truth for this governance baseline.

## Capabilities

### New Capabilities
- `development-guidelines`: Project-level engineering rules for architecture boundaries, quality expectations, and known limitations.

### Modified Capabilities
None.

## Impact

- Affects `openspec/changes/establish-development-guidelines/` and future review expectations.
- Replaces the duplicate standalone guidelines document under `docs/`.
- No runtime behavior or public API changes.
