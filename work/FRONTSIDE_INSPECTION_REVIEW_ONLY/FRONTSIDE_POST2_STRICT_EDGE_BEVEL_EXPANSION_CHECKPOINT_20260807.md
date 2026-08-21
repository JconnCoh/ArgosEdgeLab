# POST2 frontside strict edge/bevel expansion checkpoint — 2026-08-07

Status: review-only close-review checkpoint. Training, XML, production, and
automatic reject authority remain disabled.

## Scope

The extracted `FrontSide/BareBackside_POST2` set contains 13 physically
distinct slots (`02, 13, 14, 15, 16, 18, 19, 20, 21, 22, 23, 24, 25`). Each
slot has one lossless frontside BF and one lossless frontside DF BMP at
`14411 x 10995`, 24 bits per pixel. Matching backside channels were inventoried
but were not mixed into this frontside decision run.

All 13 slots have an existing review-only frontside pose in
`FRONTSIDE_NOTCH_POSE_CONSISTENCY_V2_DAMAGE_COMPETITOR_FIX_20260731T142000Z`.
Slot15 uses the recorded reciprocal-scribe-confirmed pose. The other 12 use
direct native BF/DF manufactured-notch evidence. No fixed-angle or
deepest-indentation rule was used.

## Frozen method

The expansion uses the unchanged strict method from
`Run-Post2FrontsideStrictEdgeBevelRescanV1.mjs`:

- native 1:1 BF/DF scoring over the full physical circumference;
- physical chipout requires independently observed BF/DF displacement and a
  directly observed outside-dark corridor;
- minimum BF/DF dark-corridor fractions `0.65 / 0.40` and minimum connected
  corridor-supported fraction `0.35`;
- bevel band `[-52, -8] px` relative to the local outer boundary;
- bevel damage minimum connected arc `30 px`, confirmation-only;
- tiny isolated bevel specks are ineligible;
- scribe pixels are not defect evidence; and
- no frontside hardware/holder mask is used.

The frozen regression anchor is
`POST2_FRONTSIDE_STRICT_EDGE_BEVEL_RESCAN_V1_20260807T223000Z` with SHA-256
`1387FA98A6D66A2ED492ABAD776CAAC6AE05FCF7DDE351FE488A2B9B514FAE99`.
It retains the one human-confirmed Slot01 chipout and suppresses all 22/22
human-reviewed narrow-boundary/noise controls.

## Expansion result

Output:

`outputs/review_only/POST2_FRONTSIDE_STRICT_EDGE_BEVEL_EXPANSION_V1_20260807T232500Z`

Result:

- 13/13 native BF/DF slot runs completed;
- 0 new strict `CONFIRM_EDGE_CHIPOUT` survivors;
- 0 new strict `CONFIRM_FRONTSIDE_BEVEL_DAMAGE` survivors;
- 0 frontside holder masks; and
- run state `PASS_REVIEW_ONLY_STRICT_EDGE_BEVEL_EXPANSION`.

Zero strict survivors is not full-wafer negative truth. The strongest
cross-channel suppressed responses were therefore selected by a fixed
pre-view close-review rule: connected arc at least 4 px, BF displacement at
least 16 px, DF displacement at least 20 px, and direct BF/DF physical
fraction at least 0.5. This yielded exactly two unresolved raw-review cards:

- `Slot13_CLOSE_REVIEW_01` at 357.347 degrees, 6 px connected arc, BF/DF
  displacement 26.5/44 px, direct BF/DF fraction 1.0, strict corridor 0.0;
- `Slot18_CLOSE_REVIEW_01` at 20.114 degrees, 5 px connected arc, BF/DF
  displacement 22/41 px, direct BF/DF fraction 0.6, strict corridor 0.0.

Neither row is an accepted defect. Both remain class-specific confirmation
holds because observed cross-channel boundary response exists but the strict
physical outside-corridor evidence is insufficient.

## Human review

Gallery:

`outputs/review_only/POST2_FRONTSIDE_STRICT_EDGE_BEVEL_EXPANSION_REVIEW_V1_20260807T235000Z/POST2_FRONTSIDE_STRICT_EXPANSION_CLOSE_REVIEW.html`

The gallery contains one previously confirmed Slot01 chipout control plus the
two unresolved expansion cards. It shows raw native BF and DF crops without
heatmaps or bounding boxes. A saved response remains review-only and must not
be interpreted as training, XML, or production authority.

## Human adjudication

The complete saved response was received at
`C:/Users/joshua.conn/Downloads/POST2_FRONTSIDE_STRICT_EXPANSION_CLOSE_REVIEW_RESPONSE.json`
with SHA-256
`FB452F19C43BAE4D2DB6F1166D21D5574CDFB5D5A34A09BBBB1D4A40DFF5C902`.
It contains all three expected rows with no missing, unexpected, or blank
dispositions.

- `CONTROL_SLOT01_CONFIRMED_CHIPOUT`: `CONFIRMED_DAMAGE`, preserving the
  known physical-edge sensitivity control.
- `Slot13_CLOSE_REVIEW_01`: `NOT_DAMAGE` for the physical edge/bevel task.
  The operator described it as a possible particle or flimsy piece of metal.
- `Slot18_CLOSE_REVIEW_01`: `NOT_DAMAGE` for the physical edge/bevel task.
  The operator described it as possibly particle or scratch evidence on the
  deliberately scratched wafer and explicitly not physical damage for this
  purpose.

The two new judgments are physical-edge/bevel negatives only. They are not
Normal surface truth and must not be used to suppress scratches, particles,
contamination, or residue. Preserve Slot13 as
`CONFIRM_CONTAMINATION_OR_PARTICLE` surface evidence and Slot18 as
`CONFIRM_SCRATCH_OR_CONTAMINATION_OR_PARTICLE` surface evidence until the
separate frontside surface component resolves them. The exact applied record
is `HUMAN_REVIEW_RESULT.json` beside the gallery.

Final expansion disposition: zero new human-confirmed physical edge or bevel
damage among the 13 added wafers; one known chipout control retained; two new
surface-follow-up rows preserved.
