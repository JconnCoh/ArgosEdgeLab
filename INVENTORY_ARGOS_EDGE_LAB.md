# ArgosEdgeLab Inventory

Inventory date: 2026-07-24  
Workspace: `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab`  
Phase: **migration/inventory plus approved isolated input staging and targeted review**

## Inspection boundary

No existing project source, original archive, original image, original CSV, XML, converter, or production workflow was modified or executed. Approved immutable copies were staged. Targeted Slot01/03/17 files were extracted from a copied archive, and additional-slot thumbnail/JSON inventory artifacts were copied from `BareBackside.zip` into a separate new scratch directory. Original archives remained untouched.

The inventory used only:

- filesystem listings;
- ZIP central-directory and nested-ZIP listing inspection;
- read-only text, Markdown, CSV, JSON, manifest, and source inspection;
- SHA-256 hashing and byte comparisons.

No original archive was extracted in place. No detection, GUI server, training, XML generation, full-lot run, or packaging occurred.

Current workspace census:

- 41 root ZIP archives totaling 10,606,622,780 bytes;
- 5 already-extracted historical/reference directories;
- 52 root files;
- new isolated `work` and `scratch` directories.

## Governing handoff

The handoff is:

| Artifact | Path | Bytes | Modified | SHA-256 | Role |
|---|---|---:|---|---|---|
| Codex handoff | `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab\ARGOS_CODEX_HANDOFF_ARTIFACTS.zip` | 7,116,292 | 2026-07-24 21:05:28 UTC | `862B190B51A812EF880F271AF7D58B1188153BA91DA4F950C9925F816CB21416` | Governing continuation, V2CT/V2CX notes and packages, V2DB/V2DC candidates, feedback-pack copies, and previews. |
| Map/XML notes | `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab\ARGOS_MAP_CONVERSION_AND_XML_INFRASTRUCTURE.md` | 16,059 | 2026-07-24 20:35:30 UTC | — | Descriptive map/XML infrastructure record. It is not a deployed-state verification. |

The following handoff members were read completely:

- `Argos AI Feedback.txt` — governing technical brief;
- `README_CODEX_HANDOFF.md` — attached artifact roles;
- `Argos_V2CT_render_only_notes.txt`;
- `Argos_V2CX_edge_truth_analysis_report.txt`;
- V2DB and V2DC package READMEs.

## Requested artifact map

| Requested item | Best available candidate | Status and authority |
|---|---|---|
| V2CT stable surface baseline | Root `Argos_DefectReview_V2CT_RenderOnly_CleanHeatmapContour_tool_package.zip`; handoff notes, sample, and continuation brief. | **Canonical locked logical/package baseline.** No extracted V2CT output folder exists; this is recorded and is not a blocker. |
| V2CX truth-lock output | `V2CX_GUI_BUTTON_feedback_pack_20260724_110500.zip`, root V2CX postprocessor package, and handoff analysis report. | **Six human truth decisions are authoritative locally.** The generated full 80-row V2CX output directory/tables are not present. |
| V2DB edge work | Nested `Argos_DefectReview_V2DB_EdgeGapFillClamp_Slots010317_tool_package.zip`. | **Supplied source candidate.** Inspected statically; no run output is present. |
| V2DC residual-spike work | Nested `Argos_DefectReview_V2DC_EdgeResidualSpike_Slots010317_tool_package.zip`. | **Supplied implementation candidate, not approved.** Inspected statically; not extracted or executed. Only one preview accompanies it. |
| Slot01/03/17 BF/DF samples | `Slot1Slot3Slot17.zip`. | **Sufficient full-size working set:** six backside BF/DF `resizedImage.bmp` files plus metadata for Slot01/03/17. |
| Additional Bare BF/DF samples | `BareBackside.zip`. | **Complete additional-slot folder archive:** 26 full-resolution backside BF/DF working BMPs for Slot02, Slot13–Slot16, and Slot18–Slot25. Present, but not covered by the three-slot geometry CSVs or V2CX truth locations. |
| `latest_circle_fit_results.csv` | Root CSV plus byte-identical scratch copy. | **Authoritative same-lot geometry seed.** Three slot rows; confidence about 0.621 accepted. |
| `edge_intrusion_segments_v6.csv` | Root CSV plus byte-identical scratch copy. | **Authoritative same-lot AutoGeometryBootstrap seed.** Eighteen holder/notch prior rows. |
| `notch_summary_v6.csv` | Root CSV plus byte-identical scratch copy. | **Authoritative same-lot notch seed.** Three `BOOTSTRAP_PRIOR` rows. |
| V2CV feedback | `V2CV_GUI_BUTTON_feedback_pack_20260724_101435.zip`. | **Authoritative complete V2CV feedback pack.** |
| V2CW feedback | `V2CW_GUI_BUTTON_feedback_pack_20260724_104526.zip`. | **Authoritative feedback-applied provenance.** |
| V2CX feedback | `V2CX_GUI_BUTTON_feedback_pack_20260724_110500.zip`. | **Authoritative local edge truth-lock decisions.** |

