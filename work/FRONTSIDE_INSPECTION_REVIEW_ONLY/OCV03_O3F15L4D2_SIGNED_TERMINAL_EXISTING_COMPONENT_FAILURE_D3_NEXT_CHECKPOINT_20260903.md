# OCV-03 O3F15L4D2 signed terminal existing-component failure / D3 next

Date: 2026-09-03

Disposition: `DIAGNOSTIC_ONLY`

The fresh read-only F3 response finder corrected only the Windows PowerShell
automatic `$Matches` collision. Finder
`work/OPENCV_EDGE_NOTCH_O3F15L4D2F3/Find-O3F15L4D2ResponseF3.ps1`, SHA-256
`6644B225495F7575681E1825E6F98EA6D54DC742031F90B35EA06AF467986A40`,
ran exactly once and located exactly one response for the already published
request `REQ_20260903T125334383Z_CA2B943D4CB0`. It observed 549 retained ZIPs,
one post-publication candidate, and one exact request-manifest match. No request
was retried or republished.

The matching response is
`R_ACB193568962_20260903133607394_714fcac9`, 3,189 bytes, SHA-256
`4A26C88AF87D958BEC63A1140534CE67D540E9F4158BC58298C5774B71F245FF`.
The endpoint RSA-SHA256-PKCS1 signature verifies against thumbprint
`DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`. Collection gate
`work/OPENCV_EDGE_NOTCH_O3F15L4D2/O3F15L4D2_RESPONSE_COLLECTION_GATE.json`,
SHA-256
`695E8B1E0C6C6A3588BBA1DEFE223D47465108C88F36CC7C4C2050913534D18C`,
is `HOLD_O3F15L4D2_MATCHING_SIGNED_TERMINAL_RESPONSE_COLLECTED` and remains
diagnostic-only.

The exact endpoint outcome is terminal `FAILED`. The sole owned metadata-only
child started, read zero image bytes, and exited `1` before Q mapping, detector
execution, or result-root creation. Its exact failure is
`L4AliasContractError: BF alias component exceeds 80 characters` from
`generalized_alias_plans`. The local synthetic 978 gate used short generated
filenames and its one real-shaped Slot19 BF filename remained below the
component boundary, so it did not exercise an existing source component above
80. D2 is frozen, withdrawn from reuse, and no-retry.

The next action is a fresh D3 metadata-only successor that changes only path
classification semantics and its exact tests/contracts: preserve every
canonical path, byte count, and SHA-256; distinguish exact existing source
components from newly introduced output components; keep the 80-character
hard stop for every introduced component and the 32-character suffix reserve;
exercise existing source boundaries 80, 81, and 255, reject existing 256, and
reject a new 81-character component in one local gate; then build, sign, publish once, and
collect one matching response. D3 must not run SELF_TEST, focused test, Q,
GATE, RUN, images, a detector result root, or any source/task/process/provider,
selector/threshold, or hold action on JBOD.

No full frontside corpus package is authorized until a matching signed
complete response proves `ACTUAL_FROZEN_978`, 978 unique identities, and 1,956
ordered source leaves. All 184 frontside holds and all twelve PatternedFront
holds remain, including Slot02 ambiguity and rare-hotspot Slot16. The required
order remains frontside completion, scribe, combined/unified outputs, then
fiducial/alignment. Review-only is true; training, XML, production eligibility,
and production routing are false. RustDesk, clipboard/GUI PowerShell, and
operator input remain prohibited.
