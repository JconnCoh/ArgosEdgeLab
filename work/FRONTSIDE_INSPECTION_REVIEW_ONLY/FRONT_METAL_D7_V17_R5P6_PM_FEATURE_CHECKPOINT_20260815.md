# Front-metal D7 V17 R5P6 PM-feature location checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P6`

Disposition: `DIAGNOSTIC_ONLY`

## Outcome

A fresh, bounded, file-backed visual test was built directly from the locked
Slot02 BF/DF overview and native tile sources. It does not descend from the
withdrawn R5P5 sheet.

The observed product repeat is rotated `44.70 degrees` clockwise in the Argos
image coordinate frame. The combined BF/DF PM-period edge-correlation score is
`0.8123669543`; the best score outside one degree is `0.5555148215`. The new
sheet therefore applies a `-44.70 degree` display-only straightening before it
draws any map-derived PM-area nomination.

The normalized map pair is used only as coarse evidence that the relevant PM
structure should occur in each bounded area. Bin 34 and Bin 36 are not drawn,
named as fiducials, or used as old-product feature identity. The operator's
unannotated reference image is hash-locked but its pixels are not used as a
matching template; only the stated geometry is carried forward: repeated
lollipop array, upper bar, lower bar, and consistent local die context.

The sheet shows:

- raw BF and DF overviews with the measured product axes and no map overlay;
- separately labeled display-only straightened BF and DF overviews with 32
  yellow PM-area nominations;
- four straightened `900 x 650` native-pixel BF/DF crop pairs nearest the
  existing T17 operator feature, at sites S26, S25, S31, and S20;
- cyan emphasis only on those four nominated areas; and
- no automatic feature match, translation, or die-phase selection.

The closest candidate is S26, centered at native source coordinate
`(6335.252, 7424.433)`. It is `392.343` native pixels from the center of the
existing T17 operator feature. The next step is operator visual feedback on
whether the repeated lollipop array and both bars actually appear in the
yellow area in one or more crops. If not, this test stops; it must not widen
into an adjacent-PM search.

## Artifacts

- Sheet:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P6/PM_FEATURE_LOCATION.png`
  - SHA-256:
    `616CB3C96F03798FFC18BEE44BB0A357CB5095090593D90ADCC4A7CCE2E69299`
  - dimensions: `2160 x 4240`
- Audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P6/AUDIT.json`
  - SHA-256:
    `0B0DAF35A4EE0520DB4E66311B01A1CC6298F623E4A358FDC23F5A868D09BB12`
- Input manifest:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P6_INPUT.json`
  - SHA-256:
    `575F5091A9911EA0EA839B617C83266D2F5DBEA0AF7408DC5AD95843A94FDF40`
- Builder source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17PmFeatureAuditV1.cs`
  - SHA-256:
    `10BD45161C24A55105A860F4DE5228097039BE9BE25B4390F48482DBC578ABD6`
- Builder executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17PmFeatureAuditV1.exe`
  - SHA-256:
    `2493107C699419288BEC80088BF4C59F4115DE557148474DA3D64CF12FC1EC23`

The non-mutating preflight passed for 32 nominated PM areas and all 30 native
tiles. The sheet hash reverified after the write. The locked BF and DF overview
hashes remain respectively
`9EEF4607834767E9CC77A7D036BE034FC57E09EF779C9647C9F0D286774FABE0`
and
`65FCF4C4BC40FC8E79D030843EF5B87EE6BFDA85E8D84DC9CB6CE04C91002F63`.

## Preserved authority

- R5P5 remains `WITHDRAWN` and is not a revision parent.
- R5P6 is visual diagnostic evidence only.
- T17 remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`.
- No reference composite, detector response, mask, threshold, classifier, or
  review disposition changed.
- Deferred stroke 278 remains unevaluated.
- V16 remains the released review-only reviewer.
- V17 remains `PENDING_GATE`; no V17 reviewer is presented.
- XML and production routing remain disabled.
- The strict chipout sibling remains unchanged.

