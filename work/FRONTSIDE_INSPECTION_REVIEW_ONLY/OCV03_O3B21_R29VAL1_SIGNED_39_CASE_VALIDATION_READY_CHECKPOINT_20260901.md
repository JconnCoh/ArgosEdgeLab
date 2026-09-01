# OCV-03 O3B21 R29VAL1 signed 39-case validation ready — 2026-09-01

Disposition: `PENDING_GATE`

## Completed detector design

The R28 rotation/holder diagnostic completed through matching signed JBOD
response `R_790758480D0E_20260901214151207_657582a9`, response ZIP SHA-256
`D4D756E0F619B553CD6F1EFF964CA29A4647A3E670881BC2AFD839BAD5BA9B4A`.
All eight executions completed in 54.423 seconds. The failed Slot20 result
remained zero-pair in original and CCW90 orientations and with exact versus
diagnostic-no-holder masks; the passing same-scan Slot16 remained one-pair in
all four variants. Angles shifted exactly 90 degrees and holder ablation did
not materially change the candidate measurements. This excludes an
angle-coordinate rejection and holder-mask cause. No no-holder result cleared
a hold or became detector logic.

R29 is the minimal detector-only successor over frozen R28. It adds one
fail-closed cross-channel mode: a holder-clear BF candidate that satisfies all
manufactured morphology gates except the narrow frozen symmetry boundary may
be confirmed only by a holder-clear, exterior-clear, broad-strong DF candidate
within the frozen 1.5-degree angle tolerance. It uses only existing R13
thresholds. It does not relax the base selector, holder mask, or any R28 path.

- detector: `work/OPENCV_BACKSIDE_NOTCH_O3B10/Detect-BacksideNotchOpenCvR29.py`
- detector SHA-256: `72F0DAAE7DC66D4627F03A265B65C137D7362A60C27AA649BAFE564FC515EB65`
- frozen config SHA-256: `27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3`
- frozen R28 SHA-256: `4F51BA7E8D261BF196CE559C420A4F511F0D06B39BE5F512D2E6ABF585681466`
- R28 packaged tests: 33/33 pass
- R29 focused tests: 13/13 pass

## One batched validation package

Signed request `REQ_20260901T215551125Z_E3A895430234` is ready for one
exactly-once Project Portal publication.

- ZIP: `C:/R29VAL1PK/REQ_20260901T215551125Z_E3A895430234.ready.zip`
- ZIP SHA-256: `F9803B8F4EF9747CB3EF6D14B07C0DC52AF22FAEA915E3A0DB39B1280E40B285`
- ZIP bytes: 56,605
- manifest SHA-256: `1501A2C140A036CDDC6916AB54112DCD3746B9F6C2773768EBA1A1A11618C52D`
- signature SHA-256: `B8F3D7969D2A9771DD8B82372B8E4E3516446C19C45DC0A6126549B655AC1D41`
- packaged payload files: 21
- real-image executions: 39 at maximum concurrency three
- synthetic tests before image execution: 46

The real-image set is 32 frozen controls/holds, one same-scan Slot16 control,
and deterministic first/middle/last smoke pairs from each current
`PatternedFront` and `UnpatternedFront` inventory prefix. The current inventory
is pinned at SHA-256
`D6DF4E260A9B6B559B2A13ED4159F6DA7F3648E3CFABBF080F2171BB4D5D110C`;
the six smoke source hashes are captured before detector execution and checked
again afterward. The package returns all 39 outcomes even if an expected
cardinality fails, so one delivery supplies the complete tuning evidence.

Windows PowerShell 5.1 signature/extraction, exact packaged-entry preflight,
46 packaged tests, path budget, harness safety, and zero-recurrence preaction
all pass. The package uses the unchanged same-bytes config carrier, declares
zero task actions, and cannot activate a provider. A proposed auxiliary direct
hash observation stopped at local command parsing before any RustDesk/JBOD
input; it was not retried and is not relied upon.

## Authority and next action

Publish the exact request once, collect only its matching signed terminal
response, and interpret the 39 outcomes. Preserve the damaged negative,
notch-adjacent negative, holder controls, all other holds, and no-retry
artifacts. A fresh exact-953 corpus remains unauthorized until this validation
passes. Review-only remains true; training, XML, production, provider
activation, source deletion/mutation, existing task/process action, and
automatic hold clearance remain false.
