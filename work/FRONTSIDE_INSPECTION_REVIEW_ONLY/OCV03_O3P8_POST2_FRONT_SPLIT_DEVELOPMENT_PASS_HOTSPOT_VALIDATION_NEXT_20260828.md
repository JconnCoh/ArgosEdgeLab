# OCV-03 O3P8 POST2 front split-method development pass / independent hotspot validation next — 2026-08-28

Disposition: `PENDING_GATE`

This is a review-only continuity checkpoint. It freezes the successful O3P8
POST2 development regression and the exact ordering for the next independent
Slot16 hotspot validation. It does not approve production use, activate a live
provider, clear a hold, or authorize reuse of the rejected O3N1 gallery.

## Operator contract retained

The exact operator baseline remains
`work/OPENCV_EDGE_NOTCH_O3P1/O3P1_OPERATOR_BASELINE_20260827.json`, SHA-256
`3FCB84A45222DE536BC1CD11B84B3BAE455943CED9E7719BAA0C1DCB2D7CF333`.
O3L8 is the accepted contour-evidence direction. O3N1 is immutable withdrawn
evidence, is not a successor parent, and must never be presented as a corrected
result. The successor contract is raw 360-degree inference with no Argos
rotation, orientation, or location prior. The known upper-right Slot16 display
location is allowed only after inference for scoring. Unsupported contour spans
must never be drawn or labeled as measured.

Frontside channels and backside are allowed separate methods. O3P8 uses BF
topology and DF radial outer-edge evidence independently. Backside pixels were
not consumed and backside requires a later, separate appearance-regime intent,
development method, and freeze.

## O3P7 terminal-schema failure withdrawn

O3P7 completed the detector output but its launcher failed while constructing
the terminal gate because it consumed an aggregate
`candidateLocalTopologyInsufficiencyCount` property that did not exist in the
engine terminal stdout schema. The count existed only on the individual output
rows. O3P7's executed namespace is withdrawn and cannot be rerun or reused.

- failure: `work/OPENCV_EDGE_NOTCH_O3P7/O3P7_LOCAL_REHEARSAL_FAILURE_20260828.json`, SHA-256 `17071FE62710CCEB551E2B5C1C47BE1B4B415F892B1F3583342F736223C3D48C`
- direct post-failure observation: `work/OPENCV_EDGE_NOTCH_O3P7/O3P7_POST_FAILURE_OBSERVATION.json`, SHA-256 `7C24B0C659D48CEE6E920D1EE39DD683C677DBE9A9EEDE399B7292744056F455`
- O3P8 recovery intent: `work/OPENCV_EDGE_NOTCH_O3P7/O3P8_TERMINAL_SCHEMA_RECOVERY_INTENT.json`, SHA-256 `38A8CC65138A57FE8C7E8FBFD46118D4F1DECE6958A0AC6DCBCB4EE40691A5A7`
- updated failure-prevention memory: `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`, SHA-256 `019DC0CE4E677E157B790E1211440724BE7A62E1B37544747B2B8DF4E7D3BF6F`

## O3P8 fresh-namespace correction

O3P8 changes namespace, output locations, and terminal-gate schema plumbing
only. The detector algorithm, thresholds, and exact POST2 source set are
unchanged from O3P7, mechanically proven by
`work/OPENCV_EDGE_NOTCH_O3P8/O3P8_DETECTOR_CONFIG_EQUIVALENCE_GATE.json`,
SHA-256 `CF896E114179370BC9C8A58D64FDD3470EDCAB1A96836252693C935845224F95`.

Frozen O3P8 implementation and gates:

