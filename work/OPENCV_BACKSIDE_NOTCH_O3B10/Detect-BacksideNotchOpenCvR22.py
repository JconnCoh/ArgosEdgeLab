#!/usr/bin/env python3
"""R22 strict-DF anchored, BF channel-local appearance recovery over frozen R21."""

from __future__ import annotations

import gc
import importlib.util
import math
from pathlib import Path
import sys

import cv2
import numpy as np


R21_SHA256 = "29B41CCE63BC91F99C4FFF24F2DFEECC9BDCDA8ED5314A7671EB40EEBA582A8E"


def load_r21():
    path = Path(__file__).with_name("OCV03_BacksideNotchDevelopment_O3B10R21.py")
    if not path.is_file():
        path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR21.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r21_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R21 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.BASE.sha256_file(path) != R21_SHA256:
        raise RuntimeError(f"Frozen R21 detector hash changed: {path}")
    return module


R21 = load_r21()
ORIGINAL_LOCALIZE = R21.localize_channel
ORIGINAL_ANALYZE = R21.analyze_radial
ORIGINAL_PAIR = R21.pair_candidates
LAST_PROFILE: dict[str, dict] = {}
LAST_PATH: dict[str, Path] = {}


def circular_distance_array(values: np.ndarray, angle: float) -> np.ndarray:
    return np.abs((values - angle + 180.0) % 360.0 - 180.0)


def capture_localize(image, channel, parameters):
    core = R21.R17.BASE_RADIAL
    original_extract = core.extract_candidates

    def capture_extract(angles, displacement, supported, extraction_parameters):
        LAST_PROFILE[channel] = {
            "angleDegrees": np.rad2deg(np.asarray(angles, dtype=np.float64)) % 360.0,
            "displacement": np.asarray(displacement, dtype=np.float64).copy(),
            "supported": np.asarray(supported, dtype=bool).copy(),
        }
        return original_extract(angles, displacement, supported, extraction_parameters)

    core.extract_candidates = capture_extract
    try:
        return ORIGINAL_LOCALIZE(image, channel, parameters)
    finally:
        core.extract_candidates = original_extract


def capture_analyze(path, channel, maximum_dimension, radial_engine, radial_parameters):
    LAST_PATH[channel] = Path(path)
    return ORIGINAL_ANALYZE(path, channel, maximum_dimension, radial_engine, radial_parameters)


def angle_in_holder(angle: float, spans: list[dict], dilation: float) -> bool:
    for span in spans:
        start = float(span["startAngleDegrees"])
        width = float(span["widthDegrees"])
        center = (start + width / 2.0) % 360.0
        if float(R21.BASE.circular_distance(angle, center)) <= width / 2.0 + dilation:
            return True
    return False


def contiguous_run(mask: np.ndarray, center: int) -> np.ndarray:
    left = center
    right = center
    while left > 0 and bool(mask[left - 1]):
        left -= 1
    while right + 1 < mask.size and bool(mask[right + 1]):
        right += 1
    return np.arange(left, right + 1, dtype=np.int32)


