# OCV-03 O3B21 R30VAL1 signed 70-case validation ready — 2026-09-01

Disposition: `PENDING_GATE`

## R29 signed result and interpretation

R29VAL1 request `REQ_20260901T215551125Z_E3A895430234` returned matching
signed terminal response `R_77199CE0FDDC_20260901220505464_293420ac`.
The response ZIP SHA-256 is
`2288AC05EDDB72E4B4D72C031527959CC9BB90A190A124006FE3659EB10878CC`;
the signed response manifest SHA-256 is
`257BF1B771A51FB80B9B4777228F16DD1A093BB192CC66A5300D6FDECEFF4237`.
The endpoint and exact 39-execution wrapper passed. Source mutation/deletion,
existing task/process action, provider activation, automatic hold clearance,
training, XML, and production authority all remained false.

The intended Slot20 left-notch target passed uniquely at mean angle
179.566433 degrees. The same-scan Slot16 control passed uniquely. All three
current PatternedFront smoke pairs passed uniquely. Two of three current
UnpatternedFront smoke pairs passed uniquely. The third contained the clean
strict-both notch at 90.208542 degrees plus a second legacy soft-confirmation
pair at 133.878529 degrees. Both channels of that extra pair failed the already
frozen R13 exterior-clear limits. The new R29 confirmation mode did not create
it.

The other three expectation changes were interpreted and frozen: the second
Slot20 left-notch case is an intentional clean rescue; the operator-excluded
`PST_BRKFULLMETAL/ProcessJob11/Slot19` damaged image remains an explicit
zero-count hold; and the BowComp Slot04 clean 89-degree pair is a legitimate
existing-path rescue. The exact machine terminal gate is
`work/O3B21/R29VAL1_SIGNED_TERMINAL_RESULT_GATE.json`, SHA-256
`2E4B966C76E8F2BF2754B2BD50B981EA2AE7CA98940F6AB2D4B72219CEDDF1CC`.

## R30 minimal negative control

R30 is a detector-only successor over hash-pinned R29. It removes a pair only
when its confirmation mode is one of the two legacy soft modes and both
channel-local exterior contexts fail the existing R13 appearance-clear limits.
If either channel is exterior-clear, the legacy soft pair remains. Strict-both,
R29's Slot20 rescue mode, and the strong-DF/shallow-BF paths are untouched.
This is a bounded false-positive negative control, not a post-result selector
relaxation and not a threshold change.

- detector: `work/OPENCV_BACKSIDE_NOTCH_O3B10/Detect-BacksideNotchOpenCvR30.py`
- detector SHA-256: `A300D2667DE021A9C1E177CF475E4A04ED3B87F41D7BFA9DCEF0A1DB06BE8625`
- focused R30 tests: 13/13 pass
- packaged predecessor tests: R28 33/33 and R29 13/13 pass
- total packaged synthetic tests: 59/59 pass

## One broader batched validation package

Signed request `REQ_20260901T221440855Z_AA1D598B751C` is ready for one
exactly-once Project Portal publication.

- ZIP: `C:/R30VAL1PK/REQ_20260901T221440855Z_AA1D598B751C.ready.zip`
- ZIP SHA-256: `7A69ED41EF1CCD7F0B0E63EE3609B630B09979696E93B450EF2B98B85CEC726F`
- ZIP bytes: 62,966
- manifest SHA-256: `1FCA6131EB7901D21A1B9743A80C2ADAF3010C4986B618D7607E3049FD5866D4`
- signature SHA-256: `E1DFFB6246609C1301BB5B362C952214EB509D4D386FF07D7BBF90377B2B23F0`
- packaged payload files: 24
- real-image executions: 70 at maximum concurrency three
- synthetic tests before image execution: 59

The 70-pair set contains all 32 frozen controls/holds with their interpreted
R29 expectations, one same-scan Slot16 control, all 25 exact newly added
PatternedFront pairs, and 12 deterministic evenly spaced UnpatternedFront pairs
including the sorted first and last identities. The inventory remains pinned
at SHA-256
`D6DF4E260A9B6B559B2A13ED4159F6DA7F3648E3CFABBF080F2171BB4D5D110C`.
Every source is hashed before detector execution and verified unchanged after.
All outcomes are returned even on mismatch.

Windows PowerShell 5.1 signature/extraction and exact packaged-entry tests,
all packaged synthetic tests, 22-root path budgeting, harness safety, clone
literal remediation, and R2 90-issue zero-recurrence preaction pass. Maximum
effective route length is 187. The package has zero allowed task actions and
uses the unchanged same-bytes configuration carrier.

## Authority and exact next action

Commit and push the frozen artifacts, require clean matching branch tips, then
publish the exact R30VAL1 request once and collect only its matching signed
terminal response. Do not retry. Preserve every hold and no-retry artifact.
Only an exact 70/70 pass may authorize one fresh exact frozen-953 backside
corpus. Review-only remains true; training, XML, production, provider
activation, source mutation/deletion, existing task/process action, and
automatic hold clearance remain false.
