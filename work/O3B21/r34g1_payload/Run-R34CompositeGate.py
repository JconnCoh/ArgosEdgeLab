#!/usr/bin/env python3
"""Run the complete R34 draft detector gate from one strict file-backed plan."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time


PLAN_KEYS = {
    "schema", "runtime", "output", "python", "detector", "config", "cases",
    "baseCases", "extraCases", "sourceJobs", "rotationCases",
    "targetedRunner", "unionRunner", "rotationRunner", "syntheticTests",
    "workers", "maximumPerCaseSeconds", "phaseTimeoutSeconds", "authority",
}
FILE_KEYS = {"path", "sha256"}
TEST_KEYS = {"path", "sha256", "expectedStdout"}
AUTHORITY = {
    "reviewOnly": True,
    "trainingEligible": False,
    "xmlEligible": False,
    "productionEligible": False,
    "automaticHoldClearanceAllowed": False,
}
SYNTHETIC_PASSES = [
    "PASS_R28_PACKAGED_SYNTHETIC_33_OF_33",
    "PASS_R29_PACKAGED_SYNTHETIC_13_OF_13",
    "PASS_R30_PACKAGED_SYNTHETIC_13_OF_13",
    "PASS_R31_PACKAGED_SYNTHETIC_21_OF_21",
    "PASS_R32_PACKAGED_SYNTHETIC_15_OF_15",
    "PASS_R33_PACKAGED_SYNTHETIC_13_OF_13",
    "PASS_R34_PACKAGED_SYNTHETIC_33_OF_33",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def validate_file(record: dict, label: str) -> Path:
    require(isinstance(record, dict) and set(record) == FILE_KEYS,
            f"{label} file record schema changed")
    path = Path(record["path"])
    require(path.is_file(), f"{label} absent: {path}")
    expected = str(record["sha256"]).upper()
    require(len(expected) == 64 and sha(path) == expected, f"{label} hash changed")
    return path


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def run(command: list[str], cwd: Path, timeout: int) -> dict:
    started = time.monotonic()
    try:
        completed = subprocess.run(
            command, cwd=str(cwd), text=True, capture_output=True,
            check=False, timeout=timeout,
        )
        return {
            "exitCode": completed.returncode,
            "stdoutTail": completed.stdout[-2000:],
            "stderrTail": completed.stderr[-2000:],
            "elapsedSeconds": round(time.monotonic() - started, 3),
        }
    except subprocess.TimeoutExpired as exc:
        return {
            "exitCode": None,
            "timedOut": True,
            "stdoutTail": (exc.stdout or "")[-2000:] if isinstance(exc.stdout, str) else "",
            "stderrTail": (exc.stderr or "")[-2000:] if isinstance(exc.stderr, str) else "",
            "elapsedSeconds": round(time.monotonic() - started, 3),
        }


def child_summary(path: Path, expected_state: str) -> tuple[dict, str]:
    require(path.is_file(), f"child summary absent: {path}")
    value = read_json(path)
    require(value.get("state") == expected_state,
            f"child state changed: {value.get('state')} != {expected_state}")
    return value, sha(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", required=True)
    args = parser.parse_args()
    plan_path = Path(args.plan)
    plan = read_json(plan_path)
    require(isinstance(plan, dict) and set(plan) == PLAN_KEYS, "plan schema changed")
    require(plan["schema"] == "argos_r34_composite_plan_v1", "plan revision changed")
    require(plan["authority"] == AUTHORITY, "authority changed")
    require(int(plan["workers"]) == 4, "worker count changed")
    require(int(plan["maximumPerCaseSeconds"]) == 180, "per-case timeout changed")
    phase_timeouts = plan["phaseTimeoutSeconds"]
    require(
        isinstance(phase_timeouts, dict)
        and set(phase_timeouts) == {"synthetic", "targeted", "union", "rotation"}
        and all(isinstance(value, int) and value > 0 for value in phase_timeouts.values()),
        "phase timeout schema changed",
    )
    runtime, output = Path(plan["runtime"]), Path(plan["output"])
    require(runtime.is_dir(), f"runtime absent: {runtime}")
    require(not output.exists(), f"create-new output exists: {output}")
    python = validate_file(plan["python"], "Python")
    detector = validate_file(plan["detector"], "R34 detector")
    config = validate_file(plan["config"], "R13 config")
    cases = validate_file(plan["cases"], "301-case lock")
    base_cases = validate_file(plan["baseCases"], "298-case base lock")
    extra_cases = validate_file(plan["extraCases"], "three-case sentinel lock")
    rotation_cases = validate_file(plan["rotationCases"], "rotation case lock")
    targeted_runner = validate_file(plan["targetedRunner"], "targeted runner")
    union_runner = validate_file(plan["unionRunner"], "union runner")
    rotation_runner = validate_file(plan["rotationRunner"], "rotation runner")
    source_jobs = Path(plan["sourceJobs"])
    require(source_jobs.is_dir(), f"source jobs absent: {source_jobs}")
    require(len(list(source_jobs.glob("J*.json"))) == 301, "source job count changed")
    tests = plan["syntheticTests"]
    require(isinstance(tests, list) and len(tests) == 7, "synthetic test set changed")
    require([row.get("expectedStdout") for row in tests] == SYNTHETIC_PASSES,
            "synthetic pass sequence changed")
    test_paths = []
    for index, record in enumerate(tests):
        require(isinstance(record, dict) and set(record) == TEST_KEYS,
                f"synthetic test {index} schema changed")
        test_paths.append(validate_file(
            {"path": record["path"], "sha256": record["sha256"]},
            f"synthetic test {index}",
        ))
    require(all(path.parent == runtime for path in (
        detector, config, extra_cases, rotation_cases, targeted_runner,
        union_runner, rotation_runner, *test_paths,
    )), "payload files are not co-located in the frozen runtime")

    output.mkdir(parents=False)
    started = time.monotonic()
    phases = []

    def record_phase(name: str, evidence: dict) -> None:
        phases.append({"name": name, **evidence})
        write_json(output / "PROGRESS.json", {
            "state": f"PASS_R34_{name.upper()}_PHASE" if evidence.get("passed") else
                     f"HOLD_R34_{name.upper()}_PHASE",
            "completedPhaseCount": len(phases), "phases": phases,
            **AUTHORITY,
        })

    def finish_hold(name: str, message: str) -> int:
        summary = {
            "schema": "argos_r34_composite_gate_result_v1",
            "state": "HOLD_R34_COMPOSITE_GATE",
            "failedPhase": name, "failure": message[:2000], "phases": phases,
            "elapsedSeconds": round(time.monotonic() - started, 3),
            "sourceMutationPerformed": False, "sourceDeletionPerformed": False,
            "existingTaskOrProcessActionPerformed": False,
            "providerActivationPerformed": False, "holdsAutomaticallyCleared": False,
            **AUTHORITY,
        }
        write_json(output / "SUMMARY.json", summary)
        return 2

    for test_path, expected in zip(test_paths, SYNTHETIC_PASSES):
        evidence = run(
            [str(python), "-B", str(test_path)], runtime,
            int(phase_timeouts["synthetic"]),
        )
        if evidence.get("exitCode") != 0 or expected not in evidence.get("stdoutTail", ""):
            record_phase("synthetic", {"passed": False, "test": test_path.name, **evidence})
            return finish_hold("synthetic", f"synthetic failed: {test_path.name}")
        phases.append({"name": "synthetic-test", "test": test_path.name,
                       "expected": expected, "passed": True, **evidence})
    record_phase("synthetic", {"passed": True, "testCount": 7,
                                "assertionCount": 141})

    targeted_output = output / "targeted"
    evidence = run([
        str(python), "-B", str(targeted_runner),
        "--source-jobs", str(source_jobs),
        "--cases", str(cases), "--cases-sha256", plan["cases"]["sha256"],
        "--detector", str(detector), "--detector-sha256", plan["detector"]["sha256"],
        "--config", str(config), "--config-sha256", plan["config"]["sha256"],
        "--python", str(python), "--python-sha256", plan["python"]["sha256"],
        "--output", str(targeted_output), "--workers", "4",
        "--maximum-per-case-seconds", "180",
    ], runtime, int(phase_timeouts["targeted"]))
    try:
        targeted, targeted_sha = child_summary(
            targeted_output / "SUMMARY.json", "PASS_R34_TARGETED_GATE_9_OF_9"
        )
        require(evidence.get("exitCode") == 0, "targeted runner failed")
        require(targeted.get("caseCount") == 9 and targeted.get("outcomeMismatchCount") == 0,
                "targeted cardinality changed")
        require(targeted.get("sourceHashesUnchanged") is True
                and targeted.get("sourceMutationPerformed") is False,
                "targeted source invariant changed")
        record_phase("targeted", {"passed": True, "summarySha256": targeted_sha, **evidence})
    except Exception as exc:
        record_phase("targeted", {"passed": False, **evidence})
        return finish_hold("targeted", str(exc))

    union_output = output / "union"
    evidence = run([
        str(python), "-B", str(union_runner),
        "--cases", str(base_cases), "--cases-sha256", plan["baseCases"]["sha256"],
        "--extra-cases", str(extra_cases),
        "--extra-cases-sha256", plan["extraCases"]["sha256"],
        "--detector", str(detector), "--detector-sha256", plan["detector"]["sha256"],
        "--config", str(config), "--config-sha256", plan["config"]["sha256"],
        "--python", str(python), "--python-sha256", plan["python"]["sha256"],
        "--output", str(union_output), "--workers", "4",
        "--maximum-dimension", "2400", "--maximum-per-case-seconds", "180",
    ], runtime, int(phase_timeouts["union"]))
    try:
        union, union_sha = child_summary(
            union_output / "SUMMARY.json", "PASS_R34_UNION_301_OF_301"
        )
        require(evidence.get("exitCode") == 0, "union runner failed")
        require(union.get("caseCount") == 301
                and union.get("outcomeMismatchCount") == 0
                and union.get("invariantMismatchCount") == 0,
                "union cardinality changed")
        require(union.get("scoreDominantResolutionCount") == 4
                and union.get("scoreDominanceHoldCount") == 1,
                "union score-policy population changed")
        require(union.get("sourceMutationPerformed") is False,
                "union source invariant changed")
        record_phase("union", {"passed": True, "summarySha256": union_sha, **evidence})
    except Exception as exc:
        record_phase("union", {"passed": False, **evidence})
        return finish_hold("union", str(exc))

    rotation_output = output / "rotation"
    evidence = run([
        str(python), "-B", str(rotation_runner),
        "--cases", str(rotation_cases), "--detector", str(detector),
        "--config", str(config), "--output", str(rotation_output),
    ], runtime, int(phase_timeouts["rotation"]))
    try:
        rotation, rotation_sha = child_summary(
            rotation_output / "SUMMARY.json", "PASS_R34ROT1_8_OF_8"
        )
        require(evidence.get("exitCode") == 0, "rotation runner failed")
        require(rotation.get("executionCount") == 8
                and len(rotation.get("violations", [])) == 0,
                "rotation cardinality changed")
        require(rotation.get("sourceHashesUnchanged") is True
                and rotation.get("detectorHashUnchanged") is True
                and rotation.get("sourceMutationPerformed") is False,
                "rotation immutability changed")
        record_phase("rotation", {"passed": True, "summarySha256": rotation_sha, **evidence})
    except Exception as exc:
        record_phase("rotation", {"passed": False, **evidence})
        return finish_hold("rotation", str(exc))

    summary = {
        "schema": "argos_r34_composite_gate_result_v1",
        "state": "PASS_R34_COMPOSITE_141_SYNTHETIC_9_TARGETED_301_UNION_8_ROTATION",
        "phaseCount": 4, "phases": phases,
        "planSha256": sha(plan_path), "detectorSha256": sha(detector),
        "elapsedSeconds": round(time.monotonic() - started, 3),
        "sourceMutationPerformed": False, "sourceDeletionPerformed": False,
        "existingTaskOrProcessActionPerformed": False,
        "providerActivationPerformed": False, "holdsAutomaticallyCleared": False,
        **AUTHORITY,
    }
    write_json(output / "SUMMARY.json", summary)
    print(json.dumps({
        "state": summary["state"], "summarySha256": sha(output / "SUMMARY.json"),
        "elapsedSeconds": summary["elapsedSeconds"],
    }, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
