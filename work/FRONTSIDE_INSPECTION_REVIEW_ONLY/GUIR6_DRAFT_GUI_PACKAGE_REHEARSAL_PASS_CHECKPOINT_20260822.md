# GUIR6 draft GUI package rehearsal pass checkpoint — 2026-08-22

Disposition: `PENDING_GATE`

This checkpoint supersedes the GUIR4 local-candidate checkpoint as the active
GUI work handoff. It records a successful exact packaged-installer rehearsal,
but it is not a publication, installation, or production release.

## Authority and unchanged boundaries

- Authoritative repository:
  `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab`.
- Branch: `codex/fiducial-opencv-d-drive`.
- Required commit
  `bb09223748c446f0b9e38656d80ca996049a3e55` remains present and is the
  current HEAD.
- The Codex-managed worktree is not a source of truth.
- The healthy AVC1 processor was not changed, stopped, restarted, or used as
  a package test target.
- Fiducial/OpenCV work remains paused at FOP1 and no fiducial artifact changed.
- R10, AVS1, the GUIR4 C1 fixture, and GUIR5 remain non-reusable and cannot be
  successor parents.
- Global FS15 and all XML, training, production, deletion, image-byte,
  source-mutation, and wafer-abort boundaries remain unchanged.

## Retained GUIR3 and GUIR4 authority

The exact signed GUIR3 reconciliation remains
`work/GUIR3/GUIR3_CURRENT_STATE_RECONCILIATION.json`, SHA-256
`2D4B092F82F621B63BD0A30C85C91DBF2D4DFF10534F9A8E1EAB70292539C179`,
state `PASS_GUIR3_CURRENT_STATE_RECONCILIATION`. It proved an exact 270-wafer
current dashboard identity set with zero missing, extra, or duplicate rows,
and identified the viewer's newest-date default as omitting 243 eligible
wafers. It separately proved 33 actionable Insite lookup rows and 25 metadata
holds.

The GUIR4 viewer and tray candidates remain exactly:

- viewer binary SHA-256
  `FD2ABADC0494C0FABA81452B18FB7D860AF7B4F32CA086018D0907E2885B1225`;
- viewer source SHA-256
  `CA69813161A862FF1623AE1989D18F8E6B1394901B2C1BAC279F97307AA07B2C`;
- tray source SHA-256
  `CF8C229A9F0EC5C26D88F800849DF96C9EC6AAA3039FE81F01971E477F4A3828`.

Their independent gates and fresh C2 combined integration gate remain PASS.
The design keeps runtime roots derived from the existing state/config/manifest
contracts and introduces no hard-coded test-lot, wafer, fiducial, detector, or
product switch.

## GUIR5 withdrawal

GUIR5 is `WITHDRAWN`. Its exact packaged-installer predecessor preflight
stopped before installer apply because the draft installer assumed processor
config schema v2 while the pinned exact current config is schema v3, SHA-256
`CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8`.
No candidate file or process ran, no JBOD was contacted, and no installed or
fixture target file changed. `C:\G5D` is non-reusable. The withdrawal record is
`work/GUIR5/GUIR5_DRAFT_PREFLIGHT_WITHDRAWAL.json`, SHA-256
`D37A6767AFF1D006D772DBC29DFB4EDADBDB1FECFFE5448F62DF6F6618500301`.
The failure belongs to the already documented config-schema consumer-preflight
class; it did not create a new operational failure signature.

## Fresh GUIR6 package rehearsal

GUIR6 used a fresh product and output namespace. The mechanical successor was
guarded by `work/GUIR6/GUIR6_CLONE_GATE.json`, SHA-256
`05826094366C258F3019948AA5FDCECCBD1B3E78D9A84F23411D41E27FD77D81`,
state `PASS_ARGOS_CLONE_LITERAL_REMEDIATION`. The exact generated installer and
test harness then passed the PowerShell harness guard. The wrapper gate passed,
and the path gate passed with maximum planned path length 169 and maximum
component length 75.

The exact Windows PowerShell 5.1 packaged-installer rehearsal at fresh root
`C:\G6D` returned `PASS_GUIR6_PACKAGED_INSTALLER_REHEARSAL`. Its gate is
`work/GUIR6/GUIR6_DRAFT_PACKAGED_INSTALLER_REHEARSAL_PASS.json`, SHA-256
`54B04677B1136C89166693DAC2862CAF7C0722C7786AF3979A36E87073296BED`.

The rehearsal proved:

- final-ZIP extraction and every declared payload hash;
- nested extraction and quoted paths containing spaces;
- exact acceptance of the installed tray, root viewer, nested viewer, and
  viewer-source predecessor hashes;
- one successful predecessor installation case;
- one successful already-target/idempotent case;
- four viewer smoke modes and one tray rehearsal in each successful case;
- refusal of an unapproved predecessor before creation of an audit/mutation
  root, with every protected fixture hash unchanged;
- zero orphan processes, zero JBOD access, zero task action, zero image read,
  and zero fiducial change.

The locally rehearsed draft ZIP is
`C:\G6D\GUIR6_REVIEW_ONLY_GUI_FIX_20260822.zip`, SHA-256
`5D944511117B187A5E2707B5BD318A6D1EF0FFB70AB29A5D3E24FA8524431C6C`.
Its package manifest explicitly remains `DRAFT_LOCAL_PACKAGE`. Therefore this
ZIP is test evidence only and must not be copied to `InspectionRevs`, signed,
published, installed, or used as a parent for publication.

## Exact continuation

Stop here unless the operator explicitly authorizes GUI package publication
and installation. After that authority, create a fresh GUIR7 namespace with a
frozen local-unpublished manifest, repeat clone-remediation and every mandatory
pre-action/path/wrapper/harness gate, and rerun the exact packaged-installer
rehearsal against the final ZIP under Windows PowerShell 5.1 before publication.
Do not reuse or relabel the GUIR6 draft ZIP. Do not restart or otherwise touch
the healthy processor, and do not resume fiducial work as part of GUI release.
