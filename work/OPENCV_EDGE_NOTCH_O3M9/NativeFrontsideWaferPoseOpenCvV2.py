#!/usr/bin/env python3
"""Review-only full-perimeter OpenCV wafer edge and notch detector.

The detector receives no expected notch angle, known location, score label,
fixed angular window, or candidate tie-breaker. BF and DF are localized and
qualified independently. Historical results belong only in a separate scorer.
"""

from __future__ import annotations

import argparse
import gc
import hashlib
import json
import math
import os
import platform
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import cv2
import numpy as np


SCHEMA = "argos_native_frontside_wafer_pose_opencv_v2"
SUMMARY_SCHEMA = "argos_native_frontside_wafer_pose_opencv_v2_summary"
PASS_PREFLIGHT = "PASS_NATIVE_FRONTSIDE_WAFER_POSE_OPENCV_V2_PREFLIGHT"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def atomic_write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(
        prefix=path.name + ".partial.", suffix=".json", dir=str(path.parent)
    )
    try:
        with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(value, stream, indent=2, default=json_scalar)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def json_scalar(value: Any) -> Any:
    if isinstance(value, np.generic):
        return value.item()
    if isinstance(value, np.ndarray):
        return value.tolist()
    return value


def circular_distance_degrees(a: float, b: float) -> float:
    delta = abs(a - b) % 360.0
    return min(delta, 360.0 - delta)


def circular_mean_degrees(values: list[float], weights: list[float]) -> float:
    radians = np.radians(np.asarray(values, dtype=np.float64))
    weight_array = np.asarray(weights, dtype=np.float64)
    x = float(np.sum(np.cos(radians) * weight_array))
    y = float(np.sum(np.sin(radians) * weight_array))
    return math.degrees(math.atan2(y, x)) % 360.0


@dataclass(frozen=True)
class Parameters:
    coarse_radius_minimum_fraction: float
    coarse_radius_maximum_fraction: float
    coarse_radial_step_px: int
    coarse_angle_samples: int
    refine_radial_half_width_px: int
    refine_angle_samples: int
    radial_contrast_span_px: int
    radial_smoothing_width_px: int
    minimum_boundary_contrast: float
    outer_edge_relative_contrast: float
    fit_mad_multiplier: float
    fit_residual_floor_px: float
    minimum_fit_inlier_fraction: float
    minimum_angular_coverage_fraction: float
    maximum_fit_rms_residual_px: float
    minimum_candidate_depth_px: float
    candidate_noise_multiplier: float
    candidate_gap_allowance_degrees: float
    candidate_minimum_width_degrees: float
    candidate_match_tolerance_degrees: float
    manufactured_minimum_width_degrees: float
    manufactured_maximum_width_degrees: float
    manufactured_minimum_symmetry: float
    manufactured_maximum_tip_offset_fraction: float
    manufactured_minimum_slope_consistency: float
    manufactured_minimum_cross_channel_overlap: float
    maximum_channel_center_difference_px: float
    maximum_channel_radius_difference_px: float

    @staticmethod
    def from_json(value: dict[str, Any]) -> "Parameters":
        result = Parameters(
            coarse_radius_minimum_fraction=float(value["coarseRadiusMinimumFraction"]),
            coarse_radius_maximum_fraction=float(value["coarseRadiusMaximumFraction"]),
            coarse_radial_step_px=int(value["coarseRadialStepPx"]),
            coarse_angle_samples=int(value["coarseAngleSamples"]),
            refine_radial_half_width_px=int(value["refineRadialHalfWidthPx"]),
            refine_angle_samples=int(value["refineAngleSamples"]),
            radial_contrast_span_px=int(value["radialContrastSpanPx"]),
            radial_smoothing_width_px=int(value["radialSmoothingWidthPx"]),
            minimum_boundary_contrast=float(value["minimumBoundaryContrast"]),
            outer_edge_relative_contrast=float(value["outerEdgeRelativeContrast"]),
            fit_mad_multiplier=float(value["fitMadMultiplier"]),
            fit_residual_floor_px=float(value["fitResidualFloorPx"]),
            minimum_fit_inlier_fraction=float(value["minimumFitInlierFraction"]),
            minimum_angular_coverage_fraction=float(value["minimumAngularCoverageFraction"]),
            maximum_fit_rms_residual_px=float(value["maximumFitRmsResidualPx"]),
            minimum_candidate_depth_px=float(value["minimumCandidateDepthPx"]),
            candidate_noise_multiplier=float(value["candidateNoiseMultiplier"]),
            candidate_gap_allowance_degrees=float(value["candidateGapAllowanceDegrees"]),
            candidate_minimum_width_degrees=float(value["candidateMinimumWidthDegrees"]),
            candidate_match_tolerance_degrees=float(value["candidateMatchToleranceDegrees"]),
            manufactured_minimum_width_degrees=float(value["manufacturedMinimumWidthDegrees"]),
            manufactured_maximum_width_degrees=float(value["manufacturedMaximumWidthDegrees"]),
            manufactured_minimum_symmetry=float(value["manufacturedMinimumSymmetry"]),
            manufactured_maximum_tip_offset_fraction=float(value["manufacturedMaximumTipOffsetFraction"]),
            manufactured_minimum_slope_consistency=float(value["manufacturedMinimumSlopeConsistency"]),
            manufactured_minimum_cross_channel_overlap=float(value["manufacturedMinimumCrossChannelOverlap"]),
            maximum_channel_center_difference_px=float(value["maximumChannelCenterDifferencePx"]),
            maximum_channel_radius_difference_px=float(value["maximumChannelRadiusDifferencePx"]),
        )
        if not 0.20 <= result.coarse_radius_minimum_fraction < result.coarse_radius_maximum_fraction <= 0.50:
            raise ValueError("Coarse radius fractions must satisfy 0.20 <= min < max <= 0.50.")
        if not 1 <= result.coarse_radial_step_px <= 8:
            raise ValueError("coarseRadialStepPx must be in [1, 8].")
        if not 360 <= result.coarse_angle_samples <= 4096:
            raise ValueError("coarseAngleSamples must be in [360, 4096].")
        if not 720 <= result.refine_angle_samples <= 16384:
            raise ValueError("refineAngleSamples must be in [720, 16384].")
        if result.radial_smoothing_width_px < 1 or result.radial_smoothing_width_px % 2 == 0:
            raise ValueError("radialSmoothingWidthPx must be a positive odd integer.")
        if not 0.0 < result.outer_edge_relative_contrast <= 1.0:
            raise ValueError("outerEdgeRelativeContrast must be in (0, 1].")
        return result


