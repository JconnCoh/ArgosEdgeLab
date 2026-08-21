# Front-metal D7 V17 R5P25 S02 11-field residual gate checkpoint — 2026-08-17

- Disposition: `PENDING_GATE`
- Planned revision: `FM7V17R5P25`
- Parent reference baseline: `FM7V17R5P24A_COMPOSITE_BASELINE`
- Target identity: `62546-481_POST2_SLOT02`
- Reference identities: the other 11 R5P22-qualified wafers; target self-reference is prohibited.

## Purpose

The approved R5P24A strict-plus-fallback composite is a reference engine, not a defect outcome. R5P25 is the smallest bounded successor that can test its defect sensitivity and over-detection behavior against existing operator-reviewed evidence without first multiplying an unvalidated detector presentation across all 12 wafers.

## Frozen method

- Consume the exact R5P21 independent BF/DF rigid transforms under the unchanged R5P22 stability adjudication.
- Preserve the R5P24A 128-pixel route cells, global photometric normalization, strict unique-clique reference, target-excluded one-low/one-high trimmed fallback reference, and 4-DN residual deadband.
- Require zero direct-native and zero unassigned valid pixels in every bounded field.
- Score target BF/DF at native `14411 x 10995`, scale X/Y `1.0`; reference interpolation does not resample the target.
- Emit BF and DF peer-median references, outside-envelope residuals, strict/fallback route rasters, and a class-neutral union residual evidence mask.
- A nonzero residual is only `CONFIRM_FRONT_METAL_TARGET_EXCLUDED_RESIDUAL`. It is not an automatic Reject, Normal, Scratch, Residue, Particle, Contamination, or training label.
- Do not consume M3 classification, old V16 masks, saved feedback, grid pitch, grid direction, recurrence, inferred geometry, or component size as a detector input or veto.

## Bounded fields

The gate covers the exact eleven native S02 fields already exposed in the canonical V16 review. Coordinates are S02 source pixels and use exact 2400 by 2000 scoring rectangles:

| Field | Left | Top | Width | Height |
|---|---:|---:|---:|---:|
| T02_R00C01 | 4144 | 224 | 2400 | 2000 |
| T03_R00C02 | 6304 | 224 | 2400 | 2000 |
| T07_R01C01 | 4144 | 2024 | 2400 | 2000 |
| T08_R01C02 | 6304 | 2024 | 2400 | 2000 |
| T09_R01C03 | 8464 | 2024 | 2400 | 2000 |
| T16_R03C00 | 1984 | 5624 | 2400 | 2000 |
| T17_R03C01 | 4144 | 5624 | 2400 | 2000 |
| T21_R04C00 | 1984 | 7424 | 2400 | 2000 |
| T22_R04C01 | 4144 | 7424 | 2400 | 2000 |
| T27_R05C01 | 4144 | 8672 | 2400 | 2000 |
| T29_R05C03 | 8464 | 8672 | 2400 | 2000 |

## Gate sequence

1. Build and rehearse the exact portable package under Windows PowerShell 5.1.
2. Execute the signed review-only package on JBOD and retrieve the complete result with hashes.
3. Require zero blank/unassigned/direct-native valid pixels in all 11 BF/DF fields.
4. Audit the new residual masks against the saved S02 operator review only as regression evidence; the saved review cannot alter the new mask.
5. Build a canonical BowComp-derived file-backed reviewer with raw BF/DF, composite references, residuals, route provenance, and the class-neutral confirmation layer.
6. Only after review may the unchanged detector be proposed for a 12-wafer transfer.

## Authority limits

This is bounded diagnostic coverage, not full-wafer coverage, full-lot coverage, negative truth, autonomous classification, XML authority, training truth, or production authority. The existing V16 reviewed outcomes remain separate and must not be presented as outputs of R5P25.
