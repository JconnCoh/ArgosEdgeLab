#!/usr/bin/env python3
"""Image-free proof that R13 fresh execution preserves historical R11 evidence pins."""
from __future__ import annotations
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
RUNNER = HERE / "Run-O3F8R13Targeted.py"
if not RUNNER.is_file():
    RUNNER = HERE.parent / "OPENCV_EDGE_NOTCH_O3F8R13T3" / RUNNER.name

spec = importlib.util.spec_from_file_location("argos_o3f8_r13_t3_pin_test", RUNNER)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load targeted runner: {RUNNER}")
targeted = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = targeted
spec.loader.exec_module(targeted)
l4, historical = targeted.load_l4()

def need(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)

need(str(l4.R11_SHA256) == targeted.R13_SHA256, "Fresh L4 execution engine is not R13.")
need(Path(l4.R11).resolve() == targeted.R13_PATH.resolve(), "Fresh L4 execution path is not R13.")
need(str(historical.R11_SHA256) == "B477C290EC9D3AE388BE4EE31049B2B8094F5F30FC6E0DD68AB4A03926EE4059", "Historical O3F14 evidence pin was overwritten.")
need(Path(historical.R11).name == "FullPerimeterWaferTopologyOpenCvR11.py", "Historical evidence engine is not R11.")

print(json.dumps({
    "schema": "argos_ocv03_o3f8_r13_targeted_pin_isolation_t3_v1",
    "state": "PASS_O3F8_R13_TARGETED_PIN_ISOLATION_T3",
    "runnerSha256": hashlib.sha256(RUNNER.read_bytes()).hexdigest().upper(),
    "freshExecutionSha256": str(l4.R11_SHA256),
    "historicalEvidenceSha256": str(historical.R11_SHA256),
    "imageBytesRead": False,
    "mutationsPerformed": False,
    "reviewOnly": True,
}, separators=(",", ":")))
