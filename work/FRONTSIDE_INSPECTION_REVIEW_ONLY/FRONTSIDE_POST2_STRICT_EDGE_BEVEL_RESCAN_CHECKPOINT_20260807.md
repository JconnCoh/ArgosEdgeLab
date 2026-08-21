# POST2 frontside strict edge / bevel rescan checkpoint — 2026-08-07

## Outcome

A fresh native-resolution, full-circumference BF/DF rescan was completed for
`62546-481_POST2_SLOT01`, `62546-481_POST2_SLOT03`, and
`62546-481_POST2_SLOT17` after the operator classified the prior 22 narrow
micro candidates as `NOT_DAMAGE` and `Slot01_CHIPOUT_001` as
`CONFIRMED_DAMAGE`.

The corrected physical-edge rule retained the known Slot01 chipout, suppressed
all 22 operator-confirmed noise controls, and produced only two new
confirmation-only edge survivors. Both new survivors are on Slot01 at image
angles 160.435513 and 162.708891 degrees. Slot03 and Slot17 have no surviving
chipout candidate. No wafer has a surviving bevel-damage candidate.

This is a review-only result. The two new Slot01 locations are not automatic
rejects and must not become damage truth without human confirmation.

## Physical distinction applied

The earlier narrow candidates could be driven by patterned/bevel intensity
transitions without demonstrating displaced physical wafer boundary. The
corrected rule requires the observed inward displacement corridor to be
occupied by outside-dark pixels in both BF and DF, in addition to independent
BF/DF boundary support. This preserves the known large chipout while excluding
the 22 reviewed narrow-noise controls.

- source scoring: original `14411 x 10995` lossless BMP pixels at 1:1 scale;
- circumference coverage: complete;
- resampling before scoring: none;
- frontside holder mask: none;
- fixed-angle/deepest-indentation notch decision: none;
- minimum BF outside-dark corridor fraction: 0.65;
- minimum DF outside-dark corridor fraction: 0.40;
- minimum corridor-supported connected-arc fraction: 0.35;
- bevel path: minimum 30-source-pixel connected arc, BF/DF supported,
  confirmation-only;
- tiny isolated bevel specks: ineligible.

## Per-wafer result

| Identity | Chipout confirmations | Bevel-damage confirmations | Disposition |
| --- | ---: | ---: | --- |
| `62546-481_POST2_SLOT01` | 3 | 0 | one known positive control plus two new review holds |
| `62546-481_POST2_SLOT03` | 0 | 0 | no strict survivor |
| `62546-481_POST2_SLOT17` | 0 | 0 | no strict survivor |

The native run manifest records 22/22 operator-confirmed negative controls
suppressed and the one known positive control retained.

## Review artifact

The compact review page contains exactly three raw native BF/DF cards:

1. the previously confirmed Slot01 large-chipout control;
2. Slot01 at 160.435513 degrees;
3. Slot01 at 162.708891 degrees.

No heatmap or bounding box covers the evidence. The page is:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/POST2_FRONTSIDE_STRICT_EDGE_BEVEL_REVIEW_V2_20260807T224500Z/POST2_FRONTSIDE_STRICT_EDGE_BEVEL_REVIEW.html`

## Traceability

- native rescan:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/POST2_FRONTSIDE_STRICT_EDGE_BEVEL_RESCAN_V1_20260807T223000Z`
- prior human response:
  `C:\Users\joshua.conn\Downloads\POST2_FRONTSIDE_EDGE_REVIEW_RESPONSE.json`
- prior response SHA-256:
  `D492B04F2F8F1A1D9E7F5E425A1F5FB75D43E1915E822001AE552711E37E4FB1`
- review page manifest:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/POST2_FRONTSIDE_STRICT_EDGE_BEVEL_REVIEW_V2_20260807T224500Z/REVIEW_MANIFEST.json`

All outputs remain review-only, training-ineligible, XML-ineligible, and
production-ineligible.
