# Front-metal D7 V17 classifier gate checkpoint — 2026-08-14

Disposition: `PENDING_GATE`

This file is the lightweight continuation authority after supervised
front-metal-only calibration and before raster recovery, final reviewer
generation, smoke testing, or JBOD packaging. Do not reconstruct this state
from Codex task history.

## Locked operator feedback

- Review: `FM7_V16_20260814T2350Z`
- Save root:
  `human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260815T002456Z`
- Coordinate JSON SHA-256:
  `1CB24A30C23BC3E92CDB568C32D453D506BE12DC7FC5D7D4E77773CF0F7E50DE`
- Save-marker SHA-256:
  `47FACAD98690D9221171A62DBDD7EC1869076B02133FB26B6E64351A8CC7D00C`
- All 279 earlier V14 strokes are preserved; V16 adds 38 strokes.
- The saved file contains 317 strokes: 231 reclassifications, 57 added
  misses, and 29 false-removal strokes.
- Saved class strokes: 184 Scratch, 91 Particle, 13 Residue. The 29 false
  strokes carry no defect class and remain exclusions.

## Locked training data

- Output: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17A1`
- `TRAINING_DATA.json` SHA-256:
  `F856B34BB0543E6CE8EE521B4933FEC058C77F183AFBB063A369B65CA4351AEF`
- 308 components and 72,499 exact component pixels were verified.
- 282 exact source-overlap groups; 241 directly labeled components,
  65 unlabeled components, and 2 component label conflicts.
- Direct component labels: 135 Scratch, 62 Particle, 18 Residue, 26 False.
- 24 of 26 newly added-miss strokes intersect existing exact component
  evidence in an overlapping native tile.
- Two Scratch add-miss strokes have no existing component evidence within
  32 source pixels and require bounded native BF/DF observed-pixel recovery:
  - stroke 238: `T16_R03C00 / FIELD_09_3_3`;
  - stroke 278: `T21_R04C00 / FIELD_02_0_2`.
  They must not be painted from freehand geometry or converted to Normal.

## Classifier release candidate

- Output: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17M3`
- State: `PASS_FRONT_METAL_V17_CLASSIFIER_GATE`
- Source-grouped deterministic nested 5-fold evaluation prevents exact
  source-overlap groups from crossing train/test folds.
- Group count: 217.
- Held-out accuracy: `0.8663594470046083`.
- Held-out macro F1: `0.8178875218348902`.
- Scratch recall: `0.9380530973451328`.
- Particle recall: `0.819672131147541`.
- Residue recall: `0.6666666666666666`.
- False precision: `1.0`; false recall: `0.8`.
- Selected K: `9`; automatic false threshold: `0.95`.
- All 308 components receive a result; routine hold count is zero.
- Final counts: 159 Scratch, 75 Particle, 41 Residue, 33 False.
- Authority split: 241 direct saved labels, 1 saved source-overlap-group
  label, 66 trained best-supported classifications.
- Seven model-only false exclusions all have probability `1.0`; none fall
  below the locked `0.95` automatic exclusion threshold.
- `EVALUATION.json` SHA-256:
  `CB092E201A0E0C21AA4A74F868F69BE2FF1E70AC108A601310E85D8AA345FE6B`
- `MODEL.json` SHA-256:
  `986A8FF4F859EBC8CC46CAB917A767463CE613183351D59FB7D72EDB25B5871A`
- `PREDICTIONS.json` SHA-256:
  `3D34856FAD88EF65874355E1047CFC840FF2111965472256CB6B0385231B24EF`

`FM7V17M1` and `FM7V17M2` are `DIAGNOSTIC_ONLY` and must never drive a
reviewer or JBOD release. M3 is only `PENDING_GATE`; it is not yet a smoke
pass, reviewer release, or JBOD authority.

## Required continuation order

1. Read the governing continuity files and this checkpoint; run
   `utilities/Confirm-ArgosProjectContinuity.ps1`.
2. Audit and recover the two unsupported add-miss strokes only from bounded
   native raw BF/DF evidence. Preserve source resolution and file-backed
   evidence; do not infer a line or paint the saved stroke as detector truth.
3. Build V17 from the clean canonical reviewer source and current raw/source
   masks. Do not inherit raster composites, old heatmaps, or highlighter
   drawings. Keep canonical CSS byte-identical.
4. Apply saved labels first, then the M3 best-supported class for unlabeled
   retained components. Exclude saved and qualifying model False components.
   Do not emit routine class or coverage holds. Contamination remains an
   unavailable supervised class because no operator examples were supplied;
   do not invent it.
5. Regenerate native and full-wafer class heatmaps from current masks. Full
   wafer must show the defect areas. Keep Scratch magenta, Particle green,
   and Residue amber consistently in labels, bubbles, crops, and full-wafer
   overlays. Cyan is not a defect class; it must not be used as a stale hold
   layer when routine holds are zero.
6. Run component-accounting, saved-false, raster provenance/embedded-mark,
   path-budget, wrapper, ASCII/mojibake, embedded-payload, and live GUI visual
   smoke gates. Use the in-app browser only after announcing the browser skill;
   do not return screenshots or image bytes to the task.
7. Only after the reviewer and held-out/unseen-acquisition smoke gates pass,
   build the review-only JBOD front-metal route alongside the currently
   approved routes. XML and production routing remain disabled.
8. Rehearse the exact final JBOD ZIP installer under Windows PowerShell 5.1
   against byte-for-byte copies of every approved installed predecessor,
   including refusal-before-mutation and target-hash idempotence. Publish only
   when every mandatory rehearsal case passes and a machine-readable PASS
   artifact exists beside the package.

## Session safety stop

At `2026-08-15T01:00:46.9174415Z`,
`utilities/Confirm-ArgosCodexSessionSafety.ps1 -AsJson` reported this active
task at 267,094,574 bytes (254.721 MiB), state
`CHECKPOINT_AND_PREPARE_ROTATION`, immediately below the 256 MiB rotation
threshold. Continue in a fresh task from this file. Never open or fork this
session to recover state; use this file-backed checkpoint only.
