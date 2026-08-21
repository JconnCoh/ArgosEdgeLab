# Patterned notch direct-native pose V3 implementation checkpoint - 2026-08-19

Disposition: `PENDING_GATE`

This is a parallel review-only implementation checkpoint.  It does not replace
or advance the active JBOD storage-copy gate.  The governing active checkpoint
remains
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/JBOD_D2S3_SIGNED_STATUS_COPY_IN_PROGRESS_AND_RECOVERY_CHECKPOINT_20260819.md`,
SHA-256
`605BA259A984E31A0E35FB3415B0F020E9168C956F63F52BBA4F150459E8E895`.

Parent notch checkpoint:
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/PATTERNED_NOTCH_THUMBNAIL_POSE_WITHDRAWAL_CHECKPOINT_20260819.md`,
SHA-256
`9B453DA9DEF1CDA112CCCFC6E8A0E203E7F44AAD8864DAB29DEE344516819CF2`.

## Implemented correction

`work/SCRIBE_REVIEW_ONLY/tools/NativeFrontsideWaferPoseAudit.cs`, 50,426
bytes, SHA-256
`39A16330B11324122C9B3D12BBE7B9CE702B3C2CBB3BB6B321F46CE1ECD3CDA5`,
implements a direct full-resolution BF/DF source-BMP pose audit.  Its public API
accepts BF source, DF source, output JSON, and identity only.  It cannot accept
a thumbnail, coarse center/radius, or coarse candidate angle.

The implementation:

- memory-maps the exact uncompressed 24-bit source BMPs and samples source
  pixels without resampling;
- starts only from raster dimensions, fits distributed BF perimeter evidence,
  independently fits DF perimeter evidence, and requires bounded channel
  center/radius agreement;
- rejects incomplete radial windows instead of treating off-raster pixels as
  zero;
- initializes circle recovery from deterministic, widely separated native
  three-point hypotheses so a broad coherent chipout cannot capture a global
  least-squares initializer;
- robustly refines only the best-supported normal perimeter;
- scans the complete measured native circumference at 0.05-degree spacing;
- keeps BF-only inward evidence out of pose authority, preserves BF/DF physical
  indentations, applies the existing native 35--260 px mouth and 12--140 px BF
  / 10--140 px DF morphology envelope, and fails closed on ambiguity;
- keeps pattern-interrupted morphology on the reciprocal-scribe hold path.

The bounded invocation harness is
`work/PATTERNED_FIDUCIAL_INVENTORY/tools/Invoke-NativeFrontsideWaferPoseV3.ps1`,
8,497 bytes, SHA-256
`662ECAEC9974C496425E8D5887F9F9BA3F053D5EB172F27AD836036E49959532`.
PowerShell parsing, C# `/unsafe /optimize` compilation, and the mandatory
PowerShell harness-safety gate pass.  The planned longest FS15 output leaf
passes the Windows path gate at path length 109, effective length 141 with
32-character reserve, and maximum component length 32.

## Synthetic chipout regression

The exact regression harness is
`work/SCRIBE_REVIEW_ONLY/tools/Test-NativeFrontsideWaferPoseAuditSynthetic.ps1`,
6,400 bytes, SHA-256
`815C90020528B1E0E2C43E837A73E78999680361C8D8E421F3744719DF4C21E7`.
It creates independent 1,200 by 1,200 BF/DF controls containing:

- one compact symmetric manufactured notch;
- one broad/deep BF+DF physical chipout outside the notch envelope; and
- one BF-only notch-like appearance competitor absent from DF.

`work/PNR3/SYNTH_V3/SYNTH_NATIVE_WAFER_POSE_AUDIT.json`, SHA-256
`1A186DC80F77582B9FE5B1F0C3BF5D542D1BEF4C272306133CCB573B98784326`,
passes with:

- state `FRONTSIDE_NOTCH_NATIVE_REVIEW_ONLY_CANDIDATE`;
- direct pose center `(599.870802, 589.503002)` and radius `514.960558` px;
- BF/DF center difference `0.041746` px and radius difference `0.015270` px;
- perimeter support fraction `1.0` and zero unsupported degrees;
- two preserved physical indentations;
- exactly one manufactured-notch morphology;
- selected notch angle `89.95` degrees;
- mouth width `71.902058` px, BF depth `51.960558` px, DF depth
  `49.960558` px, symmetry `0.982613`, and centered tip;
- `thumbnailPoseAuthority=false`, `thumbnailCandidateAuthority=false`, and no
  thumbnail input in the API.

`work/PNR3/SYNTH_V1` and `work/PNR3/SYNTH_V2` are preserved
`DIAGNOSTIC_ONLY` failures.  V1 exposed an incomplete-window/image-border
transition bug.  V2 exposed that residual trimming after an ordinary global
least-squares initializer is not robust to a coherent physical chipout.  Both
causes, preflights, and recoveries are now recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`, SHA-256
`CA60C1ADF1B3886FBCA0D0465E86124E0ABFA91A3660F12CBDE7B3D358A261EE`.
Neither failure was run on real-wafer evidence.

## Mandatory next gate

The next action is the sealed FS15 15-wafer native BF/DF regression using
`work/PNR2/REGRESSION_JOB.json`, SHA-256
`FCD92AD365BA0908AB3F59195F615EDC20CE99E9F368C961187156AD8D09C851`,
and a fresh output root `work/PNR3/FS15_NATIVE_V1`.  The existing
`existingCoarseAuditPath` fields are explicitly ignored.  The run must prove
that all final center/radius/candidate results come only from full-resolution
BF/DF and must preserve the known giant-chipout control: supported manufactured
notch near 89.9 degrees, physical chipout near 85.5 degrees retained but not
selected.

After the 15-wafer result is checked against the sealed prior native evidence,
run the nine patterned V1E macro-pose holds.  Only then fan the unchanged method
out without tuning to all 77 peer acquisitions.  Pattern-interrupted results
remain reciprocal-scribe holds; any BF/DF pose disagreement, incomplete native
coverage, or multiple plausible physical notch morphology remains an explicit
operator-visible alignment hold.

The metadata-only session guard is already in
`CHECKPOINT_AND_PREPARE_ROTATION` above the 128 MiB checkpoint threshold.
Project policy therefore requires a fresh Codex task before the 15-wafer
image-heavy/long-running regression.  Continue from this file, not from image
history.

No detector, fiducial, scribe, alignment-transfer, XML, training, or production
authority is created by this implementation checkpoint.  The active
storage-copy hold, D3 prohibition, no-delete rule, no-cutover rule, and
no-inspection-task-change invariants remain unchanged.
