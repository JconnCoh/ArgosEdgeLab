# Front-metal D7 V17 R5 local-match audit checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`

This is the continuation authority after the operator authorized the smallest
bounded follow-up to R4. R5 changes only target-excluded peer-reference
matching and residual display. It does not change a source/current mask,
threshold authority, M3, V16, XML/production state, JBOD state, or the strict
chipout sibling.

## Frozen scope and method

R5 evaluates only the already-reviewed controls:

- T16 stroke 238 remains the strong Scratch sensitivity and false-structure
  control;
- T17 field-10 strokes 254-258 remain the faint raw-visible,
  non-reciprocal `CONFIRM_SCRATCH_OR_RESIDUE` control;
- stroke 278 remains deferred.

The unchanged three target-excluded native peers are Slots03, 13, and 18.
The target and peers remain at native 1:1 pixels. R5 preserves the R4 coarse
integer alignments, then uses 64-pixel local blocks, searches only within
plus/minus 3 integer pixels of each coarse alignment, and median-smooths the
block shift grid. A common one-pixel BF/DF peer-neighborhood offset may explain
each target pixel; the same offset is used for all three peers and both
channels. There is no resampling, interpolation, inferred line, broad product
mask, global threshold change, or operator-mark scoring input.

The low-amplitude signed-residual panels are explicitly `DISPLAY_ONLY`. They
use the crop p90 absolute residual as their high point and gamma 0.30. They do
not invert dark residuals into detector evidence. A separate raw
feature-to-peer response was not performed in R5.

## Preflight and run

The exact executable preflight passed before the output root existed:

- state: `PASS_FM7V17R5_PREFLIGHT`;
- native scale: 1:1;
- local block size: 64 pixels;
- local shift radius: 3 pixels;
- peer-neighborhood radius: 1 pixel;
- free bytes before run: `121396998144`;
- mutation performed: false.

The bounded run completed as
`DIAGNOSTIC_ONLY_NATIVE_LOCAL_MATCH_STRUCTURAL_RESIDUAL_TWO_CONTROL` under
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5`.

Exact implementation bindings:

- source SHA-256:
  `7FECAAD7FE5B7FA67A792ED80E13F9C431CFE2910557B60ED1EFF48D639A4734`;
- input SHA-256:
  `28B41321D9F694B854ECE1926EA97100AB2E88B4F6D5CAC31F9E8DB74C0833C5`;
- executable SHA-256:
  `AE6F90D1F5653FE3C140A3EF2BC9B504F1A19C086A87C1DCF0EC3F39F9FCD2DC`;
- audit SHA-256:
  `1224FFCD89F75318F55325DA877D9CEFF6B9A26113AB655C4301BA02C5A815E2`.

## Bounded measurements

T16's crop residual quantiles changed from R4 to R5 as follows:

- p90: `1.5011938` to `0.8384266`;
- p95: `2.9175913` to `2.0938597`;
- p98: `5.6884620` to `4.7937863`.

Its operator reference-box counts at the crop p90/p95/p98 thresholds changed
from `200/114/62` to `99/49/20`. This reduction is not automatically an
improvement: it may mean false response was suppressed, Scratch response was
suppressed, or both. Operator visual review is required before claiming that
T16 sensitivity survived.

T17's crop residual quantiles changed from R4 to R5 as follows:

- p90: `39.6954707` to `38.5081038`;
- p95: `163.5067815` to `158.2678568`;
- p98: `189.9611967` to `182.5021857`.

Its operator reference-box counts changed from `2663/1774/558` to
`2611/1655/670`. The high p95/p98 product/alignment regime remains present, so
these counts are not sensitivity authority and do not establish that the
faint trace became detector-positive.

Every local-alignment block passed without global fallback. The largest
observed local change was two pixels across the bounded grids. The result
therefore stays within the authorized local integer correction.

The percentile overlays always color the top 10%, 5%, or 2% of the current
crop by construction. Their total magenta area is therefore not an absolute
before/after noise measurement. Review should ask whether response moved off
known-good structure while remaining on the physical T16 Scratch, and whether
the T17 trace remains visible in the standard or display-only signed panels.

## File-backed review sheets

- T16:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5/T16_S238_LOCAL_MATCH_RESIDUAL_AUDIT.png`,
  1744 by 2024 pixels, 811172 bytes, SHA-256
  `7728FDBF26FEDE24DF703F87457B51DD4451A35D53947A365D8FC0A66BBD024E`;
- T17:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5/T17_F10_S254_TO_S258_LOCAL_MATCH_RESIDUAL_AUDIT.png`,
  5176 by 2296 pixels, 3170956 bytes, SHA-256
  `D31DA8281AA9550553599A0E778F45C2E26D48BEFF6EC10C2F3C1623D80478B1`.

## Next action

Pause for operator review of both R5 sheets. Do not tune R5, promote any R5
pixel, perform the separate raw feature-to-peer test, inspect stroke 278,
change V17 masks, build/present V17, run raster smoke, package JBOD, emit XML,
enable production routing, or alter the strict chipout sibling before that
feedback.
