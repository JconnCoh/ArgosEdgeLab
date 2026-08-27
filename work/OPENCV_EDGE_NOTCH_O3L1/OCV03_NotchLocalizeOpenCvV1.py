#!/usr/bin/env python3
"""Localize a visible wafer notch in tangent/radial crops with OpenCV.

The old O3K1 renderer drew a center copied from detector JSON.  This provider
does not consume that center for localization.  It follows the physical
wafer/outside boundary, suppresses narrow and periodic die response, measures
inward boundary displacement, and emits review-only pixel evidence.
"""

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


JOB_SCHEMA = "argos_ocv03_notch_localization_job_v1"
MANIFEST_SCHEMA = "argos_ocv03_notch_localization_manifest_v1"
PASS_PREFLIGHT = "PASS_O3L1_NOTCH_LOCALIZER_PREFLIGHT"
PASS_RENDER = "PASS_O3L1_IMAGE_DERIVED_NOTCH_REVIEW_RENDERED"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_json(path: Path, maximum_bytes: int = 4 * 1024 * 1024) -> dict[str, Any]:
    require(path.is_file(), f"JSON file is absent: {path}")
    require(path.stat().st_size <= maximum_bytes, f"JSON file is too large: {path}")
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON root must be an object: {path}")
    return value


def atomic_write_json(path: Path, value: dict[str, Any]) -> None:
    partial = path.with_name(path.name + ".partial")
    require(not path.exists() and not partial.exists(), f"Create-new JSON exists: {path}")
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def is_under(path: Path, root: Path) -> bool:
    try:
        return os.path.commonpath([os.path.normcase(str(path)), os.path.normcase(str(root))]) == os.path.normcase(str(root))
    except ValueError:
        return False


def resolve_child(root: Path, relative_path: str) -> Path:
    require(relative_path and not os.path.isabs(relative_path), "Child path must be relative.")
    require("*" not in relative_path and "?" not in relative_path, "Child path contains a wildcard.")
    resolved = (root / relative_path).resolve()
    require(is_under(resolved, root.resolve()), "Child path escapes its root.")
    return resolved


def validate_path_budget(path: Path) -> None:
    for component in path.parts:
        require(len(component) <= 80, f"Path component exceeds 80 characters: {component}")
    require(len(str(path)) + 32 < 200, f"Path requires a short root before use: {path}")


def normalize_angle(angle: float) -> float:
    result = angle % 360.0
    return result + 360.0 if result < 0.0 else result


def angle_distance(first: float, second: float) -> float:
    return abs((first - second + 180.0) % 360.0 - 180.0)


def robust_unit(image: np.ndarray, valid: np.ndarray | None = None) -> np.ndarray:
    values = image[valid] if valid is not None else image.reshape(-1)
    values = values[np.isfinite(values)]
    require(values.size > 0, "Robust normalization population is empty.")
    low = float(np.percentile(values, 5.0))
    high = float(np.percentile(values, 97.0))
    scale = max(high - low, 1.0e-6)
    return np.clip((image - low) / scale, 0.0, 1.0).astype(np.float32)


def expected_perimeter(width: int, inward_y: float, radius: float) -> np.ndarray:
    tangent = np.arange(width, dtype=np.float64) - (width - 1.0) / 2.0
    inside = np.maximum(radius * radius - tangent * tangent, 0.0)
    return (inward_y + np.sqrt(inside) - radius).astype(np.float32)


