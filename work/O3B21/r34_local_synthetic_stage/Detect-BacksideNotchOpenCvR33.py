#!/usr/bin/env python3
"""R33 keeps R23 local-prominence recovery outside the R25 shallow-profile ratio veto."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


R32_SHA256 = "2E9D19DDCCCA751C21C545AF5E2B6AB62596E86891374AB0E13C84BEDEA48012"
SHALLOW_PROFILE_MODE = "DF_STRONG_MORPHOLOGY_ANCHORED_BF_SHALLOW_IMAGE_APPEARANCE"
LOCAL_PROMINENCE_MODE = "DF_STRONG_MORPHOLOGY_ANCHORED_BF_LOCAL_PROMINENCE_APPEARANCE"
FROZEN_R25_MODES = frozenset({SHALLOW_PROFILE_MODE, LOCAL_PROMINENCE_MODE})
R33_DEPTH_RATIO_MODES = frozenset({SHALLOW_PROFILE_MODE})


def load_r32():
    path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR32.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r32_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R32 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R21.BASE.sha256_file(path) != R32_SHA256:
        raise RuntimeError(f"Frozen R32 detector hash changed: {path}")
    return module


R32 = load_r32()
R25 = R32.R31.R30.R29.R28.R25


def install_r33_depth_ratio_scope() -> None:
    if frozenset(R25.SHALLOW_MODES) != FROZEN_R25_MODES:
        raise RuntimeError("Frozen R25 depth-ratio mode scope changed")
    R25.SHALLOW_MODES = set(R33_DEPTH_RATIO_MODES)


def main() -> int:
    install_r33_depth_ratio_scope()
    return R32.main()


if __name__ == "__main__":
    raise SystemExit(main())
