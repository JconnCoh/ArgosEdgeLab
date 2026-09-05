#!/usr/bin/env python3
"""R19 independent-channel, curve-consistent native notch-edge review."""

from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
import json
import math
import os
from pathlib import Path
import sys
from typing import Any

import cv2
import numpy as np


HERE = Path(__file__).resolve().parent
R18_SHA256 = "510F75463E8494A67442AEACBB7A16F71FE7B307EFEA9231F7CDD7FF6FE34317"
R18_SUMMARY_SHA256 = "3B7C3E32307351453F4F0F8A9146703F203B21906D619FE48252E8CAF78709B5"
R18_PATH = Path(os.environ.get("ARGOS_R18_ENGINE_PATH", HERE / "AnnularUnwrapDiagnosticOpenCvR18.py"))
R18_SUMMARY_PATH = Path(os.environ.get("ARGOS_R18_BASELINE_SUMMARY", ""))
CURVE_CORRIDOR_HALF_WIDTH_PX = 2.0
CURVE_MAX_ADJACENT_STEP_PX = 5.0
CURVE_DISCONTINUITY_PASSES = 32
BF_MINIMUM_TRACE_COVERAGE = 0.75
BF_MINIMUM_CENTRAL_COVERAGE = 0.75
BF_MAXIMUM_MISSING_RUN_SAMPLES = 19
DF_MINIMUM_TRACE_COVERAGE = 0.90
DF_MINIMUM_CENTRAL_COVERAGE = 0.90
DF_MAXIMUM_MISSING_RUN_SAMPLES = 8
TEMPLATE_WIDTH_SCALES = (0.72, 0.80, 0.88, 0.96, 1.04)
TEMPLATE_CENTER_SHIFTS = tuple(range(-16, 17, 4))
TEMPLATE_SHAPE_POWERS = (0.5, 0.75, 1.0)
TEMPLATE_AMPLITUDES_PX = tuple(range(40, 105, 4))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


if not R18_PATH.is_file() or sha256(R18_PATH) != R18_SHA256:
    raise RuntimeError("R19 requires the exact hash-pinned R18 detector")
