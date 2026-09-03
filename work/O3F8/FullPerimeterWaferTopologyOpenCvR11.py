#!/usr/bin/env python3
"""R11 review-only split-method full-perimeter wafer-notch detector.

The detector fits each frontside BF/DF wafer independently.  BF uses overlapping
top-connected topology views around the complete raw perimeter; DF uses the
qualified R6 full-360 outer-edge radial appearance regime.  Physical candidates
are paired only after both channel searches complete.  Backside pixels and Argos
rotation/orientation metadata, notch locations, angle priors, and search windows
are not accepted.  R11 preserves the complete R8/R9/R10 paths and, only when those
paths have no eligible pair, evaluates symmetric channel-local corroboration:
the frozen O3P8 DF-seeded local-BF method and a BF-seeded local-DF method using
the existing R9 radial crop.  A center-tolerance match or exact mouth-interval
overlap establishes correspondence; neither channel fit is transferred or
averaged.  Exactly one unique physical cluster is required for review output.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import sys
from typing import Any

import cv2
import numpy as np


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, f"Cannot load dependency: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


O3P8_SOURCE_SHA256 = "41F60AF393E0B2C752AF6B33BB6673145490AE2BB346A4DA8E59A2D42E383E36"
R9_SOURCE_SHA256 = "DB44AD35205AC088FE7E24C1CC8FA9291311922A7D31E0F1C055BA92EAFD2FC1"
R8_SOURCE_SHA256 = "068ECC0D4F547FCFD7A0A2AEDF673B71BB0C46207DE8EC0F47312A9030B0734B"
R6_SOURCE_SHA256 = "90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30"
TOPOLOGY_SOURCE_SHA256 = "D8897C1A5B60CB5AA9B0343CF8C9E5A249CCC5DEF5FBCDFE645EC08C354EF3BD"
RUNTIME_SOURCE_SHA256 = "7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1"
EXPECTED_OPENCV_VERSION = "5.0.0"
EXPECTED_NUMPY_VERSION = "2.5.2"
HERE = Path(__file__).resolve().parent
R6_ROOT = Path(os.environ.get("ARGOS_O3M1_R6_ROOT", str(HERE))).resolve()
TOPOLOGY_ROOT = Path(os.environ.get("ARGOS_O3M1_TOPOLOGY_ROOT", str(HERE))).resolve()
O3P8_ROOT = Path(os.environ.get("ARGOS_O3P8_ROOT", str(HERE))).resolve()
R6_PATH = R6_ROOT / "NativeFrontsideWaferPoseOpenCvV2R6.py"
TOPOLOGY_PATH = TOPOLOGY_ROOT / "WaferTopologyAxisOpenCv.py"
O3P8_PATH = O3P8_ROOT / "Detect-O3P8FrontSplitNotches.py"
for dependency_path, expected_sha256 in ((R6_PATH, R6_SOURCE_SHA256), (TOPOLOGY_PATH, TOPOLOGY_SOURCE_SHA256), (O3P8_PATH, O3P8_SOURCE_SHA256)):
    require(dependency_path.is_file(), f"Frozen dependency is missing: {dependency_path}")
    require(hashlib.sha256(dependency_path.read_bytes()).hexdigest().upper() == expected_sha256, f"Frozen dependency changed: {dependency_path}")
R6 = load_module("argos_o3m1_r6", R6_PATH)
TOPOLOGY = load_module("argos_o3m1_topology", TOPOLOGY_PATH)
require(O3P8_PATH.is_file(), f"Frozen O3P8 dependency is missing: {O3P8_PATH}")
O3P8 = load_module("argos_o3f8_o3p8", O3P8_PATH)
CORE = R6.core

O3P8_CORROBORATION = {
    "contourSmoothingSigmaPx": 2.0,
    "shoulderSpansPx": [64, 96, 128, 160, 200],
    "seedIntervalMarginDegrees": 0.75,
    "unseededSearchHalfWidthDegrees": 2.0,
    "minimumContourProminencePx": 3.0,
    "minimumTopologyToDfRadialDepthRatio": 0.1,
    "minimumMeanSupport": 0.45,
    "minimumTipSupport": 0.3,
    "minimumDfRadialIntervalWidthDegrees": 0.9,
    "maximumDfRadialIntervalWidthEnabled": False,
    "maximumBfDfAngleDifferenceDegrees": 1.5,
    "maximumSeedCountPerWafer": 64,
    "multipleEligibleDecision": "HOLD",
    "zeroEligibleDecision": "HOLD",
}

TOPOLOGY_CONFIG_KEYS = frozenset(
    {
        "clahe",
        "exteriorStartY",
        "exteriorEndY",
        "minimumExteriorScale",
        "waferDistanceThreshold",
        "dieStreetCloseKernelPx",
        "topContactRowsPx",
        "minimumTopContactPixels",
        "minimumWaferAreaPx",
        "maximumInwardPx",
        "maximumOutwardPx",
        "supportSampleOffsetPx",
        "minimumContourCoverage",
        "maximumInterpolatedGapPx",
        "patternSuppressionWidthPx",
        "minimumNotchDepthPx",
        "noiseSigmaThreshold",
        "candidateJoinWidthPx",
        "minimumNotchWidthPx",
        "maximumChannelCandidateCount",
    }
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    require(path.is_file() and path.stat().st_size <= 4 * 1024 * 1024, f"Invalid JSON: {path}")
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), "JSON root must be an object.")
    return value


def validate_topology_config(cfg: Any) -> dict[str, Any]:
    require(isinstance(cfg, dict), "Topology configuration must be an object.")
    actual = frozenset(str(key) for key in cfg)
    missing = sorted(TOPOLOGY_CONFIG_KEYS - actual)
    unknown = sorted(actual - TOPOLOGY_CONFIG_KEYS)
    require(not missing, f"Topology configuration keys missing: {','.join(missing)}")
    require(not unknown, f"Topology configuration keys unknown: {','.join(unknown)}")
    require(float(cfg["minimumNotchDepthPx"]) == 20.0, "Topology depth gate changed.")
    require(float(cfg["waferDistanceThreshold"]) >= 2.5, "Topology wafer-distance gate weakened.")
    require(int(cfg["dieStreetCloseKernelPx"]) == 17, "Topology die-street kernel changed.")
    require(int(cfg["patternSuppressionWidthPx"]) == 13, "Topology pattern-suppression width changed.")
    return cfg


def write_json(path: Path, value: dict[str, Any]) -> None:
    partial = path.with_name(path.name + ".partial")
    require(not path.exists() and not partial.exists(), f"Create-new JSON collision: {path}")
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def write_png(path: Path, image: np.ndarray) -> dict[str, Any]:
    require(not path.exists(), f"Create-new PNG collision: {path}")
    require(bool(cv2.imwrite(str(path), image, [cv2.IMWRITE_PNG_COMPRESSION, 6])), f"PNG write failed: {path}")
    return {"path": path.name, "bytes": path.stat().st_size, "sha256": sha256_file(path)}


def circular_gap(a: float, b: float) -> float:
    return abs((a - b + 180.0) % 360.0 - 180.0)


def circular_interval_segments(start: float, end: float) -> list[tuple[float, float]]:
    """Return one or two closed [0, 360] segments for a directed short arc."""
    start_value, end_value = float(start) % 360.0, float(end) % 360.0
    forward = (end_value - start_value) % 360.0
    if forward > 180.0:
        start_value, end_value = end_value, start_value
    if end_value >= start_value:
        return [(start_value, end_value)]
    return [(start_value, 360.0), (0.0, end_value)]


def circular_interval_overlap_degrees(
    first_start: float,
    first_end: float,
    second_start: float,
    second_end: float,
) -> float:
    overlap = 0.0
    for left_a, right_a in circular_interval_segments(first_start, first_end):
        for left_b, right_b in circular_interval_segments(second_start, second_end):
            overlap += max(0.0, min(right_a, right_b) - max(left_a, left_b))
    return float(overlap)


def candidate_mouth_interval(candidate: dict[str, Any]) -> tuple[float, float]:
    if "startAngleDegrees" in candidate and "endAngleDegrees" in candidate:
        return float(candidate["startAngleDegrees"]), float(candidate["endAngleDegrees"])
    return float(candidate["leftAngleDegrees"]), float(candidate["rightAngleDegrees"])


def correspondence_diagnostics(
    bf_candidate: dict[str, Any],
    df_candidate: dict[str, Any],
    maximum_center_gap_degrees: float,
) -> dict[str, Any]:
    bf_start, bf_end = candidate_mouth_interval(bf_candidate)
    df_start, df_end = candidate_mouth_interval(df_candidate)
    bf_center = float(bf_candidate.get("axisCenterAngleDegrees", bf_candidate.get("tipAngleDegrees")))
    df_center = float(df_candidate.get("axisCenterAngleDegrees", df_candidate.get("centerAngleDegrees")))
    center_gap = circular_gap(bf_center, df_center)
    overlap = circular_interval_overlap_degrees(bf_start, bf_end, df_start, df_end)
    center_passed = center_gap <= float(maximum_center_gap_degrees)
    overlap_passed = overlap > 0.0
    method = "CENTER_TOLERANCE" if center_passed else ("MOUTH_INTERVAL_OVERLAP" if overlap_passed else "NONE")
    return {
        "bfMouthStartAngleDegrees": bf_start,
        "bfMouthEndAngleDegrees": bf_end,
        "dfMouthStartAngleDegrees": df_start,
        "dfMouthEndAngleDegrees": df_end,
        "centerGapDegrees": center_gap,
        "maximumCenterGapDegrees": float(maximum_center_gap_degrees),
        "centerTolerancePassed": center_passed,
        "mouthIntervalOverlapDegrees": overlap,
        "mouthIntervalOverlapPassed": overlap_passed,
        "correspondenceMethod": method,
        "correspondencePassed": center_passed or overlap_passed,
    }


def evaluate_o3p8_candidate(
    bf: dict[str, Any],
    df: dict[str, Any],
    job: dict[str, Any],
) -> tuple[bool, float | None, bool, dict[str, Any] | None]:
    width_passed, angle_difference, original_passed = O3P8.evaluate_candidate(bf, df, job)
    if bf.get("feature") is None:
        return width_passed, angle_difference, original_passed, None
    correspondence = correspondence_diagnostics(
        bf["feature"],
        df,
        float(job["corroboration"]["maximumBfDfAngleDifferenceDegrees"]),
    )
    passed = bool(bf["topologyPassed"]) and width_passed and bool(correspondence["correspondencePassed"])
    return width_passed, angle_difference, passed, correspondence


def circular_owner(angle_degrees: float, step_degrees: float, tile_count: int) -> int:
    return int(math.floor((angle_degrees % 360.0) / step_degrees + 0.5)) % tile_count


def local_grid_maps(
    center_x: float,
    center_y: float,
    radius: float,
    angle_degrees: float,
    width: int,
    inward: int,
    outward: int,
) -> tuple[np.ndarray, np.ndarray]:
    theta = math.radians(angle_degrees)
    radial_x, radial_y = math.cos(theta), math.sin(theta)
    tangent_x, tangent_y = -radial_y, radial_x
    tangential = np.arange(width, dtype=np.float32) - (width - 1.0) / 2.0
    radial = np.arange(inward + outward, dtype=np.float32) - float(inward)
    map_x = center_x + (radius + radial[:, None]) * radial_x + tangential[None, :] * tangent_x
    map_y = center_y + (radius + radial[:, None]) * radial_y + tangential[None, :] * tangent_y
    return map_x.astype(np.float32), map_y.astype(np.float32)


def observed_columns(filled: np.ndarray, geometry: np.ndarray, cfg: dict[str, Any]) -> np.ndarray:
    height, width = filled.shape
    observed = np.zeros(width, dtype=bool)
    for x in range(width):
        lower = int(max(0, math.floor(float(geometry[x]) - float(cfg["maximumInwardPx"]))))
        upper = int(min(height - 1, math.ceil(float(geometry[x]) + float(cfg["maximumOutwardPx"]))))
        observed[x] = bool(np.any(filled[lower : upper + 1, x] > 0))
    return observed


def depth_profile(edge: np.ndarray, unindented: np.ndarray, cfg: dict[str, Any]) -> np.ndarray:
    depth = cv2.GaussianBlur((unindented - edge).reshape(1, -1), (0, 0), sigmaX=2.0).reshape(-1)
    size = int(cfg["patternSuppressionWidthPx"])
    if size % 2 == 0:
        size += 1
    depth = cv2.morphologyEx(
        depth.astype(np.float32).reshape(1, -1),
        cv2.MORPH_OPEN,
        cv2.getStructuringElement(cv2.MORPH_RECT, (size, 1)),
    ).reshape(-1)
    return cv2.GaussianBlur(depth.reshape(1, -1), (0, 0), sigmaX=3.0).reshape(-1)


def run_polylines(image: np.ndarray, values: np.ndarray, supported: np.ndarray, color: tuple[int, int, int], thickness: int) -> None:
    for left, right in TOPOLOGY.runs(supported):
        if right - left + 1 < 2:
            continue
        xs = np.arange(left, right + 1)
        points = np.column_stack((xs, np.rint(values[left : right + 1]).astype(np.int32))).reshape(-1, 1, 2)
        cv2.polylines(image, [points], False, color, thickness, cv2.LINE_8)


def honest_overlay(
    enhanced: np.ndarray,
    edge: np.ndarray,
    baseline: np.ndarray,
    observed: np.ndarray,
    candidate: dict[str, Any],
    state: str,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    height, width = enhanced.shape
    base = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    overlay = base.copy()
    mask = np.zeros((height, width), dtype=np.uint8)
    all_columns = np.ones(width, dtype=bool)
    run_polylines(overlay, baseline, all_columns, (0, 190, 0), 2)
    run_polylines(mask, baseline, all_columns, 255, 2)
    run_polylines(overlay, edge, observed, (255, 255, 0), 3)
    run_polylines(mask, edge, observed, 255, 3)

    left, right, tip = int(candidate["leftX"]), int(candidate["rightX"]), int(candidate["tipX"])
    segment_support = observed.copy()
    segment_support[:left] = False
    segment_support[right + 1 :] = False
    run_polylines(overlay, edge, segment_support, (0, 0, 255), 4)
    run_polylines(mask, edge, segment_support, 255, 4)
    for x in (left, right):
        top = max(32, int(round(baseline[x])) - 22)
        bottom = min(height - 1, int(round(baseline[x])) + 22)
        cv2.line(overlay, (x, top), (x, bottom), (0, 220, 220), 2, cv2.LINE_8)
        cv2.line(mask, (x, top), (x, bottom), 255, 2, cv2.LINE_8)
    cv2.drawMarker(overlay, (tip, int(round(edge[tip]))), (0, 0, 255), cv2.MARKER_CROSS, 14, 3, cv2.LINE_8)
    cv2.drawMarker(mask, (tip, int(round(edge[tip]))), 255, cv2.MARKER_CROSS, 14, 3, cv2.LINE_8)

    legend = "RED measured notch contour | YELLOW mouths | CYAN measured wafer edge | GREEN baseline"
    cv2.rectangle(overlay, (0, 0), (width - 1, 31), (0, 0, 0), cv2.FILLED)
    cv2.rectangle(mask, (0, 0), (width - 1, 31), 255, cv2.FILLED)
    cv2.putText(overlay, legend, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, legend, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.45, 255, 1, cv2.LINE_8)
    cv2.putText(overlay, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, 255, 1, cv2.LINE_8)
    changed = np.any(overlay != base, axis=2)
    require(np.count_nonzero(changed) > 0 and np.count_nonzero(changed & ~(mask > 0)) == 0, "Overlay mask invariant failed.")
    return base, overlay, mask


def topology_measurement(
    gray: np.ndarray,
    fit: dict[str, Any],
    tile_center: float,
    crop: dict[str, Any],
    cfg: dict[str, Any],
) -> dict[str, Any]:
    width = int(crop["widthPx"])
    inward = int(crop["inwardPx"])
    outward = int(crop["outwardPx"])
    map_x, map_y = local_grid_maps(
        float(fit["centerX"]), float(fit["centerY"]), float(fit["radius"]), tile_center, width, inward, outward
    )
    clean = cv2.remap(gray, map_x, map_y, interpolation=cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    geometry = TOPOLOGY.circle_geometry(width, float(inward), float(fit["radius"]))
    edge, support, enhanced, filled, evidence = TOPOLOGY.topology_edge(clean, geometry, cfg)
    baseline = TOPOLOGY.baseline(edge, geometry)
    candidates, noise, threshold = TOPOLOGY.notches(edge, baseline, support, cfg)
    observed = observed_columns(filled, geometry, cfg)
    depth = depth_profile(edge, baseline, cfg)
    return {
        "clean": clean,
        "edge": edge,
        "support": support,
        "enhanced": enhanced,
        "baseline": baseline,
        "observed": observed,
        "depth": depth,
        "evidence": evidence,
        "candidates": candidates,
        "depthNoisePx": noise,
        "detectionThresholdPx": threshold,
    }


def enrich_candidate(
    item: dict[str, Any],
    measurement: dict[str, Any],
    fit: dict[str, Any],
    tile_center: float,
    crop: dict[str, Any],
) -> dict[str, Any]:
    width, inward = int(crop["widthPx"]), int(crop["inwardPx"])
    edge, observed, depth = measurement["edge"], measurement["observed"], measurement["depth"]
    left, right, tip = int(item["leftX"]), int(item["rightX"]), int(item["tipX"])
    left_angle = TOPOLOGY.angle(float(left), float(edge[left]), width, float(inward), float(fit["radius"]), tile_center)
    right_angle = TOPOLOGY.angle(float(right), float(edge[right]), width, float(inward), float(fit["radius"]), tile_center)
    axis_angle = TOPOLOGY.angle(float(tip), float(edge[tip]), width, float(inward), float(fit["radius"]), tile_center)
    mouth_angle = TOPOLOGY.angle(float(item["mouthCenterX"]), float(edge[int(round(float(item["mouthCenterX"])))]), width, float(inward), float(fit["radius"]), tile_center)
    width_degrees = math.degrees((right - left + 1) / max(float(fit["radius"]), 1.0))
    shape = depth[left : right + 1]
    symmetry, tip_offset, slope_consistency = CORE.candidate_shape(shape.astype(np.float64))
    result = dict(item)
    result.update(
        {
            "tileCenterAngleDegrees": tile_center,
            "startAngleDegrees": left_angle,
            "endAngleDegrees": right_angle,
            "axisCenterAngleDegrees": axis_angle,
            "mouthMidpointAngleDegrees": mouth_angle,
            "widthDegrees": width_degrees,
            "observedContourFraction": float(np.mean(observed[left : right + 1])),
            "symmetryScore": float(symmetry),
            "tipCenterOffsetFraction": float(tip_offset),
            "slopeConsistencyFraction": float(slope_consistency),
        }
    )
    return result


def scan_channel(
    identity: str,
    channel: str,
    gray: np.ndarray,
    fit: dict[str, Any],
    crop: dict[str, Any],
    cfg: dict[str, Any],
) -> dict[str, Any]:
    step = float(crop["stepDegrees"])
    tile_count = int(round(360.0 / step))
    require(tile_count >= 36 and abs(tile_count * step - 360.0) < 1.0e-9, "Tile step must divide 360 degrees.")
    candidates: list[dict[str, Any]] = []
    incomplete_tiles: list[dict[str, Any]] = []
    qualified_tiles = 0
    for tile_index in range(tile_count):
        tile_center = tile_index * step
        try:
            measurement = topology_measurement(gray, fit, tile_center, crop, cfg)
        except Exception as exc:
            incomplete_tiles.append({"tileIndex": tile_index, "tileCenterAngleDegrees": tile_center, "reason": str(exc)[:240]})
            continue
        evidence = measurement["evidence"]
        complete = (
            float(evidence["coverageFraction"]) >= float(cfg["minimumContourCoverage"])
            and int(evidence["longestInterpolatedGapPx"]) <= int(cfg["maximumInterpolatedGapPx"])
        )
        if not complete:
            incomplete_tiles.append(
                {
                    "tileIndex": tile_index,
                    "tileCenterAngleDegrees": tile_center,
                    "coverageFraction": float(evidence["coverageFraction"]),
                    "longestInterpolatedGapPx": int(evidence["longestInterpolatedGapPx"]),
                    "reason": "CONTOUR_INCOMPLETE",
                }
            )
            continue
        qualified_tiles += 1
        for item in measurement["candidates"]:
            enriched = enrich_candidate(item, measurement, fit, tile_center, crop)
            owner = circular_owner(float(enriched["axisCenterAngleDegrees"]), step, tile_count)
            if owner != tile_index:
                continue
            enriched["tileIndex"] = tile_index
            enriched["channel"] = channel
            enriched["identity"] = identity
            candidates.append(enriched)
    candidates.sort(key=lambda row: (float(row["axisCenterAngleDegrees"]), int(row["tileIndex"])))
    require(len(candidates) <= int(cfg["maximumChannelCandidateCount"]), f"{identity} {channel} candidate cap exceeded.")
    return {
        "state": "PASS_FULL_PERIMETER_TOPOLOGY_SCANNED" if not incomplete_tiles else "HOLD_PARTIAL_TILE_TOPOLOGY_COVERAGE",
        "fit": fit,
        "tileCount": tile_count,
        "qualifiedTileCount": qualified_tiles,
        "incompleteTileCount": len(incomplete_tiles),
        "incompleteTiles": incomplete_tiles,
        "candidateCount": len(candidates),
        "candidates": candidates,
        "fullPerimeterSearch": True,
        "argosRotationMetadataConsumed": False,
        "knownNotchLocationConsumed": False,
    }


def radial_channel_from_base(identity: str, base: dict[str, Any], cfg: dict[str, Any]) -> dict[str, Any]:
    require(str(base.get("channel")) == "DF", "Radial channel must be DF.")
    candidates: list[dict[str, Any]] = []
    for item in base.get("candidates", []):
        candidates.append(
            {
                "identity": identity,
                "channel": "DF",
                "method": "OUTER_EDGE_RADIAL_FULL_360",
                "axisCenterAngleDegrees": float(item["centerAngleDegrees"]),
                "startAngleDegrees": float(item["startAngleDegrees"]),
                "endAngleDegrees": float(item["endAngleDegrees"]),
                "widthDegrees": float(item["widthDegrees"]),
                "peakDepthPx": float(item["maximumDepthPx"]),
                "medianDepthPx": float(item["medianDepthPx"]),
                "sampleCount": int(item["sampleCount"]),
                "symmetryScore": float(item["symmetryScore"]),
                "tipCenterOffsetFraction": float(item["tipCenterOffsetFraction"]),
                "slopeConsistencyFraction": float(item["slopeConsistencyFraction"]),
                "radialBoundaryQualified": bool(base.get("qualified")),
            }
        )
    require(len(candidates) <= int(cfg["maximumChannelCandidateCount"]), f"{identity} DF radial candidate cap exceeded.")
    return {
        "state": "PASS_R6_RADIAL_FULL_PERIMETER_SCANNED" if bool(base.get("qualified")) else "HOLD_R6_RADIAL_CHANNEL_NOT_QUALIFIED",
        "method": "OUTER_EDGE_RADIAL_FULL_360",
        "fit": base.get("fit"),
        "search": base.get("search"),
        "candidateDepthThresholdPx": base.get("candidateDepthThresholdPx"),
        "baselineNoiseSigmaPx": base.get("baselineNoiseSigmaPx"),
        "candidateCount": len(candidates),
        "candidates": candidates,
        "fullPerimeterSearch": True,
        "argosRotationMetadataConsumed": False,
        "knownNotchLocationConsumed": False,
    }


def pair_candidates(bf: dict[str, Any], df: dict[str, Any], params: Any) -> tuple[list[dict[str, Any]], list[int], list[int]]:
    choices: list[tuple[float, int, int]] = []
    for bf_index, b in enumerate(bf["candidates"]):
        for df_index, d in enumerate(df["candidates"]):
            gap = circular_gap(float(b["axisCenterAngleDegrees"]), float(d["axisCenterAngleDegrees"]))
            if gap <= float(params.candidate_match_tolerance_degrees):
                choices.append((gap, bf_index, df_index))
    used_bf: set[int] = set()
    used_df: set[int] = set()
    pairs: list[dict[str, Any]] = []
    for gap, bf_index, df_index in sorted(choices):
        if bf_index in used_bf or df_index in used_df:
            continue
        used_bf.add(bf_index)
        used_df.add(df_index)
        b, d = bf["candidates"][bf_index], df["candidates"][df_index]
        width = min(float(b["widthDegrees"]), float(d["widthDegrees"]))
        symmetry = max(float(b["symmetryScore"]), float(d["symmetryScore"]))
        tip_offset = min(float(b["tipCenterOffsetFraction"]), float(d["tipCenterOffsetFraction"]))
        slope = max(float(b["slopeConsistencyFraction"]), float(d["slopeConsistencyFraction"]))
        observed = float(b["observedContourFraction"])
        radial_qualified = bool(d.get("radialBoundaryQualified"))
        eligible = (
            float(params.manufactured_minimum_width_degrees) <= width <= float(params.manufactured_maximum_width_degrees)
            and symmetry >= float(params.manufactured_minimum_symmetry)
            and tip_offset <= float(params.manufactured_maximum_tip_offset_fraction)
            and slope >= float(params.manufactured_minimum_slope_consistency)
            and observed >= 0.95
            and radial_qualified
        )
        pairs.append(
            {
                "bfCandidateIndex": bf_index,
                "dfCandidateIndex": df_index,
                "bfAngleDegrees": float(b["axisCenterAngleDegrees"]),
                "dfAngleDegrees": float(d["axisCenterAngleDegrees"]),
                "channelAngleDifferenceDegrees": gap,
                "combinedWidthDegrees": width,
                "combinedSymmetryScore": symmetry,
                "combinedTipCenterOffsetFraction": tip_offset,
                "combinedSlopeConsistencyFraction": slope,
                "bfObservedTopologyContourFraction": observed,
                "dfRadialBoundaryQualified": radial_qualified,
                "bfMethod": "TOP_CONNECTED_TOPOLOGY_FULL_360",
                "dfMethod": "OUTER_EDGE_RADIAL_FULL_360",
                "manufacturedNotchMorphologyEligible": eligible,
                "bf": b,
                "df": d,
            }
        )
    return pairs, sorted(set(range(len(bf["candidates"]))) - used_bf), sorted(set(range(len(df["candidates"]))) - used_df)


def o3p8_df_seeded_local_bf_recovery(
    bf_image: np.ndarray,
    bf_fit: dict[str, Any],
    df: dict[str, Any],
    physical: list[dict[str, Any]],
    df_only_indices: list[int],
    crop: dict[str, Any],
    topology_cfg: dict[str, Any],
) -> dict[str, Any]:
    require(df["state"] == "PASS_R6_RADIAL_FULL_PERIMETER_SCANNED", "O3P8 fallback requires qualified DF full perimeter.")
    require(all(bool(candidate.get("radialBoundaryQualified")) for candidate in df["candidates"]), "O3P8 fallback received an unqualified DF seed.")
    paired_df_indices = [int(pair["dfCandidateIndex"]) for pair in physical]
    require(
        sorted(paired_df_indices + df_only_indices) == list(range(len(df["candidates"])))
        and len(set(paired_df_indices + df_only_indices)) == len(df["candidates"]),
        "R8 physical/DF-only partition changed.",
    )
    seeds: list[dict[str, Any]] = []
    for index, pair in enumerate(physical, 1):
        bf_candidate, df_candidate = pair["bf"], pair["df"]
        bf_width, df_width = float(bf_candidate["widthDegrees"]), float(df_candidate["widthDegrees"])
        if bf_width < df_width:
            seed_angle = float(bf_candidate["axisCenterAngleDegrees"])
        elif df_width < bf_width:
            seed_angle = float(df_candidate["axisCenterAngleDegrees"])
        else:
            seed_angle = CORE.circular_mean_degrees(
                [float(bf_candidate["axisCenterAngleDegrees"]), float(df_candidate["axisCenterAngleDegrees"])], [1.0, 1.0]
            )
        seeds.append(
            {
                "seedId": f"P{index:03d}",
                "seedClass": "R6_BF_DF_PHYSICAL",
                "seedAngleDegrees": seed_angle,
                "bfCandidate": {
                    "centerAngleDegrees": float(bf_candidate["axisCenterAngleDegrees"]),
                    "widthDegrees": bf_width,
                },
                "dfCandidate": {
                    "centerAngleDegrees": float(df_candidate["axisCenterAngleDegrees"]),
                    "startAngleDegrees": float(df_candidate["startAngleDegrees"]),
                    "endAngleDegrees": float(df_candidate["endAngleDegrees"]),
                    "widthDegrees": df_width,
                    "maximumDepthPx": float(df_candidate["peakDepthPx"]),
                },
                "sourcePhysicalCandidateIndex": index - 1,
                "sourceDfCandidateIndex": int(pair["dfCandidateIndex"]),
            }
        )
    for index, df_index in enumerate(df_only_indices, 1):
        df_candidate = df["candidates"][df_index]
        seeds.append(
            {
                "seedId": f"D{index:03d}",
                "seedClass": "R6_DF_ONLY",
                "seedAngleDegrees": float(df_candidate["axisCenterAngleDegrees"]),
                "bfCandidate": None,
                "dfCandidate": {
                    "centerAngleDegrees": float(df_candidate["axisCenterAngleDegrees"]),
                    "startAngleDegrees": float(df_candidate["startAngleDegrees"]),
                    "endAngleDegrees": float(df_candidate["endAngleDegrees"]),
                    "widthDegrees": float(df_candidate["widthDegrees"]),
                    "maximumDepthPx": float(df_candidate["peakDepthPx"]),
                },
                "sourcePhysicalCandidateIndex": None,
                "sourceDfCandidateIndex": int(df_index),
            }
        )
    seeds.sort(key=lambda item: (float(item["seedAngleDegrees"]), str(item["seedId"])))
    if len(seeds) > int(O3P8_CORROBORATION["maximumSeedCountPerWafer"]):
        return {"state": "HOLD_O3P8_DF_SEED_CAP_EXCEEDED", "seedCount": len(seeds), "eligibleSeedIndices": [], "seeds": []}
    recovery_job = {"crop": crop, "topologyConfig": topology_cfg, "corroboration": O3P8_CORROBORATION}
    renderer = sys.modules[__name__]
    rows: list[dict[str, Any]] = []
    for seed in seeds:
        df_candidate = seed["dfCandidate"]
        bf = O3P8.refine_bf(bf_image, bf_fit, seed, TOPOLOGY, renderer, recovery_job)
        width_passed, angle_difference, passed, correspondence = evaluate_o3p8_candidate(
            bf, df_candidate, recovery_job
        )
        rows.append(
            {
                "seedId": seed["seedId"],
                "seedClass": seed["seedClass"],
                "seedAngleDegrees": seed["seedAngleDegrees"],
                "sourcePhysicalCandidateIndex": seed["sourcePhysicalCandidateIndex"],
                "sourceDfCandidateIndex": seed["sourceDfCandidateIndex"],
                "sourceDfCandidate": df["candidates"][seed["sourceDfCandidateIndex"]],
                "bf": bf,
                "dfRadial": df_candidate,
                "dfRadialIntervalWidthPassed": width_passed,
                "bfTopologyDfRadialAngleDifferenceDegrees": angle_difference,
                "correspondence": correspondence,
                "eligible": passed,
                "dfTopologyInvoked": False,
                "bfOnlySeedConsumed": False,
            }
        )
    eligible = [index for index, row in enumerate(rows) if bool(row["eligible"])]
    return {
        "state": O3P8.decision_for_count(len(eligible)),
        "sourceDfFullPerimeterState": str(df["state"]),
        "sourceDfFullPerimeterQualified": not str(df["state"]).startswith("HOLD"),
        "seedCount": len(seeds),
        "eligibleSeedIndices": eligible,
        "selected": rows[eligible[0]] if len(eligible) == 1 else None,
        "seeds": rows,
    }


def r9_state(
    baseline_r8_state: str,
    baseline_eligible_count: int,
    recovery: dict[str, Any] | None,
    df_full_perimeter_qualified: bool,
) -> str:
    if (
        baseline_r8_state != "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH"
        or baseline_eligible_count != 0
        or recovery is None
        or not df_full_perimeter_qualified
    ):
        return baseline_r8_state
    recovered_count = len(recovery["eligibleSeedIndices"])
    if recovered_count == 1:
        return "PASS_REVIEW_ONLY_O3P8_DF_SEEDED_LOCAL_BF_NOTCH_CANDIDATE"
    if recovered_count > 1:
        return "HOLD_MULTIPLE_O3P8_DF_SEEDED_LOCAL_BF_NOTCHES"
    return baseline_r8_state


def render_o3p8_recovery_assets(
    output_root: Path,
    identity: str,
    bf_image: np.ndarray,
    bf_fit: dict[str, Any],
    crop: dict[str, Any],
    topology_cfg: dict[str, Any],
    selected: dict[str, Any],
) -> dict[str, Any]:
    bf = selected["bf"]
    feature = bf.get("feature")
    require(feature is not None and bool(selected["eligible"]), "Only an eligible O3P8 recovery may be rendered.")
    width, inward, outward = int(crop["widthPx"]), int(crop["inwardPx"]), int(crop["outwardPx"])
    map_x, map_y = local_grid_maps(
        float(bf_fit["centerX"]), float(bf_fit["centerY"]), float(bf_fit["radius"]),
        float(bf["cropCenterAngleDegrees"]), width, inward, outward,
    )
    clean = cv2.remap(bf_image, map_x, map_y, interpolation=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    geometry = TOPOLOGY.circle_geometry(width, float(inward), float(bf_fit["radius"]))
    edge, _, enhanced, filled, _ = TOPOLOGY.topology_edge(clean, geometry, topology_cfg)
    observed = observed_columns(filled, geometry, topology_cfg)
    base, overlay, mask = honest_overlay(
        enhanced, edge, geometry, observed, feature, "O3P8_DF_SEEDED_LOCAL_BF_CORROBORATION",
    )
    stem = f"{hashlib.sha256(identity.encode('utf-8')).hexdigest()[:16]}_bf_o3p8_recovery"
    assets = {
        "clean": write_png(output_root / f"{stem}_clean.png", cv2.cvtColor(clean, cv2.COLOR_GRAY2BGR)),
        "enhanced": write_png(output_root / f"{stem}_enhanced.png", base),
        "overlay": write_png(output_root / f"{stem}_overlay.png", overlay),
        "mask": write_png(output_root / f"{stem}_mask.png", mask),
    }
    for value in assets.values():
        value["operatorFeedbackRasterized"] = False
        value["inheritedReviewRasterUsed"] = False
        value["recoveryEngineSha256"] = O3P8_SOURCE_SHA256
    return assets


def render_candidate_assets(
    output_root: Path,
    identity: str,
    channel: str,
    candidate_index: int,
    gray: np.ndarray,
    fit: dict[str, Any],
    crop: dict[str, Any],
    cfg: dict[str, Any],
    candidate: dict[str, Any],
) -> dict[str, Any]:
    tile_center = float(candidate["tileCenterAngleDegrees"])
    measurement = topology_measurement(gray, fit, tile_center, crop, cfg)
    matching = None
    for item in measurement["candidates"]:
        enriched = enrich_candidate(item, measurement, fit, tile_center, crop)
        if circular_gap(float(enriched["axisCenterAngleDegrees"]), float(candidate["axisCenterAngleDegrees"])) < 0.05:
            matching = enriched
            break
    require(matching is not None, "Candidate was not deterministic during render replay.")
    base, overlay, mask = honest_overlay(
        measurement["enhanced"], measurement["edge"], measurement["baseline"], measurement["observed"], matching,
        "FULL_360_RAW_COORDINATE_TOPOLOGY_CANDIDATE",
    )
    clean_bgr = cv2.cvtColor(measurement["clean"], cv2.COLOR_GRAY2BGR)
    stem = f"{identity.lower().replace('-', '')}_{channel.lower()}_c{candidate_index + 1:02d}"
    assets = {
        "clean": write_png(output_root / f"{stem}_clean.png", clean_bgr),
        "enhanced": write_png(output_root / f"{stem}_enhanced.png", base),
        "overlay": write_png(output_root / f"{stem}_overlay.png", overlay),
        "mask": write_png(output_root / f"{stem}_mask.png", mask),
    }
    for value in assets.values():
        value["operatorFeedbackRasterized"] = False
        value["inheritedReviewRasterUsed"] = False
    return assets


def radial_crop_measurement(
    gray: np.ndarray,
    fit: dict[str, Any],
    tile_center: float,
    crop: dict[str, Any],
    params: Any,
    cfg: dict[str, Any],
) -> dict[str, Any]:
    width = int(crop["widthPx"])
    inward = int(crop["inwardPx"])
    outward = int(crop["outwardPx"])
    map_x, map_y = local_grid_maps(
        float(fit["centerX"]), float(fit["centerY"]), float(fit["radius"]), tile_center, width, inward, outward
    )
    clean = cv2.remap(gray, map_x, map_y, interpolation=cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    enhanced = cv2.createCLAHE(clipLimit=float(cfg["clahe"]), tileGridSize=(8, 8)).apply(clean)
    geometry = TOPOLOGY.circle_geometry(width, float(inward), float(fit["radius"]))

    smoothing = max(1, int(round(float(params.radial_smoothing_width_px))))
    if smoothing % 2 == 0:
        smoothing += 1
    smooth = cv2.blur(clean.astype(np.float32), (1, smoothing))
    span = max(1, int(round(float(params.radial_contrast_span_px))))
    require(span < clean.shape[0], "DF radial contrast span exceeds the crop.")
    contrast = smooth[:-span] - smooth[span:]
    maxima = np.zeros(width, dtype=np.float32)
    bounds: list[tuple[int, int]] = []
    for x in range(width):
        lower = int(max(0, math.floor(float(geometry[x]) - float(cfg["maximumInwardPx"]))))
        upper = int(min(contrast.shape[0] - 1, math.ceil(float(geometry[x]) + float(cfg["maximumOutwardPx"]))))
        bounds.append((lower, upper))
        maxima[x] = float(np.max(contrast[lower : upper + 1, x])) if upper >= lower else 0.0
    adaptive_floor = max(
        float(params.minimum_boundary_contrast),
        float(np.percentile(maxima, 20.0)) * float(params.outer_edge_relative_contrast),
    )
    edge = np.full(width, np.nan, dtype=np.float32)
    scores = np.zeros(width, dtype=np.float32)
    for x, (lower, upper) in enumerate(bounds):
        if upper < lower:
            continue
        threshold = max(
            float(params.minimum_boundary_contrast),
            float(maxima[x]) * float(params.outer_edge_relative_contrast),
            adaptive_floor,
        )
        eligible = np.flatnonzero(contrast[lower : upper + 1, x] >= threshold)
        if eligible.size:
            row = lower + int(eligible[-1])
            edge[x] = float(row) + 0.5 * float(span)
            scores[x] = float(contrast[row, x])
    supported = np.isfinite(edge)
    angles = np.full(width, np.nan, dtype=np.float64)
    for x in np.flatnonzero(supported):
        angles[x] = TOPOLOGY.angle(float(x), float(edge[x]), width, float(inward), float(fit["radius"]), tile_center)
    return {
        "clean": clean,
        "enhanced": enhanced,
        "geometry": geometry,
        "edge": edge,
        "supported": supported,
        "angles": angles,
        "scores": scores,
        "evidence": {
            "method": "OUTER_EDGE_RADIAL_PARALLEL_CROP_CONTOUR",
            "supportedColumnCount": int(np.count_nonzero(supported)),
            "supportedColumnFraction": float(np.mean(supported)),
            "adaptiveContrastFloor": float(adaptive_floor),
            "minimumBoundaryContrast": float(params.minimum_boundary_contrast),
            "outerEdgeRelativeContrast": float(params.outer_edge_relative_contrast),
            "radialSmoothingWidthPx": int(smoothing),
            "radialContrastSpanPx": int(span),
        },
    }


def linear_true_runs(mask: np.ndarray) -> list[np.ndarray]:
    runs: list[np.ndarray] = []
    start: int | None = None
    for index, active in enumerate(mask.astype(bool)):
        if active and start is None:
            start = index
        elif not active and start is not None:
            runs.append(np.arange(start, index, dtype=np.int32))
            start = None
    if start is not None:
        runs.append(np.arange(start, mask.size, dtype=np.int32))
    return runs


def close_small_linear_gaps(mask: np.ndarray, maximum_gap: int) -> np.ndarray:
    result = mask.copy().astype(bool)
    if maximum_gap <= 0 or not bool(np.any(result)):
        return result
    for gap in linear_true_runs(~result):
        left_active = int(gap[0]) > 0 and bool(result[int(gap[0]) - 1])
        right_active = int(gap[-1]) + 1 < result.size and bool(result[int(gap[-1]) + 1])
        if left_active and right_active and int(gap.size) <= maximum_gap:
            result[gap] = True
    return result


def longest_false_run(mask: np.ndarray) -> int:
    runs = linear_true_runs(~mask.astype(bool))
    return max((int(run.size) for run in runs), default=0)


def local_df_candidates(
    measurement: dict[str, Any],
    params: Any,
    crop: dict[str, Any],
    fit: dict[str, Any],
    tile_center: float,
) -> tuple[list[dict[str, Any]], float | None, float | None]:
    """Apply the frozen R6 candidate gates on a bounded, non-circular DF crop."""
    supported = np.asarray(measurement["supported"], dtype=bool)
    if int(np.count_nonzero(supported)) < 5:
        return [], None, None
    geometry = np.asarray(measurement["geometry"], dtype=np.float64)
    edge = np.asarray(measurement["edge"], dtype=np.float64)
    supported_indices = np.flatnonzero(supported)
    filled_edge = np.interp(np.arange(edge.size), supported_indices, edge[supported_indices])
    local_baseline = TOPOLOGY.baseline(filled_edge.astype(np.float32), geometry.astype(np.float32)).astype(np.float64)
    displacement = local_baseline - filled_edge
    measurement["localBaselineEvidence"] = {
        "method": "FROZEN_TOPOLOGY_ROBUST_QUADRATIC_SHOULDER_BASELINE",
        "medianOffsetFromChannelFitGeometryPx": float(np.median(local_baseline - geometry)),
        "bfFitTransferredOrAveraged": False,
    }
    padded = np.pad(displacement, (2, 2), mode="edge")
    smoothed = np.asarray([np.median(padded[index : index + 5]) for index in range(edge.size)], dtype=np.float64)
    supported_values = smoothed[supported]
    baseline_ceiling = float(np.percentile(supported_values, 80.0))
    baseline_values = supported_values[supported_values <= baseline_ceiling]
    median = float(np.median(baseline_values))
    mad = float(np.median(np.abs(baseline_values - median)))
    noise_sigma = 1.4826 * mad
    threshold = max(
        float(params.minimum_candidate_depth_px),
        median + float(params.candidate_noise_multiplier) * noise_sigma,
    )
    width = int(edge.size)
    inward = float(crop["inwardPx"])
    radius = float(fit["radius"])
    column_angles = np.asarray(
        [TOPOLOGY.angle(float(index), float(geometry[index]), width, inward, radius, tile_center) for index in range(width)],
        dtype=np.float64,
    )
    unwrapped = np.rad2deg(np.unwrap(np.deg2rad(column_angles)))
    steps = np.abs(np.diff(unwrapped))
    degrees_per_sample = float(np.median(steps[steps > 0.0]))
    require(degrees_per_sample > 0.0, "Local DF angular sampling is degenerate.")
    gap_samples = int(math.floor(float(params.candidate_gap_allowance_degrees) / degrees_per_sample))
    active = close_small_linear_gaps(supported & (smoothed >= threshold), gap_samples)
    candidates: list[dict[str, Any]] = []
    for indices in linear_true_runs(active):
        interval_width = float(unwrapped[int(indices[-1])] - unwrapped[int(indices[0])] + degrees_per_sample)
        if interval_width < float(params.candidate_minimum_width_degrees):
            continue
        depths = smoothed[indices]
        symmetry, tip_offset, slope = CORE.candidate_shape(depths)
        weights = np.maximum(depths, 0.001)
        center = CORE.circular_mean_degrees(
            [float(column_angles[index]) for index in indices],
            [float(value) for value in weights],
        )
        interval_support = supported[indices]
        candidates.append(
            {
                "centerAngleDegrees": center,
                "axisCenterAngleDegrees": center,
                "startAngleDegrees": float(column_angles[int(indices[0])]),
                "endAngleDegrees": float(column_angles[int(indices[-1])]),
                "widthDegrees": interval_width,
                "maximumDepthPx": float(np.max(depths)),
                "peakDepthPx": float(np.max(depths)),
                "medianDepthPx": float(np.median(depths)),
                "sampleCount": int(indices.size),
                "symmetryScore": symmetry,
                "tipCenterOffsetFraction": tip_offset,
                "slopeConsistencyFraction": slope,
                "supportedColumnFraction": float(np.mean(interval_support)),
                "longestUnsupportedGapPx": longest_false_run(interval_support),
                "sourceStartColumn": int(indices[0]),
                "sourceEndColumn": int(indices[-1]),
            }
        )
    candidates.sort(key=lambda item: float(item["axisCenterAngleDegrees"]))
    return candidates, threshold, noise_sigma


def bf_seed_morphology(candidate: dict[str, Any], params: Any) -> dict[str, Any]:
    width_passed = (
        float(params.manufactured_minimum_width_degrees)
        <= float(candidate["widthDegrees"])
        <= float(params.manufactured_maximum_width_degrees)
    )
    symmetry_passed = float(candidate["symmetryScore"]) >= float(params.manufactured_minimum_symmetry)
    tip_passed = float(candidate["tipCenterOffsetFraction"]) <= float(params.manufactured_maximum_tip_offset_fraction)
    slope_passed = float(candidate["slopeConsistencyFraction"]) >= float(params.manufactured_minimum_slope_consistency)
    observed_passed = float(candidate["observedContourFraction"]) >= 0.95
    return {
        "widthPassed": width_passed,
        "symmetryPassed": symmetry_passed,
        "tipOffsetPassed": tip_passed,
        "slopeConsistencyPassed": slope_passed,
        "observedContourPassed": observed_passed,
        "passed": width_passed and symmetry_passed and tip_passed and slope_passed and observed_passed,
    }


def bf_seeded_local_df_recovery(
    df_image: np.ndarray,
    df_fit: dict[str, Any],
    df_full_perimeter_state: str,
    bf: dict[str, Any],
    crop: dict[str, Any],
    params: Any,
    cfg: dict[str, Any],
) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for bf_index, bf_candidate in enumerate(bf["candidates"]):
        bf_gates = bf_seed_morphology(bf_candidate, params)
        seed_angle = float(bf_candidate["axisCenterAngleDegrees"])
        if not bool(bf_gates["passed"]):
            rows.append(
                {
                    "hypothesisId": f"B{bf_index + 1:03d}-NONE",
                    "direction": "BF_SEEDED_LOCAL_DF",
                    "sourceBfCandidateIndex": bf_index,
                    "bfCandidate": bf_candidate,
                    "bfSeedGates": bf_gates,
                    "dfRadial": None,
                    "localDfEvidence": None,
                    "correspondence": None,
                    "manufacturedMorphologyEligible": False,
                    "eligible": False,
                }
            )
            continue
        measurement = radial_crop_measurement(df_image, df_fit, seed_angle, crop, params, cfg)
        candidates, threshold, noise_sigma = local_df_candidates(measurement, params, crop, df_fit, seed_angle)
        evidence = dict(measurement["evidence"])
        evidence.update(
            {
                "globalDfFullPerimeterState": df_full_perimeter_state,
                "globalDfFullPerimeterQualified": not df_full_perimeter_state.startswith("HOLD"),
                "candidateDepthThresholdPx": threshold,
                "baselineNoiseSigmaPx": noise_sigma,
                "candidateCount": len(candidates),
                "channelLocalFitUsed": True,
                "bfFitTransferredOrAveraged": False,
                "localBaseline": measurement.get("localBaselineEvidence"),
            }
        )
        if not candidates:
            rows.append(
                {
                    "hypothesisId": f"B{bf_index + 1:03d}-NONE",
                    "direction": "BF_SEEDED_LOCAL_DF",
                    "sourceBfCandidateIndex": bf_index,
                    "bfCandidate": bf_candidate,
                    "bfSeedGates": bf_gates,
                    "dfRadial": None,
                    "localDfEvidence": evidence,
                    "correspondence": None,
                    "manufacturedMorphologyEligible": False,
                    "eligible": False,
                }
            )
            continue
        for df_index, df_candidate in enumerate(candidates):
            support_passed = (
                float(df_candidate["supportedColumnFraction"]) >= float(cfg["minimumContourCoverage"])
                and int(df_candidate["longestUnsupportedGapPx"]) <= int(cfg["maximumInterpolatedGapPx"])
            )
            df_width_passed = float(df_candidate["widthDegrees"]) >= float(
                O3P8_CORROBORATION["minimumDfRadialIntervalWidthDegrees"]
            )
            combined_width = min(float(bf_candidate["widthDegrees"]), float(df_candidate["widthDegrees"]))
            combined_symmetry = max(float(bf_candidate["symmetryScore"]), float(df_candidate["symmetryScore"]))
            combined_tip = min(
                float(bf_candidate["tipCenterOffsetFraction"]), float(df_candidate["tipCenterOffsetFraction"])
            )
            combined_slope = max(
                float(bf_candidate["slopeConsistencyFraction"]), float(df_candidate["slopeConsistencyFraction"])
            )
            manufactured = (
                float(params.manufactured_minimum_width_degrees)
                <= combined_width
                <= float(params.manufactured_maximum_width_degrees)
                and combined_symmetry >= float(params.manufactured_minimum_symmetry)
                and combined_tip <= float(params.manufactured_maximum_tip_offset_fraction)
                and combined_slope >= float(params.manufactured_minimum_slope_consistency)
            )
            correspondence = correspondence_diagnostics(
                bf_candidate,
                df_candidate,
                float(O3P8_CORROBORATION["maximumBfDfAngleDifferenceDegrees"]),
            )
            eligible = (
                bool(bf_gates["passed"])
                and support_passed
                and df_width_passed
                and manufactured
                and bool(correspondence["correspondencePassed"])
            )
            rows.append(
                {
                    "hypothesisId": f"B{bf_index + 1:03d}-D{df_index + 1:03d}",
                    "direction": "BF_SEEDED_LOCAL_DF",
                    "sourceBfCandidateIndex": bf_index,
                    "sourceLocalDfCandidateIndex": df_index,
                    "bfCandidate": bf_candidate,
                    "bfSeedGates": bf_gates,
                    "dfRadial": df_candidate,
                    "localDfEvidence": evidence,
                    "localDfSupportPassed": support_passed,
                    "dfRadialIntervalWidthPassed": df_width_passed,
                    "combinedWidthDegrees": combined_width,
                    "combinedSymmetryScore": combined_symmetry,
                    "combinedTipCenterOffsetFraction": combined_tip,
                    "combinedSlopeConsistencyFraction": combined_slope,
                    "correspondence": correspondence,
                    "manufacturedMorphologyEligible": manufactured,
                    "eligible": eligible,
                }
            )
    eligible_indices = [index for index, row in enumerate(rows) if bool(row["eligible"])]
    return {
        "state": O3P8.decision_for_count(len(eligible_indices)),
        "sourceDfFullPerimeterState": df_full_perimeter_state,
        "sourceDfFullPerimeterQualified": not df_full_perimeter_state.startswith("HOLD"),
        "seedCount": len(bf["candidates"]),
        "hypothesisCount": len(rows),
        "eligibleHypothesisIndices": eligible_indices,
        "hypotheses": rows,
    }


def hypothesis_channel_intervals(hypothesis: dict[str, Any]) -> tuple[tuple[float, float], tuple[float, float]]:
    if hypothesis["direction"] == "DF_SEEDED_LOCAL_BF":
        bf_candidate = hypothesis["bf"]["feature"]
    else:
        bf_candidate = hypothesis["bfCandidate"]
    return candidate_mouth_interval(bf_candidate), candidate_mouth_interval(hypothesis["dfRadial"])


def cluster_recovery_hypotheses(hypotheses: list[dict[str, Any]]) -> list[dict[str, Any]]:
    parents = list(range(len(hypotheses)))

    def root(index: int) -> int:
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index

    def union(first: int, second: int) -> None:
        first_root, second_root = root(first), root(second)
        if first_root != second_root:
            parents[second_root] = first_root

    for first in range(len(hypotheses)):
        bf_first, df_first = hypothesis_channel_intervals(hypotheses[first])
        for second in range(first + 1, len(hypotheses)):
            bf_second, df_second = hypothesis_channel_intervals(hypotheses[second])
            same_bf = circular_interval_overlap_degrees(*bf_first, *bf_second) > 0.0
            same_df = circular_interval_overlap_degrees(*df_first, *df_second) > 0.0
            if same_bf and same_df:
                union(first, second)
    grouped: dict[int, list[int]] = {}
    for index in range(len(hypotheses)):
        grouped.setdefault(root(index), []).append(index)
    return [
        {
            "clusterId": f"R10C{rank + 1:03d}",
            "hypothesisIndices": indices,
            "hypothesisIds": [str(hypotheses[index]["hypothesisId"]) for index in indices],
            "directions": sorted({str(hypotheses[index]["direction"]) for index in indices}),
        }
        for rank, indices in enumerate(sorted(grouped.values(), key=lambda values: values[0]))
    ]


def r10_symmetric_selection(
    baseline_r8_state: str,
    baseline_eligible_count: int,
    df_seeded: dict[str, Any] | None,
    bf_seeded: dict[str, Any] | None,
) -> dict[str, Any]:
    eligible_hypotheses: list[dict[str, Any]] = []
    if df_seeded is not None:
        for index in df_seeded["eligibleSeedIndices"]:
            row = dict(df_seeded["seeds"][int(index)])
            row["hypothesisId"] = f"DF-{row['seedId']}"
            row["direction"] = "DF_SEEDED_LOCAL_BF"
            eligible_hypotheses.append(row)
    if bf_seeded is not None:
        eligible_hypotheses.extend(
            dict(bf_seeded["hypotheses"][int(index)]) for index in bf_seeded["eligibleHypothesisIndices"]
        )
    invoked = baseline_eligible_count == 0 and baseline_r8_state in {
        "HOLD_DF_RADIAL_FULL_PERIMETER_NOT_QUALIFIED",
        "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH",
    }
    if not invoked:
        return {
            "state": baseline_r8_state,
            "invoked": False,
            "eligibleHypotheses": [],
            "physicalClusters": [],
            "selectedCluster": None,
        }
    clusters = cluster_recovery_hypotheses(eligible_hypotheses)
    if len(clusters) == 1:
        state = "PASS_REVIEW_ONLY_R10_SYMMETRIC_LOCAL_CROSS_CHANNEL_NOTCH_CANDIDATE"
    elif len(clusters) > 1:
        state = "HOLD_MULTIPLE_R10_SYMMETRIC_LOCAL_CROSS_CHANNEL_NOTCHES"
    else:
        state = baseline_r8_state
    return {
        "state": state,
        "invoked": True,
        "eligibleHypotheses": eligible_hypotheses,
        "physicalClusters": clusters,
        "selectedCluster": clusters[0] if len(clusters) == 1 else None,
    }


def render_bf_seeded_df_recovery_assets(
    output_root: Path,
    identity: str,
    df_image: np.ndarray,
    df_fit: dict[str, Any],
    crop: dict[str, Any],
    params: Any,
    cfg: dict[str, Any],
    selected: dict[str, Any],
) -> dict[str, Any]:
    require(bool(selected["eligible"]), "Only an eligible BF-seeded DF recovery may be rendered.")
    measurement = radial_crop_measurement(
        df_image,
        df_fit,
        float(selected["bfCandidate"]["axisCenterAngleDegrees"]),
        crop,
        params,
        cfg,
    )
    replayed, _, _ = local_df_candidates(measurement, params, crop, df_fit, float(selected["bfCandidate"]["axisCenterAngleDegrees"]))
    matching = [
        candidate for candidate in replayed
        if circular_gap(float(candidate["axisCenterAngleDegrees"]), float(selected["dfRadial"]["axisCenterAngleDegrees"])) < 0.05
    ]
    require(len(matching) == 1, "BF-seeded local DF candidate was not deterministic during render replay.")
    base, overlay, mask, evidence = honest_radial_overlay(measurement, matching[0])
    stem = f"{hashlib.sha256(identity.encode('utf-8')).hexdigest()[:16]}_df_r10_recovery"
    assets = {
        "clean": write_png(output_root / f"{stem}_clean.png", cv2.cvtColor(measurement["clean"], cv2.COLOR_GRAY2BGR)),
        "enhanced": write_png(output_root / f"{stem}_enhanced.png", base),
        "overlay": write_png(output_root / f"{stem}_overlay.png", overlay),
        "mask": write_png(output_root / f"{stem}_mask.png", mask),
    }
    for value in assets.values():
        value["operatorFeedbackRasterized"] = False
        value["inheritedReviewRasterUsed"] = False
    assets["radialContourEvidence"] = evidence
    return assets


def honest_radial_overlay(
    measurement: dict[str, Any],
    candidate: dict[str, Any],
) -> tuple[np.ndarray, np.ndarray, np.ndarray, dict[str, Any]]:
    enhanced = measurement["enhanced"]
    edge = measurement["edge"]
    baseline = measurement["geometry"]
    supported = measurement["supported"]
    angles = measurement["angles"]
    height, width = enhanced.shape
    base = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    overlay = base.copy()
    mask = np.zeros((height, width), dtype=np.uint8)
    run_polylines(overlay, baseline, np.ones(width, dtype=bool), (0, 190, 0), 2)
    run_polylines(mask, baseline, np.ones(width, dtype=bool), 255, 2)
    run_polylines(overlay, edge, supported, (255, 255, 0), 3)
    run_polylines(mask, edge, supported, 255, 3)

    center = float(candidate["axisCenterAngleDegrees"])
    half_width = 0.5 * float(candidate["widthDegrees"]) + 0.06
    candidate_support = supported.copy()
    candidate_support[supported] = np.asarray(
        [circular_gap(float(value), center) <= half_width for value in angles[supported]], dtype=bool
    )
    run_polylines(overlay, edge, candidate_support, (0, 0, 255), 4)
    run_polylines(mask, edge, candidate_support, 255, 4)

    supported_indices = np.flatnonzero(supported)
    require(supported_indices.size >= 2, "DF radial crop contour has fewer than two measured columns.")
    mouth_indices: list[int] = []
    for mouth_angle in (float(candidate["startAngleDegrees"]), float(candidate["endAngleDegrees"])):
        gaps = np.asarray([circular_gap(float(angles[index]), mouth_angle) for index in supported_indices])
        mouth_indices.append(int(supported_indices[int(np.argmin(gaps))]))
    for x in mouth_indices:
        point = (x, int(round(float(edge[x]))))
        cv2.circle(overlay, point, 6, (0, 220, 220), 2, cv2.LINE_8)
        cv2.circle(mask, point, 6, 255, 2, cv2.LINE_8)
    center_gaps = np.asarray([circular_gap(float(angles[index]), center) for index in supported_indices])
    axis_x = int(supported_indices[int(np.argmin(center_gaps))])
    axis_point = (axis_x, int(round(float(edge[axis_x]))))
    cv2.drawMarker(overlay, axis_point, (0, 0, 255), cv2.MARKER_CROSS, 14, 3, cv2.LINE_8)
    cv2.drawMarker(mask, axis_point, 255, cv2.MARKER_CROSS, 14, 3, cv2.LINE_8)

    state = "DF_RADIAL_MEASURED_NOTCH_CONTOUR" if int(np.count_nonzero(candidate_support)) >= 2 else "HOLD_DF_RADIAL_NOTCH_CONTOUR_SUPPORT_INSUFFICIENT"
    legend = "RED measured notch contour | YELLOW mouths | CYAN measured DF wafer edge | GREEN fitted circle"
    cv2.rectangle(overlay, (0, 0), (width - 1, 31), (0, 0, 0), cv2.FILLED)
    cv2.rectangle(mask, (0, 0), (width - 1, 31), 255, cv2.FILLED)
    cv2.putText(overlay, legend, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.43, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, legend, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.43, 255, 1, cv2.LINE_8)
    cv2.putText(overlay, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, 255, 1, cv2.LINE_8)
    changed = np.any(overlay != base, axis=2)
    require(np.count_nonzero(changed) > 0 and np.count_nonzero(changed & ~(mask > 0)) == 0, "DF radial overlay mask invariant failed.")
    evidence = dict(measurement["evidence"])
    evidence.update(
        {
            "state": state,
            "redMeasuredContourColumnCount": int(np.count_nonzero(candidate_support)),
            "mouthPointCount": len(mouth_indices),
            "straightRedAxisLineRendered": False,
            "interpolatedContourRenderedAsMeasured": False,
        }
    )
    return base, overlay, mask, evidence


def render_radial_candidate_assets(
    output_root: Path,
    identity: str,
    candidate_index: int,
    gray: np.ndarray,
    fit: dict[str, Any],
    crop: dict[str, Any],
    params: Any,
    cfg: dict[str, Any],
    candidate: dict[str, Any],
) -> dict[str, Any]:
    measurement = radial_crop_measurement(gray, fit, float(candidate["axisCenterAngleDegrees"]), crop, params, cfg)
    base, overlay, mask, evidence = honest_radial_overlay(measurement, candidate)
    stem = f"{identity.lower().replace('-', '')}_df_c{candidate_index + 1:02d}"
    assets = {
        "clean": write_png(output_root / f"{stem}_clean.png", cv2.cvtColor(measurement["clean"], cv2.COLOR_GRAY2BGR)),
        "enhanced": write_png(output_root / f"{stem}_enhanced.png", base),
        "overlay": write_png(output_root / f"{stem}_overlay.png", overlay),
        "mask": write_png(output_root / f"{stem}_mask.png", mask),
    }
    for value in assets.values():
        value["operatorFeedbackRasterized"] = False
        value["inheritedReviewRasterUsed"] = False
    assets["radialContourEvidence"] = evidence
    return assets


def render_overview(
    output_root: Path,
    identity: str,
    channel: str,
    gray: np.ndarray,
    fit: dict[str, Any],
    candidates: list[dict[str, Any]],
) -> dict[str, Any]:
    scale = min(1.0, 1400.0 / max(gray.shape))
    width = max(1, int(round(gray.shape[1] * scale)))
    height = max(1, int(round(gray.shape[0] * scale)))
    preview = cv2.resize(gray, (width, height), interpolation=cv2.INTER_AREA)
    preview = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(preview)
    overview = cv2.cvtColor(preview, cv2.COLOR_GRAY2BGR)
    for index, candidate in enumerate(candidates):
        angle = math.radians(float(candidate["axisCenterAngleDegrees"]))
        radial = float(fit["radius"]) - float(candidate["peakDepthPx"])
        x = int(round((float(fit["centerX"]) + math.cos(angle) * radial) * scale))
        y = int(round((float(fit["centerY"]) + math.sin(angle) * radial) * scale))
        cv2.circle(overview, (x, y), 10, (0, 0, 255), 2, cv2.LINE_8)
        cv2.putText(overview, f"C{index + 1}", (x + 12, y - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 1, cv2.LINE_8)
    cv2.rectangle(overview, (0, 0), (width - 1, 28), (0, 0, 0), cv2.FILLED)
    cv2.putText(overview, "RAW FULL WAFER - red circles locate channel candidates; inspect contour closeups", (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.46, (255, 255, 255), 1, cv2.LINE_8)
    stem = f"{identity.lower().replace('-', '')}_{channel.lower()}_overview.png"
    return write_png(output_root / stem, overview)


def parameters_from_job(job: dict[str, Any]) -> Any:
    return CORE.Parameters.from_json(job["parameters"])


def validate_job(path: Path, output_root: Path, verify_source_metadata: bool) -> dict[str, Any]:
    job = read_json(path)
    require(sha256_file(O3P8_PATH) == O3P8_SOURCE_SHA256, "Frozen O3P8 dependency changed.")
    runtime_text = os.environ.get("ARGOS_O3F8_RUNTIME_ROOT", "")
    require(runtime_text, "Pinned O3F8 runtime root is required.")
    runtime_root = Path(runtime_text).resolve(strict=True)
    require(Path(sys.executable).resolve(strict=True).parent == runtime_root, "O3F8 interpreter is outside the pinned runtime root.")
    require(sha256_file(Path(sys.executable).resolve(strict=True)) == RUNTIME_SOURCE_SHA256, "O3F8 interpreter hash changed.")
    for label, module_path in (("OpenCV", cv2.__file__), ("NumPy", np.__file__)):
        require(module_path is not None, f"{label} module path is unavailable.")
        try:
            Path(module_path).resolve(strict=True).relative_to(runtime_root)
        except ValueError as exc:
            raise ValueError(f"{label} loaded outside the pinned runtime root: {module_path}") from exc
    require(cv2.__version__ == EXPECTED_OPENCV_VERSION, "O3F8 OpenCV version changed.")
    require(np.__version__ == EXPECTED_NUMPY_VERSION, "O3F8 NumPy version changed.")
    require(job.get("schema") == "argos_ocv03_full_perimeter_topology_job_v1", "Job schema changed.")
    require(job.get("inferenceScope") == "FULL_360_RAW_IMAGE_NO_ORIENTATION_INPUT", "Inference scope changed.")
    require(
        job.get("channelMethods") == {"BF": "TOP_CONNECTED_TOPOLOGY_FULL_360", "DF": "OUTER_EDGE_RADIAL_FULL_360"},
        "Frontside channel methods changed.",
    )
    require(job.get("backsidePixelsConsumed") is False, "Backside pixels are forbidden in this frontside provider.")
    require(job.get("reviewOnly") is True, "Review-only authority absent.")
    for key in ("trainingEligible", "xmlEligible", "productionEligible", "productionRoutingEnabled", "sourceMutationAllowed", "providerActivationAllowed", "processorActionAllowed", "holdClearanceAllowed"):
        require(job.get(key) is False, f"Forbidden authority changed: {key}")
    serialized = json.dumps(job, sort_keys=True).lower()
    for forbidden in ("argosrotation", "orientationmetadata", "knownnotchlocation", "notchangleprior", "fixedangularsearchwindow", "upperright", "upper_right", "expectedangle"):
        require(forbidden not in serialized, f"Forbidden inference input present: {forbidden}")
    inputs = job.get("inputs")
    require(isinstance(inputs, list) and len(inputs) in (2, 6), "Input cardinality must be one or three BF/DF pairs.")
    identities: set[str] = set()
    pairs: dict[str, set[str]] = {}
    for row in inputs:
        identity = str(row["identity"])
        channel = str(row["channel"])
        require(channel in ("BF", "DF") and identity not in identities, "Input identity/channel changed.")
        identities.add(identity)
        pairs.setdefault(str(row["pairId"]), set()).add(channel)
        source_text = str(row["path"])
        require(source_text and "*" not in source_text and "?" not in source_text, "Unsafe source path.")
        source = Path(source_text)
        if verify_source_metadata:
            require(source.is_file() and source.stat().st_size == int(row["bytes"]), f"Source metadata changed: {source}")
        require(len(str(row["sha256"])) == 64, "Source hash pin changed.")
    require(all(channels == {"BF", "DF"} for channels in pairs.values()), "Every pair requires BF and DF.")
    planned_leaves: list[Path] = [output_root / "MANIFEST.json.partial"]
    for pair_id in pairs:
        require(not any(character in pair_id for character in '\\/:*?"<>|'), f"Unsafe pair identity: {pair_id}")
        stem = pair_id.lower().replace("-", "")
        planned_leaves.extend(
            [
                output_root / f"{stem}_bf_c24_enhanced.png",
                output_root / f"{stem}_df_c24_enhanced.png",
                output_root / f"{hashlib.sha256(pair_id.encode('utf-8')).hexdigest()[:16]}_bf_o3p8_recovery_enhanced.png",
                output_root / f"{hashlib.sha256(pair_id.encode('utf-8')).hexdigest()[:16]}_df_r10_recovery_enhanced.png",
                output_root / f"{stem}_bf_overview.png",
                output_root / f"{stem}_df_overview.png",
            ]
        )
    require(max(len(str(leaf)) for leaf in planned_leaves) < 200, "Planned R10 output path is unsafe.")
    require(max(len(leaf.name) for leaf in planned_leaves) <= 80, "Planned R10 output component is unsafe.")
    crop = job["crop"]
    require((int(crop["widthPx"]), int(crop["inwardPx"]), int(crop["outwardPx"])) == (1000, 420, 180), "Real crop geometry changed.")
    require(float(crop["stepDegrees"]) == 5.0, "Full-perimeter tile step changed.")
    cfg = validate_topology_config(job["topologyConfig"])
    require(not output_root.exists() and len(str(output_root)) + 32 < 200, "Output root is not fresh/path-safe.")
    parameters_from_job(job)
    return job


def process_job(job_path: Path, output_root: Path) -> dict[str, Any]:
    job = validate_job(job_path, output_root, True)
    output_root.mkdir(parents=False)
    params, crop, cfg = parameters_from_job(job), job["crop"], job["topologyConfig"]
    grouped: dict[str, dict[str, dict[str, Any]]] = {}
    verified: dict[str, str] = {}
    for row in job["inputs"]:
        path = Path(str(row["path"]))
        actual = sha256_file(path)
        require(actual == str(row["sha256"]).upper(), f"Source SHA-256 changed: {path}")
        verified[str(row["identity"])] = actual
        grouped.setdefault(str(row["pairId"]), {})[str(row["channel"])] = row

    results: list[dict[str, Any]] = []
    for pair_id in sorted(grouped):
        rows = grouped[pair_id]
        bf_image = cv2.imread(str(rows["BF"]["path"]), cv2.IMREAD_GRAYSCALE)
        df_image = cv2.imread(str(rows["DF"]["path"]), cv2.IMREAD_GRAYSCALE)
        require(bf_image is not None and df_image is not None, f"OpenCV decode failed: {pair_id}")
        base_result = CORE.analyze_pair(pair_id, bf_image, df_image, params)
        require("fit" in base_result.get("bf", {}) and "fit" in base_result.get("df", {}), f"Full-perimeter geometry fit failed: {pair_id}")
        bf = scan_channel(pair_id, "BF", bf_image, base_result["bf"]["fit"], crop, cfg)
        df = radial_channel_from_base(pair_id, base_result["df"], cfg)
        physical, bf_only, df_only = pair_candidates(bf, df, params)
        eligible = [index for index, item in enumerate(physical) if bool(item["manufacturedNotchMorphologyEligible"])]
        if df["state"].startswith("HOLD"):
            state = "HOLD_DF_RADIAL_FULL_PERIMETER_NOT_QUALIFIED"
        elif len(eligible) == 0:
            state = "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH"
        elif len(eligible) > 1:
            state = "HOLD_MULTIPLE_BF_TOPOLOGY_DF_RADIAL_NOTCHES"
        else:
            state = "PASS_REVIEW_ONLY_BF_TOPOLOGY_DF_RADIAL_NOTCH_CANDIDATE"
        baseline_r8_state = state
        recovery = None
        if baseline_r8_state == "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH" and df["state"] == "PASS_R6_RADIAL_FULL_PERIMETER_SCANNED":
            recovery = o3p8_df_seeded_local_bf_recovery(
                bf_image, base_result["bf"]["fit"], df, physical, df_only, crop, cfg
            )
        inherited_r9_state = r9_state(
            baseline_r8_state,
            len(eligible),
            recovery,
            not df["state"].startswith("HOLD"),
        )
        bf_seeded_recovery = None
        if len(eligible) == 0 and baseline_r8_state in {
            "HOLD_DF_RADIAL_FULL_PERIMETER_NOT_QUALIFIED",
            "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH",
        }:
            bf_seeded_recovery = bf_seeded_local_df_recovery(
                df_image,
                base_result["df"]["fit"],
                df["state"],
                bf,
                crop,
                params,
                cfg,
            )
        symmetric = r10_symmetric_selection(baseline_r8_state, len(eligible), recovery, bf_seeded_recovery)
        state = str(symmetric["state"]) if bool(symmetric["invoked"]) else inherited_r9_state
        if symmetric["selectedCluster"] is not None:
            rendered_directions: set[str] = set()
            for hypothesis_index in symmetric["selectedCluster"]["hypothesisIndices"]:
                selected_hypothesis = symmetric["eligibleHypotheses"][int(hypothesis_index)]
                direction = str(selected_hypothesis["direction"])
                if direction in rendered_directions:
                    continue
                if direction == "DF_SEEDED_LOCAL_BF":
                    selected_hypothesis["assets"] = render_o3p8_recovery_assets(
                        output_root,
                        pair_id,
                        bf_image,
                        base_result["bf"]["fit"],
                        crop,
                        cfg,
                        selected_hypothesis,
                    )
                else:
                    selected_hypothesis["assets"] = render_bf_seeded_df_recovery_assets(
                        output_root,
                        pair_id,
                        df_image,
                        base_result["df"]["fit"],
                        crop,
                        params,
                        cfg,
                        selected_hypothesis,
                    )
                rendered_directions.add(direction)

        bf["overview"] = render_overview(output_root, pair_id, "BF", bf_image, bf["fit"], bf["candidates"])
        for index, candidate in enumerate(bf["candidates"]):
            candidate["assets"] = render_candidate_assets(output_root, pair_id, "BF", index, bf_image, bf["fit"], crop, cfg, candidate)
        df["overview"] = render_overview(output_root, pair_id, "DF", df_image, df["fit"], df["candidates"])
        for index, candidate in enumerate(df["candidates"]):
            candidate["assets"] = render_radial_candidate_assets(output_root, pair_id, index, df_image, df["fit"], crop, params, cfg, candidate)
        results.append(
            {
                "pairId": pair_id,
                "state": state,
                "baselineR8State": baseline_r8_state,
                "inheritedR9State": inherited_r9_state,
                "baseGeometryFitState": base_result["state"],
                "baseBfGeometryCandidatesConsumedForDecision": False,
                "baseDfRadialCandidatesConsumedForDecision": True,
                "channelMethods": {"BF": "TOP_CONNECTED_TOPOLOGY_FULL_360", "DF": "OUTER_EDGE_RADIAL_FULL_360"},
                "backsidePixelsConsumed": False,
                "bf": bf,
                "df": df,
                "physicalIndentationCandidates": physical,
                "eligiblePhysicalCandidateIndices": eligible,
                "bfOnlyCandidateIndices": bf_only,
                "dfOnlyCandidateIndices": df_only,
                "selectedReviewOnlyManufacturedNotch": physical[eligible[0]] if len(eligible) == 1 else None,
                "o3p8DfSeededLocalBfRecovery": recovery,
                "bfSeededLocalDfRecovery": bf_seeded_recovery,
                "r10SymmetricRecovery": symmetric,
                "selectedReviewOnlyO3p8DfSeededLocalBfNotch": None,
                "selectedReviewOnlyR10SymmetricNotch": symmetric.get("selectedCluster"),
                "o3p8FallbackInvoked": recovery is not None,
                "bfSeededLocalDfInvoked": bf_seeded_recovery is not None,
                "bfDfPoseAveraged": False,
                "argosRotationMetadataConsumed": False,
                "knownNotchLocationConsumed": False,
                "notchAnglePriorConsumed": False,
                "fixedAngularSearchWindowConsumed": False,
            }
        )
        del bf_image, df_image

    manifest = {
        "schema": "argos_ocv03_full_perimeter_topology_manifest_v2",
        "revision": str(job["revision"]),
        "state": "COMPLETE_REVIEW_ONLY_FULL_PERIMETER_TOPOLOGY",
        "jobPath": str(job_path),
        "jobSha256": sha256_file(job_path),
        "inputCount": len(job["inputs"]),
        "inputHashesMatched": True,
        "fullPerimeterInference": True,
        "channelMethods": {"BF": "TOP_CONNECTED_TOPOLOGY_FULL_360", "DF": "OUTER_EDGE_RADIAL_FULL_360"},
        "engineProvenance": {
            "r10Sha256": sha256_file(Path(__file__).resolve()),
            "r9PredecessorSha256": R9_SOURCE_SHA256,
            "r8PredecessorSha256": R8_SOURCE_SHA256,
            "r6Sha256": sha256_file(R6_PATH),
            "topologySha256": sha256_file(TOPOLOGY_PATH),
            "o3p8Sha256": sha256_file(O3P8_PATH),
            "runtimeSha256": sha256_file(Path(sys.executable).resolve()),
            "opencvVersion": cv2.__version__,
            "numpyVersion": np.__version__,
        },
        "o3p8DfSeededLocalBfRecovery": {
            "sourceEngineSha256": O3P8_SOURCE_SHA256,
            "invocationRule": "ONLY_FOR_EXACT_R8_NO_PAIR_HOLD_WITH_QUALIFIED_DF_FULL_PERIMETER_AND_QUALIFIED_DF_SEEDS",
            "dfFullPerimeterQualificationRequired": True,
            "corroboration": O3P8_CORROBORATION,
            "existingR8CandidateArraysChanged": False,
            "existingR8SelectorThresholdsChanged": False,
        },
        "r10SymmetricRecovery": {
            "invocationRule": "ONLY_WHEN_R8_HAS_ZERO_ELIGIBLE_PAIR_AND_EXACT_NO_PAIR_OR_DF_QUALIFICATION_HOLD",
            "bfSeededLocalDfUsesDfChannelFit": True,
            "bfFitTransferredOrAveraged": False,
            "centerToleranceDegrees": O3P8_CORROBORATION["maximumBfDfAngleDifferenceDegrees"],
            "mouthIntervalOverlapAlternative": "EXACT_POSITIVE_CIRCULAR_INTERVAL_INTERSECTION",
            "numericThresholdRelaxationPerformed": False,
            "uniquePhysicalClusterRequired": True,
            "multiplePhysicalClusterDecision": "HOLD",
            "assetsRenderedOnlyForUniqueSelection": True,
            "existingR8CandidateArraysChanged": False,
            "existingR9RecoveryPathChangedExceptCorrespondenceGeometry": False,
        },
        "backsidePixelsConsumed": False,
        "tileCoverageDegrees": 360.0,
        "rawImageCoordinateSystemUsed": True,
        "argosRotationMetadataConsumed": False,
        "orientationMetadataConsumed": False,
        "knownNotchLocationConsumed": False,
        "notchAnglePriorConsumed": False,
        "fixedAngularSearchWindowConsumed": False,
        "operatorLocationConsumedBeforeOutputFreeze": False,
        "bfDiePatternSuppression": "TOP_CONNECTED_WAFER_COMPONENT_EXTERNAL_CONTOUR_FILL",
        "dfAppearanceMethod": "QUALIFIED_R6_OUTER_EDGE_RADIAL_BOUNDARY",
        "interpolatedContourRenderedAsMeasured": False,
        "notchOverlaySemantics": "RED_MEASURED_CHANNEL_CONTOUR_MOUTH_TO_MOUTH; NO_STRAIGHT_RED_AXIS_LINE",
        "results": results,
        "sourceMutationPerformed": False,
        "providerActivated": False,
        "processorTouched": False,
        "historicalHoldRecordMutated": False,
        "successorDecisionWrittenSeparately": True,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    manifest_path = output_root / "MANIFEST.json"
    write_json(manifest_path, manifest)
    return {
        "schema": "argos_ocv03_full_perimeter_topology_command_v1",
        "state": manifest["state"],
        "manifestPath": str(manifest_path),
        "manifestSha256": sha256_file(manifest_path),
        "pairCount": len(results),
        "imageInputCount": len(job["inputs"]),
        "imageBytesEmittedToStdout": False,
        "reviewOnly": True,
        "productionEligible": False,
    }


def patterned_wafer(size: int, radius: int, features: list[tuple[float, float, float, bool]]) -> np.ndarray:
    require(size >= 2 * radius + 120, "Synthetic canvas does not contain the wafer with margin.")
    center = size // 2
    image = np.zeros((size, size), dtype=np.uint8)
    cv2.circle(image, (center, center), radius, 180, cv2.FILLED, cv2.LINE_AA)
    for offset in range(-radius + 40, radius - 40, 76):
        cv2.line(image, (center - radius, center + offset), (center + radius, center + offset), 48, 9, cv2.LINE_8)
        cv2.line(image, (center + offset, center - radius), (center + offset, center + radius), 48, 9, cv2.LINE_8)
    disk = np.zeros_like(image)
    cv2.circle(disk, (center, center), radius, 255, cv2.FILLED)
    image[disk == 0] = 0
    for angle, width, depth, irregular in features:
        radians, half = math.radians(angle), math.radians(width / 2.0)
        mouths = [
            (int(round(center + math.cos(radians + delta) * radius)), int(round(center + math.sin(radians + delta) * radius)))
            for delta in (-half, half)
        ]
        tip_angle = radians + (math.radians(width * 0.22) if irregular else 0.0)
        tip = (int(round(center + math.cos(tip_angle) * (radius - depth))), int(round(center + math.sin(tip_angle) * (radius - depth))))
        cv2.fillConvexPoly(image, np.asarray([mouths[0], mouths[1], tip], dtype=np.int32), 0, cv2.LINE_AA)
    return image


def synthetic_gate(output_root: Path) -> dict[str, Any]:
    require(not output_root.exists(), "Synthetic output root must be create-new.")
    output_root.mkdir(parents=True)
    crop = {"widthPx": 1000, "inwardPx": 420, "outwardPx": 180, "stepDegrees": 5.0}
    cfg = {
        "clahe": 2.5, "exteriorStartY": 510, "exteriorEndY": 585, "minimumExteriorScale": 3.0,
        "waferDistanceThreshold": 2.5, "dieStreetCloseKernelPx": 17, "topContactRowsPx": 12,
        "minimumTopContactPixels": 100, "minimumWaferAreaPx": 150000, "maximumInwardPx": 180,
        "maximumOutwardPx": 55, "supportSampleOffsetPx": 8, "minimumContourCoverage": 0.95,
        "maximumInterpolatedGapPx": 20, "patternSuppressionWidthPx": 13, "minimumNotchDepthPx": 20.0,
        "noiseSigmaThreshold": 4.5, "candidateJoinWidthPx": 19, "minimumNotchWidthPx": 18,
        "maximumChannelCandidateCount": 24,
    }
    validate_topology_config(cfg)
    params = R6.r6_synthetic_parameters()
    cases = [
        ("UPPER_RIGHT_315", [(315.0, 2.4, 76.0, False)], [(315.2, 2.4, 76.0, False)], 1, 315.0),
        ("ANGLE_037", [(37.0, 2.2, 76.0, False)], [(37.2, 2.2, 76.0, False)], 1, 37.0),
        ("NO_NOTCH_PERIODIC", [], [], 0, None),
        ("TWO_NOTCH_AMBIGUITY", [(82.0, 2.2, 76.0, False), (242.0, 2.2, 76.0, False)], [(82.2, 2.2, 76.0, False), (242.2, 2.2, 76.0, False)], 2, None),
        ("CHIPOUT_NOT_PAIRED", [(217.0, 2.2, 76.0, False), (30.5, 18.5, 70.0, True)], [(217.2, 2.2, 76.0, False), (41.1, 1.5, 70.0, True)], 1, 217.0),
    ]
    rows: list[dict[str, Any]] = []
    overlay_control: dict[str, Any] | None = None
    for case_id, bf_features, df_features, expected_count, expected_angle in cases:
        bf_image = patterned_wafer(5000, 2200, bf_features)
        df_image = patterned_wafer(5000, 2270, df_features)
        fit_result = CORE.analyze_pair(case_id, bf_image, df_image, params)
        bf = scan_channel(case_id, "BF", bf_image, fit_result["bf"]["fit"], crop, cfg)
        df = radial_channel_from_base(case_id, fit_result["df"], cfg)
        physical, _, _ = pair_candidates(bf, df, params)
        eligible = [item for item in physical if bool(item["manufacturedNotchMorphologyEligible"])]
        passed = len(eligible) == expected_count
        detected = None
        if expected_angle is not None and len(eligible) == 1:
            detected = float(eligible[0]["bfAngleDegrees"])
            passed = passed and circular_gap(detected, expected_angle) <= 0.8
        if case_id == "UPPER_RIGHT_315" and len(eligible) == 1:
            df_index = int(eligible[0]["dfCandidateIndex"])
            overlay_control = render_radial_candidate_assets(
                output_root, case_id, df_index, df_image, df["fit"], crop, params, cfg, df["candidates"][df_index]
            )
            contour = overlay_control["radialContourEvidence"]
            passed = passed and str(contour["state"]) == "DF_RADIAL_MEASURED_NOTCH_CONTOUR" and int(contour["redMeasuredContourColumnCount"]) >= 2
        rows.append({"caseId": case_id, "eligiblePhysicalCandidateCount": len(eligible), "expectedCount": expected_count, "detectedAngleDegrees": detected, "expectedAngleScorerOnly": expected_angle, "passed": passed})
    passed = all(bool(row["passed"]) for row in rows)
    gate = {
        "schema": "argos_ocv03_split_method_full_perimeter_synthetic_gate_v1",
        "state": "PASS_O3M6_SPLIT_METHOD_FULL_PERIMETER_SYNTHETIC_GATE" if passed else "FAIL_O3M6_SPLIT_METHOD_FULL_PERIMETER_SYNTHETIC_GATE",
        "rows": rows,
        "channelMethods": {"BF": "TOP_CONNECTED_TOPOLOGY_FULL_360", "DF": "OUTER_EDGE_RADIAL_FULL_360"},
        "backsidePixelsConsumed": False,
        "dfRadialContourOverlayControl": overlay_control,
        "full360Search": True,
        "upperRightPositiveIncluded": True,
        "periodicDiePatternIncluded": True,
        "noNotchNegativeIncluded": True,
        "twoNotchAmbiguityIncluded": True,
        "chipoutPairingNegativeIncluded": True,
        "argosRotationMetadataConsumed": False,
        "knownNotchLocationConsumed": False,
        "expectedAnglesUsedOnlyAfterInference": True,
    }
    write_json(output_root / "SYNTHETIC_GATE.json", gate)
    require(passed, "Split-method full-perimeter synthetic gate failed.")
    return gate


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--runtime-preflight", action="store_true")
    mode.add_argument("--preflight", action="store_true")
    mode.add_argument("--synthetic-gate", action="store_true")
    mode.add_argument("--run", action="store_true")
    parser.add_argument("--job")
    parser.add_argument("--output-root")
    args = parser.parse_args()
    if args.runtime_preflight:
        result = {"schema": "argos_ocv03_full_perimeter_topology_runtime_preflight_v1", "state": "PASS_O3M1_RUNTIME_PREFLIGHT", "pythonVersion": sys.version.split()[0], "opencvVersion": cv2.__version__, "numpyVersion": np.__version__, "imageBytesDecoded": False, "mutationsPerformed": False}
    elif args.preflight:
        require(args.job and not args.output_root, "--preflight requires --job and forbids --output-root.")
        job = validate_job(Path(args.job), Path("O3M1_PREFLIGHT_OUTPUT_MUST_NOT_EXIST"), False)
        result = {"schema": "argos_ocv03_full_perimeter_topology_preflight_v1", "state": "PASS_O3M7_SPLIT_METHOD_PREFLIGHT", "revision": job["revision"], "inputCount": len(job["inputs"]), "full360Search": True, "sourceMetadataRead": False, "sourceImageBytesRead": False, "pixelsDecoded": False, "outputCreated": False, "argosRotationMetadataConsumed": False, "knownNotchLocationConsumed": False, "backsidePixelsConsumed": False, "reviewOnly": True}
    elif args.synthetic_gate:
        require(args.output_root and not args.job, "--synthetic-gate requires --output-root and forbids --job.")
        result = synthetic_gate(Path(args.output_root))
    else:
        require(args.job and args.output_root, "--run requires --job and --output-root.")
        result = process_job(Path(args.job), Path(args.output_root))
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
