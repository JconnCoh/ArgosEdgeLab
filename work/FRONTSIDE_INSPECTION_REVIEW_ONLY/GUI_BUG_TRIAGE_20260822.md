# GUI bug triage — 2026-08-22

Status: `DIAGNOSTIC_ONLY` (read-only)

This report is a read-only diagnosis. It is not a repair package, release,
continuity checkpoint, or authorization to modify/restart the healthy JBOD
processor. Fiducial work remains paused at
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/FIDCV1_OPERATOR_PAUSE_FOR_GUI_CHECKPOINT_20260822.md`.

## Authority and evidence

- Authoritative repository:
  `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab`
- Verified HEAD and required commit:
  `bb09223748c446f0b9e38656d80ca996049a3e55`
- Operator report:
  `8-22_BugsInGui.docx`
- Operator-report SHA-256:
  `8FC445D7AEE9CE457BAF1B0C5CB963EEF552484E5014986E0A93EE2CC6E40A34`
- Exact installed AVC1 tray source represented by:
  `work/AVC1/payload/Show-JbodAllWaferTray.ps1`
- Installed tray SHA-256 proved by the signed post-AVC1 pull:
  `C03812C6889B102DFD9B3CB466E70B06B8943C1123A882EB0ADE972C641DAB2B`
- Signed post-AVC1 response gate:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/ARGOS_ALL_VALID_INSPECTIONS_POST_AVC1_SIGNED_RESPONSE_GATE_20260822.json`
- Signed response:
  `R_437B81703A84_20260822003429334_ebb607f6`,
  `PASS_DATA_PULL`, gated at `2026-08-22T00:36:00Z`
- Installed Completed Lots viewer SHA-256:
  `39AEA256E4C08043A6F9AEFEADB32F4297217E878C8B71A4603D64FA570677A6`
- Matching frozen viewer source:
  `work/STANDALONE_APP/packages/hotfixes/ARGOS_JBOD_V3_4_6_EXPORT_SIDE_NAME_20260807T201101Z/payload/runtime/viewer/Program.cs`
- Matching viewer-source SHA-256:
  `20A2442FAC73ABDDE95C8876C6A21A2988E63AFBB119F969F7979F7096C7D545`

## Issue list

1. Completed inspection results present under the A2 output area are not all
   visible in the Completed Lots GUI.
2. Clicking Completed Lots produces a JIT exception saying
   `$script:activityLines` has not been set, although the viewer window still
   opens after the operator continues.
3. The operator asked whether the missing-lot symptom and the JIT exception
   are the same defect.
4. Importing the correct saved scribe-review response does not work.
5. Export Insite Waits appears to do nothing and the visible count remains 58.
6. The GUI paths must not introduce repeated-error loops, indefinite waits, or
   other unbounded callback behavior.

## Causes and relationships

### GUI-01 — Completed Lots is an exact-date view, not an all-lots view

Confirmed cause of the general cross-date visibility problem. The installed
viewer is not pinned to a literal calendar date, but it does impose an exact
date filter:

- `InitializeDateFilter()` derives the minimum and maximum dates from the
  manifest and sets the selected value to the maximum date (source lines
  1216-1223).
- `PopulateScanList()` calls `VisitsForDate()` using only that selected date
  (source lines 1226-1234).
- `VisitsForDate()` excludes every session whose `ScanTime.Date` differs from
  the selected date (source lines 226-232).

Therefore the initial Completed Lots window shows only visits from the newest
scan date represented in the manifest. Older completed visits remain invisible
until the date control is changed. That behavior conflicts with an operator
expectation that “Completed Lots” means all completed lots.

This is separate from the tray callback exception below.

The dashboard producer itself has no calendar cutoff. It evaluates the current
catalog acquisition fingerprint, the exact current completed ledger job key,
scribe/MES eligibility, `JOB_RESULT.json`, and the five required review
artifacts before admitting a wafer. Merely finding a directory under `D:\A2\o`
does not prove that the output is a current, eligible, complete dashboard
result.

