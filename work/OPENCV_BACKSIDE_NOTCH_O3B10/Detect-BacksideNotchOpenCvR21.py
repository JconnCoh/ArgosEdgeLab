#!/usr/bin/env python3
"""R21 channel-local holder exclusion and appearance confirmation over R20."""

from __future__ import annotations

import gc
import importlib.util
import math
from pathlib import Path
import sys

import cv2
import numpy as np


R20_SHA256 = "B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C"


def load_r20():
    path = Path(__file__).with_name("OCV03_BacksideNotchDevelopment_O3B10R20.py")
    if not path.is_file():
        path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR20.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r20_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R20 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R18.R17.BASE.sha256_file(path) != R20_SHA256:
        raise RuntimeError(f"Frozen R20 detector hash changed: {path}")
    return module


R20 = load_r20()
R17 = R20.R18.R17
BASE = R17.BASE
ORIGINAL_LOCALIZE = None
LAST_LOCALIZATION: dict[str, dict] = {}


def mask_at_count(mask: np.ndarray, count: int) -> np.ndarray:
    indices = np.floor(np.arange(count) * mask.size / count).astype(np.int32)
    return mask[np.minimum(indices, mask.size - 1)]


def holder_spans(mask: np.ndarray) -> list[dict[str, float]]:
    degrees = 360.0 / mask.size
    return [
        {
            "startAngleDegrees": float(group[0] * degrees),
            "endAngleDegrees": float(((group[-1] + 1) * degrees) % 360.0),
            "widthDegrees": float(group.size * degrees),
        }
        for group in R17.BASE_RADIAL.group_circular_true(mask)
    ]


def derive_holder_mask(image, center_x, center_y, radius, angle_samples, parameters):
    core = R17.BASE_RADIAL
    inner = float(parameters["holderExteriorInnerOffsetPx"])
    outer = float(parameters["holderExteriorOuterOffsetPx"])
    radial_count = int(parameters["holderExteriorRadialSamples"])
    radii = radius + np.linspace(inner, outer, radial_count, dtype=np.float32)
    angles, profiles = core.sample_radial_profiles(
        image, center_x, center_y, radii, angle_samples
    )
    exterior = profiles[:, radii >= radius + float(parameters["holderExteriorSupportStartOffsetPx"])]
    median = float(np.median(exterior))
    mad = float(np.median(np.abs(exterior - median)))
    threshold = median + max(
        float(parameters["holderExteriorMinimumIntensityDelta"]),
        float(parameters["holderExteriorMadMultiplier"]) * 1.4826 * mad,
    )
    support = np.mean(exterior >= threshold, axis=1)
    minimum = float(parameters["holderExteriorMinimumRadialSupportFraction"])
    active = support >= minimum
    degrees_per_sample = 360.0 / angle_samples
    gap = int(math.floor(float(parameters["holderExteriorMaximumAngularGapDegrees"]) / degrees_per_sample))
    active = core.close_small_circular_gaps(active, gap)
    qualified = np.zeros(angle_samples, dtype=bool)
    for group in core.group_circular_true(active):
        width = float(group.size * degrees_per_sample)
        if not (
            float(parameters["holderExteriorMinimumAngularWidthDegrees"]) <= width
            <= float(parameters["holderExteriorMaximumAngularWidthDegrees"])
        ):
            continue
        if float(np.max(support[group])) < float(parameters["holderExteriorMinimumPeakRadialSupportFraction"]):
            continue
        qualified[group] = True
    dilation = int(math.ceil(float(parameters["holderExteriorLocalDilationDegrees"]) / degrees_per_sample))
    if dilation and qualified.any():
        kernel = np.ones(2 * dilation + 1, dtype=np.int32)
        tripled = np.tile(qualified.astype(np.int32), 3)
        votes = np.convolve(tripled, kernel, mode="same")
        qualified = votes[angle_samples : 2 * angle_samples] > 0
    return qualified, {
        "referenceMedianIntensity": median,
        "referenceMadIntensity": mad,
        "brightThresholdIntensity": threshold,
        "maximumRadialBrightSupportFraction": float(np.max(support)),
    }


