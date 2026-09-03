#!/usr/bin/env python3
"""Review-only R14 source-to-glyph crop provider.

The provider consumes one hash-pinned BF/DF acquisition, runs the frozen R11
analysis in-process, evaluates every bounded full-perimeter localization
candidate (smooth-band and paired-channel) and both orientations with the
frozen R12B topology diagnostic, and returns a deterministic candidate grid
plus audit cells.  The search is explicitly notch-independent.  Canonical
truth is used only to select the most plausible grid for reference harvesting.
It is never an automatic identity, reference-admission, training, XML,
production, or hold-clearance authority.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Iterable

import cv2
import numpy as np


sys.dont_write_bytecode = True
cv2.setNumThreads(1)
cv2.ocl.setUseOpenCL(False)


REVISION = "ARGOS_OPENCV_SCRIBE_ALPHABET_CROP_R14P_20260902"
JOB_SCHEMA = "argos_opencv_scribe_alphabet_crop_job_v1"
RESULT_SCHEMA = "argos_opencv_scribe_alphabet_crop_case_result_v1"
SHA256_PATTERN = re.compile(r"^[0-9A-Fa-f]{64}$")
TOKEN_PATTERN = re.compile(r"^[A-Za-z0-9_.-]{1,80}$")
TRUTH_PATTERN = re.compile(r"^[0-9A-Z]{12}$")
PURPOSES = {"DEVELOPMENT", "INDEPENDENT_VALIDATION"}
CHANNEL_ORDER = {"BF": 0, "DF": 1}
DIRECTION_ORDER = {"FORWARD": 0, "REVERSE_180": 1}
OUTPUT_WIDTH = 96
OUTPUT_HEIGHT = 230
PATH_SUFFIX_RESERVE = 32
MAXIMUM_SAFE_EFFECTIVE_PATH = 199
MAXIMUM_JOB_BYTES = 1024 * 1024

DEPENDENCIES: dict[str, dict[str, Any]] = {
    "r11": {
        "names": ("R11.py", "ArgosOpenCvScribeV1R11.py"),
        "sha256": "7C6632B2D1C56DA4CA565DAB5BF7D46A366BCAE6663793CE5AB1ABB4739F72C9",
    },
    "r12a": {
        "names": ("R12A.py", "Run-ArgosOpenCvScribeR12BlobDiagnostic.py"),
        "sha256": "F5EB8FB3281D7D55CDD9FA4A3530A32BD33BBA3B8DB69E0A247C20935F6AD429",
    },
    "r12b": {
        "names": ("R12B.py", "Run-ArgosOpenCvScribeR12BBlobTopology.py"),
        "sha256": "D670CFCE64BF5FDF5307E69ED69A05CB7B404A78B521AB889C7F35044D666FDC",
    },
}

SAFE_AUTHORITY: dict[str, bool] = {
    "reviewOnly": True,
    "automaticIdentityAuthority": False,
    "automaticReferenceAdmissionAllowed": False,
    "trainingAuthorized": False,
    "trainingEligible": False,
    "trainingExecuted": False,
    "xmlEligible": False,
    "productionEligible": False,
    "productionRoutingEnabled": False,
    "mayClearHolds": False,
}


class GateError(RuntimeError):
    """Raised when a job, dependency, source, or output premise fails closed."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise GateError(message)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def sha256_array(image: np.ndarray) -> str:
    return sha256_bytes(np.ascontiguousarray(image).tobytes())


def source_pair_sha256(bf_sha256: str, df_sha256: str) -> str:
    payload = f"BF={bf_sha256.upper()}\nDF={df_sha256.upper()}\n".encode("ascii")
    return sha256_bytes(payload)


def read_job(path: Path) -> tuple[dict[str, Any], str]:
    require(path.is_file(), f"Job is absent: {path}")
    require(0 < path.stat().st_size <= MAXIMUM_JOB_BYTES, "Job byte length is invalid or unbounded")
    digest = sha256_file(path)
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    require(isinstance(value, dict), "Job JSON root must be an object")
    return value, digest


def canonical_json_sha256(value: Any) -> str:
    payload = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return sha256_bytes(payload)


def validate_sha256(value: Any, context: str) -> str:
    text = str(value)
    require(SHA256_PATTERN.fullmatch(text) is not None, f"{context} is not SHA-256")
    return text.upper()


def validate_authority(value: Any) -> None:
    require(isinstance(value, dict), "Job authority must be an object")
    for key, expected in SAFE_AUTHORITY.items():
        require(value.get(key) is expected, f"Job authority mismatch: {key}")
    for key in (
        "sourceMutationAllowed",
        "sourceDeletionAllowed",
        "taskOrProcessRestartAllowed",
        "providerActivationAllowed",
        "retryAuthorized",
    ):
        if key in value:
            require(value[key] is False, f"Job enables forbidden authority: {key}")


