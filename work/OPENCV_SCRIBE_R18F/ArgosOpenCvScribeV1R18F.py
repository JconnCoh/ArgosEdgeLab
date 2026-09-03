#!/usr/bin/env python3
"""R18C image algorithm with R18F K/W/Z references and margin correction."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from typing import Any, Iterable


def _load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


ROOT = Path(__file__).resolve().parents[1]
R18C = _load("argos_scribe_r18c_for_r18f", ROOT / "OPENCV_SCRIBE_R18C/ArgosOpenCvScribeV1R18C.py")
R18F_LOADER = _load("argos_scribe_r18f_loader", Path(__file__).with_name("ArgosOpenCvScribeSupplementLoaderR18F.py"))
MINIMUM_POST_GRID_IMAGE_SCORE = R18C.MINIMUM_POST_GRID_IMAGE_SCORE
TOPOLOGY_OVERRIDE_MINIMUM_MARGIN = 0.12
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18F_K_MARGIN_DIAGNOSTIC_20260903"

R17D = R18C.R17E.R17D
if float(R17D.TOPOLOGY_OVERRIDE_MINIMUM_MARGIN) != 0.15:
    raise ValueError("Frozen R17D topology-margin premise changed")
R17D.TOPOLOGY_OVERRIDE_MINIMUM_MARGIN = TOPOLOGY_OVERRIDE_MINIMUM_MARGIN


def run_job(job_path: Path, result_path: Path) -> int:
    loader_host = R18C.R17E.R17D.R17C.R17B
    original_loader = loader_host._load_supplement_loader
    original_revision = R18C.REVISION
    loader_host._load_supplement_loader = lambda: R18F_LOADER
    R18C.REVISION = REVISION
    try:
        return R18C.run_job(job_path, result_path)
    finally:
        loader_host._load_supplement_loader = original_loader
        R18C.REVISION = original_revision


def main(argv: Iterable[str]) -> int:
    r11 = R18C.R17E.R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
