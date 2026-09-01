# OCV-02 R6 offline localization-geometry draft pass — 2026-09-01

Disposition: `DIAGNOSTIC_ONLY`

The operator-authorized parallel offline scribe lane produced provider-local
draft `ARGOS_OPENCV_SCRIBE_V1R6`. No JBOD, RustDesk, Project Portal, installed
provider, processor, task, process, queue, ledger, hold, source image, GUI
importer, XML output, training, or production state was contacted or changed.

R6 corrects the specific V1R5 automatic-localization failure recorded by the
four-member Slot22-Slot25 assessment. Before OCR-envelope expansion it now:

1. deduplicates the same image-derived min-area rectangle emitted by multiple
   morphology orientations; and
2. requires the rectangle's observed width and height to support the
   configuration-selected OCR envelope.

The exact signed O2D20 failure rectangle appeared four times, with observed
size `1228.8895260810853 x 42.15563077807427` pixels. Under the R6 configured
`1600 x 400` OCR envelope, its height ratio is `0.10538907694518568`, below the
generic configured minimum `0.2`. The four duplicate detections collapse to
one and are rejected with
`OBSERVED_GEOMETRY_DOES_NOT_SUPPORT_OCR_ENVELOPE`. They are not enlarged into
the prior false `FFFFFFFFFFF7` twelve-cell proposal. Rejection produces an
explicit localization-geometry hold and never grants identity authority.

## Frozen offline draft bytes

- Engine: `work/OPENCV_SCRIBE_V1R6/ArgosOpenCvScribeV1R6.py`, SHA-256
  `1E4C55AA4ECFB4DA3CEA9DF577DCFE86C4A2FADCB23D29F78719F3E0AC55E0E9`.
- Configuration: `work/OPENCV_SCRIBE_V1R6/OCV02_R6_OFFLINE_CONFIGURATION.json`,
  SHA-256
  `AAA111360E6DBF9A3E40D5A846C485E10BE420910BAE325F4986582D6E5D440A`.
- Locked parity runner SHA-256
  `7AC16B6A3EC7D947D2524D88ACFCFD028D3C733E3073AC7D76A945574FF179C7`.
- Full-localization runner SHA-256
  `33C0330C7CDAAEF88E7383F7D1A732ED7816AFA3183F7A4AF2D3D6F74EABEEF1`.

## Local real-image results

The qualified local runtime was
`C:\ArgosPy313\Scripts\python.exe`, OpenCV `5.0.0`, NumPy `2.5.2`.
All inputs were already-frozen local regression evidence; exact input and
reference hashes were verified by the runners before pixel evaluation.

- Locked recognition/semantic/geometry gate:
  `PASS_OCV02_R6_LOCKED_READER_AND_GEOMETRY_SEMANTICS`; 15/15 physical
  controls; 4/4 duplicate-view groups; valid A01 automatic-localization control
  retained one qualified deduplicated region; signed O2D20 thin-texture
  regression reduced 4 raw regions to 1 rejected region. Gate SHA-256
  `267086773F7233246FE621EAA8824B495DD4CE4369CD95D92D29438D7B14DE8E`.
- Full localization and recognition gate:
  `PASS_OCV02_R6_FULL_LOCALIZATION_AND_RECOGNITION_15_OF_15`; 15/15 exact
  proposals within the frozen ten-pixel grid tolerance; 4/4 duplicate-view
  agreement. Gate SHA-256
  `704EC0CB9303EA6DC74585A55213DD525773E44E77BBC8EE18DE203C2AF4789F`.
- Configuration gate proved the exact R6 provider/hash is selected, the full
  geometry contract is required, a missing geometry field fails closed, and
  widened automatic-identity authority is refused.

## Isolation and remaining gate

The branch adds only this branch-local authority/checkpoint material and the
new `work/OPENCV_SCRIBE_V1R6` provider/configuration/test namespace. It edits no
active backside provider, shared processor entrypoint, build/package schema,
or XML/GUI path. A later final build must merge provider-local bytes through a
controlled integration commit and mechanically prove those unrelated paths
unchanged; branch isolation prevents source corruption but does not itself
authorize integration or activation.

R6 remains an offline draft. The remaining real-image gate is a fresh,
serialized review-only run on exact hash-locked full-wafer BF/DF scribe inputs
that reproduce the Slot22-Slot25 appearance regime (or a separately frozen
independent cohort). It must prove that real wafer texture reaches the explicit
geometry hold while true scribe bands remain localizable, retain the incomplete
reference-coverage and identity-confirmation holds, and accept zero identities.
That gate requires separate live/publication authority and must not overlap an
active portal transaction. Until then: `reviewOnly=true`,
`trainingEligible=false`, `xmlEligible=false`, `productionEligible=false`,
provider disabled, no hold clearance.
