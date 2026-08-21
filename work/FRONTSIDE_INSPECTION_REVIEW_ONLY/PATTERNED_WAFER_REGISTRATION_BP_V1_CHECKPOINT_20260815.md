# Patterned-wafer registration best-practice V1 checkpoint

Date: 2026-08-15

Revision: `PATTERNED_WAFER_REGISTRATION_BP_V1`

Disposition: `APPROVED_BASELINE`

## Operator decision

The operator directed that the accepted patterned-wafer alignment method be
saved as the current best practice and that bounded front-metal V17 work
proceed from it.

The authoritative human-readable contract is:

`work/ARGOS_PATTERNED_WAFER_REGISTRATION_BEST_PRACTICE.md`

SHA-256:

`E32FAF9F0EC7735C2DE668C1B49E2E52597F69B77E54CA26FA774596898936DF`

The machine-readable companion is:

`work/ARGOS_PATTERNED_WAFER_REGISTRATION_BEST_PRACTICE.json`

SHA-256:

`FE436D5BEC5D2497B2D5AB06B5180FF371C20A330493A3AF476EDA204381183A`

## Frozen method

- notch establishes macro orientation and handedness;
- the product map nominates bounded search areas unless exact bin semantics
  are independently qualified;
- full local topology identifies one specific nonrepeating fiducial;
- sustained straight boundaries in both orthogonal directions solve pose;
- BF and DF retain independent native-pixel transforms;
- soft curves have zero pose weight and may remain identity-only;
- several distributed fiducials reject whole-die/PM phase slips;
- only target-excluded peers with the same qualified topology enter a robust
  channel-specific reference; and
- each reference is sampled into the unchanged live native channel frame.

The S26 BF lower-bar lineage remains 74/78 direct samples (94.87%) with four
isolated one-pixel gaps. Operator acceptance allows a bounded diagnostic but
does not turn that numerical exception into autonomous production authority.

## Next bounded gate

Run one independent BF/DF native rigid-pose and absolute die/PM phase audit at
the four accepted fiducial sites. The gate must remain file-backed, preserve
the six straight boundaries and four identity-only circle/stem components,
and report channel pose, reconstruction residual, multi-site consistency, and
distance from every nonzero die-pitch alias.

No composite may be rebuilt unless the pose/phase gate passes. If it passes,
the next allowed diagnostic is one target-excluded, topology-matched BF/DF
composite followed by bounded T16 Scratch, T17 faint-feature, and normal-edge
overkill checks.

## Unchanged authority

- No pose or die phase is yet applied.
- T17 remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`.
- No detector mask, threshold, classifier, or saved feedback changed.
- Deferred stroke 278 remains unevaluated.
- V16 remains the released review-only reviewer.
- V17 remains `PENDING_GATE`.
- XML and production routing remain disabled.
- The strict frontside chipout sibling remains unchanged.

