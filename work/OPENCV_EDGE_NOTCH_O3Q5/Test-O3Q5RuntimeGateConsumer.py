#!/usr/bin/env python3
"""Exact-fixture contract controls for the O3Q5 O3P8 compatibility adapter."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
from typing import Any


EXPECTED_GATE_SHA256 = "09DEEF0BC1C0DC9464F5BF5CE93EF590F2780F3123BB13AB6080358E562C68C4"
EXPECTED_GATE_SCHEMA = "argos_ocv03_o3q4_jbod_runtime_binding_gate_v1"
EXPECTED_GATE_STATE = "PASS_O3RV1_FILE_BACKED_JBOD_RUNTIME_PREMISE"
EXPECTED_PYTHON_VERSION = "3.13.2"
EXPECTED_OPENCV_VERSION = "5.0.0"
EXPECTED_NUMPY_VERSION = "2.5.2"
EXPECTED_PYTHON_SHA256 = "7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1"
EXPECTED_INSTALLATION_SHA256 = "1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_module(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("argos_o3q5_runtime_gate_candidate", path)
    require(spec is not None and spec.loader is not None, f"Cannot load candidate: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def base_job(runtime_root: Path, output_path: Path, gate_path: Path, topology_path: Path, crop_path: Path) -> dict[str, Any]:
    return {
        "schema": "argos_ocv03_o3p8_front_split_notch_job_v1",
        "revision": "O3Q5_EXACT_RUNTIME_GATE_CONTRACT_TEST",
        "runtimeRoot": str(runtime_root),
        "runtimeGate": {"path": str(gate_path), "sha256": sha256_file(gate_path)},
        "expectedRuntimeGateSchema": EXPECTED_GATE_SCHEMA,
        "expectedRuntimeGateState": EXPECTED_GATE_STATE,
        "expectedRuntimeTargetRole": "JBOD",
        "expectedPythonVersion": EXPECTED_PYTHON_VERSION,
        "expectedRuntimeSha256": EXPECTED_PYTHON_SHA256,
        "expectedRuntimeInstallationSha256": EXPECTED_INSTALLATION_SHA256,
        "topologyEngine": {"path": str(topology_path), "sha256": sha256_file(topology_path)},
        "cropEngine": {"path": str(crop_path), "sha256": sha256_file(crop_path)},
        "outputPath": str(output_path),
        "expectedOpenCvVersion": EXPECTED_OPENCV_VERSION,
        "expectedNumpyVersion": EXPECTED_NUMPY_VERSION,
        "channelMethods": {
            "BF": "O3L8_TOP_CONNECTED_TOPOLOGY_MEASURED_CONTOUR",
            "DF": "FROZEN_R6_OUTER_EDGE_RADIAL_FULL_360",
        },
        "candidateLocalTopologyErrors": sorted(
            [
                "No top-connected wafer component qualified.",
                "Top-connected wafer component has no external contour.",
                "Wafer contour covers fewer than two columns.",
                "Lower-side contour-noise population is empty.",
            ]
        ),
        "knownNotchLocationConsumed": False,
        "notchAnglePriorConsumed": False,
        "fixedAngularSearchWindowConsumed": False,
        "scorerInputsPresent": False,
        "sourceMutationAllowed": False,
        "rasterOutputAllowed": False,
        "liveProviderActivation": False,
        "backsidePixelsConsumed": False,
        "dfTopologyInvocationAllowed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def call_load_job(module: Any, job_path: Path) -> tuple[bool, str]:
    try:
        module.load_job(job_path)
        return True, ""
    except ValueError as exc:
        return False, str(exc)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--exact-runtime-gate", required=True)
    parser.add_argument("--expect-legacy-failure", action="store_true")
    arguments = parser.parse_args()

    candidate_path = Path(arguments.candidate).resolve(strict=True)
    exact_gate_path = Path(arguments.exact_runtime_gate).resolve(strict=True)
    require(sha256_file(exact_gate_path) == EXPECTED_GATE_SHA256, "Exact O3Q4 runtime-gate bytes changed.")
    exact_gate = json.loads(exact_gate_path.read_text(encoding="utf-8"))
    require(exact_gate.get("schema") == EXPECTED_GATE_SCHEMA, "Exact O3Q4 runtime-gate schema changed.")
    require(exact_gate.get("state") == EXPECTED_GATE_STATE, "Exact O3Q4 runtime-gate state changed.")

    module = load_module(candidate_path)
    image_read_count = 0
    original_imread = module.cv2.imread
    original_cv_version = module.cv2.__version__
    original_np_version = module.np.__version__
    original_module_under_root = module.module_under_root

    def forbidden_imread(*args: Any, **kwargs: Any) -> Any:
        nonlocal image_read_count
        image_read_count += 1
        raise AssertionError("Contract test attempted to read image bytes.")

    module.cv2.imread = forbidden_imread
    module.cv2.__version__ = EXPECTED_OPENCV_VERSION
    module.np.__version__ = EXPECTED_NUMPY_VERSION
    module.module_under_root = lambda module_file, root, label: str(root / label)

    try:
        with tempfile.TemporaryDirectory(prefix="argos_o3q5_contract_") as temporary:
            root = Path(temporary)
            topology_path = root / "topology.py"
            crop_path = root / "crop.py"
            topology_path.write_text("# pinned contract fixture\n", encoding="utf-8", newline="\n")
            crop_path.write_text("# pinned contract fixture\n", encoding="utf-8", newline="\n")

            positive_job = base_job(root, root / "positive-result.json", exact_gate_path, topology_path, crop_path)
            positive_job_path = root / "positive-job.json"
            write_json(positive_job_path, positive_job)
            positive_passed, positive_error = call_load_job(module, positive_job_path)

            if arguments.expect_legacy_failure:
                require(not positive_passed, "Legacy O3P8 unexpectedly accepted the exact O3Q4 runtime gate.")
                require(positive_error == "O3P8 runtime gate is not PASS.", f"Unexpected legacy failure: {positive_error}")
                require(image_read_count == 0, "Legacy reproduction read image bytes.")
                print(
                    json.dumps(
                        {
                            "state": "PASS_O3Q5_EXACT_FIXTURE_REPRODUCED_LEGACY_CONSUMER_FAILURE",
                            "candidateSha256": sha256_file(candidate_path),
                            "exactRuntimeGateSha256": EXPECTED_GATE_SHA256,
                            "observedFailure": positive_error,
                            "imageReadCount": image_read_count,
                        },
                        separators=(",", ":"),
                    )
                )
                return 0

            cases: list[dict[str, Any]] = []
            cases.append({"caseId": "EXACT_O3Q4_GATE", "passed": positive_passed, "error": positive_error})

            wrong_hash_job = dict(positive_job)
            wrong_hash_job["runtimeGate"] = dict(positive_job["runtimeGate"])
            wrong_hash_job["runtimeGate"]["sha256"] = "0" * 64
            wrong_hash_path = root / "wrong-hash-job.json"
            write_json(wrong_hash_path, wrong_hash_job)
            passed, error = call_load_job(module, wrong_hash_path)
            cases.append({"caseId": "WRONG_GATE_HASH", "passed": not passed and error == "O3P8 runtime gate changed.", "error": error})

            wrong_state_job = dict(positive_job)
            wrong_state_job["expectedRuntimeGateState"] = "PASS_O3P2_LOCAL_RUNTIME_INSTALLED"
            wrong_state_path = root / "wrong-state-job.json"
            write_json(wrong_state_path, wrong_state_job)
            passed, error = call_load_job(module, wrong_state_path)
            cases.append({"caseId": "WRONG_EXPECTED_STATE", "passed": not passed and error == "O3P8 runtime gate state changed.", "error": error})

            failed_gate = dict(exact_gate)
            failed_gate["state"] = "FAIL_TEST_RUNTIME_PREMISE"
            failed_gate_path = root / "failed-gate.json"
            write_json(failed_gate_path, failed_gate)
            failed_gate_job = base_job(root, root / "failed-result.json", failed_gate_path, topology_path, crop_path)
            failed_gate_path_job = root / "failed-gate-job.json"
            write_json(failed_gate_path_job, failed_gate_job)
            passed, error = call_load_job(module, failed_gate_path_job)
            cases.append({"caseId": "FAILED_GATE_STATE", "passed": not passed and error == "O3P8 runtime gate state changed.", "error": error})

            wrong_version_gate = json.loads(json.dumps(exact_gate))
            wrong_version_gate["numpyVersion"] = "0.0.0"
            wrong_version_gate_path = root / "wrong-version-gate.json"
            write_json(wrong_version_gate_path, wrong_version_gate)
            wrong_version_job = base_job(root, root / "wrong-version-result.json", wrong_version_gate_path, topology_path, crop_path)
            wrong_version_job_path = root / "wrong-version-job.json"
            write_json(wrong_version_job_path, wrong_version_job)
            passed, error = call_load_job(module, wrong_version_job_path)
            cases.append({"caseId": "WRONG_GATE_NUMPY_VERSION", "passed": not passed and error == "O3P8 runtime gate NumPy version changed.", "error": error})

            all_passed = all(bool(case["passed"]) for case in cases) and image_read_count == 0
            print(
                json.dumps(
                    {
                        "state": "PASS_O3Q5_EXACT_RUNTIME_GATE_CONSUMER" if all_passed else "FAIL_O3Q5_EXACT_RUNTIME_GATE_CONSUMER",
                        "candidateSha256": sha256_file(candidate_path),
                        "exactRuntimeGateSha256": EXPECTED_GATE_SHA256,
                        "cases": cases,
                        "imageReadCount": image_read_count,
                    },
                    separators=(",", ":"),
                )
            )
            return 0 if all_passed else 1
    finally:
        module.cv2.imread = original_imread
        module.cv2.__version__ = original_cv_version
        module.np.__version__ = original_np_version
        module.module_under_root = original_module_under_root


if __name__ == "__main__":
    raise SystemExit(main())
