# OCV-03 O3Q4 signed runtime-gate state compatibility failure hold — 2026-08-28

Disposition: `WITHDRAWN`

Active phase: `OCV03_O3Q4_SIGNED_RUNTIME_GATE_STATE_COMPATIBILITY_FAILURE_HOLD`

Authority remains review-only. Training, XML, and production are ineligible.

## Authoritative outcome

O3Q4 request `REQ_20260828T152800444Z_62629419O3Q4` was published exactly
once. Matching response `R_4972FF4F6E27_20260828155653502_d78b4283` is a
JBOD-signed terminal `FAILED` response. The response ZIP is 2,674 bytes with
SHA-256 `72CD823F644C49DBB847B49FDAD4BC1836389A8CD4810840F503D2B4A2FB85CA`.
The signer thumbprint is `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`.

The failure is not an unknown or changed runtime version. File-backed evidence
still proves JBOD Python `3.13.2`, OpenCV `5.0.0`, and NumPy `2.5.2`. The exact
O3Q4 runtime gate used state `PASS_O3RV1_FILE_BACKED_JBOD_RUNTIME_PREMISE`.
Unchanged O3P8 SHA-256
`41F60AF393E0B2C752AF6B33BB6673145490AE2BB346A4DA8E59A2D42E383E36`
hard-codes the different predecessor state `PASS_O3P2_LOCAL_RUNTIME_INSTALLED`
in `load_job`. Signed stderr proves O3P8 stopped there with
`ValueError: O3P8 runtime gate is not PASS.`

The failure occurred before image read and before any numeric or raster result.
There is no Slot16 numeric pass or fail measurement to publish. O3Q4 is
withdrawn, no-retry, and non-parent.

## Exact evidence

- Publish gate:
  `work/OPENCV_EDGE_NOTCH_O3Q4/O3Q4_PUBLISH_GATE.json`, SHA-256
  `0292D65FD64785284EC87BA9B6D5512403CABBEA71E3C4F1E93B087E62DB5A02`.
- Signed failure collection gate:
  `work/OPENCV_EDGE_NOTCH_O3Q4/O3Q4_FAILED_RESPONSE_COLLECTION_GATE.json`,
  SHA-256
  `8F5B53A87B6F641BDA421D91395ABD09416B8D155A609FAE3FD93237FB49D670`.
- Signed terminal response gate:
  `work/OPENCV_EDGE_NOTCH_O3Q4/O3Q4_SIGNED_TERMINAL_RESPONSE_GATE.json`,
  SHA-256
  `63C54F71FB1F2F54AA2A3F14FE938D58B3F93AE88716B1F991650DB3B94D5925`.
- Signed stderr SHA-256:
  `56CEC762CADB5BFC868FEC720C9864D351E57FD2C57B2A47A792CF85CBF8E66E`.
- Runtime premise review:
  `work/OPENCV_EDGE_NOTCH_O3RV1/O3RV1_RUNTIME_PREMISE_REVIEW.json`, SHA-256
  `22557FFA8DE03DBD8690376EBCF2AF1D77A5A4CD3CFF14DFEB492ED47ADE494C`.
- Checkpoint preaction:
  `work/OPENCV_EDGE_NOTCH_O3Q4/PREACTION_O3Q4_SIGNED_FAILURE_CHECKPOINT.json`.

## Stop-loss and preserved holds

O3Q2 and O3Q4 are two signed premise/contract failures in the same incident.
Mutation stop-loss is active. No O3Q4 retry, replay, relabeling of O3RV1 as the
old laptop-runtime state, fresh numeric successor, runtime re-observation, or
compatibility mutation is authorized. A future non-algorithmic runtime-gate
consumer compatibility improvement requires workflow review and a new recovery
intent that explicitly clears stop-loss.

The following remain unchanged:

- O3N1/O3P7/O3Q1/O3TR1/O3TR2/O3RO1/O3RO2/O3RO3/O3SO1/O3SO2/O3SO3/O3Q2/
  O3Q3/O3Q4 are withdrawn or terminal, no-retry, and non-parent as applicable.
- Every stranded console/process remains untouched, including the possible
  O3Q3 child.
- No live provider was activated and the protected processor was not touched.
- No existing process or task was queried, started, restarted, stopped, or
  otherwise acted upon by the O3Q4 endpoint or collectors.
- No source was mutated or deleted; thresholds and algorithms were unchanged.
- Backside remains unconsumed and no Argos rotation, orientation, or location
  prior was consumed.
- BF Slot16 coverage remains partial.
- All operator fiducial designation, map, pose, registration, coverage,
  sensitivity, independent-alignment, XML, training, and production holds
  remain in force.

## Exact next action

Stop at this signed compatibility hold. Do not retry O3Q4 and do not create a
numeric successor. Retain an explicit authority blocker for one
non-algorithmic runtime-gate state consumer-compatibility improvement. Only a
separate workflow review and fresh recovery intent may clear mutation stop-loss
and authorize a new namespace. Runtime versions are already resolved and must
not be rediscovered.
