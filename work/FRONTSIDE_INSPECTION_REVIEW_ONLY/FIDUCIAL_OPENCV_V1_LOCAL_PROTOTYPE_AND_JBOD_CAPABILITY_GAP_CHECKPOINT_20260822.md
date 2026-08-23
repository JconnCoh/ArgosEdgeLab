# FIDCV1 local OpenCV prototype and JBOD capability-gap checkpoint

Date: 2026-08-22

Revision: `FIDCV1_LOCAL_PROTOTYPE_AND_JBOD_CAPABILITY_GAP`

Disposition: `PENDING_GATE`
Authority: review-only diagnostics; no alignment, training, XML, production,
deletion, or wafer authority

## Repository and continuity basis

Work was performed only in the authoritative repository
`C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab` on branch
`codex/fiducial-opencv-d-drive`. Commit
`bb09223748c446f0b9e38656d80ca996049a3e55` remains present and was the branch
HEAD before this uncommitted fiducial work began. The Codex-managed worktree was
not used.

The global FS15 V3 terminal hold remains the governing unresolved prerequisite.
V3 is still withdrawn because it conditions DF fitting on BF qualification and
averages channel poses. FS15 remains prohibited as tuning evidence; the nine
V1E holds and 77 peers remain unrun. PFC004 remains six of six pose-qualified
without retuning and Slot07 remains a notch hold.

The healthy AVC1 processor was not contacted, inspected, changed, restarted, or
used for this work. R10 and AVS1 remain withdrawn and non-replayable.

## Declared development partition

Before any new real pixel outcome was inspected, FIDCV1 declared two non-FS15,
non-BowComp, non-macro-pose-hold development identities:

- `PFC003` — `62628-281_20260813112015_Slot02`, product `1627304/A00`;
- `PFC010` — `62616-115_20260807120245_Slot23`, product `1427010/A01`.

The locked partition is
`work/FIDUCIAL_OPENCV_V1/DEVELOPMENT_PARTITION.json`, SHA-256
`FD54A18351D8FB70A814B4CA34BED643FC25F32904299CE5222AC84EAE75504F`.
Its BF/DF source hashes remain unobserved, `pixelScoringAllowed` remains false,
and no real image bytes were read. Independent paired BF/DF validation identities
remain deliberately unselected until after development freeze and must not
overlap this partition or FS15.

The FIDCV1 model-run record is
`work/FIDUCIAL_OPENCV_V1/FIDUCIAL_MODEL_RUN.json`, SHA-256
`6C36AE0BB40B9ECD0353B15E54716D9E508F648A37A953304C7F4B321C91FA3D`.
It binds `ARGOS_FIDUCIAL_MODEL_WORKFLOW_V2` SHA-256
`1787BBE811DE8F6D0089BC7D9F35BE1602013C3CE01569D3938A8073DF256BE4`.

## Independent-channel OpenCV prototype

`NativeFrontsideWaferPoseOpenCvV1.py` implements native-pixel BF and DF
sampling, fitting, and candidate extraction independently. It does not condition
one channel on the other and never averages BF/DF poses. Cross-channel matching
is diagnostic: BF-only and DF-only inward responses stay explicit and are
ineligible to establish physical wafer pose. Zero or multiple paired physical
indentations hold. A single paired physical indentation also holds until
manufactured-notch morphology and reciprocal notch-relative scribe support are
proved; no manufactured-notch or fiducial alignment authority is granted.

Prototype SHA-256:
`3CC4630B3A689C80887C2B8572C3A0C37B5342301E88DD8FFF4046E67EFB4DB9`.

The fresh V3 synthetic gate passed all five cases:

- clean paired perimeter: no physical indentation;
- one paired indentation: one physical candidate and the conservative
  morphology/scribe hold, with unmatched channel-local evidence preserved;
- BF-only appearance competitor: no physical candidate;
- two paired physical competitors: ambiguity hold;
- channel-pose disagreement: perimeter-agreement hold.

The same gate proved exact BF-result invariance under DF mutation, rejected FS15
as a development input, and preserved all review-only authority boundaries.
Gate: `work/FIDUCIAL_OPENCV_V1/SYNTHETIC_GATE_V3/SYNTHETIC_GATE.json`, SHA-256
`4454C3A4CC0EFF15C5E81335DEE55652C2EAE8FA65AEF9D4858F19A4B8BE4986`.

