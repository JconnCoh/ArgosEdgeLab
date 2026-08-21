# Front-metal canonical feedback footprint checkpoint — 2026-08-11

## State

`PASS_FRONT_METAL_FEEDBACK_FOOTPRINT_AUDIT_REVIEW_ONLY`

This checkpoint audits the operator-saved native-coordinate feedback from the
canonical BowComp-derived reviewer. It changes no detector, mask, threshold,
model, XML, bin, or production authority.

## Exact inputs

- Feedback:
  `human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260811T172156Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`
- Feedback SHA-256:
  `D642D9F64F0F45BDF8CB3518DCD49E6A42AA05B1AF5E62942973D99467DEB320`
- Review manifest:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FRONT_METAL_CANONICAL_NATIVE_TILE_FEEDBACK_V1_5_20260811T182500Z/REVIEW_MANIFEST.json`
- Audit result:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FRONT_METAL_FEEDBACK_FOOTPRINT_AUDIT_V1_20260811T174346Z/FRONT_METAL_FEEDBACK_FOOTPRINT_AUDIT.json`
- Audit-result SHA-256:
  `BDA1C6C610F601808763B9CB8D046C5461FE03E4C7B6C3A0AAB34D247DB9FC6A`

## Operator feedback consumed

The response contains 74 strokes: 70 missed-defect strokes and four
false-detection strokes.

- 53 `Scratch` strokes: 38 marked on raw BF and 15 on raw DF.
- 8 `ResidueStreak` strokes.
- 5 `Contamination` strokes.
- 4 `Residue` strokes.
- 4 false-detection strokes on T21. The operator comment identifies these as
  the scribe, not a defect. They are retained as exact scribe-nuisance controls.

The T17 comment confirms defect presence for the small speck but explicitly
allows bounded ambiguity among contamination, particle, and residue
association. It is not negative truth and must not be forced into Scratch.

## Footprint audit method

The human paths are treated as approximate raw-visible footprints. Their
brush width is included, so measured enhancement expansion is conservative
when the operator stroke is slightly wider than the visible defect.

Two co-registered display-only layers were compared against every path:

- seam-corrected target-excluded DF residual, using signed-distance magnitude
  thresholds 16, 24, and 32 around neutral gray 128;
- strict-zero-peer DF localization support, using intensity thresholds 16,
  32, and 64.

For each threshold, the audit measures overlap and the connected enhanced
support touching the human path. The enhanced footprint is projected onto
the human path's principal and transverse axes. This is an evidence audit,
not physical-size truth.

## Scratch-only result at the middle audit thresholds

| Human principal span | Scratch strokes | Residual attached | Residual median length / width / area ratio | Strict-zero attached | Strict-zero median length / width / area ratio |
|---|---:|---:|---:|---:|---:|
| Tiny, ≤24 px | 17 | 12 | 2.42 / 3.06 / 6.69 | 7 | 0 / 0 / 0 across the full group |
| Short, 24–80 px | 17 | 17 | 3.01 / 4.69 / 12.62 | 12 | 0.62 / 1.86 / 0.95 |
| Long, >80 px | 19 | 17 | 1.62 / 2.62 / 4.85 | 16 | 1.06 / 1.91 / 1.98 |

The zero medians in the tiny strict-zero row mean that a majority of tiny
marks had no attached threshold-32 strict-zero support; they do not mean a
zero-size physical defect.

## Interpretation locked by this checkpoint

1. Enhanced panels remain localization aids, not physical footprint or die-bin
   geometry. This is especially strict for tiny defects. The residual footprint
   is several times the already-slightly-wide human footprint.
2. For long scratches, strict-zero-peer support is useful: its median
   longitudinal extent is close to the raw-marked extent (1.06×), while its
   transverse extent is still broadened (1.91×). It may propose where to inspect
   along the scratch, but raw native BF/DF must define the final affected pixels.
3. The seam-corrected residual supplies valuable high-recall localization but
   carries a broad halo in both axes. Any residual-only longitudinal extension
   beyond a human/raw trace remains a hypothesis until native raw BF or DF
   corroborates it.
4. A final physical-damage mask should therefore use enhanced evidence to find
   candidate corridors, then recover only the directly raw-supported pixels
   inside those corridors. It must not paint the enhanced blob or infer a
   complete line across unsupported gaps.
5. Physical damage remains the model concept; the requested production bin may
   be `Scratch`. Small or round physical damage is not excluded from that bin.
6. The four T21 controls require exact scribe exclusion. They do not authorize a
   broad edge, angular, or radial exclusion.
7. The T17 ambiguous speck remains a real-defect presence signal with a
   class-specific contamination/particle/residue-association hold if autonomous
   class confidence is insufficient.

## Authority

- Review only: yes.
- Human feedback applied automatically: no.
- Detector or mask changed: no.
- Training performed or eligible: no.
- XML or production eligible: no.

