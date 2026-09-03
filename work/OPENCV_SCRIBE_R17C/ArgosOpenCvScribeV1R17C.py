#!/usr/bin/env python3
"""R17C scribe provider: R17B plus low-contrast normal-crop lattice selection."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Iterable

import cv2
import numpy as np


REVISION = "ARGOS_OPENCV_SCRIBE_V1R17C_20260903"
LOW_THRESHOLDS = (14, 18, 22)
NORMAL_CROP_SEARCH_HEIGHT = 500


def _load_r17b() -> Any:
    path = Path(__file__).resolve().parents[1] / "OPENCV_SCRIBE_R17B" / "ArgosOpenCvScribeV1R17B.py"
    spec = importlib.util.spec_from_file_location("argos_scribe_r17b_for_r17c", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load R17B provider: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


R17B = _load_r17b()
R17B_MEASURE_STRUCTURE = R17B.measure_structure


def _low_threshold_centers(view: np.ndarray, threshold: int) -> np.ndarray:
    local_mean = cv2.boxFilter(view, cv2.CV_32F, (25, 25), normalize=True)
    residual = np.maximum(0.0, local_mean - view.astype(np.float32) - 2.0)
    count, _, stats, centroids = cv2.connectedComponentsWithStats(
        (residual >= float(threshold)).astype(np.uint8), 8
    )
    points: list[np.ndarray] = []
    for index in range(1, count):
        width = int(stats[index, cv2.CC_STAT_WIDTH])
        height = int(stats[index, cv2.CC_STAT_HEIGHT])
        area = int(stats[index, cv2.CC_STAT_AREA])
        aspect = width / float(max(1, height))
        if (
            2 <= width <= 30
            and 2 <= height <= 30
            and 4 <= area <= 500
            and 0.3 <= aspect <= 3.0
        ):
            points.append(centroids[index])
    return np.asarray(points, dtype=np.float32).reshape(-1, 2)


def _normal_blob_centers(view: np.ndarray) -> np.ndarray:
    parameters = cv2.SimpleBlobDetector_Params()
    parameters.minThreshold = 0
    parameters.maxThreshold = 250
    parameters.thresholdStep = 4
    parameters.filterByColor = True
    parameters.blobColor = 0
    parameters.filterByArea = True
    parameters.minArea = 5
    parameters.maxArea = 180
    parameters.filterByCircularity = True
    parameters.minCircularity = 0.45
    parameters.filterByInertia = True
    parameters.minInertiaRatio = 0.15
    parameters.filterByConvexity = True
    parameters.minConvexity = 0.45
    parameters.minDistBetweenBlobs = 3
    return np.asarray(
        [
            (row.pt[0], row.pt[1])
            for row in cv2.SimpleBlobDetector_create(parameters).detect(view)
            if 2.0 <= row.size <= 15.0
        ],
        dtype=np.float32,
    ).reshape(-1, 2)


def _pair_support(points: np.ndarray) -> dict[str, Any]:
    if not len(points):
        return {
            "horizontalDot": {"count": 0, "pitch": 0, "ratio": 0.0},
            "verticalDot": {"count": 0, "pitch": 0, "ratio": 0.0},
            "character": {"count": 0, "pitch": 0, "ratio": 0.0},
        }
    delta_x = np.abs(points[:, None, 0] - points[None, :, 0])
    delta_y = np.abs(points[:, None, 1] - points[None, :, 1])
    horizontal = R17B._maximum_pair_support(delta_x, delta_y, range(6, 31), 2, 3, "x")
    vertical = R17B._maximum_pair_support(delta_x, delta_y, range(10, 41), 3, 2, "y")
    character = R17B._maximum_pair_support(delta_x, delta_y, range(88, 106), 3, 5, "x")
    denominator = float(len(points))
    return {
        "horizontalDot": {"count": horizontal[0], "pitch": horizontal[1], "ratio": horizontal[0] / denominator},
        "verticalDot": {"count": vertical[0], "pitch": vertical[1], "ratio": vertical[0] / denominator},
        "character": {"count": character[0], "pitch": character[1], "ratio": character[0] / denominator},
    }


def _low_contrast_profile(view: np.ndarray, threshold: int) -> dict[str, Any]:
    points = _low_threshold_centers(view, threshold)
    search_height = min(NORMAL_CROP_SEARCH_HEIGHT, view.shape[0])
    search_points = points[points[:, 1] < search_height]
    x, y, cell_width, _ = R17B._best_grid(
        search_points, view.shape[1], search_height
    )
    inside, counts = R17B._cell_counts(
        points, x, y, cell_width, R17B.CELL_HEIGHT
    )
    support = _pair_support(inside)
    component_count = int(len(inside))
    covered = int(np.sum(counts >= 8))
    minimum = int(np.min(counts))
    horizontal_ratio = float(support["horizontalDot"]["ratio"])
    vertical_ratio = float(support["verticalDot"]["ratio"])
    character_ratio = float(support["character"]["ratio"])
    coherence = horizontal_ratio + vertical_ratio + character_ratio
    passed = (
        component_count >= 150
        and covered == 12
        and minimum >= 8
        and vertical_ratio >= 0.20
        and character_ratio >= 0.18
        and coherence >= 0.55
    )
    return {
        "schema": R17B.SCHEMA,
        "profile": f"LOW_CONTRAST_LOCAL_RESIDUAL_T{threshold}",
        "passed": passed,
        "grid": {"x": x, "y": y, "cellWidth": cell_width, "cellHeight": R17B.CELL_HEIGHT},
        "qualifiedComponentCount": component_count,
        "allQualifiedComponentCount": int(len(points)),
        "cellComponentCounts": [int(value) for value in counts],
        "coveredCellCount": covered,
        "pairSupport": support,
        "ratios": {
            "horizontalDotPair": horizontal_ratio,
            "verticalDotPair": vertical_ratio,
            "characterPitchPair": character_ratio,
            "coherenceSum": coherence,
        },
        "thresholds": {
            "residualThreshold": threshold,
            "maximumSearchHeight": NORMAL_CROP_SEARCH_HEIGHT,
            "minimumComponents": 150,
            "minimumComponentsPerCell": 8,
            "requiredCoveredCells": 12,
            "minimumVerticalDotPairRatio": 0.20,
            "minimumCharacterPitchPairRatio": 0.18,
            "minimumCoherenceSum": 0.55,
        },
    }


def _normal_blob_profile(view: np.ndarray) -> dict[str, Any]:
    points = _normal_blob_centers(view)
    search_height = min(NORMAL_CROP_SEARCH_HEIGHT, view.shape[0])
    search_points = points[points[:, 1] < search_height]
    x, y, cell_width, _ = R17B._best_grid(search_points, view.shape[1], search_height)
    inside, counts = R17B._cell_counts(points, x, y, cell_width, R17B.CELL_HEIGHT)
    support = _pair_support(inside)
    component_count = int(len(inside))
    covered = int(np.sum(counts >= 20))
    minimum = int(np.min(counts))
    horizontal_ratio = float(support["horizontalDot"]["ratio"])
    vertical_ratio = float(support["verticalDot"]["ratio"])
    character_ratio = float(support["character"]["ratio"])
    coherence = horizontal_ratio + vertical_ratio + character_ratio
    passed = (
        component_count >= 250
        and covered == 12
        and minimum >= 20
        and vertical_ratio >= 0.25
        and character_ratio >= 0.18
        and coherence >= 0.75
    )
    return {
        "schema": R17B.SCHEMA,
        "profile": "NORMAL_CROP_DARK_BLOBS",
        "passed": passed,
        "grid": {"x": x, "y": y, "cellWidth": cell_width, "cellHeight": R17B.CELL_HEIGHT},
        "qualifiedComponentCount": component_count,
        "allQualifiedComponentCount": int(len(points)),
        "cellComponentCounts": [int(value) for value in counts],
        "coveredCellCount": covered,
        "pairSupport": support,
        "ratios": {
            "horizontalDotPair": horizontal_ratio,
            "verticalDotPair": vertical_ratio,
            "characterPitchPair": character_ratio,
            "coherenceSum": coherence,
        },
        "thresholds": {
            "maximumSearchHeight": NORMAL_CROP_SEARCH_HEIGHT,
            "minimumBlobDiameter": 2.0,
            "maximumBlobDiameter": 15.0,
            "minimumComponents": 250,
            "minimumComponentsPerCell": 20,
            "requiredCoveredCells": 12,
            "minimumVerticalDotPairRatio": 0.25,
            "minimumCharacterPitchPairRatio": 0.18,
            "minimumCoherenceSum": 0.75,
        },
    }


def measure_structure(view: np.ndarray) -> dict[str, Any]:
    inherited = R17B_MEASURE_STRUCTURE(view)
    profiles = list(inherited.get("profiles", [inherited]))
    if view.shape[0] > NORMAL_CROP_SEARCH_HEIGHT:
        profiles.append(_normal_blob_profile(view))
        profiles.extend(_low_contrast_profile(view, threshold) for threshold in LOW_THRESHOLDS)
    passing = [row for row in profiles if bool(row["passed"])]
    selected = max(
        passing if passing else profiles,
        key=lambda row: (
            bool(row["passed"]),
            float(row.get("ratios", {}).get("coherenceSum", 0.0))
            or sum(float(row.get("ratios", {}).get(key, 0.0)) for key in (
                "horizontalDotPair", "verticalDotPair", "characterPitchPair"
            )),
            int(row["qualifiedComponentCount"]),
        ),
    )
    output = dict(selected)
    output["profiles"] = profiles
    return output


def paired_presence_evidence(bf: np.ndarray, df: np.ndarray) -> dict[str, Any]:
    R17B.measure_structure = measure_structure
    return R17B.paired_presence_evidence(bf, df)


def run_job(job_path: Path, result_path: Path) -> int:
    R17B.measure_structure = measure_structure
    R17B.REVISION = REVISION
    return R17B.run_job(job_path, result_path)


def main(argv: Iterable[str]) -> int:
    arguments = R17B._load_r11().parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as error:
        print(json.dumps({"state": "HOLD_OPENCV_SCRIBE_PROVIDER_ERROR", "errorType": type(error).__name__, "detail": str(error)}), file=sys.stderr)
        raise
