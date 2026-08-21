# Front Metal physical-damage presence checkpoint — 2026-08-09

## State

`PASS_BOUNDED_FRONT_METAL_PHYSICAL_DAMAGE_PRESENCE_REVIEW_ONLY`

`HOLD_JBOD_DEPLOYMENT_SELECTOR_NOT_YET_QUALIFIED`

This checkpoint is review-only. It is not automatic-reject, training, XML,
recipe, production-routing, or JBOD-deployment authority.

## Scope and taxonomy

The bounded development identity is `62546-481_POST2_SLOT02`, frontside Front
Metal electroplating material. `POST2` is a development label and is not a
method selector.

The model-facing presence class is `FrontMetalPhysicalDamage`. The prior
morphology remains recorded separately and may be linear, compact, round,
stamping-like, or unknown. A confirmed event maps downstream to the operator
`Scratch` bin. This mapping does not redefine the general Scratch morphology
and does not teach that scratches are necessarily long, short, round, or
compact.

## Frozen operator feedback

- response:
  `C:\Users\joshua.conn\Downloads\FRONTSIDE_POST2_ENHANCED_ZOOM_REVIEW_RESPONSE.json`;
- SHA-256:
  `193D4C7D03FA8A245659C6959E706C43B50E15383E575408FED2D27F073125AB`;
- bounded Front Metal audit marks: strokes 27–31 are added physical-damage
  evidence and strokes 10–13 are exposed false/overkill controls.

Feedback selected evaluation locations only. It was not detector input and
did not create or expand detector pixels.

## Native evidence method

Two overlapping 2400 x 2000 source-pixel tiles were independently scored from
the original lossless 14411 x 10995 BF/DF images at `scaleX=1` and `scaleY=1`:

| Tile | Native origin | Reference peers | Selected result |
|---|---:|---:|---|
| `T16_R03C00` | `(1984,5624)` | 9 of 12; 3 weak peers excluded | 605 accepted pixels, 105 components, 1 confirmation component |
| `T21_R04C00` | `(1984,7424)` | 12 of 12 | 428 accepted pixels, 41 components, 1 confirmation component |

Both tiles used the unchanged pattern-reference-gated native detector. The
pattern reference supplied eligibility only; every proposed pixel remained an
original observed native BF/DF detector pixel. Resampling was false. Scribe,
holder, outside-qualified-wafer, and accepted pattern-reference overlap were
all zero in both runs.

The frozen physical-damage presence gate is:

- `MeanBfDrop >= 18`;
- `PeakBfDrop >= 30`;
- `DfSupport >= 0.60`;
- `PHYSICAL_BOUNDARY` components remain ineligible.

The two tiles are unioned only to ask whether each bounded operator mark has
independent selected native evidence in either tile. Components are not
joined, completed, inferred, or declared one physical event across a tile
boundary. Overlapping proposal rows remain separate views until a later
evidence-supported event-formation step.

## Frozen result

The two-tile union produced 35 presence proposal rows and passed twice:

- 5/5 marked physical-damage locations supported;
- 0/5 positive holds;
- 0/4 false controls exposed within the fixed 40-source-pixel control audit;
- proposal CSV SHA-256 in both repeats:
  `AD476571819E80C68DBAD73174D1A7D4EC568C061CB4491AD2F790EBF416A03D`.

Stroke 30 is the reason the union is necessary: it is not supported by T16,
but is supported by independently scored T21 evidence. No gate was weakened
to recover it.

Run records:

- T16 validation:
  `P:\ArgosEdgeLabRO_Temp\FrontMetalT16Local_20260809\T16_R03C00_RUN1\VALIDATION_RESULT.json`;
- T21 validation:
  `work/FP2_PATTERN_ROBUST_ABSOLUTE_RECURRENCE_SLOT02_T21_V1_20260809T102000Z\VALIDATION_RESULT.json`;
- first union:
  `P:\ArgosEdgeLabRO_Temp\FrontMetalT16Local_20260809\PHYSICAL_DAMAGE_TWO_TILE_RUN1`;
- deterministic repeat:
  `P:\ArgosEdgeLabRO_Temp\FrontMetalT16Local_20260809\PHYSICAL_DAMAGE_TWO_TILE_RUN2`.

## Method and route controls

The executable union audit is
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-Fp2PhysicalDamageMultiTileV1.ps1`
with SHA-256
`D6A354E457C8008A25ABC2F29650BB315F09DF9C4F23C7AE468670638FBD7B9F`.

The read-only resist-removed history controls are recorded in
`FRONT_METAL_RESIST_REMOVED_ROUTE_EVIDENCE_TABLE_20260809.csv` with SHA-256
`6D574BE801EBF393D7AC3B6EBC3313CAEEB81044C715A9A6EE1A22FB2D959F92`.
They confirm the bounded history signature `P-METAL ELECTROPLATING /
ELECTROPLATING / 6-6-PLATE-01` followed by `PLATING PR STRIP`. They do not yet
authorize a general production selector.

The future Front Metal selector still requires exact confirmed scribe,
frontside handedness, scan-time lineage, approved product/revision and
process/tool rule, and no conflicting lineage. Resist-present material remains
a separate unqualified method state. Recipe names, image color, `POST2`, and
visual similarity cannot grant the method.

## Remaining gates

1. qualify and approve the scan-time Front Metal route selector;
2. obtain image cohorts for the known `AVI_0` and `AVI_PD_GREYSCALE`
   resist-removed controls and test frozen-method transfer;
3. separately qualify resist-present material before enabling its method or
   future HotSpot work;
4. form physical events from overlapping views without proximity chaining or
   inferred line completion;
5. expand the bounded positive/false regression to additional independently
   reviewed wafers; and
6. rehearse any future package against the exact installed predecessor before
   JBOD deployment.

Until these gates pass, ambiguous events remain
`CONFIRM_FRONT_METAL_PHYSICAL_DAMAGE`, and all Front Metal outputs remain
review-only, training-ineligible, XML-ineligible, and production-ineligible.

## Portal note

The signed result-pull and status requests were received and moved to the
Gateway processed queue, but no downstream response package returned. They
must not be republished. This portal stall did not block the bounded T16 test
because the exact native BF/DF sources were already available locally. Portal
recovery remains separate from detector authority.
