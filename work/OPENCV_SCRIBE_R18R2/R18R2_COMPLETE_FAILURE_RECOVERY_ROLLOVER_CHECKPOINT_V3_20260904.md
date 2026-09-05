# R18R2 complete failure/recovery rollover checkpoint V3 — 2026-09-04

## Disposition

`PASS_COMPLETE_R18R2_FAILURE_RECOVERY_CONTEXT_V3_FROZEN`

This checkpoint is the complete human-readable authority for resuming only the isolated OpenCV scribe-deciphering lane. Its machine companion is:

- `work/OPENCV_SCRIBE_R18R2/R18R2_COMPLETE_RECOVERY_ROLLOVER_MANIFEST_V3.json`
- SHA-256 `B4A783C97192D1B73F7ED5C869730C7412AAD303EE0A060C58D9BD6ED474E7FF`
- 29,718 bytes

Neither this checkpoint nor the companion grants publication authority. The successor must read both, plus the exact required-read list in the companion, and must not reconstruct state from task history.

## Supersession of the rejected precommit handoff

An independent read-only precommit audit rejected the first handoff set before commit or task creation. Its bytes are preserved unchanged as withdrawn evidence:

- prior checkpoint `work/OPENCV_SCRIBE_R18R2/R18R2_COMPLETE_FAILURE_RECOVERY_ROLLOVER_CHECKPOINT_20260904.md` — 17,436 bytes — `03BEFE22AD1CC55319B6497DBABDD42D0CDCB387E25FE92CAE24B0FB49CA4B2B`
- prior manifest `work/OPENCV_SCRIBE_R18R2/R18R2_COMPLETE_RECOVERY_ROLLOVER_MANIFEST.json` — 22,891 bytes — `CE8ACE68A42AA2EC0445187B4DB6187D039EE4D0E8A11BBB109D66C0F3D0B022`
- prior gate `work/OPENCV_SCRIBE_R18R2/R18R2_COMPLETE_FAILURE_RECOVERY_ROLLOVER_GATE.json` — 6,452 bytes — `A8A30F81528AA31961BC3CF1B51EF230C430281F53D1547CBCD85709D7DB2A9D`

That V1 set is `WITHDRAWN_PRECOMMIT_INDEPENDENT_AUDIT_BLOCKERS` and is not authority. It ambiguously pinned legacy canonical-root/branch policy fields and omitted exact paths for two frozen scientific gates and the base-reference bundle.

The corrected V2 content passed an independent read-only audit, but its first staged-byte gate found one new blank line at EOF in the frozen V2 checkpoint. V2 is therefore `WITHDRAWN_PRECOMMIT_STAGED_DIFF_WHITESPACE_GATE`; its bytes are preserved and were not edited:

- V2 checkpoint `work/OPENCV_SCRIBE_R18R2/R18R2_COMPLETE_FAILURE_RECOVERY_ROLLOVER_CHECKPOINT_V2_20260904.md` — 20,028 bytes — `94AF9F992093A05DE2E581CD3B1DE93DD095F0A203F71E37CE51DFDFBF86C20A`
- V2 manifest `work/OPENCV_SCRIBE_R18R2/R18R2_COMPLETE_RECOVERY_ROLLOVER_MANIFEST_V2.json` — 28,593 bytes — `AD2E09B20E5041E622930BF215EA72F607A2144EBAED89AE65B8B0DBCA9EDBFA`
- V2 gate `work/OPENCV_SCRIBE_R18R2/R18R2_COMPLETE_FAILURE_RECOVERY_ROLLOVER_GATE_V2.json` — 8,683 bytes — `5D7805A803F176226121B9FB1358C239A807A889E1B38291DFA99B8615140974`

This V3 set carries the same audited content with an exact single-newline EOF and supersedes both rejected sets.

## Exact workspace and Git boundary

- The only authorized worktree is `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab-scribe-opencv`.
- The only authorized branch is `codex/opencv-scribe-deciphering`.
- The source task started at commit `8368e138e8654098c3aeb39fe33af8ec14876b3d`.
- The clean local/origin tip immediately before this rollover operation was `0b3d5c58a1b6890ff39b890605c4b586d65c5dc8`.
- The exact handoff commit is the later commit containing this checkpoint, its companion manifest, the PASS gate, and the rollover-governance correction. The successor prompt must state that commit, and local `HEAD` and `origin/codex/opencv-scribe-deciphering` must both equal it before the successor reads project files.
- The task's saved CWD `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab` is forbidden and is not authority.
- The canonical Desktop checkout and the c290 and ea39 worktrees must not be accessed or modified.
- Do not merge, rebase, reset, check out, or switch branches.

