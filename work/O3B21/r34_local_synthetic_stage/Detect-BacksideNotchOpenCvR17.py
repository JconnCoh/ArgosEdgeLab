#!/usr/bin/env python3
"""R17 review-only evidence revision over the frozen R15 backside detector."""

from __future__ import annotations

import importlib.util
import json
import math
from pathlib import Path
import sys

import cv2
import numpy as np


BASE_NAME = "OCV03_BacksideNotchDevelopment_O3B10R15.py"
LOCAL_BASE_NAME = "Detect-BacksideNotchOpenCvR15.py"
BASE_SHA256 = "F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C"
_PARAMETERS: dict = {}


def load_base():
    base_path = Path(__file__).with_name(BASE_NAME)
    if not base_path.is_file():
        base_path = Path(__file__).with_name(LOCAL_BASE_NAME)
    specification = importlib.util.spec_from_file_location("argos_backside_r15_frozen", base_path)
    if specification is None or specification.loader is None:
        raise RuntimeError(f"Frozen R15 detector could not be loaded: {base_path}")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    if module.sha256_file(base_path) != BASE_SHA256:
        raise RuntimeError(f"Frozen R15 detector hash changed: {base_path}")
    return module


BASE = load_base()
BASE_ANALYZE_RADIAL = BASE.analyze_radial


def exterior_context(gray: np.ndarray, fit: dict, angle_degrees: float, parameters: dict) -> dict:
    """Measure visible structure outside the fitted wafer at one image-local angle."""
    inner = float(parameters["fixtureExteriorInnerOffsetPx"])
    outer = float(parameters["fixtureExteriorOuterOffsetPx"])
    half_width = float(parameters["fixtureExteriorHalfWidthDegrees"])
    radial_count = int(parameters["fixtureExteriorRadialSamples"])
    angular_count = int(parameters["fixtureExteriorAngularSamples"])
    reference_count = int(parameters["fixtureExteriorReferenceAngleSamples"])
    radii = float(fit["radius"]) + np.linspace(inner, outer, radial_count, dtype=np.float32)

    def sample(angles: np.ndarray) -> np.ndarray:
        radians = np.deg2rad(angles.astype(np.float32))
        map_x = float(fit["centerX"]) + np.cos(radians)[:, None] * radii[None, :]
        map_y = float(fit["centerY"]) + np.sin(radians)[:, None] * radii[None, :]
        return cv2.remap(
            gray, map_x.astype(np.float32), map_y.astype(np.float32),
            cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0,
        ).astype(np.float32)

    reference = sample(np.linspace(0.0, 360.0, reference_count, endpoint=False, dtype=np.float32))
    reference_median = float(np.median(reference))
    reference_mad = float(np.median(np.abs(reference - reference_median)))
    bright_threshold = reference_median + max(
        float(parameters["fixtureExteriorMinimumIntensityDelta"]),
        float(parameters["fixtureExteriorMadMultiplier"]) * 1.4826 * reference_mad,
    )
    wedge = sample(np.linspace(
        angle_degrees - half_width, angle_degrees + half_width, angular_count, dtype=np.float32
    ))
    bright = wedge >= bright_threshold
    radial_support = np.mean(bright, axis=1)
    return {
        "referenceMedianIntensity": reference_median,
        "referenceMadIntensity": reference_mad,
        "brightThresholdIntensity": bright_threshold,
        "wedgeMedianIntensity": float(np.median(wedge)),
        "wedgeP90Intensity": float(np.percentile(wedge, 90.0)),
        "brightPixelFraction": float(np.mean(bright)),
        "maximumAngularBrightSupportFraction": float(np.max(radial_support)),
    }


