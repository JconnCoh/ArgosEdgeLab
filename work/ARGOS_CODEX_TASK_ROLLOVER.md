# Argos automatic Codex task rollover

Revision: `ARGOS_CODEX_TASK_ROLLOVER_V1_20260824`

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

## Automatic safe-boundary sequence

When the hook reports `ARGOS_AUTOMATIC_ROLLOVER_REQUIRED`:

1. Finish only the current atomic operation. Do not start a new external
   mutation merely to make the rollover look complete.
2. Record the real state in a current file-backed checkpoint. A pending signed
   request may remain pending and transfer unchanged to the fresh task.
3. Update continuity, active state, project memory, and the revision ledger
   when the completed work constitutes a project milestone.
4. Run project continuity and metadata-only session safety. Run the health
   probe when the session-size contract requires it.
5. Commit and push all authorized task work, fetch `origin`, and require the
   local and remote `codex/fiducial-opencv-d-drive` tips to match with a clean
   worktree.
6. Create one fresh Codex task in this exact Desktop project. Its prompt must
   contain only the checkpoint path and hash, continuity path, exact branch,
   preserved authority/holds, and next action. Never fork or attach the old
   transcript.
7. Record the new task ID with the hook's `--complete-handoff` command. The old
   task may then end.

The project hook is intentionally not a scheduled automation, heartbeat, or
cron job. It checks at task start and before a turn stops, so it adds no delay
to each edit and creates no recurring sidebar tasks. Codex requires one-time
trust review whenever the hook definition changes.

The machine-readable contract is `work/ARGOS_CODEX_TASK_ROLLOVER.json`.
