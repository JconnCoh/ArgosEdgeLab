# OCV-03 O3F12 signed terminal failure / O3F13 next — 2026-09-02

Disposition: `PENDING_GATE`

O3F12 request `REQ_O3F12_20260902A` was published exactly once from commit
`82dd787d8f0a5f873238291ea019c52ad88cb0ee`; publication gate SHA-256 is
`6862D61267D5413DDC5B014A95212B7638AF3E5D9E632BD4C50743B21214B3E0`.
Matching signed response `R_54F106F81E95_20260903041718428_977693bc`, ZIP
SHA-256
`BF715C256BC7566BE02BB5E3F8A5B0567CB1ECA4215889E41D5F95E99EE4624C`,
is signature-verified and `FAILED`. Exact terminal gate
`work/OPENCV_EDGE_NOTCH_O3F12/O3F12_SIGNED_TERMINAL_FAILURE_GATE.json`,
SHA-256
`8C38FE83BDB145F76CFED9129239A0AE2DE34CDCFC5CA8CF4ECD19B6CCD2ADB7`,
classifies a packaged DEV6 result-projection contract failure, not a live-state
premise failure.

The unchanged staged runner emitted bounded structured state
`HOLD_O3F12_DEV6_EXECUTION` with exit code 2, but the O3F12 endpoint asserted
zero before parsing stdout. It therefore discarded the structured six-case
result and returned only `O3F12 DEV6 child failed:` with empty child stderr.
No DEV6 case results or inner hold identity were returned. Source-image reads
are inferred from the frozen runner exit contract but not directly confirmed
by the response; `D:/O3F9D12.failed` is expected by the executed endpoint but
was not directly observed. These facts cannot clear or reclassify any hold.

O3F12 is `WITHDRAWN`, diagnostic-only, no-retry, non-reusable, and not a
publication parent. O3F9, O3F10, and O3F11 retain the same withdrawn,
diagnostic-only, no-retry, non-parent status. Exact R10
`0EEEE7A396E918AF44082EC0930871A6A94C1FBB59D3F5CEF1AC34D1273745FA`,
runner `7FA26CF830CAE3FFEB1B34295408E6551F96003A9AC3E07896F750BE5B8492A1`,
thresholds, selectors, six source identities, and the temporary `Q:` alias
lifecycle remain frozen.

Fresh O3F13 recovery observation
`work/OPENCV_EDGE_NOTCH_O3F13/O3F13_RECOVERY_OBSERVATION_EVIDENCE.json`,
SHA-256
`76A7B8291ACE0E67B677192A683478C534ABD6A5AF7E43392B37E9A284A2F174`,
supports only endpoint-consumer remedy B. Recovery intent
`work/OPENCV_EDGE_NOTCH_O3F13/O3F13_RECOVERY_INTENT.json`, SHA-256
`7F5CC35D9D822D00795FF7653ABFDB6D0F2F40D298ECD93DA7F12C9B8C64B402`,
authorizes one fresh namespace to parse one bounded DEV6 JSON object before
mapping documented exit 0 to completion and exit 2 to an explicit hold.
Timeout, nonempty stderr, malformed JSON, and all other exit codes remain
failures. No detector algorithm, threshold, selector, source-set, alias, task,
existing-process, provider, or authority change is authorized.

All 184 O3F6/O3F7 holds remain explicit, including all twelve current
`PatternedFront` holds and rare hotspot Slot16. Every earlier backside
hold and every scribe, fiducial-designation, map, pose, coverage, sensitivity,
registration, and alignment prerequisite remains in force. No post-result
selector relaxation or automatic hold clearance is authorized. Review-only is
true; training, XML, production eligibility, production routing, source
mutation/deletion, provider activation, task action, existing-process action,
and wafer action remain false.

Next action: build, gate, and sign only fresh O3F13 with the bounded consumer
correction above. When every required local and route gate passes, publish it
through the recorded Project Portal route exactly once and collect only its
matching signed terminal response. Use no RustDesk, clipboard, PowerShell GUI,
operator Enter, or retry. Only a lawfully returned six-case result may advance
targeted frontside BF/DF hold reconciliation; continue afterward in recorded
order to scribe, combined corpus/unified outputs, and site-bound
fiducial/alignment prerequisites. Production scoring remains blocked.
