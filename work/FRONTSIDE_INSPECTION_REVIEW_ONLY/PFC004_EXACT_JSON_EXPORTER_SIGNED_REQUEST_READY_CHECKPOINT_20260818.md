# PFC004 exact JSON exporter signed-request-ready checkpoint

Date: 2026-08-18  
Revision: `PFC004LT1A_EXACT_JSON_RESULT_EXPORT_V1`  
Disposition: `PENDING_GATE`

## Purpose and frozen source

The seven-wafer detector run is not being tuned or rerun. This bounded
maintenance request only exports JSON evidence from the fixed endpoint result
root `D:\A19\PFC004LT1A_20260818T203500Z`. Normal execution refuses unless
the parent `AUDIT.json` hash is exactly
`A1018988FF413C1C02AD0D90AC79C2657EFDAED689A99D700C6AE8191A70728E`.

The exporter accepts at most 128 JSON files, 4 MiB per file, and 32 MiB total.
It parses every JSON file before its first write, copies each source to a short
deterministic `Fnnn.json` name, verifies every copy hash, and writes an exact
source-to-return mapping plus export audit under the approved portal data root
`C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\diagnostics\PFC004LT1A\result_export_v1`.
It does not read or change source images, tune a model, build a raster, or grant
training, XML, production, or routing authority.

## Corrected normal/rehearsal contract

Exporter SHA-256 is
`BB197CBDEA26D7DF1771B12CDFF7DD43266AC8036A7E8C4D07879A4B26A4FF33`.
The maintenance definition SHA-256 is
`84134A1231254A765F09ECFE953D565467BB4A1B0D42DB3A7878D6CB6EC7297C`.
Its required state is the normal terminal marker
`PASS_PFC004LT1A_RESULT_EXPORT_V1`, which is also emitted by the separately
tested rehearsal path. This corrects the prior package error that required a
rehearsal-only marker after normal execution.

Windows PowerShell 5.1 rehearsals pass for the source exporter, the exact
extracted signed payload, create-new installation, idempotent target-hash
installation, and unapproved-predecessor refusal before mutation. The exact
installed exporter rehearsal also passes. Exporter rehearsal-gate SHA-256 is
`AF1ECBEA1F2A88F9D89CB74EC707539ACD8E3F88D77C5B8067E3DC5FE56E0439`.

## Signed request and complete route

Signed request `REQ_20260818T212606693Z_7EFD0668E6FB` is ready but not yet
published. Its exact 3,796-byte ZIP SHA-256 is
`0B0483D5FD2FD16841F7B6346B76A3830CE0D473497546FA0F2E3ABA43C122B4`.
Request-manifest and signature SHA-256 values are
`8FF2E3B71E6F1634D44A79ED3EF0E2532BA9C9759BBFA65335AEC4BD9DAF01D5`
and
`38A1C47AB82DA3FC3EA697E973F8A2EC5EC70C19450B4749CF32CDA791D0C3DA`.

The exact 39-path round trip passes with 32-character suffix reserve, maximum
effective length 187, and maximum component length 51. It binds the installed
gateway config, bridge, queue-safe worker, and 16-case queue-safety proof.
Pre-sign and final route-gate SHA-256 values are
`492E7A8286CC1ABA1F146DA34862772D2B6FEDB57E8DFEF3A0B759475E79B6C8`
and
`B8753D3E4DFF21719F0B6D5C311A3F0A7BD666CF10782B961ED9C6A4D03E08A9`.
The signed final-ZIP gate SHA-256 is
`C4A7BB970094B9B17B6F215CEBBEE5F686E42736C1055C7938C73185C760DD9D`.

## Required next action

Run continuity and session-safety checks again, confirm that the gateway
request inbox has zero earlier pending request ZIPs, then publish this exact
ZIP create-new. Gateway share consumption is not execution evidence. Require
the matching signed terminal response before issuing a DATA_PULL. Only after
the separately route-gated DATA_PULL returns and verifies the mapping, export
audit, parent audit, and subordinate JSON may the one notch-pose hold and five
frozen-model holds be diagnosed.

Do not tune the frozen model, build or present a new judgment raster, or start
production-wafer defect scoring first. The reusable fiducial workflow,
V17R5 geometry/polarity/response contract, later wet-strip separation, all
other pending alignment/map/pose gates, and immutable R5P30 baseline remain
unchanged.
