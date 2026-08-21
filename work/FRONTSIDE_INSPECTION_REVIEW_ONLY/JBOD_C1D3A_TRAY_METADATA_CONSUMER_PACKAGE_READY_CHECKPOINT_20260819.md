# JBOD C1D3A tray metadata-root consumer package ready checkpoint — 2026-08-19

Disposition: `PENDING_GATE`

## Scope

This checkpoint closes the uncovered config-v3 consumer gap in the interactive
tray without performing a live JBOD mutation.  The automatic Insite bridge and
the four processor metadata consumers were already root-aware, but the tray's
manual Insite export/import actions omitted `MetadataSnapshotRoot` and would
have fallen back to C: after cutover.

Only bounded Argos inspection storage is in migration scope: `cache`,
`metadata`, and `dashboard_outputs`, plus future review output at `D:\A2\o`.
Windows, user profiles, Downloads, portal/relay state, and unrelated C: data
are not migration targets.  Historical `outputs`, `identity`, and `hotfixes`
remain excluded from the active copy/cutover contract.

## Exact C1D3A patch

- Locked tray predecessor SHA-256:
  `637AE90440F2275D11697C04E21A3CD6B55230F3AC1B3B99C4945C63B12486E0`.
- Target tray SHA-256:
  `769ACAD731F8EA04C1820AB90CCA80591A132CEDDFCF44611B54D9BB2A41FB45`.
- Exactly two manual tray call sites now pass
  `-MetadataSnapshotRoot (Get-ConfiguredMetadataSnapshotRoot)`.
- Config v2 preserves `<StateRoot>\metadata\verified`; config v3 resolves the
  configured root, including `D:\A2\m\verified`.
- Review-only, XML-disabled, and production-routing-disabled authority is
  enforced.  Unsafe authority is refused.
- Completed Lot observability and dynamic review-output resolution are
  preserved.
- The entry point pins the installed Completed Lot launcher invariant at
  SHA-256
  `13A4CF7984D11058CE3F1F296E0913E06EE4228FE56FD331817220768B300A3A`.
- `allowedTaskActions` is empty; the patch does not restart the tray.  The new
  tray is to be loaded only during the separately gated final cutover
  validation restart.

## Gates passed

- Exact PowerShell 5.1 resolver behavior:
  `PASS_C1D3_EXACT_BEHAVIOR`.
- Complete portal route: 109 constructed leaves, maximum effective length 187
  with 32-character reserve, maximum component length 51.  Corrected route-gate
  SHA-256:
  `19F93EA916D70D39310BC4975EE9711C1FDE90CE621F83418EFA82B3087E0A74`.
- Exact endpoint worker SHA-256:
  `244A5ECD88020BF80C217271368C836E0AB82E7B76FDEA9D0D9AC07E0AA034E6`.
- Exact extracted-package endpoint cases passed for the real predecessor,
  target idempotence, unapproved-predecessor refusal before mutation, and
  forced post-swap helper failure with predecessor rollback.
- Final signed request manifest SHA-256:
  `1050E8A7FE5B5B0F5F40A31FB9DF625355D64E80CE7BB7F9BA717D87F6C90DB1`.
- Final ZIP:
  `C:\A3\C1D3\final\REQ_C1D3A.ready.zip`, 12,423 bytes, SHA-256
  `FF5796221F1B24AB3975A21D03FA3C4BA4A13AF4C04445F7D9D6A4ACCD300CFD`.
- Final ZIP gate SHA-256:
  `37E78DE6B4736F540FC5F23A527114256609F9EB3FA80BDFCF61BC025FCFFDC4`.

## Failure-prevention audit completed before checkpoint activation

The operator required all newly exposed and repeated implementation defects to
be documented and prevented before this checkpoint could become authoritative.
That audit is complete:

- `work/ARGOS_C1D3_FAILURE_PREVENTION_AUDIT_20260819.md`, SHA-256
  `52F33B0D8B9B1C7B9CC9B7C5D052390DBFCFB22AC8FEDB32ED0546CD1E841002`;
- `work/ARGOS_POWERSHELL_HARNESS_SAFETY.md`, SHA-256
  `5692BF7EC11CB18543B4752F2CF742D2C4A0A09DB46F3AA2A1B58F431531E643`;
- `utilities/Confirm-ArgosPowerShellHarnessSafety.ps1`, SHA-256
  `E1B08ED796DF3F56C784A03BD210727B4065F669D7DACEAE56620F56DCA15E2A`;
- durable failure memory SHA-256
  `CF9E56CBDC5B883E9B9D6BBF024B91F825CBF96C705A39C0425C91FF81ED1228`.

The new static gate rejects PowerShell parser failures, reassignment of typed
parameter variables under case variants, external `powershell.exe` text used
as a typed object, durable mutation before a preflight return, broad recursive
workspace enumeration, and width-dependent `Format-*` gate evidence.  All
seven C1D3 builder/signer/behavior/route/endpoint/final/entry-point scripts pass
the exact new harness gate with zero violations.

The initial route evidence and the final package derived from its mutating
`-Preflight` were invalidated and preserved at
`C:\A3\C1D3\failed_attempts\preflight_mutation_20260819T2011Z`.  The route
script now has separate non-mutating `-Preflight` and mutating `-Gate` actions;
the preflight proved it created no evidence path.  A case-insensitive
`[switch]$Gate`/local `$gate` collision was also detected before write, added to
the static guard as `PARAMETER_VARIABLE_REASSIGNED`, and corrected to the
semantic local `$pathBudgetResult`.  The final ZIP and endpoint matrix were
then rebuilt from fresh roots.

The earlier local draft `REQ_C1D3` is `WITHDRAWN` and was never published.
The first final-build attempt is preserved at
`C:\A3\C1D3\failed_attempts\final_20260819T2002Z`; it failed only because an
out-of-process verifier result was treated as a typed object.  The fresh final
root passed after an in-process structured-result check.  All new/repeated
failure signatures and recoveries are recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`.

## Storage and inspection state preserved

The latest signed D2S2 evidence remains authoritative: Stage 1 was still
`Running / COPY_HASH_IN_PROGRESS` at 1,252 files and 72,115,382,792 bytes, the
processor reported no active or waiting wafer, and cooperative hold
`STORAGE_CUTOVER_H1_20260819` was matched.  C1D3A preparation did not clear the
hold, cut over a path, delete a source, change an inspection task, abort a
wafer, or change detector/image evidence.

## Required prerequisite order

1. Run continuity, session-safety, wrapper, final-ZIP, and zero-pending portal
   checks; publish only `REQ_C1D3A`; require its matching signed terminal
   response and installed target hash.
2. After meaningful additional copy progress, create a fresh, fully gated
   `REQ_D2S3` status identity and require its matching signed response.
3. Do not publish D3 unless that fresh response proves
   `finalDeltaTerminalPass=true`, task `Ready`, task result zero,
   `taskLastRunAfterHold=true`, and the intact result/manifest contract.
4. Only after D3 passes, apply C2A/C2B and validate a real D: review export,
   dashboard output, automatic and manual Insite metadata paths, dynamic tray
   review root, and Completed Lot launch.
5. Do not delete or broadly move C:.  Any later C: recovery is limited to exact
   hash-verified Argos inspection roots authorized by the final cutover gate.
6. Then return to PFC004, preserving six fiducial passes and the Slot07 notch
   hold.  No production defect scoring, XML, training, or production-routing
   authority is granted.
