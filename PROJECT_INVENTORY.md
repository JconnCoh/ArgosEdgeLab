# Argos Backside Wafer Defect Detection — Approval Inventory

Inventory date: 2026-07-24  
Workspace: `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab`  
Status: **inventory complete; V2DC implementation not approved**

The full evidence record is in `INVENTORY_ARGOS_EDGE_LAB.md`.

## Inventory result

The handoff archive was inspected without extraction or execution. It resolves the missing continuation and supplies V2CT/V2CX documentation plus V2DB/V2DC source candidates.

No existing source package, extracted source tree, archive, image, CSV, XML, or machine workflow was changed or executed. No training, detection, GUI server, production XML, full-lot run, or packaging occurred.

## Authoritative local evidence

1. V2CT lock semantics:
   - `Argos AI Feedback.txt` inside `ARGOS_CODEX_HANDOFF_ARTIFACTS.zip`;
   - `Argos_V2CT_render_only_notes.txt`;
   - `Argos_DefectReview_V2CT_RenderOnly_CleanHeatmapContour_tool_package.zip`.

   Together with `Argos_V2CT_sample_V2CO_G1440_fixed.jpg`, these are the approved canonical V2CT locked logical/package baseline. No extracted V2CT output folder was found, and none is required for the targeted staging gate.

2. V2CX edge truth:
   - `V2CX_GUI_BUTTON_feedback_pack_20260724_110500.zip`;
   - `Argos_V2CX_edge_truth_analysis_report.txt`;
   - root V2CX postprocessor package.

   The six human decisions are the current local edge-truth authority. All remain review-only and XML-ineligible.

3. Complete V2CV review evidence:
   - `V2CV_DF_EDGE_BEVEL_OUTWARD_AUDIT_20260724_093331.zip`;
   - `V2CV_GUI_BUTTON_feedback_pack_20260724_101435.zip`.

   The complete feedback pack supplies review crops. `Slot1Slot3Slot17.zip` now supplies the approved full-size working BF/DF inputs for Slot01, Slot03, and Slot17.

4. V2DB/V2DC lineage:
   - nested V2DB gap-fill package;
   - nested V2DC residual-spike package.

   These are supplied source candidates only. They have not been extracted, run, modified, or approved.

## V2CX truth decisions

- Slot01 `MAN010` Darkfield: real edge chipout, bad contour.
- Slot01 `MAN016` Brightfield: same large edge chipout evidence, bad contour.
- Slot03 `MAN040`, `MAN041`, and `MAN042` Brightfield: small local chipout islands.
- Slot17 `MAN053` Darkfield: `BevelDamageCandidate`; no borrowed BF contour.
- Remaining 74 edge rows: suppressed false/artifact evidence.

## Newly resolved inputs

- `latest_circle_fit_results.csv`: authoritative same-lot geometry seed; 3 Slot01/03/17 rows; circle confidence about 0.621.
- `edge_intrusion_segments_v6.csv`: authoritative same-lot AutoGeometryBootstrap seed; 18 rows.
- `notch_summary_v6.csv`: authoritative same-lot bootstrap/notch seed; 3 rows.
- `Slot1Slot3Slot17.zip`: all six targeted backside BF/DF `resizedImage.bmp` working images, acquisition JSON, metadata PNGs, and thumbnails.
- `BareBackside.zip`: complete additional-slot folder archive for Slot02, Slot13–Slot16, and Slot18–Slot25. It contains 26 relevant full-resolution backside BF/DF `resizedImage.bmp` files (`14411 × 10995`, 24-bit), plus 26 frontside BMPs, JSON, metadata, and thumbnails. Its SHA-256 is `AA201E1885C3559AFE40D67CDC5B3D7A3A346B1AB46C33354270C4BAF85A39EA`.
- Image metadata consistently records `flipImageHorizontal=true`.

The bootstrap/prior labels are accepted provenance facts and are not blockers. The CSVs remain immutable.

Optional provenance still not present:

- a full extracted V2CT output folder;
- full generated V2CX 80-row truth output and 74-row suppression output;
- historical V2DB/V2DC run-output folders.

None of these optional outputs blocks the approved isolated staging activity.

## Duplicate disposition

