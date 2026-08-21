# PFC004 exact-pixel square zoom

Date: 2026-08-18

Revision: `PFC004_EXACT_SQUARE_ZOOM_V2_20260818`

Disposition: `RELEASED_REVIEW_ONLY`

## Exact operator selection

The operator saved the marked PNG directly in the locked 1200-by-900 V2
pixel frame. Comparison with the clean parent found exactly 850 changed
pixels, all RGB `(255,174,201)`, forming one five-pixel-thick rectangle at
x=1141..1188 and y=812..858. Dimensions were unchanged. The exact feedback is
locked as `PFC004_OP6`; feedback JSON SHA-256 is
`B4D64E1599AC60A7F8532FA4F11C8C49BF6E7BB8058268E3AC0BC2A9106ED789`
and marked-source SHA-256 is
`E5480AE111AE96509785F59E3D06425A0D83A97D04656BB14FA9A38175ED51CE`.

No screenshot registration or repeating-grid correlation was used. The exact
straightened-view center `(1164.5,835.0)` maps through the locked V2 affine to
native-crop center `(993.892353937178,1418.67797965719)` and full-wafer center
`(7085.89235393718,6073.67797965719)`.

## Fresh close view

A fresh create-new 200-by-200 straightened BF/DF close view was rendered from
the locked 3600-by-2600 native sources at one source pixel per output pixel.
Rotation resampling is display-only; the locked native pixels remain unchanged
and scoring on rotated pixels is prohibited.

The clean BF and the initial line-drawing canvas are byte-for-byte identical.
No box, line, detector overlay, edge response, or mask is present yet.

Locked artifacts:

- input SHA-256:
  `28E8509038DFF1A4F0AB02D8A8E244B6658234E6CEABAE3772B8CDC9855B38C3`;
- tool source SHA-256:
  `3A70C0D71014583EB79AE75DAB3F94B043CBCA6664B3ED37C4545F5A9858055E`;
- compiled tool SHA-256:
  `9FF82CD1FF0223D5C06E3C9D24BCBD4786816CF6767C4D8B2B011C8AD1B0D9B4`;
- BF zoom and initial drawing canvas SHA-256:
  `172FBC48E6CF75F90FB6F4D6613F279043FB3B1BCCADB9585F3ACFF40797BE6C`;
- DF zoom SHA-256:
  `4652BCE98D0CC508CF19763D19091EFF61EC14934599CC0BB3DCBF3A79EDD317`;
- selection-map SHA-256:
  `42B10664482C5D1B9BFBE8CABC73FF124F1D1EA80380B5085D78DAFD91CC29EC`;
- audit SHA-256:
  `46918AF2303C3BC6A1717D7AA107E75329B0402D903D16A7F229776DE6042B0E`.

## Operator line gate

Current phase is `PFC004_EXACT_SQUARE_ZOOM_OPERATOR_LINE_GATE`.

The operator opens `PFC004_BF_DRAW_LINES_HERE.png` in Paint, zooms the Paint
view to 400% or higher without resizing the image, and draws four short green
straight segments along the intended inward physical boundaries. Each segment
must stop before both corners so rounded corner pixels are excluded. Save the
same PNG in place without resizing or cropping.

After save, compare it pixel-for-pixel with the locked clean BF zoom, lock the
four operator line segments, and show the extracted geometry before any native
BF/DF edge response is calculated. Edge detection is still blocked.

No fit, template, distributed phase, alignment transfer, defect scoring,
Normal outcome, training truth, XML, or production authority has been created.
R5P30 remains immutable. The 11 unresolved `PENDING_GATE` objects, other 30
category rows, 20 other crop-ready designations, one map hold, and nine pose
holds remain in their existing prerequisite order.
