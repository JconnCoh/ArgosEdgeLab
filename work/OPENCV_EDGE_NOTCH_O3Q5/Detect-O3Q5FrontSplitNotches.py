#!/usr/bin/env python3
"""O3P8 detector with an O3Q5 job-pinned runtime-gate compatibility boundary."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys
from typing import Any


FROZEN_ENGINE_PATH = (
    Path(__file__).resolve().parent.parent
    / "OPENCV_EDGE_NOTCH_O3P8"
    / "Detect-O3P8FrontSplitNotches.py"
)
FROZEN_ENGINE_SHA256 = "41F60AF393E0B2C752AF6B33BB6673145490AE2BB346A4DA8E59A2D42E383E36"


def load_frozen_engine(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("argos_o3q5_frozen_o3p8_engine", path)
    if spec is None or spec.loader is None:
        raise ValueError(f"Cannot load frozen O3P8 engine: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


_engine = load_frozen_engine(FROZEN_ENGINE_PATH)
require = _engine.require
sha256_file = _engine.sha256_file
module_under_root = _engine.module_under_root
cv2 = _engine.cv2
np = _engine.np
JOB_SCHEMA = _engine.JOB_SCHEMA
CANDIDATE_LOCAL_TOPOLOGY_ERRORS = _engine.CANDIDATE_LOCAL_TOPOLOGY_ERRORS


require(sha256_file(FROZEN_ENGINE_PATH) == FROZEN_ENGINE_SHA256, "Frozen O3P8 detector changed.")


def load_job(path: Path) -> tuple[dict[str, Any], Path, Path, Path, Path, Path]:
    job = json.loads(path.read_text(encoding="utf-8"))
    require(job.get("schema") == JOB_SCHEMA, "O3P8 job schema changed.")
    for field in (
        "trainingEligible",
        "xmlEligible",
        "productionEligible",
        "productionRoutingEnabled",
        "knownNotchLocationConsumed",
        "notchAnglePriorConsumed",
        "fixedAngularSearchWindowConsumed",
        "scorerInputsPresent",
        "sourceMutationAllowed",
        "rasterOutputAllowed",
        "liveProviderActivation",
        "backsidePixelsConsumed",
        "dfTopologyInvocationAllowed",
    ):
        require(job.get(field) is False, f"Forbidden O3P8 authority changed: {field}")
    require(job.get("reviewOnly") is True, "O3P8 must remain review-only.")
    require(
        job.get("channelMethods")
        == {
            "BF": "O3L8_TOP_CONNECTED_TOPOLOGY_MEASURED_CONTOUR",
            "DF": "FROZEN_R6_OUTER_EDGE_RADIAL_FULL_360",
        },
        "O3P8 channel-method split changed.",
    )
    require(
        job.get("candidateLocalTopologyErrors") == sorted(CANDIDATE_LOCAL_TOPOLOGY_ERRORS),
        "O3P8 candidate-local exception contract changed.",
    )

    runtime_root = Path(str(job["runtimeRoot"])).resolve(strict=True)
    runtime_gate = Path(str(job["runtimeGate"]["path"])).resolve(strict=True)
    topology_path = Path(str(job["topologyEngine"]["path"])).resolve(strict=True)
    renderer_path = Path(str(job["cropEngine"]["path"])).resolve(strict=True)
    output_path = Path(str(job["outputPath"])).resolve(strict=False)
    require(runtime_root.is_dir() and output_path.parent.is_dir(), "O3P8 runtime or output parent is absent.")
    require(
        not output_path.exists() and not output_path.with_name(output_path.name + ".partial").exists(),
        "O3P8 output must be create-new.",
    )
    for record, label in (
        (job["runtimeGate"], "runtime gate"),
        (job["topologyEngine"], "topology engine"),
        (job["cropEngine"], "crop engine"),
    ):
        resolved = Path(str(record["path"])).resolve(strict=True)
        require(sha256_file(resolved) == str(record["sha256"]).upper(), f"O3P8 {label} changed.")

    runtime_gate_value = json.loads(runtime_gate.read_text(encoding="utf-8"))
    expected_gate_schema = str(job["expectedRuntimeGateSchema"])
    expected_gate_state = str(job["expectedRuntimeGateState"])
    require(expected_gate_state.startswith("PASS_"), "O3P8 expected runtime gate state is not PASS.")
    require(runtime_gate_value.get("schema") == expected_gate_schema, "O3P8 runtime gate schema changed.")
    require(runtime_gate_value.get("state") == expected_gate_state, "O3P8 runtime gate state changed.")
    require(
        str(job["expectedRuntimeTargetRole"]) == "JBOD" and runtime_gate_value.get("targetRole") == "JBOD",
        "O3P8 runtime gate target role changed.",
    )
    require(
        runtime_gate_value.get("python", {}).get("version") == str(job["expectedPythonVersion"]),
        "O3P8 runtime gate Python version changed.",
    )
    require(
        str(runtime_gate_value.get("python", {}).get("sha256", "")).upper()
        == str(job["expectedRuntimeSha256"]).upper(),
        "O3P8 runtime gate Python hash changed.",
    )
    require(
        str(runtime_gate_value.get("installation", {}).get("sha256", "")).upper()
        == str(job["expectedRuntimeInstallationSha256"]).upper(),
        "O3P8 runtime gate installation hash changed.",
    )
    require(
        runtime_gate_value.get("opencvVersion") == str(job["expectedOpenCvVersion"]),
        "O3P8 runtime gate OpenCV version changed.",
    )
    require(
        runtime_gate_value.get("numpyVersion") == str(job["expectedNumpyVersion"]),
        "O3P8 runtime gate NumPy version changed.",
    )
    require(
        runtime_gate_value.get("reviewOnly") is True
        and runtime_gate_value.get("trainingEligible") is False
        and runtime_gate_value.get("xmlEligible") is False
        and runtime_gate_value.get("productionEligible") is False
        and runtime_gate_value.get("productionRoutingEnabled") is False
        and runtime_gate_value.get("providerActivationAllowed") is False,
        "O3P8 runtime gate authority widened.",
    )

    module_under_root(str(cv2.__file__), runtime_root, "OpenCV")
    module_under_root(str(np.__file__), runtime_root, "NumPy")
    require(cv2.__version__ == str(job["expectedOpenCvVersion"]), "O3P8 OpenCV version changed.")
    require(np.__version__ == str(job["expectedNumpyVersion"]), "O3P8 NumPy version changed.")
    return job, runtime_root, runtime_gate, topology_path, renderer_path, output_path


def main() -> int:
    _engine.load_job = load_job
    return int(_engine.main())


if __name__ == "__main__":
    raise SystemExit(main())
