# Front-metal D7 V17 R5P10 leading-edge checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P10`

Disposition: `DIAGNOSTIC_ONLY`

## Operator correction

The operator accepted the R5P9 dark-only structure selection as `Good` but
observed that the magenta contour appeared slightly inside the visible
feature edges. The requested refinement is to start geometrically outside
the dark feature, move inward, and draw the first high-contrast pixels.

R5P9 remains diagnostic and unapplied. Its accepted role is the seven-part
dark-only identity model; its rendered dark-boundary location is not final
edge authority.

## One-sided leading-edge diagnostic

R5P10 uses
`DARK_MODEL_OUTWARD_NORMAL_FIRST_HIGH_CONTRAST_BF_DF_CONSENSUS`:

- the same seven darkest connected model components are retained;
- each dark-model contour pixel receives a geometric outward normal;
- the profile begins `4.0` native pixels outside and advances inward in
  `0.25`-pixel increments through `4.0` pixels inside;
- the first sample reaching both an absolute gradient of `12` and `55%` of
  the local channel maximum is selected, rather than the center or maximum
  of the whole response ridge;
- BF and DF crossings must agree within `1.25` native pixels; and
- the faint X-marked line remains explicitly ineligible.

The diagnostic keeps the R5P9 rigid pose unchanged. Cyan shows the parent
R5P9 dark-boundary location. Purple shows the BF/DF-agreed first transition
encountered outside-to-inside. This isolates the requested target-edge
semantics before any rigid pose is recomputed or applied.

| Site | BF/DF-agreed purple points | Median signed outward offset | Mean signed outward offset | Mean BF/DF disagreement |
| --- | ---: | ---: | ---: | ---: |
| S26 | 5,020 | +1.75 px | +1.975 px | 0.072 px |
| S25 | 5,021 | +1.75 px | +2.056 px | 0.083 px |
| S31 | 5,035 | +1.75 px | +2.042 px | 0.070 px |
| S20 | 5,004 | +1.75 px | +2.052 px | 0.073 px |

The identical `+1.75`-pixel median across all four sites and sub-`0.09`-pixel
mean BF/DF disagreement support the operator's observation that the prior
contour was consistently inside. They do not approve the new edge rule. The
state remains
`LEADING_EDGE_BF_DF_CONSENSUS_VISIBLE_PENDING_OPERATOR_REVIEW`.

## Artifacts

- Cyan-versus-purple review sheet:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P10/LEADING_EDGE.png`
  - SHA-256:
    `D2460BB4F408D9E71CDC3819202D1AEEE4E06CD8A3738961F1CDBD4ECEA243B4`
  - dimensions: `2160 x 3600`
- Audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P10/AUDIT.json`
  - SHA-256:
    `437092BFC2F044FDB79B15EFE152799529249C92A3C0F0859EE85997D73EFFA0`
- Input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P10_INPUT.json`
  - SHA-256:
    `9C3AE788BE0CBB5371DCE582246DE43A52A7F03E28471089DBCBD5A567BD8D98`
- Source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17LeadingEdgeAuditV1.cs`
  - SHA-256:
    `C50627D3235802D5FF2AA74228436B23BECC7B8D37DC1EEE1F93D757C9667E85`
- Executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17LeadingEdgeAuditV1.exe`
  - SHA-256:
    `D3DFB284CC4988DDCDF7B03D3A0454045FE6BF0E7523EB4454E18339EEBCAABA`

The non-mutating preflight passed with seven retained components, 5,106
contour points with outward normals, BF/DF agreement required,
`faintXMarkedLineEligible=false`, `poseApplied=false`, and zero writes. The
sheet hash reverified. All eight native BF/DF source files still hash-match
the audit.

## Preserved authority

- R5P5 and R5P7 remain `WITHDRAWN`.
- R5P8, R5P9, and R5P10 remain diagnostic only.
- No leading-edge pose has been recomputed or applied.
- T17 remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`.
- No reference composite, detector response, mask, threshold, classifier, or
  review disposition changed.
- Deferred stroke 278 remains unevaluated.
- V16 remains the released review-only reviewer.
- V17 remains `PENDING_GATE`; no V17 reviewer is presented.
- XML and production routing remain disabled.
- The strict chipout sibling remains unchanged.
