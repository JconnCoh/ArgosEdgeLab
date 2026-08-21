# Argos GUI and Dashboard Roadmap

Status: **future planning record; not implementation approval**

This roadmap consolidates the GUI, dashboard, reporting, alignment, and
production-interface ideas recorded in the browser-chat continuation, the
map/XML infrastructure notes, and the user's review feedback. It does not
change the current V2DC scope or authorize production work.

## Governing roadmap principles

- Keep detection evidence separate from reporting and export policy.
- Preserve source image, detector, channel, wafer, slot, lot, coordinate,
  recipe, software-version, and human-review provenance.
- Make every aggregate result drillable to the underlying detections and
  images.
- Display uncertainty, coverage holds, suppressed counts, and suppression
  reasons rather than silently discarding evidence.
- Never treat a visual enhancement, heatmap, grouped row, or automatic
  correlation as training truth.
- Never present correlation as causation. Show sample sizes, denominators,
  missing-data coverage, confidence, and known confounders.
- Production XML, automatic disposition, training, full-lot execution, and
  deployment remain separately gated.

## 1. Review GUI

Planned review capabilities:

- explicit `CORRECT`, `MISSED_DEFECT`, `FALSE_DETECTION`, `WRONG_CLASS`,
  `INCOMPLETE_COVERAGE`, and `UNSURE` responses instead of ambiguous
  GOOD/BAD wording;
- reliable response controls that work from local `file://` galleries,
  populate the consolidated response continuously, and support both
  copy-text and downloaded JSON/CSV fallbacks;
- consistent close-up crops with zoom and pan;
- raw, locally enhanced, contour, geometry-only, and heatmap/evidence views;
- reliable per-card BF and DF raw/adjusted toggles so a reviewer can expose
  low-visibility evidence without losing the original raw comparison;
- an explicit `DETECTOR INPUT` or `DISPLAY ONLY` badge on every adjusted
  view; an adjustment must never be implied to affect detection when it did
  not;
- raw BF/DF as the default evidence view and at most one shared locally
  normalized full-image detector representation;
- a visible toggle showing what signal the inspection is using;
- low-alpha masks with individual and global show/hide controls so overlays
  never prevent inspection of the underlying pixels;
- adaptive local enhancement for dark/shadowed edge and bevel regions without
  blowing out normally bright regions;
- clear legends for expected edge, observed/search boundary, tolerance band,
  accepted candidates, rejected fragments, and coverage holds;
- side-by-side BF/DF comparison without borrowing BF contour geometry for
  DF-only bevel decisions;
- explicit geometry-quality, feature-quality, and inspectability states;
- one reasonably sized local field-of-view card per physical event, showing
  every detected portion in that FOV and whether child detections are grouped
  into the same physical event;
- a separate full-wafer overview indexed by the same event IDs after local
  events are formed;
- a full-wafer tab whose base layers are the unmodified BF and DF images, not
  enhanced or baked preview images;
- independently toggleable colored heatmaps for accepted reject defects,
  grouped by class;
- a distinct independently toggleable layer for detected/noticed pixels that
  remain unclassified, suppressed, or held, so the user can promote a real
  region with feedback such as `REJECT_THIS_AREA`;
- a separate coverage-hold layer that is never confused with Normal or with
  an accepted defect;
- bidirectional links between every full-wafer heatmap region and its local
  event card.

Enhancement is for visualization and review unless a separately validated
detector explicitly consumes it.

The useful historical ChatGPT review pattern is retained: large local BF/DF
evidence, transparent defect mask, explicit response, optional note, and one
consolidated response block. Its known failures—broken buttons, ambiguous
GOOD/BAD semantics, crops that were too zoomed out, missing overlay toggles,
and copy-response fields that did not update—are acceptance-test failures for
the replacement.

## 1A. Dual-pass acquisition coverage

Potential Bare acquisition workflow for fixed dark/shadowed edge sectors:

- acquire a second scan only with a validated change in wafer-to-illumination
  relationship, such as intentional wafer rotation or an alternate
  lighting/exposure setting;
- estimate circle, translation, rotation, and notch evidence independently
  for each pass;
- transform both passes into the same wafer coordinate frame;
- choose the usable pass per angular sector using a predetermined DF
  transition-support and coverage-quality rule, not the presence or absence
  of detected defects;
- keep the original pass identity and source pixels for every reported
  candidate;
- do not average contours or borrow geometry across passes;
- if both passes are unusable, preserve an inspection hold.

Repeating an identical scan at an identical orientation is not assumed to
improve coverage. This is a future acquisition-validation item, not approval
to run the tool or fuse production inspections.

