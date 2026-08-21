# TODO — V2DC Edge Residual Spike Audit

Status: **approved isolated targeted implementation active; production integration, full-lot execution, training, XML, packaging, GUI deployment, and BowComp remain unapproved**

The handoff contains an existing V2DC source candidate:

`ARGOS_CODEX_HANDOFF_ARTIFACTS.zip`  
`ARGOS_CODEX_HANDOFF_ARTIFACTS/Argos_DefectReview_V2DC_EdgeResidualSpike_Slots010317_tool_package.zip`

Nested package size: 163,610 bytes  
Nested package SHA-256: `0DD631012815D0139A62EE92BE5851FB3E87EF39F3A6F6BB8CAF9A8D750C079E`

It was inspected statically through ZIP listings and text reads only. It has not been extracted, executed, modified, accepted, or promoted to an implementation baseline.

## Required scope

- Build and test V2DC as an **edge-only residual-spike audit**.
- Make no surface changes.
- Make no detector-threshold changes.
- Keep V2CT locked and read-only.
- Do not train.
- Do not generate production XML geometry.
- Do not run a full lot.
- Do not package or release.
- Limit initial evidence to Slot01, Slot03, and Slot17.
- Keep every generated row review-only, `TrainingEligible=0`, and `XMLGeometryEligible=0`.

## Intended edge model

1. Use the global fitted circle as the expected wafer edge.
2. Use a local offset only to align the expected edge to normal local drift.
3. Apply a tolerance band so ordinary smooth drift is not classified as damage.
4. Evaluate the residual after alignment.
5. Detect short, local residual chipout spikes or islands.
6. Reject long smooth offsets, holder/contact regions, notch effects, and residue streaks.
7. Never turn a long radial strip into a filled chipout.

No broad full-edge residual scan is approved.

## Target truth cases

| Slot | Truth row/channel | Required behavior |
|---|---|---|
| Slot01 | `MAN010` Darkfield | Large real edge chipout. Fill the actual bite, but do not extend a long strip. |
| Slot01 | `MAN016` Brightfield | Same physical large chipout evidence. Fill the actual bite, but do not extend a long strip. |
| Slot03 | `MAN040` Brightfield | Detect a small local chipout island. |
| Slot03 | `MAN041` Brightfield | Detect a small local chipout island. |
| Slot03 | `MAN042` Brightfield | Detect a small local chipout island. |
| Slot17 | `MAN053` Darkfield | DF-supported `BevelDamageCandidate`; do not borrow or invent a BF contour. |

The six decisions above come from the V2CX truth lock. The other 74 edge rows are suppressed false/artifact rows and must remain negative/suppressed evidence.

## Input and staging status

Artifact prerequisites are resolved:

- canonical V2CT locked logical/package baseline confirmed;
- `latest_circle_fit_results.csv` supplied and accepted;
- `edge_intrusion_segments_v6.csv` supplied and accepted;
- `notch_summary_v6.csv` supplied and accepted;
- Slot01/03/17 backside BF/DF full-size working images supplied and declared sufficient;
- `flipImageHorizontal=true` confirmed for all six backside inputs;
- isolated work/scratch directories approved and created.

The bootstrap/prior geometry markers and circle confidence near 0.621 are accepted input facts. The geometry CSVs must not be edited.

Copied inputs are staged at:

`scratch\V2DC_edge_residual_spike_staging`

Full implementation and detector execution remain unapproved.

## First targeted contact-sheet result

Current review output:

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_BARE_CONTACT_SHEETS_20260724_233524Z`

| Target | Local offset | Tolerance | Maximum residual | Accepted islands |
|---|---:|---:|---:|---:|
| Slot01 `MAN010` | +4 px | 4 px | 67 px | 1 human-expanded bounded island |
| Slot01 `MAN016` | +4 px | 3 px | 160 px | 1 contiguous bounded island; 216 px adaptive inward search; 7 review-only curved-closure points |
| Slot03 `MAN040` | -4 px | 2.5 px | 6 px | 5 separate shallow islands plus 1 tiny review-guided outline |
| Slot03 `MAN041` | -4 px | 2.5 px | 5 px | 1 short island |
| Slot03 `MAN042` | -4 px | 2.5 px | 10 px | 5 short islands |
| Slot17 `MAN053` | +13 px | 4 px | 2 px | 0 radial islands; 2 thin DF-support outlines |

This result is diagnostic and review-only. Human acceptance is required before it becomes the design reference for any later V2DC implementation.

Pink markup is approximate human review guidance only. It expands the Slot01 reviewed bite spans, confirms three separate Slot03 neighborhoods, and identifies two Slot17 DF-support regions. It is not training truth or production geometry.

The MAN016 curved wall and the tiny MAN040 outline demonstrate two cases the radial residual model does not autonomously recover. Treat them as requirements for later outside-connected boundary tracing, not as proof of detector performance.

Every chipout residual must remain edge-connected and have a complete dark radial corridor from the candidate boundary through the expected edge and at least 32 px into outside-wafer space. Search depth is derived from the bounded review window rather than a fixed maximum. Interior surface particles, contamination, and residue are ineligible even when dark.

## Targeted negative-control result

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_BARE_NEGATIVE_CONTROLS_20260724_233451Z`

- 9 representative controls selected from the 74 V2CV human-reviewed false rows;
- 0 accepted chipout candidates;
- exact notch/holder prior overlaps rejected locally;
- smooth drift, residue, and unexplained false controls rejected without broad masks.

