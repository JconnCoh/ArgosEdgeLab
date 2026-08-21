# Front-metal D7 V17 R5P1 operator-feedback checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`

This is the continuation authority after operator review exposed a limitation
in the R5P1 peer-separation sheet and, more importantly, in R5's per-pixel
neighborhood matching. R5P1 remains useful evidence of the actual R5
reference construction, but it is ineligible to adjudicate rigid die-grid
phase.

## Operator review

The operator reports that all three displayed peer contributions and the
median show patterned-die and null-die structure combined into a fuzzy result
at the die above the null. The softness of the white die and gray response in
the die "river" indicate mixed registration. The operator's working
hypothesis is that two peer images are shifted by one die in Y.

## Confirmed cause of the R5P1 softness

R5P1 did not display each peer under one rigid registration. It faithfully
replayed R5's common one-pixel BF/DF neighborhood choice independently at
every target pixel. Only `14101/163068` pixels (`8.647%`) used offset `(0,0)`;
`148967/163068` pixels (`91.353%`) selected one of the eight shifted
alternatives. Adjacent pixels can therefore come from different translations
of the same peer. That creates a registration mosaic and can soften, duplicate,
or ghost recurring die structure exactly as the operator observed.

The stored S03, S13, and S18 peer inputs are not composited rasters. Their
tile validation records assert original native 1:1 BF/DF, `rawBfDfPreserved`
true, and `resampling` false. Their native tile origins are respectively
`(4137,5618)`, `(4134,5617)`, and `(4155,5613)`. The fuzz was introduced by
the R5 reference-selection method and its replay, not baked into those peer
source files.

## Consequences

The operator's one-die-Y hypothesis remains plausible because the repeating
die lattice can give a strong correlation at the wrong periodic peak. R5P1
cannot identify which two peers are phase-shifted because the displayed
contributions already mix nine local offset choices. No peer may be rejected
from R5P1.

R5's per-pixel neighborhood step is not qualified for structural
correspondence or false-edge suppression. The T16 observation that the
physical Scratch remains very visible is retained as diagnostic sensitivity
evidence, but R5's false-response improvement and T17 low-amplitude appearance
must not be treated as calibrated detector evidence. The ghost can contaminate
the apparent upper-right T17 trace.

R5 and R5P1 remain `DIAGNOSTIC_ONLY`; neither becomes a parent for reviewer or
mask work. Their artifacts are preserved rather than overwritten.

## Smallest valid next diagnostic

If authorized, create a fresh peer-phase sheet directly from each original
native peer crop:

- use one coherent integer registration per peer for the entire review crop;
- disable the per-pixel neighborhood chooser and blockwise offset switching;
- show the current correlation peak and the adjacent Y lattice peaks
  separately after measuring the actual die pitch;
- show BF and DF for target, S03, S13, and S18 with a shared channel stretch;
- use null-die/patterned-die topology only to qualify grid phase, not as defect
  pixels or Normal truth;
- stop for operator review before selecting a peer phase or rebuilding a
  composite.

Only after coherent phase qualification may smooth local alignment be added,
and it must preserve one continuous displacement field rather than choose the
best offset independently per pixel.

## Preserved state and next action

The T17 reference remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`.
Stroke 278 remains deferred. Source/current masks, thresholds, M3, V16,
XML/production state, JBOD state, and the strict chipout sibling remain
unchanged.

Explain the confirmed neighborhood-mosaic cause and await operator direction.
Do not create the rigid phase sheet, select or reject a peer phase, rebuild
the composite, add peers, perform raw-feature scoring, tune/promote R5,
inspect stroke 278, build/present V17, run raster smoke, package JBOD, emit
XML, enable production routing, or alter the strict chipout sibling before
that direction.
