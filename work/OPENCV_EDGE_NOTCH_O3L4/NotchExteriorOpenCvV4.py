#!/usr/bin/env python3
"""Standalone float-safe hard-exterior notch localizer."""

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


def need(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    need(path.is_file() and path.stat().st_size <= 4 * 1024 * 1024, f"Invalid JSON: {path}")
    result = json.loads(path.read_text(encoding="utf-8"))
    need(isinstance(result, dict), "JSON root is not an object.")
    return result


def put_json(path: Path, value: dict[str, Any]) -> None:
    partial = path.with_name(path.name + ".partial")
    need(not path.exists() and not partial.exists(), f"Create-new collision: {path}")
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def source_path(root: Path, name: str) -> Path:
    need(name and not os.path.isabs(name) and "*" not in name and "?" not in name, "Unsafe source name.")
    result = (root / name).resolve()
    need(os.path.commonpath([os.path.normcase(str(root.resolve())), os.path.normcase(str(result))]) == os.path.normcase(str(root.resolve())), "Source escapes root.")
    return result


def geometry_row(width: int, inward: float, radius: float) -> np.ndarray:
    x = np.arange(width, dtype=np.float64) - (width - 1.0) / 2.0
    return (inward + np.sqrt(np.maximum(radius * radius - x * x, 0.0)) - radius).astype(np.float32)


def regions(bits: np.ndarray) -> list[tuple[int, int]]:
    change = np.diff(np.pad(bits.astype(np.int8), (1, 1)))
    return [(int(a), int(b - 1)) for a, b in zip(np.flatnonzero(change == 1), np.flatnonzero(change == -1))]


def trace_edge(gray: np.ndarray, geometry: np.ndarray, cfg: dict[str, Any]) -> tuple[np.ndarray, np.ndarray, np.ndarray, dict[str, Any]]:
    height, width = gray.shape
    enhanced = cv2.createCLAHE(clipLimit=float(cfg["clahe"]), tileGridSize=(8, 8)).apply(gray)
    work = cv2.GaussianBlur(enhanced.astype(np.float32), (0, 0), sigmaX=2.0, sigmaY=1.0, borderType=cv2.BORDER_REFLECT101)
    start, end = int(cfg["exteriorStartY"]), int(cfg["exteriorEndY"])
    outside = work[start:end]
    outside_level = np.median(outside, axis=0).astype(np.float32)
    outside_level = cv2.GaussianBlur(outside_level.reshape(1, -1), (0, 0), sigmaX=15.0).reshape(-1)
    outside_mad = np.median(np.abs(outside - outside_level[None]), axis=0).astype(np.float32)
    outside_scale = np.maximum(1.4826 * outside_mad, float(cfg["minimumExteriorScale"]))
    distance = np.minimum(np.abs(work - outside_level[None]) / outside_scale[None], 16.0).astype(np.float32)
    mean_distance = cv2.boxFilter(distance, cv2.CV_32F, (7, int(cfg["transitionWindowPx"])), normalize=True, borderType=cv2.BORDER_REFLECT101)
    offset = int(cfg["transitionOffsetPx"])
    y = np.arange(height, dtype=np.int32)
    above = mean_distance[np.clip(y - offset, 0, height - 1)]
    below = mean_distance[np.clip(y + offset, 0, height - 1)]
    directed = above - below
    smooth = cv2.GaussianBlur(work, (0, 0), sigmaX=float(cfg["tangentialSigma"]), sigmaY=2.0, borderType=cv2.BORDER_REFLECT101)
    gradient = np.abs(cv2.Scharr(smooth, cv2.CV_32F, 0, 1))
    gradient /= max(float(np.percentile(gradient, 97.0)), 1.0)
    score = directed + float(cfg["gradientWeight"]) * np.clip(gradient, 0.0, 1.0)
    yy = np.arange(height, dtype=np.float32)[:, None]
    eligible = (
        (yy >= geometry[None] - int(cfg["maximumInwardPx"]))
        & (yy <= geometry[None] + int(cfg["maximumOutwardPx"]))
        & (below <= float(cfg["maximumBelowExteriorDistance"]))
        & (above >= float(cfg["minimumAboveExteriorDistance"]))
        & (directed >= float(cfg["minimumDirectedTransition"]))
    )
    raw = np.full(width, np.nan, dtype=np.float32)
    raw_support = np.zeros(width, dtype=np.float32)
    for x in range(width):
        candidates = np.flatnonzero(eligible[:, x])
        if candidates.size:
            values = score[candidates, x] - float(cfg["geometryPenalty"]) * np.abs(candidates.astype(np.float32) - geometry[x])
            row = int(candidates[int(np.argmax(values))])
            raw[x], raw_support[x] = float(row), float(score[row, x])
    observed = np.isfinite(raw)
    need(np.count_nonzero(observed) >= 2, "Fewer than two hard-exterior edge columns qualified.")
    all_x = np.arange(width, dtype=np.float32)
    edge = np.interp(all_x, all_x[observed], raw[observed]).astype(np.float32)
    support = np.interp(all_x, all_x[observed], raw_support[observed]).astype(np.float32)
    missing = regions(~observed)
    longest = max((b - a + 1 for a, b in missing), default=0)
    # GaussianBlur is explicitly float32-safe; no median-kernel depth mismatch.
    edge = cv2.GaussianBlur(edge.reshape(1, -1), (0, 0), sigmaX=2.0).reshape(-1)
    evidence = {
        "hardExteriorEligibilityApplied": True,
        "observedColumns": int(np.count_nonzero(observed)),
        "coverageFraction": float(np.mean(observed)),
        "longestInterpolatedGapPx": int(longest),
        "medianExteriorLevel": float(np.median(outside_level)),
        "medianExteriorMad": float(np.median(outside_mad)),
        "boundarySmoothing": "GAUSSIAN_FLOAT32_SIGMA_2",
    }
    return edge.astype(np.float32), support.astype(np.float32), enhanced, evidence


def fit_baseline(edge: np.ndarray, geometry: np.ndarray) -> np.ndarray:
    count = edge.size
    x = np.linspace(-1.0, 1.0, count, dtype=np.float64)
    design = np.column_stack((np.ones(count), x, x * x))
    target = edge.astype(np.float64) - geometry.astype(np.float64)
    weights = np.ones(count, dtype=np.float64)
    beta = np.zeros(3, dtype=np.float64)
    for _ in range(12):
        beta = np.linalg.lstsq(design * weights[:, None], target * weights, rcond=None)[0]
        error = target - design @ beta
        middle = float(np.median(error))
        scale = max(1.4826 * float(np.median(np.abs(error - middle))), 0.35)
        z = np.abs((error - middle) / (4.685 * scale))
        weights = np.square(np.maximum(0.0, 1.0 - z * z))
        weights[error < middle - 2.2 * scale] *= 0.02
        weights = np.maximum(weights, 1.0e-4)
    return (geometry + design @ beta).astype(np.float32)


def detect(edge: np.ndarray, baseline: np.ndarray, support: np.ndarray, cfg: dict[str, Any]) -> tuple[list[dict[str, Any]], float, float]:
    depth = cv2.GaussianBlur((baseline - edge).reshape(1, -1), (0, 0), sigmaX=2.0).reshape(-1)
    kernel_width = int(cfg["patternSuppressionWidthPx"])
    if kernel_width % 2 == 0:
        kernel_width += 1
    depth = cv2.morphologyEx(depth.astype(np.float32).reshape(1, -1), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_RECT, (kernel_width, 1))).reshape(-1)
    depth = cv2.GaussianBlur(depth.reshape(1, -1), (0, 0), sigmaX=3.0).reshape(-1)
    middle = float(np.median(depth))
    noise = max(1.4826 * float(np.median(np.abs(depth - middle))), 0.5)
    threshold = max(float(cfg["minimumNotchDepthPx"]), middle + float(cfg["noiseSigmaThreshold"]) * noise)
    active = (depth >= threshold).astype(np.uint8).reshape(1, -1)
    active = cv2.morphologyEx(active, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_RECT, (int(cfg["candidateJoinWidthPx"]), 1))).reshape(-1).astype(bool)
    found: list[dict[str, Any]] = []
    for first, last in regions(active):
        if last - first + 1 < int(cfg["minimumNotchWidthPx"]):
            continue
        tip = first + int(np.argmax(depth[first : last + 1]))
        peak = float(depth[tip])
        mouth_level = max(0.45 * float(cfg["minimumNotchDepthPx"]), middle + 2.0 * noise, 0.18 * peak)
        left, right = tip, tip
        while left > 1 and depth[left - 1] >= mouth_level:
            left -= 1
        while right < depth.size - 2 and depth[right + 1] >= mouth_level:
            right += 1
        width = right - left + 1
        if width < int(cfg["minimumNotchWidthPx"]):
            continue
        center = 0.5 * (left + right)
        edge_support = float(np.mean(support[left : right + 1]))
        found.append({
            "leftX": left, "rightX": right, "mouthCenterX": center, "tipX": tip, "widthPx": width,
            "peakDepthPx": peak, "mouthLevelPx": mouth_level, "edgeSupport": edge_support,
            "score": peak * math.sqrt(width) * max(edge_support, 0.05),
        })
    found.sort(key=lambda row: (-float(row["score"]), int(row["leftX"])))
    return found, noise, threshold


