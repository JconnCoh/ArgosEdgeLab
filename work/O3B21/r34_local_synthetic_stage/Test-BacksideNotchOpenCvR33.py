#!/usr/bin/env python3
"""Focused R33 depth-ratio scope and successor-preservation tests."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path


here = Path(__file__).parent
root = here if (here / "Detect-BacksideNotchOpenCvR33.py").is_file() else (
    Path(__file__).parents[1] / "OPENCV_BACKSIDE_NOTCH_O3B10"
)
path = root / "Detect-BacksideNotchOpenCvR33.py"
spec = importlib.util.spec_from_file_location("r33_test", path)
assert spec is not None and spec.loader is not None
r33 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r33)
r33.R32.R21.R17._PARAMETERS = json.loads(
    (root / "BACKSIDE_NOTCH_CONFIG_R13.json").read_text(encoding="utf-8")
)["radialParameters"]

tests = 0


def check(value: bool, message: str) -> None:
    global tests
    assert value, message
    tests += 1


def pair(mode: str, bf_depth: float, df_depth: float) -> dict:
    return {
        "confirmationMode": mode,
        "bfDepthNativePx": bf_depth,
        "dfDepthNativePx": df_depth,
    }


check(frozenset(r33.R25.SHALLOW_MODES) == r33.FROZEN_R25_MODES, "frozen R25 scope")
check(r33.R33_DEPTH_RATIO_MODES == frozenset({r33.SHALLOW_PROFILE_MODE}), "R33 scope")
check(
    r33.R32.R21.R17._PARAMETERS["bfShallowAppearanceMaximumDepthRatioToDfAnchor"] == 0.5,
    "frozen ratio unchanged",
)
r33.install_r33_depth_ratio_scope()

original = r33.R25.ORIGINAL_R23_PAIR
try:
    cases = [
        (r33.SHALLOW_PROFILE_MODE, 74.9873046875, 80.990234375, 0, True),
        (r33.SHALLOW_PROFILE_MODE, 10.0, 80.0, 1, True),
        (r33.LOCAL_PROMINENCE_MODE, 61.0, 74.9794921875, 1, False),
        ("STRICT_BOTH_CHANNELS", 75.0, 70.0, 1, False),
    ]
    for mode, bf_depth, df_depth, expected_count, applies in cases:
        source = pair(mode, bf_depth, df_depth)
        r33.R25.ORIGINAL_R23_PAIR = lambda bf, df, row=source: [row]
        bf = {}
        retained = r33.R25.pair_candidates(bf, {})
        row = bf["bfShallowDepthRatioNegativeControl"]["rows"][0]
        check(len(retained) == expected_count, f"retained count for {mode}")
        check(row["shallowModeRatioGateApplies"] is applies, f"scope for {mode}")
finally:
    r33.R25.ORIGINAL_R23_PAIR = original

r27 = r33.R32.R31.R30.R29.R28.R27
bf = {}
retained = r27.apply_frozen_depth_ratio_gate(
    bf, [pair(r33.LOCAL_PROMINENCE_MODE, 54.0, 74.998046875)]
)
check(len(retained) == 1, "R27 preserves local-prominence recovery")
check(
    bf["bfShallowDepthRatioNegativeControl"]["rows"][0]["shallowModeRatioGateApplies"] is False,
    "R27 uses corrected scope",
)

print(f"PASS_R33_PACKAGED_SYNTHETIC_{tests}_OF_{tests}")
