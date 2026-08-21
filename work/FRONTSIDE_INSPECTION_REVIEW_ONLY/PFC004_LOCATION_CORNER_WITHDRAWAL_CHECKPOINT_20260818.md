# PFC004 invalid holdout-location withdrawal and corner-mask gate

Date: 2026-08-18

Revision: `PFC004_LOCATION_CORNER_CORRECTION_GATE`

Disposition: `PENDING_GATE`

## Operator correction

The operator rejects `PFC004_EHOLD1` because the presented location is an
ordinary random die feature, not the designated primary robust crosshair
topology. The operator also identifies that the inner corners remain exposed
to the detected-line presentation. The operator does not assert whether that
corner exposure changed the result, but both inner and outer corners were
intended to be ignored.

The exact semantic correction is locked at
`work/PATTERNED_FIDUCIAL_INVENTORY/feedback/PFC004_OP11/OPERATOR_FEEDBACK.json`,
SHA-256
`B2454155973030DCBA4A5EEC9F9A16F74B01BF36782C892D24E4DDB5F1DC5ABC`.
The file-backed screenshot is 588 by 492 pixels, 109,146 bytes, with SHA-256
`500DCE7746E5504DDD629CEA4855582C279BBF06C550608A48AEA9B5711012AE`.
No image bytes are embedded in this checkpoint.

## Product XML is correct; its use as a topology binding was not

PFCP1E binds PFC004 product `1470174/A00` to `maps/1470174.xml`, SHA-256
`B788FA33652D55732E1088A6A765BAAD62692FB0F97317F1192B6AE140992887`.
Local `Wafer_AVI_Templates/3357.xml` has that exact hash and declares
`LayoutId=1470174`. Its filename is the substrate ID; its content is the
correct product layout. No wrong-product XML was used.

The failure was a location-lineage error. The source crop was centered on
bin-34 DS9K map coordinate `(96,121)`, projected to full-wafer coordinate
`(7891.829288575311,5955.471767318508)`. The operator-selected crosshair is at
exact full-wafer coordinate
`(7085.892353937178,6073.677979657187)`, about 806 pixels left and 118 pixels
below that crop anchor, a total displacement of 814.559 pixels. The crop
manifest never bound that crosshair to bin `(96,121)`.

The invalid holdout transported that unexplained offset to the next bin-34
coordinate `(120,121)`, yielding native-crop coordinate
`(2478.545828269987,1408.312974712738)`. That arithmetic is exact, but the
recurrence assumption is false and was never authorized by the product
contract or verified from the complete nonrepeating topology.

An inverse XML-coordinate audit places the operator-selected crosshair near
continuous map coordinate `(82.959012,123.440007)`. Its nearest recorded die
is `(83,123)`, bin `1`, 20.459 pixels from the projected die center. The
nearest bin-34/bin-36 special coordinate is `(72,121)`, bin 34, 687.231 pixels
away. Therefore neither bin 34 nor bin 36 locates this within-die topology.
The product XML may nominate a die or crop window, but it contains no exact
crosshair-topology binding.

## Corner exclusion was displayed but not enforced

`PFC004_12LINE_V1` shortens every nominal segment by two pixels at each end.
That is only an along-line endpoint trim. `Pfc004EdgesV4` does not load the
yellow corner-exclusion mask, does not carry an exact corner vertex/mask hash
in its input, and does not reject a sample when its complete interpolation and
gradient-profile footprint intersects a corner neighborhood. With a profile
extending from two pixels outside to four pixels inside the nominal edge,
endpoint trim alone cannot prove that rounded or blurred corner response has
zero pose influence.

The earlier `identityCornersAndArrowTipsPoseWeight=0` claim is revoked. The V4
development pass remains useful only as exact-pixel `DIAGNOSTIC_ONLY` evidence;
its all-line-pass conclusion is not eligible for promotion until the scorer
consumes an explicit inner/outer corner exclusion and the development is
refit.

## Withdrawals

The machine-readable withdrawal is
`work/PATTERNED_FIDUCIAL_INVENTORY/withdrawals/PFC004_EHOLD1_INVALID_LOCATION_20260818/WITHDRAWAL.json`,
SHA-256
`FB00DD703071C6AB4D23C7EB1E41F6A57F42BB5D7AB18726E8D8FB2B90819078`.

The following are preserved but withdrawn from validation or successor
authority:

- `work/PATTERNED_FIDUCIAL_INVENTORY/inputs/PFC004_EHOLD1.json`;
- `work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_EHOLD1`;
- `work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_EDEV4/FROZEN_MODEL.json`;
- `work/PATTERNED_FIDUCIAL_INVENTORY/tools/Pfc004EdgesV4.cs` and its compiled
  executable for any further holdout or fanout use;
- the same-wafer holdout conclusion in
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/PFC004_NATIVE_EDGE_SAME_WAFER_HOLD_CHECKPOINT_20260818.md`.

`PFC004_EHOLD1` was never a valid holdout, so it is not a consumed holdout and
does not establish a detector failure. Its random-feature line metrics must
not drive any threshold or geometry adjustment. `PFC004_EDEV4/AUDIT.json`
remains `DIAGNOSTIC_ONLY` at the correct exact operator-selected pixel
location; it does not retain a frozen-model pass.

## Required sequence

Current phase is `PFC004_FIDUCIAL_INSTANCE_LOCATION_AND_CORNER_MASK_GATE`.

First locate additional complete instances of the operator-designated
crosshair topology without transporting an unproven XML-bin offset. A map or
die coordinate may only nominate a search window; the full nonrepeating
crosshair/arrow topology must confirm identity at native resolution.

Second build a fresh line model with an explicit locked mask for all 12 inner
and outer vertices. The scorer must reject every sample whose complete
gradient-profile footprint intersects the mask and must prove that arbitrary
pixel changes inside the ignored mask leave pose and all line metrics
unchanged. Then refit a development set before reserving a genuinely untouched
same-wafer holdout.

Only after a frozen same-wafer holdout passes may the unchanged model fan out
to multiple wafers. Fresh alignment transfer remains later, and production-
wafer defect scoring remains blocked. This current gate plus the 11
pre-existing top-level `PENDING_GATE` objects, other 30 category rows, 20
other crop-ready designations, one map hold, and nine pose holds remain in
order. R5P30 remains immutable. No template, alignment, defect, Normal,
training, XML, production, or routing authority is created.
