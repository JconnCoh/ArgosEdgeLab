# OCV-03 O3EI1 timeout-isolated runtime capability — publish ready R2

Date: 2026-08-28

Disposition: `PENDING_GATE`

Active phase: `OCV03_O3EI1_TIMEOUT_ISOLATED_RUNTIME_CAPABILITY_PUBLISH_READY`

This checkpoint supersedes the provisional pre-audit checkpoint
`OCV03_O3EI1_TIMEOUT_ISOLATED_RUNTIME_CAPABILITY_PUBLISH_READY_20260828.md`,
SHA-256 `93F5F9F40216B3BC533B9A0092B4A40E4187E8BF4887C1F9586AAE51F61B6C96`.
The exact checkpoint-promotion preaction passed before this R2 file was
created. Its contract is
`work/OPENCV_EDGE_NOTCH_O3EI1/PREACTION_O3EI1_PUBLISH_READY_CHECKPOINT.json`.
The provisional checkpoint remains evidence only and is not authoritative.

## Authoritative publish-ready state

One fresh signed review-only `MAINTENANCE_PATCH` request is ready for exactly
one publication: `REQ_20260828T143500111Z_O3EI1R01`. Its ZIP is
`work/OPENCV_EDGE_NOTCH_O3EI1/final_o3ei1/REQ_20260828T143500111Z_O3EI1R01.ready.zip`,
7,019 bytes, SHA-256
`A0FC4A5885CDD6350113212FCB299302E2EB9E8C0AA860BAEC95094F64EC740D`.
Retry is forbidden. Gateway acceptance is not execution evidence.

The request installs exact helper
`C4BCE3DBC9ABF91E99AE1E1DEB971EEB60610C2A117E645B5903EC4BAD744E8D`
under the already approved processor root and runs exact entrypoint
`B7453E74C1DF80DB4BAAA5F398870B6C5C99A71959EAD4C8F038B9A4B3812CAA`.
The helper starts only its own exact `D:\AFCV1\rt\python.exe` child, records
that child PID and creation time, enforces a 15-second wall-clock timeout, and
may terminate only that owned child on timeout. It does not query or act on an
existing process or task.

Frozen runtime inputs are executable SHA-256
`7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1`,
installation SHA-256
`1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596`,
OpenCV `5.0.0`, and NumPy `2.5.1`.

Required gates are:

- recovery intent:
  `662F73AC13ACB607997A4EF48ED917DE85A8C95C0DFF61B16AF7363BA2CDDE52`;
- local Windows PowerShell 5.1 entrypoint/timeout gate:
  `38F5608758D083D9F0951F3F53E6B5AA109685F26A064A3BC55BF315574395FF`;
- signed final package gate:
  `9DE22C2D77312614F6D68C3B4AA9F749A84A3719AF151F8FD3FB030B3670F19F`;
- exact package rehearsal:
  `07BE7BEFC7D4AC8D5607441AAFDE6155C42905722592240D000353C17F4CB69B`;
- 43-leaf complete route gate:
  `539227F71AACB9CD96FCFE92BB348264F10B364743622DC0319B9199388AD9B9`;
- current zero-pending U: share observation:
  `D4966E7E7EAAA04F151B6322397BFA817CBE4E198A57F18EA5316A19521AEB6F`;
- persistent U: alias gate:
  `E933AA39F2F07AD24FD31E8284193A2E974D6EFE2D5A69E72806FA12F4BC1DD0`.

The local exact package rehearsal passed create, target-hash idempotence,
unapproved-predecessor refusal before mutation, post-provider failure with no
output, inherited endpoint rollback/queue safety, and a forced timeout that
killed only the probe-owned child. No JBOD action has occurred. No image bytes
or source images were read or hashed; no source was changed/deleted; no task,
existing process, protected processor, or live image provider was touched.

## Required prerequisite order and preserved holds

1. Commit and push the exact publish-ready bytes and require clean matching
   local/origin `codex/fiducial-opencv-d-drive` tips.
2. Reconfirm zero pending requests and publish O3EI1 once.
3. Collect only the matching signed terminal response. Any mismatch, timeout,
   error, malformed response, or absent signed response remains a hold and is
   not retried.
4. Only exact `PASS_O3EI1_RUNTIME_PREMISE` evidence may authorize one fresh
   independent Slot16 numeric successor with the locked BF/DF hashes and
   unchanged O3P8 detector/config.
5. BF Slot16 partial coverage and independent frontside numeric validation
   remain pending. Backside remains unconsumed and requires a separate
   appearance-regime intent after frontside closure.
6. Every fiducial designation, map, pose, registration, coverage, sensitivity,
   and independent alignment-transfer gate remains pending.
7. XML, training, production eligibility, and production routing remain held.

O3N1/O3P7/O3Q1/O3TR1/O3TR2/O3RO1/O3RO2/O3RO3/O3SO1/O3SO2/O3SO3 remain
withdrawn, no-retry, and non-parent. Every stranded console and unknown process
state remains untouched. No threshold, algorithm, or hold changed.

## Exact next action

Commit and push this R2 continuity state, require clean matching branch tips,
publish `REQ_20260828T143500111Z_O3EI1R01` exactly once through persistent U:,
and collect only its matching signed terminal response. Do not retry and do not
build or publish a numeric successor unless the signed runtime premise passes.
