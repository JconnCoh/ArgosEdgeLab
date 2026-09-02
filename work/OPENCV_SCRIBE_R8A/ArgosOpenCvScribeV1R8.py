#!/usr/bin/env python3
"""Argos review-only OpenCV scribe provider, semantic revision R7.

R5 preserves the locked R3 SemiM12DotMatrixImageReader V6 mechanics without
changing their thresholds or candidate semantics.  Pose-bound standard
regions and bounded exception-search regions remain separate: an exception
search can diagnose where scribe-like texture exists, but it cannot generate
an identity until a separately qualified localization contract exists.  A
second explicit input mode accepts only hash-pinned detector inputs already
oriented by the installed review-only processor; that mode is never inferred
from a path, filename, or image dimensions.  A third explicit development-only
mode may evaluate a bounded subset of automatic whole-image localization
candidates. R6 deduplicates channel-local geometric detections and requires
their image-derived observed height and width to support the configured OCR
envelope before expansion. Thin wafer-texture lines remain rejected
diagnostics instead of being enlarged into false twelve-cell proposals. All
automatic candidates remain identity-ineligible and carry a dedicated hold.

R7 replaces the single global elongated-texture winner in development mode
with a location-independent wafer-perimeter sweep.  It estimates the wafer
ellipse, samples tangent-aligned bands around the complete perimeter at
multiple inward offsets and orientation deltas, and ranks them with
multi-scale dark/bright background residuals, CLAHE, directional gradients,
stroke-component structure, and repeated projection peaks.  The bounded
shortlist is then passed to the unchanged SEMI M12 glyph reader.  No fixed
scribe rectangle, lot, slot, or wafer angle participates in detection.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import cv2
import numpy as np


cv2.setNumThreads(1)
cv2.ocl.setUseOpenCL(False)


ENGINE_REVISION = "ARGOS_OPENCV_SCRIBE_V1R8_20260902"
RESULT_SCHEMA = "argos_opencv_scribe_result_v2"
DESCRIPTOR_WIDTH = 24
DESCRIPTOR_HEIGHT = 48
BODY_MAX_DELTA = 0.18
BODY_MAX_CANDIDATES = 4
CHECK_MAX_DELTA = 0.40
CHECK_MIN_SCORE = -0.05
CHECK_MAX_CANDIDATES = 8
GRID_MEAN_WEIGHT = 0.75
GRID_LEADING_WEIGHT = 0.125
GRID_TRAILING_WEIGHT = 0.125
BOUNDARY_MINIMUM_SCORE = 0.19
BODY_LABELS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
CHECK1_LABELS = "ABCDEFGH"
CHECK2_LABELS = "01234567"


@dataclass(frozen=True)
class Region:
    region_id: str
    source: str
    center_x: float
    center_y: float
    width: float
    height: float
    angle_degrees: float
    localization_score: float


@dataclass(frozen=True)
class Prototype:
    label: str
    physical_identity: str
    descriptor: np.ndarray


@dataclass(frozen=True)
class PrototypeBank:
    matrix: np.ndarray
    label_indices: dict[str, np.ndarray]

    @staticmethod
    def from_prototypes(prototypes: list[Prototype]) -> "PrototypeBank":
        matrix = np.vstack([item.descriptor.astype(np.float64) for item in prototypes])
        labels = np.array([item.label for item in prototypes])
        indices = {
            label: np.flatnonzero(labels == label)
            for label in sorted(set(labels.tolist()))
        }
        return PrototypeBank(matrix=matrix, label_indices=indices)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while True:
            block = stream.read(4 * 1024 * 1024)
            if not block:
                break
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(value, stream, indent=2)
            stream.write("\n")
    except Exception:
        try:
            path.unlink(missing_ok=True)
        except Exception:
            pass
        raise


def m12_remainder(text: str) -> int:
    remainder = 0
    for character in text:
        value = ord(character) - 32
        if value < 0 or value > 58:
            return -1
        remainder = (8 * remainder + value) % 59
    return remainder


def m12_check_characters(body: str) -> str:
    if len(body) != 10:
        raise ValueError("SEMI M12 body must contain exactly ten characters.")
    remainder = m12_remainder(body + "A0")
    if remainder == 0:
        return "A0"
    correction = 59 - remainder
    return chr(ord("A") + ((correction >> 3) & 7)) + chr(ord("0") + (correction & 7))


def decode_gray_exact(path: Path) -> np.ndarray:
    color = cv2.imread(str(path), cv2.IMREAD_COLOR)
    if color is None:
        raise ValueError(f"OpenCV could not decode image: {path}")
    blue = color[:, :, 0].astype(np.uint16)
    green = color[:, :, 1].astype(np.uint16)
    red = color[:, :, 2].astype(np.uint16)
    return ((29 * blue + 150 * green + 77 * red + 128) >> 8).astype(np.uint8)


def dark_residual_exact(gray: np.ndarray, radius: int) -> np.ndarray:
    """Vectorized equivalent of the locked reader's clipped integral mean."""
    height, width = gray.shape[:2]
    integral = cv2.integral(gray, sdepth=cv2.CV_64F)
    x = np.arange(width)
    y = np.arange(height)
    x0 = np.maximum(0, x - radius)
    x1 = np.minimum(width - 1, x + radius) + 1
    y0 = np.maximum(0, y - radius)
    y1 = np.minimum(height - 1, y + radius) + 1
    sums = (
        integral[y1[:, None], x1[None, :]]
        - integral[y0[:, None], x1[None, :]]
        - integral[y1[:, None], x0[None, :]]
        + integral[y0[:, None], x0[None, :]]
    )
    counts = (y1 - y0)[:, None] * (x1 - x0)[None, :]
    return np.maximum(0.0, sums / counts - gray.astype(np.float64) - 2.0).astype(np.float32)


