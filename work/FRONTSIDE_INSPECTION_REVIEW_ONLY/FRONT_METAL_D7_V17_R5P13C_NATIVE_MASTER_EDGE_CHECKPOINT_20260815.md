# Front-metal D7 V17 R5P13C native-master edge checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P13C`

Disposition: `PENDING_GATE`

## Fixed change

The operator authorized one sequential correction after reviewing R5P13B.
Only the template definition of the four short vertical boundaries changed.
The preselected S26 fiducial became the calibration master. Its channel-local
native outside-to-inside first-transition intercepts moved L03-L06 from the
old thresholded-component bounding-box coordinates to the directly observed
physical transition coordinates.

BF and DF master geometry remained separate. S25, S31, and S20 were not used
to define the correction and remained held-out validation sites. The 8 px
upper extension and 2 px lower trim from R5P13B were retained. The long bar,
fit thresholds, pose thresholds, `0.75 px` rigid RMS gate, die-phase logic,
native scale, and source pixels were unchanged.

The fixed channel-local native corrections were:

| Segment | BF correction | DF correction |
|---|---:|---:|
| L03 | +0.191176 px | +0.014706 px |
| L04 | +1.264706 px | +1.279412 px |
| L05 | +1.514706 px | +1.411765 px |
| L06 | -0.397059 px | -0.367647 px |

## Result

The numerical pose and absolute-phase gates both pass:

- state:
  `PASS_BOUNDED_NATIVE_MASTER_EDGE_POSE_PHASE_WITH_RETAINED_S26_BF_EXCEPTION`;
- phase:
  `PASS_BOUNDED_ABSOLUTE_FIDUCIAL_PHASE_NO_NONZERO_DIE_ALIAS`;
- pose: `PASS_SINGLE_RIGID_LINE_RECONSTRUCTION`;
- parent R5P13B rigid RMS range: `0.734780-0.838035 px`;
- current four-site rigid RMS range: `0.502820-0.604979 px`;
- held-out S25/S31/S20 rigid RMS range: `0.549488-0.604979 px`;
- maximum absolute short-edge intercept on the held-out sites: `0.25 px`;
- BF four-site correction spread: `0.430070 px`; and
- DF four-site correction spread: `0.431167 px`.

The correction is not a four-site empirical fit. Only S26 defined the model;
all six held-out channel/site panels pass the unchanged `0.75 px` gate. This
confirms that the R5P13B mismatch came from inconsistent template/live edge
definitions rather than weak vertical measurement, theta instability, or a
whole-die/PM phase error.

## File-backed operator gate

Review:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P13C/POSE_PHASE.png`

SHA-256:

`C1BD0270C8A7643D1874D9FD2F5D18D2DBAE28DD84868572583DF96D91912A93`

The sheet is 2160 x 3600 pixels. Magenta is direct native first-transition
support, green is the corrected channel-local model under the independent
rigid solve, and cyan is the corrected model at the prior pose. S26 is labeled
`CALIBRATION MASTER`; S25, S31, and S20 are labeled `VALIDATION`.

The result remains pending explicit operator visual confirmation. No pose or
phase has been applied to a reference and no composite has been built.

## Argos stitch concern

The operator separately noted that an incorrectly stitched Argos acquisition
could create a subtle internal discontinuity. That concern did not participate
in this model correction and was not evaluated here. A future stitch check
must be fail-closed and separate: incompatible local pose on opposite sides of
a stitch boundary should produce `STITCH_GEOMETRY_HOLD`, not be absorbed into
one rigid transform or used to change the fiducial model.

## Provenance

- audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P13C/AUDIT.json`
  (`BE028B10E86BD6B279B9106410B9C032D14E9B7E6A7BCEE13156290A881FD74A`);
- input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P13C_INPUT.json`
  (`A7B56C4181D4822B6D0763AA458D4DDDE1A4F8E776A45987DEBE88245B79B2BC`);
- source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17NativeMasterEdgeAuditV1.cs`
  (`B8457118DDD1A224E940309A48996C046EB057ED1326C72E73D8F7436EE326A9`);
- executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17NativeMasterEdgeAuditV1.exe`
  (`B6AE0817449F06C2794C1B9DDBDA66F7214D3199E1839186139D0A08C395EDEE`);
- parent R5P13B audit:
  `29A2B55AC9114026F9F7F2F139393795D68C81506A9D0DD0459198C58A9CE238`.

The first compile attempt produced only `CS1504` source-path errors because
legacy `csc.exe` dropped directories from relative forward-slash source
tokens. It created no executable or analysis root. The signature, cause,
preflight, and recovery are recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`; the successful build used fully
resolved absolute Windows paths.

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
