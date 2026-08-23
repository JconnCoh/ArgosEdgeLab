#!/usr/bin/env python3
"""Review-only independent-channel native wafer perimeter/notch diagnostic.

This module is a new implementation. It does not inherit the withdrawn C# V3
fit or use FS15 outcomes. BF and DF are sampled, fitted, and qualified
independently. Cross-channel comparison is diagnostic and never averages pose.
"""

from __future__ import annotations

import argparse
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


SCHEMA = "argos_native_frontside_wafer_pose_opencv_v1"
PASS_PREFLIGHT = "PASS_NATIVE_FRONTSIDE_WAFER_POSE_OPENCV_V1_PREFLIGHT"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def circular_distance_degrees(a: float, b: float) -> float:
    delta = abs(a - b) % 360.0
    return min(delta, 360.0 - delta)


def json_scalar(value: Any) -> Any:
    if isinstance(value, np.generic):
        return value.item()
    if isinstance(value, np.ndarray):
        return value.tolist()
    return value


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


@dataclass(frozen=True)
class FitParameters:
    nominal_radius_fraction: float
    radial_half_width_px: int
    angle_samples: int
    minimum_gradient: float
    gradient_relative_floor: float
    fit_mad_multiplier: float
    fit_residual_floor_px: float
    minimum_fit_inlier_fraction: float
    minimum_angular_coverage_fraction: float
    candidate_depth_px: float
    candidate_minimum_width_degrees: float
    candidate_match_tolerance_degrees: float
    maximum_channel_center_difference_px: float
    maximum_channel_radius_difference_px: float

    @staticmethod
    def from_json(value: dict[str, Any]) -> "FitParameters":
        result = FitParameters(
            nominal_radius_fraction=float(value["nominalRadiusFraction"]),
            radial_half_width_px=int(value["radialHalfWidthPx"]),
            angle_samples=int(value["angleSamples"]),
            minimum_gradient=float(value["minimumGradient"]),
            gradient_relative_floor=float(value["gradientRelativeFloor"]),
            fit_mad_multiplier=float(value["fitMadMultiplier"]),
            fit_residual_floor_px=float(value["fitResidualFloorPx"]),
            minimum_fit_inlier_fraction=float(value["minimumFitInlierFraction"]),
            minimum_angular_coverage_fraction=float(
                value["minimumAngularCoverageFraction"]
            ),
            candidate_depth_px=float(value["candidateDepthPx"]),
            candidate_minimum_width_degrees=float(
                value["candidateMinimumWidthDegrees"]
            ),
            candidate_match_tolerance_degrees=float(
                value["candidateMatchToleranceDegrees"]
            ),
            maximum_channel_center_difference_px=float(
                value["maximumChannelCenterDifferencePx"]
            ),
            maximum_channel_radius_difference_px=float(
                value["maximumChannelRadiusDifferencePx"]
            ),
        )
        if not 0.2 <= result.nominal_radius_fraction <= 0.5:
            raise ValueError("nominalRadiusFraction must be in [0.2, 0.5].")
        if not 32 <= result.radial_half_width_px <= 2048:
            raise ValueError("radialHalfWidthPx must be in [32, 2048].")
        if not 360 <= result.angle_samples <= 16384:
            raise ValueError("angleSamples must be in [360, 16384].")
        if not 0.0 < result.gradient_relative_floor <= 1.0:
            raise ValueError("gradientRelativeFloor must be in (0, 1].")
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


def robust_circle(points: np.ndarray, parameters: FitParameters) -> dict[str, Any]:
    retained = np.ones(points.shape[0], dtype=bool)
    cx = cy = radius = math.nan
    for _ in range(8):
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
        if updated.sum() < 3:
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
        "residuals": residuals,
        "acceptedCount": int(retained.sum()),
        "inputCount": int(points.shape[0]),
        "inlierFraction": float(retained.mean()),
        "rmsResidualPx": float(math.sqrt(np.mean(accepted * accepted))),
        "p90AbsoluteResidualPx": float(np.percentile(np.abs(accepted), 90.0)),
    }


