# FM7P24A zero-blank composite operator approval — 2026-08-17

Disposition: `APPROVED_BASELINE`

State: `APPROVED_T16_T17_TARGET_EXCLUDED_STRICT_PLUS_FALLBACK_COMPOSITE_BASELINE`

## Operator decision

After reviewing the returned file-backed composite sheets and clarifying the
inspection-route legend, the operator directed: `ok let's proceed`.

The large gold/yellow route blocks are accepted as covered pixels routed
through the separately labeled robust target-excluded fallback. They are not
unassigned pixels. Green remains strict reference, magenta remains
direct-native review, and red remains unassigned. The 128-by-128 route-cell
rendering must not be mistaken for pixel-sized blank regions.

## Approved scope

This approval freezes the FM7P24A composite-formation method for the bounded
T16/T17 gate across the twelve returned front-metal wafers:

- target excluded from its own reference;
- eleven other-wafer references per target;
- unchanged independent BF/DF alignment transforms;
- strict consensus preserved as the primary route;
- one-low/one-high trimmed target-excluded robust fallback kept separate;
- zero direct-native, zero unassigned, and zero coverage-hold control pixels;
- exact strict/fallback contribution provenance retained.

Across all 24 controls, BF and DF each contain 3,638,111 valid pixels. BF uses
3,332,904 strict and 305,207 fallback pixels. DF uses 3,434,750 strict and
203,361 fallback pixels. No fallback pixel becomes implicit Normal truth.

## Authority boundary and next action

The approval is a composite-reference baseline, not defect truth. It does not
approve a defect mask, defect class, Normal decision, training use, XML, or
production routing. The next revision may apply this frozen reference method
to the existing front-metal residual/detector pipeline without changing the
detector thresholds or alignment transforms, then produce a fresh
canonical-derived review-only defect reviewer with exact raster provenance.
