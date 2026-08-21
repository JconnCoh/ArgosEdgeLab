# Front-metal D5 recovery reconciliation and session-safety checkpoint — 2026-08-14

## Disposition

This checkpoint reconciles the completed D5 review and its operator save into
the authoritative Argos continuation chain after text-only recovery from the
quarantined Codex task.

Current phase: `FRONT_METAL_D5_OPERATOR_FEEDBACK_COMMITTED`.

The D5 reviewer is `RELEASED_REVIEW_ONLY`. The latest D5 operator response is
`LOCKED_INPUT` staged guidance. Neither state changes detector masks,
thresholds, training eligibility, XML authority, production authority, or the
frozen frontside chipout branch.

## D5 reviewer authority

Reviewer ID: `FM_D5_CANONICAL_V4_20260813T184500Z`.

Reviewer root:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM_D5_CANONICAL_V4_20260813T184500Z`

Verified artifacts:

- D5 checkpoint SHA-256:
  `110287C912C0F9F013D1E6C56E1E21C18B549D90FA70B0F861FF3004CA78789A`;
- structural-routing result SHA-256:
  `C67FDBCAEFFC67DBEFB458BDA66946D2121E22CDB7109B714B4ACCA0A7A1153D`;
- saved-feedback regression SHA-256:
  `AF4C387DE5F1B0BE6A5B418661F36599FF170F3DE1BB9D2542FEFA23BD45EA58`;
- build result SHA-256:
  `0498A2FB1D84F780815B5ACCCA76568763838F59B7975D1BBE1A055E54E5BE09`;
- presentation audit SHA-256:
  `0AB4A7EF67FC919F20DC5233921A3BB681B516B0FDB9D1FC40AD0171A7230233`;
- review manifest SHA-256:
  `86809FDEE5D59FDC45477B53BE71802A5A33546B0A8FFC46C325CBE95E8F9DCC`.

The governing D5 result remains:

- 69,623 accepted class-facing pixels;
- 2,876 class-specific confirmation pixels;
- 145,047 technical/common-condition hold pixels;
- 33/33 reviewed real-defect strokes retained;
- D4 false strokes exposed to class-facing evidence reduced from 58/58 to
  5/58;
- holder overlap zero;
- structural evidence remains held, never converted to Normal;
- frontside chipout/edge logic unchanged.

## D5 operator save

Latest completed save:

`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260814T002521Z`

Coordinates:

`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260814T002521Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`

- embedded review ID: `FM_D5_CANONICAL_V4_20260813T184500Z`;
- coordinates created UTC: `2026-08-14T00:25:21.043Z`;
- coordinates SHA-256:
  `7E3E586F2CA7611935434932A93F74E5393C35ADD66553FE581A1F64A756D967`;
- 43 reviewed fields in five tile reviews;
- 88 native-coordinate strokes;
- 74 `RECLASSIFY_REAL_DEFECT` strokes;
- 14 `ADD_MISSED_DEFECT` strokes;
- 62 Scratch and 26 Particle classifications;
- zero full-wafer feedback strokes in this save.

`SAVE_COMPLETE.json` was written at `2026-08-14T00:25:33.246Z`; its SHA-256
is `378460CDBF689D06CCDD4F7F85A1448208073E11876E1EB208E21455F1340161`.
It records 28 marked local PNGs, zero full-wafer marked PNGs, and zero marked
image errors.

An earlier D5 save at `2026-08-14T00:20:08.715Z` is preserved separately.
After normalizing only `createdUtc`, its coordinates payload is identical to
the latest save. The latest completed save above is the continuation input.

## D4 separation

D4 remains a distinct locked diagnostic feedback input:

`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260813T222605Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`

- embedded review ID: `FM_D4_CANONICAL_V3_20260813T223500Z`;
- SHA-256:
  `FD714DA87C377AD0AEFA5A646174BA54EF57B15B87205CF224F084B8A79D4476`;
- 91 strokes: 58 false removals, 30 reclassifications, and three misses.

D4 did not overwrite D5. No D4 payload may be substituted for the D5 save.

## Save-root recovery finding

The earlier `no save` report was incorrect. The completed D5 save existed in
the workspace-level `human_feedback` root. Verification searched the empty
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/human_feedback` root after the reviewer
service had been restarted with a different `RootDirectory`.

Future verification must record and compare the absolute server root, exact
manifest review ID, returned save folder, coordinates review ID, completion
marker, and hashes. The operator must never be asked to repeat review until all
recorded candidate roots have been checked.

## Codex session safety

`work/ARGOS_CODEX_SESSION_SAFETY.md` is now the approved baseline. The
metadata-only guard is
`utilities/Confirm-ArgosCodexSessionSafety.ps1`.

Mandatory gates are 128 MiB checkpoint, 256 MiB fresh-task rotation, and
512 MiB hard stop. Both image-inflated task IDs are quarantined and explicitly
refused. The standalone automation ID is
`argos-codex-session-size-guard`; it runs every 15 minutes and reports only
non-PASS states.

## Next gate

Use the latest D5 operator response only as staged classification guidance for
a deterministic review-only categorization correction. Preserve the
operator's written appearance guidance. The next canonical reviewer must add
separate accepted and held heatmap layers to the full-wafer view without
changing the locked canonical interaction contract. Uncertain cases remain
class-specific holds. Do not train, write XML, package, run a full lot, change
frontside chipout, or promote D5 feedback automatically.
