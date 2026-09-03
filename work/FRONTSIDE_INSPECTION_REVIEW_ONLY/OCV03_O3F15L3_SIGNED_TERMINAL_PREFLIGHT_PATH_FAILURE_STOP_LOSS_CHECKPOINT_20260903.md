# OCV-03 O3F15L3 signed terminal PREFLIGHT path failure and stop-loss checkpoint — 2026-09-03

Disposition: `DIAGNOSTIC_ONLY`

## Outcome

The one authorized portal-only O3F15L3 request was published exactly once and
its one matching JBOD-signed terminal response was collected. The endpoint
completed its bounded maintenance envelope, but the sole authorized child
`D:/AFCV1/rt/python.exe -I -B Run-O3F15FrontReconcile.py PREFLIGHT` returned
exit code `1`. This is terminal diagnostic evidence, not authority to retry or
to create a successor.

The child failed before image reads, corpus execution, detector result-root
creation, `SELF_TEST`, `GATE`, or `RUN`. No source was mutated or deleted. No
existing task or process was acted on, no provider was activated, no selector
or threshold was relaxed, and no hold was cleared.

## Exact publication

- Request ID: `REQ_20260903T090514331Z_84BB875EEFD2`
- Signed request ZIP SHA-256:
  `CD681FD47BFF21DE532AC430176D543FF93EF19E1AE8462BE6745A6ECCA86FEA`
- Manifest SHA-256:
  `654163E54DC0166EEA56704772810A7002A57A57354D52FBAAFC99CC3208215F`
- Signature SHA-256:
  `1551E1CC4681AEC5B51803AB7F3C627D8A5E956D28973EEDC97BA9F27C4344FC`
- Publication gate:
  `work/OPENCV_EDGE_NOTCH_O3F15L3/O3F15L3_PUBLISH_GATE.json`
- Publication gate SHA-256:
  `51782860EB94544E4E00F5F3A49559B6C8971D87A8715E453A5DF88D15D1BB16`
- Publication count: `1`
- Automatic retry authorized: `false`

Gateway acceptance was not treated as execution evidence. Completion is based
only on the matching signed response below.

## Matching signed terminal response

- Response ID: `R_B8A16CFA33BC_20260903092008761_68e46cd3`
- Response ZIP bytes: `3247`
- Response ZIP SHA-256:
  `EBA59835968348AFEBAB8A35ED45A546D7E7EB8865C64A28597B9A3952BA133E`
- Response manifest SHA-256:
  `C0A7B6C35002F6B613A11CA2771509AAFD78C0FA40550D8BE616DC4E3D54DFF9`
- Endpoint signer certificate SHA-256:
  `5220D138831BC1CD97ABF6E37F7E67D5C0569B8CE8EED2F6EF35A24C4A88F08B`
- Endpoint state: `PASS_MAINTENANCE_PATCH`
- Signed diagnostic state: `COMPLETE_O3F15L3_PREFLIGHT_DIAGNOSTIC_CAPTURED`
- Child outcome: `FAIL`
- Child exit code: `1`
- Child timed out: `false`
- Exact owned child count: `1`
- Response collection gate:
  `work/OPENCV_EDGE_NOTCH_O3F15L3/O3F15L3_RESPONSE_COLLECTION_R2_GATE.json`
- Response collection gate SHA-256:
  `1DAD141DA1DD4CD5855CC0F6F231C2969306D6563467426EAF9D92D159DCC9D9`

## Exact diagnostic blocker

The signed stderr identifies the first rejected canonical source as:

`D:\KLARFExport\BackSide_BowComp\Lot_62627-198-POST-IVS\62627-198-POST-IVS_20260730103451\Slot19\BrightfieldFrontsideWafer\resizedImage\62627-198-POST-IVS_Slot19_BrightfieldFrontsideWafer_PM2_resizedImage.bmp`

Its raw path length is `207`. The frozen O3F14 path rule adds a suffix reserve
of `32`, producing effective length `239`. The frozen canonical effective
limit is exclusive `< 230`, so PREFLIGHT correctly raised
`AliasContractError: BF canonical effective path is unsafe` before reading the
image. The premise that all frozen ordered-978 canonical paths already met the
O3F14 canonical budget is disproved.

## Collector correction evidence

The first frozen local collector invocation failed in non-mutating preflight
before creating its local root because Windows PowerShell 5.1 reported the
already-documented `ComputeHash` byte-array overload ambiguity. It is retained
only as withdrawn evidence:

- R1 failure record SHA-256:
  `79178A77289AB7C85F7383E112B5D13E2E2DC3B3E90D1D618683F44254EA958C`
- R1 collector SHA-256:
  `09F1B34B77F9E85C258F82901F7E66073F41E7557C0EA0D524499341F6C18991`
- R1 invocation SHA-256:
  `5A2C1B5B96FB68C9147690CEB31403464A0B3F0C0E1621529B15556EEA7BF1F0`
- R1 local root created: `false`
- R1 remote mutation: `false`

The R2 collector uses explicit typed byte arrays at the overloaded hash call
and a non-enumerating ZIP-entry byte boundary. Its exact PS5.1 harness,
wrapper, clone-literal, signature, entry-set, entry-hash, and path preflights
passed before collection:

- R2 collector SHA-256:
  `0510602617F885814013D30E1F9CEFD50BD655770D117525EE7ABD3D42768D82`
- R2 invocation SHA-256:
  `1FE72A93ECD9DC07A717255DFD3DE316D5638B7A96D2E049A1DC17E885DB3DA4`
- R2 clone manifest SHA-256:
  `43DC9FA5E11F45C2DF8EBF86B19BD0A99C98F276ABB7EFE6B316F17068B877FA`
- R2 clone gate SHA-256:
  `FECDFC93D3C9EE16FB1A39ACC8C2DBC0965B3D1B4FCB355D04E476318357E1D3`
- Fresh local collection root: `C:\O3F15L3C2`

## Holds and authority

- All frontside holds preserved: `184`
- Current PatternedFront holds preserved: `12`
- Slot02 ambiguity hold preserved: `true`
- Rare-hotspot Slot16 hold preserved: `true`
- All earlier map, pose, registration, fiducial, coverage, sensitivity, and
  production prerequisites remain ordered and unresolved where previously
  recorded.
- Review-only: `true`
- Training eligible: `false`
- XML eligible: `false`
- Production eligible/routing enabled: `false`
- RustDesk used: `false`
- Operator input required: `false`

## Stop-loss and next action

O3F15L2 and O3F15L3 now constitute two signed premise failures in the same
incident. Mutation stop-loss is active. Do not publish, retry, create, sign, or
execute another successor package, and do not alter the frozen canonical path
limit or bypass it. Resume only after workflow review and a fresh explicit
recovery intent clears stop-loss. Any later design must treat the effective
length `239` Slot19 BF canonical path as a locked negative control and must
preserve all holds and review-only authority.

## Checkpoint preaction

- Contract:
  `work/OPENCV_EDGE_NOTCH_O3F15L3/PREACTION_O3F15L3_TERMINAL_CHECKPOINT.json`
- Contract SHA-256:
  `03423DA0399237A3A1A90598D2C770EFDDECD44334FA48AC0DF122B8ECCCDFC4`
- Gate:
  `work/OPENCV_EDGE_NOTCH_O3F15L3/O3F15L3_TERMINAL_CHECKPOINT_PREACTION_GATE.json`
- Gate SHA-256:
  `23642697B7FFB0B70004AB69DFDEEE19ABFA94A215C1EC8D4DCE39E8E69C9D30`
- Gate state: `PASS_ARGOS_ZERO_RECURRENCE_PREACTION`
