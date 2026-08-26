# OCV-02 O2D10 local signed package / Argos inbound relay hold — 2026-08-26

Disposition: `PENDING_GATE`

This checkpoint supersedes the O2A3 operator-observation-pending checkpoint.
O2A3 was attempted once and failed closed before observation because its
healthy-processor process premise was false. O2A3 must never be rerun. Direct
file-backed evidence subsequently supplied the exact installed Slot16 proposal,
multi-channel summary, BF/DF detector-input hashes, installed O2D5 reference
bundle, and direct JBOD portal state.

## Frozen local OpenCV evidence

The current engine is
`work/OPENCV_SCRIBE_V1R3/ArgosOpenCvScribeV1R3.py`, SHA-256
`8A6DE04B7DD08EFA717AF606FD0D04622ABE84C753B690C4590B0E95D8B31BAB`.
It passed the locked direct-input parity gate at 15/15 accepted rows and 4/4
duplicate controls, SHA-256
`9C8A4F3952A4C583DC9798DE18920602EAD066BE6BD8AF557A9700509E889245`,
and the full-localization gate at 15/15 plus 4/4, SHA-256
`4CE3794895D008FC7D2105176C5C94EE5678AB76AF4D9B166BE3EE07F02E1353`.

The exact O2D10 Windows PowerShell 5.1/OpenCV rehearsal gate is
`work/OPENCV_SCRIBE_O2D10/O2D10_ENTRYPOINT_TEST_GATE.json`, SHA-256
`8722DD03F76539C270249F78A398A2BAFDA0D6BD011AA3BF1AE93D77366AD636`.
It returned top-level state `SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID` and local
proposal `0438S004FEH0`. That string is diagnostic-only: it is not a frozen or
accepted wafer identity. `SCRIBE_REFERENCE_COVERAGE_HOLD` remained present,
the installed proposal remained in
`MULTIPLE_IMAGE_SUPPORTED_M12_CANDIDATES`, the installed proposal remained
identity-ineligible, and the injected source-hash mismatch failed before write.
The protected processor process identity was unchanged. No task/process
restart, source mutation/deletion, wafer action, hold clearance, provider
activation, XML/training admission, or production authority occurred.

## Local signed request

Fresh request `REQ_20260826T015418549Z_F5D3732576F9` is frozen only on the
engineering laptop at
`work/OPENCV_SCRIBE_O2D10/final/REQ_20260826T015418549Z_F5D3732576F9.ready.zip`.
It is 19,249 bytes with SHA-256
`289276329B5C2A34F8155C33001747034ACB85CC89B16EBB630D9E4F6FC87256`.
The generic signed-package verifier, exact ZIP extraction, three exact payload
hashes, Windows PowerShell parser, final-gate construction rehearsal, and final
package gate all passed. Final package gate:
`work/OPENCV_SCRIBE_O2D10/O2D10_FINAL_PACKAGE_GATE.json`, SHA-256
`CA653F6FA44F0282F52B56DC4B8D158FFFD1AC638AD271A85FD4C43929F98D50`.
The manifest requires normal state
`PASS_O2D10_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED`; the endpoint outer timeout is
900 seconds and the OpenCV child timeout is 600 seconds. The package reuses the
installed 456-reference bundle only by exact SHA-256. Publication remains false.

O2D8 signed-invalid bytes and O2D9 signed/partial-final bytes are `WITHDRAWN`,
preserved as non-reusable evidence, and must never be published or used as a
template parent. O2D6 and O2D7 executed only disposable local rehearsals and are
withdrawn. O2D4 and O2D5 remain non-reusable and must never be rerun.

## Complete route hold

`work/OPENCV_SCRIBE_O2D10/O2D10_COMPLETE_ROUTE_GATE.json`, SHA-256
`B04FF3EF0F389C45C4FC8E4119468A56EB971E8325F2ECAB6ADAA150959061BE`,
enumerates 129 exact paths: five request leaves at nine extracted request hops,
five maximum response leaves at ten response/quarantine/relay hops, every ZIP
archive/staging path, endpoint work/ledger/compact-failure/rollback path, the
installed Slot16 inputs and reference bundle, and all D-drive work/output paths.
All pass with 32-character suffix reserve. Maximum effective length is 193 and
maximum component length is 55.

Direct JEO1 evidence proves the exact JBOD endpoint worker
`CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250`
and the JBOD response-sender process were present, and proves O2D4 absent from
all JBOD request/ledger/work/response/product roots. It does not prove current
Argos inbound relay/queue health. Therefore the route gate terminates at
`HOLD_O2D10_COMPLETE_ROUTE_GATE_ARGOS_INBOUND_RELAY_UNPROVEN`, with
`publicationAuthorized=false` and `retryAuthorized=false`.

## Exact next action

When the operator is available, expose the already-open Argos
`10.20.70.241` desktop layer in the established full-screen topology without
resizing or minimizing RustDesk. Codex may then perform only a bounded direct
read-only observation of the Argos inbound request receiver/relay process,
installed config/worker hashes, `requests_from_gateway`, `to_jbod`, and exact
queue/archive state. Do not expose or act on DFLY3005.

Only an exact PASS proving the Argos inbound relay current, healthy, and free of
an unresolved earlier accepted request can authorize one create-new publication
of the frozen O2D10 ZIP. After that one publication, collect only its matching
signed terminal response. No retry is authorized. On failure, preserve direct
observation and follow stop-loss. Until then, O2D10 stays local and unexecuted;
Slot16 remains unfrozen, Slot17 blocked, Slots22-25 unseen, the live provider
disabled, the healthy processor untouched, `SCRIBE_REFERENCE_COVERAGE_HOLD`
and every existing hold preserved, and production/XML/training/source
deletion/wafer authority remains absent.

Checkpoint preaction:
`work/OPENCV_SCRIBE_O2D10/PREACTION_O2D10_ROUTE_HOLD_CHECKPOINT.json`,
SHA-256 `A5E60779FFD95D0A64185908F2F1BAC5823216F2F246B3AECA1BCC138C5DC0E4`.
