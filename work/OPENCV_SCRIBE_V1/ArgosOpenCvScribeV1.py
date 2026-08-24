#!/usr/bin/env python3
"""Argos review-only OpenCV scribe localization and SEMI M12 candidate engine.

The engine owns image decoding, localization, rectification, enhancement,
segmentation, glyph scoring, and checksum-supported candidate generation.
It never grants automatic identity, training, XML, or production authority.
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


ENGINE_REVISION = "ARGOS_OPENCV_SCRIBE_V1R2_20260824"
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
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    descriptor = os.open(path, flags)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(value, stream, indent=2, sort_keys=False)
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


def dark_residual(gray: np.ndarray, radius: int) -> np.ndarray:
    diameter = max(3, 2 * int(radius) + 1)
    local_mean = cv2.boxFilter(
        gray.astype(np.float32), -1, (diameter, diameter),
        normalize=True, borderType=cv2.BORDER_REPLICATE,
    )
    return np.maximum(0.0, local_mean - gray.astype(np.float32) - 2.0)


def descriptor_from_residual(residual: np.ndarray) -> np.ndarray:
    height, width = residual.shape[:2]
    if width < 4 or height < 4:
        return np.zeros(DESCRIPTOR_WIDTH * DESCRIPTOR_HEIGHT, dtype=np.float32)
    margin_x = max(1, width // 16)
    margin_y = max(1, height // 18)
    interior = residual[margin_y:max(margin_y + 1, height - margin_y), margin_x:max(margin_x + 1, width - margin_x)]
    weights = interior.astype(np.float64) ** 2
    weight_sum = float(weights.sum())
    if weight_sum > 1e-6:
        yy, xx = np.indices(interior.shape)
        center_x = margin_x + float((weights * xx).sum() / weight_sum)
        center_y = margin_y + float((weights * yy).sum() / weight_sum)
    else:
        center_x = width / 2.0
        center_y = height / 2.0
    content_width = max(2, min(width - 2, 80))
    content_height = max(2, min(height - 2, 180))
    x0 = int(round(center_x - content_width / 2.0))
    y0 = int(round(center_y - content_height / 2.0))
    x0 = max(0, min(width - content_width, x0))
    y0 = max(0, min(height - content_height, y0))
    crop = residual[y0:y0 + content_height, x0:x0 + content_width]
    resized = cv2.resize(crop, (DESCRIPTOR_WIDTH, DESCRIPTOR_HEIGHT), interpolation=cv2.INTER_AREA)
    vector = resized.astype(np.float32).reshape(-1)
    vector -= float(vector.mean())
    norm = float(np.linalg.norm(vector))
    if norm < 1e-8:
        norm = 1.0
    return vector / norm


def glyph_descriptor(gray: np.ndarray) -> np.ndarray:
    radius = max(4, min(12, gray.shape[1] // 8))
    return descriptor_from_residual(dark_residual(gray, radius))


def allowed_labels(position: int) -> str:
    if position == 10:
        return CHECK1_LABELS
    if position == 11:
        return CHECK2_LABELS
    return BODY_LABELS


def resolve_reference_path(relative_path: str, roots: dict[str, Path]) -> Path:
    normalized = relative_path.replace("/", "\\")
    prefix, separator, tail = normalized.partition("\\")
    if not separator or prefix not in roots:
        raise ValueError(f"Reference prefix is not configured: {relative_path}")
    path = (roots[prefix] / Path(tail.replace("\\", os.sep))).resolve()
    root = roots[prefix].resolve()
    if path != root and root not in path.parents:
        raise ValueError(f"Reference escaped configured root: {relative_path}")
    return path


def load_reference_descriptors(
    manifest_path: Path,
    expected_manifest_sha256: str,
    roots: dict[str, Path],
) -> tuple[dict[str, list[np.ndarray]], dict[str, Any]]:
    actual_manifest_hash = sha256_file(manifest_path)
    if actual_manifest_hash != expected_manifest_sha256.upper():
        raise ValueError("Reference manifest SHA-256 mismatch.")
    manifest = read_json(manifest_path)
    if manifest.get("schema") != "argos_portable_scribe_glyph_references_v1":
        raise ValueError("Reference manifest schema mismatch.")
    if bool(manifest.get("trainingEligible")) or bool(manifest.get("productionEligible")):
        raise ValueError("Reference authority contract refused.")
    prototypes: dict[str, list[np.ndarray]] = {}
    for row in manifest.get("references", []):
        label = str(row.get("label", "")).upper()[:1]
        if not label:
            continue
        path = resolve_reference_path(str(row["relativePath"]), roots)
        if not path.is_file():
            raise FileNotFoundError(f"Reference glyph is missing: {path}")
        if sha256_file(path) != str(row["sha256"]).upper():
            raise ValueError(f"Reference glyph SHA-256 mismatch: {path}")
        image = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
        if image is None:
            raise ValueError(f"OpenCV could not decode reference glyph: {path}")
        prototypes.setdefault(label, []).append(glyph_descriptor(image))
    if sum(len(v) for v in prototypes.values()) < 10:
        raise ValueError("Insufficient glyph prototypes.")
    covered = "".join(sorted(prototypes))
    missing = "".join(label for label in BODY_LABELS if label not in prototypes)
    evidence = {
        "manifestSha256": actual_manifest_hash,
        "referenceCount": sum(len(v) for v in prototypes.values()),
        "prototypeLabels": covered,
        "missingBodyReferenceLabels": missing,
        "referenceCoverageComplete": not missing,
    }
    return prototypes, evidence


def rank_cell(
    residual: np.ndarray,
    prototypes: dict[str, list[np.ndarray]],
    position: int,
) -> list[dict[str, Any]]:
    vector = descriptor_from_residual(residual)
    ranked: list[dict[str, Any]] = []
    for label in allowed_labels(position):
        values = prototypes.get(label, [])
        if not values:
            continue
        scores = sorted((float(np.dot(vector, value)) for value in values), reverse=True)
        take = 1 if position < 10 else min(3, len(scores))
        ranked.append({"character": label, "score": float(sum(scores[:take]) / take)})
    ranked.sort(key=lambda row: (-float(row["score"]), str(row["character"])))
    return ranked


def evaluate_patch(
    gray: np.ndarray,
    prototypes: dict[str, list[np.ndarray]],
) -> dict[str, Any] | None:
    height, width = gray.shape[:2]
    if height < 24 or width < 12 * 8:
        return None
    residual = dark_residual(gray, max(4, min(16, height // 18)))
    best: dict[str, Any] | None = None
    for row_fraction in tuple(value / 100.0 for value in range(72, 101, 2)):
        total_width = width * row_fraction
        cell_width = total_width / 12.0
        for x_fraction in (-0.08, -0.04, 0.0, 0.04, 0.08):
            start_x = (width - total_width) / 2.0 + x_fraction * width
            if start_x < 0 or start_x + total_width > width:
                continue
            positions: list[dict[str, Any]] = []
            top_scores: list[float] = []
            valid = True
            for position in range(12):
                x0 = int(round(start_x + position * cell_width))
                x1 = int(round(start_x + (position + 1) * cell_width))
                x0 = max(0, min(width - 1, x0))
                x1 = max(x0 + 1, min(width, x1))
                ranked = rank_cell(residual[:, x0:x1], prototypes, position)
                if not ranked:
                    valid = False
                    break
                limit = BODY_MAX_CANDIDATES if position < 10 else CHECK_MAX_CANDIDATES
                positions.append({
                    "position": position + 1,
                    "imageFirst": ranked[0]["character"],
                    "candidates": ranked[:limit],
                })
                top_scores.append(float(ranked[0]["score"]))
            if not valid:
                continue
            mean_top = float(sum(top_scores) / 12.0)
            leading = top_scores[0]
            trailing = top_scores[-1]
            selection = (
                GRID_MEAN_WEIGHT * mean_top
                + GRID_LEADING_WEIGHT * leading
                + GRID_TRAILING_WEIGHT * trailing
            )
            current = {
                "startX": start_x,
                "cellWidth": cell_width,
                "meanTopScore": mean_top,
                "selectionScore": selection,
                "leadingBoundaryScore": leading,
                "trailingBoundaryScore": trailing,
                "positions": positions,
            }
            if best is None or selection > float(best["selectionScore"]):
                best = current
    if best is None:
        return None
    image_first = "".join(str(row["imageFirst"]) for row in best["positions"])
    expected_check = m12_check_characters(image_first[:10])
    boundary_complete = (
        float(best["leadingBoundaryScore"]) >= BOUNDARY_MINIMUM_SCORE
        and float(best["trailingBoundaryScore"]) >= BOUNDARY_MINIMUM_SCORE
    )
    checksum_valid = (
        boundary_complete
        and m12_remainder(image_first) == 0
        and image_first[10:] == expected_check
    )
    alternatives = checksum_alternatives(best["positions"], limit=5) if boundary_complete else []
    best.update({
        "imageFirstString": image_first,
        "expectedCheckCharacters": expected_check,
        "observedCheckCharacters": image_first[10:],
        "boundaryComplete": boundary_complete,
        "checksumValid": checksum_valid,
        "checksumAlternatives": alternatives,
    })
    return best


def bounded_candidates(rows: list[dict[str, Any]], position: int) -> list[dict[str, Any]]:
    ranked = list(rows)
    if not ranked:
        return []
    top = float(ranked[0]["score"])
    delta = BODY_MAX_DELTA if position < 10 else CHECK_MAX_DELTA
    maximum = BODY_MAX_CANDIDATES if position < 10 else CHECK_MAX_CANDIDATES
    minimum = -math.inf if position < 10 else CHECK_MIN_SCORE
    return [row for row in ranked if float(row["score"]) >= top - delta and float(row["score"]) >= minimum][:maximum]


def checksum_alternatives(positions: list[dict[str, Any]], limit: int) -> list[dict[str, Any]]:
    states: dict[int, list[tuple[str, float]]] = {0: [("", 0.0)]}
    for position in range(10):
        next_states: dict[int, list[tuple[str, float]]] = {}
        for remainder, bucket in states.items():
            for text, score in bucket:
                for candidate in bounded_candidates(positions[position]["candidates"], position):
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
    first = {str(row["character"]): float(row["score"]) for row in bounded_candidates(positions[10]["candidates"], 10)}
    second = {str(row["character"]): float(row["score"]) for row in bounded_candidates(positions[11]["candidates"], 11)}
    found: dict[str, float] = {}
    for bucket in states.values():
        for body, score in bucket:
            check = m12_check_characters(body)
            if check[0] in first and check[1] in second:
                text = body + check
                found[text] = max(found.get(text, -math.inf), score + first[check[0]] + second[check[1]])
    return [
        {"string": text, "scoreSum": score}
        for text, score in sorted(found.items(), key=lambda item: (-item[1], item[0]))[:limit]
    ]


def expected_regions(job: dict[str, Any]) -> list[Region]:
    output: list[Region] = []
    for row in job["search"].get("expectedRegions", []):
        output.append(Region(
            region_id=str(row["regionId"]),
            source=str(row["source"]),
            center_x=float(row["x"]) + float(row["width"]) / 2.0,
            center_y=float(row["y"]) + float(row["height"]) / 2.0,
            width=float(row["width"]),
            height=float(row["height"]),
            angle_degrees=float(row["angleDegrees"]),
            localization_score=1.0,
        ))
    return output


def rotated_kernel(length: int, thickness: int, angle_degrees: float) -> np.ndarray:
    size = max(9, int(length * 1.5) | 1)
    kernel = np.zeros((size, size), dtype=np.uint8)
    center = (size // 2, size // 2)
    radians = math.radians(angle_degrees)
    dx = int(round(math.cos(radians) * length / 2.0))
    dy = int(round(math.sin(radians) * length / 2.0))
    cv2.line(kernel, (center[0] - dx, center[1] - dy), (center[0] + dx, center[1] + dy), 1, thickness)
    return kernel


def exception_regions(
    bf: np.ndarray,
    df: np.ndarray,
    maximum_dimension: int,
    maximum_candidates: int,
    orientation_step: int,
) -> list[Region]:
    height, width = bf.shape[:2]
    scale = min(1.0, maximum_dimension / float(max(height, width)))
    target = (max(1, int(round(width * scale))), max(1, int(round(height * scale))))
    bf_small = cv2.resize(bf, target, interpolation=cv2.INTER_AREA) if scale < 1.0 else bf
    df_small = cv2.resize(df, target, interpolation=cv2.INTER_AREA) if scale < 1.0 else df
    responses = []
    for gray in (bf_small, df_small):
        radius = max(3, min(15, min(gray.shape[:2]) // 100))
        dark = dark_residual(gray, radius)
        bright = dark_residual(255 - gray, radius)
        response = np.maximum(dark, bright)
        if float(response.max()) > 0:
            response = response / float(response.max())
        responses.append(response)
    combined = np.maximum(responses[0], responses[1])
    candidates: list[Region] = []
    minimum_dimension = min(combined.shape[:2])
    line_length = max(31, int(round(minimum_dimension * 0.10)))
    thickness = max(1, line_length // 16)
    percentile = float(np.percentile(combined, 98.8))
    threshold = max(0.08, percentile)
    binary = (combined >= threshold).astype(np.uint8) * 255
    for angle in range(0, 180, orientation_step):
        kernel = rotated_kernel(line_length, thickness, float(angle))
        joined = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)
        contours, _ = cv2.findContours(joined, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for contour in contours:
            rect = cv2.minAreaRect(contour)
            (cx, cy), (rw, rh), rect_angle = rect
            major = max(rw, rh)
            minor = min(rw, rh)
            if minor < 3 or major / max(1.0, minor) < 3.0:
                continue
            if major < minimum_dimension * 0.04 or major > max(combined.shape[:2]) * 0.8:
                continue
            if minor > minimum_dimension * 0.22:
                continue
            box = cv2.boxPoints(rect).astype(np.int32)
            mask = np.zeros(combined.shape, dtype=np.uint8)
            cv2.fillConvexPoly(mask, box, 1)
            values = combined[mask > 0]
            score = float(values.mean()) if values.size else 0.0
            if rw < rh:
                rect_angle += 90.0
                rw, rh = rh, rw
            for expansion in (1.25, 2.0, 3.0):
                for offset_factor in (-0.33, 0.0, 0.33):
                    offset = rw / scale * offset_factor
                    radians = math.radians(rect_angle)
                    shifted_x = cx / scale + math.cos(radians) * offset
                    shifted_y = cy / scale + math.sin(radians) * offset
                    candidates.append(Region(
                        region_id=f"EXCEPTION_{angle:03d}_{len(candidates):04d}_X{expansion:0.2f}_O{offset_factor:+0.2f}",
                        source="BOUNDED_WHOLE_IMAGE_EXCEPTION_SEARCH",
                        center_x=float(shifted_x), center_y=float(shifted_y),
                        width=float(min(width, rw / scale * expansion)),
                        height=float(min(height, rh / scale * 2.4)),
                        angle_degrees=float(rect_angle),
                        localization_score=score - 0.005 * (expansion - 1.25) - 0.002 * abs(offset_factor),
                    ))
    candidates.sort(key=lambda item: -item.localization_score)
    selected: list[Region] = []
    for candidate in candidates:
        duplicate = False
        for prior in selected:
            distance = math.hypot(candidate.center_x - prior.center_x, candidate.center_y - prior.center_y)
            width_ratio = candidate.width / max(1.0, prior.width)
            same_scale = 0.72 <= width_ratio <= 1.39
            if distance < 0.07 * max(candidate.width, prior.width) and same_scale:
                duplicate = True
                break
        if not duplicate:
            selected.append(candidate)
        if len(selected) >= maximum_candidates:
            break
    return selected


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
    target = np.array([
        [0, 0], [output_width - 1, 0],
        [output_width - 1, output_height - 1], [0, output_height - 1],
    ], dtype=np.float32)
    matrix = cv2.getPerspectiveTransform(source, target)
    patch = cv2.warpPerspective(gray, matrix, (output_width, output_height), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    if patch.shape[0] > patch.shape[1]:
        patch = cv2.rotate(patch, cv2.ROTATE_90_CLOCKWISE)
    return patch


def decode_source(source: dict[str, Any]) -> tuple[np.ndarray, dict[str, Any]]:
    path = Path(str(source["path"]))
    if not path.is_file():
        raise FileNotFoundError(f"Source image is missing: {path}")
    size = path.stat().st_size
    if size != int(source["bytes"]):
        raise ValueError(f"Source byte length mismatch: {path}")
    digest = sha256_file(path)
    if digest != str(source["sha256"]).upper():
        raise ValueError(f"Source SHA-256 mismatch: {path}")
    gray = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
    if gray is None:
        raise ValueError(f"OpenCV could not decode source image: {path}")
    return gray, {
        "path": str(path),
        "canonicalProvenancePath": str(source.get("canonicalProvenancePath", "")),
        "ioPathClass": str(source.get("ioPathClass", "")),
        "aliasName": str(source.get("aliasName", "")),
        "aliasAnchorCanonicalPath": str(source.get("aliasAnchorCanonicalPath", "")),
        "bytes": size,
        "sha256": digest,
        "width": int(gray.shape[1]),
        "height": int(gray.shape[0]),
    }


def analyze_images(
    job: dict[str, Any],
    bf: np.ndarray,
    df: np.ndarray,
    prototypes: dict[str, list[np.ndarray]],
    reference_evidence: dict[str, Any],
    source_evidence: dict[str, Any],
) -> dict[str, Any]:
    regions = expected_regions(job)
    if bool(job["search"].get("boundedExceptionSearch")):
        regions.extend(exception_regions(
            bf, df,
            int(job["search"]["maximumWorkingDimension"]),
            int(job["search"]["maximumCandidates"]),
            int(job["search"]["orientationStepDegrees"]),
        ))
    hypotheses: list[dict[str, Any]] = []
    for region in regions:
        bf_patch = rectify(bf, region)
        df_patch = rectify(df, region)
        if bf_patch is None or df_patch is None:
            continue
        for direction, bf_view, df_view in (
            ("FORWARD", bf_patch, df_patch),
            ("REVERSE_180", cv2.rotate(bf_patch, cv2.ROTATE_180), cv2.rotate(df_patch, cv2.ROTATE_180)),
        ):
            for channel, patch in (("BF", bf_view), ("DF", df_view)):
                for polarity, view in (("DARK", patch), ("BRIGHT", 255 - patch)):
                    evaluated = evaluate_patch(view, prototypes)
                    if evaluated is None:
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
    hypotheses.sort(key=lambda row: (-float(row["selectionScore"]), -float(row["localizationScore"]), str(row["regionId"])))
    best = hypotheses[0] if hypotheses else None
    valid_evidence: list[dict[str, Any]] = []
    for row in hypotheses:
        if bool(row["boundaryComplete"]) and bool(row["checksumValid"]):
            valid_evidence.append({
                "string": row["imageFirstString"], "regionId": row["regionId"],
                "channel": row["channel"], "polarity": row["polarity"],
                "direction": row["direction"], "evidence": "IMAGE_FIRST",
                "score": row["selectionScore"],
            })
        if bool(row["boundaryComplete"]):
            for alternative in row["checksumAlternatives"]:
                valid_evidence.append({
                    "string": alternative["string"], "regionId": row["regionId"],
                    "channel": row["channel"], "polarity": row["polarity"],
                    "direction": row["direction"], "evidence": "BOUNDED_M12_ALTERNATIVE",
                    "score": alternative["scoreSum"],
                })
    grouped: dict[str, list[dict[str, Any]]] = {}
    for row in valid_evidence:
        grouped.setdefault(str(row["string"]), []).append(row)
    candidates = []
    for text, rows in grouped.items():
        candidates.append({
            "string": text,
            "directImageFirstSupport": any(row["evidence"] == "IMAGE_FIRST" for row in rows),
            "channels": sorted({str(row["channel"]) for row in rows}),
            "polarities": sorted({str(row["polarity"]) for row in rows}),
            "regions": sorted({str(row["regionId"]) for row in rows}),
            "maximumScore": max(float(row["score"]) for row in rows),
        })
    candidates.sort(key=lambda row: (-int(bool(row["directImageFirstSupport"])), -float(row["maximumScore"]), str(row["string"])))

    holds: list[dict[str, str]] = []
    if not regions:
        state = "SCRIBE_LOCALIZATION_HOLD"
        holds.append({"code": state, "detail": "No pose-bound or bounded exception-search region was found."})
    elif best is None:
        state = "SCRIBE_SEGMENTATION_HOLD"
        holds.append({"code": state, "detail": "No defensible twelve-cell hypothesis was evaluated."})
    elif not bool(best["boundaryComplete"]):
        state = "SCRIBE_SEGMENTATION_HOLD"
        holds.append({"code": state, "detail": "The leading or trailing boundary-cell score did not meet the frozen 0.19 gate."})
    elif not bool(reference_evidence["referenceCoverageComplete"]):
        state = "SCRIBE_REFERENCE_COVERAGE_HOLD"
        holds.append({"code": state, "detail": "The frozen reference set does not cover every generic uppercase body label."})
    elif len(candidates) > 1:
        state = "SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID"
        holds.append({"code": state, "detail": "More than one bounded image-supported checksum-valid string remains."})
    elif best["checksumValid"]:
        state = "SCRIBE_UNCALIBRATED_CONFIDENCE_HOLD"
        holds.append({"code": state, "detail": "Development localization/OCR confidence is not yet frozen or independently calibrated."})
    elif len(candidates) == 1:
        state = "SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED"
        holds.append({"code": state, "detail": "One checksum-valid near-scoring alternative exists but differs from the image-first string."})
    else:
        state = "SCRIBE_M12_CHECKSUM_FAILED"
        holds.append({"code": state, "detail": "No bounded image-supported string passed canonical SEMI M12 verification."})

    selected_region = next((region for region in regions if best and region.region_id == best["regionId"]), None)
    result = {
        "schema": "argos_opencv_scribe_result_v1",
        "revision": ENGINE_REVISION,
        "jobId": str(job["jobId"]),
        "state": state,
        "eligibleIdentity": False,
        "imageFirstString": "" if best is None else str(best["imageFirstString"]),
        "checksumState": "NOT_EVALUATED" if best is None else (
            "SCRIBE_M12_IMAGE_FIRST_CHECKSUM_VALID_REVIEW_ONLY" if best["checksumValid"]
            else "SCRIBE_M12_CHECKSUM_FAILED"
        ),
        "localization": {
            "candidateCount": len(regions),
            "selectedRegionId": "" if best is None else str(best["regionId"]),
            "selectedRegionSource": "" if best is None else str(best["regionSource"]),
            "x": None if selected_region is None else selected_region.center_x,
            "y": None if selected_region is None else selected_region.center_y,
            "width": None if selected_region is None else selected_region.width,
            "height": None if selected_region is None else selected_region.height,
            "angleDegrees": None if selected_region is None else selected_region.angle_degrees,
            "score": None if best is None else float(best["localizationScore"]),
            "confidenceCalibrationState": "UNQUALIFIED_DEVELOPMENT",
            "calibratedConfidence": None,
        },
        "hypotheses": hypotheses[:256],
        "candidates": candidates,
        "holds": holds,
        "provenance": {
            "engineRevision": ENGINE_REVISION,
            "opencvVersion": cv2.__version__,
            "numpyVersion": np.__version__,
            "sources": source_evidence,
            "references": reference_evidence,
            "bfDfIndependent": True,
            "fixedImageRectangleUsed": False,
            "boundedExceptionSearchUsed": bool(job["search"].get("boundedExceptionSearch")),
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
    return result


def validate_job_shape(job: dict[str, Any]) -> None:
    if job.get("schema") != "argos_opencv_scribe_job_v1":
        raise ValueError("Scribe job schema mismatch.")
    if not bool(job.get("authority", {}).get("reviewOnly")):
        raise ValueError("Review-only authority is required.")
    for forbidden in ("automaticIdentityAuthority", "trainingEligible", "xmlEligible", "productionEligible", "mayClearHolds"):
        if bool(job.get("authority", {}).get(forbidden)):
            raise ValueError(f"Authority contract refused: {forbidden}")
    if not bool(job.get("search", {}).get("boundedExceptionSearch")):
        raise ValueError("Bounded exception search is required.")
    for channel in ("bf", "df"):
        source = job.get("inputs", {}).get(channel, {})
        if source.get("ioPathClass") != "SHORT_DOS_DEVICE_ALIAS":
            raise ValueError(f"Short child-visible source alias is required: {channel}")
        if not str(source.get("canonicalProvenancePath", "")).upper().startswith("D:\\"):
            raise ValueError(f"Canonical JBOD provenance path is required: {channel}")
        alias = str(source.get("aliasName", ""))
        if len(alias) != 2 or alias[0] < "A" or alias[0] > "Z" or alias[1] != ":":
            raise ValueError(f"Source alias name is invalid: {channel}")
        if not str(source.get("path", "")).upper().startswith(alias + "\\"):
            raise ValueError(f"Source I/O path is not anchored at its declared alias: {channel}")


def run_job(job_path: Path, result_path: Path) -> int:
    job = read_json(job_path)
    validate_job_shape(job)
    roots = {
        str(row["relativePrefix"]): Path(str(row["path"]))
        for row in job["references"]["roots"]
    }
    prototypes, reference_evidence = load_reference_descriptors(
        Path(str(job["references"]["manifestPath"])),
        str(job["references"]["manifestSha256"]),
        roots,
    )
    bf, bf_evidence = decode_source(job["inputs"]["bf"])
    df, df_evidence = decode_source(job["inputs"]["df"])
    if bf.shape != df.shape:
        raise ValueError("BF and DF dimensions differ; channels remain independent but must share the declared native frame extent.")
    result = analyze_images(
        job, bf, df, prototypes, reference_evidence,
        {"bf": bf_evidence, "df": df_evidence, "jobSha256": sha256_file(job_path)},
    )
    write_json_new(result_path, result)
    print(json.dumps({"state": result["state"], "resultPath": str(result_path), "candidateCount": len(result["candidates"])}))
    return 0


def render_glyph(character: str, width: int = 96, height: int = 215) -> np.ndarray:
    image = np.full((height, width), 245, dtype=np.uint8)
    font = cv2.FONT_HERSHEY_SIMPLEX
    scale = 2.55
    thickness = 5
    (text_width, text_height), _ = cv2.getTextSize(character, font, scale, thickness)
    origin = ((width - text_width) // 2, (height + text_height) // 2)
    cv2.putText(image, character, origin, font, scale, 20, thickness, cv2.LINE_AA)
    return image


def synthesize_row(text: str) -> np.ndarray:
    return np.hstack([render_glyph(character) for character in text])


def place_rotated(canvas: np.ndarray, row: np.ndarray, center: tuple[int, int], angle: float, bright: bool = False) -> None:
    source = 255 - row if bright else row
    layer = np.full(canvas.shape, 245 if not bright else 15, dtype=np.uint8)
    x0 = center[0] - source.shape[1] // 2
    y0 = center[1] - source.shape[0] // 2
    if x0 < 0 or y0 < 0 or x0 + source.shape[1] > canvas.shape[1] or y0 + source.shape[0] > canvas.shape[0]:
        raise ValueError("Synthetic row is outside its canvas.")
    layer[y0:y0 + source.shape[0], x0:x0 + source.shape[1]] = source
    matrix = cv2.getRotationMatrix2D(center, angle, 1.0)
    rotated = cv2.warpAffine(layer, matrix, (canvas.shape[1], canvas.shape[0]), borderValue=int(canvas[0, 0]))
    if bright:
        np.maximum(canvas, rotated, out=canvas)
    else:
        np.minimum(canvas, rotated, out=canvas)


def synthetic_prototypes() -> dict[str, list[np.ndarray]]:
    return {label: [glyph_descriptor(render_glyph(label))] for label in BODY_LABELS}


def run_synthetic_gate(output_root: Path) -> int:
    output_root.mkdir(parents=True, exist_ok=False)
    body = "1234ABCD56"
    truth = body + m12_check_characters(body)
    prototypes = synthetic_prototypes()
    reference_evidence = {
        "manifestSha256": "0" * 64,
        "referenceCount": len(prototypes),
        "prototypeLabels": BODY_LABELS,
        "missingBodyReferenceLabels": "",
        "referenceCoverageComplete": True,
        "syntheticOnly": True,
    }
    cases = [
        {"id": "EXPECTED_STANDARD_DARK", "center": (900, 1050), "angle": 0.0, "bright": False, "expected": True},
        {"id": "EXCEPTION_UPPER_ROTATED", "center": (760, 420), "angle": 25.0, "bright": False, "expected": False},
        {"id": "EXCEPTION_BRIGHT_RANDOM_NOTCH", "center": (1050, 780), "angle": -32.0, "bright": True, "expected": False},
        {"id": "MISSING_SCRIBE_HOLD", "center": None, "angle": 0.0, "bright": False, "expected": False},
    ]
    rows = []
    for case in cases:
        base = 15 if case["bright"] else 245
        bf = np.full((1400, 1800), base, dtype=np.uint8)
        df = np.full((1400, 1800), base, dtype=np.uint8)
        rng = np.random.default_rng(abs(hash(case["id"])) % (2**32))
        noise = rng.normal(0, 2.0, bf.shape).astype(np.int16)
        bf[:] = np.clip(bf.astype(np.int16) + noise, 0, 255).astype(np.uint8)
        df[:] = np.clip(df.astype(np.int16) - noise, 0, 255).astype(np.uint8)
        if case["center"] is not None:
            row = synthesize_row(truth)
            place_rotated(bf, row, case["center"], float(case["angle"]), bool(case["bright"]))
            place_rotated(df, row, case["center"], float(case["angle"]), bool(case["bright"]))
        expected = []
        if case["expected"] and case["center"] is not None:
            expected.append({
                "regionId": "EXPECTED_SYNTHETIC",
                "source": "QUALIFIED_POSE_BOUND_PRIOR",
                "x": case["center"][0] - 650,
                "y": case["center"][1] - 150,
                "width": 1300,
                "height": 300,
                "angleDegrees": float(case["angle"]),
            })
        job = {
            "jobId": f"SYNTH_{case['id']}",
            "search": {
                "expectedRegions": expected,
                "boundedExceptionSearch": True,
                "maximumWorkingDimension": 1600,
                "maximumCandidates": 32,
                "orientationStepDegrees": 15,
            },
        }
        result = analyze_images(
            job, bf, df, prototypes, reference_evidence,
            {"synthetic": True, "truth": truth},
        )
        strings = [str(row["string"]) for row in result["candidates"]]
        if case["center"] is None:
            passed = result["state"] in {"SCRIBE_LOCALIZATION_HOLD", "SCRIBE_SEGMENTATION_HOLD", "SCRIBE_M12_CHECKSUM_FAILED"} and truth not in strings
        else:
            passed = truth in strings or result["imageFirstString"] == truth
        rows.append({
            "caseId": case["id"],
            "passed": passed,
            "truth": truth,
            "state": result["state"],
            "imageFirstString": result["imageFirstString"],
            "truthInCandidates": truth in strings,
            "localizationCandidateCount": result["localization"]["candidateCount"],
        })
    gate = {
        "schema": "argos_opencv_scribe_synthetic_gate_v1",
        "state": "PASS_OPENCV_SCRIBE_SYNTHETIC_GATE" if all(row["passed"] for row in rows) else "FAIL_OPENCV_SCRIBE_SYNTHETIC_GATE",
        "engineRevision": ENGINE_REVISION,
        "opencvVersion": cv2.__version__,
        "numpyVersion": np.__version__,
        "caseCount": len(rows),
        "passCount": sum(1 for row in rows if row["passed"]),
        "cases": rows,
        "imageBytesFromProductionRead": False,
        "syntheticOnly": True,
        "reviewOnly": True,
        "productionEligible": False,
    }
    write_json_new(output_root / "SYNTHETIC_GATE.json", gate)
    print(json.dumps(gate))
    return 0 if gate["state"].startswith("PASS_") else 2


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--job", type=Path)
    group.add_argument("--synthetic-gate", action="store_true")
    parser.add_argument("--result", type=Path)
    parser.add_argument("--output-root", type=Path)
    args = parser.parse_args(list(argv))
    if args.job is not None and args.result is None:
        parser.error("--result is required with --job")
    if args.synthetic_gate and args.output_root is None:
        parser.error("--output-root is required with --synthetic-gate")
    return args


def main(argv: Iterable[str]) -> int:
    args = parse_arguments(argv)
    if args.synthetic_gate:
        return run_synthetic_gate(args.output_root)
    return run_job(args.job, args.result)


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as error:
        print(json.dumps({"state": "HOLD_OPENCV_SCRIBE_PROVIDER_ERROR", "errorType": type(error).__name__, "detail": str(error)}), file=sys.stderr)
        raise