## Authoritative artifacts

### V2CT behavior lock

Root package:

`C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab\Argos_DefectReview_V2CT_RenderOnly_CleanHeatmapContour_tool_package.zip`

- Size: 100,544 bytes
- Modified: 2026-07-24 13:07:11 UTC
- SHA-256: `47131663566791176473FD7E2F2A287C776B36609FD2D6891BC6607BDFADE90B`
- Role: render-only clean heatmap/contour tooling.
- Does not alter detection, thresholds, edge decisions, training, or XML.
- Reads the prior surface output and regenerates presentation artifacts.

The same package inside the handoff is byte-identical to the root copy. Together with the handoff notes, sample, and governing brief, it is the canonical V2CT locked logical/package baseline. No extracted V2CT run folder was found in the workspace. Do not substitute V2CR/V2CU/V2CW/V2CY.

### V2CX edge truth lock

Primary decision pack:

`C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab\V2CX_GUI_BUTTON_feedback_pack_20260724_110500.zip`

- Size: 309,417 bytes
- Modified: 2026-07-24 16:05:00 UTC
- SHA-256: `DA4A01D766E5EC200ECF3B479784A3CCC197F80A3D6BCF347332A7AA7A21DEB8`
- Six review-only truth rows.
- All six retain `XMLGeometryEligible=0`.

Positive/action rows:

| Slot | Defect/channel | Decision |
|---|---|---|
| Slot01 | `MAN010` Darkfield | Real edge chipout; contour is bad. |
| Slot01 | `MAN016` Brightfield | Same large chipout evidence; contour is bad. |
| Slot03 | `MAN040` Brightfield | Small local edge chipout island. |
| Slot03 | `MAN041` Brightfield | Small local edge chipout island. |
| Slot03 | `MAN042` Brightfield | Small local edge chipout island. |
| Slot17 | `MAN053` Darkfield | DF-supported `BevelDamageCandidate`; no usable/borrowed BF contour. |

The handoff analysis states that the other 74 edge rows are suppressed false/artifact rows. The generated files named by the V2CX postprocessor—such as the complete truth table and 74-row suppression CSV—are not present as actual outputs.

Supporting V2CX tool:

`C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab\Argos_DefectReview_V2CX_EdgeTruthLocked_Postprocess_tool_package.zip`

- Size: 30,091 bytes
- Modified: 2026-07-24 15:59:28 UTC
- SHA-256: `80F2740BB2A83A1F4954E7D4EAA99903257099D9F5915464C35F9FAEBDBA19CE`

Its matching handoff copy is byte-identical. It has not been run during inventory.

### V2DB and V2DC supplied packages

Both packages exist only as nested members of `ARGOS_CODEX_HANDOFF_ARTIFACTS.zip`.

| Nested package | Bytes | Handoff member timestamp | SHA-256 | Disposition |
|---|---:|---|---|---|
| `Argos_DefectReview_V2DB_EdgeGapFillClamp_Slots010317_tool_package.zip` | 55,743 | 2026-07-24 20:39:52 -05:00 | `6B33B65B92F9BA178EE4D30497CB132764235953C088C857DA0F217CB5778C78` | Historical closest approach; gap fill is too aggressive. Reference-only. |
| `Argos_DefectReview_V2DC_EdgeResidualSpike_Slots010317_tool_package.zip` | 163,610 | 2026-07-24 20:39:52 -05:00 | `0DD631012815D0139A62EE92BE5851FB3E87EF39F3A6F6BB8CAF9A8D750C079E` | Existing residual-spike implementation candidate. Do not extract, execute, or modify before approval. |

