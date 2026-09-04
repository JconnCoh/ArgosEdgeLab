#!/usr/bin/env python3
"""R14 outward-only bevel refinement on raw fixed-fit annular evidence."""

from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import sys
from typing import Any

import cv2
import numpy as np


HERE = Path(__file__).resolve().parent
BASE_PATH = HERE / "AnnularUnwrapDiagnosticOpenCvR13.py"
SPEC = importlib.util.spec_from_file_location("argos_annular_diagnostic_r13_for_r14", BASE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load {BASE_PATH}")
r13 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = r13
SPEC.loader.exec_module(r13)
diagnostic = r13.diagnostic

OUTER_PIXEL_MIN_DELTA_PX = 0
OUTER_PIXEL_MAX_DELTA_PX = 32
OUTER_SEARCH_MIN_DELTA_PX = 2
OUTER_SEARCH_MAX_DELTA_PX = 20
OUTER_GUARD_MIN_DELTA_PX = 24
OUTER_GUARD_MAX_DELTA_PX = 32
OUTER_GAMMA = 0.40
OUTER_TANGENTIAL_MEDIAN_PX = 7
OUTER_MIN_ENHANCED_SEPARATION = 15.0
OUTER_GUARD_MAD_MULTIPLIER = 3.0
OUTER_MIN_RAW_POLARITY = 3.0
OUTER_RADIAL_SUSTAIN_PX = 3
OUTER_TANGENTIAL_SUPPORT_PX = 31
OUTER_MIN_TANGENTIAL_SUPPORT = 0.50
OUTER_LOCAL_MEDIAN_PX = 31
OUTER_MAX_LOCAL_DEVIATION_PX = 3.0
OUTER_MAX_ABSOLUTE_OFFSET_PX = 16.0
HOLD_BAR_ROWS = 3


def outer_gamma(gray: np.ndarray) -> np.ndarray:
    """Boost low-light differences with a fixed monotonic, seam-free transform."""
    diagnostic.need(gray.dtype == np.uint8 and gray.ndim == 2, "Outer enhancement input must be uint8 grayscale")
    values = np.arange(256, dtype=np.float64) / 255.0
    lut = np.rint(255.0 * np.power(values, OUTER_GAMMA)).clip(0, 255).astype(np.uint8)
    return cv2.LUT(gray, lut)


def cyclic_horizontal_mean(mask: np.ndarray, width: int) -> np.ndarray:
    half = width // 2
    wrapped = np.concatenate((mask[:, -half:], mask, mask[:, :half]), axis=1)
    return cv2.blur(wrapped.astype(np.float32), (width, 1))[:, half:-half]


def cyclic_horizontal_median(gray: np.ndarray, width: int) -> np.ndarray:
    """Median-filter tangentially with an exact cyclic halo and no resampling."""
    diagnostic.need(width >= 1 and width % 2 == 1, "Cyclic median width must be positive and odd")
    if width == 1:
        return gray.copy()
    half = width // 2
    wrapped = np.concatenate((gray[:, -half:], gray, gray[:, :half]), axis=1)
    windows = np.lib.stride_tricks.sliding_window_view(wrapped, width, axis=1)
    return np.median(windows, axis=-1).astype(np.uint8)


def circular_runs(mask: np.ndarray) -> list[np.ndarray]:
    runs = diagnostic.runs(mask)
    if len(runs) > 1 and bool(mask[0]) and bool(mask[-1]):
        runs = [np.concatenate((runs[-1], runs[0] + mask.size)), *runs[1:-1]]
    return runs


def circular_largest_runs(mask: np.ndarray, limit: int = 8) -> list[dict[str, int]]:
    runs = circular_runs(mask)
    return [
        {
            "startColumn": int(run[0]),
            "endColumnExclusive": int((run[-1] + 1) % mask.size),
            "columnCount": int(run.size),
        }
        for run in sorted(runs, key=lambda item: item.size, reverse=True)[:limit]
    ]


def continuity_anchor(stable: np.ndarray, raw_lane: np.ndarray) -> int:
    """Choose a content-bound anchor that rotates with the cyclic strip."""
    runs = circular_runs(stable)
    diagnostic.need(bool(runs), "R14 continuity solver has no stable predecessor anchor")
    longest = max(run.size for run in runs)
    centers = [int((run[0] + run.size // 2) % stable.size) for run in runs if run.size == longest]
    if len(centers) == 1:
        return centers[0]
    fingerprints: list[tuple[bytes, int]] = []
    columns = np.arange(stable.size)
    for center in centers:
        order = (center + columns) % stable.size
        digest = hashlib.sha256()
        digest.update(np.ascontiguousarray(raw_lane[:, order]).tobytes())
        digest.update(np.ascontiguousarray(stable[order]).tobytes())
        fingerprints.append((digest.digest(), center))
    return max(fingerprints)[1]


def cyclic_evidence_path(
    base_path: np.ndarray,
    base_measured: np.ndarray,
    selected_delta: np.ndarray,
    selected_measured: np.ndarray,
    selected_support: np.ndarray,
    raw_lane: np.ndarray,
) -> dict[str, Any]:
    """Maximize exact evidence on a globally one-pixel-continuous cyclic path."""
    columns = base_path.size
    states = np.arange(OUTER_SEARCH_MAX_DELTA_PX, dtype=np.float64)
    state_count = states.size
    stable = base_measured & ~selected_measured
    if not np.any(base_measured) or not np.any(stable):
        return {
            "path": base_path.copy(),
            "measured": base_measured.copy(),
            "promoted": np.zeros(columns, dtype=bool),
            "rejected": selected_measured.copy(),
            "untouchedRejected": np.zeros(columns, dtype=bool),
            "chosenDelta": np.zeros(columns, dtype=np.float32),
            "anchorColumn": None,
            "state": "BASE_RETAINED_NO_STABLE_PREDECESSOR_ANCHOR",
        }

    anchor = continuity_anchor(stable, raw_lane)
    order = (anchor + np.arange(columns)) % columns
    delta_index = np.nan_to_num(selected_delta, nan=0.0).astype(np.int32)
    diagnostic.need(
        bool(np.all((delta_index[selected_measured] >= OUTER_SEARCH_MIN_DELTA_PX) & (delta_index[selected_measured] < OUTER_SEARCH_MAX_DELTA_PX))),
        "R14 selected candidate is outside the admissible continuity states",
    )
    measured_weight = np.int64(columns * 1000 + 1)
    negative = np.int64(-(2**60))
    back = np.zeros((columns, state_count), dtype=np.uint8)
    score = np.full(state_count, negative, dtype=np.int64)
    score[0] = measured_weight

    for sequence_index in range(1, columns):
        previous_column = int(order[sequence_index - 1])
        column = int(order[sequence_index])
        previous_absolute = base_path[previous_column].astype(np.float64) + states
        current_absolute = base_path[column].astype(np.float64) + states
        allowed = np.abs(previous_absolute[:, None] - current_absolute[None, :]) <= 1.000001
        choices = np.where(allowed, score[:, None], negative)
        predecessor = np.argmax(choices, axis=0)
        best = choices[predecessor, np.arange(state_count)]
        emission = np.zeros(state_count, dtype=np.int64)
        if selected_measured[column]:
            delta = int(delta_index[column])
            bonus = int(round(float(selected_support[column]) * 500.0)) + delta * 20
            emission[delta] = measured_weight + bonus
        elif base_measured[column]:
            emission[0] = measured_weight
        score = best + emission
        back[sequence_index] = predecessor.astype(np.uint8)

    last_column = int(order[-1])
    closes = np.abs((base_path[last_column].astype(np.float64) + states) - float(base_path[anchor])) <= 1.000001
    final_choices = np.where(closes, score, negative)
    state = int(np.argmax(final_choices))
    diagnostic.need(final_choices[state] > negative, "R14 cyclic continuity path cannot close")
    chosen_delta = np.empty(columns, dtype=np.int16)
    for sequence_index in range(columns - 1, 0, -1):
        chosen_delta[int(order[sequence_index])] = state
        state = int(back[sequence_index, state])
    diagnostic.need(state == 0, "R14 continuity backtrack changed its stable anchor")
    chosen_delta[anchor] = 0

    promoted = selected_measured & (chosen_delta == delta_index)
    retained_base = stable & (chosen_delta == 0)
    refined_measured = promoted | retained_base
    rejected = base_measured & ~refined_measured
    refined_path = (base_path.astype(np.float64) + chosen_delta.astype(np.float64)).astype(np.float32)
    return {
        "path": refined_path,
        "measured": refined_measured,
        "promoted": promoted,
        "rejected": rejected,
        "untouchedRejected": stable & ~retained_base,
        "chosenDelta": chosen_delta.astype(np.float32),
        "anchorColumn": anchor,
        "state": "PASS_MAXIMUM_EVIDENCE_CYCLIC_PATH",
    }


def outer_lane_candidates(measured: dict[str, Any], enhance: bool = True) -> dict[str, Any]:
    """Find the first sustained wafer pixel while scanning inward from exterior."""
    raw_full = measured["strip"]
    offsets = measured["offsets"].astype(np.float32)
    base_path = measured["paths"]["cyclic"].astype(np.float32)
    base_measured = measured["pathMeasured"].astype(bool)
    diagnostic.need(raw_full.dtype == np.uint8 and raw_full.ndim == 2, "Raw full annular strip must be uint8 grayscale")
    diagnostic.need(raw_full.shape[1] == base_path.size, "Outer lane path width mismatch")

    relative = np.arange(OUTER_PIXEL_MIN_DELTA_PX, OUTER_PIXEL_MAX_DELTA_PX + 1, dtype=np.float32)
    columns = raw_full.shape[1]
    map_x = np.broadcast_to(np.arange(columns, dtype=np.float32)[None, :], (relative.size, columns)).copy()
    map_y = (-float(offsets[0]) + base_path[None, :] + relative[:, None]).astype(np.float32)
    raw_lane = cv2.remap(
        raw_full,
        map_x,
        map_y,
        cv2.INTER_NEAREST,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0,
    )
    enhanced_lane = outer_gamma(raw_lane) if enhance else raw_lane.copy()
    selection_raw_lane = cyclic_horizontal_median(raw_lane, OUTER_TANGENTIAL_MEDIAN_PX)
    selection_enhanced_lane = outer_gamma(selection_raw_lane) if enhance else selection_raw_lane.copy()

    guard_rows = (relative >= OUTER_GUARD_MIN_DELTA_PX) & (relative <= OUTER_GUARD_MAX_DELTA_PX)
    guard = selection_enhanced_lane[guard_rows].astype(np.float32)
    guard_median = np.median(guard, axis=0)
    guard_mad = np.median(np.abs(guard - guard_median[None, :]), axis=0)
    separation_floor = np.maximum(
        OUTER_MIN_ENHANCED_SEPARATION,
        OUTER_GUARD_MAD_MULTIPLIER * guard_mad,
    )
    raw_guard = selection_raw_lane[guard_rows].astype(np.float32)
    raw_guard_median = np.median(raw_guard, axis=0)
    raw_guard_mad = np.median(np.abs(raw_guard - raw_guard_median[None, :]), axis=0)
    raw_guard_tolerance = np.maximum(
        OUTER_MIN_RAW_POLARITY,
        OUTER_GUARD_MAD_MULTIPLIER * raw_guard_mad,
    )

    search_deltas = np.arange(OUTER_SEARCH_MIN_DELTA_PX, OUTER_SEARCH_MAX_DELTA_PX + 1, dtype=np.int32)
    separation = np.empty((search_deltas.size, columns), dtype=np.float32)
    radial_qualified = np.zeros((search_deltas.size, columns), dtype=bool)
    for row_index, delta in enumerate(search_deltas):
        inward_rows = [int(delta - step - OUTER_PIXEL_MIN_DELTA_PX) for step in range(OUTER_RADIAL_SUSTAIN_PX)]
        immediate_outward = int(delta + 1 - OUTER_PIXEL_MIN_DELTA_PX)
        raw_outward_rows = [int(delta + step - OUTER_PIXEL_MIN_DELTA_PX) for step in range(1, 4)]
        enhanced_inward = selection_enhanced_lane[inward_rows].astype(np.float32)
        separation[row_index] = np.min(enhanced_inward - guard_median[None, :], axis=0)
        raw_inside = np.mean(selection_raw_lane[inward_rows].astype(np.float32), axis=0)
        raw_outside = np.mean(selection_raw_lane[raw_outward_rows].astype(np.float32), axis=0)
        raw_polarity = raw_inside - raw_outside
        wafer_separated_from_guard = (raw_inside - raw_guard_median) >= raw_guard_tolerance
        outside_matches_guard = np.abs(raw_outside - raw_guard_median) <= raw_guard_tolerance
        outward_below = (
            selection_enhanced_lane[immediate_outward].astype(np.float32) - guard_median
        ) < separation_floor
        radial_qualified[row_index] = (
            (separation[row_index] >= separation_floor)
            & (raw_polarity >= OUTER_MIN_RAW_POLARITY)
            & wafer_separated_from_guard
            & outside_matches_guard
            & outward_below
        )

    has_radial = np.any(radial_qualified, axis=0)
    reverse_index = np.argmax(radial_qualified[::-1], axis=0)
    selected_index = search_deltas.size - 1 - reverse_index
    selected_delta = search_deltas[selected_index].astype(np.float32)
    selected_delta[~has_radial] = np.nan
    touches_search_limit = has_radial & (selected_delta >= OUTER_SEARCH_MAX_DELTA_PX)

    one_hot = np.zeros_like(radial_qualified, dtype=np.uint8)
    valid_columns = np.flatnonzero(has_radial & ~touches_search_limit)
    one_hot[selected_index[valid_columns], valid_columns] = 1
    radial_neighborhood = cv2.dilate(one_hot, np.ones((3, 1), dtype=np.uint8))
    support = cyclic_horizontal_mean(radial_neighborhood, OUTER_TANGENTIAL_SUPPORT_PX)
    selected_support = np.zeros(columns, dtype=np.float32)
    selected_support[valid_columns] = support[selected_index[valid_columns], valid_columns]

    selected_absolute = base_path.astype(np.float64) + selected_delta.astype(np.float64)
    candidate_values = selected_absolute.copy()
    candidate_values[~(has_radial & ~touches_search_limit)] = np.nan
    half = OUTER_LOCAL_MEDIAN_PX // 2
    windows = np.lib.stride_tricks.sliding_window_view(
        np.pad(candidate_values, (half, half), mode="wrap"), OUTER_LOCAL_MEDIAN_PX
    )
    valid_counts = np.sum(np.isfinite(windows), axis=1)
    local_median = np.ma.median(np.ma.masked_invalid(windows), axis=1).filled(np.nan)
    local_consistent = (
        (valid_counts >= OUTER_LOCAL_MEDIAN_PX // 4)
        & np.isfinite(selected_absolute)
        & (np.abs(selected_absolute - local_median) <= OUTER_MAX_LOCAL_DEVIATION_PX)
    )
    qualified = (
        has_radial
        & ~touches_search_limit
        & (selected_support >= OUTER_MIN_TANGENTIAL_SUPPORT)
        & local_consistent
        & (selected_absolute <= OUTER_MAX_ABSOLUTE_OFFSET_PX)
    )
    # R14 deliberately cannot recover an R12/R13 hold.  A qualified candidate is
    # eligible only where the predecessor already had measured evidence.
    selected_measured = qualified & base_measured
    proposed_path = base_path.astype(np.float32).copy()
    proposed_path[selected_measured] = selected_absolute[selected_measured].astype(np.float32)
    continuity = cyclic_evidence_path(
        base_path,
        base_measured,
        selected_delta,
        selected_measured,
        selected_support,
        selection_raw_lane,
    )
    refined_path = continuity["path"]
    refined_measured = continuity["measured"]
    promoted = continuity["promoted"]
    continuity_rejected = continuity["rejected"]
    untouched_rejected = continuity["untouchedRejected"]
    recovered = np.zeros(columns, dtype=bool)
    still_held = ~refined_measured
    diagnostic.need(
        bool(np.all(~base_measured <= still_held)),
        "R14 must preserve every predecessor hold",
    )
    diagnostic.need(
        float(np.max(np.abs(refined_path - np.roll(refined_path, 1)))) <= 1.0,
        "R14 refined path exceeds cyclic one-pixel continuity",
    )
    retained_base = refined_measured & ~promoted
    diagnostic.need(
        bool(np.all(np.abs(refined_path[retained_base] - base_path[retained_base]) <= 1.0e-6)),
        "R14 moved an untouched predecessor measurement",
    )
    diagnostic.need(
        bool(np.all(np.abs(refined_path[promoted] - selected_absolute[promoted]) <= 1.0e-6)),
        "R14 promoted a continuity-adjusted candidate",
    )

    strength = np.rint(np.clip(separation, 0.0, 32.0) * (255.0 / 32.0)).astype(np.uint8)
    return {
        "rawLane": raw_lane,
        "enhancedLane": enhanced_lane,
        "selectionRawLane": selection_raw_lane,
        "selectionEnhancedLane": selection_enhanced_lane,
        "relativeOffsets": relative,
        "searchDeltas": search_deltas.astype(np.float32),
        "candidateStrength": strength,
        "candidatePath": selected_absolute.astype(np.float32),
        "candidateDelta": selected_delta,
        "candidateQualified": qualified,
        "candidateRecovered": recovered,
        "candidateSelectedMeasured": selected_measured,
        "candidateShiftedMeasured": promoted,
        "candidateContinuityRejected": continuity_rejected,
        "untouchedPredecessorRejected": untouched_rejected,
        "refinedDelta": continuity["chosenDelta"],
        "refinedPath": refined_path,
        "refinedMeasured": refined_measured,
        "basePath": base_path,
        "baseMeasured": base_measured,
        "stillHeld": still_held,
        "candidateSupport": selected_support,
        "evidence": {
            "method": "PATH_ANCHORED_OUTSIDE_IN_WITH_MAXIMUM_EVIDENCE_CYCLIC_CONTINUITY",
            "enhancement": "OUTER_LANE_PIXELWISE_GAMMA_0P40_WITH_CYCLIC_TANGENTIAL_MEDIAN7_SELECTION",
            "enhancementEnabled": bool(enhance),
            "enhancementIsCyclicTileFree": True,
            "selectionTangentialMedianWidthPx": OUTER_TANGENTIAL_MEDIAN_PX,
            "selectionTangentialMedianIsCyclic": True,
            "selectionTangentialResamplingPerformed": False,
            "innerEnhancementPerformed": False,
            "innerCandidateSearchPerformed": False,
            "minimumEnhancedPixelDeltaPx": OUTER_PIXEL_MIN_DELTA_PX,
            "minimumCandidateDeltaPx": OUTER_SEARCH_MIN_DELTA_PX,
            "maximumCandidateDeltaPx": OUTER_SEARCH_MAX_DELTA_PX,
            "guardMinimumDeltaPx": OUTER_GUARD_MIN_DELTA_PX,
            "guardMaximumDeltaPx": OUTER_GUARD_MAX_DELTA_PX,
            "minimumEnhancedSeparation": OUTER_MIN_ENHANCED_SEPARATION,
            "guardMadMultiplier": OUTER_GUARD_MAD_MULTIPLIER,
            "minimumRawPolarity": OUTER_MIN_RAW_POLARITY,
            "radialSustainPx": OUTER_RADIAL_SUSTAIN_PX,
            "tangentialSupportPx": OUTER_TANGENTIAL_SUPPORT_PX,
            "minimumTangentialSupportFraction": OUTER_MIN_TANGENTIAL_SUPPORT,
            "localMedianWidthPx": OUTER_LOCAL_MEDIAN_PX,
            "maximumLocalDeviationPx": OUTER_MAX_LOCAL_DEVIATION_PX,
            "maximumAbsoluteCandidateOffsetPx": OUTER_MAX_ABSOLUTE_OFFSET_PX,
            "radialCandidateColumnCount": int(np.count_nonzero(has_radial)),
            "searchLimitRejectedColumnCount": int(np.count_nonzero(touches_search_limit)),
            "qualifiedCandidateColumnCount": int(np.count_nonzero(qualified)),
            "measuredCandidateBeforeContinuityColumnCount": int(np.count_nonzero(selected_measured)),
            "outwardShiftedMeasuredColumnCount": int(np.count_nonzero(promoted)),
            "continuityRejectedMeasuredColumnCount": int(np.count_nonzero(continuity_rejected)),
            "untouchedPredecessorRejectedColumnCount": int(np.count_nonzero(untouched_rejected)),
            "selectedCandidateRejectedColumnCount": int(
                np.count_nonzero(selected_measured & ~promoted)
            ),
            "predecessorHeldColumnCount": int(np.count_nonzero(~base_measured)),
            "predecessorHeldColumnsPreserved": True,
            "heldColumnRecoveryPermitted": False,
            "newlyRecoveredHeldColumnCount": 0,
            "stillHeldColumnCount": int(np.count_nonzero(still_held)),
            "largestContinuityRejectedRuns": circular_largest_runs(continuity_rejected),
            "largestStillHeldRuns": circular_largest_runs(still_held),
            "preContinuityMaximumCyclicJumpPx": float(
                np.max(np.abs(proposed_path - np.roll(proposed_path, 1)))
            ),
            "maximumCyclicJumpPx": float(
                np.max(np.abs(refined_path - np.roll(refined_path, 1)))
            ),
            "continuitySolver": "MAXIMUM_MEASURED_EVIDENCE_THEN_OUTER_SUPPORT_CYCLIC_VITERBI",
            "continuitySolverState": continuity["state"],
            "continuityAnchorColumn": continuity["anchorColumn"],
            "candidatePromotedIntoPrimaryPath": bool(np.any(promoted)),
            "continuityAdjustedColumnsEligibleAsMeasuredEvidence": False,
            "continuityRejectedMaskSemantics": "TOP_BAR_COLUMN_SEMANTIC_NOT_GEOMETRY",
            "continuityRejectedTopBarRows": HOLD_BAR_ROWS,
            "postResultSelectorRelaxationPerformed": False,
            "notchSelectionPerformed": False,
            "holderClassificationPerformed": False,
        },
    }


def apply_outer_refinement(measured: dict[str, Any]) -> dict[str, Any]:
    """Apply R14 to an R13 measurement while retaining every predecessor hold."""
    outer = outer_lane_candidates(measured, enhance=True)
    measured["paths"]["cyclic"] = outer["refinedPath"]
    measured["pathMeasured"] = outer["refinedMeasured"]
    edge_offsets = measured["edgeOffsets"]
    columns = measured["strip"].shape[1]
    map_x = np.broadcast_to(
        np.arange(columns, dtype=np.float32)[None, :],
        (edge_offsets.size, columns),
    ).copy()
    map_y = (
        -float(measured["offsets"][0])
        + outer["refinedPath"][None, :]
        + edge_offsets[:, None]
    ).astype(np.float32)
    measured["normalizedStrip"] = cv2.remap(
        measured["strip"],
        map_x,
        map_y,
        cv2.INTER_NEAREST,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0,
    )
    measured["outerLane"] = outer
    measured["evidence"].update(
        {
            "method": "NATIVE_PITCH_TWO_ZONE_ANNULAR_REFERENCE_DIAGNOSTIC_R14",
            "outerLaneCandidateEvidence": outer["evidence"],
            "trackingPathChangedFromR13": bool(
                np.any(np.abs(outer["refinedPath"] - outer["basePath"]) > 0.5)
            ),
            "predecessorHeldColumnsPreserved": True,
            "heldColumnRecoveryPermitted": False,
            "innerEnhancementDeferred": True,
            "chipoutMeasurementsUseRawPixels": True,
            "pathCenteredNormalizedStripUse": "COMPUTATIONAL_DIAGNOSTIC_ONLY",
            "pathCenteredNormalizedStripGeometryReviewEligible": False,
            "geometryReviewAssetRole": "outer_candidate_full_review",
            "geometryReviewCoordinateFrame": "UNSHIFTED_FIXED_FIT_ANNULAR",
            "geometryReviewTangentialResamplingPerformed": False,
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
    return apply_outer_refinement(measured)


def render(root: Path, pair_id: str, channel: str, measured: dict[str, Any]) -> dict[str, Any]:
    assets = r13.render(root, pair_id, channel, measured)
    path_centered_warning = np.zeros((220, diagnostic.REVIEW_SEGMENT_WIDTH_PX, 3), dtype=np.uint8)
    warning_lines = (
        "PATH-CENTERED PIXEL VIEW WITHDRAWN",
        "Per-column radial recentering creates a wavy/mirage surround.",
        "It makes the selected edge self-fulfilling at the zero row.",
        "NOT VALID FOR EDGE, GEOMETRY, STRAIGHTENING, NOTCH, OR SEAM REVIEW.",
        "Use outer_candidate_full_review: FIXED-FIT / UNSHIFTED.",
    )
    for row, line in enumerate(warning_lines):
        cv2.putText(
            path_centered_warning,
            line,
            (24, 38 + row * 36),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.72,
            (255, 255, 255) if row not in (0, 3) else (0, 0, 255),
            2,
            cv2.LINE_8,
        )
    path_centered_path = Path(assets["normalized_review"]["path"])
    diagnostic.need(
        cv2.imwrite(str(path_centered_path), path_centered_warning),
        f"OpenCV write failed: {path_centered_path}",
    )
    assets["normalized_review"] = {
        "path": str(path_centered_path),
        "bytes": path_centered_path.stat().st_size,
        "sha256": diagnostic.sha256(path_centered_path),
        "reviewEligibility": "WITHDRAWN_WARNING_CARD_NO_PATH_CENTERED_PIXELS",
    }
    outer = measured["outerLane"]
    relative = outer["relativeOffsets"]
    base_path = outer["basePath"]
    base_measured = outer["baseMeasured"]
    recovered = outer["candidateRecovered"]
    shifted_measured = outer["candidateShiftedMeasured"]
    continuity_rejected = outer["candidateContinuityRejected"]
    still_held = outer["stillHeld"]
    overlay = cv2.cvtColor(outer["selectionEnhancedLane"], cv2.COLOR_GRAY2BGR)
    line_mask = np.zeros(outer["selectionEnhancedLane"].shape, dtype=np.uint8)
    enhancement_mask = np.full(outer["selectionEnhancedLane"].shape, 255, dtype=np.uint8)
    search_mask = np.zeros(outer["selectionEnhancedLane"].shape, dtype=np.uint8)
    rejected_mask = np.zeros(outer["selectionEnhancedLane"].shape, dtype=np.uint8)
    zero = int(np.flatnonzero(relative == 0)[0])
    search_rows = (relative >= OUTER_SEARCH_MIN_DELTA_PX) & (relative <= OUTER_SEARCH_MAX_DELTA_PX)
    search_mask[search_rows] = 255
    for run in diagnostic.runs(base_measured):
        if run.size >= 2:
            points = np.column_stack((run, np.full(run.size, zero))).astype(np.int32)
            cv2.polylines(overlay, [points], False, (0, 0, 255), 1, cv2.LINE_8)
    shifted_columns = np.flatnonzero(shifted_measured)
    shifted_rows = np.rint(
        outer["refinedDelta"][shifted_columns] - OUTER_PIXEL_MIN_DELTA_PX
    ).astype(np.int32)
    overlay[shifted_rows, shifted_columns] = (255, 255, 0)
    line_mask[shifted_rows, shifted_columns] = 255
    for run in diagnostic.runs(shifted_measured):
        if run.size >= 2:
            rows = np.rint(outer["refinedDelta"][run] - OUTER_PIXEL_MIN_DELTA_PX).astype(np.int32)
            points = np.column_stack((run, rows)).astype(np.int32)
            cv2.polylines(overlay, [points], False, (255, 255, 0), 1, cv2.LINE_8)
            cv2.polylines(line_mask, [points], False, 255, 1, cv2.LINE_8)
    recovered_columns = np.flatnonzero(recovered)
    recovered_rows = np.rint(
        outer["candidateDelta"][recovered_columns] - OUTER_PIXEL_MIN_DELTA_PX
    ).astype(np.int32)
    overlay[recovered_rows, recovered_columns] = (0, 255, 255)
    line_mask[recovered_rows, recovered_columns] = 255
    for run in diagnostic.runs(recovered):
        if run.size >= 2:
            rows = np.rint(outer["candidateDelta"][run] - OUTER_PIXEL_MIN_DELTA_PX).astype(np.int32)
            points = np.column_stack((run, rows)).astype(np.int32)
            cv2.polylines(overlay, [points], False, (0, 255, 255), 1, cv2.LINE_8)
            cv2.polylines(line_mask, [points], False, 255, 1, cv2.LINE_8)
    held_columns = np.flatnonzero(still_held)
    if held_columns.size:
        overlay[:HOLD_BAR_ROWS, held_columns] = (255, 0, 255)
    rejected_columns = np.flatnonzero(continuity_rejected)
    if rejected_columns.size:
        overlay[:HOLD_BAR_ROWS, rejected_columns] = (0, 128, 255)
        rejected_mask[:HOLD_BAR_ROWS, rejected_columns] = 255
    review = diagnostic.segmented_review(
        overlay,
        "PATH-CENTERED SELECTION LANE ONLY; NOT GEOMETRY PROOF | RED old | CYAN accepted outer | MAGENTA old hold | ORANGE continuity hold",
    )

    full = r13.review_clahe(measured["strip"])
    full_overlay = cv2.cvtColor(full, cv2.COLOR_GRAY2BGR)
    full_zero = int(np.argmin(np.abs(measured["offsets"])))
    for run in diagnostic.runs(base_measured):
        if run.size >= 2:
            rows = np.rint(full_zero + base_path[run]).astype(np.int32)
            cv2.polylines(full_overlay, [np.column_stack((run, rows)).astype(np.int32)], False, (0, 0, 255), 1, cv2.LINE_8)
    shifted_rows = np.rint(full_zero + outer["refinedPath"][shifted_columns]).astype(np.int32)
    full_overlay[shifted_rows, shifted_columns] = (255, 255, 0)
    for run in diagnostic.runs(shifted_measured):
        if run.size >= 2:
            rows = np.rint(full_zero + outer["refinedPath"][run]).astype(np.int32)
            cv2.polylines(full_overlay, [np.column_stack((run, rows)).astype(np.int32)], False, (255, 255, 0), 1, cv2.LINE_8)
    recovered_rows = np.rint(full_zero + outer["candidatePath"][recovered_columns]).astype(np.int32)
    full_overlay[recovered_rows, recovered_columns] = (0, 255, 255)
    for run in diagnostic.runs(recovered):
        if run.size >= 2:
            rows = np.rint(full_zero + outer["candidatePath"][run]).astype(np.int32)
            cv2.polylines(full_overlay, [np.column_stack((run, rows)).astype(np.int32)], False, (0, 255, 255), 1, cv2.LINE_8)
    if held_columns.size:
        full_overlay[:HOLD_BAR_ROWS, held_columns] = (255, 0, 255)
    if rejected_columns.size:
        full_overlay[:HOLD_BAR_ROWS, rejected_columns] = (0, 128, 255)
    full_review = diagnostic.segmented_review(
        full_overlay,
        "FIXED-FIT UNSHIFTED FULL CLAHE2; GEOMETRY/TRACKING REVIEW | RED old | CYAN accepted outer | MAGENTA old hold | ORANGE continuity hold",
    )

    strength = outer["candidateStrength"]
    strength_review = diagnostic.segmented_review(
        strength,
        "OUTER CANDIDATE STRENGTH 0..32 -> 0..255; SEARCH +2..+20; +20 REJECTED",
    )
    stem = hashlib.sha256(pair_id.encode("utf-8")).hexdigest()[:16]
    for role, image in (
        ("outer_lane_clean", outer["rawLane"]),
        ("outer_lane_enhanced", outer["enhancedLane"]),
        ("outer_lane_selection_enhanced", outer["selectionEnhancedLane"]),
        ("outer_enhancement_mask", enhancement_mask),
        ("outer_search_mask", search_mask),
        ("outer_candidate_mask", line_mask),
        ("outer_continuity_rejected_column_bar_mask", rejected_mask),
        ("outer_candidate_strength", strength),
        ("outer_candidate_strength_review", strength_review),
        ("outer_candidate_review", review),
        ("outer_candidate_full_review", full_review),
    ):
        path = root / f"{stem}_{channel.lower()}_annular_{role}.png"
        diagnostic.need(cv2.imwrite(str(path), image), f"OpenCV write failed: {path}")
        assets[role] = {
            "path": str(path),
            "bytes": path.stat().st_size,
            "sha256": diagnostic.sha256(path),
        }
    assets["outer_candidate_review"]["reviewEligibility"] = "SELECTION_DIAGNOSTIC_ONLY_NOT_GEOMETRY_EVIDENCE"
    assets["outer_candidate_full_review"]["reviewEligibility"] = "GEOMETRY_AND_TRACKING_REVIEW"
    return assets


diagnostic.unwrap = unwrap
diagnostic.render = render
diagnostic.__file__ = __file__


if __name__ == "__main__":
    raise SystemExit(diagnostic.main())
