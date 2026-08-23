# GUIR4 local GUI candidates combined pass checkpoint — 2026-08-22

Disposition: `PENDING_GATE`

This checkpoint records the completed read-only GUI reconciliation and the
successful isolated local build and test of two GUI-only repair candidates.
It does not authorize or claim publication, installation, task/process
control, or a production GUI release.

## Authority and retained boundaries

- Authoritative repository:
  `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab`.
- Required published recovery commit
  `bb09223748c446f0b9e38656d80ca996049a3e55` is present.
- The Codex-managed worktree is not a source of truth.
- The healthy AVC1 processor was not changed, stopped, restarted, or used as
  a GUI test target.
- R10 and AVS1 remain `WITHDRAWN` and are not parents of this work.
- Fiducial/OpenCV work remains paused at FOP1. None of its artifacts were
  changed by GUIR3 or GUIR4.
- Global FS15 and all XML, training, production, deletion, image-byte, and
  wafer-abort boundaries remain unchanged.

## Exact signed current-state reconciliation

GUIR3 collected the already-returned matching signed `PASS_DATA_PULL`
response for request `REQ_GUIR2_0822_X1`; the request was not retried or
republished. The terminal response gate is
`work/GUIR3/GUIR3_TERMINAL_RESPONSE_GATE.json`, SHA-256
`A0A3B69B1EF8CA7FF3618DB214830E30720C2D36AA32B48AA3B11F75980C050C`.
The exact Windows PowerShell 5.1 analysis is
`work/GUIR3/Analyze-GUIR3CurrentState.ps1`, SHA-256
`C6B0EC38CC742CF2F9C936BCD5270F259168FDF4D8B98ABB46CB55F26024EE67`.

The reconciliation result is
`work/GUIR3/GUIR3_CURRENT_STATE_RECONCILIATION.json`, SHA-256
`2D4B092F82F621B63BD0A30C85C91DBF2D4DFF10534F9A8E1EAB70292539C179`,
state `PASS_GUIR3_CURRENT_STATE_RECONCILIATION`. It proved:

- 1,844 unique acquisition catalog rows;
- 459 completed, 63 failed, and 53 held ledger rows;
- an exact dashboard current-eligible set of 270 unique wafers, with no
  missing, extra, or duplicate identity: 38 FRONT and 232 BACK;
- 41 sessions, 40 visits, and 13 dates;
- the unchanged viewer defaulted to the newest exact date and therefore
  displayed only 2 visits, 3 sessions, and 27 wafers while omitting 38 visits,
  38 sessions, and 243 otherwise eligible wafers;
- 922 scribe-queue rows, including 33 actionable Insite lookups and 25
  metadata-hold rows whose exact `nextAction` is `NONE`;
- the processor remained `WATCHING` and untouched.

This satisfied the GUI recovery ordering rule: the authoritative dashboard
already contained the expected complete current identity set before GUI code
was changed.

## GUIR4 integration-safe design

The frozen local design is `work/GUIR4/GUIR4_DESIGN.json`, SHA-256
`44EE00B2C7C3FF62B2B307A9AC366052C25342626B04446CD1DCBBA21E34A093`.
It preserves the installed runtime-root/config/manifest relationships and
does not add test-lot, fiducial, detector, product, or wafer selectors. The
viewer and tray remain downstream consumers only, so a later qualified
fiducial/composite implementation is discoverable through the existing
manifest and state-root contracts rather than a new hard-coded switch.

The observation evidence is
`work/GUIR4/GUIR4_RECOVERY_OBSERVATION_EVIDENCE.json`, SHA-256
`B814BCD44C9F3A7B7B4EDCCFFF96BACAD2D44A367774152F838AC4315DA17C02`.
The local-only build intent is
`work/GUIR4/GUIR4_LOCAL_BUILD_MUTATION_INTENT.json`, SHA-256
`1EFCE474AF965571B7B06B86A1521917E3F1322CD61B6CDE82596CF560181EC6`.

## Viewer candidate result

