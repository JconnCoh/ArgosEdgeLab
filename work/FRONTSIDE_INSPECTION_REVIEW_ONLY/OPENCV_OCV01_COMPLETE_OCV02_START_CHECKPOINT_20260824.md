# Argos OpenCV OCV-01 complete / OCV-02 start checkpoint — 2026-08-24

## Result

`OCV-01` is complete as a local, disabled-by-default provider-platform
baseline. Seven versioned JSON schemas now define provider configuration,
jobs, results, transforms, composites, masks, and review rasters. The platform
selects runtime, engine, and work/cache/output roots from configuration and
does not embed a lot, product, source root, or authority decision in the
resolver.

The exact platform gate is
`work/OPENCV_PROVIDER_PLATFORM_V1/OCV01_PLATFORM_GATE.json`, SHA-256
`F0A6B44976C570FCE4CCAB28839AC4DEC702B51B9EEE87859738D1332DB11190`.
The contract description SHA-256 is
`55ED23C8FF1CC1C6ED25E0077630755AEA16ED18C81E6D509C953B0382A68919`.

## Contract proof

Eight valid fixtures passed their exact schemas and seven invalid controls
were rejected. Windows PowerShell 5.1 proved both required provider-selection
states:

- disabled configuration returned `DISABLED_UNCHANGED_LEGACY_PATH`, performed
  no runtime probe, and invoked no provider;
- a deliberately enabled missing-runtime fixture returned
  `HOLD_OPENCV_RUNTIME_MISSING`, was not downstream-eligible, and invoked no
  provider.

The new resolver passed wrapper, harness-safety, and path-budget preflights.
It performs configuration validation and provider resolution only. It does
not decode images, process pixels, invoke OpenCV, or write runtime output.

The disabled platform binds the installed runtime evidence at
`D:\AFCV1\rt` and configured JBOD roots `D:\A2\w\ocv`, `D:\A2\c\ocv`, and
`D:\A2\o\ocv`. It is not installed. The current processor config and current
processor path are unchanged.

Checkpoint promotion passed the exact zero-recurrence pre-action contract
`work/OPENCV_PROVIDER_PLATFORM_V1/OCV01_CHECKPOINT_PREACTION.json`, SHA-256
`137F9C68AD90E62C2F7C48FABDE5371B84EF0A51FDC1A958863A420D61626BC7`.

## Preserved authority and holds

The healthy processor was not touched. No installed file, task, process,
queue, ledger, source image, wafer, or existing hold changed. Review-only is
true. Training, XML, production routing, source deletion, wafer abort,
processor restart, live provider activation, and hold clearance remain false.

Repository authority remains the Desktop repository on branch
`codex/fiducial-opencv-d-drive`. Local and GitHub tips match at
`ecbda3205852550d7f9fdb4a4daf99b4a001e7da`.

## Next action — OCV-02

Begin scribe-provider development using only the frozen OCV-00 development
partition. The provider must locate pose-bound scribe candidate regions rather
than assume one fixed image position, preserve BF and DF as independent
channels, produce OCR candidates with calibrated evidence, and return an
explicit hold for missing, ambiguous, low-confidence, checksum-invalid, or
provenance-mismatched results. It must not infer production authority or
activate the live processor provider.
