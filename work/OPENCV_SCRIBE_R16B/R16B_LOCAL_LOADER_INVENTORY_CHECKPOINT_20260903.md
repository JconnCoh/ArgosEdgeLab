# OCV-02 scribe R16B local loader/inventory checkpoint — 2026-09-03

## Result

Fresh provider-side loader code now consumes the R16A supplement beside an
unchanged frozen base bank. It verifies the supplemental manifest hash,
schema, diagnostic-only authority, contained paths, every reference hash,
unique label/case/position keys, and declared counts before returning any
prototype. The local combined-bank contract passes with six R16A references
and remaining missing labels `IOVWYZ`. Activation and identity admission are
hard false in the returned evidence.

S17's already-recorded `K` and `X` cells are complete and independently
useful. Against the R16A J/K/Q/X bank, S17 K ranks K first (`0.5244059563`
versus Q `0.2142488510`) and S17 X ranks X first (`0.6813099980` versus J
`0.2165646106`). They are available for a fresh eight-reference supplement;
R16A remains unchanged.

The exact R13A inventory of the hash-locked confirmed-scribe overlay contains
795 rows and 319 unique confirmed scribes. It mechanically found confirmed
examples for `J/K/Q/X` and no confirmed examples for `I/O/V/W/Y/Z`. Therefore
the remaining six labels require a broader authoritative lot/inspector truth
source before selecting images. They cannot be inferred from the current
confirmed overlay.

## Exact hashes

- Loader `work/OPENCV_SCRIBE_R16B/ArgosOpenCvScribeSupplementLoaderR16B.py`:
  `3D074A9F1031A8243F49748E560EC802611765528BD49D554201CDB1F0BD5BCD`
- Test `work/OPENCV_SCRIBE_R16B/Test-R16BSupplementLoader.py`:
  `F352A5C4FD833A878B42E4E3049A73E1E9BD19E8BA4B5BFD64CDF657584652B9`
- Gate `work/OPENCV_SCRIBE_R16B/R16B_LOCAL_GATE.json`:
  `519593BA4FC757409801733AA3416935FFB6DDBFF33DDA616257687967712FF0`

## Authority and next action

This revision is `DIAGNOSTIC_ONLY`. No JBOD, portal, source-image, queue,
task/process, activation, admission, hold, training, XML, or production state
changed. Next: create a fresh supplement revision adding the two existing S17
K/X cells, then obtain a bounded file-backed lookup from the authoritative
lot/inspector truth source for `I/O/V/W/Y/Z` before selecting their wafers.
