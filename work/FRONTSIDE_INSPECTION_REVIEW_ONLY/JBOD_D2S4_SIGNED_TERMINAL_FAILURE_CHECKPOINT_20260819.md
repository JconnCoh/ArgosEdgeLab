# JBOD D2S4 signed terminal failure checkpoint - 2026-08-19

Disposition: `PENDING_GATE`

Parent checkpoint:
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/JBOD_D2S4_FRESH_FINAL_DELTA_STATUS_READY_CHECKPOINT_20260819.md`,
SHA-256
`26765F954F6BB7F6A0519F966F5C4860A370F582AD2E7348904F14282395A4D6`.

## Publication and matching terminal response

After continuity/session PASS and a repeated exact zero-pending preflight,
`REQ_D2S4` was published create-new. Publish gate SHA-256 is
`7DB2FBAB126C6FEE448ED3999B0FCC9E983FF39E0717DF007A46DA65970F6E36`.
There was no overwrite, exact-upload recovery, or reused request identity.

Matching signed response
`R_EE86E4BCC38C_20260819225731829_41d7e174` is terminal `FAILED`. The
2,214-byte response ZIP SHA-256 is
`E9567FE734769FD069B9188C8EF07B27BD6698D39B7EF5CAA89F152A1E5DD93D`.
The exact signature and all three manifest file hashes pass. Failure collector
SHA-256 is
`F877C2F7692B481265E7755D665AB206FB34869C59BDB45E294BB028792733CC`;
terminal failure gate SHA-256 is
`AB5911EB29BC96A47B00323472D3EB63975481C1FFBDAA1730F1B9BECB55671D`.

The signed stderr is `PropertyNotFoundStrict`: property `updatedUtc` does not
exist while executing `D2S.ps1`. The endpoint emitted no maintenance stdout,
so this response proves neither transfer completion nor continued progress.
It is a status-reader failure, not evidence that the storage transfer itself
failed.

## Root cause and prevention

The unchanged status verifier directly accessed live status properties under
strict mode. The live `STATUS.json` shape may omit informational fields such as
`updatedUtc` as the task advances. The verifier aborted before it could return
the task, hold, result, or terminal state.

The durable prevention record now requires optional-property access through
`PSObject.Properties`, separates informational status fields from mandatory
hold/result/task proof, and requires old in-progress, terminal, and observed
missing-field rehearsals before a fresh request. Current Windows failure-memory
SHA-256 is
`C853189A0FEA4F9BE3412DE89A533BCD8661AF02A201ED3A03A167E1E78908AE`.
It also records and prevents the preflight-only `foreach ($p in$paths)` lexical
separation error; that parser failure made no write.

## Safety state and next action

D3 remains prohibited. No source was deleted, no D: cutover occurred, the
cooperative hold was not cleared, no inspection task changed, and no wafer was
aborted. Migration remains limited to bounded Argos inspection roots, never
the entire C: drive.

Patch only the status reader, add a missing-optional-field behavior case, and
use fresh request identity `REQ_D2S5` with new rehearsal/extraction roots.
Repeat design-freeze, wrapper/harness, behavior, exact endpoint, queue,
package, complete-route, literal-root, continuity, session, and zero-pending
gates before publication. Do not reuse `REQ_D2S4` and do not infer transfer
state from its signed failure.
