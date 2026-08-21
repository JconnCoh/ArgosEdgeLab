# Front-metal D7 V17 R5P24 zero-unassigned-pixel requirement checkpoint

Date: 2026-08-17

Revision: `FM7V17R5P24_ZERO_UNASSIGNED_PIXEL_REQUIREMENT`

Parent: `FM7V17R5P23_RESULT`

Disposition: `LOCKED_INPUT`

## Operator requirement

The operator requires every valid native target BF and DF pixel to receive an
explicit inspection route. A black or zero-filled reference region must never
be silently ignored, converted to Normal, or described as complete
inspection. Near-complete coverage is insufficient for the finished
front-metal workflow; the final routing audit must report zero unassigned
valid pixels.

## Exposed R5P23 limitation

R5P23 successfully aligned and formed target-excluded composites for all
twelve wafers, but its strict local peer-consensus gate deliberately emitted
zero-valued composite and residual pixels where it could not identify one
unique reference clique of at least three peers. The target-native pixels are
present in those locations. The missing content is the reference assignment,
not the source image.

Across the returned T16/T17 control windows, R5P23 records 305,594 BF and
203,748 DF coverage-hold pixels. No current control sheet has exactly zero
held pixels in both channels. Therefore
`PASS_FM7P23_ALL_12_TARGETS_PROCESSED_WITH_TARGET_EXCLUDED_COMPOSITES_REVIEW_ONLY`
is a composite-formation diagnostic PASS, not a complete-inspection PASS.

## Required separation of concerns

Reference coverage and defect acceptance are separate gates:

- reference coverage decides whether a target-excluded reference value and
  local variability estimate can be constructed for a valid native pixel;
- defect acceptance decides whether the target differs sufficiently from
  that supported reference to become defect evidence.

Excessive false detections may indicate that the defect acceptance envelope
is too narrow, but widening that envelope must not be used to disguise
unassigned reference pixels. Conversely, forcing one strict peer clique must
not be the only way to assign a reference when a bounded, provenance-preserved
fallback can be evaluated.

## R5P24 diagnostic contract

R5P24 must remain review-only and target-excluded. For every valid native
target BF and DF pixel it must record exactly one explicit route:

1. `STRICT_CONSENSUS_REFERENCE` when the unchanged R5P23 unique-clique gate
   qualifies the location;
2. `ROBUST_FALLBACK_REFERENCE` when a predeclared target-excluded fallback
   constructs a reference and local variability envelope from eligible peer
   pixels without spatially inventing target data; or
3. `DIRECT_NATIVE_REVIEW_REQUIRED` if no defensible reference can be
   constructed.

The R5P24 coverage-closure gate requires zero unassigned valid pixels. A
direct-native route is an explicit inspection route, not Normal truth and not
a skipped pixel. Strict and fallback references must remain separately
counted and separately visible. No spatial interpolation across missing peer
pixels, target self-reference, residual-ranked peer removal, sequential
worst-peer dropping, fixed alignment adjustment, or target-native resampling
is allowed.

The diagnostic must report T16/T17 false-residual counts separately for
strict and fallback routes and must preserve a sensitivity check before any
acceptance-envelope change can be proposed. It must not emit an automatic
defect class, Reject, Normal, XML, training, or production result.

## Authority

R5P23 remains `DIAGNOSTIC_ONLY`. This requirement authorizes a new bounded
R5P24 coverage-closure diagnostic; it does not authorize silent filling,
detector-threshold promotion, production integration, or a claim of complete
inspection before the returned zero-unassigned audit and operator review.

The patterned-fiducial metadata request
`REQ_20260816T033053168Z_802B9D0EC0B4` remains accepted and unanswered in the
background and must not be duplicated.
