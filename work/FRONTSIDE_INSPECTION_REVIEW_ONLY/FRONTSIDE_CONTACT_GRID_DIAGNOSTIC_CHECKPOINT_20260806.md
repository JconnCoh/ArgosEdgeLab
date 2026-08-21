# Frontside CONTACT grid/composite diagnostic checkpoint — 2026-08-06

Status: active review-only development. No golden reference, accepted defect
mask, detector truth, training truth, XML authority, JBOD frontside enablement,
or production authority was created.

## Qualified intake

`intake/FRONTSIDE_INSPECTION_INTAKE_V1_20260806T180000Z.json`

SHA-256:

`6106F54967B843375E109C155C952A1BB47BF8288631EFE001E0F9994F45C4A8`

The append-only intake joins all 15 acquisitions to 11 operator-confirmed
frontside scribes, exact read-only MES lineage, complete visual-state keys,
and native frontside pose. It forms four visual-state cohorts:

- CONTACT PRE FIDUCIAL PATTERN: 6 acquisitions / 6 physical wafers;
- P-TI ETCH PATTERN: 4 acquisitions / 2 physical wafers;
- VIAS PATTERN: 4 acquisitions / 2 physical wafers;
- PVIA 2 PR STRIP: 1 acquisition / 1 physical wafer.

Only CONTACT has at least three physical peers after target exclusion. The
two two-wafer cohorts and singleton retain
`HOLD_INSUFFICIENT_TARGET_EXCLUDED_PHYSICAL_PEERS`. Every cohort also retains
the incomplete acquisition-profile, grid-phase/orientation, and cross-lot
golden holds. Native images were not decoded or rehashed by the intake
builder.

## First bounded grid/composite diagnostic

`grid_diagnostics/FRONTSIDE_CONTACT_TARGET_EXCLUDED_DIAGNOSTIC_V1_20260806T181500Z`

The diagnostic directly sampled the original lossless 14411-by-10995 BF/DF
BMP pixels into reduced 1441-by-1100 pose-normalized views. Those reduced
views are display-only. Each target excluded its complete physical wafer and
used the other five physical wafers for a channel-separated median display.
No native detector scoring or accepted defect mask was performed.

Validation passed:

- 60 PNG display artifacts;
- 30 pairwise registration rows;
- 64 manifest-hashed files with zero mismatches;
- zero embedded image/data URLs;
- overwrite refusal passed;
- training, XML, golden promotion, and production flags remain false.

## Registration result

The first local-gradient registration is held, not accepted:

- medoid anchor: `9914R088FEE1`;
- candidate grid registrations: 0/5;
- explicit registration holds: 5/5;
- medoid-relative combined-gradient scores: 0.043497–0.162143;
- no medoid-relative result ended at the search boundary, but the signal was
  too weak for authority.

A separate signal probe showed that raw BF has a higher median pairwise
correlation (0.386630) but remains phase-ambiguous: 3/15 pairwise optima hit
the bounded search edge and the median peak margin is only 0.002663. BF local
and gradient signals are much weaker. Raw-field correlation therefore cannot
be substituted for qualified die-grid phase.

The generated target-excluded images are useful only to inspect why the
registration fails. They must not feed a detector or be described as golden
composites.

## Periodic and multi-region follow-up

Two additional bounded checks confirmed that this is not a threshold-only
problem:

- the centered 512-by-512 BF/DF phase diagnostic produced 18/30 unique local
  phase candidates and 15/15 reciprocal pairs, but only 4/20 three-wafer
  cycles closed;
- the independent five-region CENTER/NORTH/SOUTH/EAST/WEST check produced
  only 2/30 multi-region consensus candidates, held 28/30 ordered pairs, and
  closed 0/20 three-wafer cycles despite 15/15 reciprocal pairs.

The five-region output is:

`grid_diagnostics/FRONTSIDE_CONTACT_MULTI_REGION_PHASE_V1_20260806T191500Z`

This is a real pattern-phase ambiguity or non-reciprocal appearance problem,
not a reason to lower a correlation threshold. Pixel-median composite scoring
remains blocked.

## Next safe step

Review the six pose-normalized BF/DF rows and the display-only target-excluded
gallery to identify whether the apparent mismatch is die-grid phase,
product/reticle appearance within the same MES state, or an acquisition
profile difference that is absent from current metadata. The next algorithm
must be chosen from that evidence. It must fail closed when several periodic
shifts are equally plausible. Only after that gate and the exact acquisition
profile pass may the CONTACT cohort proceed to native-pixel target-excluded
residual scoring for Scratch, Residue, Contamination, Particle, and Stain.

`HotSpot` remains `DISABLED_NO_EXAMPLES`.
