# Patterned-wafer fiducial-model inventory requirement checkpoint

Date: 2026-08-15  
Revision: `PATTERNED_FIDUCIAL_INVENTORY_V1_REQUIREMENT`  
Parent: `FM7V17R5P23_RESULT`  
Disposition: `LOCKED_INPUT`

The operator opened a separate review-only inventory phase covering every
currently available patterned-wafer product and layer-specific image identity.
The objective is to select exactly one physical wafer for each unique exact
product/layer combination and create a paired native-source BF/DF crop around
the bin 34/36 fiducial region. The resulting file-backed gallery will be used
for rapid human confirmation that the established alignment method has an
eligible model on every patterned combination.

The operator-provided annotated example identifies the two circled structures
labeled 1 and 2 as the alignment-model feature family to expose. The isolated
line-array structures marked X at labels 3 and 4 are retained as non-model
controls and must not be selected merely because they contain strong straight
lines. This interpretation remains review-only and may be corrected by the
operator before any model is approved.

Inventory contract:

- query the current JBOD catalog rather than infer coverage from historical
  chat, filenames, or one lot;
- enumerate exact unique product plus layer/process-image identities and keep
  front-metal, dielectric, resist, and any other patterned image families
  separate;
- preserve physical wafer identity, lot, acquisition timestamp, slot, exact
  scribe/MES lineage when available, BF and DF source paths, hashes,
  dimensions, and route authority;
- choose one physical wafer per exact unique combination using metadata and
  source availability before crop appearance is reviewed;
- require a native BF/DF pair from the same physical acquisition and never use
  a JPEG, thumbnail, rendered review sheet, detector mask, or resampled image
  as the crop source;
- locate the bin 34/36 region from the applicable patterned-wafer map/lattice
  contract and verified macro pose, not from a fixed image coordinate copied
  across products;
- crop both channels at 1:1 scale with identical native coordinates and record
  source path, source hash, dimensions, crop rectangle, product, layer,
  physical identity, and `scaleX=scaleY=1`;
- expose both eligible model structures and the line-array non-model controls
  when the bounded region permits, so human confirmation cannot be satisfied
  by the wrong straight-line feature;
- emit an explicit inventory or crop hold for missing metadata, missing BF/DF,
  ambiguous product/layer identity, unqualified pose, absent bin mapping, or
  absent/ambiguous model features; never silently skip a combination;
- keep all crops and any confirmation matrix file-backed and review-only.

The first action is a signed exact pull of the current JBOD all-wafer catalog,
followed by a bounded metadata-only unique-combination audit. Crop generation
is not authorized until that inventory lists every combination, its selected
source pair, and any explicit holds.

This phase does not promote the front-metal R5P23 exposed-lot result to
independent transfer authority. It changes no detector, mask, threshold, M3,
V16, canonical reviewer, strict-chipout sibling, deferred stroke, stitch, XML,
or production route. The output remains training-, XML-, and
production-ineligible pending separate confirmation and transfer gates.