def bf_appearance_probe(bf: dict, anchor_angle: float, native: np.ndarray) -> tuple[dict, dict | None]:
    p = R21.R17._PARAMETERS
    profile = LAST_PROFILE.get("BF")
    if profile is None:
        return {"state": "HOLD_BF_APPEARANCE_PROFILE_ABSENT", "anchorAngleDegrees": anchor_angle}, None
    angles = profile["angleDegrees"]
    displacement = profile["displacement"]
    supported = profile["supported"]
    distance = circular_distance_array(angles, anchor_angle)
    search_half = float(p["bfAppearanceProbeSearchHalfWidthDegrees"])
    baseline_inner = float(p["bfAppearanceProbeBaselineInnerDegrees"])
    baseline_outer = float(p["bfAppearanceProbeBaselineOuterDegrees"])
    search = (distance <= search_half) & supported
    baseline_mask = (distance >= baseline_inner) & (distance <= baseline_outer) & supported
    probe = {
        "state": "HOLD_BF_APPEARANCE_NOT_QUALIFIED",
        "anchorAngleDegrees": anchor_angle,
        "searchSupportedFraction": float(np.mean(supported[distance <= search_half])),
        "holderMasked": angle_in_holder(
            anchor_angle,
            list(bf["holderExclusion"]["spans"]),
            float(p["bfAppearanceProbeHolderClearanceDegrees"]),
        ),
    }
    if int(search.sum()) < 3 or int(baseline_mask.sum()) < 6:
        probe["state"] = "HOLD_BF_APPEARANCE_SUPPORT_INSUFFICIENT"
        return probe, None
    baseline = float(np.median(displacement[baseline_mask]))
    signal = displacement - baseline
    search_indices = np.flatnonzero(search)
    peak_index = int(search_indices[int(np.argmax(signal[search_indices]))])
    peak = float(signal[peak_index])
    sample_degrees = float(360.0 / angles.size)
    threshold = max(
        float(p["bfAppearanceProbeMinimumRunDepthPx"]),
        peak * float(p["bfAppearanceProbeRunDepthFraction"]),
    )
    ordered = np.flatnonzero(distance <= search_half)
    local_peak = int(np.flatnonzero(ordered == peak_index)[0])
    active = supported[ordered] & (signal[ordered] >= threshold)
    run_local = contiguous_run(active, local_peak) if bool(active[local_peak]) else np.asarray([], dtype=np.int32)
    if run_local.size:
        run = ordered[run_local]
        symmetry, tip_offset, slope = R21.BASE.candidate_shape(signal[run])
        weights = np.maximum(signal[run], 0.0)
        center = float(np.average(angles[run], weights=weights)) if float(weights.sum()) > 0.0 else anchor_angle
        width = float(run.size * sample_degrees)
    else:
        run = np.asarray([], dtype=np.int32)
        symmetry = tip_offset = slope = 0.0
        center = anchor_angle
        width = 0.0
    fit = R21.LAST_LOCALIZATION["BF"]["fit"]
    context = R21.R17.exterior_context(native, fit, center, p)
    probe.update({
        "baselineDisplacementPx": baseline,
        "peakProminencePx": peak,
        "runThresholdPx": threshold,
        "centerAngleDegrees": center,
        "angleDifferenceDegrees": float(R21.BASE.circular_distance(center, anchor_angle)),
        "widthDegrees": width,
        "symmetryScore": symmetry,
        "tipCenterOffsetFraction": tip_offset,
        "slopeConsistencyFraction": slope,
        "exteriorContext": context,
    })
    qualified = (
        not probe["holderMasked"]
        and probe["searchSupportedFraction"] >= float(p["bfAppearanceProbeMinimumSupportedFraction"])
        and peak >= float(p["bfAppearanceProbeMinimumProminencePx"])
        and float(p["bfAppearanceProbeMinimumWidthDegrees"]) <= width <= float(p["bfAppearanceProbeMaximumWidthDegrees"])
        and symmetry >= float(p["bfAppearanceProbeMinimumSymmetry"])
        and tip_offset <= float(p["bfAppearanceProbeMaximumTipOffsetFraction"])
        and slope >= float(p["bfAppearanceProbeMinimumSlopeConsistency"])
        and float(context["brightPixelFraction"]) <= float(p["bfAppearanceProbeMaximumExteriorBrightFraction"])
        and float(context["maximumAngularBrightSupportFraction"])
        <= float(p["bfAppearanceProbeMaximumExteriorAngularSupportFraction"])
        and probe["angleDifferenceDegrees"] <= float(p["bfAppearanceProbeMaximumCenterOffsetDegrees"])
    )
    if not qualified:
        return probe, None
    probe["state"] = "PASS_BF_CHANNEL_LOCAL_APPEARANCE_CONFIRMED"
    scale = float(bf["analysisScale"])
    candidate = {
        "startAngleDegrees": float(angles[run[0]]) if run.size else center,
        "endAngleDegrees": float(angles[run[-1]]) if run.size else center,
        "centerAngleDegrees": center,
        "widthDegrees": width,
        "maximumDepthPx": peak,
        "maximumDepthNativePx": peak,
        "maximumDepthAnalysisPx": peak * scale,
        "symmetryScore": symmetry,
        "tipCenterOffsetFraction": tip_offset,
        "slopeConsistencyFraction": slope,
        "manufacturedMorphologyPassed": False,
        "candidateSource": "STRICT_DF_ANCHORED_BF_CHANNEL_LOCAL_IMAGE_APPEARANCE",
        "exteriorContext": context,
    }
    return probe, candidate


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    existing = ORIGINAL_PAIR(bf, df)
    if existing:
        bf["channelLocalAppearanceProbes"] = []
        return existing
    native = cv2.imread(str(LAST_PATH["BF"]), cv2.IMREAD_GRAYSCALE)
    if native is None:
        raise RuntimeError(f"BF appearance probe decode failed: {LAST_PATH['BF']}")
    probes = []
    proposed = []
    try:
        for df_row in df["candidates"]:
            if not bool(df_row["manufacturedMorphologyPassed"]):
                continue
            probe, bf_row = bf_appearance_probe(bf, float(df_row["centerAngleDegrees"]), native)
            probes.append(probe)
            if bf_row is not None:
                proposed.append(R21.R17.pair_row(
                    bf_row,
                    df_row,
                    float(R21.BASE.circular_distance(bf_row["centerAngleDegrees"], df_row["centerAngleDegrees"])),
                    "STRICT_DF_CONFIRMED_BY_BF_CHANNEL_LOCAL_IMAGE_APPEARANCE",
                ))
    finally:
        del native
        gc.collect()
    bf["channelLocalAppearanceProbes"] = probes
    proposed.sort(key=lambda row: (-row["score"], row["meanAngleDegrees"]))
    clustered = []
    cluster_width = float(R21.R17._PARAMETERS["confirmationClusterWidthDegrees"])
    for row in proposed:
        if all(R21.BASE.circular_distance(row["meanAngleDegrees"], prior["meanAngleDegrees"]) > cluster_width for prior in clustered):
            clustered.append(row)
    return clustered


