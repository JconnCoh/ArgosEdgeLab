# POST2 patterned-front recurrence/native gate checkpoint — 2026-08-09

## State

`HOLD_REVIEW_ONLY_NATIVE_GATE_REGRESSION_AFTER_LOCALIZATION_STITCH_CORRECTION`

This checkpoint is review-only. It is not training, XML, production, recipe,
deployment, or automatic-reject authority.

## V1 localization retirement

Human review exposed hard 256-overview-pixel cell boundaries and local
chevron/grid shifts in the V1 residual display. The V1 implementation chose
one integer translation independently in each cell and applied it without
interpolation or feathering. Those discontinuities are processing artifacts,
not wafer defects.

All V1 recurrence and native-gate counts below are therefore retained only as
diagnostic history. They cannot support deployment, acceptance, production,
training, XML, or automatic-reject authority. The original native-resolution
source images and native detector masks were not changed by this finding; the
invalidated layer is the overview localization corridor derived from the
stitched residual.

A replacement must use a continuous shift field, pass an explicit cell-boundary
energy audit, preserve the frozen operator-feedback coverage, and rerun native
scoring before this checkpoint can return to PASS.

## Continuous-field correction

The overview localization implementation was replaced with a continuous
bilinearly interpolated displacement field. The replacement does not select or
apply independent hard translations at 256-pixel cell boundaries. Raw shift
nodes remain locally measured, but every output pixel samples one continuous
field. There is no cell-edge overwrite, mosaic seam, or feathered detector
truth: this layer remains display/localization evidence only.

The explicit Slot02 cell-boundary audit is:

`work/FP2_RAW_CONTINUOUS_FIELD_BOUNDARY_AUDIT_SLOT02_V3_20260809T080500Z/CELL_BOUNDARY_AUDIT_RESULT.json`

- retired stitched V1 boundary/control ratio: `2.0758618563`;
- raw continuous-field V3 boundary/control ratio: `0.9663077381`;
- ratio reduction: `53.4502869%`;
- state: `PASS_CONTINUOUS_FIELD_CELL_BOUNDARY_AUDIT_REVIEW_ONLY`.

The corrected boundary lines are therefore no stronger than the same metric
at adjacent non-boundary controls. The simple whole-row reversal hypothesis
was also tested independently and rejected: it weakened marked positive
coverage without clearing the exposed false controls. It is not retained as a
fallback and must not be promoted.

The corrected full-family overview recurrence output is:

`work/FP2_PATTERN_RECURRENCE_RAW_CONTINUOUS_MAX0_MARKED_V3_20260809T083000Z`

All four operator-marked wafers completed. The corrected overview recurrence
audit retained meaningful support for 38/42 marked Scratch strokes and 8/9
marked Residue strokes, with meaningful exposure on 1/55 false-control
strokes. These are localization counts only, not accepted defect pixels.

The bounded original-native-pixel radius-2 gate completed at scaleX=1 and
scaleY=1 under:

`work/FP2_PATTERN_GUIDED_NATIVE_RAW_CONTINUOUS_MAX0_R2_MARKED_V3_20260809T084000Z`

Its feedback audit retained 35/42 Scratch brush corridors (39/42 under the
fixed registration margin), 8/9 Residue corridors, and exposed 4/55 false
brush corridors (5/55 under the fixed registration margin). This improves
false-control exposure relative to the retired stitched V1, but it remains a
HOLD because one marked Scratch was lost and the false controls are not yet
cleared by the native evidence gate.

No corrected V3 mask is production, XML, training, recipe, or autonomous
reject authority. No JBOD package was created.

## Frozen operator feedback

- Response: `C:\Users\joshua.conn\Downloads\FRONTSIDE_POST2_ENHANCED_ZOOM_REVIEW_RESPONSE.json`
- SHA-256: `193D4C7D03FA8A245659C6959E706C43B50E15383E575408FED2D27F073125AB`
- Four wafers, 106 strokes:
  - Slot02: 17 missed Scratch, 15 false/overkill;
  - Slot03: 1 missed Scratch;
  - Slot18: 24 missed Scratch, 13 false/overkill;
  - Slot25: 9 missed Residue, 27 false/overkill.

Feedback selected bounded evaluation locations and supplied the audit labels.
It was not detector input and did not create detector pixels.

## Selected method

1. Form a target-excluded peer reference from the other ten accepted-family
   wafers.
2. At overview scale only, smooth with radius 3, locally register with
   256-pixel cells and a +/-4-pixel search, and remove a radius-31 illumination
   field.
3. Retain target residual locations supported by zero recurring peers at a
   robust-score threshold of 2.0 with a two-overview-pixel peer neighborhood.
4. Return to the original 14411 x 10995 lossless source geometry.
5. Retain only original native observed detector pixels that fall in the
   strict overview corridor, remain physically eligible, and do not overlap
   the scribe exclusion.

The overview never supplies reject pixels. Every retained output pixel is an
original native detector observation at scaleX=1 and scaleY=1.

## Marked-wafers audit

Strict zero-peer recurrence at overview scale:

- missed Scratch: 41/42 strokes had score >=2; 40/42 had meaningful area;
- missed Residue: 8/9 strokes had score >=2 and meaningful area;
- false/overkill: 2/55 strokes had meaningful area.

Native observed-pixel gate, radius 2:

- missed Scratch: 36/42 brush overlap, 40/42 within the fixed 150-native-pixel
  screenshot-registration audit margin;
- missed Residue: 8/9 brush overlap and 8/9 registration support;
- false/overkill: 9/55 brush overlap and 10/55 registration support.

The complete four-wafer run scored 120 native tiles and retained 26,377
native observed pixels.

