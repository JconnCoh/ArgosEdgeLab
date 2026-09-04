# OCV-03 O3F16 U12 launch terminal / archive pull ready — 2026-09-04

Disposition: `PENDING_GATE`

Request `REQ_20260904T132109333Z_DEF3809379EC` was published exactly once.
Matching response `R_3E3DDEADD12A_20260904132820956_b463faaa` verifies against
the pinned JBOD signer `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC` and is terminal
`PASS_MAINTENANCE_PATCH`. Response ZIP SHA-256 is
`042FEF75BD204DAAD138383D99E45FA6EDB993AEEFFC11FDA2AF16A31DB1232A`.

The endpoint installed exact R12 SHA-256
`1696DBE407E4461B351C6B939C591A4E652E558DF15BF4AC5CEFB369950FF7F6`
only in the existing development root and completed all four requested cases.
Fresh `D:/O3F16U12` contains 81 files. `SUMMARY.json` SHA-256 is
`7B5760BEBFB4C5096201A8D81535D27807D6EA6331510BC85C194065303A8CBC`.
The portal-readable archive is 134,273,367 bytes, SHA-256
`5B80DBF6F71E2DF01D8850F2D2301C9DBE27D258416D2058E5F93DEE9FD3C4F2`.
No source mutation, existing task/process action, provider activation, retry,
or hold clearance occurred.

Fresh read-only DATA_PULL request `REQ_20260904T133028436Z_0AF28A2F2529`
is signed but unpublished. Its 1,146-byte request ZIP SHA-256 is
`F0C5C934E35A28C3161623617BF8E1CC762568A702A35215A73F1F525505BDAB`.
It requests only
`JBOD_KLARF_EXPORT/_ArgosReview/O3F16U12_20260904.zip`, with one file and
134,273,367 bytes as exact maxima. The complete path gate passes with 32
reserved suffix characters and maximum effective length 124.

## Next action

After clean matching local/origin tips and an empty portal request queue,
publish this exact DATA_PULL once with no retry. Collect only its matching
JBOD-signed terminal response, require the returned archive hash and byte count
to match the launch response, and extract create-new locally. Verify the exact
R12 summary and all declared asset hashes. Inspect every BF/DF native-width raw,
global-minmax enhanced, full-band, and overlay strip at original detail for
straightening, dark-sector drift, artificial stitching, visible physical
notch/edge relief, chipout-retaining width, and rear-holder contamination.

POST2 and the genuine microchipout lot remain sequenced after a clean U12 strip
gate. T5, targeted-11, 978, scribe, provider activation, hold clearance,
training, XML, and production remain unauthorized.
