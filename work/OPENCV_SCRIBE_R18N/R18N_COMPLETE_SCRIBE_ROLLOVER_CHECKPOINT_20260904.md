# Complete isolated OpenCV scribe rollover checkpoint — R18N signed and unpublished

Classification: `PENDING_GATE`

This is the authoritative continuation checkpoint for the isolated OpenCV
scribe-deciphering lane. It supersedes the narrower
`R18N_SIGNED_UNPUBLISHED_READY_CHECKPOINT_20260904.md` as the rollover source.
The predecessor remains accurate R18N evidence, but it is not sufficient by
itself to continue the complete scribe work safely.

Machine-readable companion:
`work/OPENCV_SCRIBE_R18N/R18N_COMPLETE_SCRIBE_ROLLOVER_MANIFEST.json`,
SHA-256
`1AF8D4150B26DB7666900C5B0508C8A3723B635CB6C1D6DC02CA53469CA6D3C2`.

## Hard workspace isolation and rollover hazard

Use only:

`C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab-scribe-opencv`

Branch: `codex/opencv-scribe-deciphering`.

The successor task ID is
`01a06c5f-6e03-7e01-b6f0-e4486a98eebc`. Its saved Codex project directory is
the canonical Desktop checkout, which is not authority for this lane. Before
any read, Git command, edit, or action, the successor must explicitly enter
the dedicated worktree above and verify:

1. the exact branch;
2. a clean worktree;
3. local `HEAD` equals the handoff commit named in the delegation; and
4. `origin/codex/opencv-scribe-deciphering` equals that same commit.

The successor must not read from or modify any of these roots:

- `C:\Users\joshua.conn\.codex\worktrees\c290\ArgosEdgeLab`;
- `C:\Users\joshua.conn\.codex\worktrees\ea39\ArgosEdgeLab`; or
- `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab`.

Do not merge, rebase, reset, checkout, or switch branches. The c290 task and
all targeted-backside work, detector files, RustDesk state, unrelated portal
queues, tasks, processes, and JBOD work remain out of scope.

The dedicated branch's copy of `work/ARGOS_CONTINUITY_STATE.json` still points
at the separate targeted-backside phase. Read it only for global governance and
preserved authority. Its backside `activePhase`, `currentPhaseCheckpoint`, and
`nextAction` are not the continuation pointer for this isolated branch and
must not be followed or modified. This checkpoint and its machine companion
are the scribe continuation authority.

## Actual state at rollover

- Pre-handoff commit: `1de1e880d620d6f326bf914a76d0365e86fb1d89`.
- R18N is signed locally and has not been published.
- R18N has not contacted JBOD, created its work/output roots, started a worker,
  or read any source image.
- The reader, crop sweep, corpus worker, and reference library are frozen and
  unchanged.
- No identity was accepted. No reference was automatically admitted. No hold
  was cleared. Nothing was activated, trained, routed to XML, or enabled for
  production.
- This rollover does not grant publication authority. A new operator message
  containing the literal word `PUBLISH` is required for R18N.
- Maximum R18N publication count after that authority is one. Retry is false.

## Why rollover is mandatory and how this handoff prevents recurrence

The metadata-only session/health measurement recorded source task
`01a05f15-7a31-7f12-b420-f19745a811e6` at `597938927` bytes
(`570.239 MiB`) and in the `HARD_STOP_512_MIB` band. The session guard returned
`HARD_STOP_START_FRESH_TASK`; the health probe returned
`FAIL_ARGOS_CODEX_SESSION_HEALTH` from the explicitly recorded continuity
degradation. Neither check read session content.

The operator reported real continuity degradation: the first rollover prompt
named only the narrow R18N checkpoint and did not convey the complete scribe
reader history, crop rules, regressions, failure-analysis plan, or saved-CWD
hazard. The successor was paused before it changed any file or external state.

Mitigation is mandatory: resume that successor only with this comprehensive
checkpoint, require it to restate the exact worktree, frozen components,
authority, and next action before acting, then inspect its first work. Any
divergence is stopped and corrected before independent continuation.

## Frozen implementation and reference bank

- Reader:
  `work/OPENCV_SCRIBE_R18H/ArgosOpenCvScribeV1R18H.py`, SHA-256
  `3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD`.
- Crop sweep:
  `work/OPENCV_SCRIBE_R18J/ArgosOpenCvScribeCropSweepR18J.py`, SHA-256
  `EF4C58589CA8885B5CBDE0A989D3F94EE8C447925818DC0FA4E50B26B87A8B9F`.
- Full-corpus worker:
  `work/OPENCV_SCRIBE_R18J/Run-R18JScribeCorpus.py`, SHA-256
  `E8C193024317C683EA0E8DC999F3D632BF113B65C1E6F528949AE5B33F83A069`.
