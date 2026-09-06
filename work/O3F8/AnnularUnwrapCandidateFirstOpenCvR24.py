#!/usr/bin/env python3
"""R24 review-only candidate-first annular native-edge detector.

Inference and post-label evaluation are deliberately separate commands.  The
inference command never parses the scorer-only label.  It enumerates every
full-perimeter raw-depth response, traces every response from channel-local
native transition support, records irregular responses without coercing them
into a manufactured curve, and freezes the complete neutral population.

This module grants no production, provider, fiducial, registration, training,
XML, task/process, source-mutation, or hold-clearance authority.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import sys
from typing import Any, Iterable

import cv2
import numpy as np


HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parent.parent

CHECKPOINT_SHA256 = "F335161BD260AC602AA6E78D8B180F0A61A64BDAA0CFD97456BEF419AF633619"
ROLLOVER_MANIFEST_SHA256 = "7B05BF8F710E6DC684F71D62E19661C6D85F417397B8271E74828E0618DF2A2C"
ROLLOVER_GATE_SHA256 = "A65140C99AE76019DE6B5556CA9EA661E7B1162268A17928E27F487C4A6D5FFA"
SOURCE_JOB_SHA256 = "2C2D656A879BBA1DEC6377D1855A949459C7AC6F50145761B8D283076FEAD1F9"
GEOMETRY_JOB_SHA256 = "E384ABD12E9B77DB9B4492504A5D792E316C5396C3B0A3E1D2B1AB11BB4C7DD3"
SCORER_LABELS_SHA256 = "F8337BB2DDA12DBBA5769677C5A1A31E54CDD54659E0137F2EB9694EC2CCA668"
HOTSPOT_INPUT_SHA256 = "9EB2D63E2F677177B35EE9AD0EF4A35B3379E2B6845025ABB7D549E4FF1AEEA9"
HOTSPOT_ORACLE_SHA256 = "FEE52EC0EDE95F1C359071E5742B4596FC750F6DCAC29871892DCF5DA9F2EF32"
HOTSPOT_ORACLE_GATE_SHA256 = "B78DE5AF8C3633161AF2B565083B2526062F27425696B1BF9A4A9B4E76EBF6C6"
R18_BASELINE_SUMMARY_SHA256 = "3B7C3E32307351453F4F0F8A9146703F203B21906D619FE48252E8CAF78709B5"
R20_BASELINE_SUMMARY_SHA256 = "90FDD521B6322836692754FD88670BB9275EBE12E34F376C0D4B9996382411E6"
R21_SHA256 = "794F750078F323B99AB17802549ACBBBF61973380982F2A4D53A20E1FCE2C3F4"
R22_SHA256 = "CEC62EEBBF71B633D3371BD6AA5372F49E430110F4382BAC568167A1DDAA5C07"
R23_SHA256 = "E21FA14B88248AE9F50A2022A53FF4F7C7201E8B6DF74B3FAB3FD2DC475B360B"
RUNTIME_SHA256 = "D70FCED7F461F38F9F224D8673FB74E96E4FACB4283FF4E8697543B457FEA8A0"
R22_SUMMARY_SHA256 = "9818ADAC53A39E969F9A368098E5842083475BE990B8AFF6D3850BD8152E1564"
R22_GATE_SHA256 = "8262ED3CB363377828D1037008E920182E594F2282A07EAD08F95FBD55970BF2"
R23_SUMMARY_SHA256 = "6A7D841E390B67D764BAB01CB6C653493653AB3DE6EB47CB73C65D318CD9ADB2"
R23_GATE_SHA256 = "BE0922CC30DE828AED88C38FFA715DE633CA173F68E3BC44B52F387CE79A6CB8"

R21_PATH = HERE / "AnnularUnwrapDiagnosticOpenCvR21.py"
R22_PATH = HERE / "AnnularUnwrapPost2ComparisonOpenCvR22.py"
R23_PATH = HERE / "AnnularUnwrapPost2HeldReviewOpenCvR23.py"
EXTERNAL_R18_PATH = Path(r"C:\O3F16U16PROBE2\engine\AnnularUnwrapDiagnosticOpenCvR18.py")
R18_BASELINE_SUMMARY = Path(r"C:\O3F16U18LAB_DRAFT1\SUMMARY.json")
R20_BASELINE_SUMMARY = Path(r"C:\O3F16U20LAB_DRAFT1\SUMMARY.json")
R22_SUMMARY = Path(r"C:\O3F16U22P2_INFER_DRAFT1\SUMMARY.json")
R22_GATE = Path(r"C:\O3F16U22P2_INFER_DRAFT1\INFERENCE_GATE.json")
R23_SUMMARY = Path(r"C:\O3F16U23P2_HELD_REVIEW_DRAFT1\SUMMARY.json")
R23_GATE = Path(r"C:\O3F16U23P2_HELD_REVIEW_DRAFT1\REVIEW_GATE.json")
EXPECTED_INFERENCE_ROOT = Path(r"C:\O3F16U24P2_CANDIDATE_DRAFT1")

TRACE_SCHEMA = "argos_ocv03_annular_candidate_first_r24_native_trace_v1"
POPULATION_SCHEMA = "argos_ocv03_annular_candidate_first_r24_neutral_population_v1"
SUMMARY_SCHEMA = "argos_ocv03_annular_candidate_first_r24_inference_v1"
FREEZE_SCHEMA = "argos_ocv03_annular_candidate_first_r24_freeze_manifest_v1"
GATE_SCHEMA = "argos_ocv03_annular_candidate_first_r24_inference_gate_v1"
EVALUATION_SCHEMA = "argos_ocv03_annular_candidate_first_r24_post_label_evaluation_v1"

HASH_CHUNK_BYTES = 8 * 1024 * 1024
SHOULDER_WINDOW_SAMPLES = 9
MINIMUM_SHOULDER_SUPPORT_SAMPLES = 7
MINIMUM_PATH_COVERAGE_FRACTION = 0.90
MAXIMUM_UNSUPPORTED_RUN_SAMPLES = 1
MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE = 6.0
MINIMUM_RAW_CANDIDATE_FLOOR_PX = 8.0
MAXIMUM_RETURN_RESIDUAL_FROM_NORMAL_TRACE_PX = 8.0
MAXIMUM_SMOOTH_SECOND_DIFFERENCE_P90_PX = 4.0
MAXIMUM_EXTRA_CURVATURE_REVERSAL_FRACTION = 0.08
PARALLEL_BAND_SEPARATION_PX = 3.0
R6_SECONDARY_TOLERANCE_DEGREES = 0.8
CANDIDATE_REVIEW_HALF_WIDTH_COLUMNS = 512
CANDIDATE_REVIEW_HEADER_PX = 34
HOLD_BAR_ROWS = 3
PATH_COUNT_SATURATION = 1_000_001

CYAN = (255, 255, 0)
YELLOW = (0, 255, 255)
LIME = (0, 255, 0)
ORANGE = (0, 128, 255)
MAGENTA = (255, 0, 255)
OBSTRUCTION_BLUE = (255, 80, 0)
WHITE = (255, 255, 255)


def need(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while True:
            block = stream.read(HASH_CHUNK_BYTES)
            if not block:
                break
            digest.update(block)
    return digest.hexdigest().upper()


def require_exact_file(path: Path, expected_sha256: str, label: str, size: int | None = None) -> None:
    need(path.is_file(), f"Missing {label}: {path}")
    if size is not None:
        need(path.stat().st_size == int(size), f"{label} byte count changed: {path}")
    need(sha256_file(path) == expected_sha256.upper(), f"{label} hash changed: {path}")


def file_record(path: Path, known_sha256: str | None = None) -> dict[str, Any]:
    need(path.is_file(), f"Cannot record missing file: {path}")
    actual = sha256_file(path)
    if known_sha256 is not None:
        need(actual == known_sha256.upper(), f"Recorded file hash changed: {path}")
    return {"path": str(path), "bytes": path.stat().st_size, "sha256": actual}


def write_bytes_new(path: Path, data: bytes) -> dict[str, Any]:
    need(path.parent.is_dir(), f"Output parent is missing: {path.parent}")
    need(len(path.name) <= 80, f"Output path component exceeds 80 characters: {path.name}")
    need(len(str(path)) < 200, f"Output path reaches the 200-character safety stop: {path}")
    with path.open("xb") as stream:
        stream.write(data)
    return file_record(path)


def write_json_new(path: Path, payload: dict[str, Any]) -> dict[str, Any]:
    encoded = (json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n").encode("utf-8")
    return write_bytes_new(path, encoded)


def write_png_new(path: Path, image: np.ndarray) -> dict[str, Any]:
    ok, encoded = cv2.imencode(".png", image)
    need(bool(ok), f"OpenCV PNG encode failed: {path}")
    return write_bytes_new(path, encoded.tobytes())


def safe_stem(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("._")
    return (cleaned[:20] or "case") + "_" + hashlib.sha256(value.encode("utf-8")).hexdigest()[:10]


def same_windows_path(left: Path, right: Path) -> bool:
    return str(left.absolute()).replace("/", "\\").rstrip("\\").casefold() == str(
        right.absolute()
    ).replace("/", "\\").rstrip("\\").casefold()


def preflight_output_layout(root: Path, identities: Iterable[str], evaluation: bool = False) -> None:
    components = {
        "neutral",
        "post2",
        "hotspot",
        "evaluation",
        "POST2_R24_POSTFREEZE_SAME_ANGLE_NATIVE_COMPARISON.png",
        "NEUTRAL_CANDIDATE_POPULATION.json",
        "FREEZE_MANIFEST.json",
        "INFERENCE_GATE.json",
        "REVIEW_GATE.json",
        "SUMMARY.json",
    }
    suffixes = (
        "_full_enhanced_clean.png",
        "_circle_brightness_review.png",
        "_candidate_support_graph_mask.png",
        "_candidate_trace_mask.png",
        "_predecessor_hold_mask.png",
        "_obstruction_hold_mask.png",
        "_bf_c9999_obstruction_hold_mask.png",
        "_df_c9999_support_graph_mask.png",
    )
    for identity in identities:
        stem = safe_stem(str(identity))
        for suffix in suffixes:
            components.add(stem + suffix)
    longest_component = max(components, key=len)
    need(len(longest_component) <= 80, f"Planned output component exceeds 80 characters: {longest_component}")
    deepest = (
        root / "cases" / "P0001" / longest_component
        if evaluation
        else root / "neutral" / "hotspot" / "H0001" / longest_component
    )
    need(len(str(deepest)) < 200, f"Planned output path reaches the 200-character safety stop: {deepest}")


def configure_pinned_dependency_paths() -> None:
    requested = {
        "ARGOS_R18_ENGINE_PATH": EXTERNAL_R18_PATH,
        "ARGOS_R18_BASELINE_SUMMARY": R18_BASELINE_SUMMARY,
        "ARGOS_R20_BASELINE_SUMMARY": R20_BASELINE_SUMMARY,
    }
    for name, path in requested.items():
        existing = os.environ.get(name)
        if existing:
            need(Path(existing).resolve() == path.resolve(), f"{name} differs from the frozen R24 dependency path")
        os.environ[name] = str(path)


configure_pinned_dependency_paths()
require_exact_file(R21_PATH, R21_SHA256, "R21 engine")
SPEC = importlib.util.spec_from_file_location("argos_annular_r21_for_r24", R21_PATH)
need(SPEC is not None and SPEC.loader is not None, f"Cannot load {R21_PATH}")
r21 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = r21
SPEC.loader.exec_module(r21)
r18 = r21.r19.r18


def load_json_pinned(path: Path, expected_sha256: str, label: str) -> dict[str, Any]:
    require_exact_file(path, expected_sha256, label)
    value = json.loads(path.read_text(encoding="utf-8"))
    need(isinstance(value, dict), f"{label} is not a JSON object")
    return value


def assert_review_only(document: dict[str, Any], label: str) -> None:
    need(bool(document.get("reviewOnly")), f"{label} is not review-only")
    for key in (
        "trainingEligible",
        "xmlEligible",
        "productionEligible",
        "productionRoutingEnabled",
        "liveProviderActivation",
        "sourceMutationAllowed",
        "providerActivationAllowed",
        "processorActionAllowed",
        "holdClearanceAllowed",
    ):
        need(not bool(document.get(key)), f"{label} authority forbids {key}")


def set_from_indices(size: int, indices: Iterable[int]) -> np.ndarray:
    result = np.zeros(size, dtype=bool)
    values = np.asarray(list(indices), dtype=np.int64)
    if values.size:
        need(bool(np.all((values >= 0) & (values < size))), "Index lies outside frozen trace width")
        result[values] = True
    return result


def index_list(values: np.ndarray) -> list[int]:
    return [int(value) for value in np.flatnonzero(np.asarray(values, dtype=bool))]


def numeric_path(values: np.ndarray) -> list[float | None]:
    flat = np.asarray(values).reshape(-1)
    return [float(value) if math.isfinite(float(value)) else None for value in flat]


def longest_false_run(values: np.ndarray) -> int:
    best = current = 0
    for value in np.asarray(values, dtype=bool):
        current = 0 if bool(value) else current + 1
        best = max(best, current)
    return best


def linear_true_runs(values: np.ndarray) -> list[np.ndarray]:
    indices = np.flatnonzero(np.asarray(values, dtype=bool))
    if indices.size == 0:
        return []
    breaks = np.flatnonzero(np.diff(indices) > 1) + 1
    return [part for part in np.split(indices, breaks) if part.size]


def circular_distance_degrees(left: float, right: float) -> float:
    return abs((float(left) - float(right) + 180.0) % 360.0 - 180.0)


def circular_weighted_degrees(columns: np.ndarray, weights: np.ndarray, width: int) -> float:
    angles = np.asarray(columns, dtype=np.float64) * (2.0 * math.pi / width)
    positive = np.maximum(np.asarray(weights, dtype=np.float64), 1.0e-6)
    vector = np.sum(positive * np.exp(1j * angles))
    need(abs(vector) > 0.0, "Circular center vector is zero")
    return float(math.degrees(np.angle(vector)) % 360.0)


def ordered_span(left: int, right: int, width: int) -> np.ndarray:
    count = (int(right) - int(left)) % width + 1
    need(count <= width // 2, "Candidate shoulder span reaches at least half the perimeter")
    return (int(left) + np.arange(count, dtype=np.int64)) % width


def normal_trace_shoulder_window(
    normal_path: np.ndarray,
    normal_observed: np.ndarray,
    transition: dict[str, Any],
    boundary: int,
    direction: int,
    obstruction: np.ndarray,
) -> dict[str, Any]:
    width = int(normal_path.size)
    offsets = transition["searchOffsets"]
    support = transition["nativeSupported"]
    entries: list[dict[str, Any]] = []
    anchor: dict[str, Any] | None = None
    for distance in range(1, SHOULDER_WINDOW_SAMPLES + 1):
        column = (int(boundary) + direction * distance) % width
        row: int | None = None
        native_supported = False
        if bool(normal_observed[column]) and math.isfinite(float(normal_path[column])):
            proposed = int(np.argmin(np.abs(offsets - float(normal_path[column]))))
            if abs(float(offsets[proposed]) - float(normal_path[column])) <= 1.0e-6:
                row = proposed
                native_supported = bool(support[proposed, column]) and not bool(obstruction[column])
        entry = {
            "column": int(column),
            "row": row,
            "offsetPx": None if row is None else float(offsets[row]),
            "distanceFromRawComponentSamples": distance,
            "nativeNormalTraceSupported": native_supported,
            "obstructionColumn": bool(obstruction[column]),
        }
        entries.append(entry)
        if anchor is None and native_supported and row is not None:
            anchor = {
                "column": int(column),
                "row": row,
                "offsetPx": float(offsets[row]),
                "distanceFromRawComponentSamples": distance,
            }
    supported_count = sum(bool(entry["nativeNormalTraceSupported"]) for entry in entries)
    return {
        "population": "EXACT_NINE_NATIVE_COLUMNS_IMMEDIATELY_OUTSIDE_RAW_COMPONENT",
        "direction": int(direction),
        "expectedSampleCount": SHOULDER_WINDOW_SAMPLES,
        "minimumSupportedSampleCount": MINIMUM_SHOULDER_SUPPORT_SAMPLES,
        "supportedSampleCount": supported_count,
        "supportedFraction": float(supported_count / SHOULDER_WINDOW_SAMPLES),
        "passed": supported_count >= MINIMUM_SHOULDER_SUPPORT_SAMPLES and anchor is not None,
        "entries": entries,
        "anchor": anchor,
    }


def column_band_nodes(
    transition: dict[str, Any],
    column: int,
    forced_rows: set[int],
) -> tuple[list[int], dict[int, int]]:
    support = transition["nativeSupported"][:, column]
    raw = transition["rawContrast"][:, column]
    enhanced = transition["enhancedContrast"][:, column]
    rows = np.flatnonzero(support)
    if rows.size == 0:
        return [], {}
    breaks = np.flatnonzero(np.diff(rows) > 1) + 1
    bands = [part for part in np.split(rows, breaks) if part.size]
    selected: list[int] = []
    ordinals: dict[int, int] = {}
    for ordinal, band in enumerate(bands):
        forced = [value for value in forced_rows if int(band[0]) <= value <= int(band[-1])]
        if forced:
            row = int(sorted(forced)[0])
        else:
            row = max(
                (int(value) for value in band),
                key=lambda value: (float(enhanced[value]), float(raw[value]), -value),
            )
        selected.append(row)
        ordinals[row] = ordinal
    return selected, ordinals


def candidate_graph_trace(
    strip: np.ndarray,
    offsets: np.ndarray,
    outer_path: np.ndarray,
    normal_path: np.ndarray,
    normal_observed: np.ndarray,
    transition: dict[str, Any],
    component_info: dict[str, Any],
    threshold: float,
    params: Any,
    candidate_index: int,
    channel: str,
    obstruction: np.ndarray,
    predecessor_held: np.ndarray,
) -> dict[str, Any]:
    width = int(outer_path.size)
    degrees_per_sample = 360.0 / width
    component = np.asarray(component_info["component"], dtype=np.int64)
    component_rows = {
        int(column): sorted(set(int(row) for row in rows))
        for column, rows in component_info["componentRows"].items()
    }
    core_rows = {
        int(column): set(int(row) for row in rows)
        for column, rows in component_info["coreRows"].items()
    }
    core_columns = sorted(core_rows)
    need(component.size > 0 and core_columns, "R24 candidate component is empty")
    left_window = normal_trace_shoulder_window(
        normal_path, normal_observed, transition, int(component[0]), -1, obstruction
    )
    right_window = normal_trace_shoulder_window(
        normal_path, normal_observed, transition, int(component[-1]), 1, obstruction
    )
    left_anchor = left_window["anchor"]
    right_anchor = right_window["anchor"]
    empty_path = np.full(width, np.nan, dtype=np.float32)
    empty_observed = np.zeros(width, dtype=bool)
    raw_nodes = [
        {"column": column, "radialRow": row}
        for column in sorted(component_rows)
        for row in component_rows[column]
    ]
    component_native_points = [
        (int(node["column"]), int(node["radialRow"])) for node in raw_nodes
    ]
    search_offsets = np.asarray(transition["searchOffsets"], dtype=np.float32)
    base: dict[str, Any] = {
        "candidateIndex": candidate_index,
        "candidateId": f"{channel}_C{candidate_index + 1:04d}",
        "channel": channel,
        "angleSampleCount": width,
        "algorithm": "FULL_NATIVE_SUPPORT_GRAPH_WITH_BRIGHTNESS_ONLY_REPRESENTATIVE_PATH",
        "candidateDiscovery": "UNSMOOTHED_UNMORPHED_2D_NATIVE_RAW_DEPTH_COMPONENT",
        "componentColumnIndices": [int(value) for value in component],
        "coreColumnIndices": core_columns,
        "rawComponentNativeNodes": raw_nodes,
        "componentSampleCount": int(component.size),
        "coreSampleCount": sum(len(rows) for rows in core_rows.values()),
        "rawComponentStartAngleDegrees": float(component[0] * degrees_per_sample),
        "rawComponentEndAngleDegrees": float(component[-1] * degrees_per_sample),
        "rawComponentWidthDegrees": float(component.size * degrees_per_sample),
        "startAngleDegrees": float(component[0] * degrees_per_sample),
        "endAngleDegrees": float(component[-1] * degrees_per_sample),
        "widthDegrees": float(component.size * degrees_per_sample),
        "ownershipIntervalBasis": "RAW_COMPONENT_ONLY_UNTIL_NATIVE_SHOULDER_PATH_COMPLETES",
        "centerAngleDegrees": circular_weighted_degrees(
            np.asarray(core_columns, dtype=np.int64),
            np.ones(len(core_columns), dtype=np.float64),
            width,
        ),
        "rawDepthThresholdPx": float(threshold),
        "leftShoulderWindow": left_window,
        "rightShoulderWindow": right_window,
        "leftAnchor": left_anchor,
        "rightAnchor": right_anchor,
        "broadHalfPerimeterResponse": bool(component_info.get("broadHalfPerimeterResponse")),
        "templateOrIdealCurveUsed": False,
        "candidateCenterUsedByTraversal": False,
        "monotonicityUsedByTraversal": False,
        "morphologyPerformed": False,
        "interpolationPerformed": False,
        "syntheticCoordinateCount": 0,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "manufacturedCompatibleAfterContour": False,
    }

    def held_result(state: str, reasons: list[str], support_points: list[tuple[int, int]] | None = None,
                    span: np.ndarray | None = None) -> dict[str, Any]:
        points = sorted(set(component_native_points if support_points is None else support_points))
        selected_span = np.asarray(component.copy() if span is None else span, dtype=np.int64)
        need(bool(points) and selected_span.size > 0, "Held candidate lost its native component population")
        span_set = {int(column) for column in selected_span}
        need(
            all(int(column) in span_set for column, _ in points),
            "Held candidate support lies outside its declared metric/review span",
        )
        supported_columns = {int(column) for column, _ in points}
        span_supported = np.asarray(
            [int(column) in supported_columns for column in selected_span], dtype=bool
        )
        unsupported_columns = [
            int(selected_span[index]) for index in np.flatnonzero(~span_supported)
        ]
        point_depths = np.asarray(
            [float(outer_path[column] - search_offsets[row]) for column, row in points],
            dtype=np.float64,
        )
        point_raw = np.asarray(
            [float(transition["directRawContrast"][row, column]) for column, row in points],
            dtype=np.float64,
        )
        point_enhanced = np.asarray(
            [float(transition["enhancedContrast"][row, column]) for column, row in points],
            dtype=np.float64,
        )

        def shoulder_measurement(anchor: dict[str, Any] | None) -> tuple[float | None, float | None, float | None, str]:
            if anchor is None:
                return None, None, None, "NOT_MEASURABLE_UNRESOLVED_MISSING_NATIVE_SHOULDER"
            column = int(anchor["column"])
            row = int(anchor["row"])
            if not bool(normal_observed[column]) or not math.isfinite(float(normal_path[column])):
                return None, None, None, "NOT_MEASURABLE_UNRESOLVED_NORMAL_TRACE_ABSENT"
            shoulder_depth = float(outer_path[column] - search_offsets[row])
            normal_depth = float(outer_path[column] - normal_path[column])
            return (
                shoulder_depth,
                normal_depth,
                abs(shoulder_depth - normal_depth),
                "MEASURED_NATIVE_SHOULDER_TO_SAME_FIXED_OUTER_CIRCLE",
            )

        left_depth, left_normal_depth, left_residual, left_state = shoulder_measurement(left_anchor)
        right_depth, right_normal_depth, right_residual, right_state = shoulder_measurement(right_anchor)
        band_counts: list[int] = []
        parallel_band_columns = 0
        for column in sorted(component_rows):
            rows = np.asarray(component_rows[column], dtype=np.int64)
            band_count = 0 if rows.size == 0 else int(np.count_nonzero(np.diff(rows) > 1) + 1)
            band_counts.append(band_count)
            if band_count >= 2:
                breaks = np.flatnonzero(np.diff(rows) > 1)
                separations = [
                    float(search_offsets[int(rows[index + 1])] - search_offsets[int(rows[index])])
                    for index in breaks
                ]
                if max(separations, default=0.0) >= PARALLEL_BAND_SEPARATION_PX:
                    parallel_band_columns += 1
        unresolved_path_state = "NOT_MEASURABLE_UNRESOLVED_NO_COMPLETE_NATIVE_SHOULDER_PATH"
        base.update(
            {
                "state": state,
                "classification": "UNRESOLVED_DEEP_EDGE_RESPONSE",
                "classificationReasons": reasons,
                "evidenceHoldReasons": reasons,
                "postContourMorphologyReasons": [],
                "completeNativeShoulderPath": False,
                "shoulderEndpointsConnectedByNativeGraph": False,
                "expectedSpanColumnCount": int(selected_span.size),
                "supportMetricPopulation": "DECLARED_NATIVE_CANDIDATE_SPAN_NO_FILL",
                "supportMetricSpanColumnIndices": [int(column) for column in selected_span],
                "tracedShoulderColumnIndices": [],
                "representativePathObservedCount": 0,
                "rawSupportedColumnCount": int(np.count_nonzero(span_supported)),
                "rawSupportedFraction": float(np.mean(span_supported)),
                "maximumContiguousUnsupportedRun": longest_false_run(span_supported),
                "unsupportedColumnIndices": unsupported_columns,
                "discoveredComponentNativeColumnCount": len(component_rows),
                "representativePathComponentColumnCount": 0,
                "discoveredComponentCoverageFraction": 0.0,
                "obstructionOverlapColumnIndices": [
                    int(column) for column in selected_span if bool(obstruction[int(column)])
                ],
                "obstructionOverlapColumnCount": int(
                    np.count_nonzero(obstruction[selected_span])
                ),
                "inheritedPredecessorHoldOverlapColumnIndices": [
                    int(column) for column in selected_span if bool(predecessor_held[int(column)])
                ],
                "inheritedPredecessorHoldOverlapColumnCount": int(
                    np.count_nonzero(predecessor_held[selected_span])
                ),
                "leftShoulderDepthFromFixedOuterCirclePx": left_depth,
                "rightShoulderDepthFromFixedOuterCirclePx": right_depth,
                "leftNormalBrightnessTraceDepthFromFixedOuterCirclePx": left_normal_depth,
                "rightNormalBrightnessTraceDepthFromFixedOuterCirclePx": right_normal_depth,
                "leftShoulderReturnResidualFromNormalTracePx": left_residual,
                "rightShoulderReturnResidualFromNormalTracePx": right_residual,
                "shoulderSpanWidthDegrees": (
                    float(selected_span.size * degrees_per_sample)
                    if left_anchor is not None and right_anchor is not None
                    else None
                ),
                "maximumInwardDepthPx": float(np.max(point_depths)),
                "medianInwardDepthPx": float(np.median(point_depths)),
                "apexCount": None,
                "apexBandMinimumDepthPx": None,
                "apexPopulation": unresolved_path_state,
                "apexOffsetFraction": None,
                "postContourShapeTipOffsetFraction": None,
                "leftMonotonicSupportFraction": None,
                "rightMonotonicSupportFraction": None,
                "postContourShapeSlopeConsistencyFraction": None,
                "postContourSymmetryScore": None,
                "maximumAdjacentRadialChangePxPerSample": None,
                "firstDifferenceAbsoluteMedianPx": None,
                "firstDifferenceAbsoluteP90Px": None,
                "secondDifferenceAbsoluteMedianPx": None,
                "secondDifferenceAbsoluteP90Px": None,
                "secondDifferenceAbsoluteMaximumPx": None,
                "slopeDirectionReversalCount": None,
                "curvatureReversalCount": None,
                "curvatureReversalPopulation": unresolved_path_state,
                "extraCurvatureReversalFraction": None,
                "supportGraphNodeCount": len(points),
                "supportGraphBranchColumnCount": int(
                    sum(len(rows) > 1 for rows in component_rows.values())
                ),
                "parallelBandColumnCount": parallel_band_columns,
                "maximumCompleteBandCountPerColumn": max(band_counts, default=0),
                "representativeParallelBandSwitchCount": None,
                "reachableShoulderPathCountSaturated": 0,
                "reachableShoulderPathCountSaturationValue": PATH_COUNT_SATURATION,
                "selectedTransitionWitness": {
                    "state": unresolved_path_state,
                    "population": "NO_REPRESENTATIVE_PATH_SELECTED",
                    "count": 0,
                },
                "rawComponentTransitionWitness": {
                    "population": "ALL_RENDERED_NATIVE_RAW_COMPONENT_NODES",
                    "count": int(point_raw.size),
                    "rawOutsideInMinimum": float(np.min(point_raw)),
                    "rawOutsideInP10": float(np.percentile(point_raw, 10.0)),
                    "rawOutsideInMedian": float(np.median(point_raw)),
                    "enhancedOutsideInMinimum": float(np.min(point_enhanced)),
                    "enhancedOutsideInP10": float(np.percentile(point_enhanced, 10.0)),
                    "enhancedOutsideInMedian": float(np.median(point_enhanced)),
                },
                "gradientNormalAlignmentPostContourMeasurement": {
                    "state": "NOT_REQUIRED_FOR_R24_NATIVE_RAW_POLARITY_CONTOUR",
                    "selectionRole": False,
                },
                "allSelectedPixelsNativeSupported": bool(
                    all(transition["nativeSupported"][row, column] for column, row in points)
                ),
                "allSelectedPixelsRawPolaritySupported": bool(
                    np.all(point_raw >= float(r18.MINIMUM_RAW_POLARITY))
                ),
                "inwardLimitTouchCount": int(
                    sum(
                        math.isclose(float(search_offsets[row]), float(search_offsets[0]), abs_tol=1.0e-6)
                        for _, row in points
                    )
                ),
                "representativePath": [],
                "completeSupportGraphNativeNodes": [],
                "metricAvailability": {
                    "nativeSupport": "MEASURED_DECLARED_NATIVE_CANDIDATE_SPAN_NO_FILL",
                    "fullInwardDepth": "MEASURED_ALL_NATIVE_RAW_COMPONENT_NODES",
                    "leftReturnResidual": left_state,
                    "rightReturnResidual": right_state,
                    "apexAndOffset": unresolved_path_state,
                    "monotonicSides": unresolved_path_state,
                    "smoothnessJaggednessCurvature": unresolved_path_state,
                    "branchAndParallelBands": "MEASURED_ALL_NATIVE_RAW_COMPONENT_NODES",
                    "representativeParallelBandSwitches": unresolved_path_state,
                },
                "pairingEligible": False,
            }
        )
        return {
            "record": base,
            "path": empty_path,
            "observed": empty_observed,
            "supportPoints": points,
            "span": selected_span,
        }

    if not bool(left_window["passed"]) or not bool(right_window["passed"]):
        return held_result(
            "HOLD_MISSING_SUSTAINED_NATIVE_NORMAL_TRACE_SHOULDER",
            ["LEFT_OR_RIGHT_SHOULDER_HAS_FEWER_THAN_SEVEN_OF_NINE_NATIVE_SAMPLES"],
        )
    assert left_anchor is not None and right_anchor is not None
    span_count = (int(right_anchor["column"]) - int(left_anchor["column"])) % width + 1
    if span_count > width // 2:
        return held_result(
            "HOLD_BROAD_RESPONSE_HAS_NO_UNIQUE_SHORT_SHOULDER_INTERVAL",
            ["SHOULDER_INTERVAL_REACHES_AT_LEAST_HALF_PERIMETER"],
        )

    columns = (int(left_anchor["column"]) + np.arange(span_count, dtype=np.int64)) % width
    component_envelope = {int(value) for value in component}
    nodes: list[list[int]] = []
    for position, column_value in enumerate(columns):
        column = int(column_value)
        if position == 0:
            rows = [int(left_anchor["row"])]
        elif position == len(columns) - 1:
            rows = [int(right_anchor["row"])]
        elif bool(obstruction[column]):
            rows = []
        elif column in component_rows:
            rows = [
                row for row in component_rows[column]
                if bool(transition["nativeSupported"][row, column])
            ]
        elif column in component_envelope:
            rows = []
        else:
            # The exact component plus the two native shoulder anchors defines
            # this graph.  It cannot jump onto an unrelated parallel band.
            rows = []
        nodes.append(rows)

    def is_core(position: int, row: int) -> bool:
        return int(row) in core_rows.get(int(columns[position]), set())

    # Each state is keyed by (native row, has visited a raw-depth core).  The
    # ranking uses only supported-node count and measured transition strength;
    # no center, depth, symmetry, slope direction, or curve model participates.
    forward: list[dict[tuple[int, bool], dict[str, Any]]] = [{} for _ in columns]
    if nodes and int(left_anchor["row"]) in nodes[0]:
        row = int(left_anchor["row"])
        seen = is_core(0, row)
        forward[0][(row, seen)] = {
            "count": 1,
            "gaps": 0,
            "enhanced": float(transition["enhancedContrast"][row, columns[0]]),
            "raw": float(transition["directRawContrast"][row, columns[0]]),
            "previous": None,
            "pathCount": 1,
        }
    for position in range(1, len(columns)):
        for row in nodes[position]:
            choices: dict[bool, list[tuple[tuple[Any, ...], dict[str, Any], tuple[int, int, bool]]]] = {
                False: [],
                True: [],
            }
            for delta in (1, 2):
                previous_position = position - delta
                if previous_position < 0:
                    continue
                for (previous_row, previous_seen), previous in forward[previous_position].items():
                    radial_change = abs(float(search_offsets[row] - search_offsets[previous_row]))
                    if radial_change > MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE * delta + 1.0e-6:
                        continue
                    seen = bool(previous_seen or is_core(position, row))
                    state = {
                        "count": int(previous["count"]) + 1,
                        "gaps": int(previous["gaps"]) + delta - 1,
                        "enhanced": float(previous["enhanced"])
                        + float(transition["enhancedContrast"][row, columns[position]]),
                        "raw": float(previous["raw"])
                        + float(transition["directRawContrast"][row, columns[position]]),
                        "previous": (previous_position, int(previous_row), bool(previous_seen)),
                        "pathCount": int(previous["pathCount"]),
                    }
                    rank = (
                        state["count"],
                        -state["gaps"],
                        state["enhanced"],
                        state["raw"],
                        -row,
                    )
                    choices[seen].append((rank, state, (previous_position, int(previous_row), bool(previous_seen))))
            for seen, entries in choices.items():
                if not entries:
                    continue
                entries.sort(key=lambda item: item[0], reverse=True)
                best = entries[0][1]
                best["pathCount"] = min(
                    PATH_COUNT_SATURATION,
                    sum(int(item[1]["pathCount"]) for item in entries),
                )
                forward[position][(int(row), bool(seen))] = best

    backward: list[dict[int, set[bool]]] = [dict() for _ in columns]
    if nodes and int(right_anchor["row"]) in nodes[-1]:
        row = int(right_anchor["row"])
        backward[-1][row] = {is_core(len(columns) - 1, row)}
    for position in range(len(columns) - 2, -1, -1):
        for row in nodes[position]:
            flags: set[bool] = set()
            for delta in (1, 2):
                next_position = position + delta
                if next_position >= len(columns):
                    continue
                for next_row, next_flags in backward[next_position].items():
                    radial_change = abs(float(search_offsets[row] - search_offsets[next_row]))
                    if radial_change > MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE * delta + 1.0e-6:
                        continue
                    flags.update(bool(value or is_core(position, row)) for value in next_flags)
            if flags:
                backward[position][int(row)] = flags

    complete_nodes: list[list[int]] = [[] for _ in columns]
    support_points: list[tuple[int, int]] = []
    for position, column_value in enumerate(columns):
        for row in nodes[position]:
            forward_flags = {seen for candidate_row, seen in forward[position] if candidate_row == row}
            backward_flags = backward[position].get(int(row), set())
            if any(bool(left or right) for left in forward_flags for right in backward_flags):
                complete_nodes[position].append(int(row))
                support_points.append((int(column_value), int(row)))

    endpoint_key = (int(right_anchor["row"]), True)
    endpoint = forward[-1].get(endpoint_key) if forward else None
    if endpoint is None:
        return held_result(
            "HOLD_NO_CORE_VISITING_NATIVE_SHOULDER_TO_SHOULDER_PATH",
            ["NO_COMPLETE_NATIVE_PATH_THROUGH_RAW_DEPTH_CORE"],
            span=columns,
        )

    sequence: list[tuple[int, int, bool]] = []
    position = len(columns) - 1
    row = int(right_anchor["row"])
    seen = True
    while True:
        sequence.append((position, row, seen))
        state = forward[position][(row, seen)]
        previous = state["previous"]
        if previous is None:
            break
        position, row, seen = previous
    sequence.reverse()
    need(sequence[0][0] == 0 and sequence[-1][0] == len(columns) - 1, "Native path endpoints changed")

    path = empty_path.copy()
    observed = empty_observed.copy()
    span_observed = np.zeros(columns.size, dtype=bool)
    path_columns: list[int] = []
    path_rows: list[int] = []
    path_positions: list[int] = []
    for position, row, _ in sequence:
        column = int(columns[position])
        need(bool(transition["nativeSupported"][row, column]), "Representative trace contains unsupported coordinate")
        path[column] = float(search_offsets[row])
        observed[column] = True
        span_observed[position] = True
        path_columns.append(column)
        path_rows.append(row)
        path_positions.append(position)

    selected_offsets = np.asarray([float(search_offsets[row]) for row in path_rows], dtype=np.float64)
    selected_depth = outer_path[np.asarray(path_columns, dtype=np.int64)].astype(np.float64) - selected_offsets
    selected_raw = np.asarray(
        [float(transition["directRawContrast"][row, column]) for row, column in zip(path_rows, path_columns)],
        dtype=np.float64,
    )
    selected_enhanced = np.asarray(
        [float(transition["enhancedContrast"][row, column]) for row, column in zip(path_rows, path_columns)],
        dtype=np.float64,
    )
    missing_run = longest_false_run(span_observed)
    coverage = float(np.mean(span_observed))
    adjacent_positions = np.diff(np.asarray(path_positions, dtype=np.int64))
    adjacent_offsets = np.diff(selected_offsets)
    maximum_adjacent_change = (
        float(np.max(np.abs(adjacent_offsets) / adjacent_positions)) if adjacent_offsets.size else 0.0
    )
    inward_limit_count = int(
        np.count_nonzero(np.isclose(selected_offsets, float(search_offsets[0]), rtol=0.0, atol=1.0e-6))
    )

    apex_mask = np.zeros(selected_depth.size, dtype=bool)
    if selected_depth.size:
        apex_band_drop = max(3.0, 0.08 * float(np.ptp(selected_depth)))
        apex_level = max(float(threshold), float(np.max(selected_depth)) - apex_band_drop)
        apex_mask = selected_depth >= apex_level
    else:
        apex_level = float(threshold)
    apex_runs = linear_true_runs(apex_mask)
    apex_count = len(apex_runs)
    apex_position = int(np.argmax(selected_depth)) if selected_depth.size else 0
    apex_offset_fraction = (
        abs(apex_position - (selected_depth.size - 1) / 2.0) / max((selected_depth.size - 1) / 2.0, 1.0)
        if selected_depth.size
        else 1.0
    )
    tolerance = 2.0
    left_steps = np.diff(selected_depth[: apex_position + 1])
    right_steps = np.diff(selected_depth[apex_position:])
    left_monotonic = float(np.mean(left_steps >= -tolerance)) if left_steps.size else 0.0
    right_monotonic = float(np.mean(right_steps <= tolerance)) if right_steps.size else 0.0
    first_difference = np.diff(selected_depth)
    second_difference = np.diff(selected_depth, n=2)
    slope_signs = np.sign(first_difference[np.abs(first_difference) > 1.0])
    slope_direction_reversals = (
        int(np.count_nonzero(slope_signs[1:] != slope_signs[:-1]))
        if slope_signs.size >= 2
        else 0
    )
    curvature_signs = np.sign(second_difference[np.abs(second_difference) > 1.0])
    curvature_reversals = (
        int(np.count_nonzero(curvature_signs[1:] != curvature_signs[:-1]))
        if curvature_signs.size >= 2
        else 0
    )
    extra_reversal_fraction = max(0, curvature_reversals - 1) / max(int(first_difference.size), 1)
    def row_bands(rows: list[int]) -> list[np.ndarray]:
        values = np.asarray(sorted(set(int(row) for row in rows)), dtype=np.int64)
        if values.size == 0:
            return []
        breaks = np.flatnonzero(np.diff(values) > 1) + 1
        return [part for part in np.split(values, breaks) if part.size]

    complete_bands = [row_bands(rows) for rows in complete_nodes]
    parallel_band_columns = 0
    maximum_complete_band_count = 0
    for bands in complete_bands:
        maximum_complete_band_count = max(maximum_complete_band_count, len(bands))
        if len(bands) >= 2:
            separations = [
                float(search_offsets[int(bands[index + 1][0])]
                      - search_offsets[int(bands[index][-1])])
                for index in range(len(bands) - 1)
            ]
            if max(separations, default=0.0) >= PARALLEL_BAND_SEPARATION_PX:
                parallel_band_columns += 1
    parallel_band_switch_count = 0
    for index in range(1, len(path_positions)):
        if path_positions[index] - path_positions[index - 1] != 1:
            continue
        previous_position = path_positions[index - 1]
        current_position = path_positions[index]
        previous_row = path_rows[index - 1]
        current_row = path_rows[index]
        previous_band = next(
            band for band in complete_bands[previous_position] if previous_row in band
        )
        current_bands = complete_bands[current_position]
        selected_band = next(band for band in current_bands if current_row in band)
        def band_separation(left: np.ndarray, right: np.ndarray) -> float:
            if int(left[-1]) < int(right[0]):
                return float(search_offsets[int(right[0])] - search_offsets[int(left[-1])])
            if int(right[-1]) < int(left[0]):
                return float(search_offsets[int(left[0])] - search_offsets[int(right[-1])])
            return 0.0
        selected_separation = band_separation(previous_band, selected_band)
        best_continuation = min(
            (band_separation(previous_band, band) for band in current_bands),
            default=float("inf"),
        )
        if (
            selected_separation >= PARALLEL_BAND_SEPARATION_PX
            and selected_separation > best_continuation + 1.0e-6
        ):
            parallel_band_switch_count += 1
    left_depth = float(selected_depth[0])
    right_depth = float(selected_depth[-1])
    left_column = int(left_anchor["column"])
    right_column = int(right_anchor["column"])
    left_normal_depth = float(outer_path[left_column] - normal_path[left_column])
    right_normal_depth = float(outer_path[right_column] - normal_path[right_column])
    left_return_residual = abs(left_depth - left_normal_depth)
    right_return_residual = abs(right_depth - right_normal_depth)
    center_weights = np.maximum(selected_depth - min(left_depth, right_depth), 0.001)
    center_degrees = circular_weighted_degrees(
        np.asarray(path_columns, dtype=np.int64), center_weights, width
    )
    path_width_degrees = float(columns.size * degrees_per_sample)
    if selected_depth.size >= 3:
        symmetry, shape_tip_offset, shape_slope = r18.CORE.candidate_shape(selected_depth)
    else:
        symmetry, shape_tip_offset, shape_slope = 0.0, 1.0, 0.0
    component_columns = sorted(component_rows)
    selected_component_columns = sorted(set(path_columns) & set(component_columns))
    component_coverage = len(selected_component_columns) / max(len(component_columns), 1)
    obstruction_overlap = [int(column) for column in columns if bool(obstruction[int(column)])]
    inherited_hold_overlap = [int(column) for column in columns if bool(predecessor_held[int(column)])]
    evidence_reasons: list[str] = []
    if coverage < MINIMUM_PATH_COVERAGE_FRACTION:
        evidence_reasons.append("INSUFFICIENT_NATIVE_SUPPORT_FRACTION")
    if missing_run > MAXIMUM_UNSUPPORTED_RUN_SAMPLES:
        evidence_reasons.append("MAXIMUM_CONTIGUOUS_UNSUPPORTED_RUN_EXCEEDED")
    elif missing_run > 0:
        evidence_reasons.append("UNSUPPORTED_GAP_RETAINED_AS_HOLD")
    if component_coverage < MINIMUM_PATH_COVERAGE_FRACTION:
        evidence_reasons.append("INSUFFICIENT_DISCOVERED_COMPONENT_COVERAGE")
    if maximum_adjacent_change > MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE + 1.0e-6:
        evidence_reasons.append("LOCAL_NATIVE_CONNECTIVITY_LIMIT_EXCEEDED")
    if inward_limit_count:
        evidence_reasons.append("TRACE_TOUCHES_INWARD_SEARCH_LIMIT")
    if not bool(np.all(selected_raw >= float(r18.MINIMUM_RAW_POLARITY))):
        evidence_reasons.append("DIRECT_UNBLURRED_NATIVE_POLARITY_WITNESS_FAILED")
    if obstruction_overlap:
        evidence_reasons.append("EXTERIOR_OBSTRUCTION_OWNERSHIP_OVERLAP")
    if inherited_hold_overlap:
        evidence_reasons.append("INHERITED_PREDECESSOR_HOLD_OVERLAP")
    morphology_reasons: list[str] = []
    if not (
        float(params.manufactured_minimum_width_degrees)
        <= path_width_degrees
        <= float(params.manufactured_maximum_width_degrees)
    ):
        morphology_reasons.append("TRACED_SHOULDER_WIDTH_OUTSIDE_MANUFACTURED_RANGE")
    if apex_count != 1:
        morphology_reasons.append("NOT_EXACTLY_ONE_NATIVE_APEX")
    if apex_offset_fraction > float(params.manufactured_maximum_tip_offset_fraction):
        morphology_reasons.append("APEX_OFFSET_EXCEEDS_FROZEN_LIMIT")
    if left_monotonic < float(params.manufactured_minimum_slope_consistency):
        morphology_reasons.append("LEFT_SIDE_NOT_MONOTONICALLY_INWARD")
    if right_monotonic < float(params.manufactured_minimum_slope_consistency):
        morphology_reasons.append("RIGHT_SIDE_NOT_MONOTONICALLY_OUTWARD")
    if float(symmetry) < float(params.manufactured_minimum_symmetry):
        morphology_reasons.append("POST_CONTOUR_SYMMETRY_BELOW_FROZEN_LIMIT")
    second_p90 = float(np.percentile(np.abs(second_difference), 90.0)) if second_difference.size else 0.0
    if second_p90 > MAXIMUM_SMOOTH_SECOND_DIFFERENCE_P90_PX:
        morphology_reasons.append("JAGGED_SECOND_DIFFERENCE")
    if extra_reversal_fraction > MAXIMUM_EXTRA_CURVATURE_REVERSAL_FRACTION:
        morphology_reasons.append("EXCESS_CURVATURE_REVERSALS")
    if parallel_band_columns:
        morphology_reasons.append("PARALLEL_NATIVE_BAND_BRANCH")
    if parallel_band_switch_count:
        morphology_reasons.append("REPRESENTATIVE_NATIVE_RADIAL_BAND_JUMP")
    if left_return_residual > MAXIMUM_RETURN_RESIDUAL_FROM_NORMAL_TRACE_PX:
        morphology_reasons.append("LEFT_SHOULDER_DOES_NOT_RETURN_TO_NORMAL_TRACE_DEPTH")
    if right_return_residual > MAXIMUM_RETURN_RESIDUAL_FROM_NORMAL_TRACE_PX:
        morphology_reasons.append("RIGHT_SHOULDER_DOES_NOT_RETURN_TO_NORMAL_TRACE_DEPTH")

    manufactured = not evidence_reasons and not morphology_reasons
    classification = (
        "UNRESOLVED_DEEP_EDGE_RESPONSE"
        if evidence_reasons
        else "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE"
        if manufactured
        else "NON_NOTCH_DEEP_EDGE_RESPONSE"
    )
    record = {
        **base,
        "state": (
            "HOLD_UNRESOLVED_NATIVE_CANDIDATE_CONTOUR"
            if evidence_reasons
            else "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE_AFTER_NATIVE_CONTOUR"
            if manufactured
            else "NON_NOTCH_DEEP_EDGE_RESPONSE"
        ),
        "classification": classification,
        "classificationReasons": evidence_reasons + morphology_reasons,
        "evidenceHoldReasons": evidence_reasons,
        "postContourMorphologyReasons": morphology_reasons,
        "manufacturedCompatibleAfterContour": manufactured,
        "pairingEligible": manufactured and not inherited_hold_overlap and not obstruction_overlap,
        "completeNativeShoulderPath": missing_run == 0,
        "shoulderEndpointsConnectedByNativeGraph": True,
        "expectedSpanColumnCount": int(columns.size),
        "supportMetricPopulation": "TRACED_NATIVE_SHOULDER_SPAN_NO_FILL",
        "supportMetricSpanColumnIndices": [int(value) for value in columns],
        "tracedShoulderColumnIndices": [int(value) for value in columns],
        "representativePathObservedCount": len(sequence),
        "rawSupportedColumnCount": int(np.count_nonzero(span_observed)),
        "rawSupportedFraction": coverage,
        "maximumContiguousUnsupportedRun": missing_run,
        "unsupportedColumnIndices": [int(columns[value]) for value in np.flatnonzero(~span_observed)],
        "discoveredComponentNativeColumnCount": len(component_columns),
        "representativePathComponentColumnCount": len(selected_component_columns),
        "discoveredComponentCoverageFraction": float(component_coverage),
        "obstructionOverlapColumnIndices": obstruction_overlap,
        "obstructionOverlapColumnCount": len(obstruction_overlap),
        "inheritedPredecessorHoldOverlapColumnIndices": inherited_hold_overlap,
        "inheritedPredecessorHoldOverlapColumnCount": len(inherited_hold_overlap),
        "leftShoulderDepthFromFixedOuterCirclePx": left_depth,
        "rightShoulderDepthFromFixedOuterCirclePx": right_depth,
        "leftNormalBrightnessTraceDepthFromFixedOuterCirclePx": left_normal_depth,
        "rightNormalBrightnessTraceDepthFromFixedOuterCirclePx": right_normal_depth,
        "leftShoulderReturnResidualFromNormalTracePx": left_return_residual,
        "rightShoulderReturnResidualFromNormalTracePx": right_return_residual,
        "centerAngleDegrees": center_degrees,
        "startAngleDegrees": float(int(left_anchor["column"]) * degrees_per_sample),
        "endAngleDegrees": float(int(right_anchor["column"]) * degrees_per_sample),
        "widthDegrees": path_width_degrees,
        "ownershipIntervalBasis": "ACTUAL_TRACED_NATIVE_SHOULDER_ENDPOINTS",
        "shoulderSpanWidthDegrees": path_width_degrees,
        "maximumInwardDepthPx": float(np.max(selected_depth)),
        "medianInwardDepthPx": float(np.median(selected_depth)),
        "apexCount": apex_count,
        "apexBandMinimumDepthPx": float(apex_level),
        "apexPopulation": "UNSMOOTHED_REPRESENTATIVE_PATH_DEPTH_WITHIN_MAX_3PX_OR_8_PERCENT_RANGE",
        "apexOffsetFraction": float(apex_offset_fraction),
        "postContourShapeTipOffsetFraction": float(shape_tip_offset),
        "leftMonotonicSupportFraction": left_monotonic,
        "rightMonotonicSupportFraction": right_monotonic,
        "postContourShapeSlopeConsistencyFraction": float(shape_slope),
        "postContourSymmetryScore": float(symmetry),
        "maximumAdjacentRadialChangePxPerSample": maximum_adjacent_change,
        "firstDifferenceAbsoluteMedianPx": float(np.median(np.abs(first_difference))) if first_difference.size else 0.0,
        "firstDifferenceAbsoluteP90Px": float(np.percentile(np.abs(first_difference), 90.0)) if first_difference.size else 0.0,
        "secondDifferenceAbsoluteMedianPx": float(np.median(np.abs(second_difference))) if second_difference.size else 0.0,
        "secondDifferenceAbsoluteP90Px": second_p90,
        "secondDifferenceAbsoluteMaximumPx": float(np.max(np.abs(second_difference))) if second_difference.size else 0.0,
        "slopeDirectionReversalCount": slope_direction_reversals,
        "curvatureReversalCount": curvature_reversals,
        "curvatureReversalPopulation": "SIGN_CHANGES_OF_SIGNIFICANT_UNSMOOTHED_SECOND_DIFFERENCES",
        "extraCurvatureReversalFraction": float(extra_reversal_fraction),
        "supportGraphNodeCount": len(support_points),
        "supportGraphBranchColumnCount": int(sum(len(rows) > 1 for rows in complete_nodes)),
        "parallelBandColumnCount": parallel_band_columns,
        "maximumCompleteBandCountPerColumn": maximum_complete_band_count,
        "representativeParallelBandSwitchCount": parallel_band_switch_count,
        "reachableShoulderPathCountSaturated": int(endpoint["pathCount"]),
        "reachableShoulderPathCountSaturationValue": PATH_COUNT_SATURATION,
        "selectedTransitionWitness": {
            "population": "DIRECT_UNBLURRED_RAW_WITNESSES_ON_BRIGHTNESS_RANKED_NATIVE_SHOULDER_PATH",
            "count": int(selected_raw.size),
            "rawOutsideInMinimum": float(np.min(selected_raw)),
            "rawOutsideInP10": float(np.percentile(selected_raw, 10.0)),
            "rawOutsideInMedian": float(np.median(selected_raw)),
            "enhancedOutsideInMinimum": float(np.min(selected_enhanced)),
            "enhancedOutsideInP10": float(np.percentile(selected_enhanced, 10.0)),
            "enhancedOutsideInMedian": float(np.median(selected_enhanced)),
        },
        "gradientNormalAlignmentPostContourMeasurement": {
            "state": "NOT_REQUIRED_FOR_R24_NATIVE_RAW_POLARITY_CONTOUR",
            "selectionRole": False,
        },
        "allSelectedPixelsNativeSupported": True,
        "allSelectedPixelsRawPolaritySupported": bool(
            np.all(selected_raw >= float(r18.MINIMUM_RAW_POLARITY))
        ),
        "inwardLimitTouchCount": inward_limit_count,
        "representativePath": [
            {
                "column": int(column),
                "radialRow": int(row),
                "offsetPx": float(search_offsets[row]),
                "directUnblurredRawOutsideInContrast": float(transition["directRawContrast"][row, column]),
                "proposalSmoothedRawOutsideInContrast": float(transition["rawContrast"][row, column]),
                "enhancedOutsideInContrast": float(transition["enhancedContrast"][row, column]),
            }
            for column, row in zip(path_columns, path_rows)
        ],
        "completeSupportGraphNativeNodes": [
            {
                "column": int(column),
                "radialRow": int(row),
                "offsetPx": float(search_offsets[row]),
                "directUnblurredRawOutsideInContrast": float(transition["directRawContrast"][row, column]),
                "proposalSmoothedRawOutsideInContrast": float(transition["rawContrast"][row, column]),
                "enhancedOutsideInContrast": float(transition["enhancedContrast"][row, column]),
            }
            for column, row in support_points
        ],
        "metricAvailability": {
            "nativeSupport": "MEASURED_TRACED_NATIVE_SHOULDER_SPAN_NO_FILL",
            "fullInwardDepth": "MEASURED_BRIGHTNESS_RANKED_NATIVE_SHOULDER_PATH",
            "leftReturnResidual": "MEASURED_NATIVE_SHOULDER_TO_SAME_FIXED_OUTER_CIRCLE",
            "rightReturnResidual": "MEASURED_NATIVE_SHOULDER_TO_SAME_FIXED_OUTER_CIRCLE",
            "apexAndOffset": "MEASURED_BRIGHTNESS_RANKED_NATIVE_SHOULDER_PATH",
            "monotonicSides": "MEASURED_BRIGHTNESS_RANKED_NATIVE_SHOULDER_PATH",
            "smoothnessJaggednessCurvature": "MEASURED_UNSMOOTHED_BRIGHTNESS_RANKED_NATIVE_PATH",
            "branchAndParallelBands": "MEASURED_COMPLETE_NATIVE_SUPPORT_GRAPH",
            "representativeParallelBandSwitches": "MEASURED_BRIGHTNESS_RANKED_NATIVE_SHOULDER_PATH",
        },
    }
    return {
        "record": record,
        "path": path,
        "observed": observed,
        "supportPoints": support_points,
        "span": columns,
    }


def direct_native_raw_contrast(
    strip: np.ndarray,
    offsets: np.ndarray,
    search_offsets: np.ndarray,
) -> np.ndarray:
    """Witness each proposed coordinate against unblurred channel pixels."""
    rows = np.rint(search_offsets.astype(np.float64) - float(offsets[0])).astype(np.int64)
    need(
        bool(np.all(rows - (r18.RADIAL_INSIDE_SAMPLES - 1) >= 0))
        and bool(np.all(rows + r18.RADIAL_OUTSIDE_SAMPLES < strip.shape[0])),
        "Direct raw witness lacks its radial halo",
    )
    inside = sum(
        strip[rows - step].astype(np.float32)
        for step in range(r18.RADIAL_INSIDE_SAMPLES)
    ) / float(r18.RADIAL_INSIDE_SAMPLES)
    outside = sum(
        strip[rows + step].astype(np.float32)
        for step in range(1, r18.RADIAL_OUTSIDE_SAMPLES + 1)
    ) / float(r18.RADIAL_OUTSIDE_SAMPLES)
    return inside - outside


def shortest_circular_envelope(columns: Iterable[int], width: int) -> np.ndarray:
    values = np.asarray(sorted(set(int(value) % width for value in columns)), dtype=np.int64)
    need(values.size > 0, "Cannot form an envelope for an empty native component")
    if values.size == 1:
        return values.copy()
    gaps = (np.roll(values, -1) - values) % width
    cut = int(np.argmax(gaps))
    start = int(values[(cut + 1) % values.size])
    end = int(values[cut])
    count = (end - start) % width + 1
    return (start + np.arange(count, dtype=np.int64)) % width


def discover_raw_candidate_components(
    transition: dict[str, Any],
    obstruction: np.ndarray,
    outer_path: np.ndarray,
    cfg: dict[str, Any],
) -> dict[str, Any]:
    """Find every localized deep component in the full native 2-D support map."""
    support = np.asarray(transition["nativeSupported"], dtype=bool)
    search_offsets = np.asarray(transition["searchOffsets"], dtype=np.float32)
    width = int(outer_path.size)
    need(support.shape == (search_offsets.size, width), "Native support-map geometry differs")
    unobstructed = ~np.asarray(obstruction, dtype=bool)

    # Threshold calibration uses the shallowest native-supported exterior
    # witness at each angle, but candidate enumeration below uses every 2-D
    # native-supported band.  A shallower parallel band therefore cannot hide
    # a deeper component.
    shallow_path, shallow_observed = r18.outermost_frontier(
        support, search_offsets
    )
    valid = shallow_observed & unobstructed
    shallow_depth = np.zeros(width, dtype=np.float64)
    shallow_depth[valid] = np.maximum(
        0.0,
        outer_path[valid].astype(np.float64) - shallow_path[valid].astype(np.float64),
    )
    population = shallow_depth[valid]
    need(population.size > 0, "Raw native candidate depth population is empty")
    ceiling = float(np.percentile(population, 80.0))
    baseline = population[population <= ceiling]
    need(baseline.size > 0, "Raw native candidate baseline population is empty")
    center = float(np.median(baseline))
    noise = float(1.4826 * np.median(np.abs(baseline - center)))
    threshold = max(
        float(cfg["minimumNotchDepthPx"]),
        center + float(cfg["noiseSigmaThreshold"]) * noise,
    )
    floor = max(MINIMUM_RAW_CANDIDATE_FLOOR_PX, center + 2.0 * noise)
    node_depth = outer_path[None, :].astype(np.float32) - search_offsets[:, None]
    # Build the population from the complete 2-D native-supported map.  Never
    # discard a radial row merely because unrelated angles support that same
    # depth.  A strict threshold keeps the ordinary exactly-20-pixel bevel
    # from becoming one artificial full-perimeter indentation when the frozen
    # minimum-notch threshold is exactly 20 pixels.
    candidate_support = (
        support
        & (node_depth > floor + 1.0e-6)
    )

    parent: list[int] = []
    bands_by_column: list[list[dict[str, Any]]] = [[] for _ in range(width)]

    def add_node() -> int:
        value = len(parent)
        parent.append(value)
        return value

    def find(value: int) -> int:
        while parent[value] != value:
            parent[value] = parent[parent[value]]
            value = parent[value]
        return value

    def union(left: int, right: int) -> None:
        left_root = find(left)
        right_root = find(right)
        if left_root != right_root:
            parent[right_root] = left_root

    for column in range(width):
        rows = np.flatnonzero(candidate_support[:, column])
        if rows.size == 0:
            continue
        breaks = np.flatnonzero(np.diff(rows) > 1) + 1
        for band_index, band in enumerate(part for part in np.split(rows, breaks) if part.size):
            bands_by_column[column].append(
                {
                    "id": add_node(),
                    "column": column,
                    "bandIndex": band_index,
                    "minimumRow": int(band[0]),
                    "maximumRow": int(band[-1]),
                    "rows": [int(value) for value in band],
                    "coreRows": [
                        int(value) for value in band
                        if float(node_depth[int(value), column]) > threshold + 1.0e-6
                    ],
                }
            )

    def band_distance(left: dict[str, Any], right: dict[str, Any]) -> int:
        if left["maximumRow"] < right["minimumRow"]:
            return int(right["minimumRow"] - left["maximumRow"])
        if right["maximumRow"] < left["minimumRow"]:
            return int(left["minimumRow"] - right["maximumRow"])
        return 0

    for column in range(width):
        for delta in (1, 2):
            target = (column + delta) % width
            if delta == 2 and bands_by_column[(column + 1) % width]:
                continue
            for left in bands_by_column[column]:
                for right in bands_by_column[target]:
                    if band_distance(left, right) <= MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE * delta:
                        union(int(left["id"]), int(right["id"]))

    grouped: dict[int, list[dict[str, Any]]] = {}
    for column_bands in bands_by_column:
        for band in column_bands:
            grouped.setdefault(find(int(band["id"])), []).append(band)
    components: list[dict[str, Any]] = []
    global_background_count = 0
    for bands in grouped.values():
        if not any(band["coreRows"] for band in bands):
            continue
        envelope = shortest_circular_envelope(
            (int(band["column"]) for band in bands), width
        )
        broad = bool(envelope.size > width // 2)
        if broad:
            global_background_count += 1
        component_rows: dict[int, list[int]] = {}
        core_rows: dict[int, list[int]] = {}
        for band in bands:
            column = int(band["column"])
            component_rows.setdefault(column, []).extend(int(value) for value in band["rows"])
            if band["coreRows"]:
                core_rows.setdefault(column, []).extend(int(value) for value in band["coreRows"])
        for mapping in (component_rows, core_rows):
            for column in mapping:
                mapping[column] = sorted(set(mapping[column]))
        components.append(
            {
                "component": envelope,
                "componentRows": component_rows,
                "coreRows": core_rows,
                "nativeSupportColumnCount": len(component_rows),
                "nativeBandNodeCount": len(bands),
                "broadHalfPerimeterResponse": broad,
                "obstructionOverlapColumnIndices": sorted(
                    column for column in component_rows if bool(obstruction[column])
                ),
            }
        )
    components.sort(
        key=lambda item: circular_weighted_degrees(
            np.asarray(sorted(item["coreRows"]), dtype=np.int64),
            np.ones(len(item["coreRows"]), dtype=np.float64),
            width,
        )
    )
    return {
        "valid": valid,
        "shallowRawDepth": shallow_depth.astype(np.float32),
        "thresholdPx": threshold,
        "candidateFloorPx": floor,
        "baselineCenterPx": center,
        "baselineNoiseSigmaPx": noise,
        "components": components,
        "nativeCandidateBandCount": len(parent),
        "broadHalfPerimeterResponseCount": global_background_count,
        "candidateDiscoverySource": "EVERY_DEPTH_QUALIFIED_2D_NATIVE_SUPPORTED_BAND_ACROSS_FULL_360",
        "candidateDiscoverySmoothingPerformed": False,
        "candidateDiscoveryMorphologyPerformed": False,
        "candidateDiscoveryGapFillPerformed": False,
    }


def analyze_native_strip(
    strip: np.ndarray,
    offsets: np.ndarray,
    base_fit: dict[str, Any],
    params: Any,
    cfg: dict[str, Any],
    predecessor_measured: np.ndarray,
    channel: str,
) -> dict[str, Any]:
    """Preserve R18 fixed circles, replacing only its pre-contour selector."""
    need(strip.dtype == np.uint8 and strip.ndim == 2, "R24 strip must be uint8 grayscale")
    need(offsets.ndim == 1 and offsets.size == strip.shape[0], "R24 strip/offset geometry differs")
    need(predecessor_measured.shape == (strip.shape[1],), "R24 predecessor hold width differs")

    exterior = r18.exterior_connected_map(strip, offsets)
    circle_candidates = r18.outer_circle_candidates(exterior)
    circle = r18.fit_guarded_outer_circle(circle_candidates, base_fit)
    raw_witness = r18.raw_exterior_witness(exterior, circle["outerPath"])
    band_seed = circle["fit"]["outerBandSeedOffsetPx"]
    search_headroom = (
        None
        if band_seed is None
        else float(r18.EXTERIOR_SEARCH_MAX_OFFSET_PX - float(band_seed))
    )
    unsupported_runs = r18.CORE.group_circular_true(~circle["finalSupportColumns"])
    maximum_unsupported_samples = max((int(run.size) for run in unsupported_runs), default=0)
    cyan_verified = bool(
        circle["qualified"]
        and search_headroom is not None
        and search_headroom >= r18.MINIMUM_CYAN_SEARCH_HEADROOM_PX
        and float(circle["fit"]["angularCoverageFraction"])
        >= r18.MINIMUM_CYAN_ACCEPTED_COVERAGE
    )
    inner_circle = {
        "centerX": circle["fit"]["centerX"],
        "centerY": circle["fit"]["centerY"],
        "radius": circle["fit"]["radius"] - r18.EDGE_ZONE_INWARD_PX,
        "angleSampleCount": strip.shape[1],
    }
    need(inner_circle["radius"] > 0.0, "R24 inner circle radius is non-positive")
    inner_path = r18.circle_ray_offsets(base_fit, inner_circle)
    spacing_error = float(
        np.max(np.abs((circle["outerPath"] - inner_path) - r18.EDGE_ZONE_INWARD_PX))
    )
    need(spacing_error <= 1.0e-4, "R24 yellow circle is not exactly 20 px inward")

    exterior_frontier, exterior_observed = r18.outermost_frontier(
        exterior["supported"], exterior["searchOffsets"]
    )
    outward = np.zeros(strip.shape[1], dtype=np.float32)
    outward[exterior_observed] = (
        exterior_frontier[exterior_observed] - circle["outerPath"][exterior_observed]
    )
    obstruction = exterior_observed & (outward > r18.HOLDER_OUTWARD_RESIDUAL_PX)
    transition = r18.transition_map(strip, offsets)
    transition["directRawContrast"] = direct_native_raw_contrast(
        strip, offsets, transition["searchOffsets"]
    )
    transition["nativeSupported"] = np.asarray(
        transition["frontierSupported"], dtype=bool
    ) & (
        transition["directRawContrast"] >= float(r18.MINIMUM_RAW_POLARITY)
    )
    edge = r18.measure_pixel_edge_family(transition, circle["outerPath"])
    need(
        edge["normalObservedFraction"] >= r18.MINIMUM_BEVEL_TRACE_COVERAGE,
        "R24 normal brightness trace coverage is below the inherited gate",
    )
    need(
        edge["normalMaximumAdjacentStepPx"] is not None
        and edge["normalMaximumAdjacentStepPx"] <= r18.BEVEL_TRACE_MAX_ADJACENT_STEP_PX,
        "R24 normal brightness trace retains a discontinuity",
    )
    discovery = discover_raw_candidate_components(
        transition,
        obstruction,
        circle["outerPath"],
        cfg,
    )
    candidate_traces = [
        candidate_graph_trace(
            strip,
            offsets,
            circle["outerPath"],
            edge["normalPath"],
            edge["normalObserved"],
            transition,
            item,
            float(discovery["thresholdPx"]),
            params,
            index,
            channel,
            obstruction,
            ~predecessor_measured.astype(bool),
        )
        for index, item in enumerate(discovery["components"])
    ]
    return {
        "strip": strip,
        "offsets": offsets.astype(np.float32),
        "baseFit": {key: float(base_fit[key]) for key in ("centerX", "centerY", "radius")},
        "circleState": circle["state"],
        "circleQualified": bool(circle["qualified"]),
        "circleFit": circle["fit"],
        "cyanGeometryVerified": cyan_verified,
        "cyanGeometryVerificationState": (
            "PASS_DIAGNOSTIC_CYAN_GEOMETRY_SUPPORT_AND_HEADROOM"
            if cyan_verified
            else "HOLD_CYAN_GEOMETRY_UNVERIFIED"
        ),
        "outerPath": circle["outerPath"],
        "innerPath": inner_path,
        "transitionSearchOffsets": transition["searchOffsets"].astype(np.float32),
        "normalBrightnessPath": edge["normalPath"],
        "normalBrightnessObserved": edge["normalObserved"],
        "deepPath": edge["deepNotchPath"],
        "deepObserved": edge["deepNotchObserved"],
        "deepInwardLimit": edge["deepNotchTouchesInwardLimitColumns"],
        "predecessorHeldColumns": ~predecessor_measured.astype(bool),
        "obstructionColumns": obstruction,
        "candidateTraces": candidate_traces,
        "discovery": discovery,
        "evidence": {
            "algorithm": "R24_CANDIDATE_FIRST_CHANNEL_LOCAL_NATIVE_SUPPORT_GRAPH",
            "fixedOuterCircleSource": "UNCHANGED_R18_EXTERIOR_CONNECTED_CENTER_LOCKED_PHYSICAL_CIRCLE",
            "cyanGeometryChanged": False,
            "yellowInwardPx": float(r18.EDGE_ZONE_INWARD_PX),
            "maximumYellowSpacingErrorPx": spacing_error,
            "cyanSearchHeadroomPx": search_headroom,
            "cyanMaximumUnsupportedRunSamples": maximum_unsupported_samples,
            "rawExteriorWitnessObservedFraction": raw_witness["observedFraction"],
            "normalBrightnessTraceObservedFraction": edge["normalObservedFraction"],
            "candidateCount": len(candidate_traces),
            "candidateDiscoveryPopulation": "EVERY_FULL_360_UNSMOOTHED_RAW_DEPTH_COMPONENT_CONTAINING_A_THRESHOLD_CORE",
            "candidateDiscoverySmoothingPerformed": False,
            "candidateDiscoveryMorphologyPerformed": False,
            "candidateDiscoveryGapFillPerformed": False,
            "candidateContouringCompletedBeforeNotchSelection": True,
            "templateOrIdealCurveUsed": False,
            "interpolationPerformed": False,
            "pathCenteredWarpPerformed": False,
            "dynamicRecenteringPerformed": False,
            "crossChannelPixelCoordinateTransferPerformed": False,
            "predecessorHeldColumnCount": int(np.count_nonzero(~predecessor_measured)),
            "predecessorHoldsCleared": False,
        },
    }


def draw_native_points(
    image: np.ndarray,
    mask: np.ndarray,
    path: np.ndarray,
    observed: np.ndarray,
    offsets: np.ndarray,
    color: tuple[int, int, int],
) -> None:
    columns = np.flatnonzero(np.asarray(observed, dtype=bool) & np.isfinite(path))
    rows = np.rint(path[columns].astype(np.float64) - float(offsets[0])).astype(np.int64)
    valid = (rows >= 0) & (rows < image.shape[0])
    image[rows[valid], columns[valid]] = color
    mask[rows[valid], columns[valid]] = 255


def draw_support_points(
    image: np.ndarray,
    mask: np.ndarray,
    points: list[tuple[int, int]],
    search_offsets: np.ndarray,
    strip_offsets: np.ndarray,
    color: tuple[int, int, int],
) -> None:
    if not points:
        return
    columns = np.asarray([item[0] for item in points], dtype=np.int64)
    search_rows = np.asarray([item[1] for item in points], dtype=np.int64)
    rows = np.rint(search_offsets[search_rows] - float(strip_offsets[0])).astype(np.int64)
    valid = (rows >= 0) & (rows < image.shape[0]) & (columns >= 0) & (columns < image.shape[1])
    image[rows[valid], columns[valid]] = color
    mask[rows[valid], columns[valid]] = 255


def labeled_native_crop(image: np.ndarray, label: str) -> np.ndarray:
    result = cv2.copyMakeBorder(image, CANDIDATE_REVIEW_HEADER_PX, 0, 0, 0, cv2.BORDER_CONSTANT)
    cv2.putText(
        result,
        label,
        (7, 22),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.38,
        WHITE,
        1,
        cv2.LINE_8,
    )
    return result


def render_channel(
    root: Path,
    identity: str,
    channel: str,
    analysis: dict[str, Any],
    locked_clean_record: dict[str, Any] | None = None,
) -> dict[str, Any]:
    strip = analysis["strip"]
    offsets = analysis["offsets"]
    base = cv2.cvtColor(r18.shadow_lift(strip), cv2.COLOR_GRAY2BGR)
    geometry = base.copy()
    geometry_mask = np.zeros(strip.shape, dtype=np.uint8)
    r18.draw_circle_path(geometry, geometry_mask, analysis["outerPath"], offsets, CYAN)
    r18.draw_circle_path(geometry, geometry_mask, analysis["innerPath"], offsets, YELLOW)

    brightness = geometry.copy()
    normal_mask = np.zeros(strip.shape, dtype=np.uint8)
    draw_native_points(
        brightness,
        normal_mask,
        analysis["normalBrightnessPath"],
        analysis["normalBrightnessObserved"],
        offsets,
        LIME,
    )
    representative_mask = np.zeros(strip.shape, dtype=np.uint8)
    support_mask = np.zeros(strip.shape, dtype=np.uint8)
    for candidate in analysis["candidateTraces"]:
        draw_support_points(
            brightness,
            support_mask,
            candidate["supportPoints"],
            analysis["transitionSearchOffsets"],
            offsets,
            ORANGE,
        )
        draw_native_points(
            brightness,
            representative_mask,
            candidate["path"],
            candidate["observed"],
            offsets,
            LIME,
        )
    hold_mask = np.zeros(strip.shape, dtype=np.uint8)
    held = np.asarray(analysis["predecessorHeldColumns"], dtype=bool)
    if bool(np.any(held)):
        brightness[:HOLD_BAR_ROWS, held] = MAGENTA
        hold_mask[:HOLD_BAR_ROWS, held] = 255
    obstruction_mask = np.zeros(strip.shape, dtype=np.uint8)
    obstruction = np.asarray(analysis["obstructionColumns"], dtype=bool)
    if bool(np.any(obstruction)):
        brightness[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, obstruction] = OBSTRUCTION_BLUE
        obstruction_mask[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, obstruction] = 255

    changed = np.any(brightness != base, axis=2)
    declared = (
        (geometry_mask > 0)
        | (normal_mask > 0)
        | (representative_mask > 0)
        | (support_mask > 0)
        | (hold_mask > 0)
        | (obstruction_mask > 0)
    )
    need(bool(np.all(~changed | declared)), "R24 full overlay changed pixels outside declared masks")
    need(int(np.count_nonzero(normal_mask)) > 0, "R24 normal brightness trace rendered empty")
    stem = safe_stem(identity) + "_" + channel.lower()
    assets: dict[str, Any] = {
        "fullClean": (
            locked_clean_record
            if locked_clean_record is not None
            else write_png_new(root / f"{stem}_full_clean.png", strip)
        ),
        "fullEnhancedClean": write_png_new(root / f"{stem}_full_enhanced_clean.png", r18.shadow_lift(strip)),
        "circleAndBrightnessReview": write_png_new(root / f"{stem}_circle_brightness_review.png", brightness),
        "fixedCircleGeometryMask": write_png_new(root / f"{stem}_fixed_circle_geometry_mask.png", geometry_mask),
        "nativeBrightnessTraceMask": write_png_new(root / f"{stem}_native_brightness_trace_mask.png", normal_mask),
        "candidateRepresentativeTraceMask": write_png_new(root / f"{stem}_candidate_trace_mask.png", representative_mask),
        "candidateSupportGraphMask": write_png_new(root / f"{stem}_candidate_support_graph_mask.png", support_mask),
        "predecessorHoldMask": write_png_new(root / f"{stem}_predecessor_hold_mask.png", hold_mask),
        "obstructionHoldMask": write_png_new(root / f"{stem}_obstruction_hold_mask.png", obstruction_mask),
        "renderSemantics": {
            "normalBrightnessPixelCount": int(np.count_nonzero(normal_mask)),
            "candidateRepresentativePixelCount": int(np.count_nonzero(representative_mask)),
            "candidateSupportGraphPixelCount": int(np.count_nonzero(support_mask)),
            "predecessorHoldPixelCount": int(np.count_nonzero(hold_mask)),
            "obstructionHoldPixelCount": int(np.count_nonzero(obstruction_mask)),
            "allChangedPixelsInsideDeclaredMasks": True,
        },
        "candidateReviews": [],
    }
    width = strip.shape[1]
    for candidate in analysis["candidateTraces"]:
        record = candidate["record"]
        span = np.asarray(candidate["span"], dtype=np.int64)
        need(span.size > 0, f"{record['candidateId']} has an empty review span")
        padding = min(32, max(0, (width - int(span.size)) // 2))
        review_count = min(width, max(2 * CANDIDATE_REVIEW_HALF_WIDTH_COLUMNS + 1, int(span.size) + 2 * padding))
        review_start = (int(span[0]) - padding) % width
        columns = (review_start + np.arange(review_count, dtype=np.int64)) % width
        clean_crop = strip[:, columns].copy()
        candidate_canvas = geometry.copy()
        context_mask = np.zeros(strip.shape, dtype=np.uint8)
        candidate_trace_mask = np.zeros(strip.shape, dtype=np.uint8)
        candidate_support_mask = np.zeros(strip.shape, dtype=np.uint8)
        candidate_hold_mask = np.zeros(strip.shape, dtype=np.uint8)
        candidate_obstruction_mask = np.zeros(strip.shape, dtype=np.uint8)
        draw_native_points(
            candidate_canvas,
            context_mask,
            analysis["normalBrightnessPath"],
            analysis["normalBrightnessObserved"],
            offsets,
            LIME,
        )
        draw_support_points(
            candidate_canvas,
            candidate_support_mask,
            candidate["supportPoints"],
            analysis["transitionSearchOffsets"],
            offsets,
            ORANGE,
        )
        draw_native_points(
            candidate_canvas,
            candidate_trace_mask,
            candidate["path"],
            candidate["observed"],
            offsets,
            LIME,
        )
        candidate_scope = np.zeros(width, dtype=bool)
        candidate_scope[span] = True
        scoped_hold = held & candidate_scope
        scoped_obstruction = obstruction & candidate_scope
        if bool(np.any(scoped_hold)):
            candidate_canvas[:HOLD_BAR_ROWS, scoped_hold] = MAGENTA
            candidate_hold_mask[:HOLD_BAR_ROWS, scoped_hold] = 255
        if bool(np.any(scoped_obstruction)):
            candidate_canvas[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, scoped_obstruction] = OBSTRUCTION_BLUE
            candidate_obstruction_mask[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, scoped_obstruction] = 255
        candidate_changed = np.any(candidate_canvas != base, axis=2)
        candidate_declared = (
            (geometry_mask > 0)
            | (context_mask > 0)
            | (candidate_trace_mask > 0)
            | (candidate_support_mask > 0)
            | (candidate_hold_mask > 0)
            | (candidate_obstruction_mask > 0)
        )
        need(bool(np.all(~candidate_changed | candidate_declared)), f"{record['candidateId']} changed pixels outside its masks")
        review_crop = candidate_canvas[:, columns].copy()
        context_crop = context_mask[:, columns].copy()
        trace_crop = candidate_trace_mask[:, columns].copy()
        support_crop = candidate_support_mask[:, columns].copy()
        hold_crop = candidate_hold_mask[:, columns].copy()
        obstruction_crop = candidate_obstruction_mask[:, columns].copy()
        expected_trace_pixels = int(np.count_nonzero(candidate["observed"]))
        expected_support_pixels = len(set(candidate["supportPoints"]))
        need(
            not record["rawComponentNativeNodes"] or expected_support_pixels > 0,
            f"{record['candidateId']} has native component evidence but no rendered candidate graph",
        )
        need(int(np.count_nonzero(trace_crop)) == expected_trace_pixels, f"{record['candidateId']} local trace mask count differs")
        need(int(np.count_nonzero(support_crop)) == expected_support_pixels, f"{record['candidateId']} local support mask count differs")
        label = (
            f"{identity} {channel} {record['candidateId']} {record['classification']} | "
            "CYAN fixed outer | YELLOW fixed -20px | LIME native brightness | "
            "ORANGE candidate graph | MAGENTA inherited hold | BLUE obstruction hold"
        )
        candidate_stem = f"{stem}_{record['candidateId'].lower()}"
        candidate_record_path = root / f"{candidate_stem}_trace.json"
        trace_payload = {
            "schema": TRACE_SCHEMA,
            "identity": identity,
            "channel": channel,
            "angleSampleCount": width,
            "degreesPerSample": 360.0 / width,
            "radialOffsets": numeric_path(offsets),
            "outerCirclePath": numeric_path(analysis["outerPath"]),
            "innerCirclePath": numeric_path(analysis["innerPath"]),
            "normalBrightnessTracePath": numeric_path(analysis["normalBrightnessPath"]),
            "normalBrightnessObservedIndices": index_list(analysis["normalBrightnessObserved"]),
            "candidate": record,
            "representativePath": numeric_path(candidate["path"]),
            "representativeObservedIndices": index_list(candidate["observed"]),
            "predecessorHeldIndices": index_list(analysis["predecessorHeldColumns"]),
            "obstructionIndices": index_list(analysis["obstructionColumns"]),
            "nativeCoordinatesOnly": True,
            "interpolationPerformed": False,
            "templateOrIdealCurveUsed": False,
            "crossChannelPixelCoordinateTransferPerformed": False,
        }
        trace_asset = write_json_new(candidate_record_path, trace_payload)
        candidate_assets = {
            "candidateId": record["candidateId"],
            "centerAngleDegrees": record.get("centerAngleDegrees"),
            "clean": write_png_new(root / f"{candidate_stem}_clean.png", clean_crop),
            "review": write_png_new(root / f"{candidate_stem}_review.png", labeled_native_crop(review_crop, label)),
            "normalTraceContextMask": write_png_new(root / f"{candidate_stem}_normal_context_mask.png", context_crop),
            "nativeTraceMask": write_png_new(root / f"{candidate_stem}_native_trace_mask.png", trace_crop),
            "supportGraphMask": write_png_new(root / f"{candidate_stem}_support_graph_mask.png", support_crop),
            "inheritedHoldMask": write_png_new(root / f"{candidate_stem}_inherited_hold_mask.png", hold_crop),
            "obstructionHoldMask": write_png_new(root / f"{candidate_stem}_obstruction_hold_mask.png", obstruction_crop),
            "renderSemantics": {
                "expectedRepresentativeNativePixelCount": expected_trace_pixels,
                "renderedRepresentativeNativePixelCount": int(np.count_nonzero(trace_crop)),
                "expectedCandidateGraphPixelCount": expected_support_pixels,
                "renderedCandidateGraphPixelCount": int(np.count_nonzero(support_crop)),
                "normalContextPixelCount": int(np.count_nonzero(context_crop)),
                "allChangedPixelsInsideDeclaredMasks": True,
                "candidateLocalOnly": True,
            },
            "trace": trace_asset,
            "sourceColumnStart": int(columns[0]),
            "sourceColumnEnd": int(columns[-1]),
            "cyclicWrapUsed": bool(columns[0] > columns[-1]),
            "sourceColumnCount": int(columns.size),
            "resamplingPerformed": False,
            "pathCenteredWarpPerformed": False,
        }
        assets["candidateReviews"].append(candidate_assets)
    return assets


def public_candidate_records(analysis: dict[str, Any]) -> list[dict[str, Any]]:
    return [candidate["record"] for candidate in analysis["candidateTraces"]]


def iter_hash_records(value: Any, pointer: str = "$") -> Iterable[tuple[str, dict[str, Any]]]:
    if isinstance(value, dict):
        path = value.get("path")
        digest = value.get("sha256")
        if isinstance(path, str) and isinstance(digest, str) and re.fullmatch(r"[0-9A-Fa-f]{64}", digest):
            yield pointer, value
        for key, child in value.items():
            yield from iter_hash_records(child, f"{pointer}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from iter_hash_records(child, f"{pointer}[{index}]")


def resolve_manifest_record_path(
    path_text: str,
    pointer: str,
    code_root: Path,
    workspace_io: Path,
) -> Path:
    normalized = path_text.replace("\\", "/")
    if normalized.upper().startswith("R:/"):
        return workspace_io / normalized[3:]
    path = Path(path_text)
    if path.is_absolute():
        return path
    if pointer.startswith("$.post2Inputs.rasters["):
        return workspace_io / normalized
    return code_root / normalized


def verify_rollover_closure(
    manifest_path: Path,
    manifest_sha256: str,
    gate_path: Path,
    gate_sha256: str,
    checkpoint_path: Path,
    checkpoint_sha256: str,
    code_root: Path,
    workspace_io: Path,
) -> dict[str, Any]:
    need(manifest_sha256.upper() == ROLLOVER_MANIFEST_SHA256, "Rollover-manifest pin differs from R24")
    need(gate_sha256.upper() == ROLLOVER_GATE_SHA256, "Rollover-gate pin differs from R24")
    need(checkpoint_sha256.upper() == CHECKPOINT_SHA256, "Checkpoint pin differs from R24")
    require_exact_file(checkpoint_path, checkpoint_sha256, "R24 checkpoint")
    manifest = load_json_pinned(manifest_path, manifest_sha256, "R24 rollover manifest")
    gate = load_json_pinned(gate_path, gate_sha256, "R24 rollover gate")
    need(
        manifest.get("revision")
        == "OCV03_O3F16R23_R24_CANDIDATE_FIRST_ROLLOVER_20260904",
        "Rollover revision differs",
    )
    need(
        gate.get("state") == "PASS_O3F16_R23_R24_FILE_BACKED_ROLLOVER_READY",
        "Rollover gate is not PASS",
    )
    checked: dict[str, dict[str, Any]] = {}
    pointers: dict[str, list[str]] = {}
    for pointer, record in iter_hash_records(manifest):
        path = resolve_manifest_record_path(str(record["path"]), pointer, code_root, workspace_io)
        key = str(path.absolute()).lower()
        expected = str(record["sha256"]).upper()
        size = int(record["bytes"]) if record.get("bytes") is not None else None
        if key in checked:
            need(checked[key]["sha256"] == expected, f"Conflicting manifest hashes for {path}")
            if size is not None and checked[key].get("bytes") is not None:
                need(int(checked[key]["bytes"]) == size, f"Conflicting manifest byte counts for {path}")
            pointers[key].append(pointer)
            continue
        require_exact_file(path, expected, f"rollover dependency {pointer}", size)
        checked[key] = {
            "path": str(path),
            "bytes": path.stat().st_size,
            "sha256": expected,
        }
        pointers[key] = [pointer]
    need(len(checked) == 64, f"Rollover closure count changed: expected 64, got {len(checked)}")
    post2_bmps = [
        row for key, row in checked.items()
        if any(pointer.startswith("$.post2Inputs.rasters[") for pointer in pointers[key])
    ]
    need(len(post2_bmps) == 6, "Rollover closure does not contain exactly six POST2 BMPs")
    need(
        all(Path(row["path"]).drive.upper() == workspace_io.drive.upper() for row in post2_bmps),
        "POST2 BMP closure did not resolve through the frozen workspace alias",
    )
    return {
        "checkpoint": file_record(checkpoint_path, checkpoint_sha256),
        "manifest": file_record(manifest_path, manifest_sha256),
        "gate": file_record(gate_path, gate_sha256),
        "uniquePinnedFileCount": len(checked),
        "post2BmpCount": len(post2_bmps),
        "post2BmpResolution": "R_ALIAS_BOUND_TO_MANIFEST_DESKTOP_AUTHORITY_ROOT",
        "records": sorted(checked.values(), key=lambda row: row["path"].lower()),
    }


def verify_engine_lineage() -> list[dict[str, Any]]:
    require_exact_file(R21_PATH, R21_SHA256, "R21 engine")
    require_exact_file(R22_PATH, R22_SHA256, "R22 engine")
    require_exact_file(R23_PATH, R23_SHA256, "R23 engine")
    require_exact_file(EXTERNAL_R18_PATH, r21.r19.R18_SHA256, "external R18 engine")
    require_exact_file(R18_BASELINE_SUMMARY, R18_BASELINE_SUMMARY_SHA256, "R18 baseline summary")
    require_exact_file(R20_BASELINE_SUMMARY, R20_BASELINE_SUMMARY_SHA256, "R20 baseline summary")
    r21.preflight_lineage()
    runtime = Path(sys.executable)
    require_exact_file(runtime, RUNTIME_SHA256, "pinned Python runtime")
    need(cv2.__version__ == "5.0.0", f"OpenCV version changed: {cv2.__version__}")
    need(np.__version__ == "2.5.2", f"NumPy version changed: {np.__version__}")
    loaded: list[Path] = []
    for module in sys.modules.values():
        source = getattr(module, "__file__", None)
        if not source:
            continue
        path = Path(source)
        if path.suffix.lower() == ".py" and (
            path.parent == HERE or path.parent == EXTERNAL_R18_PATH.parent
        ):
            loaded.append(path)
    records = [file_record(path) for path in sorted(set(loaded), key=lambda item: str(item).lower())]
    need(any(Path(row["path"]).resolve() == EXTERNAL_R18_PATH.resolve() for row in records), "External R18 was not loaded")
    return records


def load_r22_inherited_post2_authority() -> dict[str, Any]:
    r22_summary = load_json_pinned(R22_SUMMARY, R22_SUMMARY_SHA256, "R22 label-free inference summary")
    r22_gate = load_json_pinned(R22_GATE, R22_GATE_SHA256, "R22 label-free inference gate")
    require_exact_file(R23_SUMMARY, R23_SUMMARY_SHA256, "R23 post-freeze held-review summary")
    require_exact_file(R23_GATE, R23_GATE_SHA256, "R23 post-freeze held-review gate")
    need(
        r22_summary.get("state") == "COMPLETE_DIAGNOSTIC_ONLY_R22_POST2_INFERENCE"
        and r22_gate.get("state") == "HOLD_R22_POST2_INFERENCE_CONTRACT_FAILURE"
        and r22_gate.get("checks", {}).get("allNotchOwnershipUnambiguous") is False,
        "R22 inherited hold authority differs",
    )
    need(
        str(r22_gate.get("summary", {}).get("sha256", "")).upper() == R22_SUMMARY_SHA256,
        "R22 gate does not bind the inherited summary",
    )
    by_identity: dict[str, Any] = {}
    ownership_hold_count = 0
    cyan_hold_count = 0
    for result in r22_summary.get("results", []):
        identity = str(result.get("identity"))
        need(identity and identity not in by_identity, "R22 inherited identity is missing or duplicated")
        channels: dict[str, Any] = {}
        for channel in ("BF", "DF"):
            prior = result["channels"][channel]
            ownership = prior["notchOwnership"]
            need(
                ownership.get("state") == "HOLD_NO_UNIQUE_R21_CONTOUR_OWNERSHIP_METRICS"
                and int(ownership.get("notchOwnedColumnCount", -1)) == 0,
                f"{identity} {channel} R22 ownership hold differs",
            )
            ownership_hold_count += 1
            cyan_state = str(prior["cyanGeometryVerificationState"])
            cyan_verified = bool(prior["cyanGeometryVerified"])
            if cyan_state.startswith("HOLD_"):
                cyan_hold_count += 1
            r22_broad_response = None
            if identity.endswith("SLOT17") and channel == "BF":
                broad_rows = [
                    row for row in prior.get("prePairNotchCandidates", [])
                    if float(row.get("widthDegrees", 0.0)) >= 10.0
                    and row.get("startAngleDegrees") is not None
                    and (
                        (89.64 - float(row["startAngleDegrees"]) % 360.0) % 360.0
                        <= float(row["widthDegrees"]) + 1.0e-9
                    )
                ]
                need(len(broad_rows) == 1, "R22 SLOT17 BF broad response authority differs")
                broad = broad_rows[0]
                r22_broad_response = {
                    "sourceSummarySha256": R22_SUMMARY_SHA256,
                    "sourcePopulation": "prePairNotchCandidates",
                    "centerAngleDegrees": float(broad["centerAngleDegrees"]),
                    "startAngleDegrees": float(broad["startAngleDegrees"]),
                    "endAngleDegrees": float(broad["endAngleDegrees"]),
                    "widthDegrees": float(broad["widthDegrees"]),
                }
            channels[channel] = {
                "r22NotchOwnership": ownership,
                "r22CyanGeometryVerificationState": cyan_state,
                "r22CyanGeometryVerified": cyan_verified,
                "r22HoldClearancePerformed": False,
                "r23OverallHeldReviewState": "HOLD_R23_POST2_VISUAL_COMPARISON_NOTCH_OWNERSHIP_UNRESOLVED",
                "r22BroadResponse": r22_broad_response,
            }
        by_identity[identity] = {"channels": channels, "r22PairState": result["pairDiagnostic"]["state"]}
    need(len(by_identity) == 3, "R22 inherited POST2 cardinality differs")
    need(ownership_hold_count == 6 and cyan_hold_count == 5, "R22 inherited hold counts differ")
    return {
        "records": {
            "r22Summary": file_record(R22_SUMMARY, R22_SUMMARY_SHA256),
            "r22Gate": file_record(R22_GATE, R22_GATE_SHA256),
            "r23SummaryHashVerifiedWithoutJsonParse": file_record(R23_SUMMARY, R23_SUMMARY_SHA256),
            "r23GateHashVerifiedWithoutJsonParse": file_record(R23_GATE, R23_GATE_SHA256),
        },
        "byIdentity": by_identity,
        "r22OwnershipHoldCount": ownership_hold_count,
        "r22CyanHoldCount": cyan_hold_count,
        "r23JsonParsedBeforeNeutralFreeze": False,
    }


def resolve_alias_path(workspace_io: Path, value: str) -> Path:
    normalized = value.replace("\\", "/")
    need(normalized.upper().startswith("R:/"), f"Expected frozen R: path: {value}")
    result = workspace_io / normalized[3:]
    try:
        result.absolute().relative_to(workspace_io.absolute())
    except ValueError as exc:
        raise RuntimeError(f"Alias path escapes workspace: {value}") from exc
    return result


def verify_post2_sources(
    workspace_io: Path,
    source_job: dict[str, Any],
) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    members = source_job.get("inputs")
    need(
        isinstance(members, list)
        and len(members) == int(source_job.get("expectedInputCount", -1)) == 3,
        "POST2 source-job cardinality differs",
    )
    identities = [str(member.get("identity")) for member in members]
    need(len(set(identities)) == 3, "POST2 identities are not unique")
    source_rows: list[dict[str, Any]] = []
    seeds: dict[str, dict[str, Any]] = {}
    for member in members:
        identity = str(member["identity"])
        seed_record = member["r6SeedResult"]
        seed_path = resolve_alias_path(workspace_io, str(seed_record["path"]))
        seed = load_json_pinned(seed_path, str(seed_record["sha256"]), f"{identity} R6 seed")
        need(seed.get("identity") == identity and bool(seed.get("reviewOnly")), f"{identity} R6 seed authority differs")
        seeds[identity] = seed
        for channel, key in (("BF", "bf"), ("DF", "df")):
            record = member[key]
            path = resolve_alias_path(workspace_io, str(record["path"]))
            require_exact_file(path, str(record["sha256"]), f"{identity} {channel} source", int(record["bytes"]))
            actual = str(record["sha256"]).upper()
            need(
                str(seed["sources"][f"{key}Sha256"]).upper() == actual,
                f"{identity} {channel} R6/source hash differs",
            )
            source_rows.append(
                {
                    "identity": identity,
                    "channel": channel,
                    "path": str(path),
                    "bytes": path.stat().st_size,
                    "sha256": actual,
                    "seedPath": str(seed_path),
                    "seedSha256": str(seed_record["sha256"]).upper(),
                }
            )
    return source_rows, seeds


def candidate_interval_overlap(left: dict[str, Any], right: dict[str, Any]) -> float:
    left_indices = left.get("tracedShoulderColumnIndices") or left.get("componentColumnIndices") or []
    right_indices = right.get("tracedShoulderColumnIndices") or right.get("componentColumnIndices") or []
    left_samples = int(left.get("angleSampleCount", 0))
    right_samples = int(right.get("angleSampleCount", 0))
    if left_samples > 0 and left_samples == right_samples and left_indices and right_indices:
        left_set = {int(value) % left_samples for value in left_indices}
        right_set = {int(value) % right_samples for value in right_indices}
        return float(len(left_set & right_set) / max(1, min(len(left_set), len(right_set))))

    def segments(candidate: dict[str, Any]) -> list[tuple[float, float]]:
        start = float(candidate["startAngleDegrees"]) % 360.0
        width = min(max(float(candidate["widthDegrees"]), 0.0), 360.0)
        if width >= 360.0:
            return [(0.0, 360.0)]
        end = start + width
        if end <= 360.0:
            return [(start, end)]
        return [(start, 360.0), (0.0, end - 360.0)]

    left_segments = segments(left)
    right_segments = segments(right)
    overlap = sum(
        max(0.0, min(left_end, right_end) - max(left_start, right_start))
        for left_start, left_end in left_segments
        for right_start, right_end in right_segments
    )
    denominator = min(float(left["widthDegrees"]), float(right["widthDegrees"]))
    return 0.0 if denominator <= 0.0 else float(min(1.0, overlap / denominator))


def pair_after_channel_contours(
    bf_candidates: list[dict[str, Any]],
    df_candidates: list[dict[str, Any]],
    bf_circle: dict[str, Any],
    df_circle: dict[str, Any],
    params: Any,
    r6_angle: float | None,
    bf_circle_qualified: bool,
    df_circle_qualified: bool,
) -> dict[str, Any]:
    center_difference = math.hypot(
        float(bf_circle["centerX"]) - float(df_circle["centerX"]),
        float(bf_circle["centerY"]) - float(df_circle["centerY"]),
    )
    radius_difference = abs(float(bf_circle["radius"]) - float(df_circle["radius"]))
    circle_qualified = bool(
        bf_circle_qualified
        and df_circle_qualified
        and center_difference <= float(params.maximum_channel_center_difference_px)
        and radius_difference <= float(params.maximum_channel_radius_difference_px)
    )
    pairs: list[dict[str, Any]] = []
    eligible: list[dict[str, Any]] = []
    if circle_qualified:
        for bf_index, bf in enumerate(bf_candidates):
            if not bool(bf.get("pairingEligible")):
                continue
            for df_index, df in enumerate(df_candidates):
                if not bool(df.get("pairingEligible")):
                    continue
                difference = circular_distance_degrees(
                    float(bf["centerAngleDegrees"]), float(df["centerAngleDegrees"])
                )
                if difference > float(params.candidate_match_tolerance_degrees):
                    continue
                overlap = candidate_interval_overlap(bf, df)
                row = {
                    "bfCandidateIndex": bf_index,
                    "dfCandidateIndex": df_index,
                    "bfAngleDegrees": float(bf["centerAngleDegrees"]),
                    "dfAngleDegrees": float(df["centerAngleDegrees"]),
                    "channelAngleDifferenceDegrees": difference,
                    "crossChannelIntervalOverlapFraction": overlap,
                    "widthDifferenceDegrees": abs(float(bf["widthDegrees"]) - float(df["widthDegrees"])),
                    "depthDifferencePx": abs(float(bf.get("maximumInwardDepthPx", 0.0)) - float(df.get("maximumInwardDepthPx", 0.0))),
                    "apexCountAgreement": bf.get("apexCount") == df.get("apexCount"),
                    "leftMonotonicDifference": abs(float(bf.get("leftMonotonicSupportFraction", 0.0)) - float(df.get("leftMonotonicSupportFraction", 0.0))),
                    "rightMonotonicDifference": abs(float(bf.get("rightMonotonicSupportFraction", 0.0)) - float(df.get("rightMonotonicSupportFraction", 0.0))),
                    "bothManufacturedCompatibleAfterContour": bool(
                        bf.get("manufacturedCompatibleAfterContour")
                        and df.get("manufacturedCompatibleAfterContour")
                    ),
                    "r6SecondaryBfDistanceDegrees": (
                        None
                        if r6_angle is None
                        else circular_distance_degrees(float(bf["centerAngleDegrees"]), r6_angle)
                    ),
                    "r6SecondaryDfDistanceDegrees": (
                        None
                        if r6_angle is None
                        else circular_distance_degrees(float(df["centerAngleDegrees"]), r6_angle)
                    ),
                }
                row["r6SecondaryMaximumChannelDistanceDegrees"] = (
                    None
                    if r6_angle is None
                    else max(
                        float(row["r6SecondaryBfDistanceDegrees"]),
                        float(row["r6SecondaryDfDistanceDegrees"]),
                    )
                )
                row["eligibleAfterAllChannelLocalContours"] = bool(
                    row["bothManufacturedCompatibleAfterContour"]
                    and overlap >= float(params.manufactured_minimum_cross_channel_overlap)
                )
                pairs.append(row)
                if row["eligibleAfterAllChannelLocalContours"]:
                    eligible.append(row)

    resolved = eligible
    r6_tie_break = False
    if len(eligible) > 1 and r6_angle is not None:
        corroborated = [
            row for row in eligible
            if float(row["r6SecondaryMaximumChannelDistanceDegrees"])
            <= R6_SECONDARY_TOLERANCE_DEGREES
        ]
        if len(corroborated) == 1:
            resolved = corroborated
            r6_tie_break = True
    if len(resolved) == 1:
        state = (
            "DIAGNOSTIC_UNIQUE_POST_CONTOUR_PAIR_R6_SECONDARY_TIE_BREAK"
            if r6_tie_break
            else "DIAGNOSTIC_UNIQUE_POST_CONTOUR_PAIR"
        )
    elif not eligible:
        state = "HOLD_NO_BF_DF_MANUFACTURED_PAIR_AFTER_CONTOUR"
    else:
        state = "HOLD_AMBIGUOUS_BF_DF_MANUFACTURED_PAIR_AFTER_CONTOUR"

    bf_qualified = [row for row in bf_candidates if row.get("pairingEligible")]
    df_qualified = [row for row in df_candidates if row.get("pairingEligible")]
    same_chuck = None
    bf_unreadable = []
    bf_local_qualified: list[dict[str, Any]] = []
    if len(df_qualified) == 1:
        df_reference = df_qualified[0]
        bf_local_qualified = [
            row for row in bf_qualified if candidate_interval_overlap(row, df_reference) > 0.0
        ]
        bf_unreadable = [
            row for row in bf_candidates
            if row.get("classification") == "UNRESOLVED_DEEP_EDGE_RESPONSE"
            and str(row.get("state", "")).startswith("HOLD_")
            and not bool(row.get("pairingEligible"))
            and row.get("startAngleDegrees") is not None
            and candidate_interval_overlap(row, df_reference) > 0.0
        ]
    if circle_qualified and not bf_local_qualified and len(df_qualified) == 1 and bf_unreadable:
        df = df_qualified[0]
        same_chuck = {
            "state": "DIAGNOSTIC_DF_ONLY_SAME_CHUCK_ANGLE_OWNERSHIP_INTERVAL_BF_HOLD_RETAINED",
            "angleDegrees": float(df["centerAngleDegrees"]),
            "startAngleDegrees": float(df["startAngleDegrees"]),
            "endAngleDegrees": float(df["endAngleDegrees"]),
            "sourceChannel": "DF",
            "targetChannel": "BF",
            "transferredPixelCoordinateCount": 0,
            "bfContourHoldRetained": True,
            "futureRegistrationAuthorityGranted": False,
            "lawfulCircleComparisonRequiredAndPassed": True,
            "bfUnreadableCandidateIds": [row["candidateId"] for row in bf_unreadable],
        }
    return {
        "state": state,
        "channelContoursCompletedBeforePairing": True,
        "circleComparison": {
            "centerDifferencePx": center_difference,
            "radiusDifferencePx": radius_difference,
            "qualified": circle_qualified,
            "bfQualified": bool(bf_circle_qualified),
            "dfQualified": bool(df_circle_qualified),
            "poseAveraged": False,
        },
        "physicalPairs": pairs,
        "bfPairingIneligibleCandidateIds": [
            row["candidateId"] for row in bf_candidates if not bool(row.get("pairingEligible"))
        ],
        "dfPairingIneligibleCandidateIds": [
            row["candidateId"] for row in df_candidates if not bool(row.get("pairingEligible"))
        ],
        "eligiblePairCountBeforeR6Secondary": len(eligible),
        "resolvedPairCount": len(resolved),
        "resolvedPairs": resolved,
        "r6AngleConsumedAfterAllContours": r6_angle is not None,
        "r6SecondaryToleranceDegrees": R6_SECONDARY_TOLERANCE_DEGREES,
        "r6SecondaryTieBreakPerformed": r6_tie_break,
        "sameChuckAngleOnlyTransfer": same_chuck,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "holdClearancePerformed": False,
        "productionSelectionPerformed": False,
    }


def channel_summary(
    analysis: dict[str, Any],
    source: dict[str, Any],
    assets: dict[str, Any],
    seed_fit: dict[str, Any],
    inherited_authority: dict[str, Any] | None = None,
) -> dict[str, Any]:
    inherited_hold_retained = bool(
        inherited_authority is None
        or (
            inherited_authority["r22NotchOwnership"]["state"]
            == "HOLD_NO_UNIQUE_R21_CONTOUR_OWNERSHIP_METRICS"
            and int(inherited_authority["r22NotchOwnership"]["notchOwnedColumnCount"]) == 0
            and inherited_authority["r22HoldClearancePerformed"] is False
            and inherited_authority["r23OverallHeldReviewState"]
            == "HOLD_R23_POST2_VISUAL_COMPARISON_NOTCH_OWNERSHIP_UNRESOLVED"
        )
    )
    prior_cyan_state = (
        None if inherited_authority is None
        else str(inherited_authority["r22CyanGeometryVerificationState"])
    )
    cyan_authority_state = (
        analysis["cyanGeometryVerificationState"]
        if prior_cyan_state is None or not prior_cyan_state.startswith("HOLD_")
        else prior_cyan_state
    )
    inherited_cyan_hold_retained = bool(
        prior_cyan_state is None
        or not prior_cyan_state.startswith("HOLD_")
        or cyan_authority_state == prior_cyan_state
    )
    return {
        "source": source,
        "seedFit": seed_fit,
        "decodedAnnularGeometry": {
            "rows": int(analysis["strip"].shape[0]),
            "columns": int(analysis["strip"].shape[1]),
            "dtype": str(analysis["strip"].dtype),
            "radialPitchPx": 1.0,
        },
        "circleFit": analysis["circleFit"],
        "circleState": analysis["circleState"],
        "circleQualified": analysis["circleQualified"],
        "cyanGeometryVerified": analysis["cyanGeometryVerified"],
        "cyanGeometryVerificationState": analysis["cyanGeometryVerificationState"],
        "r24DiagnosticCyanGeometryVerified": analysis["cyanGeometryVerified"],
        "r24DiagnosticCyanGeometryVerificationState": analysis["cyanGeometryVerificationState"],
        "cyanGeometryAuthorityState": cyan_authority_state,
        "inheritedR22CyanHoldRetained": inherited_cyan_hold_retained,
        "edgeZoneInwardPx": float(r18.EDGE_ZONE_INWARD_PX),
        "maximumEdgeZoneSpacingErrorPx": float(analysis["evidence"]["maximumYellowSpacingErrorPx"]),
        "candidateDiscovery": {
            "population": analysis["evidence"]["candidateDiscoveryPopulation"],
            "thresholdPx": float(analysis["discovery"]["thresholdPx"]),
            "candidateFloorPx": float(analysis["discovery"]["candidateFloorPx"]),
            "baselineCenterPx": float(analysis["discovery"]["baselineCenterPx"]),
            "baselineNoiseSigmaPx": float(analysis["discovery"]["baselineNoiseSigmaPx"]),
            "candidateCount": len(analysis["candidateTraces"]),
            "smoothingPerformed": False,
            "morphologyPerformed": False,
            "gapFillPerformed": False,
            "fixedNotchWindowUsed": False,
        },
        "candidates": public_candidate_records(analysis),
        "candidateCount": len(analysis["candidateTraces"]),
        "allCandidatesContouredBeforePairing": True,
        "allAcceptedCoordinatesNativeSupported": all(
            bool(candidate["record"].get("allSelectedPixelsNativeSupported", True))
            for candidate in analysis["candidateTraces"]
        ),
        "allAcceptedCoordinatesRawPolaritySupported": all(
            bool(candidate["record"].get("allSelectedPixelsRawPolaritySupported", True))
            for candidate in analysis["candidateTraces"]
        ),
        "predecessorHeldColumnCount": int(np.count_nonzero(analysis["predecessorHeldColumns"])),
        "predecessorHeldColumnIndices": index_list(analysis["predecessorHeldColumns"]),
        "obstructionColumnCount": int(np.count_nonzero(analysis["obstructionColumns"])),
        "obstructionColumnIndices": index_list(analysis["obstructionColumns"]),
        "inheritedAuthority": inherited_authority,
        "inheritedR22R23HoldRetained": inherited_hold_retained,
        "predecessorHoldsCleared": False,
        "assets": assets,
        "evidence": analysis["evidence"],
    }


def post2_r6_angle_after_contours(seed: dict[str, Any]) -> float:
    selected = seed.get("selectedReviewOnlyManufacturedNotch")
    need(isinstance(selected, dict), "R6 secondary record is missing after candidate contouring")
    angle = float(selected["reviewAngleDegrees"])
    need(math.isfinite(angle), "R6 secondary angle is not finite")
    return angle


def process_post2(
    neutral_root: Path,
    source_job: dict[str, Any],
    source_rows: list[dict[str, Any]],
    seeds: dict[str, dict[str, Any]],
    geometry_job: dict[str, Any],
    inherited_authority: dict[str, Any],
) -> list[dict[str, Any]]:
    params = r18.diagnostic.R11.parameters_from_job(geometry_job)
    cfg = geometry_job["topologyConfig"]
    crop = geometry_job["crop"]
    by_source = {(row["identity"], row["channel"]): row for row in source_rows}
    post2_root = neutral_root / "post2"
    post2_root.mkdir()
    results: list[dict[str, Any]] = []
    for ordinal, member in enumerate(source_job["inputs"], 1):
        identity = str(member["identity"])
        need(identity in inherited_authority, f"{identity} is absent from inherited R22 authority")
        case_root = post2_root / f"P{ordinal:04d}"
        case_root.mkdir()
        rows: dict[str, Any] = {}
        for channel, key in (("BF", "bf"), ("DF", "df")):
            source = by_source[(identity, channel)]
            gray = cv2.imread(source["path"], cv2.IMREAD_GRAYSCALE)
            need(gray is not None, f"{identity} {channel} OpenCV decode failed")
            seed_channel = seeds[identity][key]
            need(
                gray.shape == (int(seed_channel["heightPx"]), int(seed_channel["widthPx"])),
                f"{identity} {channel} source geometry differs",
            )
            fit = seed_channel.get("fit")
            need(bool(seed_channel.get("qualified")) and isinstance(fit, dict), f"{identity} {channel} seed fit held")
            measured = r18.r13.unwrap(gray, fit, crop, params, cfg)
            del gray
            predecessor_measured = np.asarray(measured.get("pathMeasured"), dtype=bool)
            analysis = analyze_native_strip(
                measured["strip"], measured["offsets"], fit, params, cfg, predecessor_measured, channel
            )
            del measured
            assets = render_channel(case_root, identity, channel, analysis)
            rows[channel] = channel_summary(
                analysis, source, assets, fit, inherited_authority[identity]["channels"][channel]
            )
            del analysis
        # This is the first access to the R6 review angle.  Both channel-local
        # candidate populations and their rasters already exist at this point.
        r6_angle = post2_r6_angle_after_contours(seeds[identity])
        pair = pair_after_channel_contours(
            rows["BF"]["candidates"],
            rows["DF"]["candidates"],
            rows["BF"]["circleFit"],
            rows["DF"]["circleFit"],
            params,
            r6_angle,
            rows["BF"]["circleQualified"],
            rows["DF"]["circleQualified"],
        )
        pair["r24DiagnosticStateBeforeInheritedAuthority"] = pair["state"]
        pair["r24DiagnosticResolvedPairsRemainUnowned"] = pair["resolvedPairs"]
        pair["inheritedR22PairState"] = inherited_authority[identity]["r22PairState"]
        pair["inheritedR22OwnershipHoldCount"] = sum(
            row["inheritedAuthority"]["r22NotchOwnership"]["state"]
            == "HOLD_NO_UNIQUE_R21_CONTOUR_OWNERSHIP_METRICS"
            for row in rows.values()
        )
        pair["inheritedR22OwnershipHoldsRetained"] = pair["inheritedR22OwnershipHoldCount"] == 2
        pair["resolvedPairs"] = []
        pair["resolvedPairCount"] = 0
        pair["state"] = "HOLD_PREDECESSOR_R22_NOTCH_OWNERSHIP_AUTHORITY_RETAINED"
        results.append(
            {
                "ordinal": ordinal,
                "identity": identity,
                "state": "DIAGNOSTIC_ONLY_R24_POST2_CANDIDATE_FIRST_CONTOURS_COMPLETE",
                "channels": rows,
                "pairDiagnostic": pair,
                "r6SecondaryCorroboration": {
                    "reviewAngleDegrees": r6_angle,
                    "toleranceDegrees": R6_SECONDARY_TOLERANCE_DEGREES,
                    "consumedOnlyAfterBothChannelCandidatePopulationsExisted": True,
                    "primaryContourSelector": False,
                    "fixedSearchWindowDefined": False,
                },
            }
        )
    return results


def process_hotspot(
    neutral_root: Path,
    hotspot_input: dict[str, Any],
    geometry_job: dict[str, Any],
) -> list[dict[str, Any]]:
    assert_review_only(hotspot_input, "hotspot predecessor")
    need(len(hotspot_input.get("results", [])) == 4, "Hotspot predecessor does not contain four cases")
    params = r18.diagnostic.R11.parameters_from_job(geometry_job)
    cfg = geometry_job["topologyConfig"]
    offsets = np.arange(
        -int(cfg["maximumInwardPx"]),
        int(cfg["maximumOutwardPx"]) + 1,
        dtype=np.float32,
    )
    hotspot_root = neutral_root / "hotspot"
    hotspot_root.mkdir()
    results: list[dict[str, Any]] = []
    for ordinal, prior in enumerate(hotspot_input["results"], 1):
        identity = str(prior["safeId"])
        case_root = hotspot_root / f"H{ordinal:04d}"
        case_root.mkdir()
        rows: dict[str, Any] = {}
        for channel in ("BF", "DF"):
            prior_channel = prior["channels"][channel]
            source_record = prior_channel["sourceFullClean"]
            hold_record = prior_channel["assets"]["predecessor_hold_mask"]
            source_path = Path(str(source_record["path"]))
            hold_path = Path(str(hold_record["path"]))
            require_exact_file(source_path, str(source_record["sha256"]), f"hotspot {ordinal} {channel} clean source", int(source_record["bytes"]))
            require_exact_file(hold_path, str(hold_record["sha256"]), f"hotspot {ordinal} {channel} hold mask", int(hold_record["bytes"]))
            strip = cv2.imread(str(source_path), cv2.IMREAD_GRAYSCALE)
            hold_mask = cv2.imread(str(hold_path), cv2.IMREAD_GRAYSCALE)
            need(strip is not None and hold_mask is not None, f"hotspot {ordinal} {channel} OpenCV decode failed")
            need(strip.shape[0] == offsets.size and hold_mask.shape == strip.shape, f"hotspot {ordinal} {channel} annular geometry differs")
            predecessor_measured = ~np.any(hold_mask > 0, axis=0)
            fit = prior_channel["baseFit"]
            analysis = analyze_native_strip(strip, offsets, fit, params, cfg, predecessor_measured, channel)
            locked_clean = {
                "path": str(source_path),
                "bytes": source_path.stat().st_size,
                "sha256": str(source_record["sha256"]).upper(),
                "role": "HASH_LOCKED_PREDECESSOR_CLEAN_ANNULAR_SOURCE",
            }
            assets = render_channel(case_root, identity, channel, analysis, locked_clean)
            source = {
                "path": str(source_path),
                "bytes": source_path.stat().st_size,
                "sha256": str(source_record["sha256"]).upper(),
                "inputPredecessorHoldMask": file_record(hold_path, str(hold_record["sha256"])),
            }
            rows[channel] = channel_summary(analysis, source, assets, fit)
            del analysis, strip, hold_mask
        pair = pair_after_channel_contours(
            rows["BF"]["candidates"],
            rows["DF"]["candidates"],
            rows["BF"]["circleFit"],
            rows["DF"]["circleFit"],
            params,
            None,
            rows["BF"]["circleQualified"],
            rows["DF"]["circleQualified"],
        )
        results.append(
            {
                "ordinal": ordinal,
                "identity": prior["identity"],
                "safeId": identity,
                "state": "DIAGNOSTIC_ONLY_R24_HOTSPOT_CANDIDATE_FIRST_CONTOURS_COMPLETE",
                "channels": rows,
                "pairDiagnostic": pair,
            }
        )
    return results


def nearest_candidate(candidates: list[dict[str, Any]], angle: float) -> tuple[dict[str, Any] | None, float | None]:
    if not candidates:
        return None, None
    candidate = min(candidates, key=lambda row: circular_distance_degrees(float(row["centerAngleDegrees"]), angle))
    return candidate, circular_distance_degrees(float(candidate["centerAngleDegrees"]), angle)


def evaluate_hotspot_regression(
    results: list[dict[str, Any]],
    oracle: dict[str, Any],
    oracle_gate: dict[str, Any],
) -> dict[str, Any]:
    need(len(results) == len(oracle.get("results", [])) == 4, "Hotspot regression cardinality differs")
    need(
        oracle_gate.get("state") == "HOLD_R21_LOCAL_CYAN_AND_CHANNEL_CONTOUR_REVIEW_REQUIRED",
        "Hotspot oracle gate state differs",
    )
    rows: list[dict[str, Any]] = []
    for current, prior in zip(results, oracle["results"]):
        need(current["safeId"] == prior["safeId"], "Hotspot regression identity order differs")
        channel_rows: dict[str, Any] = {}
        prior_held_channels: list[str] = []
        for channel in ("BF", "DF"):
            old_channel = prior["channels"][channel]
            old_metrics = old_channel["physicalBoundary"]["pairedNotchNativeShoulderPath"]
            old_accepted = bool(old_metrics["orangeEligible"])
            if not old_accepted:
                prior_held_channels.append(channel)
            old_angle = float(
                prior["pairDiagnostic"]["eligiblePairs"][0][
                    "bfAngleDegrees" if channel == "BF" else "dfAngleDegrees"
                ]
            )
            new_channel = current["channels"][channel]
            regression_pool = (
                [
                    row for row in new_channel["candidates"]
                    if row.get("manufacturedCompatibleAfterContour")
                ]
                if old_accepted
                else new_channel["candidates"]
            )
            candidate, distance = nearest_candidate(regression_pool, old_angle)
            prior_width = float(old_metrics["candidateWidthDegrees"])
            prior_span = int(old_metrics["expectedSpanColumnCount"])
            prior_selected = int(old_metrics["selectedNativePixelCount"])
            new_width = None if candidate is None else candidate.get("widthDegrees")
            new_span = None if candidate is None else candidate.get("expectedSpanColumnCount")
            new_selected = None if candidate is None else len(candidate.get("representativePath", []))
            width_compatible = bool(
                not old_accepted
                or (new_width is not None and 0.75 <= float(new_width) / prior_width <= 1.25)
            )
            span_compatible = bool(
                not old_accepted
                or (new_span is not None and 0.75 <= int(new_span) / prior_span <= 1.25)
            )
            selected_count_compatible = bool(
                not old_accepted
                or (new_selected is not None and 0.75 <= int(new_selected) / prior_selected <= 1.25)
            )
            geometry_delta = {
                key: abs(float(new_channel["circleFit"][key]) - float(old_channel["circleFit"][key]))
                for key in ("centerX", "centerY", "radius")
            }
            geometry_exact = all(value <= 1.0e-6 for value in geometry_delta.values())
            accepted_preserved = bool(
                not old_accepted
                or (
                    candidate is not None
                    and distance is not None
                    and distance <= R6_SECONDARY_TOLERANCE_DEGREES
                    and bool(candidate.get("completeNativeShoulderPath"))
                    and bool(candidate.get("allSelectedPixelsNativeSupported"))
                    and bool(candidate.get("allSelectedPixelsRawPolaritySupported"))
                    and bool(candidate.get("manufacturedCompatibleAfterContour"))
                    and width_compatible
                    and span_compatible
                    and selected_count_compatible
                )
            )
            selected_pixel_count = sum(
                len(candidate.get("representativePath", []))
                for candidate in new_channel["candidates"]
            )
            native_selected_pixel_count = sum(
                len(candidate.get("representativePath", []))
                for candidate in new_channel["candidates"]
                if bool(candidate.get("allSelectedPixelsNativeSupported", True))
                and bool(candidate.get("allSelectedPixelsRawPolaritySupported", True))
                and not bool(candidate.get("crossChannelPixelCoordinateTransferPerformed"))
            )
            fabricated_pixel_count = max(0, selected_pixel_count - native_selected_pixel_count)
            if old_accepted:
                new_channel["contourAuthorityState"] = "DIAGNOSTIC_ONLY_R24_NATIVE_CONTOUR_REGRESSION"
            else:
                new_channel["contourAuthorityState"] = "HOLD_PREDECESSOR_R21_CHANNEL_CONTOUR_AUTHORITY_RETAINED"
            new_channel["predecessorR21ContourHoldRetained"] = not old_accepted
            new_channel["r24MeasurementCannotClearPredecessorR21Hold"] = True
            held_preserved = bool(
                old_accepted
                or (
                    str(new_channel["contourAuthorityState"]).startswith("HOLD_PREDECESSOR_R21_")
                    and new_channel["predecessorHoldsCleared"] is False
                    and not current["pairDiagnostic"].get("holdClearancePerformed")
                )
            )
            channel_rows[channel] = {
                "priorAcceptedNativeContour": old_accepted,
                "priorContourAngleDegrees": old_angle,
                "nearestR24CandidateId": None if candidate is None else candidate["candidateId"],
                "nearestR24CandidateDistanceDegrees": distance,
                "acceptedContourEvidencePreserved": accepted_preserved,
                "priorWidthDegrees": prior_width,
                "r24WidthDegrees": new_width,
                "widthRatioWithinFrozenRegressionBand": width_compatible,
                "priorExpectedSpanColumnCount": prior_span,
                "r24ExpectedSpanColumnCount": new_span,
                "spanRatioWithinFrozenRegressionBand": span_compatible,
                "priorSelectedNativePixelCount": prior_selected,
                "r24SelectedNativePixelCount": new_selected,
                "selectedPixelRatioWithinFrozenRegressionBand": selected_count_compatible,
                "r24ManufacturedCompatibleAfterContour": bool(
                    candidate is not None and candidate.get("manufacturedCompatibleAfterContour")
                ),
                "predecessorContourHoldPreserved": held_preserved,
                "priorCyanGeometryVerified": bool(old_channel["cyanGeometryVerified"]),
                "r24CyanGeometryVerified": bool(new_channel["cyanGeometryVerified"]),
                "cyanStatePreserved": bool(old_channel["cyanGeometryVerified"]) == bool(new_channel["cyanGeometryVerified"]),
                "fixedCircleMaximumAbsoluteDeltaPx": max(geometry_delta.values()),
                "fixedCircleGeometryExact": geometry_exact,
                "yellowSpacingExact": float(new_channel["maximumEdgeZoneSpacingErrorPx"]) <= 1.0e-4,
                "selectedNativeCoordinateCount": selected_pixel_count,
                "nativeRawSupportedCoordinateCount": native_selected_pixel_count,
                "fabricatedPixelCount": fabricated_pixel_count,
            }
        if prior_held_channels:
            current["pairDiagnostic"]["predecessorR21HeldChannels"] = prior_held_channels
            current["pairDiagnostic"]["predecessorResolvedPairsRemainDiagnosticUnowned"] = current["pairDiagnostic"].get("resolvedPairs", [])
            current["pairDiagnostic"]["resolvedPairs"] = []
            current["pairDiagnostic"]["resolvedPairCount"] = 0
            current["pairDiagnostic"]["state"] = "HOLD_PREDECESSOR_R21_CHANNEL_CONTOUR_AUTHORITY_RETAINED"
            current["pairDiagnostic"]["crossChannelPixelCoordinateTransferPerformed"] = False
            current["pairDiagnostic"]["holdClearancePerformed"] = False
        rows.append({"safeId": current["safeId"], "channels": channel_rows})
    flat = [row["channels"][channel] for row in rows for channel in ("BF", "DF")]
    return {
        "state": (
            "PASS_R24_HOTSPOT_REGRESSION_WITH_EXISTING_HOLDS_RETAINED"
            if all(
                row["acceptedContourEvidencePreserved"]
                and row["predecessorContourHoldPreserved"]
                and row["cyanStatePreserved"]
                and row["fixedCircleGeometryExact"]
                and row["yellowSpacingExact"]
                for row in flat
            )
            else "HOLD_R24_HOTSPOT_REGRESSION_DIFFERENCE"
        ),
        "caseCount": len(rows),
        "channelCount": len(flat),
        "priorAcceptedNativeContourCount": sum(row["priorAcceptedNativeContour"] for row in flat),
        "priorBfContourHoldCount": sum(
            not row["channels"]["BF"]["priorAcceptedNativeContour"] for row in rows
        ),
        "allExistingContourHoldsRetained": all(row["predecessorContourHoldPreserved"] for row in flat),
        "allAcceptedCoordinatesNativeSupported": all(row["fabricatedPixelCount"] == 0 for row in flat),
        "crossChannelPixelCoordinateTransferPerformed": False,
        "rows": rows,
    }


def candidate_near(
    result: dict[str, Any], channel: str, angle: float, tolerance: float = 0.8
) -> dict[str, Any] | None:
    candidate, distance = nearest_candidate(result["channels"][channel]["candidates"], angle)
    return candidate if candidate is not None and distance is not None and distance <= tolerance else None


def candidate_metric_schema_valid(candidate: dict[str, Any]) -> bool:
    required = {
        "expectedSpanColumnCount",
        "supportMetricPopulation",
        "supportMetricSpanColumnIndices",
        "rawSupportedColumnCount",
        "rawSupportedFraction",
        "maximumContiguousUnsupportedRun",
        "unsupportedColumnIndices",
        "leftShoulderDepthFromFixedOuterCirclePx",
        "rightShoulderDepthFromFixedOuterCirclePx",
        "leftNormalBrightnessTraceDepthFromFixedOuterCirclePx",
        "rightNormalBrightnessTraceDepthFromFixedOuterCirclePx",
        "leftShoulderReturnResidualFromNormalTracePx",
        "rightShoulderReturnResidualFromNormalTracePx",
        "widthDegrees",
        "maximumInwardDepthPx",
        "medianInwardDepthPx",
        "apexCount",
        "apexOffsetFraction",
        "leftMonotonicSupportFraction",
        "rightMonotonicSupportFraction",
        "firstDifferenceAbsoluteP90Px",
        "secondDifferenceAbsoluteP90Px",
        "slopeDirectionReversalCount",
        "curvatureReversalCount",
        "extraCurvatureReversalFraction",
        "supportGraphNodeCount",
        "supportGraphBranchColumnCount",
        "parallelBandColumnCount",
        "maximumCompleteBandCountPerColumn",
        "representativeParallelBandSwitchCount",
        "metricAvailability",
    }
    if not required.issubset(candidate):
        return False
    try:
        span = [int(value) for value in candidate["supportMetricSpanColumnIndices"]]
        expected = int(candidate["expectedSpanColumnCount"])
        supported = int(candidate["rawSupportedColumnCount"])
        unsupported = {int(value) for value in candidate["unsupportedColumnIndices"]}
        if expected <= 0 or len(span) != expected or len(set(span)) != expected:
            return False
        flags = np.asarray([column not in unsupported for column in span], dtype=bool)
        if supported != int(np.count_nonzero(flags)):
            return False
        if not math.isclose(
            float(candidate["rawSupportedFraction"]),
            float(np.mean(flags)),
            rel_tol=0.0,
            abs_tol=1.0e-12,
        ):
            return False
        if int(candidate["maximumContiguousUnsupportedRun"]) != longest_false_run(flags):
            return False
        if int(candidate["supportGraphNodeCount"]) <= 0 or not candidate.get("rawComponentNativeNodes"):
            return False
        if not (
            math.isfinite(float(candidate["widthDegrees"]))
            and float(candidate["widthDegrees"]) > 0.0
            and math.isfinite(float(candidate["maximumInwardDepthPx"]))
            and math.isfinite(float(candidate["medianInwardDepthPx"]))
        ):
            return False
        availability = candidate["metricAvailability"]
        availability_keys = {
            "nativeSupport",
            "fullInwardDepth",
            "leftReturnResidual",
            "rightReturnResidual",
            "apexAndOffset",
            "monotonicSides",
            "smoothnessJaggednessCurvature",
            "branchAndParallelBands",
            "representativeParallelBandSwitches",
        }
        if not isinstance(availability, dict) or set(availability) != availability_keys:
            return False
        if not (
            str(availability["nativeSupport"]).startswith("MEASURED_")
            and str(availability["fullInwardDepth"]).startswith("MEASURED_")
            and str(availability["branchAndParallelBands"]).startswith("MEASURED_")
        ):
            return False
        for side in ("left", "right"):
            value = candidate[f"{side}ShoulderReturnResidualFromNormalTracePx"]
            state = str(availability[f"{side}ReturnResidual"])
            if (value is None and not state.startswith("NOT_MEASURABLE_")) or (
                value is not None and (not math.isfinite(float(value)) or not state.startswith("MEASURED_"))
            ):
                return False
        has_representative_path = int(candidate.get("representativePathObservedCount", 0)) > 0
        path_metrics = (
            "apexCount",
            "apexOffsetFraction",
            "leftMonotonicSupportFraction",
            "rightMonotonicSupportFraction",
            "firstDifferenceAbsoluteP90Px",
            "secondDifferenceAbsoluteP90Px",
            "slopeDirectionReversalCount",
            "curvatureReversalCount",
            "extraCurvatureReversalFraction",
            "representativeParallelBandSwitchCount",
        )
        path_states = (
            "apexAndOffset",
            "monotonicSides",
            "smoothnessJaggednessCurvature",
            "representativeParallelBandSwitches",
        )
        if has_representative_path:
            if any(candidate[key] is None for key in path_metrics):
                return False
            if any(not str(availability[key]).startswith("MEASURED_") for key in path_states):
                return False
        else:
            if not (
                str(candidate.get("state", "")).startswith("HOLD_")
                and candidate.get("classification") == "UNRESOLVED_DEEP_EDGE_RESPONSE"
                and all(candidate[key] is None for key in path_metrics)
                and all(str(availability[key]).startswith("NOT_MEASURABLE_") for key in path_states)
            ):
                return False
        return bool(
            candidate.get("allSelectedPixelsNativeSupported")
            and candidate.get("allSelectedPixelsRawPolaritySupported")
        )
    except (KeyError, TypeError, ValueError, OverflowError):
        return False


def post2_semantic_checks(results: list[dict[str, Any]]) -> dict[str, bool]:
    by_identity = {row["identity"]: row for row in results}
    need(len(by_identity) == 3, "POST2 semantic population does not contain three identities")
    slot01 = next(row for identity, row in by_identity.items() if identity.endswith("SLOT01"))
    slot03 = next(row for identity, row in by_identity.items() if identity.endswith("SLOT03"))
    slot17 = next(row for identity, row in by_identity.items() if identity.endswith("SLOT17"))

    def complete_native(candidate: dict[str, Any] | None) -> bool:
        return bool(
            candidate is not None
            and candidate.get("completeNativeShoulderPath")
            and candidate.get("allSelectedPixelsNativeSupported")
            and candidate.get("allSelectedPixelsRawPolaritySupported")
        )

    def interval_contains(candidate: dict[str, Any], angle: float) -> bool:
        start = float(candidate["startAngleDegrees"]) % 360.0
        width = float(candidate["widthDegrees"])
        return ((float(angle) % 360.0) - start) % 360.0 <= width + 1.0e-9

    def interval_covers(outer: dict[str, Any], inner: dict[str, Any]) -> bool:
        outer_start = float(outer["startAngleDegrees"]) % 360.0
        outer_width = min(max(float(outer["widthDegrees"]), 0.0), 360.0)
        inner_start = float(inner["startAngleDegrees"]) % 360.0
        inner_width = min(max(float(inner["widthDegrees"]), 0.0), 360.0)
        start_delta = (inner_start - outer_start) % 360.0
        return bool(
            outer_width + 1.0e-9 >= inner_width
            and start_delta + inner_width <= outer_width + 1.0e-9
        )

    slot01_channel_checks: list[bool] = []
    for channel in ("BF", "DF"):
        smooth = candidate_near(slot01, channel, 90.0)
        irregular = candidate_near(slot01, channel, 86.0, 1.5)
        slot01_channel_checks.append(
            bool(
                complete_native(smooth)
                and smooth is not None
                and smooth.get("manufacturedCompatibleAfterContour")
                and complete_native(irregular)
                and irregular is not None
                and irregular.get("classification") == "NON_NOTCH_DEEP_EDGE_RESPONSE"
                and candidate_interval_overlap(smooth, irregular) == 0.0
                and circular_distance_degrees(
                    float(smooth["centerAngleDegrees"]), float(irregular["centerAngleDegrees"])
                ) > 2.0
            )
        )
    slot01_separate = all(slot01_channel_checks)

    slot03_df = candidate_near(slot03, "DF", 90.0)
    slot03_df_real = complete_native(slot03_df)
    slot03_bf = candidate_near(slot03, "BF", 90.0, 1.5)
    slot03_bf_supported = complete_native(slot03_bf)
    slot03_bf_explicit_hold = bool(
        slot03_bf is not None
        and slot03_bf.get("classification") == "UNRESOLVED_DEEP_EDGE_RESPONSE"
        and str(slot03_bf.get("state", "")).startswith("HOLD_")
    )
    if slot03_bf is None:
        channel = slot03["channels"]["BF"]
        width = int(channel["decodedAnnularGeometry"]["columns"])
        target = int(round(90.0 * width / 360.0)) % width
        slot03_bf_explicit_hold = target in set(channel["predecessorHeldColumnIndices"]) or target in set(
            channel["obstructionColumnIndices"]
        )
    slot03_real = bool(slot03_df_real and (slot03_bf_supported or slot03_bf_explicit_hold))

    slot17_df = candidate_near(slot17, "DF", 89.64)
    slot17_df_real = complete_native(slot17_df)
    slot17_pinned_broad = slot17["channels"]["BF"]["inheritedAuthority"].get("r22BroadResponse")
    need(isinstance(slot17_pinned_broad, dict), "Pinned R22 SLOT17 BF broad response is absent")
    slot17_broad = [
        row for row in slot17["channels"]["BF"]["candidates"]
        if row.get("classification") in {
            "NON_NOTCH_DEEP_EDGE_RESPONSE",
            "UNRESOLVED_DEEP_EDGE_RESPONSE",
        }
        and row.get("startAngleDegrees") is not None
        and interval_covers(row, slot17_pinned_broad)
    ]
    slot17_other_overlap = []
    if len(slot17_broad) == 1:
        broad = slot17_broad[0]
        slot17_other_overlap = [
            row for row in slot17["channels"]["BF"]["candidates"]
            if row["candidateId"] != broad["candidateId"]
            and row.get("startAngleDegrees") is not None
            and (
                candidate_interval_overlap(row, broad) > 0.0
                or candidate_interval_overlap(row, slot17_pinned_broad) > 0.0
            )
        ]
    slot17_broad_held = bool(
        len(slot17_broad) == 1
        and not slot17_other_overlap
        and not slot17["pairDiagnostic"].get("r24DiagnosticResolvedPairsRemainUnowned")
        and slot17["pairDiagnostic"]["state"]
        == "HOLD_PREDECESSOR_R22_NOTCH_OWNERSHIP_AUTHORITY_RETAINED"
    )

    channels = [row["channels"][channel] for row in results for channel in ("BF", "DF")]
    candidates = [candidate for channel in channels for candidate in channel["candidates"]]
    candidate_assets = [asset for channel in channels for asset in channel["assets"]["candidateReviews"]]
    rendering_exact = bool(
        all(channel["assets"]["renderSemantics"]["normalBrightnessPixelCount"] > 0 for channel in channels)
        and all(
            asset["renderSemantics"]["normalContextPixelCount"] > 0
            and asset["renderSemantics"]["expectedRepresentativeNativePixelCount"]
            == asset["renderSemantics"]["renderedRepresentativeNativePixelCount"]
            and asset["renderSemantics"]["expectedCandidateGraphPixelCount"] > 0
            and asset["renderSemantics"]["expectedCandidateGraphPixelCount"]
            == asset["renderSemantics"]["renderedCandidateGraphPixelCount"]
            and asset["renderSemantics"]["candidateLocalOnly"]
            for asset in candidate_assets
        )
        and all(
            not candidate.get("completeNativeShoulderPath")
            or len(candidate.get("representativePath", [])) > 0
            for candidate in candidates
        )
    )
    inherited_holds = bool(
        all(
            channel.get("inheritedR22R23HoldRetained")
            and channel.get("inheritedR22CyanHoldRetained")
            and channel.get("predecessorHoldsCleared") is False
            for channel in channels
        )
        and all(
            row["pairDiagnostic"].get("inheritedR22OwnershipHoldsRetained")
            and row["pairDiagnostic"].get("resolvedPairCount") == 0
            for row in results
        )
        and sum(
            str(channel["inheritedAuthority"]["r22CyanGeometryVerificationState"]).startswith("HOLD_")
            for channel in channels
        ) == 5
    )
    return {
        "threePost2MembersComplete": len(results) == 3,
        "allSixChannelCirclesQualified": all(row["circleQualified"] for row in channels),
        "cyanOuterGeometryUnchanged": all(not row["evidence"]["cyanGeometryChanged"] for row in channels),
        "yellowExactly20PxInward": all(
            float(row["edgeZoneInwardPx"]) == 20.0
            and float(row["maximumEdgeZoneSpacingErrorPx"]) <= 1.0e-4
            for row in channels
        ),
        "everyRawCandidateContouredBeforePairing": all(row["allCandidatesContouredBeforePairing"] for row in channels),
        "allSelectedCandidatePixelsNativeAndRawSupported": all(
            bool(row.get("allSelectedPixelsNativeSupported", True))
            and bool(row.get("allSelectedPixelsRawPolaritySupported", True))
            for row in candidates
        ),
        "completePerCandidateContourMetricSchema": all(
            candidate_metric_schema_valid(row) for row in candidates
        ),
        "slot01Smooth90SeparateFromIrregular86": slot01_separate,
        "slot03Df90AndBfWhenSupportedUseNativeBrightness": slot03_real,
        "slot17Df89p64ContourUsesNativeBrightness": slot17_df_real,
        "slot17BroadBfResponseHeldWhole": slot17_broad_held,
        "noCandidateMorphologyOrInterpolation": all(
            not row.get("morphologyPerformed")
            and not row.get("interpolationPerformed")
            and not row.get("templateOrIdealCurveUsed")
            for row in candidates
        ),
        "brightnessTraceRenderedOnCircleAndCandidateViews": rendering_exact,
        "noCrossChannelPixelTransfer": all(
            not row["pairDiagnostic"]["crossChannelPixelCoordinateTransferPerformed"]
            for row in results
        ),
        "allPredecessorHoldsRetained": inherited_holds,
    }


def generated_inventory(root: Path) -> list[dict[str, Any]]:
    return [
        file_record(path)
        for path in sorted(
            (candidate for candidate in root.rglob("*") if candidate.is_file()),
            key=lambda item: str(item).lower(),
        )
    ]


def run_inference(args: argparse.Namespace) -> int:
    for supplied, expected, label in (
        (args.checkpoint_sha256, CHECKPOINT_SHA256, "checkpoint"),
        (args.rollover_manifest_sha256, ROLLOVER_MANIFEST_SHA256, "rollover manifest"),
        (args.rollover_gate_sha256, ROLLOVER_GATE_SHA256, "rollover gate"),
        (args.source_job_sha256, SOURCE_JOB_SHA256, "POST2 source job"),
        (args.geometry_job_sha256, GEOMETRY_JOB_SHA256, "geometry job"),
        (args.hotspot_input_sha256, HOTSPOT_INPUT_SHA256, "hotspot input"),
        (args.hotspot_oracle_sha256, HOTSPOT_ORACLE_SHA256, "hotspot oracle"),
        (args.hotspot_oracle_gate_sha256, HOTSPOT_ORACLE_GATE_SHA256, "hotspot oracle gate"),
    ):
        need(str(supplied).upper() == expected, f"Supplied {label} pin differs from R24")
    output = Path(args.output_root)
    workspace = Path(args.workspace_root).resolve()
    workspace_io = Path(args.workspace_io_root).absolute()
    code_root = Path(args.code_root).resolve()
    need(workspace.is_dir(), "Desktop authority workspace root is missing")
    need(workspace_io.is_absolute() and workspace_io.is_dir(), "R: workspace alias is missing")
    need(code_root == PROJECT_ROOT.resolve(), "R24 code root differs from its exact checkout")
    need(
        output.is_absolute()
        and output.drive.upper() == "C:"
        and same_windows_path(output, EXPECTED_INFERENCE_ROOT)
        and not output.exists()
        and len(str(output)) + 128 < 200,
        "R24 inference output must be a fresh short C: root",
    )
    source_job_path = Path(args.source_job)
    geometry_job_path = Path(args.geometry_job)
    closure = verify_rollover_closure(
        Path(args.rollover_manifest),
        args.rollover_manifest_sha256,
        Path(args.rollover_gate),
        args.rollover_gate_sha256,
        Path(args.checkpoint),
        args.checkpoint_sha256,
        code_root,
        workspace_io,
    )
    source_job = load_json_pinned(source_job_path, SOURCE_JOB_SHA256, "POST2 source job")
    geometry_job = load_json_pinned(geometry_job_path, GEOMETRY_JOB_SHA256, "geometry job")
    assert_review_only(source_job, "POST2 source job")
    assert_review_only(geometry_job, "geometry job")
    need(source_job.get("schema") == "argos_ocv03_o3p8_front_split_notch_job_v1", "POST2 source-job schema differs")
    need(geometry_job.get("schema") == "argos_ocv03_full_perimeter_topology_job_v1", "Geometry-job schema differs")
    need(Path(str(source_job["workspaceAlias"]["target"])).resolve() == workspace, "Manifest Desktop authority root differs")
    need(workspace_io.drive.upper() == str(source_job["workspaceAlias"]["drive"]).upper(), "R: alias drive differs")
    relative_job = source_job_path.resolve().relative_to(workspace)
    alias_sentinel = workspace_io / relative_job
    require_exact_file(alias_sentinel, SOURCE_JOB_SHA256, "R: source-job sentinel")
    loaded_dependencies = verify_engine_lineage()
    inherited_post2 = load_r22_inherited_post2_authority()
    hotspot_input_path = Path(args.hotspot_input)
    hotspot_oracle_path = Path(args.hotspot_oracle)
    hotspot_oracle_gate_path = Path(args.hotspot_oracle_gate)
    hotspot_input = load_json_pinned(hotspot_input_path, HOTSPOT_INPUT_SHA256, "hotspot input summary")
    require_exact_file(hotspot_oracle_path, HOTSPOT_ORACLE_SHA256, "hotspot R21 oracle")
    require_exact_file(hotspot_oracle_gate_path, HOTSPOT_ORACLE_GATE_SHA256, "hotspot R21 oracle gate")
    source_rows, seeds = verify_post2_sources(workspace_io, source_job)

    preflight_output_layout(
        output,
        [str(row["identity"]) for row in source_job["inputs"]]
        + [str(row["safeId"]) for row in hotspot_input["results"]],
    )
    output.mkdir()
    neutral_root = output / "neutral"
    neutral_root.mkdir()
    post2_results = process_post2(
        neutral_root,
        source_job,
        source_rows,
        seeds,
        geometry_job,
        inherited_post2["byIdentity"],
    )
    hotspot_results = process_hotspot(neutral_root, hotspot_input, geometry_job)

    # The prior hotspot oracle is parsed only after all 14 independent channel
    # populations (six POST2, eight hotspot) have been contoured and rendered.
    hotspot_oracle = load_json_pinned(hotspot_oracle_path, args.hotspot_oracle_sha256, "hotspot R21 oracle")
    hotspot_oracle_gate = load_json_pinned(hotspot_oracle_gate_path, args.hotspot_oracle_gate_sha256, "hotspot R21 oracle gate")
    hotspot_regression = evaluate_hotspot_regression(
        hotspot_results, hotspot_oracle, hotspot_oracle_gate
    )
    semantic_checks = post2_semantic_checks(post2_results)
    semantic_checks["hotspotRegressionPreservesGoodContoursAndAllHolds"] = hotspot_regression["state"].startswith("PASS_")
    semantic_checks["completePerCandidateContourMetricSchemaAcrossAllFourteenChannels"] = all(
        candidate_metric_schema_valid(candidate)
        for cohort in (post2_results, hotspot_results)
        for result in cohort
        for channel in ("BF", "DF")
        for candidate in result["channels"][channel]["candidates"]
    )

    population = {
        "schema": POPULATION_SCHEMA,
        "state": "FROZEN_NEUTRAL_CANDIDATE_POPULATION_PENDING_POST_LABEL_EVALUATION",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "engine": file_record(Path(__file__).resolve()),
        "post2": post2_results,
        "hotspot": hotspot_results,
        "hotspotRegression": hotspot_regression,
        "inheritedPost2Authority": inherited_post2,
        "semanticChecksBeforeLabels": semantic_checks,
        "candidatePopulation": "ALL_FULL_360_CHANNEL_LOCAL_RAW_DEPTH_RESPONSES_BEFORE_SCORER_LABEL",
        "candidatePopulationFrozenBeforeScorerLabelParse": True,
        "scorerLabelDigestVerifiedThroughRolloverClosure": True,
        "scorerLabelJsonParsed": False,
        "knownChipoutAngleConsumed": False,
        "chipoutThresholdTuningPerformed": False,
        "candidateFilteringFromChipoutTruthPerformed": False,
        "r6Role": "POST_CONTOUR_SECONDARY_CORROBORATION_OR_TIE_BREAK_ONLY",
        "r6PrimaryContourSelectionPerformed": False,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "sourceMutationPerformed": False,
        "existingTaskOrProcessActionPerformed": False,
        "providerActivated": False,
        "holdClearancePerformed": False,
        "packageBuilt": False,
        "packageAttemptCount": 0,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    population_asset = write_json_new(neutral_root / "NEUTRAL_CANDIDATE_POPULATION.json", population)
    inventory_before_freeze = generated_inventory(neutral_root)
    freeze = {
        "schema": FREEZE_SCHEMA,
        "state": "PASS_R24_COMPLETE_NEUTRAL_POPULATION_FILESET_FROZEN",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "population": population_asset,
        "generatedFileCountBeforeFreezeManifest": len(inventory_before_freeze),
        "generatedFiles": inventory_before_freeze,
        "allGeneratedFilesHashed": True,
        "externalSourceAndDependencyRecordsRemainPinnedInPopulationAndSummary": True,
        "scorerLabelJsonParsed": False,
        "postFreezeWritesRestrictedToSummaryGateAndFreshEvaluationChild": True,
    }
    freeze_asset = write_json_new(neutral_root / "FREEZE_MANIFEST.json", freeze)
    total_candidates = sum(
        row["channels"][channel]["candidateCount"]
        for cohort in (post2_results, hotspot_results)
        for row in cohort
        for channel in ("BF", "DF")
    )
    summary = {
        "schema": SUMMARY_SCHEMA,
        "state": "COMPLETE_DIAGNOSTIC_ONLY_R24_NEUTRAL_POPULATION_FROZEN",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "engine": file_record(Path(__file__).resolve()),
        "loadedDependencies": loaded_dependencies,
        "inheritedPost2AuthorityRecords": inherited_post2["records"],
        "checkpointAndRolloverClosure": closure,
        "sourceJob": file_record(source_job_path, SOURCE_JOB_SHA256),
        "geometryJob": file_record(geometry_job_path, GEOMETRY_JOB_SHA256),
        "aliasSentinel": file_record(alias_sentinel, SOURCE_JOB_SHA256),
        "sourceIntegrity": source_rows,
        "hotspotInput": file_record(hotspot_input_path, HOTSPOT_INPUT_SHA256),
        "hotspotOracle": file_record(hotspot_oracle_path, HOTSPOT_ORACLE_SHA256),
        "hotspotOracleGate": file_record(hotspot_oracle_gate_path, HOTSPOT_ORACLE_GATE_SHA256),
        "neutralPopulation": population_asset,
        "freezeManifest": freeze_asset,
        "post2MemberCount": len(post2_results),
        "post2ChannelCount": len(post2_results) * 2,
        "hotspotCaseCount": len(hotspot_results),
        "hotspotChannelCount": len(hotspot_results) * 2,
        "neutralCandidateCount": total_candidates,
        "semanticChecksBeforeLabels": semantic_checks,
        "workspaceAccess": {
            "authorityRoot": str(workspace),
            "ioAliasRoot": str(workspace_io),
            "aliasDrive": workspace_io.drive.upper(),
            "aliasByteIdentityVerified": True,
            "allSixFullResolutionBmpSourcesResolvedOnlyThroughAlias": True,
        },
        "scorerLabelDigestVerifiedOnly": True,
        "scorerLabelJsonParsed": False,
        "knownChipoutAngleConsumed": False,
        "candidatePopulationFrozenBeforeScorerLabelParse": True,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "sourceMutationPerformed": False,
        "existingTaskOrProcessActionPerformed": False,
        "providerActivated": False,
        "holdClearancePerformed": False,
        "packageBuilt": False,
        "packageAttemptCount": 0,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    summary_asset = write_json_new(output / "SUMMARY.json", summary)
    integrity_checks = {
        "checkpointAndRolloverClosureExact": closure["uniquePinnedFileCount"] == 64,
        "sixBmpSourcesExactThroughAlias": len(source_rows) == 6,
        "threePost2MembersAndFourHotspotCasesComplete": len(post2_results) == 3 and len(hotspot_results) == 4,
        "allFourteenChannelPopulationsPresent": len(post2_results) * 2 + len(hotspot_results) * 2 == 14,
        "neutralPopulationWrittenBeforeFreezeManifest": True,
        "allNeutralFilesHashed": bool(freeze["allGeneratedFilesHashed"]),
        "scorerLabelJsonUnparsed": not population["scorerLabelJsonParsed"],
        "noMorphInterpolationIdealCurveOrPixelTransfer": all(
            semantic_checks[key]
            for key in (
                "noCandidateMorphologyOrInterpolation",
                "noCrossChannelPixelTransfer",
            )
        ),
        "noSourceRuntimeProviderTaskOrPackageMutation": True,
    }
    semantic_checks_pass = all(bool(value) for value in semantic_checks.values())
    evaluation_authorized = all(integrity_checks.values()) and semantic_checks_pass
    gate = {
        "schema": GATE_SCHEMA,
        "state": (
            "PASS_R24_NEUTRAL_POPULATION_FROZEN_WITH_SEMANTIC_HOLDS_RETAINED"
            if evaluation_authorized
            else "HOLD_R24_NEUTRAL_POPULATION_PRELABEL_GATE_FAILURE"
        ),
        "summary": summary_asset,
        "neutralPopulation": population_asset,
        "freezeManifest": freeze_asset,
        "integrityChecks": integrity_checks,
        "semanticChecksBeforeLabels": semantic_checks,
        "semanticCheckFailuresRemainOperatorVisibleHolds": [
            key for key, value in semantic_checks.items() if not value
        ],
        "allRequiredSemanticChecksPassedBeforeLabelRead": semantic_checks_pass,
        "evaluationMayReadScorerLabelOnlyAfterRehashingFrozenPopulation": evaluation_authorized,
        "operatorVisualReviewRequired": True,
        "packageBuilt": False,
        "packageAttemptCount": 0,
        "reviewOnly": True,
        "productionEligible": False,
    }
    gate_asset = write_json_new(output / "INFERENCE_GATE.json", gate)
    print(
        json.dumps(
            {
                "state": gate["state"],
                "summaryPath": summary_asset["path"],
                "summarySha256": summary_asset["sha256"],
                "populationPath": population_asset["path"],
                "populationSha256": population_asset["sha256"],
                "freezePath": freeze_asset["path"],
                "freezeSha256": freeze_asset["sha256"],
                "gatePath": gate_asset["path"],
                "gateSha256": gate_asset["sha256"],
            },
            separators=(",", ":"),
        )
    )
    return 0


def verify_record_tree_before_label(*documents: dict[str, Any]) -> dict[str, Any]:
    records: dict[str, dict[str, Any]] = {}
    pointers: dict[str, list[str]] = {}
    for document_index, document in enumerate(documents):
        for pointer, record in iter_hash_records(document, f"$document[{document_index}]"):
            path = Path(str(record["path"]))
            key = str(path.absolute()).lower()
            expected = str(record["sha256"]).upper()
            size = int(record["bytes"]) if record.get("bytes") is not None else None
            if key in records:
                need(records[key]["sha256"] == expected, f"Frozen record hash conflict: {path}")
                if size is not None and records[key].get("bytes") is not None:
                    need(int(records[key]["bytes"]) == size, f"Frozen record size conflict: {path}")
                pointers[key].append(pointer)
                continue
            require_exact_file(path, expected, f"frozen pre-label record {pointer}", size)
            records[key] = {
                "path": str(path),
                "bytes": path.stat().st_size,
                "sha256": expected,
            }
            pointers[key] = [pointer]
    return {
        "uniqueFileCount": len(records),
        "records": sorted(records.values(), key=lambda row: row["path"].lower()),
        "allExactBeforeScorerLabelParse": True,
    }


def scorer_label_identity_angle(payload: dict[str, Any], identities: set[str]) -> tuple[str, float]:
    need(
        payload.get("schema") == "argos_ocv03_post2_scorer_only_labels_v1"
        and payload.get("state") == "FROZEN_POST_INFERENCE_SCORER_ONLY"
        and bool(payload.get("reviewOnly")),
        "Scorer-label schema, state, or authority differs",
    )
    for key in (
        "detectorInputAllowed",
        "thresholdSourceAllowed",
        "candidateFilterAllowed",
        "tieBreakerAllowed",
        "trainingEligible",
        "xmlEligible",
        "productionEligible",
    ):
        need(not bool(payload.get(key)), f"Scorer-label authority forbids {key}")
    members = payload.get("members")
    need(isinstance(members, list), "Scorer-label members are missing")
    labeled = [
        member for member in members
        if isinstance(member, dict) and "knownChipoutAngleDegreesImage" in member
    ]
    need(len(labeled) == 1, "Scorer labels do not contain exactly one chipout member")
    identity = str(labeled[0].get("identity"))
    need(identity in identities, "Scorer-label identity lies outside the frozen POST2 population")
    angle = float(labeled[0]["knownChipoutAngleDegreesImage"])
    need(math.isfinite(angle), "Scorer-label angle is not finite")
    return identity, angle


def native_cyclic_crop(image: np.ndarray, center_degrees: float, width: int) -> tuple[np.ndarray, np.ndarray]:
    center = int(round((center_degrees % 360.0) * width / 360.0)) % width
    relative = np.arange(
        -CANDIDATE_REVIEW_HALF_WIDTH_COLUMNS,
        CANDIDATE_REVIEW_HALF_WIDTH_COLUMNS + 1,
        dtype=np.int64,
    )
    columns = (center + relative) % width
    return image[:, columns].copy(), columns


def run_evaluation(args: argparse.Namespace) -> int:
    need(args.scorer_labels_sha256.upper() == SCORER_LABELS_SHA256, "Scorer-label pin differs from R24")
    output = Path(args.output_root)
    expected_output = EXPECTED_INFERENCE_ROOT / "evaluation"
    need(
        output.is_absolute()
        and output.drive.upper() == "C:"
        and same_windows_path(output, expected_output)
        and not output.exists()
        and len(str(output)) + 128 < 200,
        "R24 evaluation output must be a fresh short C: child/root",
    )
    need(args.engine_sha256.upper() == sha256_file(Path(__file__).resolve()), "R24 source changed after inference freeze")
    summary_path = Path(args.inference_summary)
    gate_path = Path(args.inference_gate)
    population_path = Path(args.neutral_population)
    freeze_path = Path(args.freeze_manifest)
    need(same_windows_path(summary_path.parent, EXPECTED_INFERENCE_ROOT), "Inference summary root differs")
    need(same_windows_path(gate_path.parent, EXPECTED_INFERENCE_ROOT), "Inference gate root differs")
    need(
        same_windows_path(population_path.parent, EXPECTED_INFERENCE_ROOT / "neutral")
        and same_windows_path(freeze_path.parent, EXPECTED_INFERENCE_ROOT / "neutral"),
        "Frozen neutral root differs",
    )
    summary = load_json_pinned(summary_path, args.inference_summary_sha256, "R24 inference summary")
    gate = load_json_pinned(gate_path, args.inference_gate_sha256, "R24 inference gate")
    population = load_json_pinned(population_path, args.neutral_population_sha256, "R24 neutral population")
    freeze = load_json_pinned(freeze_path, args.freeze_manifest_sha256, "R24 freeze manifest")
    need(
        summary.get("schema") == SUMMARY_SCHEMA
        and summary.get("state") == "COMPLETE_DIAGNOSTIC_ONLY_R24_NEUTRAL_POPULATION_FROZEN"
        and summary.get("scorerLabelJsonParsed") is False
        and summary.get("candidatePopulationFrozenBeforeScorerLabelParse") is True,
        "R24 inference summary is not a clean pre-label freeze",
    )
    need(
        gate.get("schema") == GATE_SCHEMA
        and str(gate.get("state", "")).startswith("PASS_R24_NEUTRAL_POPULATION_FROZEN")
        and all(bool(value) for value in gate.get("integrityChecks", {}).values())
        and all(bool(value) for value in gate.get("semanticChecksBeforeLabels", {}).values())
        and gate.get("allRequiredSemanticChecksPassedBeforeLabelRead") is True
        and bool(gate.get("evaluationMayReadScorerLabelOnlyAfterRehashingFrozenPopulation")),
        "R24 inference integrity gate does not authorize post-freeze evaluation",
    )
    need(
        population.get("schema") == POPULATION_SCHEMA
        and population.get("scorerLabelJsonParsed") is False
        and population.get("candidatePopulationFrozenBeforeScorerLabelParse") is True,
        "R24 neutral population was not frozen before label evaluation",
    )
    need(
        freeze.get("schema") == FREEZE_SCHEMA
        and freeze.get("state") == "PASS_R24_COMPLETE_NEUTRAL_POPULATION_FILESET_FROZEN",
        "R24 freeze manifest is not PASS",
    )
    need(
        str(gate["summary"]["sha256"]).upper() == args.inference_summary_sha256.upper()
        and str(gate["neutralPopulation"]["sha256"]).upper() == args.neutral_population_sha256.upper()
        and str(gate["freezeManifest"]["sha256"]).upper() == args.freeze_manifest_sha256.upper(),
        "R24 gate does not bind the supplied frozen files",
    )

    neutral_root = population_path.parent
    actual_pre_freeze = [
        row for row in generated_inventory(neutral_root)
        if Path(row["path"]).resolve() != freeze_path.resolve()
    ]
    expected_pre_freeze = freeze.get("generatedFiles", [])
    need(actual_pre_freeze == expected_pre_freeze, "Neutral generated file inventory changed after freeze")
    rehash = verify_record_tree_before_label(summary, gate, population, freeze)
    current_lineage = verify_engine_lineage()
    need(current_lineage == summary.get("loadedDependencies"), "Loaded dependency lineage changed after freeze")
    need(
        sha256_file(Path(__file__).resolve()) == args.engine_sha256.upper(),
        "R24 source changed during frozen-population rehash",
    )

    # No scorer-label JSON is opened above this line.  The entire neutral
    # population, all nested assets/sources/dependencies, summary, and gate are
    # exact at this point.
    identities = {str(row["identity"]) for row in population["post2"]}
    need(len(identities) == 3, "Frozen POST2 identity cardinality changed")
    preflight_output_layout(output, identities, evaluation=True)
    all_existing_holds_retained = bool(
        population.get("semanticChecksBeforeLabels", {}).get("allPredecessorHoldsRetained")
        and population.get("hotspotRegression", {}).get("allExistingContourHoldsRetained")
        and all(
            row["pairDiagnostic"].get("inheritedR22OwnershipHoldsRetained")
            and row["pairDiagnostic"].get("resolvedPairCount") == 0
            for row in population["post2"]
        )
    )
    need(all_existing_holds_retained, "Frozen predecessor holds are not mechanically retained")
    labels_path = Path(args.scorer_labels)
    labels = load_json_pinned(labels_path, args.scorer_labels_sha256, "scorer-only labels")
    labeled_identity, chipout_angle = scorer_label_identity_angle(labels, identities)

    output.mkdir()
    cases_root = output / "cases"
    cases_root.mkdir()
    review_rows: list[dict[str, Any]] = []
    panel_rows: list[list[np.ndarray]] = []
    for result in population["post2"]:
        identity = str(result["identity"])
        case_root = cases_root / f"P{int(result['ordinal']):04d}"
        case_root.mkdir()
        panels: list[np.ndarray] = []
        channels: dict[str, Any] = {}
        for channel in ("BF", "DF"):
            frozen_channel = result["channels"][channel]
            clean_record = frozen_channel["assets"]["fullClean"]
            review_record = frozen_channel["assets"]["circleAndBrightnessReview"]
            clean = cv2.imread(str(clean_record["path"]), cv2.IMREAD_GRAYSCALE)
            review = cv2.imread(str(review_record["path"]), cv2.IMREAD_COLOR)
            need(clean is not None and review is not None and clean.shape == review.shape[:2], f"{identity} {channel} frozen review decode failed")
            clean_crop, columns = native_cyclic_crop(clean, chipout_angle, clean.shape[1])
            review_crop, review_columns = native_cyclic_crop(review, chipout_angle, review.shape[1])
            need(bool(np.array_equal(columns, review_columns)), "Evaluation crop columns differ")
            candidate_comparisons = [
                {
                    "candidateId": candidate["candidateId"],
                    "classification": candidate["classification"],
                    "centerAngleDegrees": candidate["centerAngleDegrees"],
                    "distanceFromPostFreezeScorerAngleDegrees": circular_distance_degrees(
                        float(candidate["centerAngleDegrees"]), chipout_angle
                    ),
                    "manufacturedCompatibleAfterContour": bool(
                        candidate.get("manufacturedCompatibleAfterContour")
                    ),
                }
                for candidate in frozen_channel["candidates"]
            ]
            stem = safe_stem(identity) + "_" + channel.lower() + "_postfreeze_chipout"
            label = (
                f"{identity} {channel} | POST-FREEZE scorer angle {chipout_angle:.6f} deg | "
                "CYAN fixed outer | YELLOW -20px | LIME native brightness | ORANGE native branch | MAGENTA hold"
            )
            labeled = labeled_native_crop(review_crop, label)
            assets = {
                "cleanNativeAnnularCrop": write_png_new(case_root / f"{stem}_clean.png", clean_crop),
                "reviewNativeAnnularCrop": write_png_new(case_root / f"{stem}_review.png", labeled),
            }
            channels[channel] = {
                "sourceColumnStart": int(columns[0]),
                "sourceColumnEnd": int(columns[-1]),
                "sourceColumnCount": int(columns.size),
                "cyclicWrapUsed": bool(columns[0] > columns[-1]),
                "nativeRadialPitchPx": 1.0,
                "resamplingPerformed": False,
                "pathCenteredWarpPerformed": False,
                "candidateComparisons": candidate_comparisons,
                "assets": assets,
            }
            panels.append(labeled)
        panel_rows.append(panels)
        review_rows.append(
            {
                "ordinal": int(result["ordinal"]),
                "identity": identity,
                "scorerRole": "POSITIVE_LABELED_MEMBER" if identity == labeled_identity else "SAME_ANGLE_CONTROL",
                "channels": channels,
            }
        )
    sheet = cv2.vconcat([cv2.hconcat(row) for row in panel_rows])
    sheet_asset = write_png_new(output / "POST2_R24_POSTFREEZE_SAME_ANGLE_NATIVE_COMPARISON.png", sheet)
    evaluation = {
        "schema": EVALUATION_SCHEMA,
        "state": "HOLD_R24_POSTFREEZE_OPERATOR_VISUAL_REVIEW_REQUIRED",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "engine": file_record(Path(__file__).resolve(), args.engine_sha256),
        "inferenceSummary": file_record(summary_path, args.inference_summary_sha256),
        "inferenceGate": file_record(gate_path, args.inference_gate_sha256),
        "neutralPopulation": file_record(population_path, args.neutral_population_sha256),
        "freezeManifest": file_record(freeze_path, args.freeze_manifest_sha256),
        "completeFrozenRecordRehashBeforeLabelParse": rehash,
        "scorerLabels": file_record(labels_path, args.scorer_labels_sha256),
        "labeledPositiveIdentity": labeled_identity,
        "postFreezeScorerAngleDegrees": chipout_angle,
        "comparisonRole": "SLOT01_LARGE_FRONTSIDE_CHIPOUT_VERSUS_SLOT03_SLOT17_SAME_ANGLE_CONTROLS",
        "channelRoles": {"DF": "DETECTION_EVIDENCE", "BF": "CORROBORATING_EVIDENCE_ONLY"},
        "results": review_rows,
        "comparisonSheet": sheet_asset,
        "reviewAngleConsumedByInference": False,
        "chipoutSelectionPerformed": False,
        "chipoutThresholdTuningPerformed": False,
        "candidateFilteringFromChipoutTruthPerformed": False,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "sourceMutationPerformed": False,
        "existingTaskOrProcessActionPerformed": False,
        "providerActivated": False,
        "holdClearancePerformed": False,
        "packageBuilt": False,
        "packageAttemptCount": 0,
        "operatorVisualReviewRequired": True,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    evaluation_asset = write_json_new(output / "SUMMARY.json", evaluation)
    gate_payload = {
        "schema": "argos_ocv03_annular_candidate_first_r24_post_label_evaluation_gate_v1",
        "state": "HOLD_R24_OPERATOR_VISUAL_REVIEW_READY_NO_PACKAGE",
        "summary": evaluation_asset,
        "comparisonSheet": sheet_asset,
        "allFrozenBytesRehashedBeforeLabelParse": True,
        "threePost2PairsRenderedAtSamePostFreezeAngle": len(review_rows) == 3,
        "allSixNativeCropsRenderedWithoutResampling": all(
            not row["channels"][channel]["resamplingPerformed"]
            for row in review_rows for channel in ("BF", "DF")
        ),
        "candidateSelectionOrTuningFromScorerLabelPerformed": False,
        "allExistingHoldsRetained": all_existing_holds_retained,
        "operatorVisualReviewRequired": True,
        "packageBuilt": False,
        "packageAttemptCount": 0,
        "reviewOnly": True,
        "productionEligible": False,
    }
    evaluation_gate_asset = write_json_new(output / "REVIEW_GATE.json", gate_payload)
    print(
        json.dumps(
            {
                "state": gate_payload["state"],
                "comparisonPath": sheet_asset["path"],
                "comparisonSha256": sheet_asset["sha256"],
                "summaryPath": evaluation_asset["path"],
                "summarySha256": evaluation_asset["sha256"],
                "gatePath": evaluation_gate_asset["path"],
                "gateSha256": evaluation_gate_asset["sha256"],
            },
            separators=(",", ":"),
        )
    )
    return 0


def run_self_check() -> int:
    source = Path(__file__).read_text(encoding="utf-8")
    for forbidden in (
        "cyclic_" + "open_1d(",
        "close_small_" + "circular_gaps(",
        "cv2." + "morphologyEx(",
        "cv2." + "INTER_LINEAR",
        "cv2." + "INTER_CUBIC",
    ):
        need(forbidden not in source, f"Forbidden R24 candidate operation is present: {forbidden}")
    need("--scorer-labels" not in source.split("def run_inference", 1)[1].split("def run_evaluation", 1)[0], "Inference implementation exposes scorer labels")
    require_exact_file(
        PROJECT_ROOT / "work" / "FRONTSIDE_INSPECTION_REVIEW_ONLY"
        / "OCV03_O3F16R23_R24_ROLLOVER_20260904.md",
        CHECKPOINT_SHA256,
        "R24 checkpoint",
    )
    require_exact_file(PROJECT_ROOT / "work" / "O3F16R23_ROLLOVER.json", ROLLOVER_MANIFEST_SHA256, "R24 rollover manifest")
    require_exact_file(PROJECT_ROOT / "work" / "O3F16R23_ROLLOVER_GATE.json", ROLLOVER_GATE_SHA256, "R24 rollover gate")
    verify_engine_lineage()
    inherited = load_r22_inherited_post2_authority()
    need(
        inherited["r22OwnershipHoldCount"] == 6
        and inherited["r22CyanHoldCount"] == 5
        and inherited["r23JsonParsedBeforeNeutralFreeze"] is False,
        "Inherited R22/R23 hold contract differs",
    )

    width = 101
    search_offsets = np.arange(-50, 11, dtype=np.float32)
    strip = np.zeros((search_offsets.size, width), dtype=np.uint8)
    support = np.zeros((search_offsets.size, width), dtype=bool)
    raw = np.zeros_like(support, dtype=np.float32)
    enhanced = np.zeros_like(support, dtype=np.float32)
    outer = np.zeros(width, dtype=np.float32)
    normal = np.full(width, -20.0, dtype=np.float32)
    normal_observed = np.ones(width, dtype=bool)
    deep = np.full(width, -20.0, dtype=np.float32)
    component = np.arange(40, 61, dtype=np.int64)
    core = np.arange(48, 53, dtype=np.int64)
    curve: dict[int, float] = {}
    for column in range(39, 62):
        depth = 20.0 + max(0.0, 15.0 - 1.5 * abs(column - 50))
        curve[column] = -depth
        deep[column] = -depth
    for column in range(width):
        value = curve.get(column, -20.0)
        row = int(np.argmin(np.abs(search_offsets - value)))
        support[row, column] = True
        raw[row, column] = 12.0
        enhanced[row, column] = 24.0
        image_row = int(round(float(search_offsets[row] - search_offsets[0])))
        strip[: image_row + 1, column] = 180
        strip[image_row + 1 :, column] = 20
    transition = {
        "searchOffsets": search_offsets,
        "frontierSupported": support,
        "nativeSupported": support,
        "rawContrast": raw,
        "directRawContrast": raw,
        "enhancedContrast": enhanced,
    }
    params = argparse.Namespace(
        manufactured_maximum_width_degrees=90.0,
        manufactured_minimum_width_degrees=1.0,
        manufactured_maximum_tip_offset_fraction=0.7,
        manufactured_minimum_slope_consistency=0.55,
        manufactured_minimum_symmetry=0.5,
    )
    synthetic_discovery = discover_raw_candidate_components(
        transition,
        np.zeros(width, dtype=bool),
        outer,
        {"minimumNotchDepthPx": 20.0, "noiseSigmaThreshold": 4.5},
    )
    need(len(synthetic_discovery["components"]) == 1, "Synthetic 2-D discovery did not retain one candidate")
    trace = candidate_graph_trace(
        strip,
        search_offsets,
        outer,
        normal,
        normal_observed,
        transition,
        synthetic_discovery["components"][0],
        float(synthetic_discovery["thresholdPx"]),
        params,
        0,
        "BF",
        np.zeros(width, dtype=bool),
        np.zeros(width, dtype=bool),
    )
    need(trace["record"].get("completeNativeShoulderPath"), "Synthetic native graph did not reach both shoulders")
    need(trace["record"].get("allSelectedPixelsNativeSupported"), "Synthetic trace selected unsupported coordinates")
    need(not trace["record"].get("interpolationPerformed"), "Synthetic trace interpolated coordinates")

    broken_support = support.copy()
    broken_raw = raw.copy()
    broken_enhanced = enhanced.copy()
    broken_component = dict(synthetic_discovery["components"][0])
    broken_component["componentRows"] = {
        int(column): list(rows)
        for column, rows in synthetic_discovery["components"][0]["componentRows"].items()
    }
    broken_component["coreRows"] = {
        int(column): list(rows)
        for column, rows in synthetic_discovery["components"][0]["coreRows"].items()
    }
    far_row = 0
    for column in (49, 50):
        broken_support[:, column] = False
        broken_raw[:, column] = 0.0
        broken_enhanced[:, column] = 0.0
        broken_support[far_row, column] = True
        broken_raw[far_row, column] = 12.0
        broken_enhanced[far_row, column] = 24.0
        broken_component["componentRows"][column] = [far_row]
        broken_component["coreRows"][column] = [far_row]
    broken_transition = dict(transition)
    broken_transition["nativeSupported"] = broken_support
    broken_transition["rawContrast"] = broken_raw
    broken_transition["directRawContrast"] = broken_raw
    broken_transition["enhancedContrast"] = broken_enhanced
    held_trace = candidate_graph_trace(
        strip,
        search_offsets,
        outer,
        normal,
        normal_observed,
        broken_transition,
        broken_component,
        float(synthetic_discovery["thresholdPx"]),
        params,
        0,
        "BF",
        np.zeros(width, dtype=bool),
        np.zeros(width, dtype=bool),
    )
    need(
        held_trace["record"]["state"] == "HOLD_NO_CORE_VISITING_NATIVE_SHOULDER_TO_SHOULDER_PATH",
        "Synthetic broken graph did not retain its unresolved hold",
    )
    need(
        bool(held_trace["record"]["rawComponentNativeNodes"])
        and bool(held_trace["supportPoints"]),
        "Synthetic unresolved component lost its rendered native evidence",
    )
    need(
        candidate_metric_schema_valid(held_trace["record"]),
        "Synthetic unresolved component lacks its complete no-fill metric schema",
    )
    need(
        candidate_metric_schema_valid(trace["record"]),
        "Synthetic complete component lacks its complete metric schema",
    )
    print(json.dumps({"state": "PASS_R24_MINIMAL_SOURCE_SELF_CHECK", "engineSha256": sha256_file(Path(__file__).resolve())}, separators=(",", ":")))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("self-check")

    infer = commands.add_parser("infer")
    infer.add_argument("--workspace-root", required=True)
    infer.add_argument("--workspace-io-root", required=True)
    infer.add_argument("--code-root", required=True)
    infer.add_argument("--checkpoint", required=True)
    infer.add_argument("--checkpoint-sha256", required=True)
    infer.add_argument("--rollover-manifest", required=True)
    infer.add_argument("--rollover-manifest-sha256", required=True)
    infer.add_argument("--rollover-gate", required=True)
    infer.add_argument("--rollover-gate-sha256", required=True)
    infer.add_argument("--source-job", required=True)
    infer.add_argument("--source-job-sha256", required=True)
    infer.add_argument("--geometry-job", required=True)
    infer.add_argument("--geometry-job-sha256", required=True)
    infer.add_argument("--hotspot-input", required=True)
    infer.add_argument("--hotspot-input-sha256", required=True)
    infer.add_argument("--hotspot-oracle", required=True)
    infer.add_argument("--hotspot-oracle-sha256", required=True)
    infer.add_argument("--hotspot-oracle-gate", required=True)
    infer.add_argument("--hotspot-oracle-gate-sha256", required=True)
    infer.add_argument("--output-root", required=True)

    evaluate = commands.add_parser("evaluate")
    evaluate.add_argument("--engine-sha256", required=True)
    evaluate.add_argument("--inference-summary", required=True)
    evaluate.add_argument("--inference-summary-sha256", required=True)
    evaluate.add_argument("--inference-gate", required=True)
    evaluate.add_argument("--inference-gate-sha256", required=True)
    evaluate.add_argument("--neutral-population", required=True)
    evaluate.add_argument("--neutral-population-sha256", required=True)
    evaluate.add_argument("--freeze-manifest", required=True)
    evaluate.add_argument("--freeze-manifest-sha256", required=True)
    evaluate.add_argument("--scorer-labels", required=True)
    evaluate.add_argument("--scorer-labels-sha256", required=True)
    evaluate.add_argument("--output-root", required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.command == "self-check":
        return run_self_check()
    if args.command == "infer":
        return run_inference(args)
    if args.command == "evaluate":
        return run_evaluation(args)
    raise RuntimeError(f"Unknown R24 command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
