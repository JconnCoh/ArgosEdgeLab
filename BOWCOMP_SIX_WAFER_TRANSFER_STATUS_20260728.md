# BowComp six-wafer transfer status — 2026-07-28

## 2026-07-29 V5.7 scratch-mask coverage follow-up

The latest bounded BowComp scratch checkpoint is
`work/BOWCOMP_REVIEW_ONLY/BOWCOMP_V57_AXIS_RECOVERY_CHECKPOINT_20260729.md`.
It corrects an exposed yellow-mask escape by recovering only observed
native-pixel scratch evidence along an already accepted enhanced-Hough seed
axis. It does not lower the global scratch threshold, infer or paint gaps,
mask blue globally, change BowComp geometry status, or affect Bare behavior.

The 50-tile six-wafer targeted transfer completed with 14 positive pixel
deltas, 36 unchanged tiles, no negative deltas, no frozen-control failures,
and zero accepted holder overlap. The exact positive/control repeat matched
14/14 scratch masks by SHA-256. V5.7 remains review-only, training-ineligible,
XML-ineligible, production-ineligible, non-full-lot, and unpackaged.

Status: **corrected native-pixel surface-transfer diagnostic completed on all
six independent BowComp wafers; the BowComp-only tangential nitride-boundary
filter is accepted for review-only scratch separation; BowComp edge geometry
and production use remain held.**

## Scope and identity

The two archives contain six physically distinct wafers from two lots.
Repeated physical slot numbers are not duplicates and must never be merged:

- `62624_803_SLOT16`
- `62624_803_SLOT18`
- `62624_803_SLOT20`
- `62624_869_SLOT16`
- `62624_869_SLOT18`
- `62624_869_SLOT20`

Only backside Brightfield and Darkfield evidence was staged. Detection used
the lossless native BMP pixels at 14.5 µm/pixel. Display overviews and contact
sheets are resampled review artifacts only.

## Domain separation

This is a separate `BOWCOMP_BACKSIDE_ONLY` study. It did not consume Bare
calibration statistics and does not revise Bare authority.

The BowComp surface-transfer diagnostic used `RG_AVERAGE` evidence,
`(red + green) / 2`, so the variable blue nitride-film response does not
drive detection. Raw BF and DF remain unchanged and available for review.
The user-identified blue field variation, the two recurring blue-band
features, and the rounded edge feature are normal BowComp nuisance evidence,
not defect truth.

## BowComp-only tangential nitride-boundary correction

A diagnostic six-wafer pass exposed three long false scratch traces on the
inner blue nitride transition in `62624_869_SLOT16`,
`62624_869_SLOT18`, and `62624_869_SLOT20`. That diagnostic is not the
current accepted run.

The correction does not ignore blue globally. It is evaluated only inside
the BowComp blue-nuisance scratch branch and distinguishes:

- a false nitride transition, whose long axis stays tangential to the wafer
  and has no independent DF support; from
- a real scratch, which departs from or crosses the blue band and has a
  substantial radial component and/or independent DF evidence.

The measured false contour arcs had major-axis radial alignment of
approximately `0.003-0.012`; the marked real blue-zone scratches were
approximately `0.65-0.68`. The conservative review-only rule suppresses a
component only when its major span is at least 45 px, DF support is below
`0.05`, and radial alignment is no greater than `0.08`.

The targeted V19 gate:

- retained the exact accepted component and pixel counts for all ten marked
  positive scratch tiles;
- reduced the three newly exposed long boundary controls from
  `7073`, `7319`, and `1588` scratch pixels to zero;
- retained zero accepted holder-overlap pixels.

The final six-wafer heatmaps and 31 focused/weak-linear native-pixel crops
show no remaining long contour-following nitride trace. Genuine faint, long,
curved, and blue-band-crossing scratches remain visible.

## Geometry result

The unchanged Bare geometry qualifier did not transfer:

- all six BF circle fits failed the unchanged Bare residual gate;
- DF boundary evidence was locally sharp but had only approximately
  34–45% inlier coverage;
- unsupported DF angular gaps were approximately 75–120 degrees.

No tolerance was loosened to manufacture a pass. All six wafers retain:

`INSPECTION_HOLD_BOWCOMP_GEOMETRY_NOT_QUALIFIED`

Consequently BowComp `EdgeChipout`, `EdgeMicroDamage`, notch, and DF bevel
decisions remain disabled/held. Surface scratch, residue, contamination,
particle, and etch-stain evidence was evaluated independently of that edge
authority.

## Six-wafer surface-transfer result

All six identities completed 30 native tiles each with the corrected source:

- 180 native tiles;
- 49,429 detected defect components;
- 0 zero-byte artifacts;
- 0 holder-leak tiles;
- 0 accepted holder-overlap pixels;
- 0 training-, XML-, production-, full-lot-, or package-eligible outputs.

Detected component totals:

| Class | Components | Area (pixels) |
|---|---:|---:|
| Contamination | 44,644 | 556,764 |
| Etch stain | 104 | 31,780 |
| Particle | 1,347 | 27,233 |
| Residue | 2,377 | 191,148 |
| Residue streak | 379 | 40,309 |
| Scratch | 578 | 164,938 |

The full-wafer accepted heatmaps remain sparse. They do not paint the broad
blue field or the full blue edge band as defects. The natural brown outer
rim is already present in raw BF and must not be mistaken for an overlay.

## Scratch audit

A focused audit selected 14 representative native-pixel scratch components
across all six wafers. It showed:

- long and faint real linear scratches on both lots;
- strong recovery of the prominent diagonal scratch on
  `62624_869_SLOT16`;
- multiple faint parallel scratches that would be erased by a simple global
  threshold increase;
- two weak `62624_869_SLOT18` scratch-subclass labels where defect presence
  or the exact subtype is not visually secure.

Therefore no global scratch-threshold increase was applied. That would reduce
false labels by sacrificing genuine faint scratches, contrary to the current
scratch-first objective.

After the tangential correction, a fresh final audit selected 17 focused
scratch components and 14 weak-linear components across the six wafers.
Native BF/DF/overlay review confirmed that the sampled accepted lines follow
visible defects rather than the concentric blue transition.

The existing disposition text
`REVIEW_ONLY_REJECT_CLASS_LOW_CONFIDENCE` means that detector pixels are
treated as a defect while the residue/contamination/particle/scratch
subclass is less certain. It is not a clean automatic-classification pass.
Future run manifests now report this separately as subclass uncertainty.
Completed masks and images were not rewritten.

## Authoritative records

- Configuration:
  `work/BOWCOMP_REVIEW_ONLY/configs/bowcomp_six_wafer_surface_transfer_v1.json`
  - SHA-256:
    `172F4B0529AAABAB8A6CF285E7D83FCB35FDD53165BC14BA7D12010D74FE7D5A`
- Runner:
  `work/BOWCOMP_REVIEW_ONLY/run_bowcomp_six_wafer_surface_transfer.ps1`
  - SHA-256:
    `DDFF005123C4F3513F99B8513676CDE27D3DB8E80FFCEBF35C2277CEFE040B06`
- Corrected detector source:
  `work/BARE_SURFACE_INSPECTION_REVIEW/src/NativePhysicalEligibilityReview.cs`
  - SHA-256:
    `A4E1D57D04442116060E0F961A90764468930B46BC539B984BFF15EBEA07FFA4`
- Targeted V19 gate:
  `work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_V19A_TANGENTIAL_NITRIDE_FILTER_20260728T193500Z`
- Corrected six-wafer final summary:
  `work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_SIX_WAFER_FINAL_TANGENTIAL_FILTER_STATUS_20260728T193212Z/FINAL_SUMMARY.json`
  - SHA-256:
    `1731C3A2BB56735D880D358BB483C25887048941B44990F9B8D1A525F05A3F53`
- Final focused scratch audit:
  `work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_SIX_WAFER_FINAL_FOCUSED_SCRATCH_AUDIT_20260728T195200Z`
- Final weak-linear audit:
  `work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_SIX_WAFER_FINAL_WEAK_LINEAR_AUDIT_20260728T195200Z`
- Final full-wafer accepted-heatmap contact sheet:
  `work/BOWCOMP_REVIEW_ONLY/outputs/review_only/BOWCOMP_SIX_WAFER_FINAL_TANGENTIAL_FILTER_STATUS_20260728T193212Z/BOWCOMP_SIX_WAFER_FINAL_HEATMAP_CONTACT_SHEET.png`

## Compatibility regression

The corrected shared source still passes:

- the explicit/default Bare luma overload compatibility comparison:
  13/13 byte-identical core artifacts;
- the frozen Bare edge combined component contract: 26/26.

The correction is confined to the BowComp blue-nuisance scratch branch.
It does not alter V2CT, Bare surface behavior, or frozen
Slot01/Slot03/Slot17 edge authority.

## Eligibility

Everything in this study remains:

- review-only;
- training-ineligible;
- XML-geometry-ineligible;
- production-ineligible;
- not a full-lot run;
- not packaged.

The next BowComp edge step requires a separately qualified per-wafer geometry
method. It must not borrow Bare geometry tolerances merely to clear the hold.
