# Argos automatic task rollover V1 / O2D4 pending checkpoint — 2026-08-24

## State

Automatic safe Codex task rollover is installed in the authoritative Desktop
repository on branch `codex/fiducial-opencv-d-drive`. The operator-observed
current-task badge had reached 185 files and 12,401 additions / 18 deletions,
so this checkpoint is also the handoff boundary for a fresh task.

The active Argos phase remains
`OCV02_SCRIBE_SLOT16_O2D4_RESPONSE_PENDING`. This automation work did not poll,
retry, replace, or otherwise change `REQ_O2D4`. The gateway-consumed request
still requires its one matching signed terminal response. A pending request is
a valid safe rollover boundary and transfers unchanged to the fresh task.

## Frozen rollover implementation

The approved contract is `work/ARGOS_CODEX_TASK_ROLLOVER.json`, SHA-256
`7E97A0987B092476DC4F4ECB89E47C015B8338652FD112814BF17D2347F10D37`.
The human-readable policy is `work/ARGOS_CODEX_TASK_ROLLOVER.md`, SHA-256
`F80ACD51E6100962D80ABD7594B825C7F4CADF76465CCDAC06F9B9E1F7E2285C`.

The trusted-project hook definition is `.codex/hooks.json`, SHA-256
`EC67B9FEF7D8A5CF3B3D1F7A11DB0F3A72443005780C940913A5E7C22F47E504`.
It runs only at `SessionStart` and `Stop`; it is not a scheduled automation,
cron task, heartbeat, or per-edit hook. The implementation is
`.codex/hooks/argos_task_rollover.py`, SHA-256
`517922B30A0995FD90597BC31030253F3EE4900A45D2FFA9BA6F64D33896C42D`.
Its state is confined to `.git/codex/argos-task-rollover` and is not committed.

The guard warns at 8,000 cumulative changed lines and requires rollover at
10,000 cumulative changed lines or 150 changed files. It measures against the
task-start commit, so commits inside one task do not reset the count. It also
preserves the existing 128/256/384/512 MiB session gates and the 16 MiB
abnormal-growth stop. It reads transcript metadata only and does not read
session contents, unknown binary files, or image bytes.

Local validation passed five tests: cumulative lines survive task-local
commits; unknown untracked binary files count without content reads; the line
threshold triggers; Stop creates a continuation; and clean matching local and
origin tips permit handoff recording. Gate SHA-256 is
`BF3405593C38D91A4C20655A43DD9111AB4C05115B259DADC3B27946986F70B2`.
The updated `argos-opencv-migration` skill also passed its validator using an
isolated temporary PyYAML dependency; PyYAML is not an Argos runtime
dependency.

Codex requires one-time review/trust of the exact new hook hash when the fresh
task starts. Until that product trust step is accepted, the repository
`AGENTS.md` rule remains the durable rollover instruction.

## Preserved authority and exact continuation

No JBOD endpoint was contacted. No processor, task, process, provider config,
source image, wafer, queue, ledger, XML state, training state, production
routing state, or existing hold changed. The healthy processor, disabled live
provider, `SCRIBE_REFERENCE_COVERAGE_HOLD`, unseen Slots22-25, and every prior
global hold remain fixed.

In the fresh task, read this checkpoint and
`work/ARGOS_CONTINUITY_STATE.json`, fetch `origin`, and require matching local
and remote branch tips. Then collect and verify only the matching signed
terminal response for `REQ_O2D4`. On exact pass, freeze Slot16 and continue to
frozen development Slot17. On failure or continued absence, publish no
successor and follow the direct-observation and stop-loss policy.
