#!/usr/bin/env python3
"""Hard exterior-eligibility notch localizer for review-only tangent crops."""

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


JOB_SCHEMA = "argos_ocv03_hard_exterior_notch_job_v1"
PASS_PREFLIGHT = "PASS_O3L3_HARD_EXTERIOR_PREFLIGHT"
PASS_RENDER = "PASS_O3L3_HARD_EXTERIOR_NOTCH_REVIEW"


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for data in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(data)
    return digest.hexdigest().upper()


def json_object(path: Path) -> dict[str, Any]:
    require(path.is_file() and path.stat().st_size <= 4 * 1024 * 1024, f"Invalid JSON: {path}")
    result = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(result, dict), "JSON root must be an object.")
    return result


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    partial = path.with_name(path.name + ".partial")
    require(not path.exists() and not partial.exists(), f"Create-new collision: {path}")
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def safe_child(root: Path, name: str) -> Path:
    require(name and not os.path.isabs(name) and "*" not in name and "?" not in name, "Unsafe child path.")
    path = (root / name).resolve()
    require(os.path.commonpath([os.path.normcase(str(root.resolve())), os.path.normcase(str(path))]) == os.path.normcase(str(root.resolve())), "Child escapes root.")
    return path


def check_path(path: Path) -> None:
    require(len(str(path)) + 32 < 200, f"Path needs a short root: {path}")
    require(all(len(part) <= 80 for part in path.parts), f"Path component is too long: {path}")


def geometric_edge(width: int, inward_y: float, radius: float) -> np.ndarray:
    tangent = np.arange(width, dtype=np.float64) - (width - 1.0) / 2.0
    return (inward_y + np.sqrt(np.maximum(radius * radius - tangent * tangent, 0.0)) - radius).astype(np.float32)


def hard_exterior_boundary(gray: np.ndarray, geometry: np.ndarray, config: dict[str, Any]) -> tuple[np.ndarray, np.ndarray, np.ndarray, dict[str, Any]]:
    height, width = gray.shape
    enhanced = cv2.createCLAHE(
        clipLimit=float(config["claheClipLimit"]),
        tileGridSize=(int(config["claheGrid"]), int(config["claheGrid"])),
    ).apply(gray)
    pixels = cv2.GaussianBlur(enhanced.astype(np.float32), (0, 0), 2.0, 1.0, borderType=cv2.BORDER_REFLECT101)
    start, end = int(config["exteriorStartY"]), int(config["exteriorEndY"])
    exterior = pixels[start:end, :]
    level = np.median(exterior, axis=0).astype(np.float32)
    level = cv2.GaussianBlur(level.reshape(1, -1), (0, 0), sigmaX=15.0).reshape(-1)
    mad = np.median(np.abs(exterior - level[None, :]), axis=0).astype(np.float32)
    scale = np.maximum(1.4826 * mad, float(config["minimumExteriorScale"]))
    distance = np.minimum(np.abs(pixels - level[None, :]) / scale[None, :], 16.0).astype(np.float32)

    window = int(config["transitionWindowPx"])
    mean_distance = cv2.boxFilter(distance, cv2.CV_32F, (7, window), normalize=True, borderType=cv2.BORDER_REFLECT101)
    offset = int(config["transitionOffsetPx"])
    rows = np.arange(height, dtype=np.int32)
    above_rows = np.clip(rows - offset, 0, height - 1)
    below_rows = np.clip(rows + offset, 0, height - 1)
    above = mean_distance[above_rows, :]
    below = mean_distance[below_rows, :]
    transition = above - below

    smooth = cv2.GaussianBlur(pixels, (0, 0), float(config["tangentialSigma"]), 2.0, borderType=cv2.BORDER_REFLECT101)
    gradient = np.abs(cv2.Scharr(smooth, cv2.CV_32F, 0, 1))
    gradient_scale = max(float(np.percentile(gradient, 97.0)), 1.0)
    gradient_unit = np.clip(gradient / gradient_scale, 0.0, 1.0)
    score = transition + float(config["gradientWeight"]) * gradient_unit

    yy = np.arange(height, dtype=np.float32)[:, None]
    geometry_band = (
        (yy >= geometry[None, :] - int(config["maximumInwardPx"]))
        & (yy <= geometry[None, :] + int(config["maximumOutwardPx"]))
    )
    exterior_eligible = (
        (below <= float(config["maximumBelowExteriorDistance"]))
        & (above >= float(config["minimumAboveExteriorDistance"]))
        & (transition >= float(config["minimumDirectedTransition"]))
    )
    eligible = geometry_band & exterior_eligible

    raw = np.full(width, np.nan, dtype=np.float32)
    raw_support = np.zeros(width, dtype=np.float32)
    penalty = float(config["geometryPenalty"])
    for x in range(width):
        rows_x = np.flatnonzero(eligible[:, x])
        if rows_x.size == 0:
            continue
        values = score[rows_x, x] - penalty * np.abs(rows_x.astype(np.float32) - geometry[x])
        winner = int(rows_x[int(np.argmax(values))])
        raw[x] = float(winner)
        raw_support[x] = float(score[winner, x])

    observed = np.isfinite(raw)
    coverage = float(np.mean(observed))
    require(np.count_nonzero(observed) >= 2, "Hard exterior boundary has insufficient eligible columns.")
    x_all = np.arange(width, dtype=np.float32)
    observed_x = x_all[observed]
    interpolated = np.interp(x_all, observed_x, raw[observed]).astype(np.float32)
    support = np.interp(x_all, observed_x, raw_support[observed]).astype(np.float32)

    missing_runs = contiguous(~observed)
    longest_gap = max((right - left + 1 for left, right in missing_runs), default=0)
    boundary = cv2.medianBlur(interpolated.reshape(1, -1), 9).reshape(-1)
    boundary = cv2.GaussianBlur(boundary.reshape(1, -1), (0, 0), sigmaX=1.5).reshape(-1)
    evidence = {
        "observedColumnCount": int(np.count_nonzero(observed)),
        "coverageFraction": coverage,
        "longestInterpolatedGapPx": int(longest_gap),
        "medianExteriorLevel": float(np.median(level)),
        "medianExteriorMad": float(np.median(mad)),
        "hardEligibilityApplied": True,
    }
    return boundary.astype(np.float32), support.astype(np.float32), enhanced, evidence


