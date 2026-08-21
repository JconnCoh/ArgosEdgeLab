# RA1A withdrawn local-rehearsal failure — 2026-08-21

Status: `WITHDRAWN`.

RA1A request `REQ_RA1A_0821_1910_X1` was signed locally but was never
published to the Project Portal. Its first exact Windows PowerShell 5.1
create-from-absent endpoint rehearsal returned signed terminal `FAILED` as
response `R_CD2FBA7EC9B1_20260821190854216_5e5482c8`.

The bounded stderr was:

`The property 'Count' cannot be found on this object.`

The cause is the already documented conditional-collection scalarization
failure. RA1A assigned ledger rows with the array wrapper inside an `if`
expression instead of around the complete conditional. The zero-row fixture
therefore produced `$null` under StrictMode before the audit result could be
emitted.

The rehearsal also exposed a systemic gate premise failure:
`PREACTION_REHEARSE.json` asserted
`zeroOneManyCollectionCasesPassed: true` without pinning a machine-readable
zero/one/many ledger-cardinality gate. That assertion was not evidence.

The endpoint rehearsal's outer `finally` restored the temporary approved-root
install. `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\RA1A.ps1` was
absent before the rehearsal and is absent afterward. No live portal request was
published, no task action ran, no queue row changed, no image was read, no
source was deleted, no inspection task changed, and no wafer was aborted.

RA1A is non-replayable and cannot be a successor parent. R10 remains withdrawn;
the global FS15 hold and all XML, training, production, deletion, and wafer
boundaries remain unchanged. Continuity was not promoted, and neither ten FRONT
ledger rows nor ten FRONT GUI wafers has been proved.

Stop here. A future attempt requires new direction, a fresh namespace, the
outer conditional array boundary, and a pinned Windows PowerShell 5.1
zero/exactly-one/multiple collection case gate before signature.