Static inspection shows that the V2DC candidate implements concepts named in the brief: global circle, local alignment offset, drift residual, tolerance, short islands, bounded Slot01 fill, Slot03 focused islands, and Slot17 DF-only handling. It also marks postprocessed outputs as training- and XML-ineligible. This is a compatibility observation, not approval.

### V2CV/V2CW/V2CX feedback lineage

| Archive | Bytes | Modified UTC | SHA-256 | Authority |
|---|---:|---|---|---|
| `V2CV_DF_EDGE_BEVEL_OUTWARD_AUDIT_20260724_093331.zip` | 4,793,463 | 2026-07-24 14:55:27 | `2FD2F565E593BD811D9FA0BDCFA5A7595D72B0F565A70A61F19A52EC0536B5CF` | Complete V2CV audit output. |
| `V2CV_GUI_BUTTON_feedback_pack_20260724_101435.zip` | 6,081,856 | 2026-07-24 15:14:38 | `3DD858E6B890DCD3380F8D5BB696BFB02966E56F440945FF35238B76B01393D6` | Complete 80-row/320-image V2CV feedback set and best six-combination crop set. |
| `V2CW_GUI_BUTTON_feedback_pack_20260724_104526.zip` | 309,534 | 2026-07-24 15:45:26 | `A9548E08004D4E1192CC53704C3DEA90264B65A7C8B0E56E5A2D2D72A53A2211` | Feedback-applied provenance. |
| `V2CX_GUI_BUTTON_feedback_pack_20260724_110500.zip` | 309,417 | 2026-07-24 16:05:00 | `DA4A01D766E5EC200ECF3B479784A3CCC197F80A3D6BCF347332A7AA7A21DEB8` | Current local edge truth-lock decisions. |

The handoff copies of these three feedback packs are byte-identical to the root copies.

## Geometry CSVs

The intended same-lot geometry seeds are now present and accepted:

| File | Rows | SHA-256 | Known facts |
|---|---:|---|---|
| `latest_circle_fit_results.csv` | 3 | `5C8DD583D29F0B6B3E74D9157791788D17C893871C11ABBABC995F95B8C0336C` | Slot01/03/17, `14411 × 10995`, confidence 0.6213–0.6214. |
| `edge_intrusion_segments_v6.csv` | 18 | `F4EDCEB61EDF3A2167738EA3C2079C46E751687BD8FBE5F255F6F2CE13A3BC29` | Five `HOLDER_FIXED_PRIOR_MATCH` and one `EXPECTED_NOTCH_PRIOR_MATCH` row per slot. |
| `notch_summary_v6.csv` | 3 | `7B82B57FA450B72FB00B83FF85AD7DBF323A0A0D482F58001125D3EED38F00DF` | Selected notch angle 90°, confidence 0.800, `BOOTSTRAP_PRIOR`. |

The bootstrap/prior markers are accepted provenance, not deficiencies. These files are immutable and may be copied only into scratch.

## Slot01/Slot03/Slot17 samples

`Slot1Slot3Slot17.zip` is the authoritative sufficient image source for the targeted harness.

- Size: 1,676,229,164 bytes
- SHA-256: `B19737163B84B8EAFEB6E081EA65EC325FBC92748BC5B2BC2620F5020C52EDA2`
- 60 files total; 12 BMP, 12 JSON, and 36 PNG.
- Six relevant backside BF/DF BMPs, each valid 24-bit `14411 × 10995`.
- Six corresponding acquisition JSON files record `flipImageHorizontal=true`, `BACKSIDE`, and module `PM2`.
- The images are full-size `resizedImage.bmp` working inputs, not sensor RAW.

The V2CV pack remains the complete review-crop source, and V2CX remains the positive/action truth source.

## Additional Bare backside samples

`BareBackside.zip` is a complete folder archive for 13 additional occupied slots:

`Slot02`, `Slot13`, `Slot14`, `Slot15`, `Slot16`, `Slot18`, `Slot19`, `Slot20`, `Slot21`, `Slot22`, `Slot23`, `Slot24`, and `Slot25`.