The branch's global continuity pointer names an unrelated targeted-backside phase. It is global governance only. Do not follow or modify its backside `activePhase`, `currentPhaseCheckpoint`, or `nextAction`. This checkpoint and its machine companion govern the isolated scribe lane.

## Why rollover is mandatory and how it is accepted

At rollover detection, the source task had 18,540 cumulative changed lines and 152 changed files relative to its task-start commit. Both automatic rollover thresholds were exceeded. No R18T implementation or new live action may begin in this task.

The operator requires a checkpoint-first, verified rollover. That rule is now binding in:

- `AGENTS.md` — SHA-256 `9B8F686F00A0E0EC83034C3A61313FFC909EAD4168168C6637DAA64E8F22738A`
- `work/ARGOS_CODEX_TASK_ROLLOVER.md` — SHA-256 `B9F288027C05A501213D34077AC26830CBFF5D20ED2936F8C1D5060B6AF2DCAC`
- `work/ARGOS_CODEX_TASK_ROLLOVER.json` — SHA-256 `792524340D30A91BD582D1DD668A622CE2580B7C1BCE75A292D13F84416F7BDB`

The machine policy's top-level `projectRoot` and `requiredBranch` are explicitly legacy compatibility inputs for the current historical single-phase hook. They are not isolated-lane authority. That hook does not guard a saved-CWD task using this separate dedicated scribe worktree. The exact V3 checkpoint/manifest/gate and the predecessor's manual two-phase audit control this rollover.

The current single-phase rollover hook does not mechanically prove successor acceptance. Until a separately qualified two-phase hook exists, the predecessor must enforce the following manually:

1. Freeze and validate a complete checkpoint, machine companion, and PASS gate.
2. Commit and push them, then require a clean worktree and identical local/origin tips.
3. Create one fresh task from only the frozen handoff artifacts and exact commit, with no transcript reconstruction.
4. Require its first turn to be audit-only: zero filesystem or Git writes, zero external contacts or mutations, and zero queue/task/process/image access.
5. Inspect the actual successor response and recheck the shared worktree and local/origin tips.
6. Accept and resume only if the successor preserved every decision, hold, hash, location, authority limit, and next action without mutation or regression.

Any mismatch pauses the successor. The predecessor must supersede a deficient frozen handoff rather than ending the old task.

## R18R2 terminal failure — what happened and what did not

R18R2 / `REQ_R18R2` was published exactly once. The signed portal response proved only that the exact frozen worker was launched on `A1025645101` as PID 37456. It was not a terminal execution success.

Direct post-launch observation established:

- planned output root: `D:\A2\o\ocv\R18R2`
- terminal observed state: `LAUNCH_ONLY`
- PID 37456 no longer present
- no `INVENTORY.json`, `RUNNING.json`, `COMPLETE.json`, case directories, results, or worker failure record
- configured cases: 21
- exact live nested BF/DF pairs present: 20
- sole missing identity: `62629-401_20260902002921_Slot24`
- duplicate configured source pairs: 0
- both frozen reference manifests present

The failure occurred before inventory and before any OCR result. It therefore says nothing about R18R's OCR correctness. The root cause was execution-envelope contamination: the local-only Slot24 fixture was added to the JBOD cohort without reconciling the cohort against live paths and bytes before output/process creation. Anonymous, undrained worker stdout/stderr pipes plus the lack of a worker-owned top-level atomic failure record then hid the exception.

R18R2 is `WITHDRAWN_WORKER_EXITED_PRE_INVENTORY`, is no-retry, and cannot be a successor parent.

Pinned terminal evidence:

- terminal checkpoint SHA-256 `C5FD8423B3DD276D26643E6A2212FAB1D249F57B1FEBA960AE53895285DF0471`
- failed review gate SHA-256 `FF09E5D455752299E8EA47E7D9BDD47E11A47F2C4F6C6B2D94073C4A6FA4AADE`
- worker-exit observation SHA-256 `4BA3157A138B7C6418D47E27B6856B9926D5DFA4071E99861DB11A070CCD2345`
- launch-response gate SHA-256 `ECD1E67112AA9ED5FCDEE97895088A3A46D25EA3E820C275527679F4887824EE`
- request ZIP SHA-256 `E541EB7FCCD19A04BFE401D6FCFB70B7976C0F47E9F4F1AD8E1FCC1626EEF300`
- signed launch-response ZIP SHA-256 `D310854F22538041C1E8D1318A70F2EA7B54D02C912000124A15C4FD83B4B6A5`

