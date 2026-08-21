# Lot 62631-586 front GUI R10 signed terminal failure checkpoint

Created: `2026-08-21T18:33:00Z`

Disposition: `PENDING_GATE`

R10 disposition: `WITHDRAWN`

## Authority and supersession

This checkpoint supersedes
`LOT_62631_586_FRONT_GUI_R9_SIGNED_TERMINAL_FAILURE_CHECKPOINT_20260821.md`
for this bounded lot-specific recovery thread. The global FS15 terminal hold
and every unrelated project authority remain unchanged.

R10 was created from the last successful processor-recovery family, not from
withdrawn R9. It was signed, rehearsed against the exact packaged endpoint,
built, published create-new, processed by the JBOD endpoint, and returned one
matching signed terminal response. That response is `FAILED`; therefore R10
did not authorize or complete the processor restart or catalog refresh. R10 is
not reusable, replayable, or a successor publication parent.

## Exact terminal evidence

- Request: `REQ_R10`.
- Published ZIP: `work/R10/final/REQ_R10.ready.zip`, 9,229 bytes, SHA-256
  `10DEEB44E465CBE53A0E427BB36169E9EC1B31EB24F550251D83D838396D51E7`.
- Publish gate: `work/R10/R10_PUBLISH_GATE.json`, SHA-256
  `9D83F604EDD676195EF2BE08A819DD8646A78680A7C751F85857D7CE2EE1DC50`.
- Response: `R_1E567E7F3C79_20260821182419402_28a007a2`.
- Response ZIP: 2,245 bytes, SHA-256
  `451D8076E37DFB953E99F9CCEDB16D665337B54F459FEDE25D7E241FEBE36442`.
- Response signature: verified against the active JBOD endpoint signer.
- Terminal gate: `work/R10/R10_TERMINAL_RESPONSE_GATE.json`, SHA-256
  `742EA6577934BC0816A16A978208DEB5CB6C2308F8A745C89B87A689CD44206D`.
- Terminal state: `FAIL_R10_SIGNED_TERMINAL_RESPONSE` / `WITHDRAWN`.
- Exact stderr:
  `R10 signed V40 pre-refresh state is not the exact ten-row FRONT contract.`
- Root-cause record:
  `work/R10/R10_SIGNED_TERMINAL_FAILURE_ROOT_CAUSE_20260821.json`, SHA-256
  `C4F6EA1D936CD7F23BF98D5FEFA1ABF4EAF532F2CF220E1FD3979F0334642F44`.

The exact FRONT selector guards completed before the composite pre-refresh
assertion failed. The declared scheduled-task restart was not reached. The
signed response and all three declared result files verified. It records a
review-only failure; no source deletion, other inspection-task change, or
wafer abort is reported. The post-failure installed helper and runner hashes
have not been independently audited and must not be guessed.

## R10 controls that passed but confer no execution authority

- The raw selector gate passed six pre-sign cases, including ten intended
  FRONT rows plus ten same-identity BACKSIDE competitors, missing FRONT,
  duplicate FRONT, wrong-domain replacement, absent process, and internal
  runner-swap rollback.
- The exact signed endpoint gate verified ten signed responses: four passes and
  six bounded failures, including unapproved predecessor, population
  corruptions, absent process, injected post-swap rollback, and a final control
  request.
- The complete route gate evaluated 127 paths, with maximum effective length
  187 and maximum component length 51.
- The final ZIP was extracted, signature-verified, and rehearsed byte-for-byte;
  that final rehearsal again verified ten signed endpoint responses.

These gates prove the intended selector and queue-safety test matrix. They do
not convert the live terminal `FAILED` response into a pass and do not make R10
reusable.

## Root cause and stop-loss

R10 closed R9's missing `FRONTSIDE` population predicate, but did not bind every
later derived count to its exact evidence source. The signed V40 field
`targetConfirmedRows = 10` came from
`identity\confirmed\ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json`. R10 separately
computed `confirmedPhysical` from `identity\SCRIBE_IDENTITY_QUEUE.json` using
the state predicate `SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING`, then asserted the
same scalar ten. V40 never asserted that queue-state population.

The R10 fixture manufactured all ten queue rows in the assumed state. It
therefore proved the fixture premise rather than the installed queue semantics.
The live composite assertion failed after the exact FRONT selector passed. Its
message did not include the individual observed values, so the exact installed
queue-state distribution cannot be reconstructed from this response and must
be audited directly.

This is a second systemic dependency-closure failure after R9. The stop-loss is
active: no R11 or other restart request may be designed, signed, or published
in this task. Technical work must resume only in a fresh task from this
checkpoint.

The new failure signature and prevention are recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`, SHA-256
`A1035D0F0DF04B0468F0A1BB2196A508EBAE2A5B3BF1085B8670C3505C2EF57B`.
The no-repeat audit is
`work/ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json`, SHA-256
`712E939E3A0EAA414F59F9606659CD2DC6139DBF7635D52B3C936A5072EEF670`,
with 76 classified issues and both R9 and R10 blocked from replay, reuse, or
successor-parent authority.

## Mandatory fresh-task boundary

Before any new restart request, a fresh task must:

1. perform a separately gated bounded read-only audit of the exact ten
   `SCRIBE_IDENTITY_QUEUE.json` target rows and their states;
2. audit the installed R10 helper and processor-runner hashes after the failed
   maintenance rollback rather than assuming either predecessor;
3. bind every executable count to its exact source path, schema, selector,
   uniqueness key, and signed or direct evidence;
4. emit field-specific expected and observed values for every pre-mutation
   failure so one terminal response is diagnostically sufficient;
5. include a wrong-source fixture control proving a confirmed-overlay count
   cannot satisfy a queue-state assertion;
6. retain the exact V40 lot/date/`FRONTSIDE` selector, same-identity non-FRONT
   competitors, missing/duplicate/wrong-domain cases, exact RESTART semantics,
   rollback, idempotence, and post-failure control request;
7. start from the last successful signed recovery authority plus fresh direct
   audit evidence. R9 and R10 remain diagnostic evidence only.

The read-only audit is the next action. It is not permission to restart the
processor or to publish another same-endpoint request without its own fresh
pre-action, path, harness, route, and terminal-response gates.

## Unresolved prerequisite order

1. Preserve the separate global
   `FS15_NATIVE_V3_TERMINAL_HOLD_NEW_INDEPENDENT_CHANNEL_REVISION_REQUIRED`.
2. In a fresh task, obtain exact queue-state and installed-hash audit evidence.
3. Reconcile that evidence with the signed confirmed overlay, verified metadata
   overlay, catalog routes, and declared RESTART action.
4. Only then design and gate a fresh successor, if the audit supports one.
5. Obtain a matching signed PASS terminal response proving the bounded restart
   and ten ready FRONT rows.
6. Run a fresh signed validator requiring ten completed FRONT ledger rows and
   ten FRONT GUI asset rows.
7. Only after those gates may the lot-specific review-only GUI/source-test step
   be reconsidered.

No XML, training, production scoring, production routing, source deletion, or
wafer abort is authorized.

## Checkpoint promotion gate

The exact pre-action contract is
`work/R10/PREACTION_R10_FAILURE_CHECKPOINT.json`. Its validator result is
`PASS_ARGOS_ZERO_RECURRENCE_PREACTION` over all 76 classified history issues.
