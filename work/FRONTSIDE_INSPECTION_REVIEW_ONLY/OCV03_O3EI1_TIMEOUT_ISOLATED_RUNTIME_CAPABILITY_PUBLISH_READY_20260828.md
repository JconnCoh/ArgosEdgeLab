# OCV-03 O3EI1 timeout-isolated runtime capability — publish ready

Date: 2026-08-28

Disposition: `PENDING_GATE`

Active phase: `OCV03_O3EI1_TIMEOUT_ISOLATED_RUNTIME_CAPABILITY_PUBLISH_READY`

## Outcome

One fresh signed review-only `MAINTENANCE_PATCH` request is ready for its
single authorized publication. It installs one exact read-only runtime-version
helper under the already approved processor root and executes that installed
helper in the same transaction. The helper starts only its own exact
`D:\AFCV1\rt\python.exe` child, binds the PID and creation time, applies a
15-second external wall-clock timeout, and may terminate only that owned child
on timeout. It never queries, stops, restarts, or mutates an existing process
or scheduled task.

Request ID: `REQ_20260828T143500111Z_O3EI1R01`.

Request ZIP:
`work/OPENCV_EDGE_NOTCH_O3EI1/final_o3ei1/REQ_20260828T143500111Z_O3EI1R01.ready.zip`,
SHA-256 `A0FC4A5885CDD6350113212FCB299302E2EB9E8C0AA860BAEC95094F64EC740D`,
7,019 bytes.

Maximum publications: one. Retry: forbidden. Gateway share acceptance is not
execution evidence. Only the matching signed terminal response can resolve the
runtime premise.

## Exact evidence and gates

- The prior signed O3Q2 failure and the missing installed exact version route
  are pinned by supporting observation
  `F2F78E8389FE50C39AF8E3C591F705F4FDB16DAF7E4F0D5BE81029D30835331B`.
- The frozen one-attempt `MUTATE` recovery intent passed with SHA-256
  `662F73AC13ACB607997A4EF48ED917DE85A8C95C0DFF61B16AF7363BA2CDDE52`.
- The exact helper SHA-256 is
  `C4BCE3DBC9ABF91E99AE1E1DEB971EEB60610C2A117E645B5903EC4BAD744E8D`;
  the exact entrypoint SHA-256 is
  `B7453E74C1DF80DB4BAAA5F398870B6C5C99A71959EAD4C8F038B9A4B3812CAA`.
- Windows PowerShell 5.1 local tests passed fixed-version, nonzero-exit,
  malformed-output, entrypoint post-provider failure, and forced-timeout
  cases. The timeout case killed only the helper-owned child. Entrypoint gate
  SHA-256 is
  `38F5608758D083D9F0951F3F53E6B5AA109685F26A064A3BC55BF315574395FF`.
- Final signed package gate SHA-256 is
  `9DE22C2D77312614F6D68C3B4AA9F749A84A3719AF151F8FD3FB030B3670F19F`.
- Exact package rehearsal gate SHA-256 is
  `07BE7BEFC7D4AC8D5607441AAFDE6155C42905722592240D000353C17F4CB69B`.
  It passed exact extraction/signature, create, target-hash idempotence,
  unapproved-predecessor refusal before mutation, post-provider failure with
  output absent, rollback inheritance, and timeout-owned-child cleanup.
- Complete 43-leaf request/response route gate SHA-256 is
  `539227F71AACB9CD96FCFE92BB348264F10B364743622DC0319B9199388AD9B9`.
  The maximum effective path length is 187 and the maximum component length is
  51 with 32 characters reserved.
- Current zero-pending U: share observation SHA-256 is
  `D4966E7E7EAAA04F151B6322397BFA817CBE4E198A57F18EA5316A19521AEB6F`;
  exact persistent-alias gate SHA-256 is
  `E933AA39F2F07AD24FD31E8284193A2E974D6EFE2D5A69E72806FA12F4BC1DD0`.

No JBOD action has occurred yet. Local rehearsal read no image bytes, hashed no
source images, deleted no source, touched no protected processor, changed no
task, acted on no existing process, and activated no live image provider.

## Frozen runtime premise

- executable: `D:\AFCV1\rt\python.exe`
- executable SHA-256:
  `7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1`
- installation manifest: `D:\AFCV1\INSTALLATION.json`
- installation SHA-256:
  `1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596`
- expected OpenCV: `5.0.0`
- expected NumPy: `2.5.1`

The matching response may return `PASS_O3EI1_RUNTIME_PREMISE` or an explicit
version-mismatch/timeout/error/malformed hold. Every non-pass disposition stops
the workflow without retry.

## Unresolved prerequisites and holds, in order

1. Publish O3EI1 once and collect only its matching signed terminal response.
2. Require exact executable/install hashes and exact Python/OpenCV/NumPy
   version evidence. A mismatch or timeout remains a hold; O3EI1 is not retried.
3. Only if that runtime premise passes may one fresh independent Slot16 numeric
   successor reuse the locked BF/DF hashes and unchanged O3P8 detector/config.
4. BF Slot16 coverage remains partial and independent frontside numeric
   validation remains pending.
5. Backside remains unconsumed and requires a separate appearance-regime
   intent and method after frontside closure.
6. Every fiducial designation, map, pose, registration, coverage, sensitivity,
   and independent alignment-transfer gate remains pending.
7. XML, training, production eligibility, and production routing remain held.

O3N1, O3P7, O3Q1, O3TR1, O3TR2, O3RO1, O3RO2, O3RO3, O3SO1, O3SO2, and O3SO3
remain withdrawn/no-retry/non-parent. Their consoles and any unknown process
state remain untouched. No threshold or algorithm changed.

## Exact next action

Commit and push the publish-ready artifacts on
`codex/fiducial-opencv-d-drive`, require clean matching local/origin tips,
reconfirm zero pending requests, publish
`REQ_20260828T143500111Z_O3EI1R01` exactly once through the persistent U:
Project Portal route, and collect only the matching signed terminal response.
Do not retry and do not build or publish a numeric successor until exact
runtime evidence passes.
