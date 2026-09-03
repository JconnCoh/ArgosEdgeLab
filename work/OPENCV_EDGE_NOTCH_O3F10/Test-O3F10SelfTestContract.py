#!/usr/bin/env python3
"""Image-free exact SELF_TEST stdout contract gate for O3F10."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone


EXPECTED_STATE = "PASS_O3F9_STAGED_RUNNER_SELF_TEST"
REAL_SHA256 = "606AFE5DF058F0298CFE333D9091DF3F5F0B5F222EC03C40E73006773F587D72"
FIXTURE_SHA256 = "81A7FD17E1052477743E18FAD726FD6EFEDC201787A433F6B4CCC16485FA7963"
ENDPOINT_REHEARSAL_GATE_SHA256 = "74CAE214115BF4985EB9064678F729A4636C1231C0761AE4EBAE9052F417E311"
EXPECTED_RUNTIME_SHA256 = "4942B86A6597E5AEE0128DAA00050ED79BC21F6E709A78EB19CBFEB0C2F39AC9"
MAXIMUM_OUTPUT_BYTES = 1_048_576


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def assert_pinned(path: Path, expected: str, label: str) -> None:
    if not path.is_file() or sha256(path) != expected:
        raise RuntimeError(f"O3F10 {label} hash changed: {path}")


def run_self_test(path: Path) -> dict[str, object]:
    environment = os.environ.copy()
    environment.update(
        PYTHONDONTWRITEBYTECODE="1",
        PYTHONNOUSERSITE="1",
        PYTHONUTF8="1",
    )
    child = subprocess.run(
        [sys.executable, "-I", "-B", str(path), "SELF_TEST"],
        cwd=str(path.parent),
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=30,
        check=False,
    )
    if len(child.stdout) + len(child.stderr) > MAXIMUM_OUTPUT_BYTES:
        raise RuntimeError(f"O3F10 SELF_TEST output exceeded its bound: {path.name}")
    if child.returncode != 0 or child.stderr:
        raise RuntimeError(f"O3F10 SELF_TEST failed: {path.name}")
    try:
        value = json.loads(child.stdout.decode("utf-8").strip())
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"O3F10 SELF_TEST stdout is not one UTF-8 JSON object: {path.name}") from exc
    if not isinstance(value, dict) or set(value) != {"state", "mutationsPerformed"}:
        raise RuntimeError(f"O3F10 SELF_TEST JSON schema changed: {path.name}")
    if not isinstance(value["state"], str) or not isinstance(value["mutationsPerformed"], bool):
        raise RuntimeError(f"O3F10 SELF_TEST JSON types changed: {path.name}")
    if value["state"] != EXPECTED_STATE or value["mutationsPerformed"] is not False:
        raise RuntimeError(f"O3F10 SELF_TEST state or mutation contract changed: {path.name}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preflight", action="store_true")
    mode.add_argument("--gate", action="store_true")
    args = parser.parse_args()

    package_root = Path(__file__).resolve().parent
    project_root = package_root.parents[1]
    real_runner = project_root / "work" / "O3F8" / "Run-O3F9Staged.py"
    fixture_runner = package_root / "O3F10FixtureRunner.py"
    endpoint_gate = package_root / "O3F10_ENDPOINT_REHEARSAL_GATE.json"
    gate_path = package_root / "O3F10_SELF_TEST_CONTRACT_GATE.json"
    assert_pinned(real_runner, REAL_SHA256, "real runner")
    assert_pinned(fixture_runner, FIXTURE_SHA256, "fixture runner")
    assert_pinned(endpoint_gate, ENDPOINT_REHEARSAL_GATE_SHA256, "endpoint rehearsal gate")
    endpoint_value = json.loads(endpoint_gate.read_text(encoding="utf-8"))
    if endpoint_value.get("state") != "PASS_O3F10_EXACT_ENTRYPOINT_REHEARSAL":
        raise RuntimeError("O3F10 endpoint rehearsal state changed")
    runtime_path = Path(sys.executable).resolve()
    if sha256(runtime_path) != EXPECTED_RUNTIME_SHA256 or endpoint_value.get("pythonSha256") != EXPECTED_RUNTIME_SHA256:
        raise RuntimeError("O3F10 exact rehearsal Python changed")
    if gate_path.exists():
        raise RuntimeError(f"O3F10 SELF_TEST contract gate exists: {gate_path}")

    if args.preflight:
        print(json.dumps({
            "schema": "argos_ocv03_o3f10_self_test_contract_preflight_v1",
            "state": "PASS_O3F10_SELF_TEST_CONTRACT_PREFLIGHT",
            "realRunnerSha256": REAL_SHA256,
            "fixtureRunnerSha256": FIXTURE_SHA256,
            "endpointRehearsalGateSha256": ENDPOINT_REHEARSAL_GATE_SHA256,
            "runtimeSha256": EXPECTED_RUNTIME_SHA256,
            "childrenExecuted": 0,
            "sourceImageBytesRead": False,
            "mutationsPerformed": False,
            "reviewOnly": True,
            "productionRoutingEnabled": False,
        }, separators=(",", ":")))
        return 0

    real = run_self_test(real_runner)
    fixture = run_self_test(fixture_runner)
    result = {
        "schema": "argos_ocv03_o3f10_self_test_contract_gate_v1",
        "checkedUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "PASS_O3F10_REAL_AND_FIXTURE_SELF_TEST_CONTRACT",
        "realRunnerSha256": REAL_SHA256,
        "fixtureRunnerSha256": FIXTURE_SHA256,
        "endpointRehearsalGateSha256": ENDPOINT_REHEARSAL_GATE_SHA256,
        "endpointRehearsalState": endpoint_value["state"],
        "runtimePath": str(runtime_path),
        "runtimeSha256": EXPECTED_RUNTIME_SHA256,
        "expectedKeys": ["mutationsPerformed", "state"],
        "realState": real["state"],
        "fixtureState": fixture["state"],
        "realMutationsPerformed": real["mutationsPerformed"],
        "fixtureMutationsPerformed": fixture["mutationsPerformed"],
        "schemaMatchesExactly": set(real) == set(fixture),
        "childrenExecuted": 2,
        "sourceImageBytesRead": False,
        "sourceMutationPerformed": False,
        "taskActionCount": 0,
        "existingProcessActionCount": 0,
        "providerActivated": False,
        "requestRetryAuthorized": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    with gate_path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(result, handle, indent=2)
        handle.write("\n")
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
