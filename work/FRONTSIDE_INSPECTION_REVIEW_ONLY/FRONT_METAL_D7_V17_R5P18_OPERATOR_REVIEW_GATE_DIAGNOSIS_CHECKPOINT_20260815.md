# Front-metal D7 V17 R5P18 operator review and gate diagnosis — 2026-08-15

## State

- Revision: `FM7V17R5P18_FEEDBACK`
- Disposition: `LOCKED_INPUT`
- State: `OPERATOR_CONFIRMS_PERIMETER_LOCAL_VARIATION_AND_SLIGHT_FIDUCIAL_OVERLAY_SHIFT`
- The returned R5P18 result remains `DIAGNOSTIC_ONLY / HOLD_LOCAL_PEER_COVERAGE_INSUFFICIENT`.

## Locked operator observations

The operator reviewed the returned file-backed sheets and reported:

- The interior sheet is a group of crops that look the same; no meaningful interior difference is visible.
- The previously used fiducial is not visible in the interior crops.
- The perimeter sheet shows the exact previously declared variation: speckled die, the extreme-edge perimeter with chipout, and the high-variation die-QR-code zone appearing as gray squares with some residue.
- No major physical issue is visible in the returned evidence.
- A small shift is visible between the fiducial alignment lines; a possible adjustment must be assessed rather than assumed.

These observations are review-only locked input. They do not make the visible perimeter features Normal, do not erase chipout or residue, and do not independently approve any peer or transform.

## Sheet-semantics clarification

`INTERIOR.png` is not a fiducial sheet. The R5P18 renderer selects one generic highest-dispersion 128 px interior cell for each channel and shows peer crops at that location. The absence of the fiducial there is expected. `PEER_REGISTRATION.png` renders only S26, with magenta direct first-transition runs and the green final six-edge solution. It does not render S25, S31, or S20.

The reported small magenta/green shift therefore cannot be converted into an alignment correction from the current compact audit. The audit preserves global rigid RMS/correlation but omits the per-site corrected X/Y/theta values, local line RMS, anchor residual vectors, and the missing S25/S31/S20 visual panels needed to distinguish a repeatable channel-local offset from local edge bounce or display interpolation.

## Gate-logic diagnosis

The aggregate whole-peer result does not establish a broad interior physical mismatch:

- There are 4,257 non-perimeter cells under the package's five-die-row perimeter definition.
- BF has 577 globally ambiguous interior cells, or 13.5541%.
- DF has 657 globally ambiguous interior cells, or 15.4334%.
- The frozen whole-peer limit is 15%.
- In every globally ambiguous cell, the direct-clique implementation marks every peer ineligible. Those shared ambiguity cells are then charged to every peer's individual interior-held fraction.

The DF shared-ambiguity fraction alone exceeds the 15% whole-peer limit, so every geometry-eligible peer is inevitably whole-held even before any peer-specific mismatch is considered. BF shared ambiguity consumes almost the entire allowance. The label `HOLD_BROAD_INTERIOR_APPEARANCE_OR_TOPOLOGY_MISMATCH` is therefore not a valid peer-specific physical diagnosis for this run. The fail-closed coverage hold remains valid, but the whole-peer escalation accounting requires correction before another qualification claim.

The operator's observation that the interior crops look alike is consistent with this mathematical diagnosis. The visible perimeter differences remain local non-Normal contribution-exclusion evidence, including speckled die, edge chipout, QR-code/gray-square variation, and residue.

## Adjustment assessment

No immediate rigid-pose adjustment is justified from the current sheet. Aggregate BF/DF topology correlations remain 0.889763-0.997430 and global rigid RMS remains 0.052621-0.648460 px, but those values cannot resolve the operator-noticed local line shift. S14, S21, and S23 also retain their exact line-support holds.

The next bounded diagnostic, if requested, must preserve all current thresholds and hold states while:

1. rendering native nearest-neighbor panels for S26, S25, S31, and S20 in both BF and DF, including every failed line-support case;
2. serializing each site's corrected X/Y/theta, local line RMS, absolute anchor, rigid-predicted anchor, and residual vector;
3. reporting BF-versus-DF and across-peer medians to test whether the observed shift is systematic enough for a bounded correction;
4. serializing each peer/channel's pre-whole held fraction with globally ambiguous cells reported separately from peer-specific exclusion; and
5. computing a diagnostic counterfactual in which global ambiguity remains a local coverage hold but is not charged as peer-specific mismatch.

This diagnostic must not loosen the 15% limit, fill gaps, approve peers, change the target transform, absorb perimeter variation into Normal, or change any detector, mask, threshold, classifier/M3, V16, reviewer, XML, production, stitch, deferred-stroke, or strict chipout-sibling authority.
