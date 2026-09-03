#!/usr/bin/env python3
"""Image-free proof that fresh run_one binds R13 only after R11 validation."""
from __future__ import annotations

import hashlib
import importlib.util
import inspect
import json
from pathlib import Path
import sys


HERE = Path(__file__).resolve().parent
RUNNER = HERE / "Run-O3F8R13Targeted.py"
if not RUNNER.is_file():
    RUNNER = HERE.parent / "OPENCV_EDGE_NOTCH_O3F8R13T5" / RUNNER.name

spec = importlib.util.spec_from_file_location("argos_o3f8_r13_t5_binding_test", RUNNER)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load targeted runner: {RUNNER}")
targeted = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = targeted
spec.loader.exec_module(targeted)


def need(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


l4, child = targeted.load_l4()
need(str(child.R11_SHA256) == targeted.R11_SHA256, "Historical child is not R11 before activation.")
need(Path(child.R11).name == "FullPerimeterWaferTopologyOpenCvR11.py", "Historical child path changed.")
targeted.activate_r13_execution(l4, child)
need(str(child.R11_SHA256) == targeted.R13_SHA256, "Fresh child hash did not switch to R13.")
need(Path(child.R11).resolve() == targeted.R13_PATH.resolve(), "Fresh child path did not switch to R13.")

run_source = inspect.getsource(targeted.run)
context_at = run_source.index("context = l4.preflight_context()")
activation_at = run_source.index("activate_r13_execution(l4, frozen)")
launch_at = run_source.index("l4.run_one(")
need(context_at < activation_at < launch_at, "R13 activation is not between historical validation and child launch.")

print(json.dumps({
    "schema": "argos_ocv03_o3f8_r13_execution_binding_t5_v1",
    "state": "PASS_O3F8_R13_EXECUTION_BINDING_T5",
    "runnerSha256": hashlib.sha256(RUNNER.read_bytes()).hexdigest().upper(),
    "historicalValidationEngineSha256": targeted.R11_SHA256,
    "freshChildEngineSha256": targeted.R13_SHA256,
    "activationAfterHistoricalValidation": True,
    "activationBeforeChildLaunch": True,
    "imageBytesRead": False,
    "mutationsPerformed": False,
    "reviewOnly": True,
}, separators=(",", ":")))