def describe_exact(
    residual: np.ndarray,
    x: int,
    y: int,
    width: int,
    height: int,
) -> np.ndarray | None:
    image_height, image_width = residual.shape[:2]
    if x < 0 or y < 0 or x + width > image_width or y + height > image_height:
        return None
    margin_x = max(3, width // 16)
    margin_y = max(5, height // 18)
    interior = residual[y + margin_y:y + height - margin_y, x + margin_x:x + width - margin_x]
    weights = interior.astype(np.float64) ** 2
    weight_sum = float(weights.sum(dtype=np.float64))
    if weight_sum > 1e-6:
        yy, xx = np.indices(interior.shape, dtype=np.float64)
        center_x = x + margin_x + float((weights * xx).sum(dtype=np.float64) / weight_sum)
        center_y = y + margin_y + float((weights * yy).sum(dtype=np.float64) / weight_sum)
    else:
        center_x = x + width / 2.0
        center_y = y + height / 2.0
    content_width = min(width - 2, 80)
    content_height = min(height - 2, 180)
    content_x = int(round(center_x - content_width / 2.0))
    content_y = int(round(center_y - content_height / 2.0))
    content_x = max(x, min(x + width - content_width, content_x))
    content_y = max(y, min(y + height - content_height, content_y))
    sample_x = np.floor(
        content_x + (np.arange(DESCRIPTOR_WIDTH, dtype=np.float64) + 0.5)
        * content_width / DESCRIPTOR_WIDTH
    ).astype(np.int64)
    sample_y = np.floor(
        content_y + (np.arange(DESCRIPTOR_HEIGHT, dtype=np.float64) + 0.5)
        * content_height / DESCRIPTOR_HEIGHT
    ).astype(np.int64)
    sample_x = np.clip(sample_x, content_x, content_x + content_width - 1)
    sample_y = np.clip(sample_y, content_y, content_y + content_height - 1)
    values = residual[np.ix_(sample_y, sample_x)].reshape(-1).astype(np.float32)
    mean = float(values.astype(np.float64).mean())
    values = (values.astype(np.float64) - mean).astype(np.float32)
    norm = math.sqrt(float(np.dot(values.astype(np.float64), values.astype(np.float64))))
    if norm < 1e-8:
        norm = 1.0
    return (values.astype(np.float64) / norm).astype(np.float32)


def resolve_reference_path(relative_path: str, roots: dict[str, Path]) -> Path:
    normalized = relative_path.replace("/", "\\")
    prefix, separator, tail = normalized.partition("\\")
    if not separator or prefix not in roots:
        raise ValueError(f"Reference prefix is not configured: {relative_path}")
    root = roots[prefix].resolve()
    path = (root / Path(tail.replace("\\", os.sep))).resolve()
    if path != root and root not in path.parents:
        raise ValueError(f"Reference escaped configured root: {relative_path}")
    return path


def load_reference_prototypes(
    manifest_path: Path,
    expected_manifest_sha256: str,
    roots: dict[str, Path],
) -> tuple[list[Prototype], dict[str, Any]]:
    actual_hash = sha256_file(manifest_path)
    if actual_hash != expected_manifest_sha256.upper():
        raise ValueError("Reference manifest SHA-256 mismatch.")
    manifest = read_json(manifest_path)
    if manifest.get("schema") != "argos_portable_scribe_glyph_references_v1":
        raise ValueError("Reference manifest schema mismatch.")
    prototypes: list[Prototype] = []
    for row in manifest.get("references", []):
        label = str(row.get("label", "")).upper()[:1]
        if not label:
            continue
        path = resolve_reference_path(str(row["relativePath"]), roots)
        if not path.is_file() or sha256_file(path) != str(row["sha256"]).upper():
            raise ValueError(f"Reference glyph is missing or changed: {path}")
        gray = decode_gray_exact(path)
        residual = dark_residual_exact(gray, max(4, min(12, gray.shape[1] // 8)))
        descriptor = describe_exact(residual, 0, 0, gray.shape[1], gray.shape[0])
        if descriptor is None:
            raise ValueError(f"Reference glyph could not be described: {path}")
        prototypes.append(Prototype(label, str(row.get("physicalIdentity", "")), descriptor))
    prototypes.sort(key=lambda item: item.label)
    if len(prototypes) < 10:
        raise ValueError("Insufficient distinct glyph prototypes.")
    labels = "".join(sorted({item.label for item in prototypes}))
    missing = "".join(label for label in BODY_LABELS if label not in labels)
    return prototypes, {
        "manifestSha256": actual_hash,
        "referenceCount": len(prototypes),
        "prototypeLabels": labels,
        "missingBodyReferenceLabels": missing,
        "referenceCoverageComplete": not missing,
    }


def filtered_prototypes(prototypes: list[Prototype], excluded_identity: str) -> list[Prototype]:
    excluded = excluded_identity.casefold()
    return [
        item for item in prototypes
        if not excluded or item.physical_identity.casefold() != excluded
    ]


def allowed_labels(position: int) -> str:
    if position == 10:
        return CHECK1_LABELS
    if position == 11:
        return CHECK2_LABELS
    return BODY_LABELS


def rank_descriptor(
    descriptor: np.ndarray,
    prototypes: PrototypeBank,
    position: int,
) -> list[dict[str, Any]]:
    allowed = allowed_labels(position)
    scores = prototypes.matrix @ descriptor.astype(np.float64)
    ranked: list[dict[str, Any]] = []
    for label in allowed:
        indices = prototypes.label_indices.get(label)
        if indices is None or indices.size == 0:
            continue
        label_scores = np.sort(scores[indices])[::-1]
        take = min(1 if position < 10 else 3, int(label_scores.size))
        ranked.append({"character": label, "score": float(label_scores[:take].mean())})
    ranked.sort(key=lambda row: (-float(row["score"]), str(row["character"])))
    return ranked


def evaluate_grid(
    residual: np.ndarray,
    prototypes: PrototypeBank,
    x: int,
    y: int,
    cell_width: int = 96,
    cell_height: int = 230,
) -> dict[str, Any] | None:
    positions: list[dict[str, Any]] = []
    top_scores: list[float] = []
    for position in range(12):
        descriptor = describe_exact(residual, x + position * cell_width, y, cell_width, cell_height)
        if descriptor is None:
            return None
        ranked = rank_descriptor(descriptor, prototypes, position)
        if not ranked:
            return None
        positions.append({
            "position": position + 1,
            "imageFirst": ranked[0]["character"],
            "candidates": ranked[:4 if position < 10 else 8],
            "allCandidates": ranked,
        })
        top_scores.append(float(ranked[0]["score"]))
    mean_score = float(sum(top_scores) / 12.0)
    leading = top_scores[0]
    trailing = top_scores[-1]
    selection = GRID_MEAN_WEIGHT * mean_score + GRID_LEADING_WEIGHT * leading + GRID_TRAILING_WEIGHT * trailing
    return {
        "x": x,
        "y": y,
        "cellWidth": cell_width,
        "cellHeight": cell_height,
        "meanTopScore": mean_score,
        "selectionScore": selection,
        "leadingBoundaryScore": leading,
        "trailingBoundaryScore": trailing,
        "positions": positions,
    }


def better_grid(current: dict[str, Any] | None, candidate: dict[str, Any] | None) -> dict[str, Any] | None:
    if candidate is None:
        return current
    if current is None:
        return candidate
    delta = float(candidate["selectionScore"]) - float(current["selectionScore"])
    if delta > 1e-12 or (abs(delta) <= 1e-12 and float(candidate["meanTopScore"]) > float(current["meanTopScore"])):
        return candidate
    return current


def find_best_grid(gray: np.ndarray, prototypes: PrototypeBank) -> dict[str, Any]:
    residual = dark_residual_exact(gray, 12)
    cell_width = 96
    cell_height = min(230, gray.shape[0])
    expected_x = 88 if gray.shape[1] <= 1500 else (gray.shape[1] - 12 * cell_width) // 2
    expected_y = (gray.shape[0] - cell_height) // 2
    x_radius = 0 if gray.shape[1] <= 1500 else 170
    y_radius = 0 if gray.shape[0] <= 300 else 130
    coarse_step = 4 if gray.shape[1] <= 1500 else 10
    min_x = max(0, expected_x - x_radius)
    max_x = min(gray.shape[1] - 12 * cell_width, expected_x + x_radius)
    min_y = max(0, expected_y - y_radius)
    max_y = min(gray.shape[0] - cell_height, expected_y + y_radius)
    best: dict[str, Any] | None = None
    for y in range(min_y, max_y + 1, coarse_step):
        for x in range(min_x, max_x + 1, coarse_step):
            best = better_grid(best, evaluate_grid(residual, prototypes, x, y, cell_width, cell_height))
    if best is None:
        raise ValueError("No valid twelve-cell scribe grid could be evaluated.")
    refined: dict[str, Any] | None = None
    for y in range(max(0, int(best["y"]) - coarse_step), min(gray.shape[0] - cell_height, int(best["y"]) + coarse_step) + 1):
        for x in range(max(0, int(best["x"]) - coarse_step), min(gray.shape[1] - 12 * cell_width, int(best["x"]) + coarse_step) + 1):
            refined = better_grid(refined, evaluate_grid(residual, prototypes, x, y, cell_width, cell_height))
    if refined is None:
        raise ValueError("No refined twelve-cell scribe grid could be evaluated.")
    return refined


def bounded_candidates(rows: list[dict[str, Any]], position: int) -> list[dict[str, Any]]:
    if not rows:
        return []
    top = float(rows[0]["score"])
    delta = BODY_MAX_DELTA if position < 10 else CHECK_MAX_DELTA
    maximum = BODY_MAX_CANDIDATES if position < 10 else CHECK_MAX_CANDIDATES
    minimum = -math.inf if position < 10 else CHECK_MIN_SCORE
    return [row for row in rows if float(row["score"]) >= top - delta and float(row["score"]) >= minimum][:maximum]


def checksum_alternatives(positions: list[dict[str, Any]], limit: int = 5) -> list[dict[str, Any]]:
    states: dict[int, list[tuple[str, float]]] = {0: [("", 0.0)]}
    for position in range(10):
        next_states: dict[int, list[tuple[str, float]]] = {}
        for remainder, bucket in states.items():
            for text, score in bucket:
                for candidate in bounded_candidates(positions[position]["allCandidates"], position):
                    label = str(candidate["character"])
                    value = ord(label) - 32
                    if value < 0 or value > 58:
                        continue
                    next_remainder = (8 * remainder + value) % 59
                    next_states.setdefault(next_remainder, []).append((text + label, score + float(candidate["score"])))
        states = {
            remainder: sorted(bucket, key=lambda item: -item[1])[:max(5, limit)]
            for remainder, bucket in next_states.items()
        }
    first = {str(row["character"]): float(row["score"]) for row in bounded_candidates(positions[10]["allCandidates"], 10)}
    second = {str(row["character"]): float(row["score"]) for row in bounded_candidates(positions[11]["allCandidates"], 11)}
    found: dict[str, float] = {}
    for body, score in (item for bucket in states.values() for item in bucket):
        if len(body) != 10:
            continue
        check = m12_check_characters(body)
        if check[0] in first and check[1] in second:
            text = body + check
            found[text] = max(found.get(text, -math.inf), score + first[check[0]] + second[check[1]])
    return [
        {"string": text, "scoreSum": score}
        for text, score in sorted(found.items(), key=lambda item: (-item[1], item[0]))[:limit]
    ]


def finalize_grid(grid: dict[str, Any]) -> dict[str, Any]:
    image_first = "".join(str(row["imageFirst"]) for row in grid["positions"])
    expected_check = m12_check_characters(image_first[:10])
    boundary_complete = (
        float(grid["leadingBoundaryScore"]) >= BOUNDARY_MINIMUM_SCORE
        and float(grid["trailingBoundaryScore"]) >= BOUNDARY_MINIMUM_SCORE
    )
    checksum_valid = boundary_complete and m12_remainder(image_first) == 0 and image_first[10:] == expected_check
    alternatives = checksum_alternatives(grid["positions"]) if boundary_complete else []
    output = dict(grid)
    output.update({
        "imageFirstString": image_first,
        "expectedCheckCharacters": expected_check,
        "observedCheckCharacters": image_first[10:],
        "boundaryComplete": boundary_complete,
        "checksumValid": checksum_valid,
        "checksumAlternatives": alternatives,
        "proposedString": alternatives[0]["string"] if alternatives else image_first,
    })
    for row in output["positions"]:
        row.pop("allCandidates", None)
    return output


def evaluate_detector_input(
    gray: np.ndarray,
    prototypes: list[Prototype],
    excluded_identity: str,
    frozen_grid: tuple[int, int, int, int] | None = None,
) -> dict[str, Any]:
    active = filtered_prototypes(prototypes, excluded_identity)
    bank = PrototypeBank.from_prototypes(active)
    if frozen_grid is None:
        grid = find_best_grid(gray, bank)
    else:
        x, y, cell_width, cell_height = frozen_grid
        grid = evaluate_grid(dark_residual_exact(gray, 12), bank, x, y, cell_width, cell_height)
        if grid is None:
            raise ValueError("Frozen grid could not be evaluated.")
    return finalize_grid(grid)


def expected_regions(job: dict[str, Any]) -> list[Region]:
    return [
        Region(
            region_id=str(row["regionId"]),
            source=str(row["source"]),
            center_x=float(row["x"]) + float(row["width"]) / 2.0,
            center_y=float(row["y"]) + float(row["height"]) / 2.0,
            width=float(row["width"]),
            height=float(row["height"]),
            angle_degrees=float(row["angleDegrees"]),
            localization_score=1.0,
        )
        for row in job["search"].get("expectedRegions", [])
    ]


def exception_regions(
    bf: np.ndarray,
    df: np.ndarray,
    maximum_dimension: int,
    maximum_candidates: int,
    orientation_step: int,
) -> list[Region]:
    """Return diagnostic scribe-like regions; never feed them to OCR."""
    height, width = bf.shape[:2]
    scale = min(1.0, maximum_dimension / float(max(height, width)))
    target = (max(1, int(round(width * scale))), max(1, int(round(height * scale))))
    channels = []
    for gray in (bf, df):
        small = cv2.resize(gray, target, interpolation=cv2.INTER_AREA) if scale < 1.0 else gray
        radius = max(3, min(15, min(small.shape[:2]) // 100))
        dark = dark_residual_exact(small, radius)
        bright = dark_residual_exact(255 - small, radius)
        response = np.maximum(dark, bright)
        if float(response.max()) > 0:
            response = response / float(response.max())
        channels.append(response)
    combined = np.maximum(channels[0], channels[1])
    minimum_dimension = min(combined.shape[:2])
    line_length = max(31, int(round(minimum_dimension * 0.10)))
    thickness = max(1, line_length // 16)
    threshold = max(0.08, float(np.percentile(combined, 98.8)))
    binary = (combined >= threshold).astype(np.uint8) * 255
    candidates: list[Region] = []
    for angle in range(0, 180, orientation_step):
        size = max(9, int(line_length * 1.5) | 1)
        kernel = np.zeros((size, size), dtype=np.uint8)
        center = (size // 2, size // 2)
        radians = math.radians(float(angle))
        dx = int(round(math.cos(radians) * line_length / 2.0))
        dy = int(round(math.sin(radians) * line_length / 2.0))
        cv2.line(kernel, (center[0] - dx, center[1] - dy), (center[0] + dx, center[1] + dy), 1, thickness)
        joined = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)
        contours, _ = cv2.findContours(joined, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for contour in contours:
            (cx, cy), (rw, rh), rect_angle = cv2.minAreaRect(contour)
            major = max(rw, rh)
            minor = min(rw, rh)
            if minor < 3 or major / max(1.0, minor) < 3.0:
                continue
            if major < minimum_dimension * 0.04 or major > max(combined.shape[:2]) * 0.8 or minor > minimum_dimension * 0.22:
                continue
            box = cv2.boxPoints(((cx, cy), (rw, rh), rect_angle)).astype(np.int32)
            mask = np.zeros(combined.shape, dtype=np.uint8)
            cv2.fillConvexPoly(mask, box, 1)
            values = combined[mask > 0]
            score = float(values.mean()) if values.size else 0.0
            if rw < rh:
                rect_angle += 90.0
                rw, rh = rh, rw
            candidates.append(Region(
                region_id=f"EXCEPTION_DIAGNOSTIC_{angle:03d}_{len(candidates):04d}",
                source="BOUNDED_WHOLE_IMAGE_EXCEPTION_SEARCH_DIAGNOSTIC_ONLY",
                center_x=float(cx / scale),
                center_y=float(cy / scale),
                width=float(rw / scale),
                height=float(rh / scale),
                angle_degrees=float(rect_angle),
                localization_score=score,
            ))
    candidates.sort(key=lambda item: -item.localization_score)
    return candidates[:maximum_candidates]


def _ordered_rectangle(points: np.ndarray) -> np.ndarray:
    ordered = np.zeros((4, 2), dtype=np.float32)
    sums = points.sum(axis=1)
    differences = np.diff(points, axis=1).reshape(-1)
    ordered[0] = points[np.argmin(sums)]
    ordered[2] = points[np.argmax(sums)]
    ordered[1] = points[np.argmin(differences)]
    ordered[3] = points[np.argmax(differences)]
    return ordered


def _rectified_preview(
    image: np.ndarray,
    center: tuple[float, float],
    angle_degrees: float,
    width: int,
    height: int,
    interpolation: int = cv2.INTER_LINEAR,
) -> np.ndarray:
    rectangle = (
        (float(center[0]), float(center[1])),
        (float(width), float(height)),
        float(angle_degrees),
    )
    source = _ordered_rectangle(cv2.boxPoints(rectangle).astype(np.float32))
    target = np.array(
        [[0, 0], [width - 1, 0], [width - 1, height - 1], [0, height - 1]],
        dtype=np.float32,
    )
    matrix = cv2.getPerspectiveTransform(source, target)
    return cv2.warpPerspective(
        image,
        matrix,
        (width, height),
        flags=interpolation,
        borderMode=cv2.BORDER_REPLICATE,
    )


def _wafer_ellipse(gray: np.ndarray) -> tuple[float, float, float]:
    normalized = cv2.normalize(gray, None, 0, 255, cv2.NORM_MINMAX)
    threshold = max(20, int(np.percentile(normalized, 28.0)))
    mask = (normalized >= threshold).astype(np.uint8) * 255
    size = max(9, int(round(min(gray.shape[:2]) * 0.025)) | 1)
    mask = cv2.morphologyEx(
        mask,
        cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (size, size)),
    )
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    eligible = [item for item in contours if len(item) >= 5]
    if not eligible:
        raise ValueError("No wafer-sized contour supported a perimeter sweep.")
    contour = max(eligible, key=cv2.contourArea)
    image_area = float(gray.shape[0] * gray.shape[1])
    if cv2.contourArea(contour) < image_area * 0.20:
        raise ValueError("Largest contour is too small to be the wafer.")
    (center_x, center_y), (diameter_a, diameter_b), _ = cv2.fitEllipse(contour)
    radius = (float(diameter_a) + float(diameter_b)) / 4.0
    if radius < min(gray.shape[:2]) * 0.25:
        raise ValueError("Estimated wafer radius is implausibly small.")
    return float(center_x), float(center_y), radius


def _perimeter_patch_score(patch: np.ndarray) -> float:
    clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(6, 4)).apply(patch)
    responses: list[np.ndarray] = []
    for sigma in (1.2, 2.5, 5.0, 9.0):
        background = cv2.GaussianBlur(clahe, (0, 0), sigma)
        responses.append(cv2.subtract(background, clahe))
        responses.append(cv2.subtract(clahe, background))
    residual = np.maximum.reduce(responses).astype(np.float32)
    residual_scale = max(1.0, float(np.percentile(residual, 99.5)))
    residual = np.clip(residual / residual_scale, 0.0, 1.0)
    gradient = np.abs(cv2.Sobel(clahe, cv2.CV_32F, 1, 0, ksize=3))
    gradient_scale = max(1.0, float(np.percentile(gradient, 99.5)))
    gradient = np.clip(gradient / gradient_scale, 0.0, 1.0)

    projection = np.mean(np.maximum(residual, gradient), axis=0)
    projection = cv2.GaussianBlur(projection.reshape(1, -1), (0, 0), 1.2).reshape(-1)
    dilated = cv2.dilate(projection.reshape(1, -1), np.ones((1, 5), np.uint8)).reshape(-1)
    peak_indices = np.flatnonzero(
        (projection >= dilated - 1e-8)
        & (projection > float(np.percentile(projection, 72.0)))
    )
    separated_peaks: list[int] = []
    for value in peak_indices.tolist():
        if not separated_peaks or value - separated_peaks[-1] >= 3:
            separated_peaks.append(value)
        elif projection[value] > projection[separated_peaks[-1]]:
            separated_peaks[-1] = value

    binary = (residual > 0.45).astype(np.uint8)
    binary = cv2.morphologyEx(binary, cv2.MORPH_OPEN, np.ones((2, 1), np.uint8))
    count, _, stats, centroids = cv2.connectedComponentsWithStats(binary, 8)
    components: list[int] = []
    for index in range(1, count):
        width = int(stats[index, cv2.CC_STAT_WIDTH])
        height = int(stats[index, cv2.CC_STAT_HEIGHT])
        area = int(stats[index, cv2.CC_STAT_AREA])
        if 2 <= width <= 20 and 3 <= height <= 30 and 4 <= area <= 180:
            components.append(index)
    if components:
        xs = np.array([centroids[index, 0] for index in components])
        ys = np.array([centroids[index, 1] for index in components])
        span = float(xs.max() - xs.min())
        alignment = float(np.std(ys) / patch.shape[0])
    else:
        span = 0.0
        alignment = 1.0

    periodicity = max(0.0, 1.0 - abs(len(separated_peaks) - 20) / 20.0)
    component_term = min(len(components), 30) / 30.0
    span_term = min(span / (patch.shape[1] * 0.55), 1.0)
    alignment_term = max(0.0, 1.0 - alignment / 0.30)
    raw = (
        2.0 * periodicity
        + 1.5 * component_term
        + 1.2 * span_term
        + 0.8 * alignment_term
    )
    return float(np.clip(raw / 5.5, 0.0, 1.0))


def _perimeter_along_track_shift(patch: np.ndarray, target_width: int) -> float:
    """Return signed preview-pixel shift needed to center the glyph-width window."""
    clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(6, 4)).apply(patch)
    responses: list[np.ndarray] = []
    for sigma in (1.2, 2.5, 5.0, 9.0):
        background = cv2.GaussianBlur(clahe, (0, 0), sigma)
        responses.append(cv2.subtract(background, clahe))
        responses.append(cv2.subtract(clahe, background))
    residual = np.maximum.reduce(responses).astype(np.float32)
    upper = max(0, int(round(patch.shape[0] * 0.16)))
    lower = min(patch.shape[0], int(round(patch.shape[0] * 0.84)))
    projection = np.mean(residual[upper:lower], axis=0)
    window = max(24, min(int(target_width), patch.shape[1]))
    sums = np.convolve(projection, np.ones(window, dtype=np.float32), mode="valid")
    start = int(np.argmax(sums))
    return float(start + window / 2.0 - patch.shape[1] / 2.0)


def _dot_matrix_structure_score(patch: np.ndarray) -> float:
    """Score a full-resolution crop for a bounded twelve-cell dot-matrix band."""
    clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(12, 6)).apply(patch)
    residual = cv2.subtract(cv2.GaussianBlur(clahe, (0, 0), 5.0), clahe)
    binary = (residual >= 18).astype(np.uint8)
    count, _, stats, centroids = cv2.connectedComponentsWithStats(binary, 8)
    points: list[np.ndarray] = []
    for index in range(1, count):
        width = int(stats[index, cv2.CC_STAT_WIDTH])
        height = int(stats[index, cv2.CC_STAT_HEIGHT])
        area = int(stats[index, cv2.CC_STAT_AREA])
        fill = area / float(max(1, width * height))
        if (
            3 <= width <= 11
            and 3 <= height <= 11
            and 7 <= area <= 90
            and 0.55 <= width / float(height) <= 1.8
            and fill >= 0.25
        ):
            points.append(centroids[index])
    if not points:
        return 0.0
    point_array = np.asarray(points, dtype=np.float32)
    target_width = min(1152, patch.shape[1])
    target_height = min(230, patch.shape[0])
    best_count = 0
    best_span = 0.0
    y_limit = max(0, patch.shape[0] - target_height)
    x_limit = max(0, patch.shape[1] - target_width)
    for y in range(0, y_limit + 1, 10):
        y_points = point_array[
            (point_array[:, 1] >= y) & (point_array[:, 1] < y + target_height)
        ]
        for x in range(0, x_limit + 1, 24):
            window = y_points[
                (y_points[:, 0] >= x) & (y_points[:, 0] < x + target_width)
            ]
            if len(window) > best_count:
                best_count = len(window)
                best_span = float(window[:, 0].max() - window[:, 0].min())
    total = len(point_array)
    count_term = math.exp(-abs(best_count - 145) / 130.0)
    total_term = math.exp(-abs(total - 220) / 220.0)
    span_term = min(1.0, best_span / max(1.0, target_width * 0.78))
    return float(np.clip(count_term * total_term * span_term, 0.0, 1.0))


def perimeter_scribe_regions(
    bf: np.ndarray,
    df: np.ndarray,
    maximum_dimension: int,
    maximum_candidates: int,
    ocr_width: float,
    ocr_height: float,
) -> list[Region]:
    """Return a bounded, location-independent shortlist around the wafer rim."""
    height, width = bf.shape[:2]
    scale = min(1.0, maximum_dimension / float(max(height, width)))
    target = (max(1, int(round(width * scale))), max(1, int(round(height * scale))))
    channels = [
        cv2.resize(gray, target, interpolation=cv2.INTER_AREA) if scale < 1.0 else gray
        for gray in (bf, df)
    ]
    center_x, center_y, radius = _wafer_ellipse(channels[0])
    preview_width = max(180, int(round(ocr_width * scale * 1.4)))
    preview_height = max(64, int(round(ocr_height * scale * 2.0)))
    preview_width = min(preview_width, max(180, int(round(radius * 0.50))))
    preview_height = min(preview_height, max(64, int(round(radius * 0.18))))
    offsets = [radius * fraction for fraction in (0.05, 0.09, 0.13, 0.17, 0.21)]
    orientation_deltas = (-25.0, -15.0, -8.0, 0.0, 8.0, 15.0, 25.0)
    rows: list[tuple[float, float, float, float, float]] = []
    for perimeter_angle in np.arange(0.0, 360.0, 5.0):
        radians = math.radians(float(perimeter_angle))
        unit_x, unit_y = math.cos(radians), math.sin(radians)
        for offset in offsets:
            center = (
                center_x + (radius - offset) * unit_x,
                center_y + (radius - offset) * unit_y,
            )
            for delta in orientation_deltas:
                angle = float(perimeter_angle + 90.0 + delta)
                score = max(
                    _perimeter_patch_score(
                        _rectified_preview(
                            channel,
                            center,
                            angle,
                            preview_width,
                            preview_height,
                        )
                    )
                    for channel in channels
                )
                rows.append((score, center[0], center[1], angle, float(perimeter_angle)))
    rows.sort(key=lambda item: (-item[0], item[4], item[3]))

    accepted: list[tuple[float, float, float, float, float]] = []
    pool_size = max(96, maximum_candidates * 4)
    minimum_separation = preview_width * 0.20
    for row in rows:
        if any(
            math.hypot(row[1] - other[1], row[2] - other[2]) < minimum_separation
            and angle_distance_degrees(row[3], other[3]) < 12.0
            for other in accepted
        ):
            continue
        accepted.append(row)
        if len(accepted) >= pool_size:
            break
    regions: list[Region] = []
    target_grid_width = max(24, int(round(12 * 96 * scale)))
    for index, row in enumerate(accepted):
        center = (row[1], row[2])
        shifts = [
            _perimeter_along_track_shift(
                _rectified_preview(
                    channel,
                    center,
                    row[3],
                    preview_width,
                    preview_height,
                ),
                target_grid_width,
            )
            for channel in channels
        ]
        shift = shifts[int(np.argmax([abs(value) for value in shifts]))]
        radians = math.radians(row[3])
        refined_center = (
            center[0] - shift * math.cos(radians),
            center[1] - shift * math.sin(radians),
        )
        full_center = (float(refined_center[0] / scale), float(refined_center[1] / scale))
        structure_score = max(
            _dot_matrix_structure_score(
                _rectified_preview(
                    channel,
                    full_center,
                    row[3],
                    int(round(ocr_width)),
                    int(round(ocr_height)),
                )
            )
            for channel in (bf, df)
        )
        combined_score = 0.92 * structure_score + 0.08 * float(row[0])
        regions.append(Region(
            region_id=f"PERIMETER_SWEEP_{index:03d}",
            source="MULTISCALE_WAFER_PERIMETER_SWEEP_REVIEW_ONLY_DEVELOPMENT",
            center_x=float(refined_center[0] / scale),
            center_y=float(refined_center[1] / scale),
            width=float(ocr_width),
            height=float(ocr_height),
            angle_degrees=float(row[3]),
            localization_score=float(combined_score),
        ))
    regions.sort(key=lambda item: (-item.localization_score, item.region_id))
    return regions[:maximum_candidates]


def angle_distance_degrees(left: float, right: float) -> float:
    delta = abs((left - right) % 180.0)
    return min(delta, 180.0 - delta)


def deduplicate_auto_regions(regions: list[Region]) -> list[Region]:
    """Collapse the same min-area rectangle emitted by multiple line kernels."""
    unique: list[Region] = []
    for region in sorted(regions, key=lambda item: (-item.localization_score, item.region_id)):
        duplicate = False
        for accepted in unique:
            scale = max(1.0, region.width, accepted.width)
            center_distance = math.hypot(
                region.center_x - accepted.center_x,
                region.center_y - accepted.center_y,
            )
            width_delta = abs(region.width - accepted.width) / scale
            height_delta = abs(region.height - accepted.height) / max(
                1.0, region.height, accepted.height
            )
            if (
                center_distance <= 0.01 * scale
                and width_delta <= 0.05
                and height_delta <= 0.05
                and angle_distance_degrees(
                    region.angle_degrees, accepted.angle_degrees
                ) <= 2.0
            ):
                duplicate = True
                break
        if not duplicate:
            unique.append(region)
    return unique


def automatic_region_geometry(
    region: Region,
    ocr_width: float,
    ocr_height: float,
    minimum_height_ratio: float,
    minimum_width_ratio: float,
    maximum_width_ratio: float,
) -> dict[str, Any]:
    observed_width = max(region.width, region.height)
    observed_height = min(region.width, region.height)
    height_ratio = observed_height / ocr_height
    width_ratio = observed_width / ocr_width
    qualified = (
        height_ratio >= minimum_height_ratio
        and minimum_width_ratio <= width_ratio <= maximum_width_ratio
    )
    return {
        "regionId": region.region_id,
        "observedWidthPixels": observed_width,
        "observedHeightPixels": observed_height,
        "observedToOcrWidthRatio": width_ratio,
        "observedToOcrHeightRatio": height_ratio,
        "qualified": qualified,
        "rejection": "" if qualified else "OBSERVED_GEOMETRY_DOES_NOT_SUPPORT_OCR_ENVELOPE",
    }


def ordered_box_points(points: np.ndarray) -> np.ndarray:
    result = np.zeros((4, 2), dtype=np.float32)
    sums = points.sum(axis=1)
    differences = np.diff(points, axis=1).reshape(-1)
    result[0] = points[np.argmin(sums)]
    result[2] = points[np.argmax(sums)]
    result[1] = points[np.argmin(differences)]
    result[3] = points[np.argmax(differences)]
    return result


def rectify(gray: np.ndarray, region: Region) -> np.ndarray | None:
    if region.width < 2 or region.height < 2:
        return None
    rect = ((region.center_x, region.center_y), (region.width, region.height), region.angle_degrees)
    source = ordered_box_points(cv2.boxPoints(rect).astype(np.float32))
    output_width = max(2, int(round(region.width)))
    output_height = max(2, int(round(region.height)))
    target = np.array([[0, 0], [output_width - 1, 0], [output_width - 1, output_height - 1], [0, output_height - 1]], dtype=np.float32)
    matrix = cv2.getPerspectiveTransform(source, target)
    patch = cv2.warpPerspective(gray, matrix, (output_width, output_height), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    if patch.shape[0] > patch.shape[1]:
        patch = cv2.rotate(patch, cv2.ROTATE_90_CLOCKWISE)
    return patch


def decode_source(source: dict[str, Any]) -> tuple[np.ndarray, dict[str, Any]]:
    path = Path(str(source["path"]))
    if not path.is_file() or path.stat().st_size != int(source["bytes"]):
        raise ValueError(f"Source image is absent or its byte length changed: {path}")
    digest = sha256_file(path)
    if digest != str(source["sha256"]).upper():
        raise ValueError(f"Source SHA-256 mismatch: {path}")
    gray = decode_gray_exact(path)
    return gray, {
        "path": str(path),
        "canonicalProvenancePath": str(source.get("canonicalProvenancePath", "")),
        "ioPathClass": str(source.get("ioPathClass", "")),
        "aliasName": str(source.get("aliasName", "")),
        "bytes": path.stat().st_size,
        "sha256": digest,
        "width": int(gray.shape[1]),
        "height": int(gray.shape[0]),
    }


def analyze_images(
    job: dict[str, Any],
    bf: np.ndarray,
    df: np.ndarray,
    prototypes: list[Prototype],
    reference_evidence: dict[str, Any],
    source_evidence: dict[str, Any],
) -> dict[str, Any]:
    input_mode = str(job.get("inputMode", "POSE_BOUND_WHOLE_IMAGE"))
    direct_detector_input = input_mode == "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT"
    auto_localized_development = input_mode == "DEVELOPMENT_AUTO_LOCALIZED_WHOLE_IMAGE"
    standard_regions = expected_regions(job)
    if auto_localized_development:
        diagnostic_regions = perimeter_scribe_regions(
            bf,
            df,
            int(job["search"]["maximumWorkingDimension"]),
            int(job["search"]["maximumCandidates"]),
            float(job["search"]["developmentOcrRegionWidthPixels"]),
            float(job["search"]["developmentOcrRegionHeightPixels"]),
        )
    elif bool(job["search"].get("boundedExceptionSearch")) and not direct_detector_input:
        diagnostic_regions = exception_regions(
            bf,
            df,
            int(job["search"]["maximumWorkingDimension"]),
            int(job["search"]["maximumCandidates"]),
            int(job["search"]["orientationStepDegrees"]),
        )
    else:
        diagnostic_regions = []
    auto_unique_regions: list[Region] = []
    auto_geometry_evidence: list[dict[str, Any]] = []
    if auto_localized_development:
        maximum_regions = int(job["search"]["developmentMaximumRegions"])
        minimum_score = float(job["search"]["developmentMinimumLocalizationScore"])
        minimum_band_width = float(job["search"]["developmentMinimumBandWidthPixels"])
        ocr_region_width = float(job["search"]["developmentOcrRegionWidthPixels"])
        ocr_region_height = float(job["search"]["developmentOcrRegionHeightPixels"])
        minimum_height_ratio = float(job["search"]["developmentMinimumObservedHeightRatio"])
        minimum_width_ratio = float(job["search"]["developmentMinimumObservedWidthRatio"])
        maximum_width_ratio = float(job["search"]["developmentMaximumObservedWidthRatio"])
        auto_unique_regions = deduplicate_auto_regions(diagnostic_regions)
        auto_geometry_evidence = [
            automatic_region_geometry(
                region,
                ocr_region_width,
                ocr_region_height,
                minimum_height_ratio,
                minimum_width_ratio,
                maximum_width_ratio,
            )
            for region in auto_unique_regions
        ]
        qualified_region_ids = {
            str(row["regionId"])
            for row in auto_geometry_evidence
            if bool(row["qualified"])
        }
        eligible_regions = [
            region for region in auto_unique_regions
            if region.localization_score >= minimum_score and region.width >= minimum_band_width
            and region.region_id in qualified_region_ids
        ]
        eligible_regions.sort(key=lambda region: (-region.width, -region.localization_score, region.region_id))
        standard_regions = [
            Region(
                region_id=f"AUTO_LOCALIZED_{region.region_id}",
                source="AUTO_LOCALIZED_WHOLE_IMAGE_REVIEW_ONLY_DEVELOPMENT",
                center_x=region.center_x,
                center_y=region.center_y,
                width=max(region.width, ocr_region_width),
                height=max(region.height, ocr_region_height),
                angle_degrees=region.angle_degrees,
                localization_score=region.localization_score,
            )
            for region in eligible_regions
        ][:maximum_regions]
    hypotheses: list[dict[str, Any]] = []
    if direct_detector_input:
        for channel, patch in (("BF", bf), ("DF", df)):
            for polarity, view in (("DARK", patch), ("BRIGHT", 255 - patch)):
                for direction, oriented in (("FORWARD", view), ("REVERSE_180", cv2.rotate(view, cv2.ROTATE_180))):
                    try:
                        evaluated = evaluate_detector_input(oriented, prototypes, str(job.get("references", {}).get("excludedPhysicalIdentity", "")))
                    except ValueError:
                        continue
                    hypotheses.append({
                        "regionId": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
                        "regionSource": "HASH_PINNED_INSTALLED_REVIEW_ONLY_PROCESSOR_OUTPUT",
                        "channel": channel,
                        "polarity": polarity,
                        "direction": direction,
                        "localizationScore": 1.0,
                        **evaluated,
                    })
    for region in standard_regions:
        bf_patch = rectify(bf, region)
        df_patch = rectify(df, region)
        if bf_patch is None or df_patch is None:
            continue
        for channel, patch in (("BF", bf_patch), ("DF", df_patch)):
            for polarity, view in (("DARK", patch), ("BRIGHT", 255 - patch)):
                for direction, oriented in (("FORWARD", view), ("REVERSE_180", cv2.rotate(view, cv2.ROTATE_180))):
                    try:
                        evaluated = evaluate_detector_input(oriented, prototypes, str(job.get("references", {}).get("excludedPhysicalIdentity", "")))
                    except ValueError:
                        continue
                    hypotheses.append({
                        "regionId": region.region_id,
                        "regionSource": region.source,
                        "channel": channel,
                        "polarity": polarity,
                        "direction": direction,
                        "localizationScore": region.localization_score,
                        **evaluated,
                    })
    hypotheses.sort(key=lambda row: (-float(row["localizationScore"]), -float(row["selectionScore"]), str(row["regionId"]), str(row["channel"]), str(row["polarity"]), str(row["direction"])))
    best = hypotheses[0] if hypotheses else None
    proposed: dict[str, list[dict[str, Any]]] = {}
    for row in hypotheses:
        if bool(row["boundaryComplete"]):
            proposed.setdefault(str(row["proposedString"]), []).append(row)
    candidates = [
        {
            "string": text,
            "channels": sorted({str(item["channel"]) for item in rows}),
            "polarities": sorted({str(item["polarity"]) for item in rows}),
            "directions": sorted({str(item["direction"]) for item in rows}),
            "regions": sorted({str(item["regionId"]) for item in rows}),
            "maximumSelectionScore": max(float(item["selectionScore"]) for item in rows),
        }
        for text, rows in proposed.items()
    ]
    candidates.sort(key=lambda row: (-float(row["maximumSelectionScore"]), str(row["string"])))

    holds: list[dict[str, str]] = []
    if not standard_regions and not direct_detector_input:
        state = "SCRIBE_AUTO_LOCALIZATION_GEOMETRY_HOLD" if auto_localized_development else "SCRIBE_LOCALIZATION_HOLD"
        detail = (
            "No deduplicated image-derived region had observed geometry that supported the configured OCR envelope."
            if auto_localized_development else
            "No qualified pose-bound standard region was supplied; exception-search texture is diagnostic only."
        )
        holds.append({"code": state, "detail": detail})
    elif best is None:
        state = "SCRIBE_SEGMENTATION_HOLD"
        holds.append({"code": state, "detail": "No qualified standard-region twelve-cell hypothesis was evaluated."})
    elif not bool(best["boundaryComplete"]):
        state = "SCRIBE_SEGMENTATION_HOLD"
        holds.append({"code": state, "detail": "The leading or trailing boundary-cell score did not meet the frozen 0.19 gate."})
    elif len(candidates) > 1:
        state = "SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID"
        holds.append({"code": state, "detail": "Independent channel/polarity/direction views produced more than one bounded image-supported proposal."})
    elif not bool(reference_evidence["referenceCoverageComplete"]):
        state = "SCRIBE_REFERENCE_COVERAGE_HOLD"
    elif best["checksumValid"]:
        state = "SCRIBE_UNCALIBRATED_CONFIDENCE_HOLD"
        holds.append({"code": state, "detail": "Development localization/OCR confidence is not independently calibrated."})
    elif len(candidates) == 1:
        state = "SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED"
        holds.append({"code": state, "detail": "One bounded checksum-supported proposal differs from the image-first string."})
    else:
        state = "SCRIBE_M12_CHECKSUM_FAILED"
        holds.append({"code": state, "detail": "No bounded image-supported string passed canonical SEMI M12 verification."})
    if not bool(reference_evidence["referenceCoverageComplete"]):
        holds.append({"code": "SCRIBE_REFERENCE_COVERAGE_HOLD", "detail": "The frozen reference set does not cover every generic uppercase body label."})
    if auto_localized_development:
        holds.append({"code": "SCRIBE_AUTO_LOCALIZATION_DEVELOPMENT_HOLD", "detail": "Whole-image localization candidates were evaluated only for review-only development and have no automatic identity authority."})
    deduplicated_holds = []
    seen_hold_codes: set[str] = set()
    for hold in holds:
        if hold["code"] not in seen_hold_codes:
            seen_hold_codes.add(hold["code"])
            deduplicated_holds.append(hold)
    return {
        "schema": RESULT_SCHEMA,
        "revision": ENGINE_REVISION,
        "jobId": str(job["jobId"]),
        "state": state,
        "eligibleIdentity": False,
        "imageFirstString": "" if best is None else str(best["imageFirstString"]),
        "proposedString": "" if not candidates else str(candidates[0]["string"]),
        "checksumState": "NOT_EVALUATED" if best is None else (
            "SCRIBE_M12_IMAGE_FIRST_CHECKSUM_VALID_REVIEW_ONLY" if best["checksumValid"]
            else "SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED" if best["checksumAlternatives"]
            else "SCRIBE_M12_CHECKSUM_FAILED"
        ),
        "localization": {
            "standardCandidateCount": len(standard_regions),
            "qualifiedInstalledDetectorInputCount": 2 if direct_detector_input else 0,
            "exceptionDiagnosticCandidateCount": len(diagnostic_regions),
            "autoLocalizedDevelopmentMode": auto_localized_development,
            "autoLocalizedEligibleBandCount": len(eligible_regions) if auto_localized_development else 0,
            "autoLocalizedPromotedCandidateCount": len(standard_regions) if auto_localized_development else 0,
            "autoLocalizedUniqueGeometricCandidateCount": len(auto_unique_regions) if auto_localized_development else 0,
            "autoLocalizedGeometryQualifiedCount": sum(1 for row in auto_geometry_evidence if bool(row["qualified"])) if auto_localized_development else 0,
            "autoLocalizedGeometryRejectedCount": sum(1 for row in auto_geometry_evidence if not bool(row["qualified"])) if auto_localized_development else 0,
            "autoLocalizedOcrRegionWidthPixels": ocr_region_width if auto_localized_development else None,
            "autoLocalizedOcrRegionHeightPixels": ocr_region_height if auto_localized_development else None,
            "autoLocalizedGeometryEvidence": auto_geometry_evidence,
            "selectedRegionId": "" if best is None else str(best["regionId"]),
            "selectedRegionSource": "" if best is None else str(best["regionSource"]),
            "score": None if best is None else float(best["localizationScore"]),
            "confidenceCalibrationState": "UNQUALIFIED_DEVELOPMENT",
            "calibratedConfidence": None,
            "exceptionDiagnostics": [
                {
                    "regionId": region.region_id,
                    "source": region.source,
                    "x": region.center_x,
                    "y": region.center_y,
                    "width": region.width,
                    "height": region.height,
                    "angleDegrees": region.angle_degrees,
                    "score": region.localization_score,
                    "identityEligible": False,
                }
                for region in diagnostic_regions
            ],
        },
        "hypotheses": hypotheses[:256],
        "candidates": candidates,
        "holds": deduplicated_holds,
        "provenance": {
            "engineRevision": ENGINE_REVISION,
            "inputMode": input_mode,
            "inputQualification": job.get("inputQualification", {}),
            "acceptedReaderMechanics": "SEMI_M12_DOT_MATRIX_IMAGE_READER_V6_EXACT_PORT",
            "opencvVersion": cv2.__version__,
            "numpyVersion": np.__version__,
            "sources": source_evidence,
            "references": reference_evidence,
            "bfDfIndependent": True,
            "darkAndBrightPolarityPerChannel": True,
            "fixedImageRectangleUsed": False,
            "boundedExceptionSearchUsed": bool(job["search"].get("boundedExceptionSearch")),
            "locationIndependentPerimeterSweepUsed": auto_localized_development,
            "perimeterSweepUsesFixedImageRectangle": False,
            "standardAndExceptionResultsDistinct": not auto_localized_development,
            "exceptionRegionsIdentityEligible": False,
            "exceptionRegionsPromotedForReviewOnlyDevelopment": auto_localized_development,
            "promotedRegionCount": len(standard_regions) if auto_localized_development else 0,
        },
        "authority": {
            "reviewOnly": True,
            "automaticIdentityAuthority": False,
            "trainingEligible": False,
            "xmlEligible": False,
            "productionEligible": False,
            "mayClearHolds": False,
        },
    }


def validate_job_shape(job: dict[str, Any]) -> None:
    if job.get("schema") != "argos_opencv_scribe_job_v1":
        raise ValueError("Scribe job schema mismatch.")
    if not bool(job.get("authority", {}).get("reviewOnly")):
        raise ValueError("Review-only authority is required.")
    for forbidden in ("automaticIdentityAuthority", "trainingEligible", "xmlEligible", "productionEligible", "mayClearHolds"):
        if bool(job.get("authority", {}).get(forbidden)):
            raise ValueError(f"Authority contract refused: {forbidden}")
    input_mode = str(job.get("inputMode", "POSE_BOUND_WHOLE_IMAGE"))
    if input_mode == "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT":
        if job.get("search", {}).get("expectedRegions"):
            raise ValueError("Qualified installed detector input mode refuses expected regions.")
        if bool(job.get("search", {}).get("boundedExceptionSearch")):
            raise ValueError("Qualified installed detector input mode refuses exception search.")
        qualification = job.get("inputQualification", {})
        if qualification.get("state") != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT":
            raise ValueError("Installed detector input qualification state mismatch.")
        if not str(qualification.get("physicalIdentity", "")):
            raise ValueError("Installed detector input physical identity is absent.")
        for field in ("proposalPath", "proposalSha256", "multiChannelSummaryPath", "multiChannelSummarySha256"):
            if not str(qualification.get(field, "")):
                raise ValueError(f"Installed detector input qualification field is absent: {field}")
        for channel in ("bf", "df"):
            if str(job.get("inputs", {}).get(channel, {}).get("ioPathClass", "")) != "INSTALLED_HASH_PINNED_REVIEW_ONLY":
                raise ValueError(f"Installed detector input path class mismatch: {channel}")
    elif input_mode == "POSE_BOUND_WHOLE_IMAGE":
        if not bool(job.get("search", {}).get("boundedExceptionSearch")):
            raise ValueError("Bounded exception search is required.")
    elif input_mode == "DEVELOPMENT_AUTO_LOCALIZED_WHOLE_IMAGE":
        search = job.get("search", {})
        if not bool(search.get("boundedExceptionSearch")):
            raise ValueError("Development automatic localization requires bounded exception search.")
        if search.get("expectedRegions"):
            raise ValueError("Development automatic localization refuses preselected expected regions.")
        maximum_regions = int(search.get("developmentMaximumRegions", 0))
        minimum_score = float(search.get("developmentMinimumLocalizationScore", -1.0))
        minimum_band_width = float(search.get("developmentMinimumBandWidthPixels", 0.0))
        ocr_region_width = float(search.get("developmentOcrRegionWidthPixels", 0.0))
        ocr_region_height = float(search.get("developmentOcrRegionHeightPixels", 0.0))
        minimum_height_ratio = float(search.get("developmentMinimumObservedHeightRatio", 0.0))
        minimum_width_ratio = float(search.get("developmentMinimumObservedWidthRatio", 0.0))
        maximum_width_ratio = float(search.get("developmentMaximumObservedWidthRatio", 0.0))
        if maximum_regions < 1 or maximum_regions > 16:
            raise ValueError("Development automatic localization region bound must be between 1 and 16.")
        if minimum_score < 0.0 or minimum_score > 1.0:
            raise ValueError("Development automatic localization minimum score must be between 0 and 1.")
        if minimum_band_width < 100.0 or minimum_band_width > ocr_region_width:
            raise ValueError("Development minimum band width must be 100 pixels through the OCR region width.")
        if ocr_region_width < 12 * 96 or ocr_region_width > 4096:
            raise ValueError("Development OCR region width must contain the frozen twelve-cell grid and be at most 4096 pixels.")
        if ocr_region_height < 230 or ocr_region_height > 2048:
            raise ValueError("Development OCR region height must contain the frozen cell height and be at most 2048 pixels.")
        if not 0.0 < minimum_height_ratio <= 1.0:
            raise ValueError("Development minimum observed-height ratio must be in (0, 1].")
        if not 0.0 < minimum_width_ratio <= maximum_width_ratio <= 2.0:
            raise ValueError("Development observed-width ratios must satisfy 0 < minimum <= maximum <= 2.")
    else:
        raise ValueError(f"Unsupported input mode: {input_mode}")


def run_job(job_path: Path, result_path: Path) -> int:
    job = read_json(job_path)
    validate_job_shape(job)
    roots = {str(row["relativePrefix"]): Path(str(row["path"])) for row in job["references"]["roots"]}
    prototypes, reference_evidence = load_reference_prototypes(
        Path(str(job["references"]["manifestPath"])),
        str(job["references"]["manifestSha256"]),
        roots,
    )
    bf, bf_evidence = decode_source(job["inputs"]["bf"])
    df, df_evidence = decode_source(job["inputs"]["df"])
    if str(job.get("inputMode", "POSE_BOUND_WHOLE_IMAGE")) != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT" and bf.shape != df.shape:
        raise ValueError("BF and DF dimensions differ.")
    result = analyze_images(job, bf, df, prototypes, reference_evidence, {
        "bf": bf_evidence,
        "df": df_evidence,
        "jobSha256": sha256_file(job_path),
    })
    write_json_new(result_path, result)
    print(json.dumps({"state": result["state"], "resultPath": str(result_path), "candidateCount": len(result["candidates"])}))
    return 0


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", type=Path)
    parser.add_argument("--result", type=Path)
    arguments = parser.parse_args(list(argv))
    if arguments.job is None or arguments.result is None:
        parser.error("--job and --result are required")
    return arguments


def main(argv: Iterable[str]) -> int:
    arguments = parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as error:
        print(json.dumps({"state": "HOLD_OPENCV_SCRIBE_PROVIDER_ERROR", "errorType": type(error).__name__, "detail": str(error)}), file=sys.stderr)
        raise
