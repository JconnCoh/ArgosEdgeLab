# Front-metal D7 V15 current-heatmap review release checkpoint - 2026-08-14

## Result

`FM7_V15_20260814T1840Z` is `RELEASED_REVIEW_ONLY`.

The released result is
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM7_V15_20260814T1840Z/BUILD_RESULT.json`,
SHA-256
`758D9CE70DA2A3E66511011DE78A133F16F66452986B368983C8F6BB43BFCAC3`.

The operator launcher is
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM7_V15_20260814T1840Z/START_FM7.cmd`.

## Stale-raster diagnosis and correction

The operator's concern was valid. The V14 manifest's full-wafer accepted,
confirmation, anomaly, and coverage views referenced rendered display PNGs
from `FM6_V5_20260814T1500Z`. Those were predecessor composites rather than
fresh V14/V15 outputs. This was a display-lineage defect; it did not alter the
native BF/DF sources, detector component masks, or saved feedback.

V15 does not inherit those rendered PNGs. It starts from the locked clean
full-wafer BF overview and the clean native BF/DF tile sources, then renders
fresh display-only heatmaps from exact current component masks. Its manifest
contains zero predecessor full-wafer display references. The default Full
wafer view is now the current class-colored reviewed-defect heatmap. Separate
buttons expose current remaining holds, the unchanged detector-presence audit,
coverage state, and the clean raw BF overview.

The V15 full-wafer current heatmap changes 2,514 overview pixels, all inside
current component masks and zero outside. The remaining-hold view changes 80
pixels, all inside current masks and zero outside. The unchanged
detector-presence audit changes 2,464 pixels, all inside current masks and zero
outside. All 33 regenerated native-tile mask/composite comparisons likewise
have zero changed pixels outside their current masks.

Saved operator strokes and comments are imported as a separate runtime layer.
They are hidden by default and were not rasterized into any clean base or V15
heatmap. The browser audit confirmed that showing and hiding imported feedback
does not change the underlying image URLs.

## Review guidance and coverage

The locked V14 response remains unchanged at SHA-256
`63E8A3524E1F98C47FF782AF792A2B39F7E4E3EE07D49637C888DCF5410D306B`.
It contains 279 native-coordinate strokes, 22 comments, and 89/98 reviewed
fields. D4, D5, D6, and V14 identifiers and files remain strictly separate.

V15 carries the saved class/false guidance forward as staged review-only
presentation. It repairs V14's omission of false-removal guidance from the
field summary and labels whether a comment was inherited from D6 or changed in
the V14 save. The bounded same-wafer projection supplies review-only outcomes
for 27 of the 31 components in the nine unfinished fields. Four components
remain explicit fail-closed holds. The unfinished fields are coverage debt,
not Normal truth, and the operator is not asked to redo the 89 completed
fields.

## New durable raster-provenance gate

The governing workspace instructions now require
`work/ARGOS_RASTER_PROVENANCE_SAFETY.md` and
`utilities/Confirm-ArgosRasterProvenance.ps1` before any generated Argos
reviewer can be presented. The gate distinguishes clean bases, current
heatmaps, and operator-feedback layers; verifies source and mask hashes;
requires zero changed pixels outside current masks; rejects inherited rendered
rasters; and requires an exact-revision browser-render audit. The observed
failure signature and recovery are also recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`.

The V15 raster result is
`PASS_RASTER_PROVENANCE_RELEASE_GATE`: 57 raster entries, 23 clean bases, 34
current heatmaps, 133 current-mask references, and a verified rendered audit.
No screenshots, image bytes, Base64, or data URLs entered the task history.

## Release gates

- Canonical BowComp source hashes passed; all 27 required controls and four
  highlighter actions are present; `styles.css` is byte-for-byte canonical.
- Generated `index.html` and `app.js` are ASCII; no embedded image/Base64
  signature and no predecessor raster reference remains.
- The complete 125-path V15 tree passed the Windows path budget. Maximum path
  length was 166, maximum effective length 198, and maximum component length
  34.
- The static PowerShell/CMD wrapper gate passed. The exact target preflight
  passed under Windows PowerShell 5.1 and the exact `.cmd` launcher opened V15
  by safely reusing the hash-qualified server on port 8878.
- A true reload of the exact launcher URL opened Full wafer with
  `Current reviewed defect heatmap` active at 1800 by 1373 pixels. Imported
  wafer feedback was hidden by default.

## Scope

This release changes only review-only classification/coverage presentation and
raster provenance. The detector was not rerun or retuned; native masks, source
images, and feedback files were not changed. Training, XML, production,
packaging, full-lot execution, and automatic-reject authority remain disabled.
The strict frontside BF/DF chipout sibling branch remains frozen and unchanged.

## Next action

The operator may review V15, beginning on the Full wafer current heatmap. The
four remaining holds should stay fail-closed unless directly resolved. Do not
automatically apply the same-wafer guidance to training, XML, production, or a
full-lot run.
