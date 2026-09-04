#!/usr/bin/env python3
"""R11 binds the lane-qualified R10 diagnostic to the qualified L4 alias context."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


HERE = Path(__file__).resolve().parent
R10_PATH = HERE / "AnnularUnwrapDiagnosticOpenCvR10.py"
SPEC = importlib.util.spec_from_file_location("argos_annular_diagnostic_r10", R10_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load {R10_PATH}")
diagnostic = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = diagnostic
SPEC.loader.exec_module(diagnostic)
diagnostic.FRONT = diagnostic.load(
    "argos_annular_front_l4",
    HERE / "Run-O3F15L4FrontReconcile.py",
)


if __name__ == "__main__":
    raise SystemExit(diagnostic.main())
