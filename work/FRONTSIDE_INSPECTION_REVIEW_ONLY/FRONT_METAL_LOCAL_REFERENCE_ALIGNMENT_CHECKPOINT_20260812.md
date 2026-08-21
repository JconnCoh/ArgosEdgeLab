# Front-metal local reference-alignment checkpoint — 2026-08-12

State: `IN_PROGRESS_REVIEW_ONLY`

The target-excluded front-metal peer composite is globally pose/grid aligned,
but a single translation per 2400 x 2000 native field does not remove local
stitch/phase displacement of the repeating die pattern. That displacement
causes intact streets to appear in the residual.

The correction is limited to the reference side:

- the target BF/DF inspection pixels remain native 1:1 and are never resampled;
- every physical target wafer remains excluded from its own reference;
- each peer reference receives a bounded, recorded local displacement field
  after the existing wafer-pose and global fine-shift alignment;
- peer agreement, not grid size, pitch, direction, or recurrence, remains the
  only patterned-background suppression authority;
- raw BF/DF remain the final footprint/size authority;
- unsupported gaps stay empty;
- scribe, holder, boundary, and the existing chipout branch remain unchanged;
- all outputs remain review-only, training-ineligible, XML-ineligible, and
  production-ineligible.

No new operator-review page is allowed until the saved 70 positive / 4 false
stroke audit and explicit repeating-grid controls pass the bounded regression.

