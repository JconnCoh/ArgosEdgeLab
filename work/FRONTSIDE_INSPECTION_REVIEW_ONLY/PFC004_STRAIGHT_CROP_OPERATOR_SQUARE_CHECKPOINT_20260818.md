# PFC004 straightened native fiducial crop — operator square pending

Date: 2026-08-18

Revision: `PFC004_STRAIGHT_CROP_V2_20260818`

Disposition: `RELEASED_REVIEW_ONLY`

## Result

PFC004 remains bound to the exact qualified full-wafer notch pose and locked
native BF/DF crop. The operator's earlier screenshot was used only to choose a
bounded neighborhood; it was not used as native-pixel, pose, template, or
detector authority.

The long orthogonal device-edge angle was measured independently from the
locked native BF and DF crop. Both channels returned `43.55` degrees modulo
90, with `0.0` degree BF/DF disagreement. A 1200 by 900 selection view was
then rotated by `-43.55` degrees at one source pixel per output pixel. Rotation
resampling is explicit; the locked native sources remain unchanged. The exact
affine map from the straightened view to the native crop and full-wafer frame
is stored in `OPERATOR_SQUARE_PENDING.json`.

The BF selection axis verifies within the bounded two-degree measurement
kernel. The paired DF view receives the identical affine transform, but its
post-rotation low-frequency axis is not the dominant DF appearance response.
This does not grant DF pose authority: final BF/DF edge qualification remains
blocked until the operator supplies the small square.

## Locked artifacts

- source manifest SHA-256:
  `18A7DD070D2299767D1955A29300BF170A7709A7A7E85CE45B0B0E600E000EB2`;
- native BF crop SHA-256:
  `4EBBD4FB322F3EF55414C92C5CB1A4741D6319648C7E167BF4D69486D230638D`;
- native DF crop SHA-256:
  `7F4785B389212B64B2A7EF5A1262A73430895071FC747EDDC2C930CFE663C831`;
- straightened BF SHA-256:
  `3CAB43EE85B1CFF3AF15CDCD0EFE4CEE7E3E946227031DEBB9B827D25A85F16C`;
- straightened DF SHA-256:
  `38F01AE75B3BBE07C15443BA60CD33185E8360C0679180EAB278A299B1DE5247`;
- build audit SHA-256:
  `0DEA703A6D52B53A2B57A64CF7BAE8D4CB7941DC37212510676360A62AF9853D`;
- coordinate-map manifest SHA-256:
  `8F7255DE3139682B7B91E93147BBC644F878CAAE4E2916F3757790D0FF05625B`;
- initial OP3 feedback canvas SHA-256:
  `3CAB43EE85B1CFF3AF15CDCD0EFE4CEE7E3E946227031DEBB9B827D25A85F16C`;
- OP3 pending-feedback contract SHA-256:
  `0D991962A2415D09B081F8AE394CC78ED34EE72BD1AF6517CEA728BE5C7BCDA6`.

The earlier V1 output was not presented and is explicitly `WITHDRAWN`; V2 is
a fresh build from the locked sources and does not inherit V1 raster content.

## Operator gate

Draw one small axis-aligned square around
`PRIMARY_ROBUST_OPERATOR_FIDUCIAL` on
`work/PATTERNED_FIDUCIAL_INVENTORY/feedback/PFC004_OP3/PFC004_BF_DRAW_SQUARE_HERE.png`.
Do not add a numeric label. After the marked file is returned, map the square
through the locked affine transform and run bounded native BF/DF edge
detection only inside the resulting physical region.

No fiducial edge mask, template, distributed phase, alignment transfer,
defect scoring, Normal outcome, training truth, XML, or production authority
has been created. R5P30 remains immutable. The other 30 category rows, 20
crop-ready designations, one map hold, and nine pose holds remain pending in
their existing prerequisite order.