def analyze_radial(path, channel, maximum_dimension, radial_engine, radial_parameters):
    global _PARAMETERS
    _PARAMETERS = radial_parameters
    result, overlay = BASE_ANALYZE_RADIAL(
        path, channel, maximum_dimension, radial_engine, radial_parameters
    )
    native = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
    if native is None:
        raise RuntimeError(f"{channel} exterior-context decode failed: {path}")
    fit = result["radialQualification"]["fit"]
    for row in result["candidates"]:
        row["exteriorContext"] = exterior_context(
            native, fit, float(row["centerAngleDegrees"]), radial_parameters
        )
    return result, overlay


def soft_morphology(row: dict) -> bool:
    return (
        float(_PARAMETERS["confirmationMinimumWidthDegrees"])
        <= float(row["widthDegrees"])
        <= float(_PARAMETERS["confirmationMaximumWidthDegrees"])
        and float(row["symmetryScore"]) >= float(_PARAMETERS["confirmationMinimumSymmetry"])
        and float(row["tipCenterOffsetFraction"])
        <= float(_PARAMETERS["confirmationMaximumTipOffsetFraction"])
        and float(row["slopeConsistencyFraction"])
        >= float(_PARAMETERS["confirmationMinimumSlopeConsistency"])
    )


def fixture_contact(row: dict) -> bool:
    context = row["exteriorContext"]
    return (
        float(context["brightPixelFraction"])
        >= float(_PARAMETERS["fixtureExteriorMinimumBrightFraction"])
        and float(context["maximumAngularBrightSupportFraction"])
        >= float(_PARAMETERS["fixtureExteriorMinimumAngularSupportFraction"])
    )


def pair_row(bf_row: dict, df_row: dict, difference: float, mode: str) -> dict:
    mean_angle = (
        float(bf_row["centerAngleDegrees"])
        + ((float(df_row["centerAngleDegrees"]) - float(bf_row["centerAngleDegrees"]) + 540.0) % 360.0 - 180.0) / 2.0
    ) % 360.0
    return {
        "bfAngleDegrees": bf_row["centerAngleDegrees"],
        "dfAngleDegrees": df_row["centerAngleDegrees"],
        "angleDifferenceDegrees": difference,
        "meanAngleDegrees": mean_angle,
        "bfWidthDegrees": bf_row["widthDegrees"],
        "dfWidthDegrees": df_row["widthDegrees"],
        "bfDepthNativePx": bf_row["maximumDepthNativePx"],
        "dfDepthNativePx": df_row["maximumDepthPx"],
        "bfTipDepthAnalysisPx": bf_row["maximumDepthPx"],
        "dfTipDepthAnalysisPx": df_row["maximumDepthAnalysisPx"],
        "confirmationMode": mode,
        "bfExteriorContext": bf_row["exteriorContext"],
        "dfExteriorContext": df_row["exteriorContext"],
        "bothChannelsExteriorFixtureContact": fixture_contact(bf_row) and fixture_contact(df_row),
        "score": min(float(bf_row["maximumDepthNativePx"]), float(df_row["maximumDepthPx"])) / (1.0 + difference),
    }


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    tolerance = float(_PARAMETERS["confirmationAngleToleranceDegrees"])
    proposed: list[dict] = []
    for bf_row in bf["candidates"]:
        for df_row in df["candidates"]:
            difference = BASE.circular_distance(
                float(bf_row["centerAngleDegrees"]), float(df_row["centerAngleDegrees"])
            )
            if difference > tolerance:
                continue
            bf_strict = bool(bf_row["manufacturedMorphologyPassed"])
            df_strict = bool(df_row["manufacturedMorphologyPassed"])
            if bf_strict and df_strict:
                mode = "STRICT_BOTH_CHANNELS"
            elif bf_strict and soft_morphology(df_row):
                mode = "STRICT_BF_CONFIRMED_BY_DF"
            elif df_strict and soft_morphology(bf_row):
                mode = "STRICT_DF_CONFIRMED_BY_BF"
            else:
                continue
            proposed.append(pair_row(bf_row, df_row, difference, mode))

    proposed.sort(key=lambda row: (-row["score"], row["meanAngleDegrees"]))
    clustered: list[dict] = []
    cluster_width = float(_PARAMETERS["confirmationClusterWidthDegrees"])
    for row in proposed:
        if all(BASE.circular_distance(row["meanAngleDegrees"], prior["meanAngleDegrees"]) > cluster_width for prior in clustered):
            clustered.append(row)

    if len(clustered) > 1:
        non_fixture = [row for row in clustered if not row["bothChannelsExteriorFixtureContact"]]
        if non_fixture:
            for row in clustered:
                row["exteriorFixtureSuppressedBecauseAlternativePhysicalCandidateExists"] = row not in non_fixture
            clustered = non_fixture
    return sorted(clustered, key=lambda row: (-row["score"], row["meanAngleDegrees"]))


