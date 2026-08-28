# OCV-03 O3Q2 signed NumPy-premise failure / transport-gate hold — 2026-08-28

Disposition: `PENDING_GATE`

O3Q2 was published exactly once and returned one authentic matching
JBOD-signed terminal failure. The request was not retried or republished. The
failure occurred before image read or numeric-result production because the
active JBOD runtime's NumPy version did not equal the frozen expected version
`2.5.1`. The exact active version remains unobserved and must not be guessed.

## One-time publication and authentic terminal response

- request ID: `REQ_20260828T033000222Z_62629419O3Q2`
- request ZIP SHA-256:
  `F107CB94E8580EB018C373F2995BC6D817D7E4337D351F875E861B5A42D1AACC`
- publication count: `1`
- publication gate:
  `work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_NUMERIC_PUBLISH_GATE.json`, SHA-256
  `4196CA751A0EC3F078AF60394D91BDE93C55BFF63B7C87A4DC1FA9FE884633E0`
- response ID: `R_1B7D26E4FA16_20260828034551022_4d1f22f6`
- response ZIP SHA-256:
  `519E0B1C9EB6A2F0EE036E356E9CDB1FC3A6D72D0B38DF9AE7831CCF25C2A23E`
- response state: `FAILED`
- signer thumbprint:
  `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`
- signed terminal gate:
  `work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_SIGNED_TERMINAL_RESPONSE_GATE.json`,
  SHA-256
  `56D64F2F287477E3307BA6111AEA7C89E7B3CEADF408476F7AD9E25A5D320769`

The exact ZIP, manifest, signature, failure record, stderr, and empty stdout
were collected through a create-new partial root and atomically committed only
after request correlation, signature verification, and every declared hash
passed. Collection gate:
`work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_TERMINAL_RESPONSE_COLLECTION_GATE.json`,
SHA-256
`1A5F2D1433464DA180F0EAEEB733C1625139F72E0706030E396E41468A0F6DDA`.
Only this matching response was collected.

## Exact failure and recovery classification

The endpoint reached the unchanged O3P8 engine. Its exact terminal exception
was `ValueError: O3P8 NumPy version changed.` The engine's frozen job expected
NumPy `2.5.1`; it failed at the runtime-version gate before any source image
read, BF topology, DF radial evaluation, candidate selection, output commit,
render, or provider activation.

This is one signed live-premise failure. Mutation is prohibited until a direct
post-failure observation is pinned. Same-request replay and automatic retry
remain forbidden. The exact `OBSERVE` recovery intent passed:
`work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_POST_FAILURE_RECOVERY_INTENT.json`, SHA-256
`CDE16CF24B12527D83577BC07A1A0B462A0CA96423703087A3B47A0332BA2B2B`.
Mutation stop-loss at two signed premise failures is not active, but the
single-published-request authority has been consumed and no fresh live numeric
successor is authorized.

## Observation capability gap

The installed qualified STATUS handler reports only its configured task,
installed-hash, JSON-state, and log fields. It cannot report active Python
module versions. DATA_PULL is limited to
`C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2` and `D:\KLARFExport`;
the runtime root `D:\AFCV1` is outside both approved roots. Neither portal
observation lane can answer the exact version question.

An incident-bound, hostname-gated direct read-only observation was designed
and its recovery, Windows PowerShell 5.1, wrapper, harness, and path gates
passed. Before any GUI or remote input, the separately mandatory transport
inventory harness preflight rejected the unchanged skill dependency
`Get-ArgosControlTransportState.ps1`, SHA-256
`853776763BF5449E582CE5E1E163E7D44EED511ED43CD34A90A23ACD3C00720B`,
for lacking a declared `Preflight`/`Rehearsal` mode and for an unsafe
conditional collection assignment. The transport script was not executed;
no RustDesk, RDP, or JBOD input was sent. Block gate:
`work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_DIRECT_TRANSPORT_HARNESS_BLOCK_GATE.json`,
SHA-256
`80A5D606E0A5CC6DA94750BC680B6FAAB82F1D3FEF9BD7484C8D4C9FDBFD8344`.

The genuinely new failure signature, cause, mandatory preflight, and recovery
were recorded in `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`. The complete
capability-gap gate is
`work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_POST_FAILURE_OBSERVATION_CAPABILITY_GAP_GATE.json`,
SHA-256
`D8CA36321642A0B311B8DDEAB05F8F180AFC1B0EEF280D704DE13C965E47FDD2`.
Checkpoint-promotion zero recurrence passed at
`work/OPENCV_EDGE_NOTCH_O3Q2/PREACTION_O3Q2_NUMPY_FAILURE_CHECKPOINT.json`,
SHA-256
`F37BFBD32300AD54B25C061A020697E1CD176F8E92470DB0D2822B1D8D355C97`.

## Exact next action and required authority

Do not replay or retry O3Q2 and do not publish another numeric request. One
bounded observation capability improvement is required before work can
continue:

1. qualify an installed read-only STATUS or DATA_PULL field that returns the
   active `D:\AFCV1` NumPy and OpenCV versions; or
2. provide a fresh harness-qualified revision of
   `Get-ArgosControlTransportState.ps1`, then refresh the recovery, wrapper,
   harness, path, continuity, session, and zero-recurrence gates before one
   hostname-gated direct read-only observation.

After that observation, a fresh live numeric successor still requires separate
explicit authority because O3Q2 consumed the one authorized live publication.
No threshold, algorithm, detector configuration, source, or location-prior
change is supported by this failure.

## Preserved prerequisite order and holds

Frontside independent hotspot validation is incomplete and remains ahead of
frontside freeze. Backside remains unconsumed and cannot start until frontside
is frozen. POST2/hotspot verification, frozen front/back fanout, and fiducial
resume therefore remain pending in that order.

O3N1, O3P7, and O3Q1 remain withdrawn and non-parent. BF Slot16 partial
coverage remains unresolved. Live provider remains disabled; the protected
processor is untouched. No source mutation/deletion, task or managed-process
action, threshold/algorithm change, retry, hold clearance, image read,
training, XML, production eligibility, or production routing occurred.
Every fiducial designation, map, pose, registration, coverage, sensitivity,
and independent alignment-transfer gate remains operator-visible and pending.
