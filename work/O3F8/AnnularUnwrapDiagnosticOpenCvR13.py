#!/usr/bin/env python3
"""R13 review-only annular unwrap with honest holds and local-contrast review."""

from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import sys
from typing import Any

import cv2
import numpy as np


HERE = Path(__file__).resolve().parent
BASE_PATH = HERE / "AnnularUnwrapDiagnosticOpenCvR12.py"
SPEC = importlib.util.spec_from_file_location("argos_annular_diagnostic_r12_for_r13", BASE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load {BASE_PATH}")
r12 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = r12
SPEC.loader.exec_module(r12)
diagnostic = r12.diagnostic

CLAHE_CLIP_LIMIT = 2.0
CLAHE_TILE_GRID = (16, 8)
HOLD_BAR_ROWS = 3


def review_clahe(gray: np.ndarray) -> np.ndarray:
    """Enhance review pixels locally without changing source or selection thresholds."""
    diagnostic.need(gray.dtype == np.uint8 and gray.ndim == 2, "CLAHE review input must be uint8 grayscale")
    return cv2.createCLAHE(
        clipLimit=CLAHE_CLIP_LIMIT,
        tileGridSize=CLAHE_TILE_GRID,
    ).apply(gray)


def unwrap(
    gray: np.ndarray,
    fit: dict[str, Any],
    crop: dict[str, Any],
    params: Any,
    cfg: dict[str, Any],
) -> dict[str, Any]:
    measured = r12.unwrap(gray, fit, crop, params, cfg)
    evidence = measured["evidence"]
    evidence.update(
        {
            "method": "NATIVE_PITCH_TWO_ZONE_ANNULAR_REFERENCE_DIAGNOSTIC_R13",
            "trackingEnhancementChangedFromR12": False,
            "reviewEnhancement": "CLAHE_CLIP2_GRID16X8",
            "reviewEnhancementAffectsReferenceSelection": False,
            "heldInterpolatedPathRenderedAcrossImage": False,
            "heldColumnsRenderedOnlyAsTopSemanticBar": True,
            "heldColumnSemanticBarRows": HOLD_BAR_ROWS,
            "cleanFullBandReviewEmitted": True,
            "notchSelectionPerformed": False,
            "holderClassificationPerformed": False,
            "postResultSelectorRelaxationPerformed": False,
        }
    )
    return measured


def reference_overlay(
    enhanced: np.ndarray,
    offsets: np.ndarray,
    path: np.ndarray,
    measured: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    overlay = cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)
    line_mask = np.zeros(enhanced.shape, dtype=np.uint8)
    hold_mask = np.zeros(enhanced.shape, dtype=np.uint8)
    zero = int(np.argmin(np.abs(offsets)))
    cv2.line(overlay, (0, zero), (enhanced.shape[1] - 1, zero), (0, 200, 0), 1, cv2.LINE_8)
    cv2.line(line_mask, (0, zero), (enhanced.shape[1] - 1, zero), 255, 1, cv2.LINE_8)
    for run in diagnostic.runs(measured):
        if run.size >= 2:
            points = np.column_stack((run, np.rint(zero + path[run]).astype(np.int32))).astype(np.int32)
            cv2.polylines(overlay, [points], False, (0, 0, 255), 1, cv2.LINE_8)
            cv2.polylines(line_mask, [points], False, 255, 1, cv2.LINE_8)
    held_columns = np.flatnonzero(~measured)
    if held_columns.size:
        overlay[:HOLD_BAR_ROWS, held_columns] = (255, 0, 255)
        hold_mask[:HOLD_BAR_ROWS, held_columns] = 255
    return overlay, line_mask, hold_mask


def normalized_overlay(measured: dict[str, Any]) -> np.ndarray:
    normalized = review_clahe(measured["normalizedStrip"])
    overlay = cv2.cvtColor(normalized, cv2.COLOR_GRAY2BGR)
    zero = int(np.argmin(np.abs(measured["edgeOffsets"])))
    cv2.line(overlay, (0, zero), (normalized.shape[1] - 1, zero), (0, 200, 0), 1, cv2.LINE_8)
    for run in diagnostic.runs(measured["pathMeasured"]):
        if run.size >= 2:
            points = np.column_stack((run, np.full(run.size, zero))).astype(np.int32)
            cv2.polylines(overlay, [points], False, (0, 0, 255), 1, cv2.LINE_8)
    held_columns = np.flatnonzero(~measured["pathMeasured"])
    if held_columns.size:
        overlay[:HOLD_BAR_ROWS, held_columns] = (255, 0, 255)
    return overlay


def render(root: Path, pair_id: str, channel: str, measured: dict[str, Any]) -> dict[str, Any]:
    edge_clean = measured["edgeStrip"]
    edge_enhanced = review_clahe(edge_clean)
    edge_overlay, line_mask, hold_mask = reference_overlay(
        edge_enhanced,
        measured["edgeOffsets"],
        measured["paths"]["cyclic"],
        measured["pathMeasured"],
    )
    edge_legend = "CLAHE2 | GREEN fixed fit | RED measured | MAGENTA top bar held; NO HELD PATH"
    edge_review = diagnostic.segmented_review(edge_overlay, edge_legend)

    normalized_review = diagnostic.segmented_review(
        normalized_overlay(measured),
        "PATH-CENTERED DIAGNOSTIC | RED measured at zero | MAGENTA top bar held",
    )

    full_clean = measured["strip"]
    full_enhanced = review_clahe(full_clean)
    full_overlay, _, _ = reference_overlay(
        full_enhanced,
        measured["offsets"],
        measured["paths"]["cyclic"],
        measured["pathMeasured"],
    )
    full_review = diagnostic.segmented_review(
        full_enhanced,
        "CLEAN FULL 180-IN/55-OUT CLAHE2 | NO TRACKING ANNOTATION | NOTCH/CHIPOUT/HOLDER CONTEXT",
    )
    damage_review = diagnostic.segmented_review(
        full_overlay,
        "FULL 180-IN/55-OUT CLAHE2 | RED measured | MAGENTA top bar held; NO HELD PATH",
    )

    top = 28
    labeled_overlay = cv2.copyMakeBorder(edge_overlay, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    labeled_mask = cv2.copyMakeBorder(line_mask, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    labeled_hold_mask = cv2.copyMakeBorder(hold_mask, top, 0, 0, 0, cv2.BORDER_CONSTANT)
    cv2.putText(labeled_overlay, edge_legend, (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.43, (255, 255, 255), 1, cv2.LINE_8)
    cv2.putText(labeled_mask, "GREEN-FIT + RED-MEASURED LINE MASK; HELD PATH EXCLUDED", (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.43, 255, 1, cv2.LINE_8)
    cv2.putText(labeled_hold_mask, "HELD-COLUMN TOP-BAR MASK; NOT NOTCH OR DAMAGE EVIDENCE", (7, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.43, 255, 1, cv2.LINE_8)

    stem = hashlib.sha256(pair_id.encode("utf-8")).hexdigest()[:16]
    assets: dict[str, Any] = {}
    for role, image in (
        ("clean", edge_clean),
        ("enhanced", edge_enhanced),
        ("overlay", labeled_overlay),
        ("mask", labeled_mask),
        ("hold_mask", labeled_hold_mask),
        ("edge_review", edge_review),
        ("normalized_review", normalized_review),
        ("full_clean", full_clean),
        ("full_enhanced", full_enhanced),
        ("full_overlay", full_overlay),
        ("full_review", full_review),
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
