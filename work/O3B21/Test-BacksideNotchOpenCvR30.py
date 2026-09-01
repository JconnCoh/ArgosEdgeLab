#!/usr/bin/env python3
"""Focused R30 legacy-soft exterior negative-control tests."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path


here = Path(__file__).parent
root = here if (here / "Detect-BacksideNotchOpenCvR30.py").is_file() else (
    Path(__file__).parents[1] / "OPENCV_BACKSIDE_NOTCH_O3B10"
)
path = root / "Detect-BacksideNotchOpenCvR30.py"
spec = importlib.util.spec_from_file_location("r30_test", path)
assert spec is not None and spec.loader is not None
r30 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r30)
r30.R21.R17._PARAMETERS = json.loads(
    (root / "BACKSIDE_NOTCH_CONFIG_R13.json").read_text(encoding="utf-8")
)["radialParameters"]


def context(clear: bool) -> dict:
    return {
        "brightPixelFraction": 0.0 if clear else 0.20,
        "maximumAngularBrightSupportFraction": 0.0 if clear else 0.50,
    }


def pair(mode: str, bf_clear: bool, df_clear: bool, angle: float = 90.0) -> dict:
    return {
        "confirmationMode": mode,
        "meanAngleDegrees": angle,
        "score": 10.0,
        "bfExteriorContext": context(bf_clear),
        "dfExteriorContext": context(df_clear),
    }


tests = 0


def check(value: bool, message: str) -> None:
    global tests
    assert value, message
    tests += 1


bad = pair("STRICT_DF_CONFIRMED_BY_BF", False, False, 133.8785)
rows, diag = r30.reject_doubly_contaminated_soft_pairs([bad])
check(rows == [], "observed doubly contaminated soft pair removed")
check(diag["state"] == "APPLIED_DOUBLY_CONTAMINATED_LEGACY_SOFT_PAIR_REMOVED", "removal state")
check(diag["rows"][0]["legacySoftExteriorGateApplies"], "legacy mode gate applies")

for bf_clear, df_clear in ((True, True), (True, False), (False, True)):
    rows, _ = r30.reject_doubly_contaminated_soft_pairs([
        pair("STRICT_DF_CONFIRMED_BY_BF", bf_clear, df_clear)
    ])
    check(len(rows) == 1, f"one exterior-clear channel retains pair {bf_clear}/{df_clear}")

for mode in ("STRICT_BOTH_CHANNELS", r30.R29.CONFIRMATION_MODE,
             "DF_STRONG_MORPHOLOGY_ANCHORED_BF_SHALLOW_IMAGE_APPEARANCE"):
    rows, _ = r30.reject_doubly_contaminated_soft_pairs([pair(mode, False, False)])
    check(len(rows) == 1, f"non-target mode unchanged: {mode}")

good = pair("STRICT_BOTH_CHANNELS", True, True, 90.2)
rows, diag = r30.reject_doubly_contaminated_soft_pairs([good, bad])
check(rows == [good], "true clean pair retained while fixture-like pair removed")
check(diag["inputPairCount"] == 2 and diag["retainedPairCount"] == 1, "two-to-one cardinality")

original = r30.R29.pair_candidates
try:
    r30.R29.pair_candidates = lambda bf, df: [good, bad]
    bf = {}
    check(r30.pair_candidates(bf, {}) == [good], "wrapper returns unique clean pair")
    check(bf["legacySoftPairExteriorNegativeControl"]["retainedPairCount"] == 1,
          "wrapper records diagnostic")
finally:
    r30.R29.pair_candidates = original

assert tests == 13, tests
print("PASS_R30_PACKAGED_SYNTHETIC_13_OF_13")