- Size: 7,246,717,168 bytes.
- SHA-256: `AA201E1885C3559AFE40D67CDC5B3D7A3A346B1AB46C33354270C4BAF85A39EA`.
- 429 ZIP entries; 24,755,596,980 total uncompressed bytes.
- 52 full-resolution 24-bit `14411 × 10995` BMPs: BF/DF and frontside/backside for each slot.
- 26 relevant backside BF/DF full-resolution BMPs, each 475,379,874 bytes.
- 52 JSON files and 156 PNG metadata/thumbnail files.
- All 26 backside acquisition JSON files record `waferSide=BACKSIDE` and `flipImageHorizontal=true`.

Only the 26 backside large thumbnails and their 26 acquisition JSON files were copied into:

`scratch\BareBackside_thumbnail_screen_20260724_235631Z`

The corresponding paired BF/DF thumbnail-only review sheets are:

`work\V2DC_edge_residual_spike\outputs\review_only\BARE_ADDITIONAL_SLOT_THUMBNAIL_SCREEN_20260724_235721Z`

This screen did not run detection or create defect truth. Thumbnail resolution is insufficient for safe micro-chipout/bevel decisions. The existing authoritative geometry CSVs cover only Slot01, Slot03, and Slot17, so the additional full-resolution images must not be passed through the V2DC harness as an unlabeled or full-lot scan.

A bounded full-resolution visual spot check was later staged for three representative slots:

- Slot13: visually clean-control sample;
- Slot20: interior dark-particle separation sample;
- Slot25: higher surface/residue-variation sample.

Six full-resolution backside BMPs were copied into:

`scratch\BareBackside_fullres_review_Slots132025_20260725_000323Z`

Eight paired native-resolution BF/DF sectors per slot were written to:

`work\V2DC_edge_residual_spike\outputs\review_only\BARE_FULLRES_EDGE_VISUAL_REVIEW_SLOTS132025_20260725_000354Z`

This is a representative human-review spot check, not continuous 360° coverage. No detector, new truth, confirmed-negative label, XML, training output, full-lot run, or package was created.

## Map/XML infrastructure inventory

Relevant local evidence:

| Artifact | Bytes | Modified UTC | SHA-256 | What it establishes |
|---|---:|---|---|---|
| `ARGOS_MAP_CONVERSION_AND_XML_INFRASTRUCTURE.md` | 16,059 | 2026-07-24 20:35:30 | — | Documented folder flow, converter behavior, naming, mover behavior, route buckets, shares/IPs, and do-not-break rules. |
| `ArgosAuto_Fix_20260717E.zip` | 29,664 | 2026-07-23 15:24:01 | `F2A6FA403713F11B34A55DF0D68A6F1A92FF4B73FC7B772753E8CE590E3CB0AA` | Contains `Run-ArgosKlaAutoProcessor.ps1` plus staging, watchdog, queue, rescue, and installation scripts. |
| `Argos_KLA_XML_AutoProcessor_Setup.zip` | 44,577,324 | 2026-05-13 19:42:26 | `327F1582E3CE6C17E179C9C823CA751BA2F180E4CA6CDFF99209602741B8BC7C` | Historical setup/tooling/templates; production-sensitive and read-only. |

Still absent from the handoff:

- `Converter device setup.txt`;
- the currently deployed `C:\ArgosAuto\Move-ArgosXml-To-ShermanData.ps1`;
- scheduled-task exports;
- current deployed mappings/configuration/templates;
- representative production mover/converter logs.

No production XML action is authorized.

## Duplicate and overlap findings

Authoritative copies should be selected by role, not by newest timestamp alone.

- The handoff copies of the V2CT and V2CX tool packages are byte-identical to the root copies.
- The handoff copies of the V2CV complete feedback, V2CW, and V2CX feedback packs are byte-identical to the root copies.
- Root copies are preferred for direct inventory reference; the handoff archive remains immutable provenance.
- `POST2_darkzone_curve_samples.zip` and `POST2_darkzone_curve_samples (1).zip` are exact duplicates.
- Each of the five extracted directories is a byte-identical mirror of its matching root ZIP.
- V2CV feedback pack `095411` is a 60-row visible subset of the complete `101435` pack.
- V2CW and V2CX share selected images but have different CSV semantics and are not duplicate authorities.
- V2CY is later diagnostic feedback and does not replace the V2CX truth lock.

Nothing was deleted, moved, renamed, or deduplicated.

## Relevant folders and archive groups

Existing extracted folders are historical/reference mirrors only:

- `Argos_V2BB_EdgeStrip_Contour_TestBench`
- `Argos_V2BC_EdgeStrip_MultiEvidence_TestBench`
- `POST2_chipout_curve_samples`
- `POST2_darkzone_curve_samples`
- `V2BI_local_geometry_from_feedback_examples`

Relevant archive groups:

- Locked-surface behavior: V2CT render-only tool and handoff notes.
- Edge truth: V2CV audit/full feedback, V2CW, V2CX feedback and postprocessor.
- Residual-spike lineage: handoff V2DB and V2DC nested packages.
- Historical surface/edge provenance: three `Argos_FULL_EVIDENCE_20260723_184036_part_*.zip` files.
- Historical debug/test benches: V2BB, V2BC, V2BI, V2CO, V2CP, V2CQ, curve-sample archives.
- Production-sensitive map/XML references: `Argos_KLA_XML_AutoProcessor_Setup.zip`, `ArgosAuto_Fix_20260717E.zip`, machine constants, and the infrastructure document.

All other root archives remain immutable historical evidence. None is authorized as a replacement for V2CT or as training truth.

## Remaining missing or unverified artifacts

There is no remaining artifact blocker for isolated targeted preparation.

Optional provenance:

- full extracted V2CT output folder;
- generated full V2CX 80-row truth output and 74-row suppression output;
- V2DB/V2DC historical run-output folders;
- deployed-state XML infrastructure evidence.

## Approved isolated staging structure

The following minimal trees now exist. No source code or detector output has been placed in them.

```text
ArgosEdgeLab/
  work/
    V2DC_edge_residual_spike/
      src/
      configs/
      tests/
      inputs_read_only/
      outputs/review_only/
      logs/
  scratch/
    V2DC_edge_residual_spike_staging/
      source_archives/
        Slot1Slot3Slot17.zip
      geometry/
      latest_circle_fit_results.csv
      edge_intrusion_segments_v6.csv
      notch_summary_v6.csv
      extracted_samples/
        Slot01/{BrightfieldBacksideWafer,DarkfieldBacksideWafer}/
        Slot03/{BrightfieldBacksideWafer,DarkfieldBacksideWafer}/
        Slot17/{BrightfieldBacksideWafer,DarkfieldBacksideWafer}/
      manifests/
```

The staged archive and geometry copies hash-identically to their originals. Original archives and CSVs remain immutable. Full V2DC detector implementation, existing-detector execution, GUI launch, production XML, full-lot execution, and packaging remain unapproved.

## Targeted Bare contact-sheet run

The separately approved contact-sheet harness produced:

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_BARE_CONTACT_SHEETS_20260724_233524Z`

- 6 individual review PNGs;
- 1 combined overview PNG;
- `contact_sheet_manifest.csv`;
- `run_summary.json`.

Overview SHA-256:

`CA1182F18788F1599D5043E6DA79511DFD504631AAE14FDAED0B377CE62C6B30`

The run is `BARE_BACKSIDE_ONLY`, review-only, `TrainingEligible=0`, and `XMLGeometryEligible=0`. It incorporates thin pink human review guidance, including one tiny MAN040 review outline and seven MAN016 curved-closure control points that are explicitly not autonomous detections. It replaces the fixed inward-depth cap with a bounded review-window-derived search, requires a complete dark corridor through the expected edge into outside-wafer space, and excludes interior surface dark components. It did not execute the existing detector, launch a GUI, write XML, run a full lot, or create a package.

Representative negative-control overview:

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_BARE_NEGATIVE_CONTROLS_20260724_233451Z\V2DC_BARE_NEGATIVE_CONTROL_OVERVIEW.png`

SHA-256: `533A5EAEC41D26048F749B83C233907924DDAD1403396DC783697708DE12B1DF`

DF-only bevel overview:

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_DF_BEVEL_CONTROLS_20260724_234115Z\V2DC_DF_BEVEL_CONTROL_OVERVIEW.png`

SHA-256: `757BEE4C0809CB33491EF4C628F06E0C4A899D48A9365846AFCE436369A93464`

The negative run rejected all nine selected false controls. The bevel run accepted two MAN053 DF disruptions and rejected all eight false DF controls. Both are review-only, training-ineligible, XML-ineligible, and package-free.

BowComp/nitride wafers are a future separate domain and must not be mixed into Bare calibration or evaluation.