- Base reference-manifest SHA-256:
  `AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229`.
- Supplemental manifest:
  `work/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json`,
  SHA-256
  `FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114`.
  It contains J=2, K=2, Q=2, W=1, X=1, Z=1. Missing body-label coverage
  remains `I/O/V/Y`; never force these to the nearest known glyph.
- Payload manifest:
  `work/OPENCV_SCRIBE_R18J/R18J_PAYLOAD_MANIFEST.json`, SHA-256
  `BF2D0E809915ADEB503E2B7ADEFB3DCAC30903025D851B26067C9FB5B90DC57D`.

These bytes must not be edited, rebuilt, or silently substituted during R18N
publication or execution.

## Reader behavior that must be preserved

1. Use the processor's existing paired BF/DF oriented scribe crops first.
2. A missing, blank, structurally unusable, boundary-incomplete, or below-floor
   existing crop may enter only the bounded whole-wafer fallback.
3. A blank or wrong-location crop must emit no string and an explicit hold.
   Never select a least-bad OCR string from texture or empty pixels.
4. Whole-wafer fallback uses large `2000x800` source-pixel candidate crops and
   may evaluate BF and DF, DARK and BRIGHT polarity, and bounded direction
   hypotheses. Darkfield is not always best and must never be privileged.
5. Do not rely on notch alignment, fixed notch-relative placement, wafer/die
   grid, repeating grid, or a solid line below the scribe. Notch support may be
   unavailable for a substantial period and the scribe can move relative to it.
6. Structure may establish that a crop contains a coherent scribe band, but it
   cannot choose OCR channel, polarity, direction, glyph, or identity.
7. Synthetic dot reconstruction is prohibited. Never convert threshold
   components, connected-component centroids, or imagined blobs into OCR,
   reference, ranking, validation, or review evidence.
8. SEMI M12 checksum is `VERIFY_IMAGE_FIRST_ONLY`. It may verify or produce a
   disagreement hold. It cannot rewrite a character, select a hypothesis,
   rescue weak localization, or turn metadata into image evidence.
9. Lot/MES information may locate likely reference examples and verify an
   independently image-first read; it may never choose the glyph or string.
10. All results remain review-only proposals/holds with
    `identityAccepted=false`.

R18H fixed the exposed T/7 error at its root: best-single-exemplar dominance in
sparse, similar classes. For any body label, and only when the two appearance
leaders are within `0.02`, the generic ordered run-structure consensus may
choose between those same two leaders with a structural margin of at least
`0.20`. The chosen label retains its lower appearance score, so the rule cannot
raise blank texture past the presence floor. This is not a T/7 special case.

R18H's local gate at
`work/OPENCV_SCRIBE_R18H/R18H_FAST_GATE.json`, SHA-256
`33719DE1119BC87906B6BD0501B8F2A1A4462F1F111915C4E245B7BF789E4508`,
passes nine established visible strings, three R18G development strings, and
465 leave-one-physical-identity-out references with zero changed or harmed
previously correct cases.

## Frozen visible and hold evidence

The nine R18H visible regression strings are:

- `1878P076FEE6`, `L0751043FEC4`, `8365N004FEC6`;
- `1484P068SUD6`, `147JQ121SUE7`, `1484P102SUC0`;
- `9508R043FED4`, `1478T158SUC5`, `146J7043SUE2`.

The R18F blind visual pass adds four exact strings:

- `148AW101SUC4`, `2969P018FEE3`;
- `1478T009SUA0`, `147JQ120SUA5`.

The three exact R18G visible development strings are:

- `L0751037FEA2`, `1478T161SUG7`, `146XF113SUA5`.

Additional frozen development evidence includes:

- `148AW102SUG6`, `13DCK060SUF5`, `1480J017SUH0`;
- W/Z integration strings `148AW103SUD5` and `147Z6157SUA5`.

The operator explicitly confirmed position 2=`3` and position 5=`K` in
`13DCK060SUF5`, and confirmed the displayed W and Z glyphs. Those glyphs are
diagnostic references; they do not accept the wafer identities. Exact evidence
is in the R18D and R18F checkpoints/gates named by the machine companion.

The difficult displaced-scribe regression remains exact:
`POST2_S17_MISPLACED = 6KB71041XDE5`. Its gate is
`work/OPENCV_SCRIBE_R13B/R13B_LOCAL_REAL_IMAGE_GATE.json`, SHA-256
`CA0B6227641D5D21E569020A1408B778A95C92533041A30CAC32C98A6C225E83`.
Do not break this while improving ordinary-location behavior.

Five established blank/wrong-location controls must remain empty holds:

- `Lot-62546-481-POST2_20260713155808_Slot18`;
- `dev-01-post-8-19_20260819164148_Slot01`;
- `Lot-62546-481-POST2_20260713155808_Slot23`;
- `62627-182_20260810050905_Slot23`; and
- `62613-842A-test_20260730053955_Slot25`.