def pixel_angle(x: float, y: float, width: int, inward: float, radius: float, crop_angle: float) -> float:
    return (crop_angle + math.degrees(math.atan2(x - (width - 1.0) / 2.0, radius + y - inward))) % 360.0


def angle_difference(a: float, b: float) -> float:
    return abs((a - b + 180.0) % 360.0 - 180.0)


def make_overlay(enhanced: np.ndarray, edge: np.ndarray, baseline: np.ndarray, candidates: list[dict[str, Any]], state: str) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    height, width = enhanced.shape
    base = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    overlay, mask = base.copy(), np.zeros((height, width), dtype=np.uint8)
    baseline_points = np.column_stack((np.arange(width), np.rint(baseline).astype(np.int32))).reshape(-1, 1, 2)
    edge_points = np.column_stack((np.arange(width), np.rint(edge).astype(np.int32))).reshape(-1, 1, 2)
    for target, color, thickness in ((baseline_points, (0, 190, 0), 2), (edge_points, (255, 255, 0), 3)):
        cv2.polylines(overlay, [target], False, color, thickness, cv2.LINE_8)
        cv2.polylines(mask, [target], False, 255, thickness, cv2.LINE_8)
    for rank, item in enumerate(candidates[:3]):
        left, right, tip = int(item["leftX"]), int(item["rightX"]), int(item["tipX"])
        center = int(round(float(item["mouthCenterX"])))
        color = (0, 0, 255) if rank == 0 else (0, 140, 255)
        for x in (left, right):
            cv2.line(overlay, (x, max(0, int(baseline[x]) - 26)), (x, min(height - 1, int(baseline[x]) + 26)), (0, 220, 220), 2, cv2.LINE_8)
            cv2.line(mask, (x, max(0, int(baseline[x]) - 26)), (x, min(height - 1, int(baseline[x]) + 26)), 255, 2, cv2.LINE_8)
        cv2.line(overlay, (center, 0), (center, height - 1), color, 3 if rank == 0 else 2, cv2.LINE_8)
        cv2.line(mask, (center, 0), (center, height - 1), 255, 3 if rank == 0 else 2, cv2.LINE_8)
        cv2.drawMarker(overlay, (tip, int(round(edge[tip]))), (255, 0, 255), cv2.MARKER_CROSS, 18, 3, cv2.LINE_8)
        cv2.drawMarker(mask, (tip, int(round(edge[tip]))), 255, cv2.MARKER_CROSS, 18, 3, cv2.LINE_8)
    legend = "RED notch mouth center | MAGENTA tip | CYAN hard-exterior edge | GREEN baseline"
    cv2.rectangle(overlay, (0, 0), (width - 1, 31), (0, 0, 0), cv2.FILLED)
    cv2.rectangle(mask, (0, 0), (width - 1, 31), 255, cv2.FILLED)
    cv2.putText(overlay, legend, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.49, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, legend, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.49, 255, 1, cv2.LINE_8)
    cv2.putText(overlay, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, 255, 1, cv2.LINE_8)
    changed = np.any(overlay != base, axis=2)
    need(np.count_nonzero(changed) > 0 and np.count_nonzero(changed & ~(mask > 0)) == 0, "Overlay mask invariant failed.")
    return base, overlay, mask