def fit_circle(points: np.ndarray) -> tuple[float, float, float]:
    if points.shape[0] < 3:
        raise ValueError("At least three points are required for a circle fit.")
    x = points[:, 0].astype(np.float64)
    y = points[:, 1].astype(np.float64)
    matrix = np.column_stack((2.0 * x, 2.0 * y, np.ones_like(x)))
    target = x * x + y * y
    solution, _, rank, _ = np.linalg.lstsq(matrix, target, rcond=None)
    if rank < 3:
        raise ValueError("Circle fit is rank deficient.")
    cx, cy, constant = solution
    radius_squared = constant + cx * cx + cy * cy
    if radius_squared <= 0.0:
        raise ValueError("Circle fit produced a non-positive radius.")
    return float(cx), float(cy), float(math.sqrt(radius_squared))


def robust_circle(points: np.ndarray, parameters: Parameters) -> dict[str, Any]:
    retained = np.ones(points.shape[0], dtype=bool)
    for _ in range(12):
        cx, cy, radius = fit_circle(points[retained])
        residuals = np.hypot(points[:, 0] - cx, points[:, 1] - cy) - radius
        retained_residuals = residuals[retained]
        median = float(np.median(retained_residuals))
        mad = float(np.median(np.abs(retained_residuals - median)))
        threshold = max(
            parameters.fit_residual_floor_px,
            parameters.fit_mad_multiplier * 1.4826 * mad,
        )
        updated = np.abs(residuals - median) <= threshold
        if int(updated.sum()) < 32:
            break
        if np.array_equal(updated, retained):
            retained = updated
            break
        retained = updated
    cx, cy, radius = fit_circle(points[retained])
    residuals = np.hypot(points[:, 0] - cx, points[:, 1] - cy) - radius
    accepted = residuals[retained]
    return {
        "centerX": cx,
        "centerY": cy,
        "radius": radius,
        "acceptedMask": retained,
        "acceptedCount": int(retained.sum()),
        "inputCount": int(points.shape[0]),
        "inlierFraction": float(retained.mean()),
        "rmsResidualPx": float(math.sqrt(np.mean(accepted * accepted))),
        "p90AbsoluteResidualPx": float(np.percentile(np.abs(accepted), 90.0)),
    }


def sample_radial_profiles(
    image: np.ndarray,
    center_x: float,
    center_y: float,
    radii: np.ndarray,
    angle_samples: int,
) -> tuple[np.ndarray, np.ndarray]:
    angles = np.linspace(0.0, 2.0 * math.pi, angle_samples, endpoint=False, dtype=np.float32)
    map_x = center_x + np.cos(angles)[:, None] * radii[None, :]
    map_y = center_y + np.sin(angles)[:, None] * radii[None, :]
    profiles = cv2.remap(
        image,
        map_x.astype(np.float32),
        map_y.astype(np.float32),
        interpolation=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0,
    ).astype(np.float32)
    return angles, profiles


