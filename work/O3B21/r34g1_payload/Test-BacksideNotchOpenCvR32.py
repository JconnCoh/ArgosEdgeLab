#!/usr/bin/env python3
"""Focused R32 unique both-channel exterior-clear multi-pair resolution tests."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path


here = Path(__file__).parent
root = here if (here / "Detect-BacksideNotchOpenCvR32.py").is_file() else (
    Path(__file__).parents[1] / "OPENCV_BACKSIDE_NOTCH_O3B10"
)
path = root / "Detect-BacksideNotchOpenCvR32.py"
spec = importlib.util.spec_from_file_location("r32_test", path)
assert spec is not None and spec.loader is not None
r32 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r32)
r32.R21.R17._PARAMETERS = json.loads(
    (root / "BACKSIDE_NOTCH_CONFIG_R13.json").read_text(encoding="utf-8")
)["radialParameters"]


def context(clear: bool) -> dict:
    return {
        "brightPixelFraction": 0.0 if clear else 0.20,
        "maximumAngularBrightSupportFraction": 0.0 if clear else 0.50,
    }


def pair(angle: float, bf_clear: bool, df_clear: bool) -> dict:
    return {
        "meanAngleDegrees": angle,
        "confirmationMode": "STRICT_BOTH_CHANNELS",
        "bfExteriorContext": context(bf_clear),
        "dfExteriorContext": context(df_clear),
    }


tests = 0


def check(value: bool, message: str) -> None:
    global tests
    assert value, message
    tests += 1


true_notch = pair(89.6383, True, True)
residue_response = pair(134.3371, False, False)
retained, diagnostic = r32.resolve_unique_both_channel_exterior_clear_pair(
    [true_notch, residue_response]
)
check(retained == [true_notch], "unique clean pair retained")
check(diagnostic["state"] == "PASS_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR", "pass state")
check(diagnostic["inputPairCount"] == 2, "input count recorded")
check(diagnostic["bothChannelsExteriorClearPairCount"] == 1, "clean count recorded")
check(diagnostic["retainedPairCount"] == 1, "retained count recorded")
check(diagnostic["usesFrozenR30ExteriorThresholds"] is True, "frozen threshold reuse recorded")

single_dirty = pair(200.0, False, False)
retained, diagnostic = r32.resolve_unique_both_channel_exterior_clear_pair([single_dirty])
check(retained == [single_dirty], "single residue-covered notch is never removed")
check(diagnostic["state"] == "NOT_APPLIED_SINGLE_OR_EMPTY_PAIR", "single bypass state")

second_clean = pair(180.0, True, True)
retained, diagnostic = r32.resolve_unique_both_channel_exterior_clear_pair([true_notch, second_clean])
check(retained == [true_notch, second_clean], "two clean pairs remain ambiguous")
check(diagnostic["state"] == "HOLD_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR_NOT_UNIQUE", "two-clean hold")

bf_only = pair(45.0, True, False)
df_only = pair(225.0, False, True)
retained, diagnostic = r32.resolve_unique_both_channel_exterior_clear_pair([bf_only, df_only])
check(retained == [bf_only, df_only], "no both-channel-clean pair remains ambiguous")
check(diagnostic["bothChannelsExteriorClearPairCount"] == 0, "zero-clean count")

retained, _ = r32.resolve_unique_both_channel_exterior_clear_pair([bf_only, true_notch])
check(retained == [true_notch], "one-channel exterior response cannot displace unique both-clear pair")

original = r32.R31.pair_candidates
try:
    r32.R31.pair_candidates = lambda bf, df: [true_notch, residue_response]
    bf = {}
    check(r32.pair_candidates(bf, {}) == [true_notch], "R31 multi-pair result resolved")
    check(bf["multiPairExteriorCleanResolution"]["retainedPairCount"] == 1, "diagnostic attached")
finally:
    r32.R31.pair_candidates = original

assert tests == 15, tests
print("PASS_R32_PACKAGED_SYNTHETIC_15_OF_15")
