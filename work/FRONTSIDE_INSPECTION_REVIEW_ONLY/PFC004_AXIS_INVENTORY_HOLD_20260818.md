# PFC004 axis-line inventory completeness hold

Date: 2026-08-18

Revision: `PFC004_AXIS_ONLY_MODEL_V1_20260818_INCOMPLETE`

Disposition: `WITHDRAWN`

## Operator finding

The operator reports that the expanded crosshair approach is closer but the
presented six-segment model does not contain all straight lines. Therefore the
six-line geometry is incomplete and is withdrawn as a same-wafer test model.
The diagnostic files remain preserved and may not be promoted or used as the
complete candidate inventory.

The exact text feedback and bounded diagnosis are locked as `PFC004_OP9`.

## Diagnosis

The prior extractor required raw axis runs of at least eight pixels and then
removed two pixels from each endpoint. On the exact exemplar, the broader
four-pixel run inventory contains 14 horizontal/vertical runs, but those
settings retained only six. Testing the frozen six-line model cannot recover
the omitted lines because the line finder evaluates only seeded model
segments.

## Required recovery

Current phase is `PFC004_AXIS_LINE_INVENTORY_INCOMPLETE_HOLD`.

Before same-wafer testing, create a fresh high-recall inventory containing all
plausible horizontal and vertical runs in the enlarged crosshair ROI. Apply a
tiny corner ignore without prematurely discarding short straight boundaries.
Separate fit-eligible support from short identity/confirmation-only segments.

Then run native 1:1 BF and DF fits independently over a bounded same-wafer
development set and untouched holdout set. Testing decides which inventoried
lines have stable direct support; it does not invent missing model geometry.
Weak or missing per-channel lines remain explicit holds. Do not tune on the
holdout set, and do not begin multi-wafer fanout until the fixed same-wafer
holdout passes.

No native edge detection, same-wafer test, template authority, distributed
phase, alignment transfer, multi-wafer fanout, defect scoring, Normal outcome,
training truth, XML, or production authority has been created. R5P30 remains
immutable. The 11 unresolved `PENDING_GATE` objects, other 30 category rows,
20 other crop-ready designations, one map hold, and nine pose holds remain in
their existing prerequisite order.