def choose_outer_dark_boundary(
    profiles: np.ndarray,
    radii: np.ndarray,
    radial_step_px: float,
    parameters: Parameters,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, float]:
    smoothing_samples = max(1, int(round(parameters.radial_smoothing_width_px / radial_step_px)))
    if smoothing_samples % 2 == 0:
        smoothing_samples += 1
    smoothed = cv2.blur(profiles, (smoothing_samples, 1))
    span_samples = max(1, int(round(parameters.radial_contrast_span_px / radial_step_px)))
    if span_samples >= smoothed.shape[1]:
        raise ValueError("Radial contrast span consumes the entire search profile.")
    contrast = smoothed[:, :-span_samples] - smoothed[:, span_samples:]
    contrast_radii = (radii[:-span_samples] + radii[span_samples:]) * 0.5
    maxima = np.max(contrast, axis=1)
    row_thresholds = np.maximum(
        parameters.minimum_boundary_contrast,
        maxima * parameters.outer_edge_relative_contrast,
    )
    eligible = contrast >= row_thresholds[:, None]
    any_eligible = np.any(eligible, axis=1)
    reversed_index = np.argmax(eligible[:, ::-1], axis=1)
    selected_indices = eligible.shape[1] - 1 - reversed_index
    selected_scores = contrast[np.arange(contrast.shape[0]), selected_indices]
    supported = any_eligible & (selected_scores >= parameters.minimum_boundary_contrast)
    selected_radii = contrast_radii[selected_indices]
    adaptive_floor = max(
        parameters.minimum_boundary_contrast,
        float(np.percentile(maxima, 20.0)) * parameters.outer_edge_relative_contrast,
    )
    supported &= selected_scores >= adaptive_floor
    return selected_radii, selected_scores, supported, adaptive_floor


def angular_coverage(angles: np.ndarray, retained: np.ndarray) -> float:
    accepted = angles[retained]
    bins = np.unique(np.floor((accepted % (2.0 * math.pi)) / (2.0 * math.pi) * 72.0).astype(int))
    return float(bins.size / 72.0)


def localize_channel(image: np.ndarray, channel: str, parameters: Parameters) -> dict[str, Any]:
    height, width = image.shape
    image_center_x = (width - 1) / 2.0
    image_center_y = (height - 1) / 2.0
    minimum_dimension = float(min(width, height))
    coarse_radii = np.arange(
        minimum_dimension * parameters.coarse_radius_minimum_fraction,
        minimum_dimension * parameters.coarse_radius_maximum_fraction + parameters.coarse_radial_step_px,
        parameters.coarse_radial_step_px,
        dtype=np.float32,
    )
    coarse_angles, coarse_profiles = sample_radial_profiles(
        image,
        image_center_x,
        image_center_y,
        coarse_radii,
        parameters.coarse_angle_samples,
    )
    coarse_boundary, coarse_scores, coarse_supported, coarse_floor = choose_outer_dark_boundary(
        coarse_profiles,
        coarse_radii,
        float(parameters.coarse_radial_step_px),
        parameters,
    )
    if int(coarse_supported.sum()) < 64:
        return {
            "channel": channel,
            "qualified": False,
            "state": "HOLD_FULL_PERIMETER_COARSE_SUPPORT_INSUFFICIENT",
            "widthPx": width,
            "heightPx": height,
            "coarseSupportedSamples": int(coarse_supported.sum()),
            "knownNotchLocationConsumed": False,
        }
    coarse_points = np.column_stack(
        (
            image_center_x + np.cos(coarse_angles[coarse_supported]) * coarse_boundary[coarse_supported],
            image_center_y + np.sin(coarse_angles[coarse_supported]) * coarse_boundary[coarse_supported],
        )
    )
    coarse_fit = robust_circle(coarse_points, parameters)

    center_x = float(coarse_fit["centerX"])
    center_y = float(coarse_fit["centerY"])
    radius = float(coarse_fit["radius"])
    final_angles: np.ndarray | None = None
    final_boundary: np.ndarray | None = None
    final_scores: np.ndarray | None = None
    final_supported: np.ndarray | None = None
    final_floor = math.nan
    final_fit: dict[str, Any] | None = None
    for _ in range(2):
        refine_radii = np.arange(
            radius - parameters.refine_radial_half_width_px,
            radius + parameters.refine_radial_half_width_px + 1,
            1.0,
            dtype=np.float32,
        )
        final_angles, profiles = sample_radial_profiles(
            image,
            center_x,
            center_y,
            refine_radii,
            parameters.refine_angle_samples,
        )
        final_boundary, final_scores, final_supported, final_floor = choose_outer_dark_boundary(
            profiles, refine_radii, 1.0, parameters
        )
        points = np.column_stack(
            (
                center_x + np.cos(final_angles[final_supported]) * final_boundary[final_supported],
                center_y + np.sin(final_angles[final_supported]) * final_boundary[final_supported],
            )
        )
        final_fit = robust_circle(points, parameters)
        center_x = float(final_fit["centerX"])
        center_y = float(final_fit["centerY"])
        radius = float(final_fit["radius"])

    assert final_angles is not None
    assert final_boundary is not None
    assert final_scores is not None
    assert final_supported is not None
    assert final_fit is not None
    coverage = angular_coverage(
        final_angles[final_supported], final_fit["acceptedMask"]
    )
    displacement = radius - final_boundary
    candidates, threshold, noise_sigma = extract_candidates(
        final_angles, displacement, final_supported, parameters
    )
    qualified = (
        float(final_fit["inlierFraction"]) >= parameters.minimum_fit_inlier_fraction
        and coverage >= parameters.minimum_angular_coverage_fraction
        and float(final_fit["rmsResidualPx"]) <= parameters.maximum_fit_rms_residual_px
    )
    return {
        "channel": channel,
        "qualified": qualified,
        "state": "PASS_FULL_PERIMETER_CHANNEL_QUALIFIED" if qualified else "HOLD_FULL_PERIMETER_CHANNEL_NOT_QUALIFIED",
        "widthPx": width,
        "heightPx": height,
        "search": {
            "mode": "FULL_360_OUTERMOST_DARK_EXTERIOR_BOUNDARY",
            "coarseRadiusMinimumPx": float(coarse_radii[0]),
            "coarseRadiusMaximumPx": float(coarse_radii[-1]),
            "coarseAngleSamples": parameters.coarse_angle_samples,
            "refineAngleSamples": parameters.refine_angle_samples,
            "coarseSupportedSamples": int(coarse_supported.sum()),
            "refineSupportedSamples": int(final_supported.sum()),
            "coarseAdaptiveContrastFloor": coarse_floor,
            "refineAdaptiveContrastFloor": final_floor,
            "knownNotchLocationConsumed": False,
            "notchAnglePriorConsumed": False,
            "fixedAngularSearchWindowConsumed": False,
        },
        "coarseFit": {
            key: coarse_fit[key]
            for key in ("centerX", "centerY", "radius", "acceptedCount", "inputCount", "inlierFraction", "rmsResidualPx", "p90AbsoluteResidualPx")
        },
        "fit": {
            "centerX": center_x,
            "centerY": center_y,
            "radius": radius,
            "acceptedCount": final_fit["acceptedCount"],
            "inputCount": final_fit["inputCount"],
            "inlierFraction": final_fit["inlierFraction"],
            "angularCoverageFraction": coverage,
            "rmsResidualPx": final_fit["rmsResidualPx"],
            "p90AbsoluteResidualPx": final_fit["p90AbsoluteResidualPx"],
        },
        "candidateDepthThresholdPx": threshold,
        "baselineNoiseSigmaPx": noise_sigma,
        "candidates": candidates,
    }


