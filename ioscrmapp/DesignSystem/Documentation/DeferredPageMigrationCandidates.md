# Deferred Page Migration Candidates

This change records candidates only. It does not migrate page-level visual source in deferred modules.

## Auth

- Candidate areas: login field shell, OTP state colors, form card backgrounds.
- Risk: authentication flows are sensitive to layout and validation copy.
- Suggested split: Auth and Launch foundation follow-up.

## Launch

- Candidate areas: splash overlay chrome, progress indicators, launch container backgrounds.
- Risk: media playback and timing behavior should not be mixed with visual cleanup.
- Suggested split: Auth and Launch foundation follow-up.

## Home

- Candidate areas: carousel indicators, tab chrome, content card surfaces.
- Risk: high visual density and many cross-module entry points.
- Suggested split: Home token migration with screenshot evidence.

## Mall

- Candidate areas: product card labels, search chips, cart and detail surfaces.
- Risk: product flows and paging state should remain behaviorally unchanged.
- Suggested split: Mall components and commerce surfaces.

## Video

- Candidate areas: live/premium labels, media cards, overlay controls.
- Risk: player overlays have contrast and timing constraints.
- Suggested split: Video media surface migration.

## Billing

- Candidate areas: billing summary cards, recharge forms, status labels.
- Risk: transactional UI should preserve clarity and error handling.
- Suggested split: Billing and Offers transactional surfaces.

## Offers

- Candidate areas: offer cards, DIY selectors, status chips.
- Risk: pricing and selection states need focused regression checks.
- Suggested split: Billing and Offers transactional surfaces.

## BadgeCenter

- Candidate areas: badge grids, detail card surfaces, unlock prompt chrome.
- Risk: badge visuals and unlock prompts need separate visual review.
- Suggested split: BadgeCenter and MessageCenter list/detail migration.

## MessageCenter

- Candidate areas: message list rows, unread indicators, detail surfaces.
- Risk: list state and read/unread semantics need focused checks.
- Suggested split: BadgeCenter and MessageCenter list/detail migration.

## Excluded Modules

`Modules/Weather` and `Modules/AI` are intentionally excluded from this change. Any style findings there should be handled only by a future proposal that explicitly includes those modules.
