# PFC004 expanded crosshair axis-only model candidate

Date: 2026-08-18

Revision: `PFC004_AXIS_ONLY_MODEL_V1_20260818`

Disposition: `DIAGNOSTIC_ONLY`

## Operator direction

The operator replaces the tight four-line square proposal with an expanded
crosshair method: preserve the complete crosshair and four inward-arrow cues
for identity, enlarge the working box, apply tiny ignore neighborhoods at the
inner concave corners and outer arrow corners, and use only horizontal and
vertical straight boundaries for pose. Develop and adjust the line finder on
many same-wafer fiducials, then fan out unchanged to multiple wafers and adjust
only from measured transfer evidence, following the prior test-wafer sequence.

This direction is locked as `PFC004_OP8`; its SHA-256 is
`C2EA4E2942AFB1A0B2CE15AD94F6491B9AD9DC3A1A90533BB2F06B59F6A35A99`.

## Expanded identity and working box

The exact 200-by-200 clean BF close view is unchanged. Within the bounded
search area x=70..129 and y=68..129, a seeded dark connected component at the
crosshair contains 521 pixels with bounding box x=83..116 and y=81..114. The
component retains the full crosshair/arrow topology for identity and alias
rejection only; its pose weight is zero.

Adding a three-pixel margin yields the expanded 40-by-40 working box
x=80..119 and y=78..117. This supersedes the prior tight x=88..111,
y=86..111 square as the proposed measurement ROI without changing the clean
BF/DF sources.

## Axis-only candidate

The model-extraction stage reuses the prior test-wafer straight-boundary run
logic from `CoreLines.cs`, SHA-256
`D384C87EED2BA1B44A966F62BED0D49737E54A39D4483E1D3FA8FF7B86062A25`.
It retains only sustained horizontal and vertical connected-component
boundaries. Each raw run loses two pixels at both endpoints as the tiny corner
ignore filter. Raw runs shorter than eight pixels and retained runs shorter
than four pixels are excluded.

The six proposed retained segments are:

- `L01` horizontal: raw `(105,102)-(115,102)`, retained
  `(107,102)-(113,102)`;
- `L02` vertical: raw `(104,82)-(104,92)`, retained
  `(104,84)-(104,90)`;
- `L03` horizontal: raw `(106,94)-(115,94)`, retained
  `(108,94)-(113,94)`;
- `L04` horizontal: raw `(85,102)-(94,102)`, retained
  `(87,102)-(92,102)`;
- `L05` horizontal: raw `(95,114)-(104,114)`, retained
  `(97,114)-(102,114)`;
- `L06` vertical: raw `(96,82)-(96,91)`, retained
  `(96,84)-(96,89)`.

The overlay uses magenta for the enlarged working box, yellow for tiny ignored
endpoint/corner neighborhoods, and green for the retained axis-only support.
It contains 156 magenta, 107 yellow, and 38 green pixels. The 4X view is
nearest-neighbor display only.

Locked artifacts:

- input SHA-256:
  `BCA7C2FF3320A19082E06F242C6600F2160AEA8D78704D08E0B900FBFF225F79`;
- tool source SHA-256:
  `EEAE09F9401F7CDE4D8C1164B2920A4481B5639FC011DFDD246BE85ACE4C40C5`;
- executable SHA-256:
  `1BFFB17CD860DC13CCD7A813CE5F2AD405E53261D892206A03FF7CDDFA096831`;
- identity-context mask SHA-256:
  `9C8174935BBDA8314992D6F0DF84E9E46D9EABD30C1319C86086070C71680264`;
- 1X overlay SHA-256:
  `92834B1C30D53E902A04050B24E34EA965A42C17846D90C0DF6E9FE58C8C7BB2`;
- 4X overlay SHA-256:
  `62A9E87876B065CBAA4A36CF05D465FDF4C5FA9439BD3044280BB11EC23F7193`;
- axis-only model SHA-256:
  `6A22B4F9DA2D335790CA2555EFAC988EF8C848B04CDAFF9B19091D6D1013481A`;
- audit SHA-256:
  `FA5FB779214CCD52CEE474FF64FAC958EEECF026CFF61719983787F07120001F`.

## Gate and next sequence

Current phase is `PFC004_EXPANDED_AXIS_ONLY_MODEL_REVIEW_GATE`.

The operator first confirms or corrects the enlarged box, yellow ignore
neighborhoods, and six green segments. After confirmation, perform a bounded
same-wafer test with separate development and holdout fiducial instances. Map
the model to original unrotated native pixels, fit BF and DF independently at
1:1 scale, detect the first stable physical boundary, keep unsupported gaps
open, and audit direct support, maximum gap, fit residual, and response width.
Do not tune on the holdout instances.

Only after the fixed same-wafer holdout gate passes may the unchanged method
fan out to multiple wafers. Any wafer or channel that lacks identity or line
support emits an operator-visible hold. Multi-wafer transfer has not started.

No native edge detection, fit, template authority, distributed phase,
alignment transfer, defect scoring, Normal outcome, training truth, XML, or
production authority has been created. R5P30 remains immutable. The 11
unresolved `PENDING_GATE` objects, other 30 category rows, 20 other crop-ready
designations, one map hold, and nine pose holds remain in their existing
prerequisite order.
