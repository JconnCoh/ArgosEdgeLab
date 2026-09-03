#!/usr/bin/env python3
"""Comprehensive local synthetic regression gate for the O3F8/R10 draft."""

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
R9_PATH = HERE / "FullPerimeterWaferTopologyOpenCvR9.py"
R10_PATH = HERE / "FullPerimeterWaferTopologyOpenCvR10.py"
M9_ROOT = Path(os.environ.get("ARGOS_O3F8_DEPENDENCY_ROOT", str(ROOT / "work" / "OPENCV_EDGE_NOTCH_O3M9")))
O3P8_ROOT = Path(os.environ.get("ARGOS_O3P8_ROOT", str(ROOT / "work" / "OPENCV_EDGE_NOTCH_O3P8")))


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


def bf_candidate(
    center: float,
    start: float | None = None,
    end: float | None = None,
    observed: float = 1.0,
    symmetry: float = 1.0,
) -> dict[str, Any]:
    start_value = center - 1.0 if start is None else start
    end_value = center + 1.0 if end is None else end
    return {
        "axisCenterAngleDegrees": center,
        "startAngleDegrees": start_value % 360.0,
        "endAngleDegrees": end_value % 360.0,
        "widthDegrees": 2.0,
        "symmetryScore": symmetry,
        "tipCenterOffsetFraction": 0.0,
        "slopeConsistencyFraction": 1.0,
        "observedContourFraction": observed,
        "peakDepthPx": 60.0,
    }


def df_candidate(
    center: float,
    start: float | None = None,
    end: float | None = None,
    support: float = 1.0,
    gap: int = 0,
) -> dict[str, Any]:
    start_value = center - 1.0 if start is None else start
    end_value = center + 1.0 if end is None else end
    return {
        "centerAngleDegrees": center,
        "axisCenterAngleDegrees": center,
        "startAngleDegrees": start_value % 360.0,
        "endAngleDegrees": end_value % 360.0,
        "widthDegrees": 2.0,
        "maximumDepthPx": 60.0,
        "peakDepthPx": 60.0,
        "medianDepthPx": 40.0,
        "sampleCount": 20,
        "symmetryScore": 1.0,
        "tipCenterOffsetFraction": 0.0,
        "slopeConsistencyFraction": 1.0,
        "supportedColumnFraction": support,
        "longestUnsupportedGapPx": gap,
    }


def topology_config() -> dict[str, Any]:
    return {
        "clahe": 2.5,
        "exteriorStartY": 510,
        "exteriorEndY": 585,
        "minimumExteriorScale": 3.0,
        "waferDistanceThreshold": 2.5,
        "dieStreetCloseKernelPx": 17,
        "topContactRowsPx": 12,
        "minimumTopContactPixels": 100,
        "minimumWaferAreaPx": 150000,
        "maximumInwardPx": 180,
        "maximumOutwardPx": 55,
        "supportSampleOffsetPx": 8,
        "minimumContourCoverage": 0.95,
        "maximumInterpolatedGapPx": 20,
        "patternSuppressionWidthPx": 13,
        "minimumNotchDepthPx": 20.0,
        "noiseSigmaThreshold": 4.5,
        "candidateJoinWidthPx": 19,
        "minimumNotchWidthPx": 18,
        "maximumChannelCandidateCount": 24,
    }


def fake_measurement(width: int = 1000) -> dict[str, Any]:
    return {
        "clean": np.zeros((600, width), dtype=np.uint8),
        "enhanced": np.zeros((600, width), dtype=np.uint8),
        "geometry": np.full(width, 420.0, dtype=np.float64),
        "edge": np.full(width, 420.0, dtype=np.float64),
        "supported": np.ones(width, dtype=bool),
        "angles": np.zeros(width, dtype=np.float64),
        "scores": np.ones(width, dtype=np.float64),
        "evidence": {"supportedColumnCount": width, "supportedColumnFraction": 1.0},
    }


def eligible_df_seeded(r10: Any, identifier: str, bf: dict[str, Any], df: dict[str, Any]) -> dict[str, Any]:
    return {
        "hypothesisId": identifier,
        "seedId": identifier,
        "direction": "DF_SEEDED_LOCAL_BF",
        "bf": {"feature": bf, "topologyPassed": True},
        "dfRadial": df,
        "eligible": True,
        "correspondence": r10.correspondence_diagnostics(bf, df, 1.5),
    }


