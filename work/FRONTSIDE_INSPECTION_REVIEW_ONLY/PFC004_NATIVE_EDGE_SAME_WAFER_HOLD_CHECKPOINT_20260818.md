# PFC004 native 12-line same-wafer holdout gate

Date: 2026-08-18

Revision: `PFC004_NATIVE_EDGE_V4_SAME_WAFER_GATE`

Disposition: `PENDING_GATE`

## Operator inventory accepted

The operator confirmed that the `PFC004_12LINE_V1` guidance accounts for the
intended straight lines. The locked model contains six horizontal and six
vertical line slots. The saved pink strokes remain presence nominations only;
their positions, endpoints, widths, and centerlines are not pixel truth.
Corners, inward-arrow corners, and arrow tips retain zero pose weight.

The inventory is
`work/PATTERNED_FIDUCIAL_INVENTORY/review/PFC004_12LINE_V1/TWELVE_LINE_INVENTORY.json`,
SHA-256
`3CBBD2BEE282BD5781014C25EF0F809F9DDCE23716C3C8A21DC5D4D29CFF11CE`.

## Reused method and corrected development failures

The native fitter reuses the accepted `CoreLines.cs` method: native 1:1 sample
spacing, first stable gradient crossing from the declared outside toward the
dark interior, robust straight-line refit, direct-support accounting, maximum
gap, residual, response-width gates, and one-pixel rendering only over
contiguous accepted support. BF and DF are fit independently. Scoring does not
use rotated pixels, channel-pose averaging, corner evidence, display scaling,
or unsupported gap fill.

Three create-new development attempts are preserved as `DIAGNOSTIC_ONLY` and
are ineligible for promotion:

- `PFC004_EDEV1`, audit SHA-256
  `08762A6918CA4954C15652DBF73BB2F0A0BF7B22ACD619F8B394DD1D31642A16`,
  exposed a comparator that allowed one fully gated short edge to outrank
  broad 12-line topology support.
- `PFC004_EDEV2`, audit SHA-256
  `1161744537E2D76A953B5737A9473A1DBE34A3BCD0CA376FEA3A1B7CDF9C9400`,
  corrected the comparator but retained the historical shared 12-DN floor.
- `PFC004_EDEV3`, audit SHA-256
  `947CFB47FC937FF5E76AF6C59B0A5969E34197C9391276F72D62C08711C701D5`,
  added exact nomination metrics and proved that the intended nominal edges
  do not reach that old floor. It also exposed the rotated integer-length
  endpoint-count loss.

No frozen model was emitted by those attempts. Direct profile audit on the
locked development exemplar measured BF midpoint peak gradients of 6.74 to
9.45 DN, median 7.92, and DF peaks of 1.18 to 2.37 DN, median 1.77. The old
shared 12-DN minimum therefore does not transfer to this average plated-wafer
evidence. V4 changes only the independent absolute channel floors to BF 4.0
and DF 0.75 and preserves the prior local 0.80 fraction, 0.75-pixel residual,
0.95 support, one-pixel maximum gap, two-pixel P90 width, and all other
geometry rules. The endpoint-inclusive sample count uses a numerical epsilon;
it does not invent samples or lengthen a segment.

The exact V4 source SHA-256 is
`4365592C39A51CA6594AE824814ABE8E240A70A3EDC83723BD88D174D10C1F3E`;
the executable SHA-256 is
`E9BBE72D313C196BF3D625BACCC2EA3E550C4850CA67A79C6381297CFB831DE7`.

## Development result

`PFC004_EDEV4` used map `(96,121)` at locked native-crop nomination
`(993.892353937178, 1418.677979657187)`. Input SHA-256 is
`0D4F6548F4D136954ED9C22E98ABB1B931C5175982574EFF27D3F2081B74901D`.

