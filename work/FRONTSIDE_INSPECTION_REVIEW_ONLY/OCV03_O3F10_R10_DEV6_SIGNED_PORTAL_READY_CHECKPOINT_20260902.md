# OCV-03 O3F10 R10 DEV6 signed portal ready — 2026-09-02

Disposition: `PENDING_GATE`

O3F9 request `REQ_O3F9_20260902A` was published exactly once and returned the
matching signed terminal response
`R_763701FC91CC_20260903012427794_6cd8c644`. Response ZIP SHA-256 is
`6C75B41A724F06F2F8D34AC88104A18AE7EF980A47F338B8867E45F2EEA93B83`.
It failed at the first owned SELF_TEST child with exact error
`O3F9 SELF_TEST state changed.` The real runner emitted its documented JSON
object while the O3F9 endpoint compared raw stdout to a bare state string.
Failure gate
`AF2617E0177360D02450E09DE39835804B2F1BC322BA08019B74C0F43821A75F`
proves PREFLIGHT/GATE/DEV6 did not start, no image bytes were read, and neither
`D:/O3F9G1` nor `D:/O3F9D1` was created. O3F9 is `WITHDRAWN`, no-retry, and
cannot be a publication parent or reusable template.

O3F10 changes only the packaged endpoint caller/consumer contract. Exact R10
detector `0EEEE7A396E918AF44082EC0930871A6A94C1FBB59D3F5CEF1AC34D1273745FA`
and runner `606AFE5DF058F0298CFE333D9091DF3F5F0B5F222EC03C40E73006773F587D72`
are unchanged. The endpoint always runs the real runner for SELF_TEST, parses
one JSON object, and requires the frozen state plus Boolean
`mutationsPerformed=false`; only rehearsal PREFLIGHT/GATE/DEV6 use the
image-free fixture. Threshold/algorithm changes, post-result selector
relaxation, and automatic hold clearance are false.

The local exact-entrypoint rehearsal passed with success and injected DEV6
failure/quarantine cases:
`74CAE214115BF4985EB9064678F729A4636C1231C0761AE4EBAE9052F417E311`.
A separate lifecycle-safe contract gate executes both real and fixture
SELF_TEST and proves identical exact keys/types, expected states, and false
mutation flags:
`7013E203C2600508376B2012B3B163C1DB812EB8140DA7ED62EC0764C22339D0`.

One fresh signed review-only `MAINTENANCE_PATCH` request is frozen:

- request: `REQ_O3F10_20260902A`;
- ZIP SHA-256: `2B93471DD8450DF8A4A6128B5295D5F6D7031BCB06C985FEE3387EC44694B4CD`;
- final-package gate:
  `44920BE8BA28449F8BCB3A3ED63DAEE259239CDF12FB1C4C13FFF4BC92ABA652`;
- exact packaged Windows PowerShell 5.1 rehearsal gate:
  `0CA1DAC15B94BA7A3046355A77E66286E409E7B10674A9057636F41B08EEE25B`;
- complete 54-path round-trip gate, maximum effective length 193:
  `4F5F0049764256E6D9D485DBA690BC5443A902AA7377E8383FA6755E67F9DB06`;
- zero-pending persistent-share observation, including O3F9 signed terminal
  closure:
  `AB9E37D6652924F4B32188E2EE7361AEC4AA61178467727A874AB2B40EB1D36C`.

The exact signed-package rehearsal extracted the final ZIP, verified its
signature and all payload hashes, exercised predecessor/idempotent/refusal
cases, and ran the extracted endpoint image-free with the real SELF_TEST and
six fixture later-stage cases. The live request creates only fresh
`D:/O3F10G1` and `D:/O3F10D1` result trees and uses the unchanged qualified
portal endpoint and byte-identical installed protocol anchor.

Exact next action: commit and push this frozen successor lineage, require
matching local/origin tips and a fresh zero-pending share observation, publish
`REQ_O3F10_20260902A` exactly once through Project Portal, and collect only its
matching signed terminal response. Do not retry O3F9 or O3F10, use RustDesk,
or require operator clipboard/Enter input. Inspect the six real DEV results
before any broader frontside run. Preserve every O3F6/O3F7 hold, including
rare hotspot Slot16, unless a later explicit gate resolves it. Review-only is
true; source mutation/deletion, existing task/process action, provider
activation, training, XML, production, wafer action, and automatic hold
clearance remain false.
