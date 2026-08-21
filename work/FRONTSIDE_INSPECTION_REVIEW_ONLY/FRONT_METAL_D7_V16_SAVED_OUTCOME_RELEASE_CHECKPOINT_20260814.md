# Front-metal D7 V16 saved-outcome release checkpoint - 2026-08-14

Disposition: `RELEASED_REVIEW_ONLY`.

Review ID: `FM7_V16_20260814T2350Z`.

## Why V15 was withdrawn

The operator correctly reported that V15 changed classifications against the
locked V14 save and still displayed old unwanted component heatmaps. The
cause was presentation logic, not a changed detector: V15 projected outcomes
onto unfinished fields and regenerated native composites from whole-tile
accepted/held masks before applying the component-level saved result. Saved
false components therefore remained visible, saved classes were secondary to
the source proposal in the table, and raw confirmations stayed cyan instead
of taking the saved class color.

`FM7_V15_20260814T1840Z` is now `WITHDRAWN`. Its same-wafer 27/31 projection
remains `DIAGNOSTIC_ONLY` and is not applied by V16.

## V16 authority and behavior

V16 was built from the clean V14 reviewer and the unchanged locked V14
feedback:

`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260814T174534Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`

SHA-256:
`63E8A3524E1F98C47FF782AF792A2B39F7E4E3EE07D49637C888DCF5410D306B`.

The save remains 89/98 reviewed fields, 279 native-coordinate strokes, and 22
comments. D4, D5, D6, and V14 identifiers remain strictly separate.

The exact component presentation is:

- 216 components use saved Scratch, Particle, or Residue outcomes;
- 21 saved false components are excluded from current heatmaps;
- 14 reviewed, unlabeled definite components retain the source proposal;
- 7 reviewed, unlabeled ambiguous components remain class holds;
- 19 reviewed, unlabeled confirmation components remain confirmation holds;
- all 31 components in the 9 unfinished fields remain fail-closed holds.

The source `AutomaticClass` and source disposition remain unchanged and are
shown separately from the primary current review result. The drawing-tool
bubble is explicitly input-only and follows the selected class color. Native
and full-wafer current-result heatmaps use Scratch magenta, Particle green,
Residue amber, and remaining holds cyan. Imported feedback remains a separate
runtime canvas hidden by default.

The strict frontside physical-boundary chipout sibling branch is unchanged.
No detector mask, raw image, classification authority, training state, XML,
production route, package, or full-lot state changed.

## Exact audits and gates

The component audit passed 308/308 components and 72,499 component pixels
with zero proposal, disposition, saved-class, or component-mask mismatches.
It excludes all 3 T09/F02 saved-false grid components and all 3 T22 saved-false
grid components. T22/F04 presents its two saved Particle components and two
saved false components exactly. T29/F01 demonstrates that an unfinished field
remains `UNREVIEWED_FIELD_FAIL_CLOSED_REVIEW_ONLY`.

The raster release gate passed 55 entries: 23 clean bases, 32 current
heatmaps, and 179 current-mask references. The bounded live-browser audit
loaded the exact V16 revision, exercised raw/current/hold/detector/coverage
wafer views, verified imported-feedback toggle isolation, verified T09, T22,
and T29 native results, and found zero browser console errors. No image bytes,
screenshots, Base64, or data URLs entered the task history.

Additional gates passed:

- path budget: 146 paths, maximum effective length 160, zero non-pass paths;
- Windows PowerShell 5.1 wrapper preflight;
- exact launcher preflight with hash-qualified active-server reuse;
- ASCII/static UI gate, zero embedded-payload hits;
- canonical BowComp controls and byte-identical canonical `styles.css`.

Authoritative build result:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM7_V16_20260814T2350Z/BUILD_RESULT.json`

SHA-256:
`BE9844B4426D962E3BFF337155731019F69658AB456862999828BDA7E3529C2F`.

Launcher:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM7_V16_20260814T2350Z/START_FM7.cmd`.

## Next action

The operator may inspect V16 without redoing the 89 completed fields. Review
the Full wafer current-result heatmap and scroll the native fields for visual
sanity. Only genuinely unfinished or newly corrected fields need new input.
Do not apply the rejected V15 projection, train, emit XML, enable production,
package, run a full lot, or alter the strict chipout sibling branch.
