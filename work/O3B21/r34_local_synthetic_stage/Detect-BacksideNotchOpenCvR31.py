#!/usr/bin/env python3
"""R31 adds clean BF split-flank confirmation of one strict DF notch over R30."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


R30_SHA256 = "A300D2667DE021A9C1E177CF475E4A04ED3B87F41D7BFA9DCEF0A1DB06BE8625"
CONFIRMATION_MODE = "DF_STRICT_MORPHOLOGY_CONFIRMED_BY_BF_SPLIT_FLANK_TOPOLOGY"


def load_r30():
    path = Path(__file__).with_name("Detect-BacksideNotchOpenCvR30.py")
    spec = importlib.util.spec_from_file_location("argos_backside_r30_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Frozen R30 detector could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    if module.R21.BASE.sha256_file(path) != R30_SHA256:
        raise RuntimeError(f"Frozen R30 detector hash changed: {path}")
    return module


R30 = load_r30()
R29 = R30.R29
R21 = R30.R21


def signed_delta(angle: float, anchor: float) -> float:
    return (float(angle) - float(anchor) + 540.0) % 360.0 - 180.0


def circular_midpoint(first: float, second: float) -> float:
    return (float(first) + signed_delta(second, first) / 2.0) % 360.0


def split_flank_eligible(row: dict, result: dict, parameters: dict) -> bool:
    minimum_width = float(parameters["manufacturedMinimumWidthDegrees"])
    return bool(
        not row.get("manufacturedMorphologyPassed", False)
        and row.get("candidateSource") == "NATIVE_CHANNEL_LOCAL_HOLDER_EXCLUDED_RADIAL_PROFILE"
        and minimum_width / 2.0 <= float(row["widthDegrees"]) < minimum_width
        and float(row["maximumDepthNativePx"])
        >= float(parameters["appearanceConfirmationMinimumDepthPx"])
        and float(row["slopeConsistencyFraction"])
        >= float(parameters["manufacturedMinimumSlopeConsistency"])
        and R29.holder_clear(row, result, parameters)
        and R29.exterior_clear(
            row,
            float(parameters["appearanceConfirmationMaximumExteriorBrightFraction"]),
            float(parameters["appearanceConfirmationMaximumExteriorAngularSupportFraction"]),
        )
    )


def strict_df_eligible(row: dict, result: dict, parameters: dict) -> bool:
    return bool(
        row.get("manufacturedMorphologyPassed", False)
        and R29.holder_clear(row, result, parameters)
        and R29.exterior_clear(
            row,
            float(parameters["appearanceConfirmationMaximumExteriorBrightFraction"]),
            float(parameters["appearanceConfirmationMaximumExteriorAngularSupportFraction"]),
        )
    )


def combined_exterior(left: dict, right: dict) -> dict:
    left_context = left["exteriorContext"]
    right_context = right["exteriorContext"]
    return {
        name: max(float(left_context[name]), float(right_context[name]))
        for name in (
            "referenceMedianIntensity", "referenceMadIntensity", "brightThresholdIntensity",
            "wedgeMedianIntensity", "wedgeP90Intensity", "brightPixelFraction",
            "maximumAngularBrightSupportFraction",
        )
    }


def combined_flank_row(left: dict, right: dict, separation: float) -> dict:
    return {
        "centerAngleDegrees": circular_midpoint(left["centerAngleDegrees"], right["centerAngleDegrees"]),
        "widthDegrees": (
            float(left["widthDegrees"]) / 2.0 + separation + float(right["widthDegrees"]) / 2.0
        ),
        "maximumDepthPx": (float(left["maximumDepthPx"]) + float(right["maximumDepthPx"])) / 2.0,
        "maximumDepthNativePx": (
            float(left["maximumDepthNativePx"]) + float(right["maximumDepthNativePx"])
        ) / 2.0,
        "maximumDepthAnalysisPx": (
            float(left["maximumDepthAnalysisPx"]) + float(right["maximumDepthAnalysisPx"])
        ) / 2.0,
        "exteriorContext": combined_exterior(left, right),
    }


def pair_split_flanks(bf: dict, df: dict) -> tuple[list[dict], dict]:
    parameters = R21.R17._PARAMETERS
    bf_trace = bf.get("backsideTraceQualification", {})
    df_trace = df.get("backsideTraceQualification", {})
    trace_eligible = bool(
        bf_trace.get("strictUsable")
        and bf_trace.get("rawRmsPassed")
        and df_trace.get("strictUsable")
        and df_trace.get("rawRmsPassed")
    )
    bf_rows = [row for row in bf.get("candidates", []) if split_flank_eligible(row, bf, parameters)]
    df_rows = [row for row in df.get("candidates", []) if strict_df_eligible(row, df, parameters)]
    tolerance = float(parameters["confirmationAngleToleranceDegrees"])
    minimum_separation = float(parameters["manufacturedMinimumWidthDegrees"])
    maximum_separation = float(parameters["confirmationClusterWidthDegrees"])
    minimum_balance = float(parameters["manufacturedMinimumSymmetry"])
    maximum_combined_width = float(parameters["manufacturedMaximumWidthDegrees"])
    comparisons = []
    proposed = []
    for df_row in df_rows if trace_eligible and len(bf_rows) == 2 and len(df_rows) == 1 else []:
        df_angle = float(df_row["centerAngleDegrees"])
        for first_index, first in enumerate(bf_rows):
            for second in bf_rows[first_index + 1:]:
                first_delta = signed_delta(first["centerAngleDegrees"], df_angle)
                second_delta = signed_delta(second["centerAngleDegrees"], df_angle)
                left, right = (first, second) if first_delta < second_delta else (second, first)
                left_delta, right_delta = sorted((first_delta, second_delta))
                separation = float(R21.BASE.circular_distance(
                    float(left["centerAngleDegrees"]), float(right["centerAngleDegrees"])
                ))
                maximum_delta = max(abs(left_delta), abs(right_delta))
                angular_balance = min(abs(left_delta), abs(right_delta)) / maximum_delta if maximum_delta else 0.0
                first_depth = float(left["maximumDepthNativePx"])
                second_depth = float(right["maximumDepthNativePx"])
                depth_balance = min(first_depth, second_depth) / max(first_depth, second_depth)
                combined = combined_flank_row(left, right, separation)
                difference = float(R21.BASE.circular_distance(
                    float(combined["centerAngleDegrees"]), df_angle
                ))
                accepted = bool(
                    -tolerance <= left_delta < 0.0 < right_delta <= tolerance
                    and minimum_separation <= separation <= maximum_separation
                    and angular_balance >= minimum_balance
                    and depth_balance >= minimum_balance
                    and float(combined["widthDegrees"]) <= maximum_combined_width
                    and max(first_depth, second_depth) <= float(df_row["maximumDepthNativePx"])
                    and difference <= tolerance
                )
                comparisons.append({
                    "leftBfAngleDegrees": float(left["centerAngleDegrees"]),
                    "rightBfAngleDegrees": float(right["centerAngleDegrees"]),
                    "dfAngleDegrees": df_angle,
                    "leftDeltaDegrees": left_delta,
                    "rightDeltaDegrees": right_delta,
                    "flankSeparationDegrees": separation,
                    "angularBalanceFraction": angular_balance,
                    "depthBalanceFraction": depth_balance,
                    "combinedWidthDegrees": float(combined["widthDegrees"]),
                    "combinedBfAngleDegrees": float(combined["centerAngleDegrees"]),
                    "combinedToDfAngleDifferenceDegrees": difference,
                    "accepted": accepted,
                })
                if accepted:
                    pair = R21.R17.pair_row(combined, df_row, difference, CONFIRMATION_MODE)
                    pair["bfSplitFlanks"] = {
                        "left": left,
                        "right": right,
                        "flankSeparationDegrees": separation,
                        "angularBalanceFraction": angular_balance,
                        "depthBalanceFraction": depth_balance,
                    }
                    proposed.append(pair)
    proposed.sort(key=lambda row: (-row["score"], row["meanAngleDegrees"]))
    clustered = []
    cluster_width = float(parameters["confirmationClusterWidthDegrees"])
    for row in proposed:
        if all(R21.BASE.circular_distance(row["meanAngleDegrees"], prior["meanAngleDegrees"]) > cluster_width
               for prior in clustered):
            clustered.append(row)
    return clustered, {
        "state": "PASS_UNIQUE_BF_SPLIT_FLANK_DF_STRICT_PAIR" if len(clustered) == 1
                 else "HOLD_BF_SPLIT_FLANK_DF_STRICT_PAIR_CARDINALITY",
        "traceEligible": trace_eligible,
        "requiresExactlyTwoEligibleBfFlanks": True,
        "requiresExactlyOneEligibleDfStrictCandidate": True,
        "eligibleBfFlankCount": len(bf_rows),
        "eligibleDfStrictCount": len(df_rows),
        "pairComparisons": comparisons,
        "preClusterPairCount": len(proposed),
        "proposedPairCount": len(clustered),
    }


def pair_candidates(bf: dict, df: dict) -> list[dict]:
    existing = R30.pair_candidates(bf, df)
    if existing:
        bf["bfSplitFlankDfStrictCompensation"] = {"state": "NOT_USED_EXISTING_R30_PAIR"}
        return existing
    proposed, diagnostic = pair_split_flanks(bf, df)
    bf["bfSplitFlankDfStrictCompensation"] = diagnostic
    return proposed if len(proposed) == 1 else []


def main() -> int:
    R30.R29.R28.R25.R24.R23.pair_candidates = pair_candidates
    return R30.R29.R28.R25.R24.main()


if __name__ == "__main__":
    raise SystemExit(main())