def circular_median(values: np.ndarray, window: int) -> np.ndarray:
    half = window // 2
    padded = np.concatenate((values[-half:], values, values[:half]))
    return np.array(
        [np.median(padded[index : index + window]) for index in range(values.size)],
        dtype=np.float64,
    )


def group_circular_true(mask: np.ndarray) -> list[np.ndarray]:
    count = int(mask.size)
    if count == 0 or not mask.any():
        return []
    if mask.all():
        return [np.arange(count, dtype=np.int32)]
    start = int(np.flatnonzero(~mask)[0])
    rotated = np.roll(mask, -start - 1)
    groups: list[np.ndarray] = []
    current: list[int] = []
    for offset, active in enumerate(rotated):
        original = (start + 1 + offset) % count
        if active:
            current.append(original)
        elif current:
            groups.append(np.asarray(current, dtype=np.int32))
            current = []
    if current:
        groups.append(np.asarray(current, dtype=np.int32))
    return groups


def close_small_circular_gaps(mask: np.ndarray, maximum_gap: int) -> np.ndarray:
    result = mask.copy()
    if maximum_gap <= 0 or not result.any():
        return result
    inactive_groups = group_circular_true(~result)
    for indices in inactive_groups:
        if int(indices.size) <= maximum_gap:
            result[indices] = True
    return result


def candidate_shape(depths: np.ndarray) -> tuple[float, float, float]:
    if depths.size < 2:
        return 0.0, 1.0, 0.0
    maximum = float(np.max(depths))
    tip = int(np.argmax(depths))
    center = (depths.size - 1) / 2.0
    tip_offset = abs(tip - center) / max(center, 1.0)
    pair_count = min(tip + 1, depths.size - tip)
    if pair_count >= 2 and maximum > 0.0:
        left = depths[tip - pair_count + 1 : tip + 1]
        right = depths[tip : tip + pair_count][::-1]
        symmetry = max(0.0, 1.0 - float(np.mean(np.abs(left - right))) / maximum)
    else:
        symmetry = 0.0
    rising = np.diff(depths[: tip + 1]) if tip > 0 else np.asarray([], dtype=np.float64)
    falling = np.diff(depths[tip:]) if tip < depths.size - 1 else np.asarray([], dtype=np.float64)
    consistent = int(np.sum(rising >= -0.5)) + int(np.sum(falling <= 0.5))
    slope_count = int(rising.size + falling.size)
    slope_consistency = float(consistent / slope_count) if slope_count else 0.0
    return symmetry, tip_offset, slope_consistency