## 2. Recipe simulator and reporting controls

Detection should retain evidence. A separate recipe/reporting layer should
decide what is reportable.

Planned controls include:

- class;
- channel;
- zone;
- detector/engine;
- product;
- route;
- process step;
- risk mode;
- physical thresholds in microns, square microns, equivalent diameter,
  length, width, and distance from edge.

The simulator should show:

- detected count;
- reportable count;
- suppressed count;
- suppression reasons;
- before/after wafer-map and defect-list comparisons.

Tiny particles must not be removed before grouping because a dense field of
small particles can form meaningful residue or contamination evidence.

## 2A. Detector-engine adjustment lab

The user must be able to tune each detector engine independently without
editing source code. Planned controls include, where applicable:

- minimum and maximum event area;
- minimum length, width, equivalent diameter, angular span, and radial depth;
- raw contrast/sensitivity threshold with both absolute value and clear
  increase/decrease controls;
- BF and DF corroboration requirements;
- continuity, connected-component, bounded-gap, and parent-event grouping
  limits;
- edge/surface zone eligibility limits;
- confidence and inspection-hold thresholds;
- class-specific suppression and reporting thresholds.

The adjustment UI must provide:

- numeric entry as well as sliders;
- documented units and safe bounds;
- per-engine reset to the frozen baseline;
- named recipe/profile save and compare;
- before/after counts, masks, local events, and full-wafer diff views;
- the exact config, engine version, source-image hashes, and config hash for
  every evaluation;
- timestamped refusal-on-overwrite outputs.

Detector tuning and reporting policy remain separate. A threshold experiment
must not silently become a production recipe, alter another engine, create
training truth, or make XML geometry eligible. Promotion requires a frozen
baseline regression and separately approved transfer gate.

## 3. Map alignment and coordinate workflow

Planned map capabilities:

- import an XML textmap directly;
- qualify frontside wafer center, radius, and notch from each wafer's own
  native BF/DF boundary evidence;
- align its die grid to the inspected frontside;
- transfer the validated wafer transform to backside inspection coordinates;
- estimate translation and rotation per wafer rather than assuming a fixed
  notch angle;
- preserve `flipImageHorizontal` and other acquisition transforms;
- use notch evidence as one alignment input while retaining explicit
  notch-versus-chipout ambiguity;
- preserve the explicit frontside/backside mirror state; current acquisition
  metadata records `flipImageHorizontal=false` for frontside and
  `flipImageHorizontal=true` for backside;
- validate die-grid phase and coordinate handedness before export;
- generate inspection-result XML directly after a separately approved
  production-validation gate;
- retain KLA data as an archive or optional internal analysis input rather
  than requiring KLA-to-XML conversion for every workflow.

See `TODO_XML_TEXTMAP_FRONT_BACK_ALIGNMENT.md` for the dedicated alignment
work plan.

## 4. Production XML-fast mode

After detection and alignment validation, a production mode may support:

```text
detect -> classify/filter -> contours/masks -> XML
```

Conceptual controls:

```text
--xml-fast
--no-gui
--no-crops
--no-dashboard
--write-slot-xml-immediately
--debug-on-fail-only
```

This mode should not wait for full GUI, dashboard, heatmap, or contact-sheet
rendering. It remains unapproved until the detection, coordinate-alignment,
and XML-validation gates are complete.

## 5. Frontside scribe reader

The deterministic methodology resource is:

`work/SCRIBE_REVIEW_ONLY/SEMI_M12_SCRIBE_VALIDATION_METHOD.md`

The notch-first localization and identity-card contract is:

`work/SCRIBE_REVIEW_ONLY/FRONTSIDE_NOTCH_AND_SCRIBE_IDENTITY_METHOD.md`

The SEMI M12 source standard is preserved locally as:

`SEMI M12-0998E SPECIFICATION FOR SERIAL ALPHANUMERIC MARKING (1).pdf`

Planned naming module:

1. Find the frontside scribe region.
2. Deskew and rotate the crop.
3. Segment the laser-mark characters.
4. Use constrained OCR/template matching and retain the top candidates and
   scores for every character position.
5. Preserve the independently highest-scoring image string.
6. For eligible 12-character strings, apply the SEMI M12 modulo-59
   whole-string checksum.
7. If the image-first string fails, search only bounded near-scoring
   alternatives and show every checksum-valid alternative without silently
   replacing the image-first read.
8. Validate against MES, KLA, and slot metadata.
9. Require manual review for localization/segmentation holds, checksum
   conflicts, reranked strings, multiple valid alternatives, low confidence,
   or MES conflicts.