def circular_median(values: np.ndarray, window: int) -> np.ndarray:
    if window < 1 or window % 2 == 0:
        raise ValueError("Circular median window must be a positive odd integer.")
    half = window // 2
    padded = np.concatenate((values[-half:], values, values[:half]))
    return np.array(
        [np.nanmedian(padded[index : index + window]) for index in range(values.size)],
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
            groups.append(np.array(current, dtype=np.int32))
            current = []
    if current:
        groups.append(np.array(current, dtype=np.int32))
    return groups


def extract_candidates(
    angles: np.ndarray,
    displacement: np.ndarray,
    valid: np.ndarray,
    parameters: FitParameters,
) -> list[dict[str, Any]]:
    smoothed = circular_median(displacement, 5)
    active = valid & (smoothed >= parameters.candidate_depth_px)
    degrees_per_sample = 360.0 / angles.size
    candidates: list[dict[str, Any]] = []
    for indices in group_circular_true(active):
        width = float(indices.size * degrees_per_sample)
        if width < parameters.candidate_minimum_width_degrees:
            continue
        radians = angles[indices]
        weights = np.maximum(smoothed[indices], 0.001)
        vector_x = float(np.sum(np.cos(radians) * weights))
        vector_y = float(np.sum(np.sin(radians) * weights))
        center_degrees = math.degrees(math.atan2(vector_y, vector_x)) % 360.0
        candidates.append(
            {
                "centerAngleDegrees": center_degrees,
                "widthDegrees": width,
                "maximumDepthPx": float(np.max(smoothed[indices])),
                "medianDepthPx": float(np.median(smoothed[indices])),
                "sampleCount": int(indices.size),
            }
        )
    return sorted(candidates, key=lambda item: item["centerAngleDegrees"])


def analyze_channel(
    image: np.ndarray, channel: str, parameters: FitParameters
) -> dict[str, Any]:
    height, width = image.shape
    seed_x = (width - 1) / 2.0
    seed_y = (height - 1) / 2.0
    seed_radius = min(width, height) * parameters.nominal_radius_fraction
    radial_offsets = np.arange(
        -parameters.radial_half_width_px,
        parameters.radial_half_width_px + 1,
        dtype=np.float32,
    )
    radii = seed_radius + radial_offsets
    if radii[0] <= 0.0:
        raise ValueError("Radial search reaches a non-positive radius.")
    angles = np.linspace(
        0.0, 2.0 * math.pi, parameters.angle_samples, endpoint=False, dtype=np.float32
    )
    map_x = seed_x + np.cos(angles)[:, None] * radii[None, :]
    map_y = seed_y + np.sin(angles)[:, None] * radii[None, :]
    profiles = cv2.remap(
        image,
        map_x.astype(np.float32),
        map_y.astype(np.float32),
        interpolation=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0,
    ).astype(np.float32)
    radial_gradient = np.abs(np.diff(profiles, axis=1))
    best_indices = np.argmax(radial_gradient, axis=1)
    scores = radial_gradient[np.arange(parameters.angle_samples), best_indices]
    best_radii = (radii[:-1] + 0.5)[best_indices]
    adaptive_floor = max(
        parameters.minimum_gradient,
        float(np.percentile(scores, 75.0)) * parameters.gradient_relative_floor,
    )
    supported = scores >= adaptive_floor
    points = np.column_stack(
        (
            seed_x + np.cos(angles) * best_radii,
            seed_y + np.sin(angles) * best_radii,
        )
    )
    if supported.sum() < 16:
        return {
            "channel": channel,
            "qualified": False,
            "state": "HOLD_NATIVE_PERIMETER_DIRECT_SUPPORT_INSUFFICIENT",
            "widthPx": width,
            "heightPx": height,
            "supportedSamples": int(supported.sum()),
            "angleSamples": parameters.angle_samples,
            "adaptiveGradientFloor": adaptive_floor,
            "candidates": [],
        }
    supported_points = points[supported]
    fit = robust_circle(supported_points, parameters)
    supported_angles = angles[supported]
    accepted_supported = fit["acceptedMask"]
    accepted_bins = np.unique(
        np.floor((supported_angles[accepted_supported] % (2.0 * math.pi)) / (2.0 * math.pi) * 72.0).astype(int)
    )
    coverage = float(accepted_bins.size / 72.0)
    point_radius = np.hypot(points[:, 0] - fit["centerX"], points[:, 1] - fit["centerY"])
    displacement = fit["radius"] - point_radius
    candidates = extract_candidates(angles, displacement, supported, parameters)
    qualified = (
        fit["inlierFraction"] >= parameters.minimum_fit_inlier_fraction
        and coverage >= parameters.minimum_angular_coverage_fraction
    )
    state = (
        "PASS_NATIVE_PERIMETER_CHANNEL_QUALIFIED"
        if qualified
        else "HOLD_NATIVE_PERIMETER_CHANNEL_NOT_QUALIFIED"
    )
    return {
        "channel": channel,
        "qualified": qualified,
        "state": state,
        "widthPx": width,
        "heightPx": height,
        "seed": {"centerX": seed_x, "centerY": seed_y, "radius": seed_radius},
        "fit": {
            "centerX": fit["centerX"],
            "centerY": fit["centerY"],
            "radius": fit["radius"],
            "acceptedCount": fit["acceptedCount"],
            "inputCount": fit["inputCount"],
            "inlierFraction": fit["inlierFraction"],
            "angularCoverageFraction": coverage,
            "rmsResidualPx": fit["rmsResidualPx"],
            "p90AbsoluteResidualPx": fit["p90AbsoluteResidualPx"],
        },
        "supportedSamples": int(supported.sum()),
        "angleSamples": parameters.angle_samples,
        "adaptiveGradientFloor": adaptive_floor,
        "candidates": candidates,
    }


def match_candidates(
    bf: list[dict[str, Any]], df: list[dict[str, Any]], tolerance: float
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    remaining_df = set(range(len(df)))
    physical: list[dict[str, Any]] = []
    bf_only: list[dict[str, Any]] = []
    for bf_candidate in bf:
        choices = sorted(
            (
                circular_distance_degrees(
                    float(bf_candidate["centerAngleDegrees"]),
                    float(df[index]["centerAngleDegrees"]),
                ),
                index,
            )
            for index in remaining_df
        )
        if choices and choices[0][0] <= tolerance:
            distance, index = choices[0]
            remaining_df.remove(index)
            physical.append(
                {
                    "centerAngleDegrees": (
                        float(bf_candidate["centerAngleDegrees"])
                        + math.copysign(
                            distance / 2.0,
                            ((float(df[index]["centerAngleDegrees"]) - float(bf_candidate["centerAngleDegrees"]) + 540.0) % 360.0) - 180.0,
                        )
                    )
                    % 360.0,
                    "channelAngleDifferenceDegrees": distance,
                    "bf": bf_candidate,
                    "df": df[index],
                    "evidence": "BF_DF_PHYSICAL_BOUNDARY_DISPLACEMENT",
                }
            )
        else:
            item = dict(bf_candidate)
            item["evidence"] = "CHANNEL_LOCAL_BOUNDARY_RESPONSE_NO_DF_DISPLACEMENT"
            bf_only.append(item)
    df_only = []
    for index in sorted(remaining_df):
        item = dict(df[index])
        item["evidence"] = "CHANNEL_LOCAL_BOUNDARY_RESPONSE_NO_BF_DISPLACEMENT"
        df_only.append(item)
    return physical, bf_only, df_only


def analyze_pair(
    identity: str,
    bf_image: np.ndarray,
    df_image: np.ndarray,
    parameters: FitParameters,
) -> dict[str, Any]:
    if bf_image.ndim != 2 or df_image.ndim != 2:
        raise ValueError("BF and DF must be single-channel grayscale images.")
    if bf_image.shape != df_image.shape:
        raise ValueError("BF and DF dimensions differ.")
    bf = analyze_channel(bf_image, "BF", parameters)
    df = analyze_channel(df_image, "DF", parameters)
    if not bf["qualified"] or not df["qualified"]:
        state = "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_NATIVE_PERIMETER_NOT_QUALIFIED"
        comparison: dict[str, Any] = {
            "evaluated": False,
            "reason": "BOTH_CHANNELS_MUST_QUALIFY_INDEPENDENTLY",
        }
        physical: list[dict[str, Any]] = []
        bf_only: list[dict[str, Any]] = []
        df_only: list[dict[str, Any]] = []
    else:
        center_difference = math.hypot(
            float(bf["fit"]["centerX"]) - float(df["fit"]["centerX"]),
            float(bf["fit"]["centerY"]) - float(df["fit"]["centerY"]),
        )
        radius_difference = abs(
            float(bf["fit"]["radius"]) - float(df["fit"]["radius"])
        )
        comparison = {
            "evaluated": True,
            "centerDifferencePx": center_difference,
            "radiusDifferencePx": radius_difference,
            "poseAveraged": False,
            "qualified": center_difference
            <= parameters.maximum_channel_center_difference_px
            and radius_difference <= parameters.maximum_channel_radius_difference_px,
        }
        if not comparison["qualified"]:
            state = "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_BF_DF_PERIMETER_DISAGREEMENT"
            physical, bf_only, df_only = [], [], []
        else:
            physical, bf_only, df_only = match_candidates(
                bf["candidates"],
                df["candidates"],
                parameters.candidate_match_tolerance_degrees,
            )
            if len(physical) == 0:
                state = "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_NO_PHYSICAL_INDENTATION"
            elif len(physical) > 1:
                state = "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_MULTIPLE_PHYSICAL_INDENTATIONS"
            else:
                state = (
                    "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_MANUFACTURED_NOTCH_MORPHOLOGY_"
                    "AND_RECIPROCAL_SCRIBE_REQUIRED"
                )
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
        "manufacturedNotchSelected": False,
        "thumbnailPoseAuthority": False,
        "thumbnailCandidateAuthority": False,
        "bfDfPoseAveraged": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
    }


def read_job(path: Path) -> tuple[dict[str, Any], FitParameters]:
    job = json.loads(path.read_text(encoding="utf-8"))
    if job.get("schema") != "argos_native_frontside_wafer_pose_opencv_v1_job":
        raise ValueError("Unsupported job schema.")
    if not job.get("reviewOnly"):
        raise ValueError("Job must be review-only.")
    for field in ("trainingEligible", "xmlEligible", "productionEligible"):
        if job.get(field):
            raise ValueError(f"Job authority is not bounded: {field} is true.")
    inputs = job.get("inputs")
    if not isinstance(inputs, list) or not 1 <= len(inputs) <= 32:
        raise ValueError("Job must contain 1..32 inputs.")
    return job, FitParameters.from_json(job["parameters"])


def preflight_job(path: Path) -> dict[str, Any]:
    job, _ = read_job(path)
    verified = []
    for item in job["inputs"]:
        identity = str(item["identity"])
        if str(item.get("combinationId", "")).upper() == "FS15":
            raise ValueError("FS15 is prohibited as OpenCV development input.")
        channels = {}
        for channel in ("bf", "df"):
            source = Path(item[f"{channel}Path"])
            if not source.is_file():
                raise FileNotFoundError(f"Missing {channel.upper()} input: {source}")
            actual = sha256_file(source)
            expected = str(item[f"{channel}Sha256"]).upper()
            if actual != expected:
                raise ValueError(f"{channel.upper()} hash mismatch for {identity}.")
            channels[channel] = {"path": str(source.resolve()), "sha256": actual}
        verified.append({"identity": identity, "channels": channels})
    return {
        "schema": "argos_native_frontside_wafer_pose_opencv_v1_preflight",
        "state": PASS_PREFLIGHT,
        "jobPath": str(path.resolve()),
        "jobSha256": sha256_file(path),
        "verifiedInputCount": len(verified),
        "verifiedInputs": verified,
        "mutationsPerformed": False,
        "bfDfIndependent": True,
        "bfDfPoseAveragingAllowed": False,
        "fs15TuningAllowed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
    }


def execute_job(path: Path, output_root: Path) -> dict[str, Any]:
    preflight = preflight_job(path)
    job, parameters = read_job(path)
    if output_root.exists():
        raise FileExistsError(f"Output root already exists: {output_root}")
    output_root.mkdir(parents=True)
    rows = []
    for item in job["inputs"]:
        identity = str(item["identity"])
        bf_path = Path(item["bfPath"])
        df_path = Path(item["dfPath"])
        bf = cv2.imread(str(bf_path), cv2.IMREAD_GRAYSCALE)
        df = cv2.imread(str(df_path), cv2.IMREAD_GRAYSCALE)
        if bf is None or df is None:
            raise ValueError(f"OpenCV could not decode BF/DF for {identity}.")
        result = analyze_pair(identity, bf, df, parameters)
        result["provenance"] = {
            "combinationId": item["combinationId"],
            "bfPath": str(bf_path.resolve()),
            "bfSha256": sha256_file(bf_path),
            "dfPath": str(df_path.resolve()),
            "dfSha256": sha256_file(df_path),
        }
        result_path = output_root / identity / "NATIVE_WAFER_POSE_OPENCV_V1.json"
        atomic_write_json(result_path, result)
        rows.append(
            {
                "identity": identity,
                "state": result["state"],
                "resultPath": str(result_path.resolve()),
                "resultSha256": sha256_file(result_path),
            }
        )
    summary = {
        "schema": "argos_native_frontside_wafer_pose_opencv_v1_summary",
        "state": "COMPLETE_REVIEW_ONLY_DIAGNOSTIC",
        "jobPath": preflight["jobPath"],
        "jobSha256": preflight["jobSha256"],
        "inputCount": len(rows),
        "rows": rows,
        "bfDfIndependent": True,
        "bfDfPoseAveragingAllowed": False,
        "manufacturedNotchAuthorityGranted": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
    }
    atomic_write_json(output_root / "SUMMARY.json", summary)
    return summary


def runtime_preflight() -> dict[str, Any]:
    probe = np.zeros((32, 32), dtype=np.uint8)
    cv2.circle(probe, (16, 16), 10, 255, 1)
    edges = cv2.Canny(probe, 50, 150)
    if int(np.count_nonzero(edges)) <= 0:
        raise RuntimeError("Synthetic OpenCV edge smoke produced no edges.")
    return {
        "schema": "argos_opencv_native_pose_runtime_preflight_v1",
        "state": "PASS_OPENCV_NATIVE_POSE_RUNTIME_PREFLIGHT",
        "pythonVersion": platform.python_version(),
        "pythonImplementation": platform.python_implementation(),
        "pythonArchitectureBits": 64 if sys.maxsize > 2**32 else 32,
        "opencvVersion": cv2.__version__,
        "numpyVersion": np.__version__,
        "syntheticEdgePixels": int(np.count_nonzero(edges)),
        "mutationsPerformed": False,
        "reviewOnly": True,
    }


def draw_synthetic_wafer(
    size: int,
    center: tuple[int, int],
    radius: int,
    indentations: list[tuple[float, float, float]],
    inside: int,
    background: int,
    seed: int,
) -> np.ndarray:
    image = np.full((size, size), background, dtype=np.uint8)
    cv2.circle(image, center, radius, inside, thickness=-1, lineType=cv2.LINE_AA)
    for angle_degrees, width_degrees, depth in indentations:
        angle = math.radians(angle_degrees)
        half = math.radians(width_degrees / 2.0)
        outer_a = (
            int(round(center[0] + radius * math.cos(angle - half))),
            int(round(center[1] + radius * math.sin(angle - half))),
        )
        outer_b = (
            int(round(center[0] + radius * math.cos(angle + half))),
            int(round(center[1] + radius * math.sin(angle + half))),
        )
        inner = (
            int(round(center[0] + (radius - depth) * math.cos(angle))),
            int(round(center[1] + (radius - depth) * math.sin(angle))),
        )
        cv2.fillConvexPoly(
            image, np.array([outer_a, outer_b, inner], dtype=np.int32), background
        )
    generator = np.random.default_rng(seed)
    noise = generator.normal(0.0, 1.2, image.shape)
    return np.clip(image.astype(np.float32) + noise, 0, 255).astype(np.uint8)


def synthetic_parameters() -> FitParameters:
    return FitParameters(
        nominal_radius_fraction=0.40,
        radial_half_width_px=80,
        angle_samples=1440,
        minimum_gradient=10.0,
        gradient_relative_floor=0.35,
        fit_mad_multiplier=4.5,
        fit_residual_floor_px=1.5,
        minimum_fit_inlier_fraction=0.88,
        minimum_angular_coverage_fraction=0.90,
        candidate_depth_px=7.0,
        candidate_minimum_width_degrees=1.0,
        candidate_match_tolerance_degrees=2.5,
        maximum_channel_center_difference_px=10.0,
        maximum_channel_radius_difference_px=8.0,
    )


def synthetic_gate(output_root: Path) -> dict[str, Any]:
    if output_root.exists():
        raise FileExistsError(f"Synthetic output root already exists: {output_root}")
    output_root.mkdir(parents=True)
    parameters = synthetic_parameters()
    size = 1024
    cases = [
        {
            "id": "CLEAN_PAIRED",
            "bfCenter": (512, 512),
            "dfCenter": (514, 510),
            "bfIndentations": [],
            "dfIndentations": [],
            "expectedState": "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_NO_PHYSICAL_INDENTATION",
            "expectedPhysical": 0,
            "expectedBfOnly": 0,
            "expectedDfOnly": 0,
        },
        {
            "id": "PAIRED_SINGLE",
            "bfCenter": (512, 512),
            "dfCenter": (515, 510),
            "bfIndentations": [(270.0, 5.0, 34.0)],
            "dfIndentations": [(270.5, 5.0, 31.0)],
            "expectedState": "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_MANUFACTURED_NOTCH_MORPHOLOGY_AND_RECIPROCAL_SCRIBE_REQUIRED",
            "expectedPhysical": 1,
            "expectedBfOnly": None,
            "expectedDfOnly": None,
        },
        {
            "id": "BF_ONLY_APPEARANCE",
            "bfCenter": (512, 512),
            "dfCenter": (512, 512),
            "bfIndentations": [(210.0, 5.0, 32.0)],
            "dfIndentations": [],
            "expectedState": "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_NO_PHYSICAL_INDENTATION",
            "expectedPhysical": 0,
            "expectedBfOnly": 1,
            "expectedDfOnly": 0,
        },
        {
            "id": "TWO_PHYSICAL_COMPETITORS",
            "bfCenter": (512, 512),
            "dfCenter": (513, 511),
            "bfIndentations": [(120.0, 4.0, 28.0), (275.0, 5.0, 35.0)],
            "dfIndentations": [(120.5, 4.0, 27.0), (274.5, 5.0, 33.0)],
            "expectedState": "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_MULTIPLE_PHYSICAL_INDENTATIONS",
            "expectedPhysical": 2,
            "expectedBfOnly": 0,
            "expectedDfOnly": 0,
        },
        {
            "id": "CHANNEL_POSE_DISAGREEMENT",
            "bfCenter": (496, 512),
            "dfCenter": (528, 512),
            "bfIndentations": [(270.0, 5.0, 32.0)],
            "dfIndentations": [(270.0, 5.0, 32.0)],
            "expectedState": "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_BF_DF_PERIMETER_DISAGREEMENT",
            "expectedPhysical": 0,
            "expectedBfOnly": 0,
            "expectedDfOnly": 0,
        },
    ]
    results = []
    failures = []
    for index, case in enumerate(cases):
        bf = draw_synthetic_wafer(
            size,
            case["bfCenter"],
            410,
            case["bfIndentations"],
            190,
            24,
            1000 + index,
        )
        df = draw_synthetic_wafer(
            size,
            case["dfCenter"],
            407,
            case["dfIndentations"],
            125,
            10,
            2000 + index,
        )
        case_root = output_root / case["id"]
        case_root.mkdir()
        bf_path = case_root / "BF.bmp"
        df_path = case_root / "DF.bmp"
        if not cv2.imwrite(str(bf_path), bf) or not cv2.imwrite(str(df_path), df):
            raise RuntimeError("Failed to write synthetic BF/DF evidence.")
        result = analyze_pair(case["id"], bf, df, parameters)
        result["syntheticProvenance"] = {
            "bfPath": str(bf_path.resolve()),
            "bfSha256": sha256_file(bf_path),
            "dfPath": str(df_path.resolve()),
            "dfSha256": sha256_file(df_path),
        }
        result_path = case_root / "RESULT.json"
        atomic_write_json(result_path, result)
        actual_physical = len(result["physicalIndentationCandidates"])
        actual_bf_only = len(result["bfOnlyBoundaryCandidates"])
        actual_df_only = len(result["dfOnlyBoundaryCandidates"])
        bf_only_matches = (
            case["expectedBfOnly"] is None
            or actual_bf_only == case["expectedBfOnly"]
        )
        df_only_matches = (
            case["expectedDfOnly"] is None
            or actual_df_only == case["expectedDfOnly"]
        )
        passed = (
            result["state"] == case["expectedState"]
            and actual_physical == case["expectedPhysical"]
            and bf_only_matches
            and df_only_matches
            and result["bfDfPoseAveraged"] is False
            and result["manufacturedNotchSelected"] is False
        )
        if not passed:
            failures.append(case["id"])
        results.append(
            {
                "caseId": case["id"],
                "expectedState": case["expectedState"],
                "actualState": result["state"],
                "expectedPhysicalCandidates": case["expectedPhysical"],
                "actualPhysicalCandidates": actual_physical,
                "expectedBfOnlyCandidates": case["expectedBfOnly"],
                "actualBfOnlyCandidates": actual_bf_only,
                "expectedDfOnlyCandidates": case["expectedDfOnly"],
                "actualDfOnlyCandidates": actual_df_only,
                "resultPath": str(result_path.resolve()),
                "resultSha256": sha256_file(result_path),
                "passed": passed,
            }
        )
    independence_bf = draw_synthetic_wafer(
        size, (512, 512), 410, [(265.0, 5.0, 32.0)], 190, 24, 7001
    )
    independence_df_a = draw_synthetic_wafer(
        size, (512, 512), 407, [(265.0, 5.0, 30.0)], 125, 10, 7002
    )
    independence_df_b = draw_synthetic_wafer(
        size, (535, 498), 397, [(120.0, 7.0, 42.0)], 125, 10, 7003
    )
    independence_a = analyze_pair(
        "CHANNEL_INDEPENDENCE_A", independence_bf, independence_df_a, parameters
    )
    independence_b = analyze_pair(
        "CHANNEL_INDEPENDENCE_B", independence_bf, independence_df_b, parameters
    )
    bf_a = independence_a["bf"]
    bf_b = independence_b["bf"]
    channel_independence_pass = bf_a == bf_b
    if not channel_independence_pass:
        failures.append("BF_RESULT_DEPENDS_ON_DF")
    independence_gate = {
        "schema": "argos_native_pose_channel_independence_gate_v1",
        "state": (
            "PASS_BF_RESULT_INVARIANT_TO_DF_MUTATION"
            if channel_independence_pass
            else "FAIL_BF_RESULT_CHANGED_WITH_DF_MUTATION"
        ),
        "bfResultExactObjectMatch": channel_independence_pass,
        "bfDfPoseAveragingAllowed": False,
        "reviewOnly": True,
    }
    atomic_write_json(output_root / "CHANNEL_INDEPENDENCE_GATE.json", independence_gate)

    fs15_job_path = output_root / "FS15_REFUSAL_JOB.json"
    atomic_write_json(
        fs15_job_path,
        {
            "schema": "argos_native_frontside_wafer_pose_opencv_v1_job",
            "parameters": {
                "nominalRadiusFraction": parameters.nominal_radius_fraction,
                "radialHalfWidthPx": parameters.radial_half_width_px,
                "angleSamples": parameters.angle_samples,
                "minimumGradient": parameters.minimum_gradient,
                "gradientRelativeFloor": parameters.gradient_relative_floor,
                "fitMadMultiplier": parameters.fit_mad_multiplier,
                "fitResidualFloorPx": parameters.fit_residual_floor_px,
                "minimumFitInlierFraction": parameters.minimum_fit_inlier_fraction,
                "minimumAngularCoverageFraction": parameters.minimum_angular_coverage_fraction,
                "candidateDepthPx": parameters.candidate_depth_px,
                "candidateMinimumWidthDegrees": parameters.candidate_minimum_width_degrees,
                "candidateMatchToleranceDegrees": parameters.candidate_match_tolerance_degrees,
                "maximumChannelCenterDifferencePx": parameters.maximum_channel_center_difference_px,
                "maximumChannelRadiusDifferencePx": parameters.maximum_channel_radius_difference_px,
            },
            "inputs": [
                {
                    "identity": "PROHIBITED_FS15",
                    "combinationId": "FS15",
                    "bfPath": str(output_root / "CLEAN_PAIRED" / "BF.bmp"),
                    "dfPath": str(output_root / "CLEAN_PAIRED" / "DF.bmp"),
                    "bfSha256": "NOT_REACHED",
                    "dfSha256": "NOT_REACHED",
                }
            ],
            "reviewOnly": True,
            "trainingEligible": False,
            "xmlEligible": False,
            "productionEligible": False,
        },
    )
    fs15_refused = False
    try:
        preflight_job(fs15_job_path)
    except ValueError as error:
        fs15_refused = "FS15 is prohibited" in str(error)
    if not fs15_refused:
        failures.append("FS15_PREFLIGHT_NOT_REFUSED")
    fs15_gate = {
        "schema": "argos_native_pose_fs15_refusal_gate_v1",
        "state": (
            "PASS_FS15_DEVELOPMENT_INPUT_REFUSED"
            if fs15_refused
            else "FAIL_FS15_DEVELOPMENT_INPUT_ACCEPTED"
        ),
        "fs15TuningAllowed": False,
        "reviewOnly": True,
    }
    atomic_write_json(output_root / "FS15_REFUSAL_GATE.json", fs15_gate)
    gate = {
        "schema": "argos_native_frontside_wafer_pose_opencv_v1_synthetic_gate",
        "state": (
            "PASS_OPENCV_NATIVE_POSE_SYNTHETIC_GATE"
            if not failures
            else "FAIL_OPENCV_NATIVE_POSE_SYNTHETIC_GATE"
        ),
        "caseCount": len(cases),
        "passCount": len(cases) - len(failures),
        "failedCaseIds": failures,
        "cases": results,
        "channelIndependenceGate": independence_gate,
        "fs15RefusalGate": fs15_gate,
        "bfDfIndependent": True,
        "bfDfPoseAveragingAllowed": False,
        "manufacturedNotchAuthorityGranted": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
    }
    atomic_write_json(output_root / "SYNTHETIC_GATE.json", gate)
    return gate


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    actions = parser.add_mutually_exclusive_group(required=True)
    actions.add_argument("--runtime-preflight", action="store_true")
    actions.add_argument("--preflight", action="store_true")
    actions.add_argument("--run", action="store_true")
    actions.add_argument("--synthetic-gate", action="store_true")
    parser.add_argument("--job")
    parser.add_argument("--output-root")
    return parser.parse_args()


def main() -> int:
    args = parse_arguments()
    if args.runtime_preflight:
        result = runtime_preflight()
    elif args.synthetic_gate:
        if not args.output_root:
            raise ValueError("--synthetic-gate requires --output-root.")
        result = synthetic_gate(Path(args.output_root))
    elif args.preflight:
        if not args.job:
            raise ValueError("--preflight requires --job.")
        if args.output_root:
            raise ValueError("--preflight must not receive --output-root.")
        result = preflight_job(Path(args.job))
    else:
        if not args.job or not args.output_root:
            raise ValueError("--run requires --job and --output-root.")
        result = execute_job(Path(args.job), Path(args.output_root))
    print(json.dumps(result, separators=(",", ":"), default=json_scalar))
    return 0 if str(result.get("state", "")).startswith(("PASS_", "COMPLETE_")) else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        failure = {
            "schema": "argos_native_frontside_wafer_pose_opencv_v1_failure",
            "state": "FAIL_OPENCV_NATIVE_POSE_EXECUTION",
            "errorType": type(error).__name__,
            "message": str(error),
            "reviewOnly": True,
        }
        print(json.dumps(failure, separators=(",", ":")))
        raise SystemExit(1)
