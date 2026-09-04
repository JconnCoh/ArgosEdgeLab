#!/usr/bin/env python3
"""Local-only process-lifecycle fixture for the O3F15 launch endpoint."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time
from datetime import datetime, timezone


EXPECTED_COUNTS = {
    "holdoutCount": 18,
    "currentRemainderCount": 247,
    "fullRemainderCount": 713,
    "expectedPairCount": 978,
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def emit(value: dict) -> None:
    print(json.dumps(value, sort_keys=True, separators=(",", ":")), flush=True)


def write_json(path: Path, value: dict) -> None:
    temporary = path.with_name(path.name + ".partial")
    if temporary.exists():
        raise RuntimeError(f"fixture partial path already exists: {temporary}")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    os.replace(temporary, path)


def require_fresh(path: Path) -> None:
    if path.exists():
        raise RuntimeError(f"fixture create-new root exists: {path}")


def self_test() -> int:
    emit(
        {
            "schema": "argos_ocv03_o3f15_self_test_v1",
            "state": "PASS_O3F15_FRONT_RECONCILE_SELF_TEST",
            "fixture": True,
            "mutationsPerformed": False,
        }
    )
    return 0


def focused_test() -> int:
    emit(
        {
            "schema": "argos_ocv03_o3f15_front_reconcile_focused_gate_v1",
            "state": "PASS_O3F15_FRONT_RECONCILE_FOCUSED_GATE",
            "fixture": True,
            "mutationsPerformed": False,
        }
    )
    return 0


def preflight() -> int:
    emit(
        {
            "schema": "argos_ocv03_o3f15_preflight_v1",
            "state": "PASS_O3F15_FRONT_RECONCILE_PREFLIGHT",
            "cohortCounts": {
                "HOLDOUT18": 18,
                "CURRENT_TAIL": 247,
                "FULL_TAIL": 713,
                "FULL978": 978,
            },
            "fixture": True,
            "imageBytesRead": False,
            "mutationsPerformed": False,
        }
    )
    return 0


def gate(output_root: Path) -> int:
    require_fresh(output_root)
    output_root.mkdir(parents=False)
    result = {
        "schema": "argos_ocv03_o3f15_gate_result_v1",
        "state": "COMPLETE_O3F15_GATE",
        **EXPECTED_COUNTS,
        "fixture": True,
        "imageBytesRead": False,
        "reviewOnly": True,
    }
    write_json(output_root / "SUMMARY.json", result)
    emit(result)
    return 0


def run(
    output_root: Path,
    mirror_root: Path,
    prerequisite_summary: Path,
    prerequisite_sha256: str,
) -> int:
    mode = os.environ.get("ARGOS_O3F15_LAUNCH_FIXTURE_MODE", "NORMAL")
    if mode not in {"NORMAL", "IMMEDIATE_EXIT"}:
        raise RuntimeError(f"unsupported fixture mode: {mode}")
    if not prerequisite_summary.is_file():
        raise RuntimeError("fixture prerequisite summary is absent")
    if sha256(prerequisite_summary) != prerequisite_sha256.upper():
        raise RuntimeError("fixture prerequisite summary hash changed")
    prerequisite = json.loads(prerequisite_summary.read_text(encoding="utf-8"))
    if prerequisite.get("state") != "COMPLETE_O3F15_GATE":
        raise RuntimeError("fixture prerequisite state changed")
    require_fresh(output_root)
    require_fresh(mirror_root)
    if mode == "IMMEDIATE_EXIT":
        emit(
            {
                "schema": "argos_ocv03_o3f15_front_reconciliation_summary_v1",
                "state": "HOLD_O3F15_FIXTURE_IMMEDIATE_EXIT",
                "fixture": True,
            }
        )
        return 23

    output_root.mkdir(parents=False)
    mirror_root.mkdir(parents=False)
    progress = {
        "schema": "argos_ocv03_o3f15_progress_v1",
        "state": "RUNNING_O3F15_FULL978",
        "updatedUtc": utc_now(),
        "scheduledCount": 978,
        "executedCount": 0,
        "recordedCount": 0,
        "completedCount": 0,
        **EXPECTED_COUNTS,
        "fixture": True,
        "reviewOnly": True,
    }
    write_json(output_root / "PROGRESS.json", progress)
    write_json(mirror_root / "PROGRESS.json", progress)

    # The endpoint probes at three seconds. Staying alive for eight seconds makes
    # the packaged rehearsal exercise an actual background-worker lifecycle.
    time.sleep(8)

    holdout = {"schema": "argos_ocv03_o3f15_fixture_stage_v1", "count": 18}
    current = {"schema": "argos_ocv03_o3f15_fixture_stage_v1", "count": 265}
    results = {
        "schema": "argos_ocv03_o3f15_front_reconciliation_results_v1",
        "processedCount": 978,
        "uniqueDecodeCount": 978,
        "fixture": True,
    }
    summary = {
        "schema": "argos_ocv03_o3f15_front_reconciliation_summary_v1",
        "state": "COMPLETE_O3F15_FULL978",
        "completedUtc": utc_now(),
        "processedCount": 978,
        "uniqueDecodeCount": 978,
        **EXPECTED_COUNTS,
        "fixture": True,
        "reviewOnly": True,
    }
    write_json(output_root / "HOLDOUT18.json", holdout)
    write_json(output_root / "CURRENT265.json", current)
    write_json(output_root / "RESULTS.json", results)
    write_json(mirror_root / "RESULTS.json", results)
    write_json(output_root / "SUMMARY.json", summary)
    write_json(mirror_root / "SUMMARY.json", summary)
    progress.update(
        state="COMPLETE_O3F15_FULL978",
        updatedUtc=utc_now(),
        completedCount=978,
        executedCount=978,
        recordedCount=978,
    )
    write_json(output_root / "PROGRESS.json", progress)
    write_json(mirror_root / "PROGRESS.json", progress)
    emit(summary)
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "mode", choices=("FOCUSED_TEST", "SELF_TEST", "PREFLIGHT", "GATE", "RUN")
    )
    parser.add_argument("--output-root")
    parser.add_argument("--mirror-root")
    parser.add_argument("--prerequisite-summary")
    parser.add_argument("--prerequisite-sha256")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.mode == "FOCUSED_TEST":
        return focused_test()
    if args.mode == "SELF_TEST":
        return self_test()
    if args.mode == "PREFLIGHT":
        return preflight()
    if args.mode == "GATE":
        if not args.output_root:
            raise RuntimeError("GATE requires --output-root")
        return gate(Path(args.output_root))
    required = {
        "--output-root": args.output_root,
        "--mirror-root": args.mirror_root,
        "--prerequisite-summary": args.prerequisite_summary,
        "--prerequisite-sha256": args.prerequisite_sha256,
    }
    missing = [name for name, value in required.items() if not value]
    if missing:
        raise RuntimeError("RUN missing arguments: " + ", ".join(missing))
    return run(
        Path(args.output_root),
        Path(args.mirror_root),
        Path(args.prerequisite_summary),
        args.prerequisite_sha256,
    )


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # deterministic compact fixture failure
        emit(
            {
                "schema": "argos_ocv03_o3f15_launch_fixture_failure_v1",
                "state": "HOLD_O3F15_FIXTURE_FAILURE",
                "error": str(exc),
            }
        )
        sys.exit(2)
