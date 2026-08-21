# Argos Map Conversion and XML Infrastructure

Last updated: 2026-07-24

Purpose: preserve the current understanding of how Argos `.KLA` map conversion, XML naming/routing, and the defect-detection project connect. This file is intended to live in:

```text
C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab\ARGOS_MAP_CONVERSION_AND_XML_INFRASTRUCTURE.md
```

Use this as a read-only project reference for Codex and future debugging. Verify exact script internals against the local files before modifying any production automation.

---

## 1. Scope

This project has two connected lanes:

```text
A. Existing ArgosAuto KLA -> XML automation
   - stages Argos KLA files
   - maps physical slots to container/wafer IDs
   - converts KLA to XML
   - writes XML + bin legend CSV
   - routes XML to ShermanData folders

B. Argos Image AI defect detection / review
   - uses Brightfield/Darkfield wafer images
   - generates review GUI and feedback zips
   - will later export validated defect contours/masks to XML
```

Do not mix these carelessly. The existing KLA/XML automation is already moving files and writing XML. The AI defect-review work is still under validation and must not generate production XML geometry until explicitly promoted.

---

## 2. Known machines, shares, and tool IPs

### Argos / automation host references

Observed accessible Outbox shares:

```text
\\DESKTOP-266P787\ArgosAuto\Outbox      ACCESS OK
\\10.20.70.241\ArgosAuto\Outbox        ACCESS OK
\\10.66.82.33\ArgosAuto\Outbox         NO ACCESS / PATH NOT FOUND
```

Known IP used by mover configuration:

```text
10.20.70.241
```

Known local automation root:

```text
C:\ArgosAuto
```

Known image/detection output root:

```text
D:\ArgosImageAI
```

Known KLA acquisition/source roots from staging logs:

```text
E:\MT1300Argos\BS_SCRUB
E:\MT1300Argos\PST_BRKFULLMETAL
E:\MT1300Argos\PST_BRKFULLMETAL_BOWCOMP
```

Known lab/dev consolidation workspace:

```text
C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab
```

---

## 3. Existing ArgosAuto scheduled tasks

### KLA staging task

Observed scheduled task:

```text
Argos_Stage_BS_SCRUB_KLAs
```

Known log:

```text
C:\ArgosAuto\Logs\stage_bs_scrub_kla.log
```

Observed behavior:

```text
- scans MT1300Argos source roots
- copies KLA files into ArgosAuto inbox / lookup pending areas
- logs counts like copied / seeded / already / skipped / wait / hold
```

Observed source copy example:

```text
FROM: E:\MT1300Argos\PST_BRKFULLMETAL\Lot_62546-481_POST\62546-481_POST\Slot25\RawResults\Klarf\back_2026-07-08_15-54-40_62546-481_POST_Slot25.kla
TO:   C:\ArgosAuto\Inbox\_LookupPending\back_2026-07-08_15-54-40_62546-481_POST_Slot25.kla
```

### KLA -> XML converter task

Observed scheduled task:

```text
Argos_Convert_KLAs_To_XML
```

Observed status in log excerpts:

```text
Ready
```

Main processor script seen in process/log notes:

```text
C:\ArgosAuto\Run-ArgosKlaAutoProcessor.ps1
```

Lock file seen:

```text
C:\ArgosAuto\argos_autoprocessor.lock
```

Operational note: stale converter processes and stale lock files were previously cleared during troubleshooting before restarting converter processing.

### XML network mover task

Observed scheduled task:

```text
Argos_Move_XML_To_ShermanData
```

Known mover log:

```text
C:\ArgosAuto\Logs\network_mover.log
```

Known mover script:

```text
C:\ArgosAuto\Move-ArgosXml-To-ShermanData.ps1
```

Known mover state from evidence:

```text
Ready
```

---

## 4. Existing ArgosAuto folder flow

Observed KLA input folder pattern:

```text
C:\ArgosAuto\Inbox\3164\*.kla
```

Observed product/template key:

```text
3164
```

Observed working output folder:

```text
C:\ArgosAuto\Working
```

