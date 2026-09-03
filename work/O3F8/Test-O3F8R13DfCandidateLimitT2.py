#!/usr/bin/env python3
"""Focused image-free regression for R13 in source-tree or flat-package layout."""
from __future__ import annotations
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys

R13_PATH = Path(__file__).resolve().with_name("FullPerimeterWaferTopologyOpenCvR13.py")
LOCAL_ROOT = R13_PATH.parent
if (LOCAL_ROOT / "NativeFrontsideWaferPoseOpenCvV2R6.py").is_file():
    R6_ROOT = TOPOLOGY_ROOT = O3P8_ROOT = LOCAL_ROOT
    DEPENDENCY_LAYOUT = "FLAT_PACKAGE"
else:
    WORK_ROOT = LOCAL_ROOT.parent
    R6_ROOT = TOPOLOGY_ROOT = WORK_ROOT / "OPENCV_EDGE_NOTCH_O3M9"
    O3P8_ROOT = WORK_ROOT / "OPENCV_EDGE_NOTCH_O3P8"
    DEPENDENCY_LAYOUT = "SOURCE_TREE"
os.environ["ARGOS_O3M1_R6_ROOT"] = str(R6_ROOT)
os.environ["ARGOS_O3M1_TOPOLOGY_ROOT"] = str(TOPOLOGY_ROOT)
os.environ["ARGOS_O3P8_ROOT"] = str(O3P8_ROOT)

spec = importlib.util.spec_from_file_location("argos_o3f8_full_perimeter_r13_t2_test", R13_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load R13: {R13_PATH}")
R13 = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = R13
spec.loader.exec_module(R13)

def need(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)

def candidate(index: int) -> dict[str, float | int]:
    center = float(index) * 5.0
    return {
        "centerAngleDegrees": center,
        "startAngleDegrees": center - 0.5,
        "endAngleDegrees": center + 0.5,
        "widthDegrees": 1.0,
        "maximumDepthPx": 24.0 + float(index),
        "medianDepthPx": 16.0,
        "sampleCount": 10,
        "symmetryScore": 0.9,
        "tipCenterOffsetFraction": 0.1,
        "slopeConsistencyFraction": 0.9,
    }

def base(count: int) -> dict[str, object]:
    return {
        "channel": "DF",
        "qualified": True,
        "fit": {"centerX": 1.0, "centerY": 2.0, "radius": 3.0},
        "search": {"mode": "TEST_NO_IMAGE"},
        "candidateDepthThresholdPx": 6.0,
        "baselineNoiseSigmaPx": 1.0,
        "candidates": [candidate(index) for index in range(count)],
    }

cfg = {"maximumChannelCandidateCount": 24}
old_rejected_32 = False
try:
    R13.R11_RADIAL_CHANNEL_FROM_BASE("OLD_LIMIT_CONTROL", base(32), cfg)
except ValueError as exc:
    old_rejected_32 = "DF radial candidate cap exceeded" in str(exc)
need(old_rejected_32, "Frozen R11 no longer reproduces the 32-candidate failure.")

rows: list[dict[str, object]] = []
for count in (0, 24, 32, 34, 64):
    value = R13.radial_channel_from_base(f"DF_{count:02d}", base(count), cfg)
    need(value["state"] == "PASS_R6_RADIAL_FULL_PERIMETER_SCANNED", f"DF {count} did not remain qualified.")
    need(value["candidateCount"] == count and len(value["candidates"]) == count, f"DF {count} candidates changed.")
    need(
        [item["axisCenterAngleDegrees"] for item in value["candidates"]] == [float(index) * 5.0 for index in range(count)],
        f"DF {count} candidate ordering changed.",
    )
    need(value["candidateResourceLimit"] == 64, "R13 DF resource ceiling changed.")
    rows.append({"candidateCount": count, "preserved": True})

rejected_65 = False
try:
    R13.radial_channel_from_base("DF_65", base(65), cfg)
except ValueError as exc:
    rejected_65 = "DF radial candidate cap exceeded" in str(exc)
need(rejected_65, "R13 did not fail closed above the frozen 64-seed ceiling.")
need(cfg == {"maximumChannelCandidateCount": 24}, "R13 mutated the caller's BF topology configuration.")
need(R13.R11.scan_channel.__module__ == R13.R11.__name__, "R13 replaced the BF topology scan.")

result = {
    "schema": "argos_ocv03_o3f8_r13_df_candidate_limit_test_t2_v1",
    "state": "PASS_O3F8_R13_DF_CANDIDATE_LIMIT_T2",
    "dependencyLayout": DEPENDENCY_LAYOUT,
    "r13Sha256": hashlib.sha256(Path(R13.__file__).read_bytes()).hexdigest().upper(),
    "r11Sha256": R13.R11_SOURCE_SHA256,
    "bfTopologyCandidateLimit": cfg["maximumChannelCandidateCount"],
    "dfRadialCandidateLimit": R13.DF_RADIAL_CANDIDATE_LIMIT,
    "oldR11Rejected32": old_rejected_32,
    "acceptedCounts": rows,
    "rejected65": rejected_65,
    "candidateGenerationChanged": False,
    "candidateOrderingChanged": False,
    "selectorOrThresholdChanged": False,
    "imageBytesRead": False,
    "reviewOnly": True,
    "productionRoutingEnabled": False,
}
print(json.dumps(result, separators=(",", ":")))
