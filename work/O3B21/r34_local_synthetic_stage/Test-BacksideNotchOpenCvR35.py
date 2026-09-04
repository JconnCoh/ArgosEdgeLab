#!/usr/bin/env python3
"""Focused R35 nearby-competing-geometry tests."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path


root = Path(__file__).parent
path = root / "Detect-BacksideNotchOpenCvR35.py"
spec = importlib.util.spec_from_file_location("r35_test", path)
assert spec is not None and spec.loader is not None
r35 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r35)
r35.R34.R32.R21.R17._PARAMETERS = json.loads(
    (root / "BACKSIDE_NOTCH_CONFIG_R13.json").read_text(encoding="utf-8")
)["radialParameters"]


def context(clear: bool) -> dict:
    return {
        "brightPixelFraction": 0.0 if clear else 0.20,
        "maximumAngularBrightSupportFraction": 0.0 if clear else 0.50,
    }


def pair(angle: float, score, clear: bool) -> dict:
    row = {
        "meanAngleDegrees": angle,
        "confirmationMode": "STRICT_BOTH_CHANNELS",
        "bfExteriorContext": context(clear),
        "dfExteriorContext": context(clear),
    }
    if score is not None:
        row["score"] = score
    return row


tests = 0


def check(value: bool, message: str) -> None:
    global tests
    assert value, message
    tests += 1


o005_dirty, o005_clean = pair(223.9127, 154.2, False), pair(179.7062, 74.2, True)
retained, diagnostic = r35.resolve_unique_both_channel_exterior_clear_pair(
    [o005_dirty, o005_clean]
)
check(retained == [o005_dirty, o005_clean], "near O005 competitor remains held")
check(diagnostic["state"] == r35.R34.SCORE_DOMINANCE_HOLD_STATE, "O005 hold state")
check(diagnostic["dominatingDirtyCompetitorIsNearby"] is True, "O005 proximity recorded")

collateral_measurements = (
    (224.0945, 154.6843, 89.8413, 71.7042),
    (0.3310, 119.6463, 180.1322, 75.7867),
    (0.3597, 106.2808, 180.0736, 75.3026),
    (0.3781, 111.8539, 180.1255, 75.7843),
    (0.4232, 120.2840, 180.0637, 75.2209),
    (0.4947, 80.7543, 89.9269, 73.4223),
    (0.2714, 73.4541, 88.8370, 26.1830),
    (0.3401, 87.3321, 89.6818, 71.8914),
)
for dirty_angle, dirty_score, clean_angle, clean_score in collateral_measurements:
    dirty, clean = pair(dirty_angle, dirty_score, False), pair(clean_angle, clean_score, True)
    retained, diagnostic = r35.resolve_unique_both_channel_exterior_clear_pair([dirty, clean])
    check(retained == [clean], f"distant holder at {dirty_angle} rejected")
    check(diagnostic["state"] == r35.R34.R32_PASS_STATE, "R32 compatible pass restored")
    check(diagnostic["distantExteriorDirtyCandidatesRejected"] is True, "rejection recorded")
    check(diagnostic["minimumDominatingDirtySeparationDegrees"] > 60.0, "distance recorded")

residue_clean, residue_extra = pair(89.6383, 74.0, True), pair(134.3371, 47.2, False)
retained, diagnostic = r35.resolve_unique_both_channel_exterior_clear_pair(
    [residue_clean, residue_extra]
)
check(retained == [residue_clean], "score-dominant residue notch remains aligned")
check(diagnostic["state"] == r35.R34.R32_PASS_STATE, "residue alignment pass state")
check(diagnostic["nearbyCompetitorEvaluated"] is False, "R34 score pass bypasses R35")

for separation, should_hold in ((60.0, True), (60.0001, False)):
    retained, diagnostic = r35.resolve_unique_both_channel_exterior_clear_pair(
        [pair(separation, 100.0, False), pair(0.0, 50.0, True)]
    )
    check((len(retained) == 2) is should_hold, f"boundary {separation}")

retained, diagnostic = r35.resolve_unique_both_channel_exterior_clear_pair(
    [pair(330.0, 100.0, False), pair(10.0, 50.0, True)]
)
check(len(retained) == 2, "wraparound 40-degree competitor remains held")
check(diagnostic["minimumDominatingDirtySeparationDegrees"] == 40.0, "wrap distance")

for shift, expected_count in ((137.0, 2), (271.0, 1)):
    source = [o005_dirty, o005_clean] if expected_count == 2 else [
        pair(0.2714, 73.5, False), pair(88.8370, 26.2, True)
    ]
    rotated = [dict(value, meanAngleDegrees=(value["meanAngleDegrees"] + shift) % 360.0)
               for value in source]
    retained, diagnostic = r35.resolve_unique_both_channel_exterior_clear_pair(rotated)
    check(len(retained) == expected_count, "rotation does not change disposition")
    check(diagnostic["nearbyCompetitorEvaluated"] is True, "rotation comparison evaluated")

retained, diagnostic = r35.resolve_unique_both_channel_exterior_clear_pair(
    [pair(180.0, None, False), clean]
)
check(len(retained) == 2, "missing score remains fail-closed")
check(diagnostic["nearbyCompetitorEvaluated"] is False, "invalid score not relaxed")

second_clean = pair(180.0, 120.0, True)
retained, diagnostic = r35.resolve_unique_both_channel_exterior_clear_pair([clean, second_clean])
check(len(retained) == 2, "two exterior-clean pairs remain ambiguous")

original_main = r35.R34.main
try:
    r35.R34.main = lambda: 35
    check(r35.main() == 35, "R34 successor main result preserved")
    check(r35.R34.resolve_unique_both_channel_exterior_clear_pair is
          r35.resolve_unique_both_channel_exterior_clear_pair, "R35 resolver installed")
finally:
    r35.R34.main = original_main

assert tests == 51, tests
print("PASS_R35_PACKAGED_SYNTHETIC_51_OF_51")
