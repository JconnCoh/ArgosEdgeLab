# Front-metal D7 V17 faint reciprocal feedback checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`

This is the continuation authority after operator review of the separate
extremely faint feature audit. It supersedes the pre-feedback pause in
`FRONT_METAL_D7_V17_FAINT_RECIPROCAL_AUDIT_CHECKPOINT_20260815.md` without
promoting any response into V17.

## Operator result

For the physical feature associated with strokes 254-258 in
`T17_R03C01 / FIELD_10_3_3`, the operator reports:

- the defect is visible in the native BF and DF raw panels;
- no corresponding response is visible in the continuous reciprocal heatmap;
- no corresponding magenta response is visible in the threshold overlays.

This is a detector miss, not merely a percentile-cutoff miss. Lowering the
p90/p95/p98 overlay threshold cannot recover a feature that has no meaningful
underlying reciprocal score. The saved Scratch/Residue uncertainty remains;
visibility in raw BF/DF does not establish class.

## Consequence for the method

The signed reciprocal branch is eligible only for features that express its
specific narrow bright-BF/dark-DF ridge relationship. It must not become the
sole defect-presence gate. The current result demonstrates a raw-visible
feature outside that response family.

Adding more images to a displayed or averaged reciprocal composite would not
repair this miss. A future structural-reference test may still help, but the
reference must be used as a robust aligned baseline independently in BF and DF
before reciprocity. Repeatable product structure can then be discounted while
either-channel, target-only residual evidence remains class-neutral and
eligible. Reciprocity may remain a specialized confirming branch; lack of
reciprocity must not erase raw-visible residual evidence.

This conclusion does not authorize a broad null-die/scribe mask, global
threshold lowering, inferred line, resampling, or class promotion.

## Preserved evidence and authority

The unchanged diagnostic root remains
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R3`:

- `AUDIT.json` SHA-256
  `54F917B74A72A4C71A0F1A0CE49AF14210E85B8419A6FA73BFBD392778180BC0`;
- `T17_F10_S254_TO_S258_RECIPROCAL_AUDIT.png` SHA-256
  `8C1239B394ABE001491819B2D2D7F52CC2CCB7EC0059215AC5A799F374D1418D`.

R3 remains `DIAGNOSTIC_ONLY` and is ineligible for mask promotion. V17 M3,
all source/current masks, V16, XML/production state, JBOD state, and the
strict chipout sibling remain unchanged. Stroke 278 remains deferred.

## Next action

Await operator direction on the adjusted smallest test: use an aligned robust
same-design reference to form separate native BF and DF residuals, retain a
class-neutral either-channel residual layer, and show the reciprocal branch
separately. The original T16 Scratch remains the false-structure control; this
T17 faint feature is the raw-visible reciprocal-miss control. Do not assume
the T17 feature is Scratch or Residue.

Do not change V17 masks, build/present V17, run raster smoke, package JBOD,
emit XML, enable production routing, inspect stroke 278, or alter the strict
chipout sibling before further operator direction.