SPEC = importlib.util.spec_from_file_location("argos_annular_diagnostic_r18_for_r19", R18_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load {R18_PATH}")
r18 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = r18
SPEC.loader.exec_module(r18)
need = r18.diagnostic.need
_analyze_r18 = r18.analyze_fixed_strip
_pair_r18 = r18.pair_notch_candidates
_render_r18 = r18.render
_run_local_r18 = r18.run_local_strip_review


def longest_missing(values: np.ndarray) -> int:
    best = current = 0
    for value in values:
        current = 0 if bool(value) else current + 1
        best = max(best, current)
    return best


def select_independent_curve_trace(physical: dict[str, Any], transition: dict[str, Any], index: int) -> dict[str, Any]:
    candidate = physical["notch"]["candidates"][index]
    envelope = np.asarray(physical["notch"]["candidateColumnSets"][index], dtype=np.int32)
    width = int(physical["outerPath"].size)
    target = int(round(float(candidate["centerAngleDegrees"]) * width / 360.0)) % width
    center0 = int(np.argmin(np.minimum((envelope - target) % width, (target - envelope) % width)))
    baseline = physical["outerPath"].astype(np.float32) - r18.EDGE_ZONE_INWARD_PX + float(
        physical["evidence"]["normalBevelTraceCalibratedDeltaPx"]
    )
    supported = transition["frontierSupported"]
    contrast = transition["enhancedContrast"]
    search_offsets = transition["searchOffsets"]
    best: dict[str, Any] | None = None
    for scale in TEMPLATE_WIDTH_SCALES:
        count = max(21, int(round(envelope.size * scale)) | 1)
        count = min(count, int(envelope.size) if envelope.size % 2 else int(envelope.size) - 1)
        half = count // 2
        for shift in TEMPLATE_CENTER_SHIFTS:
            center = center0 + shift
            left, right = center - half, center + half
            if left < 0 or right >= envelope.size:
                continue
            columns = envelope[left : right + 1]
            u = (np.arange(count, dtype=np.float32) - half) / max(float(half), 1.0)
            for power in TEMPLATE_SHAPE_POWERS:
                shape = np.maximum(0.0, 1.0 - u * u) ** power
                for amplitude in TEMPLATE_AMPLITUDES_PX:
                    model = baseline[columns] - float(amplitude) * shape
                    distance = np.abs(search_offsets[:, None] - model[None, :])
                    admissible = supported[:, columns] & (distance <= CURVE_CORRIDOR_HALF_WIDTH_PX)
                    observed = np.any(admissible, axis=0)
                    scores = np.where(admissible, -distance + contrast[:, columns] * 1.0e-5, -np.inf)
                    rows = np.argmax(scores, axis=0)
                    strengths = contrast[rows, columns][observed]
                    central = shape >= 0.55
                    coverage = float(np.mean(observed))
                    central_coverage = float(np.mean(observed[central]))
                    shoulder_coverage = float(np.mean(observed[~central]))
                    missing = longest_missing(observed)
                    median_strength = float(np.median(strengths)) if strengths.size else 0.0
                    score = coverage + 0.55 * central_coverage + 0.15 * shoulder_coverage - 0.003 * missing + 0.0002 * min(median_strength, 100.0)
                    key = (score, coverage, central_coverage, shoulder_coverage, -missing, median_strength, -abs(shift), -amplitude)
                    if best is None or key > best["key"]:
                        best = {"key": key, "columns": columns.copy(), "model": model.copy(), "observed": observed.copy(),
                                "rows": rows.copy(), "strength": contrast[rows, columns].copy(), "shape": shape.copy(),
                                "amplitude": amplitude, "power": power, "scale": scale, "shift": shift}
    need(best is not None, "R19 independent notch template bank produced no model")
    columns = best["columns"]
    observed = best["observed"]
    path_values = search_offsets[best["rows"]].astype(np.float32)
    for _ in range(CURVE_DISCONTINUITY_PASSES):
        jumps = observed[1:] & observed[:-1] & (np.abs(np.diff(path_values)) > CURVE_MAX_ADJACENT_STEP_PX)
        if not bool(np.any(jumps)):
            break
        remove = np.zeros(observed.size, dtype=bool)
        for right in np.flatnonzero(jumps) + 1:
            left = right - 1
            left_residual = abs(float(path_values[left] - best["model"][left]))
            right_residual = abs(float(path_values[right] - best["model"][right]))
            remove[right if (right_residual, -float(best["strength"][right])) >= (left_residual, -float(best["strength"][left])) else left] = True
        observed[remove] = False
    full_path = np.full(width, np.nan, dtype=np.float32)
    full_observed = np.zeros(width, dtype=bool)
    full_model = np.full(width, np.nan, dtype=np.float32)
    full_path[columns[observed]] = path_values[observed]
    full_observed[columns[observed]] = True
    full_model[columns] = best["model"]
    selected_columns = columns[observed]
    selected_rows = best["rows"][observed]
    need(bool(np.all(supported[selected_rows, selected_columns])), "R19 selected a pixel absent from native transition support")
    residual = np.abs(path_values[observed] - best["model"][observed])
    need(not residual.size or float(np.max(residual)) <= CURVE_CORRIDOR_HALF_WIDTH_PX + 1.0e-6,
         "R19 selected a pixel outside the frozen curve corridor")
    adjacent = observed[1:] & observed[:-1]
    adjacent_steps = np.abs(np.diff(path_values))[adjacent]
    metrics = {
        "state": "MEASURED_INDEPENDENT_CHANNEL_CURVE_TRACE",
        "templateFamily": "INDEPENDENT_ELLIPTIC_ARC_FIXED_BANK",
        "templateWidthScale": float(best["scale"]), "templateColumnCount": int(columns.size),
        "templateCenterShiftSamples": int(best["shift"]), "templateAmplitudeFromNormalPx": float(best["amplitude"]),
        "templateShapePower": float(best["power"]), "curveCorridorHalfWidthPx": CURVE_CORRIDOR_HALF_WIDTH_PX,
        "selectedSupportedPixelCount": int(np.count_nonzero(observed)), "coverageFraction": float(np.mean(observed)),
        "centralCoverageFraction": float(np.mean(observed[best["shape"] >= 0.55])),
        "maximumMissingRunSamples": longest_missing(observed),
        "maximumAdjacentStepPx": float(np.max(adjacent_steps)) if adjacent_steps.size else None,
        "maximumModelResidualPx": float(np.max(residual)) if residual.size else None,
        "allSelectedPixelsNativeSupported": True, "interpolationPerformed": False,
        "modelPixelsRendered": False, "crossChannelPixelCoordinateTransferPerformed": False,
    }
    return {"path": full_path, "observed": full_observed, "model": full_model, "metrics": metrics}


def analyze_fixed_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    physical = _analyze_r18(*args, **kwargs)
    transition = r18.transition_map(args[0], args[1])
    records = [select_independent_curve_trace(physical, transition, index)
               for index in range(len(physical["notch"]["candidates"]))]
    for candidate, record in zip(physical["notch"]["candidates"], records):
        candidate["r19IndependentCurveTrace"] = record["metrics"]
    physical["_r19CandidateTraces"] = records
    physical["evidence"]["r19CurveTemplateBankFrozenBeforeResult"] = True
    physical["evidence"]["r19CurveTemplateCandidateSelectionChangesNotchSelector"] = False
    return physical


def pair_notch_candidates(bf: dict[str, Any], df: dict[str, Any], params: Any) -> dict[str, Any]:
    result = _pair_r18(bf, df, params)
    if result["eligiblePairCount"] != 1 or not result["state"].startswith("DIAGNOSTIC_UNIQUE_"):
        return result
    pair = result["eligiblePairs"][0]
    for role, physical, key in (("BF", bf, "bfCandidateIndex"), ("DF", df, "dfCandidateIndex")):
        index = int(pair[key])
        record = physical["_r19CandidateTraces"][index]
        envelope = physical["pairedNotchColumns"]
        selected = envelope & record["observed"]
        trace_path = physical["normalBevelTracePath"].copy()
        trace_observed = physical["normalBevelTraceObservedColumns"].copy()
        trace_path[envelope] = np.nan
        trace_observed[envelope] = False
        trace_path[selected] = record["path"][selected]
        trace_observed[selected] = True
        physical["notchProposalTracePath"] = physical["deepNotchTracePath"].copy()
        physical["notchProposalTraceObservedColumns"] = physical["deepNotchTraceObservedColumns"].copy()
        physical["deepNotchTracePath"] = record["path"].copy()
        physical["deepNotchTraceObservedColumns"] = record["observed"].copy()
        physical["deepNotchTraceTouchesInwardLimitColumns"] = record["observed"] & np.isclose(
            record["path"], r18.SEARCH_MIN_OFFSET_PX, rtol=0.0, atol=1.0e-6
        )
        physical["pixelEdgeTracePath"] = trace_path
        physical["pixelEdgeTraceObservedColumns"] = trace_observed
        physical["pixelEdgePairedNotchColumns"] = selected
        physical["pairedNotchEvidenceColumns"] = selected.copy()
        metrics = dict(record["metrics"])
        if role == "BF":
            verified = metrics["coverageFraction"] >= BF_MINIMUM_TRACE_COVERAGE and metrics["centralCoverageFraction"] >= BF_MINIMUM_CENTRAL_COVERAGE and metrics["maximumMissingRunSamples"] <= BF_MAXIMUM_MISSING_RUN_SAMPLES
            metrics["reviewState"] = "PASS_BF_INDEPENDENT_NOTCH_CURVE_EVIDENCE" if verified else "HOLD_SPARSE_BF_CURVE_EVIDENCE_INDEPENDENT_NOTCH_IDENTIFIED"
            metrics["downstreamRole"] = "INDEPENDENT_NOTCH_IDENTIFICATION_AND_EVIDENCE_ONLY_NOT_CHIPOUT_DETECTION"
        else:
            verified = metrics["coverageFraction"] >= DF_MINIMUM_TRACE_COVERAGE and metrics["centralCoverageFraction"] >= DF_MINIMUM_CENTRAL_COVERAGE and metrics["maximumMissingRunSamples"] <= DF_MAXIMUM_MISSING_RUN_SAMPLES
            metrics["reviewState"] = "PASS_DF_INDEPENDENT_NOTCH_CURVE_AND_FUTURE_DAMAGE_EVIDENCE" if verified else "HOLD_DF_CURVE_EVIDENCE_INCOMPLETE"
            metrics["downstreamRole"] = "INDEPENDENT_NOTCH_IDENTIFICATION_AND_FUTURE_CHIPOUT_DETECTION"
        metrics["independentNotchCandidateIdentified"] = bool(
            physical["notch"]["candidates"][index]["manufacturedBfTopologyEligible" if role == "BF" else "manufacturedDfRadialEligible"]
        )
        physical["evidence"]["pairedNotchCurveTrace"] = metrics
        physical["evidence"]["pixelEdgeDisplayedTraceComposition"] = "NORMAL_BEVEL_OUTSIDE_PAIR_INDEPENDENT_CURVE_CONSISTENT_NATIVE_PIXELS_INSIDE_PAIR"
        physical["evidence"]["pixelEdgeDisplayedObservedColumnCount"] = int(np.count_nonzero(trace_observed))
        physical["evidence"]["pixelEdgePairedNotchObservedColumnCount"] = int(np.count_nonzero(selected))
        physical["evidence"]["pairedNotchTraceTouchesInwardLimitColumnCount"] = int(np.count_nonzero(physical["deepNotchTraceTouchesInwardLimitColumns"] & selected))
        physical["evidence"]["crossChannelPixelCoordinateTransferPerformed"] = False
    result["state"] = "DIAGNOSTIC_UNIQUE_INDEPENDENT_BF_DF_MANUFACTURED_NOTCH_PAIR_CURVE_REFINED"
    result["bfAndDfNotchesIdentifiedIndependently"] = True
    result["crossChannelPixelCoordinateTransferPerformed"] = False
    result["reviewTraceTemplateSelectionPerformed"] = True
    result["notchPoseSelectionPerformed"] = False
    return result


def render(root: Path, pair_id: str, channel: str, measured: dict[str, Any]) -> dict[str, Any]:
    assets = _render_r18(root, pair_id, channel, measured)
    physical, raw, offsets = measured["physicalBoundary"], measured["strip"], measured["offsets"]
    enhanced = r18.shadow_lift(raw)
    overlay = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    mask = np.zeros(raw.shape, dtype=np.uint8)
    r18.draw_evidence_points(overlay, mask, physical["pixelEdgeTracePath"], physical["pixelEdgeTraceObservedColumns"], offsets, (0, 255, 0))
    lime = np.all(overlay == np.asarray((0, 255, 0), dtype=np.uint8), axis=2)
    changed = np.any(overlay != cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR), axis=2)
    need(bool(np.array_equal(lime, mask > 0)) and bool(np.array_equal(changed, mask > 0)),
         "R19 measured-edge-only overlay contains undeclared pixels")
    review = r18.diagnostic.segmented_review(
        overlay, "FULL 180-IN/55-OUT INDEPENDENT CHANNEL MEASURED EDGE | LIME native supported pixels | GAPS unsupported | NO STATUS BARS"
    )
    stem = hashlib.sha256(pair_id.encode("utf-8")).hexdigest()[:16]
    for role, image in (("measured_edge_full_overlay", overlay), ("measured_edge_full_review", review), ("measured_edge_full_mask", mask)):
        path = root / f"{stem}_{channel.lower()}_annular_{role}.png"
        need(not path.exists() and cv2.imwrite(str(path), image), f"R19 failed to write {path}")
        assets[role] = {"path": str(path), "bytes": path.stat().st_size, "sha256": r18.diagnostic.sha256(path)}
    assets["measured_edge_full_review"]["reviewEligibility"] = "FULL_PERIMETER_INDEPENDENT_CHANNEL_BEVEL_NOTCH_TRACE"
    assets["circle_only_full_review"]["greenTraceIntentionallyExcluded"] = True
    assets["circle_only_full_review"]["useInsteadForMeasuredEdge"] = "measured_edge_full_review"
    return assets