def invocation_output() -> Path:
    if "--job" not in sys.argv:
        raise RuntimeError("R17 requires the file-backed --job invocation.")
    job_path = Path(sys.argv[sys.argv.index("--job") + 1])
    return Path(json.loads(job_path.read_text(encoding="utf-8"))["output"])


def compensate_bounded_trace_hold(output: Path) -> None:
    result_path = output / "RESULT.json"
    result = json.loads(result_path.read_text(encoding="utf-8"))
    if result.get("state") != "HOLD_BACKSIDE_NOTCH_ANALYSIS_FAILED":
        return
    channels = result.get("completedChannels", {})
    pairs = result.get("pairedCandidates", [])
    if set(channels) != {"BF", "DF"} or len(pairs) != 1:
        return
    bf, df = channels["BF"], channels["DF"]
    for channel in (bf, df):
        fit = channel["radialQualification"]["fit"]
        if (
            float(fit["inlierFraction"]) < float(_PARAMETERS["compensatedMinimumFitInlierFraction"])
            or float(fit["angularCoverageFraction"]) < float(_PARAMETERS["compensatedMinimumAngularCoverageFraction"])
            or float(fit["rmsResidualPx"]) > float(_PARAMETERS["compensatedMaximumFitRmsResidualPx"])
        ):
            return
    bf_fit, df_fit = bf["radialQualification"]["fit"], df["radialQualification"]["fit"]
    center_difference = math.hypot(
        float(bf_fit["centerX"]) - float(df_fit["centerX"]),
        float(bf_fit["centerY"]) - float(df_fit["centerY"]),
    )
    radius_difference = abs(float(bf_fit["radius"]) - float(df_fit["radius"]))
    if (
        center_difference > float(_PARAMETERS["maximumChannelCenterDifferencePx"])
        or radius_difference > float(_PARAMETERS["maximumChannelRadiusDifferencePx"])
    ):
        return
    result = {
        "state": "COMPLETE_BACKSIDE_NOTCH_DEVELOPMENT_DIAGNOSTIC",
        "opencvVersion": cv2.__version__,
        "fullPerimeterInference": True,
        "knownNotchLocationConsumed": False,
        "patternSuppression": "FULL_360_OUTERMOST_DARK_EXTERIOR_BOUNDARY_BOTH_CHANNELS",
        "bf": bf, "df": df,
        "bfEligibleCandidateCount": sum(bool(row["manufacturedMorphologyPassed"]) for row in bf["candidates"]),
        "dfEligibleCandidateCount": sum(bool(row["manufacturedMorphologyPassed"]) for row in df["candidates"]),
        "pairedCandidateCount": 1,
        "pairedCandidates": pairs,
        "traceQualificationCompensated": True,
        "compensatedFailures": result["failures"],
        "overlays": result["overlays"],
        "sourceMutationPerformed": False,
        "reviewOnly": True,
    }
    result_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    BASE.analyze_radial = analyze_radial
    BASE.pair_candidates = pair_candidates
    output = invocation_output()
    code = BASE.main()
    if code == 0:
        compensate_bounded_trace_hold(output)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
