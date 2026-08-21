# PFC004 inset-line guidance and identity-cue semantics

Date: 2026-08-18

Revision: `PFC004_INSET_LINE_GUIDANCE_V1_20260818`

Disposition: `DIAGNOSTIC_ONLY`

## Operator square and semantic clarification

The operator saved a new square directly on the exact 200-by-200 BF close
view. Pixel comparison with its clean parent found exactly 96 changed pixels,
all RGB `(255,174,201)`, forming one one-pixel rectangle at x=88..111 and
y=86..111. The exact marked square is locked with SHA-256
`5D05F9D6AD9986C1A231040BBD6704A990D40F7CDA48498AECB5C65F094E0804`.
The OP7 feedback JSON SHA-256 is
`29A3CF4E87D143063CA6EDAA9DA0CCD20522E25EB2A4E6E175A4CBB9DD918C67`.

The operator explains that the inward corners on the four arrows pointing
toward the crosshair are topology identity cues. They prevent accidental
selection of a similar crosshair-like structure, analogous to the round
lollipops beneath the bars on the test wafers. Preserve those cues in identity
context. They are not straight-edge pose support and do not receive pose
weight merely because they establish identity.

## Proposed line geometry

The operator allows the working support to shrink if needed. This bounded
proposal uses a two-pixel inward offset from the exact pink rectangle and trims
four pixels from both ends of every side:

- top: `(94,88)` through `(105,88)`;
- bottom: `(94,109)` through `(105,109)`;
- left: `(90,92)` through `(90,105)`;
- right: `(109,92)` through `(109,105)`.

The four green segments contain 52 pixels. The overlay audit found exactly 52
changed pixels relative to the locked pink-square source, all green and all
inside the declared inset bounds. Corner pose weight is zero. Identity context
remains visible and separate from the proposed pose support.

The 1X guidance SHA-256 is
`70BEFA11E23D321ECFA299B3975F970CEE5BCA58543F49009A910496AFB5825E`;
the nearest-neighbor 4X guidance SHA-256 is
`F525494C16DC46C93FAC2A727AE04493C593E722CD2F505D58B790EE1883EDFD`.
The proposed-geometry SHA-256 is
`96E9E13BEAAA1178012D7B89B69D702BF05C9EA0333D003540F99DAD1C4B94F4`.
The audit SHA-256 is
`B9B7001025673316EA55472F5AF5344BD8C078A7AB9256F7D00A73C97332548F`.

Build inputs and implementation are locked as:

- input SHA-256:
  `266132370E3F8E4255D34A0A2AB9528F7152EDA55E36F4FB2186D4B5C74F7D66`;
- source SHA-256:
  `CA84EED84311FB88B438C656A8E454F43E1084657D7248350D32DABD774DCD8A`;
- executable SHA-256:
  `D87D4CEF6255E8C71E54483F3CDC12B7A34C0891AFAA50E4CAD1C17488D170CC`.

## Gate

Current phase is `PFC004_INSET_LINE_GUIDANCE_REVIEW_GATE`.

The operator confirms the four proposed green segments or requests a smaller
inset/shorter support. Only after confirmation may those exact support
segments be affine-mapped to the original unrotated native BF and DF images
and used for independent first-stable-physical-boundary detection. The four
arrow-corner identity cues remain available for topology validation but are
excluded from straight-edge pose support.

No edge detection, fit, template, distributed phase, alignment transfer,
defect scoring, Normal outcome, training truth, XML, or production authority
has been created. R5P30 remains immutable. The 11 unresolved `PENDING_GATE`
objects, other 30 category rows, 20 other crop-ready designations, one map
hold, and nine pose holds remain in their existing prerequisite order.