def eligible_bf_seeded(r10: Any, identifier: str, bf: dict[str, Any], df: dict[str, Any]) -> dict[str, Any]:
    return {
        "hypothesisId": identifier,
        "direction": "BF_SEEDED_LOCAL_DF",
        "bfCandidate": bf,
        "dfRadial": df,
        "eligible": True,
        "correspondence": r10.correspondence_diagnostics(bf, df, 1.5),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output")
    args = parser.parse_args()
    os.environ["ARGOS_O3M1_R6_ROOT"] = str(M9_ROOT)
    os.environ["ARGOS_O3M1_TOPOLOGY_ROOT"] = str(M9_ROOT)
    os.environ["ARGOS_O3P8_ROOT"] = str(O3P8_ROOT)
    r9 = load("argos_o3f8_r9_regression", R9_PATH)
    r10 = load("argos_o3f8_r10_regression", R10_PATH)
    params = r10.R6.r6_synthetic_parameters()
    cfg = topology_config()
    crop = {"widthPx": 1000, "inwardPx": 420, "outwardPx": 180, "stepDegrees": 5.0}
    fit = {"centerX": 500.0, "centerY": 500.0, "radius": 5150.0}

    inherited_functions = {
        name for name, value in vars(r9).items() if inspect.isfunction(value) and value.__module__ == r9.__name__
    }
    changed_inherited = {"o3p8_df_seeded_local_bf_recovery", "validate_job", "process_job"}
    inheritance_rows = []
    for name in sorted(inherited_functions - changed_inherited):
        unchanged = hasattr(r10, name) and inspect.getsource(getattr(r9, name)) == inspect.getsource(getattr(r10, name))
        inheritance_rows.append({"function": name, "unchanged": unchanged})
    inheritance = {
        "r9FunctionsPreserved": all(row["unchanged"] for row in inheritance_rows),
        "r9CorroborationConstantsUnchanged": r10.O3P8_CORROBORATION == r9.O3P8_CORROBORATION,
        "r9SourceSha256": digest(R9_PATH),
        "rows": inheritance_rows,
    }

    c5_bf = {
        "tipAngleDegrees": 91.618,
        "leftAngleDegrees": 90.559,
        "rightAngleDegrees": 92.470,
    }
    c5_df = df_candidate(89.687, 88.70, 90.70)
    c5_geometry = r10.correspondence_diagnostics(c5_bf, c5_df, 1.5)
    nonoverlap_bf = {
        "tipAngleDegrees": 91.618,
        "leftAngleDegrees": 90.701,
        "rightAngleDegrees": 92.470,
    }
    nonoverlap = r10.correspondence_diagnostics(nonoverlap_bf, c5_df, 1.5)
    wrap = r10.correspondence_diagnostics(
        {"tipAngleDegrees": 0.1, "leftAngleDegrees": 359.4, "rightAngleDegrees": 0.6},
        df_candidate(359.9, 359.7, 0.4),
        1.5,
    )
    o3p8_job = {"corroboration": r10.O3P8_CORROBORATION}
    o3p8_bf = {"topologyPassed": True, "feature": c5_bf}
    old_width, old_gap, old_pass = r10.O3P8.evaluate_candidate(o3p8_bf, c5_df, o3p8_job)
    new_width, new_gap, new_pass, new_correspondence = r10.evaluate_o3p8_candidate(o3p8_bf, c5_df, o3p8_job)
    geometry = {
        "c5PositiveOverlapDegrees": c5_geometry["mouthIntervalOverlapDegrees"],
        "c5CenterGapDegrees": c5_geometry["centerGapDegrees"],
        "c5UsesMouthOverlap": c5_geometry["correspondenceMethod"] == "MOUTH_INTERVAL_OVERLAP",
        "c5OldCenterOnlyRejected": old_width and old_gap is not None and not old_pass,
        "c5R10Accepted": new_width and new_gap == old_gap and new_pass and new_correspondence == c5_geometry,
        "sameGapWithoutOverlapRejected": not nonoverlap["correspondencePassed"],
        "wraparoundOverlapAccepted": wrap["mouthIntervalOverlapPassed"],
        "touchOnlyIsNotPositiveOverlap": r10.circular_interval_overlap_degrees(10.0, 11.0, 11.0, 12.0) == 0.0,
    }

    local_measurement = fake_measurement()
    x = np.arange(1000, dtype=np.float64)
    local_measurement["edge"] = local_measurement["geometry"] - 64.0 * np.exp(-0.5 * np.square((x - 500.0) / 35.0))
    local_candidates, threshold, noise = r10.local_df_candidates(local_measurement, params, crop, fit, 89.6)
    offset_measurement = fake_measurement()
    offset_measurement["edge"] = offset_measurement["geometry"] + 72.0 - 64.0 * np.exp(
        -0.5 * np.square((x - 500.0) / 35.0)
    )
    offset_candidates, _, _ = r10.local_df_candidates(offset_measurement, params, crop, fit, 89.6)
    local_extractor = {
        "candidateCount": len(local_candidates),
        "thresholdPx": threshold,
        "noiseSigmaPx": noise,
        "usesActualLocalAngles": len(local_candidates) == 1 and 0.0 < float(local_candidates[0]["widthDegrees"]) < 20.0,
        "centerNearSeed": len(local_candidates) == 1 and r10.circular_gap(float(local_candidates[0]["axisCenterAngleDegrees"]), 89.6) < 0.2,
        "largeChannelFitOffsetRecoveredByLocalBaseline": len(offset_candidates) == 1,
        "localBaselineMethodRecorded": offset_measurement.get("localBaselineEvidence", {}).get("method")
        == "FROZEN_TOPOLOGY_ROBUST_QUADRATIC_SHOULDER_BASELINE",
    }

    prior_measurement = r10.radial_crop_measurement
    prior_extractor = r10.local_df_candidates
    candidate_map: dict[float, list[dict[str, Any]]] = {}

    def stub_measurement(*unused: Any, **unused_named: Any) -> dict[str, Any]:
        return fake_measurement()

    def stub_candidates(
        unused_measurement: dict[str, Any],
        unused_params: Any,
        unused_crop: dict[str, Any],
        unused_fit: dict[str, Any],
        tile_center: float,
    ) -> tuple[list[dict[str, Any]], float, float]:
        return [dict(item) for item in candidate_map.get(round(tile_center, 3), [])], 20.0, 1.0

    r10.radial_crop_measurement = stub_measurement
    r10.local_df_candidates = stub_candidates

    def run_bf_recovery(candidates: list[dict[str, Any]], mapping: dict[float, list[dict[str, Any]]], state: str) -> dict[str, Any]:
        candidate_map.clear()
        candidate_map.update(mapping)
        return r10.bf_seeded_local_df_recovery(
            np.zeros((8, 8), dtype=np.uint8), fit, state, {"candidates": candidates}, crop, params, cfg
        )

    c1 = run_bf_recovery(
        [bf_candidate(89.5)],
        {89.5: [df_candidate(89.6)]},
        "HOLD_R6_RADIAL_CHANNEL_NOT_QUALIFIED",
    )
    c2 = run_bf_recovery(
        [bf_candidate(89.5), bf_candidate(3.0)],
        {89.5: [df_candidate(89.6)], 3.0: []},
        "HOLD_R6_RADIAL_CHANNEL_NOT_QUALIFIED",
    )
    c2_ambiguous = run_bf_recovery(
        [bf_candidate(89.5), bf_candidate(3.0)],
        {89.5: [df_candidate(89.6)], 3.0: [df_candidate(3.1)]},
        "HOLD_R6_RADIAL_CHANNEL_NOT_QUALIFIED",
    )
    c4 = run_bf_recovery(
        [bf_candidate(89.85)],
        {89.85: [df_candidate(89.7)]},
        "PASS_R6_RADIAL_FULL_PERIMETER_SCANNED",
    )
    poor_support = run_bf_recovery(
        [bf_candidate(89.5)],
        {89.5: [df_candidate(89.6, support=0.94)]},
        "HOLD_R6_RADIAL_CHANNEL_NOT_QUALIFIED",
    )
    bad_bf = run_bf_recovery(
        [bf_candidate(89.5, observed=0.94)],
        {89.5: [df_candidate(89.6)]},
        "HOLD_R6_RADIAL_CHANNEL_NOT_QUALIFIED",
    )
    r10.radial_crop_measurement = prior_measurement
    r10.local_df_candidates = prior_extractor
    bf_seeded_cases = {
        "c1UnqualifiedGlobalDfUniqueLocalPass": len(c1["eligibleHypothesisIndices"]) == 1,
        "c2SpuriousBfWithoutDfCorroborationSuppressed": len(c2["eligibleHypothesisIndices"]) == 1,
        "c2TwoCorroboratedSitesRemainAmbiguous": len(c2_ambiguous["eligibleHypothesisIndices"]) == 2,
        "c4QualifiedDfZeroGlobalCandidatesCanRecoverLocally": len(c4["eligibleHypothesisIndices"]) == 1,
        "poorLocalDfSupportHolds": len(poor_support["eligibleHypothesisIndices"]) == 0,
        "incompleteBfTopologySeedHolds": len(bad_bf["eligibleHypothesisIndices"]) == 0,
        "globalDfQualificationNotRequired": c1["sourceDfFullPerimeterQualified"] is False,
        "globalDfQualificationRecorded": c4["sourceDfFullPerimeterQualified"] is True,
    }

    reciprocal_bf = bf_candidate(89.5)
    reciprocal_df = df_candidate(89.6)
    df_seeded = {
        "eligibleSeedIndices": [0],
        "seeds": [eligible_df_seeded(r10, "D001", reciprocal_bf, reciprocal_df)],
    }
    bf_seeded = {
        "eligibleHypothesisIndices": [0],
        "hypotheses": [eligible_bf_seeded(r10, "B001-D001", reciprocal_bf, reciprocal_df)],
    }
    reciprocal = r10.r10_symmetric_selection(
        "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH", 0, df_seeded, bf_seeded
    )
    twenty_one = [
        eligible_df_seeded(r10, f"D{index + 1:03d}", bf_candidate(index * 10.0), df_candidate(index * 10.0 + 0.1))
        for index in range(21)
    ]
    c6 = r10.r10_symmetric_selection(
        "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH",
        0,
        {"eligibleSeedIndices": list(range(21)), "seeds": twenty_one},
        None,
    )
    zero = r10.r10_symmetric_selection("HOLD_DF_RADIAL_FULL_PERIMETER_NOT_QUALIFIED", 0, None, None)
    prior_pass = r10.r10_symmetric_selection("PASS_REVIEW_ONLY_BASELINE", 1, df_seeded, bf_seeded)
    selection = {
        "reciprocalDirectionsDeduplicateToOneCluster": len(reciprocal["physicalClusters"]) == 1,
        "reciprocalUniqueClusterPasses": reciprocal["state"] == "PASS_REVIEW_ONLY_R10_SYMMETRIC_LOCAL_CROSS_CHANNEL_NOTCH_CANDIDATE",
        "uniqueSelectionPresent": reciprocal["selectedCluster"] is not None,
        "c6TwentyOneDistinctSeedsHold": c6["state"] == "HOLD_MULTIPLE_R10_SYMMETRIC_LOCAL_CROSS_CHANNEL_NOTCHES",
        "c6ClusterCountPreserved": len(c6["physicalClusters"]) == 21,
        "c6HasNoSelectedCluster": c6["selectedCluster"] is None,
        "zeroRecoveryPreservesExactHold": zero["state"] == "HOLD_DF_RADIAL_FULL_PERIMETER_NOT_QUALIFIED",
        "existingPassNotInvoked": prior_pass["state"] == "PASS_REVIEW_ONLY_BASELINE" and not prior_pass["invoked"],
        "multipleNeverRanked": c6["selectedCluster"] is None,
    }

    passed = (
        all(value for key, value in inheritance.items() if key not in {"r9SourceSha256", "rows"})
        and all(geometry.values())
        and local_extractor["candidateCount"] == 1
        and local_extractor["thresholdPx"] is not None
        and local_extractor["noiseSigmaPx"] is not None
        and local_extractor["usesActualLocalAngles"]
        and local_extractor["centerNearSeed"]
        and local_extractor["largeChannelFitOffsetRecoveredByLocalBaseline"]
        and local_extractor["localBaselineMethodRecorded"]
        and all(bf_seeded_cases.values())
        and all(selection.values())
    )
    result = {
        "schema": "argos_ocv03_o3f8_r10_symmetric_recovery_local_gate_v1",
        "state": "PASS_O3F8_R10_SYMMETRIC_RECOVERY_LOCAL_GATE" if passed else "FAIL_O3F8_R10_SYMMETRIC_RECOVERY_LOCAL_GATE",
        "r9Sha256": digest(R9_PATH),
        "r10Sha256": digest(R10_PATH),
        "testSha256": digest(Path(__file__).resolve()),
        "inheritance": inheritance,
        "geometry": geometry,
        "localDfExtractor": local_extractor,
        "bfSeededCases": bf_seeded_cases,
        "selection": selection,
        "numericThresholdRelaxationPerformed": False,
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
    need(passed, "O3F8 R10 symmetric recovery gate failed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
