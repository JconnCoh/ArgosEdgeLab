#!/usr/bin/env python3
"""Exact packaged R28 branch-isolation and frozen-gate tests."""

from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR28.py")
spec = importlib.util.spec_from_file_location("r28_packaged_test", path)
require(spec is not None and spec.loader is not None, "R28 import spec absent")
r28 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r28)
r28.R21.R17._PARAMETERS = json.loads(
    Path(__file__).with_name("BACKSIDE_NOTCH_CONFIG_R13.json").read_text(encoding="utf-8")
)["radialParameters"]


def candidate(angle: float, manufactured: bool = True) -> dict:
    return {
        "centerAngleDegrees": angle, "widthDegrees": 2.0,
        "maximumDepthNativePx": 40.0, "maximumDepthPx": 8.0,
        "maximumDepthAnalysisPx": 8.0, "manufacturedMorphologyPassed": manufactured,
        "exteriorContext": {"brightPixelFraction": 0.0,
                            "maximumAngularBrightSupportFraction": 0.0},
    }


def df(angle: float, holder=False) -> dict:
    row = candidate(angle)
    row.update({"holderMasked": holder, "symmetryScore": 0.9,
                "tipCenterOffsetFraction": 0.1, "slopeConsistencyFraction": 1.0})
    return row


tests = 0


def check(condition: bool, message: str) -> None:
    global tests
    require(condition, message)
    tests += 1


rows, diag = r28.pair_frozen_cross_channel_evidence(
    [candidate(69.3)], [df(69.017), df(72.196), df(89.957)])
check(len(rows) == 1, "O23 two nearby proposals must collapse to one")
check(diag["preClusterPairCount"] == 2, "O23 precluster cardinality")
check(diag["proposedPairCount"] == 1, "O23 clustered cardinality")
check(diag["eligibleBfCandidateCount"] == 1, "O23 BF eligibility")
check(diag["dfShallowQualifiedCandidateCount"] == 3, "DF diagnostic cardinality")
check(diag["dfShallowHolderClearCandidateCount"] == 3, "DF clear cardinality")
check(rows[0]["confirmationMode"] == r28.CONFIRMATION_MODE, "new mode exact")
check(abs(rows[0]["bfAngleDegrees"] - 69.3) < 1e-9, "BF angle preserved")

rows, diag = r28.pair_frozen_cross_channel_evidence(
    [candidate(10.0)], [df(10.1, True), df(10.2)])
check(len(rows) == 1, "holder-clear candidate retained")
check(diag["dfShallowHolderClearCandidateCount"] == 1, "holder row excluded")
rows, diag = r28.pair_frozen_cross_channel_evidence([candidate(10.0)], [{
    **df(10.1), "holderMasked": None
}])
check(len(rows) == 0, "missing/None holder proof must fail closed")
rows, diag = r28.pair_frozen_cross_channel_evidence([candidate(10.0, False)], [df(10.0)])
check(len(rows) == 0, "non-manufactured BF excluded")

gate = float(r28.R21.R17._PARAMETERS["pairedShallowMaximumAngleDifferenceDegrees"])
rows, _ = r28.pair_frozen_cross_channel_evidence([candidate(10.0)], [df(10.0 + gate)])
check(len(rows) == 1, "frozen inclusive angle boundary")
rows, _ = r28.pair_frozen_cross_channel_evidence([candidate(10.0)], [df(10.0 + gate + 0.001)])
check(len(rows) == 0, "outside frozen angle boundary")
rows, _ = r28.pair_frozen_cross_channel_evidence([candidate(359.0)], [df(1.0)])
check(len(rows) == 1, "circular wraparound")
rows, _ = r28.pair_frozen_cross_channel_evidence([candidate(20.0), candidate(80.0)], [df(20.0), df(80.0)])
check(len(rows) == 2, "separated ambiguity retained for fail-closed caller")

original = r28.R26.ORIGINAL_R25_PAIR
original_full = r28.R26.df_geometry_bf_candidates
try:
    r28.R26.ORIGINAL_R25_PAIR = lambda bf, df_value: [{"existing": True}]
    bf_value = {}
    check(r28.pair_candidates(bf_value, {}) == [{"existing": True}], "existing pair passthrough")
    check(bf_value["dfGeometryBfFullPerimeterCompensation"]["state"].startswith("NOT_USED"), "existing bypass state")

    r28.R26.ORIGINAL_R25_PAIR = lambda bf, df_value: []
    bf_value = {"backsideTraceQualification": {"strictUsable": False,
                                               "bfLowFrequencyShapeSuppressed": True}}
    df_value = {"backsideTraceQualification": {"strictUsable": True, "rawRmsPassed": True}}
    check(r28.pair_candidates(bf_value, df_value) == [], "trace precondition fail closed")
    check(bf_value["dfGeometryBfFullPerimeterCompensation"]["state"].startswith("NOT_USED"), "trace bypass state")

    bf_template = {"backsideTraceQualification": {"strictUsable": True,
                                                   "bfLowFrequencyShapeSuppressed": True},
                   "dfStrongAnchorAppearanceDiagnostics": {"dfShallow": {
                       "qualifiedCandidates": [df(69.017), df(72.196), df(89.957)]}}}
    df_value = {"backsideTraceQualification": {"strictUsable": True, "rawRmsPassed": True}}
    r28.R26.df_geometry_bf_candidates = lambda bf, df_value: ([candidate(69.3)], {
        "profileThresholdAnalysisPx": 1.0})
    bf_value = copy.deepcopy(bf_template)
    paired = r28.pair_candidates(bf_value, copy.deepcopy(df_value))
    check(len(paired) == 1, "full O23 branch produces one pair")
    comp = bf_value["dfGeometryBfFullPerimeterCompensation"]
    check(comp["state"] == "PASS_UNIQUE_DF_GEOMETRY_BF_MANUFACTURED_DF_SHALLOW_PAIR", "pass state exact")
    check(comp["preClusterPairCount"] == 2 and comp["proposedPairCount"] == 1, "branch counts exact")
    check(bf_value["candidateCount"] == 1, "BF candidate replacement exact")
    check("DF_SHALLOW_APPEARANCE" in bf_value["patternSuppression"], "pattern suppression provenance")

    r28.R26.df_geometry_bf_candidates = lambda bf, df_value: ([candidate(10.0), candidate(80.0)], {
        "profileThresholdAnalysisPx": 1.0})
    ambiguous = copy.deepcopy(bf_template)
    ambiguous["dfStrongAnchorAppearanceDiagnostics"]["dfShallow"]["qualifiedCandidates"] = [df(10.0), df(80.0)]
    check(r28.pair_candidates(ambiguous, copy.deepcopy(df_value)) == [], "ambiguous branch fail closed")
    check(ambiguous["dfGeometryBfFullPerimeterCompensation"]["state"].startswith("HOLD_"), "ambiguity hold state")
finally:
    r28.R26.ORIGINAL_R25_PAIR = original
    r28.R26.df_geometry_bf_candidates = original_full

for angle in (0.0, 45.0, 90.0, 180.0, 270.0, 359.9):
    rows, _ = r28.pair_frozen_cross_channel_evidence([candidate(angle)], [df(angle)])
    check(len(rows) == 1, f"identity angle {angle}")

require(tests == 33, f"unexpected test count {tests}")
print("PASS_R28_PACKAGED_SYNTHETIC_33_OF_33")