def save_png(path: Path, image: np.ndarray) -> None:
    need(not path.exists() and bool(cv2.imwrite(str(path), image, [cv2.IMWRITE_PNG_COMPRESSION, 6])), f"PNG write failed: {path}")


def validate(job_path: Path, output_root: Path) -> tuple[dict[str, Any], Path]:
    job = read_json(job_path)
    need(job.get("schema") == "argos_ocv03_notch_exterior_v4_job" and bool(job.get("reviewOnly")), "Job schema/authority changed.")
    for key in ("trainingEligible", "xmlEligible", "productionEligible", "productionRoutingEnabled", "detectorRerun", "sourceMutation", "liveProviderActivation"):
        need(not bool(job.get(key)), f"Forbidden authority changed: {key}")
    need(job.get("localizationInput") == "CLEAN_PIXELS_HARD_EXTERIOR_FLOAT_SAFE", "Localization input changed.")
    root = (job_path.parent / str(job["sourceRootRelativeToJob"])).resolve()
    need(root.is_dir() and len(str(output_root)) + 32 < 200, "Root/path validation failed.")
    inputs = list(job.get("inputs", []))
    need(len(inputs) == 6, "Input count changed.")
    for row in inputs:
        path = source_path(root, str(row["path"]))
        need(path.is_file() and len(str(row["sha256"])) == 64, "Input pin changed.")
        need((int(row["widthPx"]), int(row["heightPx"]), int(row["inwardY"])) == (1000, 600, 420), "Input geometry changed.")
    cfg = job["config"]
    need(float(cfg["minimumNotchDepthPx"]) == 7.0 and float(cfg["maximumBelowExteriorDistance"]) <= 1.75, "Decision gates weakened.")
    return job, root


