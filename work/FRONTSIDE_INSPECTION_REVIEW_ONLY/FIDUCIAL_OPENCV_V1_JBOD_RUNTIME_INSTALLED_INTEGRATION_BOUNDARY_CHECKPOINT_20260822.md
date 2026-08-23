# FIDCV1 JBOD OpenCV Runtime Installed and Integration Boundary Locked — 2026-08-22

## Disposition

`PENDING_GATE`

This checkpoint advances the isolated, review-only non-FS15 fiducial development lane. It does not change the authoritative AVC1 provisional-live-progress stop, does not claim a fiducial transfer pass, and grants no alignment, XML, training, production-scoring, or production-routing authority.

## Authoritative repository

- Repository: `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab`
- Base commit verified present and current at the start of this work: `bb09223748c446f0b9e38656d80ca996049a3e55`
- Working branch: `codex/fiducial-opencv-d-drive`
- The Codex-managed worktree is not authoritative.

## Qualified environment observation

One FIC1 endpoint capability improvement returned matching signed `PASS_MAINTENANCE_PATCH`. The change added a bounded environment-inventory STATUS capability while mechanically preserving the installed DATA_PULL, maintenance, queue, and response implementations. The follow-up FIO1 request returned matching signed `PASS_DATA_PULL` and proved:

- `D:\` total bytes: `479994788577280`;
- `D:\` available free bytes: `476891750203392`;
- `D:\AFCV1` was absent and not a reparse point;
- OS and endpoint process are 64-bit AMD64;
- Windows PowerShell is `5.1.26100.7920`.

FIC1 terminal gate: `work/FIDUCIAL_JBOD_INVENTORY_CAPABILITY_FIC1/FIC1_TERMINAL_RESPONSE_GATE.json`, SHA-256 `650B078B3DCDC12A2B08D0A8891E4582C8120AE410937821DA3BDB885C69D5DA`.

FIO1 terminal gate: `work/FIDUCIAL_JBOD_INVENTORY_OBSERVATION_FIO1/FIO1_TERMINAL_RESPONSE_GATE.json`, SHA-256 `9B9CE3CC9420135EAB829D2B5CBE9C6AD0CD2596446729E078B0860BD224F83C`.

## D-only OpenCV installation

The exact FOI1 request ZIP was built from the signed request, passed exact extraction/signature/payload checks, passed a 54-row complete round-trip path gate with maximum effective length 187 and maximum component length 57, and was published once by create-new copy. The JBOD returned matching signed `PASS_MAINTENANCE_PATCH` response `R_A2C33C30A777_20260822152512001_bbc860ce`.

The signed maintenance stdout proves:

- entrypoint state `PASS_FIDCV1_OPENCV_D_ONLY_INSTALLED`;
- target root `D:\AFCV1`;
- runtime root `D:\AFCV1\rt`;
- installed manifest SHA-256 `1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596`;
- final installed runtime self-test `PASS_OPENCV_NATIVE_POSE_RUNTIME_PREFLIGHT`;
- no inspection-task or processor-task change;
- no source deletion, image-byte processing, or wafer action.

FOI1 exact request ZIP: `work/FIDUCIAL_OPENCV_JBOD_INSTALL_FOI1/final/REQ_FOI1.ready.zip`, SHA-256 `44E806C7C799509CA7E4D084E0F049C1F001A7C2FD4ADC3440D4624544812C12`, 66,859,425 bytes.

FOI1 terminal gate: `work/FIDUCIAL_OPENCV_JBOD_INSTALL_FOI1/FOI1_TERMINAL_RESPONSE_GATE.json`, SHA-256 `E54585857204BDC2FE9A4632BAF3308987F195F91FFE00B9E98A0D78E56B169C`.

## Integration boundary

`work/FIDUCIAL_OPENCV_JBOD_INSTALL_FOI1/INTEGRATION_BOUNDARY.json`, SHA-256 `397B49CC7B0F94F326ABD42C04B699BF1B56149D50895A11E43FC9C71E44FF93`, is `LOCKED_INPUT`.

`D:\AFCV1` is a storage placement for the portable runtime, not a hard-coded processor contract. A future processor adapter must obtain its runtime and engine entrypoints from installed configuration. BF/DF paths, output root, map/pose, designated site, appearance regime, and combination/lot eligibility must come from a versioned job and external authority profile. The geometry engine returns measurements and explicit hold states; it never grants production authority.

The bundled `NativeFrontsideWaferPoseOpenCvV1.py` remains a diagnostic implementation. Its hard-coded review-only and FS15-development refusal controls are development safety boundaries and are explicitly not the future activation entrypoint. Finished integration must pass provider-selection, disabled-path regression, schema-contract, missing-runtime fail-closed, and unqualified-appearance-regime fail-closed tests without a processor source edit to enable a qualified provider.

## Current development prerequisite

The declared development partition remains PFC003 and PFC010. Their four exact native BF/DF source hashes are not yet observed, so `developmentPixelScoringAllowed` remains false. No real test-lot image pixels have been scored. Independent validation identities remain unselected and must be fresh, paired BF/DF acquisitions selected only after development freeze.

The next proportional step is one bounded, configuration-driven source-fingerprint action over those four exact development files. It may calculate hashes and metadata only and must not perform OpenCV pixel scoring. After those hashes are frozen into the development partition, a separately gated review-only OpenCV development run may be attempted on D:. No FS15 input or outcome may be used for tuning.

## Unchanged boundaries

- AVC1 remains healthy and untouched; no repair, restart, or extra validation was issued.
- R10 and AVS1 remain `WITHDRAWN`, non-replayable, and ineligible as successor parents.
- FS15 remains `PENDING_GATE`; its outcomes remain prohibited tuning evidence.
- PFC004 remains preserved at six of six pose-qualified wafers without retuning; Slot07 remains a notch hold.
- No XML, training, production scoring, production routing, source deletion, wafer abort, or inspection-task change is authorized.
