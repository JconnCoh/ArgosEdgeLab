# Do Not Use or Train

Status: **governing exclusion list**

Training is disabled for the entire current phase. Nothing in this workspace is authorized as a training dataset.

## Never use as training truth

- V2CF automatic grouped labels.
- V2CG automatic grouped labels.
- V2CH automatic grouped labels.
- V2CI automatic grouped labels.
- V2CJ automatic grouped labels.
- V2CK automatic grouped labels.
- V2CP edge-validation rows.
- V2CQ `EdgeRescueSeed` rows.
- Any automatic grouped or tile label.
- Any `EdgeRescueSeed`, `EdgeAuditCandidate`, audit-only, review-only, or display-only row.
- Anything generated from grouping unless an explicit human label independently establishes the truth.
- Any row marked `TrainingEligible=0`.

V2CV, V2CW, and V2CX evidence must retain its review-only and XML-ineligible status. V2CX supplies the current human edge decisions, but those decisions are still not authorized for training.

## Surface-to-edge prohibition

Surface rows must never create:

- `EdgeChipout`
- `ChipoutSmall`
- `BevelDamage`
- `PhysicalDamage`

The V2CT surface behavior is locked. Edge experiments may not tune, reinterpret, or relabel the surface baseline.

## Diagnostic revisions are not truth

- V2CY local-anchor behavior is historical diagnostic evidence; it is not the V2CX truth lock.
- V2CZ, V2DA, V2DB, and the supplied V2DC package are algorithm lineage or implementation candidates, not training truth.
- V2CR, V2CU, V2CV, V2CW, and V2CY are not substitutes for the exact locked V2CT run artifact.
- Old baked preview images are not active heatmap or contour data.
- Source-code references to CSV filenames are not the CSV data.

## Prohibited geometry and grouping

- No production XML geometry from audit candidates.
- No XML geometry from rows with `XMLGeometryEligible=0`.
- No broad radial holder or notch sector masks.
- No nearest-neighbor chain grouping.
- No long strip fill presented as a local chipout island.
- No borrowed Brightfield contour for Slot17 `MAN053`; its support is Darkfield-only.

## Current permitted use

The preserved evidence may be used only for:

- read-only inventory;
- provenance comparison;
- human review;
- later targeted, review-only smoke-test evaluation after explicit approval.

It may not be used for training, production XML, a full-lot run, packaging, or release.