def localize_channel(image, channel, parameters):
    core = R17.BASE_RADIAL
    preliminary = ORIGINAL_LOCALIZE(image, channel, parameters)
    if not preliminary.get("fit"):
        preliminary["holderExclusion"] = {"state": "NOT_AVAILABLE_WITHOUT_PRELIMINARY_FIT"}
        LAST_LOCALIZATION[channel] = preliminary
        return preliminary
    height, width = image.shape
    image_center_x, image_center_y = (width - 1) / 2.0, (height - 1) / 2.0
    minimum_dimension = float(min(width, height))
    rough_fit = preliminary["fit"]
    rough_holder, holder_metrics = derive_holder_mask(
        image, float(rough_fit["centerX"]), float(rough_fit["centerY"]),
        float(rough_fit["radius"]), parameters.coarse_angle_samples, R17._PARAMETERS,
    )
    coarse_radii = np.arange(
        minimum_dimension * parameters.coarse_radius_minimum_fraction,
        minimum_dimension * parameters.coarse_radius_maximum_fraction + parameters.coarse_radial_step_px,
        parameters.coarse_radial_step_px, dtype=np.float32,
    )
    coarse_angles, coarse_profiles = core.sample_radial_profiles(
        image, image_center_x, image_center_y, coarse_radii, parameters.coarse_angle_samples
    )
    coarse_boundary, _, coarse_supported, coarse_floor = core.choose_outer_dark_boundary(
        coarse_profiles, coarse_radii, float(parameters.coarse_radial_step_px), parameters
    )
    coarse_supported &= ~rough_holder
    if int(coarse_supported.sum()) < 64:
        result = dict(preliminary)
        result.update(qualified=False, state="HOLD_HOLDER_EXCLUDED_COARSE_SUPPORT_INSUFFICIENT")
        result["holderExclusion"] = {"state": "APPLIED", "spans": holder_spans(rough_holder)}
        LAST_LOCALIZATION[channel] = result
        return result
    coarse_points = np.column_stack((
        image_center_x + np.cos(coarse_angles[coarse_supported]) * coarse_boundary[coarse_supported],
        image_center_y + np.sin(coarse_angles[coarse_supported]) * coarse_boundary[coarse_supported],
    ))
    coarse_fit = core.robust_circle(coarse_points, parameters)
    center_x, center_y, radius = (
        float(coarse_fit["centerX"]), float(coarse_fit["centerY"]), float(coarse_fit["radius"])
    )
    final_angles = final_boundary = final_supported = final_fit = holder = None
    final_floor = math.nan
    raw_supported_count = 0
    for _ in range(2):
        refine_radii = np.arange(
            radius - parameters.refine_radial_half_width_px,
            radius + parameters.refine_radial_half_width_px + 1, 1.0, dtype=np.float32,
        )
        final_angles, profiles = core.sample_radial_profiles(
            image, center_x, center_y, refine_radii, parameters.refine_angle_samples
        )
        final_boundary, _, final_supported, final_floor = core.choose_outer_dark_boundary(
            profiles, refine_radii, 1.0, parameters
        )
        raw_supported_count = int(final_supported.sum())
        holder, holder_metrics = derive_holder_mask(
            image, center_x, center_y, radius, parameters.refine_angle_samples, R17._PARAMETERS
        )
        final_supported &= ~holder
        points = np.column_stack((
            center_x + np.cos(final_angles[final_supported]) * final_boundary[final_supported],
            center_y + np.sin(final_angles[final_supported]) * final_boundary[final_supported],
        ))
        final_fit = core.robust_circle(points, parameters)
        center_x, center_y, radius = (
            float(final_fit["centerX"]), float(final_fit["centerY"]), float(final_fit["radius"])
        )
    coverage = core.angular_coverage(final_angles[final_supported], final_fit["acceptedMask"])
    displacement = radius - final_boundary
    candidates, threshold, noise_sigma = core.extract_candidates(
        final_angles, displacement, final_supported, parameters
    )
    qualified = (
        float(final_fit["inlierFraction"]) >= parameters.minimum_fit_inlier_fraction
        and coverage >= parameters.minimum_angular_coverage_fraction
        and float(final_fit["rmsResidualPx"]) <= parameters.maximum_fit_rms_residual_px
    )
    result = {
        "channel": channel, "qualified": qualified,
        "state": "PASS_FULL_PERIMETER_CHANNEL_QUALIFIED" if qualified else "HOLD_FULL_PERIMETER_CHANNEL_NOT_QUALIFIED",
        "widthPx": width, "heightPx": height,
        "search": {
            "mode": "FULL_360_CHANNEL_LOCAL_HOLDER_EXCLUDED_OUTERMOST_DARK_BOUNDARY",
            "coarseRadiusMinimumPx": float(coarse_radii[0]), "coarseRadiusMaximumPx": float(coarse_radii[-1]),
            "coarseAngleSamples": parameters.coarse_angle_samples,
            "refineAngleSamples": parameters.refine_angle_samples,
            "coarseSupportedSamples": int(coarse_supported.sum()),
            "refineRawSupportedSamples": raw_supported_count,
            "refineSupportedSamples": int(final_supported.sum()),
            "coarseAdaptiveContrastFloor": coarse_floor, "refineAdaptiveContrastFloor": final_floor,
            "knownNotchLocationConsumed": False, "notchAnglePriorConsumed": False,
            "fixedAngularSearchWindowConsumed": False,
        },
        "coarseFit": {key: coarse_fit[key] for key in (
            "centerX", "centerY", "radius", "acceptedCount", "inputCount",
            "inlierFraction", "rmsResidualPx", "p90AbsoluteResidualPx")},
        "fit": {
            "centerX": center_x, "centerY": center_y, "radius": radius,
            "acceptedCount": final_fit["acceptedCount"], "inputCount": final_fit["inputCount"],
            "inlierFraction": final_fit["inlierFraction"], "angularCoverageFraction": coverage,
            "rmsResidualPx": final_fit["rmsResidualPx"],
            "p90AbsoluteResidualPx": final_fit["p90AbsoluteResidualPx"],
        },
        "candidateDepthThresholdPx": threshold, "baselineNoiseSigmaPx": noise_sigma,
        "candidates": candidates,
        "holderExclusion": {
            "state": "APPLIED_BEFORE_FINAL_PERIMETER_FIT_AND_CANDIDATE_FORMATION",
            "maskSampleCount": int(holder.sum()), "spans": holder_spans(holder),
            "rawCandidateCountBeforeExclusion": len(preliminary.get("candidates", [])),
            "rawCandidatesBeforeExclusion": preliminary.get("candidates", []),
            "retainedCandidateCountAfterExclusion": len(candidates),
            **holder_metrics,
        },
    }
    LAST_LOCALIZATION[channel] = result
    return result


