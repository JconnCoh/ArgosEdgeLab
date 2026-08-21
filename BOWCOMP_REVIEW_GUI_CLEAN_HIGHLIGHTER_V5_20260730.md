# BowComp Clean Review GUI Highlighter V5

Date: 2026-07-30

Status: current review-only focused annotation interface.

## Correction

V4 changed the drawing control but reused old composite images containing
legacy magenta rectangles. V5 corrects the actual image source.

All 22 panels were rebuilt from the latest completed V49 native tile outputs:

- unchanged native BF crop;
- display-only green-channel local-contrast crop;
- latest V49 accepted/confirmation overlay crop.

The crop window still uses each historical review location only to choose a
reasonable field of view. No guide rectangle, historical drawing, or operator
annotation is rendered into any of the three images.

Current reviewer:

`work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_V66_CLEAN_HIGHLIGHTER_PANELS_20260730T114000Z/BOWCOMP_CLEAN_ANNOTATION_HIGHLIGHTER_V5.html`

## Annotation behavior

- `All three` is the default view.
- MISS, FALSE, and ISSUE use independent translucent highlighters.
- Width is adjustable from 2 to 48 pixels and defaults to 12 pixels.
- The page uses a fresh V5 local-storage key and contains no preloaded V3
  drawings or responses.
- Saved annotations preserve `FREEHAND`, `brushPx`, and `points`, and add
  `tool: HIGHLIGHTER` and `opacity: 0.32`.
- A closed highlighter stroke means only its painted brush corridor; its
  interior is never inferred or filled.

## Validation

- Clean-panel renderer contains no `DrawRectangle` call.
- 22/22 clean panel PNGs were created.
- 22/22 HTML image references resolve.
- Visual inspection of representative edge/holder and surface panels confirms
  that no legacy magenta rectangles remain.
- Embedded JavaScript syntax passes.
- Highlighter tagging, fresh storage, independent MISS/FALSE axes, and
  `All three` default checks pass.

This changes only review presentation and human markup capture. Detector
masks, classes, source images, training eligibility, XML eligibility,
production eligibility, and packaging authority are unchanged.
