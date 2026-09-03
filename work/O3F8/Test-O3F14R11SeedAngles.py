#!/usr/bin/env python3
"""Focused regression for R11 DF seed mouth-angle propagation."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import inspect
import json
import os
from pathlib import Path
import sys
from typing import Any

import numpy as np


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
R10_PATH = HERE / "FullPerimeterWaferTopologyOpenCvR10.py"
R11_PATH = HERE / "FullPerimeterWaferTopologyOpenCvR11.py"
M9_ROOT = Path(os.environ.get("ARGOS_O3F8_DEPENDENCY_ROOT", str(ROOT / "work" / "OPENCV_EDGE_NOTCH_O3M9")))
O3P8_ROOT = Path(os.environ.get("ARGOS_O3P8_ROOT", str(ROOT / "work" / "OPENCV_EDGE_NOTCH_O3P8")))
R10_SHA256 = "0EEEE7A396E918AF44082EC0930871A6A94C1FBB59D3F5CEF1AC34D1273745FA"
R11_SHA256 = "B477C290EC9D3AE388BE4EE31049B2B8094F5F30FC6E0DD68AB4A03926EE4059"


def need(value: Any, message: str) -> None:
    if not value:
        raise RuntimeError(message)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    need(spec is not None and spec.loader is not None, f"Cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def bf_candidate(center: float, start: float, end: float) -> dict[str, Any]:
    return {
        "axisCenterAngleDegrees": center,
        "startAngleDegrees": start,
        "endAngleDegrees": end,
        "widthDegrees": (end - start) % 360.0,
        "symmetryScore": 1.0,
        "tipCenterOffsetFraction": 0.0,
        "slopeConsistencyFraction": 1.0,
        "observedContourFraction": 1.0,
        "peakDepthPx": 60.0,
    }


def df_candidate(center: float, start: float, end: float) -> dict[str, Any]:
    return {
        "axisCenterAngleDegrees": center,
        "centerAngleDegrees": center,
        "startAngleDegrees": start,
        "endAngleDegrees": end,
        "widthDegrees": (end - start) % 360.0,
        "maximumDepthPx": 60.0,
        "peakDepthPx": 60.0,
        "medianDepthPx": 40.0,
        "sampleCount": 20,
        "symmetryScore": 1.0,
        "tipCenterOffsetFraction": 0.0,
        "slopeConsistencyFraction": 1.0,
        "radialBoundaryQualified": True,
        "supportedColumnFraction": 1.0,
        "longestUnsupportedGapPx": 0,
    }


def physical_pair(bf: dict[str, Any], df: dict[str, Any], df_index: int = 0) -> dict[str, Any]:
    return {
        "bfCandidateIndex": 0,
        "dfCandidateIndex": df_index,
        "bf": bf,
        "df": df,
        "manufacturedNotchMorphologyEligible": True,
    }


def run_recovery(
    r11: Any,
    candidates: list[dict[str, Any]],
    physical: list[dict[str, Any]],
    df_only_indices: list[int],
    topology_passed: bool = True,
) -> dict[str, Any]:
    prior = r11.O3P8.refine_bf

    def refine_bf(
        unused_image: np.ndarray,
        unused_fit: dict[str, Any],
        seed: dict[str, Any],
        unused_topology: Any,
        unused_renderer: Any,
        unused_job: dict[str, Any],
    ) -> dict[str, Any]:
        df = seed["dfCandidate"]
        return {
            "topologyPassed": topology_passed,
            "feature": {
                "tipAngleDegrees": float(df["centerAngleDegrees"]),
                "leftAngleDegrees": float(df["startAngleDegrees"]),
                "rightAngleDegrees": float(df["endAngleDegrees"]),
                "pairedShoulderProminencePx": 30.0,
                "meanSupport": 1.0,
                "tipSupport": 1.0,
            },
        }

    r11.O3P8.refine_bf = refine_bf
    try:
        return r11.o3p8_df_seeded_local_bf_recovery(
            np.zeros((8, 8), dtype=np.uint8),
            {"centerX": 4.0, "centerY": 4.0, "radius": 3.0},
            {
                "state": "PASS_R6_RADIAL_FULL_PERIMETER_SCANNED",
                "candidates": candidates,
            },
            physical,
            df_only_indices,
            {"widthPx": 8, "inwardPx": 4, "outwardPx": 4},
            {},
        )
    finally:
        r11.O3P8.refine_bf = prior


def seed_projection(result: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        {
            "seedClass": str(row["seedClass"]),
            "startAngleDegrees": float(row["dfRadial"]["startAngleDegrees"]),
            "endAngleDegrees": float(row["dfRadial"]["endAngleDegrees"]),
            "eligible": bool(row["eligible"]),
        }
        for row in result["seeds"]
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output")
    args = parser.parse_args()

    os.environ["ARGOS_O3M1_R6_ROOT"] = str(M9_ROOT)
    os.environ["ARGOS_O3M1_TOPOLOGY_ROOT"] = str(M9_ROOT)
    os.environ["ARGOS_O3P8_ROOT"] = str(O3P8_ROOT)
    need(digest(R10_PATH) == R10_SHA256, "R10 predecessor pin changed")
    need(digest(R11_PATH) == R11_SHA256, "R11 detector pin changed")
    r10 = load("argos_o3f14_r10_predecessor", R10_PATH)
    r11 = load("argos_o3f14_r11_regression", R11_PATH)

    inheritance = {
        "corroborationThresholdsUnchanged": r11.O3P8_CORROBORATION == r10.O3P8_CORROBORATION,
        "correspondenceFunctionUnchanged": inspect.getsource(r11.correspondence_diagnostics)
        == inspect.getsource(r10.correspondence_diagnostics),
        "selectionFunctionUnchanged": inspect.getsource(r11.r10_symmetric_selection)
        == inspect.getsource(r10.r10_symmetric_selection),
        "r10Sha256": digest(R10_PATH),
        "r11Sha256": digest(R11_PATH),
    }

    physical_bf = bf_candidate(40.0, 38.75, 41.25)
    physical_df = df_candidate(40.2, 39.125, 41.375)
    physical_unique = run_recovery(r11, [physical_df], [physical_pair(physical_bf, physical_df)], [])
    physical_projection = seed_projection(physical_unique)

    df_only = df_candidate(140.4, 139.25, 141.75)
    df_only_unique = run_recovery(r11, [df_only], [], [0])
    df_only_projection = seed_projection(df_only_unique)

    ambiguous = run_recovery(
        r11,
        [physical_df, df_only],
        [physical_pair(physical_bf, physical_df)],
        [1],
    )
    ambiguous_projection = seed_projection(ambiguous)
    rejected = run_recovery(r11, [df_only], [], [0], topology_passed=False)

    angle_paths = {
        "physicalSeedClassExact": [row["seedClass"] for row in physical_projection] == ["R6_BF_DF_PHYSICAL"],
        "physicalAnglesExact": physical_projection[0]["startAngleDegrees"] == 39.125
        and physical_projection[0]["endAngleDegrees"] == 41.375,
        "dfOnlySeedClassExact": [row["seedClass"] for row in df_only_projection] == ["R6_DF_ONLY"],
        "dfOnlyAnglesExact": df_only_projection[0]["startAngleDegrees"] == 139.25
        and df_only_projection[0]["endAngleDegrees"] == 141.75,
        "bothPathsExecuteWithoutLegacyKeyError": physical_unique["seedCount"] == 1
        and df_only_unique["seedCount"] == 1,
    }
    decision_semantics = {
        "physicalUniquePositivePasses": physical_unique["state"]
        == "PASS_REVIEW_ONLY_UNIQUE_BF_TOPOLOGY_DF_RADIAL_NOTCH"
        and physical_unique["eligibleSeedIndices"] == [0]
        and physical_unique["selected"] is not None,
        "dfOnlyUniquePositivePasses": df_only_unique["state"]
        == "PASS_REVIEW_ONLY_UNIQUE_BF_TOPOLOGY_DF_RADIAL_NOTCH"
        and df_only_unique["eligibleSeedIndices"] == [0]
        and df_only_unique["selected"] is not None,
        "twoDistinctEligibleSeedsRemainAmbiguous": ambiguous["state"]
        == "HOLD_MULTIPLE_BF_TOPOLOGY_DF_RADIAL_NOTCHES"
        and ambiguous["eligibleSeedIndices"] == [0, 1]
        and ambiguous["selected"] is None,
        "ambiguousClassesPreserved": [row["seedClass"] for row in ambiguous_projection]
        == ["R6_BF_DF_PHYSICAL", "R6_DF_ONLY"],
        "ineligibleSeedRemainsNegative": rejected["state"] == "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH"
        and rejected["eligibleSeedIndices"] == []
        and rejected["selected"] is None,
    }

    passed = (
        all(value for key, value in inheritance.items() if not key.endswith("Sha256"))
        and all(angle_paths.values())
        and all(decision_semantics.values())
    )
    result = {
        "schema": "argos_ocv03_o3f14_r11_seed_angle_regression_v1",
        "state": "PASS_O3F14_R11_SEED_ANGLE_REGRESSION" if passed else "FAIL_O3F14_R11_SEED_ANGLE_REGRESSION",
        "r10Sha256": inheritance["r10Sha256"],
        "r11Sha256": inheritance["r11Sha256"],
        "testSha256": digest(Path(__file__).resolve()),
        "inheritance": inheritance,
        "anglePaths": angle_paths,
        "decisionSemantics": decision_semantics,
        "physicalProjection": physical_projection,
        "dfOnlyProjection": df_only_projection,
        "ambiguousProjection": ambiguous_projection,
        "numericThresholdRelaxationPerformed": False,
        "postResultSelectorRelaxationPerformed": False,
        "expectedAnglePriorConsumed": False,
        "bfDfFitAveragingPerformed": False,
        "sourceMutation": False,
        "providerActivated": False,
        "jbodAccessed": False,
    }
    if args.output:
        output = Path(args.output)
        need(not output.exists(), "Output already exists")
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(result, separators=(",", ":")))
    need(passed, "O3F14 R11 seed-angle regression failed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