Observed outbox folder:

```text
C:\ArgosAuto\Outbox
```

Observed network source roots for mover:

```text
\\10.20.70.241\ArgosAuto\Outbox
\\10.20.70.241\ArgosAuto\Sent
\\10.20.70.241\ArgosAuto\Move_Error
```

Observed converter lifecycle for each KLA:

```text
1. Found KLA in C:\ArgosAuto\Inbox\3164
2. WAFER MAP: physical SlotXX -> container/wafer LOT-WAFERID
3. Converting product/template-key=3164 wafer=LOT-WAFERID
4. Working XML: C:\ArgosAuto\Working\LOT-WAFERID.XML
5. CONVERTER: Output XML: C:\ArgosAuto\Working\LOT-WAFERID.XML
6. CONVERTER: XML SubstrateId/Wafer: LOT-WAFERID
7. CONVERTER: Bin legend CSV: C:\ArgosAuto\Working\LOT-WAFERID_bin_legend.csv
8. If no blocking condition, place XML in C:\ArgosAuto\Outbox with route prefix.
```

Blocking condition observed:

```text
CONVERTER: WARNING: Unmapped KLA classes found.
See: C:\ArgosAuto\Working\LOT-WAFERID_UNMAPPED_KLA_CLASSES.csv
HOLD: Unmapped KLA classes found for LOT-WAFERID. Not placing XML in Outbox.
```

---

## 5. XML outbox naming convention

Observed outbox XML format:

```text
<ROUTE_BUCKET>__<LOT>-<WAFER3>.XML
```

Examples:

```text
BACK_PRE__62546-481-190.XML
BACK_POST__62546-481-010.XML
FRONT_PRE__62546-481-050.XML
FRONT_POST__62546-481-010.XML
```

Known route buckets:

```text
BACK_PRE
BACK_POST
FRONT_PRE
FRONT_POST
```

Mover regex observed in script snippets:

```text
^(?<bucket>BACK_PRE|BACK_POST|FRONT_PRE|FRONT_POST)__(?<lot>\d{5,6}-\d{3})-(?<wafer>\d{3})\.XML$
```

If an XML file does not match the route-prefix naming rule, the mover sends it to:

```text
Move_Error\UnknownRoute
```

Observed sidecar file:

```text
<LOT>-<WAFER3>_bin_legend.csv
```

Example:

```text
C:\ArgosAuto\Working\62546-481-010_bin_legend.csv
C:\ArgosAuto\Outbox\62546-481-190_bin_legend.csv
```

---

## 6. XML mover destination folders

Known destination map from `C:\ArgosAuto\Move-ArgosXml-To-ShermanData.ps1`:

```powershell
BACK_PRE   = "\\shm-cifs\department\ShermanData\AUTO_PROCESSING\Fab_Data\Zone6\Inspection\ARGOS_AVI_BACK_PRE\6-11-ARGOS-01"
BACK_POST  = "\\shm-cifs\department\ShermanData\AUTO_PROCESSING\Fab_Data\Zone6\Inspection\ARGOS_AVI_BACK_POST\6-11-ARGOS-01"
FRONT_PRE  = "\\shm-cifs\department\ShermanData\AUTO_PROCESSING\Fab_Data\Zone6\Inspection\ARGOS_AVI_FRONT_PRE\6-11-ARGOS-01"
FRONT_POST = "\\shm-cifs\department\ShermanData\AUTO_PROCESSING\Fab_Data\Zone6\Inspection\ARGOS_AVI_FRONT_POST\6-11-ARGOS-01"
```

Mover behavior observed:

```text
1. Verify source path reachable.
2. Verify all destination roots reachable.
3. Find *.XML in SourceRoot.
4. Parse route bucket from filename.
5. Copy XML to matching ShermanData destination.
6. Move source XML to Sent.
7. If destination already has file, leave source in Outbox and log WAIT.
8. If filename lacks valid route prefix, move to Move_Error\UnknownRoute.
```

Known mover issue:

