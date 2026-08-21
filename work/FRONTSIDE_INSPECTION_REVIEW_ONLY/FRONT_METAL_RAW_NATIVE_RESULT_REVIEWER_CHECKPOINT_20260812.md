# Front-metal raw-native result reviewer checkpoint — 2026-08-12

## SUPERSEDED — WITHDRAWN_PATTERN_OVERKILL

Operator broad-field review exposed recurring die/grid and edge texture in the
yellow accepted layer. This is detector overkill, not a display-alignment
issue. The accepted candidate expression allowed auxiliary local raw-change
evidence to bypass target-excluded composite difference. Preserve this record
for audit only; never present, promote, package, or use its masks as truth.

The governing correction record is
`FRONT_METAL_COMPOSITE_AUTHORITY_CORRECTION_CHECKPOINT_20260812.md`.

## Outcome

The current front-metal surface result is ready for operator review in a
derived copy of the locked BowComp highlighter. The reviewer is review-only;
it does not change detector masks, thresholds, classes, chipout behavior,
training authority, XML authority, or production routing.

Output:

`outputs/review_only/FRONT_METAL_RAW_NATIVE_RESULT_REVIEW_V1_20260812T045000Z`

Launcher:

`START_FRONT_METAL_RAW_NATIVE_RESULT_REVIEW.cmd`

Build state:

`PASS_FRONT_METAL_RAW_NATIVE_RESULT_REVIEW_ONLY`

Build-result SHA-256:

`6FB4B604D95A6151A4397FBF8C80075846EE4484CED05D14E80C685A32DAE513`

## Review evidence

- Yellow: accepted connected native raw BF/DF footprint.
- Magenta: `CONFIRM_SCRATCH_PERIODIC_BF_ELONGATED`.
- Cyan: `CONFIRM_RESIDUE_OR_CONTAMINATION_MULTICHANNEL`.
- Raw BF and raw DF at native 1:1 scale define physical size and affected
  area.
- Seam-corrected and strict-zero-peer panels remain display-only localization
  aids and do not define size.
- Accepted-or-class-specific-confirmation evidence touches 70/70 locked
  positive paths and 0/4 exact T21 scribe false controls.
- No component was suppressed merely because it recurs with the metal grid.
- Common-mode recurrence remains fail-closed pending an approved golden
  sentinel.

## Canonical UI and asset gate

- Canonical source hashes were verified before derivation.
- `styles.css` remains byte-for-byte canonical with SHA-256
  `F0D1C31FE2DA28D00857486C9678A642B7AD1C837BB9249A1FB50BAB9036777E`.
- Required canonical controls and all four highlighter actions are present.
- Full-wafer and native-tile review, zoom/pan, native-coordinate capture, queue
  workflow, and staged-feedback semantics are preserved.
- 77 referenced assets were checked with zero missing paths.
- All native tile and overlay assets are 2400 by 2000 pixels.
- 33 result overlays were generated.
- Native images are referenced from the existing V1.5 review asset set rather
  than copied. Duplicated native-image bytes: zero.
- New output size: 2.579 MiB (41 files).
- The in-app automation sandbox blocks localhost and file URLs, so no policy
  workaround was attempted. The normal local launcher is the operator path.

## Preserved chipout branch

The independent strict physical-edge/chipout branch was not altered. A fresh
native rerun on the operator-specified `Slot1Slot3Slot17/Slot01` source
retained the exact known notch-adjacent chipout (339.999 px arc) and suppressed
22/22 reviewed negative controls. See
`FRONTSIDE_SLOT01_CHIPOUT_PRESERVATION_REGRESSION_20260812.md`.

## Authority

- review-only: true
- training-eligible: false
- XML-eligible: false
- production-eligible: false

The operator next reviews the tile result and saves staged feedback. A separate
front-metal transfer cohort from another product/material state remains the
next detector gate after this review.
