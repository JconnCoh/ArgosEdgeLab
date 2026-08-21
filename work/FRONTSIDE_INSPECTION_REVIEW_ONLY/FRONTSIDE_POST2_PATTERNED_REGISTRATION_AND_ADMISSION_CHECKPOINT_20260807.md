# POST2 frontside patterned registration and appearance admission checkpoint — 2026-08-07

## State

`HOLD_OPERATOR_POST2_APPEARANCE_FAMILY_ADMISSION_REVIEW`

This checkpoint is review-only. It creates no accepted defect mask, detector
truth, golden promotion, XML, or production route.

## Exact physical cohort

- Lot archive: `62546-481_POST2`.
- Sixteen distinct physical frontside BF/DF wafer pairs are available.
- Every source is a native lossless `14411 x 10995` BMP and remains scored at
  `scaleX=1`, `scaleY=1` whenever detector scoring is later authorized.
- Frontside handedness is `flipImageHorizontal=false`.
- Qualified per-wafer center/radius/notch evidence is reused; a fixed notch
  angle or deepest-indentation rule is not introduced.
- Frontside hardware remains behind the wafer and cannot establish a holder
  mask. The scribe remains identity-only and cannot enter a reference or a
  defect mask.

Product/process/step defines a lookup boundary but does not automatically
admit a wafer to a composite. The operator reported that more than one visual
color was intentionally mixed inside this same product/step population.

## Frozen first registration gate

Selection:
`config/POST2_PATTERNED_REGISTRATION_SELECTION_V1.json`

Result:
`../FP2R1_20260807T205543Z/POST2_PATTERNED_REGISTRATION_RESULT.json`

- eight distinct physical wafers, seven target-excluded peers per target;
- global registration candidates: `15/56`;
- multi-region phase candidates: `40/56`;
- reciprocal closure: `28/28`;
- triangle-cycle closure: `36/56`;
- state: `HOLD_POST2_MULTI_REGION_PHASE_NOT_QUALIFIED`.

The failure localized to Slot01 versus all seven peers and the Slot15/Slot16
pair. No composite was created. Those exposed results were not tuned and then
reused as blind transfer evidence.

## Independent second registration gate

The previously unexposed second half was frozen before its output was viewed.

Selection:
`config/POST2_PATTERNED_REGISTRATION_SELECTION_V1B.json`

Result:
`../FP2R1B_20260807T205808Z/POST2_PATTERNED_REGISTRATION_RESULT.json`

- Slots18 through 25, eight distinct physical wafers;
- global registration candidates: `25/56`;
- multi-region phase candidates: `56/56`;
- reciprocal closure: `28/28`;
- triangle-cycle closure: `56/56`;
- state: `HOLD_OPERATOR_POST2_MULTI_REGION_PHASE_REVIEW`.

This independently demonstrates phase-compatible patterned geometry for the
candidate reference family. It does not by itself approve appearance-family
membership or a composite.

## Appearance-family admission review

Result:
`../FP2A1_20260807T210227Z/POST2_APPEARANCE_ADMISSION_RESULT.json`

Gallery:
`../FP2A1_20260807T210227Z/POST2_APPEARANCE_FAMILY_REVIEW.html`

The phase-closed V1B members define a provisional display-only appearance
reference. Interior pose-normalized BF/DF color/luminance features propose:

- 13 candidate-admitted wafers;
- three `HOLD_APPEARANCE_FAMILY_MISMATCH` wafers: Slot01, Slot15, Slot17;
- five bounded human-review cards: the three mismatches plus Slots20 and 23 as
  the closest admitted boundary controls.

Different-family wafers remain inspection targets. They cannot contaminate
the accepted-family reference, and their broad appearance mismatch must not
be painted as thousands of local defects. After operator confirmation, an
excluded family may form its own target-excluded reference only if it has
sufficient independent compatible peers; otherwise it remains an explicit
appearance-family hold.

## Next gate

Import the five-card operator response. Only an operator-confirmed admitted
family may proceed to a target-excluded patterned composite diagnostic. The
composite must be compared with a separately approved cross-lot golden before
promotion; no such golden is approved yet.
