# JBOD inspection repair project — 2026-08-22

Disposition: `PENDING_GATE`

This is the authoritative repair list for the live JBOD review-only inspection
pipeline. Work is performed against exact live JBOD files and state. The
healthy AVC1 processor, working GUI behavior, portal route, XML boundary,
training/production authority, source images, and wafer state remain frozen
unless a listed repair explicitly requires a separately authorized bounded
change.

## Repair order

| ID | Priority | State | Problem | Completion boundary |
|---|---:|---|---|---|
| `META-01` | 0 | `PATCH_INSTALLED_AWAITING_LIVE_CALLBACK` | The exact tray callback defect was its strict-mode direct read of the omitted optional `productionRoutingEnabled` property. META01R1 installed the false-default presence check and restarted only the tray. | Invoke `Export Insite backlog` once from the refreshed tray, then prove current eligible confirmed acquisitions receive bounded Insite request coverage and qualifying responses populate the configured `D:\A2\m\verified` overlay. No production routing or unrelated task/process change. |
| `SCRIBE-01` | 1 | `PENDING` | Automatic scribe deciphering leaves valid physical wafers awaiting operator confirmation. | Improve native-image scribe localization/normalization/recognition without hard-coded lot or scribe identities; preserve operator confirmation for ambiguous results and prove bounded positive/negative live-JBOD regression coverage. |
| `GEOM-01` | 1 | `PENDING` | All five attempted wafers for lot `62624-871` ended `BARE_JOB_HOLD_GEOMETRY`. | Pull the five exact live `JOB_RESULT.json` records, determine whether the approved geometry fix is absent or still failing, change only the proved geometry defect, and obtain non-held review-only results without weakening unrelated geometry safety. |
| `BOWREF-01` | 1 | `PENDING` | Two BowComp-ready wafers for lot `62628-317` are blocked by the live minimum-three leave-one-out reference-family rule. | Add use of an exact qualified, versioned server/JBOD BowComp composite when available; retain fail-closed hold when neither a compatible stored reference nor a sufficient live family exists. Do not make a one-wafer peer composite authoritative. |
| `CVCORE-01` | 2 | `PENDING_AFTER_BLOCKERS` | Pixel-heavy PowerShell processing is slow and fragments fiducial, registration, geometry, composite, and scribe logic. | Introduce a stable JBOD-native OpenCV worker interface with file-backed JSON input/output. PowerShell remains orchestration. Runtime-intensive work and model/cache/output data use `D:`. No laptop path, lot identity, or current test image is hard-coded. |
| `FIDCV1` | 2 | `OPERATOR_PAUSED` | Fiducial OpenCV integration was intentionally paused for GUI work and still has its recorded source-path capability gap. | Resume only after explicit operator direction and from the existing pause checkpoint; preserve the downstream fiducial-to-composite-to-inspected-wafer alignment contract. |

## Current exact evidence

- Authoritative repository:
  `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab`.
- Required published commit is present:
  `bb09223748c446f0b9e38656d80ca996049a3e55`.
- Signed live data pull:
  request `REQ_20260822T224156201Z_40770C214CFA`, response
  `R_6C8CC60D5ADD_20260822224125446_cd0c2700`, `PASS_DATA_PULL`.
- The six reported missing lots all have zero current `COMPLETED` ledger rows.
  Their causes are preserved as upstream identity, metadata, geometry, or
  reference-family holds rather than reclassified as a GUI failure.
- The exact live processor config is schema v3, review-only, XML-disabled,
  production-ineligible, and safely omits optional `productionRoutingEnabled`.
  Its SHA-256 is
  `CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8`.
- Prior signed C2W installed a presence-checked Insite bridge worker at SHA-256
  `4F60B9C9D5AE3CC6EABE8983A6A27D5EB391D6101C07E94406CDD570748B02B2`.
  Therefore `META-01` must locate the separate installed consumer still
  emitting the same strict-mode error; the live config must not be rewritten
  merely to satisfy that consumer.
- META01R1 returned signed `PASS_MAINTENANCE_PATCH` for request
  `REQ_20260822T231515986Z_B57FB9CFE577`. It installed only
  `Show-JbodAllWaferTray.ps1` at SHA-256
  `DA8E272CF2A00BC50A37FD17662E10E0FFEFFA130A928769D517028372CC881F`
  and restarted only the tray. Processor PID 6708 and its creation time were
  unchanged; no processor task action, viewer close, config rewrite, image
  read, deletion, wafer action, or fiducial change occurred.

## Working rule

One item is changed at a time. Working components are frozen. Each repair must
start from exact live installed bytes and direct live state, change only the
proved defect, and verify the result on the JBOD. A hold may be cleared only by
the normal successful producer/consumer flow that owns it; no queue, ledger,
metadata, or result row is fabricated or manually deleted.