## Frozen science and reference bytes

R18T may change only the execution envelope. These scientific bytes remain immutable:

- reader `work/OPENCV_SCRIBE_R18H/ArgosOpenCvScribeV1R18H.py` — `3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD`
- crop sweep `work/OPENCV_SCRIBE_R18J/ArgosOpenCvScribeCropSweepR18J.py` — `EF4C58589CA8885B5CBDE0A989D3F94EE8C447925818DC0FA4E50B26B87A8B9F`
- reference-isolated envelope `work/OPENCV_SCRIBE_R18P/Run-R18PReferenceIsolatedCorpus.py` — `5B6AA224E844FCEA22DEC6A9D10C863437F039CA73EC258C263DF539905791D0`
- scientific wrapper `work/OPENCV_SCRIBE_R18R/Run-R18RReferenceIsolatedCorpus.py` — `B826767EA21BB148DD30A719595B23DD818FD9CFC08B347FEAFD9FD4959F4E3C`
- R18R provider `work/OPENCV_SCRIBE_R18R/ArgosOpenCvScribeV1R18R.py` — `51C95B3279D253EF717F663F3860CC6B4CA38517706E08E9FE2302BE02CD2BB5`
- R18Q generic-structure provider `work/OPENCV_SCRIBE_R18Q/ArgosOpenCvScribeV1R18Q.py` — `AB20CFB25D223D40D31237118436446018AE213F800ECF1652213EB942C40DC1`
- local base-reference ZIP `work/OPENCV_SCRIBE_O2D5/final/extract/O2D5_REFS.zip`; installed pin `D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip`; 14,855,150 bytes — `56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6`
- embedded base-reference manifest member `refs/PORTABLE_GLYPH_REFERENCE_MANIFEST.json`; 207,802 bytes — `AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229`
- supplemental reference manifest `work/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json` — `FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114`

The supplemental reference bank still lacks body labels `I`, `O`, `V`, and `Y`. That limitation is unchanged and is not authority to synthesize or auto-admit references.

## Crop/OCR invariants that must not regress

- Use existing processor paired scribe crops first.
- Displaced `POST2_S17_MISPLACED` remains image-first `6KB71041XDE5` with state `HOLD_R13B_REVIEW_ONLY_GRID_SELECTED`.
- All five blank controls, across all 40 evaluated views, remain `HOLD_SCRIBE_NOT_LOCALIZED` and emit no string.
- Local Slot24 remains image-first `143B0083SUE6`, checksum valid, and a package-excluded local real-image regression. It must not be copied to JBOD.
- Synthetic dots are forbidden.
- Notch dependence, a fixed notch grid, and solid-line dependence are forbidden.
- Checksum is `VERIFY_IMAGE_FIRST_ONLY`. It may not select, invent, or rewrite a glyph, and it may not be disabled for a test or package.
- Identity acceptance remains false.
- R18T whole-wafer fallback remains false.

Pinned R18R proof:

- local gate `work/OPENCV_SCRIBE_R18R/R18R_LOCAL_GATE.json` — SHA-256 `566EB33649697713F5E0EFD3E0F04F9861333103BBBC1C1BACFEDE3CD184C82A`
- reference-isolation gate `work/OPENCV_SCRIBE_R18R2/R18R_REFERENCE_ISOLATION_LOCAL_GATE.json` — SHA-256 `9E645CCEE7BB4C62610AD1D93418985F2F3FB3A3DCD68007A3ECA56D30784471`
- canonical checksum gate `work/OPENCV_SCRIBE_R18R2/R18R_CANONICAL_CHECKSUM_GATE.json` — SHA-256 `BB0F36B38A7CB697087B324CDE2037E8F2B8ED184BCE8DB71EA1BCB3DB787407`
- Slot22 image-first exact result `13DCK060SUF5`
- Slot24 image-first exact result `143B0083SUE6`
- frozen reference lineage correct: 389; previously correct harmed: 0
- visible exact: 21; blank-view holds: 40; hard-coded executable literals: 0

## Cohort boundary

The exact R18P live cohort is:

- `work/OPENCV_SCRIBE_R18P/R18P_REVIEW_COHORT.json`
- SHA-256 `62A5E864C174A6E2C7F368E784E8DD0F86A11828036401351B2FCBB6336A2661`
- 20 ordered cases

The failed R18R2 cohort is:

- `work/OPENCV_SCRIBE_R18R2/R18R_REVIEW_COHORT.json`
- SHA-256 `7393A6CB84F3CF246DCA3751DFCCB76422198C25270CA2759FBF260D2DE8AF56`
- 21 ordered cases

The required mechanical relation is exact: R18R2 equals the ordered 20-row R18P cohort plus only the package-excluded local Slot24 fixture. R18T must use an exact ordered clone of the frozen R18P cohort. It must not assume that any configured row exists live merely because it exists locally. It must hash and reconcile the exact live crop files twice before any output write or process start.

## Prior attempts and retained evidence

- R18N1: published once, operator stopped after bad whole-wafer crops; no retry; not a parent. Request ZIP `198F365EF1B21739A9D6D7E67628F45751641ECE17112C01CE9A3F586431BEE4`.
- R18O2: published once, operator stopped during partial existing-crop diagnostic; completion is not claimed; no retry; not a parent. Request ZIP `0DC7D8D3FE59AD2296A036DCE04AA425CA20C859EAB2B7B0F1EEC9A8A9A09B36`.
- R18P1: completed all 20 exact reference-isolated live cases: 18 image-first passes, two intended ambiguity holds, zero execution errors. Slot22 exposed the general K-to-R defect. Request ZIP `0975925ED1079D042701882BE9D61A24CA0BD1977C6078B18E9633E26ECAEEFD`; signed response ZIP `961ED9E6461E7A6C96C942F27D532B6DBD5D04A376B9BC1336DA3CE1552E0F02`; complete evidence `89E8749AC7278EF07BC0562D4F2995124EE593C2DF4446F7CEC61ED9E36B8417`.
- R18Q: generic, label-agnostic run-structure correction passed local gates without hard-coded K/R behavior.
- R18R: fixed the general K/R defect and Slot24 reciprocal ambiguity from image evidence only while preserving all frozen invariants.
- R18R1: signed locally but withdrawn unpublished after its packaged entrypoint revealed a stale internal manifest pin. No retry and not a parent.
- R18R2: published once and withdrawn after the pre-inventory execution-envelope failure described above. No retry and no OCR conclusion.

## Exact R18T successor

The next namespace is:

- work directory: `work/OPENCV_SCRIBE_R18T`
- revision: `R18T_LIVE_ONLY_EXECUTION_ENVELOPE_CORRECTION_REVIEW_ONLY_20260904A`
- request ID: `REQ_R18T1`
- JBOD work root: `D:\A2\w\ocv\R18T1`
- JBOD output root: `D:\A2\o\ocv\R18T1`
- planned installed launcher: `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R18T1.ps1`
- planned final ZIP: `work/OPENCV_SCRIBE_R18T/final/REQ_R18T1.ready.zip`

R18T is a bounded execution-envelope correction, not new OCR science. It must:

1. Clone the exact ordered 20-row R18P cohort and prove that R18R2 differs solely by local Slot24.
2. Perform generic safe-identity, unique casefold-identity, unique BF/DF-pair, exact nested-leaf, and exact live-byte-hash reconciliation before any `New-Item`, work/output creation, or process start.
3. Repeat that reconciliation immediately before launch and require both bindings to be identical.
4. Derive all cardinalities from actual collections. Executable files must not encode expected 20, 21, or any other corpus count.
5. Use a thin envelope worker that delegates unchanged to the frozen R18R scientific wrapper, writes create-new durable `WORKER.stdout.log` and `WORKER.stderr.log`, and atomically commits a bounded `FAILURE.json` for any top-level exception or nonzero return.
6. Rehearse both a dynamically omitted configured case and an injected pre-inventory worker failure from the exact staged bytes. Missing input must reject before writes/process; injected failure must leave durable evidence and no false `COMPLETE`.
7. Scan all executable and extracted-package bytes for concrete lot, slot, product, identity, truth, fixture, fixed-count, test-hook, checksum-override, threshold-override, whole-wafer-fallback, notch-dependence, and synthetic-dot contamination.
8. Rerun the canonical checksum, reference-isolation, Slot24, displaced-S17, visible, blank, T/7, and K/R gates without changing frozen runtime or reference bytes.
9. Pass recovery-intent, zero-recurrence, clone-remediation, Windows PowerShell 5.1 parser/harness/wrapper, path, exact-membership, signature, extraction, and contamination gates.
10. Stop at signed-unpublished.