10. Deskew the observed character baseline and crop the union of the 12
    observed character bounds with only a small adaptive readability margin.

Naming priority remains metadata first, then MES/lot-slot mapping, then
validated scribe OCR, with manual fallback.

The fixed 19-string regression set currently passes 19/19. Any implementation
change must retain all vectors. Checksum validation is deterministic and does
not authorize training.

### Scribe identity card

The first card for every selected wafer/slot should be a compact
`WAFER_IDENTITY` card:

- show the tight BF crop plus useful DF/pattern-suppressed evidence;
- prefill the editable comment/identity field with the canonical scribe;
- show per-character scores, SEMI M12 status, and MES/metadata agreement;
- set `CountInDefects=false`, `YieldEligible=false`, `XMLBinEligible=false`,
  and `KLABinEligible=false`;
- require explicit Save/Confirm for human correction; and
- propagate a confirmed correction through one canonical identity record,
  with an old/new/operator/time/reason audit trail and no silent overwrite or
  renaming of prior artifacts.

The user's tight crop example is visual guidance only. Do not reuse the
historical fixed 148-degree rotation or 2300-by-1100 rectangle.

## 6. Detection-impact, failure-mode, and presentation analytics

User-requested roadmap addition:

> Tools to quickly investigate the effects of detections to other failure
> modes and even the impacts of detections and patterns to breakage events,
> process issues and probe results, and display analysis in easy to digest
> powerpoint format for presentations.

Planned capability:

- connect inspection detections and spatial patterns with downstream failure
  modes, wafer-breakage events, process excursions/issues, and probe or
  electrical-test results;
- compare affected and control populations by product, route, process step,
  tool, chamber, recipe, lot, wafer, slot, time window, zone, defect class,
  size, density, and spatial pattern;
- support quick cohort comparison, trend analysis, wafer-map overlays,
  Pareto views, distributions, correlation matrices, event timelines, and
  drill-down to source images;
- distinguish defect presence, defect severity, detection coverage, and
  reporting suppression so analyses do not confuse “not reported” with “not
  present”;
- show data lineage, join keys, sample sizes, missing data, confidence, and
  confounding variables;
- allow an analyst to save a reproducible analysis definition and rerun it on
  a refreshed dataset;
- export an easy-to-digest PowerPoint presentation containing an executive
  summary, key charts, wafer maps, representative evidence images, methods,
  filters, sample sizes, caveats, and provenance;
- keep generated conclusions editable and label statistical associations as
  hypotheses unless validated by process engineering or a controlled study.

External process, breakage, MES, and probe sources should initially be
read-only. Analytics must not automatically alter inspection recipes,
training truth, wafer disposition, or production XML.

### MES-backed visual-state and cohort index

Every inspection should store the scribe-first metadata record defined in
`work/MES_INSITE_READ_ONLY/ARGOS_WAFER_METADATA_SCHEMA_V1.json`. Frontside
appearance cohorts use the complete tuple Device Workflow, ProdFamily,
Product/Revision, Process Block Workflow, Process Block, Step, and the exact
`In Process`/`In Queue` semantic state. Missing values remain visible holds;
they are not grouped into the nearest cohort.

The dashboard should filter on the raw fields, complete cohort key, backside
regime, EPI resource, Argos tool/slot, acquisition time, detector version,
and inspection coverage. A saved investigation preset stores filters, source
snapshot IDs, and schema/version hashes so another user can reproduce it.

The governing staged workflow is
`ARGOS_PHASE1_PHASE2_OPERATIONAL_ROADMAP.md`. BowComp selection comes from an
exact scribe-linked `SPUTTER BOW COMP DEP` / `MoveIn` history event, not from
image color or folder naming.

## 7. Suggested delivery order

1. Establish scribe-first discovery, MES visual-state snapshots, and exact
   Bare/BowComp history classification.
2. Finish and freeze the Bare edge/bevel detection and review contract.
3. Stabilize the review GUI views, controls, enhancement, and provenance.
4. Validate the copied KLA-to-test-XML size/location round trip.
5. Validate frontside textmap alignment and backside coordinate transfer.
6. Build versioned candidate edge-die templates without modifying originals.
7. Add recipe simulation and reporting-policy previews.
8. Add read-only joins to failure, breakage, process, and probe data.
9. Add reproducible analytics and PowerPoint export.
10. Consider XML-fast production operation and network routing only after the
    preceding validation gates are separately approved.

BowComp remains a separate future image domain and must not inherit Bare
calibration without its own validation.
