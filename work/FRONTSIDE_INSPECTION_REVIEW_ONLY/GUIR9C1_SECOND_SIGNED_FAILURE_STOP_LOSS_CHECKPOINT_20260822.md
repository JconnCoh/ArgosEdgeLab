# GUIR9C1 second signed failure and mutation stop-loss checkpoint — 2026-08-22

Disposition: `PENDING_GATE`

## Authority and outcome

The authoritative repository is
`C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab`. Commit
`bb09223748c446f0b9e38656d80ca996049a3e55` was verified present before this
work. The Codex-managed worktree is not authoritative.

The GUI repair is **not installed and not fixed**. The JBOD is safely back on
the four known-good predecessor GUI files, and the healthy processor remains
`WATCHING`. No third maintenance request is authorized or pending.

## Signed live attempts

GUIR9 request `REQ_G9_0822_A1` returned signed terminal `FAILED` response
`R_B27BAAB4CDA4_20260822205836383_182e8c7d`. Its live process start-time
verification passed a typed CIM `CreationDate` value to the DMTF string
converter, producing `ArgumentOutOfRangeException` for parameter `dmtfDate`.
The endpoint rolled back all four GUI files before any successful activation.
GUIR9 is `WITHDRAWN`, cannot be replayed, and cannot parent a successor.

Evidence:
`work/GUIR9_PORTAL/GUIR9_SIGNED_TERMINAL_FAILURE_GATE.json`, SHA-256
`4522895613100466F802D76A40091924258F5AB5302381966CE408EBAF25B4D7`.

The first signed post-failure read-only observation returned
`PASS_DATA_PULL`, proved all four predecessor hashes restored, and observed the
processor `WATCHING`.

Evidence:
`work/GUIR9_PORTAL/GUIR9O1_POST_FAILURE_OBSERVATION_EVIDENCE.json`, SHA-256
`15B16D0B4A2681052CD3C9B5305E679E375CD7A47FC578C55AEE9E79BB36D788`.

GUIR9C1 corrected only the typed-CIM/string conversion boundary and removed
the hard-coded request ID. The final source SHA-256 was
`A689CB43A86141554C92391520F4626727D846363CC276234BF946F88F49A643`;
the three intended target GUI payload hashes remained unchanged. Its signed
request `REQ_20260822T212739224Z_8F17C57DEAFA` was published exactly once.

The matching signed terminal response
`R_4ED6AC7A9CBB_20260822213037518_7efea9df` returned `FAILED` before GUI task or
process action with exact stderr:

`Endpoint predecessor evidence is missing: Show-JbodAllWaferTray.ps1`

The verifier incorrectly tried to reconstruct an endpoint-private predecessor
evidence filename instead of consuming an endpoint-produced mapping/contract.
The endpoint again followed its rollback boundary. GUIR9C1 is `WITHDRAWN`,
cannot be replayed, and cannot parent a successor.

Evidence:
`work/GUIR9C1_PORTAL/GUIR9C1_SIGNED_TERMINAL_FAILURE_GATE.json`, SHA-256
`D6A2E2680C27CA9B5C25ED7C8600FB034DAA41009691A4048ABCFC35017FCE89`.

## Final signed read-only observation

The separately classified `OBSERVE` request
`REQ_20260822T213441259Z_BA3DAB8B985E` was published exactly once with no
retry. Matching response `R_C2E52461A222_20260822213533375_7ce0d9e2`
verified against the JBOD endpoint signer and returned signed
`PASS_DATA_PULL`.

The returned files hash exactly as follows:

- `Show-JbodAllWaferTray.ps1`:
  `C03812C6889B102DFD9B3CB466E70B06B8943C1123A882EB0ADE972C641DAB2B`
- root viewer executable:
  `39AEA256E4C08043A6F9AEFEADB32F4297217E878C8B71A4603D64FA570677A6`
- runtime viewer executable:
  `39AEA256E4C08043A6F9AEFEADB32F4297217E878C8B71A4603D64FA570677A6`
- runtime `Program.cs`:
  `20A2442FAC73ABDDE95C8876C6A21A2988E63AFBB119F969F7979F7096C7D545`
- `PROCESSOR_STATUS.json`:
  `ECD00C0513F1CE7F6F0B35B664C62836DC8A62754AA0A7A57C335D679533D345`

Processor state is `WATCHING`; its observed `updatedUtc` is
`2026-08-22T21:35:21.188128Z`. The response ZIP SHA-256 is
`EDD0D09888E8BDCCAAA4E20B328B37FBB98FD2CE4B72487542CDD37D8B264136`.

Evidence:
`work/GUIR9C1_PORTAL/GUIR9C1O1_POST_FAILURE_OBSERVATION_EVIDENCE.json`,
SHA-256
`D6A480561D2723CD1EE2D5206E14B3C6FA39AFAB8568A0B74B8487F0915F4E18`.

## Stop-loss and continuation boundary

Two signed live premise failures occurred in this incident. Mutation stop-loss
is active. Do not publish another `MAINTENANCE_PATCH`, install a helper, change
an installed file, or start/restart/stop a GUI or processor task/process until
a workflow review is recorded and a fresh recovery intent explicitly clears
the stop-loss.

The next design must consume an endpoint-produced exact predecessor-evidence
mapping/contract. It must not guess or reconstruct endpoint-private rollback
filenames. Only the broken GUI installation/activation path is in scope; the
known-good GUI payload files remain frozen until that boundary is proved.

The checkpoint promotion preaction is
`work/GUIR9C1_PORTAL/GUIR9C1_STOP_LOSS_CHECKPOINT_PREACTION.json`, SHA-256
`166A1A705AAE0A2616D64506532056976D1B46E2C30778E2ED5BAA424A986C24`,
and passed the 90-issue zero-recurrence audit.

Leave the healthy AVC1 processor and paused fiducial work untouched. R10 and
AVS1 remain `WITHDRAWN`. Formal AVC1 10/10 closure remains unclaimed. Global
FS15 and all XML, training, production, deletion, image-byte, source-deletion,
and wafer-abort boundaries are unchanged.
