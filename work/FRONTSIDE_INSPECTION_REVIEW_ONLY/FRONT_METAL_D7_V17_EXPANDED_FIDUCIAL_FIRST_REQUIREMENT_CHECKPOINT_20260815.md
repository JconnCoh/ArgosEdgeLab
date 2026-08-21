# Front-metal D7 V17 expanded-fiducial-first requirement — 2026-08-15

## Authority

- Revision: `FM7V17R5P20_EXPANDED_FIDUCIAL_REQUIREMENT`
- Parent: `FM7V17R5P20_ROBUST_ALIGNMENT_REQUIREMENT`
- Disposition: `LOCKED_INPUT`
- Operator observation: the exposed wafers do not show damaged or missing
  fiducials; search for additional alignment fiducials before issuing holds

## Clarification

The current alignment engine searches only four fixed fields: S26, S25, S31,
and S20. It has not performed a broader full-wafer search for additional
topology-matched fiducials. The exposed S14/S21/S23 failures are single L02
direct-support gaps while identity and local pose still pass. This evidence
does not establish missing or damaged fiducials and is insufficient to justify
treating the wafers as unalignable.

Robust alignment must therefore use redundant fiducial discovery and
consensus before any leave-one-edge fallback or target alignment hold.

## Required method boundary

1. Generate additional expected fiducial locations from the locked target
   lattice and macro wafer geometry, not from peer pass/fail outcomes.
2. Qualify those locations on the target using the same seven-component
   identity and six observed straight-edge model at native resolution.
3. Freeze the target-qualified site set before evaluating peer eligibility.
4. Solve BF and DF independently at every frozen site.
5. Form a distributed no-scale rigid consensus from directly qualified sites;
   one local weak segment must not invalidate a whole wafer when enough other
   independently observed, spatially distributed fiducials qualify.
6. Require explicit minimum site count, spatial/quadrant distribution, identity
   support, rigid RMS, and mapped-control stability. A genuinely insufficient
   consensus remains an explicit alignment hold, never a silent skip.
7. Keep the five-edge leaveout method only as a separately reported last-resort
   stability diagnostic. Do not use iterative residual minimization to remove
   observations until a desired pass appears.

Additional-site discovery must not use defects, appearance residuals, the
operator-identified darker-green perimeter crescent, a fixed notch angle, or
peer reference eligibility. It must not change source pixels, line thresholds,
the accepted fiducial model, scale, detector evidence, masks, M3, V16, reviewer,
XML, or production authority.

## Current state

No expanded search has yet been executed. R5P20 remains diagnostic only and
`NO_FIXED_ALIGNMENT_ADJUSTMENT` remains controlling. The next artifact is a
fresh native-pixel expanded-fiducial diagnostic whose site-selection record is
separate from peer scoring and whose output explicitly reports whether every
wafer obtains a robust BF/DF pose.