```text
ERROR: Destination not reachable for FRONT_POST:
\\shm-cifs\department\ShermanData\AUTO_PROCESSING\Fab_Data\Zone6\Inspection\ARGOS_AVI_FRONT_POST\6-11-ARGOS-01
```

This error appeared repeatedly in one log window, then later logs resumed with “No XML files found in Outbox.” Treat FRONT_POST reachability as something to verify during deployment.

---

## 7. Observed lot/slot to container-wafer mapping

The converter logs show that physical slots do not always map one-to-one to the same numeric wafer index. The converter writes a wafer/container ID such as `62546-481-010`, `62546-481-020`, etc.

### PRE examples from observed logs

```text
Physical Slot03 -> 62546-481-010
Physical Slot04 -> 62546-481-020
Physical Slot05 -> 62546-481-030
Physical Slot06 -> 62546-481-040
Physical Slot07 -> 62546-481-050
Physical Slot08 -> 62546-481-060
Physical Slot09 -> 62546-481-070
Physical Slot10 -> 62546-481-080
Physical Slot11 -> 62546-481-090
Physical Slot12 -> 62546-481-100
Physical Slot13 -> 62546-481-110
Physical Slot14 -> 62546-481-120
Physical Slot15 -> 62546-481-130
Physical Slot16 -> 62546-481-140
Physical Slot17 -> 62546-481-150
Physical Slot18 -> 62546-481-160
```

### POST examples from observed logs

```text
Physical Slot03 -> 62546-481-010
Physical Slot04 -> 62546-481-020
Physical Slot12 -> 62546-481-040
Physical Slot13 -> 62546-481-050
Physical Slot16 -> 62546-481-060
Physical Slot19 -> 62546-481-070
Physical Slot20 -> 62546-481-080
Physical Slot21 -> 62546-481-090
Physical Slot23 -> 62546-481-110
Physical Slot24 -> 62546-481-120
Physical Slot25 -> 62546-481-130
```

Important: these are observed examples from logs, not necessarily the authoritative mapping table. Codex should locate and preserve the actual converter map source before changing logic.

Likely authoritative sources to inventory locally:

```text
C:\ArgosAuto\Run-ArgosKlaAutoProcessor.ps1
C:\ArgosAuto\*.ps1
C:\ArgosAuto\Config\*
C:\ArgosAuto\Working\*_bin_legend.csv
C:\ArgosAuto\Working\*_UNMAPPED_KLA_CLASSES.csv
C:\ArgosAuto\Logs\*
```

---

## 8. Existing image-inspection / defect-review lane

### Current stable surface baseline

Current good surface review/display baseline:

```text
V2CT RenderOnly CleanHeatmapContour
Argos_DefectReview_V2CT_RenderOnly_CleanHeatmapContour_tool_package.zip
```

Expected output pattern:

```text
D:\ArgosImageAI\DefectReview\V2CT_RENDER_ONLY_CLEAN_HEATMAP_CONTOUR_<timestamp>
GUI: http://127.0.0.1:9444/
```

V2CT does not rerun detection; it regenerates display artifacts from safe V2CR/V2CT surface rows.

V2CT regenerated display columns:

```text
DisplayCleanCropFile
DisplayHeatmapCropFile
DisplayRejectContourCropFile
MaskCropFile
```

Display meanings:

```text
Clean image: no baked boxes or labels.
Evidence heatmap: field evidence in the crop; not final reject geometry.
Reject contour: selected component contour/visible marker; not wafer-edge contouring.
Tiny specs: visible halo/marker for review; true geometry remains tiny.
```

### Surface lane guardrails

```text
V2CT surface baseline is locked.
Do not change BF/DF surface detector thresholds without explicit request.
Do not let surface grouped/tile rows create edge classes.
Do not train from automatic grouped/tile labels.
Do not use old baked preview images as active heatmap/contour views.
```

Surface rows must never auto-create:

```text
EdgeChipout
ChipoutSmall
BevelDamage
PhysicalDamage
```

### Current edge/chipout/bevel lane

Current locked edge truth:

