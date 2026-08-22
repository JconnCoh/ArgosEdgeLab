# All-valid-inspections fix and acceptance checklist

State: `PENDING_GATE`

This checklist is the fixed scope for the recovery. The ten FRONT wafers from
lot `62631-586`, scan `20260819173317`, are the regression cohort; they are not
the product boundary or the whole success criterion.

## Defects that must be corrected

1. Remove the nonexistent `-MetadataSnapshotRoot` argument from the installed
   runner-to-inventory call. Do not change any other runner ordering or safety
   behavior.
2. Make inventory, processing, and dashboard use the same exact producer-
   approved review-only identity-state set:
   `HUMAN_CONFIRMED_REVIEW_ONLY`,
   `IMAGE_CONFIRMED_EXACT_PREVIOUS_HUMAN_SCRIBE_MATCH_REVIEW_ONLY`, and
   `IMAGE_CONFIRMED_CURRENT_PIXELS_EXACT_UNIQUE_MES_REVIEW_ONLY`.
3. Anchor the tray timer's mutable activity key on the captured WinForms form
   object so the Completed Lot button cannot trigger the observed uninitialized
   `$script:lastActivityKey` callback error.
4. Do not surface a superseded completed result as current merely because the
   physical identity is unique. Reuse requires exact recorded source-byte hash
   equality. Without it, retain the row as historical evidence or reprocess the
   current acquisition.
5. Do not modify detector, pose, scribe-exclusion, composite, raster, viewer,
   or other image-processing algorithms unless new direct live evidence proves
   an independent defect. The R5 transitive audit found no call-surface,
   dependency-resolution, or current-source incompatibility requiring such a
   change.
6. Install or restart nothing unless the five installed top-level files are a
   coherent known predecessor. Signed R5C proved all five match the pre-AVS1
   hashes exactly.

## End success state

All of the following are required; none may be replaced by a ten-row-only
check:

1. The processor and tray scheduled tasks are running, with fresh direct
   endpoint heartbeat/process evidence and no tray callback exception.
2. Every current eligible FRONT acquisition has exactly one truthful
   disposition: waiting, processing, completed, failed, or an explicit hold.
   No producer-approved row is silently removed by a downstream enum mismatch.
3. Every current completed FRONT ledger identity appears exactly once in the
   dashboard/Completed Lot data and its ledger job key matches the current
   acquisition fingerprint. Dashboard duplicates and completed-current-ledger
   omissions are both zero.
4. The ten `62631-586_20260819173317` FRONT identities are present exactly once
   in the completed ledger and exactly once in the dashboard/GUI data.
5. The three existing historical completions for slots 02, 07, and 10 of scan
   `20260815171102` are not substituted for different current acquisitions.
   Their current acquisitions must either receive new current-fingerprint
   results or remain explicitly and truthfully non-current.
6. The real tray button opens the Completed Lot viewer without the reported
   `$script:lastActivityKey` exception, and the visible records are derived from
   the same verified dashboard manifest.
7. A matching signed terminal `PASS` proves the one bounded repair action, and
   a subsequent direct read-only endpoint audit proves tasks, heartbeats,
   ledger, dashboard, target-ten, and reconciliation counts.
8. Review-only authority, the global FS15 hold, XML/training/production
   prohibitions, source deletion prohibition, wafer-abort prohibition, and
   image-byte/session-safety boundaries remain unchanged.

## Immediate stop conditions

- any installed top-level hash differs from the signed R5C predecessor set;
- the exact live non-scoring plan does not admit the ten regression rows;
- any required task identity, principal, action, or installed dependency is
  ambiguous;
- a new systemic premise fails during the one bounded action; or
- validation requires historical identity substitution, queue fabrication,
  detector changes, or repeated trial packages.

