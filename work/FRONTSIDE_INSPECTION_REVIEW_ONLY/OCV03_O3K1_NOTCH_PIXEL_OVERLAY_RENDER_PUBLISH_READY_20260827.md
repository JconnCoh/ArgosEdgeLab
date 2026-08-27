# OCV-03 O3K1 notch pixel-overlay render publish ready — 2026-08-27

## Disposition

`PENDING_GATE` — one exact review-only render request is signed and fully rehearsed but not yet published.

## Operator authorization and bounded purpose

The operator authorized reading and hashing only the four already frozen Slot16/Slot17 BF/DF source images needed to produce actual candidate crops and overlays. The visual comparison is limited to `S16-C1`, `S17-C1`, and `S17-C2`. It does not rerun detection, change an algorithm or threshold, score a new candidate, clear a hold, activate a provider, touch the protected processor, or grant training/XML/production authority.

The renderer creates one clean native-pixel crop, one current geometry mask, and one overlay for each candidate/channel pair. Overlay colors are: green frozen fitted perimeter, yellow frozen candidate interval bounds, and red frozen candidate center ray. The clean base and current overlay remain separate, and the synthetic/rehearsal gate proves zero changed pixels outside the current mask.

## Frozen request

- Request ID: `REQ_20260827T201500111Z_62629419O3K1`
- Signed ZIP: `work/OPENCV_EDGE_NOTCH_O3K1/final_render/REQ_20260827T201500111Z_62629419O3K1.ready.zip`
- ZIP SHA-256: `B755ECE17D8FE81BD5D49D607445004BE729A47FD7F2154AD0544D1B1F8FA24C`
- OpenCV renderer SHA-256: `6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4`
- Frozen render job SHA-256: `2BD9E34A9CCFDFF92942FC11A6E88CBABE2CBBED47A0320C118520D2C16988C7`
- Windows PowerShell 5.1 endpoint SHA-256: `E1D0D45622DC4AB1E2C086A2B765F4F7022B548AD8399DEB2D1048FF08FAB958`
- Endpoint rehearsal gate SHA-256: `2790E5BBEA726EA98AA5BBF8A88FA368EA14E2D1E12BD467F47F773F0A62C16B`
- Exact signed-package rehearsal gate SHA-256: `CF55899F25D2143629A9E0EE9165DAEC390597A12504352C2AB663B4A9009299`
- Complete 50-path round-trip gate SHA-256: `74B5B8D29596D6DADB81CFE987584AE768D0BAC4F37FF63CE990403588BBF1E0`
- Maximum planned effective path length: `187`
- Persistent `U:` zero-pending observation SHA-256: `80BBCA60C07F0EE75DD82A8E877AA031C02FCA98F426C5AA66BD677C660DFB2C`

The exact Windows PowerShell 5.1 rehearsal rendered 18 synthetic raster assets and a 19-entry export ZIP, verified all entry hashes, preserved processor identity, removed the owned alias, and performed no detector rerun, tuning, source mutation, task/process restart, provider activation, or wafer action. The live request has not read any source image bytes yet.

## Two-request return sequence

1. Publish this one `MAINTENANCE_PATCH` render request once through the already persistent `U:` route, with no retry.
2. Accept only its matching JBOD-signed terminal response. Gateway acceptance is not execution evidence.
3. Only after that terminal response proves the exact output ZIP path/hash/bytes, build and publish one separate `DATA_PULL` request for `OCV03ReviewExports/O3K1_20260827T200000Z/O3K1_REVIEW.zip`, again once with no retry.
4. Collect only the matching JBOD-signed `DATA_PULL` response, reconstitute the exact returned ZIP, run raster-provenance and real-browser gates, and present the local file-backed gallery to the operator.

## Preserved holds and prerequisite order

- Slot16 and Slot17 remain review-only morphology holds; Slot18 remains the frozen detector pass described in O3J1.
- No threshold or algorithm change is supported by current evidence.
- The frozen POST2 R6 regression remains mandatory before any later fresh hotspot detector successor.
- Patterned-wafer fiducial designation, map/pose/registration, coverage, sensitivity, transfer, XML, training, and production-routing prerequisites remain unresolved where previously recorded and are not superseded.
- Live provider activation is disabled. The protected all-wafer processor, tasks, and resident process are untouched.

## Exact next action

Run continuity and metadata-only session safety; commit and push the frozen package/gates/checkpoint; fetch `origin`; require a clean worktree with matching local/remote `codex/fiducial-opencv-d-drive` tips; rerun exact Windows PowerShell 5.1 publisher preflight and persistent-`U:` zero-pending checks; then publish `REQ_20260827T201500111Z_62629419O3K1` exactly once with no retry and collect only its matching JBOD-signed terminal response.
