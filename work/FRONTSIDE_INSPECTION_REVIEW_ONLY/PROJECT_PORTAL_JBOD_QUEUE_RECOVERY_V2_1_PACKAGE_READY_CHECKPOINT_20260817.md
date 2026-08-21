# Project Portal JBOD queue-recovery V2.1 package-ready checkpoint

Date: 2026-08-17  
Revision: `PORTAL_JBOD_QUEUE_RECOVERY_V2_1_PACKAGE`  
Disposition: `PENDING_GATE`

## V2 withdrawal

`PORTAL_JBOD_QUEUE_RECOVERY_V2_PACKAGE` is `WITHDRAWN`. Its live
`PREFLIGHT_ONLY.cmd` stopped on `Portal request is expired.` before any task
stop, artifact move, worker replacement, alias/config change, or other JBOD
mutation. `RUN_RECOVERY.cmd` from V2 must not be run.

V2's final rehearsal created only a fresh signed request and therefore did not
exercise the exact expired-request condition. The new failure signature,
cause, preflight, and recovery are recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`.

## V2.1 correction

V2.1 contains no expiry bypass. It fully verifies the signed request, pinned
certificate, exact request ID, exact manifest hash, safety flags, historical
signed lifetime, parameters, declared payload count/size/hash, and absence of
reparse/traversal paths only to authorize quarantine of expired request
`REQ_20260816T033053168Z_802B9D0EC0B4`. The request manifest SHA-256 is
`AD86EDBDFAC654AA3D1D1E65559E7DF9C0A270A4EB2DC3FC8A4164034D809CD2`.
The expired request is never eligible for endpoint execution.

The same preflight independently verifies that current queued maintenance
request `REQ_20260817T153923252Z_2EB5616C2942` remains signed, unexpired, and
exactly hash-matched to manifest SHA-256
`6D0A6C09E269C41843B92FB5AEB2F3EA529D0462E35987F93DB401495127B225`.
It is preserved in the live queue while only the expired request, exact
`JOB_98EACF412AD3B32C` work root, and exact `R_5591861D03D0_*.partial` move
recoverably to `C:\Q\A\R`, `C:\Q\A\W`, and `C:\Q\A\P`.

The worker target remains SHA-256
`64F1BFA34A2F54F6D84D14C5D91BC270346E88E3D95E2E303C0A858206E770B2`
from sole approved predecessor
`CBB1D168DACF392259C93898D8CE725BED7C917571937207757423A05FAC4DE0`.
Only the endpoint and response-sender tasks may stop/restart. The request
receiver stays running and detector, scribe, Insite, and monitor task states
must remain unchanged.

## Exact final-ZIP gate

The sealed ZIP is `work/ARGOS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1.zip`, 34,471
bytes, SHA-256
`9BC3319A2D0988CB6ADAEE78EB5C5A02C3FAF049394E1262C798AB31B532FF56`.
Its nine-file package manifest SHA-256 is
`ED71B903731336C3CCCA2C19D744A3D708AE9F4C0CEEF7B209752214A7240D53`.

A fresh exact extraction passed both wrapper gates and 16/16 Windows
PowerShell 5.1 controls. They include path boundaries 199/200/229/230;
non-mutating expired preflight; refusal of a fresh quarantine target;
signature-, manifest-, and payload-tamper refusal; exact expired
request/work/partial quarantine; target idempotency; current maintenance queue
advance; preserved-path DATA_PULL; replay without duplicate response; stale
collision plus later queue item; compact terminal response construction
failure; forced restart; unapproved predecessor refusal; and complete
request/work/partial/worker/alias/task rollback.

Companion evidence:

- path gate SHA-256
  `89362BE14786A481A98DC6282AA71DE64ED85B9A51851CE175C9616EAF2CAB72`;
- rehearsal gate SHA-256
  `F4FCE2D1E2AFDC35DFFA575EC6374ADE1456ECCB52ACCE16F2B23BF8A7E6EDC6`;
- final package gate SHA-256
  `1C19698CCB928264DA129351D32D500D4984404969638EB79CFBBB69EC61753D`.

The exact fresh extraction root `C:\AR21Z` was removed after PASS. V2.1 is
package-ready but not yet published at this checkpoint. No JBOD recovery,
inspection, detector, alignment, composite, mask, XML, training, or production
authority changed.
