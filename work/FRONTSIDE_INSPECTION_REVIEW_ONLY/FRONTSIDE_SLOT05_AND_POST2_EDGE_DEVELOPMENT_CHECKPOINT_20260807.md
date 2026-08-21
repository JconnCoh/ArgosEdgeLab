# Frontside Slot05 and POST2 edge development checkpoint — 2026-08-07

## State

This is an isolated review-only development checkpoint. It does not authorize
training, XML generation, production routing, or autonomous frontside edge
disposition.

Frontside inspection scope at this checkpoint is:

- required development classes: `Scratch`, `Stain`, `Residue`,
  `Contamination`, `Particle`, `EdgeChipout`, and `EdgeMicroDamage`;
- frontside `BevelDamage` is disabled, non-required, and non-blocking by
  operator direction;
- the visible frontside scribe is identity evidence and is excluded before
  defect candidate formation;
- frontside hardware is behind the wafer and no frontside holder mask is
  created;
- all scored pixels remain native `1:1`; frontside handedness remains
  `flipImageHorizontal=false`.

## Slot05 efficient raw plus target-excluded-shadow result

The frozen input run is:

`work/FRONT_JBOD_TEST/F5A4_20260807T175000Z/JOB_RESULT.json`

It completed 30/30 native tiles with 30/30 pose-bound reference-cache hits,
zero reference builds, and zero accepted scribe, holder, or outside-qualified-
wafer overlap. Raw and target-excluded-shadow evidence are combined by exact
pixel union; neither branch clears the other.

The existing Scratch mask remains unchanged by the correction below. The
prominent linear signals remain either accepted Scratch or class-specific
Scratch confirmation holds. No global Scratch threshold was raised.

## Broad low-frequency Slot05 evidence

The broad BF-visible cloud is the strongest interior target-versus-peer
low-frequency chromatic residual. Four contiguous 128-source-pixel blocks in
tile `T20_R03C04` exceed a fixed mean RGB-vector magnitude of `8.0`; the next
eligible block is `5.7521`. The supported source-coordinate envelope is
`x=[10801,11185), y=[6364,6620)`.

This evidence is recorded as
`CONFIRM_RESIDUE_OR_STAIN_BROAD_LOW_FREQUENCY` in:

`work/FRONT_JBOD_TEST/SLOT05_BROAD_LOW_FREQUENCY_HOLD_V1.json`

The 65,536-pixel / 13.778944 mm2 number is only the area of the four supporting
blocks. It is not a claimed defect-pixel area. The hold is not painted into an
accepted mask and cannot become Scratch truth.

## Smooth physical-boundary false response

The exposed false response was raw and shadow component `1` in
`T29_R05C03`: 4,864 pixels, 1,906-pixel major extent, 18.220 elongation,
2.552-pixel robust width, 0.073 DF support, and 23.607-pixel mean boundary
depth. Its geometry follows the smooth wafer/outside transition.

The bounded correction suppresses only an `ETCH_STAIN` candidate that:

- physically touches the fitted boundary;
- has at least 1,000 pixels and at least 800 pixels major extent;
- has elongation at least 12 and robust width at most 4 pixels;
- has DF support at most 0.10; and
- remains at most 35 pixels deep on average.

The single-tile regression is:

`work/FRONT_JBOD_TEST/F5A5_T29_20260807T190000Z/RUN_MANIFEST.json`

It completed in 23.902 seconds using the existing pose-bound reference cache.
Raw accepted pixels changed from 6,398 to 1,534 and shadow accepted pixels
from 6,402 to 1,538: exactly the same 4,864-pixel physical-boundary component
was removed from each branch. The raw and shadow Scratch alpha masks are
byte-for-byte unchanged. Residue, scribe-exclusion, and physical-eligibility
masks are also unchanged. A search of all prior Slot05 component tables found
no other component meeting the bounded rule.

Corrected detector source SHA-256:

`47E9B3B647411EBF2F3CFFCC0986FC81569407967702737FF64439F2F928CB44`

## POST2 patterned-metal frontside edge intake

Six original native BF/DF BMP sources for `62546-481_POST2` Slot01, Slot03,
and Slot17 are staged under:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/staging/POST2_FRONT_EDGE_V1`

Display thumbnails are localization aids only. The notch-first pose
method produced:

- Slot03: one coarse BF/DF physical candidate near 89.75 degrees and one
  native manufactured-notch candidate; locally qualified review-only.
- Slot17: one direct native BF/DF manufactured-notch candidate near 89.6
  degrees; locally qualified review-only.
- Slot01: the ordinary coarse pass held, then the bounded BF/DF exception
  path refined every image-supported physical competitor. The native profile
  preserved the giant 85.5-degree chipout as physical edge-damage evidence
  and selected the bounded pattern-interrupted manufactured notch at 89.9
  degrees. The current angle is identical to the corrected July result and
  the independently observed, human-verified scribe `3912P014FED2` satisfies
  the reciprocal notch-relative check. Final disposition:
  `FRONTSIDE_POSE_REVIEW_ONLY_RECIPROCAL_SCRIBE_CONFIRMED`.

The coarse diagnostics remain under `work/FP2P`; the corrected current
Slot01 refinement and confirmation are under `work/FP2P_SLOT01_EXCEPTION_V2`.
Neither the coarse diagnostic nor a historical thumbnail is pose authority.
The current native decision uses neither a fixed-angle rule nor a
deepest-indentation rule, and backside geometry did not select the notch.

## POST2 independent frontside physical-boundary transfer

The full-circumference native-pixel frontside boundary diagnostic is:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/POST2_FRONTSIDE_PHYSICAL_BOUNDARY_V1_20260807T200500Z`