- Root V2CT/V2CX tool packages and V2CV/V2CW/V2CX feedback packs are byte-identical to their handoff copies. Prefer the root copies for direct reference and retain the handoff as immutable provenance.
- `POST2_darkzone_curve_samples.zip` and `POST2_darkzone_curve_samples (1).zip` are exact duplicates.
- The five already-extracted historical folders mirror corresponding ZIPs.
- V2CV `095411` is a visible subset of V2CV `101435`.
- V2CW and V2CX reuse media but differ semantically and are not duplicate authorities.

Nothing was deleted, moved, renamed, or deduplicated.

## Current approval boundary

Approved and completed:

- create `work\V2DC_edge_residual_spike`;
- create `scratch\V2DC_edge_residual_spike_staging`;
- copy the immutable input archive and geometry CSVs into scratch;
- extract only the six backside BF/DF sample sets from the copied archive.
- create a thumbnail-only, no-detection screening set for the 13 additional Bare slots in `BareBackside.zip`.

Still not approved:

- full V2DC detector implementation;
- detector-pipeline execution;
- GUI servers;
- production XML;
- full-lot execution;
- packaging or release.

Any later harness must remain targeted, edge-only, review-only, training-disabled, XML-disabled, and packaging-disabled. Contact sheets must precede any build/package consideration.

The supplied geometry CSVs cover only Slot01, Slot03, and Slot17. The additional full-resolution images are valid source evidence, but they do not yet have approved slot-specific geometry or human edge-truth locations. Do not run the V2DC residual/bevel harness across those slots as a full-lot or unlabeled scan.

A bounded full-resolution human-review spot check was subsequently created for Slot13, Slot20, and Slot25:

`work\V2DC_edge_residual_spike\outputs\review_only\BARE_FULLRES_EDGE_VISUAL_REVIEW_SLOTS132025_20260725_000354Z`

It contains eight paired BF/DF native-resolution sectors per slot and no detector output. The sectors are representative samples, not continuous 360° coverage. No new truth or confirmed-negative decision was created.

## Targeted contact-sheet result

The approved isolated Bare-backside harness was created and run against only the six V2CX truth targets.

Current review output:

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_BARE_CONTACT_SHEETS_20260724_233524Z`

- Slot01 `MAN010`: one human-expanded bounded island, maximum residual 67 px.
- Slot01 `MAN016`: one bounded island, maximum residual 160 px. The former 110 px fixed inward-search cap was replaced by a 216 px review-window-derived search. Seven approximate review-only control points replace the radial jump with one contiguous curved left wall without including the separate rounded contact feature.
- Slot03 `MAN040`: five separate shallow local islands plus one tiny review-guided outline across the user-confirmed rough edge span, maximum residual 6 px; no long strip fill and no global threshold reduction.
- Slot03 `MAN041`: one short local island, maximum residual 5 px.
- Slot03 `MAN042`: five short local islands, maximum residual 10 px.
- Slot17 `MAN053`: zero radial chipout contours and two thin yellow DF-support outlines; no borrowed BF contour.

The run generated no XML, training data, detector output, GUI, full-lot result, archive, or package.

Pink user markup is recorded as approximate review guidance, not pixel-exact geometry or training truth. Review-guided micro outlines and non-radial closure points are explicitly not autonomous detector results. The revised harness requires a complete dark radial corridor from the candidate boundary through the expected edge and at least 32 px into outside-wafer space. The inward search is derived from the bounded review window instead of a fixed chipout-depth cap, so interior surface particles, contamination, and residue separated from outside space by intact wafer remain ineligible.

## Negative-control and DF-bevel validation

The approved representative negative-control run is:

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_BARE_NEGATIVE_CONTROLS_20260724_233451Z`

All nine selected controls produced zero accepted chipout candidates. The set covers notch, holder/contact, residue, smooth drift, and an unexplained false edge row from the 74 V2CV human-reviewed false rows. Four local candidates were suppressed by exact same-lot notch/holder prior overlap; no broad sector mask was used.

The approved DF-only bevel run is:

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_DF_BEVEL_CONTROLS_20260724_234115Z`

Slot17 `MAN053` produced two DF-only bevel-band disruptions with arc lengths 31.6 px and 25.6 px. All eight false DF controls produced zero accepted candidates. No Brightfield contour was borrowed.
