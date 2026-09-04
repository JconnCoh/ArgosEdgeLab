#!/usr/bin/env python3
"""R12 review-only annular unwrap with global enhancement and continuity holds."""

from __future__ import annotations

import hashlib
import importlib.util
import math
from pathlib import Path
import sys
from typing import Any

import cv2
import numpy as np


HERE = Path(__file__).resolve().parent
BASE_PATH = HERE / "AnnularUnwrapDiagnosticOpenCvR10.py"
SPEC = importlib.util.spec_from_file_location("argos_annular_diagnostic_r10_for_r12", BASE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load {BASE_PATH}")
diagnostic = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = diagnostic
SPEC.loader.exec_module(diagnostic)
diagnostic.FRONT = diagnostic.load(
    "argos_annular_front_l4_r12",
    HERE / "Run-O3F15L4FrontReconcile.py",
)

MAX_REFERENCE_STEP_PX = 1.0
CONTINUITY_PASSES = 4


def global_minmax(gray: np.ndarray) -> tuple[np.ndarray, dict[str, float]]:
    source_min = float(np.min(gray))
    source_max = float(np.max(gray))
    if source_max <= source_min:
        return gray.copy(), {"sourceMin": source_min, "sourceMax": source_max, "gain": 1.0}
    enhanced = cv2.normalize(gray, None, 0, 255, cv2.NORM_MINMAX)
    return enhanced, {
        "sourceMin": source_min,
        "sourceMax": source_max,
        "gain": 255.0 / (source_max - source_min),
    }


def limit_cyclic_step(path: np.ndarray) -> np.ndarray:
    limited = path.astype(np.float64).copy()
    for _ in range(CONTINUITY_PASSES):
        for column in range(1, limited.size):
            limited[column] = np.clip(
                limited[column],
                limited[column - 1] - MAX_REFERENCE_STEP_PX,
                limited[column - 1] + MAX_REFERENCE_STEP_PX,
            )
        limited[0] = np.clip(
            limited[0], limited[-1] - MAX_REFERENCE_STEP_PX, limited[-1] + MAX_REFERENCE_STEP_PX
        )
        for column in range(limited.size - 2, -1, -1):
            limited[column] = np.clip(
                limited[column],
                limited[column + 1] - MAX_REFERENCE_STEP_PX,
                limited[column + 1] + MAX_REFERENCE_STEP_PX,
            )
        limited[-1] = np.clip(
            limited[-1], limited[0] - MAX_REFERENCE_STEP_PX, limited[0] + MAX_REFERENCE_STEP_PX
        )
    return limited.astype(np.float32)


def refresh_path_evidence(
    evidence: dict[str, Any],
    original_path: np.ndarray,
    path: np.ndarray,
    measured: np.ndarray,
    tangential_pitch: float,
) -> None:
    changed = np.abs(path.astype(np.float64) - original_path.astype(np.float64)) > 0.5
    continuity_rejected = measured & changed
    measured[continuity_rejected] = False
    imputed = ~measured
    imputed_runs = diagnostic.runs(imputed)
    if len(imputed_runs) > 1 and bool(imputed[0]) and bool(imputed[-1]):
        imputed_runs = [
            np.concatenate((imputed_runs[-1], imputed_runs[0] + path.size)),
            *imputed_runs[1:-1],
        ]
    gap_rows = [
        {
            "startColumn": int(run[0]),
            "endColumnExclusive": int((run[-1] + 1) % path.size),
            "columnCount": int(run.size),
            "startDegrees": float(run[0] * 360.0 / path.size),
            "endDegrees": float(((run[-1] + 1) % path.size) * 360.0 / path.size),
            "centerDegrees": float(((run[0] + run.size * 0.5) % path.size) * 360.0 / path.size),
        }
        for run in sorted(imputed_runs, key=lambda item: item.size, reverse=True)[:8]
    ]
    jumps = np.abs(path - np.roll(path, 1))
    evidence.update(
        {
            "method": "GLOBAL_MINMAX_ENHANCED_REFERENCE_WITH_CYCLIC_CONTINUITY_HOLD",
            "preContinuityMaximumCyclicJumpPx": float(
                np.max(np.abs(original_path - np.roll(original_path, 1)))
            ),
            "maximumReferenceStepPxPerColumn": MAX_REFERENCE_STEP_PX,
            "continuityPassCount": CONTINUITY_PASSES,
            "continuityRejectedMeasuredColumnCount": int(np.count_nonzero(continuity_rejected)),
            "measuredColumnCount": int(np.count_nonzero(measured)),
            "measuredColumnFraction": float(np.mean(measured)),
            "imputedColumnCount": int(np.count_nonzero(imputed)),
            "maximumCircularImputedRunColumns": int(gap_rows[0]["columnCount"] if gap_rows else 0),
            "maximumCircularImputedRunArcPx": float(
                gap_rows[0]["columnCount"] * tangential_pitch if gap_rows else 0.0
            ),
            "largestImputedRuns": gap_rows,
            "maximumCyclicJumpPx": float(np.max(jumps)),
            "p95CyclicJumpPx": float(np.percentile(jumps, 95.0)),
            "continuityAdjustedColumnsEligibleAsMeasuredEvidence": False,
        }
    )


def unwrap(
    gray: np.ndarray,
    fit: dict[str, Any],
    crop: dict[str, Any],
    params: Any,
    cfg: dict[str, Any],
) -> dict[str, Any]:
    source_inward, source_outward = int(crop["inwardPx"]), int(crop["outwardPx"])
    maximum_inward = float(cfg["maximumInwardPx"])
    maximum_outward = float(cfg["maximumOutwardPx"])
    diagnostic.need(math.isfinite(maximum_inward) and maximum_inward > 0.0, "Invalid operational inward annulus")
    diagnostic.need(math.isfinite(maximum_outward) and maximum_outward > 0.0, "Invalid operational outward annulus")
    inward, outward = int(math.ceil(maximum_inward)), int(math.ceil(maximum_outward))
    smoothing = max(1, int(round(float(params.radial_smoothing_width_px))))
    smoothing += 1 - smoothing % 2
    span = max(1, int(round(float(params.radial_contrast_span_px))))
    halo = int(math.ceil(span * 0.5)) + smoothing // 2
    diagnostic.need(inward + halo <= source_inward, "Operational inward annulus exceeds source crop")
    diagnostic.need(outward + halo <= source_outward, "Operational outward annulus exceeds source crop")
    sampled_offsets = np.arange(-(inward + halo), outward + halo + 1, dtype=np.float32)
    samples = int(math.ceil(2.0 * math.pi * float(fit["radius"]) / diagnostic.TANGENTIAL_SAMPLE_PITCH_PX))
    diagnostic.need(4096 <= samples < 32767, "Native-pitch annular sample count exceeds OpenCV remap dimensions")
    tangential_pitch = 2.0 * math.pi * float(fit["radius"]) / samples
    angles = np.linspace(0.0, 2.0 * math.pi, samples, endpoint=False, dtype=np.float32)
    radii = float(fit["radius"]) + sampled_offsets
    map_x = float(fit["centerX"]) + radii[:, None] * np.cos(angles)[None, :]
    map_y = float(fit["centerY"]) + radii[:, None] * np.sin(angles)[None, :]
    sampled = cv2.remap(gray, map_x, map_y, cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    tracking_sampled, enhancement = global_minmax(sampled)

    smooth = cv2.blur(tracking_sampled.astype(np.float32), (1, smoothing))
    diagnostic.need(span < sampled.shape[0], "Radial contrast span consumes annular strip")
    contrast = smooth[:-span] - smooth[span:]
    middle_offsets = (sampled_offsets[:-span] + sampled_offsets[span:]) * 0.5
    analysis_rows = (middle_offsets >= -maximum_inward) & (middle_offsets <= maximum_outward)
    diagnostic.need(bool(np.any(analysis_rows)), "Operational annulus contains no contrast rows")
    contrast = contrast[analysis_rows]
    middle_offsets = middle_offsets[analysis_rows]
    visible_rows = (sampled_offsets >= -maximum_inward) & (sampled_offsets <= maximum_outward)
    strip = sampled[visible_rows]
    enhanced_strip = tracking_sampled[visible_rows]
    offsets = sampled_offsets[visible_rows]
    maxima = np.max(contrast, axis=0)
    floor = max(
        float(params.minimum_boundary_contrast),
        float(np.percentile(maxima, 20.0)) * float(params.outer_edge_relative_contrast),
    )
    thresholds = np.maximum(floor, maxima * float(params.outer_edge_relative_contrast))
    eligible = contrast >= thresholds[None, :]
    counts = np.count_nonzero(eligible, axis=0).astype(np.int32)
    separation = np.zeros(samples, dtype=np.float32)
    supported = counts > 0
    if np.any(supported):
        first = np.argmax(eligible, axis=0)
        last = eligible.shape[0] - 1 - np.argmax(eligible[::-1], axis=0)
        separation[supported] = middle_offsets[last[supported]] - middle_offsets[first[supported]]
    original_path, path_measured, path_evidence = diagnostic.cyclic_path(
        contrast,
        middle_offsets,
        float(params.minimum_boundary_contrast),
        float(params.outer_edge_relative_contrast),
        tangential_pitch,
    )
    path = limit_cyclic_step(original_path)
    refresh_path_evidence(path_evidence, original_path, path, path_measured, tangential_pitch)
    path_evidence["trackingEnhancement"] = "GLOBAL_MINMAX_ON_NATIVE_ANNULAR_SAMPLE"
    path_evidence["trackingEnhancementEvidence"] = enhancement

    edge_rows = (offsets >= -diagnostic.REFERENCE_CORE_INWARD_PX) & (offsets <= diagnostic.REFERENCE_CORE_OUTWARD_PX)
    edge_strip = strip[edge_rows]
    edge_enhanced_strip = enhanced_strip[edge_rows]
    edge_offsets = offsets[edge_rows]
    map_normalized_x = np.broadcast_to(np.arange(samples, dtype=np.float32)[None, :], (edge_offsets.size, samples)).copy()
    map_normalized_y = (-float(offsets[0]) + path[None, :] + edge_offsets[:, None]).astype(np.float32)
    normalized_strip = cv2.remap(
        strip,
        map_normalized_x,
        map_normalized_y,
        cv2.INTER_NEAREST,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0,
    )
    deep_rows = middle_offsets < -diagnostic.REFERENCE_CORE_INWARD_PX
    evidence = {
        "method": "NATIVE_PITCH_TWO_ZONE_ANNULAR_REFERENCE_DIAGNOSTIC_R12",
        "angleSampleCount": samples,
        "degreesPerSample": 360.0 / samples,
        "requestedLegacyAngleSampleCount": int(params.refine_angle_samples),
        "tangentialSamplePitchPx": tangential_pitch,
        "inwardPx": inward,
        "outwardPx": outward,
        "sourceCropInwardPx": source_inward,
        "sourceCropOutwardPx": source_outward,
        "filterHaloPx": halo,
        "analysisRadialRowCount": int(contrast.shape[0]),
        "contrastPopulation": "GLOBAL_MINMAX_ENHANCED_FULL_CHIPOUT_EVIDENCE_ENVELOPE",
        "diagnosticStripPopulation": "RAW_FIXED_FIT_REFERENCE_CORE_ONLY",
        "fixedFitCoreInwardPx": int(diagnostic.REFERENCE_CORE_INWARD_PX),
        "fixedFitCoreOutwardPx": int(diagnostic.REFERENCE_CORE_OUTWARD_PX),
        "fixedFitCoreRadialRowCount": int(edge_offsets.size),
        "nativeScaleReviewSegmentWidthPx": diagnostic.REVIEW_SEGMENT_WIDTH_PX,
        "nativeScaleReviewSegmentCount": int(math.ceil(samples / diagnostic.REVIEW_SEGMENT_WIDTH_PX)),
        "nativeScaleReviewResamplingPerformed": False,
        "unsegmentedNativeWidthAssetsEmitted": True,
        "chipoutEvidenceEnvelopeInwardPx": inward,
        "chipoutEvidenceEnvelopeOutwardPx": outward,
        "chipoutEnvelopeUsedForReferenceSelection": False,
        "deepEnvelopeTransitionRowCount": int(np.count_nonzero(deep_rows)),
        "deepEnvelopeSupportedColumnCount": int(np.count_nonzero(np.any(eligible[deep_rows], axis=0))),
        "radialInterpolation": "INTER_NEAREST",
        "fixedFitEdgeDiagnosticResamplingPerformed": False,
        "normalizedInspectionDiagnosticInterpolation": "INTER_NEAREST",
        "radialSmoothingWidthPx": smoothing,
        "radialContrastSpanPx": span,
        "adaptiveContrastFloor": floor,
        "supportedColumnCount": int(np.count_nonzero(counts)),
        "multipleTransitionColumnCount": int(np.count_nonzero(counts > 1)),
        "multipleTransitionColumnFraction": float(np.mean(counts > 1)),
        "maximumTransitionsInOneColumn": int(np.max(counts)),
        "p95TransitionCount": float(np.percentile(counts, 95.0)),
        "p95ExternalTransitionSeparationPx": float(np.percentile(separation, 95.0)),
        "notchSelectionPerformed": False,
        "holderClassificationPerformed": False,
        "referencePathUsedAsPrimaryDiagnosticWarp": False,
        "referencePathUsedAsSeparateNormalizedTextureDiagnosticWarp": True,
        "imputedReferenceSegmentsUsedAsNotchOrDamageEvidence": False,
        "cyclicPath": path_evidence,
    }
    return {
        "strip": strip,
        "enhancedStrip": enhanced_strip,
        "offsets": offsets,
        "edgeStrip": edge_strip,
        "edgeEnhancedStrip": edge_enhanced_strip,
        "normalizedStrip": normalized_strip,
        "edgeOffsets": edge_offsets,
        "paths": {"cyclic": path},
        "pathMeasured": path_measured,
        "evidence": evidence,
    }


def render(root: Path, pair_id: str, channel: str, measured: dict[str, Any]) -> dict[str, Any]:
    strip = measured["edgeStrip"]
    enhanced = measured["edgeEnhancedStrip"]
    overlay = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    mask = np.zeros(strip.shape, dtype=np.uint8)
    zero = int(np.argmin(np.abs(measured["edgeOffsets"])))
    cv2.line(overlay, (0, zero), (strip.shape[1] - 1, zero), (0, 200, 0), 1, cv2.LINE_8)
    cv2.line(mask, (0, zero), (strip.shape[1] - 1, zero), 255, 1, cv2.LINE_8)
    for supported, color in ((measured["pathMeasured"], (0, 0, 255)), (~measured["pathMeasured"], (255, 0, 255))):
        for run in diagnostic.runs(supported):
            if run.size >= 2:
                points = np.column_stack((run, np.rint(zero + measured["paths"]["cyclic"][run]).astype(np.int32))).astype(np.int32)
                cv2.polylines(overlay, [points], False, color, 1, cv2.LINE_8)
                cv2.polylines(mask, [points], False, 255, 1, cv2.LINE_8)
    legend = "GLOBAL MINMAX | GREEN fit | RED measured | MAGENTA held/interpolated"
    edge_review = diagnostic.segmented_review(overlay, legend)

    normalized_strip = measured["normalizedStrip"]
    normalized_enhanced, _ = global_minmax(normalized_strip)
    normalized_overlay = cv2.cvtColor(normalized_enhanced, cv2.COLOR_GRAY2BGR)
    normalized_zero = int(np.argmin(np.abs(measured["edgeOffsets"])))
    normalized_fixed = -measured["paths"]["cyclic"]
    fixed_points = np.column_stack((np.arange(normalized_strip.shape[1]), np.rint(normalized_zero + normalized_fixed).astype(np.int32))).astype(np.int32)
    cv2.polylines(normalized_overlay, [fixed_points], False, (0, 200, 0), 1, cv2.LINE_8)
    for supported, color in ((measured["pathMeasured"], (0, 0, 255)), (~measured["pathMeasured"], (255, 0, 255))):
        for run in diagnostic.runs(supported):
            if run.size >= 2:
                points = np.column_stack((run, np.full(run.size, normalized_zero))).astype(np.int32)
                cv2.polylines(normalized_overlay, [points], False, color, 1, cv2.LINE_8)
    normalized_review = diagnostic.segmented_review(
        normalized_overlay,
        "PATH-CENTERED DIAGNOSTIC ONLY; NOT NOTCH OR STRAIGHTENING PROOF",
    )

    full_clean = measured["strip"]
    full_enhanced = measured["enhancedStrip"]
    full_overlay = cv2.cvtColor(full_enhanced, cv2.COLOR_GRAY2BGR)
    full_zero = int(np.argmin(np.abs(measured["offsets"])))
    cv2.line(full_overlay, (0, full_zero), (full_clean.shape[1] - 1, full_zero), (0, 200, 0), 1, cv2.LINE_8)
    for supported, color in ((measured["pathMeasured"], (0, 0, 255)), (~measured["pathMeasured"], (255, 0, 255))):
        for run in diagnostic.runs(supported):
            if run.size >= 2:
                points = np.column_stack((run, np.rint(full_zero + measured["paths"]["cyclic"][run]).astype(np.int32))).astype(np.int32)
                cv2.polylines(full_overlay, [points], False, color, 1, cv2.LINE_8)
    damage_review = diagnostic.segmented_review(
        full_overlay,
        "FULL 180-IN/55-OUT GLOBAL MINMAX GEOMETRY; REFERENCE SELECTION EXCLUDED",
    )

    top = 28
    labeled_overlay = cv2.copyMakeBorder(overlay, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    labeled_mask = cv2.copyMakeBorder(mask, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    cv2.putText(labeled_overlay, legend, (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.43, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(labeled_mask, legend, (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.43, 255, 1, cv2.LINE_8)
    stem = hashlib.sha256(pair_id.encode("utf-8")).hexdigest()[:16]
    assets: dict[str, Any] = {}
    for role, image in (
        ("clean", strip),
        ("enhanced", enhanced),
        ("overlay", labeled_overlay),
        ("mask", labeled_mask),
        ("edge_review", edge_review),
        ("normalized_review", normalized_review),
        ("full_clean", full_clean),
        ("full_enhanced", full_enhanced),
        ("full_overlay", full_overlay),
        ("damage_review", damage_review),
    ):
        path = root / f"{stem}_{channel.lower()}_annular_{role}.png"
        diagnostic.need(cv2.imwrite(str(path), image), f"OpenCV write failed: {path}")
        assets[role] = {"path": str(path), "bytes": path.stat().st_size, "sha256": diagnostic.sha256(path)}
    return assets


diagnostic.unwrap = unwrap
diagnostic.render = render
diagnostic.__file__ = __file__


if __name__ == "__main__":
    raise SystemExit(diagnostic.main())
