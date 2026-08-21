# Front-metal D7 V17 training-input lock checkpoint - 2026-08-14

Status: `PENDING_GATE`.

## Exact saved operator input

The authoritative new save is:

- directory: `human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260815T002456Z`;
- review ID: `FM7_V16_20260814T2350Z`;
- coordinates: `ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`;
- coordinates SHA-256: `1CB24A30C23BC3E92CDB568C32D453D506BE12DC7FC5D7D4E77773CF0F7E50DE`;
- completion marker SHA-256: `47FACAD98690D9221171A62DBDD7EC1869076B02133FB26B6E64351A8CC7D00C`;
- saved UTC: `2026-08-15T00:25:44.501Z`;
- local marked PNGs: 87;
- marked-image errors: 0.

This save is strictly separate from the locked V14 save at
`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260814T174534Z`, SHA-256
`63E8A3524E1F98C47FF782AF792A2B39F7E4E3EE07D49637C888DCF5410D306B`.
D4, D5, D6, V14, and V16 identifiers must remain separate.

## Save accounting

The V16-backed save contains all 98 native review fields and 317
native-coordinate strokes:

- 231 `RECLASSIFY_REAL_DEFECT`;
- 57 `ADD_MISSED_DEFECT`;
- 29 `REMOVE_FALSE_DETECTION`;
- 184 Scratch;
- 91 Particle;
- 13 Residue;
- 22 field comments.

All 279 V14 strokes are preserved byte-for-byte. The V16-backed save adds 38
strokes and removes none: 26 missed-defect additions, 5 reclassifications, and
7 false removals. The new class strokes are 27 Scratch, 1 Particle, and 3
Residue.

## Operator authorization and intended use

The operator explicitly authorized front-metal supervised training/calibration
as part of the pre-smoke phase. The saved response's historical
`trainingEligible=false` field remains immutable evidence of the state at save
time; the later authorization is recorded here and does not rewrite the save.

The requested V17 behavior is:

- every retained front-metal finding receives the highest-supported available
  defect category rather than a routine class/coverage hold;
- saved false findings remain excluded;
- saved reclassifications and missed-defect guidance are training inputs;
- no old comments, highlighter marks, or predecessor heatmaps may be baked into
  clean or current rasters;
- front-metal training stays isolated from Bare, BowComp, scratch-test, edge,
  and chipout families;
- XML and production routing remain disabled.

## Frozen validation design

Before per-field labels are used for fitting, components that share exact
source-space pixels across overlapping tiles must be assigned to one validation
group. Groups are deterministically partitioned by SHA-256 so an overlapping
view of one physical finding cannot appear in both training and evaluation.
The pre-smoke gate must report class confusion, saved-false precision/recall,
missed-defect support, and per-class coverage. A separately bounded unseen
acquisition smoke run must exercise the real wrapper, paths, full-resolution
inputs, reviewer, and JBOD review-only route; it is not a substitute for the
held-out labeled evaluation.

No V17 reviewer or JBOD package is released by this checkpoint. Both remain
`PENDING_GATE` until classifier, raster-provenance, canonical-UI, path,
PowerShell 5.1 wrapper, installed-predecessor, and final-ZIP rehearsals pass.

