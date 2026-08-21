# Frontside scan-time appearance correlation checkpoint — 2026-08-06

Status: provisional review-only appearance correlation. No detector scoring,
defect mask, golden promotion, training, XML authority, JBOD frontside
enablement, or production authority was created.

## Correction to the earlier grouping

The first frontside intake grouped acquisitions by a later/current MES visual
state snapshot. That is not reliable acquisition-time authority. The same
process-block text can cover both an unpatterned early step and a patterned
later step. In particular, the words `CONTACT PRE FIDUCIAL PATTERN` do not by
themselves prove either state.

The new bounded display review instead uses:

1. operator-confirmed 12-character scribe;
2. exact read-only Insite lineage;
3. the last `MoveIn` preceding the Argos scan timestamp;
4. the next surrounding Insite event;
5. the actual frontside BF/DF appearance.

Recipe and folder names are not used. A later/current visual-state snapshot is
retained only as provenance.

## Display-only evidence

Output:

`appearance_diagnostics/FSAP1_20260806T192447Z`

The review contains one BF/DF representative for each exact product plus
preceding-MoveIn context. All thumbnails are display-only reductions of the
sealed native lossless sources. The manifest records the native source path,
hash, dimensions, scan timestamp, preceding and next Insite context, and
explicitly records that native detector scoring was not performed.

## Provisional appearance observations

| Product | Last Insite context before scan | Observed frontside appearance |
|---|---|---|
| `1480861/A00` | `BOW COMP DEP / POST WAFER BOW MEASURE` | visually unpatterned |
| `1480861/A00` | `CONTACT PRE FIDUCIAL PATTERN / SORT_DBSP_S04` | visually unpatterned |
| `1491551/A00` | `CONTACT PRE FIDUCIAL PATTERN / INSPECT` | visibly patterned |
| `1491551/A00` | `FIDUCIAL OVERLAY / MEASURE` | visibly patterned |
| `1491551/A00` | `P-METAL OL AND CD MEASURE / MEASURE` | visibly patterned |
| `1509314/A00` | `PVA2 OL AND CD MEASURE / MEASURE` | visibly patterned/dielectric |

This demonstrates that `CONTACT PRE FIDUCIAL PATTERN` is not one appearance
class. The `1480861/A00` scans occurred before photo pretreat, while the
`1491551/A00` `INSPECT` scan visibly contains repeating product structure.
The operator's process interpretation is that this `INSPECT` step is the
human inspection point for the pre-fiducial pattern. That interpretation is
consistent with both the image and the preceding Insite photo sequence.

These observations identify states already represented by the current images;
they do not infer the first patterned step between scans. A step such as
`EXPOSE` or `DEVELOP` cannot be declared the boundary without an acquisition
at that state or equivalent bounded evidence.

## Consequences

- Retain the earlier CONTACT target-excluded/grid artifacts only as display
  history. Their weak periodic registration must not be described as a failed
  die-grid alignment test for the visually unpatterned members.
- Build frontside reference cohorts from exact product, scan-time Insite
  context, acquisition profile, and observed appearance state—not recipe or
  later/current MES labels.
- Treat entry into the pattern-forming sequence as `POTENTIALLY_PATTERNED`
  until BF/DF appearance and complete surrounding history exclude an
  interrupted, breakage, rework, or engineering-scan intermediate state.
  Potentially patterned wafers cannot contribute to either reference cohort.
- Use an unpatterned surface method for supported unpatterned cohorts.
- Require product-pattern registration and target-excluded composites for
  supported patterned/dielectric cohorts.
- Hold any acquisition whose scan-time context is incomplete or whose actual
  appearance conflicts with its proposed cohort.

## Frozen safety state

- `reviewOnly = true`
- `nativeDetectorScoringPerformed = false`
- `goldenPromoted = false`
- `trainingEligible = false`
- `xmlEligible = false`
- `productionEligible = false`
- `jbodFrontsideProcessingEnabled = false`
