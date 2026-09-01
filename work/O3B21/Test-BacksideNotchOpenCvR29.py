#!/usr/bin/env python3
"""R29 branch tests; R28's frozen 33 tests run separately."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path


here = Path(__file__).parent
root = here if (here / "Detect-BacksideNotchOpenCvR29.py").is_file() else (
    Path(__file__).parents[1] / "OPENCV_BACKSIDE_NOTCH_O3B10"
)
path = root / "Detect-BacksideNotchOpenCvR29.py"
spec = importlib.util.spec_from_file_location("r29_test", path)
assert spec is not None and spec.loader is not None
r29 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r29)
r29.R21.R17._PARAMETERS = json.loads(
    (root / "BACKSIDE_NOTCH_CONFIG_R13.json").read_text(encoding="utf-8")
)["radialParameters"]


def row(angle: float, width: float, symmetry: float, *, holder=False, bright=0.0) -> dict:
    return {
        "centerAngleDegrees": angle,
        "widthDegrees": width,
        "maximumDepthNativePx": 70.0,
        "maximumDepthPx": 14.0,
        "maximumDepthAnalysisPx": 14.0,
        "symmetryScore": symmetry,
        "tipCenterOffsetFraction": 0.25 if width < 4.0 else 0.01,
        "slopeConsistencyFraction": 1.0 if width < 4.0 else 0.95,
        "manufacturedMorphologyPassed": False,
        "exteriorContext": {
            "brightPixelFraction": bright,
            "maximumAngularBrightSupportFraction": 0.0,
        },
        "holder": holder,
    }


def result(rows: list[dict]) -> dict:
    spans = [{"startAngleDegrees": 175.0, "widthDegrees": 10.0}] if any(r.pop("holder") for r in rows) else []
    return {"candidates": rows, "holderExclusion": {"spans": spans}}


tests = 0


def check(value: bool, message: str) -> None:
    global tests
    assert value, message
    tests += 1


bf = result([row(179.5853900434719, 2.5, 0.710185945150426)])
df = result([row(179.5474757494876, 16.4, 0.9555497050729952)])
pairs, diag = r29.pair_near_strict_broad(bf, df)
check(len(pairs) == 1, "observed Slot20 morphology must pair")
check(diag["eligibleBfCandidateCount"] == 1 and diag["eligibleDfCandidateCount"] == 1,
      "both observed candidates eligible")
check(pairs[0]["confirmationMode"] == r29.CONFIRMATION_MODE, "mode exact")

bf90 = result([row(89.5853900434719, 2.5, 0.710185945150426)])
df90 = result([row(89.5474757494876, 16.4, 0.9555497050729952)])
check(len(r29.pair_near_strict_broad(bf90, df90)[0]) == 1, "rotation invariant")
check(len(r29.pair_near_strict_broad(
    result([row(179.58, 2.5, 0.64)]), result([row(179.55, 16.4, 0.96)]))[0]) == 0,
    "BF below frozen confirmation symmetry excluded")
check(len(r29.pair_near_strict_broad(
    result([row(179.58, 2.5, 0.71)]), result([row(179.55, 18.1, 0.96)]))[0]) == 0,
    "DF beyond frozen broad width excluded")
check(len(r29.pair_near_strict_broad(
    result([row(179.58, 2.5, 0.71, holder=True)]), result([row(179.55, 16.4, 0.96)]))[0]) == 0,
    "BF holder span excluded")
check(len(r29.pair_near_strict_broad(
    result([row(179.58, 2.5, 0.71)]), result([row(179.55, 16.4, 0.96, holder=True)]))[0]) == 0,
    "DF holder span excluded")
check(len(r29.pair_near_strict_broad(
    result([row(179.58, 2.5, 0.71)]), result([row(179.55, 16.4, 0.96, bright=0.02)]))[0]) == 0,
    "DF exterior contamination excluded")
check(len(r29.pair_near_strict_broad(
    result([row(179.58, 2.5, 0.71)]), result([row(182.0, 16.4, 0.96)]))[0]) == 0,
    "cross-channel mismatch excluded")
check(len(r29.pair_near_strict_broad(
    result([row(20.0, 2.5, 0.71), row(80.0, 2.5, 0.71)]),
    result([row(20.0, 16.4, 0.96), row(80.0, 16.4, 0.96)]))[0]) == 2,
    "separated ambiguity retained for fail-closed caller")

original = r29.R28.pair_candidates
try:
    r29.R28.pair_candidates = lambda bf_value, df_value: [{"existing": True}]
    bf_value = {}
    check(r29.pair_candidates(bf_value, {}) == [{"existing": True}], "R28 passthrough")
    check(bf_value["bfNearStrictDfBroadCompensation"]["state"] == "NOT_USED_EXISTING_R28_PAIR",
          "passthrough diagnostic")
finally:
    r29.R28.pair_candidates = original

assert tests == 13, tests
print("PASS_R29_PACKAGED_SYNTHETIC_13_OF_13")