def run(job_path: Path, output_root: Path) -> dict[str, Any]:
    job, root = validate(job_path, output_root)
    need(not output_root.exists(), "Output root must be create-new.")
    output_root.mkdir(parents=False)
    cfg, results, lookup = job["config"], [], {}
    for row in sorted(job["inputs"], key=lambda item: str(item["id"])):
        path = source_path(root, str(row["path"]))
        actual = sha(path)
        need(actual == str(row["sha256"]).upper(), f"Source hash changed: {path}")
        clean = cv2.imread(str(path), cv2.IMREAD_COLOR)
        need(clean is not None and clean.shape == (600, 1000, 3), f"Decode changed: {path}")
        geometry = geometry_row(1000, float(row["inwardY"]), float(row["radiusPx"]))
        edge, support, enhanced, evidence = trace_edge(cv2.cvtColor(clean, cv2.COLOR_BGR2GRAY), geometry, cfg)
        baseline = fit_baseline(edge, geometry)
        candidates, noise, threshold = detect(edge, baseline, support, cfg)
        complete = float(evidence["coverageFraction"]) >= float(cfg["minimumObservedCoverage"]) and int(evidence["longestInterpolatedGapPx"]) <= int(cfg["maximumInterpolatedGapPx"])
        if not complete:
            state = "HOLD_HARD_EXTERIOR_EDGE_INCOMPLETE"
        elif not candidates:
            state = "HOLD_NO_HARD_EXTERIOR_NOTCH"
        elif len(candidates) > 1 and float(candidates[1]["score"]) >= float(cfg["ambiguityScoreRatio"]) * float(candidates[0]["score"]):
            state = "HOLD_MULTIPLE_HARD_EXTERIOR_INDENTATIONS"
        else:
            state = "HARD_EXTERIOR_NOTCH_FOR_OPERATOR_REVIEW"
        for item in candidates:
            center, tip = float(item["mouthCenterX"]), int(item["tipX"])
            ci = int(round(center))
            item["mouthCenterAngleDegrees"] = pixel_angle(center, float(edge[ci]), 1000, float(row["inwardY"]), float(row["radiusPx"]), float(row["cropCenterAngleDegrees"]))
            item["tipAngleDegrees"] = pixel_angle(float(tip), float(edge[tip]), 1000, float(row["inwardY"]), float(row["radiusPx"]), float(row["cropCenterAngleDegrees"]))
        enhanced_bgr, overlay, mask = make_overlay(enhanced, edge, baseline, candidates, state)
        stem = str(row["id"]).lower().replace("-", "")
        names = {"clean": f"{stem}_clean.png", "enhanced": f"{stem}_enhanced.png", "overlay": f"{stem}_edge_overlay.png", "mask": f"{stem}_mask.png"}
        for name, image in ((names["clean"], clean), (names["enhanced"], enhanced_bgr), (names["overlay"], overlay), (names["mask"], mask)):
            save_png(output_root / name, image)
        item_result = {
            "id": str(row["id"]), "pairId": str(row["pairId"]), "channel": str(row["channel"]), "state": state,
            "source": {"path": str(row["path"]), "sha256": actual}, "jsonCandidateCenterConsumed": False,
            "edgeEvidence": evidence, "depthNoisePx": noise, "detectionThresholdPx": threshold,
            "candidateCount": len(candidates), "candidates": candidates, "primary": candidates[0] if candidates else None,
            "assets": {key: {"path": name, "sha256": sha(output_root / name)} for key, name in names.items()},
            "imageBytesEmittedToStdout": False,
        }
        results.append(item_result)
        lookup[item_result["id"]] = item_result
    pairs = []
    for pair in job["pairs"]:
        bf, df = lookup[str(pair["bfInputId"])], lookup[str(pair["dfInputId"])]
        if bf["primary"] is None or df["primary"] is None:
            state, difference = "HOLD_BF_DF_PRIMARY_MISSING", None
        else:
            difference = angle_difference(float(bf["primary"]["mouthCenterAngleDegrees"]), float(df["primary"]["mouthCenterAngleDegrees"]))
            state = "BF_DF_HARD_EXTERIOR_AGREEMENT_FOR_OPERATOR_REVIEW" if difference <= float(cfg["bfDfAgreementDegrees"]) else "HOLD_BF_DF_HARD_EXTERIOR_DISAGREEMENT"
        pairs.append({"pairId": str(pair["pairId"]), "state": state, "absoluteCenterDifferenceDegrees": difference, "transformAveragingPerformed": False})
    manifest = {
        "schema": "argos_ocv03_notch_exterior_v4_manifest", "revision": str(job["revision"]), "state": "PASS_O3L4_HARD_EXTERIOR_REVIEW_RENDERED",
        "hardExteriorEligibilityApplied": True, "floatSafeBoundarySmoothing": True, "jsonCandidateCenterConsumed": False, "thresholdRelaxationPerformed": False,
        "inputHashesMatched": True, "results": results, "pairs": pairs, "assetFileCount": 24,
        "sourceMutationPerformed": False, "detectorRerunPerformed": False, "providerActivated": False, "taskOrProcessActionPerformed": False,
        "protectedProcessorTouched": False, "holdCleared": False, "reviewOnly": True, "trainingEligible": False, "xmlEligible": False,
        "productionEligible": False, "productionRoutingEnabled": False,
    }
    manifest_path = output_root / "MANIFEST.json"
    put_json(manifest_path, manifest)
    return {"schema": "argos_ocv03_notch_exterior_v4_command", "state": manifest["state"], "manifest": str(manifest_path), "manifestSha256": sha(manifest_path), "imageInputCount": 6, "assetFileCount": 24, "imageBytesEmittedToStdout": False, "reviewOnly": True}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    job_path, output_root = Path(args.job).resolve(), Path(args.output_root).resolve()
    job, _ = validate(job_path, output_root)
    result = {
        "schema": "argos_ocv03_notch_exterior_v4_preflight", "state": "PASS_O3L4_NOTCH_EXTERIOR_PREFLIGHT", "revision": str(job["revision"]),
        "inputCount": 6, "sourceImageBytesRead": False, "pixelsDecoded": False, "outputCreated": False, "jsonCandidateCenterConsumed": False,
        "reviewOnly": True, "productionRoutingEnabled": False,
    } if args.preflight else run(job_path, output_root)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