def extract_candidates(
    angles: np.ndarray,
    displacement: np.ndarray,
    supported: np.ndarray,
    parameters: Parameters,
) -> tuple[list[dict[str, Any]], float, float]:
    smoothed = circular_median(displacement.astype(np.float64), 5)
    supported_values = smoothed[supported]
    baseline_ceiling = float(np.percentile(supported_values, 80.0))
    baseline = supported_values[supported_values <= baseline_ceiling]
    median = float(np.median(baseline))
    mad = float(np.median(np.abs(baseline - median)))
    noise_sigma = 1.4826 * mad
    threshold = max(
        parameters.minimum_candidate_depth_px,
        median + parameters.candidate_noise_multiplier * noise_sigma,
    )
    active = supported & (smoothed >= threshold)
    degrees_per_sample = 360.0 / angles.size
    gap_samples = int(math.floor(parameters.candidate_gap_allowance_degrees / degrees_per_sample))
    active = close_small_circular_gaps(active, gap_samples)
    candidates: list[dict[str, Any]] = []
    for indices in group_circular_true(active):
        width = float(indices.size * degrees_per_sample)
        if width < parameters.candidate_minimum_width_degrees:
            continue
        depths = smoothed[indices]
        symmetry, tip_offset, slope_consistency = candidate_shape(depths)
        weights = np.maximum(depths, 0.001)
        center = circular_mean_degrees(
            [math.degrees(float(angles[index])) % 360.0 for index in indices],
            [float(value) for value in weights],
        )
        candidates.append(
            {
                "centerAngleDegrees": center,
                "startAngleDegrees": math.degrees(float(angles[int(indices[0])])) % 360.0,
                "endAngleDegrees": math.degrees(float(angles[int(indices[-1])])) % 360.0,
                "widthDegrees": width,
                "maximumDepthPx": float(np.max(depths)),
                "medianDepthPx": float(np.median(depths)),
                "sampleCount": int(indices.size),
                "symmetryScore": symmetry,
                "tipCenterOffsetFraction": tip_offset,
                "slopeConsistencyFraction": slope_consistency,
            }
        )
    return sorted(candidates, key=lambda item: item["centerAngleDegrees"]), threshold, noise_sigma


def interval_overlap_fraction(a: dict[str, Any], b: dict[str, Any]) -> float:
    center_distance = circular_distance_degrees(
        float(a["centerAngleDegrees"]), float(b["centerAngleDegrees"])
    )
    half_a = float(a["widthDegrees"]) / 2.0
    half_b = float(b["widthDegrees"]) / 2.0
    overlap = max(0.0, half_a + half_b - center_distance)
    union = half_a + half_b + center_distance
    return float(overlap / union) if union > 0.0 else 0.0


