#!/usr/bin/env python3
"""Diagnostic-only native-pitch two-zone annular reference for frozen frontside pairs."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import sys
from typing import Any

import cv2
import numpy as np


HERE = Path(__file__).resolve().parent

TANGENTIAL_SAMPLE_PITCH_PX = 1.0
REFERENCE_CORE_INWARD_PX = 32.0
REFERENCE_CORE_OUTWARD_PX = 16.0
REFERENCE_TRACK_RADIUS_PX = 12.0
REFERENCE_TANGENTIAL_SUPPORT_PX = 17
REFERENCE_MIN_SUPPORT_FRACTION = 0.35
REFERENCE_MEDIAN_WINDOW_PX = 31
REFERENCE_MAX_LOCAL_DEVIATION_PX = 5.0
REFERENCE_PATH_SMOOTHING_PX = 9
REVIEW_SEGMENT_WIDTH_PX = 2048
REVIEW_SEGMENT_HEADER_PX = 24


def need(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    need(spec is not None and spec.loader is not None, f"Cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


R11 = load("argos_annular_r11", HERE / "FullPerimeterWaferTopologyOpenCvR11.py")
FRONT = load("argos_annular_front", HERE / "Run-O3F15FrontReconcile.py")


def atomic_json(path: Path, value: dict[str, Any]) -> None:
    data = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
    partial = Path(str(path) + ".partial")
    need(not path.exists() and not partial.exists(), f"Refusing overwrite: {path}")
    partial.write_bytes(data)
    os.replace(partial, path)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def cyclic_path(
    contrast: np.ndarray,
    offsets: np.ndarray,
    minimum_contrast: float,
    relative_contrast: float,
    tangential_pitch: float,
) -> tuple[np.ndarray, np.ndarray, dict[str, Any]]:
    columns = int(contrast.shape[1])
    core_rows = (offsets >= -REFERENCE_CORE_INWARD_PX) & (offsets <= REFERENCE_CORE_OUTWARD_PX)
    need(bool(np.any(core_rows)), "Reference core contains no contrast rows")
    core_contrast = contrast[core_rows]
    core_offsets = offsets[core_rows]
    core_maxima = np.max(core_contrast, axis=0)
    nominal_floor = max(minimum_contrast, float(np.percentile(core_maxima, 20.0)) * relative_contrast)

    row_response = np.median(core_contrast, axis=1)
    row_support = np.mean(core_contrast >= nominal_floor, axis=1)
    row_scores = row_response + nominal_floor * row_support
    nominal_ties = np.flatnonzero(np.isclose(row_scores, np.max(row_scores)))
    nominal_index = int(nominal_ties[np.argmin(np.abs(core_offsets[nominal_ties]))])
    nominal = float(core_offsets[nominal_index])
    need(
        nominal - REFERENCE_TRACK_RADIUS_PX >= -REFERENCE_CORE_INWARD_PX
        and nominal + REFERENCE_TRACK_RADIUS_PX <= REFERENCE_CORE_OUTWARD_PX,
        "Nominal reference tracking lane is truncated by the fixed-fit core",
    )

    lane = np.abs(core_offsets - nominal) <= REFERENCE_TRACK_RADIUS_PX
    lane_maxima = np.max(core_contrast[lane], axis=0)
    floor = max(minimum_contrast, float(np.percentile(lane_maxima, 20.0)) * relative_contrast)
    thresholds = np.maximum(floor, lane_maxima * relative_contrast)
    lane_eligible = (core_contrast >= thresholds[None, :]) & lane[:, None]
    half_support = REFERENCE_TANGENTIAL_SUPPORT_PX // 2
    wrapped = np.concatenate((lane_eligible[:, -half_support:], lane_eligible, lane_eligible[:, :half_support]), axis=1)
    support = cv2.blur(wrapped.astype(np.float32), (REFERENCE_TANGENTIAL_SUPPORT_PX, 1))[:, half_support:-half_support]
    normalized = np.clip(core_contrast / np.maximum(lane_maxima, 1.0)[None, :], 0.0, 1.0)
    scores = 3.0 * normalized + 2.0 * support - 0.12 * np.abs(core_offsets[:, None] - nominal)
    state_eligible = lane_eligible & (support >= REFERENCE_MIN_SUPPORT_FRACTION)
    scores[~state_eligible] = -np.inf
    selected = np.argmax(scores, axis=0)
    raw = core_offsets[selected].astype(np.float64)
    prefiltered = np.any(state_eligible, axis=0)
    raw[~prefiltered] = np.nan

    half_median = REFERENCE_MEDIAN_WINDOW_PX // 2
    windows = np.lib.stride_tricks.sliding_window_view(
        np.pad(raw, (half_median, half_median), mode="wrap"), REFERENCE_MEDIAN_WINDOW_PX
    )
    valid_counts = np.sum(np.isfinite(windows), axis=1)
    local_medians = np.ma.median(np.ma.masked_invalid(windows), axis=1).filled(np.nan)
    measured = (
        prefiltered
        & (valid_counts >= REFERENCE_MEDIAN_WINDOW_PX // 4)
        & (np.abs(raw - local_medians) <= REFERENCE_MAX_LOCAL_DEVIATION_PX)
    )

    measured_columns = np.flatnonzero(measured)
    interpolation_constructible = measured_columns.size >= 2
    if interpolation_constructible:
        interpolation_columns = np.concatenate(
            ((measured_columns[-1:] - columns), measured_columns, (measured_columns[:1] + columns))
        )
        interpolation_values = np.concatenate(
            (raw[measured_columns[-1:]], raw[measured_columns], raw[measured_columns[:1]])
        )
        path = np.interp(np.arange(columns), interpolation_columns, interpolation_values)
    else:
        path = np.full(columns, nominal, dtype=np.float64)
    half_smoothing = REFERENCE_PATH_SMOOTHING_PX // 2
    path_windows = np.lib.stride_tricks.sliding_window_view(
        np.pad(path, (half_smoothing, half_smoothing), mode="wrap"), REFERENCE_PATH_SMOOTHING_PX
    )
    path = np.median(path_windows, axis=1).astype(np.float32)
    imputed = ~measured
    imputed_runs = runs(imputed)
    if len(imputed_runs) > 1 and bool(imputed[0]) and bool(imputed[-1]):
        wrapped_run = np.concatenate((imputed_runs[-1], imputed_runs[0] + columns))
        imputed_runs = [wrapped_run, *imputed_runs[1:-1]]
    gap_rows = [
        {
            "startColumn": int(run[0]),
            "endColumnExclusive": int((run[-1] + 1) % columns),
            "columnCount": int(run.size),
            "startDegrees": float(run[0] * 360.0 / columns),
            "endDegrees": float(((run[-1] + 1) % columns) * 360.0 / columns),
            "centerDegrees": float(((run[0] + run.size * 0.5) % columns) * 360.0 / columns),
        }
        for run in sorted(imputed_runs, key=lambda item: item.size, reverse=True)[:8]
    ]
    jumps = np.abs(path - np.roll(path, 1))
    old_thresholds = np.maximum(nominal_floor, core_maxima * relative_contrast)
    old_lane_eligible = np.any((core_contrast >= old_thresholds[None, :]) & lane[:, None], axis=0)
    return path, measured, {
        "method": "NARROW_CORE_TRACKING_LANE_QUALIFIED_REFERENCE_WITH_CYCLIC_INTERPOLATION",
        "coreInwardPx": REFERENCE_CORE_INWARD_PX,
        "coreOutwardPx": REFERENCE_CORE_OUTWARD_PX,
        "trackingRadiusPx": REFERENCE_TRACK_RADIUS_PX,
        "tangentialSupportWidthPx": REFERENCE_TANGENTIAL_SUPPORT_PX,
        "minimumTangentialSupportFraction": REFERENCE_MIN_SUPPORT_FRACTION,
        "localMedianWidthPx": REFERENCE_MEDIAN_WINDOW_PX,
        "maximumLocalDeviationPx": REFERENCE_MAX_LOCAL_DEVIATION_PX,
        "nominalReferenceOffsetPx": nominal,
        "nominalContrastFloor": nominal_floor,
        "referenceContrastFloor": floor,
        "qualificationPopulation": "NOMINAL_TRACKING_LANE_ONLY",
        "offLaneMaximumVetoAvoidedColumnCount": int(np.count_nonzero(prefiltered & ~old_lane_eligible)),
        "prefilteredMeasuredColumnCount": int(np.count_nonzero(prefiltered)),
        "tangentialSupportRejectedColumnCount": int(np.count_nonzero(np.any(lane_eligible, axis=0) & ~prefiltered)),
        "localMedianRejectedColumnCount": int(np.count_nonzero(prefiltered & ~measured)),
        "referenceQualificationPerformed": False,
        "referenceInterpolationConstructible": bool(interpolation_constructible),
        "referenceState": (
            "DIAGNOSTIC_REFERENCE_INTERPOLATED"
            if interpolation_constructible
            else "HOLD_INSUFFICIENT_REFERENCE_MEASUREMENTS"
        ),
        "measuredColumnCount": int(np.count_nonzero(measured)),
        "measuredColumnFraction": float(np.mean(measured)),
        "imputedColumnCount": int(np.count_nonzero(imputed)),
        "maximumCircularImputedRunColumns": int(gap_rows[0]["columnCount"] if gap_rows else 0),
        "maximumCircularImputedRunArcPx": float(gap_rows[0]["columnCount"] * tangential_pitch if gap_rows else 0.0),
        "largestImputedRuns": gap_rows,
        "maximumCyclicJumpPx": float(np.max(jumps)),
        "p95CyclicJumpPx": float(np.percentile(jumps, 95.0)),
        "imputedBridgeConstruction": (
            "LINEAR_BETWEEN_NEAREST_ACCEPTED_CYCLIC_MEASUREMENTS_THEN_MEDIAN_SMOOTHED"
            if interpolation_constructible
            else "CONSTANT_NOMINAL_HOLD_ONLY_NO_DATA_DRIVEN_BRIDGE"
        ),
        "imputedBridgeEligibleAsNotchOrDamageEvidence": False,
        "notchSelectionPerformed": False,
        "holderClassificationPerformed": False,
    }


def unwrap(gray: np.ndarray, fit: dict[str, Any], crop: dict[str, Any], params: Any, cfg: dict[str, Any]) -> dict[str, Any]:
    source_inward, source_outward = int(crop["inwardPx"]), int(crop["outwardPx"])
    maximum_inward = float(cfg["maximumInwardPx"])
    maximum_outward = float(cfg["maximumOutwardPx"])
    need(math.isfinite(maximum_inward) and maximum_inward > 0.0, "Invalid operational inward annulus")
    need(math.isfinite(maximum_outward) and maximum_outward > 0.0, "Invalid operational outward annulus")
    inward, outward = int(math.ceil(maximum_inward)), int(math.ceil(maximum_outward))
    smoothing = max(1, int(round(float(params.radial_smoothing_width_px))))
    smoothing += 1 - smoothing % 2
    span = max(1, int(round(float(params.radial_contrast_span_px))))
    halo = int(math.ceil(span * 0.5)) + smoothing // 2
    need(inward + halo <= source_inward, "Operational inward annulus exceeds source crop")
    need(outward + halo <= source_outward, "Operational outward annulus exceeds source crop")
    sampled_offsets = np.arange(-(inward + halo), outward + halo + 1, dtype=np.float32)
    samples = int(math.ceil(2.0 * math.pi * float(fit["radius"]) / TANGENTIAL_SAMPLE_PITCH_PX))
    need(4096 <= samples < 32767, "Native-pitch annular sample count exceeds OpenCV remap dimensions")
    tangential_pitch = 2.0 * math.pi * float(fit["radius"]) / samples
    angles = np.linspace(0.0, 2.0 * math.pi, samples, endpoint=False, dtype=np.float32)
    radii = float(fit["radius"]) + sampled_offsets
    map_x = float(fit["centerX"]) + radii[:, None] * np.cos(angles)[None, :]
    map_y = float(fit["centerY"]) + radii[:, None] * np.sin(angles)[None, :]
    sampled = cv2.remap(gray, map_x, map_y, cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT, borderValue=0)

    smooth = cv2.blur(sampled.astype(np.float32), (1, smoothing))
    need(span < sampled.shape[0], "Radial contrast span consumes annular strip")
    contrast = smooth[:-span] - smooth[span:]
    middle_offsets = (sampled_offsets[:-span] + sampled_offsets[span:]) * 0.5
    analysis_rows = (middle_offsets >= -maximum_inward) & (middle_offsets <= maximum_outward)
    need(bool(np.any(analysis_rows)), "Operational annulus contains no contrast rows")
    contrast = contrast[analysis_rows]
    middle_offsets = middle_offsets[analysis_rows]
    visible_rows = (sampled_offsets >= -maximum_inward) & (sampled_offsets <= maximum_outward)
    strip = sampled[visible_rows]
    offsets = sampled_offsets[visible_rows]
    maxima = np.max(contrast, axis=0)
    floor = max(
        float(params.minimum_boundary_contrast),
        float(np.percentile(maxima, 20.0)) * float(params.outer_edge_relative_contrast),
    )
    thresholds = np.maximum(floor, maxima * float(params.outer_edge_relative_contrast))
    eligible = contrast >= thresholds[None, :]
    counts = np.count_nonzero(eligible, axis=0).astype(np.int32)
    separation = np.zeros(samples, dtype=np.float32)
    supported = counts > 0
    if np.any(supported):
        first = np.argmax(eligible, axis=0)
        last = eligible.shape[0] - 1 - np.argmax(eligible[::-1], axis=0)
        separation[supported] = middle_offsets[last[supported]] - middle_offsets[first[supported]]
    path, path_measured, path_evidence = cyclic_path(
        contrast,
        middle_offsets,
        float(params.minimum_boundary_contrast),
        float(params.outer_edge_relative_contrast),
        tangential_pitch,
    )
    paths = {"cyclic": path}

    edge_rows = (offsets >= -REFERENCE_CORE_INWARD_PX) & (offsets <= REFERENCE_CORE_OUTWARD_PX)
    edge_strip = strip[edge_rows]
    edge_offsets = offsets[edge_rows]
    map_normalized_x = np.broadcast_to(
        np.arange(samples, dtype=np.float32)[None, :], (edge_offsets.size, samples)
    ).copy()
    map_normalized_y = (
        -float(offsets[0]) + path[None, :] + edge_offsets[:, None]
    ).astype(np.float32)
    normalized_strip = cv2.remap(
        strip,
        map_normalized_x,
        map_normalized_y,
        cv2.INTER_NEAREST,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0,
    )
    deep_rows = middle_offsets < -REFERENCE_CORE_INWARD_PX
    evidence = {
        "method": "NATIVE_PITCH_TWO_ZONE_ANNULAR_REFERENCE_DIAGNOSTIC",
        "angleSampleCount": samples,
        "degreesPerSample": 360.0 / samples,
        "requestedLegacyAngleSampleCount": int(params.refine_angle_samples),
        "tangentialSamplePitchPx": tangential_pitch,
        "inwardPx": inward,
        "outwardPx": outward,
        "sourceCropInwardPx": source_inward,
        "sourceCropOutwardPx": source_outward,
        "filterHaloPx": halo,
        "analysisRadialRowCount": int(contrast.shape[0]),
        "contrastPopulation": "FULL_CHIPOUT_EVIDENCE_ENVELOPE",
        "diagnosticStripPopulation": "FIXED_FIT_REFERENCE_CORE_ONLY",
        "fixedFitCoreInwardPx": int(REFERENCE_CORE_INWARD_PX),
        "fixedFitCoreOutwardPx": int(REFERENCE_CORE_OUTWARD_PX),
        "fixedFitCoreRadialRowCount": int(edge_offsets.size),
        "nativeScaleReviewSegmentWidthPx": REVIEW_SEGMENT_WIDTH_PX,
        "nativeScaleReviewSegmentCount": int(math.ceil(samples / REVIEW_SEGMENT_WIDTH_PX)),
        "nativeScaleReviewResamplingPerformed": False,
        "chipoutEvidenceEnvelopeInwardPx": inward,
        "chipoutEvidenceEnvelopeOutwardPx": outward,
        "chipoutEnvelopeUsedForReferenceSelection": False,
        "deepEnvelopeTransitionRowCount": int(np.count_nonzero(deep_rows)),
        "deepEnvelopeSupportedColumnCount": int(np.count_nonzero(np.any(eligible[deep_rows], axis=0))),
        "radialInterpolation": "INTER_NEAREST",
        "fixedFitEdgeDiagnosticResamplingPerformed": False,
        "normalizedInspectionDiagnosticInterpolation": "INTER_NEAREST",
        "radialSmoothingWidthPx": smoothing,
        "radialContrastSpanPx": span,
        "adaptiveContrastFloor": floor,
        "supportedColumnCount": int(np.count_nonzero(counts)),
        "multipleTransitionColumnCount": int(np.count_nonzero(counts > 1)),
        "multipleTransitionColumnFraction": float(np.mean(counts > 1)),
        "maximumTransitionsInOneColumn": int(np.max(counts)),
        "p95TransitionCount": float(np.percentile(counts, 95.0)),
        "p95ExternalTransitionSeparationPx": float(np.percentile(separation, 95.0)),
        "notchSelectionPerformed": False,
        "holderClassificationPerformed": False,
        "referencePathUsedAsPrimaryDiagnosticWarp": False,
        "referencePathUsedAsSeparateNormalizedTextureDiagnosticWarp": True,
        "imputedReferenceSegmentsUsedAsNotchOrDamageEvidence": False,
        "cyclicPath": path_evidence,
    }
    return {
        "strip": strip,
        "offsets": offsets,
        "edgeStrip": edge_strip,
        "normalizedStrip": normalized_strip,
        "edgeOffsets": edge_offsets,
        "paths": paths,
        "pathMeasured": path_measured,
        "evidence": evidence,
    }


def runs(mask: np.ndarray) -> list[np.ndarray]:
    padded = np.pad(mask.astype(np.uint8), (1, 1))
    changes = np.diff(padded)
    starts, ends = np.flatnonzero(changes == 1), np.flatnonzero(changes == 255)
    return [np.arange(start, end, dtype=np.int32) for start, end in zip(starts, ends)]


def segmented_review(image: np.ndarray, legend: str) -> np.ndarray:
    height, width = image.shape[:2]
    segment_count = int(math.ceil(width / REVIEW_SEGMENT_WIDTH_PX))
    shape = (segment_count * (height + REVIEW_SEGMENT_HEADER_PX), REVIEW_SEGMENT_WIDTH_PX) + image.shape[2:]
    sheet = np.zeros(shape, dtype=image.dtype)
    text_color: int | tuple[int, int, int] = 255 if image.ndim == 2 else (255, 255, 255)
    for segment in range(segment_count):
        start = segment * REVIEW_SEGMENT_WIDTH_PX
        end = min(width, start + REVIEW_SEGMENT_WIDTH_PX)
        top = segment * (height + REVIEW_SEGMENT_HEADER_PX)
        start_degrees = start * 360.0 / width
        end_degrees = end * 360.0 / width
        label = f"{legend} | arc {start}:{end - 1}px | {start_degrees:.3f}-{end_degrees:.3f}deg"
        cv2.putText(sheet, label, (5, top + 16), cv2.FONT_HERSHEY_SIMPLEX, 0.38, text_color, 1, cv2.LINE_8)
        sheet[top + REVIEW_SEGMENT_HEADER_PX : top + REVIEW_SEGMENT_HEADER_PX + height, : end - start] = image[:, start:end]
    return sheet


def render(root: Path, pair_id: str, channel: str, measured: dict[str, Any]) -> dict[str, Any]:
    strip = measured["edgeStrip"]
    enhanced = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(16, 8)).apply(strip)
    overlay = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    mask = np.zeros(strip.shape, dtype=np.uint8)
    zero = int(np.argmin(np.abs(measured["edgeOffsets"])))
    cv2.line(overlay, (0, zero), (strip.shape[1] - 1, zero), (0, 200, 0), 1, cv2.LINE_8)
    cv2.line(mask, (0, zero), (strip.shape[1] - 1, zero), 255, 1, cv2.LINE_8)
    for supported, color in (
        (measured["pathMeasured"], (0, 0, 255)),
        (~measured["pathMeasured"], (255, 0, 255)),
    ):
        for run in runs(supported):
            if run.size >= 2:
                points = np.column_stack(
                    (run, np.rint(zero + measured["paths"]["cyclic"][run]).astype(np.int32))
                ).astype(np.int32)
                cv2.polylines(overlay, [points], False, color, 1, cv2.LINE_8)
                cv2.polylines(mask, [points], False, 255, 1, cv2.LINE_8)
    legend = "FIXED-FIT CORE | GREEN fit | RED accepted reference support | MAGENTA non-evidence bridge"
    edge_review = segmented_review(overlay, legend)

    normalized_strip = measured["normalizedStrip"]
    normalized_overlay = cv2.cvtColor(
        cv2.createCLAHE(clipLimit=2.0, tileGridSize=(16, 8)).apply(normalized_strip), cv2.COLOR_GRAY2BGR
    )
    normalized_zero = int(np.argmin(np.abs(measured["edgeOffsets"])))
    normalized_fixed = -measured["paths"]["cyclic"]
    normalized_fixed_points = np.column_stack(
        (np.arange(normalized_strip.shape[1]), np.rint(normalized_zero + normalized_fixed).astype(np.int32))
    ).astype(np.int32)
    cv2.polylines(normalized_overlay, [normalized_fixed_points], False, (0, 200, 0), 1, cv2.LINE_8)
    for supported, color in (
        (measured["pathMeasured"], (0, 0, 255)),
        (~measured["pathMeasured"], (255, 0, 255)),
    ):
        for run in runs(supported):
            if run.size >= 2:
                points = np.column_stack((run, np.full(run.size, normalized_zero))).astype(np.int32)
                cv2.polylines(normalized_overlay, [points], False, color, 1, cv2.LINE_8)
    normalized_review = segmented_review(
        normalized_overlay,
        "PATH-CENTERED TEXTURE DIAGNOSTIC; GREEN SHOWS ORIGINAL FIXED CIRCLE",
    )

    damage_strip = measured["strip"]
    damage_overlay = cv2.cvtColor(
        cv2.createCLAHE(clipLimit=2.0, tileGridSize=(16, 8)).apply(damage_strip), cv2.COLOR_GRAY2BGR
    )
    damage_zero = int(np.argmin(np.abs(measured["offsets"])))
    cv2.line(damage_overlay, (0, damage_zero), (damage_strip.shape[1] - 1, damage_zero), (0, 200, 0), 1, cv2.LINE_8)
    for supported, color in (
        (measured["pathMeasured"], (0, 0, 255)),
        (~measured["pathMeasured"], (255, 0, 255)),
    ):
        for run in runs(supported):
            if run.size >= 2:
                points = np.column_stack(
                    (run, np.rint(damage_zero + measured["paths"]["cyclic"][run]).astype(np.int32))
                ).astype(np.int32)
                cv2.polylines(damage_overlay, [points], False, color, 1, cv2.LINE_8)
    damage_review = segmented_review(
        damage_overlay,
        "FULL 180-IN/55-OUT CLAHE GEOMETRY; REFERENCE SELECTION EXCLUDED",
    )

    top = 28
    overlay = cv2.copyMakeBorder(overlay, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    mask = cv2.copyMakeBorder(mask, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    cv2.putText(overlay, legend, (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.43, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(mask, legend, (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.43, 255, 1, cv2.LINE_8)
    stem = hashlib.sha256(pair_id.encode("utf-8")).hexdigest()[:16]
    assets: dict[str, Any] = {}
    for role, image in (
        ("clean", strip),
        ("overlay", overlay),
        ("mask", mask),
        ("edge_review", edge_review),
        ("normalized_review", normalized_review),
        ("damage_review", damage_review),
    ):
        path = root / f"{stem}_{channel.lower()}_annular_{role}.png"
        need(cv2.imwrite(str(path), image), f"OpenCV write failed: {path}")
        assets[role] = {"path": str(path), "bytes": path.stat().st_size, "sha256": sha256(path)}
    return assets


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--safe-id", action="append", required=True)
    parser.add_argument("--output-root", required=True)
    args = parser.parse_args()
    need(1 <= len(args.safe_id) <= 12 and len(set(args.safe_id)) == len(args.safe_id), "Require 1-12 unique safe IDs")
    output = Path(args.output_root)
    need(output.is_absolute() and output.drive.upper() == "D:" and not output.exists(), "Output must be a fresh JBOD D: root")
    need(len(str(output)) + 96 < 200, "Output path budget failed")

    context = FRONT.preflight_context()
    by_safe = {str(row["safeId"]): (row, plan) for row, plan in zip(context["cohorts"]["ordered978"], context["plans"])}
    need(all(safe_id in by_safe for safe_id in args.safe_id), "A requested safe ID is outside the frozen 978")
    output.mkdir()
    (output / "cases").mkdir()
    results: list[dict[str, Any]] = []
    for ordinal, safe_id in enumerate(args.safe_id, 1):
        row, plan = by_safe[safe_id]
        case_root = output / "cases" / f"C{ordinal:04d}"
        case_root.mkdir()
        alias_evidence = {"ordinal": ordinal, "identity": str(row["identity"]), "aliasDrive": context["o3f14"].ALIAS_DRIVE, "slotRoot": str(plan["slotRoot"])}
        try:
            with context["o3f14"].owned_case_alias(plan, alias_evidence):
                images: dict[str, np.ndarray] = {}
                for channel, key in (("BF", "bf"), ("DF", "df")):
                    path = Path(str(plan[key]["aliasPath"]))
                    need(R11.sha256_file(path) == str(plan[key]["sha256"]).upper(), f"{channel} source hash changed")
                    images[channel] = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
                    need(images[channel] is not None, f"{channel} OpenCV decode failed")
                base = R11.CORE.analyze_pair(safe_id, images["BF"], images["DF"], R11.parameters_from_job(context["canonicalFixed"]))
                channel_rows: dict[str, Any] = {}
                for channel in ("BF", "DF"):
                    fit = base[channel.lower()].get("fit")
                    need(isinstance(fit, dict), f"{channel} global fit unavailable")
                    measured = unwrap(images[channel], fit, context["canonicalFixed"]["crop"], R11.parameters_from_job(context["canonicalFixed"]), context["canonicalFixed"]["topologyConfig"])
                    channel_rows[channel] = {"fit": fit, "baseState": base[channel.lower()].get("state"), "baseCandidateCount": len(base[channel.lower()].get("candidates", [])), "annularEvidence": measured["evidence"], "assets": render(case_root, safe_id, channel, measured)}
            results.append({"ordinal": ordinal, "identity": str(row["identity"]), "safeId": safe_id, "state": "DIAGNOSTIC_ONLY_ANNULAR_UNWRAP_COMPLETE", "channels": channel_rows, "alias": alias_evidence})
        except Exception as exc:
            results.append({"ordinal": ordinal, "identity": str(row["identity"]), "safeId": safe_id, "state": "HOLD_ANNULAR_UNWRAP_ERROR", "error": f"{type(exc).__name__}: {str(exc)[:1200]}", "alias": alias_evidence})
    summary = {
        "schema": "argos_ocv03_annular_unwrap_diagnostic_v1",
        "state": "COMPLETE_DIAGNOSTIC_ONLY_ANNULAR_UNWRAP",
        "engineSha256": sha256(Path(__file__).resolve()),
        "requestedCount": len(args.safe_id),
        "completedCount": sum(row["state"] == "DIAGNOSTIC_ONLY_ANNULAR_UNWRAP_COMPLETE" for row in results),
        "results": results,
        "candidateSelectionPerformed": False,
        "selectorThresholdRelaxationPerformed": False,
        "sourceMutationPerformed": False,
        "providerActivated": False,
        "existingTaskOrProcessActionPerformed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    atomic_json(output / "SUMMARY.json", summary)
    print(json.dumps({"state": summary["state"], "completedCount": summary["completedCount"], "summaryPath": str(output / "SUMMARY.json"), "summarySha256": sha256(output / "SUMMARY.json")}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
