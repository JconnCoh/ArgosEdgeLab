# Front-metal D7 V17 R5P2 rigid peer-phase audit checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`.

Current phase:
`FRONT_METAL_D7_V17_R5P2_RIGID_PHASE_REVIEW_PENDING`.

## Scope and authority

The operator authorized one bounded T17 follow-up after identifying the R5
per-pixel registration mosaic. This audit tests only coherent whole-crop
integer translations of the preserved native S03, S13, and S18 BF/DF peers.
It does not select a peer or phase, rebuild a composite, score a defect, tune a
threshold, or change detector authority.

The tool binds the exact R5 audit SHA-256
`1224FFCD89F75318F55325DA877D9CEFF6B9A26113AB655C4301BA02C5A815E2`.
The target and peers remain native 1:1 lossless inputs. There is no
resampling, per-pixel switching, or blockwise switching.

## Result

Target self-correlation measured a positive-Y lattice vector of `(14, 107)`
source pixels with correlation `0.844603`. Three rigid candidates are shown
for every peer: the R5 coarse shift, that shift minus one measured lattice
vector, and that shift plus one measured lattice vector.

The rigid BF candidate correlations are:

| Peer | Current | Minus lattice | Plus lattice |
|---|---:|---:|---:|
| S03 | `(60,-40)` / `0.762193` | `(46,-147)` / `0.706265` | `(74,67)` / `0.806459` |
| S13 | `(44,-56)` / `0.851781` | `(30,-163)` / `0.867255` | `(58,51)` / `0.803441` |
| S18 | `(47,-49)` / `0.883916` | `(33,-156)` / `0.852974` | `(61,58)` / `0.911790` |

The correlation maximum differs by peer. Correlation alone is not allowed to
decide which candidate has the correct null-die topology. The file-backed
sheet therefore awaits operator visual review, with one rigid translation per
panel and shared per-channel display stretch.

## Artifacts

- Input manifest:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P2_INPUT.json`
  - SHA-256: `022D84340AA931CE1684F8119E8825F4ECF96A2ED3CF256D8BBC59EFF1C47CC5`
- Source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Audit-FM7V17RigidPeerPhaseV1.cs`
  - SHA-256: `26C58F6CFA37AABB1057EE9DEABED685145587CA76EFA710730C416D2F751492`
- Executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/bin/Audit-FM7V17RigidPeerPhaseV1.exe`
  - SHA-256: `FCAE53D511970922628A91A920D88EE53EF2DE9104728FCAB98F3B2D384D00DB`
- Audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P2/AUDIT.json`
  - SHA-256: `131A8BDF992B176771D687A4820501310718EDF87D1282B1F83A429BCB77EE53`
- Review sheet:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P2/T17_RIGID_PEER_PHASE_AUDIT.png`
  - SHA-256: `F4A74A62909675E2207E6E3146BC6502BDBC4B9CB02D3F2C70F80E2A48102A1C`
  - Dimensions: `5176 x 3386`
  - Bytes: `5,955,183`

## Preserved state and next gate

No phase or peer is selected. T17 remains
`HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`. R5 remains ineligible for
structural false-suppression claims. Source/current masks, M3, the released
V16 reviewer, XML, production routing, JBOD state, and the strict chipout
sibling are unchanged. Deferred stroke 278 was not evaluated.

Next action: pause for operator review of the rigid phase sheet. Ask which of
the three columns preserves the correct patterned-die/null-die topology for
each peer. Do not rebuild the reference or resume Scratch recovery until that
visual phase decision is recorded.