def robust_unindented_edge(boundary: np.ndarray, geometry: np.ndarray) -> np.ndarray:
    count = boundary.size
    x = np.linspace(-1.0, 1.0, count, dtype=np.float64)
    design = np.column_stack((np.ones(count), x, x * x))
    target = boundary.astype(np.float64) - geometry.astype(np.float64)
    weights = np.ones(count, dtype=np.float64)
    beta = np.zeros(3, dtype=np.float64)
    for _ in range(12):
        beta = np.linalg.lstsq(design * weights[:, None], target * weights, rcond=None)[0]
        error = target - design @ beta
        middle = float(np.median(error))
        sigma = max(1.4826 * float(np.median(np.abs(error - middle))), 0.35)
        normalized = np.abs((error - middle) / (4.685 * sigma))
        weights = np.square(np.maximum(0.0, 1.0 - normalized * normalized))
        weights[error < middle - 2.2 * sigma] *= 0.02
        weights = np.maximum(weights, 1.0e-4)
    return (geometry + design @ beta).astype(np.float32)


def contiguous(mask: np.ndarray) -> list[tuple[int, int]]:
    changes = np.diff(np.pad(mask.astype(np.int8), (1, 1)))
    return [(int(left), int(right - 1)) for left, right in zip(np.flatnonzero(changes == 1), np.flatnonzero(changes == -1))]


