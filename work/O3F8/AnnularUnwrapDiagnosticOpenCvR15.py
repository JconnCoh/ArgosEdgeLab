#!/usr/bin/env python3
"""R15 physical-circle bevel zone and independent notch/holder evidence.

The review geometry remains in the original fixed-fit annular coordinate frame.
Pixel enhancement may nominate an outer transition, but a raw-polarity gate must
corroborate it.  Accepted transition points robustly fit one physical circle;
the inner edge-zone boundary is the same circle moved inward by exactly 32 px.
Neither per-column evidence nor notch/holder residuals may bend either circle.
"""

from __future__ import annotations

import argparse
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
SPEC = importlib.util.spec_from_file_location("argos_annular_diagnostic_r13_for_r15", BASE_PATH)
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

SEARCH_MIN_OFFSET_PX = -120.0
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
EDGE_ZONE_INWARD_PX = 32.0
HOLDER_OUTWARD_RESIDUAL_PX = 8.0
AMBIGUOUS_INWARD_RESIDUAL_PX = 8.0
NOTCH_INITIAL_GAUSSIAN_SIGMA_PX = 2.0
NOTCH_PATTERN_OPEN_WIDTH_PX = 13
NOTCH_FINAL_GAUSSIAN_SIGMA_PX = 3.0
NOTCH_SHOULDER_WIDTH_PX = 9
MINIMUM_NOTCH_SHOULDER_SUPPORT = 0.75
ZONE_REVIEW_INWARD_PX = 48.0
ZONE_REVIEW_OUTWARD_PX = 24.0
HOLD_BAR_ROWS = 3


def shadow_lift(gray: np.ndarray) -> np.ndarray:
    """Apply the operator-provided monotonic curve without changing coordinates."""
    diagnostic.need(gray.dtype == np.uint8 and gray.ndim == 2, "R15 shadow lift requires uint8 grayscale")
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
    diagnostic.need(width >= 1 and width % 2 == 1, "R15 support width must be positive and odd")
    half = width // 2
    wrapped = np.concatenate((values[:, -half:], values, values[:, :half]), axis=1)
    return cv2.blur(wrapped.astype(np.float32), (width, 1))[:, half:-half]


def cyclic_gaussian_1d(values: np.ndarray, sigma: float) -> np.ndarray:
    radius = int(math.ceil(4.0 * sigma))
    x = np.arange(-radius, radius + 1, dtype=np.float64)
    kernel = np.exp(-0.5 * np.square(x / sigma))
    kernel /= np.sum(kernel)
    padded = np.pad(values.astype(np.float64), (radius, radius), mode="wrap")
    return np.convolve(padded, kernel, mode="valid")


def cyclic_open_1d(values: np.ndarray, width: int) -> np.ndarray:
    diagnostic.need(width >= 1 and width % 2 == 1, "R15 morphology width must be positive and odd")
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
        "R15 original center must remain strictly inside the fitted circle",
    )
    discriminant = np.square(projection) - (qx * qx + qy * qy - radius * radius)
    diagnostic.need(bool(np.all(discriminant >= -1.0e-6)), "R15 circle does not intersect every original radial ray")
    radial_distance = -projection + np.sqrt(np.maximum(discriminant, 0.0))
    diagnostic.need(
        bool(np.all(np.isfinite(radial_distance))) and bool(np.all(radial_distance > 0.0)),
        "R15 circle produced a non-finite or non-positive radial intersection",
    )
    return (radial_distance - float(base_fit["radius"])).astype(np.float32)


def angular_coverage(columns: np.ndarray, accepted: np.ndarray, width: int) -> float:
    accepted_columns = columns[accepted]
    if accepted_columns.size == 0:
        return 0.0
    bins = np.floor(accepted_columns.astype(np.float64) * CIRCLE_COVERAGE_BINS / width).astype(np.int32)
    return float(np.unique(np.clip(bins, 0, CIRCLE_COVERAGE_BINS - 1)).size / CIRCLE_COVERAGE_BINS)


