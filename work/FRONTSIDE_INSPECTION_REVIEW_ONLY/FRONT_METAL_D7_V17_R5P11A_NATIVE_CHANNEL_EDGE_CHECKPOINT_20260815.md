# Front-metal D7 V17 R5P11A native individual-channel edge checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P11A`

Disposition: `DIAGNOSTIC_ONLY`

Evaluation state: `HOLD_NATIVE_CHANNEL_EDGE_CONTINUITY_INSUFFICIENT`

## Operator correction and R5P10 withdrawal

The operator rejected the R5P10 shared BF/DF leading-edge display as too
noisy and corrected the alignment contract:

- BF alignment will be derived from BF only;
- DF alignment will be derived from DF only;
- each line must be solid, thin, and well defined;
- missing line segments are bad;
- excessive left/right pixel bounce is bad; and
- a thick response would introduce registration shift.

The former R5P10 BF/DF agreement gate had attempted to suppress
channel-specific false edges by requiring nearby crossings and averaging
them. That behavior is ineligible for registration because it can discard a
valid channel-local edge, hide differences between the two registrations,
and convert two independent alignment problems into one shared noisy result.
R5P10 is `WITHDRAWN` as alignment authority; it was never applied.

The operator additionally required high-resolution crops. R5P11A therefore
measures the original stitched `900 x 650` native source pixels independently
for each channel with `scaleX=1`, `scaleY=1`, no downsampling, and no rotation
resampling. The model and outward normals are transformed into the original
image coordinate frame. Only the review sheet is enlarged for display, and
display scaling does not participate in measurement.

## Bounded individual-channel diagnostic

R5P11A uses
`NATIVE_1TO1_CHANNEL_LOCAL_OUTSIDE_IN_FIRST_HIGH_CONTRAST_CONTINUITY_AUDIT`.
It retains the same seven-component dark identity model and excludes the
faint X-marked line.

The first preliminary R5P11 run oversampled the guidance contour about
thirteen times per native pixel. Its 55%-of-local-peak response yielded only
78.5%-80.6% connected-line continuity and 3.0-3.25-pixel p90 response width.
It was not presented and is ineligible as a parent.

R5P11A collapses the evidence to one median observation per original native
contour pixel and raises the high-contrast criterion to 80% of the local
channel peak. BF and DF are never compared or averaged. Magenta is rendered
as one-pixel connected segments only. No dots or gap filling are allowed. A
missing response or adjacent normal-offset jump greater than 0.75 pixel
remains a visible break.

Every native contour cell produced a response in every panel, but the strict
continuity requirement still fails:

| Site | Channel | Native cells found | Connected-line continuity | Jump breaks | p90 response width | p90 adjacent jump |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| S26 | BF | 356/356 | 82.33% | 123 | 1.50 px | 1.50 px |
| S26 | DF | 356/356 | 81.61% | 128 | 1.50 px | 1.63 px |
| S25 | BF | 360/360 | 86.94% | 93 | 1.75 px | 1.36 px |
| S25 | DF | 360/360 | 87.36% | 90 | 1.75 px | 1.25 px |
| S31 | BF | 364/364 | 85.79% | 102 | 1.75 px | 1.50 px |
| S31 | DF | 364/364 | 84.12% | 114 | 1.75 px | 1.50 px |
| S20 | BF | 371/371 | 81.00% | 141 | 1.75 px | 1.25 px |
| S20 | DF | 371/371 | 81.40% | 138 | 1.75 px | 1.25 px |

The native-cell aggregation removed all missing-response breaks and narrowed
the response materially, but 90-141 jump breaks remain per panel. Under the
operator's stated rules, this is
`HOLD_NATIVE_CHANNEL_EDGE_CONTINUITY_INSUFFICIENT`, not an approved edge and
not alignment authority. No threshold was loosened and no break was filled.

The likely next bounded method is channel-local robust fitting of only the
long straight model boundaries, with direct support coverage, residual, gap,
and width reported independently for BF and DF. The circles would remain
identity disambiguation only. That work requires operator feedback on this
hold and has not begun.

## Artifacts

- Independent-channel native review sheet:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P11A/NATIVE_CHANNEL_EDGES.png`
  - SHA-256:
    `C2189AC5D4BA55C611372C9482F25CC51DA8C50917CF8EDA9D902F7DFFB3168E`
  - dimensions: `2160 x 3600`
- Audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P11A/AUDIT.json`
  - SHA-256:
    `32645B39F4FF8D6F451DF92E736CEEAEB09348CD63E4D612054659139D98A15B`
- Input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P11_INPUT.json`
  - SHA-256:
    `F85D5AD29900226F226357CF07DD17EC6E93F8E7C95EE7F1AFC1665751A9354F`
- Native-channel source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17NativeChannelEdgeAuditV1.cs`
  - SHA-256:
    `826454865F6BB21162264ECF774E3F6944C5E8AADCBE37D117CB883D43ECCBCB`
- Shared compiled dependency source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17LeadingEdgeAuditV1.cs`
  - SHA-256:
    `C50627D3235802D5FF2AA74228436B23BECC7B8D37DC1EEE1F93D757C9667E85`
- Executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17NativeChannelEdgeAuditV1.exe`
  - SHA-256:
    `583BBBF9C84C3C8E6CA7E42339E298A13F33133E7176EDFEC568C4375117100B`

The non-mutating preflight passed with BF/DF agreement disabled, independent
channels enabled, native crop dimensions `900 x 650`, scored scale `1 x 1`,
no source or rotation resampling, `faintXMarkedLineEligible=false`,
`poseApplied=false`, and zero writes. The sheet hash reverified. All eight
native BF/DF source files hash-match the audit.

## Preserved authority

- R5P5 and R5P7 remain `WITHDRAWN`.
- R5P10 is withdrawn as alignment authority.
- R5P11 is a superseded preliminary diagnostic and ineligible as a parent.
- R5P11A is a diagnostic continuity hold; no channel pose is applied.
- T17 remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`.
- No reference composite, detector response, mask, threshold, classifier, or
  review disposition changed.
- Deferred stroke 278 remains unevaluated.
- V16 remains the released review-only reviewer.
- V17 remains `PENDING_GATE`; no V17 reviewer is presented.
- XML and production routing remain disabled.
- The strict chipout sibling remains unchanged.
