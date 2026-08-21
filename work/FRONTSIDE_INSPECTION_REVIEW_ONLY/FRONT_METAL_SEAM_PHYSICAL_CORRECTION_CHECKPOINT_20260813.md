# Front-metal seam and physical-eligibility correction checkpoint — 2026-08-13

## State

`PASS_FRONT_METAL_SEAM_PHYSICAL_CORRECTED_CANONICAL_REVIEW_V2`

This is a review-only presentation and mask-eligibility correction for the
front-metal local-composite study. It is not training, XML, packaging, or
production authority. Detector thresholds were not changed, the frontside
chipout engine was not changed, source BF/DF images were not modified, and
human feedback was not applied automatically as detector truth.

## Frozen operator feedback

- Coordinates: `human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260813T131750Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`
- Coordinates SHA-256: `3D13EFC12D255076502A35F6AD9834F3F74205C62088C8A2FE3045CF1120AE68`
- Text response: `human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260813T131750Z/ARGOS_CANONICAL_DEFECT_REVIEW_RESPONSE.txt`
- Text SHA-256: `D86E496BA2DE5E4290DEAA7ECFA5A2E4E3D75E2F3A221D97239ED550B81BF1E0`
- Saved strokes: 334 total — 37 missed defects, 148 real detections needing
  class confirmation, and 149 false detections.
- Saved tile comments are preserved. The prior reviewer stored one comment per
  tile, which could make a comment appear to carry between review fields in the
  same tile. The corrected reviewer keys comments by exact native review field.

The three explicit grid comments are on `T02_R00C01`, `T03_R00C02`, and
`T07_R01C01`. The largest remaining miss groups are `T08_R01C02` (11),
`T17_R03C01` (9), and `T21_R04C00` (8). T21 is an explicit reference-coverage
hold; its missing heatmap is not interpreted as Normal or as a detector pass.

## Root-cause separation

1. Crop-edge grid: overlapping crops could paint the same source evidence more
   than once. A deterministic source-coordinate owner is now assigned before
   accepted-mask presentation. Non-owner copies are removed from the accepted
   layer. Ambiguous uncorroborated crop-edge pixels remain confirmation holds.
2. Holder/outside detections: the prior local holder alpha did not cover the
   physical hardware seen in the saved false marks. A BF/DF physical-wafer
   support mask now excludes outside-wafer and holder pixels before acceptance.
3. Halos: the accepted footprint is deliberately conservative. A six-pixel
   shrink trial lost two additional human-positive strokes without clearing any
   additional human-false stroke, and the alternate local raw threshold test
   provided no improvement. Both trials were rejected. Remaining halo pixels
   must be reviewed locally rather than removed by a blind erosion or grid veto.
4. Comments: exact field-scoped comment keys replace the prior tile-scoped key.

No grid pitch, direction, recurrence, or component-size veto was introduced.
No target image was warped or resampled. Raw BF/DF remains the sizing authority;
composite score images remain display-only localization aids.

## Corrected artifacts

- Reviewer: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FRONT_METAL_SEAM_PHYSICAL_CORRECTED_CANONICAL_REVIEW_V2_1_20260813T161500Z`
- Launcher: `START_FRONT_METAL_LOCAL_COMPOSITE_REVIEW.cmd`
- Manifest SHA-256: `90A7F636BDB49A4DEBED7480979C7DE1414FE68204E2DD978A5B64525FEF014D`
- App SHA-256: `9B87C8173E5A609714BE15C27EF90564EC81BF1CA2B88EFD3F0FFCA481E44D43`
- Styles SHA-256: `F0D1C31FE2DA28D00857486C9678A642B7AD1C837BB9249A1FB50BAB9036777E`
- Corrected accepted layer: 119,460 native pixels in 231 components.
- Confirmation layer: 348 total components, including bounded weak and
  crop-seam holds. Confirmation pixels are not accepted defect truth.
- Corrected presentation audit: `PRESENTATION_AUDIT_V2.json`

The reviewer was built from the locked BowComp canonical application and its
CSS remains byte-for-byte canonical. A live local-server smoke test verified
the full-wafer view, all four 2400 x 2000 native panels, default accepted-only
visibility, exact-field comments, clean labels, and zero browser console errors.

## Native global-coordinate regression

- Audit: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FRONT_METAL_GLOBAL_SEAM_OWNERSHIP_AUDIT_V1_20260813/AUDIT_RESULT.json`
- Audit SHA-256: `C0F595E16B8BFAAE0C4D5876EAEC0B07E3E588056D40E9CD19FAB14DDEFE9C34`
- State: `PASS_FRONT_METAL_GLOBAL_SEAM_OWNERSHIP_AUDIT_REVIEW_ONLY`
- Qualified tiles: 10; T21 remains a reference-coverage hold.
- Accepted tile pixels: 119,460.
- Unique accepted native source coordinates: 119,460.
- Duplicate accepted source coordinates across crops: 0.
- Accepted/confirmation overlap in source coordinates: 0.
- Accepted pixels inside physical exclusion: 0.
- Accepted pixels outside physical-wafer eligibility: 0.
- Scale X/Y: 1/1.

## Required bounded re-review

Do not repeat the full operator review. Use the corrected reviewer with only
the accepted layer visible by default and verify:

1. the saved crop-border grid locations in T02, T03, and T07;
2. the physical edge/holder locations, especially T16, T27, and T29;
3. representative retained small particles and scratches in T08 and T17;
4. T21 remains visibly labeled as a reference-coverage hold rather than clean.

If a remaining accepted halo is visibly false, mark only that local footprint.
The 37 saved misses remain staged human guidance; this correction does not
silently paint them into accepted detector truth.

