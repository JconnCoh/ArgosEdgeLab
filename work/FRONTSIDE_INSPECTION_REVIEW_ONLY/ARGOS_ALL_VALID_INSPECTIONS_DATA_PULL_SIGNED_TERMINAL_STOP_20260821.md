# All-valid-inspections read-only audit — signed terminal stop

State: `STOP_READ_ONLY_AUDIT_REQUIRED_SOURCE_ABSENT`

The broadened goal is unchanged: every valid input must have an explicit
disposition and every completed inspection must appear exactly once in the
completed-lot GUI. The ten `62631-586` FRONT wafers remain a regression cohort,
not the success boundary.

The single authorized read-only request
`REQ_20260821T202917395Z_675B67258EC9` returned signed response
`R_4E81B46C722B_20260821203034791_6c70a719` with terminal state `FAILED`:

`DATA_PULL source not found: R10.ps1`

The JBOD signature was verified against the pinned endpoint certificate. The
response returned only `FAILURE.json`; none of the catalog, queue, overlay,
ledger, dashboard, heartbeat, runner, or live tray files were returned.

`R10.ps1` absence is consistent with R10's failed maintenance verifier and the
endpoint's create-on-install rollback behavior. It should have been classified
as an optional/expected-absent artifact, not placed in an all-or-nothing
`DATA_PULL` source list.

No retry is published. No endpoint or installed file changed. No task or
process action, restart, queue or ledger mutation, GUI change, image read,
source deletion, or wafer action occurred. Remedies `A`-`D`, restart value, the
ten-wafer result, and the global pipeline reconciliation remain unestablished.

This stop is deliberately terminal for the current attempt. A future separately
authorized audit must omit `R10.ps1`, bind its absence from this signed response
and R10 rollback evidence, and prove every remaining `DATA_PULL` source is
required-present before publication. It must not create R11 or a diagnostic
helper.
