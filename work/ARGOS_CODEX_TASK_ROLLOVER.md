# Argos automatic Codex task rollover

Revision: `ARGOS_CODEX_TASK_ROLLOVER_V2_20260904`

Disposition: `APPROVED_BASELINE`

The operator grants standing authority to checkpoint an Argos task and create
one fresh Codex task when this guard reaches a rollover threshold. This does
not authorize any additional JBOD, processor, image, wafer, XML, training,
production, deletion, queue, ledger, or hold mutation.

## Thresholds

- Warn at 8,000 changed lines.
- Roll over at 10,000 changed lines or 150 changed files.
- Preserve the existing session-size gates: checkpoint at 128 MiB, health
  probe at 256 MiB, safe rollover at 384 MiB, and hard stop at 512 MiB.
- Treat 16 MiB or more growth between adjacent Stop measurements as an
  abnormal-growth stop.

Changed lines are additions plus deletions relative to the task-start Git
commit. That baseline survives commits made inside the task. All untracked
paths count as changed files. Only known source-text extensions are opened to
count untracked lines; unknown and binary files are never opened by the guard.

## Checkpoint-before-rollover contract

Task creation is prohibited until a complete immutable checkpoint, machine
companion, and PASS gate are written, hashed, committed, pushed, and verified
on a clean matching local/origin branch tip. The handoff set must carry every
decision and exact data location needed to continue without chat reconstruction,
including frozen artifact hashes, authority, holds, unresolved gates, signed
request/response and external state, withdrawals/no-retry rules, next action,
prohibitions, and a hashed required-read order. The checkpoint must name the
actual active worktree and branch; a hard-coded historical branch or unrelated
global continuity checkpoint is not authority for an isolated lane.

## Automatic safe-boundary sequence

When the hook reports `ARGOS_AUTOMATIC_ROLLOVER_REQUIRED`:

1. Finish only the current atomic operation. Do not start a new external
   mutation merely to make the rollover look complete.
2. Record the real state in the complete checkpoint/companion/gate set above.
   A pending signed request may remain pending and transfer unchanged.
3. Update continuity, active state, project memory, and the revision ledger
   when the completed work constitutes a project milestone.
4. Run project continuity and metadata-only session safety. Run the health
   probe when the session-size contract requires it.
5. Commit and push all authorized task work, fetch `origin`, and require the
   checkpoint's exact local and origin branch tips to match with a clean
   worktree.
6. Create one fresh Codex task from the exact checkpoint, companion, and gate
   paths/hashes. Never fork or attach the old transcript.
7. Keep the predecessor active. Require the successor's first turn to be a
   zero-mutation audit that independently verifies every handoff hash and the
   exact worktree/branch/HEAD/origin/clean state, then restates the decisions,
   locations, authority, holds, prohibitions, and next action.
8. Inspect the actual successor response and recheck the shared worktree. If it
   diverged, mutated, omitted context, or followed an unrelated continuity
   pointer, pause it and supersede the deficient handoff; do not end the
   predecessor.
9. Only after exact no-regression acceptance may the predecessor record the new
   task ID with `--complete-handoff` and end.

The currently qualified hook is only a threshold and predecessor-stop guard;
its task-ID record does not itself prove successor acceptance. Until a tested
two-phase hook is separately qualified, the predecessor must enforce steps
7-9 directly and must not call `--complete-handoff` early.

The machine policy's legacy `projectRoot` and `requiredBranch` fields serve
only the present single-phase hook. They are not isolated-lane handoff
authority, and the hook does not guard a saved-CWD task that operates in a
separate dedicated worktree; the frozen checkpoint controls that boundary.

The project hook is intentionally not a scheduled automation, heartbeat, or
cron job. It checks at task start and before a turn stops, so it adds no delay
to each edit and creates no recurring sidebar tasks. Codex requires one-time
trust review whenever the hook definition changes.

The machine-readable contract is `work/ARGOS_CODEX_TASK_ROLLOVER.json`.
