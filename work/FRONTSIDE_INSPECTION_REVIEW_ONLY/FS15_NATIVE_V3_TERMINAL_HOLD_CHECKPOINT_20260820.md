# FS15 direct-native V3 terminal hold checkpoint

Date: 2026-08-20

Disposition: `PENDING_GATE`

State: `HOLD_FS15_NATIVE_POSE_V3_NOT_QUALIFIED`

The frozen FS15 direct-native regression completed under Windows PowerShell
5.1 after the exact non-mutating preflight passed. The run used all 15 sealed
identities `A01` through `A15`, all 30 BF/DF source hashes matched, and the
output contains exactly the 15 expected audit files plus `SUMMARY.json` with
no missing, extra, or hash-mismatched file.

The terminal summary is
`work/PNR3/FS15_NATIVE_V1/SUMMARY.json`, SHA-256
`2FCC3DB1D76E245FDEA81E84CDCFD231AAC239536B9C8EBB94BA67FA65BF2219`.
Its state is `HOLD_NATIVE_FRONTSIDE_WAFER_POSE_V3_REVIEW_REQUIRED`.
The machine terminal gate is
`work/PNR3/FS15_NATIVE_V1_TERMINAL_GATE.json`, SHA-256
`F044F46AA7074EAA278A419FD6AC1AD39872CC5DF83670727B2A3E259D3F4559`.

## Frozen result

- All 15 rows are
  `FRONTSIDE_NOTCH_ALIGNMENT_HOLD_NATIVE_PERIMETER_NOT_QUALIFIED`.
- BF perimeter qualification is 12/15. The three BF holds are A01, A07, and
  A09.
- DF perimeter qualification is 0/15. DF fitting was attempted on the 12
  BF-qualified rows; their frozen DF inlier fractions range from 0.501389 to
  0.696927, below the unchanged 0.70 gate.
- Because perimeter qualification failed first, no manufactured-notch,
  physical-indentation, pattern-interrupted, or selected-candidate decision
  was reached. The expected manufactured-notch-versus-chipout decision is not
  claimed.
- Thumbnail pose and thumbnail candidate authority remain false. All output
  remains review-only, training-ineligible, XML-ineligible, and
  production-ineligible.

The nine V1E macro-pose holds and 77 peers were not run. Their prerequisite was
an FS15 pass, and that prerequisite failed closed.

## Source-contract finding

The frozen V3 source is not reusable. Static inspection after the terminal hold
showed that DF fitting is conditioned on BF qualification, its search window is
derived from the BF center/radius, and the implementation averages BF and DF
circle parameters when both qualify. Those behaviors do not implement the
governing independent BF/DF transform contract. No FS15 row reached the
averaging branch, but the mismatch blocks any later pass or fanout claim from
this revision.

`work/SCRIBE_REVIEW_ONLY/tools/NativeFrontsideWaferPoseAudit.cs`, SHA-256
`39A16330B11324122C9B3D12BBE7B9CE702B3C2CBB3BB6B321F46CE1ECD3CDA5`,
is therefore `WITHDRAWN` from successor-parent and execution use. The exact
failed output remains immutable terminal hold evidence and is not a tuning
set. A corrected revision must use a separately declared development
partition, fit the complete native BF and DF perimeters independently, use
agreement only as a diagnostic gate, never average transforms, and reserve a
new independent paired validation set because FS15 is now exposed.

## Path and recurrence gates

The frozen parent job remains unchanged at SHA-256
`FCD92AD365BA0908AB3F59195F615EDC20CE99E9F368C961187156AD8D09C851`.
The short-path transport job is
`work/PNR2/REGRESSION_JOB_R1.json`, SHA-256
`05D508D8D5AD4A3457B5543DF2AD0774DBA8CC21B2C5A8F0A453322547CF160D`.
It preserves all identities, source-relative leaves, source hashes, source
index hash, and authority with zero semantic mismatch and records
`imageContentChanged=false`. Existing `R:\` maps exactly to the workspace and
hashes the `AGENTS.md` sentinel identically.

All 36 exact Windows PowerShell 5.1 path candidates passed with 32 characters
of suffix reserve, maximum effective length 185, and maximum component length
52. A PowerShell 7.6.5 overload-binding incompatibility initially treated the
whole aliased path as one component; it was metadata-only, is recorded in the
durable failure memory, and its result is ineligible. Only the Windows
PowerShell 5.1 gate is authoritative.

The pre-execution zero-recurrence contract is
`work/ZR_FS15_20260820.json`, SHA-256
`828177F6D6D7C2E05A270A63F1884F63A58A6D4C9F1472FB1141EFF534CA177D`;
its durable pass result has SHA-256
`5AB396FA48ACA78A1D35F0D94AF305C5D47ABCDE37757A0F0862FFBE9CAAC3EE`.

The current history audit now classifies 33 recurrence classes. Its JSON
SHA-256 is
`6FA1EC4469D636D552051177A675B761D77AA8967188C069095E343FFB7C40D0`.
The fresh checkpoint-promotion contract is
`work/ZR_FS15_CP_20260820.json`, SHA-256
`0863E36D546EC80233EA1903EC6E3FE91C6DB3F62A8E127D11F56DE9DBF78817`;
its `PASS_ARGOS_ZERO_RECURRENCE_PREACTION` result has SHA-256
`3CA7CD7F59CADA896E99630EC0A086D890B85D396A64ACC471AD58DF2A43BD65`.

## Preserved prerequisites and next action

PFC004 remains locked at six of six pose-qualified wafers without retuning.
Slot07 remains a notch-review hold. The completed seven-wafer backside lot,
dashboard, and Insite closure remain unchanged. Historical deterministic
short-name remediation and static cutover regression remain deferred.

Next, create a new review-only native-pose development revision from a
separately declared non-FS15 development partition. It must correct the
channel-independence contract without using the exposed FS15 results to tune
thresholds or morphology, then reserve a genuinely new independent paired
BF/DF validation set. No V1E or 77-peer run is allowed first.

No XML, training, production scoring, production routing, source deletion,
wafer abort, scheduled-task change, or JBOD state change is authorized.
