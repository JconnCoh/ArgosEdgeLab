#!/usr/bin/env python3
"""Construction test for the file-backed R34 composite gate."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


PASSES = [
    "PASS_R28_PACKAGED_SYNTHETIC_33_OF_33",
    "PASS_R29_PACKAGED_SYNTHETIC_13_OF_13",
    "PASS_R30_PACKAGED_SYNTHETIC_13_OF_13",
    "PASS_R31_PACKAGED_SYNTHETIC_21_OF_21",
    "PASS_R32_PACKAGED_SYNTHETIC_15_OF_15",
    "PASS_R33_PACKAGED_SYNTHETIC_13_OF_13",
    "PASS_R34_PACKAGED_SYNTHETIC_33_OF_33",
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def file_record(path: Path) -> dict:
    return {"path": str(path), "sha256": sha(path)}


def mock_runner(path: Path, summary: dict) -> None:
    path.write_text(
        "import argparse,json,pathlib\n"
        "p=argparse.ArgumentParser();p.add_argument('--output',required=True);a,u=p.parse_known_args()\n"
        "o=pathlib.Path(a.output);o.mkdir(parents=True)\n"
        f"s={summary!r}\n"
        "(o/'SUMMARY.json').write_text(json.dumps(s),encoding='utf-8')\n",
        encoding="utf-8",
    )


def main() -> int:
    composite = Path(__file__).with_name("Run-R34CompositeGate.py")
    with tempfile.TemporaryDirectory(prefix="r34_composite_test_") as raw:
        root = Path(raw)
        runtime = root / "runtime"
        runtime.mkdir()
        data = root / "data"
        data.mkdir()
        jobs = data / "jobs"
        jobs.mkdir()
        for ordinal in range(301):
            write_json(jobs / f"J{ordinal:03d}.json", {})

        detector = runtime / "Detect-BacksideNotchOpenCvR34.py"
        detector.write_text("# frozen detector fixture\n", encoding="utf-8")
        config = runtime / "BACKSIDE_NOTCH_CONFIG_R13.json"
        cases = data / "FROZEN_CASES.json"
        base = data / "BASE_CASES.json"
        extras = runtime / "EXTRA_CASES.json"
        rotation_cases = runtime / "R28ROT1_CASES.json"
        for path, value in (
            (config, {"config": True}), (cases, list(range(301))),
            (base, list(range(298))), (extras, list(range(3))),
            (rotation_cases, {"cases": [1, 2]}),
        ):
            write_json(path, value)

        targeted_runner = runtime / "Run-R34TargetedGate.py"
        union_runner = runtime / "Run-R34Union.py"
        rotation_runner = runtime / "Diagnose-R34RotationHolderAblation.py"
        mock_runner(targeted_runner, {
            "state": "PASS_R34_TARGETED_GATE_9_OF_9", "caseCount": 9,
            "outcomeMismatchCount": 0, "sourceHashesUnchanged": True,
            "sourceMutationPerformed": False,
        })
        mock_runner(union_runner, {
            "state": "PASS_R34_UNION_301_OF_301", "caseCount": 301,
            "outcomeMismatchCount": 0, "invariantMismatchCount": 0,
            "scoreDominantResolutionCount": 4, "scoreDominanceHoldCount": 1,
            "sourceMutationPerformed": False,
        })
        mock_runner(rotation_runner, {
            "state": "PASS_R34ROT1_8_OF_8", "executionCount": 8,
            "violations": [], "sourceHashesUnchanged": True,
            "detectorHashUnchanged": True, "sourceMutationPerformed": False,
        })

        test_records = []
        for revision, expected in zip(range(28, 35), PASSES):
            path = runtime / f"Test-BacksideNotchOpenCvR{revision}.py"
            path.write_text(f"print({expected!r})\n", encoding="utf-8")
            test_records.append({**file_record(path), "expectedStdout": expected})

        output = root / "output"
        plan = {
            "schema": "argos_r34_composite_plan_v1",
            "runtime": str(runtime), "output": str(output),
            "python": file_record(Path(sys.executable)),
            "detector": file_record(detector), "config": file_record(config),
            "cases": file_record(cases), "baseCases": file_record(base),
            "extraCases": file_record(extras), "sourceJobs": str(jobs),
            "rotationCases": file_record(rotation_cases),
            "targetedRunner": file_record(targeted_runner),
            "unionRunner": file_record(union_runner),
            "rotationRunner": file_record(rotation_runner),
            "syntheticTests": test_records, "workers": 4,
            "maximumPerCaseSeconds": 180,
            "phaseTimeoutSeconds": {
                "synthetic": 30, "targeted": 30, "union": 30, "rotation": 30,
            },
            "authority": {
                "reviewOnly": True, "trainingEligible": False,
                "xmlEligible": False, "productionEligible": False,
                "automaticHoldClearanceAllowed": False,
            },
        }
        plan_path = runtime / "R34G1_PLAN.json"
        write_json(plan_path, plan)
        passed = subprocess.run(
            [sys.executable, "-B", str(composite), "--plan", str(plan_path)],
            text=True, capture_output=True, check=False, timeout=60,
        )
        assert passed.returncode == 0, passed.stderr
        summary = json.loads((output / "SUMMARY.json").read_text(encoding="utf-8"))
        assert summary["state"] == \
            "PASS_R34_COMPOSITE_141_SYNTHETIC_9_TARGETED_301_UNION_8_ROTATION"
        assert summary["phaseCount"] == 4
        assert [row["name"] for row in summary["phases"][-4:]] == \
            ["synthetic", "targeted", "union", "rotation"]
        assert summary["sourceMutationPerformed"] is False
        assert summary["reviewOnly"] is True
        assert summary["trainingEligible"] is False
        assert summary["xmlEligible"] is False
        assert summary["productionEligible"] is False
        assert summary["automaticHoldClearanceAllowed"] is False

        rejected_output = root / "rejected"
        rejected_plan = dict(plan)
        rejected_plan["output"] = str(rejected_output)
        rejected_plan["detector"] = {"path": str(detector), "sha256": "0" * 64}
        rejected_path = runtime / "REJECTED_PLAN.json"
        write_json(rejected_path, rejected_plan)
        rejected = subprocess.run(
            [sys.executable, "-B", str(composite), "--plan", str(rejected_path)],
            text=True, capture_output=True, check=False, timeout=30,
        )
        assert rejected.returncode != 0
        assert not rejected_output.exists(), "bad detector hash created output"
    print("PASS_R34_COMPOSITE_GATE_CONSTRUCTION")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