def run_local_strip_review(*args: Any, **kwargs: Any) -> int:
    output = Path(args[-1])
    with contextlib.redirect_stdout(io.StringIO()):
        code = _run_local_r18(*args, **kwargs)
    need(code == 0, "R19 predecessor execution did not complete")
    need(R18_SUMMARY_PATH.is_file() and sha256(R18_SUMMARY_PATH) == R18_SUMMARY_SHA256,
         "R19 requires the exact hash-pinned R18 result summary")
    summary_path, gate_path = output / "SUMMARY.json", output / "LOCAL_DETECTOR_GATE.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    gate = json.loads(gate_path.read_text(encoding="utf-8"))
    baseline = json.loads(R18_SUMMARY_PATH.read_text(encoding="utf-8"))
    preserved_roles = ("full_clean", "full_enhanced", "outer_circle_mask", "inner_circle_mask", "circle_only_full_review",
                       "accepted_outer_pixel_mask", "predecessor_hold_mask", "exterior_obstruction_mask", "ambiguous_inward_mask")
    mismatch_count = removed_hold_pixels = 0
    trace_rows: list[dict[str, Any]] = []
    for new_result, old_result in zip(summary["results"], baseline["results"]):
        for channel in ("BF", "DF"):
            new_channel, old_channel = new_result["channels"][channel], old_result["channels"][channel]
            mismatch_count += sum(new_channel["assets"][role]["sha256"] != old_channel["assets"][role]["sha256"] for role in preserved_roles)
            old_missing = cv2.imread(old_channel["assets"]["missing_pixel_edge_trace_mask"]["path"], cv2.IMREAD_GRAYSCALE)
            new_missing = cv2.imread(new_channel["assets"]["missing_pixel_edge_trace_mask"]["path"], cv2.IMREAD_GRAYSCALE)
            need(old_missing is not None and new_missing is not None and old_missing.shape == new_missing.shape,
                 "R19 cannot verify predecessor missing-evidence holds")
            removed_hold_pixels += int(np.count_nonzero((old_missing > 0) & (new_missing == 0)))
            trace = new_channel["physicalBoundary"]["pairedNotchCurveTrace"]
            trace_rows.append({"case": int(new_result["ordinal"]), "channel": channel, **trace})
        new_result["state"] = new_result["state"].replace("R18", "R19")
    need(mismatch_count == 0 and removed_hold_pixels == 0, "R19 changed frozen R18 geometry/raster provenance or removed an existing hold")
    bf_sparse = sum(row["channel"] == "BF" and row["reviewState"].startswith("HOLD_") for row in trace_rows)
    df_holds = sum(row["channel"] == "DF" and row["reviewState"].startswith("HOLD_") for row in trace_rows)
    summary.update({
        "schema": "argos_ocv03_annular_unwrap_independent_curve_trace_diagnostic_r19_local_v1",
        "state": "COMPLETE_DIAGNOSTIC_ONLY_R19_LOCAL_ANNULAR_UNWRAP",
        "detectorRevision": "R19",
        "disposition": "DIAGNOSTIC_ONLY_EXISTING_CYAN_HOLDS_AND_SPARSE_BF_CONTOUR_HOLDS_RETAINED",
        "visualReviewState": "PENDING_OPERATOR_REVIEW",
        "r18BaselineEngine": {"path": str(R18_PATH), "bytes": R18_PATH.stat().st_size, "sha256": R18_SHA256},
        "r18BaselineSummary": {"path": str(R18_SUMMARY_PATH), "bytes": R18_SUMMARY_PATH.stat().st_size, "sha256": R18_SUMMARY_SHA256},
        "r18Preservation": {"assetHashMismatchCount": mismatch_count, "removedExistingHoldPixelCount": removed_hold_pixels,
                            "enhancementCyanYellowAndCircleOnlyPreserved": True, "allExistingHoldsPreserved": True},
        "independentChannelCurveTraces": trace_rows,
        "bfSparseCurveEvidenceHoldCount": bf_sparse,
        "dfCurveEvidenceHoldCount": df_holds,
        "bfAndDfNotchesIdentifiedIndependently": True,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "postResultSelectorRelaxationPerformed": False,
    })
    r18.diagnostic.atomic_json(summary_path, summary)
    gate.update({
        "schema": "argos_ocv03_annular_unwrap_r19_local_detector_gate_v1",
        "state": "HOLD_R19_LOCAL_CYAN_AND_SPARSE_BF_CURVE_REVIEW_REQUIRED" if bf_sparse or summary["cyanGeometryHoldCount"] else "PASS_R19_LOCAL_DETECTOR_GATE",
        "summary": {"path": str(summary_path), "sha256": r18.diagnostic.sha256(summary_path)},
        "allSelectedNotchPixelsNativeSupported": all(row["allSelectedPixelsNativeSupported"] for row in trace_rows),
        "maximumSelectedNotchModelResidualPx": max(row["maximumModelResidualPx"] for row in trace_rows if row["maximumModelResidualPx"] is not None),
        "allDfIndependentCurveEvidenceVerified": df_holds == 0,
        "bfSparseCurveEvidenceHoldCount": bf_sparse,
        "bfAndDfNotchesIdentifiedIndependently": True,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "selectedTraceInterpolationPerformed": False,
        "r18PreservedAssetHashMismatchCount": mismatch_count,
        "removedExistingHoldPixelCount": removed_hold_pixels,
        "allExistingHoldsPreserved": True,
        "reviewOnly": True,
    })
    r18.diagnostic.atomic_json(gate_path, gate)
    print(json.dumps({"state": gate["state"], "summaryPath": str(summary_path), "summarySha256": r18.diagnostic.sha256(summary_path),
                      "gatePath": str(gate_path), "gateSha256": r18.diagnostic.sha256(gate_path)}, separators=(",", ":")))
    return 0


r18.analyze_fixed_strip = analyze_fixed_strip
r18.pair_notch_candidates = pair_notch_candidates
r18.render = render
r18.run_local_strip_review = run_local_strip_review
r18.__file__ = str(Path(__file__).resolve())


def main() -> int:
    need("--local-predecessor-summary" in sys.argv, "R19 is restricted to hash-pinned local review mode")
    return r18.main()


if __name__ == "__main__":
    raise SystemExit(main())