def build_boundary_score(gray: np.ndarray, expected: np.ndarray, config: dict[str, Any]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    height, width = gray.shape
    enhanced = cv2.createCLAHE(
        clipLimit=float(config["claheClipLimit"]),
        tileGridSize=(int(config["claheTileSize"]), int(config["claheTileSize"])),
    ).apply(gray)

    # Long tangential blur attenuates periodic die/grid structure.  Boundary
    # evidence is then required to separate textured wafer material above from
    # a flatter outside region below, which internal die lines do not do.
    smooth = cv2.GaussianBlur(
        enhanced.astype(np.float32),
        (0, 0),
        sigmaX=float(config["tangentialBlurSigma"]),
        sigmaY=float(config["radialBlurSigma"]),
        borderType=cv2.BORDER_REFLECT101,
    )
    fine = cv2.GaussianBlur(
        enhanced.astype(np.float32),
        (0, 0),
        sigmaX=2.0,
        sigmaY=1.2,
        borderType=cv2.BORDER_REFLECT101,
    )
    gradient = np.abs(cv2.Scharr(smooth, cv2.CV_32F, 0, 1))
    local_mean = cv2.boxFilter(fine, cv2.CV_32F, (9, 13), normalize=True, borderType=cv2.BORDER_REFLECT101)
    high_pass = np.abs(fine - cv2.GaussianBlur(fine, (0, 0), 3.0))
    texture = cv2.boxFilter(high_pass, cv2.CV_32F, (11, 13), normalize=True, borderType=cv2.BORDER_REFLECT101)

    offset = int(config["regionOffsetPx"])
    rows = np.arange(height, dtype=np.int32)
    above_rows = np.clip(rows - offset, 0, height - 1)
    below_rows = np.clip(rows + offset, 0, height - 1)
    mean_above = local_mean[above_rows, :]
    mean_below = local_mean[below_rows, :]
    texture_above = texture[above_rows, :]
    texture_below = texture[below_rows, :]

    intensity_step = np.abs(mean_above - mean_below)
    texture_drop = np.maximum(texture_above - texture_below, 0.0)

    max_inward = int(config["maximumInwardExcursionPx"])
    max_outward = int(config["maximumOutwardExcursionPx"])
    yy = np.arange(height, dtype=np.float32)[:, None]
    valid = (yy >= (expected[None, :] - max_inward)) & (yy <= (expected[None, :] + max_outward))

    gradient_unit = robust_unit(gradient, valid)
    step_unit = robust_unit(intensity_step, valid)
    drop_unit = robust_unit(texture_drop, valid)
    outside_texture_unit = robust_unit(texture_below, valid)
    outside_flatness = 1.0 - outside_texture_unit
    score = (
        0.32 * gradient_unit
        + 0.25 * step_unit
        + 0.31 * drop_unit
        + 0.12 * outside_flatness
    )
    score[~valid] = 0.0
    return score.astype(np.float32), enhanced, valid


def trace_boundary(score: np.ndarray, valid: np.ndarray, expected: np.ndarray, config: dict[str, Any]) -> tuple[np.ndarray, np.ndarray]:
    height, width = score.shape
    max_step = int(config["maximumBoundaryStepPx"])
    step_penalty = float(config["boundaryStepPenalty"])
    prior_penalty = float(config["expectedPerimeterPenalty"])
    yy = np.arange(height, dtype=np.float32)[:, None]
    data_cost = -score + prior_penalty * np.abs(yy - expected[None, :])
    data_cost[~valid] = 1.0e6

    accumulated = np.full((height, width), 1.0e12, dtype=np.float64)
    back = np.zeros((height, width), dtype=np.int16)
    accumulated[:, 0] = data_cost[:, 0]
    for x in range(1, width):
        previous = accumulated[:, x - 1]
        best = np.full(height, 1.0e12, dtype=np.float64)
        best_delta = np.zeros(height, dtype=np.int16)
        for delta in range(-max_step, max_step + 1):
            shifted = np.full(height, 1.0e12, dtype=np.float64)
            if delta < 0:
                shifted[:delta] = previous[-delta:]
            elif delta > 0:
                shifted[delta:] = previous[:-delta]
            else:
                shifted[:] = previous
            candidate = shifted + step_penalty * abs(delta)
            take = candidate < best
            best[take] = candidate[take]
            best_delta[take] = delta
        accumulated[:, x] = data_cost[:, x] + best
        back[:, x] = best_delta

    seam = np.zeros(width, dtype=np.int32)
    seam[-1] = int(np.argmin(accumulated[:, -1]))
    for x in range(width - 1, 0, -1):
        seam[x - 1] = seam[x] - int(back[seam[x], x])
    seam_float = cv2.medianBlur(seam.astype(np.float32).reshape(1, -1), 5).reshape(-1)
    seam_float = cv2.GaussianBlur(seam_float.reshape(1, -1), (0, 0), sigmaX=1.2).reshape(-1)
    indices = np.clip(np.rint(seam_float).astype(np.int32), 0, height - 1)
    confidence = score[indices, np.arange(width)]
    return seam_float.astype(np.float32), confidence.astype(np.float32)


def robust_baseline(seam: np.ndarray, expected: np.ndarray) -> np.ndarray:
    width = seam.size
    x = np.linspace(-1.0, 1.0, width, dtype=np.float64)
    design = np.column_stack((np.ones(width), x, x * x))
    residual_from_geometry = seam.astype(np.float64) - expected.astype(np.float64)
    weights = np.ones(width, dtype=np.float64)
    beta = np.zeros(3, dtype=np.float64)
    for _ in range(10):
        weighted_design = design * weights[:, None]
        beta = np.linalg.lstsq(weighted_design, residual_from_geometry * weights, rcond=None)[0]
        error = residual_from_geometry - design @ beta
        center = float(np.median(error))
        scale = max(1.4826 * float(np.median(np.abs(error - center))), 0.35)
        normalized = np.abs((error - center) / (4.685 * scale))
        weights = np.square(np.maximum(0.0, 1.0 - normalized * normalized))
        # A notch is a negative residual.  Do not let a deep indentation pull
        # the unindented perimeter baseline inward.
        weights[error < center - 2.5 * scale] *= 0.08
        weights = np.maximum(weights, 1.0e-4)
    return (expected.astype(np.float64) + design @ beta).astype(np.float32)


def contiguous_regions(binary: np.ndarray) -> list[tuple[int, int]]:
    padded = np.pad(binary.astype(np.int8), (1, 1))
    changes = np.diff(padded)
    starts = np.flatnonzero(changes == 1)
    ends = np.flatnonzero(changes == -1) - 1
    return [(int(left), int(right)) for left, right in zip(starts, ends)]


def detect_indentations(
    seam: np.ndarray,
    baseline: np.ndarray,
    confidence: np.ndarray,
    config: dict[str, Any],
) -> tuple[np.ndarray, list[dict[str, Any]], float, float]:
    depth = baseline - seam
    depth = cv2.GaussianBlur(depth.reshape(1, -1), (0, 0), sigmaX=2.0).reshape(-1)
    kernel_width = int(config["diePatternSuppressionWidthPx"])
    if kernel_width % 2 == 0:
        kernel_width += 1
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (kernel_width, 1))
    shape_depth = cv2.morphologyEx(depth.astype(np.float32).reshape(1, -1), cv2.MORPH_OPEN, kernel).reshape(-1)
    shape_depth = cv2.GaussianBlur(shape_depth.reshape(1, -1), (0, 0), sigmaX=3.0).reshape(-1)

    center = float(np.median(shape_depth))
    noise = max(1.4826 * float(np.median(np.abs(shape_depth - center))), 0.5)
    threshold = max(float(config["minimumNotchDepthPx"]), center + float(config["noiseSigmaThreshold"]) * noise)
    active = (shape_depth >= threshold).astype(np.uint8).reshape(1, -1)
    active = cv2.morphologyEx(
        active,
        cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_RECT, (int(config["candidateJoinWidthPx"]), 1)),
    ).reshape(-1).astype(bool)

    candidates: list[dict[str, Any]] = []
    for coarse_left, coarse_right in contiguous_regions(active):
        if coarse_right - coarse_left + 1 < int(config["minimumNotchWidthPx"]):
            continue
        tip_x = coarse_left + int(np.argmax(shape_depth[coarse_left : coarse_right + 1]))
        peak = float(shape_depth[tip_x])
        mouth_level = max(float(config["minimumNotchDepthPx"]) * 0.45, center + 2.0 * noise, peak * 0.18)
        left = tip_x
        right = tip_x
        while left > 1 and shape_depth[left - 1] >= mouth_level:
            left -= 1
        while right < shape_depth.size - 2 and shape_depth[right + 1] >= mouth_level:
            right += 1
        width = right - left + 1
        if width < int(config["minimumNotchWidthPx"]):
            continue
        center_x = (left + right) / 2.0
        support = float(np.mean(confidence[left : right + 1]))
        area = float(np.sum(np.maximum(shape_depth[left : right + 1] - mouth_level, 0.0)))
        score = peak * math.sqrt(float(width)) * max(support, 0.05) + 0.05 * area
        candidates.append(
            {
                "leftX": int(left),
                "rightX": int(right),
                "centerX": float(center_x),
                "tipX": int(tip_x),
                "widthPx": int(width),
                "peakDepthPx": peak,
                "mouthLevelPx": float(mouth_level),
                "boundarySupport": support,
                "shapeAreaPx2": area,
                "score": float(score),
            }
        )
    candidates.sort(key=lambda row: (-float(row["score"]), int(row["leftX"])))
    return shape_depth.astype(np.float32), candidates, float(noise), float(threshold)


