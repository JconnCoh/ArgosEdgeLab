# OpenCV all-image-processing migration start checkpoint — 2026-08-22

Disposition: `PENDING_GATE`

Revision: `OPENCV_ALL_IMAGE_PROCESSING_MIGRATION_V1_20260822`

## Operator direction

The operator expanded the OpenCV project from fiducial/notch development to
all Argos image processing. The migration includes scribe deciphering, wafer
perimeter and notch pose, fiducials, reference composites, inspected-wafer
registration, Bare, all backside regimes, BowComp, all frontside patterned and
unpatterned families, detector masks, heatmaps, crops, overlays, and review
rasters.

PowerShell remains the automation layer only: watchers, scheduling,
configuration/manifests, exact file operations and hashing, provider calls,
timeouts and exit states, queues, ledgers, dashboards, GUI data flow, and
signed transport. It must not perform image decoding, pixel operations, OCR,
geometry fitting, compositing, registration, defect scoring, or image-derived
raster generation.

The complete human-readable program is
`work/ARGOS_OPENCV_ALL_IMAGE_PROCESSING_MIGRATION.md`. Its machine-readable
companion is `work/ARGOS_OPENCV_ALL_IMAGE_PROCESSING_MIGRATION.json`.

## Scribe work restored to scope

The earlier list omitted the known weak scribe-deciphering problem. `OCV-02`
now requires pose-bound OpenCV scribe ROI localization, independent BF/DF
enhancement, rectification, glyph segmentation, OCR candidates,
canonical/checksum scoring, calibrated confidence, explicit operator-review
holds, and reciprocal notch-relative scribe evidence. Ambiguous characters
must never be silently guessed or treated as confirmed identity.

## Notch starting point

The direct-native notch V3 is not an installed or reusable implementation. It
passed a synthetic chipout control, then failed the sealed FS15 regression at
15/15 holds and violated the independent-channel contract by conditioning DF
on BF and permitting pose averaging. It remains `WITHDRAWN` and may be used
only as failure/requirement evidence.

The OpenCV prototype and its independent BF/DF synthetic gate are the
structural starting point. The portable runtime is installed and self-tested
at `D:\AFCV1\rt`, but no real OpenCV development pixels have been scored and
the inspection processor has not been integrated with it.

## Required execution order

1. `OCV-00`: read-only exact inventory of every installed image-processing
   operation and frozen family baseline; resolve the exact PFC003/PFC010 paired
   BF/DF leaves and source hashes.
2. `OCV-01`: configuration-selected provider platform and stable schemas.
3. `OCV-02` and `OCV-03`: scribe deciphering plus independent perimeter/notch
   pose.
4. `OCV-04`: reusable site-bound fiducial localization and appearance regimes.
5. `OCV-05`: exact reference composite and inspected-wafer registration.
6. `OCV-06` through `OCV-10`: separately frozen Bare, backside, BowComp,
   frontside, patterned-comparison, mask, heatmap, and review-raster migrations.
7. `OCV-11`: one-family-at-a-time shadow comparison and configuration-driven
   activation.

Do not perform a big-bang rewrite. Freeze what works, replace one bounded
family at a time, compare mechanically, and preserve the unchanged disabled
path. No hard-coded lot, product, source/output root, FS15 exception, or
authority switch is allowed. Resource-intensive activity uses JBOD `D:`.

## Unchanged live boundaries

- META01R6 remains the current signed live processor repair checkpoint.
- The healthy processor must not be restarted or modified merely to start the
  migration.
- R10 and AVS1 remain `WITHDRAWN` and non-reusable.
- FS15 remains exposed terminal failure evidence and cannot be used for tuning.
- No real image read, live provider activation, XML, training, production
  routing, source deletion, wafer abort, or inspection-task action is
  authorized by this checkpoint.

## New-chat start line

Copy this exact line into a fresh chat:

> Continue the Argos OpenCV all-image-processing migration from `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab\work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OPENCV_ALL_IMAGE_PROCESSING_MIGRATION_START_CHECKPOINT_20260822.md`; use only the authoritative Desktop repository on branch `codex/fiducial-opencv-d-drive`, verify local and GitHub branch tips match, preserve the healthy processor and all existing holds, and begin at `OCV-00` with the read-only exact inventory and PFC003/PFC010 source-path resolution before writing or running any new image-processing code.
