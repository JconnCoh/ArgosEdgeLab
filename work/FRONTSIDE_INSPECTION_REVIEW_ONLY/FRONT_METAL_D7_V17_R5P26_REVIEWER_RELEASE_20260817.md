# Front-metal D7 V17 R5P26 returned composite and canonical reviewer release

Date: 2026-08-17

Disposition: `RELEASED_REVIEW_ONLY`

## Result

The exact signed FM7P26 JBOD result is returned locally at
`work/FM7P26/result/FM7P26_20260817T210000Z`. The returned set contains 94
declared result files plus `RETURN_GATE.json`; the return-gate SHA-256 is
`90A339E3D27BC0CD301CFFAD3E42FED68A7932B86E3A4B369277B46AE8B4209D`.
The signed `AUDIT.json` SHA-256 remains
`E0E6A30CCB66932A14611EF37C83D1922F0E41C4C7D5EF3C0121FDF8BAD71580`.

All eleven frozen S02 native fields completed. Each channel contains
45,577,863 fitted-physical-domain pixels and 7,222,137 rectangular crop pixels
outside that disk. BF and DF each have zero direct-native pixels and zero
unassigned valid inspection pixels. Outside-disk pixels are not inspection
coverage, not coverage holds, and not Normal or defect evidence.

The unchanged-threshold comparison produced 1,192,372 union residual pixels.
They have disposition `CONFIRM_FRONT_METAL_TARGET_EXCLUDED_RESIDUAL`. They are
class-neutral comparison evidence, not classified defects. The post-run V16
regression recovered all 57 saved missed-defect strokes and all 231 saved
real/reclassification strokes exactly, but it also overlaps 21 of 29 saved
false strokes exactly and all 29 within 64 pixels. Therefore this revision is
useful for operator review but is not autonomous defect authority.

## Reviewer

The released canonical-derived reviewer is
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM7P26_20260817T2150Z`.
Its `BUILD_RESULT.json` SHA-256 is
`2A6CAAAED02BEF480CD3A5EAFE9D29490E4E93423D8A588CF91E7791F44AD84A`.
Launch it with `START_FM7.cmd`.

The reviewer preserves the locked BowComp DOM/actions and byte-identical
canonical `styles.css`. Clean 1:1 BF and DF are locked clean-source rasters.
The current residual is a separate alpha layer. Imported V16 feedback is
loaded only as post-run guidance and is hidden by default; it was not
rasterized into any clean base or current heatmap.

The full-wafer default is the current residual in magenta. Cyan and orange are
alternate colors for the exact same residual mask; green is the fitted
physical scoring scope. Native panels show clean BF, clean DF, clean BF plus
current residual, and clean DF plus current residual. The prior large yellow
or gold route cells were robust-fallback coverage, not uncovered pixels; this
reviewer does not reuse those route colors as defect evidence.

The real-browser gate loaded exact review ID `FM7P26_20260817T2150Z`, kept
imported feedback hidden, exercised all five full-wafer views and all twelve
native layer toggles, and verified both `awaiting` and `all` queues cover 11 of
11 fields. T02, T16, T17, T21, T27, and T29 each loaded complete 2400 by 2000
clean BF/DF and exact current mask assets with zero browser console errors.
Raster provenance passed 39 entries: 24 clean bases, 15 current heatmaps, and
59 current-mask lineage verifications.

The earlier roots `FM7P26_20260817T2115Z`, `FM7P26_20260817T2125Z`, and
`FM7P26_20260817T2140Z` are explicitly `WITHDRAWN`. They are diagnostic only,
were not presented, and are ineligible as future parents.

## Authority and next action

No detector threshold, alignment transform, clean image, defect class,
automatic outcome, Normal outcome, training authority, XML authority, or
production authority changed. The next action is operator review of all eleven
native fields in the released page. Feedback may mark missed defects, false
detections, reclassifications, or display/alignment issues, but remains staged
until a separate evidence-backed successor is approved.
