# BowComp V6.5 defect-presence confidence checkpoint

Date: 2026-07-29  
Domain: `BOWCOMP_BACKSIDE_ONLY`  
State: review-only confidence checkpoint

## Outcome

The six approved BowComp wafers completed a fresh native-pixel surface
reinspection with the V6.5 bounded line-presence correction.

For the supplied human-marked scratch/defect evidence, the inspection now has
high confidence that fail-worthy pixels are noticed:

- 20 of 22 registered pink regions contain defect evidence in the exact
  projected screenshot box.
- 22 of 22 contain defect evidence within a fixed 150-source-pixel audit
  margin.
- The two exact-box exceptions are the already identified unreliable
  screenshot registrations:
  - mark 13, `62624_803_SLOT18/T27_R05C01`, registration score `0.022`;
  - mark 21, `62624_803_SLOT20/T27_R05C01`, registration score `0.3275`.
- Their rendered registration panels point to empty or holder-adjacent
  locations rather than the visible defects marked by the operator. They are
  not evidence of a new detector escape.

The 150-pixel margin is an audit tolerance for uncertain screenshot
registration. It is not an algorithmic grouping distance, contour expansion,
training label, or production geometry.

This establishes defect-presence coverage for the exposed six-wafer evidence
set. It does not claim that every future defect pixel will be autonomously
classified, and it is not production validation.

## Six-wafer native run

Status directory:

`work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_V65_SIX_WAFER_NATIVE_REINSPECTION_20260729T235000Z`

All six identities completed with
`PASS_WITH_DEFECT_PRESENCE_CONFIRMATIONS`:

| Identity | Source/scored dimensions | Tiles | Components | Automatic defect presence | Confirmation holds | Holder overlap |
|---|---:|---:|---:|---:|---:|---:|
| `62624_803_SLOT16` | 14409 x 10994 | 30 | 11,234 | 8,977 | 2,257 | 0 |
| `62624_803_SLOT18` | 14409 x 10994 | 30 | 9,488 | 7,487 | 2,001 | 0 |
| `62624_803_SLOT20` | 14409 x 10994 | 30 | 8,655 | 6,910 | 1,745 | 0 |
| `62624_869_SLOT16` | 14411 x 10995 | 30 | 8,725 | 7,263 | 1,462 | 0 |
| `62624_869_SLOT18` | 14411 x 10995 | 30 | 10,561 | 8,833 | 1,728 | 0 |
| `62624_869_SLOT20` | 14411 x 10995 | 30 | 12,015 | 10,223 | 1,792 | 0 |
| **Total** | native | **180** | **60,678** | **49,693** | **10,985** | **0** |

Every run records:

- lossless BMP BF/DF source paths and SHA-256 hashes;
- scored dimensions equal to source dimensions;
- `detectorScaleX=1` and `detectorScaleY=1`;
- `detectorResampling=false`;
- `RG_AVERAGE` BowComp detector evidence;
- zero zero-byte output artifacts;
- no Bare calibration consumption.

## Defect-presence dispositions

The V6.5 correction separates defect presence from subtype authority.

Across all six wafers:

- 26,507 components are `REVIEW_ONLY_REJECT`;
- 22,922 components are
  `REVIEW_ONLY_REJECT_CLASS_LOW_CONFIDENCE`;
- 10,985 components are bounded, class-specific confirmation holds.

The main new confirmation dispositions are:

- 5,083 `CONFIRM_SCRATCH_NATIVE_HOUGH_LINEAR_DEFECT`;
- 2,976 `CONFIRM_SCRATCH_NATIVE_LINEAR_DEFECT`;
- 2,924 `CONFIRM_SCRATCH_OR_RESIDUE_LINEAR_DEFECT`;
- 2 `CONFIRM_SCRATCH_BLUE_FEATURE_BOUNDARY`.

A confirmation means the inspection detected fail-worthy line pixels but does
not yet have validated authority to call the event an autonomous Scratch
reject. It is not Normal truth and is not a generic unclassified event.

## Nuisance and positive controls

The frozen control behavior remains bounded:

- `62624_869_SLOT16/T11_R02C00` smooth tangential control:
  `ScratchPixels=0`;
- `62624_869_SLOT20/T02_R00C01` smooth tangential control:
  `ScratchPixels=0`;
- `62624_869_SLOT18/T29_R05C03` pre-existing response:
  `ScratchPixels=695`, unchanged;
- `62624_869_SLOT20/T01_R00C00` rounded blue nuisance:
  `ScratchPixels=0`;
- `62624_869_SLOT16/T06_R01C00` clear positive:
  `ScratchPixels=2030`;
- `62624_869_SLOT20/T22_R04C01` clear positive:
  `ScratchPixels=3295`.

The high-recall confirmation layer can still notice ambiguous line evidence
inside these control tiles. That evidence remains a class-specific hold and
does not convert the blue nuisance into an automatic scratch rejection.

## Algorithm boundary

The new path:

- evaluates native source pixels without resampling;
- uses a native-dimension bounded local-contrast representation without
  overwriting BF/DF;
- aggregates sampled collinear defect-presence pixels;
- splits support at gaps greater than 28 pixels;
- expands only measured support by one normal pixel;
- suppresses a long, no-DF, one-sided, essentially tangential smooth nitride
  transition;
- emits surviving new evidence as a class-specific confirmation hold.

It does not use a global blue mask, broad radial exclusion, nearest-neighbor
chain grouping, inferred scratch continuation, or screenshot markup as
pixel-exact truth.

## Geometry and edge engines

BowComp edge, notch, microdamage, and bevel decisions remain:

`INSPECTION_HOLD_BOWCOMP_GEOMETRY_NOT_QUALIFIED`

The fresh output manifests used older slot-specific hold wording. The runner
has been corrected for future runs to emit the governing hold above. Existing
run artifacts were not edited or overwritten.

This checkpoint therefore validates BowComp surface defect-presence coverage,
not BowComp edge-chipout, edge-microdamage, notch, or bevel authority.

## Audit artifacts

- Exact registered-box audit:
  `work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_V65_FULLRUN_MARKED_EXACT_AUDIT_20260729T202500Z`
- Registration-tolerance audit:
  `work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_V65_FULLRUN_MARKED_EXPANDED_AUDIT_20260729T202600Z`
- Targeted marked-tile gates:
  `BOWCOMP_V65_MARKED_GATE_BATCH_A/B/C/D_20260729T225000Z-230500Z`
- Frozen nuisance/positive controls:
  `BOWCOMP_V65_FROZEN_CONTROL_GATE_A/B_20260729T231000Z-231500Z`
- Mark evidence panels:
  `work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_V65_MARK_LINE_EVIDENCE_REVIEW_20260729T232500Z`

## Authority

All V6.5 artifacts remain:

- review-only;
- training-ineligible;
- XML-geometry-ineligible;
- production-ineligible;
- unpackaged;
- isolated from Bare calibration and truth.

No production XML was written, no model was trained, and no production/full
lot was executed.
