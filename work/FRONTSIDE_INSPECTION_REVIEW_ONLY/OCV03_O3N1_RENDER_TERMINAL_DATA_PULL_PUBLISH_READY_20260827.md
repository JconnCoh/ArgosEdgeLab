# OCV-03 O3N1 signed split-method render terminal / exact Slot16 DATA_PULL publish ready — 2026-08-27

## Disposition

`PENDING_GATE` — the exact split-method Slot16 review renderer completed on JBOD and its matching terminal response is signature-verified. The result remains `HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH`. One exact one-file `DATA_PULL` is signed and fully path-gated but remains unpublished.

## Signed render result

- Render request: `REQ_20260827T231500111Z_62629419O3N1`
- Render request ZIP SHA-256: `76BA22E074ADE5DF0D2B14CBB2C7937EA7E25DBEC3A1D552B923834C1BF12FAE`
- Render publication gate SHA-256: `1697F3E96207C20FCF10C9BFB11C9C17D23EE7728956CAFA5CD12006AA946953`
- Publication count: `1`; retry authorized: `false`
- Matching response: `R_0F274208CEBB_20260827233856916_3a28577f`
- Response ZIP bytes: `2713`
- Response ZIP SHA-256: `5B292BCE4487ED8D5CC11DDD99C61F571F305837551A0839B9BAC8CC76AD373D`
- Response collection gate: `work/OPENCV_EDGE_NOTCH_O3N1/O3N1_RENDER_RESPONSE_COLLECTION_R3_GATE.json`
- Response collection gate SHA-256: `4ED5AA2ABC5FCFD8F07CB7BC766AA2A02070FAA93780AEBA456D81BD9451E8BC`
- Endpoint state: `PASS_O3M8_SLOT16_SPLIT_METHOD_RENDERED_FOR_DATA_PULL`
- Detector state: `HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH`
- Eligible physical candidate count: `0`; physical candidate count: `0`
- JBOD signer thumbprint: `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`
- Exact source image read count: `2`; both frozen source hashes matched: `true`
- Render manifest SHA-256: `69FDAD4AB4DCF06A8A38C76EA009F0DA178896E8D0291668670AB9ADD24A05C8`
- Staged review ZIP: `OCV03ReviewExports/O3N1_20260827T231100Z/O3N1_SLOT16_REVIEW.zip`
- Staged review ZIP bytes: `15166219`
- Staged review ZIP SHA-256: `93B2A18D70CAD29B321818EDCD5F1F39C0F189C44DA9F2495BF4AE5AAECD7B2D`
- Staged review ZIP entry count: `91`

The endpoint reran the frozen split-method detector for the exact authorized Slot16 BF/DF sources and froze the hold outcome. It did not change a threshold or algorithm, consume backside pixels or Argos rotation/orientation metadata, mutate or delete a source, activate a provider, or touch the protected processor. The observed processor process count was zero; this is not represented as proof of a healthy resident processor. Gateway acceptance is not execution evidence; the matching JBOD-signed response above is the execution evidence.

## Frozen one-file DATA_PULL

- Request ID: `REQ_20260827T235851191Z_95B56EC29E54`
- Signed ZIP: `work/OPENCV_EDGE_NOTCH_O3N1/dpf/REQ_20260827T235851191Z_95B56EC29E54.ready.zip`
- ZIP bytes: `1173`
- ZIP SHA-256: `65CE29AE28459607BF9B6AD8217CBA957AE7F26E49499DE28B4B7AF235AAE606`
- Request manifest SHA-256: `4E6793D9DDC910D3D21D0EBA15E9A40D1FD0B1DBF558E2E7553550225D0EC2C7`
- Request signature SHA-256: `BDA169B64EB5DF38554004BBFD1E7E03C0E21F68DD1AB2F27351EA1CDFFDCABC`
- Exact requested path: `OCV03ReviewExports/O3N1_20260827T231100Z/O3N1_SLOT16_REVIEW.zip`
- Maximum files: `1`; maximum bytes/result bytes: `16777216`
- Final-package gate SHA-256: `0ACDC1850535BA9F225A6F64190DEAF82AA020AB9C1DFF10DD69D1C45AE91179`
- Complete route gate SHA-256: `4DBD062AE7D77594C6502611052B10EB40BF17EF7118D38AA48D07DEDDAEA291`
- Exact maximum effective route length: `185`; maximum component length: `61`; suffix reserve: `32`
- Persistent-`U:` share observation SHA-256: `54E77ABC0BC9F379AF7F177E40E4B9B21C7FD775B626DEDA8D130B5A601AA7E3`
- Publication count: `0`; maximum authorized publications: `1`; retry authorized: `false`

The DATA_PULL can return only the already staged exact review ZIP. It does not decode pixels, rerun the detector, alter the JBOD output, or change an installed endpoint, task, process, provider, source, wafer, ledger, hold, or production route.

## Human review contract

After the matching signed DATA_PULL terminal response proves the exact returned ZIP hash and bytes, reconstitute that ZIP locally and run the raster-provenance gate. Build a file-backed BF/DF Slot16 gallery from the returned clean and current overlay assets. Present the current contour-hugging evidence and the zero-candidate hold honestly; do not relabel a missing qualified contour as a detector pass. No image bytes may enter the Codex task.

## Preserved holds and prerequisite order

- Slot16 remains `HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH`; the operator contour review and BF partial-coverage questions remain open.
- The frozen POST2 R6 regression remains mandatory before any later fresh hotspot detector successor.
- Raster-provenance release and real-browser/manual visual review remain pending.
- Patterned-wafer fiducial designation, map/pose/registration, coverage, sensitivity, alignment transfer, XML, training, and production-routing prerequisites remain unresolved where previously recorded.
- Backside remains unconsumed, live provider activation remains disabled, and the protected all-wafer processor and inspection tasks remain untouched.

## Exact next action

Run project continuity and exact-session metadata safety; commit and push this exact package and checkpoint; fetch `origin`; require a clean worktree with matching local/remote `codex/fiducial-opencv-d-drive` tips; rerun recovery, wrapper, harness, zero-recurrence, exact Windows PowerShell 5.1 non-mutating publisher preflight, and fresh persistent-`U:` zero-pending gates. Publish `REQ_20260827T235851191Z_95B56EC29E54` exactly once with no retry. Collect only its matching JBOD-signed terminal response, verify and extract only the exact staged ZIP, run raster-provenance and file-backed gallery gates without returning image bytes into the task, and present the local Slot16 BF/DF contour gallery path. Preserve the detector hold and all review-only/training-false/XML-false/production-false authority boundaries.
