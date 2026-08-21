# FS15 fresh-task execution handoff

Date: 2026-08-20

Disposition: `PENDING_GATE`

The PFC004 designated-fiducial method is already terminal at six of six
pose-qualified wafers. Do not retune or redesign the fiducial. The remaining
geometric gate is the direct-native notch regression.

## Frozen inputs

- Job: `work/PNR2/REGRESSION_JOB.json`, SHA-256
  `FCD92AD365BA0908AB3F59195F615EDC20CE99E9F368C961187156AD8D09C851`.
- Native engine: `work/SCRIBE_REVIEW_ONLY/tools/NativeFrontsideWaferPoseAudit.cs`,
  SHA-256
  `39A16330B11324122C9B3D12BBE7B9CE702B3C2CBB3BB6B321F46CE1ECD3CDA5`.
- Invocation harness:
  `work/PATTERNED_FIDUCIAL_INVENTORY/tools/Invoke-NativeFrontsideWaferPoseV3.ps1`,
  SHA-256
  `662ECAEC9974C496425E8D5887F9F9BA3F053D5EB172F27AD836036E49959532`.
- Synthetic control harness:
  `work/SCRIBE_REVIEW_ONLY/tools/Test-NativeFrontsideWaferPoseAuditSynthetic.ps1`,
  SHA-256
  `815C90020528B1E0E2C43E837A73E78999680361C8D8E421F3744719DF4C21E7`.
- Fresh output root: `work/PNR3/FS15_NATIVE_V1`; it does not exist at this
  handoff.

The job contains exactly 15 identities, `A01` through `A15`, and 30 BF/DF
source leaves. Every declared source leaf exists. The source-candidate index
hash matches the frozen job. No source path component exceeds 80 characters.
The exact harness parser/safety preflight passes with zero violations. The
planned output root, summary, and longest identity audit leaf pass the path
budget with 32 characters of suffix reserve, maximum effective length 144,
and maximum component length 32.

No real-wafer preflight or regression was executed in the prior task because
the metadata-only session guard was already at 215.893 MiB and the governing
checkpoint explicitly requires a fresh task for the image-heavy FS15 run.

## Fresh-task sequence

1. Read the mandatory continuation files and run project continuity and Codex
   session-safety checks.
2. Reconfirm the four frozen hashes, the fresh absent output root, exact source
   existence, harness safety, and path budget.
3. Run the exact non-mutating preflight:

   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File work\PATTERNED_FIDUCIAL_INVENTORY\tools\Invoke-NativeFrontsideWaferPoseV3.ps1 -JobConfigPath work\PNR2\REGRESSION_JOB.json -OutputRoot work\PNR3\FS15_NATIVE_V1 -Preflight`

4. Only after exact preflight PASS, run the same command without `-Preflight`.
5. Validate all 15 audit rows before producing any reviewer. The manufactured
   notch near 89.9 degrees must remain selected while the physical chipout near
   85.5 degrees remains preserved but unselected. Thumbnail/coarse pose fields
   have zero authority.
6. If FS15 passes, run the nine V1E macro-pose holds without tuning. Only then
   fan the unchanged method to 77 peer acquisitions.

Any BF/DF pose disagreement, incomplete native coverage, multiple plausible
physical notch morphology, or reciprocal-scribe interruption remains an
operator-visible hold. Slot07 remains a notch-review hold. This work is
review-only and creates no XML, training, or production authority.

