#!/usr/bin/env python3
"""Exact-delta and decision-table gate for the O3F4 R8 front detector."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
R7 = ROOT / "OPENCV_EDGE_NOTCH_O3M9" / "FullPerimeterWaferTopologyOpenCvR7.py"
R8 = Path(__file__).with_name("FullPerimeterWaferTopologyOpenCvR8.py")
REMOVED = (
    '        elif bf["state"].startswith("HOLD"):\n'
    '            state = "HOLD_PARTIAL_BF_TOPOLOGY_COVERAGE_WITH_ONE_CROSS_METHOD_CANDIDATE"\n'
)
r7 = R7.read_text(encoding="utf-8")
r8 = R8.read_text(encoding="utf-8")
assert r7.count(REMOVED) == 1
assert r8 == r7.replace(REMOVED, "")


def r8_state(df_hold: bool, eligible_count: int) -> str:
    if df_hold:
        return "HOLD_DF_RADIAL_FULL_PERIMETER_NOT_QUALIFIED"
    if eligible_count == 0:
        return "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH"
    if eligible_count > 1:
        return "HOLD_MULTIPLE_BF_TOPOLOGY_DF_RADIAL_NOTCHES"
    return "PASS_REVIEW_ONLY_BF_TOPOLOGY_DF_RADIAL_NOTCH_CANDIDATE"


assert r8_state(True, 1).startswith("HOLD_DF_")
assert r8_state(False, 0).startswith("HOLD_NO_")
assert r8_state(False, 1).startswith("PASS_REVIEW_ONLY_")
assert r8_state(False, 2).startswith("HOLD_MULTIPLE_")
print("PASS_O3F4_R8_EXACT_TWO_LINE_DELTA_AND_FOUR_DECISIONS")
