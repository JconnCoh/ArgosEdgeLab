# Front-metal D7 V17 R5P7 bounded PM-match checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P7`

Disposition: `DIAGNOSTIC_ONLY`

## Operator gate consumed

The operator reviewed R5P6 and responded `Looks right.` This locks only the
`44.70 degree` product/image coordinate frame and the bounded PM-area
nomination for the next diagnostic. It does not qualify Bin 34/Bin 36 as old-
product fiducials, select a die phase, or authorize a reference rebuild.

## Bounded match result

The promised within-PM test used exactly the four R5P6 sites S26, S25, S31,
and S20. It did not search an adjacent PM. The hash-locked operator screenshot
was used as a review-only geometry template cropped to the right-hand
lollipop-array structure, including its upper and lower bars. The template
pixels are not training truth, detector truth, or production authority.

The four-site pooled edge match proposes:

- straightened PM-frame translation: `(-71, -113)` native pixels;
- corresponding original image-frame translation:
  `(+29.017, -130.261)` native pixels;
- template scale: `0.395`;
- native template dimensions: `110 x 73` pixels; and
- pooled template score: `0.379028`.

The proposal remains held. The individual BF/DF review matches prefer the
following residual corrections relative to the common proposal:

| Site | Common BF | Common DF | Individual residual | Individual score |
| --- | ---: | ---: | ---: | ---: |
| S26 | 0.418246 | 0.379459 | `(+1,+1)` | 0.644588 |
| S25 | 0.141308 | 0.134358 | `(+1,-3)` | 0.609533 |
| S31 | 0.427925 | 0.433175 | `(-1,0)` | 0.593859 |
| S20 | 0.070763 | 0.069579 | `(+6,-1)` | 0.608714 |

S20 reaches the positive-X edge of the fixed plus/minus-six-pixel residual
audit, and its common-location channel scores are weak. The maximum residual
is `6.083` pixels. The state is therefore
`HOLD_COMMON_TRANSLATION_SITE_RESIDUAL_DISAGREEMENT`, not an accepted
translation. The residual search was not widened.

The new sheet exposes the operator template, pooled four-site edge agreement,
and all four native BF/DF sites. Cyan is the one common proposal; magenta is
each site's bounded local best. Operator visual feedback is required on
whether cyan encloses the same lollipop/bar structure at all four sites.

## Artifacts

- Sheet:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P7/PM_MATCH.png`
  - SHA-256:
    `AD583DFD448916B3AFBE8A4248C9FEF9C01AE4FB3E219DDE6090C634AB5D5E62`
  - dimensions: `2160 x 4200`
- Audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P7/AUDIT.json`
  - SHA-256:
    `E2684D8B24FFFDAA71C858838679A1DC9B3DE505B403A4632A81CA8356451BD0`
- Input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P7_INPUT.json`
  - SHA-256:
    `B78BB32046BF142515D7E39A31761A4D95680D6379AE3589AC707AAE4AA6597B`
- Source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17PmMatchAuditV1.cs`
  - SHA-256:
    `D1182259E7B5E0A54E8EE39CF50EF65B9B6CBE33ED491E4B7F4AEA3810ADF2DC`
- Executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17PmMatchAuditV1.exe`
  - SHA-256:
    `CC030E47927A810D3A9850C872987B8EFD3DF0499215978E5308BEF8682CAD3A`

The non-mutating preflight passed with four fixed sites, a `260 x 170`
half-size within-PM search bound, and `adjacentPmSearchAllowed=false`. The
written sheet hash reverified. Eight native BF/DF source files are hash-
recorded in the audit and remain unchanged.

## Preserved authority

- R5P5 remains `WITHDRAWN`.
- R5P6 remains visual diagnostic evidence; its operator feedback is locked
  only for the corrected coordinate frame and bounded PM-area nomination.
- R5P7 is held diagnostic evidence; its translation is not applied.
- T17 remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`.
- No reference composite, detector response, mask, threshold, classifier, or
  review disposition changed.
- Deferred stroke 278 remains unevaluated.
- V16 remains the released review-only reviewer.
- V17 remains `PENDING_GATE`; no V17 reviewer is presented.
- XML and production routing remain disabled.
- The strict chipout sibling remains unchanged.

