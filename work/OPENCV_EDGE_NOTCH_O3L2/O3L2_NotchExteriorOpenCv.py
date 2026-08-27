#!/usr/bin/env python3
"""Exterior-referenced OpenCV notch localization for OCV-03 review crops."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
from typing import Any

import cv2
import numpy as np


JOB_SCHEMA = "argos_ocv03_exterior_notch_job_v1"
PASS_PREFLIGHT = "PASS_O3L2_EXTERIOR_NOTCH_PREFLIGHT"
PASS_RESULT = "PASS_O3L2_EXTERIOR_REFERENCED_NOTCH_REVIEW"


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_object(path: Path) -> dict[str, Any]:
    ensure(path.is_file() and path.stat().st_size <= 4 * 1024 * 1024, f"Invalid JSON path: {path}")
    value = json.loads(path.read_text(encoding="utf-8"))
    ensure(isinstance(value, dict), "JSON root must be an object.")
    return value


def new_json(path: Path, value: dict[str, Any]) -> None:
    partial = path.with_name(path.name + ".partial")
    ensure(not path.exists() and not partial.exists(), f"Create-new JSON collision: {path}")
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def contains(root: Path, child: Path) -> bool:
    try:
        return os.path.commonpath([os.path.normcase(str(root)), os.path.normcase(str(child))]) == os.path.normcase(str(root))
    except ValueError:
        return False


def child_path(root: Path, name: str) -> Path:
    ensure(name and not os.path.isabs(name) and "*" not in name and "?" not in name, "Unsafe child path.")
    result = (root / name).resolve()
    ensure(contains(root.resolve(), result), "Child escapes root.")
    return result


def path_safe(path: Path) -> None:
    ensure(len(str(path)) + 32 < 200, f"Path requires short-root handling: {path}")
    ensure(all(len(part) <= 80 for part in path.parts), f"Overlong path component: {path}")


def unit_scale(values: np.ndarray, mask: np.ndarray) -> np.ndarray:
    sample = values[mask]
    sample = sample[np.isfinite(sample)]
    ensure(sample.size > 100, "Score normalization population is too small.")
    lower = float(np.percentile(sample, 4.0))
    upper = float(np.percentile(sample, 97.0))
    return np.clip((values - lower) / max(upper - lower, 1.0e-6), 0.0, 1.0).astype(np.float32)


def circle_row(width: int, inward: float, radius: float) -> np.ndarray:
    tangent = np.arange(width, dtype=np.float64) - (width - 1.0) / 2.0
    return (inward + np.sqrt(np.maximum(radius * radius - tangent * tangent, 0.0)) - radius).astype(np.float32)


def exterior_transition_score(gray: np.ndarray, geometry: np.ndarray, settings: dict[str, Any]) -> tuple[np.ndarray, np.ndarray, np.ndarray, dict[str, float]]:
    height, width = gray.shape
    enhanced = cv2.createCLAHE(
        clipLimit=float(settings["claheClipLimit"]),
        tileGridSize=(int(settings["claheGrid"]), int(settings["claheGrid"])),
    ).apply(gray)
    working = cv2.GaussianBlur(enhanced.astype(np.float32), (0, 0), 2.2, 1.1, borderType=cv2.BORDER_REFLECT101)

    exterior_start = int(settings["exteriorStartY"])
    exterior_end = int(settings["exteriorEndY"])
    ensure(0 <= exterior_start < exterior_end <= height, "Exterior band is invalid.")
    exterior_band = working[exterior_start:exterior_end, :]
    exterior_level = np.median(exterior_band, axis=0).astype(np.float32)
    exterior_level = cv2.GaussianBlur(exterior_level.reshape(1, -1), (0, 0), sigmaX=17.0).reshape(-1)
    exterior_mad = np.median(np.abs(exterior_band - exterior_level[None, :]), axis=0).astype(np.float32)
    exterior_scale = np.maximum(1.4826 * exterior_mad, 3.0)

    appearance_distance = np.abs(working - exterior_level[None, :]) / exterior_scale[None, :]
    appearance_distance = np.minimum(appearance_distance, 12.0).astype(np.float32)

    high_frequency = np.abs(working - cv2.GaussianBlur(working, (0, 0), 3.2, 2.2))
    local_texture = cv2.boxFilter(high_frequency, cv2.CV_32F, (9, 13), normalize=True, borderType=cv2.BORDER_REFLECT101)
    exterior_texture = np.median(local_texture[exterior_start:exterior_end, :], axis=0).astype(np.float32)
    exterior_texture = cv2.GaussianBlur(exterior_texture.reshape(1, -1), (0, 0), sigmaX=13.0).reshape(-1)
    texture_excess = np.maximum(local_texture - exterior_texture[None, :], 0.0)

    radial_window = int(settings["transitionWindowPx"])
    appearance_mean = cv2.boxFilter(appearance_distance, cv2.CV_32F, (7, radial_window), normalize=True, borderType=cv2.BORDER_REFLECT101)
    texture_mean = cv2.boxFilter(texture_excess, cv2.CV_32F, (7, radial_window), normalize=True, borderType=cv2.BORDER_REFLECT101)
    offset = int(settings["transitionOffsetPx"])
    rows = np.arange(height, dtype=np.int32)
    above = np.clip(rows - offset, 0, height - 1)
    below = np.clip(rows + offset, 0, height - 1)
    appearance_above = appearance_mean[above, :]
    appearance_below = appearance_mean[below, :]
    texture_above = texture_mean[above, :]
    texture_below = texture_mean[below, :]

    below_exterior_similarity = np.exp(-0.75 * appearance_below).astype(np.float32)
    directed_appearance = np.maximum(appearance_above - appearance_below, 0.0) * below_exterior_similarity
    directed_texture = np.maximum(texture_above - texture_below, 0.0) * below_exterior_similarity
    long_blur = cv2.GaussianBlur(working, (0, 0), float(settings["tangentialSigma"]), 2.0, borderType=cv2.BORDER_REFLECT101)
    radial_gradient = np.abs(cv2.Scharr(long_blur, cv2.CV_32F, 0, 1)) * below_exterior_similarity

    yy = np.arange(height, dtype=np.float32)[:, None]
    valid = (
        (yy >= geometry[None, :] - int(settings["maxInwardPx"]))
        & (yy <= geometry[None, :] + int(settings["maxOutwardPx"]))
    )
    score = (
        0.56 * unit_scale(directed_appearance, valid)
        + 0.27 * unit_scale(directed_texture, valid)
        + 0.17 * unit_scale(radial_gradient, valid)
    )
    score *= (0.35 + 0.65 * below_exterior_similarity)
    score[~valid] = 0.0
    exterior_metrics = {
        "medianLevel": float(np.median(exterior_level)),
        "medianMad": float(np.median(exterior_mad)),
        "medianTexture": float(np.median(exterior_texture)),
    }
    return score.astype(np.float32), enhanced, valid, exterior_metrics


def shortest_boundary(score: np.ndarray, valid: np.ndarray, geometry: np.ndarray, settings: dict[str, Any]) -> tuple[np.ndarray, np.ndarray]:
    height, width = score.shape
    max_step = int(settings["maxStepPx"])
    smooth_penalty = float(settings["stepPenalty"])
    geometry_penalty = float(settings["geometryPenalty"])
    yy = np.arange(height, dtype=np.float32)[:, None]
    local_cost = -score + geometry_penalty * np.abs(yy - geometry[None, :])
    local_cost[~valid] = 1.0e7
    total = np.full((height, width), 1.0e10, dtype=np.float64)
    parent = np.zeros((height, width), dtype=np.int16)
    total[:, 0] = local_cost[:, 0]
    for x in range(1, width):
        prior = total[:, x - 1]
        column_best = np.full(height, 1.0e10, dtype=np.float64)
        column_parent = np.zeros(height, dtype=np.int16)
        for step in range(-max_step, max_step + 1):
            moved = np.full(height, 1.0e10, dtype=np.float64)
            if step < 0:
                moved[:step] = prior[-step:]
            elif step > 0:
                moved[step:] = prior[:-step]
            else:
                moved[:] = prior
            moved += smooth_penalty * abs(step)
            choice = moved < column_best
            column_best[choice] = moved[choice]
            column_parent[choice] = step
        total[:, x] = local_cost[:, x] + column_best
        parent[:, x] = column_parent
    path = np.zeros(width, dtype=np.int32)
    path[-1] = int(np.argmin(total[:, -1]))
    for x in range(width - 1, 0, -1):
        path[x - 1] = path[x] - int(parent[path[x], x])
    path_float = cv2.medianBlur(path.astype(np.float32).reshape(1, -1), 5).reshape(-1)
    path_float = cv2.GaussianBlur(path_float.reshape(1, -1), (0, 0), sigmaX=1.2).reshape(-1)
    rounded = np.clip(np.rint(path_float).astype(np.int32), 0, height - 1)
    support = score[rounded, np.arange(width)]
    return path_float.astype(np.float32), support.astype(np.float32)


def unindented_baseline(boundary: np.ndarray, geometry: np.ndarray) -> np.ndarray:
    count = boundary.size
    x = np.linspace(-1.0, 1.0, count, dtype=np.float64)
    matrix = np.column_stack((np.ones(count), x, x * x))
    target = boundary.astype(np.float64) - geometry.astype(np.float64)
    weights = np.ones(count, dtype=np.float64)
    coefficients = np.zeros(3, dtype=np.float64)
    for _ in range(12):
        coefficients = np.linalg.lstsq(matrix * weights[:, None], target * weights, rcond=None)[0]
        error = target - matrix @ coefficients
        median = float(np.median(error))
        sigma = max(1.4826 * float(np.median(np.abs(error - median))), 0.4)
        standardized = np.abs((error - median) / (4.685 * sigma))
        weights = np.square(np.maximum(0.0, 1.0 - standardized * standardized))
        weights[error < median - 2.2 * sigma] *= 0.03
        weights = np.maximum(weights, 1.0e-4)
    return (geometry + matrix @ coefficients).astype(np.float32)


def runs(bits: np.ndarray) -> list[tuple[int, int]]:
    changes = np.diff(np.pad(bits.astype(np.int8), (1, 1)))
    return [(int(a), int(b - 1)) for a, b in zip(np.flatnonzero(changes == 1), np.flatnonzero(changes == -1))]


def indentation_candidates(boundary: np.ndarray, baseline: np.ndarray, support: np.ndarray, settings: dict[str, Any]) -> tuple[np.ndarray, list[dict[str, Any]], float, float]:
    depth = baseline - boundary
    depth = cv2.GaussianBlur(depth.reshape(1, -1), (0, 0), sigmaX=2.0).reshape(-1)
    suppress_width = int(settings["patternSuppressWidthPx"])
    if suppress_width % 2 == 0:
        suppress_width += 1
    depth = cv2.morphologyEx(
        depth.astype(np.float32).reshape(1, -1),
        cv2.MORPH_OPEN,
        cv2.getStructuringElement(cv2.MORPH_RECT, (suppress_width, 1)),
    ).reshape(-1)
    depth = cv2.GaussianBlur(depth.reshape(1, -1), (0, 0), sigmaX=3.0).reshape(-1)
    median = float(np.median(depth))
    noise = max(1.4826 * float(np.median(np.abs(depth - median))), 0.5)
    threshold = max(float(settings["minDepthPx"]), median + float(settings["noiseSigma"]) * noise)
    active = (depth >= threshold).astype(np.uint8).reshape(1, -1)
    active = cv2.morphologyEx(
        active,
        cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_RECT, (int(settings["joinWidthPx"]), 1)),
    ).reshape(-1).astype(bool)
    found: list[dict[str, Any]] = []
    for initial_left, initial_right in runs(active):
        if initial_right - initial_left + 1 < int(settings["minWidthPx"]):
            continue
        tip = initial_left + int(np.argmax(depth[initial_left : initial_right + 1]))
        peak = float(depth[tip])
        mouth_level = max(0.45 * float(settings["minDepthPx"]), median + 2.0 * noise, 0.18 * peak)
        left, right = tip, tip
        while left > 1 and depth[left - 1] >= mouth_level:
            left -= 1
        while right < depth.size - 2 and depth[right + 1] >= mouth_level:
            right += 1
        width = right - left + 1
        if width < int(settings["minWidthPx"]):
            continue
        mouth_center = 0.5 * (left + right)
        edge_support = float(np.mean(support[left : right + 1]))
        shape_area = float(np.sum(np.maximum(depth[left : right + 1] - mouth_level, 0.0)))
        score = peak * math.sqrt(width) * max(edge_support, 0.05) + 0.05 * shape_area
        found.append(
            {
                "leftX": left,
                "rightX": right,
                "mouthCenterX": mouth_center,
                "tipX": tip,
                "widthPx": width,
                "peakDepthPx": peak,
                "mouthLevelPx": mouth_level,
                "edgeSupport": edge_support,
                "shapeAreaPx2": shape_area,
                "score": score,
            }
        )
    found.sort(key=lambda item: (-float(item["score"]), int(item["leftX"])))
    return depth.astype(np.float32), found, noise, threshold


def absolute_angle(x: float, y: float, width: int, inward: float, radius: float, crop_angle: float) -> float:
    tangent = x - (width - 1.0) / 2.0
    angle = crop_angle + math.degrees(math.atan2(tangent, radius + y - inward))
    return angle % 360.0


def angular_difference(a: float, b: float) -> float:
    return abs((a - b + 180.0) % 360.0 - 180.0)


def save_png(path: Path, image: np.ndarray) -> None:
    ensure(not path.exists(), f"Create-new PNG collision: {path}")
    ensure(bool(cv2.imwrite(str(path), image, [cv2.IMWRITE_PNG_COMPRESSION, 6])), f"PNG write failed: {path}")


def review_layers(clean: np.ndarray, enhanced: np.ndarray, boundary: np.ndarray, baseline: np.ndarray, candidates: list[dict[str, Any]], state: str) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    height, width = enhanced.shape
    enhanced_bgr = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    overlay = enhanced_bgr.copy()
    mask = np.zeros((height, width), dtype=np.uint8)
    base_points = np.column_stack((np.arange(width), np.rint(baseline).astype(np.int32))).reshape(-1, 1, 2)
    edge_points = np.column_stack((np.arange(width), np.rint(boundary).astype(np.int32))).reshape(-1, 1, 2)
    cv2.polylines(overlay, [base_points], False, (0, 190, 0), 2, cv2.LINE_8)
    cv2.polylines(mask, [base_points], False, 255, 2, cv2.LINE_8)
    cv2.polylines(overlay, [edge_points], False, (255, 255, 0), 3, cv2.LINE_8)
    cv2.polylines(mask, [edge_points], False, 255, 3, cv2.LINE_8)
    for index, candidate in enumerate(candidates[:3]):
        left, right = int(candidate["leftX"]), int(candidate["rightX"])
        center = int(round(float(candidate["mouthCenterX"])))
        tip = int(candidate["tipX"])
        color = (0, 0, 255) if index == 0 else (0, 140, 255)
        for x in (left, right):
            top = max(0, int(baseline[x]) - 28)
            bottom = min(height - 1, int(baseline[x]) + 28)
            cv2.line(overlay, (x, top), (x, bottom), (0, 220, 220), 2, cv2.LINE_8)
            cv2.line(mask, (x, top), (x, bottom), 255, 2, cv2.LINE_8)
        cv2.line(overlay, (center, 0), (center, height - 1), color, 3 if index == 0 else 2, cv2.LINE_8)
        cv2.line(mask, (center, 0), (center, height - 1), 255, 3 if index == 0 else 2, cv2.LINE_8)
        cv2.drawMarker(overlay, (tip, int(round(boundary[tip]))), (255, 0, 255), cv2.MARKER_CROSS, 18, 3, cv2.LINE_8)
        cv2.drawMarker(mask, (tip, int(round(boundary[tip]))), 255, cv2.MARKER_CROSS, 18, 3, cv2.LINE_8)
    top_label = "RED mouth center | MAGENTA deepest tip | CYAN exterior-referenced wafer edge | GREEN baseline"
    cv2.rectangle(overlay, (0, 0), (width - 1, 31), (0, 0, 0), cv2.FILLED)
    cv2.rectangle(mask, (0, 0), (width - 1, 31), 255, cv2.FILLED)
    cv2.putText(overlay, top_label, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.47, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, top_label, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.47, 255, 1, cv2.LINE_8)
    cv2.putText(overlay, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, 255, 1, cv2.LINE_8)
    changed = np.any(overlay != enhanced_bgr, axis=2)
    ensure(np.count_nonzero(changed) > 0 and np.count_nonzero(changed & ~(mask > 0)) == 0, "Overlay mask invariant failed.")
    return enhanced_bgr, overlay, mask


def validate_job(job_path: Path, output_root: Path) -> tuple[dict[str, Any], Path]:
    job = read_object(job_path)
    ensure(job.get("schema") == JOB_SCHEMA, "Job schema changed.")
    ensure(bool(job.get("reviewOnly")), "Review-only authority is required.")
    for field in ("trainingEligible", "xmlEligible", "productionEligible", "productionRoutingEnabled", "detectorRerun", "sourceMutation", "liveProviderActivation"):
        ensure(not bool(job.get(field)), f"Forbidden authority changed: {field}")
    ensure(job.get("localizationInput") == "CLEAN_PIXELS_AND_CROP_TRANSFORM_WITHOUT_JSON_CANDIDATE_CENTER", "Localization input changed.")
    source_root = (job_path.parent / str(job["sourceRootRelativeToJob"])).resolve()
    ensure(source_root.is_dir(), "Source root is absent.")
    path_safe(output_root)
    inputs = list(job.get("inputs", []))
    expected = {"S16-C1-BF", "S16-C1-DF", "S17-C1-BF", "S17-C1-DF", "S17-C2-BF", "S17-C2-DF"}
    ensure(len(inputs) == 6 and {str(row["id"]) for row in inputs} == expected, "Input identity set changed.")
    for row in inputs:
        path = child_path(source_root, str(row["path"]))
        path_safe(path)
        ensure(path.is_file() and len(str(row["sha256"])) == 64, "Input pin is invalid.")
        ensure(int(row["widthPx"]) == 1000 and int(row["heightPx"]) == 600 and int(row["inwardY"]) == 420, "Input geometry changed.")
    pairs = list(job.get("pairs", []))
    ensure(len(pairs) == 3 and {str(row["pairId"]) for row in pairs} == {"S16-C1", "S17-C1", "S17-C2"}, "Pair set changed.")
    settings = job.get("settings")
    ensure(isinstance(settings, dict) and int(settings["exteriorStartY"]) >= 500 and int(settings["exteriorEndY"]) <= 600, "Exterior reference is not pinned.")
    ensure(float(settings["minDepthPx"]) == 7.0, "O3L1 minimum depth was relaxed.")
    return job, source_root


def run(job_path: Path, output_root: Path) -> dict[str, Any]:
    job, source_root = validate_job(job_path, output_root)
    ensure(not output_root.exists(), "Output root must be create-new.")
    output_root.mkdir(parents=False)
    settings = job["settings"]
    results: list[dict[str, Any]] = []
    by_id: dict[str, dict[str, Any]] = {}
    for item in sorted(job["inputs"], key=lambda row: str(row["id"])):
        source = child_path(source_root, str(item["path"]))
        actual_hash = file_hash(source)
        ensure(actual_hash == str(item["sha256"]).upper(), f"Input hash changed: {source}")
        clean = cv2.imread(str(source), cv2.IMREAD_COLOR)
        ensure(clean is not None and clean.shape == (600, 1000, 3), f"Input decode changed: {source}")
        gray = cv2.cvtColor(clean, cv2.COLOR_BGR2GRAY)
        geometry = circle_row(1000, float(item["inwardY"]), float(item["radiusPx"]))
        edge_score, enhanced, valid, exterior_metrics = exterior_transition_score(gray, geometry, settings)
        boundary, edge_support = shortest_boundary(edge_score, valid, geometry, settings)
        baseline = unindented_baseline(boundary, geometry)
        _, candidates, noise, threshold = indentation_candidates(boundary, baseline, edge_support, settings)
        if not candidates:
            state = "HOLD_NO_EXTERIOR_REFERENCED_INDENTATION"
        elif len(candidates) > 1 and float(candidates[1]["score"]) >= float(settings["ambiguityRatio"]) * float(candidates[0]["score"]):
            state = "HOLD_MULTIPLE_EXTERIOR_REFERENCED_INDENTATIONS"
        else:
            state = "EXTERIOR_REFERENCED_NOTCH_FOR_OPERATOR_REVIEW"
        for candidate in candidates:
            center_x = float(candidate["mouthCenterX"])
            center_index = int(round(center_x))
            tip_x = int(candidate["tipX"])
            candidate["mouthCenterAngleDegrees"] = absolute_angle(center_x, float(boundary[center_index]), 1000, float(item["inwardY"]), float(item["radiusPx"]), float(item["cropCenterAngleDegrees"]))
            candidate["tipAngleDegrees"] = absolute_angle(float(tip_x), float(boundary[tip_x]), 1000, float(item["inwardY"]), float(item["radiusPx"]), float(item["cropCenterAngleDegrees"]))
        enhanced_bgr, overlay, mask = review_layers(clean, enhanced, boundary, baseline, candidates, state)
        stem = str(item["id"]).lower().replace("-", "")
        names = {
            "clean": f"{stem}_clean.png",
            "enhanced": f"{stem}_enhanced.png",
            "overlay": f"{stem}_edge_overlay.png",
            "mask": f"{stem}_mask.png",
        }
        save_png(output_root / names["clean"], clean)
        save_png(output_root / names["enhanced"], enhanced_bgr)
        save_png(output_root / names["overlay"], overlay)
        save_png(output_root / names["mask"], mask)
        roundtrip = cv2.imread(str(output_root / names["clean"]), cv2.IMREAD_COLOR)
        ensure(roundtrip is not None and np.array_equal(roundtrip, clean), "Clean PNG changed pixels.")
        assets = {key: {"path": name, "sha256": file_hash(output_root / name)} for key, name in names.items()}
        result = {
            "id": str(item["id"]),
            "pairId": str(item["pairId"]),
            "channel": str(item["channel"]),
            "state": state,
            "source": {"path": str(item["path"]), "sha256": actual_hash},
            "localizationInput": "CLEAN_PIXELS_AND_CROP_TRANSFORM_WITHOUT_JSON_CANDIDATE_CENTER",
            "jsonCandidateCenterConsumed": False,
            "exteriorReference": exterior_metrics,
            "boundary": {
                "minimumY": float(np.min(boundary)),
                "maximumY": float(np.max(boundary)),
                "medianY": float(np.median(boundary)),
                "meanSupport": float(np.mean(edge_support)),
            },
            "depthNoisePx": noise,
            "detectionThresholdPx": threshold,
            "candidateCount": len(candidates),
            "candidates": candidates,
            "primary": candidates[0] if candidates else None,
            "assets": assets,
            "imageBytesEmittedToStdout": False,
        }
        results.append(result)
        by_id[result["id"]] = result

    pair_results: list[dict[str, Any]] = []
    for pair in job["pairs"]:
        bf = by_id[str(pair["bfInputId"])]
        df = by_id[str(pair["dfInputId"])]
        difference = None
        if bf["primary"] is None or df["primary"] is None:
            state = "HOLD_BF_DF_PRIMARY_MISSING"
        else:
            difference = angular_difference(float(bf["primary"]["mouthCenterAngleDegrees"]), float(df["primary"]["mouthCenterAngleDegrees"]))
            state = "BF_DF_EXTERIOR_NOTCH_AGREEMENT_FOR_OPERATOR_REVIEW" if difference <= float(settings["bfDfAgreementDegrees"]) else "HOLD_BF_DF_EXTERIOR_NOTCH_DISAGREEMENT"
        pair_results.append({
            "pairId": str(pair["pairId"]),
            "state": state,
            "absoluteCenterDifferenceDegrees": difference,
            "transformAveragingPerformed": False,
        })
    manifest = {
        "schema": "argos_ocv03_exterior_notch_manifest_v1",
        "revision": str(job["revision"]),
        "state": PASS_RESULT,
        "failedParentsReusable": False,
        "imageInputCount": len(results),
        "inputHashesMatched": True,
        "jsonCandidateCenterConsumed": False,
        "columnLocalExteriorReferenceUsed": True,
        "thresholdRelaxationPerformed": False,
        "settings": settings,
        "results": results,
        "pairs": pair_results,
        "assetFileCount": len(results) * 4,
        "sourceMutationPerformed": False,
        "detectorRerunPerformed": False,
        "providerActivated": False,
        "taskOrProcessActionPerformed": False,
        "protectedProcessorTouched": False,
        "holdCleared": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    manifest_path = output_root / "MANIFEST.json"
    new_json(manifest_path, manifest)
    return {
        "schema": "argos_ocv03_exterior_notch_command_result_v1",
        "state": PASS_RESULT,
        "manifest": str(manifest_path),
        "manifestSha256": file_hash(manifest_path),
        "imageInputCount": len(results),
        "assetFileCount": len(results) * 4,
        "imageBytesEmittedToStdout": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    job_path = Path(args.job).resolve()
    output_root = Path(args.output_root).resolve()
    job, _ = validate_job(job_path, output_root)
    if args.preflight:
        result = {
            "schema": "argos_ocv03_exterior_notch_preflight_v1",
            "state": PASS_PREFLIGHT,
            "revision": str(job["revision"]),
            "inputCount": len(job["inputs"]),
            "sourceImageBytesRead": False,
            "pixelsDecoded": False,
            "outputCreated": False,
            "jsonCandidateCenterConsumed": False,
            "reviewOnly": True,
            "productionRoutingEnabled": False,
        }
    else:
        result = run(job_path, output_root)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
