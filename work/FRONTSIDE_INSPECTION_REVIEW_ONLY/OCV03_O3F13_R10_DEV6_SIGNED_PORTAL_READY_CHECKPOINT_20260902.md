# OCV-03 O3F13 R10 DEV6 signed portal ready — 2026-09-02

Disposition: `PENDING_GATE`

Fresh review-only request `REQ_O3F13_20260902A` is frozen, signed, and ready
for exactly one Project Portal publication. It has not been published or
executed. Final ZIP
`work/OPENCV_EDGE_NOTCH_O3F13/final_o3f13/REQ_O3F13_20260902A.ready.zip`
is 114346 bytes with SHA-256
`6CD1551EB5E7B71FD58542E6313B9528DB37E2CA35884B4BA3BAB39CBB701063`.
The request manifest SHA-256 is
`B90F557E75F7D0B852A4908F402D5124F54E9B18682EBAC2200621590691F301`;
the request signature SHA-256 is
`F19EB4ED3F5EDAC1DA6152159314F37C1F0142F51C4B3A0754792BD9CECFAD29`.
No publication artifact exists yet, and none is claimed here.

O3F13 changes only the endpoint consumer corrected after O3F12. Endpoint
`work/OPENCV_EDGE_NOTCH_O3F13/Invoke-O3F13StagedEndpoint.ps1` has SHA-256
`812391373F107130509A1C19C8D6645C9212C533D69ED738706DAF9DB2563D7B`.
It validates one bounded structured DEV6 result and accepts only exit 0 with
`COMPLETE_O3F12_DEV6` or exit 2 with `HOLD_O3F12_DEV6_EXECUTION`; timeout,
nonempty stderr, malformed JSON, mismatched state/exit, and every other exit
remain failures. Exact R10
`0EEEE7A396E918AF44082EC0930871A6A94C1FBB59D3F5CEF1AC34D1273745FA`,
staged runner
`7FA26CF830CAE3FFEB1B34295408E6551F96003A9AC3E07896F750BE5B8492A1`,
thresholds, selectors, six source identities, and source-alias plan
`2ACA89A702CCC9E8B346EF2E31EF3C34382DF59D23D9DF3E5B431A4E37AD7D9C`
remain unchanged.

Exact prepublication gates are:

- endpoint rehearsal `PASS`, SHA-256
  `73C92FC2A90EDF71B6F62B69823800C63D93A7E3D5A7C069A99D6E33DBD0E675`;
- final package `PASS`, SHA-256
  `DF183E8ECB1CA386D7F41D10C7FF2650981EF260DA9A4F794F0C06CFE4964F04`;
- exact signed-package rehearsal `PASS`, SHA-256
  `CC01A68D4A35A75E9DC840E56CE2424069AD7A417C05D4C22ADB8EB79F71AAA9`;
- complete prepublication route/path gate `PASS`, SHA-256
  `3415B576902E932BE439479C2ADDBDC554E53A809140469E261C3F4390EB4B42`;
- current-share zero-pending observation `PASS`, SHA-256
  `9A0C2C1FBADA05B1510FE86515BEA2FF30693C532C7752A992C9392F065A3635`.

O3F12 remains `WITHDRAWN`, diagnostic-only, no-retry, non-reusable, and not
a publication parent. O3F9 through O3F11 retain the same withdrawn/no-retry/
non-parent restrictions. O3F13 is one-shot and has publication count zero.

All 184 O3F6/O3F7 holds remain explicit, including all twelve current
`PatternedFront` holds and rare hotspot Slot16. Every earlier backside hold
and every scribe, fiducial-designation, map, pose, coverage, sensitivity,
registration, and alignment prerequisite remains in force. No selector
relaxation or automatic hold clearance is authorized. Review-only is true;
training, XML, production eligibility and routing, source mutation/deletion,
provider activation, task/existing-process action, and wafer action are false.

Next action: publish this exact ZIP through the recorded Project Portal route
exactly once, then collect and interpret only its matching signed terminal
response. Do not use RustDesk, clipboard, PowerShell GUI, operator Enter, or
retry. Only a lawfully returned six-case result may advance targeted frontside
BF/DF hold reconciliation; continue afterward in recorded order to scribe,
combined corpus/unified outputs, and site-bound fiducial/alignment
prerequisites. Production scoring remains blocked.
