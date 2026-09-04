# R18R2 Signed-Unpublished Ready Checkpoint — 2026-09-04

## Disposition

`REQ_R18R2` is the fresh, locally signed, unpublished 21-case R18R
existing-crop regression package. Every local scientific, checksum,
contamination, signature, exact-membership, and round-trip path gate passes.
It has not contacted Project Portal or JBOD and has not read source images.

Classification: `PENDING_GATE`.

The immediate next external execution remains this bounded 21-case regression.
The full-KLARF existing-crop run is not packaged or authorized yet; it belongs
in a fresh successor namespace only after `REQ_R18R2` completes cleanly.

## Isolated scope and source base

- Dedicated worktree:
  `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab-scribe-opencv`
- Branch: `codex/opencv-scribe-deciphering`
- Source base before this package-preparation milestone:
  `38d8941ff70a808bf78b06ab83cb3bb3c1c69b5b`
- Active request ID: `REQ_R18R2`
- Work root: `D:\A2\w\ocv\R18R2`
- Output root: `D:\A2\o\ocv\R18R2`
- The unrelated global targeted-backside phase was neither followed nor
  modified. No canonical checkout, c290/ea39, portal, queue, JBOD, process, or
  image access occurred except the operator-approved read-only acquisition of
  the two exact canonical checksum files before packaging.

## Withdrawn predecessor

The first local build, `REQ_R18R1`, was signed but stopped during exact
packaged-launcher preflight because the launcher's internal payload-manifest
hash still named the draft manifest. It was never published or executed.

- Withdrawn ZIP: `C:\R18RP\REQ_R18R1.ready.zip`
- SHA-256:
  `D6520A8F46F105130EB8A0F2A155B94B1CECEDBE21C89AA655744BBF726090C6`
- Withdrawal gate:
  `work/OPENCV_SCRIBE_R18R/R18R_BUILD1_SIGNED_WITHDRAWN_GATE.json`
- Withdrawal-gate SHA-256:
  `9E85F7C07867DB1EE5DDEDB93C00CCF2AF2DDC68985FF5593C89DF09312FF650`
- Lifecycle: `WITHDRAWN`, no retry, non-parent.

The new failure signature, cause, mandatory preflight, and recovery are
recorded in `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`, SHA-256
`D16FA7A8213551F1FD7290E88FC2925B66D8B7EC0A707FA649C4349569317182`.
R18R2 runs its exact staged launcher preflight before opening the signing
identity or private key, then repeats that preflight from the extracted signed
ZIP.

## Frozen runtime and scientific evidence

- Provider:
  `work/OPENCV_SCRIBE_R18R/ArgosOpenCvScribeV1R18R.py`
  - SHA-256:
    `51C95B3279D253EF717F663F3860CC6B4CA38517706E08E9FE2302BE02CD2BB5`
- R18R wrapper runner:
  `work/OPENCV_SCRIBE_R18R/Run-R18RReferenceIsolatedCorpus.py`
  - SHA-256:
    `B826767EA21BB148DD30A719595B23DD818FD9CFC08B347FEAFD9FD4959F4E3C`
- Frozen envelope worker:
  `work/OPENCV_SCRIBE_R18P/Run-R18PReferenceIsolatedCorpus.py`
  - SHA-256:
    `5B6AA224E844FCEA22DEC6A9D10C863437F039CA73EC258C263DF539905791D0`
- Frozen crop sweep:
  `work/OPENCV_SCRIBE_R18J/ArgosOpenCvScribeCropSweepR18J.py`
  - SHA-256:
    `EF4C58589CA8885B5CBDE0A989D3F94EE8C447925818DC0FA4E50B26B87A8B9F`
- Accepted reader:
  `src/ArgosEdgeLab/Services/Scribe/SemiM12DotMatrixImageReader.cs`
  - SHA-256:
    `0E64D5FBE57556B7FC5A37D6764FDA65CBF780F96A3C994B73954CF985E67206`
