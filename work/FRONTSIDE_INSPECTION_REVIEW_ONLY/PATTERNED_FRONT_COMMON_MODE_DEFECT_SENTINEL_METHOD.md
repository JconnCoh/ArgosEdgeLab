# Patterned-front common-mode defect sentinel (review only)

## Problem

A target-excluded same-lot composite is necessary but not sufficient. If the
same defect is present on every wafer used as a peer, the peer composite can
absorb that condition and make it look normal. The operator-confirmed black
perimeter ring is an exposed example of this common-mode failure risk.

## Required independent evidence layers

1. **Same-lot target-excluded composite**
   - Exclude the target wafer from every reference used to inspect it.
   - Detect nonrecurring scratches, residue, contamination, particles, and
     stain evidence on the target.
   - Do not use this layer to clear a condition shared by all peer wafers.

2. **Within-wafer registered die-population comparison**
   - Qualify wafer pose and die-grid phase/orientation before comparing die
     populations.
   - Compare only equivalent pattern positions; physical adjacency is not
     evidence that two die regions should look identical.
   - Retain minority die/field populations and coherent radial bands as
     review candidates when they differ materially from the dominant
     equivalent-position population.
   - A photo-field cohort may be internally similar while still being an
     outlier against the remainder of the registered population.
   - Never chain components or fields by nearest-neighbor proximity.

3. **Approved product/step golden across prior accepted lots**
   - Compare a new lot reference against a stored approved product/step
     reference before allowing the new reference to inspect or replace it.
   - Promotion requires review of both localized anomalies and common-mode
     changes.
   - Never auto-update the stored golden from a lot that it is currently
     judging.

## Black perimeter ring disposition

The operator identified the black perimeter ring as real manufacturing-defect
evidence. Preserve it as:

`CONFIRM_RESIDUE_OR_STAIN_COMMON_PERIMETER_RING`

until its process class and decision authority are separately validated. It
must not be suppressed as ordinary edge noise and must not be classified as
`EdgeChipout`, `EdgeMicroDamage`, or `BevelDamage` merely because it is near
the physical perimeter.

The ring requires direct raw-image radial/common-condition evidence plus the
within-wafer and stored-golden checks above. The same-lot composite alone may
support it but cannot clear it.

## Authority and coordinate limits

- All findings remain review-only, training-ineligible, XML-ineligible, and
  production-ineligible.
- Die-population comparison does not authorize XML coordinates. Frontside
  die-grid phase and orientation require their separate qualification gate.
- Detector scoring must use original native lossless pixels at scaleX=1 and
  scaleY=1. Overviews are localization and display artifacts only.
- Scribe identity is excluded before candidate formation and is never a
  defect.
- Frontside hardware behind the wafer does not create a holder-exclusion mask.

