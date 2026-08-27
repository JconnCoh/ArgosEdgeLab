#!/usr/bin/env python3
"""Render provenance-bound review crops for frozen notch candidates.

This helper performs no detection, scoring, thresholding, pose selection, or
authority decision. It verifies exact source bytes and frozen result JSON, then
uses OpenCV to render clean native-pixel crops plus the current frozen geometry
as a separate mask/composite layer.
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


JOB_SCHEMA = "argos_ocv03_notch_review_job_v1"
RESULT_SCHEMA = "argos_native_frontside_wafer_pose_opencv_v2"
OUTPUT_SCHEMA = "argos_ocv03_notch_review_render_v1"
PASS_PREFLIGHT = "PASS_O3K1_NOTCH_REVIEW_RENDERER_PREFLIGHT"
PASS_RENDER = "PASS_O3K1_NOTCH_REVIEW_RENDERED"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while True:
            block = stream.read(8 * 1024 * 1024)
            if not block:
                break
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
    payload = json.dumps(value, indent=2, sort_keys=False) + "\n"
    partial.write_text(payload, encoding="utf-8", newline="\n")
    os.replace(partial, path)


def resolve_job_child(job_root: Path, relative_value: str) -> Path:
    require(relative_value and not os.path.isabs(relative_value), "Job child must be relative.")
    require("*" not in relative_value and "?" not in relative_value, "Job child contains a wildcard.")
    candidate = (job_root / relative_value).resolve()
    common = os.path.commonpath([os.path.normcase(str(job_root.resolve())), os.path.normcase(str(candidate))])
    require(common == os.path.normcase(str(job_root.resolve())), "Job child escapes the job root.")
    return candidate


def is_under(path: Path, root: Path) -> bool:
    try:
        common = os.path.commonpath([os.path.normcase(str(path)), os.path.normcase(str(root))])
    except ValueError:
        return False
    return common == os.path.normcase(str(root))


def validate_new_component_names(output_root: Path) -> None:
    for component in output_root.parts:
        require(len(component) <= 80, f"Output component exceeds 80 characters: {component}")
    require(len(str(output_root)) + 32 < 230, "Output root exceeds the hard path budget with suffix reserve.")


def validate_job(job_path: Path, output_root: Path) -> tuple[dict[str, Any], dict[int, dict[str, Any]]]:
    job = load_json(job_path)
    require(job.get("schema") == JOB_SCHEMA, "Job schema changed.")
    require(bool(job.get("reviewOnly")), "Job must remain review-only.")
    for field in ("trainingEligible", "xmlEligible", "productionEligible", "productionRoutingEnabled"):
        require(not bool(job.get(field)), f"Job authority changed: {field}")
    require(not bool(job.get("detectorRerun")), "Detector rerun is forbidden.")
    require(not bool(job.get("thresholdOrAlgorithmChange")), "Threshold or algorithm change is forbidden.")

    crop = job.get("crop")
    require(isinstance(crop, dict), "Crop configuration is absent.")
    width = int(crop.get("widthPx", 0))
    inward = int(crop.get("inwardPx", 0))
    outward = int(crop.get("outwardPx", 0))
    require(400 <= width <= 1600, "Crop width is outside the bounded range.")
    require(200 <= inward <= 800 and 80 <= outward <= 400, "Crop radial bounds are invalid.")
    require(inward + outward <= 1000, "Crop height exceeds the bounded range.")

    source_root = Path(str(job.get("sourceRoot", "")))
    require(source_root.is_absolute(), "sourceRoot must be absolute.")
    allowed_output_root = Path(str(job.get("allowedOutputRoot", "")))
    require(allowed_output_root.is_absolute(), "allowedOutputRoot must be absolute.")
    require(output_root.is_absolute(), "Output root must be absolute.")
    require(is_under(output_root, allowed_output_root), "Output root escapes allowedOutputRoot.")
    validate_new_component_names(output_root)

    result_rows = list(job.get("resultFiles", []))
    require(len(result_rows) == 2, "Exactly two frozen result files are required.")
    results: dict[int, dict[str, Any]] = {}
    for row in result_rows:
        slot = int(row.get("slot", 0))
        require(slot in (16, 17) and slot not in results, "Result slot set changed.")
        result_path = resolve_job_child(job_path.parent, str(row.get("path", "")))
        require(sha256_file(result_path) == str(row.get("sha256", "")).upper(), "Frozen result hash changed.")
        result = load_json(result_path)
        require(result.get("schema") == RESULT_SCHEMA, "Frozen result schema changed.")
        require(str(result.get("identity", "")).endswith(f"_SLOT{slot}"), "Frozen result identity changed.")
        results[slot] = result

    sources = list(job.get("sources", []))
    require(len(sources) == 4, "Exactly four frozen source rows are required.")
    source_ids: set[str] = set()
    for source in sources:
        source_id = str(source.get("id", ""))
        slot = int(source.get("slot", 0))
        channel = str(source.get("channel", ""))
        require(source_id and source_id not in source_ids, "Source IDs must be unique.")
        source_ids.add(source_id)
        require(slot in (16, 17) and channel in ("BF", "DF"), "Source slot/channel changed.")
        path = Path(str(source.get("path", "")))
        require(path.is_absolute() and is_under(path, source_root), "Source path escapes sourceRoot.")
        require(len(str(path)) + 32 < 230, "Source path exceeds hard path budget with suffix reserve.")
        require(int(source.get("bytes", 0)) > 0, "Source byte count is invalid.")
        require(len(str(source.get("sha256", ""))) == 64, "Source SHA-256 is invalid.")
        result_sources = results[slot]["sources"]
        prefix = "bf" if channel == "BF" else "df"
        require(int(result_sources[f"{prefix}Bytes"]) == int(source["bytes"]), "Result/source byte count mismatch.")
        require(str(result_sources[f"{prefix}Sha256"]).upper() == str(source["sha256"]).upper(), "Result/source hash mismatch.")
        require(str(result_sources[f"{prefix}Path"]) == str(source.get("frozenResultSourcePath", "")), "Frozen result source path changed.")

    candidates = list(job.get("candidates", []))
    require(len(candidates) == 3, "Exactly three candidate rows are required.")
    expected_ids = {"S16-C1", "S17-C1", "S17-C2"}
    require({str(row.get("id", "")) for row in candidates} == expected_ids, "Candidate identity set changed.")
    for row in candidates:
        slot = int(row.get("slot", 0))
        index = int(row.get("physicalCandidateIndex", -1))
        physical = list(results[slot].get("physicalIndentationCandidates", []))
        require(0 <= index < len(physical), "Candidate index is outside the frozen result.")
        candidate = physical[index]
        require(abs(float(candidate["bfAngleDegrees"]) - float(row["bfAngleDegrees"])) < 1e-9, "BF candidate angle changed.")
        require(abs(float(candidate["dfAngleDegrees"]) - float(row["dfAngleDegrees"])) < 1e-9, "DF candidate angle changed.")
    return job, results


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


def local_point(radius: float, center_angle: float, ray_angle: float, radial_offset: float, width: int, inward: int) -> tuple[int, int]:
    delta = math.radians(ray_angle - center_angle)
    absolute_radius = radius + radial_offset
    tangent = absolute_radius * math.sin(delta)
    radial = absolute_radius * math.cos(delta) - radius
    return int(round((width - 1.0) / 2.0 + tangent)), int(round(inward + radial))


def draw_geometry_layer(
    shape: tuple[int, int, int],
    radius: float,
    center_angle: float,
    start_angle: float,
    end_angle: float,
    inward: int,
    outward: int,
) -> tuple[np.ndarray, np.ndarray]:
    height, width = shape[:2]
    layer = np.zeros(shape, dtype=np.uint8)
    mask = np.zeros((height, width), dtype=np.uint8)

    tangent = np.arange(width, dtype=np.float64) - (width - 1.0) / 2.0
    valid = np.abs(tangent) < radius
    perimeter_y = np.full(width, inward, dtype=np.float64)
    perimeter_y[valid] = inward + np.sqrt(radius * radius - tangent[valid] * tangent[valid]) - radius
    perimeter_points = np.column_stack((np.arange(width), np.rint(perimeter_y).astype(np.int32)))
    perimeter_points = perimeter_points[(perimeter_points[:, 1] >= 0) & (perimeter_points[:, 1] < height)]
    cv2.polylines(layer, [perimeter_points.reshape(-1, 1, 2)], False, (0, 210, 0), 3, cv2.LINE_8)
    cv2.polylines(mask, [perimeter_points.reshape(-1, 1, 2)], False, 255, 3, cv2.LINE_8)

    radial_min = -float(inward)
    radial_max = float(outward - 1)
    for ray_angle, color, thickness in (
        (start_angle, (0, 220, 220), 3),
        (end_angle, (0, 220, 220), 3),
        (center_angle, (0, 0, 235), 3),
    ):
        first = local_point(radius, center_angle, ray_angle, radial_min, width, inward)
        last = local_point(radius, center_angle, ray_angle, radial_max, width, inward)
        cv2.line(layer, first, last, color, thickness, cv2.LINE_8)
        cv2.line(mask, first, last, 255, thickness, cv2.LINE_8)
    return layer, mask


def write_png(path: Path, image: np.ndarray) -> None:
    require(not path.exists(), f"Create-new PNG exists: {path}")
    ok = cv2.imwrite(str(path), image, [cv2.IMWRITE_PNG_COMPRESSION, 6])
    require(bool(ok), f"OpenCV failed to write PNG: {path}")


def render(job_path: Path, output_root: Path) -> dict[str, Any]:
    job, results = validate_job(job_path, output_root)
    require(not output_root.exists(), "Output root must be create-new.")
    verified_source_hashes: dict[str, str] = {}
    for source in job["sources"]:
        source_path = Path(str(source["path"]))
        require(source_path.is_file(), f"Source image is absent: {source_path}")
        require(source_path.stat().st_size == int(source["bytes"]), f"Source byte count changed: {source_path}")
        actual_source_hash = sha256_file(source_path)
        require(actual_source_hash == str(source["sha256"]).upper(), f"Source SHA-256 changed: {source_path}")
        verified_source_hashes[str(source["id"])] = actual_source_hash
    require(len(verified_source_hashes) == 4, "Exact source-hash cardinality changed.")
    output_root.mkdir(parents=False)
    crop_config = job["crop"]
    width = int(crop_config["widthPx"])
    inward = int(crop_config["inwardPx"])
    outward = int(crop_config["outwardPx"])

    candidate_rows: dict[tuple[int, int], dict[str, Any]] = {}
    candidate_ids: dict[tuple[int, int], str] = {}
    for row in job["candidates"]:
        key = (int(row["slot"]), int(row["physicalCandidateIndex"]))
        candidate_rows[key] = results[key[0]]["physicalIndentationCandidates"][key[1]]
        candidate_ids[key] = str(row["id"])

    outputs: list[dict[str, Any]] = []
    source_reads = 0
    for source in job["sources"]:
        source_path = Path(str(source["path"]))
        actual_source_hash = verified_source_hashes[str(source["id"])]
        image = cv2.imread(str(source_path), cv2.IMREAD_COLOR)
        require(image is not None and image.ndim == 3 and image.shape[2] == 3, f"OpenCV decode failed: {source_path}")
        source_reads += 1
        slot = int(source["slot"])
        channel = str(source["channel"])
        channel_key = "bf" if channel == "BF" else "df"
        result_channel = results[slot][channel_key]
        require(int(result_channel["widthPx"]) == int(image.shape[1]), "Decoded source width changed.")
        require(int(result_channel["heightPx"]) == int(image.shape[0]), "Decoded source height changed.")
        fit = result_channel["fit"]

        for key in sorted(candidate_rows):
            if key[0] != slot:
                continue
            candidate = candidate_rows[key]
            channel_candidate = candidate[channel_key]
            candidate_id = candidate_ids[key]
            angle = float(channel_candidate["centerAngleDegrees"])
            map_x, map_y = local_grid_maps(
                float(fit["centerX"]),
                float(fit["centerY"]),
                float(fit["radius"]),
                angle,
                width,
                inward,
                outward,
            )
            clean = cv2.remap(
                image,
                map_x,
                map_y,
                interpolation=cv2.INTER_NEAREST,
                borderMode=cv2.BORDER_CONSTANT,
                borderValue=(0, 0, 0),
            )
            layer, mask = draw_geometry_layer(
                clean.shape,
                float(fit["radius"]),
                angle,
                float(channel_candidate["startAngleDegrees"]),
                float(channel_candidate["endAngleDegrees"]),
                inward,
                outward,
            )
            overlay = clean.copy()
            mask_pixels = mask > 0
            overlay[mask_pixels] = layer[mask_pixels]
            changed = np.any(overlay != clean, axis=2)
            changed_inside = int(np.count_nonzero(changed & mask_pixels))
            changed_outside = int(np.count_nonzero(changed & ~mask_pixels))
            require(changed_inside > 0 and changed_outside == 0, "Overlay pixel-mask invariant failed.")

            stem = candidate_id.lower().replace("-", "") + "_" + channel.lower()
            clean_path = output_root / f"{stem}_clean.png"
            mask_path = output_root / f"{stem}_mask.png"
            overlay_path = output_root / f"{stem}_overlay.png"
            write_png(clean_path, clean)
            write_png(mask_path, mask)
            write_png(overlay_path, overlay)
            clean_roundtrip = cv2.imread(str(clean_path), cv2.IMREAD_COLOR)
            require(clean_roundtrip is not None and np.array_equal(clean_roundtrip, clean), "Clean PNG is not lossless.")

            outputs.append(
                {
                    "candidateId": candidate_id,
                    "slot": slot,
                    "channel": channel,
                    "sourcePath": str(source_path),
                    "sourceBytes": int(source["bytes"]),
                    "sourceSha256": actual_source_hash,
                    "frozenResultSha256": str(next(row["sha256"] for row in job["resultFiles"] if int(row["slot"]) == slot)).upper(),
                    "physicalCandidateIndex": key[1],
                    "candidateCenterAngleDegrees": angle,
                    "candidateStartAngleDegrees": float(channel_candidate["startAngleDegrees"]),
                    "candidateEndAngleDegrees": float(channel_candidate["endAngleDegrees"]),
                    "candidateWidthDegrees": float(channel_candidate["widthDegrees"]),
                    "fit": {
                        "centerX": float(fit["centerX"]),
                        "centerY": float(fit["centerY"]),
                        "radius": float(fit["radius"]),
                    },
                    "cropTransform": {
                        "schema": "argos_tangent_radial_crop_transform_v1",
                        "widthPx": width,
                        "heightPx": inward + outward,
                        "inwardPx": inward,
                        "outwardPx": outward,
                        "centerAngleDegrees": angle,
                        "interpolation": "INTER_NEAREST",
                    },
                    "clean": {"path": clean_path.name, "bytes": clean_path.stat().st_size, "sha256": sha256_file(clean_path)},
                    "currentMask": {"path": mask_path.name, "bytes": mask_path.stat().st_size, "sha256": sha256_file(mask_path)},
                    "currentOverlay": {"path": overlay_path.name, "bytes": overlay_path.stat().st_size, "sha256": sha256_file(overlay_path)},
                    "changedPixelsInsideCurrentMask": changed_inside,
                    "changedPixelsOutsideCurrentMask": changed_outside,
                    "operatorFeedbackRasterized": False,
                    "inheritedReviewRasterUsed": False,
                }
            )
        del image

    require(source_reads == 4, "Exact source-read cardinality changed.")
    require(len(outputs) == 6, "Exact candidate/channel output cardinality changed.")
    manifest = {
        "schema": OUTPUT_SCHEMA,
        "revision": str(job["revision"]),
        "state": PASS_RENDER,
        "sourceImageReadCount": source_reads,
        "sourceHashesComputed": True,
        "allSourceHashesMatched": True,
        "detectorRerunPerformed": False,
        "thresholdOrAlgorithmChanged": False,
        "assetGroups": outputs,
        "assetFileCount": len(outputs) * 3,
        "cleanBaseCount": len(outputs),
        "currentMaskCount": len(outputs),
        "currentOverlayCount": len(outputs),
        "sourceMutationPerformed": False,
        "sourceDeletionPerformed": False,
        "taskOrProcessActionPerformed": False,
        "providerActivated": False,
        "waferActionPerformed": False,
        "operatorFeedbackRasterized": False,
        "inheritedReviewRasterUsed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    manifest_path = output_root / "RENDER_MANIFEST.json"
    atomic_write_json(manifest_path, manifest)
    return {
        "schema": "argos_ocv03_notch_review_command_result_v1",
        "state": PASS_RENDER,
        "manifest": str(manifest_path),
        "manifestSha256": sha256_file(manifest_path),
        "assetFileCount": 18,
        "sourceImageReadCount": 4,
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
    if args.preflight:
        job, _ = validate_job(job_path, output_root)
        result = {
            "schema": "argos_ocv03_notch_review_renderer_preflight_v1",
            "state": PASS_PREFLIGHT,
            "revision": str(job["revision"]),
            "sourceCount": len(job["sources"]),
            "candidateCount": len(job["candidates"]),
            "sourceImageBytesRead": False,
            "sourceHashesComputed": False,
            "pixelsDecoded": False,
            "outputCreated": False,
            "reviewOnly": True,
            "productionRoutingEnabled": False,
        }
    else:
        result = render(job_path, output_root)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
