#!/usr/bin/env python3
"""R2 review-only full-perimeter wafer-notch topology detector.

The detector fits each BF/DF wafer independently, samples overlapping tangent
views around the complete raw 360-degree perimeter, suppresses internal die
streets through filled top-connected topology, and pairs physical indentation
contours only after both channels have been searched.  It accepts no Argos
rotation/orientation metadata, notch location, angle prior, or search window.
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


HERE = Path(__file__).resolve().parent
R6_ROOT = Path(os.environ.get("ARGOS_O3M1_R6_ROOT", str(HERE))).resolve()
TOPOLOGY_ROOT = Path(os.environ.get("ARGOS_O3M1_TOPOLOGY_ROOT", str(HERE))).resolve()
R6 = load_module("argos_o3m1_r6", R6_ROOT / "NativeFrontsideWaferPoseOpenCvV2R6.py")
TOPOLOGY = load_module("argos_o3m1_topology", TOPOLOGY_ROOT / "WaferTopologyAxisOpenCv.py")
CORE = R6.core


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
        observed = min(float(b["observedContourFraction"]), float(d["observedContourFraction"]))
        eligible = (
            float(params.manufactured_minimum_width_degrees) <= width <= float(params.manufactured_maximum_width_degrees)
            and symmetry >= float(params.manufactured_minimum_symmetry)
            and tip_offset <= float(params.manufactured_maximum_tip_offset_fraction)
            and slope >= float(params.manufactured_minimum_slope_consistency)
            and observed >= 0.95
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
                "minimumObservedContourFraction": observed,
                "manufacturedNotchMorphologyEligible": eligible,
                "bf": b,
                "df": d,
            }
        )
    return pairs, sorted(set(range(len(bf["candidates"]))) - used_bf), sorted(set(range(len(df["candidates"]))) - used_df)


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
    cv2.putText(overview, "RAW FULL WAFER - red circles locate topology candidates; inspect contour closeups", (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.46, (255, 255, 255), 1, cv2.LINE_8)
    stem = f"{identity.lower().replace('-', '')}_{channel.lower()}_overview.png"
    return write_png(output_root / stem, overview)


def parameters_from_job(job: dict[str, Any]) -> Any:
    return CORE.Parameters.from_json(job["parameters"])


def validate_job(path: Path, output_root: Path) -> dict[str, Any]:
    job = read_json(path)
    require(job.get("schema") == "argos_ocv03_full_perimeter_topology_job_v1", "Job schema changed.")
    require(job.get("inferenceScope") == "FULL_360_RAW_IMAGE_NO_ORIENTATION_INPUT", "Inference scope changed.")
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
        source = Path(str(row["path"]))
        require(source.is_file() and source.stat().st_size == int(row["bytes"]), f"Source metadata changed: {source}")
        require(len(str(row["sha256"])) == 64, "Source hash pin changed.")
    require(all(channels == {"BF", "DF"} for channels in pairs.values()), "Every pair requires BF and DF.")
    crop = job["crop"]
    require((int(crop["widthPx"]), int(crop["inwardPx"]), int(crop["outwardPx"])) == (1000, 420, 180), "Real crop geometry changed.")
    require(float(crop["stepDegrees"]) == 5.0, "Full-perimeter tile step changed.")
    cfg = job["topologyConfig"]
    require(float(cfg["minimumNotchDepthPx"]) == 20.0 and float(cfg["waferDistanceThreshold"]) >= 2.5, "Topology gates weakened.")
    require(not output_root.exists() and len(str(output_root)) + 32 < 200, "Output root is not fresh/path-safe.")
    parameters_from_job(job)
    return job


def process_job(job_path: Path, output_root: Path) -> dict[str, Any]:
    job = validate_job(job_path, output_root)
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
        df = scan_channel(pair_id, "DF", df_image, base_result["df"]["fit"], crop, cfg)
        physical, bf_only, df_only = pair_candidates(bf, df, params)
        eligible = [index for index, item in enumerate(physical) if bool(item["manufacturedNotchMorphologyEligible"])]
        if bf["state"].startswith("HOLD") or df["state"].startswith("HOLD"):
            state = "HOLD_FULL_PERIMETER_TOPOLOGY_COVERAGE_INCOMPLETE"
        elif len(eligible) == 0:
            state = "HOLD_NO_BF_DF_TOPOLOGY_NOTCH"
        elif len(eligible) > 1:
            state = "HOLD_MULTIPLE_BF_DF_TOPOLOGY_NOTCHES"
        else:
            state = "PASS_REVIEW_ONLY_BF_DF_TOPOLOGY_NOTCH_CANDIDATE"

        for channel, image, channel_result in (("BF", bf_image, bf), ("DF", df_image, df)):
            channel_result["overview"] = render_overview(output_root, pair_id, channel, image, channel_result["fit"], channel_result["candidates"])
            for index, candidate in enumerate(channel_result["candidates"]):
                candidate["assets"] = render_candidate_assets(output_root, pair_id, channel, index, image, channel_result["fit"], crop, cfg, candidate)
        results.append(
            {
                "pairId": pair_id,
                "state": state,
                "baseGeometryFitState": base_result["state"],
                "baseGeometryCandidatesConsumedForTopologyDecision": False,
                "bf": bf,
                "df": df,
                "physicalIndentationCandidates": physical,
                "eligiblePhysicalCandidateIndices": eligible,
                "bfOnlyCandidateIndices": bf_only,
                "dfOnlyCandidateIndices": df_only,
                "selectedReviewOnlyManufacturedNotch": physical[eligible[0]] if len(eligible) == 1 else None,
                "bfDfPoseAveraged": False,
                "argosRotationMetadataConsumed": False,
                "knownNotchLocationConsumed": False,
                "notchAnglePriorConsumed": False,
                "fixedAngularSearchWindowConsumed": False,
            }
        )
        del bf_image, df_image

    manifest = {
        "schema": "argos_ocv03_full_perimeter_topology_manifest_v1",
        "revision": str(job["revision"]),
        "state": "COMPLETE_REVIEW_ONLY_FULL_PERIMETER_TOPOLOGY",
        "jobPath": str(job_path),
        "jobSha256": sha256_file(job_path),
        "inputCount": len(job["inputs"]),
        "inputHashesMatched": True,
        "fullPerimeterInference": True,
        "tileCoverageDegrees": 360.0,
        "rawImageCoordinateSystemUsed": True,
        "argosRotationMetadataConsumed": False,
        "orientationMetadataConsumed": False,
        "knownNotchLocationConsumed": False,
        "notchAnglePriorConsumed": False,
        "fixedAngularSearchWindowConsumed": False,
        "operatorLocationConsumedBeforeOutputFreeze": False,
        "diePatternSuppression": "TOP_CONNECTED_WAFER_COMPONENT_EXTERNAL_CONTOUR_FILL",
        "interpolatedContourRenderedAsMeasured": False,
        "notchOverlaySemantics": "RED_MEASURED_CONTOUR_MOUTH_TO_MOUTH",
        "results": results,
        "sourceMutationPerformed": False,
        "providerActivated": False,
        "processorTouched": False,
        "holdCleared": False,
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
    params = R6.r6_synthetic_parameters()
    cases = [
        ("UPPER_RIGHT_315", [(315.0, 2.4, 38.0, False)], [(315.2, 2.4, 38.0, False)], 1, 315.0),
        ("ANGLE_037", [(37.0, 2.2, 36.0, False)], [(37.2, 2.2, 36.0, False)], 1, 37.0),
        ("NO_NOTCH_PERIODIC", [], [], 0, None),
        ("TWO_NOTCH_AMBIGUITY", [(82.0, 2.2, 36.0, False), (242.0, 2.2, 36.0, False)], [(82.2, 2.2, 36.0, False), (242.2, 2.2, 36.0, False)], 2, None),
        ("CHIPOUT_NOT_PAIRED", [(217.0, 2.2, 36.0, False), (30.5, 18.5, 70.0, True)], [(217.2, 2.2, 36.0, False), (41.1, 1.5, 70.0, True)], 1, 217.0),
    ]
    rows: list[dict[str, Any]] = []
    for case_id, bf_features, df_features, expected_count, expected_angle in cases:
        bf_image = patterned_wafer(2048, 840, bf_features)
        df_image = patterned_wafer(2048, 876, df_features)
        fit_result = CORE.analyze_pair(case_id, bf_image, df_image, params)
        bf = scan_channel(case_id, "BF", bf_image, fit_result["bf"]["fit"], crop, cfg)
        df = scan_channel(case_id, "DF", df_image, fit_result["df"]["fit"], crop, cfg)
        physical, _, _ = pair_candidates(bf, df, params)
        eligible = [item for item in physical if bool(item["manufacturedNotchMorphologyEligible"])]
        passed = len(eligible) == expected_count
        detected = None
        if expected_angle is not None and len(eligible) == 1:
            detected = float(eligible[0]["bfAngleDegrees"])
            passed = passed and circular_gap(detected, expected_angle) <= 0.8
        rows.append({"caseId": case_id, "eligiblePhysicalCandidateCount": len(eligible), "expectedCount": expected_count, "detectedAngleDegrees": detected, "expectedAngleScorerOnly": expected_angle, "passed": passed})
    passed = all(bool(row["passed"]) for row in rows)
    gate = {
        "schema": "argos_ocv03_full_perimeter_topology_synthetic_gate_v1",
        "state": "PASS_O3M1_FULL_PERIMETER_TOPOLOGY_SYNTHETIC_GATE" if passed else "FAIL_O3M1_FULL_PERIMETER_TOPOLOGY_SYNTHETIC_GATE",
        "rows": rows,
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
    require(passed, "Full-perimeter topology synthetic gate failed.")
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
        job = validate_job(Path(args.job), Path("O3M1_PREFLIGHT_OUTPUT_MUST_NOT_EXIST"))
        result = {"schema": "argos_ocv03_full_perimeter_topology_preflight_v1", "state": "PASS_O3M1_FULL_PERIMETER_TOPOLOGY_PREFLIGHT", "revision": job["revision"], "inputCount": len(job["inputs"]), "full360Search": True, "sourceImageBytesRead": False, "pixelsDecoded": False, "outputCreated": False, "argosRotationMetadataConsumed": False, "knownNotchLocationConsumed": False, "reviewOnly": True}
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