def render_channel(path, channel, maximum_dimension, result):
    native = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
    if native is None:
        raise RuntimeError(f"{channel} diagnostic render decode failed: {path}")
    scale = min(1.0, maximum_dimension / max(native.shape))
    gray = cv2.resize(native, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    overlay = cv2.cvtColor(cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8)).apply(gray), cv2.COLOR_GRAY2BGR)
    fit = result["fit"]
    center = (round(float(fit["centerX"]) * scale), round(float(fit["centerY"]) * scale))
    radius = round(float(fit["radius"]) * scale)
    cv2.circle(overlay, center, radius, (255, 255, 0), 2, cv2.LINE_AA)
    mask = np.zeros(gray.shape, dtype=np.uint8)
    inward = float(R17._PARAMETERS["holderMaskInwardPx"])
    outward = float(R17._PARAMETERS["holderMaskOutwardPx"])
    middle = round((float(fit["radius"]) + (outward - inward) / 2.0) * scale)
    thickness = max(1, round((inward + outward) * scale))
    for span in result["holderExclusion"]["spans"]:
        start = float(span["startAngleDegrees"])
        end = start + float(span["widthDegrees"])
        cv2.ellipse(mask, center, (middle, middle), 0.0, start, end, 255, thickness, cv2.LINE_8)
        cv2.ellipse(overlay, center, (radius, radius), 0.0, start, end, (255, 0, 255), 5, cv2.LINE_AA)
    for index, row in enumerate(result["candidates"], start=1):
        angle = math.radians(float(row["centerAngleDegrees"]))
        point = (round(center[0] + radius * math.cos(angle)), round(center[1] + radius * math.sin(angle)))
        cv2.circle(overlay, point, 8, (0, 0, 255), 2, cv2.LINE_AA)
        cv2.putText(overlay, f"{channel}{index}", (point[0] + 10, point[1] - 6),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 0, 255), 2, cv2.LINE_AA)
    del native, gray
    gc.collect()
    return overlay, mask