The locally built viewer candidate is
`C:\G4B\viewer\ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe`, SHA-256
`FD2ABADC0494C0FABA81452B18FB7D860AF7B4F32CA086018D0907E2885B1225`.
Its generated source is `C:\G4B\viewer\Program.cs`, SHA-256
`CA69813161A862FF1623AE1989D18F8E6B1394901B2C1BAC279F97307AA07B2C`.

The candidate shows every eligible date by default, newest first; retains an
explicit date filter; preserves exact lot/timestamp visit grouping and
FRONT/BACK separation; displays the full scan timestamp and exact manifest
identity/readiness; and provides deterministic manifest reload.

The independent gate is `work/GUIR4/GUIR4_VIEWER_TEST_GATE.json`, SHA-256
`2345665FF761E40E5DAB506DF17A48DAFB5E296583029D0C91EA2E1B5A16D85F`,
state `PASS_GUIR4_VIEWER_INDEPENDENT_TEST`. Its bounded fixture proved 41
sessions, 40 visits, 270 wafers, and 13 dates and passed catalog, export-name,
UI, and side-selector smoke tests without reading image bytes.

## Tray candidate result

The locally built tray candidate is
`C:\G4B\tray\Show-JbodAllWaferTray.ps1`, SHA-256
`CF8C229A9F0EC5C26D88F800849DF96C9EC6AAA3039FE81F01971E477F4A3828`.
Its mutable callback state is anchored to the form object. Child operations
are single-flight, bounded to 120 seconds, asynchronously drain stdout and
stderr, contain activity-log failures, and may terminate only their own child
on deadline or exit. Each operation records durable script/input/output/queue/
gallery hashes. The UI separately reports 33 actionable lookups and 25
metadata holds; export is explicitly not represented as queue completion.

The independent gate is `work/GUIR4/GUIR4_TRAY_TEST_GATE.json`, SHA-256
`168644ADC77F4AF4B49146E40FE10BDF7130A13695822CD15991A3664817C821`,
state `PASS_GUIR4_TRAY_INDEPENDENT_TEST`. It passed source-contract assertions,
callback/timer fixtures, Windows PowerShell 5.1 parsing, and the exact
non-mutating rehearsal path with no child operation left running.

## Combined result and withdrawn local fixture

The first combined C1 local fixture is `WITHDRAWN`. It failed before any
candidate or child process launched because its local assertion searched raw
serialized JSON for an unescaped Windows path. It created only the partial
local root `C:\G4C`; that root is non-reusable. The record is
`work/GUIR4/GUIR4_COMBINED_C1_WITHDRAWN_LOCAL_FIXTURE_FAILURE.json`, SHA-256
`E329629F001BA7EC21CCEB97D0772EB6DB955CB330534C082570799BC215A4A3`.
This was a known serialized-path assertion class, not a JBOD or GUI-product
failure, and no production state was contacted.

Fresh C2 used `C:\G4C2`. Its gate is
`work/GUIR4/GUIR4_COMBINED_C2_TEST_GATE.json`, SHA-256
`2993A3C861C5631C753F860C0741F76CB9C398912433DBA3E540DEBFFE51AE45`,
state `PASS_GUIR4_COMBINED_C2_LOCAL_INTEGRATION`. The exact tray rehearsal and
unchanged completed-lot launcher rehearsal completed successfully, including
the launcher's three nested viewer smoke tests. Five bounded local processes
completed; none contacted the JBOD, opened a production viewer, or touched the
processor.

## Stop point and exact continuation

The GUI repair candidates are locally validated but remain `PENDING_GATE`.
No JBOD package has been built, signed, published, installed, or launched.

Continue only by creating a fresh GUI-only package namespace and applying the
mandatory Windows/JBOD pre-action, path-budget, wrapper, harness, clone-
remediation, and exact packaged-installer predecessor gates. Exercise every
declared installed predecessor under Windows PowerShell 5.1. Do not install or
publish the package without explicit operator authorization. Do not alter or
restart the healthy processor, and do not resume fiducial work as part of the
GUI package.
