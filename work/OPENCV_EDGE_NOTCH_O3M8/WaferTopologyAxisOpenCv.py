#!/usr/bin/env python3
"""Topology notch localization with deepest-axis center semantics."""

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


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            value.update(block)
    return value.hexdigest().upper()


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


def child(root: Path, name: str) -> Path:
    require(name and not os.path.isabs(name) and "*" not in name and "?" not in name, "Unsafe child path.")
    path = (root / name).resolve()
    require(os.path.commonpath([os.path.normcase(str(root.resolve())), os.path.normcase(str(path))]) == os.path.normcase(str(root.resolve())), "Child escapes root.")
    return path


def circle_geometry(width: int, inward: float, radius: float) -> np.ndarray:
    tangent = np.arange(width, dtype=np.float64) - (width - 1.0) / 2.0
    return (inward + np.sqrt(np.maximum(radius * radius - tangent * tangent, 0.0)) - radius).astype(np.float32)


def runs(mask: np.ndarray) -> list[tuple[int, int]]:
    delta = np.diff(np.pad(mask.astype(np.int8), (1, 1)))
    return [(int(a), int(b - 1)) for a, b in zip(np.flatnonzero(delta == 1), np.flatnonzero(delta == -1))]


def topology_edge(gray: np.ndarray, geometry: np.ndarray, cfg: dict[str, Any]) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, dict[str, Any]]:
    height, width = gray.shape
    enhanced = cv2.createCLAHE(clipLimit=float(cfg["clahe"]), tileGridSize=(8, 8)).apply(gray)
    smooth = cv2.GaussianBlur(enhanced.astype(np.float32), (0, 0), sigmaX=2.0, sigmaY=1.0, borderType=cv2.BORDER_REFLECT101)
    start, end = int(cfg["exteriorStartY"]), int(cfg["exteriorEndY"])
    outside = smooth[start:end]
    outside_level = np.median(outside, axis=0).astype(np.float32)
    outside_level = cv2.GaussianBlur(outside_level.reshape(1, -1), (0, 0), sigmaX=15.0).reshape(-1)
    outside_mad = np.median(np.abs(outside - outside_level[None]), axis=0).astype(np.float32)
    outside_scale = np.maximum(1.4826 * outside_mad, float(cfg["minimumExteriorScale"]))
    distance = np.abs(smooth - outside_level[None]) / outside_scale[None]
    wafer_like = (distance >= float(cfg["waferDistanceThreshold"])).astype(np.uint8) * 255

    close_size = int(cfg["dieStreetCloseKernelPx"])
    if close_size % 2 == 0:
        close_size += 1
    wafer_like = cv2.morphologyEx(wafer_like, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_RECT, (close_size, close_size)))
    wafer_like = cv2.morphologyEx(wafer_like, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3)))

    count, labels, stats, _ = cv2.connectedComponentsWithStats(wafer_like, connectivity=8)
    candidates: list[tuple[int, int]] = []
    for label in range(1, count):
        area = int(stats[label, cv2.CC_STAT_AREA])
        component = labels == label
        top_contact = int(np.count_nonzero(component[0 : int(cfg["topContactRowsPx"])]))
        if top_contact >= int(cfg["minimumTopContactPixels"]) and area >= int(cfg["minimumWaferAreaPx"]):
            candidates.append((label, area))
    require(candidates, "No top-connected wafer component qualified.")
    candidates.sort(key=lambda item: (-item[1], item[0]))
    label, area = candidates[0]
    component = np.where(labels == label, 255, 0).astype(np.uint8)

    contours, _ = cv2.findContours(component, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    require(contours, "Top-connected wafer component has no external contour.")
    filled = np.zeros_like(component)
    cv2.drawContours(filled, contours, -1, 255, cv2.FILLED)

    edge = np.full(width, np.nan, dtype=np.float32)
    for x in range(width):
        lower = int(max(0, math.floor(float(geometry[x]) - float(cfg["maximumInwardPx"]))))
        upper = int(min(height - 1, math.ceil(float(geometry[x]) + float(cfg["maximumOutwardPx"]))))
        rows = np.flatnonzero(filled[lower : upper + 1, x] > 0)
        if rows.size:
            edge[x] = float(lower + int(rows[-1]))
    observed = np.isfinite(edge)
    require(np.count_nonzero(observed) >= 2, "Wafer contour covers fewer than two columns.")
    x_all = np.arange(width, dtype=np.float32)
    edge = np.interp(x_all, x_all[observed], edge[observed]).astype(np.float32)
    edge = cv2.GaussianBlur(edge.reshape(1, -1), (0, 0), sigmaX=2.0).reshape(-1)
    gaps = runs(~observed)
    longest_gap = max((b - a + 1 for a, b in gaps), default=0)

    # Support is the normalized exterior separation immediately above the
    # extracted contour; internal die streets have already been filled.
    row_index = np.clip(np.rint(edge - int(cfg["supportSampleOffsetPx"])).astype(np.int32), 0, height - 1)
    support = np.clip(distance[row_index, np.arange(width)] / 8.0, 0.0, 1.0).astype(np.float32)
    evidence = {
        "topConnectedComponentCount": len(candidates),
        "selectedComponentAreaPx": area,
        "dieStreetCloseKernelPx": close_size,
        "externalContourFillApplied": True,
        "observedColumnCount": int(np.count_nonzero(observed)),
        "coverageFraction": float(np.mean(observed)),
        "longestInterpolatedGapPx": int(longest_gap),
        "medianExteriorLevel": float(np.median(outside_level)),
        "medianExteriorMad": float(np.median(outside_mad)),
    }
    return edge.astype(np.float32), support, enhanced, filled, evidence


def baseline(edge: np.ndarray, geometry: np.ndarray) -> np.ndarray:
    count = edge.size
    x = np.linspace(-1.0, 1.0, count, dtype=np.float64)
    design = np.column_stack((np.ones(count), x, x * x))
    target = edge.astype(np.float64) - geometry.astype(np.float64)
    weights = np.ones(count, dtype=np.float64)
    beta = np.zeros(3, dtype=np.float64)
    for _ in range(12):
        beta = np.linalg.lstsq(design * weights[:, None], target * weights, rcond=None)[0]
        residual = target - design @ beta
        center = float(np.median(residual))
        scale = max(1.4826 * float(np.median(np.abs(residual - center))), 0.35)
        z = np.abs((residual - center) / (4.685 * scale))
        weights = np.square(np.maximum(0.0, 1.0 - z * z))
        weights[residual < center - 2.2 * scale] *= 0.02
        weights = np.maximum(weights, 1.0e-4)
    return (geometry + design @ beta).astype(np.float32)


def notches(edge: np.ndarray, unindented: np.ndarray, support: np.ndarray, cfg: dict[str, Any]) -> tuple[list[dict[str, Any]], float, float]:
    depth = cv2.GaussianBlur((unindented - edge).reshape(1, -1), (0, 0), sigmaX=2.0).reshape(-1)
    k = int(cfg["patternSuppressionWidthPx"])
    if k % 2 == 0:
        k += 1
    depth = cv2.morphologyEx(depth.astype(np.float32).reshape(1, -1), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_RECT, (k, 1))).reshape(-1)
    depth = cv2.GaussianBlur(depth.reshape(1, -1), (0, 0), sigmaX=3.0).reshape(-1)
    center = float(np.median(depth))
    lower_side = depth[depth <= center]
    require(lower_side.size > 0, "Lower-side contour-noise population is empty.")
    noise = max(1.4826 * float(np.median(np.abs(lower_side - center))), 0.5)
    threshold = max(float(cfg["minimumNotchDepthPx"]), center + float(cfg["noiseSigmaThreshold"]) * noise)
    active = (depth >= threshold).astype(np.uint8).reshape(1, -1)
    active = cv2.morphologyEx(active, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_RECT, (int(cfg["candidateJoinWidthPx"]), 1))).reshape(-1).astype(bool)
    found: list[dict[str, Any]] = []
    for coarse_left, coarse_right in runs(active):
        if coarse_right - coarse_left + 1 < int(cfg["minimumNotchWidthPx"]):
            continue
        tip = coarse_left + int(np.argmax(depth[coarse_left : coarse_right + 1]))
        peak = float(depth[tip])
        mouth_level = max(0.45 * float(cfg["minimumNotchDepthPx"]), center + 2.0 * noise, 0.18 * peak)
        left, right = tip, tip
        while left > 1 and depth[left - 1] >= mouth_level:
            left -= 1
        while right < depth.size - 2 and depth[right + 1] >= mouth_level:
            right += 1
        width = right - left + 1
        if width < int(cfg["minimumNotchWidthPx"]):
            continue
        mouth_center = 0.5 * (left + right)
        edge_support = float(np.mean(support[left : right + 1]))
        found.append({
            "leftX": left, "rightX": right, "mouthCenterX": mouth_center, "tipX": tip, "widthPx": width,
            "peakDepthPx": peak, "mouthLevelPx": mouth_level, "edgeSupport": edge_support,
            "score": peak * math.sqrt(width) * max(edge_support, 0.05),
        })
    found.sort(key=lambda row: (-float(row["score"]), int(row["leftX"])))
    return found, noise, threshold


