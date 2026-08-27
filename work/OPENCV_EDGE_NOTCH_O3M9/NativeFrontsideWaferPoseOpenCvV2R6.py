#!/usr/bin/env python3
"""R6 full-perimeter OCV-03 development entrypoint.

R6 retains R5 edge-family and no-prior semantics, performs BF/DF candidate
assignment globally by strongest physical interval overlap, and requires at
least 90 percent independently observed perimeter-bin coverage. Historical
notch locations are not loaded or referenced.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
from typing import Any


BASE_PATH = Path(__file__).with_name("NativeFrontsideWaferPoseOpenCvV2R5.py")
BASE_MODULE_NAME = "argos_native_frontside_wafer_pose_opencv_v2_r6_base"
BASE_SPEC = importlib.util.spec_from_file_location(BASE_MODULE_NAME, BASE_PATH)
if BASE_SPEC is None or BASE_SPEC.loader is None:
    raise RuntimeError(f"Unable to create an import spec for {BASE_PATH}.")
base = importlib.util.module_from_spec(BASE_SPEC)
sys.modules[BASE_MODULE_NAME] = base
BASE_SPEC.loader.exec_module(base)
core = base.core


def build_physical(bf: dict[str, Any], df: dict[str, Any], distance: float, overlap: float, parameters: Any) -> dict[str, Any]:
    bf_width = float(bf["widthDegrees"])
    df_width = float(df["widthDegrees"])
    if bf_width < df_width:
        review_angle = float(bf["centerAngleDegrees"])
        review_channel = "BF"
    elif df_width < bf_width:
        review_angle = float(df["centerAngleDegrees"])
        review_channel = "DF"
    else:
        review_angle = core.circular_mean_degrees(
            [float(bf["centerAngleDegrees"]), float(df["centerAngleDegrees"])], [1.0, 1.0]
        )
        review_channel = "BF_DF_EQUAL_WIDTH_MEAN"
    width = min(bf_width, df_width)
    symmetry = max(float(bf["symmetryScore"]), float(df["symmetryScore"]))
    tip_offset = min(float(bf["tipCenterOffsetFraction"]), float(df["tipCenterOffsetFraction"]))
    slope_consistency = max(float(bf["slopeConsistencyFraction"]), float(df["slopeConsistencyFraction"]))
    manufactured = (
        parameters.manufactured_minimum_width_degrees <= width <= parameters.manufactured_maximum_width_degrees
        and symmetry >= parameters.manufactured_minimum_symmetry
        and tip_offset <= parameters.manufactured_maximum_tip_offset_fraction
        and slope_consistency >= parameters.manufactured_minimum_slope_consistency
        and overlap >= parameters.manufactured_minimum_cross_channel_overlap
    )
    return {
        "bfAngleDegrees": float(bf["centerAngleDegrees"]),
        "dfAngleDegrees": float(df["centerAngleDegrees"]),
        "reviewAngleDegrees": review_angle,
        "reviewAngleChannel": review_channel,
        "channelAngleDifferenceDegrees": distance,
        "crossChannelOverlapFraction": overlap,
        "combinedWidthDegrees": width,
        "combinedWidthSemantics": "NARROWER_CHANNEL_RESPONSE_WITH_BF_DF_PHYSICAL_OVERLAP_REQUIRED",
        "combinedSymmetryScore": symmetry,
        "combinedTipCenterOffsetFraction": tip_offset,
        "combinedSlopeConsistencyFraction": slope_consistency,
        "manufacturedNotchMorphologyEligible": manufactured,
        "bf": bf,
        "df": df,
        "evidence": "BF_DF_INDEPENDENT_FULL_PERIMETER_GLOBAL_INTERVAL_OVERLAP_ASSIGNMENT",
    }


def match_candidates_global(
    bf_candidates: list[dict[str, Any]],
    df_candidates: list[dict[str, Any]],
    parameters: Any,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    choices: list[tuple[float, float, int, int]] = []
    for bf_index, bf in enumerate(bf_candidates):
        for df_index, df in enumerate(df_candidates):
            distance = core.circular_distance_degrees(
                float(bf["centerAngleDegrees"]), float(df["centerAngleDegrees"])
            )
            overlap = core.interval_overlap_fraction(bf, df)
            if distance <= parameters.candidate_match_tolerance_degrees or overlap >= parameters.manufactured_minimum_cross_channel_overlap:
                choices.append((-overlap, distance, bf_index, df_index))
    used_bf: set[int] = set()
    used_df: set[int] = set()
    physical: list[dict[str, Any]] = []
    for negative_overlap, distance, bf_index, df_index in sorted(choices):
        if bf_index in used_bf or df_index in used_df:
            continue
        used_bf.add(bf_index)
        used_df.add(df_index)
        physical.append(
            build_physical(
                bf_candidates[bf_index], df_candidates[df_index], distance, -negative_overlap, parameters
            )
        )
    bf_only = [dict(row) for index, row in enumerate(bf_candidates) if index not in used_bf]
    df_only = [dict(row) for index, row in enumerate(df_candidates) if index not in used_df]
    return physical, bf_only, df_only


def r6_synthetic_parameters() -> Any:
    original = base.r5_synthetic_parameters()
    values = dict(original.__dict__)
    values["minimum_angular_coverage_fraction"] = 0.90
    return core.Parameters(**values)


def candidate(angle: float, width: float, symmetry: float, tip: float) -> dict[str, Any]:
    return {
        "centerAngleDegrees": angle,
        "startAngleDegrees": angle - width / 2.0,
        "endAngleDegrees": angle + width / 2.0,
        "widthDegrees": width,
        "maximumDepthPx": 40.0,
        "medianDepthPx": 30.0,
        "sampleCount": max(4, int(round(width * 10.0))),
        "symmetryScore": symmetry,
        "tipCenterOffsetFraction": tip,
        "slopeConsistencyFraction": 1.0,
    }


def erase_wedge(image: Any, start_degrees: float, end_degrees: float) -> Any:
    result = image.copy()
    mask = core.np.zeros_like(result)
    core.cv2.ellipse(mask, (512, 512), (800, 800), 0.0, start_degrees, end_degrees, 255, thickness=-1)
    result[mask > 0] = 0
    return result


def r6_synthetic_gate(output_root: Path) -> dict[str, Any]:
    if output_root.exists():
        raise FileExistsError(f"Synthetic V2 R6 output root already exists: {output_root}")
    output_root.mkdir(parents=True)
    parameters = r6_synthetic_parameters()
    positive_cases = [
        {
            "caseId": "ANGLE_037_EDGE_FAMILY_OFFSET",
            "expected": 37.0,
            "chipout": None,
            "bf": base.draw_channel(37.0, 420, 2.2, 34.0),
            "df": base.draw_channel(37.15, 438, 2.2, 34.0),
        },
        {
            "caseId": "ANGLE_217_BROAD_CHANNEL_WITH_CHIPOUT",
            "expected": 217.0,
            "chipout": 41.0,
            "bf": base.draw_channel(219.5, 420, 12.0, 34.0, 30.5, 18.5, 70.0),
            "df": base.draw_channel(217.15, 438, 2.2, 34.0, 41.12, 1.5, 70.0),
        },
    ]
    rows: list[dict[str, Any]] = []
    for case in positive_cases:
        result = core.analyze_pair(case["caseId"], case["bf"], case["df"], parameters)
        selected = result["selectedReviewOnlyManufacturedNotch"]
        detected = None if selected is None else float(selected["reviewAngleDegrees"])
        passed = detected is not None and core.circular_distance_degrees(detected, float(case["expected"])) <= 0.8
        if case["chipout"] is not None and detected is not None:
            passed = passed and core.circular_distance_degrees(detected, float(case["chipout"])) > 1.0
        rows.append({"caseId":case["caseId"],"expectedAngleDegreesScorerOnly":case["expected"],"detectedReviewAngleDegrees":detected,"state":result["state"],"passed":passed})
        core.atomic_write_json(output_root / case["caseId"] / "RESULT.json", result)

    bad_bf = erase_wedge(base.draw_channel(143.0, 420, 2.2, 34.0), 250.0, 305.0)
    bad_df = erase_wedge(base.draw_channel(143.15, 438, 2.2, 34.0), 250.0, 305.0)
    bad_result = core.analyze_pair("NEGATIVE_MISSING_PERIMETER_WEDGE", bad_bf, bad_df, parameters)
    negative_passed = bad_result["selectedReviewOnlyManufacturedNotch"] is None and "PERIMETER_NOT_QUALIFIED" in bad_result["state"]
    core.atomic_write_json(output_root / "NEGATIVE_MISSING_PERIMETER_WEDGE" / "RESULT.json", bad_result)

    unit_bf = [candidate(118.9, 0.7, 0.0, 1.0), candidate(120.0, 1.4, 0.0, 1.0)]
    unit_df = [candidate(119.64, 2.4, 0.82, 0.13)]
    unit_physical, _, _ = match_candidates_global(unit_bf, unit_df, parameters)
    pairing_passed = (
        len(unit_physical) == 1
        and abs(float(unit_physical[0]["bfAngleDegrees"]) - 120.0) < 1e-9
        and bool(unit_physical[0]["manufacturedNotchMorphologyEligible"])
    )
    gate_passed = all(row["passed"] for row in rows) and negative_passed and pairing_passed
    gate = {
        "schema": "argos_native_frontside_wafer_pose_opencv_v2_r6_synthetic_gate",
        "state": "PASS_OPENCV_V2_R6_SYNTHETIC_GATE" if gate_passed else "FAIL_OPENCV_V2_R6_SYNTHETIC_GATE",
        "rows": rows,
        "globalPairingStrongestOverlapControlPassed": pairing_passed,
        "missingPerimeterWedgeNegativeControlPassed": negative_passed,
        "minimumSupportedPerimeterCoverageFraction": parameters.minimum_angular_coverage_fraction,
        "edgeFamilyRadiusOffsetIncluded": True,
        "broadChannelResponseIncluded": True,
        "chipoutControlIncluded": True,
        "knownLocationConsumedByDetector": False,
        "expectedAnglesUsedOnlyAfterInference": True,
    }
    core.atomic_write_json(output_root / "SYNTHETIC_GATE.json", gate)
    return gate


core.match_candidates = match_candidates_global
core.synthetic_parameters = r6_synthetic_parameters
core.synthetic_gate = r6_synthetic_gate


if __name__ == "__main__":
    raise SystemExit(core.main())