## Slot24 cropping acceptance case and resist-lot partition

For `62629-401_20260902002921_Slot24`, the operator-confirmed truth is
`143B0083SUE6`. The unchanged R18H reader returns that exact image-first string
from a BF DARK `2000x800` source-pixel crop without notch/grid/solid-line
alignment or synthetic dots. Gate:
`work/OPENCV_SCRIBE_R18I/R18I_SLOT24_CROP_DEMONSTRATION_GATE.json`, SHA-256
`CB13E9BD9F4C8854BD07D02866D3702366BFFA85ADB2B108981D56BE7B2690AC`.

The full-corpus wrapper's existing-crop path also selects `143B0083SUE6` and
retains close alternative `103B0083SUE6` as
`HOLD_SCRIBE_MULTIPLE_CLOSE_IMAGE_FIRST_STRINGS`. Gate:
`work/OPENCV_SCRIBE_R18J/R18J_CORPUS_LOCAL_GATE.json`, SHA-256
`2803AEE7EF2C1C8993BF279F4F3C1F305B375E4018E1DFC344A8A678A76EA03E`.
The exact top string is correct, but the close alternative means the identity
is still held and unaccepted.

The operator-supplied suspected-resist folder was inventoried read-only as
lot/acquisition `62629-401_20260902002921`. Slot24 is development; Slot25 was
frozen as independent validation before image reads. The actual BF/DF source
paths and hashes are in:

- `work/OPENCV_SCRIBE_R18I/R18I_62629_401_METADATA_AND_SPLIT.json`, SHA-256
  `8B006A9802266FA8533DA227CFFFF63708B47809734FF5A2F4E324FE299AD9E1`;
- `work/OPENCV_SCRIBE_R18I/R18I_62629_401_SOURCE_HASH_GATE.json`, SHA-256
  `B125865BC44DEEA34AF8A82C31079D6169DCDF226A9671EAD309204C98178617`.

Do not assume the appearance is resist until evidence proves it, and do not
tune on Slot25 before treating it as the independent partition.

## Terminal request history and why no prior package may be retried

- R18J2 `REQ_20260904T014700000Z_R18J2`: signed terminal failure before worker,
  image read, or root creation because
  `D:\AFCV1\review\identity\proposals` did not exist. No retry. Signed STATUS
  observation proved the installed root is
  `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals`.
- R18K: signed locally, never published, withdrawn because a deep packaged leaf
  had effective length `206`. It is non-reusable.
- R18L `REQ_R18L_20260904A`: signed terminal failure before worker/images/roots.
  The portal did not translate the manifest's proposal-root field into an
  entrypoint argument, so the old default was used. No retry.
- R18M `REQ_R18M_20260904A`: signed terminal failure before worker/images/roots.
  Its hand-maintained route gate omitted the actual 173-character supplemental
  manifest leaf; with reserve its effective length was `205`. No retry.

Exact failure and observation paths/hashes are frozen in the machine companion.
The three signed failures activated stop-loss; fresh R18N was permitted only by
`work/OPENCV_SCRIBE_R18N/R18N_WORKFLOW_REVIEW_CLEARANCE.json`, SHA-256
`E82EECA3204683FF99FCA23DE58F5A05D0DDA8B2F2E45F5447B5D4C8C3496F5D`.

## R18N exact signed package

- Request ID: `REQ_R18N1`.
- Ready ZIP:
  `work/OPENCV_SCRIBE_R18N/final/REQ_R18N1.ready.zip`.
- Bytes: `150135`.
- ZIP SHA-256:
  `198F365EF1B21739A9D6D7E67628F45751641ECE17112C01CE9A3F586431BEE4`.
- Request-manifest SHA-256:
  `2031B32D26DF561F3A8ADD35C3D60EF853CB9A630B1993F899A71ECF993B8A0E`.
- Signature SHA-256:
  `DE65F4464919E1B2730CEA81DAFE87EEF2378E01E5F8229F30A21D0C5DBD9632`.
- Entrypoint:
  `work/OPENCV_SCRIBE_R18N/Invoke-R18NCorpusLaunch.ps1`, SHA-256
  `0B75F178A4D73668DBD76E0F07A820E16897DA40D0466A6FBA84806A8AFCD746`.
- JBOD source root: `D:\KLARFExport`.
- Installed proposal root:
  `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals`.
- Fresh work root: `D:\A2\w\ocv\R18N1`.
- Fresh output root: `D:\A2\o\ocv\R18N1`.

