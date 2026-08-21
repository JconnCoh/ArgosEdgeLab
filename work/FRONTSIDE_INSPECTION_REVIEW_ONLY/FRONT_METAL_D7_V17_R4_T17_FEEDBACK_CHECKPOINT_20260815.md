# Front-metal D7 V17 R4 T17 feedback checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`

This is the continuation authority after operator review of both controls in
the bounded R4 structural-residual experiment. It records what the current
signed-residual rendering reveals and what it does not establish. R4 pixels
remain ineligible for mask promotion.

## Operator review

For the T17 field-10 feature marked by strokes 254-258, the operator observes
the faint feature as the dark, nearly colorless trace in both the BF and DF
signed-residual panels. A display-only GIMP color-curve adjustment makes that
trace visibly distinct. The feature remains directly visible in the native
BF/DF raw panels and its class remains uncertain between Scratch and Residue.

The earlier T16 review remains preserved: stroke 238 is extremely visible in
the R4 response views, while known-good die structure produces substantial
false response.

## Interpretation

The signed-residual hue encodes sign: red is positive and blue is negative.
Darkness encodes small magnitude relative to the crop display scale. A dark
or nearly colorless trace therefore means low displayed residual magnitude;
it does not mean zero evidence and must not be labeled Normal.

The T17 class-neutral union-score distribution rises from
`p90=39.6954707` to `p95=163.5067815` and `p98=189.9611967`. This sharp jump
is consistent with high-amplitude product-edge and alignment residuals
consuming most of the displayed range and compressing weaker variation near
black. The operator's curve adjustment demonstrates display-recoverable
low-level variation at the raw-visible feature, but it is display-only. It
does not by itself prove detector support, defect class, or pixel-exact defect
geometry.

Low residual magnitude must not be inverted into an automatic detection
rule: a dark pixel can also mean that the target agrees with its peer
reference. The raw BF/DF visibility, the co-located low-amplitude signed
variation, and the T16 sensitivity result together justify a bounded
alignment/display correction; they do not justify threshold lowering or mask
promotion.

## Smallest justified next test

If authorized, retain the native target pixels and change reference matching
only:

- use bounded, smooth, block-local integer translations instead of one shift
  for the entire peer/crop;
- use a one- or two-pixel observed peer-reference neighborhood tolerance to
  suppress paired residual halos from recurring product edges;
- retain the ordinary signed-residual view and add a clearly labeled
  `DISPLAY_ONLY` low-amplitude/local-standardized residual view so alignment
  artifacts do not consume its dynamic range;
- keep BF and DF evidence independent and reciprocity supporting-only;
- if the T17 feature remains a low-magnitude trough after improved matching,
  compare a bounded raw feature response against the same target-excluded
  peer feature responses instead of treating raw intensity subtraction alone
  as the presence gate.

This is not permission to resample, infer a line, turn dark residual pixels
into detections, use a broad product mask, change a global threshold, or
consume operator marks as scoring input. T16 remains the sensitivity anchor,
and the T17 proposal remains `CONFIRM_SCRATCH_OR_RESIDUE`.

## Preserved state

The unchanged R4 sheets remain:

- `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R4/T16_S238_STRUCTURAL_RESIDUAL_AUDIT.png`,
  SHA-256
  `AB494D2216D170EEEE931578BCBF666D10D571FDB1425708A90AD5902F604B03`;
- `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R4/T17_F10_S254_TO_S258_STRUCTURAL_RESIDUAL_AUDIT.png`,
  SHA-256
  `2E42365AB46E97DB2932F4E08B29361F48DAFAF957C09CB03716D98EBF059378`.

Stroke 278 remains deferred. R4 remains `DIAGNOSTIC_ONLY`; V17 M3,
source/current masks, V16, XML/production state, JBOD state, and the strict
chipout sibling remain unchanged.

## Next action

Explain the bounded interpretation and await operator direction. Do not start
the alignment-only follow-up, tune thresholds, promote pixels, inspect stroke
278, change V17 masks, build/present V17, run raster smoke, package JBOD, emit
XML, enable production routing, or alter the strict chipout sibling before
that direction.