## DF-only bevel result

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_DF_BEVEL_CONTROLS_20260724_234115Z`

- Slot17 `MAN053`: 2 accepted DF-only bevel-band disruptions;
- accepted arc lengths: 31.6 px and 25.6 px;
- mean outer/inner DF brightness ratios: 0.159 and 0.267;
- 8 false DF controls: 0 accepted candidates;
- no borrowed BF contour;
- no training or XML eligibility.

User review accepted this result as the conservative MAN053 reference. Two very small endpoint/shoulder portions marked in pink remain outside the yellow contours. Preserve that minor under-contour rather than relaxing global thresholds from a single positive example.

## Future BowComp work

BowComp is explicitly out of the current run. Its nitride and higher variation require a separate input inventory, truth set, geometry check, tolerance study, and approval. Do not reuse Bare thresholds or residual morphology without that work.

## Bare blind smoke V2 result

The frozen Slot21/Slot24/Slot15 gate is complete.

- 94 raw Darkfield candidates were frozen into 43 groups before review.
- The displayed targeted set produced no human-identified chipout, clear bevel
  damage, or unmistakable-contamination reject.
- All 15 final coverage-recovery members rendered; no source hold or
  unrendered member remains.
- The cyan inner-transition review placement is `0.55`, with approximately one
  pixel of local review variation accepted.
- C02 / D09 / `Slot24_BEVEL_DF_027` is the explicit exception:
  `OUTER_BOUNDARY_UNCERTAIN`. Its orange boundary remains review-only and
  cannot become a production limit or XML geometry.
- Dark/no-signal areas remain coverage holds rather than Normal truth.

This does not establish full-wafer negative truth or unseen-positive
sensitivity. Full implementation still requires explicit approval.

## Approved working pattern

```text
work/
  V2DC_edge_residual_spike/
    src/
    configs/
    tests/
    inputs_read_only/
    outputs/
      review_only/
    logs/
```

The directory skeleton and read-only input staging exist. Approved isolated
implementation increments are confined to
`work\V2DC_edge_residual_spike\implementation`; original source packages and
extracted source trees remain unchanged.

Before any build or package is considered, generate targeted contact sheets showing:

- cyan: global-circle expected edge;
- orange: observed local edge;
- gray: tolerance/nonreject drift band;
- yellow: accepted residual chipout islands.

Never overwrite prior outputs. Keep Slot01 bounded-gap behavior, Slot03 local islands, and Slot17 `MAN053` DF-only behavior isolated from surface logic.

## V4.1 DF inner-boundary micro-pocket result

The user accepted Slot03 candidates P01-P06 and marked P07-P09 false. That
adjudication is frozen as review guidance and is not pixel-exact training
truth.

The isolated V4.1 deterministic second-stage gate is implemented at:

`work\V2DC_edge_residual_spike\implementation\v4`

The authoritative review-only run is:

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_IMPLEMENTATION_V4_1_DF_MICRO_POCKET_REGRESSION_20260725_225620Z`

- 6/6 accepted examples retained;
- 3/3 marked false examples rejected;
- 225/225 radial/tangential alignment-stress combinations passed over
  -2 through +2 pixels;
- all nine frozen V2CX negatives remain suppressed by the required upstream
  V3 gate;
- MAN053 remains DF-only and unchanged;
- BF is display evidence only and supplies no contour;
- every row remains review-only, `TrainingEligible=0`, and
  `XMLGeometryEligible=0`.

The outside-corridor audit found that none of the six accepted micro pockets
has a complete dark path through the bevel to persistent outside-wafer space.
The user approved `EdgeMicroDamage` as the autonomous reject class for these
features. Routine human classification is not part of the operational goal.
V4.2 routes accepted micro pockets without a complete corridor to
`EdgeMicroDamage`/`REJECT`, complete corridors to the separate `EdgeChipout`
stage, and rejected pockets to `NoEdgeMicroDamage`.

The authoritative V4.2 targeted run is:

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_IMPLEMENTATION_V4_2_EDGE_MICRO_DAMAGE_REGRESSION_20260725_232132Z`

- six automatic `EdgeMicroDamage` rejects;
- three automatic non-rejects;
- zero human classifications required;
- zero classification holds;
- 9/9 taxonomy regressions;
- byte-identical automatic classification manifest on deterministic rerun;
- 225/225 frozen alignment-stress checks retained;
- all nine frozen V2CX negatives still suppressed upstream;
- MAN053 unchanged and DF-only.

This approval does not authorize production integration, XML geometry,
training, full-lot execution, packaging, GUI deployment, surface changes, or
BowComp.

## V4.3 Phase A held-out status

The approved bounded Slot03 Phase A run is complete at:

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_EDGE_MICRO_DAMAGE_PHASE_A_HELDOUT_20260725_235935Z`

- autonomous first-stage locator added in the isolated V4.3 tree;
- known positive recovery: 6/6;
- known false-reference recovery: 0/3;
- eight complete, separated held-out strips;
- six usable automatic no-reject windows;
- H01/H07 explicit low-DF-coverage holds;
- zero automatic damage rejects;
- deterministic manifests confirmed.

Pending: one-time review of the complete strips for visible misses. Do not
interpret unreviewed no-reject windows as negative truth. Do not interpret
coverage holds as Normal.
