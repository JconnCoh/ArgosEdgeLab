# Frontside unpatterned four-wafer transfer checkpoint — 2026-08-06

> **SUPERSEDED PRESENTATION NOTICE:** The 27-card scratch-priority page is a
> narrow detector diagnostic only. It is not an inspection review design, does
> not represent full frontside defect coverage, and must not be reused as the
> JBOD frontside operator interface. Its bounding boxes, local crops, and
> scratch-only queue are retired from forward frontside review work. The
> governing replacement is
> `FRONTSIDE_FULL_WAFER_INSPECTION_AND_REVIEW_CONTRACT_V1.md`.

## State

`PASS_FOUR_WAFER_EXACT_CONTEXT_PRIORITY_GALLERY_REVIEW_ONLY`

This checkpoint is review-only. It creates no automatic defect decision and
is not eligible for training, XML, production, or JBOD frontside deployment.

## Frozen cohort

The eligible cohort contains four physically distinct frontside wafers at the
same exact scan-time MES context:

- product `1480861/A00`;
- process block `BOW COMP DEP`;
- step `POST WAFER BOW MEASURE`.

Every target used the other three physical wafers as its target-excluded,
native-pixel low-frequency reference. Raw BF remained an independent active
branch and DF remained unchanged. The separate two-wafer `CONTACT PRE
FIDUCIAL PATTERN / SORT_DBSP_S04` cohort remains
`HOLD_INSUFFICIENT_TARGET_EXCLUDED_PHYSICAL_PEERS`; it was not merged or
forced into a reference.

## Native scoring and exclusions

- Source dimensions: `14411 x 10995` for every BF/DF source.
- Pixel pitch: `14.5 um`.
- Scoring scale: `scaleX=1`, `scaleY=1`; no resampling.
- Scribe: tight frozen reader-grid quadrilateral plus the fixed local margin,
  recorded as a coverage hold and never defect eligible.
- Notch: bounded local exclusion only, recorded as a coverage hold.
- No broad angular, radial, notch, scribe, or holder sector was used.
- Broad connected scratch-or-residue ambiguity remained audit-only and was
  excluded from the scratch-priority operator queue.

## Exact transfer results

| Target | Scribe | Raw views | Shadow views | Raw high-DF views | Shadow high-DF views | Raw low-DF holds | Shadow low-DF holds | Direct raw+shadow physical events | Raw broad ambiguity audit | Shadow broad ambiguity audit |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `62631-544_20260803105445_SLOT01` | `0230S038FEF5` | 13 | 19 | 0 | 0 | 13 | 19 | 4 | 39 | 38 |
| `62631-544_20260803105445_SLOT10` | `1483G012SUB0` | 26 | 19 | 1 | 1 | 19 | 13 | 9 | 165 | 145 |
| `62631-545_20260803104055_SLOT01` | `0230S029FEF3` | 19 | 19 | 4 | 4 | 14 | 14 | 10 | 63 | 65 |
| `62631-545_20260803104055_SLOT10` | `0230S035FEA2` | 16 | 20 | 2 | 2 | 14 | 17 | 4 | 36 | 37 |

The 27 direct raw+shadow physical events are the bounded priority review set.
Single-branch and low-DF items remain explicit confirmation holds and were not
cleared, converted to Normal, or hidden from the machine record.

## Review assets

The retired diagnostic operator page is:

`operator_review/FRONTSIDE_UNPATTERNED_SCRATCH_PRIORITY_REVIEW_V1_20260806T221500Z/FRONTSIDE_UNPATTERNED_SCRATCH_PRIORITY_REVIEW.html`

It contains 27 diagnostic cards and 81 local image references. It contains no embedded
image bytes, base64, or data URLs. Each card shows:

- native raw BF, with a raw-evidence toggle;
- native lot-excluded shadow BF, with a shadow-evidence toggle;
- unchanged native DF;
- exact selected component pixels plus a one-pixel display-only visibility
  halo;
- a display-only yellow box around the card's primary physical event;
- every selected same-branch component that falls inside the local field of
  view, not only the component that selected the card.

The page saves only reviewed rows. It does not import decisions or change any
detector state.

## Regression proof

The presentation-only V2.2 rerun reproduced every prior V2.1 event CSV
byte-for-byte:

- `62631-544...SLOT01`: `36B8E78D621314532ACBCA96095FC5631A8588272541E925DBF408F83CEBDA28`
- `62631-544...SLOT10`: `2F1F5CDFCE7C13A5EAF24E74CF48F749124BAA878F10BF36D1977B21E670AF96`
- `62631-545...SLOT01`: `71D6735BC79FF07C995D928D3D34E920D0148A6BF32CB1B8CBCF9C902172D737`
- `62631-545...SLOT10`: `D8B32041FB10B20832E6E14BAD8D8D5CF82A4BC429AF03FA9C7C609BA31849BF`

The review gallery SHA-256 is
`CB1D40B20114054FC1724866E6FA2F32A26BC78BFF9963913E192610C648A6BD`.

## Failed diagnostic retained for audit

`unpatterned_diagnostics/FRONTSIDE_UNPATTERNED_SCRATCH_TRANSFER_V2_2_62631-544_20260803105445_SLOT01`
is an incomplete failed presentation diagnostic. Its long output path exceeded
the legacy GDI+ PNG save limit. It has no result JSON and must never be reused
or interpreted. The corrected short-path runs are the four `FSU_V22_*`
directories recorded by the gallery result.

## Superseded next step

Do not require completion of this scratch-card queue as the frontside
inspection review. Inventory patterned and dielectric frontside appearance
cohorts independently of recipe-folder names, then use the full-wafer,
all-class BF/DF review contract. The retained cards may be consulted only as
diagnostic scratch examples.
