# Patterned-wafer fiducial native-crop V1E partial result checkpoint

Date: 2026-08-15

Revision: `PATTERNED_FIDUCIAL_CROP_V1E_RESULT`

Disposition: `PENDING_GATE`

## Authority

This is a review-only, file-backed fiducial-model transfer diagnostic. It
grants no alignment, detector, training, XML, production, or automatic
inspection authority. Candidate structures 1 and 2 remain pending operator
confirmation. Line-array structures 3 and 4 remain non-model controls.

## Frozen inventory

- Exact catalog SHA-256:
  `AC689B5C60DDD467061FCE1A88603C44772A0BBCC709FBC8D357639DA295D715`.
- Frozen inventory SHA-256:
  `68CE326946BF88132ABBEC1C742FCECA0FEFDECA19E2E9A9D53841233EC8FD39`.
- 31 exact product/layer image combinations across eight products.
- One physical acquisition per combination was selected deterministically
  before appearance review.
- 30 combinations have one exact `LayoutId` product map with bin 34 or 36.
- `1498994/A00` remains `HOLD_MAP_TEMPLATE_NOT_FOUND`; product-family
  `3393-901` was not substituted.

## Signed JBOD execution and recovery

The early PFCP1 revisions are preserved and never became evidence:

- `PFCP1`: withdrawn when the exact path gate proved that one source-root
  alias did not shorten deep paths or overlong leaf names.
- `PFCP1A`: withdrawn after strict mode exposed a missing `processBlock` field
  on the map-hold result row.
- `PFCP1B`: withdrawn after Windows PowerShell 5.1 rejected an unnecessary
  generic-list array-subexpression conversion.
- `PFCP1C`: withdrawn locally before signing when the packaged preflight was
  strengthened to exercise both hold and success result schemas.
- `PFCP1D`: diagnostic only. The package ran successfully but a first-wafer
  coarse-notch hold aborted the legacy pose batch and created 30 missing-pose
  holds. No crop was emitted.

PFCP1E introduced per-wafer fail-closed pose containment. Package ZIP SHA-256
is `9C50558BAE7F1D852E7A1C753EFC63C0475E9A7236D47ED82F544F08E0434633`;
package-manifest SHA-256 is
`D353A14B80D862DCF763C188415261FFBDC17866186BAECBEA838F47D3FFE912`.
Signed request `REQ_20260816T025133400Z_B2003720D6A3` reached the endpoint's
900-second child timeout after the final crop audit and ZIP had already been
written, so the request response itself is `FAILED` and is not treated as a
PASS execution record.

Signed timeout recovery `REQ_20260816T031657680Z_B3A0E4EB8C72` returned
`PASS_MAINTENANCE_PATCH`. It removed exactly 60 temporary hard links and the
single `R:` output-parent alias, preserved the partial output, and confirmed
30 pose directories plus the final pose manifest, final review audit, return
gate, and crop ZIP. Canonical source images were unchanged.

Signed data pull `REQ_20260816T031820541Z_E70D72924536` returned response
`R_17E6F17CB3BE_20260816031759600` with `PASS_DATA_PULL`. The crop ZIP is
401,588,820 bytes, SHA-256
`9EAAE8216D769DC356370837E7824015BEC9105BC2410EA0577819CCFD467A4E`.
The return gate SHA-256 is
`D9212024CC4DA0AF777DA3C1F9C70950E1EEB705107E0BAA520EAB4F61110338`.

## Verified result

- Final audit SHA-256:
  `51D42C63627DEAED80FFF5D5692E48D259CE603BE6D6E7DBA558F5D314222201`.
- Index SHA-256:
  `14DC86EF40137ED7618122E821F6C500090DC0EFAC1CF82B9BD43FCC2C682364`.
- Combinations CSV SHA-256:
  `AB5078E4C756DCD2A6982B40BC28A6877DEE7B24B93DA8C5B46FDAD6397ECB8E`.
- 21 combinations are
  `PENDING_OPERATOR_FIDUCIAL_MODEL_CONFIRMATION`.
- 42/42 referenced PNGs hash-match their audit rows.
- Every crop is a direct native 1:1 `3600 x 2600` extraction with
  `scaleX=1`, `scaleY=1`, and `sourcePixelsResampled=false`.
- Every ready row records exact BF/DF source SHA-256 values, source dimensions,
  map projection, native crop rectangle, and crop hashes.
- Nine combinations remain `HOLD_MACRO_POSE_NOT_QUALIFIED`: PFC002, PFC008,
  PFC009, PFC012, PFC013, PFC025, PFC026, PFC027, and PFC031.
- PFC001 remains the exact-map hold.
- Held rows contain no crop images and are not skipped, Normal, or Reject
  truth.

The create-new department-share copy is:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\PatternedFiducials_V1E_20260816`

It contains 75 files, including 42 PNGs, totaling 401,592,414 bytes. Every
share-copy hash matches the returned local gallery.

## Next action

The operator may review the 21 paired BF/DF crops now. In parallel, diagnose
the nine named per-wafer pose holds without a fixed-angle decision or wafer
skip, and locate an exact `LayoutId=1498994` map before attempting PFC001.
Use fresh output roots for any recovery. Do not call the inventory complete or
grant alignment authority until all remaining combinations are either
resolved and confirmed or retain explicit operator-visible holds.
