# OCV-03 O3F15L1 local signed-rehearsal failure / O3F15L2 next — 2026-09-03

Disposition: `PENDING_GATE`

O3F15L1 built and signed exact review-only request
`REQ_20260903T073146289Z_52B5864F4522`, ZIP SHA-256
`AEEA0E60DA44E4C333528EEEE1DE5F1CD8AF2CCB6045ACC8E1F7EBDC059F7EA1`,
manifest SHA-256
`865FC9BFA09A96BFC27BAEA3F30D40DCE7B2CF8D85EEC75EC90BAF97267DB025`,
and signature SHA-256
`0629E696FA969211BA638DDDD7AC168C5E4DC27EB3D449682524A30AF546ECAC`.
It was never published and never reached JBOD.

The exact signed-ZIP rehearsal passed signature verification, the packaged
focused test, package-leaf preflight, and the normal owned-worker launch. Its
deliberate create-new collision case then failed locally before returning the
required bounded hold JSON. Direct inspection of the preserved fixture at
`C:/O3F15L1V1` returned exact error `The variable '$fixtureMode' cannot be
retrieved because it has not been set.` The endpoint assigned `fixtureMode`
inside `Invoke-O3F15L1Main`, but its outer script-level catch read that
function-local variable under StrictMode.

Machine failure evidence
`work/OPENCV_EDGE_NOTCH_O3F15/O3F15L1_LOCAL_REHEARSAL_FAILURE.json` is SHA-256
`89288A4C0C1B0343613007EF732F8C7A7681D49AD8EDD88AC59708CC6A52EBC5`.
Direct recovery observation
`work/OPENCV_EDGE_NOTCH_O3F15/O3F15L1_RECOVERY_OBSERVATION.json` is SHA-256
`31E5645EF92552D4DC2F16FEE2DD79D5A1660C735E78214D610FBF290985CAFB`.
Recovery intent
`work/OPENCV_EDGE_NOTCH_O3F15/O3F15L2_RECOVERY_INTENT.json`, SHA-256
`5A3C42E68D63895F47D964F662AD34246C360A1C1820845AC4F883DD1EC3EF76`,
passes gate SHA-256
`DFA605564C01AE108CA338A44C8703EBE4B685D012912BA86829ABEE284BD19A`.
Signed-premise failure count is zero, local-premise failure count is one, and
mutation stop-loss is not active.

O3F15L1 is `WITHDRAWN`, no-retry, non-reusable, and non-parent. Its exact ZIP,
signing tree, and fixture root are retained as evidence. No source image was
read; no source, JBOD, portal queue, existing task/process, provider, wafer,
training, XML, or production state was touched.

Only fresh O3F15L2 may proceed. Its sole semantic correction is explicit
script-shared rehearsal context initialized before the main function, updated
after the rehearsal manifest is validated, and read by the outer catch. R11
`B477C290EC9D3AE388BE4EE31049B2B8094F5F30FC6E0DD68AB4A03926EE4059`,
runner `DCE1E1F3B42FBD38ED73FF7D346F19C3BAE013EE3003B3485E91A41DAF573C48`,
focused test
`37F1D9980CA0635673D39B3E9B5EBC2BCF21021EB329ABD8C64820F518FC6C47`,
all detector thresholds/selectors, exact 978 identities, execution order,
live `D:/O3F15*` roots, mirror root, and authority limits remain unchanged.

All 184 O3F6/O3F7 holds and all twelve current `PatternedFront` holds remain
explicit, including Slot02 multiple-candidate ambiguity and rare-hotspot
Slot16. Every backside, scribe, combined-output, fiducial-designation, map,
pose, coverage, sensitivity, registration, and alignment prerequisite remains
in force. There is no post-result selector relaxation or automatic hold
clearance.

Next action: build, sign, and run all exact local O3F15L2 package/installer/
collision/immediate-exit/path rehearsals once. Only after those gates pass may
the fresh L2 request be committed, pushed, and published exactly once through
the unchanged recorded Project Portal route. Collect only its matching signed
launch response, then observe the background exact-978 result through fresh
DATA_PULL requests. Do not use RustDesk, clipboard, PowerShell GUI, operator
Enter, or retry. Review-only remains true; training, XML, production
eligibility, and production routing remain false.
