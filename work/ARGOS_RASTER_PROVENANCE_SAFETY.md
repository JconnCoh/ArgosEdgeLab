# Argos raster-provenance and rendered-visual safety

Date: 2026-08-14

State: `APPROVED_BASELINE`

## Purpose

An Argos reviewer must never present a predecessor preview, old heatmap, or
operator highlighter mark as current clean detector evidence. File existence,
dimensions, filenames, and page controls are insufficient: the exact raster
lineage and the actual rendered state must both pass before presentation.

## Required layer separation

Every review image belongs to exactly one declared role:

1. `CLEAN_BASE` - immutable raw or explicitly approved clean display source;
2. `CURRENT_HEATMAP` - a current-revision detector or confirmation mask shown
   as a separate layer or a documented current composite;
3. `OPERATOR_FEEDBACK` - runtime or file-backed review guidance, hidden by
   default when imported and never part of a clean base or detector heatmap.

A marked feedback PNG, predecessor composite, or already-annotated preview is
ineligible as `CLEAN_BASE`. Hiding a canvas does not repair a baked raster.

## Mandatory pre-presentation gate

For every new reviewer revision:

1. Write a bounded UTF-8 `RASTER_PROVENANCE_MANIFEST.json` containing the
   current review ID, every clean base, every displayed heatmap, exact file
   hashes, clean-source hashes, and current mask lineage.
2. Require each `CLEAN_BASE` file to match its locked clean source byte for
   byte. A mismatch is a release hard stop.
3. Generate each `CURRENT_HEATMAP` only from masks named by the current
   revision. Record each mask path and SHA-256. Set
   `operatorFeedbackRasterized=false` and `inheritedReviewRasterUsed=false`.
4. For any composited heatmap image, independently compare it with the clean
   base and assert `changedPixelsOutsideCurrentMask=0` and
   `changedPixelsInsideCurrentMask>0`. An alpha-only overlay must likewise
   prove that every nontransparent pixel belongs to a documented current mask.
5. Run `utilities/Confirm-ArgosRasterProvenance.ps1` on the exact manifest.
6. Load the exact revision in the real reviewer service. With imported local
   and full-wafer feedback hidden, inspect bounded rendered pixel state for:
   the full-wafer clean base, every default current heatmap, an edge field, a
   zero-signal field, a feedback-bearing field, and a held-component field.
   Toggle each current heatmap and imported-feedback layer independently.
7. Save only bounded text results and hashes in a rendered audit. Do not return
   screenshot bytes, Base64, data URLs, or canvas/image bodies to task history.

The rendered audit must prove:

- the browser loaded the exact expected review ID and manifest;
- imported feedback is hidden by default;
- current full-wafer defect heatmaps are visible and nonempty by default;
- heatmap toggles change only their declared layer;
- showing imported feedback changes only the feedback canvas;
- clean base pixels are unchanged when heatmaps and feedback are hidden;
- no predecessor review image or stale raster annotation is referenced.

## Failure disposition

Any clean-source mismatch, predecessor raster reference, unexplained changed
pixel, missing full-wafer defect heatmap, or rendered-layer mismatch makes the
candidate `WITHDRAWN` or `DIAGNOSTIC_ONLY`. Do not patch the presented root in
place. Preserve it for audit and rebuild in a fresh short root from locked
clean sources and current masks. Never erase operator feedback or change the
detector merely to obtain a clean display.

This gate is display and provenance safety only. It does not grant training,
XML, production, packaging, full-lot, or automatic-reject authority.
