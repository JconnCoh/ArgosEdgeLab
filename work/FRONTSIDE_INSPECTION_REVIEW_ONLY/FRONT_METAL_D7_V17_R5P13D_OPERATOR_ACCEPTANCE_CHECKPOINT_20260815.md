# Front-metal D7 V17 R5P13D operator acceptance checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P13D_FEEDBACK`

Disposition: `LOCKED_INPUT`

## Operator decision

The operator reviewed
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P13D/POSE_PHASE.png`
and responded: `nice, ok this is basically perfect`.

This is explicit visual acceptance of the R5P13D full-orthogonal registration
geometry for the next bounded review-only composite diagnostic. It accepts:

- the S26-only channel-local first-transition model definition;
- separate BF and DF rigid X/Y/theta solutions;
- unchanged physical measurement/search anchors;
- corrected model coordinates for all six sustained orthogonal boundaries;
- S25, S31, and S20 as held-out validation sites; and
- continued retention of S26 BF L02 at 74/78 as a bounded non-autonomous
  exception.

## Authorized next bounded step

One topology-matched, target-excluded, channel-specific BF/DF composite may be
built and sampled into the unchanged native live frame. Its bounded review
must compare:

- T16 scratch response and normal-edge overkill;
- T17 faint low-amplitude evidence without inventing a complete line; and
- nearby structurally normal edges and null/pattern transitions.

The composite must not include its target image in its own reference. BF and
DF references and live poses remain independent. No raw image may be resampled
before scoring; only the reference may be sampled into the unchanged target
frame. No detector threshold, mask, classifier, saved feedback, or inspection
authority changes through this authorization.

## Separate stitch concern

The operator's possible Argos internal stitch-fault concern remains separate
and unevaluated. It may later produce fail-closed `STITCH_GEOMETRY_HOLD`, but
it must not be mixed into the bounded composite or used to change the accepted
fiducial geometry.

## Accepted evidence

- R5P13D audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P13D/AUDIT.json`
  (`1BF65512AB0428DDCB9E41B936932324A5D1B524921863280995EFF9159FE1ED`);
- R5P13D sheet:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P13D/POSE_PHASE.png`
  (`09EDC8528FF03A084113CC78C19CEC522565C0A7842FA7507300AC268DD832EC`);
- governing numerical checkpoint:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/FRONT_METAL_D7_V17_R5P13D_FULL_ORTHOGONAL_EDGE_CHECKPOINT_20260815.md`
  (`58CAFB0589303E535E8DCAA2240FFA622C72915CA72B3797E11BF39C764FA9D5`).

No pose or reference was applied by this acceptance itself. XML, JBOD, and
production routing remain disabled. Deferred stroke 278 and the strict
frontside chipout sibling remain unchanged.