- engine: `work/OPENCV_EDGE_NOTCH_O3P8/Detect-O3P8FrontSplitNotches.py`, SHA-256 `41F60AF393E0B2C752AF6B33BB6673145490AE2BB346A4DA8E59A2D42E383E36`
- job: `work/OPENCV_EDGE_NOTCH_O3P8/O3P8_POST2_SHORT_ALIAS_JOB.json`, SHA-256 `2C2D656A879BBA1DEC6377D1855A949459C7AC6F50145761B8D283076FEAD1F9`
- synthetic gate: `work/OPENCV_EDGE_NOTCH_O3P8/O3P8_SYNTHETIC_GATE.json`, SHA-256 `CEE4B1849042C86938084F91A4892118BE1E43D1648B587280113C3FFFA67A63`
- exact terminal fixture: `work/OPENCV_EDGE_NOTCH_O3P8/O3P8_ENGINE_TERMINAL_GATE_FIXTURE.json`, SHA-256 `127F3018CB9B203D34C045158C8880A424DFD9B6EC3114E47CA2C92D13BE1963`
- launcher: `work/OPENCV_EDGE_NOTCH_O3P8/Invoke-O3P8Post2ShortAlias.ps1`, SHA-256 `33798DA9B8D4C218702CC20344FC5B62ADB7AB4154DBEBF43EAF2AE2854F50CC`
- invocation: `work/OPENCV_EDGE_NOTCH_O3P8/O3P8_SHORT_ALIAS_LAUNCH_INVOCATION.json`, SHA-256 `A5565C8583E4A951AD5B4AC1F8587BBAC3A9ACCADA4059ADDE13D889BA874FC4`
- path gate: `work/OPENCV_EDGE_NOTCH_O3P8/O3P8_POST2_SHORT_ALIAS_PATH_GATE.json`, SHA-256 `2AE6164F1C37B2F8FAF1F280D7F98E8EC21BB23DB2FAC61812226CADD8050FDA`
- preflight gate: `work/OPENCV_EDGE_NOTCH_O3P8/O3P8_POST2_PREFLIGHT_GATE.json`, SHA-256 `DAF738CB29ED4CB0F6974CC3F222BB33C2A75ED2118384F00FF8BFFCB03ABDAB`

The synthetic gate passes deep, shallow, and broad positive shapes; a narrow
periodic negative; a no-notch negative; BF/DF angle mismatch; injected member
exception continuation; and zero DF-topology calls. The exact Windows
PowerShell 5.1 launcher preflight exercises the same terminal-gate construction
function using the exact engine terminal fixture. The path gate covers 22
constructed candidates, uses the verified short `R:` alias where required,
and has no hard stop.

## POST2 development regression result

The exact execution completed successfully:

- result: `work/OPENCV_EDGE_NOTCH_O3P8/O3P8_POST2_RESULT.json`, SHA-256 `5B7D2D93959F3AA97885682E3909D5C8E736F2E23084C5D84AB5094B58E1E6F8`
- launch gate: `work/OPENCV_EDGE_NOTCH_O3P8/O3P8_POST2_LAUNCH_GATE.json`, SHA-256 `62934E335640DE0C8A5FDB2965284C1E99557B6FFDD1C4050BD94E3FEE479843`
- inference freeze: `work/OPENCV_EDGE_NOTCH_O3P8/O3P8_POST2_INFERENCE_FREEZE.json`, SHA-256 `1112411F82714DAC589AEF53B756095F2FCF663B1BAA10BBD14FA7D5842F6821`
- post-inference scorer: `work/OPENCV_EDGE_NOTCH_O3P8/O3P8_POST2_SCORER_GATE.json`, SHA-256 `FD005EB32416892CAF3819484F56C67DF56A6AE368810AAFB3DFF2B8F7B3960D`

The launch gate state is `PASS_O3P8_POST2_SHORT_ALIAS_EXECUTION`. All three
members produced exactly one unique BF-topology/DF-radial candidate, local
topology insufficiency count is zero, DF topology invocation count is zero,
the temporary `R:` mapping was removed, and no source mutation, network,
backside, task, process, or live-provider action occurred.

The scorer state is
`PASS_O3P8_POST2_DEVELOPMENT_REGRESSION_SCORER_GATE`:

