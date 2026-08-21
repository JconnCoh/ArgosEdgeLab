# Front-metal D7 V17 R5P8 geometric-edge checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P8`

Disposition: `DIAGNOSTIC_ONLY`

## Operator correction and R5P7 withdrawal

The operator rejected R5P7 after overlaying the four proposed matches and
observing considerable displacement. R5P7 optimized pattern/edge-image
correlation; that objective could score repeated texture without placing a
geometric model directly on the physical feature boundaries. R5P7 is now
`WITHDRAWN` as an alignment method. Its proposed common translation is
ineligible and remains unapplied.

The operator directed the replacement method: draw a geometric model along
the feature edges and align that contour directly to the observed edges, as
shown by the purple geometric-model lines in the supplied tool example.

## Bounded replacement

R5P8 uses `GEOMETRIC_EDGE_CONTOUR_CHAMFER`. Intensity and texture correlation
are prohibited from the final pose objective.

The old-product lollipop/bar source crop supplies the initial dark-geometry
boundary. Stable model points are then restricted to boundaries that fall
within `2.5` pixels of an extracted edge in both BF and DF at at least three
of the four fixed R5P6 sites. The resulting contour contains `1,693` points
from `2,023` source boundary points. The operator-rejected R5P7 positions are
used only as bounded within-PM starting-window hints, never as alignment
authority.

The final fit:

- searches only `+/-12` native pixels around each fixed within-PM hint;
- searches only `+/-1.0 degree` local angle;
- selects one common scale, `0.395`;
- refines translation at `0.25`-pixel increments;
- refines angle at `0.05`-degree increments;
- minimizes BF/DF geometric contour-to-edge distance; and
- does not search an adjacent PM.

| Site | Straightened-frame pose | Angle residual | BF mean distance | DF mean distance | Both-channel inlier <=2 px |
| --- | --- | ---: | ---: | ---: | ---: |
| S26 | `(-70.25,-111.75)` | `-0.20 deg` | 0.127 px | 0.168 px | 100.000% |
| S25 | `(-70.00,-116.25)` | `-0.40 deg` | 0.165 px | 0.224 px | 100.000% |
| S31 | `(-72.50,-113.25)` | `0.00 deg` | 0.152 px | 0.190 px | 99.762% |
| S20 | `(-65.25,-113.75)` | `-0.30 deg` | 0.159 px | 0.198 px | 99.762% |

The numerical state is
`GEOMETRIC_CONTOUR_FOUR_SITE_CONSISTENT_PENDING_OPERATOR_OVERLAY_REVIEW`.
This is not approval. The near-perfect numerical support is explicitly
subject to visual confirmation that the purple contour lies on the intended
physical lollipop/bar edges in every BF and DF panel, rather than on other
dense nearby edges.

## Artifacts

- Purple-contour review sheet:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P8/GEOM_EDGE.png`
  - SHA-256:
    `5A822B8ABDBB9273CD2D168A1A1405ED38985F443692E78BBA74F2F90429C896`
  - dimensions: `2160 x 3600`
- Audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P8/AUDIT.json`
  - SHA-256:
    `49BD81E98B7F8D34891C9A492FEA258523D0AAD2BFE7255283B7FBE265E56E3F`
- Input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P8_INPUT.json`
  - SHA-256:
    `098063C4B7F7DF3B01B4D95FC0FC970597709DB122CE49E03288AB2D101FD67E`
- Source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17GeomEdgeAuditV1.cs`
  - SHA-256:
    `46048CECD803400F3016E5B4BC597E846768081FCCB8BAB8C3D2EA58B9C42007`
- Executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17GeomEdgeAuditV1.exe`
  - SHA-256:
    `5AAC9BF17E5E02E4D69AC017F8CB8551AE3BC012614BB1A6FE3C787788C100D4`

The non-mutating preflight passed with geometric contour matching only,
`adjacentPmSearchAllowed=false`, and
`intensityCorrelationFinalPoseAllowed=false`. The sheet hash reverified.
Eight native source files are hash-recorded in the audit and remain unchanged.

## Preserved authority

- R5P5 and R5P7 are `WITHDRAWN`.
- R5P8 is diagnostic overlay evidence only; no pose is applied.
- T17 remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`.
- No reference composite, detector response, mask, threshold, classifier, or
  review disposition changed.
- Deferred stroke 278 remains unevaluated.
- V16 remains the released review-only reviewer.
- V17 remains `PENDING_GATE`; no V17 reviewer is presented.
- XML and production routing remain disabled.
- The strict chipout sibling remains unchanged.

