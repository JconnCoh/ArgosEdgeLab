# Patterned-wafer fiducial pose-hold metadata transport checkpoint

Date: 2026-08-15

Revision: `PATTERNED_FIDUCIAL_CROP_V1E_POSE_METADATA_PULL`

Disposition: `PENDING_GATE`

## Authority

This is a transport checkpoint for a bounded, signed, read-only JSON pull.
It grants no alignment, detector, training, XML, production, or automatic
inspection authority. It does not change the verified V1E result: 21 exact
product/layer combinations have paired native BF/DF crops pending operator
confirmation, nine exact-map combinations retain explicit macro-pose holds,
and PFC001 retains its exact-map hold.

## Pending signed request

Signed request `REQ_20260816T033053168Z_802B9D0EC0B4` requests exactly 13
JSON files from the preserved `PFCP1E_20260816T025500Z` output:

- the final native-pose manifest;
- nine held-wafer coarse BF/DF notch audits; and
- the three native audits already known to have
  `NATIVE_PATTERN_INTERRUPTED_NOTCH_CANDIDATE` state.

The signed request manifest SHA-256 is
`AD86EDBDFAC654AA3D1D1E65559E7DF9C0A270A4EB2DC3FC8A4164034D809CD2`.
The published request ZIP SHA-256 is
`95F6ADAC4A110B9F08BC842073ACAA464D99BDFB9725767DDC68652A218DAC92`.
The gateway archived the exact request under
`ProjectPortalRO\requests\processed` at 2026-08-16 03:30:53 UTC, proving
acceptance from the engineering share.

As of 2026-08-16 04:12:33 UTC, no signed response for this request is present
locally or on the engineering-share response root. The response root itself
has not changed since the prior 401 MB V1E data-pull response was published at
2026-08-16 03:19:16 UTC. This is recorded as a pending response-transport
delay, not an endpoint failure and not a failed data-pull result. The request
must not be duplicated while it remains accepted and unanswered.

## Recovery contract after response

When the signed response arrives, verify it through the installed portal
receiver and inspect only the requested bounded JSON fields. For ordinary
coarse holds, evaluate all BF/DF-supported physical-boundary competitors with
the existing bounded exception path; do not select the deepest indentation or
the candidate nearest a fixed angle. Pattern-interrupted native candidates
remain held unless reciprocal notch-relative scribe support is independently
verified. Any rerun must use fresh output roots, attempt every named wafer,
and preserve explicit holds rather than skip a wafer.

PFC001 must remain `HOLD_MAP_TEMPLATE_NOT_FOUND` until an exact
`LayoutId=1498994` product map is found. Product-family `3393-901` is not an
eligible substitute. Candidate structures 1 and 2 remain pending operator
confirmation; line-array structures 3 and 4 remain non-model controls.

## Operator-visible result

The verified 21-pair native gallery remains available at:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\PatternedFiducials_V1E_20260816`

No image bytes were embedded in this checkpoint or the Codex task.
