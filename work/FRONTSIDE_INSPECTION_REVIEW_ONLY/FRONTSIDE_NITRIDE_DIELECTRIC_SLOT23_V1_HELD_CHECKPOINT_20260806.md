# Frontside nitride dielectric Slot23 V1 held checkpoint

## Disposition

`FRONTSIDE_NITRIDE_DIELECTRIC_SLOT23_V1_20260807T000000Z` is an exposed diagnostic only. It is held and must not be copied into the JBOD processor or used as detector, golden, training, XML, or production authority.

The two blocking defects were visible in the full-wafer review:

1. the observed 12-character frontside scribe row entered surface-defect evidence;
2. visible acquisition hardware outside the physical wafer remained present near the accepted display and did not yet have an explicit zero-accepted-overlap audit.

The scribe is `WAFER_IDENTITY` evidence only. It is never a surface defect, edge defect, yield item, KLA bin, or XML bin. Its exclusion must be derived from the observed localized row and applied before any defect candidate is formed.

Frontside acquisition hardware is behind the wafer and must not create a holder mask. Surface scoring must instead remain inside the qualified physical wafer boundary, including the edge and notch, and must explicitly report zero accepted pixels outside that boundary.

## Preserved facts

- Source identity: `62631-586_20260806152140_SLOT23`
- Native BF/DF dimensions: `14411 x 10995`
- Scored scale: `1:1`, no resampling
- Native tiles completed: `30/30`
- Frontside hardware holder-mask pixels: `0`
- Target-excluded local BF peers: Slot01 and Slot05
- EdgeChipout, EdgeMicroDamage, and BevelDamage decisions remained held.

## Required successor gates

The successor may pass only when all of the following are true:

- a tight observed-row scribe quadrilateral is applied to eligibility before weak pixels, seeds, components, or classes are formed;
- accepted scribe-overlap pixels equal zero in both raw and target-excluded-shadow branches;
- the qualified frontside physical-wafer outer bound is enforced independently of outside hardware appearance;
- accepted pixels outside the qualified wafer equal zero;
- no frontside holder mask is created;
- raw BF/DF remain unchanged and available;
- all detector scoring remains native lossless `1:1`;
- the two-tab review remains `Composite Accepted BF` and `Composite Accepted DF`, without bounding boxes or filled heatmaps.

All work remains review-only, training-ineligible, XML-ineligible, and production-ineligible.
