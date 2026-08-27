#!/usr/bin/env python3
"""R5 full-perimeter OCV-03 development entrypoint.

The detector receives no historical locations. R5 corrects three generic
measurement semantics exposed by frozen R4 outputs: boundary observation
coverage is measured before robust-fit outlier rejection, BF/DF indentations
may associate by interval overlap when one channel response is broad, and the
narrower channel supplies the review-only angle/width while both channels must
still provide overlapping physical evidence.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
from typing import Any


CORE_PATH = Path(__file__).with_name("NativeFrontsideWaferPoseOpenCvV2.py")
CORE_MODULE_NAME = "argos_native_frontside_wafer_pose_opencv_v2_r5_core"
CORE_SPEC = importlib.util.spec_from_file_location(CORE_MODULE_NAME, CORE_PATH)
if CORE_SPEC is None or CORE_SPEC.loader is None:
    raise RuntimeError(f"Unable to create an import spec for {CORE_PATH}.")
core = importlib.util.module_from_spec(CORE_SPEC)
sys.modules[CORE_MODULE_NAME] = core
CORE_SPEC.loader.exec_module(core)
ORIGINAL_SYNTHETIC_PARAMETERS = core.synthetic_parameters
ORIGINAL_LOCALIZE_CHANNEL = core.localize_channel
ORIGINAL_ANALYZE_PAIR = core.analyze_pair


def supported_boundary_coverage(angles: Any, retained: Any) -> float:
    """Measure observed boundary bins, not robust-circle inlier bins.

    `angles` is already restricted to independently supported boundary samples
    by localize_channel. A real indentation is intentionally a circle-fit
    outlier and must not be reclassified as an unobserved perimeter sector.
    """
    del retained
    bins = core.np.unique(
        core.np.floor((angles % (2.0 * core.math.pi)) / (2.0 * core.math.pi) * 72.0).astype(int)
    )
    return float(bins.size / 72.0)


def match_candidates_by_physical_overlap(
    bf_candidates: list[dict[str, Any]],
    df_candidates: list[dict[str, Any]],
    parameters: Any,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    remaining = set(range(len(df_candidates)))
    physical: list[dict[str, Any]] = []
    bf_only: list[dict[str, Any]] = []
    for bf in bf_candidates:
        choices: list[tuple[float, float, int]] = []
        for index in remaining:
            df = df_candidates[index]
            distance = core.circular_distance_degrees(
                float(bf["centerAngleDegrees"]), float(df["centerAngleDegrees"])
            )
            overlap = core.interval_overlap_fraction(bf, df)
            if distance <= parameters.candidate_match_tolerance_degrees or overlap >= parameters.manufactured_minimum_cross_channel_overlap:
                choices.append((-overlap, distance, index))
        if not choices:
            bf_only.append(dict(bf))
            continue
        negative_overlap, distance, index = sorted(choices)[0]
        remaining.remove(index)
        df = df_candidates[index]
        overlap = -negative_overlap
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
        physical.append(
            {
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
                "evidence": "BF_DF_INDEPENDENT_FULL_PERIMETER_INTERVAL_OVERLAP",
            }
        )
    df_only = [dict(df_candidates[index]) for index in sorted(remaining)]
    return physical, bf_only, df_only


def r5_synthetic_parameters() -> Any:
    original = ORIGINAL_SYNTHETIC_PARAMETERS()
    values = dict(original.__dict__)
    values["minimum_fit_inlier_fraction"] = 0.80
    values["manufactured_maximum_tip_offset_fraction"] = 0.70
    values["maximum_channel_radius_difference_px"] = 32.0
    return core.Parameters(**values)


def r5_localize_channel(image: Any, channel: str, parameters: Any) -> dict[str, Any]:
    result = ORIGINAL_LOCALIZE_CHANNEL(image, channel, parameters)
    if "fit" in result:
        result["fit"]["angularCoveragePopulation"] = "SUPPORTED_BOUNDARY_SAMPLES_BEFORE_ROBUST_CIRCLE_INLIER_REJECTION"
    return result


def r5_analyze_pair(identity: str, bf_image: Any, df_image: Any, parameters: Any) -> dict[str, Any]:
    result = ORIGINAL_ANALYZE_PAIR(identity, bf_image, df_image, parameters)
    result["developmentCohortUnlabeledGeometryUsedForGenericGateRevision"] = True
    result["historicalNotchLabelsConsumed"] = False
    result["historicalNotchLocationUsedToDeriveThreshold"] = False
    return result


def draw_channel(
    notch_angle: float,
    radius: int,
    notch_width: float,
    notch_depth: float,
    chipout_angle: float | None = None,
    chipout_width: float = 5.0,
    chipout_depth: float = 70.0,
) -> Any:
    image = core.np.zeros((1024, 1024), dtype=core.np.uint8)
    center = (512, 512)
    core.cv2.circle(image, center, radius, 210, thickness=-1, lineType=core.cv2.LINE_AA)
    features = [(notch_angle, notch_width, notch_depth, False)]
    if chipout_angle is not None:
        features.append((chipout_angle, chipout_width, chipout_depth, True))
    for angle, width, depth, irregular in features:
        radians = core.math.radians(angle)
        half = core.math.radians(width / 2.0)
        points = []
        for offset in (-half, half):
            points.append(
                (
                    int(round(center[0] + core.math.cos(radians + offset) * radius)),
                    int(round(center[1] + core.math.sin(radians + offset) * radius)),
                )
            )
        tip_angle = radians + (core.math.radians(width * 0.22) if irregular else 0.0)
        points.append(
            (
                int(round(center[0] + core.math.cos(tip_angle) * (radius - depth))),
                int(round(center[1] + core.math.sin(tip_angle) * (radius - depth))),
            )
        )
        core.cv2.fillConvexPoly(image, core.np.asarray(points, dtype=core.np.int32), 0, lineType=core.cv2.LINE_AA)
    return image


def r5_synthetic_gate(output_root: Path) -> dict[str, Any]:
    if output_root.exists():
        raise FileExistsError(f"Synthetic V2 R5 output root already exists: {output_root}")
    output_root.mkdir(parents=True)
    parameters = r5_synthetic_parameters()
    cases = [
        {
            "caseId": "ANGLE_037_EDGE_FAMILY_OFFSET",
            "expected": 37.0,
            "chipout": None,
            "bf": draw_channel(37.0, 420, 2.2, 34.0),
            "df": draw_channel(37.15, 438, 2.2, 34.0),
        },
        {
            "caseId": "ANGLE_217_BROAD_CHANNEL_WITH_CHIPOUT",
            "expected": 217.0,
            "chipout": 41.0,
            "bf": draw_channel(219.5, 420, 12.0, 34.0, 30.5, 18.5, 70.0),
            "df": draw_channel(217.15, 438, 2.2, 34.0, 41.12, 1.5, 70.0),
        },
    ]
    rows: list[dict[str, Any]] = []
    for case in cases:
        result = core.analyze_pair(case["caseId"], case["bf"], case["df"], parameters)
        selected = result["selectedReviewOnlyManufacturedNotch"]
        detected = None if selected is None else float(selected["reviewAngleDegrees"])
        passed = detected is not None and core.circular_distance_degrees(detected, float(case["expected"])) <= 0.8
        if case["chipout"] is not None and detected is not None:
            passed = passed and core.circular_distance_degrees(detected, float(case["chipout"])) > 1.0
        rows.append(
            {
                "caseId": case["caseId"],
                "expectedAngleDegreesScorerOnly": case["expected"],
                "detectedReviewAngleDegrees": detected,
                "state": result["state"],
                "passed": passed,
            }
        )
        core.atomic_write_json(output_root / case["caseId"] / "RESULT.json", result)
    gate = {
        "schema": "argos_native_frontside_wafer_pose_opencv_v2_r5_synthetic_gate",
        "state": "PASS_OPENCV_V2_R5_SYNTHETIC_GATE" if all(row["passed"] for row in rows) else "FAIL_OPENCV_V2_R5_SYNTHETIC_GATE",
        "rows": rows,
        "edgeFamilyRadiusOffsetIncluded": True,
        "broadChannelResponseIncluded": True,
        "chipoutControlIncluded": True,
        "knownLocationConsumedByDetector": False,
        "expectedAnglesUsedOnlyAfterInference": True,
    }
    core.atomic_write_json(output_root / "SYNTHETIC_GATE.json", gate)
    return gate


core.angular_coverage = supported_boundary_coverage
core.match_candidates = match_candidates_by_physical_overlap
core.localize_channel = r5_localize_channel
core.analyze_pair = r5_analyze_pair
core.synthetic_parameters = r5_synthetic_parameters
core.synthetic_gate = r5_synthetic_gate


if __name__ == "__main__":
    raise SystemExit(core.main())
