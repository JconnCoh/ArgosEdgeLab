# Front-metal D7 V17 structural-residual audit checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`

This is the continuation authority after the operator approved one bounded
two-control structural-reference experiment. It does not promote pixels,
change V17 M3, or authorize a reviewer/JBOD build.

## Frozen controls

- T16 false-structure control: stroke 238, source box
  `(4293.494,7143.628)-(4312.542,7169.342)`.
- T17 faint non-reciprocal control: field 10 strokes 254-258, source box
  `(5826.533,7123.074)-(6274.152,7183.074)`, with class preserved as
  `CONFIRM_SCRATCH_OR_RESIDUE` rather than an automatic class.
- Stroke 278 remains deferred and was not evaluated.

Both controls use the locked Slot02 native `T17_R03C01` BF/DF tile at
`2400 x 2000`, `scaleX=1`, `scaleY=1`. The T16 location lies in the exact
240-pixel T16/T17 tile overlap. For Slot02 and all three peers, 120,000 sampled
overlap pixels per channel were byte-identical between T16 and T17, with zero
differences. This allows the T17 tile to provide bounded native alignment
reserve around T16 without resampling or changing target pixels.

## Reference and method

Three physically distinct, target-excluded peer wafers are locked:

- Slot03;
- Slot13;
- Slot18.

Each contributes native BF and DF from the same `T17_R03C01` source geometry.
For each control and peer, the tool finds one integer-only local translation
from combined BF/DF product-edge correlation, excluding an 8-pixel expansion
of the operator reference box. It fits only a bounded affine intensity map per
channel, then forms a three-peer per-pixel median BF reference and median DF
reference. There is no geometric interpolation or resampling.

Class-neutral evidence is the stronger of independent BF and DF absolute
residuals after a peer-median-absolute-deviation floor and local 3-by-3 native
aggregation. Bright-BF/dark-DF residual reciprocity is rendered separately as
support only. Lack of reciprocity cannot erase a BF-or-DF residual.

The operator boxes are yellow display/audit references only. They are not
rasterized into evidence and their aggregate metrics are not sensitivity
authority.

## Alignment gate

The exact non-mutating preflight passed source hashes, dimensions, target and
peer identities, target exclusion, output-root absence, free-space reserve,
native scale, and the frozen minimum correlation `0.60`:

- T16:
  - Slot03 shift `(+13,+13)`, correlation `0.954653`;
  - Slot13 shift `(-3,-11)`, correlation `0.965106`;
  - Slot18 shift `(0,0)`, correlation `0.979011`.
- T17:
  - Slot03 shift `(+60,-40)`, correlation `0.766473`;
  - Slot13 shift `(+44,-56)`, correlation `0.851781`;
  - Slot18 shift `(+47,-49)`, correlation `0.883916`.

All shifts are integer translations. No reduced overview or prior
display-localization raster is detector input.

## Artifacts

Output root:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R4`

- `AUDIT.json` SHA-256
  `664DAE0E4AE2D3829507B9002BB58D4E8922FF6E25971446D8A259F3B8AFE8D9`;
- `T16_S238_STRUCTURAL_RESIDUAL_AUDIT.png` SHA-256
  `AB494D2216D170EEEE931578BCBF666D10D571FDB1425708A90AD5902F604B03`;
- `T17_F10_S254_TO_S258_STRUCTURAL_RESIDUAL_AUDIT.png` SHA-256
  `2E42365AB46E97DB2932F4E08B29361F48DAFAF957C09CB03716D98EBF059378`.

Tooling:

- source: `tools/Audit-FM7V17StructuralResidualV4.cs`, SHA-256
  `DB887CBD5620C0FFC37C943F4A033D268B1E5744429ECF0464D64FB2A2782606`;
- input: `tools/FM7V17R4_INPUT.json`, SHA-256
  `3371C0A9DA184064AFA8D66A5A625A9AB54497214C2121BBE5443B3FC6658390`;
- executable: `tools/bin/Audit-FM7V17StructuralResidualV4.exe`, SHA-256
  `273EC5EC560961EAA7EBEDF23817D537A06779F30CAB0C69324D69AE142972FC`.

All planned paths passed with maximum effective length 192 and maximum
component length 67. The documented `PathInfo`/`System.Drawing` PowerShell
constructor failure was recorded in `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`;
the failed comparison rows were discarded and the overlap check was rerun
with scalar resolved paths, terminating errors, complete counts, and zero
command errors.

## Bounded numerical result

T16's reference box now contains 200/114/62 class-neutral pixels at the crop
p90/p95/p98 cutoffs; its maximum ranks at percentile `0.996009` and its box
p90 ranks at `0.982181`. This is sufficient to present but not to claim that
the physical Scratch is followed or good die structure is suppressed.

T17's large combined reference box contains 2663/1774/558 class-neutral pixels
at p90/p95/p98. The crop distribution rises sharply from p90 `39.695471` to
p95 `163.506782`, so product/alignment residuals may still dominate the strict
panels. The aggregate box includes product structure between five fragments
and is not a sensitivity metric. Operator visual review is required; no tuning
is authorized from these numbers alone.

## Next action

Pause for operator review of both file-backed sheets. For T16, ask whether the
actual Scratch is marked and whether good-die magenta is materially reduced.
For T17, ask whether the faint raw-visible feature appears in either signed
channel residual, the class-neutral heatmap, or any magenta panel. Reciprocity
is supporting context only.

Do not tune, promote pixels, inspect stroke 278, change V17 masks, build or
present V17, run raster smoke, package JBOD, emit XML, enable production
routing, or alter the strict chipout sibling before that feedback.
