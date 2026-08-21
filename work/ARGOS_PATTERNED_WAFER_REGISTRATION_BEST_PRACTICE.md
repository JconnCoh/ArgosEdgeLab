# Argos patterned-wafer registration best practice

Date: 2026-08-15

Revision: `PATTERNED_WAFER_REGISTRATION_BP_V1`

Disposition: `APPROVED_BASELINE`

Authority: operator-approved current best practice for review-only patterned-
wafer registration development. It is not autonomous production-registration,
XML, detector-mask, or reject authority.

## Purpose

Establish the absolute patterned-wafer coordinate frame before constructing a
reference composite or inspecting residuals. The method is designed to prevent
whole-die/PM phase slips and the patterned-die/null-die ghost mixing exposed in
front-metal V17.

Fiducial topology designation, automatic line calibration, and frozen
validation are governed by `work/ARGOS_FIDUCIAL_MODEL_WORKFLOW.md`, SHA-256
`5CAA6FF17EE916B358427A21CC525B9B4F780F19A0FAC295F4EE41F7001E8CCC`,
and `work/ARGOS_FIDUCIAL_MODEL_WORKFLOW.json`, SHA-256
`265617A5115C08C430752631E40B2940BB6EC663530DCC68098F0B6F0E8A4095`.
That workflow is a prerequisite to the registration hierarchy below.

## Required hierarchy

1. Use the physical wafer notch to establish macro wafer orientation and
   handedness. Do not select the deepest indentation or the candidate nearest
   a fixed image angle; retain the governing frontside notch-competitor rules.
2. Use product/map evidence only to nominate bounded search regions unless the
   exact product's bin semantics have been independently qualified.
3. Identify one specific nonrepeating fiducial by its full local topology.
   Identity-only curved/circular elements may disambiguate the structure, but
   they do not carry pose weight when their native-pixel edges are soft.
4. Solve X, Y, and theta from sustained, high-contrast straight boundaries in
   both orthogonal directions. Use the first stable physical boundary from
   geometric outside toward the dark interior, not an interior intensity ridge.
5. Repeat the same identity and pose measurement at enough distributed
   fiducials to reject any whole-die or whole-PM X/Y phase slip and to expose
   field-dependent pose variation.
6. Assign die/PM topology only after the multi-site absolute phase check passes.
7. Construct BF and DF references independently from target-excluded peers of
   the same qualified structural class: null with null, patterned with
   patterned, and like PM topology with like PM topology.
8. Sample each reference into the live channel's native frame. The live raw
   image remains unchanged and is never resampled for scoring.

## Channel and resolution contract

- BF pose is measured from BF only and is used for BF.
- DF pose is measured from DF only and is used for DF.
- BF/DF agreement is a diagnostic cross-check, never a reason to average or
  force the two transforms together.
- Pose evidence and inspection scoring use original lossless native pixels at
  scale X=1 and scale Y=1. Downsampled, rotated, stretched, or curve-adjusted
  images are display-only.
- Reference warping/sampling may map a qualified reference into the live native
  frame; it must not modify or resample the live source image.

## Fiducial geometry contract

- Retain the smallest local model that uniquely identifies the fiducial.
- Prefer long, thin, continuous straight boundaries for theta and translation.
- Require straight evidence in both orthogonal directions.
- Soft curves and circles have zero pose weight when they cannot produce a
  thin, continuous native-pixel boundary. They may remain identity-only.
- Exclude faint internal lines or secondary ridges that can pull the fit away
  from the first stable outer high-contrast boundary.
- A broken, thick, doubled, or laterally bouncing line is a hold, not a line to
  fill or smooth into existence.

The front-metal V17 accepted implementation uses six straight boundaries: two
long-bar edges and four orthogonal side-feature edges. Four circle/stem
components are identity-only and have zero fit weight. This specific geometry
is a qualified example, not a claim that every product uses the same shape.

## Fail-closed quality gates

Every channel/site fit records at least:

- fiducial identity and bounded search region;
- direct line-support fraction;
- maximum unsupported gap;
- fit residual;
- response width/thickness;
- translation and theta;
- distance from every nonzero whole-die/PM phase alias; and
- multi-site phase/topology consistency.

Weak identity, insufficient direct support, excessive gaps, thick response,
poor residual, inconsistent distributed poses, or an unresolved die/PM alias
must stop the reference build. Do not widen into an adjacent PM, choose the
brightest/darkest-looking phase, or use a local repeating-pattern correlation
to manufacture absolute phase.

The accepted V17 lineage retains the S26 BF lower-bar result of 74/78 direct
samples (94.87%) and four isolated one-pixel gaps. Operator acceptance permits
that geometry to enter a bounded diagnostic; it does not silently make the
fixed 95% numerical gate an autonomous pass.

## Composite contract

- Exclude the live target from every reference.
- Use only peers whose identity, channel pose, absolute phase, and topology
  pass their gates.
- Combine peers robustly per channel, preserving provenance for every source.
- More peers may reduce random speckle, mild discoloration, and sensor/wafer
  texture only after registration and topology are correct. More images cannot
  repair a phase error and can make a wrong composite more confidently wrong.
- Normal product boundaries should cancel substantially in the residual.
  A physical scratch remains because it is absent from the target-excluded
  reference; this must still be verified against bounded positive and normal-
  edge controls rather than inferred from the method.

## Product-map and older-product handling

Newer products may expose fiducial bins such as 34/36, but bin identity is not
universal. For an older clone product, the map pair may only nominate where a
known PM structure should occur. Image-derived topology and multi-site phase
consistency remain mandatory. The bottom scribe PM may be an expected-absence
exception and must be recorded explicitly rather than treated as a failed
fiducial.

## Provenance and authority

Record source paths, hashes, dimensions, channel, crop origins, transforms,
fit metrics, peer inclusion/exclusion, structural class, phase result, and
reference lineage. A diagnostic output does not change detector masks,
thresholds, classifier authority, saved feedback, reviewer state, XML, or
production routing. Promotion beyond review-only registration requires a
separate transfer and release gate.