def local_x_to_angle(x: float, boundary_y: float, width: int, inward_y: float, radius: float, crop_angle: float) -> float:
    tangent = x - (width - 1.0) / 2.0
    absolute_radius = radius + (boundary_y - inward_y)
    return normalize_angle(crop_angle + math.degrees(math.atan2(tangent, absolute_radius)))


def write_png(path: Path, image: np.ndarray) -> None:
    require(not path.exists(), f"Create-new PNG exists: {path}")
    require(bool(cv2.imwrite(str(path), image, [cv2.IMWRITE_PNG_COMPRESSION, 6])), f"OpenCV failed to write: {path}")


def render_assets(
    clean: np.ndarray,
    enhanced_gray: np.ndarray,
    seam: np.ndarray,
    baseline: np.ndarray,
    candidates: list[dict[str, Any]],
    state: str,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    height, width = enhanced_gray.shape
    enhanced = cv2.cvtColor(enhanced_gray, cv2.COLOR_GRAY2BGR)
    overlay = enhanced.copy()
    mask = np.zeros((height, width), dtype=np.uint8)

    boundary_points = np.column_stack((np.arange(width), np.rint(seam).astype(np.int32)))
    baseline_points = np.column_stack((np.arange(width), np.rint(baseline).astype(np.int32)))
    cv2.polylines(overlay, [baseline_points.reshape(-1, 1, 2)], False, (0, 180, 0), 2, cv2.LINE_8)
    cv2.polylines(mask, [baseline_points.reshape(-1, 1, 2)], False, 255, 2, cv2.LINE_8)
    cv2.polylines(overlay, [boundary_points.reshape(-1, 1, 2)], False, (255, 255, 0), 3, cv2.LINE_8)
    cv2.polylines(mask, [boundary_points.reshape(-1, 1, 2)], False, 255, 3, cv2.LINE_8)

    for rank, candidate in enumerate(candidates[:3], start=1):
        left = int(candidate["leftX"])
        right = int(candidate["rightX"])
        center_x = int(round(float(candidate["centerX"])))
        tip_x = int(candidate["tipX"])
        color = (0, 0, 255) if rank == 1 else (0, 128, 255)
        thickness = 3 if rank == 1 else 2
        for x in (left, right):
            cv2.line(overlay, (x, max(0, int(baseline[x]) - 25)), (x, min(height - 1, int(baseline[x]) + 25)), (0, 220, 220), 2, cv2.LINE_8)
            cv2.line(mask, (x, max(0, int(baseline[x]) - 25)), (x, min(height - 1, int(baseline[x]) + 25)), 255, 2, cv2.LINE_8)
        cv2.line(overlay, (center_x, 0), (center_x, height - 1), color, thickness, cv2.LINE_8)
        cv2.line(mask, (center_x, 0), (center_x, height - 1), 255, thickness, cv2.LINE_8)
        cv2.drawMarker(overlay, (tip_x, int(round(seam[tip_x]))), (255, 0, 255), cv2.MARKER_CROSS, 18, 3, cv2.LINE_8)
        cv2.drawMarker(mask, (tip_x, int(round(seam[tip_x]))), 255, cv2.MARKER_CROSS, 18, 3, cv2.LINE_8)

    label = "RED: image-derived notch mouth center | CYAN: traced physical edge | GREEN: unindented baseline"
    cv2.rectangle(overlay, (0, 0), (width - 1, 31), (0, 0, 0), cv2.FILLED)
    cv2.rectangle(mask, (0, 0), (width - 1, 31), 255, cv2.FILLED)
    cv2.putText(overlay, label, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.48, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, label, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.48, 255, 1, cv2.LINE_8)
    cv2.putText(overlay, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.52, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.52, 255, 1, cv2.LINE_8)

    changed = np.any(overlay != enhanced, axis=2)
    mask_pixels = mask > 0
    require(int(np.count_nonzero(changed)) > 0, "Overlay changed no pixels.")
    require(int(np.count_nonzero(changed & ~mask_pixels)) == 0, "Overlay changed pixels outside its current mask.")
    return enhanced, overlay, mask


def validate_job(job_path: Path, output_root: Path) -> tuple[dict[str, Any], Path]:
    job = load_json(job_path)
    require(job.get("schema") == JOB_SCHEMA, "Job schema changed.")
    require(bool(job.get("reviewOnly")), "Job must remain review-only.")
    for field in ("trainingEligible", "xmlEligible", "productionEligible", "productionRoutingEnabled", "liveProviderActivation", "detectorRerun", "sourceMutation"):
        require(not bool(job.get(field)), f"Forbidden authority changed: {field}")
    require(job.get("detectionInput") == "CLEAN_CROP_PIXELS_ONLY", "Detection input changed.")
    require(not bool(job.get("frozenJsonCandidateCenterConsumed")), "Frozen JSON candidate center cannot be detection input.")

    source_root = (job_path.parent / str(job.get("sourceRootRelativeToJob", ""))).resolve()
    require(source_root.is_dir(), "Source root is absent.")
    require(output_root.is_absolute(), "Output root must be absolute.")
    validate_path_budget(output_root)
    inputs = list(job.get("inputs", []))
    require(len(inputs) == 6, "Exactly six clean crop inputs are required.")
    expected_ids = {"S16-C1-BF", "S16-C1-DF", "S17-C1-BF", "S17-C1-DF", "S17-C2-BF", "S17-C2-DF"}
    require({str(row.get("id", "")) for row in inputs} == expected_ids, "Input identity set changed.")
    for row in inputs:
        path = resolve_child(source_root, str(row.get("path", "")))
        require(path.is_file(), f"Input is absent: {path}")
        validate_path_budget(path)
        require(len(str(row.get("sha256", ""))) == 64, "Input SHA-256 is invalid.")
        require(int(row.get("widthPx", 0)) == 1000 and int(row.get("heightPx", 0)) == 600, "Input dimensions changed.")
        require(float(row.get("radiusPx", 0.0)) > 1000.0, "Crop radius is invalid.")
        require(int(row.get("inwardY", 0)) == 420, "Crop inward coordinate changed.")
    pairs = list(job.get("pairs", []))
    require(len(pairs) == 3, "Exactly three BF/DF pairs are required.")
    require({str(row.get("pairId", "")) for row in pairs} == {"S16-C1", "S17-C1", "S17-C2"}, "Pair identity set changed.")
    config = job.get("algorithm")
    require(isinstance(config, dict), "Algorithm configuration is absent.")
    required_config = (
        "claheClipLimit", "claheTileSize", "tangentialBlurSigma", "radialBlurSigma", "regionOffsetPx",
        "maximumInwardExcursionPx", "maximumOutwardExcursionPx", "maximumBoundaryStepPx", "boundaryStepPenalty",
        "expectedPerimeterPenalty", "diePatternSuppressionWidthPx", "minimumNotchDepthPx", "noiseSigmaThreshold",
        "candidateJoinWidthPx", "minimumNotchWidthPx", "ambiguityScoreRatio", "bfDfAgreementDegrees",
    )
    for name in required_config:
        require(name in config, f"Algorithm configuration omitted {name}.")
    return job, source_root


def process(job_path: Path, output_root: Path) -> dict[str, Any]:
    job, source_root = validate_job(job_path, output_root)
    require(not output_root.exists(), "Output root must be create-new.")
    output_root.mkdir(parents=False)
    rows: list[dict[str, Any]] = []
    row_by_id: dict[str, dict[str, Any]] = {}
    config = job["algorithm"]

    for source in sorted(job["inputs"], key=lambda row: str(row["id"])):
        source_path = resolve_child(source_root, str(source["path"]))
        actual_hash = sha256_file(source_path)
        require(actual_hash == str(source["sha256"]).upper(), f"Input SHA-256 changed: {source_path}")
        clean = cv2.imread(str(source_path), cv2.IMREAD_COLOR)
        require(clean is not None and clean.shape == (600, 1000, 3), f"OpenCV decode/dimensions changed: {source_path}")
        gray = cv2.cvtColor(clean, cv2.COLOR_BGR2GRAY)
        expected = expected_perimeter(clean.shape[1], float(source["inwardY"]), float(source["radiusPx"]))
        boundary_score, enhanced_gray, valid = build_boundary_score(gray, expected, config)
        seam, confidence = trace_boundary(boundary_score, valid, expected, config)
        baseline = robust_baseline(seam, expected)
        depth, candidates, noise, threshold = detect_indentations(seam, baseline, confidence, config)

        if not candidates:
            state = "HOLD_NO_IMAGE_DERIVED_NOTCH"
        elif len(candidates) > 1 and float(candidates[1]["score"]) >= float(config["ambiguityScoreRatio"]) * float(candidates[0]["score"]):
            state = "HOLD_MULTIPLE_IMAGE_DERIVED_INDENTATIONS"
        else:
            state = "IMAGE_DERIVED_NOTCH_PRIMARY_FOR_OPERATOR_REVIEW"

        for candidate in candidates:
            center_x = float(candidate["centerX"])
            tip_x = int(candidate["tipX"])
            center_index = int(round(center_x))
            candidate["centerAngleDegrees"] = local_x_to_angle(
                center_x,
                float(seam[center_index]),
                clean.shape[1],
                float(source["inwardY"]),
                float(source["radiusPx"]),
                float(source["cropCenterAngleDegrees"]),
            )
            candidate["tipAngleDegrees"] = local_x_to_angle(
                float(tip_x),
                float(seam[tip_x]),
                clean.shape[1],
                float(source["inwardY"]),
                float(source["radiusPx"]),
                float(source["cropCenterAngleDegrees"]),
            )

        enhanced, overlay, mask = render_assets(clean, enhanced_gray, seam, baseline, candidates, state)
        stem = str(source["id"]).lower().replace("-", "")
        clean_name = f"{stem}_clean.png"
        enhanced_name = f"{stem}_enhanced.png"
        overlay_name = f"{stem}_edge_overlay.png"
        mask_name = f"{stem}_mask.png"
        write_png(output_root / clean_name, clean)
        write_png(output_root / enhanced_name, enhanced)
        write_png(output_root / overlay_name, overlay)
        write_png(output_root / mask_name, mask)
        clean_roundtrip = cv2.imread(str(output_root / clean_name), cv2.IMREAD_COLOR)
        require(clean_roundtrip is not None and np.array_equal(clean_roundtrip, clean), "Clean PNG round-trip changed pixels.")

        row = {
            "id": str(source["id"]),
            "pairId": str(source["pairId"]),
            "channel": str(source["channel"]),
            "state": state,
            "source": {"path": str(source["path"]), "sha256": actual_hash},
            "detectionInput": "CLEAN_CROP_PIXELS_ONLY",
            "frozenJsonCandidateCenterConsumed": False,
            "diePatternSuppression": "TANGENTIAL_BLUR_PLUS_WAFER_TO_OUTSIDE_TEXTURE_DROP_PLUS_1D_MORPHOLOGICAL_OPEN",
            "boundary": {
                "meanSupport": float(np.mean(confidence)),
                "minimumY": float(np.min(seam)),
                "maximumY": float(np.max(seam)),
                "medianY": float(np.median(seam)),
            },
            "depthNoisePx": noise,
            "detectionThresholdPx": threshold,
            "candidateCount": len(candidates),
            "candidates": candidates,
            "primary": candidates[0] if candidates else None,
            "assets": {
                "clean": {"path": clean_name, "sha256": sha256_file(output_root / clean_name)},
                "enhanced": {"path": enhanced_name, "sha256": sha256_file(output_root / enhanced_name)},
                "overlay": {"path": overlay_name, "sha256": sha256_file(output_root / overlay_name)},
                "mask": {"path": mask_name, "sha256": sha256_file(output_root / mask_name)},
            },
            "imageBytesEmittedToStdout": False,
        }
        rows.append(row)
        row_by_id[row["id"]] = row

    pair_rows: list[dict[str, Any]] = []
    for pair in job["pairs"]:
        bf = row_by_id[str(pair["bfInputId"])]
        df = row_by_id[str(pair["dfInputId"])]
        if bf["primary"] is None or df["primary"] is None:
            state = "HOLD_BF_DF_NOTCH_MISSING"
            difference = None
        else:
            difference = angle_distance(float(bf["primary"]["centerAngleDegrees"]), float(df["primary"]["centerAngleDegrees"]))
            state = "BF_DF_IMAGE_DERIVED_CENTER_AGREEMENT_FOR_OPERATOR_REVIEW" if difference <= float(config["bfDfAgreementDegrees"]) else "HOLD_BF_DF_IMAGE_DERIVED_CENTER_DISAGREEMENT"
        pair_rows.append(
            {
                "pairId": str(pair["pairId"]),
                "bfInputId": str(pair["bfInputId"]),
                "dfInputId": str(pair["dfInputId"]),
                "state": state,
                "absoluteCenterDifferenceDegrees": difference,
                "transformAveragingPerformed": False,
            }
        )

    manifest = {
        "schema": MANIFEST_SCHEMA,
        "revision": str(job["revision"]),
        "state": PASS_RENDER,
        "failedParentReviewId": str(job["failedParentReviewId"]),
        "failedParentReusable": False,
        "imageInputCount": len(rows),
        "inputHashesMatched": True,
        "frozenJsonCandidateCenterConsumed": False,
        "imageDerivedLocalizationPerformed": True,
        "bfDfTransformsAveraged": False,
        "algorithm": config,
        "results": rows,
        "pairs": pair_rows,
        "assetFileCount": len(rows) * 4,
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
    atomic_write_json(manifest_path, manifest)
    return {
        "schema": "argos_ocv03_notch_localization_command_result_v1",
        "state": PASS_RENDER,
        "manifest": str(manifest_path),
        "manifestSha256": sha256_file(manifest_path),
        "assetFileCount": len(rows) * 4,
        "imageInputCount": len(rows),
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
            "schema": "argos_ocv03_notch_localizer_preflight_v1",
            "state": PASS_PREFLIGHT,
            "revision": str(job["revision"]),
            "inputCount": len(job["inputs"]),
            "sourceImageBytesRead": False,
            "pixelsDecoded": False,
            "outputCreated": False,
            "frozenJsonCandidateCenterConsumed": False,
            "reviewOnly": True,
            "productionRoutingEnabled": False,
        }
    else:
        result = process(job_path, output_root)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
