# Front-metal composite-authority correction checkpoint — 2026-08-12

## Disposition

`FRONT_METAL_RAW_NATIVE_RESULT_REVIEW_V1_20260812T045000Z` is
`WITHDRAWN_PATTERN_OVERKILL`.

The operator review exposed broad yellow acceptance of recurring die/grid and
edge texture. This is detector overkill, not a coordinate-display problem and
not an approved front-metal result. Preserve the files for audit, but never
present, promote, package, or use their accepted masks as detector truth.

## Root cause

The target-excluded periodic-peer/composite evidence was generated, but the
accepted-footprint candidate expression allowed an auxiliary local raw-change
branch to bypass it:

`(compositeLocalized AND rawSupported) OR rawChangeQualified`

The second branch made target-minus-composite evidence optional. On recurring
front-metal geometry it admitted normal die/grid texture. For example,
`T02_R00C01` contains 574,280 accepted pixels in a 2400 x 2000 field while
only 276 pixels were classed Scratch. The previous 70/70 positive-path and
4/4 scribe-control audit did not include a broad clean recurring-pattern
negative gate and was therefore insufficient.

## Locked correction contract

1. Register native target pixels to a target-excluded same-family peer
   composite.
2. Candidate formation begins only from target-minus-composite residual.
3. Apply sparse low/high hysteresis to residual pixels; a low-threshold
   component must contain an independent high-threshold seed.
4. Raw BF/DF confirms physical presence and defines exact footprint, size,
   and affected die. Raw change cannot independently create an accepted
   candidate.
5. Enhanced or strict-zero-peer evidence remains localization-only.
6. Do not suppress components merely because their size, pitch, direction, or
   recurrence resembles the grid. Suppression must follow from composite
   agreement or another explicit physical-evidence rule.
7. Preserve unsupported gaps as empty; never infer a complete line.
8. The frozen frontside chipout branch remains unchanged and independent.

## Required gates before another operator reviewer

- locked positive-path coverage audit;
- four exact scribe-control exclusions;
- holder and physical-boundary exclusions;
- broad clean recurring-pattern overkill audit across every selected native
  field, not only small controls;
- raw BF/DF footprint audit for size and affected-die authority;
- canonical BowComp-derived reviewer hash/control gate.

No replacement reviewer is ready at this checkpoint. Work remains review-only,
training-ineligible, XML-ineligible, and production-ineligible.
