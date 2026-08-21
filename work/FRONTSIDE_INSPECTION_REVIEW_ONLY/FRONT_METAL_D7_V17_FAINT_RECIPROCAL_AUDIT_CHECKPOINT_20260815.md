# Front-metal D7 V17 faint reciprocal audit checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`

This is the continuation authority after the operator requested one quick
application of the unchanged signed reciprocal method to a separately marked,
extremely faint feature before any structural-reference correction.

## Resolved operator target

The exact locked V16 field comment is:

> idk if its possible to detect this scratch without blowing up false defects.
> I wouldnt lose sleep over giving up on it

It resolves to identity `62546-481_POST2_SLOT02`, tile `T17_R03C01`, field
`FIELD_10_3_3`. The operator now recalls uncertainty between Residue and
Scratch. The saved feedback contains five short `ADD_MISSED_DEFECT / SCRATCH`
strokes, global indices 254 through 258, spanning source bounds
`(5826.533,7123.074)-(6274.152,7183.074)`. Preserve the operator's present
class uncertainty; this diagnostic does not establish Scratch or Residue.

## Bounded run

Output root:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R3`

The run applies the exact R2 scoring method to only the combined local region:
native 1:1 BF bright-ridge evidence plus native 1:1 DF dark-valley evidence,
a symmetric-side penalty, and at most four same-axis pixels of reciprocal
support. It does not compare against the display composite, a prior detector
composite/current mask, peer-die structure, or a layout template. The planned
T16 structural-reference comparison was not started. Stroke 278 remains
deferred.

Locked native sources:

- BF `T17_R03C01/BF_NATIVE_1TO1.png`, `2400 x 2000`, SHA-256
  `8976497ED322297ADB488512C720B2757D4E8E86E4FA263A32E65F93D87926F5`;
- DF `T17_R03C01/DF_NATIVE_1TO1.png`, `2400 x 2000`, SHA-256
  `1374B9A4B5745C98786D21BC7B7388C68794115E61BC50B9CAF580335DB7E3CD`.

Artifacts:

- `AUDIT.json` SHA-256
  `54F917B74A72A4C71A0F1A0CE49AF14210E85B8419A6FA73BFBD392778180BC0`;
- `T17_F10_S254_TO_S258_RECIPROCAL_AUDIT.png` SHA-256
  `8C1239B394ABE001491819B2D2D7F52CC2CCB7EC0059215AC5A799F374D1418D`.

Tooling:

- source: `tools/Audit-FM7V17FaintReciprocalV3.cs`, SHA-256
  `C81157931C98C1B08F03EE7B11B94788EAF39158528870B3FE5A4402B10A86F5`;
- input: `tools/FM7V17R3_INPUT.json`, SHA-256
  `570BD5B400B4B0D3D894FABB1A8CC973166EC9E156FF94E6ED3EFE3D41FF5FB6`;
- executable: `tools/bin/Audit-FM7V17FaintReciprocalV3.exe`, SHA-256
  `560763E51BC8989737E14916A8A6E33345D3D14BE5E65CE5A737568AD3EA702B`.

The exact non-mutating preflight passed the target identity lock, source
hashes, native dimensions, output-root absence, and free-space reserve. All
planned paths passed with maximum effective length 192 and maximum component
length 64.

## Interpretation limit

The crop covers source `x=5730, y=7027, width=642, height=254`. Its displayed
p90/p95/p98 reciprocal thresholds are `36.890823 / 61.607084 / 74.704148`.
The combined yellow reference rectangle necessarily includes unmarked
background and product structure between the five fragments. Its aggregate
pixel counts and maximum percentile are therefore not a valid sensitivity or
class metric. Operator inspection of whether the physical faint feature
appears in the heatmap or threshold panels is the only pending purpose.

No diagnostic response is eligible for V17 mask promotion. V17 M3, all
source/current masks, V16, XML/production state, JBOD state, and the strict
chipout sibling remain unchanged.

## Next action

Pause for operator review of the single T17 sheet. Ask whether the faint
physical feature is visible in the reciprocal heatmap and whether any portion
survives the p90/p95/p98 magenta overlays. If the combined feature is not the
intended spot, use operator direction to isolate one of strokes 254-258; do
not guess from strength.

Do not start the T16 structural-reference comparison, inspect stroke 278,
change masks, build/present V17, run raster smoke, package JBOD, emit XML,
enable production routing, or alter the strict chipout sibling before that
feedback.