The earlier V2 synthetic output is retained as withdrawn evidence. It exposed a
conservative test defect: the test incorrectly required zero unmatched DF-only
fragments after one valid physical BF/DF match. The implementation correctly
preserved that channel-local evidence. The expectation was corrected only in a
fresh V3 namespace, and the new prevention rule was added to the Windows failure
memory.

## Portable D:-drive runtime readiness

An isolated 64-bit portable runtime was built locally from exact pinned inputs:
CPython 3.13.2, OpenCV headless 5.0.0.93 (runtime version 5.0.0), and NumPy
2.5.2. The bundle is
`work/FIDUCIAL_OPENCV_V1/portable/FIDCV1_PORTABLE_OPENCV_RUNTIME.zip`, 67,277,595
bytes, SHA-256
`467B210E941725724AE7F6F90CF5F7C162A51BD2E9018A7A0A768CA7AEE777D8`.

Its local stage and fresh extraction each contain 1,034 files and 180,627,977
bytes with identical tree SHA-256
`104CCE5D12FD7BED0CBB3DBD7CAFCDC663FEEDB404786F32A7AF28E5B4975FD7`.
Both exact runtimes passed version and OpenCV execution preflight. Runtime gate:
`work/FIDUCIAL_OPENCV_V1/portable/FIDCV1_PORTABLE_RUNTIME_GATE.json`, SHA-256
`6BCA2B3FA69416BE9E7DE9D02B606081A24C976275C5A4D1B1E83D133D30A409`.

The full five-case synthetic suite then passed again using the fresh extracted
portable runtime. Portable synthetic gate:
`work/FIDUCIAL_OPENCV_V1/SYNTHETIC_GATE_PORTABLE_V1/SYNTHETIC_GATE.json`, SHA-256
`0F3AA230AD1CDBBEC2BD47F5AD7C6834FA98282739A1FBFC247F66A537049558`.

The planned JBOD roots are intentionally short: `D:\AFCV1`, `D:\AFCV1\rt`,
and `D:\AFCV1\out`. Every planned source, endpoint, partial, and output leaf
passed the path-budget gate; the maximum observed effective length was 175,
below the 200 warning boundary.

## JBOD capability gap and stop boundary

No runtime was published to or installed on the JBOD. The installed endpoint
configuration and current route-capability inventory prove that qualified
`STATUS` cannot return current D: capacity, target-root state, or host/runtime
architecture, while `DATA_PULL` can only return exact existing files under
approved roots. No qualified generic direct-admin route was found.

The exact missing preinstallation facts are current D: free bytes, exact
`D:\AFCV1` root state, JBOD OS/process architecture, and existing Python/OpenCV
runtime inventory. Without them, extraction capacity and collision safety
cannot be proved. `MAINTENANCE_PATCH` is prohibited as an observation route.

Capability-gap record:
`work/FIDUCIAL_OPENCV_V1/JBOD_CAPABILITY_GAP.json`, SHA-256
`B2EC65578921675C1CB87487FD9694176940D0B2B79EC1E2F59AF46A68738818`.
State: `HOLD_JBOD_READ_ONLY_CAPABILITY_GAP`.

Checkpoint preaction contract:
`work/FIDUCIAL_OPENCV_V1/CHECKPOINT_PREACTION.json`. The exact Windows
PowerShell 5.1 preflight returned `PASS_ARGOS_ZERO_RECURRENCE_PREACTION` across
90 classified history issues and 17 pinned dependencies.

## Next authorized choice

Continuation requires one explicit choice outside the currently qualified
capability set:

1. authorize one bounded generic read-only endpoint capability improvement that
   reports D: capacity/root state and host/runtime inventory; or
2. authorize one rehearsed operator-local read-only preflight that records the
   same facts.

Only after that observation passes may a separately gated isolated portable
runtime deployment to `D:\AFCV1` be considered. This checkpoint does not
authorize endpoint mutation, installation, real-image access, threshold tuning,
operator fiducial presentation, task/process action, queue/ledger mutation,
source deletion, XML, training, production routing, or wafer action.