def find_notches(boundary: np.ndarray, baseline: np.ndarray, support: np.ndarray, config: dict[str, Any]) -> tuple[list[dict[str, Any]], float, float]:
    depth = baseline - boundary
    depth = cv2.GaussianBlur(depth.reshape(1, -1), (0, 0), sigmaX=2.0).reshape(-1)
    width = int(config["patternSuppressionWidthPx"])
    if width % 2 == 0:
        width += 1
    depth = cv2.morphologyEx(
        depth.astype(np.float32).reshape(1, -1),
        cv2.MORPH_OPEN,
        cv2.getStructuringElement(cv2.MORPH_RECT, (width, 1)),
    ).reshape(-1)
    depth = cv2.GaussianBlur(depth.reshape(1, -1), (0, 0), sigmaX=3.0).reshape(-1)
    center = float(np.median(depth))
    noise = max(1.4826 * float(np.median(np.abs(depth - center))), 0.5)
    threshold = max(float(config["minimumNotchDepthPx"]), center + float(config["noiseSigmaThreshold"]) * noise)
    active = (depth >= threshold).astype(np.uint8).reshape(1, -1)
    active = cv2.morphologyEx(active, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_RECT, (int(config["candidateJoinWidthPx"]), 1))).reshape(-1).astype(bool)
    candidates: list[dict[str, Any]] = []
    for initial_left, initial_right in contiguous(active):
        if initial_right - initial_left + 1 < int(config["minimumNotchWidthPx"]):
            continue
        tip = initial_left + int(np.argmax(depth[initial_left : initial_right + 1]))
        peak = float(depth[tip])
        mouth_level = max(0.45 * float(config["minimumNotchDepthPx"]), center + 2.0 * noise, 0.18 * peak)
        left, right = tip, tip
        while left > 1 and depth[left - 1] >= mouth_level:
            left -= 1
        while right < depth.size - 2 and depth[right + 1] >= mouth_level:
            right += 1
        span = right - left + 1
        if span < int(config["minimumNotchWidthPx"]):
            continue
        mouth_center = 0.5 * (left + right)
        edge_support = float(np.mean(support[left : right + 1]))
        score = peak * math.sqrt(span) * max(edge_support, 0.05)
        candidates.append({
            "leftX": left,
            "rightX": right,
            "mouthCenterX": mouth_center,
            "tipX": tip,
            "widthPx": span,
            "peakDepthPx": peak,
            "mouthLevelPx": mouth_level,
            "edgeSupport": edge_support,
            "score": score,
        })
    candidates.sort(key=lambda row: (-float(row["score"]), int(row["leftX"])))
    return candidates, noise, threshold


def to_angle(x: float, y: float, width: int, inward_y: float, radius: float, crop_angle: float) -> float:
    tangent = x - (width - 1.0) / 2.0
    return (crop_angle + math.degrees(math.atan2(tangent, radius + y - inward_y))) % 360.0


def angle_gap(first: float, second: float) -> float:
    return abs((first - second + 180.0) % 360.0 - 180.0)


def save_png(path: Path, pixels: np.ndarray) -> None:
    require(not path.exists(), f"Create-new PNG collision: {path}")
    require(bool(cv2.imwrite(str(path), pixels, [cv2.IMWRITE_PNG_COMPRESSION, 6])), f"PNG write failed: {path}")


def overlay_images(enhanced: np.ndarray, boundary: np.ndarray, baseline: np.ndarray, candidates: list[dict[str, Any]], state: str) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    height, width = enhanced.shape
    base = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    overlay = base.copy()
    mask = np.zeros((height, width), dtype=np.uint8)
    base_line = np.column_stack((np.arange(width), np.rint(baseline).astype(np.int32))).reshape(-1, 1, 2)
    edge_line = np.column_stack((np.arange(width), np.rint(boundary).astype(np.int32))).reshape(-1, 1, 2)
    cv2.polylines(overlay, [base_line], False, (0, 190, 0), 2, cv2.LINE_8)
    cv2.polylines(mask, [base_line], False, 255, 2, cv2.LINE_8)
    cv2.polylines(overlay, [edge_line], False, (255, 255, 0), 3, cv2.LINE_8)
    cv2.polylines(mask, [edge_line], False, 255, 3, cv2.LINE_8)
    for rank, candidate in enumerate(candidates[:3]):
        left, right = int(candidate["leftX"]), int(candidate["rightX"])
        center = int(round(float(candidate["mouthCenterX"])))
        tip = int(candidate["tipX"])
        color = (0, 0, 255) if rank == 0 else (0, 135, 255)
        for x in (left, right):
            cv2.line(overlay, (x, max(0, int(baseline[x]) - 26)), (x, min(height - 1, int(baseline[x]) + 26)), (0, 220, 220), 2, cv2.LINE_8)
            cv2.line(mask, (x, max(0, int(baseline[x]) - 26)), (x, min(height - 1, int(baseline[x]) + 26)), 255, 2, cv2.LINE_8)
        cv2.line(overlay, (center, 0), (center, height - 1), color, 3 if rank == 0 else 2, cv2.LINE_8)
        cv2.line(mask, (center, 0), (center, height - 1), 255, 3 if rank == 0 else 2, cv2.LINE_8)
        cv2.drawMarker(overlay, (tip, int(round(boundary[tip]))), (255, 0, 255), cv2.MARKER_CROSS, 18, 3, cv2.LINE_8)
        cv2.drawMarker(mask, (tip, int(round(boundary[tip]))), 255, cv2.MARKER_CROSS, 18, 3, cv2.LINE_8)
    legend = "RED notch mouth center | MAGENTA tip | CYAN physical edge | GREEN unindented edge"
    cv2.rectangle(overlay, (0, 0), (width - 1, 31), (0, 0, 0), cv2.FILLED)
    cv2.rectangle(mask, (0, 0), (width - 1, 31), 255, cv2.FILLED)
    cv2.putText(overlay, legend, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.49, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, legend, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.49, 255, 1, cv2.LINE_8)
    cv2.putText(overlay, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, 255, 1, cv2.LINE_8)
    changed = np.any(overlay != base, axis=2)
    require(np.count_nonzero(changed) > 0 and np.count_nonzero(changed & ~(mask > 0)) == 0, "Overlay mask invariant failed.")
    return base, overlay, mask


