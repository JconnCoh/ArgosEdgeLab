# Front-metal D5 structural-hold routing checkpoint — 2026-08-13

## State

`PASS_FRONT_METAL_D5_CANONICAL_REVIEW_V4` — review only.

The partial D4 operator response is sufficient for this correction. It contains
25 reviewed fields and 91 native-coordinate strokes: 58 false-detection
removals, 30 real-defect reclassifications, and 3 missed-defect strokes. The
operator does not need to finish or repeat the D4 queue.

## Observed structural failures

The D4 class-facing queue exposed three related structural false-evidence
forms:

- ordinary grid/street response;
- inverted die-fill response, in which die interiors were selected instead of
  the complementary grid;
- small repeated responses in null-die structures.

These signals are not declared Normal. D5 isolates them as explicit technical
or common-condition holds pending alignment/common-condition or approved
golden-sentinel resolution.

## D5 decision contract

- The accepted physical-damage core is unchanged at 69,623 native pixels.
- The direct-strong scratch/physical-damage branch is unchanged.
- Raw-connected class-facing confirmation requires independent target-excluded
  peer support: target-excluded second-channel score at least 16 on at least
  0.94 of the component pixels.
- Crop-seam evidence is routed to `HOLD_CROP_SEAM_ALIGNMENT`.
- Edge-common evidence is routed to
  `HOLD_FRONT_METAL_EDGE_COMMON_CONDITION_PENDING_GOLDEN_SENTINEL`.
- No component is suppressed by pitch, direction, recurrence, component size,
  or a generic grid rule.
- No structural evidence is converted to Normal.
- Frontside chipout/edge inspection is unchanged.
- Raw BF/DF remain the size authority; scoring remains native 1:1.

## Saved-feedback regression

Exact native-coordinate union audit:

- reviewed real-defect strokes retained by class-facing evidence: 33/33;
- reviewed false strokes touching D4 class-facing evidence: 58/58;
- reviewed false strokes touching D5 class-facing evidence: 5/58.

Four of the five residual false touches intersect components that also contain
operator-marked real physical damage. Whole-component deletion would erase
real defects, so those mixed components remain visible for bounded trimming or
review. This is not permission to accept the false halo as size truth.

## D5 totals

- accepted class-facing pixels: 69,623;
- class-specific confirmation pixels: 2,876;
- technical/common-condition hold pixels: 145,047;
- all decision evidence: 217,546 pixels;
- accepted components: 197;
- class-specific confirmation components: 111;
- technical/common-condition hold components: 601;
- holder overlap: zero.

## Canonical reviewer

Output:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM_D5_CANONICAL_V4_20260813T184500Z`

The output reuses the locked BowComp highlighter interface. The derived
`index.html`, `app.js`, and `styles.css` hashes match the approved derived
reviewer inputs, all required controls/actions are present, and `styles.css`
matches the canonical BowComp source byte-for-byte. All 11 tile asset contracts
resolve.

Primary audit artifacts:

- `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM_D5_STRUCTURAL_HOLD_ROUTING_V1_20260814T000000Z/RUN_RESULT.json`
- `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM_D5_SAVED_FEEDBACK_REGRESSION_V1_20260814/AUDIT_RESULT.json`
- `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM_D5_CANONICAL_V4_20260813T184500Z/PRESENTATION_AUDIT_V4.json`
- `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM_D5_CANONICAL_V4_20260813T184500Z/BUILD_RESULT_V4.json`

## Authority

D5 remains review-only, training-ineligible, XML-ineligible, and
production-ineligible. Operator strokes remain staged guidance and were not
automatically promoted to detector truth.