```text
V2CX EdgeTruthLocked Postprocess
Argos_DefectReview_V2CX_EdgeTruthLocked_Postprocess_tool_package.zip
```

V2CX truth summary:

```text
80 total V2CV edge-audit rows
74 suppressed false/artifact rows
6 positive/action rows
```

Positive/action rows:

```text
Slot01 MAN010 -> EdgeChipoutCandidate
  real huge chipout, BadContour, edge followed into chipout

Slot01 MAN016 -> EdgeChipoutCandidate
  real huge chipout, BadContour, edge followed into chipout

Slot03 MAN040 -> EdgeChipout
Slot03 MAN041 -> EdgeChipout
Slot03 MAN042 -> EdgeChipout
  small real chipouts with usable enough BF geometry

Slot17 MAN053 -> BevelDamageCandidate
  DF-supported edge/bevel damage, bad/no usable BF contour
```

Current next algorithm target:

```text
V2DC Edge Residual Spike Audit
```

V2DC goal:

```text
- global wafer-circle expected edge
- local offset correction only for alignment
- tolerance band for normal drift
- short local residual chipout islands
- no long edge strips
- bounded gap fill only for Slot01 BadContour huge chipouts
- Slot03 small chipouts as local islands
- Slot17 MAN053 DF-only BevelDamageCandidate / no BF contour borrowing
- no training
- no XML geometry
- no surface changes
```

---

## 9. Production XML-fast direction for AI defects

Do not wait for full GUI/debug rendering in production. Future production AI XML export should have a fast mode:

```text
detect -> classify/filter -> contours/masks -> XML
```

Avoid by default in production:

```text
per-card crops
full GUI generation
full-wafer dashboard JPGs
heatmap JPGs
debug contact sheets
```

Future flags / mode concept:

```text
--xml-fast
--no-gui
--no-crops
--no-dashboard
--write-slot-xml-immediately
--debug-on-fail-only
```

Do not implement XML-fast until detection/edge validation is stable.

---

## 10. Future recipe/reporting threshold layer

The consolidated future GUI/dashboard plan is maintained in
`ARGOS_GUI_DASHBOARD_ROADMAP.md`. That roadmap also covers review
visualization, map alignment, downstream failure/process/probe analytics, and
PowerPoint presentation export. It is a planning record, not implementation
approval.

Current principle:

```text
Detection keeps everything.
Reporting/export rules decide what is reportable.
```

Future threshold/reporting controls should be separated from detection and should support:

```text
class
channel
zone
detector/engine
product
route
step
risk mode
```

Use physical units:

```text
microns
microns squared
equivalent diameter microns
length microns
width microns
distance from edge microns
```

Future GUI feature:

```text
Recipe Simulator:
  detected count
  reportable count
  suppressed count
  suppression reasons
```

Important rule:

```text
Do not suppress tiny particles before grouping,
because dense fields of tiny particles can become real residue/contam clusters.
```

---

## 11. Future frontside scribe reader for naming

Methodology resource:

```text
work/SCRIBE_REVIEW_ONLY/SEMI_M12_SCRIBE_VALIDATION_METHOD.md
```

Local source standard:

```text
SEMI M12-0998E SPECIFICATION FOR SERIAL ALPHANUMERIC MARKING (1).pdf
```

Potential future module: frontside laser-scribe OCR/template reader for export naming.

Frontside notch-first localization and the compact identity-card contract are
defined in:

```text
work/SCRIBE_REVIEW_ONLY/FRONTSIDE_NOTCH_AND_SCRIBE_IDENTITY_METHOD.md
```

Planned approach:

```text
1. Find scribe street/frontside region.
2. Deskew/rotate crop.
3. Threshold dark laser marks.
4. Segment dot-matrix characters.
5. Use constrained OCR/template matching and retain per-character candidates/scores.
6. Preserve the independently highest-scoring image string.
7. Apply SEMI M12 whole-string validation to eligible 12-character scribes.
8. Search only bounded image-supported alternatives when the image-first string fails.
9. Require confirmation before using a reranked, ambiguous, low-confidence, or conflicting read.
10. Validate against MES/KLA/slot metadata.
11. Create a tight, baseline-deskewed crop around the observed 12-character
    bounds rather than a fixed-angle, fixed-size wafer crop.
```

