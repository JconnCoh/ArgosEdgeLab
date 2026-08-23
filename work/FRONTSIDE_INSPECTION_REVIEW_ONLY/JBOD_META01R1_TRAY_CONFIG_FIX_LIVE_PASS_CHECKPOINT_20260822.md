# JBOD META01R1 tray config fix live pass — 2026-08-22

Disposition: `PENDING_GATE`

META01R1 fixed the exact live tray callback defect without redesigning the
inspection flow. The installed `Show-JbodAllWaferTray.ps1` directly read the
optional `productionRoutingEnabled` property under strict mode even though the
approved review-only config safely omits it. The patch changes only that read
to a false-default presence check while retaining fail-closed refusal for
explicit unsafe true.

The signature-verified response for request
`REQ_20260822T231515986Z_B57FB9CFE577` is `PASS_MAINTENANCE_PATCH`; entrypoint
state is `PASS_META01R1_TRAY_CONFIG_READ_FIX_AND_TRAY_ACTIVATION`. The one
installed file moved from SHA-256
`CF8C229A9F0EC5C26D88F800849DF96C9EC6AAA3039FE81F01971E477F4A3828`
to `DA8E272CF2A00BC50A37FD17662E10E0FFEFFA130A928769D517028372CC881F`.
Only the tray task was stopped and started. The refreshed tray is stable as PID
15976 in interactive session 1. Processor PID 6708 and creation time
`2026-08-22T00:17:03.6603700Z` are unchanged; the processor was not restarted
and received no task action. No viewer process was closed, protected task
definition or principal changed, config was rewritten, image was read, source
was mutated, file was deleted, wafer action occurred, or fiducial artifact
changed.

Exact terminal evidence:
`work/META01R1_TRAY_OPTIONAL_CONFIG_FIX/META01R1_LIVE_TERMINAL_EVIDENCE.json`,
SHA-256 `B7656EE2A7E4ACC25F4FC5276EFFC0470ABA22AD07E935D5384A686E0A0E9D75`.

The repair project is
`work/JBOD_INSPECTION_REPAIR_PROJECT_20260822.md`, SHA-256
`61196972554E29E2B9AB40D136F81C6F9AB79F848736625A9F4330CBDD3CB36A`.
`META-01` remains the only active item and is now
`PATCH_INSTALLED_AWAITING_LIVE_CALLBACK`.

Next action: the operator invokes `Export Insite backlog` once from the
refreshed tray. Then use only the normal resulting request/response evidence to
reconcile bounded eligible-request coverage and verified metadata arrival at
`D:\A2\m\verified`. Do not publish another repair, restart the processor,
rewrite the config, clear holds manually, or start SCRIBE-01/GEOM-01/BOWREF-01
until this exact live callback is observed.

AVC1 remains healthy and untouched. FIDCV1 remains operator-paused. R10 and
AVS1 remain withdrawn and cannot be replayed or parent a successor. Global
FS15 and XML, training, production, deletion, image-byte, and wafer-abort
boundaries remain unchanged.
