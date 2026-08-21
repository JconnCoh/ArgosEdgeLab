# Lot 62631-586 front GUI R9 signed terminal failure checkpoint

Created: `2026-08-21T17:50:00Z`

Disposition: `PENDING_GATE`

R9 disposition: `WITHDRAWN`

## Authority and supersession

This checkpoint supersedes
`LOT_62631_586_FRONT_GUI_SAFE_STOP_R2_CHECKPOINT_20260821.md` for this bounded
lot-specific recovery thread. The global FS15 terminal hold and every unrelated
project authority remain unchanged.

R9 was signed, locally rehearsed, built, published, processed by the JBOD
endpoint, and returned one matching signed terminal response. That response is
`FAILED`; therefore R9 did not authorize or complete the processor refresh and
must never be described as a successful execution, reusable package, or
publication parent.

## Exact terminal evidence

- Request: `REQ_R9`.
- Published ZIP: `work/R9/final/REQ_R9.ready.zip`, 8,949 bytes, SHA-256
  `1BE5D66E8B2361B9DE2AAD3E022A534A4EE5EBAAC532E02D7BFABBC1C3A048D6`.
- Publish gate: `work/R9/R9_PUBLISH_GATE.json`, SHA-256
  `5F70960426FB72CF7F94DB860D55A2E04A487DB180EBFB74F79AE98B19D024A8`.
- Response: `R_A5A427490F0D_20260821174144370_961e73de`.
- Response ZIP: 2,246 bytes, SHA-256
  `ADFAC753D950253F186D8B34AF19B24E7F450E57E968C962DF32AF1EB90695F4`.
- Response signature: verified against the active JBOD endpoint signer.
- Terminal gate: `work/R9/R9_TERMINAL_RESPONSE_GATE.json`, SHA-256
  `445B1CDA8C28E5E0C8239C913BC6C0B2BBB72B6DEB4637615482B0206F2AE91A`.
- Terminal state: `FAIL_R9_SIGNED_TERMINAL_RESPONSE` / `WITHDRAWN`.
- Exact stderr: `C2R expected ten current FRONT catalog rows; found 20.`
- Root-cause record:
  `work/R9/R9_SIGNED_TERMINAL_FAILURE_ROOT_CAUSE_20260821.json`, SHA-256
  `87F580134661FF600B9281EF79AC0F31B82C04CAD59FC472F8BD38CBD996DA9F`.

The verifier failed before the exact scheduled-task restart. The signed
terminal evidence records no source deletion, no other inspection-task change,
and no wafer abort. Completed FRONT ledger rows remain zero and FRONT GUI asset
rows remain zero.

## Root cause

The signed V40 validator's value `frontCatalogRows = 10` was produced from an
exact population predicate that included `domain == FRONTSIDE`, exact lot, and
exact scan. R9 copied the scalar value ten but selected catalog acquisitions
only by the ten physical identities. The broader live selector returned 20
rows. R9 therefore compared the right scalar to the wrong population.

This corrects the earlier incomplete recovery characterization that changing
20-valued assertions to 10 was sufficient. The raw 20-row result is not proof
of twenty FRONT rows, and the signed ten-row FRONT result is not authority to
expect ten rows from an all-domain selector.

The new failure signature and prevention are recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`. The current no-repeat audit is
`work/ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json`, SHA-256
`33152D8494EE0F0670B50CAC54964BB890E2A3AA159C3FE56D87260D28B2AA05`,
with 75 classified issues and R9's exact final ZIP blocked from replay, reuse,
or successor-parent authority.

## Mandatory successor boundary

A fresh successor is required. R9 source and terminal artifacts are diagnostic
evidence only. Before any successor build, signature, or publication:

1. bind the complete V40 selector: exact lot, scan, physical identity, and
   `domain == FRONTSIDE`;
2. represent actual catalog rows in the endpoint fixture rather than a scalar
   `catalogRows` field;
3. include ten intended FRONT rows plus bounded non-FRONT rows sharing the same
   physical identities and prove only the FRONT rows are selected;
4. exercise missing-FRONT, duplicate-FRONT, wrong-domain, absent-process,
   unapproved-predecessor, injected-rollback, idempotent, and post-failure
   control cases;
5. preserve the exact declared action
   `RESTART:ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2` and require one old
   process, one different new process, and no passing start-if-absent or no-op
   branch;
6. repeat complete clone, parser, harness, wrapper, path, zero-recurrence,
   exact packaged endpoint, route, publisher, and terminal-response gates from
   fresh roots.

No later request may be published from R9 or while any earlier same-endpoint
request lacks a signed terminal response. R9 now has its signed terminal
response, but that fact does not authorize a successor until the controls above
are implemented and gated.

## Unresolved prerequisite order

1. Preserve the separate global
   `FS15_NATIVE_V3_TERMINAL_HOLD_NEW_INDEPENDENT_CHANNEL_REVISION_REQUIRED`.
2. Build and gate a fresh lot-specific successor with exact FRONT population
   semantics.
3. Obtain a matching signed PASS terminal response proving the bounded
   processor restart and ten ready FRONT rows.
4. Run a fresh signed validator requiring ten completed FRONT ledger rows and
   ten FRONT GUI asset rows.
5. Only after those gates may the lot-specific review-only GUI/source-test step
   be reconsidered.

No XML, training, production scoring, production routing, source deletion, or
wafer abort is authorized.

## Checkpoint promotion gate

The exact pre-action contract is
`work/R9/PREACTION_R9_FAILURE_CHECKPOINT.json`. Its validator result is
`PASS_ARGOS_ZERO_RECURRENCE_PREACTION` over all 75 classified history issues.

