# Front-metal native-peer V1.6 withdrawal checkpoint — 2026-08-11

## State

`WITHDRAWN_FRONT_METAL_NATIVE_PEER_V1_6_OPERATOR_REVIEW`

The V1.6 review output at
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FRONT_METAL_NATIVE_PEER_V1_6_20260811T220500Z`
is withdrawn from operator review. Preserve it as a diagnostic artifact only.
Do not use it as detector truth, physical-size truth, affected-die geometry,
training truth, XML evidence, or production evidence.

## Exact cause

1. The canonical reviewer was initialized with `Review presence union` enabled.
   Its `renderMasks()` implementation placed `REVIEW_PRESENCE_UNION_ALPHA.png`
   over every native-tile panel, including both display-only enhanced panels.
   The resulting magenta pixels made a localization mask appear to be part of
   the enhanced evidence and appear to describe physical defect geometry.
2. The V1.6 replay used cached strict/native-peer support. Those masks are
   confirmation/localization evidence only. They were not a raw-BF/DF physical
   footprint recovery derived from the operator's saved raw-visible paths.
3. The saved operator response contains approximate physical footprints in
   native source coordinates. V1.6 merely measured whether cached support
   touched those paths. Touching 43/70 positive paths is not footprint
   agreement and did not justify presenting V1.6 as the requested detector
   correction.

## Preserved authority

- Raw BF and DF remain the only physical-size and affected-die authority.
- Seam-corrected and strict-zero-peer enhanced evidence may localize where to
  inspect, but must not define width, area, or affected die.
- The operator-marked raw-visible paths, including the paired damage paths in
  the supplied front-metal example, remain staged truth-informed regression
  evidence. Sparse cyan/yellow proposal pixels are not a substitute for those
  paths.
- The four saved T21 scribe controls remain false-detection controls.
- The source feedback file and hash remain:
  `human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260811T172156Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`,
  `D642D9F64F0F45BDF8CB3518DCD49E6A42AA05B1AF5E62942973D99467DEB320`.

## Required successor gate

A successor must use enhanced evidence only to propose bounded candidate
corridors, recover only directly supported native raw BF/DF pixels, keep
unsupported gaps empty, exclude the scribe controls, and report footprint
coverage and transverse expansion against every saved operator path. It must
not be presented until its default reviewer view clearly separates clean
enhanced localization from physical raw-supported result masks.

All work remains review-only, training-ineligible, XML-ineligible, and
production-ineligible.
