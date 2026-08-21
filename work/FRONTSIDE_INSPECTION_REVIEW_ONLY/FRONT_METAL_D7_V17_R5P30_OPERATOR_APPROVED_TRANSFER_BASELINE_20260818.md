# Front-metal D7 V17 R5P30 operator-approved transfer baseline — 2026-08-18

## Operator decision

At 2026-08-18T15:29:41Z, after reviewing `FM7P30_20260818T1515Z`, the operator stated that the result looks good and directed that it be locked in for now. The next phase is testing on representative production wafers instead of the erratic old test wafers.

## Locked scope

R5P30 is now the `APPROVED_BASELINE` for a review-only production-wafer transfer study. The already presented reviewer remains immutable at:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM7P30_20260818T1515Z`

Its `BUILD_RESULT.json` SHA-256 is `A5387507FB292351E80454A9505E1B349DF7A22E121CC904FBD145567A80231C`.

The locked transfer method preserves:

- the R5P29 X24 greater-than-240 no-growth response;
- the pixel-local 384-source-pixel physical-edge protection, unchanged;
- removal only of complete eight-connected one-pixel components outside that protected band;
- no erosion or deletion of connected one-pixel-wide lines;
- no die-boundary suppression, because the strict boundary diagnostic qualified zero pixels;
- separate retained-candidate, removed-singleton, clean BF/DF, and imported-feedback layers.

## Known limitation

The inherited eight-pixel `T22_R04C01_STROKE_4_RESIDUE_8_PIXELS` location remains absent, so the sensitivity gate remains false. Operator approval locks the practical review appearance and transfer method; it does not convert this known exception to Normal truth or grant autonomous inspection authority.

## Production-wafer transfer gate

Production-wafer evaluation must use a fresh diagnostic output root and preserve R5P30 byte-for-byte. Select representative production wafers without first tuning from their defect pixels, retain physical wafer identity and BF/DF provenance, run the frozen alignment/composite/candidate method, and present all fields through the canonical reviewer. Any needed change becomes a new revision; it must not be patched into R5P30.

The transfer remains review-only. “Production wafer” describes the source material, not permission for production routing. No automatic Reject, Normal, training, XML, or production authority is granted.

## Next action

Inventory eligible front-metal production-wafer BF/DF pairs and freeze a representative transfer set by product/layer and wafer identity before scoring. Then run the unchanged R5P30 method as a fresh diagnostic successor, with particular attention to interior snow, faint-scratch retention, repeating die-edge discoloration, and physical perimeter behavior.
