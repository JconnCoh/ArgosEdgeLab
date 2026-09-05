#!/usr/bin/env python3
"""R21 evidence-connected native-pixel notch contour diagnostic."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import sys
from typing import Any

import cv2
import numpy as np


HERE = Path(__file__).resolve().parent
R20_SHA256 = "8703BC3D3E1B2FB685FD70AA4D13E28BE1A9026D5BB548A298AFB9104049828D"
R20_SUMMARY_SHA256 = "90FDD521B6322836692754FD88670BB9275EBE12E34F376C0D4B9996382411E6"
R20_PATH = Path(os.environ.get("ARGOS_R20_ENGINE_PATH", HERE / "AnnularUnwrapDiagnosticOpenCvR20.py"))
R20_SUMMARY_PATH = Path(os.environ.get("ARGOS_R20_BASELINE_SUMMARY", r"C:\O3F16U20LAB_DRAFT1\SUMMARY.json"))

SHOULDER_WINDOW_SAMPLES = 9
MINIMUM_SHOULDER_SUPPORT_SAMPLES = 7
MAXIMUM_ANCHOR_SEARCH_SAMPLES = 64
MAXIMUM_MISSING_RUN_SAMPLES = 1
MAXIMUM_ADJACENT_SLOPE_PX_PER_SAMPLE = 6.0
MAXIMUM_RADIAL_JUMP_PX_PER_LINK = 12.0
MAXIMUM_OUTWARD_WIGGLE_PX_PER_LINK = 2.0
TIP_SEARCH_HALF_WIDTH_SAMPLES = 44
MINIMUM_PATH_COVERAGE_FRACTION = 0.90
MINIMUM_GRADIENT_NORMAL_ALIGNMENT = 0.80
MINIMUM_GRADIENT_ALIGNED_FRACTION = 0.85
MINIMUM_CORRECT_GRADIENT_POLARITY_FRACTION = 0.98


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


if not R20_PATH.is_file() or sha256(R20_PATH) != R20_SHA256:
    raise RuntimeError("R21 requires the exact hash-pinned R20 first-write layer")
SPEC = importlib.util.spec_from_file_location("argos_annular_diagnostic_r20_for_r21", R20_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load {R20_PATH}")
r20 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = r20
SPEC.loader.exec_module(r20)
r19 = r20.r19
r18 = r19.r18
need = r19.need

need(sha256(r20.R19_PATH) == r20.R19_SHA256, "R21/R20 R19 source pin differs")
need(sha256(r19.R18_PATH) == r19.R18_SHA256, "R21/R19 R18 source pin differs")
need(r18.run_local_strip_review is r19._run_local_r18, "R21 requires the pristine R18 local runner")
need(r18.diagnostic.atomic_json is r20.atomic_json, "R21 requires the R20 first-write dispatcher")

_analyze_r18 = r19._analyze_r18
_pair_r18 = r19._pair_r18
_render_r19 = r19.render
_dedicated_notch_review_r18 = r18.dedicated_notch_review
_preservation: dict[str, Any] = {}


def longest_missing(values: np.ndarray) -> int:
    best = current = 0
    for value in values:
        current = 0 if bool(value) else current + 1
        best = max(best, current)
    return best


def ordered_span(left: int, right: int, width: int) -> np.ndarray:
    count = (int(right) - int(left)) % width + 1
    need(count <= width // 2, "R21 shoulder span exceeds half the perimeter")
    return (int(left) + np.arange(count, dtype=np.int64)) % width


def shoulder_population(
    physical: dict[str, Any], envelope: np.ndarray, left: bool
) -> tuple[np.ndarray, int]:
    width = int(physical["outerPath"].size)
    edge = int(envelope[0] if left else envelope[-1])
    distance = np.arange(1, SHOULDER_WINDOW_SAMPLES + 1, dtype=np.int64)
    columns = (edge - distance if left else edge + distance) % width
    count = int(np.count_nonzero(physical["normalBevelTraceObservedColumns"][columns]))
    return columns, count


def find_shoulder_anchor(
    physical: dict[str, Any], transition: dict[str, Any], envelope: np.ndarray, left: bool
) -> dict[str, Any] | None:
    width = int(physical["outerPath"].size)
    edge = int(envelope[0] if left else envelope[-1])
    observed = physical["normalBevelTraceObservedColumns"]
    path = physical["normalBevelTracePath"]
    search_offsets = transition["searchOffsets"]
    supported = transition["frontierSupported"]
    for distance in range(1, MAXIMUM_ANCHOR_SEARCH_SAMPLES + 1):
        column = (edge - distance if left else edge + distance) % width
        if not bool(observed[column]) or not math.isfinite(float(path[column])):
            continue
        row = int(np.argmin(np.abs(search_offsets - float(path[column]))))
        if (
            abs(float(search_offsets[row]) - float(path[column])) <= 1.0e-6
            and bool(supported[row, column])
        ):
            return {
                "column": int(column),
                "row": row,
                "offsetPx": float(search_offsets[row]),
                "distanceFromCandidateSamples": distance,
            }
    return None


def directional_paths(
    columns: np.ndarray,
    nodes: list[np.ndarray],
    start_row: int,
    forward: bool,
    transition: dict[str, Any],
) -> list[dict[int, tuple[int, int, float, float, float, tuple[int, int] | None]]]:
    """Build native-node paths moving inward from one measured lime shoulder."""
    search_offsets = transition["searchOffsets"]
    enhanced = transition["enhancedContrast"]
    raw = transition["rawContrast"]
    states: list[dict[int, tuple[int, int, float, float, float, tuple[int, int] | None]]] = [
        {} for _ in columns
    ]
    start = 0 if forward else len(columns) - 1
    states[start][int(start_row)] = (
        1,
        0,
        float(enhanced[start_row, columns[start]]),
        float(raw[start_row, columns[start]]),
        0.0,
        None,
    )
    scan = range(len(columns)) if forward else range(len(columns) - 1, -1, -1)
    for index in scan:
        if index == start:
            continue
        for row_value in nodes[index]:
            row = int(row_value)
            best: tuple[tuple[Any, ...], tuple[Any, ...]] | None = None
            for delta in range(1, MAXIMUM_MISSING_RUN_SAMPLES + 2):
                previous_index = index - delta if forward else index + delta
                if previous_index < 0 or previous_index >= len(columns):
                    continue
                for previous_row, previous in states[previous_index].items():
                    radial_delta = float(search_offsets[row] - search_offsets[previous_row])
                    if (
                        abs(radial_delta) > MAXIMUM_RADIAL_JUMP_PX_PER_LINK + 1.0e-6
                        or abs(radial_delta)
                        > MAXIMUM_ADJACENT_SLOPE_PX_PER_SAMPLE * delta + 1.0e-6
                        or radial_delta > MAXIMUM_OUTWARD_WIGGLE_PX_PER_LINK + 1.0e-6
                    ):
                        continue
                    candidate = (
                        previous[0] + 1,
                        previous[1] + delta - 1,
                        previous[2] + float(enhanced[row, columns[index]]),
                        previous[3] + float(raw[row, columns[index]]),
                        previous[4] + abs(radial_delta) / delta,
                        (previous_index, int(previous_row)),
                    )
                    rank = (
                        candidate[0],
                        -candidate[1],
                        candidate[2],
                        candidate[3],
                        -candidate[4],
                        -row,
                    )
                    if best is None or rank > best[0]:
                        best = (rank, candidate)
            if best is not None:
                states[index][row] = best[1]
    return states


def restore_half_path(
    states: list[dict[int, tuple[int, int, float, float, float, tuple[int, int] | None]]],
    index: int,
    row: int,
    reverse_result: bool,
) -> list[tuple[int, int]]:
    result: list[tuple[int, int]] = []
    while True:
        result.append((int(index), int(row)))
        previous = states[index][row][5]
        if previous is None:
            break
        index, row = previous
    if reverse_result:
        result.reverse()
    return result


def gradient_metrics(
    strip: np.ndarray,
    offsets: np.ndarray,
    transition: dict[str, Any],
    columns: np.ndarray,
    sequence: list[tuple[int, int]],
) -> dict[str, Any]:
    smooth = r18.cyclic_gaussian_image(strip).astype(np.float32)
    cyclic = np.pad(smooth, ((0, 0), (1, 1)), mode="wrap")
    gx = cv2.Sobel(cyclic, cv2.CV_32F, 1, 0, ksize=3)[:, 1:-1]
    gy = cv2.Sobel(cyclic, cv2.CV_32F, 0, 1, ksize=3)[:, 1:-1]
    search_offsets = transition["searchOffsets"]
    alignments: list[float] = []
    for sequence_index, (position, row) in enumerate(sequence):
        before = sequence[max(0, sequence_index - 1)]
        after = sequence[min(len(sequence) - 1, sequence_index + 1)]
        tangent_x = float(after[0] - before[0])
        tangent_y = float(search_offsets[after[1]] - search_offsets[before[1]])
        if tangent_x == 0.0 and tangent_y == 0.0:
            continue
        column = int(columns[position])
        image_row = int(round(float(search_offsets[row]) - float(offsets[0])))
        grad_x = float(gx[image_row, column])
        grad_y = float(gy[image_row, column])
        denominator = max(math.hypot(grad_x, grad_y) * math.hypot(tangent_x, tangent_y), 1.0e-6)
        # Increasing radial rows point outward, so (tangent_y, -tangent_x) is inward.
        alignments.append((grad_x * tangent_y - grad_y * tangent_x) / denominator)
    values = np.asarray(alignments, dtype=np.float64)
    return {
        "population": "SELECTED_NATIVE_PATH_NODES_WITH_DEFINED_LOCAL_TANGENT_ON_RAW_GAUSSIAN_IMAGE",
        "sampleCount": int(values.size),
        "minimumCosine": float(np.min(values)) if values.size else None,
        "p10Cosine": float(np.percentile(values, 10.0)) if values.size else None,
        "medianCosine": float(np.median(values)) if values.size else None,
        "fractionAtLeast0p8": (
            float(np.mean(values >= MINIMUM_GRADIENT_NORMAL_ALIGNMENT)) if values.size else 0.0
        ),
        "correctSignedPolarityFraction": float(np.mean(values > 0.0)) if values.size else 0.0,
    }


def select_native_shoulder_path(
    physical: dict[str, Any],
    transition: dict[str, Any],
    index: int,
    channel: str,
    predecessor_observed: np.ndarray,
) -> dict[str, Any]:
    candidate = physical["notch"]["candidates"][index]
    envelope = np.asarray(physical["notch"]["candidateColumnSets"][index], dtype=np.int32)
    width = int(physical["outerPath"].size)
    need(
        predecessor_observed.shape == (width,),
        "R21 predecessor observed-column shape differs",
    )
    need(envelope.size > 0 and bool(np.all((np.diff(envelope) % width) == 1)), "R21 candidate columns are not ordered")
    left_population, left_count = shoulder_population(physical, envelope, True)
    right_population, right_count = shoulder_population(physical, envelope, False)
    left_anchor = find_shoulder_anchor(physical, transition, envelope, True)
    right_anchor = find_shoulder_anchor(physical, transition, envelope, False)

    base_metrics: dict[str, Any] = {
        "algorithm": "BIDIRECTIONAL_NATIVE_SUPPORT_GRAPH_FROM_MEASURED_NORMAL_BEVEL_SHOULDERS",
        "channel": channel,
        "candidateCenterAngleDegrees": float(candidate["centerAngleDegrees"]),
        "candidateWidthDegrees": float(candidate["widthDegrees"]),
        "candidateEnvelopeSampleCount": int(envelope.size),
        "shoulderWindowSamples": SHOULDER_WINDOW_SAMPLES,
        "minimumShoulderSupportSamples": MINIMUM_SHOULDER_SUPPORT_SAMPLES,
        "leftShoulderSupportCount": left_count,
        "rightShoulderSupportCount": right_count,
        "leftShoulderSupportFraction": float(left_count / SHOULDER_WINDOW_SAMPLES),
        "rightShoulderSupportFraction": float(right_count / SHOULDER_WINDOW_SAMPLES),
        "leftShoulderPopulationColumns": [int(value) for value in left_population],
        "rightShoulderPopulationColumns": [int(value) for value in right_population],
        "leftAnchor": left_anchor,
        "rightAnchor": right_anchor,
        "maximumAnchorSearchSamples": MAXIMUM_ANCHOR_SEARCH_SAMPLES,
        "maximumMissingRunSamplesAllowed": MAXIMUM_MISSING_RUN_SAMPLES,
        "maximumAdjacentSlopePxPerSampleAllowed": MAXIMUM_ADJACENT_SLOPE_PX_PER_SAMPLE,
        "maximumRadialJumpPxPerLinkAllowed": MAXIMUM_RADIAL_JUMP_PX_PER_LINK,
        "maximumOutwardWigglePxPerLinkAllowed": MAXIMUM_OUTWARD_WIGGLE_PX_PER_LINK,
        "tipSearchHalfWidthSamples": TIP_SEARCH_HALF_WIDTH_SAMPLES,
        "minimumCoverageFraction": MINIMUM_PATH_COVERAGE_FRACTION,
        "minimumGradientNormalAlignment": MINIMUM_GRADIENT_NORMAL_ALIGNMENT,
        "minimumGradientAlignedFraction": MINIMUM_GRADIENT_ALIGNED_FRACTION,
        "minimumCorrectGradientPolarityFraction": MINIMUM_CORRECT_GRADIENT_POLARITY_FRACTION,
        "transitionSupport": "R18_FRONTIER_SUPPORTED_POSITIVE_RAW_AND_ENHANCED_OUTSIDE_TO_INSIDE_POLARITY",
        "templateModelUsed": False,
        "curveFitUsedToPlacePixels": False,
        "interpolationPerformed": False,
        "syntheticPixelCount": 0,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "postResultSelectorRelaxationPerformed": False,
        "contourEvidenceReplacesCandidateSelector": False,
        "contourEvidenceValidatesAlreadyPairedCandidate": True,
    }
    empty_path = np.full(width, np.nan, dtype=np.float32)
    empty_observed = np.zeros(width, dtype=bool)
    shoulder_gate = bool(
        left_count >= MINIMUM_SHOULDER_SUPPORT_SAMPLES
        and right_count >= MINIMUM_SHOULDER_SUPPORT_SAMPLES
        and left_anchor is not None
        and right_anchor is not None
    )
    if not shoulder_gate:
        base_metrics.update(
            {
                "state": "HOLD_INSUFFICIENT_MEASURED_SHOULDER_SUPPORT",
                "reviewState": f"HOLD_{channel}_NOTCH_CONTOUR_UNOBSERVED",
                "holdScope": f"{channel}_NOTCH_CONTOUR_PRESENTATION_ONLY",
                "fullShoulderToShoulderPathExists": False,
                "boundedGapShoulderToShoulderPathExists": False,
                "orangeEligible": False,
                "orangePixelCount": 0,
                "selectedNativePixelCount": 0,
                "expectedSpanColumnCount": 0,
                "coverageFraction": 0.0,
                "maximumMissingRunSamples": None,
                "maximumAdjacentSlopePxPerSample": None,
                "maximumRadialJumpPxPerLink": None,
                "maximumOutwardWigglePxPerLink": None,
                "tipDepthPx": None,
                "tipCenterDeltaSamples": None,
                "gradientNormalAlignment": None,
                "allSelectedPixelsNativeSupported": True,
                "inwardLimitTouchCount": 0,
            }
        )
        return {"path": empty_path, "observed": empty_observed, "accepted": False, "metrics": base_metrics}

    assert left_anchor is not None and right_anchor is not None
    columns = ordered_span(left_anchor["column"], right_anchor["column"], width)
    supported = transition["frontierSupported"]
    # Existing missing-evidence columns remain unavailable to the successor
    # contour. A newly supported pixel may not silently clear an inherited hold.
    nodes = [
        np.flatnonzero(supported[:, column])
        if predecessor_observed[column]
        else np.empty(0, dtype=np.int64)
        for column in columns
    ]
    need(left_anchor["row"] in nodes[0] and right_anchor["row"] in nodes[-1], "R21 shoulder anchor lost native support")
    forward = directional_paths(columns, nodes, int(left_anchor["row"]), True, transition)
    backward = directional_paths(columns, nodes, int(right_anchor["row"]), False, transition)
    target = int(round(float(candidate["centerAngleDegrees"]) * width / 360.0)) % width
    signed_center_distance = ((columns - target + width // 2) % width) - width // 2
    threshold = float(physical["notch"]["thresholdPx"])
    best: tuple[tuple[Any, ...], int, int] | None = None
    for position_value in np.flatnonzero(np.abs(signed_center_distance) <= TIP_SEARCH_HALF_WIDTH_SAMPLES):
        position = int(position_value)
        for row in set(forward[position]).intersection(backward[position]):
            tip_depth = float(physical["outerPath"][columns[position]] - transition["searchOffsets"][row])
            if tip_depth + 1.0e-6 < threshold:
                continue
            left_state = forward[position][row]
            right_state = backward[position][row]
            count = left_state[0] + right_state[0] - 1
            gaps = left_state[1] + right_state[1]
            enhanced_sum = left_state[2] + right_state[2] - float(
                transition["enhancedContrast"][row, columns[position]]
            )
            raw_sum = left_state[3] + right_state[3] - float(
                transition["rawContrast"][row, columns[position]]
            )
            movement = left_state[4] + right_state[4]
            rank = (
                count,
                -gaps,
                -abs(int(signed_center_distance[position])),
                tip_depth,
                enhanced_sum,
                raw_sum,
                -movement,
                -row,
            )
            if best is None or rank > best[0]:
                best = (rank, position, int(row))

    if best is None:
        base_metrics.update(
            {
                "state": "HOLD_NO_CONNECTED_NATIVE_SHOULDER_TO_SHOULDER_PATH",
                "reviewState": f"HOLD_{channel}_NOTCH_CONTOUR_UNOBSERVED",
                "holdScope": f"{channel}_NOTCH_CONTOUR_PRESENTATION_ONLY",
                "fullShoulderToShoulderPathExists": False,
                "boundedGapShoulderToShoulderPathExists": False,
                "orangeEligible": False,
                "orangePixelCount": 0,
                "selectedNativePixelCount": 0,
                "expectedSpanColumnCount": int(columns.size),
                "coverageFraction": 0.0,
                "maximumMissingRunSamples": None,
                "maximumAdjacentSlopePxPerSample": None,
                "maximumRadialJumpPxPerLink": None,
                "maximumOutwardWigglePxPerLink": None,
                "tipDepthPx": None,
                "tipCenterDeltaSamples": None,
                "gradientNormalAlignment": None,
                "allSelectedPixelsNativeSupported": True,
                "inwardLimitTouchCount": 0,
            }
        )
        return {"path": empty_path, "observed": empty_observed, "accepted": False, "metrics": base_metrics}

    _, meeting_position, meeting_row = best
    left_half = restore_half_path(forward, meeting_position, meeting_row, True)
    right_half = restore_half_path(backward, meeting_position, meeting_row, False)
    sequence = left_half + right_half[1:]
    full_path = empty_path.copy()
    full_observed = empty_observed.copy()
    span_observed = np.zeros(columns.size, dtype=bool)
    search_offsets = transition["searchOffsets"]
    for position, row in sequence:
        column = int(columns[position])
        full_path[column] = float(search_offsets[row])
        full_observed[column] = True
        span_observed[position] = True
    need(len(sequence) == len(set(sequence)), "R21 native path repeats a graph node")
    need(
        bool(np.all([supported[row, columns[position]] for position, row in sequence])),
        "R21 selected a pixel absent from native transition support",
    )
    deltas = np.diff(np.asarray([position for position, _ in sequence], dtype=np.int32))
    radial = np.asarray([float(search_offsets[row]) for _, row in sequence], dtype=np.float64)
    radial_delta = np.diff(radial)
    slopes = np.abs(radial_delta) / deltas
    midpoint = len(left_half) - 1
    toward_center_outward = np.concatenate((radial_delta[:midpoint], -radial_delta[midpoint:]))
    maximum_outward = (
        max(0.0, float(np.max(toward_center_outward)))
        if toward_center_outward.size
        else 0.0
    )
    tip_depth = float(
        physical["outerPath"][columns[meeting_position]] - search_offsets[meeting_row]
    )
    gradient = gradient_metrics(physical["strip"], physical["offsets"], transition, columns, sequence)
    raw_response = np.asarray(
        [transition["rawContrast"][row, columns[position]] for position, row in sequence],
        dtype=np.float64,
    )
    enhanced_response = np.asarray(
        [transition["enhancedContrast"][row, columns[position]] for position, row in sequence],
        dtype=np.float64,
    )
    inward_limit = int(
        np.count_nonzero(
            full_observed
            & np.isclose(full_path, r18.SEARCH_MIN_OFFSET_PX, rtol=0.0, atol=1.0e-6)
        )
    )
    maximum_missing = longest_missing(span_observed)
    coverage = float(np.mean(span_observed))
    maximum_slope = float(np.max(slopes)) if slopes.size else 0.0
    maximum_radial_jump = float(np.max(np.abs(radial_delta))) if radial_delta.size else 0.0
    accepted = bool(
        coverage >= MINIMUM_PATH_COVERAGE_FRACTION
        and maximum_missing <= MAXIMUM_MISSING_RUN_SAMPLES
        and maximum_slope <= MAXIMUM_ADJACENT_SLOPE_PX_PER_SAMPLE + 1.0e-6
        and maximum_radial_jump <= MAXIMUM_RADIAL_JUMP_PX_PER_LINK + 1.0e-6
        and maximum_outward <= MAXIMUM_OUTWARD_WIGGLE_PX_PER_LINK + 1.0e-6
        and tip_depth + 1.0e-6 >= threshold
        and inward_limit == 0
        and gradient["fractionAtLeast0p8"] >= MINIMUM_GRADIENT_ALIGNED_FRACTION
        and gradient["correctSignedPolarityFraction"]
        >= MINIMUM_CORRECT_GRADIENT_POLARITY_FRACTION
    )
    base_metrics.update(
        {
            "state": (
                "PASS_BOUNDED_GAP_NATIVE_SHOULDER_TO_SHOULDER_NOTCH_CONTOUR"
                if accepted
                else "HOLD_NATIVE_PATH_FAILED_EVIDENCE_GATE"
            ),
            "reviewState": (
                f"PASS_{channel}_BOUNDED_GAP_NATIVE_NOTCH_CONTOUR"
                if accepted
                else f"HOLD_{channel}_NOTCH_CONTOUR_UNOBSERVED"
            ),
            "holdScope": None if accepted else f"{channel}_NOTCH_CONTOUR_PRESENTATION_ONLY",
            "fullShoulderToShoulderPathExists": maximum_missing == 0,
            "boundedGapShoulderToShoulderPathExists": True,
            "orangeEligible": accepted,
            "orangePixelCount": int(np.count_nonzero(full_observed)) if accepted else 0,
            "selectedNativePixelCount": int(np.count_nonzero(full_observed)),
            "expectedSpanColumnCount": int(columns.size),
            "predecessorMissingColumnCountInSpan": int(
                np.count_nonzero(~predecessor_observed[columns])
            ),
            "coverageFraction": coverage,
            "maximumMissingRunSamples": maximum_missing,
            "continuousEveryColumn": maximum_missing == 0,
            "missingColumnsRenderedOrInterpolated": False,
            "selectedPathManufacturedMorphologyRequalified": False,
            "manufacturedCandidateEligibilitySource": "UNCHANGED_R18_DEEP_FRONTIER_BF_DF_PAIR",
            "orangeRole": "NATIVE_CONTOUR_CORROBORATION_OF_ALREADY_PAIRED_NOTCH_NOT_STANDALONE_SELECTOR",
            "maximumAdjacentSlopePxPerSample": maximum_slope,
            "maximumRadialJumpPxPerLink": maximum_radial_jump,
            "maximumOutwardWigglePxPerLink": maximum_outward,
            "tipDepthThresholdPx": threshold,
            "tipDepthPx": tip_depth,
            "tipCenterDeltaSamples": int(signed_center_distance[meeting_position]),
            "gradientNormalAlignment": gradient,
            "gradientAlignmentGateRole": "POPULATION_LEVEL_PATH_CORROBORATION_NOT_PER_NODE_ORANGE_SELECTOR",
            "orangeNodeEligibility": "EACH_NODE_IS_R18_FRONTIER_SUPPORTED_WITH_POSITIVE_RAW_AND_ENHANCED_RADIAL_TRANSITION",
            "selectedTransitionResponse": {
                "population": "SELECTED_NATIVE_PATH_NODES",
                "rawOutsideInMinimum": float(np.min(raw_response)),
                "rawOutsideInP10": float(np.percentile(raw_response, 10.0)),
                "rawOutsideInMedian": float(np.median(raw_response)),
                "enhancedOutsideInMinimum": float(np.min(enhanced_response)),
                "enhancedOutsideInP10": float(np.percentile(enhanced_response, 10.0)),
                "enhancedOutsideInMedian": float(np.median(enhanced_response)),
            },
            "allSelectedPixelsNativeSupported": True,
            "inwardLimitTouchCount": inward_limit,
        }
    )
    return {"path": full_path, "observed": full_observed, "accepted": accepted, "metrics": base_metrics}


def analyze_fixed_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    physical = _analyze_r18(*args, **kwargs)
    transition = r18.transition_map(args[0], args[1])
    physical["_r21Transition"] = transition
    physical["evidence"].update(
        {
            "r21NotchContourAlgorithm": "BIDIRECTIONAL_NATIVE_SUPPORT_GRAPH_FROM_MEASURED_NORMAL_BEVEL_SHOULDERS",
            "r21TemplateModelUsed": False,
            "r21CurveFitUsedToPlacePixels": False,
            "r21CandidateSelectorChanged": False,
            "r21PostResultSelectorRelaxationPerformed": False,
        }
    )
    return physical


def pair_notch_candidates(bf: dict[str, Any], df: dict[str, Any], params: Any) -> dict[str, Any]:
    result = _pair_r18(bf, df, params)
    if result["eligiblePairCount"] != 1 or not result["state"].startswith("DIAGNOSTIC_UNIQUE_"):
        return result
    pair = result["eligiblePairs"][0]
    predecessor_observed = {
        "BF": bf["pixelEdgeTraceObservedColumns"].copy(),
        "DF": df["pixelEdgeTraceObservedColumns"].copy(),
    }
    records = {
        "BF": select_native_shoulder_path(
            bf,
            bf["_r21Transition"],
            int(pair["bfCandidateIndex"]),
            "BF",
            predecessor_observed["BF"],
        ),
        "DF": select_native_shoulder_path(
            df,
            df["_r21Transition"],
            int(pair["dfCandidateIndex"]),
            "DF",
            predecessor_observed["DF"],
        ),
    }
    for role, physical, key in (
        ("BF", bf, "bfCandidateIndex"),
        ("DF", df, "dfCandidateIndex"),
    ):
        index = int(pair[key])
        record = records[role]
        paired_columns = physical["pairedNotchColumns"].copy()
        trace_path = physical["normalBevelTracePath"].copy()
        trace_observed = physical["normalBevelTraceObservedColumns"].copy()
        trace_path[paired_columns] = np.nan
        trace_observed[paired_columns] = False
        selected = record["observed"].copy() if record["accepted"] else np.zeros_like(paired_columns)
        need(
            not bool(np.any(selected & ~predecessor_observed[role])),
            "R21 contour attempted to clear predecessor missing evidence",
        )
        trace_path[selected] = record["path"][selected]
        trace_observed[selected] = True
        physical["notchProposalTracePath"] = physical["deepNotchTracePath"].copy()
        physical["notchProposalTraceObservedColumns"] = physical[
            "deepNotchTraceObservedColumns"
        ].copy()
        physical["deepNotchTracePath"] = record["path"].copy() if record["accepted"] else np.full_like(record["path"], np.nan)
        physical["deepNotchTraceObservedColumns"] = selected.copy()
        physical["deepNotchTraceTouchesInwardLimitColumns"] = selected & np.isclose(
            physical["deepNotchTracePath"], r18.SEARCH_MIN_OFFSET_PX, rtol=0.0, atol=1.0e-6
        )
        physical["pixelEdgeTracePath"] = trace_path
        physical["pixelEdgeTraceObservedColumns"] = trace_observed
        physical["pixelEdgePairedNotchColumns"] = selected
        physical["pairedNotchEvidenceColumns"] = selected.copy()
        physical["notch"]["candidates"][index]["r21NativeShoulderContour"] = record["metrics"]
        physical["evidence"].update(
            {
                "pairedNotchNativeShoulderPath": record["metrics"],
                "pixelEdgeDisplayedTraceComposition": (
                    "NORMAL_BEVEL_OUTSIDE_PAIR_CONNECTED_NATIVE_SHOULDER_PATH_INSIDE_PAIR"
                    if record["accepted"]
                    else "NORMAL_BEVEL_OUTSIDE_PAIR_GAP_INSIDE_UNOBSERVED_CONTOUR_HOLD"
                ),
                "pixelEdgeDisplayedObservedColumnCount": int(np.count_nonzero(trace_observed)),
                "pixelEdgePairedNotchObservedColumnCount": int(np.count_nonzero(selected)),
                "pairedNotchTraceTouchesInwardLimitColumnCount": int(
                    np.count_nonzero(physical["deepNotchTraceTouchesInwardLimitColumns"])
                ),
                "pairedNotchPoseEnvelopeRetainedWhenContourHeld": True,
                "crossChannelPixelCoordinateTransferPerformed": False,
            }
        )
    df_metrics = records["DF"]["metrics"]
    bf_metrics = records["BF"]["metrics"]
    df_candidate = df["notch"]["candidates"][int(pair["dfCandidateIndex"])]
    df_pose_available = bool(
        records["DF"]["accepted"]
        and result["channelCircleComparison"]["qualified"]
        and result["eligiblePairCount"] == 1
    )
    result.update(
        {
            "state": "DIAGNOSTIC_UNIQUE_R21_SAME_CHUCK_NOTCH_POSE_WITH_CHANNEL_LOCAL_CONTOURS",
            "contourState": (
                "PASS_BOTH_CHANNEL_NATIVE_CONTOURS"
                if records["BF"]["accepted"] and records["DF"]["accepted"]
                else "HOLD_ONE_OR_MORE_CHANNEL_NATIVE_CONTOURS_UNOBSERVED"
            ),
            "bfContourState": bf_metrics["reviewState"],
            "dfContourState": df_metrics["reviewState"],
            "dfSameChuckPoseBound": {
                "state": (
                    "AVAILABLE_DIAGNOSTIC_ONLY"
                    if df_pose_available
                    else "HOLD_DF_CONTOUR_UNOBSERVED"
                ),
                "centerAngleDegrees": float(df_candidate["centerAngleDegrees"]),
                "source": "R18_DF_CANDIDATE_CENTER_GATED_BY_R21_DF_NATIVE_CONTOUR_AND_UNIQUE_PAIR",
                "simultaneousSameChuckBasis": "OPERATOR_CONFIRMED_ACQUISITION_DOMAIN_FACT",
                "bfPixelCoordinatesTransferred": False,
            },
            "fiducialRegistrationPoseInputState": (
                "AVAILABLE_DIAGNOSTIC_ONLY_FRESH_ALIGNMENT_TRANSFER_GATE_REQUIRED"
                if df_pose_available
                else "HOLD_DF_POSE_INPUT_UNAVAILABLE"
            ),
            "bfContourHoldAutomaticallyBlocksFutureFiducialRegistration": False,
            "freshFiducialAlignmentTransferGateRequired": True,
            "futureRegistrationAuthorityGranted": False,
            "reviewTraceTemplateSelectionPerformed": False,
            "notchPoseSelectionPerformed": False,
            "candidateSelectionPerformed": False,
            "holdClearancePerformed": False,
            "crossChannelPixelCoordinateTransferPerformed": False,
        }
    )
    return result


def dedicated_notch_review(
    contour_overlay: np.ndarray,
    contour_mask: np.ndarray,
    offsets: np.ndarray,
    paired_columns: np.ndarray,
    paired_trace_path: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, dict[str, Any]]:
    if bool(np.any(paired_columns)):
        return _dedicated_notch_review_r18(
            contour_overlay, contour_mask, offsets, paired_columns, paired_trace_path
        )
    rows = (offsets >= -r18.NOTCH_REVIEW_INWARD_PX) & (offsets <= r18.NOTCH_REVIEW_OUTWARD_PX)
    shape = (
        int(np.count_nonzero(rows)) + r18.NOTCH_REVIEW_HEADER_PX,
        2 * r18.NOTCH_REVIEW_HALF_WIDTH_COLUMNS + 1,
        3,
    )
    hold = np.zeros(shape, dtype=np.uint8)
    cv2.putText(
        hold,
        "HOLD: PAIRED POSE EXISTS; CHANNEL CONTOUR UNOBSERVED; NO ORANGE",
        (7, 24),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.38,
        (255, 255, 255),
        1,
        cv2.LINE_8,
    )
    return hold, np.zeros(shape[:2], dtype=np.uint8), {
        "state": "HOLD_PAIRED_POSE_CHANNEL_CONTOUR_UNOBSERVED_REVIEW",
        "pairedTraceEvidenceCount": 0,
        "pairedTraceEvidenceVisibleCount": 0,
        "pairedTraceEvidenceClippedCount": 0,
        "resamplingPerformed": False,
        "pathCenteredWarpPerformed": False,
        "statusBarsRendered": False,
        "uniquePairPoseRetained": True,
        "orangeContourSuppressed": True,
    }


def render(root: Path, pair_id: str, channel: str, measured: dict[str, Any]) -> dict[str, Any]:
    physical = measured["physicalBoundary"]
    metrics = physical["evidence"]["pairedNotchNativeShoulderPath"]
    render_physical = dict(physical)
    render_physical["pairedNotchColumns"] = (
        physical["pixelEdgePairedNotchColumns"]
        & np.isfinite(physical["pixelEdgeTracePath"])
    )
    render_measured = dict(measured)
    render_measured["physicalBoundary"] = render_physical
    assets = _render_r19(root, pair_id, channel, render_measured)
    assets["notch_review"]["r21ContourReviewState"] = metrics["reviewState"]
    assets["notch_review"]["orangeEligible"] = bool(metrics["orangeEligible"])
    assets["notch_review"]["pairPoseEnvelopeRetainedInSummary"] = True
    assets["paired_notch_trace_mask"]["r21ExpectedOrangePixelCount"] = int(
        metrics["orangePixelCount"]
    )
    return assets


def preflight_lineage() -> None:
    need(
        R20_SUMMARY_PATH.is_file() and sha256(R20_SUMMARY_PATH) == R20_SUMMARY_SHA256,
        "R21 requires the exact hash-pinned R20 diagnostic summary before output",
    )
    baseline_path = r19.R18_SUMMARY_PATH
    need(
        baseline_path.is_file() and sha256(baseline_path) == r19.R18_SUMMARY_SHA256,
        "R21 requires the exact hash-pinned R18 result summary before output",
    )
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    r20_summary = json.loads(R20_SUMMARY_PATH.read_text(encoding="utf-8"))
    need(
        baseline.get("detectorRevision") == "R18"
        and r20_summary.get("detectorRevision") == "R20"
        and bool(baseline.get("reviewOnly"))
        and bool(r20_summary.get("reviewOnly")),
        "R21 lineage is not the exact review-only R18/R20 diagnostic chain",
    )
    for document, label in ((baseline, "R18"), (r20_summary, "R20")):
        for key in (
            "trainingEligible",
            "xmlEligible",
            "productionEligible",
            "providerActivated",
            "sourceMutationPerformed",
            "existingTaskOrProcessActionPerformed",
            "holdClearancePerformed",
        ):
            need(not bool(document.get(key)), f"R21 {label} lineage authority forbids {key}")
    baseline_ids = [row["safeId"] for row in baseline["results"]]
    r20_ids = [row["safeId"] for row in r20_summary["results"]]
    need(
        len(baseline_ids) == 4
        and len(set(baseline_ids)) == 4
        and baseline_ids == r20_ids,
        "R21 R18/R20 four-case identity order differs",
    )


def upgrade_summary(summary: dict[str, Any]) -> None:
    need(
        R20_SUMMARY_PATH.is_file() and sha256(R20_SUMMARY_PATH) == R20_SUMMARY_SHA256,
        "R21 requires the exact hash-pinned R20 diagnostic summary",
    )
    baseline_path = r19.R18_SUMMARY_PATH
    need(
        baseline_path.is_file() and sha256(baseline_path) == r19.R18_SUMMARY_SHA256,
        "R21 requires the exact hash-pinned R18 result summary",
    )
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    r20_summary = json.loads(R20_SUMMARY_PATH.read_text(encoding="utf-8"))
    need(
        len(summary["results"]) == len(baseline["results"]) == len(r20_summary["results"]),
        "R21/R18/R20 result cardinality differs",
    )
    preserved_roles = (
        "full_clean",
        "full_enhanced",
        "outer_circle_mask",
        "inner_circle_mask",
        "circle_only_full_review",
        "accepted_outer_pixel_mask",
        "predecessor_hold_mask",
        "exterior_obstruction_mask",
        "ambiguous_inward_mask",
    )
    mismatch_count = removed_hold_pixels = orange_mask_mismatch_count = 0
    held_orange_pixels = 0
    trace_rows: list[dict[str, Any]] = []
    for new_result, old_result, r20_result in zip(
        summary["results"], baseline["results"], r20_summary["results"]
    ):
        need(
            new_result["safeId"] == old_result["safeId"] == r20_result["safeId"],
            "R21/R18/R20 case identity differs",
        )
        channel_holds = 0
        channel_contour_eligible: dict[str, bool] = {}
        for channel in ("BF", "DF"):
            new_channel = new_result["channels"][channel]
            old_channel = old_result["channels"][channel]
            mismatch_count += sum(
                new_channel["assets"][role]["sha256"] != old_channel["assets"][role]["sha256"]
                for role in preserved_roles
            )
            old_missing = cv2.imread(
                old_channel["assets"]["missing_pixel_edge_trace_mask"]["path"], cv2.IMREAD_GRAYSCALE
            )
            new_missing = cv2.imread(
                new_channel["assets"]["missing_pixel_edge_trace_mask"]["path"], cv2.IMREAD_GRAYSCALE
            )
            orange_mask = cv2.imread(
                new_channel["assets"]["paired_notch_trace_mask"]["path"], cv2.IMREAD_GRAYSCALE
            )
            need(
                old_missing is not None
                and new_missing is not None
                and orange_mask is not None
                and old_missing.shape == new_missing.shape == orange_mask.shape,
                "R21 cannot verify hold/orange raster evidence",
            )
            removed_hold_pixels += int(np.count_nonzero((old_missing > 0) & (new_missing == 0)))
            trace = new_channel["physicalBoundary"]["pairedNotchNativeShoulderPath"]
            actual_orange = int(np.count_nonzero(orange_mask))
            orange_mask_mismatch_count += int(actual_orange != int(trace["orangePixelCount"]))
            contour_present = bool(trace["orangeEligible"] and actual_orange > 0)
            channel_contour_eligible[channel] = contour_present
            new_channel["pairedNotchEvidencePresent"] = contour_present
            if not bool(trace["orangeEligible"]):
                held_orange_pixels += actual_orange
                channel_holds += 1
                new_channel["pairedNotchEvidenceObserved"] = False
                new_channel["pairedNotchEvidenceMatchesDeepTrace"] = False
            trace_rows.append({"case": int(new_result["ordinal"]), "channel": channel, **trace})
        new_result["state"] = (
            "HOLD_R21_DF_NOTCH_CONTOUR_UNOBSERVED_NO_REGISTRATION_POSE_INPUT"
            if not channel_contour_eligible["DF"]
            else (
                "HOLD_R21_BF_NOTCH_CONTOUR_UNOBSERVED_WITH_UNIQUE_SAME_CHUCK_DF_POSE"
                if not channel_contour_eligible["BF"]
                else (
                    "HOLD_R21_CYAN_GEOMETRY_UNVERIFIED_WITH_NATIVE_NOTCH_CONTOURS"
                    if not all(
                        new_result["channels"][channel]["cyanGeometryVerified"]
                        for channel in ("BF", "DF")
                    )
                    else "DIAGNOSTIC_ONLY_R21_NATIVE_NOTCH_CONTOURS_COMPLETE"
                )
            )
        )
    need(
        mismatch_count == 0
        and removed_hold_pixels == 0
        and orange_mask_mismatch_count == 0
        and held_orange_pixels == 0,
        "R21 changed protected R18 evidence, removed a hold, or rendered ineligible orange",
    )
    bf_holds = sum(
        row["channel"] == "BF" and not bool(row["orangeEligible"]) for row in trace_rows
    )
    df_holds = sum(
        row["channel"] == "DF" and not bool(row["orangeEligible"]) for row in trace_rows
    )
    _preservation.clear()
    _preservation.update(
        mismatchCount=mismatch_count,
        removedHoldPixels=removed_hold_pixels,
        orangeMaskMismatchCount=orange_mask_mismatch_count,
        heldOrangePixels=held_orange_pixels,
        bfHolds=bf_holds,
        dfHolds=df_holds,
        traceRows=trace_rows,
    )
    summary.update(
        {
            "schema": "argos_ocv03_annular_unwrap_native_shoulder_contour_diagnostic_r21_local_v1",
            "state": "COMPLETE_DIAGNOSTIC_ONLY_R21_LOCAL_ANNULAR_UNWRAP",
            "detectorRevision": "R21",
            "disposition": "DIAGNOSTIC_ONLY_EXISTING_CYAN_AND_CHANNEL_CONTOUR_HOLDS_RETAINED",
            "visualReviewState": "PENDING_OPERATOR_REVIEW",
            "r20FirstWriteLayer": {
                "path": str(R20_PATH),
                "bytes": R20_PATH.stat().st_size,
                "sha256": R20_SHA256,
            },
            "r19PresentationDependency": {
                "path": str(r20.R19_PATH),
                "bytes": r20.R19_PATH.stat().st_size,
                "sha256": r20.R19_SHA256,
                "usage": "R18_RENDER_PLUS_MEASURED_EDGE_ASSET_ONLY",
                "selectionAuthority": False,
                "ellipseTemplateSelectorUsed": False,
            },
            "r20DiagnosticPredecessor": {
                "path": str(R20_SUMMARY_PATH),
                "bytes": R20_SUMMARY_PATH.stat().st_size,
                "sha256": R20_SUMMARY_SHA256,
                "disposition": "DIAGNOSTIC_ONLY_METADATA_AND_REGRESSION_COMPARISON_NOT_PIXEL_SOURCE_OR_ACTIVATION_PARENT",
            },
            "r18BaselineEngine": {
                "path": str(r19.R18_PATH),
                "bytes": r19.R18_PATH.stat().st_size,
                "sha256": r19.R18_SHA256,
            },
            "r18BaselineSummary": {
                "path": str(baseline_path),
                "bytes": baseline_path.stat().st_size,
                "sha256": r19.R18_SUMMARY_SHA256,
            },
            "r18Preservation": {
                "assetHashMismatchCount": mismatch_count,
                "removedExistingHoldPixelCount": removed_hold_pixels,
                "orangeMaskCountMismatchCount": orange_mask_mismatch_count,
                "orangePixelCountOnHeldChannels": held_orange_pixels,
                "enhancementCyanYellowCircleOnlyAndExistingHoldsPreserved": True,
                "allExistingHoldsPreserved": True,
            },
            "nativeShoulderContourTraces": trace_rows,
            "bfContourHoldCount": bf_holds,
            "dfContourHoldCount": df_holds,
            "allDfNativeNotchContoursObserved": df_holds == 0,
            "templateModelUsed": False,
            "curveFitUsedToPlacePixels": False,
            "crossChannelPixelCoordinateTransferPerformed": False,
            "postResultSelectorRelaxationPerformed": False,
            "bfContourHoldAutomaticallyBlocksFutureFiducialRegistration": False,
            "futureFiducialRegistrationDependency": "FRESH_FIDUCIAL_ALIGNMENT_TRANSFER_GATE_REQUIRED_NO_AUTHORITY_GRANTED",
            "automaticHoldClearancePerformed": False,
        }
    )


def upgrade_gate(path: Path, gate: dict[str, Any]) -> None:
    need(bool(_preservation), "R21 summary upgrade did not precede gate upgrade")
    rows = _preservation["traceRows"]
    accepted_rows = [row for row in rows if bool(row["orangeEligible"])]
    gate.update(
        {
            "schema": "argos_ocv03_annular_unwrap_r21_local_detector_gate_v1",
            "state": (
                "HOLD_R21_LOCAL_CYAN_AND_CHANNEL_CONTOUR_REVIEW_REQUIRED"
                if _preservation["bfHolds"]
                or _preservation["dfHolds"]
                or gate["cyanGeometryHoldCount"]
                else "PASS_R21_LOCAL_DETECTOR_GATE"
            ),
            "summary": {
                "path": str(path.parent / "SUMMARY.json"),
                "sha256": r18.diagnostic.sha256(path.parent / "SUMMARY.json"),
            },
            "acceptedNativeContourCount": len(accepted_rows),
            "bfContourHoldCount": _preservation["bfHolds"],
            "dfContourHoldCount": _preservation["dfHolds"],
            "allDfNativeNotchContoursObserved": _preservation["dfHolds"] == 0,
            "allAcceptedContoursRequiredAndPresent": bool(accepted_rows) and all(
                int(row["orangePixelCount"]) > 0 for row in accepted_rows
            ),
            "allAcceptedContourPixelsNativeSupported": bool(accepted_rows) and all(
                bool(row["allSelectedPixelsNativeSupported"]) for row in accepted_rows
            ),
            "allPairedNotchEvidenceObserved": _preservation["bfHolds"] == 0
            and _preservation["dfHolds"] == 0,
            "allDedicatedNotchReviewsComplete": _preservation["bfHolds"] == 0
            and _preservation["dfHolds"] == 0,
            "heldChannelOrangePixelCount": _preservation["heldOrangePixels"],
            "orangeMaskCountMismatchCount": _preservation["orangeMaskMismatchCount"],
            "templateModelUsed": False,
            "curveFitUsedToPlacePixels": False,
            "selectedTraceInterpolationPerformed": False,
            "syntheticContourPixelCount": 0,
            "crossChannelPixelCoordinateTransferPerformed": False,
            "postResultSelectorRelaxationPerformed": False,
            "r18PreservedAssetHashMismatchCount": _preservation["mismatchCount"],
            "removedExistingHoldPixelCount": _preservation["removedHoldPixels"],
            "allExistingHoldsPreserved": True,
            "bfContourHoldAutomaticallyBlocksFutureFiducialRegistration": False,
            "freshFiducialAlignmentTransferGateRequired": True,
            "futureRegistrationAuthorityGranted": False,
            "automaticHoldClearancePerformed": False,
            "operatorVisualReviewRequired": True,
            "reviewOnly": True,
        }
    )


def main() -> int:
    need("--local-predecessor-summary" in sys.argv, "R21 is restricted to hash-pinned local review mode")
    preflight_lineage()
    original = {
        "analyze": r18.analyze_fixed_strip,
        "pair": r18.pair_notch_candidates,
        "render": r18.render,
        "dedicated": r18.dedicated_notch_review,
        "summary": r20.upgrade_summary,
        "gate": r20.upgrade_gate,
        "file": r18.__file__,
    }
    r18.analyze_fixed_strip = analyze_fixed_strip
    r18.pair_notch_candidates = pair_notch_candidates
    r18.render = render
    r18.dedicated_notch_review = dedicated_notch_review
    r20.upgrade_summary = upgrade_summary
    r20.upgrade_gate = upgrade_gate
    r18.__file__ = str(Path(__file__).resolve())
    try:
        return r20.main()
    finally:
        r18.analyze_fixed_strip = original["analyze"]
        r18.pair_notch_candidates = original["pair"]
        r18.render = original["render"]
        r18.dedicated_notch_review = original["dedicated"]
        r20.upgrade_summary = original["summary"]
        r20.upgrade_gate = original["gate"]
        r18.__file__ = original["file"]


if __name__ == "__main__":
    raise SystemExit(main())