## Rejected alternatives

- Corridor radius 3 retained no additional marked Scratch or Residue strokes
  and increased false registration exposure from 10 to 12. It is rejected.
- Allowing one recurring peer retained no additional marked Scratch strokes
  and doubled false brush exposure from 9 to 18. It is rejected as the
  Scratch route. It is not silently retained as a fallback.

## Eleven-wafer regression

All 11 accepted-family wafers completed all 330 native tiles. The run retained
63,974 native observed pixels in total:

| Slot | Retained native pixels |
|---|---:|
| Slot02 | 6,681 |
| Slot03 | 10,301 |
| Slot13 | 230 |
| Slot14 | 0 |
| Slot16 | 35,007 |
| Slot18 | 5,711 |
| Slot19 | 1,159 |
| Slot22 | 169 |
| Slot23 | 951 |
| Slot24 | 81 |
| Slot25 | 3,684 |

The family median is 1,159 pixels with a median absolute deviation of 1,159.
Slot16 is a strong population outlier (robust z approximately 19.7), and
Slot03 is secondary (approximately 5.32). These are review holds requiring
visual assessment; they are not automatic defects or grounds for deleting a
wafer from the family.

The bounded visual audit of only these two statistical outliers found that
their retained evidence is predominantly perimeter-localized. Slot16 carries
the strongest response around the operator-declared real black-ring condition;
Slot03 has a smaller perimeter-localized response. Neither overview shows an
unbounded explosion across the patterned die surface. This is encouraging
but remains review evidence, not class or reject authority.

## Common-mode defect protection

The operator confirmed that the black perimeter ring is real manufacturing
defect evidence. Preserve it as:

`CONFIRM_RESIDUE_OR_STAIN_COMMON_PERIMETER_RING`

It must not be suppressed as normal edge texture and must not be called
chipout or bevel damage. A target-excluded lot composite can absorb a defect
shared by all peers, so this condition requires the three independent layers
defined in `PATTERNED_FRONT_COMMON_MODE_DEFECT_SENTINEL_METHOD.md`:

1. same-lot target-excluded comparison;
2. registered within-wafer equivalent die/field population comparison;
3. approved product/step golden comparison across prior accepted lots.

## Source hashes

- `FrontsidePatternOverviewResidualV1.cs` — `04E822461FD2BC6BC1B6A2C0317A944CFB9CFF8C8915253B5CE63651AF617EAF`
- `FrontsidePatternRecurrenceGateV1.cs` — `E6989F4621FB2584133BC0F930EF7577E24504FB2A01AC6E50A8949DD7AC92C1`
- `Post2OverviewGuidedNativeEvidenceV1.cs` — `1763B78DFE29B536A1011AAD4075E03B2803FF855AD2577F6F4E991A7892247B`
- `Run-Post2PatternRecurrenceGateV1.ps1` — `50C2E0376A909F17132D2EDD10141BFAE3187823A3D2914E76CFC9EA70B7597C`
- `Run-Post2FullTargetOverviewGuidedNativeEvidenceV1.ps1` — `24193F7EB93B82F22D9D1222F61F70F36A80C401E09665D27D61165EBFEA9CC8`
- `Build-Post2PatternRecurrenceNativeReviewV1.ps1` — `DEAFA3069D76B0EB485ECA8EC8A706B8730D15E2059E8814C4224558B27D4616`
- qualified offsets CSV — `59EECA3304015DA46ECD05820AE8AB4ACB5D71C21182DF24BF54821E52451637`

## Remaining gate

Do not deploy this method to the JBOD yet. Review the all-family comparison,
resolve the Slot16/Slot03 population outliers, and implement/qualify the
within-wafer die-grid population and approved-golden common-condition gates.

The executable fail-closed guard is recorded at
`work/FP2_PATTERN_COMMON_MODE_GUARD_V1_20260809T040000Z/COMMON_MODE_GUARD_RESULT.json`.
It enables the completed target-excluded/native gate, holds the unqualified
within-wafer die-population gate, holds the missing approved product/step
golden, and preserves the black perimeter ring as a class-specific
Residue-or-Stain confirmation.

## Front Metal electroplating family clarification

The operator identified the material under this checkpoint as **Front Metal
electroplating**. `POST2` is a development label and is not a safe production
method selector. No JBOD package may select this detector from a recipe-folder
name, image color, or visual similarity alone.

The future fail-closed selector is
`FRONTSIDE_FRONT_METAL_ELECTROPLATING`. It requires all of the following:

1. an exact confirmed 12-character scribe for the acquisition;
2. a read-only Insite lineage lookup evaluated at the acquisition timestamp;
3. an approved product/process-block/step/tool rule that identifies Front
   Metal electroplating; and
4. explicit frontside acquisition handedness.

Missing, ambiguous, conflicting, or not-yet-approved lineage remains
`HOLD_FRONTSIDE_METHOD_UNQUALIFIED`. Appearance may raise a mismatch hold but
must not grant the method.

The operator clarified the Front Metal taxonomy. The physical/model class is
`FrontMetalPhysicalDamage`; it may have linear, compact, round, stamping-like,
or unknown morphology. Confirmed events in that family map downstream to the
operator `Scratch` bin. This mapping must not redefine the general Scratch
class or teach a generic model that scratches are compact or round. The
automated method must keep physical-damage presence, morphology, and bin
mapping separate. Repeating die/metal pattern brightness is still nuisance
evidence and must be distinguished with target-excluded BF/DF/native support.
Ambiguous native close-ups may be returned for operator categorization, but
the resulting labels remain review-only references; training, XML, production
authority, and JBOD deployment remain disabled.
