# FIDCV1 FSF3 signed source failure and FSO1 capability gap checkpoint — 2026-08-22

Disposition: `PENDING_GATE`.

This checkpoint continues only the patterned-wafer fiducial development lane.
The authoritative AVC1 processor remains healthy and untouched. R10 and AVS1
remain `WITHDRAWN`; global FS15 and every XML, training, production, deletion,
image-byte, and wafer-abort boundary remain unchanged.

## Downstream integration contract

The operator clarified the required dependency chain:

1. localize the designated fiducial in each qualified reference wafer;
2. produce a qualified, provenance-bound coordinate transform;
3. use only qualified reference transforms to construct an exact composite;
4. register each inspected patterned wafer to that exact composite revision;
5. permit defect comparison only after the inspected-wafer registration passes.

Missing, ambiguous, unqualified, or mismatched fiducial/registration evidence
must fail closed before composite construction or patterned-wafer inspection.
Geometry or registration success does not grant production authority.

The superseding integration boundary is
`work/FIDUCIAL_OPENCV_JBOD_INSTALL_FOI1/INTEGRATION_BOUNDARY_V2.json`, SHA-256
`046F8EBA7177A5D2B1189B68AFFC6AB78DDEDAA62F6F5449A3A1AD24BA0BC994`.
It requires configuration-selected runtime/provider activation, processor-
supplied source/map/pose/site/appearance-regime values, versioned localization
and registration artifacts, and exact transform/composite/source hashes. It
does not hard-code a lot, D: runtime root, FS15 rule, or inspection authority
into the geometry engine.

## FSF3 signed terminal failure

One exact configuration-driven fingerprint request was published. Its signed
terminal response
`R_8000B87CFC61_20260822163530416_79c70d47` returned `FAILED` before any
image read or hash acceptance because the exact PFC010 BF source was missing
through the verified process-local alias:

`D:/KLARFExport/Lot_62616-115/62616-115_20260807120245/Slot23/BrightfieldFrontsideWafer/resizedImage/62616-115_Slot23_BrightfieldFrontsideWafer_PM2_resizedImage.bmp`.

Terminal-response gate:
`work/FIDUCIAL_OPENCV_SOURCE_FINGERPRINT_FSF3/FSF3_TERMINAL_RESPONSE_GATE.json`,
SHA-256
`2D4A50ED964BC7B0D0E8C1FE2B0D8CB2D6B754D9064904BA0A9A2FC9B57589D8`.
Failure gate SHA-256 is
`15B0F42987342283BDADAE66411B7DAA9ECD4868B14F7281E0A0DD1985B2A8E8`.
The create-new fingerprint helper was rolled back. No source hash was accepted,
and OpenCV scoring, composite construction, registration, and inspection all
remain disabled.

## FSO1 signed post-failure observation

No successor mutation followed the failure. One bounded STATUS observation
was published and returned signed `PASS_STATUS_COLLECTED` response
`R_736E657E8CCC_20260822165423207_9db7c7bc`. The signed result proves:

- `ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2` remains `Running`;
- installed processor configuration still names `D:/KLARFExport` as the raw
  search root;
- frontside defect inspection and production authority remain disabled;
- the current running STATUS worker returned its legacy field set and did not
  return the requested `environmentInventory` property.

The signed response therefore does not prove D: volume capacity, exact
top-level child state, or the location/existence of the missing nested source.
Those facts remain explicitly unresolved.

Terminal observation gate:
`work/FIDUCIAL_OPENCV_POSTFAIL_OBSERVATION_FSO1/FSO1_TERMINAL_RESPONSE_GATE.json`,
SHA-256
`EDEF1E00933FD96094679DB96169A6F42E553038B025EE7DCD96966F9B4D76D7`.
Post-failure evidence:
`work/FIDUCIAL_OPENCV_POSTFAIL_OBSERVATION_FSO1/POST_FAILURE_OBSERVATION.json`,
SHA-256
`6E622BF6BB96A45E75483EF9543B7588076BBF0B6F794F60B0D90EA24B9D25BE`.

## Stop boundary and next action

The direct post-failure observation is pinned, but it closes only the
observation requirement; it does not resolve the source premise. Existing
qualified read-only behavior cannot discover the exact nested replacement
paths or test arbitrary exact-leaf metadata without image reads. Do not publish
another fingerprint helper and do not restart the healthy processor or the
resident portal worker merely to activate a field.

Continuation requires explicit authority for one bounded, generic,
metadata-only endpoint capability improvement (or an already qualified
equivalent route) that can resolve exact requested leaves beneath the approved
`D:/KLARFExport` root. It must return only existence, leaf/container type,
containment, and reparse metadata; it must not enumerate broadly, read image
bytes, change tasks/processes, or mutate sources. After that observation passes,
freeze corrected BF/DF paths and hashes before any review-only OpenCV pixel
scoring. Composite construction and patterned-wafer inspection remain later,
separately gated downstream consumers of qualified transforms.

Checkpoint preaction:
`work/FIDUCIAL_OPENCV_POSTFAIL_OBSERVATION_FSO1/CHECKPOINT_PREACTION.json`;
`PASS_ARGOS_ZERO_RECURRENCE_PREACTION` over 90 classified issues and 12 pinned
dependencies.