- Base reference ZIP SHA-256:
  `56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6`
- Base reference-manifest SHA-256:
  `AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229`
- Supplemental reference-manifest SHA-256:
  `FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114`
- Definitive local image gate SHA-256:
  `566EB33649697713F5E0EFD3E0F04F9861333103BBBC1C1BACFEDE3CD184C82A`

The invariants remain frozen:

- existing paired BF/DF oriented crops only for this 21-case execution;
- missing, blank, wrong-location, boundary-incomplete, structurally unusable,
  or below-floor crops emit no string and an explicit hold;
- displaced `POST2_S17_MISPLACED = 6KB71041XDE5` remains exact;
- all established blank controls remain empty holds;
- Slot24 remains image-first `143B0083SUE6` with a valid checksum;
- no notch/grid/solid-line dependence and no synthetic dots;
- checksum is verify-only and cannot select, invent, or rewrite an image-first
  glyph;
- missing checksum fields fail terminally, evaluation errors fail closed, and
  equal-top hypotheses hold deterministically;
- frozen reference lineage remains 389 correct with 0 previously correct
  harmed; 21 visible exact controls pass and all 40 blank views hold;
- executable runtime contains no lot, slot, physical identity, expected truth,
  glyph-pair, checksum, threshold, test-hook, or authority special case.

## Canonical SEMI M12 checksum gate

- Method SHA-256:
  `E5B78AFBA2614A3D4186298C84CF8E46F4816B0A9F3B2BC3DE751E854C014C2C`
- Verified-vector SHA-256:
  `6911A0E12E81AEFBF59D7EE4FCC99457362DE0834949431E26C27566F6E93F16`
- Test:
  `work/OPENCV_SCRIBE_R18R/Test-R18RCanonicalChecksum.py`
  - SHA-256:
    `46ABFA818CA64979CCD31710632136AF2573D34CE70B08EE1665ED4C364122BF`
- Gate:
  `work/OPENCV_SCRIBE_R18R2/R18R_CANONICAL_CHECKSUM_GATE.json`
  - SHA-256:
    `BB0F36B38A7CB697087B324CDE2037E8F2B8ED184BCE8DB71EA1BCB3DB787407`

The direct runtime gate passes all 19 canonical vectors and rejects all 19
deterministic invalid controls. It explicitly records
`checksumVerificationRequired=true`, `checksumUsedForImageFirst=false`, and
`checksumMutationAllowed=false`. Both the test and canonical files are absent
from the runtime ZIP.

## Signed package

- ZIP:
  `work/OPENCV_SCRIBE_R18R2/final/REQ_R18R2.ready.zip`
- Bytes: `164276`
- SHA-256:
  `E541EB7FCCD19A04BFE401D6FCFB70B7976C0F47E9F4F1AD8E1FCC1626EEF300`
- Request-manifest SHA-256:
  `411B7BD36E66CA8D6E546A33746DB7B1C4C7078AF3DFBF07133D748BB42FE80C`
- Request-signature SHA-256:
  `B5E56FDCC6D8FB92C0CB3D875B0081EA137A21372ACD7953A91D494D0DCFE09F`
- Manifest expiry:
  `2026-09-05T18:12:21.969923-05:00`
- Exact ZIP members: `31`
- Payload-manifest files: `27`
- Signed manifest file rows: `29`
- Python runtime sources: `15`
- Exact member-set SHA-256:
  `CD49F02C4708E66DF6807D96A8E99E942536C150864F20794B6B852FBEB3E994`

Key frozen package artifacts:

