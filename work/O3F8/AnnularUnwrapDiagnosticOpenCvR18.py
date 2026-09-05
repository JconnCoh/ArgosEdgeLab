#!/usr/bin/env python3
"""R18 exterior-connected physical-circle, bevel-crest, and full-depth notch diagnostic.

The review geometry remains in the original fixed-fit annular coordinate frame.
Only a transition whose complete outward corridor remains connected to the
measured exterior guard may nominate the physical edge.  The farthest coherent
outer band adjusts the predecessor radius while retaining its independently
fitted center.  The inner edge-zone boundary is the same circle moved inward by
exactly 20 px.  Neither per-column evidence nor notch residuals may bend either
circle, and unsupported inner-pattern fallbacks remain holds.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys
from typing import Any

import cv2
import numpy as np


HERE = Path(__file__).resolve().parent
BASE_PATH = HERE / "AnnularUnwrapDiagnosticOpenCvR13.py"
SPEC = importlib.util.spec_from_file_location("argos_annular_diagnostic_r13_for_r18", BASE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load {BASE_PATH}")
r13 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = r13
SPEC.loader.exec_module(r13)
diagnostic = r13.diagnostic
CORE = diagnostic.R11.CORE


SHADOW_LIFT_PREFIX = (
    0, 12, 25, 37, 49, 62, 73, 85, 97, 108, 119, 129, 140, 150, 159, 168,
    176, 184, 192, 198, 205, 210, 215, 219, 222, 224, 226, 227, 228, 229,
    230, 231, 232, 233, 234, 235, 236, 237, 238, 238, 239, 240, 241, 242,
    243, 243, 244, 245, 246, 246, 247, 248, 249, 249, 250, 251, 251, 252,
    253, 253, 254, 255,
)
SHADOW_LIFT_LUT = np.asarray(
    SHADOW_LIFT_PREFIX + (255,) * (256 - len(SHADOW_LIFT_PREFIX)), dtype=np.uint8
)

SEARCH_MIN_OFFSET_PX = -175.0
SEARCH_MAX_OFFSET_PX = 45.0
RADIAL_INSIDE_SAMPLES = 3
RADIAL_OUTSIDE_SAMPLES = 3
TANGENTIAL_GAUSSIAN_SIGMA_PX = 3.0
RADIAL_GAUSSIAN_SIGMA_PX = 1.0
MINIMUM_ENHANCED_CONTRAST = 8.0
RELATIVE_ENHANCED_CONTRAST = 0.35
MINIMUM_RAW_POLARITY = 0.35
TANGENTIAL_SUPPORT_WIDTH_PX = 31
MINIMUM_TANGENTIAL_SUPPORT = 0.35
MINIMUM_GLOBAL_RIDGE_COVERAGE = 0.35
CIRCLE_TRACK_HALF_WIDTH_PX = 5.0
CIRCLE_REFINEMENT_PASSES = 2
CIRCLE_COVERAGE_BINS = 72
MINIMUM_CIRCLE_COVERAGE = 0.90
MINIMUM_CIRCLE_INLIER_FRACTION = 0.85
MAXIMUM_CIRCLE_RMS_RESIDUAL_PX = 3.10
MAXIMUM_CIRCLE_P90_RESIDUAL_PX = 5.0
EDGE_ZONE_INWARD_PX = 20.0
BEVEL_TRACE_LANE_HALF_WIDTH_PX = 8.0
BEVEL_TRACE_CALIBRATED_HALF_WIDTH_PX = 5.0
BEVEL_TRACE_MAX_ADJACENT_STEP_PX = 5.0
BEVEL_TRACE_DISCONTINUITY_PASSES = 32
MINIMUM_BEVEL_TRACE_COVERAGE = 0.85
HOLDER_OUTWARD_RESIDUAL_PX = 8.0
AMBIGUOUS_INWARD_RESIDUAL_PX = 8.0
NOTCH_INITIAL_GAUSSIAN_SIGMA_PX = 2.0
NOTCH_PATTERN_OPEN_WIDTH_PX = 13
NOTCH_FINAL_GAUSSIAN_SIGMA_PX = 3.0
NOTCH_SHOULDER_WIDTH_PX = 9
MINIMUM_NOTCH_SHOULDER_SUPPORT = 0.75
ZONE_REVIEW_INWARD_PX = 48.0
ZONE_REVIEW_OUTWARD_PX = 24.0
NOTCH_REVIEW_INWARD_PX = 180.0
NOTCH_REVIEW_OUTWARD_PX = 24.0
NOTCH_REVIEW_HALF_WIDTH_COLUMNS = 512
NOTCH_REVIEW_HEADER_PX = 32
HOLD_BAR_ROWS = 3

EXTERIOR_SEARCH_MIN_OFFSET_PX = -120
EXTERIOR_SEARCH_MAX_OFFSET_PX = 20
EXTERIOR_GUARD_MIN_OFFSET_PX = 24
EXTERIOR_GUARD_MAX_OFFSET_PX = 32
EXTERIOR_TANGENTIAL_MEDIAN_PX = 7
EXTERIOR_MIN_ENHANCED_SEPARATION = 4.0
EXTERIOR_GUARD_MAD_MULTIPLIER = 2.0
EXTERIOR_MIN_RAW_POLARITY = 0.35
EXTERIOR_OUTSIDE_MARGIN_FLOOR = 8.0
EXTERIOR_OUTSIDE_MARGIN_MAD_MULTIPLIER = 4.0
EXTERIOR_MIN_CORRIDOR_FRACTION = 0.70
EXTERIOR_RADIAL_SUSTAIN_PX = 3
EXTERIOR_TANGENTIAL_SUPPORT_PX = 31
EXTERIOR_MIN_TANGENTIAL_SUPPORT = 0.25
EXTERIOR_LOCAL_MEDIAN_PX = 31
EXTERIOR_MAX_LOCAL_DEVIATION_PX = 5.0
OUTER_BAND_HALF_WIDTH_PX = 3.0
MINIMUM_OUTER_BAND_COVERAGE = 0.50
MINIMUM_OUTER_BAND_FRACTION = 0.10
FINAL_ACCEPTED_RESIDUAL_PX = 1.5
MINIMUM_FINAL_ACCEPTED_COVERAGE = 0.35
MAXIMUM_FINAL_ADJACENT_RESIDUAL_JUMP_PX = 2.0
MINIMUM_CYAN_SEARCH_HEADROOM_PX = 3.0
MINIMUM_CYAN_ACCEPTED_COVERAGE = 0.40
MAXIMUM_NOTCH_MISSING_RUN_SAMPLES = 19


def shadow_lift(gray: np.ndarray) -> np.ndarray:
    """Apply the operator-provided monotonic curve without changing coordinates."""
    diagnostic.need(gray.dtype == np.uint8 and gray.ndim == 2, "R18 shadow lift requires uint8 grayscale")
    return cv2.LUT(gray, SHADOW_LIFT_LUT)


def cyclic_gaussian_image(gray: np.ndarray) -> np.ndarray:
    """Gaussian smooth with an explicit cyclic tangential halo."""
    radius = int(math.ceil(4.0 * TANGENTIAL_GAUSSIAN_SIGMA_PX))
    wrapped = np.concatenate((gray[:, -radius:], gray, gray[:, :radius]), axis=1)
    smoothed = cv2.GaussianBlur(
        wrapped.astype(np.float32),
        (0, 0),
        sigmaX=TANGENTIAL_GAUSSIAN_SIGMA_PX,
        sigmaY=RADIAL_GAUSSIAN_SIGMA_PX,
        borderType=cv2.BORDER_REFLECT_101,
    )
    return smoothed[:, radius:-radius]


def cyclic_horizontal_mean(values: np.ndarray, width: int) -> np.ndarray:
    diagnostic.need(width >= 1 and width % 2 == 1, "R18 support width must be positive and odd")
    half = width // 2
    wrapped = np.concatenate((values[:, -half:], values, values[:, :half]), axis=1)
    return cv2.blur(wrapped.astype(np.float32), (width, 1))[:, half:-half]


def cyclic_horizontal_median(gray: np.ndarray, width: int) -> np.ndarray:
    """Median filter tangentially with an exact cyclic halo and no resampling."""
    diagnostic.need(width >= 1 and width % 2 == 1, "R18 median width must be positive and odd")
    if width == 1:
        return gray.copy()
    half = width // 2
    wrapped = np.concatenate((gray[:, -half:], gray, gray[:, :half]), axis=1)
    windows = np.lib.stride_tricks.sliding_window_view(wrapped, width, axis=1)
    return np.median(windows, axis=-1).astype(np.uint8)


def exterior_connected_map(strip: np.ndarray, offsets: np.ndarray) -> dict[str, Any]:
    """Find outside-in transitions that stay connected to the exterior guard."""
    diagnostic.need(strip.dtype == np.uint8 and strip.ndim == 2, "R18 strip must be uint8 grayscale")
    diagnostic.need(offsets.shape == (strip.shape[0],), "R18 strip/offset mismatch")
    diagnostic.need(bool(np.allclose(np.diff(offsets), 1.0)), "R18 requires native one-pixel radial pitch")
    raw = cyclic_horizontal_median(strip, EXTERIOR_TANGENTIAL_MEDIAN_PX)
    enhanced = shadow_lift(raw)
    guard_rows = np.flatnonzero(
        (offsets >= EXTERIOR_GUARD_MIN_OFFSET_PX)
        & (offsets <= EXTERIOR_GUARD_MAX_OFFSET_PX)
    )
    search_rows = np.flatnonzero(
        (offsets >= EXTERIOR_SEARCH_MIN_OFFSET_PX)
        & (offsets <= EXTERIOR_SEARCH_MAX_OFFSET_PX)
    )
    diagnostic.need(guard_rows.size >= 3 and search_rows.size > 0, "R18 exterior guard/search is empty")
    diagnostic.need(
        int(search_rows[0]) >= EXTERIOR_RADIAL_SUSTAIN_PX - 1
        and int(search_rows[-1]) + 3 < int(guard_rows[0]),
        "R18 exterior search lacks its radial or guard corridor",
    )
    raw_guard = raw[guard_rows].astype(np.float32)
    enhanced_guard = enhanced[guard_rows].astype(np.float32)
    raw_guard_median = np.median(raw_guard, axis=0)
    enhanced_guard_median = np.median(enhanced_guard, axis=0)
    raw_guard_mad = np.median(np.abs(raw_guard - raw_guard_median[None, :]), axis=0)
    enhanced_guard_mad = np.median(
        np.abs(enhanced_guard - enhanced_guard_median[None, :]), axis=0
    )
    raw_tolerance = np.maximum(
        EXTERIOR_MIN_RAW_POLARITY,
        EXTERIOR_GUARD_MAD_MULTIPLIER * raw_guard_mad,
    )
    enhanced_floor = np.maximum(
        EXTERIOR_MIN_ENHANCED_SEPARATION,
        EXTERIOR_GUARD_MAD_MULTIPLIER * enhanced_guard_mad,
    )
    outside_upper = raw_guard_median + np.maximum(
        EXTERIOR_OUTSIDE_MARGIN_FLOOR,
        EXTERIOR_OUTSIDE_MARGIN_MAD_MULTIPLIER * raw_guard_mad,
    )
    outside_like = raw.astype(np.float32) <= outside_upper[None, :]
    outside_integral = np.cumsum(outside_like.astype(np.int32), axis=0)
    guard_start = int(guard_rows[0])
    corridor_lengths = (guard_start - search_rows).astype(np.float32)
    corridor_counts = outside_integral[guard_start][None, :] - outside_integral[search_rows]
    corridor_fraction = corridor_counts.astype(np.float32) / corridor_lengths[:, None]

    inside_rows = np.stack(
        [search_rows - step for step in range(EXTERIOR_RADIAL_SUSTAIN_PX)], axis=1
    )
    outside_rows = np.stack([search_rows + step for step in range(1, 4)], axis=1)
    raw_inside = np.mean(raw[inside_rows].astype(np.float32), axis=1)
    raw_outside = np.mean(raw[outside_rows].astype(np.float32), axis=1)
    enhanced_inside = np.min(enhanced[inside_rows].astype(np.float32), axis=1)
    separation = enhanced_inside - enhanced_guard_median[None, :]
    radial = (
        (separation >= enhanced_floor[None, :])
        & ((raw_inside - raw_outside) >= EXTERIOR_MIN_RAW_POLARITY)
        & ((raw_inside - raw_guard_median[None, :]) >= raw_tolerance[None, :])
        & (np.abs(raw_outside - raw_guard_median[None, :]) <= raw_tolerance[None, :])
        & (corridor_fraction >= EXTERIOR_MIN_CORRIDOR_FRACTION)
    )
    radial_neighborhood = cv2.dilate(
        radial.astype(np.uint8), np.ones((3, 1), dtype=np.uint8)
    )
    support = cyclic_horizontal_mean(
        radial_neighborhood.astype(np.float32), EXTERIOR_TANGENTIAL_SUPPORT_PX
    )
    supported = radial & (support >= EXTERIOR_MIN_TANGENTIAL_SUPPORT)
    return {
        "searchOffsets": offsets[search_rows].astype(np.float32),
        "supported": supported,
        "support": support,
        "corridorFraction": corridor_fraction,
        "separation": separation,
        "rawPolarity": raw_inside - raw_outside,
        "guardRawMedian": raw_guard_median,
        "guardRawMad": raw_guard_mad,
    }


def cyclic_gaussian_1d(values: np.ndarray, sigma: float) -> np.ndarray:
    radius = int(math.ceil(4.0 * sigma))
    x = np.arange(-radius, radius + 1, dtype=np.float64)
    kernel = np.exp(-0.5 * np.square(x / sigma))
    kernel /= np.sum(kernel)
    padded = np.pad(values.astype(np.float64), (radius, radius), mode="wrap")
    return np.convolve(padded, kernel, mode="valid")


def cyclic_open_1d(values: np.ndarray, width: int) -> np.ndarray:
    diagnostic.need(width >= 1 and width % 2 == 1, "R18 morphology width must be positive and odd")
    # Opening is erosion followed by dilation, so its composed support reaches
    # width-1 samples in each direction.  A half-kernel halo is insufficient.
    halo = width - 1
    padded = np.pad(values.astype(np.float32), (halo, halo), mode="wrap")[None, :]
    opened = cv2.morphologyEx(
        padded,
        cv2.MORPH_OPEN,
        np.ones((1, width), dtype=np.uint8),
        borderType=cv2.BORDER_REPLICATE,
    )[0]
    return opened[halo:-halo].astype(np.float64)


def circle_ray_offsets(base_fit: dict[str, Any], circle: dict[str, Any]) -> np.ndarray:
    """Intersect every original-fit radial ray with an exact physical circle."""
    columns = int(circle["angleSampleCount"])
    angles = np.arange(columns, dtype=np.float64) * (2.0 * math.pi / columns)
    ux, uy = np.cos(angles), np.sin(angles)
    qx = float(base_fit["centerX"]) - float(circle["centerX"])
    qy = float(base_fit["centerY"]) - float(circle["centerY"])
    projection = qx * ux + qy * uy
    radius = float(circle["radius"])
    center_distance = math.hypot(qx, qy)
    diagnostic.need(
        math.isfinite(radius) and math.isfinite(center_distance) and center_distance < radius,
        "R18 original center must remain strictly inside the fitted circle",
    )
    discriminant = np.square(projection) - (qx * qx + qy * qy - radius * radius)
    diagnostic.need(bool(np.all(discriminant >= -1.0e-6)), "R18 circle does not intersect every original radial ray")
    radial_distance = -projection + np.sqrt(np.maximum(discriminant, 0.0))
    diagnostic.need(
        bool(np.all(np.isfinite(radial_distance))) and bool(np.all(radial_distance > 0.0)),
        "R18 circle produced a non-finite or non-positive radial intersection",
    )
    return (radial_distance - float(base_fit["radius"])).astype(np.float32)


def angular_coverage(columns: np.ndarray, accepted: np.ndarray, width: int) -> float:
    accepted_columns = columns[accepted]
    if accepted_columns.size == 0:
        return 0.0
    bins = np.floor(accepted_columns.astype(np.float64) * CIRCLE_COVERAGE_BINS / width).astype(np.int32)
    return float(np.unique(np.clip(bins, 0, CIRCLE_COVERAGE_BINS - 1)).size / CIRCLE_COVERAGE_BINS)


def outer_circle_candidates(exterior: dict[str, Any]) -> dict[str, Any]:
    offsets = exterior["searchOffsets"]
    supported = exterior["supported"] & (offsets[:, None] >= 0.0)
    observed = np.any(supported, axis=0)
    reverse = np.argmax(supported[::-1], axis=0)
    rows = supported.shape[0] - 1 - reverse
    selected = offsets[rows].astype(np.float32)
    selected[~observed] = np.nan
    touches_limit = observed & (selected >= EXTERIOR_SEARCH_MAX_OFFSET_PX)
    half = EXTERIOR_LOCAL_MEDIAN_PX // 2
    windows = np.lib.stride_tricks.sliding_window_view(
        np.pad(selected.astype(np.float64), (half, half), mode="wrap"),
        EXTERIOR_LOCAL_MEDIAN_PX,
    )
    valid_counts = np.sum(np.isfinite(windows), axis=1)
    local_median = np.ma.median(np.ma.masked_invalid(windows), axis=1).filled(np.nan)
    consistent = (
        (valid_counts >= EXTERIOR_LOCAL_MEDIAN_PX // 4)
        & np.isfinite(selected)
        & (np.abs(selected - local_median) <= EXTERIOR_MAX_LOCAL_DEVIATION_PX)
    )
    qualified = observed & ~touches_limit & consistent
    return {
        "selectedOffsets": selected,
        "qualifiedColumns": qualified,
        "touchesSearchLimitColumns": touches_limit,
    }


def raw_exterior_witness(
    exterior: dict[str, Any], outer_path: np.ndarray
) -> dict[str, Any]:
    """Measure an unenhanced raw-polarity witness without moving cyan."""
    radial = (
        (exterior["rawPolarity"] >= EXTERIOR_MIN_RAW_POLARITY)
        & (exterior["corridorFraction"] >= EXTERIOR_MIN_CORRIDOR_FRACTION)
    )
    radial_neighborhood = cv2.dilate(
        radial.astype(np.uint8), np.ones((3, 1), dtype=np.uint8)
    )
    support = cyclic_horizontal_mean(
        radial_neighborhood.astype(np.float32), EXTERIOR_TANGENTIAL_SUPPORT_PX
    )
    supported = radial & (support >= EXTERIOR_MIN_TANGENTIAL_SUPPORT)
    candidates = outer_circle_candidates(
        {
            "searchOffsets": exterior["searchOffsets"],
            "supported": supported,
        }
    )
    observed = candidates["qualifiedColumns"] & np.isfinite(
        candidates["selectedOffsets"]
    )
    residual = np.full(outer_path.size, np.nan, dtype=np.float32)
    residual[observed] = (
        candidates["selectedOffsets"][observed] - outer_path[observed]
    )
    population = residual[observed].astype(np.float64)
    return {
        "path": candidates["selectedOffsets"],
        "observed": observed,
        "residualFromCyan": residual,
        "observedFraction": float(np.mean(observed)),
        "medianResidualFromCyanPx": (
            float(np.median(population)) if population.size else None
        ),
        "p90AbsoluteResidualFromCyanPx": (
            float(np.percentile(np.abs(population), 90.0))
            if population.size
            else None
        ),
        "touchesOutwardSearchLimitColumnCount": int(
            np.count_nonzero(candidates["touchesSearchLimitColumns"])
        ),
        "enhancementUsed": False,
        "cyanGeometryChanged": False,
    }


def fit_guarded_outer_circle(
    candidates: dict[str, Any], base_fit: dict[str, Any]
) -> dict[str, Any]:
    selected = candidates["selectedOffsets"]
    qualified = candidates["qualifiedColumns"]
    width = int(selected.size)
    band = np.zeros(width, dtype=bool)
    band_seed: float | None = None
    band_coverage = 0.0
    for seed in range(EXTERIOR_SEARCH_MAX_OFFSET_PX, -1, -1):
        proposed = qualified & (np.abs(selected - float(seed)) <= OUTER_BAND_HALF_WIDTH_PX)
        columns = np.flatnonzero(proposed)
        coverage = angular_coverage(columns, np.ones(columns.size, dtype=bool), width)
        if coverage >= MINIMUM_OUTER_BAND_COVERAGE and float(np.mean(proposed)) >= MINIMUM_OUTER_BAND_FRACTION:
            band = proposed
            band_seed = float(seed)
            band_coverage = coverage
            break
    if band_seed is None:
        radius_delta = 0.0
        accepted = np.zeros(width, dtype=bool)
    else:
        radius_delta = float(np.median(selected[band]))
        accepted = band & (np.abs(selected - radius_delta) <= FINAL_ACCEPTED_RESIDUAL_PX)
    accepted_columns = np.flatnonzero(accepted)
    accepted_coverage = angular_coverage(
        accepted_columns, np.ones(accepted_columns.size, dtype=bool), width
    )
    residuals = selected[accepted].astype(np.float64) - radius_delta
    rms = float(math.sqrt(np.mean(np.square(residuals)))) if residuals.size else float("inf")
    p90 = float(np.percentile(np.abs(residuals), 90.0)) if residuals.size else float("inf")
    adjacent = accepted & np.roll(accepted, 1)
    adjacent_jumps = np.abs(selected - np.roll(selected, 1))[adjacent]
    maximum_jump = float(np.max(adjacent_jumps)) if adjacent_jumps.size else 0.0
    qualified_circle = bool(
        band_seed is not None
        and accepted_coverage >= MINIMUM_FINAL_ACCEPTED_COVERAGE
        and maximum_jump <= MAXIMUM_FINAL_ADJACENT_RESIDUAL_JUMP_PX
    )
    outer_path = np.full(width, radius_delta, dtype=np.float32)
    fit = {
        "centerX": float(base_fit["centerX"]),
        "centerY": float(base_fit["centerY"]),
        "radius": float(base_fit["radius"]) + radius_delta,
        "acceptedCount": int(np.count_nonzero(accepted)),
        "inputCount": int(np.count_nonzero(band)),
        "fitObservationFraction": float(np.mean(band)),
        "observationFraction": float(np.mean(accepted)),
        "inlierFraction": float(np.count_nonzero(accepted) / max(1, np.count_nonzero(band))),
        "angularCoverageFraction": accepted_coverage,
        "observedAngularCoverageFraction": band_coverage,
        "angularCoverageBins": CIRCLE_COVERAGE_BINS,
        "rmsResidualPx": rms,
        "p90AbsoluteResidualPx": p90,
        "centerDisplacementFromPredecessorPx": 0.0,
        "radiusDeltaFromPredecessorPx": radius_delta,
        "fitPassCount": 1,
        "finalSupportRmsResidualPx": rms,
        "finalSupportP90AbsoluteResidualPx": p90,
        "maximumSelectedToFinalCircleDifferencePx": (
            float(np.max(np.abs(residuals))) if residuals.size else float("inf")
        ),
        "maximumAdjacentAcceptedResidualJumpPx": maximum_jump,
        "outerBandSeedOffsetPx": band_seed,
        "outerBandCoverageFraction": band_coverage,
        "centerLockedToIndependentFullWaferFit": True,
    }
    return {
        "fit": fit,
        "qualified": qualified_circle,
        "state": (
            "PASS_DIAGNOSTIC_EXTERIOR_CONNECTED_OUTER_CIRCLE_QUALIFIED"
            if qualified_circle
            else "HOLD_DIAGNOSTIC_EXTERIOR_CONNECTED_OUTER_CIRCLE_NOT_QUALIFIED"
        ),
        "selectedOffsets": selected,
        "observed": accepted,
        "robustFitAcceptedColumns": accepted.copy(),
        "finalSupportColumns": accepted.copy(),
        "outerBandColumns": band,
        "rejectedBandColumns": qualified & ~accepted,
        "outerPath": outer_path,
    }


def transition_map(strip: np.ndarray, offsets: np.ndarray) -> dict[str, Any]:
    diagnostic.need(strip.dtype == np.uint8 and strip.ndim == 2, "R18 strip must be uint8 grayscale")
    diagnostic.need(offsets.ndim == 1 and offsets.size == strip.shape[0], "R18 strip/offset mismatch")
    diagnostic.need(bool(np.allclose(np.diff(offsets), 1.0)), "R18 requires native one-pixel radial pitch")
    raw = cyclic_gaussian_image(strip)
    enhanced = cyclic_gaussian_image(shadow_lift(strip))
    search_indices = np.flatnonzero((offsets >= SEARCH_MIN_OFFSET_PX) & (offsets <= SEARCH_MAX_OFFSET_PX))
    diagnostic.need(search_indices.size > 0, "R18 transition search is empty")
    diagnostic.need(
        int(search_indices[0]) >= RADIAL_INSIDE_SAMPLES - 1
        and int(search_indices[-1]) + RADIAL_OUTSIDE_SAMPLES < strip.shape[0],
        "R18 transition search lacks its radial halo",
    )
    raw_inside = sum(raw[search_indices - step] for step in range(RADIAL_INSIDE_SAMPLES)) / RADIAL_INSIDE_SAMPLES
    raw_outside = sum(raw[search_indices + step] for step in range(1, RADIAL_OUTSIDE_SAMPLES + 1)) / RADIAL_OUTSIDE_SAMPLES
    enhanced_inside = sum(enhanced[search_indices - step] for step in range(RADIAL_INSIDE_SAMPLES)) / RADIAL_INSIDE_SAMPLES
    enhanced_outside = sum(enhanced[search_indices + step] for step in range(1, RADIAL_OUTSIDE_SAMPLES + 1)) / RADIAL_OUTSIDE_SAMPLES
    raw_contrast = raw_inside - raw_outside
    enhanced_contrast = enhanced_inside - enhanced_outside
    absolute_radial = (enhanced_contrast >= MINIMUM_ENHANCED_CONTRAST) & (raw_contrast >= MINIMUM_RAW_POLARITY)
    absolute_support = cyclic_horizontal_mean(
        absolute_radial.astype(np.float32), TANGENTIAL_SUPPORT_WIDTH_PX
    )
    absolute_supported = absolute_radial & (absolute_support >= MINIMUM_TANGENTIAL_SUPPORT)
    row_coverage = np.mean(absolute_supported, axis=1)
    ridge_rows = np.flatnonzero(row_coverage >= MINIMUM_GLOBAL_RIDGE_COVERAGE)
    diagnostic.need(ridge_rows.size > 0, "R18 found no globally sustained outside-in transition ridge")
    ridge_row = int(ridge_rows[-1])
    search_offsets = offsets[search_indices].astype(np.float32)
    ridge_offset = float(search_offsets[ridge_row])

    # The relative maximum is intentionally restricted to the outer physical
    # lane.  A strong inner die transition must not suppress a faint bevel.
    outer_lane = np.abs(search_offsets - ridge_offset) <= CIRCLE_TRACK_HALF_WIDTH_PX
    outer_peak = np.maximum(np.max(enhanced_contrast[outer_lane], axis=0), 0.0)
    outer_threshold = np.maximum(
        MINIMUM_ENHANCED_CONTRAST, outer_peak * RELATIVE_ENHANCED_CONTRAST
    )
    outer_radial = (
        outer_lane[:, None]
        & (enhanced_contrast >= outer_threshold[None, :])
        & (raw_contrast >= MINIMUM_RAW_POLARITY)
    )
    outer_support = cyclic_horizontal_mean(
        outer_radial.astype(np.float32), TANGENTIAL_SUPPORT_WIDTH_PX
    )
    outer_supported = outer_radial & (outer_support >= MINIMUM_TANGENTIAL_SUPPORT)

    # This remains an outside-silhouette map, including a notch.  Enhancement
    # may nominate a faint dark silhouette pixel, but unchanged raw polarity is
    # still mandatory.  No inner edge-zone boundary is detected from pixels.
    frontier_supported = absolute_supported
    frontier_support = absolute_support
    return {
        "searchOffsets": search_offsets,
        "outerSupported": outer_supported,
        "outerSupport": outer_support,
        "frontierSupported": frontier_supported,
        "frontierSupport": frontier_support,
        "rowCoverage": row_coverage,
        "ridgeRow": ridge_row,
        "ridgeOffsetPx": ridge_offset,
        "outerEnhancedThreshold": outer_threshold,
        "rawContrast": raw_contrast,
        "enhancedContrast": enhanced_contrast,
    }


def select_near_model(
    supported: np.ndarray,
    search_offsets: np.ndarray,
    model: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    admissible = supported & (
        np.abs(search_offsets[:, None].astype(np.float64) - model[None, :]) <= CIRCLE_TRACK_HALF_WIDTH_PX
    )
    observed = np.any(admissible, axis=0)
    reverse = np.argmax(admissible[::-1], axis=0)
    selected_rows = admissible.shape[0] - 1 - reverse
    selected = search_offsets[selected_rows].astype(np.float32)
    selected[~observed] = np.nan
    return selected, observed


def fit_physical_circle(
    supported: np.ndarray,
    search_offsets: np.ndarray,
    base_fit: dict[str, Any],
    params: Any,
    ridge_offset: float,
) -> dict[str, Any]:
    width = int(supported.shape[1])
    model = np.full(width, ridge_offset, dtype=np.float32)
    selected = np.full(width, np.nan, dtype=np.float32)
    observed = np.zeros(width, dtype=bool)
    fit: dict[str, Any] | None = None
    accepted_columns = np.zeros(width, dtype=bool)
    fit_pass_count = 0
    for _ in range(CIRCLE_REFINEMENT_PASSES):
        selected, observed = select_near_model(supported, search_offsets, model)
        columns = np.flatnonzero(observed)
        diagnostic.need(columns.size >= 32, "R18 has fewer than 32 circle observations")
        angles = columns.astype(np.float64) * (2.0 * math.pi / width)
        radii = float(base_fit["radius"]) + selected[columns].astype(np.float64)
        points = np.column_stack(
            (
                float(base_fit["centerX"]) + radii * np.cos(angles),
                float(base_fit["centerY"]) + radii * np.sin(angles),
            )
        )
        fit = CORE.robust_circle(points, params)
        accepted_columns = np.zeros(width, dtype=bool)
        accepted_columns[columns[fit["acceptedMask"]]] = True
        circle = {
            "centerX": float(fit["centerX"]),
            "centerY": float(fit["centerY"]),
            "radius": float(fit["radius"]),
            "angleSampleCount": width,
        }
        model = circle_ray_offsets(base_fit, circle)
        fit_pass_count += 1
    assert fit is not None
    fit_columns = np.flatnonzero(observed)
    fit_coverage = angular_coverage(fit_columns, fit["acceptedMask"], width)
    fit_observation_fraction = float(np.mean(observed))
    robust_accepted_columns = accepted_columns.copy()

    # Re-evaluate raw-supported sample centers against the final circle without
    # fitting again.  This avoids a discrete two-cycle while proving that the
    # displayed evidence remains inside the final five-pixel lane.
    selected, observed = select_near_model(supported, search_offsets, model)
    columns = np.flatnonzero(observed)
    diagnostic.need(columns.size >= 32, "R18 final circle lane has fewer than 32 observations")
    angles = columns.astype(np.float64) * (2.0 * math.pi / width)
    radii = float(base_fit["radius"]) + selected[columns].astype(np.float64)
    final_points = np.column_stack(
        (
            float(base_fit["centerX"]) + radii * np.cos(angles),
            float(base_fit["centerY"]) + radii * np.sin(angles),
        )
    )
    final_residuals = (
        np.hypot(
            final_points[:, 0] - float(fit["centerX"]),
            final_points[:, 1] - float(fit["centerY"]),
        )
        - float(fit["radius"])
    )
    final_coverage = angular_coverage(
        columns, np.ones(columns.size, dtype=bool), width
    )
    final_rms = float(math.sqrt(np.mean(np.square(final_residuals))))
    final_p90 = float(np.percentile(np.abs(final_residuals), 90.0))
    maximum_final_lane_difference = float(
        np.max(
            np.abs(
                selected[observed].astype(np.float64)
                - model[observed].astype(np.float64)
            )
        )
    )
    fit_row = {
        "centerX": float(fit["centerX"]),
        "centerY": float(fit["centerY"]),
        "radius": float(fit["radius"]),
        "acceptedCount": int(fit["acceptedCount"]),
        "inputCount": int(fit["inputCount"]),
        "fitObservationFraction": fit_observation_fraction,
        "observationFraction": float(np.mean(observed)),
        "inlierFraction": float(fit["inlierFraction"]),
        "angularCoverageFraction": fit_coverage,
        "observedAngularCoverageFraction": final_coverage,
        "angularCoverageBins": CIRCLE_COVERAGE_BINS,
        "rmsResidualPx": float(fit["rmsResidualPx"]),
        "p90AbsoluteResidualPx": float(fit["p90AbsoluteResidualPx"]),
        "centerDisplacementFromPredecessorPx": float(
            math.hypot(
                float(fit["centerX"]) - float(base_fit["centerX"]),
                float(fit["centerY"]) - float(base_fit["centerY"]),
            )
        ),
        "radiusDeltaFromPredecessorPx": float(fit["radius"] - float(base_fit["radius"])),
        "fitPassCount": fit_pass_count,
        "finalSupportRmsResidualPx": final_rms,
        "finalSupportP90AbsoluteResidualPx": final_p90,
        "maximumSelectedToFinalCircleDifferencePx": maximum_final_lane_difference,
    }
    qualified = (
        fit_coverage >= MINIMUM_CIRCLE_COVERAGE
        and final_coverage >= MINIMUM_CIRCLE_COVERAGE
        and fit_row["inlierFraction"] >= MINIMUM_CIRCLE_INLIER_FRACTION
        and fit_row["rmsResidualPx"] <= MAXIMUM_CIRCLE_RMS_RESIDUAL_PX
        and fit_row["p90AbsoluteResidualPx"] <= MAXIMUM_CIRCLE_P90_RESIDUAL_PX
        and final_rms <= MAXIMUM_CIRCLE_RMS_RESIDUAL_PX
        and final_p90 <= MAXIMUM_CIRCLE_P90_RESIDUAL_PX
        and maximum_final_lane_difference <= CIRCLE_TRACK_HALF_WIDTH_PX + 1.0e-6
    )
    return {
        "fit": fit_row,
        "qualified": bool(qualified),
        "state": "PASS_DIAGNOSTIC_PHYSICAL_OUTER_CIRCLE_QUALIFIED" if qualified else "HOLD_DIAGNOSTIC_PHYSICAL_OUTER_CIRCLE_NOT_QUALIFIED",
        "selectedOffsets": selected,
        "observed": observed,
        "robustFitAcceptedColumns": robust_accepted_columns,
        "finalSupportColumns": observed.copy(),
        "outerPath": model,
    }


def outermost_frontier(supported: np.ndarray, search_offsets: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    observed = np.any(supported, axis=0)
    reverse = np.argmax(supported[::-1], axis=0)
    rows = supported.shape[0] - 1 - reverse
    frontier = search_offsets[rows].astype(np.float32)
    frontier[~observed] = np.nan
    return frontier, observed


def measure_pixel_edge_family(
    transition: dict[str, Any], outer_path: np.ndarray
) -> dict[str, Any]:
    """Measure one edge family without changing the fixed annular coordinates.

    The normal branch follows the strongest supported outside-to-inside edge in
    a narrow circle-anchored bevel lane.  The deep branch retains the broad
    exterior-facing trace needed to propose a notch.  Neither branch is
    interpolated, and neither may define either fitted circle.
    """
    search_offsets = transition["searchOffsets"]
    supported = transition["frontierSupported"]
    contrast = transition["enhancedContrast"]
    diagnostic.need(
        supported.shape == contrast.shape
        and supported.shape[0] == search_offsets.size
        and supported.shape[1] == outer_path.size,
        "R18 pixel-edge family geometry mismatch",
    )
    normal_model = outer_path.astype(np.float32) - EDGE_ZONE_INWARD_PX
    normal_lane = (
        np.abs(search_offsets[:, None] - normal_model[None, :])
        <= BEVEL_TRACE_LANE_HALF_WIDTH_PX
    )
    initial_observed = np.any(supported & normal_lane, axis=0)
    initial_scores = np.where(supported & normal_lane, contrast, -np.inf)
    initial_rows = np.argmax(initial_scores, axis=0)
    initial_path = search_offsets[initial_rows].astype(np.float32)
    initial_path[~initial_observed] = np.nan
    diagnostic.need(bool(np.any(initial_observed)), "R18 normal bevel trace calibration has no observations")
    calibrated_delta = float(np.median(initial_path[initial_observed] - normal_model[initial_observed]))
    calibrated_model = normal_model + calibrated_delta
    calibrated_lane = (
        np.abs(search_offsets[:, None] - calibrated_model[None, :])
        <= BEVEL_TRACE_CALIBRATED_HALF_WIDTH_PX
    )
    normal_candidates = supported & calibrated_lane
    normal_observed = np.any(normal_candidates, axis=0)
    scores = np.where(normal_candidates, contrast, -np.inf)
    normal_rows = np.argmax(scores, axis=0)
    columns = np.arange(outer_path.size, dtype=np.int32)
    normal_path = search_offsets[normal_rows].astype(np.float32)
    normal_strength = scores[normal_rows, columns]
    normal_path[~normal_observed] = np.nan
    normal_strength[~normal_observed] = -np.inf

    discontinuity_held = np.zeros(outer_path.size, dtype=bool)
    for _ in range(BEVEL_TRACE_DISCONTINUITY_PASSES):
        jumps = (
            normal_observed
            & np.roll(normal_observed, 1)
            & (np.abs(normal_path - np.roll(normal_path, 1)) > BEVEL_TRACE_MAX_ADJACENT_STEP_PX)
        )
        jump_columns = np.flatnonzero(jumps)
        if jump_columns.size == 0:
            break
        remove = np.zeros(outer_path.size, dtype=bool)
        for right in jump_columns:
            left = (int(right) - 1) % outer_path.size
            if normal_strength[right] < normal_strength[left]:
                remove[right] = True
            elif normal_strength[left] < normal_strength[right]:
                remove[left] = True
            elif abs(normal_path[right] - calibrated_model[right]) >= abs(
                normal_path[left] - calibrated_model[left]
            ):
                remove[right] = True
            else:
                remove[left] = True
        remove &= normal_observed
        if not bool(np.any(remove)):
            break
        normal_observed[remove] = False
        normal_path[remove] = np.nan
        normal_strength[remove] = -np.inf
        discontinuity_held |= remove

    deep_path, deep_observed = outermost_frontier(supported, search_offsets)
    deep_inward_limit = deep_observed & np.isclose(
        deep_path, float(search_offsets[0]), rtol=0.0, atol=1.0e-6
    )
    adjacent = normal_observed & np.roll(normal_observed, 1)
    adjacent_steps = np.abs(normal_path - np.roll(normal_path, 1))[adjacent]
    missing_runs = CORE.group_circular_true(~normal_observed)
    return {
        "normalPath": normal_path,
        "normalObserved": normal_observed,
        "normalModel": normal_model,
        "calibratedNormalModel": calibrated_model,
        "calibratedDeltaPx": calibrated_delta,
        "deepNotchPath": deep_path,
        "deepNotchObserved": deep_observed,
        "deepNotchTouchesInwardLimitColumns": deep_inward_limit,
        "normalCandidateColumns": initial_observed,
        "normalCandidateFractionBeforeConsistency": float(np.mean(initial_observed)),
        "normalCalibratedCandidateFraction": float(np.mean(np.any(normal_candidates, axis=0))),
        "normalObservedFraction": float(np.mean(normal_observed)),
        "normalDiscontinuityHeldColumns": discontinuity_held,
        "normalDiscontinuityHeldColumnCount": int(np.count_nonzero(discontinuity_held)),
        "normalMaximumAdjacentStepPx": float(np.max(adjacent_steps)) if adjacent_steps.size else None,
        "normalMaximumMissingRunSamples": max(
            (int(run.size) for run in missing_runs), default=0
        ),
        "deepNotchObservedFraction": float(np.mean(deep_observed)),
        "interpolationPerformed": False,
        "coordinatesChanged": False,
    }


def extract_notch_candidates(
    frontier: np.ndarray,
    observed: np.ndarray,
    holder: np.ndarray,
    outer_path: np.ndarray,
    params: Any,
    cfg: dict[str, Any],
) -> dict[str, Any]:
    valid = observed & ~holder
    raw_depth = np.zeros(frontier.size, dtype=np.float64)
    raw_depth[valid] = np.maximum(0.0, outer_path[valid].astype(np.float64) - frontier[valid].astype(np.float64))
    smoothed = cyclic_gaussian_1d(raw_depth, NOTCH_INITIAL_GAUSSIAN_SIGMA_PX)
    suppressed = cyclic_open_1d(smoothed, NOTCH_PATTERN_OPEN_WIDTH_PX)
    filtered = cyclic_gaussian_1d(suppressed, NOTCH_FINAL_GAUSSIAN_SIGMA_PX)
    population = filtered[valid]
    diagnostic.need(population.size > 0, "R18 notch residual population is empty")
    ceiling = float(np.percentile(population, 80.0))
    baseline = population[population <= ceiling]
    center = float(np.median(baseline))
    noise = float(1.4826 * np.median(np.abs(baseline - center)))
    threshold = max(float(cfg["minimumNotchDepthPx"]), center + float(cfg["noiseSigmaThreshold"]) * noise)
    core = valid & (filtered >= threshold)
    core = CORE.close_small_circular_gaps(core, int(cfg["candidateJoinWidthPx"]))
    mouth_threshold = max(
        AMBIGUOUS_INWARD_RESIDUAL_PX,
        center + 2.0 * noise,
    )
    mouth = valid & (filtered >= mouth_threshold)
    mouth = CORE.close_small_circular_gaps(mouth, int(cfg["candidateJoinWidthPx"]))
    degrees_per_sample = 360.0 / frontier.size
    minimum_samples = max(
        int(cfg["minimumNotchWidthPx"]),
        int(math.ceil(float(params.candidate_minimum_width_degrees) / degrees_per_sample)),
    )
    maximum_samples = int(
        math.floor(float(params.manufactured_maximum_width_degrees) / degrees_per_sample)
    )
    candidate_columns = np.zeros(frontier.size, dtype=bool)
    topology_candidate_columns = np.zeros(frontier.size, dtype=bool)
    all_candidate_columns = np.zeros(frontier.size, dtype=bool)
    candidate_entries: list[tuple[dict[str, Any], np.ndarray]] = []
    for indices in CORE.group_circular_true(mouth):
        if not bool(np.any(core[indices])):
            continue
        if int(indices.size) < minimum_samples:
            continue
        maximum_extra = maximum_samples - int(indices.size)
        return_width = NOTCH_SHOULDER_WIDTH_PX

        def nearest_circle_return(boundary: int, direction: int) -> tuple[int, np.ndarray, float, float] | None:
            if maximum_extra < 0:
                return None
            for distance in range(1, maximum_extra + 2):
                window = (
                    boundary + direction * np.arange(distance, distance + return_width)
                ) % frontier.size
                support = float(np.mean(valid[window]))
                circle_return = valid[window] & (raw_depth[window] <= CIRCLE_TRACK_HALF_WIDTH_PX)
                return_fraction = float(np.mean(circle_return))
                if (
                    support >= MINIMUM_NOTCH_SHOULDER_SUPPORT
                    and return_fraction >= MINIMUM_NOTCH_SHOULDER_SUPPORT
                ):
                    return distance, window, support, return_fraction
            return None

        left_return = nearest_circle_return(int(indices[0]), -1)
        right_return = nearest_circle_return(int(indices[-1]), 1)
        left_extra = 0 if left_return is None else int(left_return[0]) - 1
        right_extra = 0 if right_return is None else int(right_return[0]) - 1
        physical_sample_count = int(indices.size) + left_extra + right_extra
        shoulders_supported = bool(
            left_return is not None
            and right_return is not None
            and physical_sample_count <= maximum_samples
        )
        if shoulders_supported:
            physical_start = (int(indices[0]) - left_extra) % frontier.size
            physical_indices = (
                physical_start + np.arange(physical_sample_count, dtype=np.int32)
            ) % frontier.size
        else:
            physical_indices = indices
        shape_depths = filtered[indices]
        symmetry, tip_offset, slope_consistency = CORE.candidate_shape(shape_depths)
        threshold_width = float(indices.size * degrees_per_sample)
        width = float(physical_indices.size * degrees_per_sample)
        left_support = 0.0 if left_return is None else float(left_return[2])
        right_support = 0.0 if right_return is None else float(right_return[2])
        left_return_fraction = 0.0 if left_return is None else float(left_return[3])
        right_return_fraction = 0.0 if right_return is None else float(right_return[3])
        missing_runs = diagnostic.runs(~valid[indices])
        maximum_missing_run = max((int(run.size) for run in missing_runs), default=0)
        observed_sample_count = int(np.count_nonzero(valid[indices]))
        observed_fraction = float(np.mean(valid[indices]))
        weights = np.maximum(shape_depths, 0.001)
        center_degrees = CORE.circular_mean_degrees(
            [float(index) * degrees_per_sample for index in indices],
            [float(value) for value in weights],
        )
        all_candidate_columns[physical_indices] = True
        topology_eligible = bool(
            float(params.manufactured_minimum_width_degrees)
            <= threshold_width
            <= float(params.manufactured_maximum_width_degrees)
            and symmetry >= float(params.manufactured_minimum_symmetry)
            and tip_offset <= float(params.manufactured_maximum_tip_offset_fraction)
            and slope_consistency >= float(params.manufactured_minimum_slope_consistency)
            and observed_sample_count >= minimum_samples
            and maximum_missing_run <= MAXIMUM_NOTCH_MISSING_RUN_SAMPLES
        )
        radial_eligible = bool(
            topology_eligible
            and float(params.manufactured_minimum_width_degrees)
            <= width
            <= float(params.manufactured_maximum_width_degrees)
            and shoulders_supported
        )
        if topology_eligible:
            topology_candidate_columns[physical_indices] = True
        if radial_eligible:
            candidate_columns[physical_indices] = True
        candidate_entries.append(
            ({
                "centerAngleDegrees": float(center_degrees),
                "startAngleDegrees": float(physical_indices[0] * degrees_per_sample),
                "endAngleDegrees": float(physical_indices[-1] * degrees_per_sample),
                "widthDegrees": width,
                "thresholdMouthWidthDegrees": threshold_width,
                "maximumDepthPx": float(np.max(shape_depths)),
                "maximumRawDepthPx": float(np.max(raw_depth[indices])),
                "medianDepthPx": float(np.median(shape_depths)),
                "sampleCount": int(physical_indices.size),
                "thresholdMouthSampleCount": int(indices.size),
                "observedSampleCount": observed_sample_count,
                "observedFraction": observed_fraction,
                "maximumContiguousMissingSamples": maximum_missing_run,
                "supportPopulation": "THRESHOLD_MOUTH_EXTERIOR_CONNECTED_SAMPLES",
                "leftMouthShoulderSupportFraction": left_support,
                "rightMouthShoulderSupportFraction": right_support,
                "leftCircleReturnFraction": left_return_fraction,
                "rightCircleReturnFraction": right_return_fraction,
                "leftCircleReturnDistanceSamples": None if left_return is None else int(left_return[0]),
                "rightCircleReturnDistanceSamples": None if right_return is None else int(right_return[0]),
                "mouthShouldersSupported": bool(shoulders_supported),
                "symmetryScore": float(symmetry),
                "tipCenterOffsetFraction": float(tip_offset),
                "slopeConsistencyFraction": float(slope_consistency),
                "manufacturedBfTopologyEligible": topology_eligible,
                "manufacturedDfRadialEligible": radial_eligible,
                "manufacturedChannelMorphologyEligible": radial_eligible,
            }, physical_indices.copy())
        )
    candidate_entries.sort(key=lambda entry: entry[0]["centerAngleDegrees"])
    candidates = [entry[0] for entry in candidate_entries]
    candidate_column_sets = [entry[1] for entry in candidate_entries]
    return {
        "sourceTrace": "DEEP_EXTERIOR_FACING_PIXEL_EDGE_TRACE",
        "sourceTraceUsedForNotchIdentification": True,
        "rawDepth": raw_depth.astype(np.float32),
        "filteredDepth": filtered.astype(np.float32),
        "candidateColumns": candidate_columns,
        "topologyCandidateColumns": topology_candidate_columns,
        "allCandidateColumns": all_candidate_columns,
        "candidateColumnSets": candidate_column_sets,
        "candidates": candidates,
        "thresholdPx": float(threshold),
        "mouthThresholdPx": float(mouth_threshold),
        "baselineCenterPx": center,
        "baselineNoiseSigmaPx": noise,
        "validColumnCount": int(np.count_nonzero(valid)),
    }


def analyze_fixed_strip(
    strip: np.ndarray,
    offsets: np.ndarray,
    base_fit: dict[str, Any],
    params: Any,
    cfg: dict[str, Any],
    predecessor_measured: np.ndarray,
) -> dict[str, Any]:
    """Analyze one already sampled, fixed-fit, unshifted annular strip."""
    exterior = exterior_connected_map(strip, offsets)
    circle_candidates = outer_circle_candidates(exterior)
    circle = fit_guarded_outer_circle(circle_candidates, base_fit)
    raw_witness = raw_exterior_witness(exterior, circle["outerPath"])
    band_seed = circle["fit"]["outerBandSeedOffsetPx"]
    search_headroom = (
        None
        if band_seed is None
        else float(EXTERIOR_SEARCH_MAX_OFFSET_PX - float(band_seed))
    )
    unsupported_runs = CORE.group_circular_true(~circle["finalSupportColumns"])
    maximum_unsupported_samples = max(
        (int(run.size) for run in unsupported_runs), default=0
    )
    cyan_geometry_verified = bool(
        circle["qualified"]
        and search_headroom is not None
        and search_headroom >= MINIMUM_CYAN_SEARCH_HEADROOM_PX
        and float(circle["fit"]["angularCoverageFraction"])
        >= MINIMUM_CYAN_ACCEPTED_COVERAGE
    )
    inner_circle = {
        "centerX": circle["fit"]["centerX"],
        "centerY": circle["fit"]["centerY"],
        "radius": circle["fit"]["radius"] - EDGE_ZONE_INWARD_PX,
        "angleSampleCount": strip.shape[1],
    }
    diagnostic.need(inner_circle["radius"] > 0.0, "R18 inner edge-zone circle has non-positive radius")
    inner_path = circle_ray_offsets(base_fit, inner_circle)
    edge_zone_spacing_error = float(
        np.max(np.abs((circle["outerPath"] - inner_path) - EDGE_ZONE_INWARD_PX))
    )
    diagnostic.need(
        edge_zone_spacing_error <= 1.0e-4,
        "R18 inner edge-zone path is not exactly 20 px inward of the outer circle",
    )
    exterior_frontier, exterior_frontier_observed = outermost_frontier(
        exterior["supported"], exterior["searchOffsets"]
    )
    outward = np.zeros(strip.shape[1], dtype=np.float32)
    outward[exterior_frontier_observed] = (
        exterior_frontier[exterior_frontier_observed]
        - circle["outerPath"][exterior_frontier_observed]
    )
    exterior_obstruction = exterior_frontier_observed & (outward > HOLDER_OUTWARD_RESIDUAL_PX)
    notch_transition = transition_map(strip, offsets)
    pixel_edge = measure_pixel_edge_family(notch_transition, circle["outerPath"])
    diagnostic.need(
        pixel_edge["normalObservedFraction"] >= MINIMUM_BEVEL_TRACE_COVERAGE,
        "R18 normal bevel trace coverage is below the review threshold",
    )
    diagnostic.need(
        pixel_edge["normalMaximumAdjacentStepPx"] is not None
        and pixel_edge["normalMaximumAdjacentStepPx"] <= BEVEL_TRACE_MAX_ADJACENT_STEP_PX,
        "R18 normal bevel trace retains a discontinuous radial jump",
    )
    frontier = pixel_edge["deepNotchPath"]
    frontier_observed = pixel_edge["deepNotchObserved"]
    notch = extract_notch_candidates(
        frontier,
        frontier_observed,
        exterior_obstruction,
        circle["outerPath"],
        params,
        cfg,
    )
    diagnostic.need(
        notch["sourceTraceUsedForNotchIdentification"]
        and notch["sourceTrace"] == "DEEP_EXTERIOR_FACING_PIXEL_EDGE_TRACE",
        "R18 notch candidates are not bound to the deep pixel-edge trace",
    )
    expected_notch_depth = np.zeros(frontier.size, dtype=np.float32)
    expected_notch_valid = frontier_observed & ~exterior_obstruction
    expected_notch_depth[expected_notch_valid] = np.maximum(
        0.0,
        circle["outerPath"][expected_notch_valid]
        - frontier[expected_notch_valid],
    )
    diagnostic.need(
        bool(np.array_equal(notch["rawDepth"], expected_notch_depth)),
        "R18 notch depth is not derived from the identifying deep pixel-edge trace",
    )
    diagnostic.need(
        not pixel_edge["interpolationPerformed"] and not pixel_edge["coordinatesChanged"],
        "R18 pixel-edge trace changed or interpolated fixed annular coordinates",
    )
    inward = np.zeros(strip.shape[1], dtype=np.float32)
    valid = frontier_observed & ~exterior_obstruction
    inward[valid] = circle["outerPath"][valid] - frontier[valid]
    ambiguous = valid & ~notch["candidateColumns"] & (inward >= AMBIGUOUS_INWARD_RESIDUAL_PX)
    diagnostic.need(predecessor_measured is not None, "R18 requires the exact predecessor measurement mask")
    prior_measured = predecessor_measured.astype(bool).copy()
    diagnostic.need(prior_measured.shape == (strip.shape[1],), "R18 predecessor hold width mismatch")
    return {
        "method": "EXTERIOR_CONNECTED_FARTHEST_COHERENT_BAND_CENTER_LOCKED_PHYSICAL_CIRCLE_R18",
        "strip": strip,
        "offsets": offsets.astype(np.float32),
        "baseFit": {key: float(base_fit[key]) for key in ("centerX", "centerY", "radius")},
        "ridgeOffsetPx": circle["fit"]["radiusDeltaFromPredecessorPx"],
        "ridgeCoverageFraction": circle["fit"]["outerBandCoverageFraction"],
        "maximumRowCoverageFraction": circle["fit"]["outerBandCoverageFraction"],
        "circleState": circle["state"],
        "circleQualified": circle["qualified"],
        "circleFit": circle["fit"],
        "cyanGeometryVerified": cyan_geometry_verified,
        "cyanGeometryVerificationState": (
            "PASS_DIAGNOSTIC_CYAN_GEOMETRY_SUPPORT_AND_HEADROOM"
            if cyan_geometry_verified
            else "HOLD_CYAN_GEOMETRY_UNVERIFIED"
        ),
        "rawExteriorWitnessPath": raw_witness["path"],
        "rawExteriorWitnessObservedColumns": raw_witness["observed"],
        "outerPath": circle["outerPath"],
        "innerPath": inner_path,
        "selectedOffsets": circle["selectedOffsets"],
        "selectedObserved": circle["observed"],
        "robustFitAcceptedColumns": circle["robustFitAcceptedColumns"],
        "finalSupportColumns": circle["finalSupportColumns"],
        "normalBevelTracePath": pixel_edge["normalPath"],
        "normalBevelTraceObservedColumns": pixel_edge["normalObserved"],
        "normalBevelTraceDiscontinuityHeldColumns": pixel_edge[
            "normalDiscontinuityHeldColumns"
        ],
        "deepNotchTracePath": pixel_edge["deepNotchPath"],
        "deepNotchTraceObservedColumns": pixel_edge["deepNotchObserved"],
        "deepNotchTraceTouchesInwardLimitColumns": pixel_edge[
            "deepNotchTouchesInwardLimitColumns"
        ],
        "pixelEdgeTracePath": pixel_edge["normalPath"].copy(),
        "pixelEdgeTraceObservedColumns": pixel_edge["normalObserved"].copy(),
        "pixelEdgePairedNotchColumns": np.zeros(strip.shape[1], dtype=bool),
        "pairedNotchEvidenceColumns": np.zeros(strip.shape[1], dtype=bool),
        "frontier": frontier,
        "frontierObserved": frontier_observed,
        "holderColumns": np.zeros(strip.shape[1], dtype=bool),
        "exteriorObstructionColumns": exterior_obstruction,
        "ambiguousColumns": ambiguous,
        "pairedNotchColumns": np.zeros(strip.shape[1], dtype=bool),
        "unpairedNotchColumns": np.zeros(strip.shape[1], dtype=bool),
        "predecessorHeldColumns": ~prior_measured,
        "notch": notch,
        "evidence": {
            "enhancement": "EXTERIOR_CIRCLE_AND_PIXEL_EDGE_BRANCHES_USE_OPERATOR_MONOTONIC_SHADOW_LIFT_WITH_RAW_POLARITY",
            "enhancementChangesCoordinates": False,
            "rawPolarityCorroborationRequired": True,
            "exteriorCircleMinimumRawPolarity": EXTERIOR_MIN_RAW_POLARITY,
            "exteriorCircleMinimumEnhancedSeparation": EXTERIOR_MIN_ENHANCED_SEPARATION,
            "exteriorCircleSearchMinimumOffsetPx": EXTERIOR_SEARCH_MIN_OFFSET_PX,
            "exteriorCircleSearchMaximumOffsetPx": EXTERIOR_SEARCH_MAX_OFFSET_PX,
            "exteriorCircleTangentialSupportWidthPx": EXTERIOR_TANGENTIAL_SUPPORT_PX,
            "exteriorCircleMinimumTangentialSupportFraction": EXTERIOR_MIN_TANGENTIAL_SUPPORT,
            "pixelEdgeMinimumRawPolarity": MINIMUM_RAW_POLARITY,
            "pixelEdgeMinimumEnhancedContrast": MINIMUM_ENHANCED_CONTRAST,
            "pixelEdgeRelativeEnhancedContrast": RELATIVE_ENHANCED_CONTRAST,
            "pixelEdgeSearchMinimumOffsetPx": SEARCH_MIN_OFFSET_PX,
            "pixelEdgeSearchMaximumOffsetPx": SEARCH_MAX_OFFSET_PX,
            "pixelEdgeTangentialSupportWidthPx": TANGENTIAL_SUPPORT_WIDTH_PX,
            "pixelEdgeMinimumTangentialSupportFraction": MINIMUM_TANGENTIAL_SUPPORT,
            "circleTrackHalfWidthPx": OUTER_BAND_HALF_WIDTH_PX,
            "circleRefinementPasses": 1,
            "circleFitPassCount": circle["fit"]["fitPassCount"],
            "maximumSelectedToFinalCircleDifferencePx": circle["fit"][
                "maximumSelectedToFinalCircleDifferencePx"
            ],
            "circleModel": "CENTER_LOCKED_TRUE_CIRCLE_RADIUS_FROM_FARTHEST_EXTERIOR_CONNECTED_BAND",
            "outerCircleFit": circle["fit"],
            "outerCircleQualified": circle["qualified"],
            "cyanGeometryChangedFromR17": False,
            "cyanGeometryVerificationState": (
                "PASS_DIAGNOSTIC_CYAN_GEOMETRY_SUPPORT_AND_HEADROOM"
                if cyan_geometry_verified
                else "HOLD_CYAN_GEOMETRY_UNVERIFIED"
            ),
            "cyanSearchHeadroomPx": search_headroom,
            "minimumCyanSearchHeadroomPx": MINIMUM_CYAN_SEARCH_HEADROOM_PX,
            "cyanAcceptedAngularCoverageFraction": circle["fit"]["angularCoverageFraction"],
            "minimumCyanAcceptedAngularCoverageFraction": MINIMUM_CYAN_ACCEPTED_COVERAGE,
            "cyanMaximumUnsupportedRunSamples": maximum_unsupported_samples,
            "cyanMaximumUnsupportedArcDegrees": float(
                maximum_unsupported_samples * 360.0 / strip.shape[1]
            ),
            "rawExteriorWitnessEnhancementUsed": raw_witness["enhancementUsed"],
            "rawExteriorWitnessObservedFraction": raw_witness["observedFraction"],
            "rawExteriorWitnessMedianResidualFromCyanPx": raw_witness[
                "medianResidualFromCyanPx"
            ],
            "rawExteriorWitnessP90AbsoluteResidualFromCyanPx": raw_witness[
                "p90AbsoluteResidualFromCyanPx"
            ],
            "rawExteriorWitnessTouchesOutwardSearchLimitColumnCount": raw_witness[
                "touchesOutwardSearchLimitColumnCount"
            ],
            "rawExteriorWitnessMovedCyan": raw_witness["cyanGeometryChanged"],
            "circleQualificationMinimumAcceptedCoverageFraction": MINIMUM_FINAL_ACCEPTED_COVERAGE,
            "circleQualificationMaximumAdjacentResidualJumpPx": MAXIMUM_FINAL_ADJACENT_RESIDUAL_JUMP_PX,
            "circleResidualStatisticsAreDiagnosticOnly": True,
            "edgeZoneInwardPx": EDGE_ZONE_INWARD_PX,
            "maximumEdgeZoneSpacingErrorPx": edge_zone_spacing_error,
            "innerCircleSharesOuterCenter": True,
            "perColumnPathAllowedToDefineReviewGeometry": False,
            "pathCenteredResamplingPerformed": False,
            "fixedFitUnshiftedReviewGeometry": True,
            "notchCandidateDetectionPerformed": True,
            "innerEdgeZonePixelEnhancementPerformed": False,
            "pixelEdgeFamilyUsedForNotchIdentification": True,
            "pixelEdgeFamilyContract": "NORMAL_CIRCLE_ANCHORED_STRONGEST_SUPPORTED_BEVEL_EDGE_PLUS_DEEP_EXTERIOR_FACING_NOTCH_TRACE",
            "normalBevelTraceTargetInwardPx": EDGE_ZONE_INWARD_PX,
            "normalBevelTraceInitialLaneHalfWidthPx": BEVEL_TRACE_LANE_HALF_WIDTH_PX,
            "normalBevelTraceCalibratedDeltaPx": pixel_edge["calibratedDeltaPx"],
            "normalBevelTraceCalibratedLaneHalfWidthPx": BEVEL_TRACE_CALIBRATED_HALF_WIDTH_PX,
            "normalBevelTraceMaximumAdjacentStepPxAllowed": BEVEL_TRACE_MAX_ADJACENT_STEP_PX,
            "normalBevelTraceDiscontinuityPassLimit": BEVEL_TRACE_DISCONTINUITY_PASSES,
            "minimumNormalBevelTraceCoverageFraction": MINIMUM_BEVEL_TRACE_COVERAGE,
            "normalBevelTraceCandidateFractionBeforeConsistency": pixel_edge[
                "normalCandidateFractionBeforeConsistency"
            ],
            "normalBevelTraceCalibratedCandidateFraction": pixel_edge[
                "normalCalibratedCandidateFraction"
            ],
            "normalBevelTraceObservedColumnCount": int(np.count_nonzero(pixel_edge["normalObserved"])),
            "normalBevelTraceObservedFraction": pixel_edge["normalObservedFraction"],
            "normalBevelTraceDiscontinuityHeldColumnCount": pixel_edge[
                "normalDiscontinuityHeldColumnCount"
            ],
            "normalBevelTraceMaximumAdjacentStepPx": pixel_edge["normalMaximumAdjacentStepPx"],
            "normalBevelTraceMaximumMissingRunSamples": pixel_edge["normalMaximumMissingRunSamples"],
            "deepNotchTraceObservedColumnCount": int(np.count_nonzero(pixel_edge["deepNotchObserved"])),
            "deepNotchTraceObservedFraction": pixel_edge["deepNotchObservedFraction"],
            "deepNotchTraceSearchMinimumOffsetPx": SEARCH_MIN_OFFSET_PX,
            "deepNotchTraceTouchesInwardLimitColumnCount": int(
                np.count_nonzero(pixel_edge["deepNotchTouchesInwardLimitColumns"])
            ),
            "notchCandidateTraceBranch": "DEEP_EXTERIOR_FACING_PIXEL_EDGE_TRACE",
            "pixelEdgeTraceInterpolationPerformed": pixel_edge["interpolationPerformed"],
            "pixelEdgeTraceChangesCoordinates": pixel_edge["coordinatesChanged"],
            "pixelEdgeDisplayedTraceComposition": "NORMAL_BEVEL_BRANCH_ONLY_PAIRING_NOT_YET_EVALUATED",
            "pixelEdgeDisplayedObservedColumnCount": int(np.count_nonzero(pixel_edge["normalObserved"])),
            "pixelEdgePairedNotchObservedColumnCount": 0,
            "pairedNotchTraceTouchesInwardLimitColumnCount": 0,
            "notchFrontierEnhancement": "DEEP_PIXEL_EDGE_BRANCH_USES_BROAD_TOPOLOGY_SHADOW_LIFT_WITH_RAW_POLARITY_CORROBORATION",
            "notchChannelContract": "BF_TOPOLOGY_CORROBORATION_DF_BOUNDED_RADIAL_CIRCLE_RETURNS",
            "transitionCoordinateConvention": "LAST_INSIDE_SAMPLE_CENTER_AT_OFFSETS_ROW",
            "notchSelectionPerformed": False,
            "notchCandidateCount": len(notch["candidates"]),
            "notchCandidateDepthThresholdPx": notch["thresholdPx"],
            "notchBaselineNoiseSigmaPx": notch["baselineNoiseSigmaPx"],
            "notchCandidates": notch["candidates"],
            "holderClassificationPerformed": False,
            "exteriorObstructionClassification": "COVERAGE_HOLD_NOT_HOLDER_IDENTITY",
            "exteriorObstructionOutwardResidualThresholdPx": HOLDER_OUTWARD_RESIDUAL_PX,
            "exteriorObstructionColumnCount": int(np.count_nonzero(exterior_obstruction)),
            "exteriorGuardMinimumOffsetPx": EXTERIOR_GUARD_MIN_OFFSET_PX,
            "exteriorGuardMaximumOffsetPx": EXTERIOR_GUARD_MAX_OFFSET_PX,
            "minimumExteriorCorridorFraction": EXTERIOR_MIN_CORRIDOR_FRACTION,
            "ambiguousInwardResidualThresholdPx": AMBIGUOUS_INWARD_RESIDUAL_PX,
            "ambiguousColumnCount": int(np.count_nonzero(ambiguous)),
            "frontierObservedColumnCount": int(np.count_nonzero(frontier_observed)),
            "frontierObservedFraction": float(np.mean(frontier_observed)),
            "predecessorHeldColumnCount": int(np.count_nonzero(~prior_measured)),
            "predecessorHoldsCleared": False,
            "candidateSelectionPerformed": False,
            "postResultSelectorRelaxationPerformed": False,
            "reviewOnly": True,
            "trainingEligible": False,
            "xmlEligible": False,
            "productionEligible": False,
        },
    }


def pair_notch_candidates(bf: dict[str, Any], df: dict[str, Any], params: Any) -> dict[str, Any]:
    """Compare independent channel candidates without selecting or clearing a hold."""
    if not bf["circleQualified"] or not df["circleQualified"]:
        return {
            "state": "HOLD_DIAGNOSTIC_CHANNEL_CIRCLE_NOT_QUALIFIED",
            "evaluated": False,
            "channelCircleComparison": {
                "evaluated": False,
                "reason": "BOTH_CHANNEL_CIRCLES_MUST_QUALIFY_INDEPENDENTLY",
                "poseAveraged": False,
            },
            "eligiblePairCount": 0,
            "candidateSelectionPerformed": False,
            "holdClearancePerformed": False,
        }
    center_difference = math.hypot(
        float(bf["circleFit"]["centerX"]) - float(df["circleFit"]["centerX"]),
        float(bf["circleFit"]["centerY"]) - float(df["circleFit"]["centerY"]),
    )
    radius_difference = abs(
        float(bf["circleFit"]["radius"]) - float(df["circleFit"]["radius"])
    )
    circle_comparison = {
        "evaluated": True,
        "centerDifferencePx": center_difference,
        "maximumCenterDifferencePx": float(params.maximum_channel_center_difference_px),
        "radiusDifferencePx": radius_difference,
        "maximumRadiusDifferencePx": float(params.maximum_channel_radius_difference_px),
        "poseAveraged": False,
        "qualified": bool(
            center_difference <= float(params.maximum_channel_center_difference_px)
            and radius_difference <= float(params.maximum_channel_radius_difference_px)
        ),
    }
    if not circle_comparison["qualified"]:
        return {
            "state": "HOLD_DIAGNOSTIC_BF_DF_PHYSICAL_CIRCLE_DISAGREEMENT",
            "evaluated": False,
            "channelCircleComparison": circle_comparison,
            "eligiblePairCount": 0,
            "candidateSelectionPerformed": False,
            "holdClearancePerformed": False,
        }
    bf_candidates = bf["notch"]["candidates"]
    df_candidates = df["notch"]["candidates"]
    physical: list[dict[str, Any]] = []
    eligible: list[dict[str, Any]] = []
    for bf_index, bf_candidate in enumerate(bf_candidates):
        for df_index, df_candidate in enumerate(df_candidates):
            gap = CORE.circular_distance_degrees(
                float(bf_candidate["centerAngleDegrees"]),
                float(df_candidate["centerAngleDegrees"]),
            )
            if gap > float(params.candidate_match_tolerance_degrees):
                continue
            overlap = CORE.interval_overlap_fraction(bf_candidate, df_candidate)
            combined_width = max(
                float(bf_candidate["widthDegrees"]), float(df_candidate["widthDegrees"])
            )
            combined_symmetry = max(
                float(bf_candidate["symmetryScore"]), float(df_candidate["symmetryScore"])
            )
            combined_tip_offset = min(
                float(bf_candidate["tipCenterOffsetFraction"]),
                float(df_candidate["tipCenterOffsetFraction"]),
            )
            combined_slope = max(
                float(bf_candidate["slopeConsistencyFraction"]),
                float(df_candidate["slopeConsistencyFraction"]),
            )
            manufactured = (
                float(params.manufactured_minimum_width_degrees)
                <= combined_width
                <= float(params.manufactured_maximum_width_degrees)
                and combined_symmetry >= float(params.manufactured_minimum_symmetry)
                and combined_tip_offset <= float(params.manufactured_maximum_tip_offset_fraction)
                and combined_slope >= float(params.manufactured_minimum_slope_consistency)
                and overlap >= float(params.manufactured_minimum_cross_channel_overlap)
                and bool(bf_candidate["manufacturedBfTopologyEligible"])
                and bool(df_candidate["manufacturedDfRadialEligible"])
            )
            row = {
                "bfCandidateIndex": bf_index,
                "dfCandidateIndex": df_index,
                "bfAngleDegrees": float(bf_candidate["centerAngleDegrees"]),
                "dfAngleDegrees": float(df_candidate["centerAngleDegrees"]),
                "channelAngleDifferenceDegrees": float(gap),
                "crossChannelOverlapFraction": float(overlap),
                "combinedWidthDegrees": combined_width,
                "combinedSymmetryScore": combined_symmetry,
                "combinedTipCenterOffsetFraction": combined_tip_offset,
                "combinedSlopeConsistencyFraction": combined_slope,
                "manufacturedNotchMorphologyEligible": bool(manufactured),
                "bf": bf_candidate,
                "df": df_candidate,
                "evidence": "COMPLETE_BF_DF_INDEPENDENT_CANDIDATE_GRAPH",
            }
            physical.append(row)
            if manufactured:
                eligible.append(row)
    bf_degrees = {
        index: sum(row["bfCandidateIndex"] == index for row in eligible)
        for index in range(len(bf_candidates))
    }
    df_degrees = {
        index: sum(row["dfCandidateIndex"] == index for row in eligible)
        for index in range(len(df_candidates))
    }
    graph_ambiguous = any(value > 1 for value in bf_degrees.values()) or any(
        value > 1 for value in df_degrees.values()
    )
    eligible_bf = {row["bfCandidateIndex"] for row in eligible}
    eligible_df = {row["dfCandidateIndex"] for row in eligible}
    unmatched_bf = [
        {"candidateIndex": index, **row}
        for index, row in enumerate(bf_candidates)
        if row["manufacturedBfTopologyEligible"] and index not in eligible_bf
    ]
    unmatched_df = [
        {"candidateIndex": index, **row}
        for index, row in enumerate(df_candidates)
        if row["manufacturedDfRadialEligible"] and index not in eligible_df
    ]
    if len(eligible) == 1 and not graph_ambiguous:
        state = (
            "DIAGNOSTIC_UNIQUE_MANUFACTURED_NOTCH_PAIR_WITH_UNPAIRED_CHANNEL_RESPONSES_HELD"
            if unmatched_bf or unmatched_df
            else "DIAGNOSTIC_UNIQUE_MANUFACTURED_NOTCH_PAIR_NO_UNMATCHED_RESPONSES"
        )
    elif not eligible:
        state = "HOLD_DIAGNOSTIC_NO_MANUFACTURED_NOTCH_PAIR"
    elif graph_ambiguous or len(eligible) > 1:
        state = "HOLD_DIAGNOSTIC_AMBIGUOUS_MANUFACTURED_NOTCH_GRAPH"
    else:
        state = "HOLD_DIAGNOSTIC_UNMATCHED_MANUFACTURED_CHANNEL_RESPONSE"
    unique_pair = state.startswith("DIAGNOSTIC_UNIQUE_")
    paired_bf = eligible_bf if unique_pair else set()
    paired_df = eligible_df if unique_pair else set()
    channel_semantics = (
        (bf, paired_bf, bf["notch"]["topologyCandidateColumns"]),
        (df, paired_df, df["notch"]["candidateColumns"]),
    )
    for physical_row, paired_indices, eligible_columns in channel_semantics:
        paired_columns = np.zeros_like(physical_row["pairedNotchColumns"])
        for index in paired_indices:
            paired_columns[physical_row["notch"]["candidateColumnSets"][index]] = True
        physical_row["pairedNotchColumns"] = paired_columns
        physical_row["unpairedNotchColumns"] = eligible_columns & ~paired_columns
        physical_row["ambiguousColumns"] |= physical_row["unpairedNotchColumns"]
        trace_path = physical_row["normalBevelTracePath"].copy()
        trace_observed = physical_row["normalBevelTraceObservedColumns"].copy()
        trace_path[paired_columns] = np.nan
        trace_observed[paired_columns] = False
        paired_trace = paired_columns & physical_row["deepNotchTraceObservedColumns"]
        paired_trace_at_inward_limit = (
            paired_trace & physical_row["deepNotchTraceTouchesInwardLimitColumns"]
        )
        trace_path[paired_trace] = physical_row["deepNotchTracePath"][paired_trace]
        trace_observed[paired_trace] = True
        diagnostic.need(
            bool(np.all(~paired_trace | trace_observed))
            and bool(np.all(~paired_trace | physical_row["deepNotchTraceObservedColumns"])),
            "R18 paired notch evidence is not a subset of observed pixel-edge trace data",
        )
        diagnostic.need(
            bool(
                np.allclose(
                    trace_path[paired_trace],
                    physical_row["deepNotchTracePath"][paired_trace],
                    rtol=0.0,
                    atol=0.0,
                )
            ),
            "R18 paired notch rendering does not use the identifying deep trace",
        )
        diagnostic.need(
            not bool(np.any(paired_trace_at_inward_limit)),
            "R18 paired notch trace touches the inward search limit",
        )
        physical_row["pixelEdgeTracePath"] = trace_path
        physical_row["pixelEdgeTraceObservedColumns"] = trace_observed
        physical_row["pixelEdgePairedNotchColumns"] = paired_trace
        physical_row["pairedNotchEvidenceColumns"] = paired_trace.copy()
        physical_row["evidence"]["pixelEdgeDisplayedTraceComposition"] = (
            "NORMAL_BEVEL_BRANCH_OUTSIDE_UNIQUE_PAIR_DEEP_NOTCH_BRANCH_INSIDE_UNIQUE_PAIR"
            if unique_pair
            else "NORMAL_BEVEL_BRANCH_ONLY_NO_UNIQUE_PAIR"
        )
        physical_row["evidence"]["pixelEdgeDisplayedObservedColumnCount"] = int(
            np.count_nonzero(trace_observed)
        )
        physical_row["evidence"]["pixelEdgePairedNotchObservedColumnCount"] = int(
            np.count_nonzero(paired_trace)
        )
        physical_row["evidence"]["pairedNotchTraceTouchesInwardLimitColumnCount"] = int(
            np.count_nonzero(paired_trace_at_inward_limit)
        )
    return {
        "state": state,
        "evaluated": True,
        "channelCircleComparison": circle_comparison,
        "physicalPairs": physical,
        "bfUnmatchedManufacturedResponses": unmatched_bf,
        "dfUnmatchedManufacturedResponses": unmatched_df,
        "eligiblePairs": eligible,
        "eligiblePairCount": len(eligible),
        "eligibleGraphAmbiguous": bool(graph_ambiguous),
        "candidateSelectionPerformed": False,
        "holdClearancePerformed": False,
    }


def apply_physical_boundary(
    measured: dict[str, Any],
    fit: dict[str, Any],
    params: Any,
    cfg: dict[str, Any],
) -> dict[str, Any]:
    physical = analyze_fixed_strip(
        measured["strip"],
        measured["offsets"],
        fit,
        params,
        cfg,
        measured.get("pathMeasured"),
    )
    measured["physicalBoundary"] = physical
    measured["evidence"].update(
        {
            "method": "NATIVE_PITCH_EXTERIOR_CONNECTED_CENTER_LOCKED_PHYSICAL_CIRCLE_DIAGNOSTIC_R18",
            "physicalBoundary": physical["evidence"],
            "predecessorPathRetainedAsDiagnosticData": True,
            "predecessorPathReviewEligibility": "WITHDRAWN_NOT_GEOMETRY_EVIDENCE",
            "normalizedStripReviewEligibility": "WITHDRAWN_WARNING_CARD_NO_PATH_CENTERED_PIXELS",
            "geometryReviewAssetRole": "physical_circle_full_review",
            "notchSelectionPerformed": False,
            "holderClassificationPerformed": False,
            "holdClearancePerformed": False,
        }
    )
    return measured


def unwrap(
    gray: np.ndarray,
    fit: dict[str, Any],
    crop: dict[str, Any],
    params: Any,
    cfg: dict[str, Any],
) -> dict[str, Any]:
    measured = r13.unwrap(gray, fit, crop, params, cfg)
    return apply_physical_boundary(measured, fit, params, cfg)


def draw_circle_path(
    overlay: np.ndarray,
    mask: np.ndarray,
    path: np.ndarray,
    offsets: np.ndarray,
    color: tuple[int, int, int],
) -> None:
    rows = np.rint(path.astype(np.float64) - float(offsets[0])).astype(np.int32)
    columns = np.arange(path.size, dtype=np.int32)
    valid = (rows >= 0) & (rows < overlay.shape[0])
    for run in diagnostic.runs(valid):
        if run.size >= 2:
            points = np.column_stack((columns[run], rows[run])).astype(np.int32)
            cv2.polylines(overlay, [points], False, color, 1, cv2.LINE_8)
            cv2.polylines(mask, [points], False, 255, 1, cv2.LINE_8)


def draw_evidence_points(
    overlay: np.ndarray,
    mask: np.ndarray,
    path: np.ndarray,
    selected: np.ndarray,
    offsets: np.ndarray,
    color: tuple[int, int, int],
) -> None:
    columns = np.flatnonzero(selected & np.isfinite(path))
    rows = np.rint(path[columns].astype(np.float64) - float(offsets[0])).astype(np.int32)
    valid = (rows >= 0) & (rows < overlay.shape[0])
    overlay[rows[valid], columns[valid]] = color
    mask[rows[valid], columns[valid]] = 255


def warning_card() -> np.ndarray:
    card = np.zeros((220, diagnostic.REVIEW_SEGMENT_WIDTH_PX, 3), dtype=np.uint8)
    lines = (
        "PATH-CENTERED PIXEL VIEW WITHDRAWN",
        "Per-column recentering creates the wavy/mirage surround.",
        "R18 review uses only the unshifted fixed-fit annular strip.",
        "CYAN/YELLOW are exact concentric physical circles; LIME cannot warp them.",
    )
    for row, line in enumerate(lines):
        cv2.putText(
            card,
            line,
            (24, 42 + row * 42),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.75,
            (0, 0, 255) if row == 0 else (255, 255, 255),
            2,
            cv2.LINE_8,
        )
    return card


def dedicated_notch_review(
    contour_overlay: np.ndarray,
    contour_mask: np.ndarray,
    offsets: np.ndarray,
    paired_columns: np.ndarray,
    paired_trace_path: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, dict[str, Any]]:
    """Return a native-pixel cyclic crop showing the complete paired notch."""
    width = contour_overlay.shape[1]
    selected = np.flatnonzero(paired_columns)
    rows = (offsets >= -NOTCH_REVIEW_INWARD_PX) & (offsets <= NOTCH_REVIEW_OUTWARD_PX)
    diagnostic.need(bool(np.any(rows)), "R18 dedicated notch review radial window is empty")
    if selected.size == 0:
        shape = (
            int(np.count_nonzero(rows)) + NOTCH_REVIEW_HEADER_PX,
            2 * NOTCH_REVIEW_HALF_WIDTH_COLUMNS + 1,
            3,
        )
        hold = np.zeros(shape, dtype=np.uint8)
        cv2.putText(
            hold,
            "HOLD: NO UNIQUE PAIRED NOTCH; NO ORANGE CONTOUR REVIEW EMITTED",
            (7, 29),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.45,
            (255, 255, 255),
            1,
            cv2.LINE_8,
        )
        return hold, np.zeros(shape[:2], dtype=np.uint8), {
            "state": "HOLD_NO_UNIQUE_PAIRED_NOTCH_REVIEW",
            "pairedTraceEvidenceCount": 0,
            "pairedTraceEvidenceVisibleCount": 0,
            "pairedTraceEvidenceClippedCount": 0,
            "resamplingPerformed": False,
            "pathCenteredWarpPerformed": False,
            "statusBarsRendered": False,
        }
    phase = np.angle(np.mean(np.exp(2j * np.pi * selected.astype(np.float64) / width)))
    center = int(round((phase % (2.0 * np.pi)) * width / (2.0 * np.pi))) % width
    signed_distance = ((selected - center + width // 2) % width) - width // 2
    diagnostic.need(
        int(np.max(np.abs(signed_distance))) <= NOTCH_REVIEW_HALF_WIDTH_COLUMNS,
        "R18 paired notch exceeds the dedicated review angular window",
    )
    relative = np.arange(
        -NOTCH_REVIEW_HALF_WIDTH_COLUMNS,
        NOTCH_REVIEW_HALF_WIDTH_COLUMNS + 1,
        dtype=np.int32,
    )
    columns = (center + relative) % width
    crop = contour_overlay[rows][:, columns].copy()
    crop_mask = contour_mask[rows][:, columns].copy()
    labeled = cv2.copyMakeBorder(
        crop, NOTCH_REVIEW_HEADER_PX, 0, 0, 0, cv2.BORDER_CONSTANT
    )
    labeled_mask = cv2.copyMakeBorder(
        crop_mask, NOTCH_REVIEW_HEADER_PX, 0, 0, 0, cv2.BORDER_CONSTANT
    )
    center_degrees = center * 360.0 / width
    label = (
        "NATIVE 1:1 FULL-DEPTH NOTCH | CYAN outer | YELLOW -20px | "
        f"LIME edge | ORANGE paired notch | center {center_degrees:.3f}deg | NO STATUS BARS"
    )
    cv2.putText(
        labeled,
        label,
        (7, 21),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.35,
        (255, 255, 255),
        1,
        cv2.LINE_8,
    )
    labeled_mask[:NOTCH_REVIEW_HEADER_PX] = 255
    paired_evidence = paired_columns & np.isfinite(paired_trace_path)
    visible_evidence = paired_evidence & (
        (paired_trace_path >= -NOTCH_REVIEW_INWARD_PX)
        & (paired_trace_path <= NOTCH_REVIEW_OUTWARD_PX)
    )
    diagnostic.need(
        bool(np.all(~paired_evidence | visible_evidence)),
        "R18 dedicated notch review clips paired trace evidence",
    )
    return labeled, labeled_mask, {
        "state": "COMPLETE_NATIVE_PIXEL_FULL_DEPTH_PAIRED_NOTCH_REVIEW",
        "centerColumn": center,
        "centerAngleDegrees": center_degrees,
        "sourceColumnCount": int(columns.size),
        "sourceColumnStart": int(columns[0]),
        "sourceColumnEnd": int(columns[-1]),
        "cyclicWrapUsed": bool(columns[0] > columns[-1]),
        "radialMinimumOffsetPx": float(np.min(offsets[rows])),
        "radialMaximumOffsetPx": float(np.max(offsets[rows])),
        "pairedTraceEvidenceCount": int(np.count_nonzero(paired_evidence)),
        "pairedTraceEvidenceVisibleCount": int(np.count_nonzero(visible_evidence)),
        "pairedTraceEvidenceClippedCount": int(
            np.count_nonzero(paired_evidence & ~visible_evidence)
        ),
        "resamplingPerformed": False,
        "pathCenteredWarpPerformed": False,
        "statusBarsRendered": False,
    }


def render(root: Path, pair_id: str, channel: str, measured: dict[str, Any]) -> dict[str, Any]:
    physical = measured["physicalBoundary"]
    raw = measured["strip"]
    offsets = measured["offsets"]
    enhanced = shadow_lift(raw)
    overlay = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    outer_mask = np.zeros(raw.shape, dtype=np.uint8)
    inner_mask = np.zeros(raw.shape, dtype=np.uint8)
    observed_mask = np.zeros(raw.shape, dtype=np.uint8)
    pixel_edge_trace_mask = np.zeros(raw.shape, dtype=np.uint8)
    notch_mask = np.zeros(raw.shape, dtype=np.uint8)
    predecessor_hold_mask = np.zeros(raw.shape, dtype=np.uint8)
    exterior_obstruction_mask = np.zeros(raw.shape, dtype=np.uint8)
    missing_mask = np.zeros(raw.shape, dtype=np.uint8)
    ambiguous_mask = np.zeros(raw.shape, dtype=np.uint8)
    draw_circle_path(overlay, outer_mask, physical["outerPath"], offsets, (255, 255, 0))
    draw_circle_path(overlay, inner_mask, physical["innerPath"], offsets, (0, 255, 255))
    draw_evidence_points(
        overlay,
        observed_mask,
        physical["selectedOffsets"],
        physical["finalSupportColumns"],
        offsets,
        (0, 0, 255),
    )
    draw_evidence_points(
        overlay,
        pixel_edge_trace_mask,
        physical["pixelEdgeTracePath"],
        physical["pixelEdgeTraceObservedColumns"],
        offsets,
        (0, 255, 0),
    )
    draw_evidence_points(
        overlay,
        notch_mask,
        physical["pixelEdgeTracePath"],
        physical["pixelEdgePairedNotchColumns"],
        offsets,
        (0, 128, 255),
    )
    contour_overlay = overlay.copy()
    orange_pixels = np.all(
        contour_overlay == np.asarray((0, 128, 255), dtype=np.uint8), axis=2
    )
    diagnostic.need(
        bool(np.array_equal(orange_pixels, notch_mask > 0)),
        "R18 orange contour pixels are not exactly the paired notch trace mask",
    )
    circle_only_overlay = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    circle_only_outer_mask = np.zeros(raw.shape, dtype=np.uint8)
    circle_only_inner_mask = np.zeros(raw.shape, dtype=np.uint8)
    draw_circle_path(
        circle_only_overlay,
        circle_only_outer_mask,
        physical["outerPath"],
        offsets,
        (255, 255, 0),
    )
    draw_circle_path(
        circle_only_overlay,
        circle_only_inner_mask,
        physical["innerPath"],
        offsets,
        (0, 255, 255),
    )
    geometry_union_mask = cv2.bitwise_or(outer_mask, inner_mask)
    for layer in (observed_mask, pixel_edge_trace_mask, notch_mask):
        geometry_union_mask = cv2.bitwise_or(geometry_union_mask, layer)
    predecessor_held = physical["predecessorHeldColumns"]
    if np.any(predecessor_held):
        overlay[:HOLD_BAR_ROWS, predecessor_held] = (255, 0, 255)
        predecessor_hold_mask[:HOLD_BAR_ROWS, predecessor_held] = 255
    exterior_obstruction = physical["exteriorObstructionColumns"]
    if np.any(exterior_obstruction):
        overlay[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, exterior_obstruction] = (255, 0, 128)
        exterior_obstruction_mask[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, exterior_obstruction] = 255
    missing = ~physical["pixelEdgeTraceObservedColumns"]
    if np.any(missing):
        overlay[2 * HOLD_BAR_ROWS : 3 * HOLD_BAR_ROWS, missing] = (255, 0, 0)
        missing_mask[2 * HOLD_BAR_ROWS : 3 * HOLD_BAR_ROWS, missing] = 255
    if np.any(physical["ambiguousColumns"]):
        ambiguous_mask[3 * HOLD_BAR_ROWS : 4 * HOLD_BAR_ROWS, physical["ambiguousColumns"]] = 255
    rendered_union_mask = geometry_union_mask.copy()
    for layer in (
        predecessor_hold_mask,
        exterior_obstruction_mask,
        missing_mask,
    ):
        rendered_union_mask = cv2.bitwise_or(rendered_union_mask, layer)
    all_evidence_mask = cv2.bitwise_or(rendered_union_mask, ambiguous_mask)
    changed = np.any(overlay != cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR), axis=2)
    diagnostic.need(
        bool(np.all(~changed | (rendered_union_mask > 0))),
        "R18 overlay changed pixels outside declared rendered masks",
    )

    zone_rows = (offsets >= -ZONE_REVIEW_INWARD_PX) & (offsets <= ZONE_REVIEW_OUTWARD_PX)
    diagnostic.need(bool(np.any(zone_rows)), "R18 edge-zone review crop is empty")
    zone_raw = raw[zone_rows]
    zone_enhanced = enhanced[zone_rows]
    zone_overlay = overlay[zone_rows].copy()
    zone_union = rendered_union_mask[zone_rows].copy()
    zone_predecessor_hold = np.zeros(zone_raw.shape, dtype=np.uint8)
    zone_exterior_obstruction = np.zeros(zone_raw.shape, dtype=np.uint8)
    zone_missing = np.zeros(zone_raw.shape, dtype=np.uint8)
    zone_ambiguous = np.zeros(zone_raw.shape, dtype=np.uint8)
    if np.any(predecessor_held):
        zone_overlay[:HOLD_BAR_ROWS, predecessor_held] = (255, 0, 255)
        zone_predecessor_hold[:HOLD_BAR_ROWS, predecessor_held] = 255
    if np.any(exterior_obstruction):
        zone_overlay[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, exterior_obstruction] = (255, 0, 128)
        zone_exterior_obstruction[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, exterior_obstruction] = 255
    if np.any(missing):
        zone_overlay[2 * HOLD_BAR_ROWS : 3 * HOLD_BAR_ROWS, missing] = (255, 0, 0)
        zone_missing[2 * HOLD_BAR_ROWS : 3 * HOLD_BAR_ROWS, missing] = 255
    if np.any(physical["ambiguousColumns"]):
        zone_ambiguous[3 * HOLD_BAR_ROWS : 4 * HOLD_BAR_ROWS, physical["ambiguousColumns"]] = 255
    for layer in (zone_predecessor_hold, zone_exterior_obstruction, zone_missing):
        zone_union = cv2.bitwise_or(zone_union, layer)
    zone_hold = cv2.bitwise_or(
        zone_predecessor_hold,
        cv2.bitwise_or(
            zone_exterior_obstruction,
            cv2.bitwise_or(zone_missing, zone_ambiguous),
        ),
    )
    legend = "NARROW -48..+24 NORMAL-EDGE VIEW; USE notch_review FOR FULL DEPTH | CYAN outer | YELLOW -20px | LIME pixel edge | RED fit | ORANGE paired notch | bars: MAGENTA prior, PINK exterior hold, BLUE missing; ambiguity only in hold mask"
    edge_review = diagnostic.segmented_review(zone_overlay, legend)
    full_review = diagnostic.segmented_review(
        enhanced,
        "CLEAN OPERATOR SHADOW-LIFT FULL 180-IN/55-OUT | PIXELWISE ONLY; NO GEOMETRIC WARP",
    )
    physical_review = diagnostic.segmented_review(
        contour_overlay,
        "FULL 180-IN/55-OUT CONTOUR | CYAN outer | YELLOW -20px | LIME pixel edge | RED fit evidence | ORANGE paired notch | NO STATUS BARS",
    )
    circle_only_review = diagnostic.segmented_review(
        circle_only_overlay,
        "FULL 180-IN/55-OUT CIRCLE PLACEMENT ONLY | CYAN outer | YELLOW -20px | NO PIXEL TRACE OR STATUS BARS",
    )
    notch_review, notch_review_mask, notch_review_metadata = dedicated_notch_review(
        contour_overlay,
        geometry_union_mask,
        offsets,
        physical["pairedNotchColumns"],
        physical["pixelEdgeTracePath"],
    )

    top = 28
    labeled_overlay = cv2.copyMakeBorder(zone_overlay, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    labeled_mask = cv2.copyMakeBorder(zone_union, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    labeled_hold = cv2.copyMakeBorder(zone_hold, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    header_mask = np.zeros(labeled_overlay.shape[:2], dtype=np.uint8)
    header_mask[:top] = 255
    cv2.putText(labeled_overlay, legend, (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.38, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(labeled_mask, "UNION OF DECLARED R18 ANNOTATION MASKS", (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.43, 255, 1, cv2.LINE_8)
    cv2.putText(labeled_hold, "R18 PRIOR/EXTERIOR/MISSING/AMBIGUITY HOLD MASK; AMBIGUITY NOT DRAWN ON CONTOUR", (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.38, 255, 1, cv2.LINE_8)

    stem = hashlib.sha256(pair_id.encode("utf-8")).hexdigest()[:16]
    assets: dict[str, Any] = {}
    roles = (
        ("clean", zone_raw),
        ("enhanced", zone_enhanced),
        ("overlay", labeled_overlay),
        ("mask", labeled_mask),
        ("hold_mask", labeled_hold),
        ("edge_review", edge_review),
        ("normalized_review", warning_card()),
        ("full_clean", raw),
        ("full_enhanced", enhanced),
        ("full_overlay", contour_overlay),
        ("full_status_overlay", overlay),
        ("full_review", full_review),
        ("damage_review", physical_review),
        ("physical_circle_full_review", physical_review),
        ("circle_only_full_review", circle_only_review),
        ("notch_review", notch_review),
        ("notch_review_mask", notch_review_mask),
        ("outer_circle_mask", outer_mask),
        ("inner_circle_mask", inner_mask),
        ("accepted_outer_pixel_mask", observed_mask),
        ("pixel_bevel_notch_trace_mask", pixel_edge_trace_mask),
        ("paired_notch_trace_mask", notch_mask),
        ("predecessor_hold_mask", predecessor_hold_mask),
        ("exterior_obstruction_mask", exterior_obstruction_mask),
        ("missing_pixel_edge_trace_mask", missing_mask),
        ("ambiguous_inward_mask", ambiguous_mask),
        ("contour_annotation_union_mask", geometry_union_mask),
        ("annotation_union_mask", rendered_union_mask),
        ("all_evidence_including_unrendered_ambiguity_mask", all_evidence_mask),
        ("review_header_mask", header_mask),
    )
    for role, image in roles:
        path = root / f"{stem}_{channel.lower()}_annular_{role}.png"
        diagnostic.need(not path.exists(), f"R18 refuses asset overwrite: {path}")
        diagnostic.need(cv2.imwrite(str(path), image), f"OpenCV write failed: {path}")
        assets[role] = {
            "path": str(path),
            "bytes": path.stat().st_size,
            "sha256": diagnostic.sha256(path),
        }
    assets["notch_review"].update(notch_review_metadata)
    physical["evidence"]["dedicatedNotchReview"] = notch_review_metadata
    physical["evidence"]["orangePixelsEqualPairedNotchTraceMask"] = True
    physical["evidence"]["ambiguityStatusRenderedOnContour"] = False
    assets["normalized_review"]["reviewEligibility"] = "WITHDRAWN_WARNING_CARD_NO_PATH_CENTERED_PIXELS"
    assets["physical_circle_full_review"]["reviewEligibility"] = "GEOMETRY_EDGE_ZONE_NOTCH_AND_HOLDER_REVIEW"
    return assets


def run_local_strip_review(
    predecessor_summary_path: Path,
    predecessor_summary_sha256: str,
    job_path: Path,
    job_sha256: str,
    output: Path,
) -> int:
    """Reproduce a review from hash-pinned clean annular strips without live access."""
    diagnostic.need(output.is_absolute() and output.drive.upper() == "C:" and not output.exists(),
                    "Local output must be a fresh C: root")
    diagnostic.need(len(str(output)) + 96 < 200, "Local output path budget failed")
    diagnostic.need(predecessor_summary_path.is_file(), "Local predecessor summary is missing")
    diagnostic.need(job_path.is_file(), "Local job is missing")
    diagnostic.need(
        diagnostic.sha256(predecessor_summary_path) == predecessor_summary_sha256.upper(),
        "Local predecessor summary hash changed",
    )
    diagnostic.need(
        diagnostic.sha256(job_path) == job_sha256.upper(),
        "Local job hash changed",
    )
    predecessor = json.loads(predecessor_summary_path.read_text(encoding="utf-8"))
    job = json.loads(job_path.read_text(encoding="utf-8"))
    diagnostic.need(bool(predecessor.get("reviewOnly")), "Predecessor is not review-only")
    for key in ("trainingEligible", "xmlEligible", "productionEligible", "providerActivated",
                "sourceMutationPerformed", "existingTaskOrProcessActionPerformed"):
        diagnostic.need(not bool(predecessor.get(key)), f"Predecessor authority forbids local mode: {key}")
    for key in ("trainingEligible", "xmlEligible", "productionEligible", "providerActivationAllowed",
                "sourceMutationAllowed", "processorActionAllowed", "holdClearanceAllowed"):
        diagnostic.need(not bool(job.get(key)), f"Job authority forbids local mode: {key}")
    diagnostic.need(bool(job.get("reviewOnly")), "Job is not review-only")
    params = diagnostic.R11.parameters_from_job(job)
    cfg = job["topologyConfig"]
    offsets = np.arange(
        -int(cfg["maximumInwardPx"]),
        int(cfg["maximumOutwardPx"]) + 1,
        dtype=np.float32,
    )
    output.mkdir()
    (output / "cases").mkdir()
    results: list[dict[str, Any]] = []
    for ordinal, prior_result in enumerate(predecessor["results"], 1):
        case_root = output / "cases" / f"C{ordinal:04d}"
        case_root.mkdir()
        measured_by_channel: dict[str, Any] = {}
        physical_by_channel: dict[str, Any] = {}
        channel_rows: dict[str, Any] = {}
        for channel in ("BF", "DF"):
            prior_channel = prior_result["channels"][channel]
            source_record = prior_channel["sourceFullClean"]
            source_path = Path(source_record["path"])
            hold_record = prior_channel["assets"]["predecessor_hold_mask"]
            hold_path = Path(hold_record["path"])
            for path, record, role in (
                (source_path, source_record, "clean annular source"),
                (hold_path, hold_record, "predecessor hold mask"),
            ):
                diagnostic.need(path.is_file(), f"Missing {channel} {role}")
                diagnostic.need(path.stat().st_size == int(record["bytes"]),
                                f"{channel} {role} byte count changed")
                diagnostic.need(diagnostic.sha256(path) == str(record["sha256"]).upper(),
                                f"{channel} {role} hash changed")
            strip = cv2.imread(str(source_path), cv2.IMREAD_GRAYSCALE)
            hold_mask = cv2.imread(str(hold_path), cv2.IMREAD_GRAYSCALE)
            diagnostic.need(strip is not None and hold_mask is not None,
                            f"{channel} local OpenCV decode failed")
            diagnostic.need(strip.shape[0] == offsets.size and hold_mask.shape == strip.shape,
                            f"{channel} local strip geometry changed")
            predecessor_measured = ~np.any(hold_mask > 0, axis=0)
            physical = analyze_fixed_strip(
                strip, offsets, prior_channel["baseFit"], params, cfg, predecessor_measured
            )
            measured_by_channel[channel] = {
                "strip": strip,
                "offsets": offsets,
                "physicalBoundary": physical,
            }
            physical_by_channel[channel] = physical
            channel_rows[channel] = {
                "sourceFullClean": {**source_record, "actualSha256": diagnostic.sha256(source_path), "hashMatched": True},
                "inputPredecessorHoldMask": {**hold_record, "actualSha256": diagnostic.sha256(hold_path), "hashMatched": True},
                "decodedGeometry": {"rows": int(strip.shape[0]), "columns": int(strip.shape[1]), "dtype": str(strip.dtype)},
                "radialOffsets": {"startPx": float(offsets[0]), "endPx": float(offsets[-1]),
                                  "count": int(offsets.size), "pitchPx": 1.0},
                "predecessorMeasuredMaskDerivation": "COLUMN_MEASURED_IFF_INPUT_PREDECESSOR_HOLD_MASK_HAS_NO_NONZERO_PIXEL",
                "baseFit": prior_channel["baseFit"],
                "baseFitSourceJsonPointer": f"/results/{ordinal - 1}/channels/{channel}/baseFit",
                "circleState": physical["circleState"],
                "circleFit": physical["circleFit"],
                "physicalBoundary": physical["evidence"],
                "notchCandidates": physical["notch"]["candidates"],
                "acceptedOuterPixelCount": int(np.count_nonzero(physical["finalSupportColumns"])),
            }
        pair = pair_notch_candidates(physical_by_channel["BF"], physical_by_channel["DF"], params)
        diagnostic.need(pair["eligiblePairCount"] == 1 and pair["state"].startswith("DIAGNOSTIC_UNIQUE_"),
                        f"Case {ordinal} lacks one unique notch pair")
        for channel in ("BF", "DF"):
            physical = physical_by_channel[channel]
            diagnostic.need(physical["circleQualified"], f"Case {ordinal} {channel} circle held")
            spacing_error = float(
                np.max(
                    np.abs(
                        (physical["outerPath"] - physical["innerPath"])
                        - EDGE_ZONE_INWARD_PX
                    )
                )
            )
            paired_evidence = physical["pixelEdgePairedNotchColumns"]
            paired_evidence_observed = bool(
                np.all(~paired_evidence | physical["pixelEdgeTraceObservedColumns"])
                and np.all(~paired_evidence | physical["deepNotchTraceObservedColumns"])
            )
            paired_evidence_equal = bool(
                np.allclose(
                    physical["pixelEdgeTracePath"][paired_evidence],
                    physical["deepNotchTracePath"][paired_evidence],
                    rtol=0.0,
                    atol=0.0,
                )
            )
            diagnostic.need(spacing_error <= 1.0e-4, f"Case {ordinal} {channel} edge-zone spacing changed")
            diagnostic.need(
                physical["notch"]["sourceTraceUsedForNotchIdentification"]
                and physical["notch"]["sourceTrace"]
                == "DEEP_EXTERIOR_FACING_PIXEL_EDGE_TRACE",
                f"Case {ordinal} {channel} notch input is not the pixel-edge trace",
            )
            diagnostic.need(
                not physical["evidence"]["pixelEdgeTraceInterpolationPerformed"]
                and not physical["evidence"]["pixelEdgeTraceChangesCoordinates"],
                f"Case {ordinal} {channel} pixel-edge trace changed fixed coordinates",
            )
            diagnostic.need(
                paired_evidence_observed and paired_evidence_equal,
                f"Case {ordinal} {channel} paired notch evidence is not observed deep-trace data",
            )
            diagnostic.need(
                physical["evidence"]["pairedNotchTraceTouchesInwardLimitColumnCount"] == 0,
                f"Case {ordinal} {channel} paired notch trace touches its inward search limit",
            )
            assets = render(case_root, str(prior_result["safeId"]), channel, measured_by_channel[channel])
            diagnostic.need(
                assets["full_clean"]["sha256"]
                == str(channel_rows[channel]["sourceFullClean"]["sha256"]).upper(),
                f"Case {ordinal} {channel} clean raster provenance changed",
            )
            channel_rows[channel]["pairedNotchColumnCount"] = int(
                np.count_nonzero(physical["pairedNotchColumns"])
            )
            channel_rows[channel]["pairedNotchEvidenceColumnCount"] = int(
                np.count_nonzero(paired_evidence)
            )
            channel_rows[channel]["edgeZoneSpacingMaximumErrorPx"] = spacing_error
            channel_rows[channel]["pixelEdgeNotchInputVerified"] = True
            channel_rows[channel]["pixelEdgeTraceInterpolationPerformed"] = False
            channel_rows[channel]["pixelEdgeTraceChangesCoordinates"] = False
            channel_rows[channel]["pairedNotchEvidenceObserved"] = paired_evidence_observed
            channel_rows[channel]["pairedNotchEvidenceMatchesDeepTrace"] = paired_evidence_equal
            channel_rows[channel]["pairedNotchTouchesInwardSearchLimit"] = False
            channel_rows[channel]["cyanGeometryVerified"] = physical["cyanGeometryVerified"]
            channel_rows[channel]["cyanGeometryVerificationState"] = physical[
                "cyanGeometryVerificationState"
            ]
            channel_rows[channel]["dedicatedNotchReviewComplete"] = (
                assets["notch_review"]["state"]
                == "COMPLETE_NATIVE_PIXEL_FULL_DEPTH_PAIRED_NOTCH_REVIEW"
            )
            channel_rows[channel]["dedicatedNotchReviewClippedEvidenceCount"] = assets[
                "notch_review"
            ]["pairedTraceEvidenceClippedCount"]
            channel_rows[channel]["dedicatedNotchReviewResamplingPerformed"] = assets[
                "notch_review"
            ]["resamplingPerformed"]
            channel_rows[channel]["dedicatedNotchReviewStatusBarsRendered"] = assets[
                "notch_review"
            ]["statusBarsRendered"]
            channel_rows[channel]["assets"] = assets
        case_cyan_verified = all(
            channel_rows[channel]["cyanGeometryVerified"] for channel in ("BF", "DF")
        )
        results.append(
            {
                "ordinal": ordinal,
                "identity": prior_result["identity"],
                "safeId": prior_result["safeId"],
                "state": (
                    "DIAGNOSTIC_ONLY_R18_ANNULAR_COMPLETE_UNSELECTED_UNIQUE_PAIR"
                    if case_cyan_verified
                    else "HOLD_R18_CYAN_GEOMETRY_UNVERIFIED_WITH_UNIQUE_NOTCH_PAIR"
                ),
                "channels": channel_rows,
                "pairDiagnostic": pair,
            }
        )
    loaded_dependencies = []
    for loaded in sys.modules.values():
        loaded_path_text = getattr(loaded, "__file__", None)
        if not loaded_path_text:
            continue
        loaded_path = Path(loaded_path_text).resolve()
        if loaded_path.suffix.lower() == ".py" and loaded_path.parent == HERE and loaded_path != Path(__file__).resolve():
            loaded_dependencies.append(loaded_path)
    loaded_dependencies = sorted(set(loaded_dependencies), key=lambda path: str(path).lower())
    summary = {
        "schema": "argos_ocv03_annular_unwrap_exterior_circle_bevel_trace_diagnostic_r18_local_v1",
        "state": "COMPLETE_DIAGNOSTIC_ONLY_R18_LOCAL_ANNULAR_UNWRAP",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "detectorRevision": "R18",
        "disposition": "DIAGNOSTIC_ONLY_CYAN_HOLD_PENDING_OPERATOR_REVIEW",
        "visualReviewState": "PENDING_OPERATOR_REVIEW",
        "argv": list(sys.argv),
        "outputRoot": str(output),
        "outputRootExistedBeforeRun": False,
        "engine": {"path": str(Path(__file__).resolve()), "bytes": Path(__file__).stat().st_size,
                   "sha256": diagnostic.sha256(Path(__file__).resolve())},
        "loadedDependencies": [
            {"path": str(path), "bytes": path.stat().st_size, "sha256": diagnostic.sha256(path)}
            for path in loaded_dependencies
        ],
        "predecessorSummary": {"path": str(predecessor_summary_path),
                               "bytes": predecessor_summary_path.stat().st_size,
                               "sha256": predecessor_summary_sha256.upper(),
                               "schema": predecessor.get("schema"), "state": predecessor.get("state")},
        "predecessorUsage": "LOCKED_CLEAN_STRIP_INDEX_BASE_FIT_AND_HOLD_MASK_ONLY_R15_SELECTOR_NOT_INHERITED",
        "job": {"path": str(job_path), "bytes": job_path.stat().st_size,
                "sha256": job_sha256.upper(), "schema": job.get("schema"), "revision": job.get("revision")},
        "effectiveParameters": job["parameters"],
        "effectiveTopologyConfig": cfg,
        "runtime": {"executable": sys.executable, "python": sys.version.split()[0],
                    "opencv": cv2.__version__, "numpy": np.__version__},
        "commandMode": "HASH_PINNED_LOCAL_CLEAN_ANNULAR_STRIPS",
        "frontPreflightContextCalled": False,
        "driveAliasActionPerformed": False,
        "portalActionPerformed": False,
        "jbodActionPerformed": False,
        "requestedCount": len(results),
        "completedCount": len(results),
        "results": results,
        "cyanGeometryHoldCount": sum(
            not row["channels"][channel]["cyanGeometryVerified"]
            for row in results for channel in ("BF", "DF")
        ),
        "candidateSelectionPerformed": False,
        "postResultSelectorRelaxationPerformed": False,
        "holdClearancePerformed": False,
        "sourceMutationPerformed": False,
        "providerActivated": False,
        "existingTaskOrProcessActionPerformed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    diagnostic.atomic_json(output / "SUMMARY.json", summary)
    all_cyan_geometry_verified = all(
        row["channels"][channel]["cyanGeometryVerified"]
        for row in results for channel in ("BF", "DF")
    )
    gate = {
        "schema": "argos_ocv03_annular_unwrap_r18_local_detector_gate_v1",
        "state": (
            "PASS_R18_LOCAL_DETECTOR_GATE"
            if all_cyan_geometry_verified
            else "HOLD_R18_LOCAL_CYAN_GEOMETRY_REVIEW_REQUIRED"
        ),
        "summary": {"path": str(output / "SUMMARY.json"), "sha256": diagnostic.sha256(output / "SUMMARY.json")},
        "caseCount": len(results),
        "uniqueNotchPairCount": sum(row["pairDiagnostic"]["eligiblePairCount"] == 1 for row in results),
        "allCirclesCenterLocked": all(
            row["channels"][channel]["circleFit"]["centerLockedToIndependentFullWaferFit"]
            for row in results for channel in ("BF", "DF")
        ),
        "maximumAdjacentAcceptedResidualJumpPx": max(
            row["channels"][channel]["circleFit"]["maximumAdjacentAcceptedResidualJumpPx"]
            for row in results for channel in ("BF", "DF")
        ),
        "maximumEdgeZoneSpacingErrorPx": max(
            row["channels"][channel]["edgeZoneSpacingMaximumErrorPx"]
            for row in results for channel in ("BF", "DF")
        ),
        "allPixelEdgeNotchInputsVerified": all(
            row["channels"][channel]["pixelEdgeNotchInputVerified"]
            for row in results for channel in ("BF", "DF")
        ),
        "pixelEdgeTraceInterpolationPerformed": any(
            row["channels"][channel]["pixelEdgeTraceInterpolationPerformed"]
            for row in results for channel in ("BF", "DF")
        ),
        "pixelEdgeTraceCoordinateChangePerformed": any(
            row["channels"][channel]["pixelEdgeTraceChangesCoordinates"]
            for row in results for channel in ("BF", "DF")
        ),
        "allPairedNotchEvidenceObserved": all(
            row["channels"][channel]["pairedNotchEvidenceObserved"]
            for row in results for channel in ("BF", "DF")
        ),
        "allPairedNotchEvidenceMatchesDeepTrace": all(
            row["channels"][channel]["pairedNotchEvidenceMatchesDeepTrace"]
            for row in results for channel in ("BF", "DF")
        ),
        "allPairedNotchTracesClearOfInwardSearchLimit": all(
            not row["channels"][channel]["pairedNotchTouchesInwardSearchLimit"]
            for row in results for channel in ("BF", "DF")
        ),
        "allDedicatedNotchReviewsComplete": all(
            row["channels"][channel]["dedicatedNotchReviewComplete"]
            for row in results for channel in ("BF", "DF")
        ),
        "dedicatedNotchReviewClippedEvidenceCount": sum(
            row["channels"][channel]["dedicatedNotchReviewClippedEvidenceCount"]
            for row in results for channel in ("BF", "DF")
        ),
        "dedicatedNotchReviewResamplingPerformed": any(
            row["channels"][channel]["dedicatedNotchReviewResamplingPerformed"]
            for row in results for channel in ("BF", "DF")
        ),
        "dedicatedNotchReviewStatusBarsRendered": any(
            row["channels"][channel]["dedicatedNotchReviewStatusBarsRendered"]
            for row in results for channel in ("BF", "DF")
        ),
        "allCyanGeometryVerified": all_cyan_geometry_verified,
        "cyanGeometryHoldCount": sum(
            not row["channels"][channel]["cyanGeometryVerified"]
            for row in results for channel in ("BF", "DF")
        ),
        "cleanRasterHashMatch": True,
        "overlayMaskContainmentCheckedByRenderer": True,
        "reviewOnly": True,
    }
    diagnostic.atomic_json(output / "LOCAL_DETECTOR_GATE.json", gate)
    print(json.dumps({"state": gate["state"], "summaryPath": str(output / "SUMMARY.json"),
                      "summarySha256": diagnostic.sha256(output / "SUMMARY.json"),
                      "gatePath": str(output / "LOCAL_DETECTOR_GATE.json"),
                      "gateSha256": diagnostic.sha256(output / "LOCAL_DETECTOR_GATE.json")},
                     separators=(",", ":")))
    return 0


def main() -> int:
    """Run the bounded live-source route or the hash-pinned local-strip route."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--safe-id", action="append")
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--local-predecessor-summary")
    parser.add_argument("--local-predecessor-summary-sha256")
    parser.add_argument("--local-job")
    parser.add_argument("--local-job-sha256")
    args = parser.parse_args()
    local_values = (
        args.local_predecessor_summary,
        args.local_predecessor_summary_sha256,
        args.local_job,
        args.local_job_sha256,
    )
    if any(value is not None for value in local_values):
        diagnostic.need(all(value is not None for value in local_values) and not args.safe_id,
                        "Local mode requires all four hash-pinned inputs and no safe IDs")
        return run_local_strip_review(
            Path(args.local_predecessor_summary),
            str(args.local_predecessor_summary_sha256),
            Path(args.local_job),
            str(args.local_job_sha256),
            Path(args.output_root),
        )
    diagnostic.need(
        args.safe_id is not None
        and 1 <= len(args.safe_id) <= 12
        and len(set(args.safe_id)) == len(args.safe_id),
        "Require 1-12 unique safe IDs",
    )
    output = Path(args.output_root)
    diagnostic.need(
        output.is_absolute() and output.drive.upper() == "D:" and not output.exists(),
        "Output must be a fresh JBOD D: root",
    )
    diagnostic.need(len(str(output)) + 96 < 200, "Output path budget failed")

    context = diagnostic.FRONT.preflight_context()
    by_safe = {
        str(row["safeId"]): (row, plan)
        for row, plan in zip(context["cohorts"]["ordered978"], context["plans"])
    }
    diagnostic.need(
        all(safe_id in by_safe for safe_id in args.safe_id),
        "A requested safe ID is outside the frozen 978",
    )
    params = diagnostic.R11.parameters_from_job(context["canonicalFixed"])
    cfg = context["canonicalFixed"]["topologyConfig"]
    output.mkdir()
    (output / "cases").mkdir()
    results: list[dict[str, Any]] = []
    for ordinal, safe_id in enumerate(args.safe_id, 1):
        row, plan = by_safe[safe_id]
        case_root = output / "cases" / f"C{ordinal:04d}"
        case_root.mkdir()
        alias_evidence = {
            "ordinal": ordinal,
            "identity": str(row["identity"]),
            "aliasDrive": context["o3f14"].ALIAS_DRIVE,
            "slotRoot": str(plan["slotRoot"]),
        }
        try:
            with context["o3f14"].owned_case_alias(plan, alias_evidence):
                images: dict[str, np.ndarray] = {}
                for channel, key in (("BF", "bf"), ("DF", "df")):
                    path = Path(str(plan[key]["aliasPath"]))
                    diagnostic.need(
                        diagnostic.R11.sha256_file(path) == str(plan[key]["sha256"]).upper(),
                        f"{channel} source hash changed",
                    )
                    images[channel] = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
                    diagnostic.need(images[channel] is not None, f"{channel} OpenCV decode failed")
                base = diagnostic.R11.CORE.analyze_pair(
                    safe_id, images["BF"], images["DF"], params
                )
                channel_rows: dict[str, Any] = {}
                physical_by_channel: dict[str, Any] = {}
                measured_by_channel: dict[str, Any] = {}
                for channel in ("BF", "DF"):
                    fit = base[channel.lower()].get("fit")
                    diagnostic.need(isinstance(fit, dict), f"{channel} global fit unavailable")
                    measured = unwrap(
                        images[channel],
                        fit,
                        context["canonicalFixed"]["crop"],
                        params,
                        cfg,
                    )
                    measured_by_channel[channel] = measured
                    physical_by_channel[channel] = measured["physicalBoundary"]
                    channel_rows[channel] = {
                        "fit": fit,
                        "baseState": base[channel.lower()].get("state"),
                        "baseCandidateCount": len(base[channel.lower()].get("candidates", [])),
                        "annularEvidence": measured["evidence"],
                    }
                pair = pair_notch_candidates(
                    physical_by_channel["BF"], physical_by_channel["DF"], params
                )
                for channel in ("BF", "DF"):
                    channel_rows[channel]["cyanGeometryVerified"] = physical_by_channel[
                        channel
                    ]["cyanGeometryVerified"]
                    channel_rows[channel]["cyanGeometryVerificationState"] = physical_by_channel[
                        channel
                    ]["cyanGeometryVerificationState"]
                    channel_rows[channel]["assets"] = render(
                        case_root, safe_id, channel, measured_by_channel[channel]
                    )
            unique_pair = pair["state"].startswith("DIAGNOSTIC_UNIQUE_")
            cyan_verified = all(
                physical_by_channel[channel]["cyanGeometryVerified"]
                for channel in ("BF", "DF")
            )
            results.append(
                {
                    "ordinal": ordinal,
                    "identity": str(row["identity"]),
                    "safeId": safe_id,
                    "state": (
                        "DIAGNOSTIC_ONLY_R18_ANNULAR_COMPLETE_UNSELECTED_UNIQUE_PAIR"
                        if unique_pair and cyan_verified
                        else (
                            "HOLD_R18_CYAN_GEOMETRY_UNVERIFIED_WITH_UNIQUE_NOTCH_PAIR"
                            if unique_pair
                            else pair["state"]
                        )
                    ),
                    "technicalCompletionState": "DIAGNOSTIC_ONLY_R18_ANNULAR_UNWRAP_COMPLETE",
                    "channels": channel_rows,
                    "pairDiagnostic": pair,
                    "alias": alias_evidence,
                }
            )
        except Exception as exc:
            results.append(
                {
                    "ordinal": ordinal,
                    "identity": str(row["identity"]),
                    "safeId": safe_id,
                    "state": "HOLD_R18_ANNULAR_UNWRAP_ERROR",
                    "error": f"{type(exc).__name__}: {str(exc)[:1200]}",
                    "alias": alias_evidence,
                }
            )
    summary = {
        "schema": "argos_ocv03_annular_unwrap_exterior_circle_bevel_trace_diagnostic_r18_v1",
        "state": "COMPLETE_DIAGNOSTIC_ONLY_R18_ANNULAR_UNWRAP",
        "engineSha256": diagnostic.sha256(Path(__file__).resolve()),
        "requestedCount": len(args.safe_id),
        "completedCount": sum(
            row.get("technicalCompletionState")
            == "DIAGNOSTIC_ONLY_R18_ANNULAR_UNWRAP_COMPLETE"
            for row in results
        ),
        "results": results,
        "notchPairComparisonPerformed": True,
        "candidateSelectionPerformed": False,
        "notchSelectionPerformed": False,
        "holdClearancePerformed": False,
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
    diagnostic.atomic_json(output / "SUMMARY.json", summary)
    print(
        json.dumps(
            {
                "state": summary["state"],
                "completedCount": summary["completedCount"],
                "summaryPath": str(output / "SUMMARY.json"),
                "summarySha256": diagnostic.sha256(output / "SUMMARY.json"),
            },
            separators=(",", ":"),
        )
    )
    return 0


diagnostic.unwrap = unwrap
diagnostic.render = render
diagnostic.__file__ = __file__


if __name__ == "__main__":
    raise SystemExit(main())
