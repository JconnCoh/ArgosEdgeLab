# Front-metal D7 V17 R5P12A native straight-edge checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P12A`

Disposition: `DIAGNOSTIC_ONLY`

Evaluation state: `HOLD_S26_BF_LOWER_BAR_DIRECT_SUPPORT_94_87_PERCENT`

## Approved bounded method

The operator agreed with the R5P11A diagnosis and approved the next bounded
method: fit only the sustained straight boundaries independently in BF and
DF; report direct support, residual bounce, unsupported gaps, and response
width; retain circle/stem geometry for identity only.

R5P12A uses
`NATIVE_1TO1_INDEPENDENT_CHANNEL_ROBUST_STRAIGHT_BOUNDARY_FIT` on original
`900 x 650` native crops with `scaleX=1`, `scaleY=1`, no downsampling, and no
rotation resampling. BF and DF are never compared or averaged. No channel
pose is recomputed or applied.

## Straight model

Literal straight-run extraction from the guidance boundary failed preflight
because the operator's dotted magenta markup interrupts the dark boundary.
It stopped before writes. The corrected model derives straight boundaries
from the retained component geometry rather than from the markup:

- `L01` and `L02`: top and bottom edges of the `1,029`-guidance-pixel long
  horizontal dark bar;
- `L03` through `L06`: left and right edges of the two `146-147`-guidance-
  pixel tall dark side components; and
- four compact circle/stem components: identity-only, zero fit weight.

Each channel samples at 1-native-pixel spacing. A robust linear offset is fit
per segment. Magenta is drawn one pixel thin only over contiguous directly
supported samples. Residuals above `0.75` pixel remain gaps. Required support
is `>=95%`, maximum unsupported gap is `<=1` pixel, and p90 response width is
`<=2` pixels.

## Bounded outer-search correction

The first R5P12 run began `4` native pixels outside every edge. Five of six
segments passed in all eight site/channel panels. Only `L02`, the lower long-
bar edge, failed everywhere because its outward scan points toward the nearby
circle row and encountered circle contrast first. This repeated geometric
competitor made the 4-pixel run ineligible.

R5P12A starts `2` pixels outside, still beyond the observed edge correction
but short of the circle row. No support, residual, gap, width, or gradient
gate was loosened.

Seven of eight site/channel panels pass every metric:

| Site | Channel | Minimum support | Maximum gap | Maximum p90 residual | Maximum p90 width | Result |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| S26 | BF | 94.87% | 1 px | 0.277 px | 1.75 px | HOLD |
| S26 | DF | 96.15% | 1 px | 0.277 px | 1.50 px | PASS |
| S25 | BF | 100.00% | 0 px | 0.243 px | 1.75 px | PASS |
| S25 | DF | 100.00% | 0 px | 0.218 px | 1.75 px | PASS |
| S31 | BF | 98.72% | 1 px | 0.272 px | 1.75 px | PASS |
| S31 | DF | 100.00% | 0 px | 0.243 px | 1.75 px | PASS |
| S20 | BF | 96.15% | 1 px | 0.283 px | 1.75 px | PASS |
| S20 | DF | 98.72% | 1 px | 0.273 px | 1.75 px | PASS |

The sole hold is S26 BF `L02`: `74/78` samples pass, or `94.87%`, leaving
four isolated one-pixel breaks. The fixed `95%` requirement is not rounded or
loosened. The overall audit remains
`HOLD_INDEPENDENT_NATIVE_STRAIGHT_EDGE_METRICS_INSUFFICIENT` pending operator
review of whether the visible isolated breaks match the raw image.

## Artifacts

- Native straight-line review sheet:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P12A/NATIVE_STRAIGHT_EDGES.png`
  - SHA-256:
    `36AA124BEB8D9B5754AF14A1581396C3AC04C18B73FC904605398B6CDDFB775A`
  - dimensions: `2160 x 3600`
- Audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P12A/AUDIT.json`
  - SHA-256:
    `DA29B9670A56417EE9C76A73ECF3D0542383D987EC3C2AFFB88449B5F0F80668`
- Input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P12_INPUT.json`
  - SHA-256:
    `37B8DC6AA140D877C2FFD94029861CBB338BC3BE6E6BD7A4B1F787AD0C2F460C`
- Straight-line source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17NativeStraightEdgeAuditV1.cs`
  - SHA-256:
    `D384C87EED2BA1B44A966F62BED0D49737E54A39D4483E1D3FA8FF7B86062A25`
- Shared compiled dependency source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17LeadingEdgeAuditV1.cs`
  - SHA-256:
    `C50627D3235802D5FF2AA74228436B23BECC7B8D37DC1EEE1F93D757C9667E85`
- Executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17NativeStraightEdgeAuditV1.exe`
  - SHA-256:
    `A0A8BB44C49275965DCE3FA6739D0074BE4D1551B7C85BE5A967BA4A7CF84CF5`

The final non-mutating preflight passed with exactly six sustained straight
segments, four identity-only circle/stem components, BF/DF agreement disabled,
independent channel fits, native scale `1 x 1`, no source or rotation
resampling, `poseApplied=false`, and zero writes. The sheet hash reverified.
All eight native BF/DF source files hash-match the audit.

## Preserved authority

- R5P5, R5P7, and R5P10 remain `WITHDRAWN`.
- R5P11 and R5P12 are superseded preliminary diagnostics and ineligible as
  revision parents.
- R5P12A is a diagnostic one-panel support hold; no channel pose is applied.
- T17 remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`.
- No reference composite, detector response, mask, threshold, classifier, or
  review disposition changed.
- Deferred stroke 278 remains unevaluated.
- V16 remains the released review-only reviewer.
- V17 remains `PENDING_GATE`; no V17 reviewer is presented.
- XML and production routing remain disabled.
- The strict chipout sibling remains unchanged.
