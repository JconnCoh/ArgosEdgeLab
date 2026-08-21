# Front-metal operator feedback intake — 2026-08-13

## Frozen source

- Canonical review response: `human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260813T131750Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`
- SHA-256: `3D13EFC12D255076502A35F6AD9834F3F74205C62088C8A2FE3045CF1120AE68`
- Text response SHA-256: `D86E496BA2DE5E4290DEAA7ECFA5A2E4E3D75E2F3A221D97239ED550B81BF1E0`
- Source reviewer: `FRONT_METAL_LOCAL_COMPOSITE_CANONICAL_REVIEW_V1_20260813T021407Z`

## Review counts

- 334 native-coordinate strokes total.
- 37 missed-defect strokes: 36 Scratch, 1 Particle.
- 148 real-defect reclassification strokes: 73 Scratch, 69 Particle, 6 Residue.
- 149 false-detection strokes: 132 Other false evidence, 12 Holder or holder halo, 5 Noise or compression.

The saved response contains all eleven review tiles. Six tile comments are non-empty. No comment was duplicated across different tiles in the saved response; the current canonical app scopes its comment field to a tile, so a comment can remain visible while moving between fields in that tile.

## Operator findings to preserve

1. Tiny particles and scratches are now visibly detected.
2. A few genuine defects remain missed.
3. A grid effect appears at crop/tile boundaries.
4. Several accepted masks retain a small halo beyond the raw-visible footprint.
5. Some displayed accepted pixels fall outside the physical wafer on holder hardware.
6. Edge plating damage marked by the operator remains real defect evidence and must not be removed by a broad edge inset.

## Corrective contract

- Treat tile ownership, mask-footprint sizing, and physical eligibility as separate corrections.
- Do not raise the global presence threshold to remove these false pixels.
- Do not suppress evidence because it repeats at die pitch, direction, recurrence, or component size.
- Partition overlapping tiles by deterministic source-coordinate ownership so evidence is owned once without a crop-boundary seam.
- Let the target-excluded composite localize a candidate; raw native BF/DF support defines the accepted footprint and size.
- Apply complete wafer/holder/scribe/boundary eligibility before candidate formation while keeping compact raw-supported edge defects eligible through the physical edge zone.
- Preserve unsupported gaps as empty.
- Preserve frontside chipout/microchipout as a separate unchanged engine.
- Keep this feedback review-only and ineligible for training, XML, and production authority.

## Status

Feedback is frozen and audit-ready. No detector change is authorized by this intake checkpoint alone.