def transition_map(strip: np.ndarray, offsets: np.ndarray) -> dict[str, Any]:
    diagnostic.need(strip.dtype == np.uint8 and strip.ndim == 2, "R15 strip must be uint8 grayscale")
    diagnostic.need(offsets.ndim == 1 and offsets.size == strip.shape[0], "R15 strip/offset mismatch")
    diagnostic.need(bool(np.allclose(np.diff(offsets), 1.0)), "R15 requires native one-pixel radial pitch")
    raw = cyclic_gaussian_image(strip)
    enhanced = cyclic_gaussian_image(shadow_lift(strip))
    search_indices = np.flatnonzero((offsets >= SEARCH_MIN_OFFSET_PX) & (offsets <= SEARCH_MAX_OFFSET_PX))
    diagnostic.need(search_indices.size > 0, "R15 transition search is empty")
    diagnostic.need(
        int(search_indices[0]) >= RADIAL_INSIDE_SAMPLES - 1
        and int(search_indices[-1]) + RADIAL_OUTSIDE_SAMPLES < strip.shape[0],
        "R15 transition search lacks its radial halo",
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
    diagnostic.need(ridge_rows.size > 0, "R15 found no globally sustained outside-in transition ridge")
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
        diagnostic.need(columns.size >= 32, "R15 has fewer than 32 circle observations")
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
    diagnostic.need(columns.size >= 32, "R15 final circle lane has fewer than 32 observations")
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
    diagnostic.need(population.size > 0, "R15 notch residual population is empty")
    ceiling = float(np.percentile(population, 80.0))
    baseline = population[population <= ceiling]
    center = float(np.median(baseline))
    noise = float(1.4826 * np.median(np.abs(baseline - center)))
    threshold = max(float(cfg["minimumNotchDepthPx"]), center + float(cfg["noiseSigmaThreshold"]) * noise)
    active = valid & (filtered >= threshold)
    active = CORE.close_small_circular_gaps(active, int(cfg["candidateJoinWidthPx"]))
    degrees_per_sample = 360.0 / frontier.size
    minimum_samples = max(
        int(cfg["minimumNotchWidthPx"]),
        int(math.ceil(float(params.candidate_minimum_width_degrees) / degrees_per_sample)),
    )
    candidate_columns = np.zeros(frontier.size, dtype=bool)
    candidates: list[dict[str, Any]] = []
    for indices in CORE.group_circular_true(active):
        if int(indices.size) < minimum_samples:
            continue
        depths = filtered[indices]
        symmetry, tip_offset, slope_consistency = CORE.candidate_shape(depths)
        width = float(indices.size * degrees_per_sample)
        left_shoulder = (int(indices[0]) - np.arange(1, NOTCH_SHOULDER_WIDTH_PX + 1)) % frontier.size
        right_shoulder = (int(indices[-1]) + np.arange(1, NOTCH_SHOULDER_WIDTH_PX + 1)) % frontier.size
        left_support = float(np.mean(valid[left_shoulder]))
        right_support = float(np.mean(valid[right_shoulder]))
        left_below_mouth = bool(np.median(filtered[left_shoulder]) < threshold)
        right_below_mouth = bool(np.median(filtered[right_shoulder]) < threshold)
        shoulders_supported = (
            left_support >= MINIMUM_NOTCH_SHOULDER_SUPPORT
            and right_support >= MINIMUM_NOTCH_SHOULDER_SUPPORT
            and left_below_mouth
            and right_below_mouth
        )
        missing_runs = diagnostic.runs(~valid[indices])
        maximum_missing_run = max((int(run.size) for run in missing_runs), default=0)
        weights = np.maximum(depths, 0.001)
        center_degrees = CORE.circular_mean_degrees(
            [float(index) * degrees_per_sample for index in indices],
            [float(value) for value in weights],
        )
        candidate_columns[indices] = True
        candidates.append(
            {
                "centerAngleDegrees": float(center_degrees),
                "startAngleDegrees": float(indices[0] * degrees_per_sample),
                "endAngleDegrees": float(indices[-1] * degrees_per_sample),
                "widthDegrees": width,
                "maximumDepthPx": float(np.max(depths)),
                "maximumRawDepthPx": float(np.max(raw_depth[indices])),
                "medianDepthPx": float(np.median(depths)),
                "sampleCount": int(indices.size),
                "observedSampleCount": int(np.count_nonzero(valid[indices])),
                "maximumContiguousMissingSamples": maximum_missing_run,
                "leftMouthShoulderSupportFraction": left_support,
                "rightMouthShoulderSupportFraction": right_support,
                "mouthShouldersSupported": bool(shoulders_supported),
                "symmetryScore": float(symmetry),
                "tipCenterOffsetFraction": float(tip_offset),
                "slopeConsistencyFraction": float(slope_consistency),
                "manufacturedChannelMorphologyEligible": bool(
                    float(params.manufactured_minimum_width_degrees) <= width <= float(params.manufactured_maximum_width_degrees)
                    and symmetry >= float(params.manufactured_minimum_symmetry)
                    and tip_offset <= float(params.manufactured_maximum_tip_offset_fraction)
                    and slope_consistency >= float(params.manufactured_minimum_slope_consistency)
                    and shoulders_supported
                ),
            }
        )
    candidates.sort(key=lambda row: row["centerAngleDegrees"])
    return {
        "rawDepth": raw_depth.astype(np.float32),
        "filteredDepth": filtered.astype(np.float32),
        "candidateColumns": candidate_columns,
        "candidates": candidates,
        "thresholdPx": float(threshold),
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
    transition = transition_map(strip, offsets)
    circle = fit_physical_circle(
        transition["outerSupported"],
        transition["searchOffsets"],
        base_fit,
        params,
        transition["ridgeOffsetPx"],
    )
    inner_circle = {
        "centerX": circle["fit"]["centerX"],
        "centerY": circle["fit"]["centerY"],
        "radius": circle["fit"]["radius"] - EDGE_ZONE_INWARD_PX,
        "angleSampleCount": strip.shape[1],
    }
    diagnostic.need(inner_circle["radius"] > 0.0, "R15 inner edge-zone circle has non-positive radius")
    inner_path = circle_ray_offsets(base_fit, inner_circle)
    frontier, frontier_observed = outermost_frontier(
        transition["frontierSupported"], transition["searchOffsets"]
    )
    outward = np.zeros(strip.shape[1], dtype=np.float32)
    outward[frontier_observed] = frontier[frontier_observed] - circle["outerPath"][frontier_observed]
    holder = frontier_observed & (outward > HOLDER_OUTWARD_RESIDUAL_PX)
    notch = extract_notch_candidates(
        frontier,
        frontier_observed,
        holder,
        circle["outerPath"],
        params,
        cfg,
    )
    inward = np.zeros(strip.shape[1], dtype=np.float32)
    valid = frontier_observed & ~holder
    inward[valid] = circle["outerPath"][valid] - frontier[valid]
    ambiguous = valid & ~notch["candidateColumns"] & (inward >= AMBIGUOUS_INWARD_RESIDUAL_PX)
    diagnostic.need(predecessor_measured is not None, "R15 requires the exact predecessor measurement mask")
    prior_measured = predecessor_measured.astype(bool).copy()
    diagnostic.need(prior_measured.shape == (strip.shape[1],), "R15 predecessor hold width mismatch")
    return {
        "method": "OUTSIDE_IN_FIRST_SUSTAINED_FRONTIER_ROBUST_PHYSICAL_CIRCLE_R15",
        "strip": strip,
        "offsets": offsets.astype(np.float32),
        "baseFit": {key: float(base_fit[key]) for key in ("centerX", "centerY", "radius")},
        "ridgeOffsetPx": transition["ridgeOffsetPx"],
        "ridgeCoverageFraction": float(transition["rowCoverage"][transition["ridgeRow"]]),
        "maximumRowCoverageFraction": float(np.max(transition["rowCoverage"])),
        "circleState": circle["state"],
        "circleQualified": circle["qualified"],
        "circleFit": circle["fit"],
        "outerPath": circle["outerPath"],
        "innerPath": inner_path,
        "selectedOffsets": circle["selectedOffsets"],
        "selectedObserved": circle["observed"],
        "robustFitAcceptedColumns": circle["robustFitAcceptedColumns"],
        "finalSupportColumns": circle["finalSupportColumns"],
        "frontier": frontier,
        "frontierObserved": frontier_observed,
        "holderColumns": holder,
        "ambiguousColumns": ambiguous,
        "predecessorHeldColumns": ~prior_measured,
        "notch": notch,
        "evidence": {
            "enhancement": "OPERATOR_EXACT_MONOTONIC_SHADOW_LIFT_LUT_0_TO_61_THEN_SATURATE",
            "enhancementChangesCoordinates": False,
            "rawPolarityCorroborationRequired": True,
            "minimumRawPolarity": MINIMUM_RAW_POLARITY,
            "minimumEnhancedContrast": MINIMUM_ENHANCED_CONTRAST,
            "relativeEnhancedContrast": RELATIVE_ENHANCED_CONTRAST,
            "searchMinimumOffsetPx": SEARCH_MIN_OFFSET_PX,
            "searchMaximumOffsetPx": SEARCH_MAX_OFFSET_PX,
            "tangentialSupportWidthPx": TANGENTIAL_SUPPORT_WIDTH_PX,
            "minimumTangentialSupportFraction": MINIMUM_TANGENTIAL_SUPPORT,
            "minimumGlobalRidgeCoverageFraction": MINIMUM_GLOBAL_RIDGE_COVERAGE,
            "circleTrackHalfWidthPx": CIRCLE_TRACK_HALF_WIDTH_PX,
            "circleRefinementPasses": CIRCLE_REFINEMENT_PASSES,
            "circleFitPassCount": circle["fit"]["fitPassCount"],
            "maximumSelectedToFinalCircleDifferencePx": circle["fit"][
                "maximumSelectedToFinalCircleDifferencePx"
            ],
            "circleModel": "K0_K1_TRUE_CIRCLE_ONLY_NO_HIGHER_HARMONICS",
            "outerCircleFit": circle["fit"],
            "outerCircleQualified": circle["qualified"],
            "minimumCircleCoverageFraction": MINIMUM_CIRCLE_COVERAGE,
            "minimumCircleInlierFraction": MINIMUM_CIRCLE_INLIER_FRACTION,
            "maximumCircleRmsResidualPx": MAXIMUM_CIRCLE_RMS_RESIDUAL_PX,
            "maximumCircleP90AbsoluteResidualPx": MAXIMUM_CIRCLE_P90_RESIDUAL_PX,
            "edgeZoneInwardPx": EDGE_ZONE_INWARD_PX,
            "innerCircleSharesOuterCenter": True,
            "perColumnPathAllowedToDefineReviewGeometry": False,
            "pathCenteredResamplingPerformed": False,
            "fixedFitUnshiftedReviewGeometry": True,
            "notchCandidateDetectionPerformed": True,
            "innerEdgeZonePixelEnhancementPerformed": False,
            "notchFrontierEnhancement": "OUTER_SILHOUETTE_SHADOW_LIFT_WITH_RAW_POLARITY_CORROBORATION",
            "transitionCoordinateConvention": "LAST_INSIDE_SAMPLE_CENTER_AT_OFFSETS_ROW",
            "notchSelectionPerformed": False,
            "notchCandidateCount": len(notch["candidates"]),
            "notchCandidateDepthThresholdPx": notch["thresholdPx"],
            "notchBaselineNoiseSigmaPx": notch["baselineNoiseSigmaPx"],
            "notchCandidates": notch["candidates"],
            "holderClassificationPerformed": True,
            "holderOutwardResidualThresholdPx": HOLDER_OUTWARD_RESIDUAL_PX,
            "holderColumnCount": int(np.count_nonzero(holder)),
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
                and bool(bf_candidate["mouthShouldersSupported"])
                and bool(df_candidate["mouthShouldersSupported"])
                and bool(bf_candidate["manufacturedChannelMorphologyEligible"])
                and bool(df_candidate["manufacturedChannelMorphologyEligible"])
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
    paired_bf = {row["bfCandidateIndex"] for row in eligible}
    paired_df = {row["dfCandidateIndex"] for row in eligible}
    unmatched_bf = [
        {"candidateIndex": index, **row}
        for index, row in enumerate(bf_candidates)
        if row["manufacturedChannelMorphologyEligible"] and index not in paired_bf
    ]
    unmatched_df = [
        {"candidateIndex": index, **row}
        for index, row in enumerate(df_candidates)
        if row["manufacturedChannelMorphologyEligible"] and index not in paired_df
    ]
    if len(eligible) == 1 and not graph_ambiguous and not unmatched_bf and not unmatched_df:
        state = "DIAGNOSTIC_UNIQUE_MANUFACTURED_NOTCH_PAIR_NO_UNMATCHED_RESPONSES"
    elif not eligible:
        state = "HOLD_DIAGNOSTIC_NO_MANUFACTURED_NOTCH_PAIR"
    elif graph_ambiguous or len(eligible) > 1:
        state = "HOLD_DIAGNOSTIC_AMBIGUOUS_MANUFACTURED_NOTCH_GRAPH"
    else:
        state = "HOLD_DIAGNOSTIC_UNMATCHED_MANUFACTURED_CHANNEL_RESPONSE"
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
            "method": "NATIVE_PITCH_FIXED_FIT_PHYSICAL_CIRCLE_EDGE_ZONE_DIAGNOSTIC_R15",
            "physicalBoundary": physical["evidence"],
            "predecessorPathRetainedAsDiagnosticData": True,
            "predecessorPathReviewEligibility": "WITHDRAWN_NOT_GEOMETRY_EVIDENCE",
            "normalizedStripReviewEligibility": "WITHDRAWN_WARNING_CARD_NO_PATH_CENTERED_PIXELS",
            "geometryReviewAssetRole": "physical_circle_full_review",
            "notchSelectionPerformed": False,
            "holderClassificationPerformed": True,
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
        "R15 review uses only the unshifted fixed-fit annular strip.",
        "CYAN/YELLOW are exact concentric physical circles; no path warp.",
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


def render(root: Path, pair_id: str, channel: str, measured: dict[str, Any]) -> dict[str, Any]:
    physical = measured["physicalBoundary"]
    raw = measured["strip"]
    offsets = measured["offsets"]
    enhanced = shadow_lift(raw)
    overlay = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    outer_mask = np.zeros(raw.shape, dtype=np.uint8)
    inner_mask = np.zeros(raw.shape, dtype=np.uint8)
    observed_mask = np.zeros(raw.shape, dtype=np.uint8)
    notch_mask = np.zeros(raw.shape, dtype=np.uint8)
    predecessor_hold_mask = np.zeros(raw.shape, dtype=np.uint8)
    holder_mask = np.zeros(raw.shape, dtype=np.uint8)
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
        notch_mask,
        physical["frontier"],
        physical["notch"]["candidateColumns"],
        offsets,
        (0, 128, 255),
    )
    predecessor_held = physical["predecessorHeldColumns"]
    if np.any(predecessor_held):
        overlay[:HOLD_BAR_ROWS, predecessor_held] = (255, 0, 255)
        predecessor_hold_mask[:HOLD_BAR_ROWS, predecessor_held] = 255
    holder = physical["holderColumns"]
    if np.any(holder):
        overlay[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, holder] = (255, 0, 128)
        holder_mask[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, holder] = 255
    missing = ~physical["frontierObserved"]
    if np.any(missing):
        overlay[2 * HOLD_BAR_ROWS : 3 * HOLD_BAR_ROWS, missing] = (255, 0, 0)
        missing_mask[2 * HOLD_BAR_ROWS : 3 * HOLD_BAR_ROWS, missing] = 255
    if np.any(physical["ambiguousColumns"]):
        overlay[3 * HOLD_BAR_ROWS : 4 * HOLD_BAR_ROWS, physical["ambiguousColumns"]] = (0, 128, 255)
        ambiguous_mask[3 * HOLD_BAR_ROWS : 4 * HOLD_BAR_ROWS, physical["ambiguousColumns"]] = 255
    union_mask = cv2.bitwise_or(outer_mask, inner_mask)
    for layer in (
        observed_mask,
        notch_mask,
        predecessor_hold_mask,
        holder_mask,
        missing_mask,
        ambiguous_mask,
    ):
        union_mask = cv2.bitwise_or(union_mask, layer)
    changed = np.any(overlay != cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR), axis=2)
    diagnostic.need(bool(np.all(~changed | (union_mask > 0))), "R15 overlay changed pixels outside declared masks")

    zone_rows = (offsets >= -ZONE_REVIEW_INWARD_PX) & (offsets <= ZONE_REVIEW_OUTWARD_PX)
    diagnostic.need(bool(np.any(zone_rows)), "R15 edge-zone review crop is empty")
    zone_raw = raw[zone_rows]
    zone_enhanced = enhanced[zone_rows]
    zone_overlay = overlay[zone_rows].copy()
    zone_union = union_mask[zone_rows].copy()
    zone_predecessor_hold = np.zeros(zone_raw.shape, dtype=np.uint8)
    zone_holder = np.zeros(zone_raw.shape, dtype=np.uint8)
    zone_missing = np.zeros(zone_raw.shape, dtype=np.uint8)
    zone_ambiguous = np.zeros(zone_raw.shape, dtype=np.uint8)
    if np.any(predecessor_held):
        zone_overlay[:HOLD_BAR_ROWS, predecessor_held] = (255, 0, 255)
        zone_predecessor_hold[:HOLD_BAR_ROWS, predecessor_held] = 255
    if np.any(holder):
        zone_overlay[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, holder] = (255, 0, 128)
        zone_holder[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, holder] = 255
    if np.any(missing):
        zone_overlay[2 * HOLD_BAR_ROWS : 3 * HOLD_BAR_ROWS, missing] = (255, 0, 0)
        zone_missing[2 * HOLD_BAR_ROWS : 3 * HOLD_BAR_ROWS, missing] = 255
    if np.any(physical["ambiguousColumns"]):
        zone_overlay[3 * HOLD_BAR_ROWS : 4 * HOLD_BAR_ROWS, physical["ambiguousColumns"]] = (0, 128, 255)
        zone_ambiguous[3 * HOLD_BAR_ROWS : 4 * HOLD_BAR_ROWS, physical["ambiguousColumns"]] = 255
    for layer in (zone_predecessor_hold, zone_holder, zone_missing, zone_ambiguous):
        zone_union = cv2.bitwise_or(zone_union, layer)
    zone_hold = cv2.bitwise_or(
        zone_predecessor_hold,
        cv2.bitwise_or(zone_holder, zone_missing),
    )
    legend = "UNSHIFTED FIXED-FIT | CYAN outer | YELLOW inner | RED accepted | ORANGE notch/ambiguity | bars: MAGENTA prior, PINK holder, BLUE missing"
    edge_review = diagnostic.segmented_review(zone_overlay, legend)
    full_review = diagnostic.segmented_review(
        enhanced,
        "CLEAN OPERATOR SHADOW-LIFT FULL 180-IN/55-OUT | PIXELWISE ONLY; NO GEOMETRIC WARP",
    )
    physical_review = diagnostic.segmented_review(overlay, legend)

    top = 28
    labeled_overlay = cv2.copyMakeBorder(zone_overlay, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    labeled_mask = cv2.copyMakeBorder(zone_union, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    labeled_hold = cv2.copyMakeBorder(zone_hold, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    header_mask = np.zeros(labeled_overlay.shape[:2], dtype=np.uint8)
    header_mask[:top] = 255
    cv2.putText(labeled_overlay, legend, (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.38, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(labeled_mask, "UNION OF DECLARED R15 ANNOTATION MASKS", (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.43, 255, 1, cv2.LINE_8)
    cv2.putText(labeled_hold, "MAGENTA PREDECESSOR/MISSING/HOLDER TOP-BAR MASK", (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.43, 255, 1, cv2.LINE_8)

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
        ("full_overlay", overlay),
        ("full_review", full_review),
        ("damage_review", physical_review),
        ("physical_circle_full_review", physical_review),
        ("outer_circle_mask", outer_mask),
        ("inner_circle_mask", inner_mask),
        ("accepted_outer_pixel_mask", observed_mask),
        ("notch_candidate_mask", notch_mask),
        ("predecessor_hold_mask", predecessor_hold_mask),
        ("holder_obstruction_mask", holder_mask),
        ("missing_frontier_mask", missing_mask),
        ("ambiguous_inward_mask", ambiguous_mask),
        ("annotation_union_mask", union_mask),
        ("review_header_mask", header_mask),
    )
    for role, image in roles:
        path = root / f"{stem}_{channel.lower()}_annular_{role}.png"
        diagnostic.need(not path.exists(), f"R15 refuses asset overwrite: {path}")
        diagnostic.need(cv2.imwrite(str(path), image), f"OpenCV write failed: {path}")
        assets[role] = {
            "path": str(path),
            "bytes": path.stat().st_size,
            "sha256": diagnostic.sha256(path),
        }
    assets["normalized_review"]["reviewEligibility"] = "WITHDRAWN_WARNING_CARD_NO_PATH_CENTERED_PIXELS"
    assets["physical_circle_full_review"]["reviewEligibility"] = "GEOMETRY_EDGE_ZONE_NOTCH_AND_HOLDER_REVIEW"
    return assets


def main() -> int:
    """Run the inherited bounded source route and emit R15 pair diagnostics."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--safe-id", action="append", required=True)
    parser.add_argument("--output-root", required=True)
    args = parser.parse_args()
    diagnostic.need(
        1 <= len(args.safe_id) <= 12 and len(set(args.safe_id)) == len(args.safe_id),
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
                    physical_by_channel[channel] = measured["physicalBoundary"]
                    channel_rows[channel] = {
                        "fit": fit,
                        "baseState": base[channel.lower()].get("state"),
                        "baseCandidateCount": len(base[channel.lower()].get("candidates", [])),
                        "annularEvidence": measured["evidence"],
                        "assets": render(case_root, safe_id, channel, measured),
                    }
                pair = pair_notch_candidates(
                    physical_by_channel["BF"], physical_by_channel["DF"], params
                )
            unique_pair = pair["state"].startswith("DIAGNOSTIC_UNIQUE_")
            results.append(
                {
                    "ordinal": ordinal,
                    "identity": str(row["identity"]),
                    "safeId": safe_id,
                    "state": (
                        "DIAGNOSTIC_ONLY_R15_ANNULAR_COMPLETE_UNSELECTED_UNIQUE_PAIR"
                        if unique_pair
                        else pair["state"]
                    ),
                    "technicalCompletionState": "DIAGNOSTIC_ONLY_R15_ANNULAR_UNWRAP_COMPLETE",
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
                    "state": "HOLD_R15_ANNULAR_UNWRAP_ERROR",
                    "error": f"{type(exc).__name__}: {str(exc)[:1200]}",
                    "alias": alias_evidence,
                }
            )
    summary = {
        "schema": "argos_ocv03_annular_unwrap_physical_circle_diagnostic_r15_v1",
        "state": "COMPLETE_DIAGNOSTIC_ONLY_R15_ANNULAR_UNWRAP",
        "engineSha256": diagnostic.sha256(Path(__file__).resolve()),
        "requestedCount": len(args.safe_id),
        "completedCount": sum(
            row.get("technicalCompletionState")
            == "DIAGNOSTIC_ONLY_R15_ANNULAR_UNWRAP_COMPLETE"
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
