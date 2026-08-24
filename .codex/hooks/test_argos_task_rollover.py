from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from argparse import Namespace
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("argos_task_rollover.py")
SPEC = importlib.util.spec_from_file_location("argos_task_rollover", MODULE_PATH)
assert SPEC and SPEC.loader
ROLLOVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ROLLOVER)


class ArgosTaskRolloverTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.git("init", "-b", "codex/fiducial-opencv-d-drive")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "Argos Test")
        (self.root / "tracked.py").write_text("first\n", encoding="utf-8")
        self.git("add", "tracked.py")
        self.git("commit", "-m", "baseline")
        self.baseline = self.git("rev-parse", "HEAD").strip()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def git(self, *args: str) -> str:
        return subprocess.run(
            ["git", "-C", str(self.root), *args],
            check=True,
            capture_output=True,
            text=True,
        ).stdout

    def policy(self, rollover_lines: int = 10) -> dict[str, object]:
        return {
            "schema": "argos_codex_task_rollover_v1",
            "projectRoot": self.root.as_posix(),
            "requiredBranch": "codex/fiducial-opencv-d-drive",
            "changeThresholds": {
                "warningChangedLines": max(1, rollover_lines - 2),
                "rolloverChangedLines": rollover_lines,
                "rolloverChangedFiles": 150,
            },
            "sessionThresholds": {
                "checkpointBytes": 128 * 1024 * 1024,
                "firstProbeBytes": 256 * 1024 * 1024,
                "secondProbeAndRolloverBytes": 384 * 1024 * 1024,
                "hardStopBytes": 512 * 1024 * 1024,
                "abnormalStopToStopGrowthBytes": 16 * 1024 * 1024,
            },
        }

    def test_tracked_lines_survive_commits_inside_task(self) -> None:
        (self.root / "tracked.py").write_text(
            "".join(f"line {index}\n" for index in range(12)), encoding="utf-8"
        )
        self.git("add", "tracked.py")
        self.git("commit", "-m", "inside task")
        stats = ROLLOVER.collect_change_stats(self.root, self.baseline, 10)
        self.assertGreaterEqual(stats["changedLines"], 10)
        self.assertEqual(stats["changedFiles"], 1)

    def test_untracked_unknown_binary_counts_as_file_not_lines(self) -> None:
        (self.root / "source.bmp").write_bytes(b"BM\x00\x01\n\n")
        stats = ROLLOVER.collect_change_stats(self.root, self.baseline, 10)
        self.assertEqual(stats["changedFiles"], 1)
        self.assertEqual(stats["untrackedFiles"], 1)
        self.assertEqual(stats["untrackedSourceLines"], 0)

    def test_stop_threshold_requests_continuation(self) -> None:
        continuity = self.root / "work/ARGOS_CONTINUITY_STATE.json"
        continuity.parent.mkdir()
        continuity.write_text(
            json.dumps(
                {
                    "currentPhaseCheckpoint": "work/checkpoint.md",
                    "currentPhaseCheckpointSha256": "ABC",
                    "nextAction": "Continue exact pending observation.",
                }
            ),
            encoding="utf-8",
        )
        measurement = {
            "branch": "codex/fiducial-opencv-d-drive",
            "baselineCommit": self.baseline,
            "changes": {"changedLines": 10, "changedFiles": 1},
            "sessionBytes": 1,
            "warnings": ["CHANGED_LINES_WARNING"],
            "rolloverRequired": True,
            "rolloverReasons": ["CHANGED_LINES_THRESHOLD"],
        }
        output = ROLLOVER.event_output(
            self.root,
            {"hook_event_name": "Stop", "stop_hook_active": False},
            {"handoffCompleted": False, "sessionId": "test-session"},
            measurement,
        )
        self.assertEqual(output["decision"], "block")
        self.assertIn("ARGOS_AUTOMATIC_ROLLOVER_REQUIRED", output["reason"])

    def test_measurement_crosses_configured_line_threshold(self) -> None:
        (self.root / "tracked.py").write_text(
            "".join(f"line {index}\n" for index in range(12)), encoding="utf-8"
        )
        state = {
            "baselineCommit": self.baseline,
            "lastStopSessionBytes": 0,
        }
        measurement = ROLLOVER.measure(
            self.root, self.policy(), state, None, "Stop"
        )
        self.assertTrue(measurement["rolloverRequired"])
        self.assertIn(
            "CHANGED_LINES_THRESHOLD", measurement["rolloverReasons"]
        )

    def test_clean_matching_tip_handoff_is_recorded(self) -> None:
        work = self.root / "work"
        work.mkdir()
        checkpoint = work / "checkpoint.md"
        checkpoint.write_text("safe checkpoint\n", encoding="utf-8")
        checkpoint_hash = ROLLOVER.sha256_file(checkpoint)
        (work / "ARGOS_CODEX_TASK_ROLLOVER.json").write_text(
            json.dumps(self.policy()), encoding="utf-8"
        )
        (work / "ARGOS_CONTINUITY_STATE.json").write_text(
            json.dumps(
                {
                    "currentPhaseCheckpoint": "work/checkpoint.md",
                    "currentPhaseCheckpointSha256": checkpoint_hash,
                }
            ),
            encoding="utf-8",
        )
        self.git("add", "work")
        self.git("commit", "-m", "handoff checkpoint")
        head = self.git("rev-parse", "HEAD").strip()
        with tempfile.TemporaryDirectory() as remote_directory:
            subprocess.run(
                ["git", "init", "--bare", remote_directory], check=True,
                capture_output=True,
            )
            self.git("remote", "add", "origin", remote_directory)
            self.git("push", "-u", "origin", "codex/fiducial-opencv-d-drive")
            ROLLOVER.write_state(
                self.root,
                "handoff-session",
                {
                    "schema": "argos_codex_task_rollover_state_v1",
                    "sessionId": "handoff-session",
                    "baselineCommit": self.baseline,
                    "handoffCompleted": False,
                },
            )
            result = ROLLOVER.complete_handoff(
                Namespace(
                    project_root=str(self.root),
                    session_id="handoff-session",
                    new_thread_id="new-thread",
                    checkpoint_path="work/checkpoint.md",
                    checkpoint_sha256=checkpoint_hash,
                    commit=head,
                )
            )
        self.assertEqual(result["state"], "PASS_HANDOFF_RECORDED")


if __name__ == "__main__":
    unittest.main()
