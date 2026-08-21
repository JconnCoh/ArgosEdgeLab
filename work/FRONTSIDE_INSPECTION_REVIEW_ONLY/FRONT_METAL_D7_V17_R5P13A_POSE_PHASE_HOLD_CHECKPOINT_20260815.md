# Front-metal D7 V17 R5P13A pose/phase hold checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P13A`

Disposition: `DIAGNOSTIC_ONLY`

## Result

The operator-approved patterned-wafer best practice was applied to one bounded
four-fiducial diagnostic. The exact R5P12A native straight-edge measurements
replayed byte-for-byte at the fit level. BF and DF were solved independently;
no BF/DF agreement term or shared transform was used.

The absolute identity and die-phase evidence passes:

- maximum straightened-frame correction magnitude: `0.402402 px`;
- maximum absolute theta correction: `0.350458 degrees`;
- BF four-site correction spread: `0.456267 px`;
- DF four-site correction spread: `0.401096 px`;
- minimum distance from every solution to the nearest nonzero whole-die alias:
  `65.927192 px`; and
- no adjacent PM search was performed.

The phase state is
`PASS_BOUNDED_ABSOLUTE_FIDUCIAL_PHASE_NO_NONZERO_DIE_ALIAS`.

The single-rigid-line reconstruction gate remains held. Channel/site RMS spans
`0.705543-0.805278 px`; five of eight panels exceed the frozen `0.75 px`
limit, some narrowly. P90 absolute residual spans `1.117455-1.343392 px`.
The pose state is `HOLD_SINGLE_RIGID_LINE_RMS_ABOVE_0_75PX` and the overall
result is `HOLD_BOUNDED_INDEPENDENT_POSE_PHASE`.

This cleanly separates two questions: there is no evidence of a one-die/PM
phase slip at the four accepted fiducials, but one rigid transform does not yet
reconstruct all six measured physical boundaries within the frozen residual
limit. The reference rebuild is therefore stopped.

## File-backed review gate

Review:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P13A/POSE_PHASE.png`

SHA-256:

`972AC0CE9DB2496F022EFE0E598B08EFB9613C3BA90A83297C9A4DA1EF421D46`

The sheet preserves separate BF and DF panels at all four sites:

- magenta is the exact direct accepted native edge runs; unsupported gaps stay
  open;
- green is the one-rigid-transform X/Y/theta reconstruction; and
- cyan is the prior R5P9 pose.

If green tracks the magenta runs thinly and consistently, the `0.75 px` RMS
gate may be over-tight for the real product-to-guidance geometry and a bounded
model-geometry calibration can be considered. If green visibly sits between
or outside magenta boundaries, retain the hold and do not build a composite.
No threshold is loosened by this checkpoint.

## Provenance

- audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P13A/AUDIT.json`
  (`54C8E30FC27CCCB6D074D030BA5F9A38FC0767EFC3757D8D3A66767721E0F8D4`);
- input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P13_INPUT.json`
  (`09F170F0CA70E9184E0B5D76E9398A950576F9804DC5A0C9B2DDC19F782207F3`);
- source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17IndependentPosePhaseAuditV1.cs`
  (`E13698F29D04F8102EBEC6D78AB82CF2AA388FD00E1266E09DEF83B765BE9208`);
- executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17IndependentPosePhaseAuditV1.exe`
  (`8BE71B319CC9433B5F209A02E1679119351B5F019C28A8994F3F4F9C49904043`);
- parent R5P12A audit:
  `DA29B9670A56417EE9C76A73ECF3D0542383D987EC3C2AFFB88449B5F0F80668`;
- best-practice Markdown:
  `E32FAF9F0EC7735C2DE668C1B49E2E52597F69B77E54CA26FA774596898936DF`;
- best-practice JSON:
  `FE436D5BEC5D2497B2D5AB06B5180FF371C20A330493A3AF476EDA204381183A`.

The preliminary `FM7V17R5P13` root is `DIAGNOSTIC_ONLY` and superseded only
for state wording: it conflated the rigid-residual hold with the independently
passing phase result. R5P13A uses identical measurements and numerical output
while separating `phaseState` from `poseState`.

## Preserved authority

- The S26 BF lower-bar result remains 74/78 direct samples (94.87%) with four
  isolated one-pixel gaps and is not an autonomous pass.
- No pose or phase was applied to a reference.
- No reference composite was rebuilt.
- T17 remains structurally unqualified for inspection until this pose hold is
  resolved and a later composite gate passes.
- No detector mask, threshold, classifier, or saved feedback changed.
- Deferred stroke 278 remains unevaluated.
- V16 remains the released review-only reviewer; V17 remains `PENDING_GATE`.
- XML and production routing remain disabled.
- The strict frontside chipout sibling remains unchanged.

