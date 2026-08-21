# PFC004 close fiducial zoom and corner-inset proposal

Date: 2026-08-18

Revision: `PFC004_FIDUCIAL_ZOOM_V1_20260818`

Disposition: `DIAGNOSTIC_ONLY`

## Operator guidance captured

The operator reports that the V2 view is too zoomed out, identifies the
primary robust fiducial in the bottom-right pink box, requests a closer view,
and directs that the working edge region be pulled inward so outermost edges
and potentially rounded corners do not influence the fit.

The exact screenshot is locked as `PFC004_OP4` with SHA-256
`87F02A68BCB65EDBE2E2E8AFB9C3C0D482F183D26AAAE8906A1C42B006F59707`.
Its pink box is x=1151..1187, y=610..644. Bounded grayscale registration to
the locked V2 BF view produced correlation 0.95278105 at exact scale 1.0 and
display offsets x=3, y=-69. The mapped V2 center is `(1166, 696)`; the mapped
native-crop center is `(1090.7488, 1318.9680)` and the full-wafer center is
`(7182.7488, 5973.9680)`. The screenshot is navigation-only and supplies no
native pixel or detector truth.

## Fresh close view

A fresh 240-by-240 BF/DF close view was rendered directly from the locked
3600-by-2600 native crops using the existing 43.55-degree straightened display
frame. The 1X views retain one source pixel per output pixel; rotation
resampling is display-only and scoring on the rotated pixels is forbidden.

The separate 4X nearest-neighbor BF guidance view uses:

- pink: the operator's outer navigation box;
- cyan: a proposed five-pixel inset box;
- green: proposed straight-support segments, each trimmed five pixels from
  the inset-box corners;
- zero corner pose weight.

No edge response or fitted line is shown. The clean BF/DF zoom files contain
no operator or guidance raster. The overlay audit found 6,080 changed display
pixels, all inside the declared guidance bounds and zero outside.

## Locked artifacts

- OP4 feedback JSON SHA-256:
  `78D3A88C6008D4051177FADB4AF428BBA523AA0E248B90A5071601FED770A5D9`;
- BF zoom SHA-256:
  `86F34BD6AE3B012087689BD08CBBED06AD4A556F0B89A26B188E18EEC908165E`;
- DF zoom SHA-256:
  `953491A7D8CD672D2461CA99D21BA65D6ECBDB1A6D1FA3CDC9AD9AE550313F20`;
- guidance overlay SHA-256:
  `338116B0398775629D47D6CBE12694FC065E7E5BE4516B0A32BD3EF1485A7C89`;
- proposed edge-window SHA-256:
  `109F28727A8E53138CA47D8ABC07B0EA86425FEA76C358A7AE6735BEA83A539A`;
- guidance-overlay audit SHA-256:
  `C234F3E5AC157D83B8BB184AD152537E02CE914D4CF5165D62B6723F88DEB5D9`;
- build audit SHA-256:
  `AF0EC9B17B4B90620804B18FB3C35E55D8ACFD08B0F5BD3E33220E88E9830703`.

## Gate

The operator reviews the 4X guidance view and confirms or corrects the
five-pixel inset and five-pixel endpoint trim. Only after confirmation may a
fresh bounded diagnostic map those straight-support segments back to the
original unrotated native BF and DF pixels and independently detect their first
stable physical boundaries.

No edge detection, fit, template, distributed phase, alignment transfer,
defect scoring, Normal outcome, training truth, XML, or production authority
has been created. R5P30 remains immutable. The other 30 category rows, 20
crop-ready designations, one map hold, and nine pose holds remain pending in
their existing prerequisite order.