At the signed `2026-08-22T00:36:00Z` observation, the bounded reconciliation was
internally exact: 260 catalog acquisitions had a current completed job and the
dashboard contained the same 260 physical-identity/domain rows; there were no
current completed rows missing from that dashboard snapshot. The catalog also
contained 1,584 acquisitions without a current completed job. Because
processing continued after that snapshot, an exact current per-lot explanation
requires a fresh proportional read-only reconciliation of the full catalog,
holds, ledger, dashboard, and dashboard-refresh failure record. This report
does not claim that every presently observed A2 directory is eligible.

### GUI-02 — callback-owned state was left in `$script:` scope

Confirmed cause of the reported JIT exception and the common cause for issues
2, 4, and the misleading feedback portion of issue 5.

`Show-JbodAllWaferTray.ps1` creates the activity queue at line 344 as
`$script:activityLines`. `Add-ActivityLine()` reads that script-scoped variable
at lines 347-349. WinForms callbacks cannot reliably retrieve mutable caller
script scope. The installed code already moved `LastActivityKey` to
`$form.Tag`, but it did not move the queue or the other callback-owned state.

The same source still contains script-scoped `exitRequested`, `lastGoodCatalog`,
`lastGoodStatus`, and `lastGoodScribeQueue`. Even though the operator-observed
failure names `activityLines`, all callback-owned mutable state must be moved to
one captured form/control state object; correcting only the named variable
would leave the same failure class in place.

The timer runs every two seconds. Its catch block calls `Add-ActivityLine()`
again. If logging is the failing operation, the error handler repeats the same
failure and can create recurring JIT dialogs or an error storm.

### GUI-03 — Completed Lots opens, then logging fails

Same root as GUI-02, not GUI-01.

`Open-ReviewApplication()` launches and validates the Completed Lots window at
lines 146-147. Only afterward, line 148 calls `Add-ActivityLine()`. This ordering
exactly explains why the viewer opens and the JIT exception follows. Its catch
block calls the same failing logger at line 150 before it can show the intended
error message.

### GUI-04 — valid scribe import is stopped before the importer launches

Same root as GUI-02.

`Import-ScribeReview()` validates the selected response schema and row count,
then asks for confirmation. After the operator answers Yes, line 202 calls
`Add-ActivityLine()` before the child PowerShell importer is created or started
at lines 203-217. The callback-state exception therefore blocks a correct saved
review before the import program runs. Its catch block calls the same failing
logger at line 236 before showing the intended failure dialog.

This evidence supports the operator's statement that selecting the correct
file is not the cause of the observed failure.

### GUI-05 — Insite export feedback fails, and export is not queue resolution

Partly the same root as GUI-02, with an additional semantics problem.

`Export-InsiteRequest()` invokes the exporter first (line 252) and logs the
success afterward (line 253). If the exporter succeeds, a JSON file may already
exist in Downloads before the activity logger throws. The success dialog is
then skipped, and the catch block calls the same failing logger before its own
error dialog. This can make a successful export look like “nothing happened.”

Exporting is intentionally non-resolving: it creates a read-only lookup request
and does not update the identity queue. The number must remain unchanged until
matching Insite evidence is imported and the queue is rebuilt. Therefore “still
says 58” is not, by itself, proof that the export failed.

The signed snapshot proves the displayed 58 was data-derived, not a hard-coded
label: it contained 58 unique physical identities and 58 unique wafer IDs in
`SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING`. However, the aggregate conflated two
different subcohorts:

- 33 rows: `READ_ONLY_INSITE_LOOKUP_REQUIRED`;
- 25 rows: `nextAction = NONE` with
  `HOLD_INSITE_METADATA_REQUIRED_BEFORE_DETECTOR`.

The action should not be removed merely because the current feedback is broken.
The GUI should separate actionable lookup exports from metadata holds and state
plainly that export does not clear either count.

### GUI-06 — unbounded GUI blocking risks

Additional reliability defect found during the requested loop-safety review.

- The scribe importer waits synchronously with an unbounded `WaitForExit()` on
  the UI callback.
- It drains standard output and standard error sequentially, which can deadlock
  when the child fills the stream not currently being drained.