def validate_job(job_path: Path, output_root: Path) -> tuple[dict[str, Any], Path]:
    job = json_object(job_path)
    require(job.get("schema") == JOB_SCHEMA and bool(job.get("reviewOnly")), "Job schema/authority changed.")
    for field in ("trainingEligible", "xmlEligible", "productionEligible", "productionRoutingEnabled", "detectorRerun", "sourceMutation", "liveProviderActivation"):
        require(not bool(job.get(field)), f"Forbidden authority changed: {field}")
    require(job.get("localizationInput") == "CLEAN_PIXELS_WITH_HARD_EXTERIOR_ELIGIBILITY", "Localization input changed.")
    root = (job_path.parent / str(job["sourceRootRelativeToJob"])).resolve()
    require(root.is_dir(), "Source root is absent.")
    check_path(output_root)
    inputs = list(job.get("inputs", []))
    expected = {"S16-C1-BF", "S16-C1-DF", "S17-C1-BF", "S17-C1-DF", "S17-C2-BF", "S17-C2-DF"}
    require(len(inputs) == 6 and {str(row["id"]) for row in inputs} == expected, "Input identity set changed.")
    for row in inputs:
        path = safe_child(root, str(row["path"]))
        require(path.is_file() and len(str(row["sha256"])) == 64, "Input pin is invalid.")
        require((int(row["widthPx"]), int(row["heightPx"]), int(row["inwardY"])) == (1000, 600, 420), "Input geometry changed.")
    require(len(list(job.get("pairs", []))) == 3, "Pair set changed.")
    config = job["config"]
    require(float(config["minimumNotchDepthPx"]) == 7.0, "Minimum depth was relaxed.")
    require(float(config["maximumBelowExteriorDistance"]) <= 1.75, "Hard exterior distance was weakened.")
    return job, root


