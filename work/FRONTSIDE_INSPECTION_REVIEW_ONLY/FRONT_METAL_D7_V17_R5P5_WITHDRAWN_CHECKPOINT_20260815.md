# Front-metal D7 V17 R5P5 withdrawal checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P5`

Disposition: `WITHDRAWN`

## Reason for withdrawal

The R5P5 XML-fiducial projection sheet is invalid and must not be used as a
registration, reference, detector, review, XML, or production parent.

The sheet projected a horizontal normalized map directly onto a wafer whose
observed product grid is rotated in the image. It therefore mixed map and
image coordinate frames before any micro-registration decision. The operator
correctly rejected the sheet on review.

The old product also does not establish that the nominated PM structures are
uniquely represented by Bin 34 or Bin 36. Those bin labels are not eligible as
fiducial identity for this product. At most, the supplied pair is coarse map
evidence that the relevant PM structure should be present in that area.

## Corrected bounded method

For this old product only:

1. qualify the physical wafer/notch pose;
2. estimate the observed product-grid rotation from the wafer image and place
   map evidence in that rotated image coordinate frame;
3. use the supplied pair only to nominate a bounded PM region;
4. refine against the image structure itself, provisionally the operator-
   identified repeated lollipop array on the right, with its upper and lower
   bars and local die context as consistency checks;
5. require agreement at several mapped PM locations before a die phase can be
   accepted; a weak or ambiguous structure produces a hold and must not widen
   into an adjacent-PM search.

The operator requested a quick visual test before further work. The next step
is therefore limited to one rotation-corrected file-backed feature-location
sheet. It must stop for feedback and cannot rebuild the T17 reference.

## Preserved authority

- R5P5 files remain preserved as withdrawn evidence and are not deleted.
- T17 remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`.
- The reference composite, residual response, source masks, thresholds, and
  M3 classifier are unchanged.
- Deferred stroke 278 remains unevaluated.
- V16 remains the released review-only reviewer.
- V17 remains `PENDING_GATE`; no V17 reviewer is presented.
- XML and production routing remain disabled.
- The strict chipout sibling is unchanged.

