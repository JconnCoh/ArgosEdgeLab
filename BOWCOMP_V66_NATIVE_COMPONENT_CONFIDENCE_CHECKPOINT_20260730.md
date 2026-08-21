# BowComp V6.6 native-component confidence checkpoint

Date: 2026-07-30  
Domain: `BOWCOMP_BACKSIDE_ONLY`  
State: review-only confidence checkpoint

## Outcome

The saved V6.5 annotation response was sufficient to correct and validate the
known BowComp scratch-visibility failures without asking the operator to
review the same cards again.

The corrected exact freehand-path audit produced:

- 12/12 `MISS` drawings with directly observed native-pixel anomaly evidence;
- 11/12 `MISS` drawings with accepted Scratch pixels or a class-specific
  Scratch confirmation;
- 4/12 `MISS` drawings with accepted Scratch pixels;
- 6/6 `FALSE` drawings with zero accepted Scratch pixels;
- 6/6 `FALSE` drawings with zero class-specific Scratch confirmations.

The remaining one of twelve miss drawings is not silent. Its marked path has
81 directly observed local-contrast anomaly pixels. Adjacent directly
connected fragments of the visible scratch receive `CONFIRM_SCRATCH`, but
the exact approximate freehand stroke does not overlap those component
pixels. Lowering the component gate further re-admits the saved nitride
texture false controls. It therefore remains a fail-closed noticed/coverage
signal rather than invented Scratch geometry or Normal truth.

Pink markup remains approximate review guidance. It was not converted into
pixel-exact detector truth, training truth, or production geometry.

## Corrections

### Exact annotation audit

`work/BOWCOMP_REVIEW_ONLY/audit_bowcomp_annotation_mask_coverage.ps1`
now audits the saved freehand points rather than only their bounding boxes:

- an open stroke is rendered as its exact brush corridor;
- a closed outline includes its enclosed review region;
- accepted, confirmation, holder, blue-nuisance, eligibility, boundary, and
  class-neutral noticed masks are counted independently.

This removed bounding-box contamination from the saved-response audit.

### Component-local Scratch confirmation

The native BF local-contrast path now emits a class-specific Scratch
confirmation only through one of three component-local evidence routes:

1. compact independent DF support;
2. a longer native-BF component that departs from the wafer tangent; or
3. a compact, substantially darker native-BF component with stronger radial
   departure.

The rule does not merge components, bridge gaps, infer a complete line, use
nearest-neighbor grouping, or create a broad blue/edge exclusion.

### Retired weak-texture confirmation

The old weak native-linear branch emitted `CONFIRM_SCRATCH` even when its
independent line evidence failed. The saved false annotations exposed this
as nitride texture. That branch is now
`SUPPRESS_WEAK_NATIVE_LINEAR_TEXTURE`; independently supported native-linear
Scratch rejects remain unchanged.

### Holder qualification

The local holder mask is qualified by its own connected component evidence.
It retains the physical near-black holder body and immediate fragments while
preventing a connected blue-film transition from inheriting holder status.
The holder exclusion is still local and precedes candidate formation in all
surface engines.

## Frozen targeted gate

Targeted run:

`work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_V66_V48_RETIRE_WEAK_NATIVE_TEXTURE_CONFIRM_20260731T060000Z`

Exact saved-annotation audit:

`work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_V66_V48_EXACT_ANNOTATION_REGION_AUDIT_20260731T064500Z`

The gate includes saved positive evidence, the saved false nitride-texture
markings, three holder controls, and the operator-declared normal rounded
blue feature. Accepted Scratch pixel counts in the positive/control tiles
were unchanged from V6.6 V47. Holder controls and the rounded feature
retained zero accepted Scratch pixels.

## Six-wafer native reinspection

Status directory:

`work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_V66_V49_SIX_WAFER_NATIVE_REINSPECTION_20260731T073000Z`

All six approved physical wafers completed:

| Identity | Source/scored dimensions | Tiles | Components | Automatic defect presence | Scratch confirmations | Holder overlap |
|---|---:|---:|---:|---:|---:|---:|
| `62624_803_SLOT16` | 14409 x 10994 | 30 | 11,931 | 9,262 | 2,669 | 0 |
| `62624_803_SLOT18` | 14409 x 10994 | 30 | 10,618 | 7,770 | 2,848 | 0 |
| `62624_803_SLOT20` | 14409 x 10994 | 30 | 9,944 | 7,095 | 2,849 | 0 |
| `62624_869_SLOT16` | 14411 x 10995 | 30 | 11,060 | 7,362 | 3,698 | 0 |
| `62624_869_SLOT18` | 14411 x 10995 | 30 | 12,806 | 8,982 | 3,824 | 0 |
| `62624_869_SLOT20` | 14411 x 10995 | 30 | 14,588 | 10,409 | 4,179 | 0 |
| **Total** | native | **180** | **70,947** | **50,880** | **20,067** | **0** |

Every wafer reports
`PASS_WITH_DEFECT_PRESENCE_CONFIRMATIONS`. This is an execution and
fail-closed integrity result, not autonomous production authority.

Across the run there are 22,096 Scratch components:

- 2,029 are review-only automatic Scratch defect-presence components;
- 20,067 are class-specific Scratch or Scratch/Residue confirmation holds.

There are also 22,922 accepted defect-presence components whose specific
surface subtype remains low confidence. These are defects, not Normal rows;
their subtype uncertainty must not be summarized as an unqualified automatic
classification pass.

## Deterministic transfer check

Eight frozen targeted tiles were compared with their corresponding tiles in
the complete six-wafer run. All 56 compared artifacts matched byte-for-byte:

- BF raw;
- DF raw;
- accepted Scratch alpha;
- confirmation alpha;
- local-contrast noticed-anomaly alpha;
- local holder-exclusion alpha;
- blue-nuisance alpha.

This verifies that the bounded V48 gate transferred unchanged into the V49
six-wafer execution.

## Input and safety contracts

Every wafer manifest records:

- lossless BMP BF/DF source paths and SHA-256 hashes;
- scored dimensions equal to the actual source dimensions;
- `detectorScaleX=1` and `detectorScaleY=1`;
- `detectorResampling=false`;
- `RG_AVERAGE` BowComp detector evidence;
- 30 native scoring tiles;
- zero zero-byte run artifacts;
- zero accepted holder-overlap pixels;
- no Bare calibration consumption.

BowComp edge, notch, microdamage, and bevel remain:

`INSPECTION_HOLD_BOWCOMP_GEOMETRY_NOT_QUALIFIED`

No Bare geometry tolerance was loosened and no BowComp chipout, microdamage,
notch, or bevel authority was claimed.

## Authority

All V6.6/V49 artifacts remain:

- review-only;
- training-ineligible;
- XML-geometry-ineligible;
- production-ineligible;
- non-full-lot;
- unpackaged;
- isolated from Bare calibration and truth.

No model was trained, no production XML was written, no package was created,
and no production or full-lot workflow was run.