def validate_target_positions(value: Any, truth: str) -> list[dict[str, Any]]:
    require(isinstance(value, list) and value, "targetPositions must be a nonempty array")
    rows: list[dict[str, Any]] = []
    seen: set[int] = set()
    for index, raw in enumerate(value):
        require(isinstance(raw, dict), f"targetPositions[{index}] must be an object")
        position = raw.get("position")
        label = raw.get("label")
        require(isinstance(position, int) and not isinstance(position, bool), f"targetPositions[{index}].position must be an integer")
        require(1 <= position <= 10, f"Target position must be a body position from 1 through 10: {position}")
        require(isinstance(label, str) and re.fullmatch(r"[0-9A-Z]", label) is not None, f"Invalid target label at position {position}")
        require(position not in seen, f"Duplicate target position: {position}")
        require(truth[position - 1] == label, f"Target label does not match canonical truth at position {position}")
        seen.add(position)
        rows.append({"position": position, "label": label})
    return sorted(rows, key=lambda row: int(row["position"]))


def validate_source_spec(value: Any, channel: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"inputs.{channel} must be an object")
    path = str(value.get("path", ""))
    byte_count = value.get("bytes")
    require(bool(path), f"inputs.{channel}.path is absent")
    require(isinstance(byte_count, int) and not isinstance(byte_count, bool) and byte_count > 0, f"inputs.{channel}.bytes is invalid")
    validate_sha256(value.get("sha256"), f"inputs.{channel}.sha256")
    return value


def validate_job(job: dict[str, Any], r11: Any) -> tuple[dict[str, Any], list[dict[str, Any]], dict[str, Any]]:
    require(job.get("schema") == JOB_SCHEMA, "R14 job schema mismatch")
    for field in ("jobId", "caseId"):
        require(isinstance(job.get(field), str) and TOKEN_PATTERN.fullmatch(job[field]) is not None, f"Invalid {field}")
    require(isinstance(job.get("physicalIdentity"), str) and 1 <= len(job["physicalIdentity"]) <= 256, "Invalid physicalIdentity")
    require(job.get("purpose") in PURPOSES, "Unsupported purpose")
    truth = job.get("canonicalTruth")
    require(isinstance(truth, str) and TRUTH_PATTERN.fullmatch(truth) is not None, "canonicalTruth must be twelve uppercase alphanumeric characters")
    require(r11.m12_remainder(truth) == 0, "canonicalTruth failed SEMI M12 remainder")
    require(r11.m12_check_characters(truth[:10]) == truth[10:], "canonicalTruth check characters are not canonical")
    targets = validate_target_positions(job.get("targetPositions"), truth)
    validate_authority(job.get("authority"))

    inputs = job.get("inputs")
    require(isinstance(inputs, dict), "inputs must be an object")
    bf_spec = validate_source_spec(inputs.get("bf"), "bf")
    df_spec = validate_source_spec(inputs.get("df"), "df")
    require(os.path.normcase(str(bf_spec["path"])) != os.path.normcase(str(df_spec["path"])), "BF and DF source paths must differ")

    references = job.get("references")
    require(isinstance(references, dict), "references must be an object")
    require(str(references.get("excludedPhysicalIdentity", "")) == job["physicalIdentity"], "Exact-acquisition reference self-exclusion is required")
    require(bool(str(references.get("manifestPath", ""))), "Reference manifest path is absent")
    validate_sha256(references.get("manifestSha256"), "references.manifestSha256")
    roots = references.get("roots")
    require(isinstance(roots, list) and roots, "Reference roots must be a nonempty array")
    for index, root in enumerate(roots):
        require(isinstance(root, dict), f"references.roots[{index}] must be an object")
        require(bool(str(root.get("relativePrefix", ""))) and bool(str(root.get("path", ""))), f"Reference root {index} is incomplete")

    require(job.get("inputMode") == "DEVELOPMENT_AUTO_LOCALIZED_WHOLE_IMAGE", "R14 requires R11 development automatic localization")
    search = job.get("search")
    require(isinstance(search, dict), "search must be an object")
    require(search.get("expectedRegions") == [], "R14 refuses preselected expected regions")
    require(search.get("boundedExceptionSearch") is True, "Bounded exception search is required")
    require(1 <= int(search.get("maximumCandidates", 0)) <= 16, "maximumCandidates must be from 1 through 16")
    require(256 <= int(search.get("maximumWorkingDimension", 0)) <= 2048, "maximumWorkingDimension is outside the R14 bound")

    blob = job.get("blobGrid")
    require(isinstance(blob, dict), "blobGrid must be an object")
    minimum_dot_size = float(blob.get("minimumDotSize", 0.0))
    maximum_dot_size = float(blob.get("maximumDotSize", 0.0))
    maximum_perimeter = int(blob.get("maximumPerimeterRegionsEvaluated", blob.get("maximumPairedRegionsEvaluated", 0)))
    require(0.0 < minimum_dot_size < maximum_dot_size <= 64.0, "Blob diameter bounds are invalid")
    require(1 <= maximum_perimeter <= 16, "maximumPerimeterRegionsEvaluated must be from 1 through 16")
    require(maximum_perimeter >= int(search["maximumCandidates"]), "Perimeter-region bound must cover every bounded R11 candidate")
    require(blob.get("directions") == ["FORWARD", "REVERSE_180"], "R14 direction contract mismatch")

    r11_job = copy.deepcopy(job)
    r11_job["schema"] = "argos_opencv_scribe_job_v1"
    r11.validate_job_shape(r11_job)
    return r11_job, targets, {
        "minimumDotSize": minimum_dot_size,
        "maximumDotSize": maximum_dot_size,
        "maximumPerimeterRegionsEvaluated": maximum_perimeter,
    }


