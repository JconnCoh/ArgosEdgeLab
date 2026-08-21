# Gateway response-publication repair V1.1 released checkpoint — 2026-08-17

## State

`GATEWAY_RESPONSE_PUBLICATION_REPAIR_V1_1` is `RELEASED_REVIEW_ONLY` for one
administrator launch on exact gateway `TXSH-DPMZ0295HR`. It is not yet applied.
The 41-file FM7P24A result pull remains unsigned.

`GATEWAY_RESPONSE_PUBLICATION_REPAIR_V1` is now `WITHDRAWN`. Its Explorer-run
preflight wrapper did not hold the terminal open, so it did not provide a
usable operator result. The operator ran only the non-mutating preflight; no
live apply evidence exists. V1 must not be retried or followed by its separate
repair wrapper.

## Exact V1.1 package

The replacement preserves the already rehearsed repair payload and its exact
gateway, installed-predecessor, task-identity, alias, path, rollback, and
review-only pins. It changes the operator orchestration only:

- `RUN_ON_GATEWAY.cmd` is the single operator launcher;
- a create-new persistent log is written beneath `C:\GWR_LAUNCH` before
  preflight begins;
- the pinned repair starts automatically only after the exact authorized
  preflight PASS;
- failed preflight launches zero repair actions;
- an already-applied target launches no duplicate repair; and
- every wrapper path converges on an unconditional terminal hold.

The exact published artifacts are:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `ARGOS_GATEWAY_RESPONSE_PUBLICATION_REPAIR_V1_1.zip` | 27,305 | `CD2F283F5A0376A89F6BD4A440CCFFA2D697282B28D441C8448EF1C24C276DFF` |
| `ARGOS_GATEWAY_RESPONSE_PUBLICATION_REPAIR_V1_1.PATH_PREFLIGHT.json` | 1,055 | `15D8B06026DBDB59C36D0AD1803FBD90A8F1D777BB80A9E9DD1B2CD5A6F52584` |
| `ARGOS_GATEWAY_RESPONSE_PUBLICATION_REPAIR_V1_1.REHEARSAL_PASS.json` | 1,776 | `80E75DB95AA30A8DB1C1B4BC9FFF8E3146BECFED6D7BF2A752A70CB599DBA5F3` |
| `ARGOS_GATEWAY_RESPONSE_PUBLICATION_REPAIR_V1_1.FINAL_PACKAGE_GATE.json` | 3,281 | `A11079BAB5072A4D926857C10FFAE3ECA11533B3BBF048D63133FD680DFC42BF` |

All four were copied create-new to the operator-provided `InspectionRevs`
root through a verified short `I:` mapping. Every share hash matched, and the
mapping was removed after publication.

## Exact final-ZIP gate

The final ZIP was extracted fresh to `C:\GLZ\X1`. Its 12 files and all 11
manifest entries matched exact sizes and hashes. The extracted wrapper passed
`PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT` under the required Windows
PowerShell 5.1 structure.

The extracted repair then passed all eight predecessor/apply/rollback controls
from fresh fixture root `C:\GLZ\R1`, including task-context alias write proof,
unapproved-predecessor refusal before mutation, idempotent target acceptance,
and response-receiver immutability.

The extracted launcher passed 11/11 controls from fresh fixture root
`C:\GLZ\L1`: success preflight-then-apply, persistent success log, failed
preflight with zero apply and persistent failure log, already-applied with zero
duplicate, persistent preflight-only mode with zero apply, one PowerShell call,
unconditional terminal hold, and no detached or arbitrary-argument wrapper
hop.

## Authorized live behavior

The unchanged repair payload creates `C:\APR\S` as a directory symbolic link
to the existing canonical `ProjectPortalRO` share root, replaces exactly the
gateway share bridge and `gateway_share.json`, and restarts only
`ArgosProjectPortal.Gateway.ShareBridge.RO`. The restarted interactive
`fab.op` task must itself prove create/read/delete access through the alias.
The response receiver is never stopped or changed. Any failure restores the
exact predecessors and removes only the exact newly created alias. Production
routing remains disabled.

## Next action

On gateway `TXSH-DPMZ0295HR`, extract only the V1.1 ZIP to a fresh short local
folder such as `C:\GWR11`, then run only `RUN_ON_GATEWAY.cmd` as Administrator.
No second launcher or manual preflight step is required. The terminal remains
open and the persistent log path is printed. A successful repair also writes
`C:\GWR\REPAIR_RESULT.json`.

After live PASS, rerun the complete 41-file response-publication route gate
before signing the FM7P24A pull. No detector, alignment, composite, defect,
Normal, mask, XML, training, or production authority changed.
