# JBOD C1F0A Terminal Pass and C1F1 Bridge Bootstrap Ready — 2026-08-19

Disposition: `PENDING_GATE`

Revision: `JBOD_C1F0A_TERMINAL_AND_C1F1_BRIDGE_BOOTSTRAP_READY`

## Operator-visible processor state

The operator monitor shows `Current: none` and `Waiting: 0`. There is no wafer
awaiting completion. The cooperative storage hold
`STORAGE_CUTOVER_H1_20260819` remains
`HELD_AT_PROCESSING_PASS_BOUNDARY`. No wafer was stopped or aborted.

## Exact installed endpoint root contract

C1F0A request `REQ_C1F0A` returned signed terminal response
`R_7F721A4D9C2E_20260819185652824_c476ea62` in state
`PASS_MAINTENANCE_PATCH`. The response ZIP SHA-256 is
`5461BB2B0682F3F90E3CBE3FDE2903B9F52764390ECAF546ACA8027CAD3AD219`.
The terminal gate is
`work/JBOD_ENDPOINT_ROOT_DIAGNOSTIC_C1F0/C1F0_TERMINAL_RESPONSE_GATE.json`,
SHA-256
`5EE1B37E88DE021E60E56EB30244CE86E878E90B1FDB064E76219EE676FB92CD`.

The live endpoint config is exactly:

- path: `C:\ProgramData\ArgosProjectPortalRO\config\endpoint_jbod.json`;
- SHA-256:
  `55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F`;
- approved maintenance root count: `1`;
- sole approved maintenance root:
  `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2`.

The file-backed parsed config record is
`work/JBOD_ENDPOINT_ROOT_DIAGNOSTIC_C1F0/C1F0_LIVE_ENDPOINT_CONFIG.json`,
SHA-256
`465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB`.
No endpoint-config revision is authorized or needed for the bounded recovery
below.

## C1F1 least-privilege bridge bootstrap

C1F1 preserves the installed one-root endpoint contract. The ordinary signed
maintenance change installs one idempotent helper at
`C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\C1F1.ps1`. That helper
performs one declared, exact-hash, atomic replacement of
`C:\ProgramData\ArgosInsiteBridgeRO\Invoke-JbodAutomaticInsiteBridgeWorker.ps1`.
It does not modify or restart the portal endpoint, response sender, processor,
detector, scribe, Insite, monitor, or inspection tasks.

The approved bridge predecessor and target hashes are:

- predecessor:
  `886A9B5A7F81F4537043F99F8913521A6AC688A8DEA3ACCDB6AA06881B3A6F89`;
- target:
  `3A4701A44B35CD7E3B8D0C430A98045F0F735C1360E3D75F583396B3C7A0FE7E`.

The C1F1 helper SHA-256 is
`6253652D9CEE1946FE8B15FB87BE040E61EF96D26E4119F899DBAB945488F84B`.
Its signed request manifest SHA-256 is
`B6191014133D752135BC5D7AFC89A3A845EA214F79703941334D91892E3B11B8`.

The exact endpoint rehearsal used endpoint worker SHA-256
`244A5ECD88020BF80C217271368C836E0AB82E7B76FDEA9D0D9AC07E0AA034E6`
and the literal installed approved-root set above. It proved:

- old predecessor installs the target and returns a verified signed PASS;
- target predecessor is idempotent and returns a verified signed PASS;
- an unapproved predecessor remains byte-identical and returns a verified
  signed terminal `FAILED` response;
- the helper's injected post-swap failure restores the approved predecessor
  and quarantines the failed target;
- no inspection task, wafer, hold, D: path, or source tree changes.

The exact endpoint gate is
`work/JBOD_BRIDGE_CONSUMER_BOOTSTRAP_C1F1/C1F1_EXACT_ENDPOINT_GATE.json`,
SHA-256
`B8365AC9447DBA407529729F310CAD8E3CD3971240034A06B461D5F7389D9E4F`.
The independently exercised helper gate is `C:\B1T\TEST_RESULT.json`,
SHA-256
`82E7B2AB17BA6E313F5028510B1FF35675C49F79753D83A5BC4DBA68C0E1E635`.

## Final package and route gates

The unpublished final request is
`work/JBOD_BRIDGE_CONSUMER_BOOTSTRAP_C1F1/final/REQ_C1F1.ready.zip`:

- bytes: `6376`;
- ZIP SHA-256:
  `B6486056645E04758BF87CCC0E3ED27C5C459F543A92653DC8E24FBD828567C3`;
- final package gate SHA-256:
  `558ADA9452790C12C9E1B861F21E9FE43699304B8EE186D49E0DAECBAB16A512`.

The exact final ZIP was extracted and signature/hash verified under Windows
PowerShell 5.1. Both payload scripts parsed, all approved predecessor cases
passed, target idempotence passed, unapproved refusal occurred before bridge
mutation, injected rollback passed, and the failed target was quarantined.
The inherited endpoint queue-safety suite passed all 16 cases.

The complete route gate evaluated 113 request, work, maintenance-evidence,
response, relay, archive, and short laptop-extraction leaves. It passed with a
32-character suffix reserve, maximum effective length `187`, and maximum
component length `51`. The route gate is
`work/JBOD_BRIDGE_CONSUMER_BOOTSTRAP_C1F1/C1F1_COMPLETE_ROUTE_GATE.json`,
SHA-256
`6BE6FFE34582F274A616A6F95A1E67281FCD29719B3760580FA9AD2555F278D8`.

## Required prerequisite sequence

1. Before publishing C1F1, prove zero earlier accepted portal request lacks a
   signed terminal response. Publish only exact request `REQ_C1F1`, then
   require and verify its matching signed terminal response.
2. After C1F1 terminal PASS, rebuild the failed C1D work under a new request ID
   with only the four consumers inside the processor root. Re-run behavior,
   exact endpoint, path, queue, final-package, predecessor, and idempotence
   gates against the literal installed one-root contract before publication,
   then require its matching signed terminal response.
3. Obtain a fresh signed D2 status. D3 remains prohibited until D2 is terminal
   and the final delta/hash is complete.
4. Only after corrected consumers and D3 pass may C2A/C2B reload or cut over
   future output, dashboard, cache, and verified-metadata roots to D:. Validate
   a real export, Insite metadata, dynamic tray, and Completed Lot view before
   clearing the cooperative hold or recovering any exact C: source.
5. Return to PFC004 fiducial/notch work only after the storage/portal sequence.
   Preserve the six qualified fiducial passes and the operator-visible Slot07
   notch hold. No wafer may bypass fiducial qualification or a notch hold.

No judgment raster, alignment transfer, production defect scoring, XML,
training, or production-routing authority is granted by this checkpoint.
