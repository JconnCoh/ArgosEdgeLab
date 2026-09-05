#!/usr/bin/env python3
"""R20 first-write-safe wrapper for the R19 independent-channel detector."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
from typing import Any

import cv2
import numpy as np


HERE = Path(__file__).resolve().parent
R19_SHA256 = "AFD995353F36BA30078F42D0AB3D53D8B7FDDA20A649C3300A837944CE5CAE31"
R19_PATH = Path(os.environ.get("ARGOS_R19_ENGINE_PATH", HERE / "AnnularUnwrapDiagnosticOpenCvR19.py"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


if not R19_PATH.is_file() or sha256(R19_PATH) != R19_SHA256:
    raise RuntimeError("R20 requires the exact hash-pinned R19 algorithm layer")
SPEC = importlib.util.spec_from_file_location("argos_annular_diagnostic_r19_for_r20", R19_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot load {R19_PATH}")
r19 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = r19
SPEC.loader.exec_module(r19)
need = r19.need
_atomic_json = r19.r18.diagnostic.atomic_json
_preservation: dict[str, Any] = {}


def upgrade_summary(summary: dict[str, Any]) -> None:
    baseline_path = r19.R18_SUMMARY_PATH
    need(
        baseline_path.is_file() and sha256(baseline_path) == r19.R18_SUMMARY_SHA256,
        "R20 requires the exact hash-pinned R18 result summary",
    )
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    need(
        len(summary["results"]) == len(baseline["results"]),
        "R20/R18 result cardinality differs",
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
    mismatch_count = removed_hold_pixels = 0
    trace_rows: list[dict[str, Any]] = []
    for new_result, old_result in zip(summary["results"], baseline["results"]):
        need(
            new_result["safeId"] == old_result["safeId"],
            "R20/R18 case identity differs",
        )
        for channel in ("BF", "DF"):
            new_channel = new_result["channels"][channel]
            old_channel = old_result["channels"][channel]
            mismatch_count += sum(
                new_channel["assets"][role]["sha256"]
                != old_channel["assets"][role]["sha256"]
                for role in preserved_roles
            )
            old_missing = cv2.imread(
                old_channel["assets"]["missing_pixel_edge_trace_mask"]["path"],
                cv2.IMREAD_GRAYSCALE,
            )
            new_missing = cv2.imread(
                new_channel["assets"]["missing_pixel_edge_trace_mask"]["path"],
                cv2.IMREAD_GRAYSCALE,
            )
            need(
                old_missing is not None
                and new_missing is not None
                and old_missing.shape == new_missing.shape,
                "R20 cannot verify predecessor missing-evidence holds",
            )
            removed_hold_pixels += int(
                np.count_nonzero((old_missing > 0) & (new_missing == 0))
            )
            trace = new_channel["physicalBoundary"]["pairedNotchCurveTrace"]
            trace_rows.append(
                {"case": int(new_result["ordinal"]), "channel": channel, **trace}
            )
        new_result["state"] = new_result["state"].replace("R18", "R20")
    need(
        mismatch_count == 0 and removed_hold_pixels == 0,
        "R20 changed frozen R18 geometry/raster provenance or removed a hold",
    )
    bf_sparse = sum(
        row["channel"] == "BF" and row["reviewState"].startswith("HOLD_")
        for row in trace_rows
    )
    df_holds = sum(
        row["channel"] == "DF" and row["reviewState"].startswith("HOLD_")
        for row in trace_rows
    )
    _preservation.update(
        mismatchCount=mismatch_count,
        removedHoldPixels=removed_hold_pixels,
        bfSparse=bf_sparse,
        dfHolds=df_holds,
        traceRows=trace_rows,
    )
    summary.update(
        {
            "schema": "argos_ocv03_annular_unwrap_independent_curve_trace_diagnostic_r20_local_v1",
            "state": "COMPLETE_DIAGNOSTIC_ONLY_R20_LOCAL_ANNULAR_UNWRAP",
            "detectorRevision": "R20",
            "disposition": "DIAGNOSTIC_ONLY_EXISTING_CYAN_HOLDS_AND_SPARSE_BF_CONTOUR_HOLDS_RETAINED",
            "visualReviewState": "PENDING_OPERATOR_REVIEW",
            "r19AlgorithmLayer": {
                "path": str(R19_PATH),
                "bytes": R19_PATH.stat().st_size,
                "sha256": R19_SHA256,
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
                "enhancementCyanYellowAndCircleOnlyPreserved": True,
                "allExistingHoldsPreserved": True,
            },
            "independentChannelCurveTraces": trace_rows,
            "bfSparseCurveEvidenceHoldCount": bf_sparse,
            "dfCurveEvidenceHoldCount": df_holds,
            "bfAndDfNotchesIdentifiedIndependently": True,
            "crossChannelPixelCoordinateTransferPerformed": False,
            "postResultSelectorRelaxationPerformed": False,
        }
    )


def upgrade_gate(path: Path, gate: dict[str, Any]) -> None:
    need(bool(_preservation), "R20 summary upgrade did not precede gate upgrade")
    trace_rows = _preservation["traceRows"]
    gate.update(
        {
            "schema": "argos_ocv03_annular_unwrap_r20_local_detector_gate_v1",
            "state": (
                "HOLD_R20_LOCAL_CYAN_AND_SPARSE_BF_CURVE_REVIEW_REQUIRED"
                if _preservation["bfSparse"] or gate["cyanGeometryHoldCount"]
                else "PASS_R20_LOCAL_DETECTOR_GATE"
            ),
            "summary": {
                "path": str(path.parent / "SUMMARY.json"),
                "sha256": r19.r18.diagnostic.sha256(path.parent / "SUMMARY.json"),
            },
            "allSelectedNotchPixelsNativeSupported": all(
                row["allSelectedPixelsNativeSupported"] for row in trace_rows
            ),
            "maximumSelectedNotchModelResidualPx": max(
                row["maximumModelResidualPx"]
                for row in trace_rows
                if row["maximumModelResidualPx"] is not None
            ),
            "allDfIndependentCurveEvidenceVerified": _preservation["dfHolds"] == 0,
            "bfSparseCurveEvidenceHoldCount": _preservation["bfSparse"],
            "bfAndDfNotchesIdentifiedIndependently": True,
            "crossChannelPixelCoordinateTransferPerformed": False,
            "selectedTraceInterpolationPerformed": False,
            "r18PreservedAssetHashMismatchCount": _preservation["mismatchCount"],
            "removedExistingHoldPixelCount": _preservation["removedHoldPixels"],
            "allExistingHoldsPreserved": True,
            "reviewOnly": True,
        }
    )


def atomic_json(path: Path, payload: dict[str, Any]) -> None:
    if path.name == "SUMMARY.json":
        upgrade_summary(payload)
    elif path.name == "LOCAL_DETECTOR_GATE.json":
        upgrade_gate(path, payload)
    _atomic_json(path, payload)


r19.r18.run_local_strip_review = r19._run_local_r18
r19.r18.diagnostic.atomic_json = atomic_json
r19.r18.__file__ = str(Path(__file__).resolve())


def main() -> int:
    need(
        "--local-predecessor-summary" in sys.argv,
        "R20 is restricted to hash-pinned local review mode",
    )
    return r19.r18.main()


if __name__ == "__main__":
    raise SystemExit(main())
