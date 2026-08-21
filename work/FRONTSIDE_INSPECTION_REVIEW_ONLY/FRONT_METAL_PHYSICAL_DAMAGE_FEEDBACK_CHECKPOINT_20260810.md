# Front-metal physical-damage feedback checkpoint — 2026-08-10

## State

`PASS_FRONT_METAL_PHYSICAL_DAMAGE_FEEDBACK_GALLERY_REVIEW_ONLY`

One BowComp-style full-wafer annotation page was built for
`62546-481_POST2_SLOT02` from the frozen actual-detection manifest. It is an
operator-guidance surface only. It does not alter the detector, train a model,
write XML, or enable production routing.

## Review page

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FRONT_METAL_PHYSICAL_DAMAGE_FEEDBACK_V1_20260810T144253Z/FRONT_METAL_PHYSICAL_DAMAGE_FEEDBACK.html`

The page provides:

- raw and accepted BF/DF views;
- the current accepted detector pixels in cyan;
- pink open freehand paths for missed physical damage / underkill;
- red open freehand paths for false detections / overkill;
- fit, zoom, and direct jumps to the two evaluated native tiles;
- partial export, local recovery, and exact prior-response reload;
- both overview and native `14411 x 10995` coordinates for every stroke.

The response file is
`FRONT_METAL_PHYSICAL_DAMAGE_FEEDBACK_RESPONSE.json` with schema
`argos_front_metal_physical_damage_feedback_response_v1`.

## Frozen detector evidence

- Identity: `62546-481_POST2_SLOT02`
- Inspection family: front-metal, no-resist, physical damage
- Bounded native tiles: `T16_R03C00`, `T21_R04C00`
- Candidate components displayed: 35
- Exact accepted detector pixels displayed: 568
- Scoring scale: `1:1`; no detector resampling
- Operator-facing downstream bin: `SCRATCH`

The current detector did not evaluate the full wafer. Each stroke records one
of `WITHIN_FINAL_GATE_COVERAGE`, `PARTIAL_OVERLAP_FINAL_GATE_COVERAGE`, or
`OUTSIDE_FINAL_GATE_COVERAGE`. A pink path outside the two tiles is valid
coverage guidance and must not be misreported as a threshold miss.

## Safety state

- `fullWaferNegativeTruth=false`
- `feedbackUsedAsDetectorInput=false`
- `reviewOnly=true`
- `trainingEligible=false`
- `xmlEligible=false`
- `productionEligible=false`
- source BF/DF images unchanged
- no image bytes, base64, data URLs, or `<img>` payloads embedded in the page

## Next gate

The operator may mark any useful subset and export it. Before any detector
revision, audit the saved paths against native BF/DF pixels, separate coverage
misses from within-gate underkill, preserve visible physical-damage presence
independently of the eventual `SCRATCH` bin, and run a bounded regression that
does not reinterpret unmarked pixels as Normal.

## V2 corrected enhanced-display amendment

State: `PASS_FRONT_METAL_PHYSICAL_DAMAGE_FEEDBACK_GALLERY_V2_REVIEW_ONLY`

Review page:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FRONT_METAL_PHYSICAL_DAMAGE_FEEDBACK_V2_20260810T155236Z/FRONT_METAL_PHYSICAL_DAMAGE_FEEDBACK.html`

Builder:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FrontMetalPhysicalDamageFeedbackGalleryV2.ps1`

V2 adds two markable views, `Enhanced DF` and `Enhanced DF + accepted`, using
the target-excluded, ten-peer, continuously interpolated displacement-field
artifact
`DF_PATTERN_NORMALIZED_ROBUST_SCORE_DISPLAY_ONLY.png` with SHA-256
`4B5A67787BB9CF84F21799192ADB62DB777EA1805C659468D81BD41785496B22`.
The retired hard-cell stitched residual remains ineligible. The enhanced view
is display/localization only, is not detector input or pixel truth, and may
make a physical feature look wider. Operator strokes continue to record the
same overview coordinates and native `14411 x 10995` coordinates independent
of the selected base view.

The white proposal locator audit found all `18/18` T16 and `17/17` T21 native
component bounding boxes intersect their exact accepted mask pixels. The V1
display inflated very small boxes asymmetrically from their upper-left corner,
which could make a box appear shifted. V2 centers any minimum-size locator on
the exact native bounding-box center and leaves proposal locators off by
default. The cyan accepted mask remains the primary detector display.

The V2 page has zero embedded image tags and zero data-image URIs. Detector
behavior, source images, accepted pixels, feedback authority, and all
review-only/training/XML/production safety states remain unchanged.
