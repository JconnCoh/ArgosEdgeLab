# Patterned notch thumbnail-pose withdrawal checkpoint - 2026-08-19

Disposition: `WITHDRAWN`

This is a parallel review-only diagnostic checkpoint.  It does not replace or
advance the active JBOD storage-copy gate.  The governing active checkpoint
remains
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/JBOD_D2S3_SIGNED_STATUS_COPY_IN_PROGRESS_AND_RECOVERY_CHECKPOINT_20260819.md`,
SHA-256
`605BA259A984E31A0E35FB3415B0F020E9168C956F63F52BBA4F150459E8E895`.

## Operator-caught pose dependency

The operator correctly identified that a thumbnail-derived pose can be wrong
when a chipout biases the fitted wafer circle or wins the coarse indentation
score.  Scaling that center/radius into the native source then moves the native
crop, limits native search to the wrong angle, and corrupts every downstream
notch, scribe, and fiducial coordinate.  Opening full-resolution pixels after
that decision does not make the pose native.

The attempted V2 integration did exactly that: it propagated coarse thumbnail
center, radius, and candidate angle into its native crop/refinement stage.  It
violated the existing requirement in
`work/SCRIBE_REVIEW_ONLY/FRONTSIDE_NOTCH_AND_SCRIBE_IDENTITY_METHOD.md`
that the final boundary and notch be refined from native pixels and that a
coarse angle never exclude the actual notch.

## Withdrawal evidence

`work/PATTERNED_FIDUCIAL_INVENTORY/tools/Invoke-PatternedNotchRecoveryV2.ps1`
is `WITHDRAWN`, 19,585 bytes, SHA-256
`02CB9D54F8D8FE6ABBBDA072784F845ACA0EDC254703CFF058073273F5A48298`.
It now throws
`WITHDRAWN_NATIVE_POSE_STILL_SCALED_FROM_THUMBNAIL` before any function or
workflow action can run.

Its exact 15-wafer invocation reached only a non-mutating hash/dimension
preflight.  No detector result, native pose result, crop, or output root was
created; `work/PNR2/FS15_V2` is absent.  The preserved job input is
`work/PNR2/REGRESSION_JOB.json`, 18,128 bytes, SHA-256
`FCD92AD365BA0908AB3F59195F615EDC20CE99E9F368C961187156AD8D09C851`.
It and
`work/PATTERNED_FIDUCIAL_INVENTORY/tools/Build-PatternedNotchRecoveryV2RegressionJob.ps1`,
SHA-256
`1B730EDB2EFB7397A4E6AAFB01A664389FCDE79253CA985929AB976E8D0D3A75`,
are diagnostic history only and cannot establish a corrected notch result.

The new failure signature, cause, preflight, and recovery are recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`, SHA-256
`FBA2944330101182EA1BE15F31C99CBD39690B8DA1C04B92016E0B759C91CF7C`.

## Required replacement

The replacement must fit the normal wafer perimeter directly from distributed
full-resolution BF and DF boundary samples around the entire circumference.
The fit must robustly exclude notch, chipout, pattern interruption, and
unsupported spans.  It must then scan that measured native circumference for
all physical indentation candidates.  Thumbnail center/radius/angle/rank must
have zero weight in the final pose and candidate eligibility; a thumbnail may
at most nominate broad read regions for I/O efficiency.

The native engine must preserve these dispositions:

- a channel-local inward response without independent physical-boundary
  displacement is appearance-only and cannot establish pose;
- every BF/DF-supported indentation remains a physical competitor;
- manufactured-notch morphology requires two mouths, a tip, bounded native
  width/depth, symmetry, and direct support;
- pattern-interrupted candidates require the reciprocal notch-relative scribe
  gate;
- multiple plausible physical candidates or incomplete perimeter evidence emit
  `FRONTSIDE_NOTCH_ALIGNMENT_HOLD` rather than a forced angle.

## Regression sequence

First run the replacement on the sealed 15-wafer FS15 native BF/DF set.  It
must preserve the known giant-chipout control by selecting the supported
manufactured notch near 89.9 degrees rather than the physical chipout near
85.5 degrees, and it must reproduce the independently supported reciprocal
scribe disposition without thumbnail pose authority.  Next run the nine V1E
macro-pose holds.  Only after those fixed cases pass or fail closed may the
unchanged native method fan out without tuning to all 77 cataloged peer
acquisitions.

No notch, scribe, fiducial, detector, XML, training, alignment-transfer, or
production authority is created by this checkpoint.  The active storage-copy
hold, D3 prohibition, no-delete rule, no-cutover rule, and no-inspection-task
change remain unchanged.
