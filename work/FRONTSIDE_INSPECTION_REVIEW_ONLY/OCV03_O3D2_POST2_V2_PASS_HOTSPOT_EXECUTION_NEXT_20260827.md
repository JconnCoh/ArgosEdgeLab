# OCV-03 O3D2 POST2 V2 pass / signed hotspot execution next — 2026-08-27

## Disposition

`PENDING_GATE`

OCV-03 now has concrete review-only OpenCV edge-and-notch results on the frozen
POST2 development/known-failure cohort. This checkpoint does not activate the
provider, grant rotation or alignment authority, clear any prerequisite, or
authorize XML, training, production scoring, or production routing.

## R6 result

The frozen R6 entrypoint is
`work/PATTERNED_FIDUCIAL_INVENTORY/tools/NativeFrontsideWaferPoseOpenCvV2R6.py`,
SHA-256 `90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30`.
The job is `work/OPENCV_EDGE_NOTCH_O3D2/O3D2_POST2_V2_R6_JOB.json`, SHA-256
`FF0615B4B6EBAF6B513CA6B8585611A1816AA4A3D9DF6D68F9BAEA2176FFE1F6`.
Its exact process completed with exit code zero and state
`COMPLETE_REVIEW_ONLY_DEVELOPMENT`.

All three members returned exactly one BF/DF-supported manufactured-notch
candidate:

| Identity | Review angle | Historical scorer error | Result |
|---|---:|---:|---|
| `62546-481_POST2_SLOT01` | `90.03556734938735` | `0.13556734938731552` degrees | PASS; known chipout not selected |
| `62546-481_POST2_SLOT03` | `90.01343213566035` | `0.463432135660355` degrees | PASS |
| `62546-481_POST2_SLOT17` | `89.68100140621873` | `0.08100140621877472` degrees | PASS |

The frozen output gate is
`work/OPENCV_EDGE_NOTCH_O3D2/O3D2_R6_DETECTOR_OUTPUT_FREEZE.json`, SHA-256
`FC3B23E22855C3473E2AE8DF8F971FCFB7BAA7EB0A608199E421D51CC99162E3`.
The separate post-inference scorer is
`work/OPENCV_EDGE_NOTCH_O3D2/O3D2_R6_POST_INFERENCE_SCORE.json`; all three
members pass the frozen `0.8`-degree historical acceptance limits.

## Edge and algorithm semantics

The detector finds the full 360-degree wafer perimeter independently in BF and
DF before extracting inward deviations. R6 corrected three general measurement
semantics: supported perimeter coverage is not confused with robust-circle
inlier coverage; BF/DF edge-family radial offsets are allowed while centers
remain independently constrained; and BF/DF indentation pairing is assigned
globally by strongest physical interval overlap. The narrower physical channel
response supplies the review-only angle/width while overlapping evidence from
both channels remains mandatory.

The synthetic gate passed an 18-pixel BF/DF edge-family offset, broad-channel
notch response, separate chipout rejection, strongest-overlap assignment, and
a fail-closed missing-perimeter-wedge negative control.

The detector core, R5 base, R6 entrypoint, and R6 job contain zero historical
POST2 notch-angle literals and zero scorer-manifest references. No known notch
location, angle prior, fixed angular window, historical candidate filter, or
historical tie-breaker was available during inference. Historical results were
read only after detector JSON outputs were hash-frozen.

R4 remains frozen diagnostic evidence. R5 is diagnostic-only because its
complete output was written before a 10-second caller boundary expired, but no
terminal process exit was captured; that namespace was not rerun and is not a
publication parent.

## Hotspot source and execution boundary

O3C2 already froze ten stable BF/DF frontside pairs for
`Lot_62629-419_NotchBad_Hotspot`, Slot16-Slot25, with 20 exact source hashes and
aggregate acquisition fingerprint
`EB45C81DB9A4A3B220B0D4161C2F280A7FB402A40296FB94110223692073BAA0`.
The installed JBOD OpenCV runtime remains at `D:\AFCV1\rt`; all heavy runtime
and output work must remain on JBOD `D:`. The engineering laptop has no `F:`
source alias and will not copy or decode the 9.5 GB source cohort locally.

The exact next action is to build, rehearse, sign, commit, push, and publish one
no-retry review-only Project Portal request that stages the frozen R6 engine/job
into a fresh short JBOD `D:` work/output namespace, verifies the installed
runtime and all 20 source hashes before decode, executes the ten pairs without
known-location inputs, returns bounded JSON results, and removes only its exact
temporary source alias. Collect only the exact matching signed terminal
response; gateway acceptance is not execution evidence.

## Additional operator-reported regression candidate

The operator reported a chipout in `Lot_62627-193`, Slot01,
`BrightfieldBacksideWafer`, and made a marked copy. It is recorded at
`work/OPENCV_EDGE_NOTCH_O3D2/O3D2_ADDITIONAL_BACKSIDE_CHIPOUT_REGRESSION_CANDIDATE.json`
as a separate future backside-family `PENDING_GATE`. The marked copy can be a
post-inference scorer/annotation layer only. It cannot enter detector pixels,
thresholds, candidate filtering, or tie-breaking; the clean exact leaf, hash,
and paired-channel availability remain unresolved.

## Unresolved prerequisite sequence and holds

1. Keep the live OpenCV provider disabled and the protected healthy processor
   and every resident task/process untouched.
2. Preserve `SCRIBE_REFERENCE_COVERAGE_HOLD` and the OCV-02 four-of-four
   ambiguity/reference/localization/identity hold.
3. Preserve every map, pose, fiducial-designation, reusable-model,
   alignment-transfer, coverage, and sensitivity prerequisite. R6 grants no
   registration or rotation authority.
4. Keep the fresh independent paired BF/DF validation cohort uninspected until
   a development freeze and explicit validation action.
5. Preserve Slot25 as metadata-disclosed rather than wholly unseen,
   `lot62631586FrontGuiRecovery` as `PENDING_GATE`, O2D14 as withdrawn, and
   DFLY3005 as excluded.
6. Preserve review-only authority with training, XML, production scoring, and
   production routing all false.
