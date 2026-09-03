#!/usr/bin/env python3
"""Image-free exact flat-package closure check for the targeted R13 runner."""
from __future__ import annotations
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
RUNNER = HERE / "Run-O3F14Staged.py"
if not RUNNER.is_file():
    RUNNER = HERE.parent / "O3F8" / RUNNER.name
spec = importlib.util.spec_from_file_location("argos_o3f8_r13_t4_closure", RUNNER)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load closure owner: {RUNNER}")
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
module.assert_package_pins()
print(json.dumps({
    "schema":"argos_ocv03_o3f8_r13_package_closure_t4_v1",
    "state":"PASS_O3F8_R13_PACKAGE_CLOSURE_T4",
    "validatedPinCount":9,
    "imageBytesRead":False,
    "mutationsPerformed":False,
    "reviewOnly":True,
}, separators=(",", ":")))
