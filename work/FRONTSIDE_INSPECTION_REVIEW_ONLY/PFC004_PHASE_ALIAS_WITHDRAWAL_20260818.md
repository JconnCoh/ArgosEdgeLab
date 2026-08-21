# PFC004 phase-alias withdrawal

Date: 2026-08-18

Revision: `PFC004_FIDUCIAL_ZOOM_V1_20260818`

Disposition: `WITHDRAWN`

## Operator rejection

The operator rejected the presented close view as not close to the intended
fiducial. The exact text-only rejection and bounded diagnosis are locked as
`PFC004_OP5`; its JSON SHA-256 is
`4320033C859F0BD1D5B6C820535438814FB1CA388CC5E6A543E38804619372ED`.

The OP4 screenshot remains preserved as operator input. Its earlier
screenshot-to-V2 coordinate mapping is not location authority.

## Diagnosis

The screenshot was registered against a repeating patterned grid by global
normalized correlation. The accepted correlation was 0.95278105, while the
second candidate was 0.95161983: a margin of only 0.00116122. That result was
not unique and selected the wrong lattice phase.

A bounded check between the chosen V2 location and the rendered BF zoom gave
0.98579806 correlation. This confirms that the zoom renderer reproduced the
chosen location; the failure occurred upstream when a non-unique repeating-
grid match was treated as a unique location.

The following derived values are invalid and must not be reused:

- V2 center `(1166, 696)`;
- native-crop center `(1090.7488, 1318.9680)`;
- full-wafer center `(7182.7488, 5973.9680)`;
- the proposed five-pixel inset;
- the proposed five-pixel endpoint trim.

`PFC004_FIDUCIAL_ZOOM_V1_20260818` is therefore withdrawn. Its files remain
preserved for audit and must not be patched, presented, or promoted.

## Restored gate

Current phase is `PFC004_FIDUCIAL_LOCATION_PHASE_ALIAS_HOLD`.

Before another crop is produced, the location must be selected in the exact
same saved pixel frame as the locked straightened BF image, or confirmed using
explicit nonrepeating topology that cannot alias by one or more die periods.
A screenshot-to-source global repeating-grid correlation is prohibited from
providing native location authority.

The safest next operator handoff is a fresh feedback copy of the exact locked
straightened BF PNG, opened at 100% and saved in place after the small square
is drawn. The saved marked PNG can then be compared pixel-for-pixel with its
clean parent, eliminating browser/window scale, crop, and phase ambiguity.
Only after that exact-pixel selection is locked may a fresh native BF/DF close
crop be built and shown. Edge detection remains blocked until the operator
confirms that close crop and its inward/corner exclusion.

No edge detection, fit, template, distributed phase, alignment transfer,
defect scoring, Normal outcome, training truth, XML, or production authority
was created. R5P30 remains immutable.

The unresolved prerequisite order remains unchanged: 11 `PENDING_GATE`
objects, the other 30 category rows, 20 other crop-ready designations, one map
hold, and nine pose holds remain ahead of production-wafer scoring.