It reads all six native `14411 x 10995` BF/DF sources at scale 1, uses the
qualified frontside circle and notch for each wafer, and applies no frontside
holder mask. Backside geometry does not establish any frontside contour.
Frontside BF establishes the candidate physical contour; DF is supporting
evidence and cannot promote a narrow patterned-metal response to chipout by
itself.

The exposed Slot01 regression separates the competing features correctly:

- giant physical chipout: 85.542068 degrees, 340.880588 px arc width,
  306 px maximum BF depth, 356 px maximum DF depth, disposition
  `CONFIRM_EDGE_CHIPOUT`;
- manufactured notch: 89.912097 degrees, 143.528669 px arc width,
  36 px maximum BF depth, 72 px maximum DF depth, disposition
  `EXPECTED_NOTCH_PRIOR_MATCH`.

Compared with the independently reviewed local native audit, the chipout
center differs by 0.042068 degree, its BF depth is identical, and its DF
depth differs by 2 px. The notch center differs by 0.012097 degree and its BF
depth is identical. A second full three-wafer pass reproduced every contour
metric exactly. The only intentional decision change was removal of two
narrow Slot01 DF-pattern responses that had no large BF contour; the final
run contains one chipout hold, not three.

This establishes a frontside review-only `EdgeChipout` candidate path for the
exposed Slot01 control. It does not establish autonomous reject authority.
The 0.05-degree physical-boundary pass is not microdamage authority; tiny
candidate rows remain holds until a separate source-pixel microdamage gate is
qualified.

## POST2 native microdamage refinement

The bounded native-resolution microdamage refinement is:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/POST2_FRONTSIDE_MICRO_REFINEMENT_V1_20260807T202000Z`

It refines only the coarse physical-boundary candidates, samples the original
BF/DF pixels at one-pixel arc spacing, and applies no frontside holder mask.
BF physical-boundary displacement remains mandatory; a channel-local DF or
pattern response cannot establish physical damage by itself. It produced 22
`CONFIRM_EDGE_MICRODAMAGE` candidates and retained 13 appearance-only
competitors outside the damage set:

- Slot01: 17 microdamage confirmations, 8 appearance-only competitors;
- Slot03: 2 microdamage confirmations, 1 appearance-only competitor;
- Slot17: 3 microdamage confirmations, 4 appearance-only competitors.

These rows are a bounded human-review set, not automatic rejects or negative
truth. Frontside `BevelDamage` remains disabled.

## Raw BF/DF edge review gallery

The current human-review gallery is:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/POST2_FRONTSIDE_EDGE_REVIEW_V1_20260807T204500Z/POST2_FRONTSIDE_EDGE_REVIEW.html`

Its manifest records 23 cards and 46 separate native-resolution crop files:
one exposed Slot01 `CONFIRM_EDGE_CHIPOUT` plus the 22 microdamage candidates.
The cards show raw BF and raw DF together without heatmaps, bounding boxes, or
overlays. The manufactured notch and scribe are excluded from the review set.
The gallery is review-only, training-ineligible, XML-ineligible, and
production-ineligible.

## Operator edge-card result

The operator completed all 23 cards in
`POST2_FRONTSIDE_EDGE_REVIEW_RESPONSE.json` on 2026-08-07. The response file
SHA-256 is
`D492B04F2F8F1A1D9E7F5E425A1F5FB75D43E1915E822001AE552711E37E4FB1`.

- `Slot01_CHIPOUT_001`: `CONFIRMED_DAMAGE` (`big chipout`);
- all 22 provisional `*_MICRO_*` candidates: `NOT_DAMAGE`.

The exposed micro-refinement gate therefore has 22/22 false-positive
controls and no operator-confirmed frontside microchipout. These labels are
bounded review-only evidence; they are not training, XML, or production
truth. The provisional micro candidates must not be promoted, painted, or
summarized as frontside damage.

For subsequent frontside edge work, keep two observed boundaries separate:
the outer physical perimeter bordering outside-wafer space and the inward
transition from the reflective top-bevel band to the front surface. A
frontside microchipout candidate must be an observed local interruption or
inward displacement of the physical front-surface edge with independent
BF/DF physical-boundary support. Tiny isolated specks or intensity texture
inside the reflective bevel band are ineligible. Frontside bevel damage
remains disabled pending a known positive. If reconsidered, it requires a
separate high-specificity confirmation-only path for a large, connected,
intense physical disruption; it must not borrow the microchipout class or
authority.

## Next gate

1. Preserve the corrected Slot01 notch/chipout regression above.
2. Retire the exposed provisional micro gate as failed (22/22 false-positive
   controls) and search for a genuine frontside microchipout example before
   granting any microdamage authority.
3. Apply the already qualified surface classes independently of edge
   geometry; the scribe remains an identity region and never a defect.
4. Do not prepare a JBOD revision until the frontside edge regression and the
   Slot05 correction regression both pass.