def resolve_dependency(base: Path, key: str) -> tuple[Path, str]:
    spec = DEPENDENCIES[key]
    candidates = [base / str(name) for name in spec["names"] if (base / str(name)).is_file()]
    require(len(candidates) == 1, f"Expected exactly one packaged {key} sibling; found {len(candidates)}")
    path = candidates[0]
    digest = sha256_file(path)
    require(digest == spec["sha256"], f"Packaged {key} SHA-256 mismatch: {digest}")
    return path, digest


def import_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, f"Could not create import specification: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def load_dependencies() -> tuple[Any, Any, Any, dict[str, Any]]:
    base = Path(__file__).resolve().parent
    paths: dict[str, Path] = {}
    hashes: dict[str, str] = {}
    for key in ("r11", "r12a", "r12b"):
        paths[key], hashes[key] = resolve_dependency(base, key)
    r11 = import_module("argos_scribe_r13b_r11", paths["r11"])
    r12a = import_module("argos_scribe_r13b_r12a", paths["r12a"])
    r12b = import_module("argos_scribe_r13b_r12b", paths["r12b"])
    evidence = {
        key: {
            "filename": paths[key].name,
            "sha256": hashes[key],
            "expectedSha256": DEPENDENCIES[key]["sha256"],
        }
        for key in ("r11", "r12a", "r12b")
    }
    return r11, r12a, r12b, evidence


def perimeter_regions(r11_result: dict[str, Any], maximum: int) -> list[dict[str, Any]]:
    localization = r11_result.get("localization", {})
    rows = localization.get("exceptionDiagnostics", [])
    require(isinstance(rows, list), "R11 exception diagnostics are malformed")
    selected = [
        row for row in rows
        if isinstance(row, dict)
        and str(row.get("source", "")).endswith("_FULL_PERIMETER_REVIEW_ONLY_DEVELOPMENT")
        and (
            str(row.get("source", "")).startswith("SMOOTH_")
            or str(row.get("source", "")).startswith("PAIRED_BF_DF_")
        )
    ]
    require(len(selected) <= maximum, "R11 emitted more perimeter regions than the declared complete-evaluation bound")
    return sorted(
        selected,
        key=lambda row: (
            -float(row.get("score", 0.0)),
            str(row.get("regionId", "")),
        ),
    )


def non_target_truth_score(text: str, truth: str, target_positions: set[int]) -> tuple[int, list[int]]:
    mismatches = [
        position
        for position in range(1, 13)
        if position not in target_positions
        and (len(text) != 12 or text[position - 1] != truth[position - 1])
    ]
    return 12 - len(target_positions) - len(mismatches), mismatches


def grid_selection_key(row: dict[str, Any]) -> tuple[Any, ...]:
    return (
        -int(row["nonTargetCanonicalMatchCount"]),
        -int(bool(row["checksumValid"])),
        -float(row["selectionScore"]),
        -float(row["meanTopScore"]),
        -float(row["localizationScore"]),
        str(row["regionId"]),
        CHANNEL_ORDER[str(row["channel"])],
        DIRECTION_ORDER[str(row["direction"])],
        int(row["gridY"]),
        int(row["gridX"]),
        int(row["cellWidth"]),
        int(row["cellHeight"]),
    )


def normalized_cell(raw: np.ndarray, source_y: int, width: int = OUTPUT_WIDTH, height: int = OUTPUT_HEIGHT) -> np.ndarray:
    require(raw.ndim == 2 and raw.dtype == np.uint8, "Raw grid cell is not 8-bit grayscale")
    require(raw.shape[0] > 0 and raw.shape[1] > 0, "Raw grid cell is empty")
    if raw.shape[1] >= width:
        source_x = (raw.shape[1] - width) // 2
        content = raw[:, source_x:source_x + width]
    else:
        content = np.zeros((raw.shape[0], width), dtype=np.uint8)
        target_x = (width - raw.shape[1]) // 2
        content[:, target_x:target_x + raw.shape[1]] = raw
    if content.shape[0] >= height:
        crop_y = (content.shape[0] - height) // 2
        normalized = content[crop_y:crop_y + height, :]
    else:
        normalized = np.zeros((height, width), dtype=np.uint8)
        target_y = (height - content.shape[0]) // 2
        if (target_y - source_y) % 2 and target_y > 0:
            target_y -= 1
        normalized[target_y:target_y + content.shape[0], :] = content
    return cv2.cvtColor(cv2.bitwise_not(normalized), cv2.COLOR_GRAY2BGR)


