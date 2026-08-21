# Front-metal D7 V17 R5P9 dark-geometric checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P9`

Disposition: `DIAGNOSTIC_ONLY`

## Operator refinement

The operator accepted the direct geometric-edge approach in R5P8 as
`Perfect`, then narrowed the desired model. The final correction supersedes
the earlier crop: use only the darkest connected geometry from the supplied
compact model, and exclude the faint X-marked horizontal line completely.

R5P8 remains diagnostic and its poses were never applied. Its accepted role
is limited to method confirmation: fit an explicit geometric contour to
physical feature edges rather than correlating image texture.

## Dark-only model

R5P9 uses `DARK_ONLY_GEOMETRIC_EDGE_CONTOUR_CHAMFER`. The model is extracted
from the operator's corrected `1137 x 370` guidance image using:

- grayscale value `<=60` only;
- connected-component area `>=500` pixels;
- exactly `7` retained dark components and `19` excluded components;
- `84,908` retained dark pixels and `3,954` contour points; and
- no intensity or texture correlation in the final pose objective.

The seven retained components are the long dark bar, two dark straight side
features, and four dark circle/stem features. Straight edges provide X/Y and
theta. The circle/stem portions only disambiguate the intended structure.
The faint X-marked line is explicitly `eligible=false`; it is neither scored
nor downweighted. No adjacent PM is searched.

The final contour is restricted to points supported by BF and DF at three of
the four fixed sites, producing `3,920` consensus points at common scale
`0.075`.

| Site | Straightened-frame pose | Angle residual | BF mean distance | DF mean distance | Both-channel inlier <=2 px |
| --- | --- | ---: | ---: | ---: | ---: |
| S26 | `(-78.25,-133.00)` | `0.05 deg` | 0.092 px | 0.103 px | 100.000% |
| S25 | `(-78.25,-137.50)` | `0.45 deg` | 0.266 px | 0.309 px | 100.000% |
| S31 | `(-80.50,-134.50)` | `0.50 deg` | 0.248 px | 0.325 px | 100.000% |
| S20 | `(-73.25,-135.00)` | `0.00 deg` | 0.065 px | 0.082 px | 100.000% |

The numerical state is
`DARK_GEOMETRIC_CONTOUR_FOUR_SITE_CONSISTENT_PENDING_OPERATOR_OVERLAY_REVIEW`.
This is not pose approval. The operator must confirm that purple appears only
on the intended darkest straight and circle/stem boundaries, that the faint
X-marked line has no purple influence, and that all BF/DF sites identify the
same structure.

## Artifacts

- Purple-contour review sheet:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P9/DARK_GEOM.png`
  - SHA-256:
    `1BCDDBEBD8F1522B3F22866F06CC221A836B1269B3F42915B76E473ACD458CAF`
  - dimensions: `2160 x 3600`
- Audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P9/AUDIT.json`
  - SHA-256:
    `C828AC2F9F4975B8CBA7812CC8AD586FB1CBE2C7D41BD5F62FC98E1409770CC6`
- Input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P9_INPUT.json`
  - SHA-256:
    `703C9A358E37779BFF2DA434085232ABD2E87312DE00A460A84359A8F4F13B80`
- Source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17DarkGeomAuditV1.cs`
  - SHA-256:
    `7502EEE5E8E97AB666347C43D523C6F334155971CEE3CE114859733C8A349D6E`
- Executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17DarkGeomAuditV1.exe`
  - SHA-256:
    `872E452EF7F400DED2E52A2ECBEF3EDD2B544D7BB3B32C7C913A588FEB57B454`
- Operator guidance image:
  `C:/Users/JOSHUA~1.CON/AppData/Local/Temp/codex-clipboard-e7366894-e1cf-4780-9755-825eb6721699.png`
  - SHA-256:
    `0317DEB563ADA9D0A819BBCE3437B4519ACD25556224A92253EF2E4E013761C5`

The non-mutating preflight passed with seven included components,
`faintLineEligible=false`, `adjacentPmSearchAllowed=false`, and zero writes.
The rendered sheet hash reverified. All eight native BF/DF inputs still
hash-match the hashes recorded in the audit.

## Preserved authority

- R5P5 and R5P7 remain `WITHDRAWN`.
- R5P8 and R5P9 are diagnostic geometric evidence only; no pose is applied.
- T17 remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`.
- No reference composite, detector response, mask, threshold, classifier, or
  review disposition changed.
- Deferred stroke 278 remains unevaluated.
- V16 remains the released review-only reviewer.
- V17 remains `PENDING_GATE`; no V17 reviewer is presented.
- XML and production routing remain disabled.
- The strict chipout sibling remains unchanged.
