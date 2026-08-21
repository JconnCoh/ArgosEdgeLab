# Front-metal D7 V17 R5P12A operator-acceptance checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P12A_FEEDBACK`

Disposition: `LOCKED_INPUT`

## Operator decision

The operator reviewed
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P12A/NATIVE_STRAIGHT_EDGES.png`
and responded that it looks good. The operator explicitly accepted omission
of the soft curved edges at this resolution, provided the registration model
contains straight lines for both horizontal and vertical alignment. This
matches the operator's established fiducial practice shown in the original
tool example.

The accepted bounded geometry is:

- the two long-bar edges provide the strongest constraint normal to the bar
  and strong theta leverage from their length;
- the four orthogonal side-feature edges constrain the other translation
  direction and cross-check theta;
- the four circle/stem components disambiguate fiducial identity only; and
- soft curved edges have zero registration weight.

R5P12A is accepted for a future bounded registration diagnostic. This does
not silently convert its fixed S26 BF `74/78` numerical row into an autonomous
95%-gate pass. The visual acceptance and the recorded numerical exception
must both remain in lineage. No pose has yet been recomputed or applied.

## How the anchor can be used

The approved geometry provides an absolute nonperiodic anchor inside the PM,
which resolves the failure mode that allowed a patterned die and null die to
be combined one die apart. The intended staged use is:

1. notch-derived macro wafer orientation;
2. fiducial identity from the dark component arrangement;
3. independent native BF and DF rigid pose from the accepted orthogonal
   straight lines;
4. multiple fiducial observations across the wafer to reject any whole-die
   X/Y phase slip and estimate field-level translation/theta variation;
5. target-excluded, topology-matched BF and DF reference composites built in
   their own coordinate frames; and
6. live inspection by sampling each channel's reference into the live native
   pixel frame while leaving the live raw pixels unchanged.

The expected detector benefit is sharper reference edges, removal of
patterned/null ghost mixing, and substantially lower residual response on
normal product boundaries. A real scratch remains because it is absent from
the target-excluded reference. More peer wafers can then reduce random
texture, discoloration, and speckle only after registration and structural
class selection are correct; more images cannot repair a phase error.

Every future pose remains fail-closed on fiducial identity, direct line
support, residual, gap, width, and whole-die phase consistency. BF and DF
must retain separate transforms. No curved edge may be restored as fit
evidence without new operator approval.

## Preserved authority

- This checkpoint records operator input; it does not apply a transform.
- The S26 BF numerical exception remains documented.
- T17 remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED` until a bounded
  channel-pose and topology check is completed.
- No reference composite, detector response, mask, threshold, classifier, or
  review disposition changed.
- Deferred stroke 278 remains unevaluated.
- V16 remains the released review-only reviewer.
- V17 remains `PENDING_GATE`; no V17 reviewer is presented.
- XML and production routing remain disabled.
- The strict chipout sibling remains unchanged.
