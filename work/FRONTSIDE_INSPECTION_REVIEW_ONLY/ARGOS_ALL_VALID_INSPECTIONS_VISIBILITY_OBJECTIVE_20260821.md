# All-valid-inspections visibility objective

State: `PENDING_GATE`

The ten FRONT wafers from lot `62631-586` are a regression cohort, not the
product-level goal.

The problem to determine and correct is whether valid, eligible inspection
inputs are failing before terminal completion or whether completed inspections
are failing to surface in the completed-lot GUI. No valid input may disappear
silently between the catalog, explicit eligibility/hold state, processing
ledger, dashboard manifest, and GUI.

Success requires all of the following:

1. The complete current catalog is reconciled against the installed
   review-only eligibility contract. Every valid input has exactly one explicit
   disposition: held with a recorded reason, waiting, processing, failed, or
   completed. There are no unaccounted eligible inputs.
2. Every completed inspection ledger identity is represented exactly once in
   the dashboard/completed-lot data, with no duplicate or silent omission.
3. The exact ten `62631-586` FRONT identities are present exactly once in the
   eligible/terminal reconciliation and, when completed, exactly once in the
   completed-lot GUI data.
4. The completed-lot window opens from the real tray button without the
   reported uninitialized `$script:lastActivityKey` exception, and its visible
   records match the authoritative dashboard manifest.
5. Processor heartbeat and terminal-state evidence establish whether a restart
   has any point. No restart is performed merely because a GUI button failed.
6. Review-only, FS15 hold, XML, training, production, deletion, image-byte,
   source, and wafer-abort boundaries remain unchanged.

The first action is one bounded read-only data pull through the already
qualified endpoint. It retrieves only text/JSON/PowerShell files and hashes.
If that single snapshot cannot distinguish the failing boundary, stop and
report the exact ambiguity; do not build another diagnostic package.
