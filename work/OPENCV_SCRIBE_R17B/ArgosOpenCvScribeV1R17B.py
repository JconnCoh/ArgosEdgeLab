#!/usr/bin/env python3
"""R17B review-only scribe provider with a pre-OCR dot-matrix presence gate.

The R11 OCR remains the recognition implementation.  R17B prevents it from
scoring a candidate unless the pixels first prove a spatially coherent
twelve-cell dot-matrix band.  A failed gate produces no string and cannot be
rescued by template rank or an M12 checksum.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Iterable

import cv2
import numpy as np


REVISION = "ARGOS_OPENCV_SCRIBE_V1R17B_20260903"
SCHEMA = "argos_opencv_scribe_presence_gate_v1"
CELL_HEIGHT = 230
CELL_WIDTHS = tuple(range(90, 106))
MIN_COMPONENTS = 120
MIN_COMPONENTS_PER_CELL = 8
MIN_HORIZONTAL_PAIR_RATIO = 0.26
MIN_VERTICAL_PAIR_RATIO = 0.20
MIN_CHARACTER_PAIR_RATIO = 0.33
MIN_CONCENTRATION_RATIO = 3.5


def _load_r11() -> Any:
    path = Path(__file__).resolve().parents[1] / "OPENCV_SCRIBE_R11A" / "ArgosOpenCvScribeV1R11.py"
    spec = importlib.util.spec_from_file_location("argos_scribe_r11_for_r17b", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load R11 provider: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _load_supplement_loader() -> Any:
    path = Path(__file__).resolve().parents[1] / "OPENCV_SCRIBE_R16B" / "ArgosOpenCvScribeSupplementLoaderR16B.py"
    spec = importlib.util.spec_from_file_location("argos_scribe_r16b_for_r17b", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load R16B supplement loader: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _component_centers(view: np.ndarray) -> np.ndarray:
    local_mean = cv2.boxFilter(view, cv2.CV_32F, (25, 25), normalize=True)
    residual = np.maximum(0.0, local_mean - view.astype(np.float32) - 2.0)
    count, _, stats, centroids = cv2.connectedComponentsWithStats(
        (residual >= 40.0).astype(np.uint8), 8
    )
    points: list[np.ndarray] = []
    for index in range(1, count):
        width = int(stats[index, cv2.CC_STAT_WIDTH])
        height = int(stats[index, cv2.CC_STAT_HEIGHT])
        area = int(stats[index, cv2.CC_STAT_AREA])
        aspect = width / float(max(1, height))
        if (
            3 <= width <= 20
            and 3 <= height <= 20
            and 7 <= area <= 220
            and 0.4 <= aspect <= 2.5
        ):
            points.append(centroids[index])
    return np.asarray(points, dtype=np.float32).reshape(-1, 2)


def _small_blob_centers(view: np.ndarray) -> np.ndarray:
    parameters = cv2.SimpleBlobDetector_Params()
    parameters.minThreshold = 0
    parameters.maxThreshold = 250
    parameters.thresholdStep = 4
    parameters.filterByColor = True
    parameters.blobColor = 0
    parameters.filterByArea = True
    parameters.minArea = 5
    parameters.maxArea = 180
    parameters.filterByCircularity = True
    parameters.minCircularity = 0.45
    parameters.filterByInertia = True
    parameters.minInertiaRatio = 0.15
    parameters.filterByConvexity = True
    parameters.minConvexity = 0.45
    parameters.minDistBetweenBlobs = 3
    keypoints = cv2.SimpleBlobDetector_create(parameters).detect(view)
    return np.asarray(
        [(row.pt[0], row.pt[1]) for row in keypoints if 2.0 <= row.size <= 4.5],
        dtype=np.float32,
    ).reshape(-1, 2)


def _cell_counts(
    points: np.ndarray, x: int, y: int, cell_width: int, cell_height: int
) -> tuple[np.ndarray, np.ndarray]:
    inside = points[
        (points[:, 0] >= x)
        & (points[:, 0] < x + 12 * cell_width)
        & (points[:, 1] >= y)
        & (points[:, 1] < y + cell_height)
    ]
    counts = np.zeros(12, dtype=np.int32)
    if inside.size:
        cell = ((inside[:, 0] - x) // cell_width).astype(np.int32)
        counts = np.bincount(np.clip(cell, 0, 11), minlength=12)[:12]
    return inside, counts


def _candidate_key(counts: np.ndarray) -> tuple[int, int, int, float]:
    return (
        int(np.sum(counts >= MIN_COMPONENTS_PER_CELL)),
        int(np.min(counts)),
        int(np.sum(counts)),
        -float(np.std(counts)),
    )


def _best_grid(points: np.ndarray, width: int, height: int) -> tuple[int, int, int, np.ndarray]:
    if height < CELL_HEIGHT or width < 12 * min(CELL_WIDTHS):
        return 0, 0, min(CELL_WIDTHS), np.zeros(12, dtype=np.int32)
    point_image = np.zeros((height, width), dtype=np.uint8)
    if len(points):
        pixel_x = np.clip(np.rint(points[:, 0]).astype(np.int32), 0, width - 1)
        pixel_y = np.clip(np.rint(points[:, 1]).astype(np.int32), 0, height - 1)
        point_image[pixel_y, pixel_x] = 1
    integral = cv2.integral(point_image, sdepth=cv2.CV_32S)

    def counts_for_x_values(y: int, cell_width: int, x_values: np.ndarray) -> np.ndarray:
        starts = x_values[:, None] + np.arange(12, dtype=np.int32)[None, :] * cell_width
        ends = starts + cell_width
        return (
            integral[y + CELL_HEIGHT, ends]
            - integral[y, ends]
            - integral[y + CELL_HEIGHT, starts]
            + integral[y, starts]
        )

    best: tuple[tuple[int, int, int, float], int, int, int, np.ndarray] | None = None
    for y in range(0, height - CELL_HEIGHT + 1, 10):
        for cell_width in CELL_WIDTHS:
            x_values = np.arange(0, width - 12 * cell_width + 1, 10, dtype=np.int32)
            rows = counts_for_x_values(y, cell_width, x_values)
            covered = np.sum(rows >= MIN_COMPONENTS_PER_CELL, axis=1)
            minimum = np.min(rows, axis=1)
            total = np.sum(rows, axis=1)
            spread_score = -np.std(rows, axis=1)
            index = int(np.lexsort((spread_score, total, minimum, covered))[-1])
            counts = rows[index]
            row = (_candidate_key(counts), int(x_values[index]), y, cell_width, counts)
            if best is None or row[0] > best[0]:
                best = row
    if best is None:
        return 0, 0, min(CELL_WIDTHS), np.zeros(12, dtype=np.int32)
    _, coarse_x, coarse_y, coarse_width, _ = best
    refined = best
    for y in range(max(0, coarse_y - 9), min(height - CELL_HEIGHT, coarse_y + 9) + 1):
        for cell_width in range(max(min(CELL_WIDTHS), coarse_width - 1), min(max(CELL_WIDTHS), coarse_width + 1) + 1):
            x_values = np.arange(
                max(0, coarse_x - 9),
                min(width - 12 * cell_width, coarse_x + 9) + 1,
                dtype=np.int32,
            )
            if not len(x_values):
                continue
            rows = counts_for_x_values(y, cell_width, x_values)
            covered = np.sum(rows >= MIN_COMPONENTS_PER_CELL, axis=1)
            minimum = np.min(rows, axis=1)
            total = np.sum(rows, axis=1)
            spread_score = -np.std(rows, axis=1)
            index = int(np.lexsort((spread_score, total, minimum, covered))[-1])
            counts = rows[index]
            row = (_candidate_key(counts), int(x_values[index]), y, cell_width, counts)
            if row[0] > refined[0]:
                refined = row
    return refined[1], refined[2], refined[3], refined[4]


def _maximum_pair_support(
    delta_x: np.ndarray,
    delta_y: np.ndarray,
    pitches: Iterable[int],
    x_tolerance: int,
    y_tolerance: int,
    pitch_axis: str,
) -> tuple[int, int]:
    best = (0, 0)
    for pitch in pitches:
        if pitch_axis == "x":
            matches = (np.abs(delta_x - pitch) <= x_tolerance) & (delta_y <= y_tolerance)
        else:
            matches = (np.abs(delta_y - pitch) <= y_tolerance) & (delta_x <= x_tolerance)
        row = (int(np.count_nonzero(matches)) // 2, pitch)
        if row > best:
            best = row
    return best


def _measure_points(
    points: np.ndarray,
    view: np.ndarray,
    profile: str,
    minimum_character_pair_ratio: float,
    minimum_concentration_ratio: float,
) -> dict[str, Any]:
    x, y, cell_width, counts = _best_grid(points, view.shape[1], view.shape[0])
    inside, counts = _cell_counts(points, x, y, cell_width, CELL_HEIGHT)
    if len(inside):
        delta_x = np.abs(inside[:, None, 0] - inside[None, :, 0])
        delta_y = np.abs(inside[:, None, 1] - inside[None, :, 1])
        horizontal = _maximum_pair_support(delta_x, delta_y, range(6, 31), 2, 3, "x")
        vertical = _maximum_pair_support(delta_x, delta_y, range(10, 41), 3, 2, "y")
        character = _maximum_pair_support(delta_x, delta_y, range(88, 106), 3, 5, "x")
    else:
        horizontal = vertical = character = (0, 0)
    component_count = int(len(inside))
    area_fraction = (12 * cell_width * CELL_HEIGHT) / float(max(1, view.size))
    expected_uniform = len(points) * area_fraction
    concentration = component_count / max(1.0, expected_uniform)
    ratios = {
        "horizontalDotPair": horizontal[0] / float(max(1, component_count)),
        "verticalDotPair": vertical[0] / float(max(1, component_count)),
        "characterPitchPair": character[0] / float(max(1, component_count)),
        "concentration": concentration,
    }
    passed = (
        component_count >= MIN_COMPONENTS
        and int(np.min(counts)) >= MIN_COMPONENTS_PER_CELL
        and ratios["horizontalDotPair"] >= MIN_HORIZONTAL_PAIR_RATIO
        and ratios["verticalDotPair"] >= MIN_VERTICAL_PAIR_RATIO
        and ratios["characterPitchPair"] >= minimum_character_pair_ratio
        and ratios["concentration"] >= minimum_concentration_ratio
    )
    return {
        "schema": SCHEMA,
        "profile": profile,
        "passed": passed,
        "grid": {"x": x, "y": y, "cellWidth": cell_width, "cellHeight": CELL_HEIGHT},
        "qualifiedComponentCount": component_count,
        "allQualifiedComponentCount": int(len(points)),
        "cellComponentCounts": [int(value) for value in counts],
        "pairSupport": {
            "horizontalDot": {"count": horizontal[0], "pitch": horizontal[1]},
            "verticalDot": {"count": vertical[0], "pitch": vertical[1]},
            "character": {"count": character[0], "pitch": character[1]},
        },
        "ratios": ratios,
        "thresholds": {
            "minimumComponents": MIN_COMPONENTS,
            "minimumComponentsPerCell": MIN_COMPONENTS_PER_CELL,
            "minimumHorizontalDotPairRatio": MIN_HORIZONTAL_PAIR_RATIO,
            "minimumVerticalDotPairRatio": MIN_VERTICAL_PAIR_RATIO,
            "minimumCharacterPitchPairRatio": minimum_character_pair_ratio,
            "minimumConcentrationRatio": minimum_concentration_ratio,
        },
    }


def measure_structure(view: np.ndarray) -> dict[str, Any]:
    large = _measure_points(
        _component_centers(view),
        view,
        "LOCAL_RESIDUAL_COMPONENTS",
        MIN_CHARACTER_PAIR_RATIO,
        1.5 if view.shape[0] <= 500 else MIN_CONCENTRATION_RATIO,
    )
    profiles = [large]
    if view.shape[0] <= 500:
        profiles.append(_measure_points(
            _small_blob_centers(view),
            view,
            "SMALL_DOT_BLOBS",
            0.30,
            1.5,
        ))
    passing = [row for row in profiles if bool(row["passed"])]
    selected = max(
        passing if passing else profiles,
        key=lambda row: (
            bool(row["passed"]),
            float(row["ratios"]["horizontalDotPair"])
            + float(row["ratios"]["verticalDotPair"])
            + float(row["ratios"]["characterPitchPair"]),
            int(row["qualifiedComponentCount"]),
        ),
    )
    output = dict(selected)
    output["profiles"] = profiles
    return output


def paired_presence_evidence(bf: np.ndarray, df: np.ndarray) -> dict[str, Any]:
    views = []
    for channel, image in (("BF", bf), ("DF", df)):
        for polarity, view in (("DARK", image), ("BRIGHT", 255 - image)):
            measured = measure_structure(view)
            measured.update({"channel": channel, "polarity": polarity})
            views.append(measured)
    return {
        "schema": SCHEMA,
        "passed": any(bool(row["passed"]) for row in views),
        "decision": "SCRIBE_PRESENT_FOR_OCR" if any(bool(row["passed"]) for row in views) else "HOLD_SCRIBE_NOT_LOCALIZED",
        "views": views,
    }


def _apply_not_localized_hold(result: dict[str, Any], evidence: dict[str, Any]) -> None:
    result["revision"] = REVISION
    result["state"] = "HOLD_SCRIBE_NOT_LOCALIZED"
    result["imageFirstString"] = ""
    result["proposedString"] = ""
    result["checksumState"] = "NOT_EVALUATED_SCRIBE_NOT_LOCALIZED"
    result["hypotheses"] = []
    result["candidates"] = []
    result["holds"] = [{
        "code": "HOLD_SCRIBE_NOT_LOCALIZED",
        "detail": "No candidate independently proved a spatially coherent twelve-cell dot-matrix band; OCR and checksum scoring were not allowed.",
    }]
    result["localization"]["scribePresenceEvidence"] = evidence
    result["provenance"]["engineRevision"] = REVISION
    result["provenance"]["preOcrStructureGate"] = True


def run_job(job_path: Path, result_path: Path) -> int:
    r11 = _load_r11()
    job = r11.read_json(job_path)
    r11.validate_job_shape(job)
    roots = {str(row["relativePrefix"]): Path(str(row["path"])) for row in job["references"]["roots"]}
    prototypes, reference_evidence = r11.load_reference_prototypes(
        Path(str(job["references"]["manifestPath"])),
        str(job["references"]["manifestSha256"]),
        roots,
    )
    supplemental_path = str(job["references"].get("supplementalManifestPath", ""))
    supplemental_sha256 = str(job["references"].get("supplementalManifestSha256", ""))
    if bool(supplemental_path) != bool(supplemental_sha256):
        raise ValueError("Supplemental reference path and SHA-256 must be supplied together.")
    if supplemental_path:
        supplement_loader = _load_supplement_loader()
        prototypes, reference_evidence = supplement_loader.combine_reference_prototypes(
            r11,
            prototypes,
            reference_evidence,
            Path(supplemental_path),
            supplemental_sha256,
        )
    bf, bf_evidence = r11.decode_source(job["inputs"]["bf"])
    df, df_evidence = r11.decode_source(job["inputs"]["df"])
    if str(job.get("inputMode", "POSE_BOUND_WHOLE_IMAGE")) != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT" and bf.shape != df.shape:
        raise ValueError("BF and DF dimensions differ.")

    original_evaluate = r11.evaluate_detector_input
    cache: dict[str, dict[str, Any]] = {}

    def gated_evaluate(gray: np.ndarray, active: list[Any], excluded: str, frozen_grid: Any = None) -> dict[str, Any]:
        key = hashlib.sha256(gray.tobytes()).hexdigest()
        evidence = cache.setdefault(key, measure_structure(gray))
        if not bool(evidence["passed"]):
            raise ValueError("HOLD_SCRIBE_NOT_LOCALIZED")
        evaluated = original_evaluate(gray, active, excluded, frozen_grid)
        evaluated["scribePresence"] = evidence
        return evaluated

    r11.evaluate_detector_input = gated_evaluate
    result = r11.analyze_images(job, bf, df, prototypes, reference_evidence, {
        "bf": bf_evidence,
        "df": df_evidence,
        "jobSha256": r11.sha256_file(job_path),
    })
    result["revision"] = REVISION
    result["provenance"]["engineRevision"] = REVISION
    result["provenance"]["preOcrStructureGate"] = True
    if not result["hypotheses"]:
        direct_evidence = paired_presence_evidence(bf, df) if str(job.get("inputMode")) == "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT" else {
            "schema": SCHEMA,
            "passed": False,
            "decision": "HOLD_SCRIBE_NOT_LOCALIZED",
            "detail": "All image-localized candidate patches failed the pre-OCR structure gate.",
        }
        _apply_not_localized_hold(result, direct_evidence)
    r11.write_json_new(result_path, result)
    print(json.dumps({"state": result["state"], "resultPath": str(result_path), "candidateCount": len(result["candidates"])}))
    return 0


def main(argv: Iterable[str]) -> int:
    r11 = _load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as error:
        print(json.dumps({"state": "HOLD_OPENCV_SCRIBE_PROVIDER_ERROR", "errorType": type(error).__name__, "detail": str(error)}), file=sys.stderr)
        raise