def match_candidates(
    bf_candidates: list[dict[str, Any]],
    df_candidates: list[dict[str, Any]],
    parameters: Parameters,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    remaining = set(range(len(df_candidates)))
    physical: list[dict[str, Any]] = []
    bf_only: list[dict[str, Any]] = []
    for bf in bf_candidates:
        choices = sorted(
            (
                circular_distance_degrees(
                    float(bf["centerAngleDegrees"]),
                    float(df_candidates[index]["centerAngleDegrees"]),
                ),
                index,
            )
            for index in remaining
        )
        if not choices or choices[0][0] > parameters.candidate_match_tolerance_degrees:
            bf_only.append(dict(bf))
            continue
        distance, index = choices[0]
        remaining.remove(index)
        df = df_candidates[index]
        width = max(float(bf["widthDegrees"]), float(df["widthDegrees"]))
        symmetry = max(float(bf["symmetryScore"]), float(df["symmetryScore"]))
        tip_offset = min(float(bf["tipCenterOffsetFraction"]), float(df["tipCenterOffsetFraction"]))
        slope_consistency = max(float(bf["slopeConsistencyFraction"]), float(df["slopeConsistencyFraction"]))
        overlap = interval_overlap_fraction(bf, df)
        manufactured = (
            parameters.manufactured_minimum_width_degrees <= width <= parameters.manufactured_maximum_width_degrees
            and symmetry >= parameters.manufactured_minimum_symmetry
            and tip_offset <= parameters.manufactured_maximum_tip_offset_fraction
            and slope_consistency >= parameters.manufactured_minimum_slope_consistency
            and overlap >= parameters.manufactured_minimum_cross_channel_overlap
        )
        physical.append(
            {
                "bfAngleDegrees": float(bf["centerAngleDegrees"]),
                "dfAngleDegrees": float(df["centerAngleDegrees"]),
                "channelAngleDifferenceDegrees": distance,
                "crossChannelOverlapFraction": overlap,
                "combinedWidthDegrees": width,
                "combinedSymmetryScore": symmetry,
                "combinedTipCenterOffsetFraction": tip_offset,
                "combinedSlopeConsistencyFraction": slope_consistency,
                "manufacturedNotchMorphologyEligible": manufactured,
                "bf": bf,
                "df": df,
                "evidence": "BF_DF_INDEPENDENT_FULL_PERIMETER_BOUNDARY_DISPLACEMENT",
            }
        )
    df_only = [dict(df_candidates[index]) for index in sorted(remaining)]
    return physical, bf_only, df_only


def analyze_pair(identity: str, bf_image: np.ndarray, df_image: np.ndarray, parameters: Parameters) -> dict[str, Any]:
    if bf_image.ndim != 2 or df_image.ndim != 2:
        raise ValueError("BF and DF must be OpenCV-decoded single-channel images.")
    if bf_image.shape != df_image.shape:
        raise ValueError("BF and DF dimensions differ.")
    bf = localize_channel(bf_image, "BF", parameters)
    df = localize_channel(df_image, "DF", parameters)
    physical: list[dict[str, Any]] = []
    bf_only: list[dict[str, Any]] = []
    df_only: list[dict[str, Any]] = []
    if not bf["qualified"] or not df["qualified"]:
        state = "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_NATIVE_PERIMETER_NOT_QUALIFIED"
        comparison: dict[str, Any] = {"evaluated": False, "reason": "BOTH_CHANNELS_MUST_QUALIFY_INDEPENDENTLY"}
        selected = None
    else:
        center_difference = math.hypot(
            float(bf["fit"]["centerX"]) - float(df["fit"]["centerX"]),
            float(bf["fit"]["centerY"]) - float(df["fit"]["centerY"]),
        )
        radius_difference = abs(float(bf["fit"]["radius"]) - float(df["fit"]["radius"]))
        comparison = {
            "evaluated": True,
            "centerDifferencePx": center_difference,
            "radiusDifferencePx": radius_difference,
            "poseAveraged": False,
            "qualified": center_difference <= parameters.maximum_channel_center_difference_px
            and radius_difference <= parameters.maximum_channel_radius_difference_px,
        }
        if not comparison["qualified"]:
            state = "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_BF_DF_PERIMETER_DISAGREEMENT"
            selected = None
        else:
            physical, bf_only, df_only = match_candidates(bf["candidates"], df["candidates"], parameters)
            eligible = [candidate for candidate in physical if candidate["manufacturedNotchMorphologyEligible"]]
            if len(eligible) == 1:
                state = "PASS_REVIEW_ONLY_MANUFACTURED_NOTCH_CANDIDATE"
                selected = eligible[0]
            elif len(eligible) == 0:
                state = "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_NO_MANUFACTURED_NOTCH_MORPHOLOGY"
                selected = None
            else:
                state = "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_MULTIPLE_MANUFACTURED_NOTCH_MORPHOLOGIES"
                selected = None
    return {
        "schema": SCHEMA,
        "identity": identity,
        "state": state,
        "bf": bf,
        "df": df,
        "channelComparison": comparison,
        "physicalIndentationCandidates": physical,
        "bfOnlyBoundaryCandidates": bf_only,
        "dfOnlyBoundaryCandidates": df_only,
        "selectedReviewOnlyManufacturedNotch": selected,
        "manufacturedNotchSelectedForReview": selected is not None,
        "rotationAuthorityGranted": False,
        "bfDfPoseAveraged": False,
        "knownNotchLocationConsumed": False,
        "notchAnglePriorConsumed": False,
        "fixedAngularSearchWindowConsumed": False,
        "regressionLabelThresholdConsumed": False,
        "regressionLabelCandidateFilterConsumed": False,
        "regressionLabelTieBreakerConsumed": False,
        "fullPerimeterInference": True,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
    }


def load_job(path: Path) -> tuple[dict[str, Any], Parameters]:
    job = json.loads(path.read_text(encoding="utf-8"))
    if job.get("schema") != "argos_native_frontside_wafer_pose_opencv_v2_job":
        raise ValueError("V2 job schema changed.")
    if job.get("inferenceScope") != "FULL_360_PERIMETER_NO_LOCATION_PRIOR":
        raise ValueError("V2 job does not require full-perimeter inference.")
    forbidden = {
        "knownnotchangle",
        "knownnotchlocation",
        "expectednotchangle",
        "searchwindow",
        "fixedangularwindow",
        "groundtruth",
        "labels",
    }

    def visit_keys(value: Any) -> list[str]:
        if isinstance(value, dict):
            result = [str(key).lower() for key in value]
            for child in value.values():
                result.extend(visit_keys(child))
            return result
        if isinstance(value, list):
            result: list[str] = []
            for child in value:
                result.extend(visit_keys(child))
            return result
        return []

    present_forbidden = sorted(forbidden.intersection(visit_keys(job)))
    if present_forbidden:
        raise ValueError(
            "V2 detector job contains forbidden scorer-only keys: "
            + ",".join(present_forbidden)
        )
    if job.get("knownNotchLocationConsumed") is not False or job.get("notchAnglePriorConsumed") is not False or job.get("fixedAngularSearchWindowConsumed") is not False or job.get("regressionLabelsConsumed") is not False:
        raise ValueError("V2 detector job algorithm-integrity declaration widened.")
    if job.get("reviewOnly") is not True or any(job.get(key) is not False for key in ("trainingEligible", "xmlEligible", "productionEligible")):
        raise ValueError("V2 job authority widened.")
    inputs = job.get("inputs")
    if not isinstance(inputs, list) or not 1 <= len(inputs) <= 32:
        raise ValueError("V2 job input cardinality is outside 1..32.")
    return job, Parameters.from_json(job["parameters"])


def preflight_job(path: Path) -> dict[str, Any]:
    job, _ = load_job(path)
    identities: set[str] = set()
    for row in job["inputs"]:
        identity = str(row["identity"])
        if not identity or identity in identities:
            raise ValueError("V2 job identity is absent or duplicated.")
        identities.add(identity)
        for channel in ("bf", "df"):
            source = Path(row[f"{channel}Path"])
            if not source.is_file():
                raise FileNotFoundError(f"V2 {channel.upper()} source is absent: {source}")
            if source.stat().st_size != int(row[f"{channel}Bytes"]):
                raise ValueError(f"V2 {channel.upper()} source byte count changed: {identity}")
    return {
        "schema": "argos_native_frontside_wafer_pose_opencv_v2_preflight",
        "state": PASS_PREFLIGHT,
        "jobPath": str(path.resolve()),
        "jobSha256": sha256_file(path),
        "inputCount": len(job["inputs"]),
        "fullPerimeterInference": True,
        "knownNotchLocationConsumed": False,
        "imageBytesDecoded": False,
        "pixelProcessingPerformed": False,
        "mutationsPerformed": False,
        "reviewOnly": True,
        "productionEligible": False,
    }


def execute_job(path: Path, output_root: Path) -> dict[str, Any]:
    job, parameters = load_job(path)
    if output_root.exists():
        raise FileExistsError(f"V2 output root already exists: {output_root}")
    output_root.mkdir(parents=True)
    rows: list[dict[str, Any]] = []
    for row in job["inputs"]:
        identity = str(row["identity"])
        bf_path = Path(row["bfPath"])
        df_path = Path(row["dfPath"])
        if sha256_file(bf_path) != str(row["bfSha256"]).upper():
            raise ValueError(f"V2 BF SHA-256 changed: {identity}")
        if sha256_file(df_path) != str(row["dfSha256"]).upper():
            raise ValueError(f"V2 DF SHA-256 changed: {identity}")
        bf_image = cv2.imread(str(bf_path), cv2.IMREAD_GRAYSCALE)
        df_image = cv2.imread(str(df_path), cv2.IMREAD_GRAYSCALE)
        if bf_image is None or df_image is None:
            raise ValueError(f"OpenCV failed to decode V2 source pair: {identity}")
        result = analyze_pair(identity, bf_image, df_image, parameters)
        result["sources"] = {
            "bfPath": str(bf_path),
            "bfBytes": bf_path.stat().st_size,
            "bfSha256": str(row["bfSha256"]).upper(),
            "dfPath": str(df_path),
            "dfBytes": df_path.stat().st_size,
            "dfSha256": str(row["dfSha256"]).upper(),
        }
        result_path = output_root / identity / "NATIVE_WAFER_POSE_OPENCV_V2.json"
        atomic_write_json(result_path, result)
        rows.append(
            {
                "identity": identity,
                "state": result["state"],
                "resultPath": str(result_path.resolve()),
                "resultSha256": sha256_file(result_path),
                "bfCandidateCount": len(result["bf"].get("candidates", [])),
                "dfCandidateCount": len(result["df"].get("candidates", [])),
                "physicalCandidateCount": len(result["physicalIndentationCandidates"]),
                "manufacturedMorphologyCount": sum(1 for item in result["physicalIndentationCandidates"] if item["manufacturedNotchMorphologyEligible"]),
                "manufacturedNotchSelectedForReview": result["manufacturedNotchSelectedForReview"],
            }
        )
        del bf_image
        del df_image
        gc.collect()
    summary = {
        "schema": SUMMARY_SCHEMA,
        "state": "COMPLETE_REVIEW_ONLY_DEVELOPMENT",
        "jobPath": str(path.resolve()),
        "jobSha256": sha256_file(path),
        "inputCount": len(rows),
        "rows": rows,
        "fullPerimeterInference": True,
        "bfDfIndependent": True,
        "bfDfPoseAveragingAllowed": False,
        "knownNotchLocationConsumed": False,
        "notchAnglePriorConsumed": False,
        "fixedAngularSearchWindowConsumed": False,
        "regressionLabelsConsumed": False,
        "rotationAuthorityGranted": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
    }
    atomic_write_json(output_root / "SUMMARY.json", summary)
    return summary


def draw_synthetic(angle_degrees: float, chipout_angle: float | None) -> np.ndarray:
    image = np.zeros((1024, 1024), dtype=np.uint8)
    center = (512, 512)
    radius = 420
    cv2.circle(image, center, radius, 210, thickness=-1, lineType=cv2.LINE_AA)
    for angle, width, depth, irregular in (
        (angle_degrees, 2.2, 34.0, False),
        *(([(chipout_angle, 5.0, 70.0, True)] if chipout_angle is not None else [])),
    ):
        assert angle is not None
        radians = math.radians(angle)
        half = math.radians(width / 2.0)
        points = []
        for offset in (-half, half):
            points.append(
                (
                    int(round(center[0] + math.cos(radians + offset) * radius)),
                    int(round(center[1] + math.sin(radians + offset) * radius)),
                )
            )
        tip_angle = radians + (math.radians(width * 0.22) if irregular else 0.0)
        points.append(
            (
                int(round(center[0] + math.cos(tip_angle) * (radius - depth))),
                int(round(center[1] + math.sin(tip_angle) * (radius - depth))),
            )
        )
        cv2.fillConvexPoly(image, np.asarray(points, dtype=np.int32), 0, lineType=cv2.LINE_AA)
    return image


def synthetic_parameters() -> Parameters:
    return Parameters.from_json(
        {
            "coarseRadiusMinimumFraction": 0.28,
            "coarseRadiusMaximumFraction": 0.49,
            "coarseRadialStepPx": 2,
            "coarseAngleSamples": 720,
            "refineRadialHalfWidthPx": 100,
            "refineAngleSamples": 1800,
            "radialContrastSpanPx": 8,
            "radialSmoothingWidthPx": 5,
            "minimumBoundaryContrast": 8.0,
            "outerEdgeRelativeContrast": 0.35,
            "fitMadMultiplier": 4.0,
            "fitResidualFloorPx": 2.0,
            "minimumFitInlierFraction": 0.88,
            "minimumAngularCoverageFraction": 0.95,
            "maximumFitRmsResidualPx": 3.0,
            "minimumCandidateDepthPx": 6.0,
            "candidateNoiseMultiplier": 6.0,
            "candidateGapAllowanceDegrees": 0.25,
            "candidateMinimumWidthDegrees": 0.4,
            "candidateMatchToleranceDegrees": 0.8,
            "manufacturedMinimumWidthDegrees": 0.9,
            "manufacturedMaximumWidthDegrees": 3.2,
            "manufacturedMinimumSymmetry": 0.72,
            "manufacturedMaximumTipOffsetFraction": 0.35,
            "manufacturedMinimumSlopeConsistency": 0.55,
            "manufacturedMinimumCrossChannelOverlap": 0.10,
            "maximumChannelCenterDifferencePx": 6.0,
            "maximumChannelRadiusDifferencePx": 6.0,
        }
    )


def synthetic_gate(output_root: Path) -> dict[str, Any]:
    if output_root.exists():
        raise FileExistsError(f"Synthetic V2 output root already exists: {output_root}")
    output_root.mkdir(parents=True)
    parameters = synthetic_parameters()
    cases = [
        ("ANGLE_037_CLEAN", 37.0, None),
        ("ANGLE_217_WITH_CHIPOUT", 217.0, 41.0),
    ]
    rows = []
    for case_id, notch_angle, chipout_angle in cases:
        bf = draw_synthetic(notch_angle, chipout_angle)
        df = draw_synthetic(notch_angle + 0.15, None if chipout_angle is None else chipout_angle + 0.12)
        result = analyze_pair(case_id, bf, df, parameters)
        selected = result["selectedReviewOnlyManufacturedNotch"]
        detected = None if selected is None else float(selected["bfAngleDegrees"])
        passed = detected is not None and circular_distance_degrees(detected, notch_angle) <= 0.8
        if chipout_angle is not None and detected is not None:
            passed = passed and circular_distance_degrees(detected, chipout_angle) > 1.0
        rows.append(
            {
                "caseId": case_id,
                "expectedAngleDegreesScorerOnly": notch_angle,
                "detectedBfAngleDegrees": detected,
                "state": result["state"],
                "passed": passed,
            }
        )
        atomic_write_json(output_root / case_id / "RESULT.json", result)
    gate = {
        "schema": "argos_native_frontside_wafer_pose_opencv_v2_synthetic_gate",
        "state": "PASS_OPENCV_V2_SYNTHETIC_GATE" if all(row["passed"] for row in rows) else "FAIL_OPENCV_V2_SYNTHETIC_GATE",
        "rows": rows,
        "inferenceAnglesDiffer": True,
        "chipoutControlIncluded": True,
        "knownLocationConsumedByDetector": False,
        "expectedAnglesUsedOnlyAfterInference": True,
    }
    atomic_write_json(output_root / "SYNTHETIC_GATE.json", gate)
    return gate


def runtime_preflight() -> dict[str, Any]:
    probe = np.zeros((64, 64), dtype=np.uint8)
    cv2.circle(probe, (32, 32), 20, 255, 1)
    return {
        "schema": "argos_native_frontside_wafer_pose_opencv_v2_runtime_preflight",
        "state": "PASS_OPENCV_NATIVE_POSE_V2_RUNTIME_PREFLIGHT",
        "pythonVersion": platform.python_version(),
        "opencvVersion": cv2.__version__,
        "numpyVersion": np.__version__,
        "probeNonzeroPixels": int(cv2.countNonZero(probe)),
        "imageBytesDecoded": False,
        "mutationsPerformed": False,
    }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--runtime-preflight", action="store_true")
    mode.add_argument("--preflight", action="store_true")
    mode.add_argument("--synthetic-gate", action="store_true")
    mode.add_argument("--run", action="store_true")
    parser.add_argument("--job")
    parser.add_argument("--output-root")
    return parser.parse_args()


def main() -> int:
    args = parse_arguments()
    if args.runtime_preflight:
        result = runtime_preflight()
    elif args.preflight:
        if not args.job or args.output_root:
            raise ValueError("--preflight requires --job and forbids --output-root.")
        result = preflight_job(Path(args.job))
    elif args.synthetic_gate:
        if args.job or not args.output_root:
            raise ValueError("--synthetic-gate requires --output-root and forbids --job.")
        result = synthetic_gate(Path(args.output_root))
    else:
        if not args.job or not args.output_root:
            raise ValueError("--run requires --job and --output-root.")
        result = execute_job(Path(args.job), Path(args.output_root))
    json.dump(result, sys.stdout, indent=2, default=json_scalar)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