The exact final ZIP has 27 members. The exact member-set SHA-256 is
`02D888A6921BF16695C262B821FF894DE5BCF3AF42F5E192B544491C233003B8`.
The path proof evaluates 127 expanded candidates and all 26 round-trip
candidates. Maximum effective length with the required 32-character reserve is
`196`; unsafe count is zero. The prior omitted supplemental-manifest leaf is
explicitly included and is the measured longest endpoint leaf.

Required R18N gates:

- final package:
  `work/OPENCV_SCRIBE_R18N/R18N_FINAL_PACKAGE_GATE.json`, SHA-256
  `865B96A8775F30A7D4DC7B81A65C428B4CB2B816EF3B5D5160F4CE221BD41A73`;
- full round-trip path:
  `work/OPENCV_SCRIBE_R18N/R18N_FULL_ROUND_TRIP_PATH_GATE.json`, SHA-256
  `D7230106F89C80062E2C64D018441554A0ED64D5FD25959792930F3DA71C7967`;
- independent exact-package path:
  `work/OPENCV_SCRIBE_R18N/R18N_EXACT_PACKAGE_PATH_GATE.json`, SHA-256
  `7265749BAF77759B973CB58BDCAA33094B4A7A353AE165E8B1E3AC095891AF74`;
- zero-recurrence preaction SHA-256
  `AAF77F58FCF74002EDA06012207182D0A80459153D43A962684FE4A2D94E1460`;
- recovery-intent SHA-256
  `A8B192B886A00FDE58D235F720845C58456B06346AFDD7947A75693DF28904C2`.

The signed request itself records
`publication.explicitOperatorAuthorityPresent=false`. Do not reinterpret any
earlier `Publish`, `Proceed`, `Continue`, or rollover instruction as the new
literal R18N publication authority.

## Exact next action

Until the operator says literal `PUBLISH` for R18N: wait. Do not create a
publication-authority file or publisher; do not access the portal share, JBOD,
source images, queues, tasks, or processes.

After literal `PUBLISH` only:

1. Re-hash the frozen R18N ZIP and gates; do not rebuild or resign them.
2. Create and pin only a fresh narrow R18N publication-authority record and
   exact R18N publisher.
3. Apply the current failure memory, recovery/stop-loss clearance,
   zero-recurrence, wrapper/harness, clone-remediation, full route/path,
   signature, clean-branch, and exact queue-state gates.
4. Require zero pending requests and absence of `REQ_R18N1` at upload, ready,
   and processed paths.
5. Publish the exact ZIP once with create-new semantics.
6. Collect only its matching signed terminal response and verify source role
   `JBOD`, signer thumbprint
   `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`, and exact request ID.
7. A signed failure is terminal: preserve it and stop with no retry.
8. A signed launch pass is not corpus completion. First verify `LAUNCH.json`
   names exact output root `D:\A2\o\ocv\R18N1` and the owned worker.

## Correct post-launch continuation

Monitor only through separately authorized bounded read-only/status actions.
Do not touch unrelated processes, tasks, queues, roots, or JBOD state. Expected
fresh output under `D:\A2\o\ocv\R18N1` is:

- `INVENTORY.json`;
- `RUNNING.json`;
- per-case `c/<safe-id>/RESULT.json`; and
- terminal `COMPLETE.json`.

Do not report completion until exact `COMPLETE.json` is collected and verified.
Check every result for `identityAccepted=false`, review-only authority, explicit
state/hold, and no source mutation.

Build the failure-first analysis queue mechanically, grouped by:

- source inventory or BF/DF pairing;
- existing-crop localization;
- whole-wafer localization/displaced scribe;
- appearance regime, channel, polarity, or direction;
- segmentation/grid-boundary failure;
- missing `I/O/V/Y` reference coverage;
- close-character/run-structure arbitration;
- checksum disagreement; and
- confidence or explicit hold reason.

Do not change the reader or admit references from full-corpus output. A future
correction requires a fresh namespace, frozen development/independent split,
smallest relevant regression against every established visible/blank/blind
control, and separate explicit authority. Difficult-to-find or ambiguous
scribes remain holds until confirmed; obvious readable scribes must not be
turned into false holds because of crop error.

## Required successor read order

After the exact worktree/branch/commit/clean check, read:

1. `AGENTS.md`;
2. this checkpoint;
3. `R18N_COMPLETE_SCRIBE_ROLLOVER_MANIFEST.json` and verify its hash above;
4. the narrower R18N signed-unpublished checkpoint;
5. the R18H root-fix checkpoint and pre-full-KLARF plan;
6. the R18I Slot24 crop gate;
7. the R18J local corpus gate; and
8. the R18N workflow-clearance, full-round-trip, and final-package gates.

Do not rediscover any pinned route, root, hash, runtime, topology, or source
fact. Do not reconstruct the lane from chat. If any exact byte, branch, root,
or authority premise differs, stop and report that single mismatch from the
dedicated scribe worktree only.
