# Front-metal D7 V17 R5P18 JBOD-result hold checkpoint — 2026-08-15

## State

- Revision: `FM7V17R5P18_JBOD_RESULT`
- Disposition: `DIAGNOSTIC_ONLY`
- Returned audit state: `HOLD_LOCAL_PEER_COVERAGE_INSUFFICIENT`
- Authority remains review-only. This result is not a defect-negative result, not a reference parent, and not permission for a full-wafer rerun.

The operator ran the frozen R5P18 package and copied its complete timestamped output to:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\FM7P18_20260815T233457Z`

## Integrity and native-source contract

- `AUDIT.json`: 45709 bytes, SHA-256 `997F4B51A60FB41B9E5D1D0855B260E0008120DF8206DC526F10C418F12C3E26`
- `MASKS.json`: 17484 bytes, SHA-256 `56295719FC1588DADFD38E735DE8BD1A7320CE8C100B2C6BD03C374B15801983`
- The audit and mask schemas, revision, authority hashes, and target-exclusion fields parse successfully.
- All 24 BF/DF inputs for S02, S13, S14, S16, S18, S19, S20, S21, S22, S23, S24, and S25 passed the package's exact recovery-ledger SHA-256, byte-length, 24-bit BMP, `14411 x 10995`, `scaleX=1`, and `scaleY=1` preflight.
- Slot02 remained excluded from its own reference. BF and DF registration remained independent. Live target pixels were not resampled before scoring.
- All nine returned files are present. `MASKS.json` and every sheet hash-match the audit.

## Fail-closed result

- BF spatial cells: 5057; pair threshold 6.894137 DN; ambiguous-population cells 724; coverage-hold cells 5057; coverage range 0-0.
- DF spatial cells: 5057; pair threshold 14.006156 DN; ambiguous-population cells 745; coverage-hold cells 5057; coverage range 0-0.
- No peer remained eligible after the frozen whole-peer gates. Therefore T16 and T17 have zero scored residual pixels. Every T16/T17 pixel is a coverage hold; these controls contain no Normal or defect-negative authority.
- The returned spatial masks are valid hold masks, not accepted Normal-reference masks.

Three candidate peers failed the distributed straight-edge registration gate:

- S14: BF S31 failed line support because the maximum unsupported gap was 3 px.
- S21: DF S31 had 0.935897 minimum direct support with a 2 px maximum gap; DF S20 had a 2 px maximum gap.
- S23: BF S26/S20 and DF S26 failed line support, with minimum direct support 0.910256-0.935897 and 2 px maximum gaps.

S13, S16, S18, S19, S20, S22, S24, and S25 passed 4/4 BF and 4/4 DF sites and the global rigid/topology gates. Their BF/DF topology correlations span 0.889763-0.992980 and their rigid RMS values remain below the frozen 1.25 px limit. Each was nevertheless whole-held because at least one channel exceeded the frozen `maximumInteriorHeldFraction=0.15` spatial contribution limit. No whole-peer hold may be removed from these aggregate numbers alone.

## Returned file-backed sheets

- `PEER_REGISTRATION.png`: SHA-256 `9284E63E87C3A003094FB9EDEB697CC7555670979B8BCAF3DFAF245F742D4686`
- `BF_SPATIAL.png`: SHA-256 `52BC8A1AA3695EBF0E9A4CB36DBA473C482D9E4E7F3313AC7ABD35618D44349C`
- `DF_SPATIAL.png`: SHA-256 `65BA090995014DABF9B1149716485CB7F356A7C43A72DC044A8593F27C76F9B1`
- `PERIMETER.png`: SHA-256 `A148DF53579183D66A2523025C87613F1811598C84982541B64A8B9182B55720`
- `INTERIOR.png`: SHA-256 `E22C68F14CFF42920FB6439D56A9567C170A62919D0B8C28DE281E12E2BF70DD`
- `T16.png`: SHA-256 `4D48E27DBB1C1F1B733F2D5066CAF11D7C8A50704979BD43DBF43A272A72FD0F`
- `T17.png`: SHA-256 `656690AA950EDCF2F497D69E7E9F9EDF4D587956565873F08476A5E99DAA6542`

The current registration sheet renders S26 only. It cannot visually adjudicate the S14 S31, S21 S31/S20, or S23 S20 failures. Those exact failures must remain held unless a future bounded diagnostic returns their native panels without changing thresholds or filling gaps.

## Next action

Do not rerun `RUN.cmd`, loosen the 15% whole-peer gate, accept any peer, or interpret the zero T16/T17 residual count. The operator may inspect the file-backed `INTERIOR.png`, `PERIMETER.png`, `BF_SPATIAL.png`, and `DF_SPATIAL.png` sheets to describe whether the held populations look like perimeter crescent, legitimate wafer-to-wafer process variation, or registration displacement.

If further evidence is requested, the next bounded artifact is an evidence-only follow-up package that serializes each peer/channel pre-whole interior-held fraction and renders the exact failed S31/S20/S26 native registration panels. It must preserve the frozen source hashes, line gates, 15% gate, BF/DF independence, target exclusion, and all hold states. No detector, mask, threshold, classifier/M3, V16, reviewer, XML, production, stitch, deferred-stroke, or strict chipout-sibling state changed.
