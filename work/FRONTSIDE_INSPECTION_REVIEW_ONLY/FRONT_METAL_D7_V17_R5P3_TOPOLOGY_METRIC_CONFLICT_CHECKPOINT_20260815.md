# Front-metal D7 V17 R5P3 topology-metric conflict checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`.

Current phase:
`FRONT_METAL_D7_V17_R5P3_TOPOLOGY_METRIC_CONFLICT_HOLD`.

## Operator feedback and interpretation

The operator could not reliably choose Current, Minus lattice, or Plus
lattice from the R5P2 rigid sheet and asked whether the correct phase should
have the highest bright values and lowest dark values, while greater grayness
would indicate more shift.

That rule is not valid for the rigid panels. An integer translation relocates
source pixels without blurring or averaging them, so a wrong one-die phase can
remain perfectly sharp and high contrast. Grayness/softness was valid evidence
against the prior R5 per-pixel composite because that composite mixed multiple
translations. It is not a phase-distance measure for an individual rigid raw
peer.

## Quick topology check

A bounded numerical check used only the existing R5P2 candidates. It sampled
11,280 native locations outside the operator box, selected the 2,256 locations
whose multiscale BF/DF descriptors most distinguish adjacent lattice phases,
and compared low-frequency intensity plus local texture in both channels.

The result is internally conflicting:

| Peer | Absolute BF/DF topology-distance winner | Four-map correlation winner | Best/second distance margin |
|---|---|---|---:|
| S03 | Minus lattice | Plus lattice | 4.33% |
| S13 | Minus lattice | Plus lattice | 6.22% |
| S18 | Minus lattice | Plus lattice | 8.11% |

The same conflict occurs for all three peers. The pre-existing R5 photometric
gain/offset was fitted around the Current phase, so absolute brightness
distance is not phase-neutral. Correlation is invariant to much of that
photometric bias but remains vulnerable to the repeating grid. Neither metric
is sufficient by itself. No phase is selected.

## Artifacts

- Input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P3_INPUT.json`
  - SHA-256: `6966ED13E6FD06F30B1EECA71C0BCF98D84794A5D530D54C87ECF8118C3F46C9`
- Source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Measure-FM7V17RigidPhaseTopologyV1.cs`
  - SHA-256: `4E1D6FBE342D0A87F5D77DC54336A34762C0CF84606401991CE842C704224F93`
- Executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/bin/Measure-FM7V17RigidPhaseTopologyV1.exe`
  - SHA-256: `DFB78E10BD66BDF02DAB2E821B21EFC3CEB93F2DD7A9B9CCC1616E959D358574`
- Audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P3/AUDIT.json`
  - SHA-256: `6A2657BC84E162C21C3754B47AF302B42FCEE51297726B0D6741073E669959F0`

## Preserved state and next gate

T17 remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`. No peer or phase
is selected, no reference is rebuilt, and no Scratch decision is made. Source
or current masks, M3, the released V16 reviewer, XML, production routing,
JBOD state, and the strict chipout sibling remain unchanged. Deferred stroke
278 was not evaluated.

The smallest possible follow-up, if explicitly authorized, is one candidate-
neutral photometric test: fit each candidate's BF/DF gain and offset only on
phase-stable periodic anchors, then compare the held-out phase-discriminative
locations. Stop if absolute distance and correlation still disagree. An
absolute die-index or nonperiodic full-wafer anchor would be preferable if it
can be recovered from existing registration metadata.