def circular_mean_degrees(angles: np.ndarray, weights: np.ndarray) -> float:
    radians = np.deg2rad(angles)
    x = float(np.sum(np.cos(radians) * weights))
    y = float(np.sum(np.sin(radians) * weights))
    return float(np.rad2deg(math.atan2(y, x)) % 360.0)


def shallow_candidates(channel: str, result: dict, native: np.ndarray) -> tuple[list[dict], dict]:
    p = R21.R17._PARAMETERS
    core = R21.R17.BASE_RADIAL
    profile = LAST_PROFILE[channel]
    angles = profile["angleDegrees"]
    displacement = profile["displacement"]
    supported = profile["supported"]
    smoothed = core.circular_median(displacement.astype(np.float64), 5)
    supported_values = smoothed[supported]
    baseline_ceiling = float(np.percentile(supported_values, 80.0))
    baseline_values = supported_values[supported_values <= baseline_ceiling]
    median = float(np.median(baseline_values))
    mad = float(np.median(np.abs(baseline_values - median)))
    noise_sigma = 1.4826 * mad
    threshold = max(
        float(p["pairedShallowMinimumProfileDepthPx"]),
        median + float(p["pairedShallowNoiseMultiplier"]) * noise_sigma,
    )
    active = supported & (smoothed >= threshold)
    degrees_per_sample = float(360.0 / angles.size)
    gap = int(math.floor(float(p["pairedShallowGapAllowanceDegrees"]) / degrees_per_sample))
    active = core.close_small_circular_gaps(active, gap)
    fit = R21.LAST_LOCALIZATION[channel]["fit"]
    candidates = []
    rejected = []
    for indices in core.group_circular_true(active):
        width = float(indices.size * degrees_per_sample)
        depths = smoothed[indices]
        symmetry, tip_offset, slope = R21.BASE.candidate_shape(depths)
        weights = np.maximum(depths - median, 0.001)
        center = circular_mean_degrees(angles[indices], weights)
        context = R21.R17.exterior_context(native, fit, center, p)
        row = {
            "startAngleDegrees": float(angles[int(indices[0])]),
            "endAngleDegrees": float(angles[int(indices[-1])]),
            "centerAngleDegrees": center,
            "widthDegrees": width,
            "maximumDepthPx": float(np.max(depths)),
            "maximumDepthNativePx": float(np.max(depths)),
            "maximumDepthAnalysisPx": float(np.max(depths)) * float(result["analysisScale"]),
            "medianDepthPx": float(np.median(depths)),
            "sampleCount": int(indices.size),
            "symmetryScore": symmetry,
            "tipCenterOffsetFraction": tip_offset,
            "slopeConsistencyFraction": slope,
            "manufacturedMorphologyPassed": False,
            "candidateSource": "PAIRED_SHALLOW_CHANNEL_LOCAL_HOLDER_EXCLUDED_PROFILE",
            "exteriorContext": context,
            "holderMasked": angle_in_holder(
                center,
                list(result["holderExclusion"]["spans"]),
                float(p["pairedShallowHolderClearanceDegrees"]),
            ),
        }
        qualified = (
            float(p["pairedShallowMinimumWidthDegrees"]) <= width <= float(p["pairedShallowMaximumWidthDegrees"])
            and row["maximumDepthNativePx"] >= float(p["pairedShallowMinimumCandidateDepthPx"])
            and slope >= float(p["pairedShallowMinimumSlopeConsistency"])
            and not row["holderMasked"]
            and float(context["brightPixelFraction"]) <= float(p["pairedShallowMaximumExteriorBrightFraction"])
            and float(context["maximumAngularBrightSupportFraction"])
            <= float(p["pairedShallowMaximumExteriorAngularSupportFraction"])
        )
        (candidates if qualified else rejected).append(row)
    return candidates, {
        "channel": channel,
        "baselineMedianPx": median,
        "baselineNoiseSigmaPx": noise_sigma,
        "thresholdPx": threshold,
        "qualifiedCandidateCount": len(candidates),
        "rejectedCandidateCount": len(rejected),
        "qualifiedCandidates": candidates,
        "rejectedCandidates": rejected,
    }


