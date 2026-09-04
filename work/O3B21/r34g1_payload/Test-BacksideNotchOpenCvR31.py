#!/usr/bin/env python3
"""Focused R31 BF split-flank plus strict DF topology tests."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path


here = Path(__file__).parent
root = here if (here / "Detect-BacksideNotchOpenCvR31.py").is_file() else (
    Path(__file__).parents[1] / "OPENCV_BACKSIDE_NOTCH_O3B10"
)
path = root / "Detect-BacksideNotchOpenCvR31.py"
spec = importlib.util.spec_from_file_location("r31_test", path)
assert spec is not None and spec.loader is not None
r31 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r31)
r31.R21.R17._PARAMETERS = json.loads(
    (root / "BACKSIDE_NOTCH_CONFIG_R13.json").read_text(encoding="utf-8")
)["radialParameters"]


def context(clear: bool = True) -> dict:
    return {
        "referenceMedianIntensity": 1.0,
        "referenceMadIntensity": 0.0,
        "brightThresholdIntensity": 13.0,
        "wedgeMedianIntensity": 1.0,
        "wedgeP90Intensity": 1.0,
        "brightPixelFraction": 0.0 if clear else 0.2,
        "maximumAngularBrightSupportFraction": 0.0 if clear else 0.5,
    }


def row(angle: float, width: float, depth: float, strict: bool, clear: bool = True) -> dict:
    return {
        "centerAngleDegrees": angle,
        "widthDegrees": width,
        "maximumDepthPx": depth,
        "maximumDepthNativePx": depth,
        "maximumDepthAnalysisPx": depth / 6.0,
        "symmetryScore": 0.82 if strict else 0.0,
        "tipCenterOffsetFraction": 0.1 if strict else 1.0,
        "slopeConsistencyFraction": 1.0,
        "manufacturedMorphologyPassed": strict,
        "candidateSource": "NATIVE_CHANNEL_LOCAL_HOLDER_EXCLUDED_RADIAL_PROFILE",
        "exteriorContext": context(clear),
    }


def result(candidates: list[dict]) -> dict:
    return {
        "candidates": candidates,
        "holderExclusion": {"spans": []},
        "backsideTraceQualification": {"strictUsable": True, "rawRmsPassed": True},
    }


tests = 0


def check(value: bool, message: str) -> None:
    global tests
    assert value, message
    tests += 1


left = row(88.8269, 0.6, 53.0166, False)
right = row(90.6709, 0.6, 53.0166, False)
anchor = row(89.7520, 2.4, 81.9653, True)
pairs, diagnostic = r31.pair_split_flanks(result([left, right]), result([anchor]))
check(len(pairs) == 1, "observed split-flank topology produces one pair")
check(pairs[0]["confirmationMode"] == r31.CONFIRMATION_MODE, "new mode recorded")
check(abs(pairs[0]["bfAngleDegrees"] - 89.7489) < 0.01, "combined BF center")
check(diagnostic["state"] == "PASS_UNIQUE_BF_SPLIT_FLANK_DF_STRICT_PAIR", "pass state")
check(diagnostic["pairComparisons"][0]["angularBalanceFraction"] > 0.99, "angular balance")
check(diagnostic["pairComparisons"][0]["depthBalanceFraction"] == 1.0, "depth balance")

for altered, message in (
    ([row(88.8269, 0.4, 53.0, False), right], "too-narrow flank"),
    ([row(88.0, 0.6, 53.0, False), right], "flank outside angle gate"),
    ([row(89.3, 0.6, 53.0, False), right], "insufficient separation"),
    ([row(88.8269, 0.6, 20.0, False), right], "insufficient depth"),
    ([row(88.8269, 0.6, 53.0, False, False), right], "exterior contamination"),
):
    candidate_pairs, _ = r31.pair_split_flanks(result(altered), result([anchor]))
    check(candidate_pairs == [], message)

candidate_pairs, _ = r31.pair_split_flanks(result([left, right]), result([row(89.752, 2.4, 82.0, False)]))
check(candidate_pairs == [], "DF must be strict")
candidate_pairs, _ = r31.pair_split_flanks(result([left, right]), result([row(89.752, 2.4, 82.0, True, False)]))
check(candidate_pairs == [], "DF must be exterior clear")
candidate_pairs, _ = r31.pair_split_flanks(
    result([left, right, row(180.0, 0.6, 40.0, False)]), result([anchor])
)
check(candidate_pairs == [], "exactly two eligible BF flanks required")
candidate_pairs, _ = r31.pair_split_flanks(
    result([left, right]), result([anchor, row(180.0, 2.4, 80.0, True)])
)
check(candidate_pairs == [], "exactly one eligible strict DF candidate required")
bf_bad_trace = result([left, right])
bf_bad_trace["backsideTraceQualification"]["strictUsable"] = False
candidate_pairs, _ = r31.pair_split_flanks(bf_bad_trace, result([anchor]))
check(candidate_pairs == [], "both channel traces must be strict usable")
wrong_source = row(88.8269, 0.6, 53.0, False)
wrong_source["candidateSource"] = "OTHER"
candidate_pairs, _ = r31.pair_split_flanks(result([wrong_source, right]), result([anchor]))
check(candidate_pairs == [], "BF flanks must come from native holder-excluded profile")

original = r31.R30.pair_candidates
try:
    existing = {"confirmationMode": "STRICT_BOTH_CHANNELS"}
    r31.R30.pair_candidates = lambda bf, df: [existing]
    bf = result([left, right])
    check(r31.pair_candidates(bf, result([anchor])) == [existing], "R30 pair unchanged")
    check(bf["bfSplitFlankDfStrictCompensation"]["state"] == "NOT_USED_EXISTING_R30_PAIR",
          "R30 bypass recorded")
finally:
    r31.R30.pair_candidates = original

check(r31.signed_delta(359.5, 0.5) == -1.0, "circular signed delta")
check(r31.circular_midpoint(359.0, 1.0) == 0.0, "circular midpoint")

assert tests == 21, tests
print("PASS_R31_PACKAGED_SYNTHETIC_21_OF_21")