The installed live source root remains `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals`, with required nested leaves `scribe\BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png` and `scribe\DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png`. The local Slot24 fixture remains under `C:\R18J_CORPUS_FIXTURE\proposals`, derived from `C:\R18IR8\BF_BRIGHT_BEST_SOURCE_WINDOW.png`, with BF SHA-256 `F67972F31B30C9BE42615DF7FBDC0E64D642F89860A38F4D8172365C7C261201` and DF SHA-256 `2D4B7AC5861BE87B2876842C3010B15E268DC7150FFAF84B290EF01E9BFC1386`. These locations are pinned context, not permission to access them in the successor audit turn.

## Recovery classification

- incident: `R18R2_LIVE_SET_AND_TERMINAL_EVIDENCE_20260904`
- next mode: `MUTATE`
- supported remedy: `B` — correct invalid package-input and terminal-evidence preconditions while preserving frozen OCR science
- signed terminal failed-response count: 0
- mutation stop-loss: not active
- fresh namespace: required

The signed R18R2 portal response was a launch PASS, not a terminal FAILED response. The direct post-launch worker observation must be pinned as a machine-readable supporting observation; it must not be falsely counted as a signed terminal failure.

## Authority and holds

Explicit unresolved records:

- R18R2 is withdrawn pre-inventory, no-retry, and has no OCR conclusion.
- R18T publication is pending a fresh literal `PUBLISH` for `REQ_R18T1`.
- R18S full existing-crop work remains blocked and neither build nor publication is authorized.
- Slot24 is package-excluded local real-image evidence and must not be copied to JBOD.
- Supplemental body labels `I`, `O`, `V`, and `Y` remain absent; no automatic admission is authorized.
- The two-phase rollover-hook implementation is deferred and unqualified; manual predecessor acceptance remains mandatory.

Authorized now:

- review-only state
- local R18T correction and package preparation after the successor audit is accepted

Not authorized:

- R18T publication; a fresh literal `PUBLISH` for `REQ_R18T1` is required
- any R18T retry; after fresh publication authority, the maximum is one publication
- R18S build or publication
- identity acceptance or automatic reference admission
- automatic hold clearance, activation, training, XML, or production
- source mutation or deletion
- unrelated portal, JBOD, queue, task, process, or image actions

R18S, the full existing-crop corpus, remains blocked. Only a clean R18T live completion plus the unchanged package-excluded Slot24 regression gate may unblock its build. R18S is never automatically published.

## Procedural disclosure

During the source task's read-only recovery-governance delegation, a subagent mistakenly ran `git fetch origin --quiet`. This was a repository-origin read/local remote-tracking refresh only. It did not write origin, did not change worktree content, and observed the same origin tip `0b3d5c58a1b6890ff39b890605c4b586d65c5dc8`. It did not access JBOD, portal, queues, processes, or images. This was outside that subagent's assigned no-external-read boundary, is disclosed here, and must not be repeated.

## Successor required-read and first-turn contract

After it verifies the exact handoff commit, branch, origin tip, and clean dedicated worktree, the successor must read the exact `requiredReadOrderAfterWorkspaceVerification` array from the machine companion and verify every listed SHA-256 before proceeding. The array includes the binding rollover rules, R18R2 terminal evidence, R18P/R18Q/R18R scientific evidence, both cohorts, Windows failure memory, recovery/stop-loss policy, zero-recurrence policy, and OpenCV migration policy.

The successor's first turn is audit-only and must also acknowledge both V1/V2 withdrawals, the V3 supersession, legacy hook-scope limitation, and six explicit unresolved records. It must report:

1. exact worktree, branch, `HEAD`, origin tip, and clean state;
2. exact hashes for this checkpoint, the companion manifest, and the PASS gate;
3. frozen implementation and reference hashes;
4. all crop/OCR invariants, including displaced S17, blank controls, package-excluded Slot24, no synthetic dots, no notch dependence, and checksum verify-only;
5. R18R2's pre-inventory failure and exact live-set evidence;
6. the R18T/R18S decision, authority, blockers, and exact next action; and
7. an explicit statement that it made zero writes, external contacts, mutations, or queue/task/process/image accesses.

The successor must then wait. The predecessor will inspect that actual response and recheck the shared worktree before sending acceptance. Only after that acceptance may the successor create the direct-observation record, create and gate the R18T recovery intent, and begin the bounded local R18T implementation.

## Exact next action

Finish and validate the companion PASS gate, commit and push this frozen handoff, create one fresh audit-only successor task, inspect its actual response, and reverify the clean matching local/origin worktree. If and only if that audit has no mutation or regression, accept the rollover and direct the successor to begin R18T recovery-governance records and local implementation. It must stop at signed-unpublished and await a fresh literal `PUBLISH` for `REQ_R18T1`.
