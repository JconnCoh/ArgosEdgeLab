#!/usr/bin/env python3
"""Metadata-only Argos Codex task rollover hook."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


POLICY_RELATIVE_PATH = Path("work/ARGOS_CODEX_TASK_ROLLOVER.json")
CONTINUITY_RELATIVE_PATH = Path("work/ARGOS_CONTINUITY_STATE.json")
STATE_RELATIVE_ROOT = Path(".git/codex/argos-task-rollover")
QUARANTINED_SESSION_IDS = {
    "019f95b4-36be-72c0-b0bc-34ae4c3dbf97",
    "019fcd2e-cf41-7f11-93de-592c43d4131b",
}
UNTRACKED_SOURCE_EXTENSIONS = {
    ".bat",
    ".c",
    ".cc",
    ".cmd",
    ".cpp",
    ".cs",
    ".css",
    ".go",
    ".h",
    ".hpp",
    ".html",
    ".java",
    ".js",
    ".jsx",
    ".md",
    ".ps1",
    ".psd1",
    ".psm1",
    ".py",
    ".rs",
    ".sh",
    ".sql",
    ".toml",
    ".ts",
    ".tsx",
    ".xml",
    ".yaml",
    ".yml",
}


class GuardError(RuntimeError):
    """A fail-closed rollover guard error."""


def run_git(root: Path, *args: str, allow_difference: bool = False) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    allowed = {0, 1} if allow_difference else {0}
    if completed.returncode not in allowed:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise GuardError(f"git {' '.join(args)} failed: {detail[:500]}")
    return completed.stdout


def resolve_project_root(cwd: str | None) -> Path:
    candidate = Path(cwd or os.getcwd()).resolve()
    output = run_git(candidate, "rev-parse", "--show-toplevel").strip()
    if not output:
        raise GuardError("Cannot resolve the Git project root.")
    return Path(output).resolve()


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise GuardError(f"Cannot read valid JSON from {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise GuardError(f"Expected a JSON object at {path}.")
    return value


def load_policy(root: Path) -> dict[str, Any]:
    policy = load_json(root / POLICY_RELATIVE_PATH)
    if policy.get("schema") != "argos_codex_task_rollover_v1":
        raise GuardError("Unexpected Argos rollover policy schema.")
    expected_root = Path(str(policy["projectRoot"])).resolve()
    if os.path.normcase(str(expected_root)) != os.path.normcase(str(root)):
        raise GuardError(f"Rollover policy root mismatch: {root}")
    return policy


def normalized_session_id(raw: Any) -> str:
    session_id = str(raw or "").strip()
    if not session_id or len(session_id) > 128:
        raise GuardError("Missing or invalid Codex session ID.")
    if not re.fullmatch(r"[A-Za-z0-9._-]+", session_id):
        raise GuardError("Codex session ID contains unsafe characters.")
    if session_id.lower() in QUARANTINED_SESSION_IDS:
        raise GuardError(f"Refusing quarantined Codex session {session_id}.")
    return session_id


def state_path(root: Path, session_id: str) -> Path:
    return root / STATE_RELATIVE_ROOT / f"{session_id}.json"


def read_state(root: Path, session_id: str) -> dict[str, Any] | None:
    path = state_path(root, session_id)
    return load_json(path) if path.is_file() else None


def write_state(root: Path, session_id: str, state: dict[str, Any]) -> None:
    path = state_path(root, session_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(state, indent=2, sort_keys=True) + "\n"
    temporary_name = ""
    try:
        with tempfile.NamedTemporaryFile(
            mode="x",
            encoding="utf-8",
            newline="\n",
            prefix=f"{session_id}.",
            suffix=".partial",
            dir=path.parent,
            delete=False,
        ) as stream:
            temporary_name = stream.name
            stream.write(payload)
        os.replace(temporary_name, path)
    finally:
        if temporary_name and os.path.exists(temporary_name):
            os.unlink(temporary_name)


def session_bytes(transcript_path: Any) -> int:
    if not transcript_path:
        return 0
    path = Path(str(transcript_path))
    lowered = path.name.lower()
    if any(session_id in lowered for session_id in QUARANTINED_SESSION_IDS):
        raise GuardError("Refusing metadata access for a quarantined session.")
    try:
        return path.stat().st_size
    except OSError:
        return 0


def count_bounded_source_lines(path: Path, cap: int) -> int:
    if path.suffix.lower() not in UNTRACKED_SOURCE_EXTENSIONS:
        return 0
    count = 0
    try:
        with path.open("rb") as stream:
            first = stream.read(8192)
            if b"\x00" in first:
                return 0
            count += first.count(b"\n")
            while count <= cap:
                block = stream.read(65536)
                if not block:
                    break
                count += block.count(b"\n")
    except OSError:
        return 0
    return min(count, cap + 1)


def collect_change_stats(
    root: Path, baseline_commit: str, rollover_line_cap: int
) -> dict[str, Any]:
    run_git(root, "cat-file", "-e", f"{baseline_commit}^{{commit}}")
    ancestor = subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", baseline_commit, "HEAD"],
        check=False,
        capture_output=True,
    ).returncode == 0
    if not ancestor:
        raise GuardError("Task-start commit is no longer an ancestor of HEAD.")

    tracked_output = run_git(root, "diff", "--numstat", baseline_commit, "--")
    changed_paths: set[str] = set()
    additions = 0
    deletions = 0
    binary_files = 0
    for row in tracked_output.splitlines():
        fields = row.split("\t", 2)
        if len(fields) != 3:
            continue
        added, deleted, relative = fields
        changed_paths.add(relative)
        if added.isdigit() and deleted.isdigit():
            additions += int(added)
            deletions += int(deleted)
        else:
            binary_files += 1

    untracked_raw = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--others", "--exclude-standard", "-z"],
        check=True,
        capture_output=True,
    ).stdout
    untracked_paths = [
        item.decode("utf-8", errors="surrogateescape")
        for item in untracked_raw.split(b"\x00")
        if item
    ]
    untracked_source_lines = 0
    remaining_cap = max(0, rollover_line_cap - additions - deletions)
    for relative in untracked_paths:
        changed_paths.add(relative)
        if untracked_source_lines <= remaining_cap:
            untracked_source_lines += count_bounded_source_lines(
                root / relative, remaining_cap - untracked_source_lines
            )

    return {
        "additions": additions,
        "deletions": deletions,
        "untrackedSourceLines": untracked_source_lines,
        "changedLines": additions + deletions + untracked_source_lines,
        "changedFiles": len(changed_paths),
        "untrackedFiles": len(untracked_paths),
        "binaryTrackedFiles": binary_files,
    }


def initial_state(
    root: Path, session_id: str, transcript_path: Any
) -> dict[str, Any]:
    return {
        "schema": "argos_codex_task_rollover_state_v1",
        "sessionId": session_id,
        "projectRoot": str(root),
        "baselineCommit": run_git(root, "rev-parse", "HEAD").strip(),
        "baselineSessionBytes": session_bytes(transcript_path),
        "lastStopSessionBytes": session_bytes(transcript_path),
        "handoffCompleted": False,
        "handoff": None,
        "lastMeasurement": None,
    }


def measure(
    root: Path,
    policy: dict[str, Any],
    state: dict[str, Any],
    transcript_path: Any,
    event_name: str,
) -> dict[str, Any]:
    branch = run_git(root, "branch", "--show-current").strip()
    required_branch = str(policy["requiredBranch"])
    if branch != required_branch:
        raise GuardError(f"Required branch {required_branch}; found {branch}.")
    changes = collect_change_stats(
        root,
        str(state["baselineCommit"]),
        int(policy["changeThresholds"]["rolloverChangedLines"]),
    )
    current_session_bytes = session_bytes(transcript_path)
    previous_stop_bytes = int(state.get("lastStopSessionBytes") or 0)
    stop_growth = (
        current_session_bytes - previous_stop_bytes
        if event_name == "Stop" and previous_stop_bytes > 0
        else 0
    )
    change_policy = policy["changeThresholds"]
    size_policy = policy["sessionThresholds"]
    reasons: list[str] = []
    if changes["changedLines"] >= int(change_policy["rolloverChangedLines"]):
        reasons.append("CHANGED_LINES_THRESHOLD")
    if changes["changedFiles"] >= int(change_policy["rolloverChangedFiles"]):
        reasons.append("CHANGED_FILES_THRESHOLD")
    if current_session_bytes >= int(size_policy["secondProbeAndRolloverBytes"]):
        reasons.append("SESSION_SECOND_PROBE_ROLLOVER_THRESHOLD")
    if current_session_bytes >= int(size_policy["hardStopBytes"]):
        reasons.append("SESSION_HARD_STOP_THRESHOLD")
    if stop_growth >= int(size_policy["abnormalStopToStopGrowthBytes"]):
        reasons.append("ABNORMAL_STOP_TO_STOP_SESSION_GROWTH")

    warnings: list[str] = []
    if changes["changedLines"] >= int(change_policy["warningChangedLines"]):
        warnings.append("CHANGED_LINES_WARNING")
    if current_session_bytes >= int(size_policy["checkpointBytes"]):
        warnings.append("SESSION_CHECKPOINT_THRESHOLD")
    if current_session_bytes >= int(size_policy["firstProbeBytes"]):
        warnings.append("SESSION_HEALTH_PROBE_THRESHOLD")

    return {
        "branch": branch,
        "baselineCommit": state["baselineCommit"],
        "changes": changes,
        "sessionBytes": current_session_bytes,
        "stopToStopSessionGrowthBytes": stop_growth,
        "warnings": warnings,
        "rolloverRequired": bool(reasons),
        "rolloverReasons": reasons,
    }


def continuation_context(
    root: Path, state: dict[str, Any], measurement: dict[str, Any]
) -> str:
    continuity = load_json(root / CONTINUITY_RELATIVE_PATH)
    changes = measurement["changes"]
    reasons = ",".join(measurement["rolloverReasons"])
    return (
        "ARGOS_AUTOMATIC_ROLLOVER_REQUIRED. Standing operator authority is recorded in "
        "work/ARGOS_CODEX_TASK_ROLLOVER.md. "
        f"Reasons={reasons}; changedLines={changes['changedLines']}; "
        f"changedFiles={changes['changedFiles']}; sessionBytes={measurement['sessionBytes']}; "
        f"sessionId={state['sessionId']}. "
        "Finish only the current atomic operation; do not start a new external mutation. "
        "Write or confirm the exact file-backed checkpoint, update continuity records when "
        "needed, run continuity/session gates, commit and push, fetch origin, require clean "
        "matching branch tips, then create one fresh Codex task in this Desktop project. "
        "Use no fork and no transcript. The new prompt must name only: "
        f"checkpoint={continuity.get('currentPhaseCheckpoint')}; "
        f"checkpointSha256={continuity.get('currentPhaseCheckpointSha256')}; "
        "continuity=work/ARGOS_CONTINUITY_STATE.json; "
        f"branch={measurement['branch']}; authority=reviewOnly:{continuity.get('reviewOnly')},"
        f"trainingEligible:{continuity.get('trainingEligible')},"
        f"xmlEligible:{continuity.get('xmlEligible')},"
        f"productionEligible:{continuity.get('productionEligible')}; "
        f"nextAction={continuity.get('nextAction')}; preserve all existing holds. "
        "After create_thread succeeds, run this hook with --complete-handoff, the new task ID, "
        "checkpoint path/hash, and HEAD commit so this old task can end."
    )


def event_output(
    root: Path,
    event: dict[str, Any],
    state: dict[str, Any],
    measurement: dict[str, Any],
) -> dict[str, Any]:
    event_name = str(event.get("hook_event_name") or event.get("hookEventName") or "")
    changes = measurement["changes"]
    if state.get("handoffCompleted"):
        return {"continue": True}

    if measurement["rolloverRequired"]:
        context = continuation_context(root, state, measurement)
        if event_name == "Stop":
            if bool(event.get("stop_hook_active")):
                return {
                    "continue": False,
                    "stopReason": "Argos automatic rollover is still incomplete; see the prior continuation.",
                    "systemMessage": context,
                }
            return {"decision": "block", "reason": context}
        return {
            "systemMessage": "Argos automatic rollover threshold reached.",
            "hookSpecificOutput": {
                "hookEventName": event_name,
                "additionalContext": context,
            },
        }

    warnings = measurement["warnings"]
    if warnings:
        context = (
            "Argos rollover guard warning: "
            f"{','.join(warnings)}; changedLines={changes['changedLines']}; "
            f"changedFiles={changes['changedFiles']}; sessionBytes={measurement['sessionBytes']}. "
            "Prepare the next safe file-backed checkpoint without interrupting atomic work."
        )
        if event_name in {"SessionStart", "PostToolUse"}:
            return {
                "systemMessage": "Argos task rollover warning threshold reached.",
                "hookSpecificOutput": {
                    "hookEventName": event_name,
                    "additionalContext": context,
                },
            }
        return {"continue": True, "systemMessage": context}

    if event_name == "SessionStart":
        return {
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": (
                    "Argos automatic rollover guard is active. "
                    f"Task baseline commit: {measurement['baselineCommit']}."
                ),
            }
        }
    return {"continue": True}


def handle_hook(event: dict[str, Any]) -> dict[str, Any]:
    root = resolve_project_root(event.get("cwd"))
    policy = load_policy(root)
    session_id = normalized_session_id(event.get("session_id"))
    state = read_state(root, session_id)
    if state is None:
        state = initial_state(root, session_id, event.get("transcript_path"))
    event_name = str(event.get("hook_event_name") or event.get("hookEventName") or "")
    measurement = measure(
        root, policy, state, event.get("transcript_path"), event_name
    )
    state["lastMeasurement"] = measurement
    if event_name == "Stop":
        state["lastStopSessionBytes"] = measurement["sessionBytes"]
    write_state(root, session_id, state)
    return event_output(root, event, state, measurement)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def complete_handoff(args: argparse.Namespace) -> dict[str, Any]:
    root = resolve_project_root(args.project_root)
    policy = load_policy(root)
    session_id = normalized_session_id(args.session_id)
    state = read_state(root, session_id)
    if state is None:
        raise GuardError(f"No rollover state exists for session {session_id}.")
    branch = run_git(root, "branch", "--show-current").strip()
    if branch != str(policy["requiredBranch"]):
        raise GuardError(f"Cannot hand off from unexpected branch {branch}.")
    head = run_git(root, "rev-parse", "HEAD").strip()
    remote = run_git(root, "rev-parse", f"refs/remotes/origin/{branch}").strip()
    if head != args.commit or head != remote:
        raise GuardError("Local HEAD, supplied commit, and origin branch tip must match.")
    if run_git(root, "status", "--porcelain").strip():
        raise GuardError("Working tree must be clean before completing handoff.")

    checkpoint = (root / args.checkpoint_path).resolve()
    try:
        checkpoint.relative_to(root)
    except ValueError as exc:
        raise GuardError("Checkpoint must remain inside the project root.") from exc
    actual_hash = sha256_file(checkpoint)
    if actual_hash != args.checkpoint_sha256.upper():
        raise GuardError("Supplied checkpoint hash does not match the file.")
    continuity = load_json(root / CONTINUITY_RELATIVE_PATH)
    if continuity.get("currentPhaseCheckpoint") != args.checkpoint_path.replace("\\", "/"):
        raise GuardError("Handoff checkpoint is not the current continuity checkpoint.")
    if str(continuity.get("currentPhaseCheckpointSha256", "")).upper() != actual_hash:
        raise GuardError("Continuity checkpoint hash does not match the handoff checkpoint.")
    if not args.new_thread_id.strip():
        raise GuardError("A created fresh-task ID is required.")

    state["handoffCompleted"] = True
    state["handoff"] = {
        "newThreadId": args.new_thread_id.strip(),
        "checkpointPath": args.checkpoint_path.replace("\\", "/"),
        "checkpointSha256": actual_hash,
        "commit": head,
        "remoteTip": remote,
    }
    write_state(root, session_id, state)
    return {
        "schema": "argos_codex_task_rollover_handoff_v1",
        "state": "PASS_HANDOFF_RECORDED",
        "sessionId": session_id,
        **state["handoff"],
    }


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser()
    result.add_argument("--complete-handoff", action="store_true")
    result.add_argument("--project-root")
    result.add_argument("--session-id")
    result.add_argument("--new-thread-id")
    result.add_argument("--checkpoint-path")
    result.add_argument("--checkpoint-sha256")
    result.add_argument("--commit")
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        if args.complete_handoff:
            required = (
                args.project_root,
                args.session_id,
                args.new_thread_id,
                args.checkpoint_path,
                args.checkpoint_sha256,
                args.commit,
            )
            if any(value is None for value in required):
                raise GuardError("All handoff arguments are required.")
            output = complete_handoff(args)
        else:
            event = json.load(sys.stdin)
            if not isinstance(event, dict):
                raise GuardError("Hook input must be a JSON object.")
            output = handle_hook(event)
        print(json.dumps(output, separators=(",", ":")))
        return 0
    except Exception as exc:  # fail closed with valid hook JSON
        event_name = ""
        if "event" in locals() and isinstance(event, dict):
            event_name = str(
                event.get("hook_event_name") or event.get("hookEventName") or ""
            )
        reason = f"ARGOS_AUTOMATIC_ROLLOVER_GUARD_ERROR: {exc}"
        if event_name == "Stop":
            print(json.dumps({"decision": "block", "reason": reason}))
            return 0
        print(json.dumps({"systemMessage": reason}))
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