| member | BF selected angle | DF selected angle | frozen expected | maximum error |
|---|---:|---:|---:|---:|
| Slot01 P001 | 90.04732196373999 | 90.03556734938735 | 89.9 | < 0.148 degrees |
| Slot03 | 89.63519434998574 | 89.64385690044607 | 89.55 | < 0.094 degrees |
| Slot17 | 89.6753506577232 | 89.64755723590974 | 89.6 | < 0.076 degrees |

Slot01's known chipout at 85.503639 degrees was not selected. These rows are a
development regression only. They are not independent validation.

## Frozen frontside method

- BF only: O3L8 top-connected measured-contour topology over raw 360 degrees.
- DF only: frozen R6 full-360 outer-edge radial evidence.
- DF topology is forbidden.
- Candidate seeds are physical BF/DF and DF-only seeds; BF-only seeds are excluded.
- minimum DF radial width is 0.9 degrees; no maximum width is imposed so broad notch variants remain eligible.
- prominence is 3 pixels; maximum BF/DF angle gap is 1.5 degrees; topology-to-DF depth ratio is 0.1.
- No known notch location, Argos pose/orientation/rotation, scorer input, backside pixels, or operator display location participates in inference.

## Independent hotspot action ordered next

At a clean matching local/remote branch tip, rerun project continuity and
metadata-only session safety, then apply recovery, zero-recurrence, wrapper,
harness, and path gates before publication. Create a fresh O3Q1 numeric
review-only request for exact Slot16 sources:

- BF SHA-256 `3F98D5B506B3EF6E18BF9C24A64DC4516F024248DE994BD3DCBD5C8680EB7E90`
- DF SHA-256 `E293D3155A50554104A232C1FF9F1BDA7E6935D798C7266A2C8A0F90FC0A098B`
- canonical root `D:\KLARFExport\PatternedFront\Lot_62629-419_NotchBad_Hotspot`
- qualified short-alias source paths under `F:/62629-419_20260824112405/Slot16/`
- runtime `D:\AFCV1\rt\python.exe`, SHA-256 `7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1`
- installation `D:\AFCV1\INSTALLATION.json`, SHA-256 `1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596`

Adapt O3P8 with namespace/output/gate plumbing only. The detector
algorithm/configuration and source hashes remain frozen. Seed the full-360
numeric evaluation deterministically from every DF candidate in the withdrawn
O3N1 numeric manifest, SHA-256
`69FDAD4AB4DCF06A8A38C76EA009F0DA178896E8D0291668670AB9ADD24A05C8`;
this is candidate enumeration, not use of an operator location prior. Publish
exactly one fresh signed request through persistent `U:` with no retry. Only a
matching JBOD-signed terminal response is execution evidence.

If and only if numeric independent validation passes, create a separately
signed no-retry render followed by a separately signed no-retry DATA_PULL for
only the selected BF/DF contour-hugging evidence. Reconstitute and hash-verify
the returned file-backed gallery before presentation. Never render or present
the O3N1 21-candidate tooth-overlay gallery again.

## Preserved holds and prerequisite ordering

O3N1 and O3P7 remain withdrawn and non-parent. BF Slot16 partial coverage
remains unresolved. Live provider stays disabled; protected processor stays
untouched; backside remains unconsumed; source mutation/deletion, task/process
action, threshold/algorithm change, retry, hold clearance, XML, training, and
production routing remain forbidden. Fiducial designation, map, pose,
registration, coverage, sensitivity, and independent alignment-transfer gates
remain pending and operator-visible.

After the independent frontside hotspot gate passes, freeze the frontside
revision. Then create a separate backside appearance-regime intent and method,
verify frontside and backside on POST2 and the hotspot lot, and fan the frozen
front/back detectors out to separately qualified additional lots. Resume the
paused fiducial work only if both notch programs complete and time remains.

