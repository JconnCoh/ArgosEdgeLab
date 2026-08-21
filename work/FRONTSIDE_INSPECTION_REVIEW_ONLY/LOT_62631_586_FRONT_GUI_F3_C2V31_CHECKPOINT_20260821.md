# Lot 62631-586 FRONT GUI F3 / C2V31 checkpoint

Status: `PENDING_GATE`

F3 installed the generic confirmed-scribe-first JBOD bridge worker through the existing signed Project Portal route. The worker is not identity-specific: it requests `CONFIRMED_SCRIBE` metadata first and uses `CURRENT_IMAGE_CANDIDATE` only when no confirmed metadata is pending.

Locked live evidence:

- Installed JBOD worker SHA-256: `8D10D7A775741F9A2B4FD4AA831E1426DCA1DC2A17A9A68AD8CD432F10265B5C`.
- F3 signed terminal gate: `work/F3/F3_TERMINAL_RESPONSE_GATE.json`; SHA-256 `53AABC73325F27199F886705F63B9850986934BF546AA5735C10FAF70256D453`.
- Exact request content SHA-256: `099A2BD997E94666ABE0861719132E65AC3B000980861B30D64E5AD2734ECF64`.
- Exact imported response payload SHA-256: `19E94B8F399A28A366FF55F8C1CE0451DECEAB72F31EC77F2F55476AE31E16AB`.
- Response records: 25; exact target acquisition contexts: 10.
- All ten `62631-586_20260819173317_SLOT01..10` acquisitions have confirmed scribes.
- Target active Insite holds: 0; verified metadata rows: 0; GUI FRONT asset wafers: 0.
- C2V31 signed terminal gate: `work/V31/C2V31_TERMINAL_RESPONSE_GATE.json`; SHA-256 `BDC303C17598407D005A68A89E7592AF983C134C0C5DD39EC4189DCBB2A45E05`.

The remaining blocker is isolated to the generic Argos-side frontside scratch-test route classifier. Its installed V1 implementation only recognizes `SACRIFICIAL NITRIDE DEP {1}` as the deposition anchor. The target lot has a legitimate repeated cycle with a newer `SACRIFICIAL NITRIDE DEP {2}` / `NITRIDE_DEP` move-in on 2026-08-19, so V1 anchors to the older July cycle and incorrectly emits `HOLD_FRONTSIDE_SCRATCH_TEST_POST_ANCHOR_MATERIAL_TOOL_PRESENT` for all ten current acquisition contexts.

Next action: minimally patch the established Argos query provider to choose the latest qualifying numbered sacrificial-nitride deposition anchor at or before the exact Argos scan, restrict same-flow allowance to that selected process-block instance, preserve genuine post-anchor material-tool holds, install it through the existing signed Argos Project Portal endpoint, queue/import a fresh exact confirmed-scribe response, refresh the existing consumer path, and require a signed `frontsideAssetWafers=10` result before release.

No image was read, no lot/slot identity was hardcoded, no queue was cleared, no task was restarted, no source was deleted, no wafer was aborted, and no XML, training, or production authority was granted.

Session safety at this checkpoint: metadata-only checker state `CHECKPOINT_ONLY_CONTINUE`; current task size 152,761,004 bytes (145.684 MiB), below the first-probe and rotation thresholds.
