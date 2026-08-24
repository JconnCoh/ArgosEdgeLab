# OCV-00 OLS5 signed source-hash timeout — 2026-08-24

Disposition: `PENDING_GATE`; `REQ_OLS5` is `WITHDRAWN` and non-reusable.

## Signed terminal result

The exact OLS5 request was published once after matching local/GitHub branch
tips and complete route/path gates. The gateway and JBOD returned signed
terminal response `R_4D8558155D38_20260824204249394_c1fdb46b.ready.zip`,
2,050 bytes, SHA-256
`932EA043EB763FCB960D8458019F4CE2109688257A3E194C9D2A50C7CEBFF752`.
The pinned JBOD signature passed.

The endpoint failure is exact: `Portal child timed out after 900 seconds` while
executing `Invoke-OCV00SourceHashEndpoint.ps1`. The request attempted one
provider-aware sequential SHA-256 pass over twenty 475,379,874-byte frontside
BMP leaves (9,507,597,480 bytes total). No hash result was committed before
the fixed child timeout. Signed timeout-gate SHA-256 is
`BC60CE0401105FD4F02A0F0363B9E702A6CE5C5D9055DC7F7997E3ED590633EC`.

This disproves only the premise that Windows PowerShell 5.1 provider-aware
`Get-Content -Encoding Byte` hashing can finish the full frozen set inside the
900-second endpoint window. It does not prove a missing source, image hold, or
source change. The locally proven hash algorithm and exact targets remain
diagnostic evidence, but OLS5 cannot be replayed or parent a successor.

## Preserved boundaries

No pixel decoding or image processing ran. The helper writes its result only
after all twenty hashes, so no partial result was promoted. No source file,
task, process, processor state, wafer, or hold was changed by the hash logic.
Review-only, no-XML, no-training, and no-production boundaries remain active.

## Required next action

Before any successor mutation, obtain one signed direct post-failure
observation of exact output identity
`C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV00_OLS5_FRONT_SOURCE_HASHES.json`
through the already qualified read-only DATA_PULL route. Do not retry OLS5.
After the observation is pinned, redesign the hash transport so the byte pass
finishes within the installed 900-second limit, while retaining the exact
frozen target set, alias/path safety, source-stability checks, and zero pixel
decode.
