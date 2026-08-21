# Front-metal D7 V17 R5P4 photometric phase hold checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`.

Current phase:
`FRONT_METAL_D7_V17_R5P4_PHOTOMETRIC_PHASE_UNRESOLVED_HOLD`.

## Authorized bounded test

The operator authorized exactly one final local phase check after R5P3's
absolute-distance/correlation conflict. R5P4 uses the same preserved native
target and rigid S03/S13/S18 candidates. For every candidate and channel, it
fits gain and offset only on the 40% most phase-stable periodic samples, then
scores the disjoint 20% most phase-discriminative samples. The operator box is
excluded. There is no resampling, pixelwise switching, blockwise switching,
composite rebuild, detector scoring, or mask change.

The fit uses 4,512 phase-stable anchors and the test uses 2,256 held-out
phase-discriminative locations from 11,280 eligible native samples.

## Result

The held-out metrics still disagree:

| Peer | Combined distance | BF distance | DF distance | Four-map correlation | Best/second combined-distance margin |
|---|---|---|---|---|---:|
| S03 | Current | Current | Current | Plus lattice | 9.21% |
| S13 | Minus lattice | Minus lattice | Minus lattice | Plus lattice | 8.68% |
| S18 | Plus lattice | Current | Current | Plus lattice | 1.15% |

Candidate-specific fitted gains are plausible and close to unity, so the
conflict is not resolved by removing the prior R5 photometric bias. None of
the three peers has agreement across the required primary metrics. The local
repeating crop therefore cannot establish absolute die phase.

No phase or peer is selected. In particular, the unanimous Plus-lattice
correlation result is not promoted because correlation remains vulnerable to
the repeating grid and directly conflicts with held-out BF/DF distance.

## Artifacts

- Input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P4_INPUT.json`
  - SHA-256: `637487FF23EAF6F1F0FA730DF6D893475BF309FB472723255A659997149F1454`
- Source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Measure-FM7V17RigidPhasePhotometricV1.cs`
  - SHA-256: `93FBE9C7635137B39D6E6B5E1F78932207DD0B0281944030124AA09C6AFF5687`
- Executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/bin/Measure-FM7V17RigidPhasePhotometricV1.exe`
  - SHA-256: `41A837FC73BBBDE79791C3DE3A09EB5D6F8ED5802569AB8E15C8AC0D74BE81A7`
- Audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P4/AUDIT.json`
  - SHA-256: `6D325BD530427F279E90F8D268C9DF2769C9B8502303030E9081B8A6F32238F7`

## Preserved state and next gate

The promised local phase experiment stops here. T17 remains
`HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`. No reference is rebuilt and no
Scratch decision is made. Source/current masks, M3, the released V16
reviewer, XML, production routing, JBOD state, and the strict chipout sibling
remain unchanged. Deferred stroke 278 was not evaluated.

Do not run another local phase metric. Future T17 structural reference work
requires an absolute nonperiodic/full-wafer or die-index registration anchor.
If that authority is unavailable, these peers must not be used to claim T17
structural correspondence; use different metadata-qualified peers or leave
the faint feature on explicit review hold.
