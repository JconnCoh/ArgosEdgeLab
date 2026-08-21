# PFC004 operator-declared 12-line presence inventory gate

Date: 2026-08-18

Revision: `PFC004_12LINE_V1`

Disposition: `DIAGNOSTIC_ONLY`

## Locked operator input

The operator declares that this fiducial contains 12 straight lines. The 12
saved pink strokes mean only that a straight line exists in each approximate
region and must be accounted for. Their placement, endpoints, widths, and
centerlines are explicitly not exact geometry truth.

The marked file differs from the clean presented image at exactly 1,638
pixels. All changed pixels are RGB `#FFAEC9`, they form exactly 12 separate
eight-connected strokes, and there are zero other changed pixels. The clean
baseline was reconstructed byte-for-byte with its original SHA-256
`62A9E87876B065CBAA4A36CF05D465FDF4C5FA9439BD3044280BB11EC23F7193`.

The exact semantic feedback is locked as `PFC004_OP10` at
`work/PATTERNED_FIDUCIAL_INVENTORY/feedback/PFC004_OP10/OPERATOR_FEEDBACK.json`,
SHA-256
`4E37219B8249E8A08BEE049582E7B5D2DAAE5B9E6D5B3EF37FC081045F6333B6`.

## Fourteen raw runs reconcile to twelve lines

The earlier broader extractor count of 14 described thresholded raster runs,
not 14 physical lines. Two operator-nominated lines each split into two
one-pixel-connected fragments after straightening and thresholding:

- the bottom-left vertical line has adjacent fragments at x=96 and x=95;
- the left-upper horizontal line has adjacent fragments at y=93 and y=94.

Those are consolidated only because their observed pixels are one-pixel
connected and belong to one operator nomination. No proximity-only merge is
used. The resulting semantic inventory contains exactly six horizontal and
six vertical lines.

## New 12-line guidance

The fresh root is
`work/PATTERNED_FIDUCIAL_INVENTORY/review/PFC004_12LINE_V1`. Green shows all
12 proposed axis-support segments. Yellow marks the small excluded
neighborhoods at the 12 inner/outer corner vertices, and magenta shows the
40-by-40 working box. The green centerlines and endpoints are bounded search
initialization only; native clean BF/DF fits must determine actual geometry.
Corners and arrow tips retain zero pose weight.

The 1X overlay changes 356 pixels, all inside the working box: 156 magenta,
108 yellow, and 92 green. The 4X view is exact nearest-neighbor enlargement
with zero mismatched pixels. The guidance hashes are:

- 1X: `B0483B9ED39AFEA7A21C38DDDEDEECF0A5211FAED4F3B6AFE8D1CCD10DA7BEE5`;
- 4X: `B1AF190E84CAEF46F0629509305746DEE2A463B1F5E9F11EE8624A891E14575D`.

The full audit is `AUDIT.json`, SHA-256
`30B56D57CE42384133E9A8948F91D1E67EBB4E53B8E50E1ADD01845724ABC23F`.
Raster-provenance preflight passed four entries, two clean bases, two current
guidance composites, and two masks. This is a file-backed diagnostic image,
not a released browser reviewer; no rendered-browser audit or reviewer
authority is claimed.

The initially planned longer output root was rejected before write at an
effective path length of 203. The shortened root passes with 32 suffix
characters reserved and a maximum effective path length of 167.

## Required sequence

Current phase is `PFC004_OPERATOR_12_LINE_PRESENCE_INVENTORY_GATE`.

First obtain operator confirmation that the green inventory accounts for all
12 intended lines. Then fit each inventoried line independently on clean
native 1:1 BF and DF evidence across a bounded same-wafer development set and
an untouched same-wafer holdout set. A missing or weak required line remains
an explicit hold; no line may be completed through an unsupported gap. Do not
tune on the holdout set.

Only after the frozen same-wafer holdout passes may the unchanged method fan
out to multiple wafers. Native edge detection, same-wafer testing, and
multi-wafer fanout have not started. No template authority, distributed phase,
alignment transfer, defect scoring, Normal outcome, training truth, XML, or
production authority is created.

The 11 unresolved `PENDING_GATE` objects, other 30 category rows, 20 other
crop-ready designations, one map hold, and nine pose holds remain in their
existing prerequisite order. R5P30 remains immutable.
