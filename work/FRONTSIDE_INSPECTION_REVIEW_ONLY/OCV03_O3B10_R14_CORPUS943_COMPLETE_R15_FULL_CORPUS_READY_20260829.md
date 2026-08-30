# OCV-03 O3B10 R14 corpus-943 complete / R15 full backside corpus ready

Date: 2026-08-29
Classification: `PENDING_GATE`
Authority: review-only; no training, XML, production, provider activation, source mutation/deletion, existing task/process action, protected-processor action, or hold clearance.

## R14 complete result

The create-new R14 backside-only corpus at
`D:/KLARFExport/_ArgosReview/C15RUN1` completed all `943` exact BACK BF/DF
pairs. The final signed observation used request
`REQ_20260829T165601353Z_E241A0604626` and matching JBOD response
`R_163B42E44A3A_20260829165646898_82a8c555`.

- final response ZIP SHA-256: `4D0E0FD2A5925CC20F6CA007643C3203ECCB30F7264AC803CBA7F68C58991F4E`
- final `SUMMARY.json` SHA-256: `2EE840467C74978E7C6B19F3AA413736E4D60E5075785D5D3FC257EF597DED0D`
- pair count: `943`
- unique BF/DF notch pass count: `803`
- explicit hold count: `140`
- channel-analysis hold count: `30`
- no-pair hold count: `110`
- source-problem count: `0`
- `complete`: `true`

The final R14 result is regression evidence, not production authority. No
source image was changed or deleted, and no existing task/process or protected
processor was touched.

## Exact hold evidence already inspected

Representative R14 holds were pulled only through signed read-only DATA_PULL
requests and inspected before any further detector change. The major recoverable
families are split DF notch response and DF perimeter coverage that retains
passing inlier/RMS evidence. R15 already passed the frozen eight-case regression:
seven unique physical BF/DF notch passes and one intentional broad-DF hold.

R15 detector SHA-256:
`F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C`.
R15 configuration SHA-256:
`B3AD3EBDA8B89A6862E99E38D68BB05B939742A38A86A5B3A982745B1801B821`.
R15 regression response:
`R_E4B97B8EA790_20260829161821811_3a7a879e`.
R15 regression response ZIP SHA-256:
`AE2AD7CB97E8C6B2E3884A715D314D5EA648E668AA84EA07AF59D7E847FE28A`.

The `62624-803` R14 failures were visually inspected. Their true physical
notch is the small bottom indentation; the larger rim features are fixture
contacts. The edge trace hugs the wafer, but BF morphology rejects the smaller
notch before pairing. Exact source paths and BF/DF hashes are pinned from the
corpus parent result records for later targeted regression. No threshold was
relaxed from those samples and no known notch angle was consumed.

The severely damaged `62617-215D` BF edge remains a correct hold. The broad-DF
`62626-015` family remains a correct hold. These are negative safety controls,
not failures to be forced into a pose.

## R15 full-corpus successor

The fresh R15 full-corpus launcher targets only the create-new output root
`D:/KLARFExport/_ArgosReview/C15RUN2`. It starts one owned review-only child
and performs no action against the completed R14 worker or any existing
process.

- launcher: `work/OPENCV_BACKSIDE_NOTCH_O3B10/Invoke-O3B10R15BacksideCorpusAll.ps1`
- launcher SHA-256: `070394687272CFCBA0647375790EA605BDFAFAC02B469CFEBF713C26D5952830`
- definition: `work/OPENCV_BACKSIDE_NOTCH_O3B10/R15_BACKSIDE_CORPUS_ALL_DEFINITION.json`
- definition SHA-256: `171D21FEF7E199E3B7F247937313571F7D2E17D2DD15A9D53D6D038798DDB654`
- clone-literal gate SHA-256: `AF1C4D9E6D82694B1579EE50DEF712BE372509D5980A7E744607EDE53AC02791`
- zero-recurrence pre-action state: `PASS_ARGOS_ZERO_RECURRENCE_PREACTION`
- wrapper state: `PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT`
- harness state: `PASS_ARGOS_POWERSHELL_HARNESS_SAFETY`

## Preserved prerequisites and holds

Every prior withdrawal/no-retry/non-parent record remains preserved. The
frontside hotspot issue remains deferred. No Argos rotation/orientation/
location prior is granted. Fiducial designation, alignment transfer, map,
pose, coverage, and sensitivity prerequisites remain ordered before any
patterned production scoring. BF Slot16 partial coverage remains explicit.
Inspection-held wafers must later remain visible in the dashboard with their
exact held reason. XML, training, and production routing remain ineligible.

## Exact next action

Run project continuity and metadata-only session safety. Then build, path-gate,
sign, and publish exactly one R15 full-backside corpus request using the pinned
launcher/detector/configuration and collect its matching signed terminal launch
response. Do not retry. Observe `C15RUN2/SUMMARY.json` only through the
qualified signed read-only route. Freeze and compare all `943` rows against R14
before any additional detector change. Inspect every residual hold from its
actual result and overlays before tuning.
