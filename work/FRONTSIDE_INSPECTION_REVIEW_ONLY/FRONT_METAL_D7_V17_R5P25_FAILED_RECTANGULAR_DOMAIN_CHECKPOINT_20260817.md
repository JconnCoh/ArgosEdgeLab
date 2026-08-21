# Front-metal D7 V17 R5P25 failed rectangular-domain checkpoint — 2026-08-17

- Disposition: `WITHDRAWN`
- Revision: `FM7V17R5P25`
- Output run: `FM7P25_20260817T204500Z`
- Signed request: `REQ_20260817T203153032Z_64E3FEE909E0`
- Signed response: `R_9368DCE98C10_20260817203522038_6e4e8639`
- Response state: `FAILED`
- Response ZIP SHA-256: `9F24EA8C4CC5CA887769F7C39C4FCF0DE34F59CC08E6AB10ACA23808C5D71A83`
- Response manifest SHA-256: `8786BA1685009963378343FA0D650F47DBEA44891B1B267A3C86D997E314A0C6`
- JBOD audit SHA-256 reported by the signed response: `4D98BF41101183225BAB5B2D102313FA18FAF871C6D25B2C94582ACEEAF14D79`

## Result

The package processed S02 and all 11 bounded controls, but correctly refused its PASS because BF/DF contained 14,776,320 unassigned pixels. It emitted state `HOLD_FM7P25_S02_RESIDUAL_COMPARISON_COVERAGE_INCOMPLETE` and exit code 2. No defect outcome, Normal authority, training truth, XML authority, or production authority was emitted.

The exact signed response is stored under:

`work/FM7P25/portal_response/R_9368DCE98C10_20260817203522038_6e4e8639`

## Cause

The eleven 2400 by 2000 rectangles contain pixels outside the fitted S02 wafer disk. R5P25 marked the entire rectangle valid, while the inherited R5P24 canonical grid admitted only cells whose centers were inside `radius - 8 px`.

An independent analytic count over the frozen S02 center/radius and exact 11 rectangles found 14,685,092 BF+DF rectangle pixels outside `radius - 8 px`. That explains 99.383 percent of the unassigned count. The remaining 91,228 pixels are in physical disk-edge portions of cells whose centers were outside the inherited grid. This is a validity/grid-domain mismatch, not missing source imagery, a failed alignment, a blank composite, or an approved fallback failure.

## Required correction

R5P25 and its JBOD output are withdrawn and must not be patched, presented, or used as a reviewer parent. A fresh R5P26 revision/output must:

1. define the physical inspection domain as the fitted S02 wafer disk with no generic inward inset;
2. mark outside-disk crop pixels as outside the inspection domain, never unassigned and never Normal;
3. create every route cell intersecting the physical disk and choose an in-disk representative for spatial adjudication;
4. analytically prove before scoring that every in-domain control pixel maps to a route cell;
5. retain zero direct-native and zero unassigned requirements for all in-domain BF/DF pixels; and
6. render outside-domain pixels distinctly so they cannot be mistaken for blank inspection coverage.

The approved R5P24A strict/fallback reference method, 4-DN deadband, target exclusion, transforms, and authority limits remain unchanged.
