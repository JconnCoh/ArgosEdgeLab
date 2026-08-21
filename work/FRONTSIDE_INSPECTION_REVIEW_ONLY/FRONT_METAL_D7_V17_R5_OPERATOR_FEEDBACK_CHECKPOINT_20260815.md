# Front-metal D7 V17 R5 operator-feedback checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`

This is the continuation authority after operator review of both R5 sheets.
It records the surviving T16 sensitivity, remaining false response, the T17
method miss, and the newly exposed null-die reference-correspondence concern.
It does not authorize a new run or promote R5 pixels.

## Operator review

For T16 stroke 238, the operator reports:

- the physical Scratch remains extremely visible in the top 10%, 5%, and 2%
  class-neutral overlays;
- no residual misalignment is visually apparent, subject to the limits of
  human review;
- some false-kill edge response remains at the top 2%;
- a top-1% full-wafer rule is concerning because it could still create
  substantial overkill.

For the T17 field-10 feature, the operator reports:

- the faint trace is not visible in the unedited standard signed-residual
  panels;
- it is visible in both display-only low-amplitude panels;
- it is absent from the class-neutral residual heatmap;
- a ghosted patterned die appears over the null die in the target-excluded
  reference, and it may contaminate the upper-right end of the faint trace.

The T17 class remains `CONFIRM_SCRATCH_OR_RESIDUE`.

## Interpretation

T16 establishes that the bounded R5 reference matching preserved strong
Scratch sensitivity while removing the visually obvious paired-edge
misalignment. The remaining top-2% edge response is therefore more likely to
be recurring product-edge appearance variation or wrong structural reference
correspondence than a simple one- or two-pixel shift. This is an inference,
not autonomous false-pixel truth.

A global percentile is not a viable final full-wafer operating rule. At the
native `14411 x 10995` full-frame dimensions, exactly 1% is approximately
1,584,489 pixels or 333.139 square millimetres at 14.5 micrometres per pixel.
A top-1% rule selects that burden by construction even when every remaining
pixel is normal. Percentile panels remain diagnostic ranking views only.

More target-excluded composites can reduce random speckle and wafer-to-wafer
variation only after structural correspondence is qualified. Blindly adding
peers can strengthen a wrong patterned-die reference over a null die. Tighter
subpixel alignment cannot repair a one-die phase or structural-class mismatch.

The R5 local-grid record is consistent with the operator's concern. In the
upper-right T17 region, blocks above the affected band correlate at roughly
0.92-0.97, while blocks crossing columns 7-8 of local row 2 fall to roughly
0.30-0.60 for all three peers. Much of that row intersects the
operator-excluded band, so the values do not prove the cause, but they do show
that this local reference is not qualified to adjudicate the upper-right
trace. The ghost may affect its apparent low-amplitude contrast and must be
removed before interpreting that segment.

T17 remains a miss for the R5 detector family. Visibility in the
`DISPLAY_ONLY` low-amplitude views is useful localization evidence, but it is
not heatmap support and must not be converted into a dark-residual detection
rule.

## Smallest justified next direction

If the operator authorizes another bounded diagnostic, the next step should
not be a top-1% cutoff. It should:

1. expose the three T17 peers separately at the null-die/trace region to
   identify which peer or die-grid phase contributes the ghost;
2. require die-grid phase and local structural-class agreement before a peer
   patch can enter the median reference; a null-die target must not be
   compared with a patterned-die patch;
3. add more target-excluded peers only after that eligibility gate, use robust
   median/MAD consensus, and emit a coverage hold when too few compatible
   peers remain;
4. retain an absolute score calibrated from target-excluded peer-versus-peer
   controls rather than selecting a fixed full-wafer percentage;
5. evaluate the T17 raw BF and DF local feature response against the qualified
   peer feature-response distribution, independently by channel and without
   using low-amplitude display pixels as detector truth;
6. keep T16 as the sensitivity anchor and retain only observed connected
   response; do not infer a complete scratch line or broadly mask product
   edges.

This separates three problems: correspondence, calibrated anomaly magnitude,
and scratch-like connected geometry. It is not permission to declare
recurring structure Normal, erase all die edges, or use recurrence alone as
negative truth.

## Preserved state and next action

R5 remains `DIAGNOSTIC_ONLY`. Stroke 278 remains deferred. Source/current
masks, thresholds, M3, V16, XML/production state, JBOD state, and the strict
chipout sibling remain unchanged.

Explain this interpretation and await operator direction. Do not start the
peer-separated/null-die correspondence audit, add composites, tune a cutoff,
perform the raw feature-response comparison, promote pixels, inspect stroke
278, build/present V17, run raster smoke, package JBOD, emit XML, enable
production routing, or alter the strict chipout sibling before that direction.