def encode_png(image: np.ndarray) -> bytes:
    success, encoded = cv2.imencode(".png", image, [cv2.IMWRITE_PNG_COMPRESSION, 9])
    require(bool(success), "OpenCV could not encode PNG output")
    return encoded.tobytes()


def make_region(r11: Any, row: dict[str, Any]) -> Any:
    return r11.Region(
        str(row["regionId"]),
        str(row["source"]),
        float(row["x"]),
        float(row["y"]),
        float(row["width"]),
        float(row["height"]),
        float(row["angleDegrees"]),
        float(row["score"]),
    )


def evaluate_all_grids(
    r11: Any,
    r12a: Any,
    r12b: Any,
    bf: np.ndarray,
    df: np.ndarray,
    prototypes: list[Any],
    excluded_identity: str,
    regions: list[dict[str, Any]],
    truth: str,
    targets: list[dict[str, Any]],
    blob: dict[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    target_set = {int(row["position"]) for row in targets}
    candidates: list[dict[str, Any]] = []
    matrix: list[dict[str, Any]] = []
    for region_row in regions:
        region = make_region(r11, region_row)
        for channel, gray in (("BF", bf), ("DF", df)):
            rectified = r11.rectify(gray, region)
            if rectified is None:
                for direction in ("FORWARD", "REVERSE_180"):
                    matrix.append({
                        "regionId": region.region_id,
                        "channel": channel,
                        "direction": direction,
                        "state": "HOLD_RECTIFICATION_FAILED",
                        "detail": "R11 returned no rectified patch",
                    })
                continue
            rectified_hash = sha256_array(rectified)
            for direction, oriented in (
                ("FORWARD", rectified),
                ("REVERSE_180", cv2.rotate(rectified, cv2.ROTATE_180)),
            ):
                oriented_hash = sha256_array(oriented)
                try:
                    evaluated, canvas = r12b.evaluate_patch(
                        r11,
                        r12a,
                        oriented,
                        prototypes,
                        excluded_identity,
                        float(blob["minimumDotSize"]),
                        float(blob["maximumDotSize"]),
                    )
                except (ValueError, cv2.error) as error:
                    matrix.append({
                        "regionId": region.region_id,
                        "channel": channel,
                        "direction": direction,
                        "state": "HOLD_NO_EVALUABLE_GRID",
                        "detail": str(error),
                        "rectifiedPatchArraySha256": rectified_hash,
                        "orientedPatchArraySha256": oriented_hash,
                    })
                    continue
                canvas_hash = sha256_array(canvas)
                grids = evaluated.get("gridDiagnostics", [])
                require(isinstance(grids, list) and grids, "R12B returned no grid diagnostics after successful evaluation")
                matrix.append({
                    "regionId": region.region_id,
                    "channel": channel,
                    "direction": direction,
                    "state": "EVALUATED",
                    "gridCount": len(grids),
                    "detectedBlobCount": int(evaluated["detectedBlobCount"]),
                    "diameterQualifiedBlobCount": int(evaluated["diameterQualifiedBlobCount"]),
                    "rectifiedPatchArraySha256": rectified_hash,
                    "orientedPatchArraySha256": oriented_hash,
                    "blobCanvasArraySha256": canvas_hash,
                })
                for grid_index, grid in enumerate(grids):
                    text = str(grid.get("imageFirstString", ""))
                    match_count, mismatches = non_target_truth_score(text, truth, target_set)
                    candidate = {
                        "candidateId": f"{region.region_id}_{channel}_{direction}_G{grid_index:02d}",
                        "regionId": region.region_id,
                        "regionSource": region.source,
                        "localizationScore": float(region.localization_score),
                        "region": {
                            "centerX": float(region.center_x),
                            "centerY": float(region.center_y),
                            "width": float(region.width),
                            "height": float(region.height),
                            "angleDegrees": float(region.angle_degrees),
                        },
                        "channel": channel,
                        "direction": direction,
                        "gridX": int(grid["gridX"]),
                        "gridY": int(grid["gridY"]),
                        "cellWidth": int(grid["cellWidth"]),
                        "cellHeight": int(grid["cellHeight"]),
                        "selectionScore": float(grid["selectionScore"]),
                        "meanTopScore": float(grid["meanTopScore"]),
                        "descriptorImageFirstString": str(grid.get("descriptorImageFirstString", "")),
                        "imageFirstString": text,
                        "observedCheckCharacters": str(grid.get("observedCheckCharacters", "")),
                        "expectedCheckCharacters": str(grid.get("expectedCheckCharacters", "")),
                        "boundaryComplete": bool(grid.get("boundaryComplete")),
                        "checksumValid": bool(grid.get("checksumValid")),
                        "proposedString": str(grid.get("proposedString", "")),
                        "topologySubstitutions": grid.get("topologySubstitutions", []),
                        "topologyDiagnostics": grid.get("topologyDiagnostics", []),
                        "nonTargetCanonicalMatchCount": match_count,
                        "nonTargetCanonicalPositionCount": 12 - len(target_set),
                        "nonTargetCanonicalMismatchPositions": mismatches,
                        "rectifiedPatchArraySha256": rectified_hash,
                        "orientedPatchArraySha256": oriented_hash,
                        "blobCanvasArraySha256": canvas_hash,
                        "_canvas": canvas,
                    }
                    candidates.append(candidate)
    return candidates, matrix


def public_candidate(candidate: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in candidate.items() if not key.startswith("_")}


def selected_artifacts(
    selected: dict[str, Any],
    truth: str,
    targets: list[dict[str, Any]],
    source_evidence: dict[str, Any],
) -> tuple[dict[str, bytes], dict[str, Any], list[dict[str, Any]]]:
    canvas = selected["_canvas"]
    x = int(selected["gridX"])
    y = int(selected["gridY"])
    pitch = int(selected["cellWidth"])
    height = int(selected["cellHeight"])
    grid_width = 12 * pitch
    require(x >= 0 and y >= 0 and pitch > 0 and height > 0, "Selected grid geometry is invalid")
    require(x + grid_width <= canvas.shape[1] and y + height <= canvas.shape[0], "Selected grid escapes the R12B blob canvas")
    grid = canvas[y:y + height, x:x + grid_width].copy()
    require(grid.dtype == np.uint8 and grid.ndim == 2, "Selected grid is not 8-bit grayscale")
    grid_bytes = encode_png(cv2.cvtColor(grid, cv2.COLOR_GRAY2BGR))
    grid_sha256 = sha256_bytes(grid_bytes)
    artifacts: dict[str, bytes] = {"selected_grid.png": grid_bytes}
    pair_sha256 = source_pair_sha256(
        str(source_evidence["bf"]["sha256"]),
        str(source_evidence["df"]["sha256"]),
    )
    artifact_rows: list[dict[str, Any]] = [{
        "kind": "ORIENTED_GRID",
        "relativePath": "selected_grid.png",
        "sha256": grid_sha256,
        "sourceChannel": "BF_DF_DERIVED",
        "sourceSha256": pair_sha256,
    }]
    cell_rows: list[dict[str, Any]] = []
    target_rows: list[dict[str, Any]] = []
    target_by_position = {int(row["position"]): str(row["label"]) for row in targets}
    for index, label in enumerate(truth):
        position = index + 1
        source_x = index * pitch
        raw = grid[:, source_x:source_x + pitch]
        normalized = normalized_cell(raw, y)
        cell_relative = f"cells/P{position:02d}_{label}.png"
        cell_bytes = encode_png(normalized)
        cell_sha256 = sha256_bytes(cell_bytes)
        artifacts[cell_relative] = cell_bytes
        artifact_rows.append({
            "kind": "AUDIT_CELL",
            "relativePath": cell_relative,
            "sha256": cell_sha256,
            "sourceChannel": "SELECTED_GRID",
            "sourceSha256": grid_sha256,
        })
        cell_row = {
            "position": position,
            "label": label,
            "relativePath": cell_relative,
            "sha256": cell_sha256,
            "selectedGridSha256": grid_sha256,
            "gridRelativeBounds": {"x": source_x, "y": 0, "width": pitch, "height": height},
            "blobCanvasBounds": {"x": x + source_x, "y": y, "width": pitch, "height": height},
            "outputWidth": int(normalized.shape[1]),
            "outputHeight": int(normalized.shape[0]),
            "outputChannels": int(normalized.shape[2]),
        }
        cell_rows.append(cell_row)
        if position in target_by_position:
            require(target_by_position[position] == label, f"Target/cell label mismatch at position {position}")
            target_relative = f"targets/P{position:02d}_{label}.png"
            artifacts[target_relative] = cell_bytes
            artifact_rows.append({
                "kind": "TARGET_GLYPH",
                "relativePath": target_relative,
                "sha256": cell_sha256,
                "sourceChannel": "AUDIT_CELL",
                "sourceSha256": cell_sha256,
            })
            target_rows.append({
                "position": position,
                "label": label,
                "relativePath": target_relative,
                "sha256": cell_sha256,
                "sourceCellRelativePath": cell_relative,
                "sourceCellSha256": cell_sha256,
                "byteIdenticalToSourceCell": True,
                "referenceAdmissionEligible": False,
            })
    require(len(cell_rows) == 12, "Exactly twelve audit cells were not produced")
    require(len(target_rows) == len(targets), "Exact target duplicates were not produced")
    channel_key = str(selected["channel"]).lower()
    source = source_evidence[channel_key]
    provenance = {
        "sourceToGrid": {
            "sourceChannel": selected["channel"],
            "sourcePath": source["path"],
            "sourceSha256": source["sha256"],
            "sourceBytes": source["bytes"],
            "sourceWidth": source["width"],
            "sourceHeight": source["height"],
            "regionId": selected["regionId"],
            "region": selected["region"],
            "direction": selected["direction"],
            "rectifiedPatchArraySha256": selected["rectifiedPatchArraySha256"],
            "orientedPatchArraySha256": selected["orientedPatchArraySha256"],
            "blobCanvasArraySha256": selected["blobCanvasArraySha256"],
            "blobCanvasBounds": {"x": x, "y": y, "width": grid_width, "height": height},
            "selectedGridRelativePath": "selected_grid.png",
            "selectedGridSha256": grid_sha256,
            "selectedGridWidth": int(grid.shape[1]),
            "selectedGridHeight": int(grid.shape[0]),
            "selectedGridChannels": 3,
        },
        "gridToCells": cell_rows,
        "cellsToTargets": target_rows,
        "chainComplete": True,
    }
    return artifacts, provenance, artifact_rows


def run_case(job: dict[str, Any], job_path: Path, job_sha256: str) -> tuple[dict[str, Any], dict[str, bytes]]:
    r11, r12a, r12b, dependency_evidence = load_dependencies()
    r11_job, targets, blob = validate_job(job, r11)
    roots = {
        str(row["relativePrefix"]): Path(str(row["path"]))
        for row in r11_job["references"]["roots"]
    }
    prototypes, reference_evidence = r11.load_reference_prototypes(
        Path(str(r11_job["references"]["manifestPath"])),
        str(r11_job["references"]["manifestSha256"]),
        roots,
    )
    bf, bf_evidence = r11.decode_source(r11_job["inputs"]["bf"])
    df, df_evidence = r11.decode_source(r11_job["inputs"]["df"])
    require(bf.shape == df.shape, "BF and DF dimensions differ")
    source_evidence = {
        "bf": bf_evidence,
        "df": df_evidence,
        "jobPath": str(job_path),
        "jobSha256": job_sha256,
        "bfDecodeCount": 1,
        "dfDecodeCount": 1,
        "decodeImplementation": "R11.decode_source_TO_R11.decode_gray_exact",
        "sourceHashVerifiedBeforeDecode": True,
    }
    r11_result = r11.analyze_images(
        r11_job,
        bf,
        df,
        prototypes,
        reference_evidence,
        source_evidence,
    )
    regions = perimeter_regions(r11_result, int(blob["maximumPerimeterRegionsEvaluated"]))
    candidates, matrix = evaluate_all_grids(
        r11,
        r12a,
        r12b,
        bf,
        df,
        prototypes,
        str(r11_job["references"]["excludedPhysicalIdentity"]),
        regions,
        str(job["canonicalTruth"]),
        targets,
        blob,
    )
    ranked = sorted(candidates, key=grid_selection_key)
    selected = ranked[0] if ranked else None
    expected_attempts = len(regions) * 2 * 2
    require(len(matrix) == expected_attempts, "Not every paired-region/channel/direction combination was attempted")

    holds: list[dict[str, str]] = []
    artifacts: dict[str, bytes] = {}
    artifact_rows: list[dict[str, Any]] = []
    provenance: dict[str, Any] | None = None
    if not regions:
        state = "HOLD_R14_NO_PERIMETER_LOCALIZATION"
        holds.append({"code": "SCRIBE_ALPHABET_LOCALIZATION_HOLD", "detail": "R11 produced no bounded full-perimeter localization region."})
    elif selected is None:
        state = "HOLD_R14_NO_EVALUABLE_GRID"
        holds.append({"code": "SCRIBE_ALPHABET_GRID_HOLD", "detail": "R12B produced no evaluable twelve-cell grid in any bounded perimeter region, channel, or direction."})
    else:
        artifacts, provenance, artifact_rows = selected_artifacts(
            selected,
            str(job["canonicalTruth"]),
            targets,
            source_evidence,
        )
        if selected["nonTargetCanonicalMismatchPositions"]:
            state = "HOLD_R14_GRID_NON_TARGET_TRUTH_MISMATCH"
            holds.append({
                "code": "SCRIBE_ALPHABET_GRID_SELECTION_UNCERTAIN_HOLD",
                "detail": "The best bounded R12B grid does not reproduce every non-target canonical truth position.",
            })
        else:
            state = "HOLD_R14_REVIEW_ONLY_GRID_SELECTED"
    holds.append({
        "code": "SCRIBE_ALPHABET_REFERENCE_ADMISSION_HOLD",
        "detail": "Candidate crops are review-only and cannot be admitted automatically; the frozen reference manifest remains unchanged.",
    })

    result = {
        "schema": RESULT_SCHEMA,
        "revision": REVISION,
        "classification": "PENDING_GATE",
        "state": state,
        "caseId": job["caseId"],
        "jobId": job["jobId"],
        "physicalIdentity": job["physicalIdentity"],
        "purpose": job["purpose"],
        "canonicalTruth": job["canonicalTruth"],
        "canonicalTruthUse": "REVIEW_ONLY_GRID_SELECTION_NOT_IDENTITY_ACCEPTANCE",
        "targetPositions": targets,
        "eligibleIdentity": False,
        "referenceAdmissionEligible": False,
        "sourceEvidence": source_evidence,
        "provenance": {
            "sources": {
                "bf": {"sha256": bf_evidence["sha256"], "verified": True},
                "df": {"sha256": df_evidence["sha256"], "verified": True},
            },
            "sourcePairSha256": source_pair_sha256(
                str(bf_evidence["sha256"]),
                str(df_evidence["sha256"]),
            ),
        },
        "artifacts": artifact_rows,
        "referenceEvidence": reference_evidence,
        "dependencyEvidence": dependency_evidence,
        "providerEvidence": {
            "path": str(Path(__file__).resolve()),
            "sha256": sha256_file(Path(__file__).resolve()),
            "opencvVersion": cv2.__version__,
            "numpyVersion": np.__version__,
            "bytecodeWritesDisabled": bool(sys.dont_write_bytecode),
        },
        "r11Analysis": {
            "resultSha256": canonical_json_sha256(r11_result),
            "state": r11_result.get("state"),
            "imageFirstString": r11_result.get("imageFirstString", ""),
            "proposedString": r11_result.get("proposedString", ""),
            "localization": r11_result.get("localization", {}),
            "holds": r11_result.get("holds", []),
        },
        "blobGridEvaluation": {
            "minimumDotSize": blob["minimumDotSize"],
            "maximumDotSize": blob["maximumDotSize"],
            "perimeterRegionCount": len(regions),
            "perimeterRegions": regions,
            "candidateFamiliesEvaluated": sorted({
                "SMOOTH" if str(row.get("source", "")).startswith("SMOOTH_") else "PAIRED_BF_DF"
                for row in regions
            }),
            "notchUsed": False,
            "expectedRegionChannelDirectionAttempts": expected_attempts,
            "actualRegionChannelDirectionAttempts": len(matrix),
            "allBoundedPairedRegionsChannelsAndDirectionsAttempted": len(matrix) == expected_attempts,
            "evaluationMatrix": matrix,
            "evaluableGridCount": len(ranked),
            "selectionRule": "MAX_NON_TARGET_CANONICAL_MATCH_THEN_R12B_CHECKSUM_SELECTION_AND_MEAN_SCORE",
            "selectedCandidate": None if selected is None else public_candidate(selected),
            "rankedCandidates": [public_candidate(row) for row in ranked],
        },
        "artifactProvenance": provenance,
        "holds": holds,
        "normalization": {
            "implementation": "OPENCV_CENTER_CROP_OR_ZERO_PAD_NO_RESAMPLING_THEN_BITWISE_INVERT",
            "sourcePolarity": "WHITE_DOTS_ON_BLACK_RESIDUAL_BLOB_CANVAS",
            "outputPolarity": "BLACK_DOTS_ON_WHITE_R11_REFERENCE_RASTER",
            "verticalPlacement": "CENTER_PAD_ADJUSTED_UP_ONE_PIXEL_WHEN_NEEDED_TO_PRESERVE_SOURCE_Y_PARITY_FOR_ROUND_TO_EVEN",
            "outputWidth": OUTPUT_WIDTH,
            "outputHeight": OUTPUT_HEIGHT,
            "outputChannels": 3,
        },
        "invariants": {
            "sourceImagesMutated": False,
            "frozenReferenceManifestMutated": False,
            "automaticRetryPerformed": False,
            "externalAccessPerformed": False,
            "identityAccepted": False,
            "referenceAdmitted": False,
            "trainingPerformed": False,
            "xmlWritten": False,
            "productionStateChanged": False,
            "holdCleared": False,
        },
        "authority": dict(SAFE_AUTHORITY),
    }
    return result, artifacts


def validate_output_path(output_root: Path) -> tuple[Path, Path]:
    root = output_root.resolve()
    require(root.parent != root, "Output root cannot be a filesystem root")
    require(len(root.name) <= 80 and root.name not in ("", ".", ".."), "Output root component is invalid")
    partial = root.with_name(root.name + ".partial")
    require(not root.exists(), f"Refusing to replace case output: {root}")
    require(not partial.exists(), f"Prior partial case output exists: {partial}")
    require(root.parent.is_dir(), f"Output parent is absent: {root.parent}")
    planned = [
        partial / "CASE_RESULT.json.partial",
        partial / "selected_grid.png",
        partial / "cells" / "P12_Z.png",
        partial / "targets" / "P12_Z.png",
    ]
    require(
        max(len(str(path)) + PATH_SUFFIX_RESERVE for path in planned) <= MAXIMUM_SAFE_EFFECTIVE_PATH,
        "Case output exceeds the R14 path budget",
    )
    require(all(len(part) <= 80 for path in planned for part in path.parts), "A planned output component exceeds 80 characters")
    return root, partial


def write_new(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
    except Exception:
        try:
            path.unlink(missing_ok=True)
        except Exception:
            pass
        raise


def commit_case_output(output_root: Path, result: dict[str, Any], artifacts: dict[str, bytes]) -> str:
    root, partial = validate_output_path(output_root)
    partial.mkdir()
    for relative, payload in sorted(artifacts.items()):
        relative_path = Path(relative)
        require(not relative_path.is_absolute() and ".." not in relative_path.parts, f"Unsafe artifact path: {relative}")
        write_new(partial / relative_path, payload)
    result_payload = (json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8")
    write_new(partial / "CASE_RESULT.json", result_payload)
    partial.rename(root)
    return sha256_bytes(result_payload)


def failure_result(job: dict[str, Any] | None, job_path: Path, error: Exception) -> dict[str, Any]:
    safe_job = job if isinstance(job, dict) else {}
    inputs = safe_job.get("inputs") if isinstance(safe_job.get("inputs"), dict) else {}
    declared_hashes: dict[str, str | None] = {}
    for channel in ("bf", "df"):
        source = inputs.get(channel) if isinstance(inputs.get(channel), dict) else {}
        value = source.get("sha256")
        declared_hashes[channel] = str(value).upper() if SHA256_PATTERN.fullmatch(str(value)) else None
    declared_pair = (
        source_pair_sha256(str(declared_hashes["bf"]), str(declared_hashes["df"]))
        if declared_hashes["bf"] is not None and declared_hashes["df"] is not None
        else None
    )
    return {
        "schema": RESULT_SCHEMA,
        "revision": REVISION,
        "classification": "PENDING_GATE",
        "state": "HOLD_R14_INPUT_OR_PROVIDER_GATE_FAILED",
        "caseId": safe_job.get("caseId"),
        "jobId": safe_job.get("jobId"),
        "physicalIdentity": safe_job.get("physicalIdentity"),
        "purpose": safe_job.get("purpose"),
        "eligibleIdentity": False,
        "referenceAdmissionEligible": False,
        "provenance": {
            "sources": {
                "bf": {"sha256": declared_hashes["bf"], "verified": False},
                "df": {"sha256": declared_hashes["df"], "verified": False},
            },
            "sourcePairSha256": declared_pair,
        },
        "artifacts": [],
        "failure": {
            "errorType": type(error).__name__,
            "detail": str(error),
            "jobPath": str(job_path),
            "jobSha256": sha256_file(job_path) if job_path.is_file() else None,
        },
        "holds": [{
            "code": "SCRIBE_ALPHABET_PROVIDER_GATE_HOLD",
            "detail": "The contract, dependency, source-hash, decode, or provider gate failed closed; no candidate raster was emitted.",
        }],
        "invariants": {
            "sourceImagesMutated": False,
            "frozenReferenceManifestMutated": False,
            "automaticRetryPerformed": False,
            "externalAccessPerformed": False,
            "identityAccepted": False,
            "referenceAdmitted": False,
            "trainingPerformed": False,
            "xmlWritten": False,
            "productionStateChanged": False,
            "holdCleared": False,
        },
        "authority": dict(SAFE_AUTHORITY),
    }


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    return parser.parse_args(list(argv))


def main(argv: Iterable[str]) -> int:
    arguments = parse_arguments(argv)
    job_path = arguments.job.resolve()
    output_root = arguments.output_root.resolve()
    validate_output_path(output_root)
    job: dict[str, Any] | None = None
    try:
        job, job_sha256 = read_job(job_path)
        result, artifacts = run_case(job, job_path, job_sha256)
        exit_code = 0
    except Exception as error:
        result = failure_result(job, job_path, error)
        artifacts = {}
        exit_code = 2
    result_sha256 = commit_case_output(output_root, result, artifacts)
    print(json.dumps({
        "state": result["state"],
        "caseId": result.get("caseId"),
        "outputRoot": str(output_root),
        "caseResultSha256": result_sha256,
        "artifactCount": len(artifacts),
    }, separators=(",", ":")))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
