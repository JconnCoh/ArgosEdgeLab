# Front-metal D7 V17 R4 T16 feedback checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`

This is the continuation authority after operator review of the T16 half of
the bounded R4 structural-residual experiment. It does not promote R4 pixels
or supersede the pending review of the separate T17 faint control.

## Operator review

For T16 stroke 238, the operator reports that the physical Scratch is
extremely visible throughout the reviewed residual response views. The same
sheet contains substantial noise on known-good die structure, and the operator
asks whether that noise is caused by the quick alignment.

## Diagnosis

Yes, a substantial fraction of the structured noise is alignment residual.
The signed BF and DF panels show paired red/blue outlines along normal product
edges. That polarity pair is the expected signature when the target edge and
reference edge remain fractionally or locally displaced: one side becomes a
positive residual and the opposite side becomes a negative residual.

The R4 coarse alignment itself is not random. Its three T16 peer correlations
are high (`0.954653`, `0.965106`, and `0.979011`) at integer shifts
`(+13,+13)`, `(-3,-11)`, and `(0,0)`. The limitation is that each peer receives
only one integer translation for the entire crop. That model cannot absorb
small local rotation, optical distortion, shape variation, or fractional-edge
placement. The scattered interior speckle can additionally contain genuine
wafer-to-wafer appearance and sensor/texture variation; it must not all be
called shift noise.

The R4 T16 result is therefore promising sensitivity evidence but not an
acceptable false-response result. Threshold lowering or class promotion is
not justified.

## Smallest justified correction

If authorized after the remaining review, preserve the target at native 1:1
pixels and improve only reference matching:

- replace the single crop-wide shift with bounded, smooth, block-local integer
  translations;
- compare a target pixel with a very small native peer-reference neighborhood
  so a one- or two-pixel recurring edge displacement does not create a double
  residual halo;
- retain a target residual only when no observed peer pixel in that bounded
  neighborhood explains it;
- keep BF and DF evidence independent and reciprocity supporting-only.

This is not permission for geometric interpolation, resampling, inferred
lines, a broad product mask, or a higher/lower global threshold. T16 remains
the sensitivity anchor during any alignment-only correction.

## Preserved state

The unchanged R4 T16 sheet remains
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R4/T16_S238_STRUCTURAL_RESIDUAL_AUDIT.png`,
SHA-256
`AB494D2216D170EEEE931578BCBF666D10D571FDB1425708A90AD5902F604B03`.

T17 operator review remains pending. Stroke 278 remains deferred. R4 remains
`DIAGNOSTIC_ONLY`; V17 M3, source/current masks, V16, XML/production state,
JBOD state, and the strict chipout sibling remain unchanged.

## Next action

Explain the alignment signature to the operator and await review/direction.
Do not tune R4, start the alignment-only correction, promote pixels, inspect
stroke 278, change V17 masks, build/present V17, run raster smoke, package
JBOD, emit XML, enable production routing, or alter the strict chipout sibling
before that direction.