def pair_candidates_shallow(bf: dict, df: dict) -> list[dict]:
    existing = ORIGINAL_PAIR(bf, df)
    if existing:
        bf["pairedShallowAppearanceDiagnostics"] = {"state": "NOT_USED_EXISTING_PAIR", "proposedPairCount": 0}
        return existing
    bf_native = cv2.imread(str(LAST_PATH["BF"]), cv2.IMREAD_GRAYSCALE)
    df_native = cv2.imread(str(LAST_PATH["DF"]), cv2.IMREAD_GRAYSCALE)
    if bf_native is None or df_native is None:
        raise RuntimeError("Paired shallow appearance decode failed.")
    try:
        bf_rows, bf_diagnostic = shallow_candidates("BF", bf, bf_native)
        df_rows, df_diagnostic = shallow_candidates("DF", df, df_native)
    finally:
        del bf_native, df_native
        gc.collect()
    p = R21.R17._PARAMETERS
    proposed = []
    pair_diagnostics = []
    for bf_row in bf_rows:
        for df_row in df_rows:
            difference = float(R21.BASE.circular_distance(
                float(bf_row["centerAngleDegrees"]), float(df_row["centerAngleDegrees"])
            ))
            if difference > float(p["pairedShallowMaximumAngleDifferenceDegrees"]):
                continue
            bf_strong = (
                float(bf_row["symmetryScore"]) >= float(p["pairedShallowStrongMinimumSymmetry"])
                and float(bf_row["tipCenterOffsetFraction"]) <= float(p["pairedShallowStrongMaximumTipOffsetFraction"])
                and float(bf_row["slopeConsistencyFraction"]) >= float(p["pairedShallowStrongMinimumSlopeConsistency"])
            )
            df_strong = (
                float(df_row["symmetryScore"]) >= float(p["pairedShallowStrongMinimumSymmetry"])
                and float(df_row["tipCenterOffsetFraction"]) <= float(p["pairedShallowStrongMaximumTipOffsetFraction"])
                and float(df_row["slopeConsistencyFraction"]) >= float(p["pairedShallowStrongMinimumSlopeConsistency"])
            )
            pair_diagnostics.append({
                "bfAngleDegrees": bf_row["centerAngleDegrees"],
                "dfAngleDegrees": df_row["centerAngleDegrees"],
                "angleDifferenceDegrees": difference,
                "bfStrong": bf_strong,
                "dfStrong": df_strong,
            })
            if not (bf_strong or df_strong):
                continue
            proposed.append(R21.R17.pair_row(
                bf_row,
                df_row,
                difference,
                "PAIRED_SHALLOW_CHANNEL_LOCAL_IMAGE_APPEARANCE",
            ))
    proposed.sort(key=lambda row: (-row["score"], row["meanAngleDegrees"]))
    clustered = []
    cluster_width = float(p["confirmationClusterWidthDegrees"])
    for row in proposed:
        if all(R21.BASE.circular_distance(row["meanAngleDegrees"], prior["meanAngleDegrees"]) > cluster_width for prior in clustered):
            clustered.append(row)
    bf["pairedShallowAppearanceDiagnostics"] = {
        "state": "PASS_PAIRED_SHALLOW_APPEARANCE_PROPOSED" if clustered else "HOLD_NO_PAIRED_SHALLOW_APPEARANCE",
        "bf": bf_diagnostic,
        "df": df_diagnostic,
        "pairComparisons": pair_diagnostics,
        "proposedPairCount": len(clustered),
    }
    return clustered


def main() -> int:
    R21.localize_channel = capture_localize
    R21.analyze_radial = capture_analyze
    R21.pair_candidates = pair_candidates_shallow
    return R21.main()


if __name__ == "__main__":
    raise SystemExit(main())
