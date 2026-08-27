# OCV-03 O3K1 signed render terminal / exact overlay DATA_PULL publish ready — 2026-08-27

## Disposition

`PENDING_GATE` — the exact review renderer completed on JBOD and its matching terminal response is signature-verified. One exact one-file `DATA_PULL` is signed and fully path-gated but remains unpublished.

## Signed render result

- Render request: `REQ_20260827T201500111Z_62629419O3K1`
- Render request ZIP SHA-256: `B755ECE17D8FE81BD5D49D607445004BE729A47FD7F2154AD0544D1B1F8FA24C`
- Publication count: `1`; retry authorized: `false`
- Matching response: `R_34948C162186_20260827202149504_651be723`
- Response ZIP SHA-256: `AB08F56DD42317734750CA27159694598268D4029656500FC2485D4D21517034`
- Response collection gate: `work/OPENCV_EDGE_NOTCH_O3K1/O3K1_RENDER_RESPONSE_COLLECTION_GATE.json`
- Response collection gate SHA-256: `1CE3B6EC3AE63654DCA10B8113ED1DD04A9946EA40DF2A815226886967B7D4E4`
- Terminal state: `PASS_O3K1_NOTCH_REVIEW_RENDERED_FOR_DATA_PULL`
- JBOD signer thumbprint: `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`
- Exact source image read count: `4`; all four frozen source hashes matched: `true`
- Render manifest SHA-256: `26F784FD7C5B4C35D89083CCAFDE5CD499F9CD3533AFE8319AD4877B38C8186A`
- Staged review ZIP: `OCV03ReviewExports/O3K1_20260827T200000Z/O3K1_REVIEW.zip`
- Staged review ZIP bytes: `5666342`
- Staged review ZIP SHA-256: `CEE193475613E04D0AD25F0402437E3E21E310EF1F8B1312737B28463699F724`

The signed proof records no detector rerun, threshold or algorithm change, source mutation or deletion, task/process action, provider activation, or protected-processor identity change. Gateway acceptance is not treated as execution evidence; the matching JBOD-signed response is the execution evidence.

## Frozen one-file DATA_PULL

- Request ID: `REQ_20260827T203242373Z_0DBC2A7558B3`
- Signed ZIP: `work/OPENCV_EDGE_NOTCH_O3K1/dpf/REQ_20260827T203242373Z_0DBC2A7558B3.ready.zip`
- ZIP bytes: `1167`
- ZIP SHA-256: `DD7651041B5C37B6BBBA09E069152BB2C4859D825C6BF38911E80F1DB4F173AF`
- Request manifest SHA-256: `FE1B41D86E8D99B44CA8AC3DABEA7E35697E7FC1F91EDD5150ABAD43A89C317A`
- Request signature SHA-256: `4747907A75AE6CF63FB573A7B93713AD81C9D9CE67CAA5A842E41ED6E07E20CD`
- Exact requested path: `OCV03ReviewExports/O3K1_20260827T200000Z/O3K1_REVIEW.zip`
- Maximum files: `1`; maximum bytes/result bytes: `16777216`
- Final-package gate SHA-256: `13CEED2CD3D1B3D1E983633B82BDD971F0241AEF6003F266DB2C9EA09A722C3E`
- Complete route gate SHA-256: `F8AB82BB364AD6DBADF2C40AE0BFE7F18B646013D89F9A8663924E0770D06247`
- Exact maximum effective route length: `185`; maximum component length: `61`; suffix reserve: `32`
- Publication count: `0`; maximum authorized publications: `1`; retry authorized: `false`

The DATA_PULL can return only the already staged exact review ZIP. It does not decode pixels, rerun the detector, alter the JBOD output, or change an installed endpoint, task, process, provider, source, wafer, ledger, or production route.

## Human review contract

After the matching signed DATA_PULL terminal response proves the exact returned ZIP hash and bytes, reconstitute that ZIP locally and build a file-backed comparison gallery with actual pixels—not charts. The gallery must present `S16-C1`, `S17-C1`, and `S17-C2` in BF and DF, with clean crops and current overlays together. Overlay colors remain green frozen fitted perimeter, yellow frozen candidate interval bounds, and red frozen candidate center ray. The operator, not the detector, decides whether the candidates are wrong overlays, distinct manufactured notch types, a non-notch lookalike, or visually ambiguous.

## Preserved holds and prerequisite order

- Slot16 and Slot17 remain review-only morphology holds; Slot18 remains the frozen O3J1 detector pass.
- No threshold or algorithm change is supported by current evidence.
- The frozen POST2 R6 regression remains mandatory before any later fresh hotspot detector successor.
- Patterned-wafer fiducial designation, map/pose/registration, coverage, sensitivity, transfer, XML, training, and production-routing prerequisites remain unresolved where previously recorded.
- Live provider activation remains disabled. The protected all-wafer processor, resident process, and inspection tasks remain untouched.

## Exact next action

Run project continuity and metadata-only session safety; commit and push this exact package and checkpoint; fetch `origin`; require a clean worktree with matching local/remote `codex/fiducial-opencv-d-drive` tips; rerun exact Windows PowerShell 5.1 non-mutating publisher preflight and persistent-`U:` zero-pending gates; publish `REQ_20260827T203242373Z_0DBC2A7558B3` exactly once with no retry. Collect only its matching JBOD-signed terminal response, verify and extract only the exact staged ZIP, run raster-provenance and real-browser gates without returning image bytes into the task, and present the local gallery path to the operator.
