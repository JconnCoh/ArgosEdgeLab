# OCV-03 O3Q2 Slot16 numeric request publication ready — 2026-08-28

Disposition: `PENDING_GATE`

This review-only checkpoint freezes one fresh O3Q2 numeric validation request
for the exact independent Slot16 hotspot BF/DF pair. The request is signed and
fully rehearsed but has not been published. It does not establish an endpoint
outcome, approve production use, activate a provider, clear a hold, or consume
backside pixels or any Argos rotation/orientation/location prior.

## O3Q1 withdrawal and fresh O3Q2 namespace

O3Q1 request `REQ_20260828T031000111Z_62629419O3Q1` was never published.
Its exact-package rehearsal exposed a PowerShell tokenization defect in the
injected timeout path, so the signed O3Q1 ZIP is immutable withdrawn evidence,
is non-reusable, and is not a publication or successor parent. Withdrawal:
`work/OPENCV_EDGE_NOTCH_O3Q1/O3Q1_SIGNED_PACKAGE_WITHDRAWAL.json`, SHA-256
`FD8A3540B0D5D78756821E5BF068E671123D2B8A126E909CB50C791E2862A1B2`.
Publication count is zero.

O3Q2 is a fresh request ID, signed ZIP, local output namespace, rehearsal
namespace, and gate namespace. Its recovery intent is
`work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_RECOVERY_INTENT.json`, SHA-256
`DB7A28145EFD4DEB5DC29730CDFC6576829A0615755FF74DB8508E5902E056EE`.
The one prior failure was local and unsigned; signed premise-failure count is
zero and mutation stop-loss is not active.

## Frozen numeric contract

O3Q2 uses the unchanged O3P8 detector, SHA-256
`41F60AF393E0B2C752AF6B33BB6673145490AE2BB346A4DA8E59A2D42E383E36`,
and unchanged O3P8 configuration-equivalence gate, SHA-256
`CF896E114179370BC9C8A58D64FDD3470EDCAB1A96836252693C935845224F95`.
There is no threshold, algorithm, or source relaxation.

The exact live inputs are:

- BF SHA-256 `3F98D5B506B3EF6E18BF9C24A64DC4516F024248DE994BD3DCBD5C8680EB7E90`
- DF SHA-256 `E293D3155A50554104A232C1FF9F1BDA7E6935D798C7266A2C8A0F90FC0A098B`
- canonical source root `D:\KLARFExport\PatternedFront\Lot_62629-419_NotchBad_Hotspot`
- runtime SHA-256 `7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1`
- installation SHA-256 `1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596`
- exact Slot16 source record SHA-256 `FBBF0609AD337D495E90E73C6F175E6D255287730B81498CE23C4C83536760B1`
- frozen O3N1 numeric candidate manifest SHA-256 `69FDAD4AB4DCF06A8A38C76EA009F0DA178896E8D0291668670AB9ADD24A05C8`
- exact 21-candidate O3Q2 seed projection SHA-256 `ADE7F68259982CF82C5AC3BC016DE1908E757725AB84E2ACFB5DE74D291DEEBF`

Every full-360 DF seed candidate is consumed. Candidate enumeration is not a
known-location prior. Hotspot membership, known notch location, Argos pose,
orientation, rotation, fixed search window, scorer input, and backside pixels
are absent from inference. BF uses the frozen top-connected measured-contour
method; DF uses frozen R6 full-360 radial evidence; DF topology remains
forbidden.

## Local and exact-package qualification

The fresh POST2 Slot17 endpoint rehearsal passed with one eligible candidate,
zero candidate-local topology insufficiencies, zero DF-topology calls, no
raster output, source alias removal, and unchanged processor identity:
`work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_ENDPOINT_REHEARSAL_GATE.json`, SHA-256
`520FB2AD34C5313C03B3D9242C5FCB0C2FA2E6E42197E78471F7A89884C1C53C`.

