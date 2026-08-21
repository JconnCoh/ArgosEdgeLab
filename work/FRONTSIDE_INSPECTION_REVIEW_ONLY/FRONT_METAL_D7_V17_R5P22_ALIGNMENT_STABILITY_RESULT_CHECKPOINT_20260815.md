# Front-metal D7 V17 R5P22 alignment-stability result checkpoint

Date: 2026-08-15  
Revision: `FM7V17R5P22_RESULT`  
Parent: `FM7V17R5P22`  
Disposition: `DIAGNOSTIC_ONLY`

The predeclared R5P22 gate was applied to the exact hash-locked R5P21 return.
The result is
`PASS_FM7P22_REVIEW_ONLY_ALIGNMENT_STABILITY_ALL_12_WAFERS`.

- result:
  `work/FM7P21/result/R5P22_ADJUDICATION/R5P22_ALIGNMENT_STABILITY.json`;
- result bytes: 11335;
- result SHA-256:
  `7F34E996C53AE4B2263E0AEFFD266205C554C5B30ED27F9E6239B8B771975F9F`;
- frozen contract SHA-256:
  `DBB7220752DDF26C1E76E922F5068F7E5B1D00269241E9C0780E2534E770AB27`;
- exact R5P21 input SHA-256:
  `CE1D926D1CA1A36DB8C854998D1D82A649C80914A9204D9EAF5F5ED96753C829`;
- adjudicator source SHA-256:
  `7BC82D0C2854EABD15FDCFED50F0B1FF89FE7C4A8421182BBDBA17F8F0514486`;
- executable SHA-256:
  `E15A4EACAB84E65A9982BD70BFBF8BFDAA9948235010E22A5781B513521D434F`.

Slot02 and all eleven peer wafers support stable review-only alignment. S14,
S16, S21, and S24 change from the exact R5P21 wafer-level hold disposition to
R5P22 `alignmentStabilitySupported=true`; their local R5P21 site diagnostics
and hold reasons remain preserved in the result.

The deterministic self-test passed and proves fail-closed behavior for fewer
than six consensus sites, fewer than three consensus quadrants, rigid RMS
above 1.25 px, leave-one mapping change above 0.35 px, and BF/DF whole-wafer
mapping disagreement above 0.35 px.

R5P22 recomputed and changed no transform. It changed no direct site
qualification, chose or removed no site by final residual rank, performed no
sequential worst-site removal, used no five-edge fallback, and applied no fixed
alignment correction. R5P21 remains an unchanged diagnostic parent.

This is an exposed-data review-only semantics correction, not an independent
transfer result. It is training-, XML-, and production-ineligible. The next
inspection integration may process every wafer with its unchanged R5P21
independent BF/DF transforms under the R5P22 stability gate, but later
independent lot evidence is required before transfer authority.

No detector, mask, threshold, M3, V16, reviewer, stitch, deferred-stroke,
strict-chipout, XML, or production state changed.
