# OCV-03 O3N1 split-method Slot 16 publication ready

Date: 2026-08-27

Revision: `OCV03_O3N1_SPLIT_METHOD_SLOT16_PUBLISH_READY_20260827`

Disposition: `PENDING_GATE`

## Outcome

The successor no longer forces frontside BF and DF through one segmentation
method. BF uses `TOP_CONNECTED_TOPOLOGY_FULL_360`; DF uses the independently
qualified `OUTER_EDGE_RADIAL_FULL_360`. Candidates become physical review
candidates only when both channel methods support the same angular location.
Backside pixels are not consumed and backside remains free to use a separate
provider later.

The detector searches the raw BF and DF images through all 360 degrees. It
does not consume Argos rotation/orientation metadata, a known notch location,
an angle prior, a fixed angular search window, or the operator's upper-right
location before output freeze. Review overlays use the measured channel edge
and a red mouth-to-mouth contour; no straight red center ray is rendered.

## Evidence

- The operator feedback that disproved the old displayed Slot16 candidate is
  frozen at `work/OPENCV_EDGE_NOTCH_O3L8/O3L8_OPERATOR_FEEDBACK_20260827.json`.
- The mandatory unchanged R6 POST2 rerun passed before successor work.
- R7 synthetic evidence passed upper-right and arbitrary-angle positives, a
  no-notch negative, two-notch ambiguity, and a one-channel chipout negative:
  `work/O3M7/T7/SYNTHETIC_GATE.json`, SHA-256
  `A4A85A46B61701EA9973DA768AF77D5240A682DBE4D1085FAF14BEAB21F8D937`.
- The exact frozen POST2 set returned one BF-topology/DF-radial common physical
  candidate for Slots01, 03, and 17 without tuning:
  `work/O3M7/P7/MANIFEST.json`, SHA-256
  `825118A0D53D478AA2F8B5334ED9405267561041FD21E14C1EBD4E46DF016AEE`.
  Each row retains the explicit partial-BF-topology-coverage hold (71/72
  qualified tiles); that hold is not cleared.
- The exact O3N1 endpoint passed Windows PowerShell 5.1 rehearsal with two
  source hashes matched, one common candidate on the frozen POST2 control,
  39 returned review leaves, no tuning, no backside pixels, no Argos rotation
  metadata, unchanged processor identity, and removed temporary source alias.
- The signed final package gate is
  `work/OPENCV_EDGE_NOTCH_O3N1/O3N1_FINAL_PACKAGE_GATE.json`, SHA-256
  `DEC2F1226474E655D98B9BD00FB105D47641586D7483AC162824236C79F8A958`.
- The exact signed ZIP extraction/signature/predecessor/idempotence/refusal and
  extracted endpoint preflight gate is
  `work/OPENCV_EDGE_NOTCH_O3N1/O3N1_EXACT_PACKAGE_REHEARSAL_GATE.json`, SHA-256
  `5AFFED3580C93D1ACC97CDB6AF1D5CCA58D9673A132A1350DB83AC4F09844BBB`.
- The 53-row complete round-trip path gate is
  `work/OPENCV_EDGE_NOTCH_O3N1/O3N1_COMPLETE_ROUTE_GATE.json`, SHA-256
  `C46F4C24150E4799A373224DF421A8A08872FC7921309F8F9DD87C033C86E94D`.
- Persistent `U:` resolves through both PowerShell and Win32 to the exact
  engineering share with drive type 4 and zero request files. The observation
  is `work/OPENCV_EDGE_NOTCH_O3N1/O3N1_CURRENT_SHARE_OBSERVATION.json`,
  SHA-256 `11F82CC0D11243CD4CBBEDA67BF020049E8AF5CAC852F34C88EA06CAF88DAA2D`.

## Exact request

- Request ID: `REQ_20260827T231500111Z_62629419O3N1`
- ZIP: `work/OPENCV_EDGE_NOTCH_O3N1/final_render/REQ_20260827T231500111Z_62629419O3N1.ready.zip`
- ZIP SHA-256: `76BA22E074ADE5DF0D2B14CBB2C7937EA7E25DBEC3A1D552B923834C1BF12FAE`
- Maximum publications: one
- Retry authorized: false
- Required evidence: only its matching JBOD-signed terminal response
- Gateway/importer acceptance is not execution evidence.

The maintenance protocol requires one change row. O3N1 therefore pins the
already-installed non-processor O3K1 review helper at the same source,
predecessor, and installed SHA-256 with `allowCreate=false`. It is not called
by the O3N1 entrypoint. The exact-package rehearsal proves the absent,
same-hash idempotent, and unapproved-predecessor cases. No protected processor
file is named or touched.

## Preserved holds and prerequisite order

1. Publish the exact request once and accept only the matching JBOD-signed
   terminal response. Do not infer execution from gateway acceptance.
2. Only after that terminal response may one separately signed, no-retry
   `DATA_PULL` request return the exact staged O3N1 review ZIP.
3. Present the returned Slot16 BF and DF contour-hugging overlays for operator
   visual judgment. Detector output must remain frozen before using the
   operator's upper-right location as review evidence.
4. Slot16 notch acceptance, BF partial-coverage resolution, raster-provenance
   release, and operator visual approval remain pending gates.
5. Patterned-wafer fiducial designation and a fresh alignment-transfer pass
   remain prerequisites before any production-wafer defect scoring.
6. Live provider activation, training, XML, production routing, wafer action,
   task/process restart, source mutation/deletion, threshold relaxation, and
   hold clearance remain unauthorized.

## Next action

Commit and push this frozen publication state, fetch and require matching clean
local/remote tips, rerun continuity and metadata-only session safety, rerun the
exact publisher preflight and persistent-`U:` zero-pending gates, then publish
`REQ_20260827T231500111Z_62629419O3N1` exactly once with no retry. Collect only
its matching signed terminal response. If successful, build and publish one
separate exact-file `DATA_PULL`, reconstitute and hash-verify the O3N1 review
ZIP, and present a local file-backed gallery containing the actual measured
BF/DF notch contours.