| Artifact | SHA-256 |
|---|---|
| `Build-R18RRequest.ps1` | `66A0FDBAEEA283B615F9ABBAC7B0E875AFA8F721E06E9FE36B9EACA8BE5B3A5D` |
| `Invoke-R18RReferenceIsolatedLaunch.ps1` | `A0283E05F71240A2ABA74E2BB5DCDB8C905E3769564BC5504CCCEC604258D6A3` |
| `R18R_PAYLOAD_MANIFEST.json` | `52114D3C344F9864918844A987B59984AB5578A076AE403701894A52DA551FD8` |
| `R18R_REVIEW_COHORT.json` | `7393A6CB84F3CF246DCA3751DFCCB76422198C25270CA2759FBF260D2DE8AF56` |
| `MAINTENANCE_DEFINITION.json` | `FA9714B86ED327E33FB0F2FD02A9BDAE5E0A435D78D037B48AB131D59BADA399` |
| `PREACTION_R18R_REFERENCE_ISOLATED_PREPARATION.json` | `CFF735C0D213367034673BFE0AB58DE5F733AD47AC1F4087AB95F4C24E325F1D` |
| `R18R_REFERENCE_ISOLATION_LOCAL_GATE.json` | `9E645CCEE7BB4C62610AD1D93418985F2F3FB3A3DCD68007A3ECA56D30784471` |
| `R18R_COHORT_BINDING_GATE.json` | `866AA2921A01BF6CE91CEDD71DE53841723131C60A6119B3BA36844B3328434D` |
| `R18R_PATH_PLAN_GATE.json` | `616761ADFAC1A764521A133A5614835CA54404839A1C219E6376B912C7D31BF9` |
| `R18R_FINAL_PACKAGE_GATE.json` | `3970AE7F63E5309DD6425EEEC72865AF56215B4226398064F324162E3DB2F4A4` |
| `R18R_PACKAGED_RUNTIME_GATE.json` | `F26EC0447026B76E458C104350D5285EB124FB209D804E3F27C07FEFBE13D5FA` |
| `REQ_R18R2.ready.zip.complete_route_gate.json` | `C66F9E564639E5080E76D14BDDBA0B01E3CB7F96FB53CDB9E29F1EBFB2E3F617` |
| `R18R_FULL_ROUND_TRIP_PATH_GATE.json` | `CD6AB17E09C12B23557048B3B3A7AB0EC2DFDFF68439A01474B41240CB66C81C` |
| `R18R_EXACT_PACKAGE_PATH_GATE.json` | `077EE30402CBD9A5F72191972B2CA14E63B355B6C9A24102D075D6F57E6D8A38` |

The final signature verifies. Source and extracted runtime contamination gates
report zero forbidden package paths, zero test artifacts, zero runtime
overrides, zero hard-coded/configuration identity leaks, and zero executable
production-shaped identity literals. No Python bytecode cache exists.

The exact 26-candidate full round-trip gate passes with maximum path length
164, maximum effective length 196 including 32 reserved characters, maximum
component length 55, and zero unsafe paths. The exact package-path test
independently re-enumerates all 31 ZIP members and binds the signed definition's
R18R2 work/output roots.

## Authority and effects

- Review-only: true.
- Publication authorized: false.
- Explicit fresh `PUBLISH` still required: true.
- Identity acceptance, automatic reference admission, activation, training,
  XML, production routing, source mutation, and source deletion: false.
- Maximum publication: one.
- Retry: false.
- Portal/JBOD/queue/process/image access: none.
- Target execution or worker start: none.

## Exact next action

Remain idle until the operator sends a fresh literal `PUBLISH` for
`REQ_R18R2`. On that instruction only, create and pin the narrow R18R2
publication authority and exact publisher, rerun the required continuity,
queue, namespace, branch, signature, package, and path gates, publish the
frozen ZIP exactly once, immediately collect its exact signed response, and
prove `D:\A2\o\ocv\R18R2` exists before monitoring. No retry.

If the bounded 21-case regression completes cleanly, the next development
stage is a fresh full-KLARF existing-crop successor. Do not build or publish
that successor from this checkpoint before the R18R2 result is reviewed.
