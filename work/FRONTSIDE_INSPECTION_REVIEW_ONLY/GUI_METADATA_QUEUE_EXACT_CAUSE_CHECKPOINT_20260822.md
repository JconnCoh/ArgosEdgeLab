# GUI metadata queue exact-cause checkpoint — 2026-08-22

State: `DIAGNOSTIC_ONLY`

The live GUI child-operation cascade is repaired. META01R3 produced one clean `PASS_GUI_CHILD_OPERATION` and no repeated modal or `.NET` callback error. Its exported request contained zero actionable acquisitions because the exact installed queue producer emits an internally inconsistent state/action contract.

Signed read-only request `REQ_20260822T235242969Z_59007CFF5CED` returned `PASS_DATA_PULL` in response `R_04C93040C64A_20260822235427336_a363581c`. The exact installed `Update-JbodScribeIdentityQueue.ps1` hash is `F7505FD013D2B908E2E38F9205E9D767E6A30E7DE42724C94B657BA358822418`.

Exact cause:

- Lines 105–115 place both `SCRIBE_CONFIRMED_MES_SNAPSHOT` and `SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING` catalog rows into the same branch and unconditionally write `nextAction='NONE'`. This suppresses the 25 genuinely pending metadata rows, including all six currently missing-lot cohorts.
- Lines 136–147 then use confirmed-overlay membership as a fallback and write `READ_ONLY_INSITE_LOOKUP_REQUIRED` without respecting a terminal metadata-hold route state. This falsely advertises 33 exhausted terminal holds as actionable.
- The exporter independently honors the terminal-hold overlay, rejects those 33 rows, and therefore writes zero actionable acquisitions. The exporter is behaving correctly against the malformed queue.

The 25 suppressed rows are: 62621-582 (4), 62624-869 (3), 62628-301 (9), 62628-317 (3), 62630-465 (4), and 62631-536 (2).

No installed file was changed. No task or process was started, stopped, or restarted. The healthy processor was left untouched. R10 and AVS1 remain WITHDRAWN. XML, training, production, deletion, image-byte, fiducial, and wafer-abort boundaries are unchanged.

Durable machine evidence: `work/META01R3_QUEUE_SOURCE_OBSERVATION_R2/LIVE_CAUSE_RESULT.json`.

Next action is intentionally stopped at diagnosis, per operator instruction. Any repair must be a minimal change to the exact installed queue producer: separate MES-complete from Insite-pending action mapping and prevent terminal route states from being re-advertised by the confirmed-overlay fallback.
