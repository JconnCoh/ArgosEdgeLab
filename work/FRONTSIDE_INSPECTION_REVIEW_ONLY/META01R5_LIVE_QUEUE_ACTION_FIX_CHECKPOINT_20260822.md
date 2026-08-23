# META01R5 live queue action fix — 2026-08-22

State: `RELEASED_REVIEW_ONLY`

META01R5 changed one installed file, `Update-JbodScribeIdentityQueue.ps1`, from SHA-256 `F7505FD013D2B908E2E38F9205E9D767E6A30E7DE42724C94B657BA358822418` to `6185D960F32088120E304BE49D5BF99C525B07EE60F5D68017A40A93F68EC6A9`. Signed response `R_C0632572664F_20260823000831457_be2eadd0` returned `PASS_MAINTENANCE_PATCH` with exactly one changed file.

The patch separates pending metadata from complete metadata and prevents the confirmed-overlay fallback from re-advertising terminal Insite holds. No task or process was restarted.

Signed post-action readback `R_9D8FE1FE292E_20260823001116830_ebc2c913` returned `PASS_DATA_PULL`. The live queue now has exactly 25 actionable rows, all 25 are genuine `HOLD_INSITE_METADATA_REQUIRED_BEFORE_DETECTOR` rows, and zero terminal holds are falsely actionable. The six cohorts are 62621-582 (4), 62624-869 (3), 62628-301 (9), 62628-317 (3), 62630-465 (4), and 62631-536 (2).

The healthy processor was untouched. R10 and AVS1 remain WITHDRAWN. Fiducial work remains paused. XML, training, production, deletion, image-byte, and wafer-abort boundaries are unchanged.

Machine evidence: `work/META01R5_QUEUE_ACTION_FIX/LIVE_TERMINAL_EVIDENCE.json`.
