# Front-metal D7 V17 R5P13D full-orthogonal edge checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P13D`

Disposition: `PENDING_GATE`

## Operator-authorized change

After visually confirming that the R5P13C short edges were substantially
improved, the operator requested the same preselected-master first-transition
correction for the two long horizontal-model edges L01 and L02.

S26 remained the only calibration master. S25, S31, and S20 remained held-out
validation sites. BF and DF remained channel-local and independent. The fixed
S26 horizontal corrections were:

| Segment | BF correction | DF correction |
|---|---:|---:|
| L01 | +0.916667 px | +0.794872 px |
| L02 | +0.391959 px | +0.393048 px |

The four accepted R5P13C short-edge corrections replayed unchanged.

## Measurement-anchor safeguard

A first direct attempt moved both the physical measurement/search anchor and
the model coordinate. It stopped before producing an audit or sheet because
S26 BF L02 fell from its retained 74/78 support to 69/78 with a three-pixel
gap. Its corrected intercept was already nearly ideal at -0.029065 px, showing
that the model coordinate was right but the moved search profile admitted the
known circle-row competitor.

The accepted diagnostic therefore separates measurement from modeling:

- the proven R5P13B measurement/search anchors remain unchanged;
- the same direct native first-transition pixels and support runs are retained;
- those measurements are expressed relative to the corrected channel-local
  six-edge model coordinates for the rigid solve and green reconstruction; and
- no accepted pixel, gap, response width, threshold, or profile changed as a
  consequence of the coordinate correction.

This preserves S26 BF L02 at exactly 74/78 with a one-pixel maximum gap. It
remains a bounded historical exception and is explicitly not an autonomous
gate pass.

## Result

All numerical gates pass:

- state:
  `PASS_BOUNDED_FULL_ORTHOGONAL_MASTER_EDGE_POSE_PHASE_WITH_RETAINED_S26_BF_EXCEPTION`;
- phase:
  `PASS_BOUNDED_ABSOLUTE_FIDUCIAL_PHASE_NO_NONZERO_DIE_ALIAS`;
- pose: `PASS_SINGLE_RIGID_ORTHOGONAL_LINE_RECONSTRUCTION`;
- line quality:
  `PASS_WITH_RETAINED_HISTORICAL_S26_BF_L02_EXCEPTION`;
- parent R5P13C rigid RMS range: `0.502820-0.604979 px`;
- current four-site rigid RMS range: `0.105849-0.138571 px`;
- held-out S25/S31/S20 rigid RMS range: `0.122471-0.138571 px`;
- maximum absolute six-edge intercept on held-out sites: `0.321696 px`;
- BF four-site correction spread: `0.428960 px`; and
- DF four-site correction spread: `0.413079 px`.

The calibration-master maximum six-edge intercept is zero in both channels.
All six held-out channel/site panels remain far below the unchanged 0.75 px
rigid RMS gate.

## File-backed operator gate

Review:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P13D/POSE_PHASE.png`

SHA-256:

`09EDC8528FF03A084113CC78C19CEC522565C0A7842FA7507300AC268DD832EC`

The sheet is 2160 x 3600 pixels. Magenta is unchanged direct native
first-transition support, green is the corrected channel-local six-edge model
under the independent rigid solve, and cyan is the corrected model at the
prior pose. S26 is labeled `CALIBRATION MASTER`; S25, S31, and S20 are labeled
`VALIDATION`.

The result remains pending explicit operator visual confirmation. No pose or
phase has been applied to a reference and no composite has been built.

## Separate Argos stitch concern

The possible internal Argos stitch fault remains explicitly unevaluated and
did not change this model. A later independent check may emit fail-closed
`STITCH_GEOMETRY_HOLD` when local pose is incompatible across a stitch
boundary; it must not be absorbed into this rigid-pose acceptance.

## Provenance

- audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P13D/AUDIT.json`
  (`1BF65512AB0428DDCB9E41B936932324A5D1B524921863280995EFF9159FE1ED`);
- input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P13D_INPUT.json`
  (`976E580D4DADA629479EDBC6EFBE65F008394234C95278FF5B1E4039B53C110F`);
- source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17FullOrthogonalMasterEdgeAuditV1.cs`
  (`2D8D45533E6A537E75FEAA8C1AB3986D92BD814BA4C7845E4E0202B3B0A2862E`);
- executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17FullOrthogonalMasterEdgeAuditV1.exe`
  (`2AE4DAB6D28B6150ECB8A7B3A2B3CC04DBDE93612B47C9A509E5E1CB988C0948`);
- parent R5P13C audit:
  `BE028B10E86BD6B279B9106410B9C032D14E9B7E6A7BCEE13156290A881FD74A`;
- native straight-edge audit used only for frozen S26 L01/L02 master
  intercepts:
  `DA29B9670A56417EE9C76A73ECF3D0542383D987EC3C2AFFB88449B5F0F80668`.

## Preserved authority

- S26 BF L02 remains exactly 74/78 direct samples (94.87%) and is not an
  autonomous pass.
- No pose or phase was applied to a reference.
- No target-excluded reference composite was built.
- T17 remains structurally unqualified until operator visual confirmation and
  a later composite gate.
- No detector mask, threshold, classifier, saved feedback, M3, or V16 changed.
- Deferred stroke 278 remains unevaluated.
- XML, JBOD, and production routing remain disabled.
- The strict frontside chipout sibling remains unchanged.
