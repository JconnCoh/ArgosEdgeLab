# Argos Codex session-safety contract

Date: 2026-08-19

State: `APPROVED_BASELINE_V2`

## Purpose

Argos work is image-heavy, but Codex task history must remain text-light. Two
tasks became unusable after binary image data was serialized into JSONL:

- task `019f95b4-36be-72c0-b0bc-34ae4c3dbf97` reached approximately
  20.6 GiB;
- task `019fcd2e-cf41-7f11-93de-592c43d4131b` reached exactly
  18,490,749,343 bytes and contained 306 oversized binary/image records.

Both tasks are quarantined. Their contents must never be opened, read,
restored, forked, summarized, or passed to another task. Recovery may use only
saved filesystem checkpoints and bounded text-only recovery artifacts.

## Hard content wall

- Never place image, video, or audio bytes, Base64, `data:` URLs, blob bodies,
  or binary-returning tool results in an Argos task.
- Do not use screenshot or image-returning tools in Argos tasks. Create the
  artifact as a normal local file and give the operator its path.
- Browser inspection must use bounded DOM text and exact element state only.
  Do not request screenshots and do not return attributes containing embedded
  binary payloads.
- Query only required fields from JSON, CSV, manifests, logs, and timelines.
  Never print a large file merely to inspect one value.
- Tool output should normally remain below 8,000 tokens. Save larger evidence
  to a file and summarize it by path, size, hash, and selected fields.

## Metadata-only size gate

Run `utilities/Confirm-ArgosCodexSessionSafety.ps1`:

1. after resuming any Argos task;
2. before and after any potentially image-heavy review step;
3. at every major filesystem checkpoint;
4. before presenting a reviewer or starting a long-running inspection.

The checker reads only file names, sizes, and timestamps. It never reads JSONL
content and explicitly refuses either quarantined task ID.

The two quarantined failures above were caused by serialized binary/image
payloads measured in tens of GiB. They do not establish that an otherwise
text-only task becomes unreliable at 128 MiB. Normal task growth and abnormal
payload growth are therefore gated separately.

Staged thresholds:

- below 128 MiB: continue;
- 128 MiB or above: write or confirm a current text-only filesystem checkpoint,
  then continue in the same task;
- 256 MiB or above: run the deterministic session-health probe and record the
  result. Continue only when continuity, authority, and interaction-health
  checks pass;
- 384 MiB or above: run the second health probe and make a soft recommendation
  to rotate. Continuing is allowed when the probe passes and the current work
  is safer to finish in place;
- 512 MiB or above: hard stop and resume from the filesystem checkpoint in a
  fresh task until accumulated evidence supports a different ceiling.

Run `utilities/Confirm-ArgosCodexSessionHealth.ps1` for the 256 MiB and
384 MiB probes. The automated portion verifies session metadata, continuity
hashes, the current checkpoint, and review-only authority without reading task
contents. The checkpoint must also record the observed interaction result:
unexpected latency or retries, repeated work, loss of continuity, incorrect
authority, and any operator-reported degradation. A probe does not pass if any
of those observations is unresolved.

An unexpected increase of 16 MiB or more between two adjacent measurements is
a provisional abnormal-growth alarm regardless of total size. Supply the prior
measurement to the guard so it can fail closed. Investigate metadata and the
tool/action that preceded the increase; never inspect the JSONL contents.

## Rotation handoff

A fresh task receives only:

- the current checkpoint path and hash;
- the continuity-state path;
- the exact next action and authority state;
- small selected text fields needed to resume.

It must never receive session JSONL, screenshots, embedded media, large tool
transcripts, or a fork of a quarantined/image-heavy task. The filesystem is the
continuation authority.

## Automation behavior

Do not schedule the session-size guard as either a standalone cron automation
or a heartbeat. A standalone Codex cron run creates a new visible task on every
interval; a heartbeat grows the active task it is supposed to protect. Run the
metadata-only checker directly at the mandatory checkpoints above instead.
A PASS stays a bounded text result. A checkpoint-only state is non-blocking.
Any health-probe, soft-rotation, abnormal-growth, or hard-stop state is reported
to the operator and requires the corresponding action above.

Confirmed failure signature on 2026-08-17: automation
`argos-codex-session-size-guard` was configured as `kind = "cron"` with a
15-minute interval and created at least 256 visible tasks titled
`Argos Codex session size guard`. Recovery is to pause the automation before
cleanup, archive only tasks whose exact title and automation ID match, preserve
the active pinned Argos task, and verify that no matching unarchived task
remains in the visible list. Never replace this cron with a heartbeat.
