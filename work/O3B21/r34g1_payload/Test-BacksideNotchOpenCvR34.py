#!/usr/bin/env python3
"""Focused R34 conservative score-dominance resolution tests."""

from __future__ import annotations

import importlib.util
import json
import math
from pathlib import Path


here = Path(__file__).parent
root = here if (here / "Detect-BacksideNotchOpenCvR34.py").is_file() else (
    Path(__file__).parents[1] / "OPENCV_BACKSIDE_NOTCH_O3B10"
)
path = root / "Detect-BacksideNotchOpenCvR34.py"
spec = importlib.util.spec_from_file_location("r34_test", path)
assert spec is not None and spec.loader is not None
r34 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r34)
r34.R32.R21.R17._PARAMETERS = json.loads(
    (root / "BACKSIDE_NOTCH_CONFIG_R13.json").read_text(encoding="utf-8")
)["radialParameters"]


def context(clear: bool) -> dict:
    return {
        "brightPixelFraction": 0.0 if clear else 0.20,
        "maximumAngularBrightSupportFraction": 0.0 if clear else 0.50,
    }


def pair(angle: float, score, bf_clear: bool, df_clear: bool) -> dict:
    row = {
        "meanAngleDegrees": angle,
        "confirmationMode": "STRICT_BOTH_CHANNELS",
        "bfExteriorContext": context(bf_clear),
        "dfExteriorContext": context(df_clear),
    }
    if score is not MISSING:
        row["score"] = score
    return row


MISSING = object()
tests = 0


def check(value: bool, message: str) -> None:
    global tests
    assert value, message
    tests += 1


clean_high = pair(89.6383, 74.0, True, True)
dirty_low = pair(134.3371, 47.2, False, False)
retained, diagnostic = r34.resolve_unique_both_channel_exterior_clear_pair(
    [clean_high, dirty_low]
)
check(retained == [clean_high], "score-dominant clean pair resolves")
check(diagnostic["state"] == r34.R32_PASS_STATE, "compatible pass state retained")
check(diagnostic["requiresStrictScoreDominance"] is True, "dominance contract recorded")
check(diagnostic["scoreDominanceEvaluated"] is True, "dominance evaluated")
check(diagnostic["allComparedPairScoresFinite"] is True, "finite population recorded")
check(diagnostic["strictScoreDominancePassed"] is True, "dominance pass recorded")
check(diagnostic["uniqueBothChannelsExteriorClearPairScore"] == 74.0, "clean score recorded")
check(diagnostic["maximumExteriorDirtyPairScore"] == 47.2, "dirty maximum recorded")

dirty_high = pair(223.9127, 154.2, False, False)
clean_low = pair(179.7062, 74.2, True, True)
retained, diagnostic = r34.resolve_unique_both_channel_exterior_clear_pair(
    [dirty_high, clean_low]
)
check(retained == [dirty_high, clean_low], "stronger dirty pair preserves ambiguity")
check(diagnostic["state"] == r34.SCORE_DOMINANCE_HOLD_STATE, "dominance hold state")
check(diagnostic["retainedPairCount"] == 2, "hold retains both pairs")
check(diagnostic["strictScoreDominancePassed"] is False, "failed dominance recorded")

for unsafe_score, label in (
    (74.2, "tie"),
    (MISSING, "missing"),
    (math.nan, "nan"),
    (math.inf, "infinite"),
    ("not-a-number", "nonnumeric"),
):
    unsafe = pair(220.0, unsafe_score, False, False)
    retained, diagnostic = r34.resolve_unique_both_channel_exterior_clear_pair(
        [clean_low, unsafe]
    )
    check(len(retained) == 2, f"{label} score preserves ambiguity")
    check(diagnostic["state"] == r34.SCORE_DOMINANCE_HOLD_STATE, f"{label} hold")

second_clean = pair(180.0, 120.0, True, True)
retained, diagnostic = r34.resolve_unique_both_channel_exterior_clear_pair(
    [clean_high, second_clean]
)
check(len(retained) == 2, "two clean pairs remain ambiguous")
check(
    diagnostic["state"] == "HOLD_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR_NOT_UNIQUE",
    "R32 two-clean state unchanged",
)
check(diagnostic["scoreDominanceEvaluated"] is False, "two-clean ranking not evaluated")

bf_only = pair(45.0, 100.0, True, False)
df_only = pair(225.0, 90.0, False, True)
retained, diagnostic = r34.resolve_unique_both_channel_exterior_clear_pair(
    [bf_only, df_only]
)
check(len(retained) == 2, "zero both-channel-clean pairs remain ambiguous")
check(diagnostic["scoreDominanceEvaluated"] is False, "zero-clean ranking not evaluated")

for source in ([], [dirty_high]):
    retained, diagnostic = r34.resolve_unique_both_channel_exterior_clear_pair(source)
    check(retained == source, "empty or single pair unchanged")
    check(diagnostic["state"] == "NOT_APPLIED_SINGLE_OR_EMPTY_PAIR", "bypass state unchanged")

original_r33_main = r34.R33.main
original_resolver = r34.R32.resolve_unique_both_channel_exterior_clear_pair
try:
    r34.R33.main = lambda: 37
    check(r34.main() == 37, "R33 successor main result preserved")
    check(
        r34.R32.resolve_unique_both_channel_exterior_clear_pair
        is r34.resolve_unique_both_channel_exterior_clear_pair,
        "R34 resolver installed into R32 lookup",
    )
finally:
    r34.R33.main = original_r33_main
    r34.R32.resolve_unique_both_channel_exterior_clear_pair = original_resolver

assert tests == 33, tests
print("PASS_R34_PACKAGED_SYNTHETIC_33_OF_33")
