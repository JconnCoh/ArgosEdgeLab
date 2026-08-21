# Frontside scan-time material selector V1 checkpoint

## Outcome

A review-only scan-time lineage selector now classifies frontside acquisitions by observed process history rather than by recipe-folder name. It implements the requested dielectric/front-metal, resist-present/resist-removed, and exposed-pattern state transitions. The selector passed its seven-case deterministic unit gate and completed a read-only pass over the current JBOD-derived catalog.

This checkpoint does not deploy a JBOD revision, enable training, enable XML, or grant production authority. It freezes the routing evidence and the smallest useful validation matrix before detector transfer work.

## Frozen inputs and implementation

- Selector: `tools/Select-FrontsideInspectionFamilyFromLineageV1.ps1`
- Selector SHA-256: `C76540880053DFF93EC25E851909F38191F6E5834D357BCCB8A733105AFCCCD7`
- Unit gate: `tests/Test-FrontsideInspectionFamilyFromLineageV1.ps1`
- Unit-gate SHA-256: `831C20EAF5DF3AB4A23ABE608AFECE02B9CDEFE29BE62206A39A3151777274C8`
- Unit result: `PASS_FRONT_LINEAGE_SELECTOR_UNIT_V1`, 7/7 cases
- Live-output contract gate: `tests/Test-FrontsideLineageClassificationOutputV1.ps1`
- Live-output gate SHA-256: `FE420D93C08149E0B895355A0912D5967FDEE75338D0F0FA651729EA21664BE4`
- Live-output result: `PASS_FRONT_LINEAGE_CLASSIFICATION_OUTPUT_V1`, 757/757 rows accounted for
- Validation matrix SHA-256: `D47B8AF40036C1F4CA51F107D2FC941F1AE8FDD6570B60AAB46ACA724B563BF5`
- Final read-only result: `P:\ArgosEdgeLabRO_Temp\FrontsideLineageClassificationV1_2_20260809T055000Z`
- Final result state: `PASS_REVIEW_ONLY_LINEAGE_CLASSIFICATION`
- Exact history source: `P:\ArgosEdgeLabRO_Temp\FrontLineageInventory_20260809T044033038Z\RAW_HISTORY_ROWS.json`
- Exact signed history-return archive SHA-256: `83B68123CFC35428E03A41BB84ED0B43CD9DF14FB8FEDA63284DB88540241EEE`

## Scan-time state contract

Only chronological `MoveIn` history at or before the acquisition timestamp may change material state.

1. A qualifying dielectric deposition such as nitride/oxide/CVD establishes `DIELECTRIC`.
2. A qualifying evaporation/electroplating/plate operation establishes `FRONT_METAL`.
3. A coat operation after the active surface-forming event establishes resist `PRESENT`.
4. An expose operation after that coat establishes patterned resist.
5. Develop, transfer, and other in-cycle steps do not remove resist by themselves.
6. A qualifying PR, wet, plating, or lift-off strip after the coat establishes resist `REMOVED`.
7. A pattern-transfer event after exposure may preserve `PATTERNED` as an underlying surface state after strip.
8. Events after the exact acquisition timestamp are ignored.
9. `AVI_PM`, `AVI_PD_GREYSCALE`, `AVI_0`, `INSPECT_AUTO`, and similar measurement names are not material authority by themselves.
10. Recipe-directory names are discovery hints only and have no routing authority.

## Mandatory fail-closed gates

An acquisition is held unless all of the following are available:

- exact frontside side/handedness;
- confirmed 12-character scribe identity;
- exact scan-time history for that lot/identity;
- resolved product;
- paired native frontside BF and DF sources;
- qualified base material state;
- qualified pattern state when dielectric routing depends on it.

Every target wafer is excluded from its own composite. A same-product/same-step appearance outlier remains inspectable but is held out of reference contribution. Adjacent lots are never substituted for a requested lot.

## Current inventory result

- Frontside acquisitions evaluated: 757
- Safely classified: 142
- Held: 615
- Confirmed-identity acquisitions: 650
- Exact-history lots available: 32
- Missing-product rows: 353
- Unconfirmed-identity rows: 107
- Missing paired BF rows: 0
- Missing paired DF rows: 0

Classified families:

| Method | Acquisitions | Products | Lots |
|---|---:|---:|---:|
| `FRONTSIDE_DIELECTRIC_PATTERNED_NO_RESIST` | 31 | 3 | 4 |
| `FRONTSIDE_DIELECTRIC_PATTERNED_RESIST` | 61 | 3 | 8 |
| `FRONTSIDE_DIELECTRIC_UNPATTERNED_NO_RESIST` | 18 | 1 | 1 |
| `FRONTSIDE_FRONT_METAL_NO_RESIST` | 32 | 1 | 1 |

No product-qualified current cohort exists for `FRONTSIDE_DIELECTRIC_UNPATTERNED_RESIST` or `FRONTSIDE_FRONT_METAL_RESIST`.

Hold reasons overlap; they are not additive:

- `HOLD_BASE_MATERIAL_STATE_UNQUALIFIED`: 417
- `HOLD_PRODUCT_NOT_RESOLVED`: 353
- `HOLD_NO_EXACT_SCAN_TIME_HISTORY`: 177
- `HOLD_SCRIBE_IDENTITY_NOT_CONFIRMED`: 107
- `HOLD_DIELECTRIC_SURFACE_PATTERN_UNQUALIFIED`: 5

## Requested and adjacent lots

`62618-253` has 400 returned history rows but zero exact frontside catalog/image acquisitions. Its state is `HOLD_EXACT_IMAGE_ACQUISITION_ABSENT`.

`62618-252` has ten frontside acquisitions at `2026-07-15T11:53:52`. Three have confirmed scribe/product `1470174/A00`; their exact pre-scan lineage is nitride deposition, coat, expose, then strip. They classify as `FRONTSIDE_DIELECTRIC_PATTERNED_NO_RESIST`. The other seven remain held because identity/product is unresolved. `62618-252` is a useful transfer candidate but is not and must never be represented as `62618-253`.

The user-listed front-metal transfer lots `62626-046`, `62626-010`, `62625-899`, `62626-991`, `62613-847`, `62616-080`, `62621-592A`, `62616-094`, `62619-451`, `62618-307`, and `62551-820B` have no exact acquisition rows in the current catalog snapshot. Their histories cannot authorize image classification without their exact acquisitions.

## Bounded validation sequence

Use `FRONTSIDE_MATERIAL_STATE_VALIDATION_MATRIX_20260809.csv`.

1. Preserve the already reviewed `62631-586` scratch-test visits as the unpatterned dielectric/no-resist baseline and repeatability pair.
2. Review one patterned dielectric/no-resist visit for each available product: `62618-252`, `62624-803`, and `62626-015`.
3. Develop the resist-specific path using `62616-115`, then transfer to `62627-198`. Do not assume the no-resist detector transfers unchanged.
4. Preserve `62546-481` as the current front-metal/no-resist development baseline; expand only after exact product/state cohorts are available.
5. Hold front-metal-with-resist and unpatterned-dielectric-with-resist until product-qualified exact acquisitions exist.
6. Acquire/catalog `62618-253` if that exact lot is required for confirmation.

All outputs remain review-only, training-ineligible, XML-ineligible, production-ineligible, and non-deployed.
