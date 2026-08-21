# Front-metal D7 V17 R5P30 singleton-filter checkpoint — 2026-08-18

## Authority

- Revision: `FM7P30_20260818T1515Z`
- Reviewer disposition: `RELEASED_REVIEW_ONLY`
- Candidate disposition: `DIAGNOSTIC_ONLY_OPERATOR_REVIEW_PENDING_SENSITIVITY_GATE_NOT_PASSED`
- This revision is not training-, XML-, or production-eligible and emits no Reject or Normal outcomes.

## Operator-directed change

The operator directed that the existing R5P29 physical-edge protection remain unchanged until production wafers can be reviewed. R5P30 therefore preserves the 384-source-pixel (5.568 mm) pixel-local edge band exactly: all 98,001 protected candidate pixels remain present.

Outside that band, R5P30 removes only eight-connected candidate components whose complete area is exactly one source pixel. It performs no erosion and does not remove a connected one-pixel-wide scratch or other line.

## Result

- Parent candidate pixels: 187,023
- Removed interior singleton pixels: 2,127
- R5P30 candidate pixels: 184,896
- Operator-positive exact locations retained: 287/287 relative to R5P29
- Additional positive locations lost: 0
- Positive-pixel retention relative to R5P29: 99.9541115452%
- Saved-false exact locations still hit: 2/29

The inherited eight-pixel `T22_R04C01_STROKE_4_RESIDUE_8_PIXELS` exception remains absent from R5P29 and R5P30. The sensitivity gate therefore remains false even though this revision introduced no new exact-location loss.

## Die-boundary diagnostic

A deliberately strict repeating-boundary qualification was evaluated separately. It qualified zero components and zero pixels. No boundary pixel was suppressed. This is the fail-closed result: the rule was not loosened to force cleanup at the risk of masking a faint scratch.

## Verification

- Candidate audit: `work/FM7P30/audit/S1B1/AUDIT.json`
- Candidate audit SHA-256: `22BCC1FC2FEE5867F21B5B7B38D5FBE375CF08E62ABB9A4707B11317F3292CA1`
- Reviewer: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM7P30_20260818T1515Z`
- Build result SHA-256: `A5387507FB292351E80454A9505E1B349DF7A22E121CC904FBD145567A80231C`
- Final raster manifest SHA-256: `F0B34951BADE805D91A48C5ACF28F31723D0A884EE52B5FEAF4D45A833167761`
- Render audit SHA-256: `1EC25F40E05BD0CB386856E8CF5372693AE42155C64A061FAC737B53311E4CCD`
- Raster provenance release gate: PASS, 48 entries, 24 clean bases, 24 heatmaps, 46 masks
- Real-browser gate: PASS, exact revision, 11/11 eligible fields in both queues, six native fields and all five native view modes exercised, zero console errors

## Next action

The operator reviews R5P30 across all 11 native fields, using the yellow singleton-removal layer to audit exactly what was removed. Do not change the 384-pixel edge protection until representative production-wafer evidence is available. The repeating die-edge discoloration band remains an unresolved diagnostic problem and is not suppressed in this revision.
