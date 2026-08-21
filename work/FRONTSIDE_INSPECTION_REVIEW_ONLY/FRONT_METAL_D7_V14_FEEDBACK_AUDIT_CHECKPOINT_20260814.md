# Front-metal D7 V14 operator-feedback audit checkpoint - 2026-08-14

Disposition: `DIAGNOSTIC_ONLY`

Active reviewer: `FM7_V14_20260814T1915Z` (`RELEASED_REVIEW_ONLY`)

This checkpoint records the completed file-backed audit of the operator's
latest V14 save. It does not change detector evidence, accepted-presence
masks, raw BF/DF, training eligibility, XML eligibility, production authority,
packaging, or the independently preserved strict frontside chipout branch.

## Locked V14 operator response

The completed save is:

`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260814T174534Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`

- review ID: `FM7_V14_20260814T1915Z`
- created UTC: `2026-08-14T17:45:34.615Z`
- save completed UTC: `2026-08-14T17:46:18.184Z`
- coordinates SHA-256:
  `63E8A3524E1F98C47FF782AF792A2B39F7E4E3EE07D49637C888DCF5410D306B`
- `SAVE_COMPLETE.json` SHA-256:
  `19FF45CE27A4D5F81412AFFC669A632A6A29DF7A044CED7F56FDD7B8620056F3`
- reviewed fields: 89/98
- unreviewed fields: 9
- native-coordinate strokes: 279
- actions: 226 reclassifications, 31 missed-defect additions, and 22 false-removal strokes
- class marks: 157 Scratch, 90 Particle, and 10 Residue
- nonempty field comments: 22
- marked local PNGs: 81; full-wafer marked PNGs: 0; save errors: 0

All 88 D5 strokes remain present byte-for-byte. Relative to the preceding D6
partial save, 88 strokes remain exact, 18 older D6 strokes were replaced by
the current-field response, and 191 strokes are new in V14. D4, D5, D6, and
V14 identifiers and response files remain strictly separated. The V14 save
is the current `LOCKED_INPUT`; it is partial and is not applied automatically.

## Current operator class guidance

The operator's current message supersedes stale inherited comments where the
two conflict:

- a bright BF defect on die is generally Scratch;
- a dark BF defect is generally Particle;
- touching bright-on-metal and dark-in-street evidence is generally one
  Scratch crossing the metal/street boundary;
- faint DF evidence with little or no BF visibility is generally Residue.

This guidance was checked against component masks and saved native-coordinate
marks. It is useful population-level evidence, not a universal autonomous
classifier. In particular, accepted component
`T27_R05C01_ACCEPTED_000006` is fully marked Residue but has a bright BF and
low-DF signature that contradicts the simple rule. It remains a preserved
operator exception and must not be silently relabeled or used to claim
zero-error automatic Residue authority.

## File-backed signal audit

Audit root:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7_V15_AUDIT4_20260814T1800Z`

The audit read the native 1:1 BF/DF PNGs, exact connected-component masks, and
saved native-coordinate paths. It emitted text and numeric artifacts only; no
image bytes, Base64, data URLs, or screenshots entered task history.

- state: `PASS_REVIEW_ONLY_SIGNAL_AUDIT`
- components audited: 308/308
- exact component-area checks: 308/308 match the recorded `AreaPx`
- strong accepted labels: 145 total (92 Scratch, 46 Particle, 7 Residue)
- component label conflicts: 0
- median BF local residual: Scratch `+2.169`, Particle `-3.860`
- median PCA aspect: Scratch `2.54`, Particle `1.68`
- prior definite geometry proposals among strong labels: 88 correct, 4 wrong

The four prior proposal errors all had PCA aspect below 3, confirming that
size or major-axis geometry alone is insufficient for reliable subclassing.

## False-grid diagnosis

The two reported inverted-grid examples are not a global image or heatmap
polarity inversion. They are component-selection/eligibility false positives:

- T09/F02: all three raw cyan components were covered completely by current
  false-removal strokes (`204/204`, `71/71`, and `70/70` mask pixels).
- T22/F04: accepted components `000005` and `000012` were fully marked
  Particle (`105/105` and `41/41` pixels), while raw cyan components `000001`
  and `000003` were fully marked false (`379/379` and `49/49` pixels).

The earlier V14 display audit still has zero changes outside documented
masks. The correction belongs in component eligibility/classification, not in
display inversion or recoloring.

## Remaining-field projection

Nine fields remain unfinished, containing 31 components. The deterministic
same-wafer projection resolves 27 components to review-only outcomes and
preserves four explicit holds. It never copies a direct human label into an
automatic class and does not modify the V14 reviewer or feedback.

- 23 existing definite Scratch/Particle proposals are retained only where at
  least 3 of 5 strong reviewed accepted-shape neighbors agree.
- `T27_R05C01_ACCEPTED_000008` projects as Particle from dark BF plus Particle
  shape corroboration.
- `T29_R05C03_ACCEPTED_000012` projects as Scratch from mixed bright/dark BF
  plus Scratch shape corroboration.
- `T29_R05C03_RAW_CONFIRM_000001` and `000002` are repeated-normal-pattern
  false-candidate previews, not Normal truth and not detector-mask changes.

The four unresolved components remain fail-closed:

1. `T29_R05C03_ACCEPTED_000009` -
   `CONFIRM_SCRATCH_OR_RESIDUE_CHANNEL_SHAPE_CONFLICT`
2. `T29_R05C03_ACCEPTED_000013` -
   `CONFIRM_SCRATCH_OR_PARTICLE_CHANNEL_SHAPE_CONFLICT`
3. `T29_R05C03_RAW_CONFIRM_000003` -
   `CONFIRM_PARTICLE_OR_NORMAL_REPEATING_PATTERN`
4. `T29_R05C03_RAW_CONFIRM_000004` -
   `CONFIRM_SCRATCH_OR_PARTICLE_OR_NORMAL_REPEATING_PATTERN`

Projection state: `PASS_REVIEW_ONLY_REMAINING_CLASS_PROJECTION`.

## Reviewer presentation finding

The live V14 page successfully imported the completed V14 response. Its
`Saved operator guidance` summary counts missed-defect and reclassification
strokes but omits false-removal strokes, so a field can incorrectly say
`none` even though its saved false mark is intact. Inherited D6-era comments
also appear without a clear historical label. Any successor reviewer must
count false-removal guidance and visually distinguish inherited comments from
the current response. This is a presentation issue, not feedback loss.

## Authority and next gate

The completed V14 response is sufficient for 27/31 remaining components to
receive defensible review-only projected outcomes. It is not sufficient to
force the remaining four conflicts into a class or Normal result.

A future canonical-derived V15 candidate may apply this projection only as a
new `PENDING_GATE` review-only revision, preserve the four holds, keep the two
normal-pattern matches as review-only previews, and repair the two reviewer
presentation issues above. It must pass canonical, display, coverage,
continuity, path, session-size, and launcher gates before presentation.
Training, XML, production routing, packaging, full-lot execution, and
automatic reject authority remain prohibited.