def analyze_radial(path, channel, maximum_dimension, radial_engine, radial_parameters):
    global ORIGINAL_LOCALIZE
    R17._PARAMETERS = radial_parameters
    ORIGINAL_LOCALIZE = radial_engine.localize_channel
    R17.BASE_RADIAL = radial_engine
    radial_engine.localize_channel = localize_channel
    try:
        result, _ = R17.BASE_ANALYZE_RADIAL(
            path, channel, maximum_dimension, radial_engine, radial_parameters
        )
    finally:
        radial_engine.localize_channel = ORIGINAL_LOCALIZE
    localized = LAST_LOCALIZATION[channel]
    scale = float(result["analysisScale"])
    native = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
    if native is None:
        raise RuntimeError(f"{channel} native decode failed: {path}")
    candidates = []
    try:
        for source in localized.get("candidates", []):
            row = dict(source)
            row["maximumDepthNativePx"] = float(row["maximumDepthPx"])
            row["maximumDepthAnalysisPx"] = float(row["maximumDepthPx"]) * scale
            row["manufacturedMorphologyPassed"] = BASE.manufactured_candidate(row)
            row["candidateSource"] = "NATIVE_CHANNEL_LOCAL_HOLDER_EXCLUDED_RADIAL_PROFILE"
            row["exteriorContext"] = R17.exterior_context(
                native, localized["fit"], float(row["centerAngleDegrees"]), radial_parameters
            )
            candidates.append(row)
    finally:
        del native
        gc.collect()
    result["candidates"] = candidates
    result["candidateCount"] = len(candidates)
    result["profileThresholdPx"] = float(localized.get("candidateDepthThresholdPx", 0.0)) * scale
    result["profileMaximumDepthPx"] = max(
        [float(row["maximumDepthAnalysisPx"]) for row in candidates], default=0.0
    )
    result["radialQualification"] = {
        "qualified": bool(localized.get("qualified")), "state": localized["state"],
        "fit": localized.get("fit", {}), "search": localized.get("search", {}),
    }
    result["circle"] = {
        "centerX": float(localized["fit"]["centerX"]) * scale,
        "centerY": float(localized["fit"]["centerY"]) * scale,
        "radius": float(localized["fit"]["radius"]) * scale,
    }
    result["patternSuppression"] = "FULL_360_CHANNEL_LOCAL_HOLDER_EXCLUDED_BOUNDARY"
    result["holderExclusion"] = localized["holderExclusion"]
    overlay, mask = render_channel(path, channel, maximum_dimension, localized)
    output = R17.invocation_output()
    mask_path = output / f"{channel}_holder_exclusion.png"
    if not cv2.imwrite(str(mask_path), mask):
        raise RuntimeError(f"{channel} holder exclusion mask write failed: {mask_path}")
    result["holderExclusion"]["maskPath"] = str(mask_path)
    result["holderExclusion"]["maskSha256"] = BASE.sha256_file(mask_path)
    return result, overlay


def appearance_confirmation(row: dict) -> bool:
    p = R17._PARAMETERS
    context = row["exteriorContext"]
    return (
        float(p["appearanceConfirmationMinimumWidthDegrees"]) <= float(row["widthDegrees"])
        <= float(p["appearanceConfirmationMaximumWidthDegrees"])
        and float(row["maximumDepthNativePx"]) >= float(p["appearanceConfirmationMinimumDepthPx"])
        and float(row["slopeConsistencyFraction"]) >= float(p["appearanceConfirmationMinimumSlopeConsistency"])
        and float(row["tipCenterOffsetFraction"]) <= float(p["appearanceConfirmationMaximumTipOffsetFraction"])
        and float(context["brightPixelFraction"]) <= float(p["appearanceConfirmationMaximumExteriorBrightFraction"])
        and float(context["maximumAngularBrightSupportFraction"])
        <= float(p["appearanceConfirmationMaximumExteriorAngularSupportFraction"])
    )


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    p = R17._PARAMETERS
    standard_tolerance = float(p["confirmationAngleToleranceDegrees"])
    appearance_tolerance = float(p["appearanceConfirmationAngleToleranceDegrees"])
    proposed = []
    for bf_row in bf["candidates"]:
        for df_row in df["candidates"]:
            difference = BASE.circular_distance(
                float(bf_row["centerAngleDegrees"]), float(df_row["centerAngleDegrees"])
            )
            bf_strict = bool(bf_row["manufacturedMorphologyPassed"])
            df_strict = bool(df_row["manufacturedMorphologyPassed"])
            mode = None
            if difference <= standard_tolerance and bf_strict and df_strict:
                mode = "STRICT_BOTH_CHANNELS"
            elif difference <= standard_tolerance and bf_strict and R17.soft_morphology(df_row):
                mode = "STRICT_BF_CONFIRMED_BY_DF"
            elif difference <= standard_tolerance and df_strict and R17.soft_morphology(bf_row):
                mode = "STRICT_DF_CONFIRMED_BY_BF"
            elif difference <= appearance_tolerance and bf_strict and appearance_confirmation(df_row):
                mode = "STRICT_BF_CONFIRMED_BY_CHANNEL_LOCAL_APPEARANCE_DF"
            elif difference <= appearance_tolerance and df_strict and appearance_confirmation(bf_row):
                mode = "STRICT_DF_CONFIRMED_BY_CHANNEL_LOCAL_APPEARANCE_BF"
            if mode:
                proposed.append(R17.pair_row(bf_row, df_row, difference, mode))
    proposed.sort(key=lambda row: (-row["score"], row["meanAngleDegrees"]))
    clustered = []
    cluster_width = float(p["confirmationClusterWidthDegrees"])
    for row in proposed:
        if all(BASE.circular_distance(row["meanAngleDegrees"], prior["meanAngleDegrees"]) > cluster_width
               for prior in clustered):
            clustered.append(row)
    return clustered


def main() -> int:
    R17.analyze_radial = analyze_radial
    R20.R18.pair_candidates = pair_candidates
    return R20.main()


if __name__ == "__main__":
    raise SystemExit(main())
