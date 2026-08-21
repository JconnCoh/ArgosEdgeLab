# TODO — XML textmap and front/back wafer alignment

Status: isolated manual-alignment review workstation implemented; validation
and production coordinate authority remain disabled. XML generation and
production geometry remain disabled.

## Current review workstation

`work/FRONTSIDE_MAP_ALIGNMENT_REVIEW` now provides the deliberately simple
first-stage workflow requested by the operator:

1. select a frontside wafer preview;
2. select any available product XML template from a dropdown;
3. rotate the wafer image manually with coarse and fine increments;
4. explicitly orient the XML map;
5. nudge map phase by whole or fractional die amounts;
6. save a new review-only transform record.

The initial 45-degree image rotation is a starting guess, not accepted
geometry. The operator's saved value is authoritative only for that
review record. Source images and XML remain immutable. The current display
uses a 1000 × 763 preview, so every accepted transform must later be mapped
and verified against native source coordinates before it can support an
inspection-coordinate transfer.

## Intended normal flow

1. Import the authoritative XML textmap directly.
2. Preserve the source XML unchanged.
3. Align the die grid to a frontside wafer image.
4. Establish a physical wafer frame from center, radius/scale, and notch angle.
5. Transfer that frame to the backside inspection with the explicit front/back
   mirror transform and acquisition metadata, including `flipImageHorizontal`.
6. Convert reviewed backside inspection coordinates into map/die coordinates.
7. Write results only to a new copy of the XML after a separate approval gate.
8. Save the KLA file as traceability/archive input for a future internal
   Klarity-like viewer; KLA-to-XML conversion is not the normal path.

## Bare-wafer registration

The notch is a primary rotational reference, but its image position must be
detected per wafer. Argos can load/prealign a wafer with translation or rotation
error, so the notch must never be assumed to remain at one fixed angle. Circle
center establishes translation and fitted radius establishes scale. The notch
alone does not define the die-grid row/column phase; one frontside die-grid/map
reference is still required. After that frontside anchor is established, the
backside can be registered through the shared physical wafer frame.

## Required safeguards

- Never infer or silently guess the front/back mirror.
- Keep image/tool-frame holder geometry separate from wafer-frame notch geometry.
- Treat chipout-versus-notch confusion as an explicit ambiguity requiring
  review; do not force a notch match from angle proximity alone.
- Record every transform and its residual error.
- Keep source XML and source KLA immutable.
- Do not borrow Brightfield geometry for DF-only bevel support.
- Do not export review-only, training-ineligible, or XML-ineligible candidates.
- Require contact-sheet/map-overlay review before any production XML write.
- Keep V2CT surface behavior locked and V2DC edge work isolated.

## Deferred validation cases

- Bare backside wafers first.
- BowComp/nitride backsides only after the bare-wafer transform is proven.
- Verify notch ambiguity, horizontal-flip metadata, die-grid phase, and wafer
  side mirroring with a small set of known frontside landmarks.
