# Front-metal feedback-bounded decision checkpoint — 2026-08-13

## State

This is the append-only review-only checkpoint after consuming the complete
operator response saved at:

`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260813T174347Z`

The operator reported that the result is close, while still exposing:

- some grid/crop-seam halos around real defects;
- some escaped scratches;
- some false surface calls in the edge/holder-adjacent zone.

Those observations remain explicit correction controls. They are not Normal
truth, they do not authorize broad grid suppression, and they do not authorize
an edge-zone inset.

## Frozen operator feedback

- Review ID: `FRONT_METAL_SEAM_PHYSICAL_CORRECTED_CANONICAL_REVIEW_V2_1_20260813T161500Z`
- Reviewed native tiles: 11
- Total saved strokes: 277
- `ADD_MISSED_DEFECT`: 50
  - Scratch: 47
  - Particle: 3
- `REMOVE_FALSE_DETECTION`: 41
- `RECLASSIFY_REAL_DEFECT`: 186
  - Scratch: 91
  - Particle: 82
  - Residue: 13
- Commented tiles: 11/11
- Coordinates JSON SHA-256: `253F660DB3B220A92E583E9CFCF15AD910E87BB51471BCF2F63F8AA78DB73A9C`
- Response text SHA-256: `87A442763B7811D7513931308897081ED7FDE181235DC6CD4F7F22C02A269FE9`

The drawings remain native-coordinate review guidance. They are not automatic
pixel truth, training truth, XML authority, or production authority.

## Bounded detector result

Source:

`analysis/FM_D4_20260813T2350Z/RUN_RESULT.json`

- State: `PASS`
- Accepted automatic review-only core: 197 components / 69,623 px
- Edge-zone surface confirmations: 52 components / 49,837 px
- Crop-seam confirmations: 331 components / 50,627 px
- Raw-connected confirmations: 319 components / 47,211 px
- Direct-strong confirmations: 19 components / 248 px
- Branch-specific confirmation rows: 721 / 147,923 px union
- Connected components in the confirmation union: 709
- Accepted plus confirmation evidence: 217,546 px / 854 connected components
- Accepted and confirmation masks: disjoint
- Confirmation branches: disjoint
- Holder overlap: 0 px

The global detector threshold was not changed. No grid pitch, direction,
recurrence, component-size veto, or blanket edge mask was introduced. The
existing chipout detector and its authority were not changed.

## Feedback coverage audit

Source:

`analysis/FM_D4_FEEDBACK_AUDIT_20260813T2358Z/AUDIT_RESULT.json`

- State: `PASS`
- Accepted evidence intersects 180/236 operator-marked real controls.
- Accepted evidence intersects 5/41 operator-marked false controls.
- Accepted active-pixel fraction: 0.0013186.
- Confirmation evidence intersects 50/236 marked-real controls.
- Confirmation evidence intersects 36/41 marked-false controls.
- Confirmation active-pixel fraction: 0.0028016.
- Accepted-or-confirmation evidence intersects 210/236 marked-real controls.
- Accepted-or-confirmation evidence intersects 41/41 marked-false controls.
- Total evidence active-pixel fraction: 0.0041202.
- Remaining explicit marked-real misses: 26.
- Remaining accepted false-control intersections: 5.

Interpretation:

- The 26 remaining marked-real locations are genuine bounded miss controls.
  They must stay visible for the next correction and must not be inferred into
  complete lines or converted to Normal.
- The 5 accepted false-control intersections require focused correction or
  verification. They must not be removed by a blanket edge, grid, recurrence,
  direction, or size exclusion.
- The other 36 marked-false locations are retained as fail-closed confirmation
  evidence, not automatic defects and not Normal truth.
- The current accepted core is promising but is not autonomous classification
  authority.

## Native-pixel and UI contract

- BF/DF source dimensions: 14,411 x 10,995
- Scored dimensions: 14,411 x 10,995
- `scaleX=1`, `scaleY=1`
- Source images remain lossless and unchanged.
- Enhancements and composite residuals remain display/localization aids only;
  raw BF/DF define physical size.

Canonical reviewer output:

`outputs/review_only/FM_D4_CANONICAL_V3_20260813T223500Z`

- Build state: `PASS_FRONT_METAL_FEEDBACK_BOUNDED_CANONICAL_REVIEW_V3`
- Manifest SHA-256: `7201F172132288514608CE75CE165EEA55878BDBA70A3E3DFA7423EB71CD46E1`
- `index.html` SHA-256: `E62741404A07C949D1ACDCD5D4E721EFCA766A9CCF4893594E4E5554F8492019`
- `app.js` SHA-256: `9B87C8173E5A609714BE15C27EF90564EC81BF1CA2B88EFD3F0FFCA481E44D43`
- Canonical `styles.css` SHA-256:
  `F0D1C31FE2DA28D00857486C9678A642B7AD1C837BB9249A1FB50BAB9036777E`
- Presentation audit SHA-256:
  `24287D61AAC06F7F21CBE72A9E6E96754EDC0E9EA001C26D37713707B7F66FB5`

The local runtime audit loaded all 11 tiles with zero broken images and zero
console errors. The canonical full-wafer/native-tile tabs, zoom/pan, four
highlighter actions, class and false-reason palettes, queue controls, and
native-coordinate capture controls were present.

## Eligibility and next bounded action

This checkpoint remains review-only, training-ineligible, XML-ineligible,
production-ineligible, and unpackaged.

The next detector change is limited to the 26 remaining marked-real miss
controls and the 5 remaining accepted false-control intersections. It must:

1. preserve every already-supported real defect unless directly contradicted;
2. remove crop-grid halos through seam-valid support, not grid-shape rejection;
3. suppress holder/outside-wafer evidence before candidate formation while
   retaining compact real edge defects;
4. recover escaped scratches only from observed raw/composite-supported pixels;
5. preserve the existing chipout branch unchanged; and
6. rerun the full 11-tile native-pixel regression before another operator page
   is presented.

