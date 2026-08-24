# OpenCV OCV-00 OLS2 Signed Terminal Failure Checkpoint — 2026-08-24

Disposition: `PENDING_GATE`

## Signed terminal outcome

The pinned JBOD certificate verifies response
`R_CC18FEEA00BD_20260824173017440_aae41c8c` as the matching terminal response
for `REQ_OLS2`. The exact 2,248-byte response ZIP has SHA-256
`D6C4C56ECEA086FE29CB31704E1BA61E783E0D887EE6A9827B597E2225C84673`.
The terminal gate SHA-256 is
`6F37C539876D879B2D91D64BC950817737259A6A4721F001F5323A61859CA70D`.

The endpoint state is signed `FAILED`. `FAILURE.json` says the maintenance
verifier exited 1 and points to exact stderr. That stderr has SHA-256
`9FDE269E93D3E42B4B3193059615BCC2E6466C6CA215364632A79665ACFBD683`
and reports:
`OLS2 output bounded subtree inventory did not complete safely.`
The failing assertion is in the installed OLS2 entrypoint after the worker
returns; signed stdout is empty. The response does not expose which frozen
completion predicate failed, so no cause below that assertion is yet proven.

This is one signed live-premise failure in the OLS2 incident. It establishes
no inventory pass, no exact `Lot_62619-433` BF/DF leaf, no PFC010 replacement
pair, no source hash, and no image-processing authority. A retry, duplicate,
successor mutation, threshold relaxation, broader enumeration, or source
fallback is prohibited until a direct post-failure observation is pinned.

## Local collector lifecycle

The first local failure collector is `WITHDRAWN`. It successfully reached
signature verification but then failed to write its terminal gate by directly
reading an absent optional `FAILURE.json.message` property under StrictMode.
Its preserved non-reusable root is `C:\AS2F`; its withdrawal SHA-256 is
`B4D684E3FFA065D54C7AB60E8C5A08E23A2006CA95BDA36ABD91B9DECB628A33`.

Fresh R2 used `C:\AS2G`, explicit absent/present optional-property controls,
the same pinned response ZIP, and the unchanged qualified signature verifier.
It collected the signed failure successfully. Neither collector contacted the
endpoint, mutated a queue, read lot file contents or image bytes, hashed source
images, processed pixels, changed a task/process, restarted the healthy
processor, deleted a source, or acted on a wafer.

## Next bounded action

Classify the next step as `OBSERVE`. Use only an already installed and
qualified read-only route to retrieve the exact installed OLS2 inventory output
and the minimum pinned installed worker/config evidence needed to identify the
failed completion predicate. Do not use another maintenance patch and do not
rerun enumeration merely for diagnosis. If the exact output is absent or the
existing route cannot return it, stop with that capability gap.

All bin/null-clue-only, PFC003/PFC010, replacement-pair, global FS15, notch,
map, pose, fiducial-site, composite, registration, scoring, reviewer,
R10/AVS1, XML, training, production, deletion, and wafer-action holds remain
unchanged.
