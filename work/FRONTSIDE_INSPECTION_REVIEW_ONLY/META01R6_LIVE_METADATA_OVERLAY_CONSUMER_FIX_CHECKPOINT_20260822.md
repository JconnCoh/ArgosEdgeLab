# META01R6 live metadata-overlay consumer fix checkpoint — 2026-08-22

Status: `PENDING_GATE` — live bounded repair passed; downstream completed-result production remains naturally asynchronous.

The exact live cause was a split metadata authority. `Export-JbodPendingInsiteRequest.ps1` correctly read `D:\A2\m\verified` and therefore exported zero of the 25 rows because their metadata already existed. The installed inventory instead hard-coded `stateRoot\metadata\verified` on `C:` and did not consume the same verified overlay.

META01R6 changed only:

- `Invoke-JbodAllWaferInventory.ps1`: accepts the metadata root and, for the already-resident runner, resolves `PROCESSOR_CONFIG.metadataSnapshotRoot` when the argument is absent.
- `Run-JbodAllWaferProcessor.ps1`: restores explicit forwarding of the configured metadata root using the already-qualified predecessor implementation.

Signed live terminal evidence:

- maintenance request `REQ_20260823T002019647Z_07515D4B31F0`;
- signed response `R_F6C90BFF0572_20260823002114236_9c13bb1b` returned `PASS_MAINTENANCE_PATCH` with `changedFiles: 2`, exit code `0`, and no task/process action or processor restart;
- read-only request `REQ_20260823T002413638Z_36C673670154`;
- signed response `R_30120B503CC4_20260823002345978_672684d7` returned `PASS_DATA_PULL`;
- installed inventory SHA-256 `228D9EDD0EFF45E58682659DC6C807FB04F63DD55E48C7F70426BF272C08FA7C`;
- installed runner SHA-256 `46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4`;
- configured metadata root `D:\A2\m\verified`;
- catalog remained `1844/1844` stable with `0` waiting;
- route-ready acquisitions increased from `313` to `526`;
- queue `insiteLookupPending` is `0`.

This does not claim every lot is completed or GUI-visible. Remaining rows are separated into their actual scribe, appearance-route, exact-scan-context, BowComp-qualification, or other domain holds. No further repair, restart, or replay is authorized merely to obtain more validation. R10 and AVS1 remain withdrawn. Fiducial work remains paused. Global XML/training/production/deletion/wafer-abort boundaries are unchanged.

Canonical machine evidence: `work/META01R6_METADATA_OVERLAY_FIX/LIVE_TERMINAL_EVIDENCE.json`.