Naming priority:

```text
1. KLA/Argos metadata wafer ID
2. MES wafer list / lot-slot map
3. frontside scribe OCR
4. manual fallback
```

Rule:

```text
Never silently use low-confidence OCR.
Never silently substitute characters merely to satisfy the checksum.
The checksum may validate or boundedly rerank image-supported candidates,
but the image-first string and every changed position must remain visible.
The scribe identity card is not a defect, yield item, KLA bin, or XML bin.
Frontside/backside coordinate transfer must preserve the explicit acquisition
mirror state; the current data uses `flipImageHorizontal=false` on frontside
and `flipImageHorizontal=true` on backside.
```

---

## 12. Recommended Codex inventory tasks

Codex should create/maintain these files in the workspace root:

```text
INVENTORY_ARGOS_EDGE_LAB.md
AGENTS.md
TODO_V2DC_EDGE_RESIDUAL_SPIKE.md
DO_NOT_USE_OR_TRAIN.md
ARGOS_MAP_CONVERSION_AND_XML_INFRASTRUCTURE.md
ARGOS_GUI_DASHBOARD_ROADMAP.md
```

Read-only inventory first. Do not modify production automation until the inventory is complete.

Useful inventory commands for Codex to run locally in PowerShell:

```powershell
Get-ChildItem -LiteralPath C:\ArgosAuto -Recurse -File |
  Select-Object FullName, Length, LastWriteTime |
  Sort-Object FullName

Get-ScheduledTask | Where-Object { $_.TaskName -like '*Argos*' } |
  Select-Object TaskName, State

Get-ChildItem -LiteralPath C:\ArgosAuto\Logs -File |
  Select-Object FullName, Length, LastWriteTime

Select-String -Path C:\ArgosAuto\*.ps1 -Pattern 'SourceRoot|Destinations|WAFER MAP|template-key|Outbox|Working|UNMAPPED|bin_legend' -Context 2,2
```

Use read-only archive listing for ZIPs. Do not extract archives over existing folders.

---

## 13. Critical do-not-break rules

```text
Do not modify, overwrite, delete, extract over, package, execute, or run existing project files during migration inventory.
Do not rerun full inspections unless explicitly requested.
Do not train from automatic grouped/tile labels.
Do not train from EdgeRescueSeed / EdgeAuditCandidate / review-only rows.
Do not XML-export audit candidates automatically.
Do not let surface rows create edge/chipout/bevel classes.
Do not use broad radial holder/notch sector masks.
Do not use nearest-neighbor chain grouping that creates spiral/star artifacts.
Do not use old baked preview images as active heatmap/contour views.
Do not use local damaged edge as the expected edge for chipout.
Do not borrow BF contour for Slot17 MAN053 / DF-supported bevel damage.
```

---

## 14. Source/evidence notes

This file is based on browser-chat project records and uploaded evidence snippets, especially:

```text
Argos AI Feedback.txt
Converter device setup.txt
Pasted text snippets from 2026-07-08 converter/mover/staging logs
V2BK emergency localStorage feedback JSON
```

High-confidence facts:

```text
C:\ArgosAuto folder structure and logs exist in evidence.
Move-ArgosXml-To-ShermanData.ps1 source/sent/error/destination routes are in evidence.
Outbox route naming with BACK_PRE/BACK_POST/FRONT_PRE/FRONT_POST is in evidence.
Converter writes Working XML, SubstrateId/Wafer, bin legend CSV, and holds unmapped KLA classes.
V2CT surface baseline and V2CX edge truth are documented in Argos AI Feedback.txt.
```

Facts to verify locally before production changes:

```text
Exact current versions of all PS1 scripts.
Exact authoritative slot -> wafer mapping source.
Exact currently enabled scheduled tasks and triggers.
Exact production destination availability.
Exact KLA class mapping tables/templates for product 3164 and other products.
```
