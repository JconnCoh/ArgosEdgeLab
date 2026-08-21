# Front-metal class-neutral candidate checkpoint — 2026-08-12

## Disposition

Review-only diagnostic PASS. This checkpoint does **not** grant automatic
Reject, Normal, training, XML, or production authority.

The R3 neighborhood-composite threshold-12 mask is retained only as a
class-neutral *noticed-pixel candidate layer*. It must not be described as a
scratch mask or as defect truth. Unmarked pixels are not negative truth.

## Meaning of the coverage number

Before the scribe exclusion, the threshold-12 candidate layer contained
1,790,270 active pixels across 52,800,000 native scored pixels (3.3907%). The
number is candidate coverage, not a false-defect rate and not a reject rate.
Those pixels can contain scratches, physical damage, residue streaks,
contamination, residue, other unreviewed defect classes, and patterned
alignment/photometric residual.

## Exact scribe exclusion gate

Only the observed Slot02 frontside scribe-row quadrilateral was excluded.
The exclusion was built at native scale from the qualified pose and observed
scribe localization. It is not a broad angular, edge, notch, or product mask.

- Human-confirmed string: `1878P076FEE6`.
- Reader image-first string: `1878E076FEE6`; this disagreement does not
  broaden the geometry.
- Candidate pixels removed: 16,037.
- Remaining active pixels: 1,774,233 / 52,800,000 (3.360290%).
- Human positive strokes retaining candidate support: 70 / 70.
- Human scribe-only false controls retaining candidate support: 0 / 4.

## Component audit and safety consequence

After the exact scribe exclusion, 161,310 eight-connected components remain.
The 70 human-positive strokes touch components from 2 to 4,054 pixels
(median 235 pixels). By reviewed class:

- Scratch: 53 strokes, component range 2–4,054 pixels, median 305.
- ResidueStreak: 8 strokes, component range 16–110 pixels, median 58.
- Contamination: 5 strokes, component range 39–268 pixels, median 96.
- Residue: 4 strokes, component range 94–725 pixels, median 235.

Therefore component size, recurrence, lack of a human stroke, or membership
in a dense patterned field must not independently erase or declare a
candidate false. In particular, a generic small-component filter would erase
human-reviewed real evidence. The next stage must preserve class-neutral
presence separately from class confidence, use only directly pixel-connected
relationships, and issue class-specific confirmation holds where authority
is insufficient.

Systematic/common-condition evidence must remain eligible for an approved
golden-sentinel comparison; it must not be absorbed into Normal merely because
it appears on multiple wafers or in repeated die locations.

The existing frontside chipout/edge branch remains unchanged by this surface
candidate audit.

## Locked evidence hashes (SHA-256)

- Human feedback: `D642D9F64F0F45BDF8CB3518DCD49E6A42AA05B1AF5E62942973D99467DEB320`
- Canonical review manifest: `4ADAD8FC399E807DEBF497EAE205BED44FF6A01EA2253F3E45006A940FD4D8AA`
- Exact scribe exclusion: `54394556A6F0B95A04A64294DFB9A2A8A7B807D34815CE0C6836DF388A04FE07`
- Component audit result: `DA2236ADEC21A4A3878C559876EB1AD8D07E52B6BA4D55EBB342DA6D2EED02BC`
- Audit source: `F6BBB0799F3F666C3217A32DCD2FFDE98778C6DF7DE084A1F656586D30A1B777`
- Audit executable: `F3CF10AC5A9C988DA1A4EDAA9FBD09A675C1DB1598B2473BCC760A65B4607242`

## File-backed results

- `analysis/MWC_V5_NEIGHBORHOOD_COMPOSITE_R3_FULL_20260812/CLASS_NEUTRAL_COMPONENT_AUDIT_T012_V1/COMPONENT_AUDIT.json`
- `analysis/MWC_V5_NEIGHBORHOOD_COMPOSITE_R3_FULL_20260812/SCRIBE_IDENTITY_EXCLUSION_V1/SCRIBE_IDENTITY_EXCLUSION.json`

All detector scoring remained at native 1:1 pixels. Display enhancement is a
localization aid only; raw BF/DF define physical size and geometry.