The exact signed O3Q2 ZIP passed Windows PowerShell 5.1 extraction, signature,
payload hashes, allow-create false, same-hash idempotence, unapproved
predecessor refusal before mutation, exact endpoint preflight, exact success,
and injected timeout quarantine. The injected failure message is exactly
`O3Q2 Python exceeded its bounded timeout.`:
`work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_EXACT_PACKAGE_REHEARSAL_R3_GATE.json`,
SHA-256
`A280ABD5962589DBFB53654B571304CB8F5E8476B04497464E485194F37B7D00`.

The 55-leaf complete portal round trip, including all request, endpoint,
maintenance, compact-failure, quarantine, relay, response, and collection
roots, passed with 32-character reserve. Maximum effective path length is 187
and maximum component length is 53:
`work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_COMPLETE_ROUTE_GATE.json`, SHA-256
`99DF24C6CF06C3365E9349E140216B300BA4AE565A9162AEC99670F6EB72DC2C`.

## Exact signed request awaiting one publication

- request ID: `REQ_20260828T033000222Z_62629419O3Q2`
- ZIP: `work/OPENCV_EDGE_NOTCH_O3Q2/final_numeric/REQ_20260828T033000222Z_62629419O3Q2.ready.zip`
- ZIP bytes: `48540`
- ZIP SHA-256: `F107CB94E8580EB018C373F2995BC6D817D7E4337D351F875E861B5A42D1AACC`
- request manifest SHA-256: `EAFBF1E1AE2AC5B96B1B13C9596493E29D10D4527C9E9BB79F7EE5D343A98D09`
- request signature SHA-256: `22646BD0071668976DA2433885A42731913267CE18066C54D0912575C45C528D`
- final-package gate SHA-256: `E4313D61A5DC7D81858630F1ED65C916BB05A669927EBA3D8877C86683390397`
- publisher SHA-256: `2059D45D2EEAFA42EF66A1559D96A60EC7A51A1E205165556A90F3623E8CE2B9`
- publish invocation SHA-256: `E6A752F10F85873AA92B1FF01B5EF96CB9A415FAD3B96245DD10C702182F2EBB`

The current persistent `U:` observation proves both `Get-PSDrive.DisplayRoot`
and `Win32_LogicalDisk.ProviderName`, DriveType 4, match the locked UNC, and
the request directory has zero pending files:
`work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_CURRENT_SHARE_OBSERVATION.json`, SHA-256
`D461ADF0870F74C66243A6BA26D8F9FD57CA14B098621CC721BBE775DED07BF9`.

Publication count is zero. Exactly one publication is authorized, through the
persistent `U:` mapping, using a create-new `.upload` copy and atomic move.
Retry and republication are forbidden. Gateway import is not execution
evidence. Only the unique matching JBOD-signed terminal response with signer
thumbprint `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC` may be collected.

## Exact next action

Run project continuity and metadata-only session safety. Require a clean
`codex/fiducial-opencv-d-drive` worktree with identical local and remote tips.
Run the exact publication zero-recurrence and publisher preflight gates, then
publish O3Q2 once with no retry. Observe and collect only the matching signed
terminal response.

If and only if that numeric response independently passes, freeze the numeric
result first. Only after the freeze may the known upper-right hotspot be used
for post-inference membership scoring. Then create separately signed, one-shot,
no-retry render and DATA_PULL requests for only the selected BF/DF
contour-hugging evidence. Do not render or present the withdrawn O3N1
21-candidate overlay.

## Preserved holds and prerequisite order

O3N1, O3P7, and the never-published O3Q1 package remain withdrawn and
non-parent. BF Slot16 partial-coverage uncertainty remains unresolved. Live
provider stays disabled and the protected processor stays untouched. No
source mutation/deletion, task or managed-process action, threshold/algorithm
change, retry, hold clearance, XML, training, or production routing is
authorized.

Backside remains unconsumed and requires a separate appearance-regime intent
and method after frontside freeze. After independent frontside and backside
POST2/hotspot verification, fan out the frozen detectors to separately
qualified additional lots. Fiducial designation, map, pose, registration,
coverage, sensitivity, and independent alignment-transfer gates remain
pending and operator-visible; fiducial work may resume only after both notch
programs complete and time remains.
