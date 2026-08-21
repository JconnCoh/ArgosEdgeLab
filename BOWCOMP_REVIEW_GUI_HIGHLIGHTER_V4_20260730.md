# BowComp Review GUI Highlighter V4

Date: 2026-07-30

Status: **superseded by clean V5**. V4 changed the annotation control but
incorrectly reused composite images with legacy magenta rectangles baked into
all three views. Do not use V4 for review.

## Result

The V4 page changed the annotation control to a translucent pixel highlighter:

`work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_V65_MARK_LINE_EVIDENCE_REVIEW_20260729T232500Z/BOWCOMP_FOCUSED_ANNOTATION_HIGHLIGHTER_V4.html`

However, V4 reused the V3 panel PNGs. Those PNGs already contained magenta
guide rectangles drawn directly into raw BF, local contrast, and detector
evidence. This was not a clean reviewer and was rejected by the operator.

Use `BOWCOMP_REVIEW_GUI_CLEAN_HIGHLIGHTER_V5_20260730.md` and the clean V5
page instead. The historical V3 page and its saved operator feedback remain
unchanged.

## Operator behavior

- `All three` is the default card view.
- MISS, FALSE, and ISSUE remain independent categories.
- The highlighter width is adjustable from 2 to 48 composite-image pixels and
  defaults to 12 pixels.
- New marks use 0.32 display opacity so raw BF, local-contrast BF, and
  detector evidence remain visible below the mark.
- Direct project-folder save, text response, coordinate JSON, marked PNG,
  per-card undo/clear, global drawing visibility, and prior-JSON import remain
  available.
- The new page starts with a fresh V4 local-storage key and does not preload or
  alter the completed V3 review.

## Saved-coordinate contract

Each new stroke preserves the existing compatible fields:

- `category`;
- `shape: FREEHAND`;
- `brushPx`;
- `points`.

It also records:

- `tool: HIGHLIGHTER`;
- `opacity: 0.32`.

The audit parser was updated so a V4 highlighter stroke always means only the
painted brush corridor. Closing a highlighter loop does not fill the loop's
interior. Legacy annotations without `tool: HIGHLIGHTER` retain their earlier
closed-outline behavior.

Highlighter coordinates remain approximate human review guidance. They are
not pixel-exact training truth, XML geometry, or production authority.

## Validation

- Embedded JavaScript syntax parsed successfully.
- The annotation-audit PowerShell script parsed successfully.
- All referenced panel-image assets were checked locally.
- Static contract checks confirmed V4 highlighter tagging, fresh storage,
  independent coverage/false axes, and `All three` default behavior.
- Automated interaction with the local `file://` page was blocked by the app
  browser's local-file security policy. The first operator open should perform
  a short manual smoke test: draw one MISS and one FALSE highlight on one card,
  undo one stroke, restore it, and verify the exported JSON contains
  `tool: HIGHLIGHTER`.