def process(job_path: Path, output_root: Path) -> dict[str, Any]:
    job, source_root = validate_job(job_path, output_root)
    require(not output_root.exists(), "Output root must be create-new.")
    output_root.mkdir(parents=False)
    config = job["config"]
    results: list[dict[str, Any]] = []
    lookup: dict[str, dict[str, Any]] = {}
    for source in sorted(job["inputs"], key=lambda row: str(row["id"])):
        input_path = safe_child(source_root, str(source["path"]))
        actual_hash = hash_file(input_path)
        require(actual_hash == str(source["sha256"]).upper(), f"Input hash changed: {input_path}")
        clean = cv2.imread(str(input_path), cv2.IMREAD_COLOR)
        require(clean is not None and clean.shape == (600, 1000, 3), f"Decode changed: {input_path}")
        gray = cv2.cvtColor(clean, cv2.COLOR_BGR2GRAY)
        geometry = geometric_edge(1000, float(source["inwardY"]), float(source["radiusPx"]))
        boundary, support, enhanced, edge_evidence = hard_exterior_boundary(gray, geometry, config)
        baseline = robust_unindented_edge(boundary, geometry)
        candidates, noise, threshold = find_notches(boundary, baseline, support, config)
        coverage_ok = float(edge_evidence["coverageFraction"]) >= float(config["minimumObservedCoverage"])
        gap_ok = int(edge_evidence["longestInterpolatedGapPx"]) <= int(config["maximumInterpolatedGapPx"])
        if not coverage_ok or not gap_ok:
            state = "HOLD_HARD_EXTERIOR_BOUNDARY_INCOMPLETE"
        elif not candidates:
            state = "HOLD_NO_HARD_EXTERIOR_NOTCH"
        elif len(candidates) > 1 and float(candidates[1]["score"]) >= float(config["ambiguityScoreRatio"]) * float(candidates[0]["score"]):
            state = "HOLD_MULTIPLE_HARD_EXTERIOR_INDENTATIONS"
        else:
            state = "HARD_EXTERIOR_NOTCH_FOR_OPERATOR_REVIEW"
        for candidate in candidates:
            center_x = float(candidate["mouthCenterX"])
            center_index = int(round(center_x))
            tip = int(candidate["tipX"])
            candidate["mouthCenterAngleDegrees"] = to_angle(center_x, float(boundary[center_index]), 1000, float(source["inwardY"]), float(source["radiusPx"]), float(source["cropCenterAngleDegrees"]))
            candidate["tipAngleDegrees"] = to_angle(float(tip), float(boundary[tip]), 1000, float(source["inwardY"]), float(source["radiusPx"]), float(source["cropCenterAngleDegrees"]))
        enhanced_bgr, overlay, mask = overlay_images(enhanced, boundary, baseline, candidates, state)
        stem = str(source["id"]).lower().replace("-", "")
        names = {"clean": f"{stem}_clean.png", "enhanced": f"{stem}_enhanced.png", "overlay": f"{stem}_edge_overlay.png", "mask": f"{stem}_mask.png"}
        for name, pixels in ((names["clean"], clean), (names["enhanced"], enhanced_bgr), (names["overlay"], overlay), (names["mask"], mask)):
            save_png(output_root / name, pixels)
        roundtrip = cv2.imread(str(output_root / names["clean"]), cv2.IMREAD_COLOR)
        require(roundtrip is not None and np.array_equal(roundtrip, clean), "Clean round-trip changed pixels.")
        row = {
            "id": str(source["id"]),
            "pairId": str(source["pairId"]),
            "channel": str(source["channel"]),
            "state": state,
            "source": {"path": str(source["path"]), "sha256": actual_hash},
            "jsonCandidateCenterConsumed": False,
            "hardExteriorEligibility": edge_evidence,
            "depthNoisePx": noise,
            "detectionThresholdPx": threshold,
            "candidateCount": len(candidates),
            "candidates": candidates,
            "primary": candidates[0] if candidates else None,
            "assets": {key: {"path": name, "sha256": hash_file(output_root / name)} for key, name in names.items()},
            "imageBytesEmittedToStdout": False,
        }
        results.append(row)
        lookup[row["id"]] = row
    pair_results: list[dict[str, Any]] = []
    for pair in job["pairs"]:
        bf, df = lookup[str(pair["bfInputId"])], lookup[str(pair["dfInputId"])]
        if bf["primary"] is None or df["primary"] is None:
            state, difference = "HOLD_BF_DF_PRIMARY_MISSING", None
        else:
            difference = angle_gap(float(bf["primary"]["mouthCenterAngleDegrees"]), float(df["primary"]["mouthCenterAngleDegrees"]))
            state = "BF_DF_HARD_EXTERIOR_CENTER_AGREEMENT_FOR_OPERATOR_REVIEW" if difference <= float(config["bfDfAgreementDegrees"]) else "HOLD_BF_DF_HARD_EXTERIOR_CENTER_DISAGREEMENT"
        pair_results.append({"pairId": str(pair["pairId"]), "state": state, "absoluteCenterDifferenceDegrees": difference, "transformAveragingPerformed": False})
    manifest = {
        "schema": "argos_ocv03_hard_exterior_notch_manifest_v1",
        "revision": str(job["revision"]),
        "state": PASS_RENDER,
        "hardExteriorEligibilityApplied": True,
        "jsonCandidateCenterConsumed": False,
        "thresholdRelaxationPerformed": False,
        "inputHashesMatched": True,
        "results": results,
        "pairs": pair_results,
        "assetFileCount": 24,
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
    write_json_new(manifest_path, manifest)
    return {"schema": "argos_ocv03_hard_exterior_command_result_v1", "state": PASS_RENDER, "manifest": str(manifest_path), "manifestSha256": hash_file(manifest_path), "imageInputCount": 6, "assetFileCount": 24, "imageBytesEmittedToStdout": False, "reviewOnly": True, "productionRoutingEnabled": False}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    job_path, output_root = Path(args.job).resolve(), Path(args.output_root).resolve()
    job, _ = validate_job(job_path, output_root)
    result = {
        "schema": "argos_ocv03_hard_exterior_preflight_v1",
        "state": PASS_PREFLIGHT,
        "revision": str(job["revision"]),
        "inputCount": 6,
        "sourceImageBytesRead": False,
        "pixelsDecoded": False,
        "outputCreated": False,
        "jsonCandidateCenterConsumed": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    } if args.preflight else process(job_path, output_root)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
