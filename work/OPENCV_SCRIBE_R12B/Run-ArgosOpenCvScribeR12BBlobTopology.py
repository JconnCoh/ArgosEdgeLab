#!/usr/bin/env python3
"""Review-only blob topology supplement for uncovered scribe glyph labels."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np

sys.dont_write_bytecode = True


REVISION = "ARGOS_OPENCV_SCRIBE_R12B_BLOB_TOPOLOGY_20260902"
SCHEMA = "argos_opencv_scribe_blob_topology_diagnostic_v1"


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load module: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    payload = json.dumps(value, indent=2, ensure_ascii=False) + "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise FileExistsError(f"Refusing to replace existing diagnostic: {path}")
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(payload)


def line_intersection(first: tuple[int, int, int, int], second: tuple[int, int, int, int]) -> tuple[float, float] | None:
    x1, y1, x2, y2 = first
    x3, y3, x4, y4 = second
    denominator = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if abs(denominator) < 1e-9:
        return None
    determinant_first = x1 * y2 - y1 * x2
    determinant_second = x3 * y4 - y3 * x4
    return (
        (determinant_first * (x3 - x4) - (x1 - x2) * determinant_second) / denominator,
        (determinant_first * (y3 - y4) - (y1 - y2) * determinant_second) / denominator,
    )


def missing_glyph_topology(cell: np.ndarray, missing_labels: set[str]) -> dict[str, Any]:
    binary = cv2.dilate(
        (cell > 0).astype(np.uint8) * 255,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)),
    )
    detected = cv2.HoughLinesP(
        binary, 1, np.pi / 180.0,
        threshold=18, minLineLength=25, maxLineGap=10,
    )
    rows: dict[str, list[tuple[float, tuple[int, int, int, int]]]] = {
        "vertical": [], "positiveDiagonal": [],
        "negativeDiagonal": [], "horizontal": [],
    }
    if detected is not None:
        for x1, y1, x2, y2 in detected.reshape(-1, 4):
            dx = float(x2 - x1)
            dy = float(y2 - y1)
            length = math.hypot(dx, dy)
            angle = math.degrees(math.atan2(dy, dx))
            if angle > 90.0:
                angle -= 180.0
            if angle <= -90.0:
                angle += 180.0
            if abs(angle) >= 75.0:
                family = "vertical"
            elif 35.0 <= angle <= 70.0:
                family = "positiveDiagonal"
            elif -70.0 <= angle <= -35.0:
                family = "negativeDiagonal"
            elif abs(angle) <= 20.0:
                family = "horizontal"
            else:
                continue
            rows[family].append((length, (int(x1), int(y1), int(x2), int(y2))))
    for family in rows:
        rows[family].sort(key=lambda item: item[0], reverse=True)
    height = float(cell.shape[0])
    width = float(cell.shape[1])
    ratios = {
        family: (values[0][0] / height if values else 0.0)
        for family, values in rows.items()
    }
    positive = ratios["positiveDiagonal"]
    negative = ratios["negativeDiagonal"]
    vertical = ratios["vertical"]
    horizontal = ratios["horizontal"]
    left_spine = any(
        length / height >= 0.45
        and (line[0] + line[2]) / 2.0 <= 0.45 * width
        for length, line in rows["vertical"]
    )
    intersection: tuple[float, float] | None = None
    if rows["positiveDiagonal"] and rows["negativeDiagonal"]:
        intersection = line_intersection(
            rows["positiveDiagonal"][0][1], rows["negativeDiagonal"][0][1]
        )
    central_intersection = bool(
        intersection is not None
        and 0.20 * width <= intersection[0] <= 0.80 * width
        and 0.20 * height <= intersection[1] <= 0.80 * height
    )
    label = ""
    if (
        "X" in missing_labels
        and min(positive, negative) >= 0.48
        and vertical < 0.40
        and central_intersection
    ):
        label = "X"
    elif (
        "K" in missing_labels
        and vertical >= 0.48
        and max(positive, negative) >= 0.48
        and min(positive, negative) >= 0.28
        and horizontal < 0.42
        and left_spine
    ):
        label = "K"
    return {
        "label": label,
        "lineLengthRatios": {key: round(value, 6) for key, value in ratios.items()},
        "leftSpine": left_spine,
        "centralDiagonalIntersection": central_intersection,
        "diagonalIntersection": (
            {"x": round(intersection[0], 3), "y": round(intersection[1], 3)}
            if intersection is not None else None
        ),
    }


def evaluate_patch(
    r11: Any,
    r12a: Any,
    patch: np.ndarray,
    prototypes: list[Any],
    excluded_identity: str,
    minimum_dot_size: float,
    maximum_dot_size: float,
) -> tuple[dict[str, Any], np.ndarray]:
    keypoints = r12a.make_blob_detector().detect(patch)
    points = np.asarray([
        (float(row.pt[0]), float(row.pt[1]), float(row.size))
        for row in keypoints
        if minimum_dot_size <= row.size <= maximum_dot_size
    ], dtype=np.float32)
    if len(points) < 40:
        raise ValueError("Too few diameter-qualified blob points for a twelve-cell diagnostic.")
    grids = r12a.select_grids(points, patch.shape[1], patch.shape[0])
    if not grids:
        raise ValueError("Diameter-qualified blob points did not form a grid candidate.")
    _, canvas_y, _, canvas_height = grids[0]
    canvas = np.zeros_like(patch, dtype=np.float32)
    for point_x, point_y, _ in points:
        if canvas_y <= point_y < canvas_y + canvas_height:
            cv2.circle(canvas, (int(round(point_x)), int(round(point_y))), 2, 255, -1)
    active = r11.filtered_prototypes(prototypes, excluded_identity)
    bank = r11.PrototypeBank.from_prototypes(active)
    present_labels = {str(item.label) for item in active}
    missing_labels = set(r11.BODY_LABELS) - present_labels
    evaluated: list[dict[str, Any]] = []
    for x, y, pitch, height in grids:
        grid = r11.evaluate_grid(canvas, bank, x, y, pitch, height)
        if grid is None:
            continue
        descriptor_chars = [str(row["imageFirst"]) for row in grid["positions"]]
        direct_chars = list(descriptor_chars)
        topology_rows: list[dict[str, Any]] = []
        for position in range(10):
            cell = canvas[y:y + height, x + position * pitch:x + (position + 1) * pitch]
            topology = missing_glyph_topology(cell, missing_labels)
            topology["position"] = position + 1
            topology["descriptorCharacter"] = descriptor_chars[position]
            topology_rows.append(topology)
            if topology["label"]:
                direct_chars[position] = str(topology["label"])
        descriptor_string = "".join(descriptor_chars)
        direct_string = "".join(direct_chars)
        expected_check = r11.m12_check_characters(direct_string[:10])
        boundary_complete = (
            float(grid["leadingBoundaryScore"]) >= r11.BOUNDARY_MINIMUM_SCORE
            and float(grid["trailingBoundaryScore"]) >= r11.BOUNDARY_MINIMUM_SCORE
        )
        checksum_valid = bool(
            boundary_complete
            and direct_string[10:] == expected_check
            and r11.m12_remainder(direct_string) == 0
        )
        evaluated.append({
            "gridX": int(x), "gridY": int(y),
            "cellWidth": int(pitch), "cellHeight": int(height),
            "selectionScore": float(grid["selectionScore"]),
            "meanTopScore": float(grid["meanTopScore"]),
            "descriptorImageFirstString": descriptor_string,
            "imageFirstString": direct_string,
            "observedCheckCharacters": direct_string[10:],
            "expectedCheckCharacters": expected_check,
            "boundaryComplete": boundary_complete,
            "checksumValid": checksum_valid,
            "proposedString": direct_string if checksum_valid else "",
            "topologySubstitutions": [row for row in topology_rows if row["label"]],
            "topologyDiagnostics": topology_rows,
            "checksumSearchApplied": False,
        })
    if not evaluated:
        raise ValueError("Diameter-qualified blob points did not form an evaluable grid.")
    best = dict(max(
        evaluated,
        key=lambda row: (
            bool(row["checksumValid"]),
            float(row["selectionScore"]),
            float(row["meanTopScore"]),
        ),
    ))
    best["gridDiagnostics"] = evaluated
    best["detectedBlobCount"] = len(keypoints)
    best["diameterQualifiedBlobCount"] = int(len(points))
    best["minimumDotSize"] = minimum_dot_size
    best["maximumDotSize"] = maximum_dot_size
    best["missingBodyReferenceLabels"] = "".join(sorted(missing_labels))
    best["referenceCoverageHold"] = bool(missing_labels)
    return best, np.clip(canvas, 0, 255).astype(np.uint8)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", required=True, type=Path)
    parser.add_argument("--legacy-result", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    parser.add_argument("--minimum-dot-size", type=float, default=2.0)
    parser.add_argument("--maximum-dot-size", type=float, default=4.5)
    args = parser.parse_args()
    if args.output_root.exists():
        raise FileExistsError(f"Output root already exists: {args.output_root}")

    r12a_path = Path(__file__).resolve().parents[1] / "OPENCV_SCRIBE_R12A" / "Run-ArgosOpenCvScribeR12BlobDiagnostic.py"
    r12a = load_module("argos_scribe_r12a_topology_base", r12a_path)
    r11, r11_path = r12a.load_r11()
    job = read_json(args.job)
    legacy = read_json(args.legacy_result)
    legacy_valid = [row for row in legacy.get("hypotheses", []) if row.get("checksumValid")]
    base: dict[str, Any] = {
        "schema": SCHEMA,
        "revision": REVISION,
        "jobId": job.get("jobId"),
        "legacyResultSha256": sha256_file(args.legacy_result),
        "r11ProviderSha256": sha256_file(r11_path),
        "r12aDiagnosticSha256": sha256_file(r12a_path),
        "authority": {
            "reviewOnly": True,
            "automaticIdentityAuthority": False,
            "trainingEligible": False,
            "xmlEligible": False,
            "productionEligible": False,
            "mayClearHolds": False,
        },
    }
    if legacy_valid:
        base.update({
            "state": "LEGACY_CHECKSUM_VALID_BLOB_TOPOLOGY_SKIPPED",
            "legacyImageFirstString": legacy.get("imageFirstString", ""),
            "legacyProposedString": legacy.get("proposedString", ""),
            "blobTopologyDiagnostics": [],
        })
        write_json_new(args.output_root / "result.json", base)
        return 0

    roots = {
        str(row["relativePrefix"]): Path(str(row["path"]))
        for row in job["references"]["roots"]
    }
    prototypes, reference_evidence = r11.load_reference_prototypes(
        Path(str(job["references"]["manifestPath"])),
        str(job["references"]["manifestSha256"]), roots,
    )
    bf, bf_evidence = r11.decode_source(job["inputs"]["bf"])
    df, df_evidence = r11.decode_source(job["inputs"]["df"])
    paired = [
        row for row in legacy["localization"]["exceptionDiagnostics"]
        if "PAIRED_BF_DF" in str(row.get("source", ""))
    ]
    if not paired:
        raise ValueError("Legacy result has no paired BF/DF localization candidate.")
    selected = max(paired, key=lambda row: (float(row["score"]), str(row["regionId"])))
    region = r11.Region(
        str(selected["regionId"]), str(selected["source"]),
        float(selected["x"]), float(selected["y"]),
        float(selected["width"]), float(selected["height"]),
        float(selected["angleDegrees"]), float(selected["score"]),
    )
    diagnostics: list[dict[str, Any]] = []
    canvases: list[tuple[str, np.ndarray]] = []
    for channel, patch in (("BF", r11.rectify(bf, region)), ("DF", r11.rectify(df, region))):
        if patch is None:
            continue
        for direction, oriented in (
            ("FORWARD", patch),
            ("REVERSE_180", cv2.rotate(patch, cv2.ROTATE_180)),
        ):
            try:
                evaluated, canvas = evaluate_patch(
                    r11, r12a, oriented, prototypes,
                    str(job["references"].get("excludedPhysicalIdentity", "")),
                    args.minimum_dot_size, args.maximum_dot_size,
                )
            except ValueError as error:
                diagnostics.append({"channel": channel, "direction": direction, "error": str(error)})
                continue
            evaluated.update({"channel": channel, "direction": direction, "identityEligible": False})
            diagnostics.append(evaluated)
            canvases.append((f"{channel}_{direction}_blobs.png", canvas))

    successful = [row for row in diagnostics if "selectionScore" in row]
    best = max(
        successful,
        key=lambda row: (
            bool(row["checksumValid"]), float(row["selectionScore"]),
            str(row["channel"]), str(row["direction"]),
        ),
    ) if successful else None
    base.update({
        "state": (
            "SCRIBE_BLOB_TOPOLOGY_CHECKSUM_VALID_REVIEW_HOLD"
            if best and best.get("checksumValid")
            else "SCRIBE_BLOB_TOPOLOGY_NO_VALID_DIRECT_READ_HOLD"
        ),
        "selectedLegacyRegion": selected,
        "minimumDotSize": args.minimum_dot_size,
        "maximumDotSize": args.maximum_dot_size,
        "referenceEvidence": reference_evidence,
        "sourceEvidence": {"bf": bf_evidence, "df": df_evidence},
        "bestDiagnostic": best,
        "blobTopologyDiagnostics": diagnostics,
    })
    args.output_root.mkdir(parents=True)
    for name, canvas in canvases:
        if not cv2.imwrite(str(args.output_root / name), canvas):
            raise RuntimeError(f"OpenCV could not write diagnostic raster: {name}")
    write_json_new(args.output_root / "result.json", base)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
