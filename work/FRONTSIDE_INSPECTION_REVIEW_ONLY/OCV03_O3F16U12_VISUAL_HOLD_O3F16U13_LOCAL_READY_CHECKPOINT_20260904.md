# OCV-03 O3F16 U12 visual hold / U13 local ready — 2026-09-04

Disposition: `PENDING_GATE`

The one authorized U12 read-only return completed on its first publication.
Matching response `R_C6592AF3282C_20260904133455935_5ccc11ad` verifies against
the pinned JBOD signer and is terminal `PASS_DATA_PULL`. The returned archive
hash-matches the launch response: 134,273,367 bytes, SHA-256
`5B80DBF6F71E2DF01D8850F2D2301C9DBE27D258416D2058E5F93DEE9FD3C4F2`.
`SUMMARY.json` SHA-256 is
`7B5760BEBFB4C5096201A8D81535D27807D6EA6331510BC85C194065303A8CBC`;
all 80 declared assets verify with zero mismatches.

Ultra inspection covered every R12 BF/DF edge-review, damage-review, and full
band. Numeric 0/360 continuity is clean at a maximum one-pixel cyclic step and
the 2,048-column boundaries are presentation cuts, not geometric stitches.
However, U12 is not visually approved: R12 draws long held/interpolated spans
as a magenta edge path, the 49-row narrow review clips wider notch/fixture
context, and neither notch nor rear-holder geometry is classified. The
236-row full band retains the physical edge relief and shows the large
notch/fixture sectors, but any measured response inside dark or contaminated
regions remains diagnostic only. Gate
`work/OPENCV_EDGE_UNWRAP_O3F16U12/O3F16U12_PULL_TERMINAL_VISUAL_GATE.json`,
SHA-256 `F41EA5ADDAC954299971BD733775D4D023F97F8519826DBA10531F63D62214F4`,
records the terminal provenance and visual hold.

Fresh R13 SHA-256
`35940B211AEB51898B7BA9F279004D404D1C0AF2013B933414D1F58B30EF7748`
does not change R12 tracking, thresholds, or selectors. It adds review-only
CLAHE, a clean 236-row full-band review, red measured points only, a separate
held-column mask, and a three-row magenta semantic bar without drawing held
interpolation through the image. The exact eight BF/DF U12 intermediates pass
the local render gate; raw clean-band hashes remain unchanged. All eight
R13 full-review and edge-review sheets were inspected at original detail.
Gate `work/OPENCV_EDGE_UNWRAP_O3F16U13/O3F16U13_LOCAL_REVIEW_RENDER_GATE.json`,
SHA-256 `1E5CEAE8319BD183682E4E981715BEE210793CD84EFA8DB6EA31FF9B5C61E852`.

## Next action

Use the unchanged recorded Project Portal route exactly once to install exact
R13 only in the existing JBOD development root and run the same four pinned
cases into fresh `D:/O3F16U13`. Do not retry if that unchanged route fails.
Pull only the matching fresh archive, verify every declared hash, and inspect
all eight BF/DF clean full-band, enhanced full-band, edge, hold-mask, and
damage-review assets at original detail. Require R12-identical tracking metrics,
honest held-column rendering, visible edge/notch/fixture context, and no new
stitch discontinuity before any broader test.

If U13 passes, run the frozen POST2 Slots01/03/17 regression, then identify and
run the exact genuine microchipout lot before any targeted-11 or 978 expansion.
The exact microchipout lot identity remains pending. T5, targeted-11, 978,
scribe, source mutation/deletion, existing task/process action, provider
activation, automatic hold clearance, retry, training, XML, and production
remain unauthorized.
