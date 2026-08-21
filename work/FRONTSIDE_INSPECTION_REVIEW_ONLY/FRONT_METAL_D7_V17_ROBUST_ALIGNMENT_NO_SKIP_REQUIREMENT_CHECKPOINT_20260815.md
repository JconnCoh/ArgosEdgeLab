# Front-metal D7 V17 robust-alignment no-skip requirement — 2026-08-15

## Authority

- Revision: `FM7V17R5P20_ROBUST_ALIGNMENT_REQUIREMENT`
- Parent: `FM7V17R5P20_JBOD_RESULT`
- Disposition: `LOCKED_INPUT`
- Operator requirement: every wafer must be inspected; reference-peer
  exclusion must not become target-wafer inspection exclusion

## Requirement

The operator rejected an inspection workflow that simply omits a wafer when
one fiducial segment does not meet the primary direct-support gate. A wafer may
be excluded from voting in another wafer's reference composite, but that does
not qualify its own target pose and must not cause its inspection to be
silently skipped.

Every target wafer must follow one of two explicit outcomes:

1. obtain a qualified pose through the primary alignment path or a separately
   validated robust fallback and continue inspection; or
2. emit a visible fail-closed alignment hold when no pose can be qualified.

Normal, Reject, or defect-negative authority must never be emitted from an
unqualified transform. A hold is not a skipped wafer: it is an explicit
required-engine result that prevents a false pass and requests resolution.

## Bounded robust-fallback direction

The exposed S14/S21/S23 failures are not gross rigid-pose failures. All failed
sites have `posePass=true`; each failure is localized to L02 direct line
support while the other five accepted orthogonal boundaries remain available.
The robust alignment correction must therefore be evaluated at the segment
level before considering whole-site or whole-wafer exclusion.

The fallback must be predeclared and fail closed. It may use the other five
directly supported edges only when:

- exactly one segment fails the primary evidence gate;
- the remaining edges retain both orthogonal directions and nonrepeating
  fiducial identity;
- the alternate pose is recomputed from observed native pixels, not inferred
  from proximity or a fixed expected angle;
- the all-edge and leave-one-edge mapped transforms are compared at the
  fiducial sites, wafer perimeter, and bounded T16/T17 controls;
- maximum mapped displacement stays within a frozen, regression-qualified
  tolerance;
- BF and DF remain independently solved and each channel establishes its own
  eligibility; and
- any competing leaveout, multi-segment failure, insufficient identity, or
  unstable mapped transform remains an explicit alignment hold.

This is not permission to repeatedly remove whichever observation produces
the lowest residual. The selection rule and tolerance must be fixed before a
future blind gate. It is also not permission to loosen L02 support thresholds,
fill unsupported gaps, apply a global alignment correction, or convert a held
wafer to Normal.

## Current state

R5P20 remains diagnostic only. Its decision
`NO_FIXED_ALIGNMENT_ADJUSTMENT` remains valid. No target pose, reference peer,
detector, mask, threshold, T16/T17, reviewer, XML, or production authority is
changed by this requirement. The next engineering artifact is a bounded
robust-alignment validation package, followed by a separate blind transfer
gate before autonomous inspection authority.