- The Insite exporter is also invoked synchronously in the UI callback without
  a deadline.
- Buttons are not guarded against re-entry while these operations run.

These are not proven causes of the current operator report, but they are real
paths to a frozen GUI and must be closed in the repair design.

## Relationship summary

| Operator symptom | Confirmed cause | Same cause? |
|---|---|---|
| Missing completed lots | Exact selected-date filtering; current-result eligibility also applies before the manifest | Separate from callback failure |
| Completed Lots JIT after window opens | `$script:activityLines` callback scope | Same as scribe and export feedback |
| Correct scribe response will not import | Logger throws before importer start | Same as Completed Lots JIT |
| Insite export appears inert | Logger can throw after export; export does not resolve queue | Partly same callback bug plus misunderstood/conflated count semantics |
| Risk of repeating dialogs or frozen GUI | Logger called from its own timer error path; unbounded synchronous child work | Same architectural callback-state family plus separate timeout defects |

## Success criteria for a repair

### Completed-lot visibility

1. The default view presents all eligible completed lot visits across the
   manifest, newest first. Date is an optional visible filter, not the implicit
   definition of “Completed Lots.”
2. Every current eligible completed catalog acquisition appears exactly once in
   the dashboard identity set. Missing, held, superseded, incomplete, duplicate,
   or conflicting acquisitions receive a machine-readable exclusion reason.
3. Repeated visits of the same lot remain distinct by exact scan timestamp, and
   FRONT/BACK grouping remains correct.
4. A failed manifest refresh remains nonblocking for inspection but is surfaced
   explicitly in the tray/viewer; the UI must not silently present a stale
   manifest as current.
5. The viewer identifies the exact manifest revision/hash it loaded and offers
   a deterministic reload or relaunch path.
6. Before any GUI mutation, a fresh read-only full-set reconciliation proves the
   expected ledger/dashboard rows and reproduces the unchanged UI omission, as
   required by the governing GUI recovery rule.

### Callback and error handling

1. No mutable WinForms callback state relies on `$script:` scope. Activity
   lines, last-good snapshots, exit state, and deduplication keys live on one
   captured shared state object.
2. The activity queue remains bounded to ten lines.
3. Logging failure cannot throw from an error handler. One failure produces one
   bounded visible diagnostic, not a second logging exception.
4. A bounded Windows PowerShell 5.1 callback fixture fires Shown, timer ticks,
   close, Completed Lots success/failure, scribe import success/failure, and
   Insite export success/failure. It must produce no unresolved-variable JIT
   dialog and no repeated error on later timer ticks.
5. Timer validation uses a fixed tick count and deadline; it never depends on an
   open-ended wait.

### Scribe import

1. The exact saved response is validated, confirmed, and passed to the installed
   importer before any nonessential logging can interfere.
2. Import success proves the child exit code, exact input path/hash, queue update,
   and refreshed review gallery; import failure reports the child's bounded
   output without hiding the original exception.
3. Child stdout and stderr are drained concurrently with a defined timeout,
   termination policy, and durable result record.
4. The import action disables re-entry while active and always restores the GUI
   state in `finally`.

### Insite action and counts

1. The GUI shows separate counts for actionable read-only lookups and
   metadata/detector holds; it does not label the combined 58 as one homogeneous
   exportable backlog.
2. Export proves the output exists, has the expected schema, exact acquisition
   set/count, SHA-256, and an operator-visible destination.
3. The success message explicitly says export does not decrement the queue.
4. Counts change only after a matching imported snapshot is validated and the
   queue is rebuilt.
5. Export has a bounded deadline, re-entry guard, durable result record, and a
   failure path independent of the activity logger.

## Next safe action

Do not repair or restart the healthy processor from this report. The next safe
step is one proportional read-only observation that freezes the current full
catalog, holds, ledger, dashboard identity set, dashboard-refresh status, and
the exact omitted visits. After that, a separately gated GUI-only repair can be
designed and rehearsed without changing detector, inspection, fiducial,
training, XML, production, deletion, source-image, or wafer-abort authority.
