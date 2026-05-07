## Context

The repository uses OpenSpec for change tracking, but the new development-guidelines baseline was initially written as a standalone document under `docs/`. That placement does not follow the repository workflow and makes governance drift likely. The project also needs one concise source for current architectural reality: single target boundaries, SceneKit as a feature exception, large root screens, weak test automation, and mock/remote parity risks.

## Goals / Non-Goals

**Goals:**
- Capture project governance as an OpenSpec change.
- Define one capability spec for engineering guardrails and known limits.
- Make OpenSpec the source of truth for future updates to this baseline.

**Non-Goals:**
- Refactor runtime code in this change.
- Archive the governance baseline into `openspec/specs/` before team review.
- Solve testing, CI, or modularization gaps immediately.

## Decisions

### 1. Use a dedicated change
Store the baseline in `openspec/changes/establish-development-guidelines/`. Keeping it in `docs/` was rejected because it bypasses the existing spec-driven workflow.

### 2. Define one repository-wide capability
Use a single capability, `development-guidelines`, instead of splitting by architecture, testing, and security. The scope is governance, not implementation.

### 3. Remove the duplicate standalone file
Keep one canonical source to avoid divergence between `docs/` and OpenSpec artifacts.

## Risks / Trade-offs

- [Documentation-only governance] -> Review discipline must enforce it until CI and module boundaries improve.
- [Broad repository-wide scope] -> Keep the spec normative and implementation-neutral.
- [English-only artifacts vs Chinese discussion] -> Keep user communication in Chinese and OpenSpec artifacts in English.

## Migration Plan

Create the change artifacts, remove the duplicate `docs/` file, review wording with the team, then archive the change after adoption.
