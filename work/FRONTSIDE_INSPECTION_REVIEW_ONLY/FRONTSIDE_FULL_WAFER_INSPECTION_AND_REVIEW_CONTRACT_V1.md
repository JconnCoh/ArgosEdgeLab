# Frontside full-wafer inspection and review contract V1

Status: governing review-only development contract. This contract supersedes
the earlier 27-card scratch-priority presentation as the forward operator
review design.

## Coverage

Every eligible frontside acquisition is inspected from the interior surface
through the physical perimeter. Coverage includes the narrow edge zone, the
physical edge, the notch neighborhood, and visible bevel evidence. The tool
hardware behind the frontside wafer is not a surface occlusion and must not be
converted into a frontside holder mask.

No blanket inward inset, broad notch sector, angular exclusion, or radial
exclusion may remove compact raw-supported defects. A bounded scribe identity
region is excluded because it is identity evidence, not a defect. Ambiguous
geometry produces an explicit hold and never a silent uninspected region.

Every detector branch must intersect candidate pixels with the qualified
physical-wafer boundary before component formation. The run must report zero
accepted pixels outside that boundary, zero accepted pixels on behind-wafer
hardware, and zero accepted pixels in the localized scribe row. Any nonzero
count is a hard run failure, not a display cleanup. This boundary contract
must preserve eligible compact evidence touching the true perimeter and must
not become a broad inward edge mask.

## Defect presence and classes

The first layer is class-neutral local defect presence using native lossless
BF and DF pixels. Classification follows only after supported presence is
formed. The required frontside classes are:

- `Scratch`;
- `Residue`;
- `Contamination`;
- `Particle`;
- `Stain`;
- `EdgeChipout`;
- `EdgeMicroDamage`;
- `BevelDamage`.

`HotSpot` remains reserved and disabled until representative photo examples
and a separate validation gate exist. Known ink is ordinary `Residue` with
optional provenance and never a separate class.

Scratch sensitivity has first priority, but the accepted result is the union
of every supported class. Scratch-specific logic must not erase or consume
other defects. Chuck/process patterns and recurring product structures are
context, not Scratch; a localized abnormal deposit, stain, particle, residue,
or physical-edge signal remains eligible even when it is not scratch-like.

## Raw and target-excluded composite branches

For every qualified appearance context, retain raw BF/DF evidence and the
target-excluded peer-reference branch independently. The target physical wafer
never contributes to its own reference. The accepted class mask is the exact
native-pixel OR of raw-accepted and shadow-accepted evidence. Neither branch
can clear the other.

Patterned and dielectric contexts additionally require validated grid phase
and orientation. Recurring structure seen across the current lot cannot be
silently absorbed as Normal; it remains held until compared with a separately
approved, append-only cross-lot golden.

## Operator display

Reuse the accepted JBOD backside interaction model without a new feedback
scheme:

1. `Composite Accepted BF` full-wafer tab.
2. `Composite Accepted DF` full-wafer tab.
3. Exact accepted class pixels over the unchanged BF or DF full-wafer base.
4. No bounding boxes, inferred geometry, filled heatmaps, or broad display
   halos.
5. Confirmation holds stay out of the accepted image but remain in the
   machine record.
6. Full physical edge and visible bevel remain displayed.
7. Existing lot/date selection, full-window image export, and sharing controls
   are retained.

The display must let the raw wafer remain readable. Local diagnostic cards may
be generated later for a specific question, but they are never the primary
frontside inspection review and never establish full-wafer coverage.

## Safety and authority

Detector scoring uses original native lossless pixels at `scaleX=1` and
`scaleY=1`. Thumbnails and overviews are display-only. Frontside geometry,
pattern registration, and all defect classes remain review-only until their
separate validation gates pass.

- `reviewOnly = true`
- `trainingEligible = false`
- `xmlEligible = false`
- `xmlGeometryEligible = false`
- `productionEligible = false`
- `jbodFrontsideProcessingEnabled = false`
- `hotSpotEnabled = false`