The BF fit passes 12/12 lines at center
`(994.142353937178, 1417.927979657187)` and image angle 41.8 degrees. Its
minimum support is 1.0, maximum gap zero, maximum P90 residual
0.151111 pixels, and maximum P90 width 1.75 pixels. The independent DF fit
passes 12/12 at center `(993.392353937178, 1417.677979657187)` and image angle
44.4 degrees, with minimum support 1.0, maximum gap zero, maximum P90 residual
0.373333 pixels, and maximum P90 width 1.55 pixels.

The development audit SHA-256 is
`9716235950FAF8CB962A017396E3A0BFDA661013125413686FC4DCE3BD508585`.
It emitted frozen model SHA-256
`B65C832F492689DDE2E86C1D2AFFB88FA7DEF9A8DDAA5DC7C5A160DF0E8BC0E1`
before any holdout input was consumed. This frozen model remains
`DIAGNOSTIC_ONLY`; it is not a passed same-wafer model.

## Untouched holdout result

The sole other map-consistent bin-34 site inside the locked 3600-by-2600 crop
was reserved as holdout. Its map coordinate is `(120,121)`. Its nomination is
the exact operator-selected development center plus the 24-device displacement
from the locked 897-micron device pitch, 14.5-micron pixel pitch, and qualified
-0.4-degree notch-relative map rotation. It is native-crop coordinate
`(2478.545828269987, 1408.312974712738)`. The map only nominated this search
window; it did not establish topology or pose.

The sealed holdout input SHA-256 is
`07B663AA12786B49AF17C79E7B6D5BE78D62562B27043E420552BD434F2E1DDD`.
Preflight hash-matched the frozen model and confirmed that no parameters or
safety flags changed. The fixed run then returned
`HOLD_UNTOUCHED_HOLDOUT_NATIVE_EDGE_METRICS`:

- BF found at least half direct support on all 12 slots, but only 3/12 lines
  passed. Minimum support was 0.555556, maximum gap four pixels, maximum P90
  residual 2.269925 pixels, and maximum P90 width 2.15 pixels.
- DF found at least half direct support on all 12 slots, but only 7/12 lines
  passed. Minimum support was 0.555556, maximum gap two pixels, maximum P90
  residual 2.916667 pixels, and maximum P90 width 1.3 pixels.
- The measured per-line gradients are above the frozen channel floors. The
  failure is spatial continuity/residual evidence, not an absent-gradient
  failure. Lowering gradient, support, gap, residual, or width gates is not an
  authorized recovery.
- The best BF center is offset about 10.2 pixels from the map nomination. The
  best DF angle reaches the lower boundary of the frozen angle search. This is
  diagnostic localization evidence, not permission to enlarge the holdout
  search or retune on it.

The holdout audit SHA-256 is
`0D71E3258685BB26D67DF2AD0F8733F2C44DA62EACEC947841943FE864DEE2FB`.
The file-backed comparison sheet is
`work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_EHOLD1/HOLDOUT_EDGES_4X.png`,
SHA-256
`E2397559D3847AEA07B70F8B75EC22605A4CA5E8FE312942C38A659A8165002E`.
It is diagnostic only.

## Required sequence

Current phase is `PFC004_NATIVE_EDGE_SAME_WAFER_HOLD`.

The consumed holdout may be used only as labeled diagnostic/development
evidence for a future method revision; it can never validate that revision.
Before any adjustment, acquire additional native PFC004 evidence that provides
at least one genuinely untouched same-wafer fiducial after development is
frozen. The current locked crop contains no third map-consistent bin-34 site,
and its recorded full native BF/DF source paths are not locally accessible.
Do not tune this V4 model on `PFC004_EHOLD1`, do not rerun it as a passing
holdout, and do not begin multi-wafer fanout.

After a fresh development revision passes a genuinely untouched same-wafer
holdout, fan out the unchanged model to multiple representative wafers. Only
after that review-only transfer passes may a fresh alignment-transfer test be
considered. Production-wafer defect scoring remains later and blocked. The 11
pre-existing top-level `PENDING_GATE` objects, other 30 category rows, 20 other
crop-ready designations, one map hold, and nine pose holds remain in order.
R5P30 remains immutable. No template, alignment, defect, Normal, training,
XML, production, or routing authority is created.
