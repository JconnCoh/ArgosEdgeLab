#!/usr/bin/env python3
"""R18C algorithm with the R18D operator-confirmed W/Z diagnostic bank."""

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
R18C = _load("argos_scribe_r18c_for_r18d", ROOT / "OPENCV_SCRIBE_R18C/ArgosOpenCvScribeV1R18C.py")
R18D_LOADER = _load("argos_scribe_r18d_loader", Path(__file__).with_name("ArgosOpenCvScribeSupplementLoaderR18D.py"))
MINIMUM_POST_GRID_IMAGE_SCORE = R18C.MINIMUM_POST_GRID_IMAGE_SCORE
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18D_WZ_DIAGNOSTIC_20260903"


def run_job(job_path: Path, result_path: Path) -> int:
    chain = R18C.R17E.R17D.R17C.R17B
    original = chain._load_supplement_loader
    chain._load_supplement_loader = lambda: R18D_LOADER
    try:
        return R18C.run_job(job_path, result_path)
    finally:
        chain._load_supplement_loader = original


def main(argv: Iterable[str]) -> int:
    r11 = R18C.R17E.R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
