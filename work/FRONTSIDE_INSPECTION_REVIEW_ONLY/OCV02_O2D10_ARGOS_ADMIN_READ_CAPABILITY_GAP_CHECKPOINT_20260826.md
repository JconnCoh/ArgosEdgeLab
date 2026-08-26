# OCV-02 O2D10 Argos administrative-read capability gap — 2026-08-26

Disposition: `PENDING_GATE`

This checkpoint supersedes the O2D10 local-signed route-hold checkpoint only
as continuity metadata. It does not supersede, clear, or weaken the complete
route hold. O2D10 remains frozen locally, unpublished, unexecuted, and without
retry authority.

## Direct Argos evidence

The exact ordinary current-layer inventory completed on
`DESKTOP-266P787`. Evidence is
`work/OPENCV_SCRIBE_O2D10/O2D10_ARGOS_CURRENT_LAYER_OBSERVATION_R3.json`,
SHA-256
`A149201990FD6B86E10E9517D1A017A09532E1334BA8D23085108A0430A9B17E`.
It returned state `PASS_EXACT_ARGOS_LEGACY_LAUNCH_INVENTORY`. Both legacy
converter tasks, `Argos_Convert_KLAs_To_XML` and `XML_ConvertScript`, were
already disabled; no task mutation was needed or performed.

The first exact protected inbound-relay observation passed its Argos hostname
gate but did not return structured portal evidence. The operator-visible
terminal result was `Access denied`. Its local failure record is
`work/OPENCV_SCRIBE_O2D10/O2D10_ARGOS_INBOUND_RELAY_OBSERVATION_R2_FAILURE.json`,
SHA-256
`80289EAF532142AFC4C4B01F1E53B5B1A2F2E510DC28DB0A5106CE06BA0298C6`.
This proves that ordinary desktop visibility does not grant the required
protected `C:\ProgramData\ArgosProjectPortalRO` read capability.

A fresh partial observer was then built to catch each task, config, binary,
connection, and queue read independently. The exact Windows PowerShell 5.1
no-clipboard rehearsal and static gates passed. Static gate:
`work/OPENCV_SCRIBE_O2D10/O2D10_ARGOS_INBOUND_RELAY_PARTIAL_OBSERVER_R2_STATIC_GATE.json`,
SHA-256
`40B088A859BF047B2514CA882318CFF1C1746892AB50BE5FBCB410C961BD9035`.
Frozen payload SHA-256 is
`58FA457DFBB35843311DE5239B33802F2CD0DBB56A8B54C86133BD851415C613`;
frozen runner SHA-256 is
`93DAE4FF29C53C696894D32A6994E190373B7A95BEFE6D00BB753E2C3FE9FFE3`.

That fresh action tried to reuse the visible PowerShell console but did not
receive the exact hostname from its bounded `hostname | clip` identity gate
within 30 seconds. It stopped before payload transfer or invocation. Failure
evidence is
`work/OPENCV_SCRIBE_O2D10/O2D10_ARGOS_INBOUND_RELAY_PARTIAL_OBSERVATION_R4_FAILURE.json`,
SHA-256
`F599DE21A2A12765DAF5D84E8431E8B7EC24F8C33E8DB65A5C5C29C38409E0E1`.
The action must not be rerun. No JBOD contact, request publication, target
mutation, task/process restart, provider activation, processor action, source
read, or wafer action occurred.

## Capability gap and exact next action

Current route health is still unproved. The ordinary Argos desktop token is
insufficient for the protected portal reads, and the presumed reusable console
is not proved to be at a usable prompt. Do not change ACLs, create a helper
task, guess credentials, reuse the frozen observer, start another tunnel, or
publish O2D10.

The only operator input required is to open **Windows PowerShell as
Administrator on Argos `10.20.70.241`** and leave that exact window visible at
an idle prompt. Do not open it on the gateway, JBOD, or engineering laptop.
Codex must then create and gate a fresh read-only observer namespace, first
prove exact hostname and administrative read capability, and only then collect
the bounded inbound receiver/relay task, installed config and worker hashes,
`requests_from_gateway`, `to_jbod`, and exact queue/archive state. The
administrative window grants read-only observation authority only; it grants no
mutation authority.

Only an exact route PASS proving current relay health and no unresolved earlier
accepted request can authorize one create-new publication of the already frozen
O2D10 ZIP. Then collect only its matching signed terminal response. No retry is
authorized. Slot16 remains unfrozen, Slot17 blocked, Slots22-25 unseen, live
provider disabled, healthy processor untouched,
`SCRIBE_REFERENCE_COVERAGE_HOLD` and every existing hold preserved. Production,
XML, training, source-deletion, and wafer authority remain absent.

The frozen O2D10 ZIP remains
`work/OPENCV_SCRIBE_O2D10/final/REQ_20260826T015418549Z_F5D3732576F9.ready.zip`,
19,249 bytes, SHA-256
`289276329B5C2A34F8155C33001747034ACB85CC89B16EBB630D9E4F6FC87256`.
The unchanged complete route gate remains
`HOLD_O2D10_COMPLETE_ROUTE_GATE_ARGOS_INBOUND_RELAY_UNPROVEN`, SHA-256
`B04FF3EF0F389C45C4FC8E4119468A56EB971E8325F2ECAB6ADAA150959061BE`.

Checkpoint preaction:
`work/OPENCV_SCRIBE_O2D10/PREACTION_O2D10_ARGOS_ADMIN_READ_CAPABILITY_GAP_CHECKPOINT.json`,
SHA-256 `DAFCA225448C93BDE96A37648C22CE4B6A8069EF3EEB7E448D4AF53D006A8CFE`.