def angle(x: float, y: float, width: int, inward: float, radius: float, crop_center: float) -> float:
    return (crop_center + math.degrees(math.atan2(x - (width - 1.0) / 2.0, radius + y - inward))) % 360.0


def angle_gap(a: float, b: float) -> float:
    return abs((a - b + 180.0) % 360.0 - 180.0)


def overlay(enhanced: np.ndarray, edge: np.ndarray, unindented: np.ndarray, found: list[dict[str, Any]], state: str) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    height, width = enhanced.shape
    base, mask = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR), np.zeros((height, width), np.uint8)
    out = base.copy()
    for values, color, thickness in ((unindented, (0, 190, 0), 2), (edge, (255, 255, 0), 3)):
        points = np.column_stack((np.arange(width), np.rint(values).astype(np.int32))).reshape(-1, 1, 2)
        cv2.polylines(out, [points], False, color, thickness, cv2.LINE_8)
        cv2.polylines(mask, [points], False, 255, thickness, cv2.LINE_8)
    for rank, item in enumerate(found[:3]):
        left, right, tip = int(item["leftX"]), int(item["rightX"]), int(item["tipX"])
        color = (0, 0, 255) if rank == 0 else (0, 140, 255)
        segment_x = np.arange(left, right + 1)
        segment_points = np.column_stack(
            (segment_x, np.rint(edge[left : right + 1]).astype(np.int32))
        ).reshape(-1, 1, 2)
        cv2.polylines(out, [segment_points], False, color, 4 if rank == 0 else 2, cv2.LINE_8)
        cv2.polylines(mask, [segment_points], False, 255, 4 if rank == 0 else 2, cv2.LINE_8)
        for x in (left, right):
            cv2.line(out, (x, max(0, int(unindented[x]) - 26)), (x, min(height - 1, int(unindented[x]) + 26)), (0, 220, 220), 2, cv2.LINE_8)
            cv2.line(mask, (x, max(0, int(unindented[x]) - 26)), (x, min(height - 1, int(unindented[x]) + 26)), 255, 2, cv2.LINE_8)
        cv2.drawMarker(out, (tip, int(round(edge[tip]))), color, cv2.MARKER_CROSS, 14, 3, cv2.LINE_8)
        cv2.drawMarker(mask, (tip, int(round(edge[tip]))), 255, cv2.MARKER_CROSS, 14, 3, cv2.LINE_8)
    legend = "RED notch contour mouth-to-mouth + deepest axis | YELLOW mouth bounds | CYAN wafer edge"
    cv2.rectangle(out, (0, 0), (width - 1, 31), (0, 0, 0), cv2.FILLED)
    cv2.rectangle(mask, (0, 0), (width - 1, 31), 255, cv2.FILLED)
    cv2.putText(out, legend, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.47, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, legend, (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.47, 255, 1, cv2.LINE_8)
    cv2.putText(out, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, state, (8, height - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, 255, 1, cv2.LINE_8)
    changed = np.any(out != base, axis=2)
    require(np.count_nonzero(changed) > 0 and np.count_nonzero(changed & ~(mask > 0)) == 0, "Overlay mask invariant failed.")
    return base, out, mask


def png(path: Path, image: np.ndarray) -> None:
    require(not path.exists() and bool(cv2.imwrite(str(path), image, [cv2.IMWRITE_PNG_COMPRESSION, 6])), f"PNG write failed: {path}")


def validate(job_path: Path, output_root: Path) -> tuple[dict[str, Any], Path]:
    job = read_json(job_path)
    require(job.get("schema") == "argos_ocv03_wafer_topology_axis_job_v1" and bool(job.get("reviewOnly")), "Job schema/authority changed.")
    for field in ("trainingEligible", "xmlEligible", "productionEligible", "productionRoutingEnabled", "detectorRerun", "sourceMutation", "liveProviderActivation"):
        require(not bool(job.get(field)), f"Forbidden authority changed: {field}")
    require(job.get("localizationInput") == "CLEAN_PIXELS_TOP_CONNECTED_WAFER_TOPOLOGY", "Localization input changed.")
    root = (job_path.parent / str(job["sourceRootRelativeToJob"])).resolve()
    require(root.is_dir() and len(str(output_root)) + 32 < 200, "Root/path validation failed.")
    inputs = list(job.get("inputs", []))
    require(len(inputs) == 6, "Input count changed.")
    for row in inputs:
        path = child(root, str(row["path"]))
        require(path.is_file() and len(str(row["sha256"])) == 64, "Input pin changed.")
        require((int(row["widthPx"]), int(row["heightPx"]), int(row["inwardY"])) == (1000, 600, 420), "Input geometry changed.")
    cfg = job["config"]
    require(float(cfg["minimumNotchDepthPx"]) == 20.0 and float(cfg["waferDistanceThreshold"]) >= 2.5, "Decision gates weakened.")
    return job, root


def process(job_path: Path, output_root: Path) -> dict[str, Any]:
    job, root = validate(job_path, output_root)
    require(not output_root.exists(), "Output root must be create-new.")
    output_root.mkdir(parents=False)
    cfg, results, lookup = job["config"], [], {}
    for row in sorted(job["inputs"], key=lambda item: str(item["id"])):
        path = child(root, str(row["path"]))
        actual = digest(path)
        require(actual == str(row["sha256"]).upper(), f"Source hash changed: {path}")
        clean = cv2.imread(str(path), cv2.IMREAD_COLOR)
        require(clean is not None and clean.shape == (600, 1000, 3), f"Decode changed: {path}")
        geometry = circle_geometry(1000, float(row["inwardY"]), float(row["radiusPx"]))
        edge, support, enhanced, _, evidence = topology_edge(cv2.cvtColor(clean, cv2.COLOR_BGR2GRAY), geometry, cfg)
        unindented = baseline(edge, geometry)
        found, noise, threshold = notches(edge, unindented, support, cfg)
        complete = float(evidence["coverageFraction"]) >= float(cfg["minimumContourCoverage"]) and int(evidence["longestInterpolatedGapPx"]) <= int(cfg["maximumInterpolatedGapPx"])
        if not complete:
            state = "HOLD_WAFER_TOPOLOGY_CONTOUR_INCOMPLETE"
        elif not found:
            state = "HOLD_NO_TOPOLOGY_NOTCH"
        elif len(found) > 1:
            state = "HOLD_MULTIPLE_TOPOLOGY_INDENTATIONS"
        else:
            state = "WAFER_TOPOLOGY_NOTCH_FOR_OPERATOR_REVIEW"
        for item in found:
            mouth_midpoint, tip = float(item["mouthCenterX"]), int(item["tipX"])
            mouth_index = int(round(mouth_midpoint))
            item["mouthMidpointAngleDegrees"] = angle(mouth_midpoint, float(edge[mouth_index]), 1000, float(row["inwardY"]), float(row["radiusPx"]), float(row["cropCenterAngleDegrees"]))
            item["axisCenterX"] = tip
            item["axisCenterAngleDegrees"] = angle(float(tip), float(edge[tip]), 1000, float(row["inwardY"]), float(row["radiusPx"]), float(row["cropCenterAngleDegrees"]))
        enhanced_bgr, over, mask = overlay(enhanced, edge, unindented, found, state)
        stem = str(row["id"]).lower().replace("-", "")
        names = {"clean": f"{stem}_clean.png", "enhanced": f"{stem}_enhanced.png", "overlay": f"{stem}_contour_overlay.png", "mask": f"{stem}_mask.png"}
        for name, image in ((names["clean"], clean), (names["enhanced"], enhanced_bgr), (names["overlay"], over), (names["mask"], mask)):
            png(output_root / name, image)
        result = {
            "id": str(row["id"]), "pairId": str(row["pairId"]), "channel": str(row["channel"]), "state": state,
            "source": {"path": str(row["path"]), "sha256": actual}, "jsonCandidateCenterConsumed": False,
            "topologyEvidence": evidence, "depthNoisePx": noise, "detectionThresholdPx": threshold,
            "candidateCount": len(found), "candidates": found, "primary": found[0] if found else None,
            "assets": {key: {"path": name, "sha256": digest(output_root / name)} for key, name in names.items()}, "imageBytesEmittedToStdout": False,
        }
        results.append(result)
        lookup[result["id"]] = result
    pairs = []
    for pair in job["pairs"]:
        bf, df = lookup[str(pair["bfInputId"])], lookup[str(pair["dfInputId"])]
        if bf["primary"] is None or df["primary"] is None:
            state, difference = "HOLD_BF_DF_PRIMARY_MISSING", None
        else:
            difference = angle_gap(float(bf["primary"]["axisCenterAngleDegrees"]), float(df["primary"]["axisCenterAngleDegrees"]))
            if int(bf["candidateCount"]) > 1 or int(df["candidateCount"]) > 1:
                state = "HOLD_BF_DF_INPUT_NOT_UNIQUE"
            else:
                state = "BF_DF_TOPOLOGY_NOTCH_AGREEMENT_FOR_OPERATOR_REVIEW" if difference <= float(cfg["bfDfAgreementDegrees"]) else "HOLD_BF_DF_TOPOLOGY_NOTCH_DISAGREEMENT"
        pairs.append({"pairId": str(pair["pairId"]), "state": state, "absoluteCenterDifferenceDegrees": difference, "transformAveragingPerformed": False})
    manifest = {
        "schema": "argos_ocv03_wafer_topology_axis_manifest_v1", "revision": str(job["revision"]), "state": "PASS_O3L8_WAFER_TOPOLOGY_AXIS_REVIEW_RENDERED",
        "topConnectedWaferTopologyUsed": True, "internalDieHolesFilled": True,
        "notchShapeOverlay": "CONTOUR_HUGGING_MOUTH_TO_MOUTH", "fullHeightCenterLineRendered": False,
        "noisePopulation": "LOWER_SIDE_RESIDUALS_AT_OR_BELOW_MEDIAN",
        "minimumTopologyIndentationDepthPx": float(cfg["minimumNotchDepthPx"]),
        "multipleQualifiedIndentationDecision": "HOLD",
        "ambiguityScoreRatioDecisionUse": False,
        "redCenterDefinition": "DEEPEST_INDENTATION_AXIS", "mouthMidpointDiagnosticOnly": True,
        "jsonCandidateCenterConsumed": False, "thresholdRelaxationPerformed": False,
        "inputHashesMatched": True, "results": results, "pairs": pairs, "assetFileCount": 24,
        "sourceMutationPerformed": False, "detectorRerunPerformed": False, "providerActivated": False, "taskOrProcessActionPerformed": False,
        "protectedProcessorTouched": False, "holdCleared": False, "reviewOnly": True, "trainingEligible": False, "xmlEligible": False,
        "productionEligible": False, "productionRoutingEnabled": False,
    }
    manifest_path = output_root / "MANIFEST.json"
    write_json(manifest_path, manifest)
    return {"schema": "argos_ocv03_wafer_topology_axis_command_v1", "state": manifest["state"], "manifest": str(manifest_path), "manifestSha256": digest(manifest_path), "imageInputCount": 6, "assetFileCount": 24, "imageBytesEmittedToStdout": False, "reviewOnly": True}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    job_path, output_root = Path(args.job).resolve(), Path(args.output_root).resolve()
    job, _ = validate(job_path, output_root)
    result = {
        "schema": "argos_ocv03_wafer_topology_axis_preflight_v1", "state": "PASS_O3L8_WAFER_TOPOLOGY_AXIS_PREFLIGHT", "revision": str(job["revision"]),
        "inputCount": 6, "sourceImageBytesRead": False, "pixelsDecoded": False, "outputCreated": False, "jsonCandidateCenterConsumed": False,
        "reviewOnly": True, "productionRoutingEnabled": False,
    } if args.preflight else process(job_path, output_root)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
