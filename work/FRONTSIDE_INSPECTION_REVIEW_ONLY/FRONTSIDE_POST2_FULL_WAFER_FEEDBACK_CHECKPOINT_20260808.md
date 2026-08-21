# POST2 patterned-frontside full-wafer feedback checkpoint

State: `PASS_POST2_PATTERN_FULL_WAFER_FEEDBACK_GALLERY_BUILD_REVIEW_ONLY`

This checkpoint supplies the operator-facing full-wafer marking pass requested
after patterned-frontside review exposed long-scratch under-detection and
perimeter over-detection. It does not change detector thresholds, physical-edge
logic, source images, training state, XML eligibility, production eligibility,
or the JBOD runtime.

## Deliverable

- Gallery: `work/FP2_PATTERN_FULL_WAFER_FEEDBACK_V1_1_20260808T180257Z/POST2_PATTERNED_FRONTSIDE_FULL_WAFER_FEEDBACK.html`
- Manifest: `work/FP2_PATTERN_FULL_WAFER_FEEDBACK_V1_1_20260808T180257Z/FULL_WAFER_FEEDBACK_GALLERY_MANIFEST.json`
- Build result: `work/FP2_PATTERN_FULL_WAFER_FEEDBACK_V1_1_20260808T180257Z/GALLERY_BUILD_RESULT.json`
- Builder: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-Post2PatternFullWaferFeedbackGalleryV1.ps1`

The gallery contains 11 qualified patterned-frontside wafers: `Slot02`,
`Slot03`, `Slot13`, `Slot14`, `Slot16`, `Slot18`, `Slot19`, `Slot22`,
`Slot23`, `Slot24`, and `Slot25`. The fail-closed Slot20 and Slot21 alignment
holds are intentionally absent.

## Operator pass

1. Use the default `Raw BF` full-wafer view.
2. Select `MISS / big scratch` and trace each complete visible large scratch.
   Trace the observed scratch path; do not infer through invisible gaps.
3. Use `Accepted BF` to compare the existing accepted overlay, then return to
   `Raw BF` before drawing a missed-scratch path.
4. `FALSE / overkill` is available for unmistakable false detections, but the
   requested first pass is the large-scratch miss pass.
5. Move through the wafer selector and export with
   `Save / export marked review`. The response filename is
   `FRONTSIDE_POST2_FULL_WAFER_FEEDBACK_RESPONSE.json`.

Marks are saved as open freehand guidance paths in both overview and native
coordinate systems. They are not pixel-exact truth and cannot directly become
training, XML, or production authority.

## Integrity audit

- 11/11 identities unique.
- 44/44 referenced BF/DF raw/accepted display artifacts present.
- 44/44 referenced display hashes match.
- 22/22 native BF/DF source paths present and source hashes match.
- Nested BF/DF manifest records round-trip as objects, not strings.
- Raw BF, Accepted BF, Raw DF, and Accepted DF selectors are present.
- Both overview and native-coordinate point arrays are present.
- HTML image tags: 0.
- Embedded image/data URLs: 0.

The first generated V1 artifact exposed a BF/DF manifest serialization defect
during static audit and is not the handoff. The V1.1 builder now performs a
mandatory JSON round-trip channel-structure check before emitting PASS.

## Frozen hashes

- Builder SHA-256:
  `EB3B993DBB40E6BE18E781F7BBC5058E79B1B7AB385618BF21E36674671801A6`
- Gallery SHA-256:
  `C62C7F75FAB3E1868E7167A1CD6362798A05F5B0F2F5610CFF02257130930123`
- Manifest SHA-256:
  `6165039E865F3562A58DEE6B8DF6AB03FB9119A947B9698E4AC073D39EDDB7A7`
- Build-result SHA-256:
  `913A87ED51462BD45455BB6B83665450ABE62A88BDA304D9D7F306CE11C04F51`

