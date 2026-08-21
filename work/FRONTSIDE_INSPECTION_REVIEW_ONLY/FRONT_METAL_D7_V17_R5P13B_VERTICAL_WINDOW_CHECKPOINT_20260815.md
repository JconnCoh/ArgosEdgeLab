# Front-metal D7 V17 R5P13B vertical-window diagnostic checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P13B`

Disposition: `DIAGNOSTIC_ONLY`

## Fixed sequential change

This is the first operator-authorized sequential follow-up to R5P13A. Only
the four vertical straight-edge measurement windows changed:

- the upper end was extended by `8 native px`;
- the lower end was trimmed by `2 native px` to avoid the softened end;
- expected samples increased from `11` to `17`; and
- the two long horizontal bar edges, model width, edge coordinates, search
  profile, BF/DF independence, absolute phase logic, and frozen `0.75 px`
  rigid-line RMS gate were unchanged.

No model-width or paired-edge-spacing correction was attempted.

## Result

The longer vertical windows provide excellent direct measurements in all
eight site/channel panels. Every vertical segment has:

- `17/17` direct native samples (`100%` support);
- zero unsupported gaps; and
- a maximum p90 response width no greater than `1.75 px`.

The evidence is therefore long, continuous, and thin. Insufficient vertical
evidence is not the cause of the visible rigid-model mismatch.

Despite the improved evidence, rigid reconstruction RMS became slightly worse
in every BF and DF panel. The parent range was `0.705543-0.805278 px`; the
current range is `0.734780-0.838035 px`:

| Site | BF parent | BF current | DF parent | DF current |
|---|---:|---:|---:|---:|
| S26 | 0.754590 | 0.780869 | 0.705543 | 0.734780 |
| S25 | 0.792018 | 0.824258 | 0.751868 | 0.784283 |
| S31 | 0.798789 | 0.827058 | 0.748116 | 0.773058 |
| S20 | 0.805278 | 0.838035 | 0.746431 | 0.776321 |

The absolute phase state remains
`PASS_BOUNDED_ABSOLUTE_FIDUCIAL_PHASE_NO_NONZERO_DIE_ALIAS`; the pose state
remains `HOLD_SINGLE_RIGID_LINE_RMS_ABOVE_0_75PX`. The BF and DF four-site
correction spreads are `0.438566 px` and `0.417992 px`, and the minimum
nonzero whole-die alias distance remains `65.927252 px`.

This result points away from vertical-window length and toward a systematic
model-geometry mismatch, such as paired-edge separation or centerline
placement. It does not authorize a threshold change. The next sequential
diagnostic, only after operator review, is a fixed paired-edge geometry test.

## File-backed review gate

Review:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P13B/POSE_PHASE.png`

SHA-256:

`1C1F4164F82096EB3E942DF570CF08A4683FEBFDACC6F7DD3836BC6CB3E06895`

Magenta is the direct accepted native boundary evidence, green is the one
rigid X/Y/theta reconstruction for that channel, and cyan is the prior R5P9
pose. BF and DF remain separate. The operator should assess whether opposite
magenta boundaries systematically bracket the green reconstruction; that is
the visual signature expected from paired-edge width/coordinate mismatch.

## Provenance

- audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P13B/AUDIT.json`
  (`29A2B55AC9114026F9F7F2F139393795D68C81506A9D0DD0459198C58A9CE238`);
- input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P13B_INPUT.json`
  (`3BD15469024CB86A10FD324BD2F8BEBAD2D82661E91390E02E3A58BA482197A8`);
- source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17VerticalWindowAuditV1.cs`
  (`41DD0F311E74F65517242C986A07228674E229B8B21AC5CECEA29A21521BA3AC`);
- executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17VerticalWindowAuditV1.exe`
  (`B90F168F9C9CCDB469AF017D14CCB1120FB26E1A9B63E887021DE64D24625DE9`);
- parent R5P13A audit:
  `54C8E30FC27CCCB6D074D030BA5F9A38FC0767EFC3757D8D3A66767721E0F8D4`.

## Preserved authority

- S26 BF L02 remains exactly 74/78 direct samples (94.87%) and is not an
  autonomous pass.
- No pose or phase was applied to a reference.
- No reference composite was rebuilt.
- T17 remains structurally unqualified for inspection.
- No detector mask, threshold, classifier, saved feedback, M3, or V16 changed.
- Deferred stroke 278 remains unevaluated.
- XML, JBOD, and production routing remain disabled.
- The strict frontside chipout sibling remains unchanged.
