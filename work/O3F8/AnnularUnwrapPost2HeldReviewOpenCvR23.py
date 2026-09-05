#!/usr/bin/env python3
"""Render a held, post-freeze POST2 comparison without clearing R22 notch holds."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
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
R22_SHA256 = "CEC62EEBBF71B633D3371BD6AA5372F49E430110F4382BAC568167A1DDAA5C07"
R22_PATH = Path(
    os.environ.get("ARGOS_R22_ENGINE_PATH", HERE / "AnnularUnwrapPost2ComparisonOpenCvR22.py")
)
R22_SUMMARY_SHA256 = "9818ADAC53A39E969F9A368098E5842083475BE990B8AFF6D3850BD8152E1564"
R22_GATE_SHA256 = "8262ED3CB363377828D1037008E920182E594F2282A07EAD08F95FBD55970BF2"
SCORER_LABELS_SHA256 = "F8337BB2DDA12DBBA5769677C5A1A31E54CDD54659E0137F2EB9694EC2CCA668"
SCHEMA = "argos_ocv03_annular_post2_r23_held_post_label_review_v1"
HOLD_BAR_ROWS = 6
HASH_CHUNK_BYTES = 8 * 1024 * 1024


def need(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(HASH_CHUNK_BYTES)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest().upper()


need(R22_PATH.is_file() and sha256_file(R22_PATH) == R22_SHA256, "R23 requires exact R22")
SPEC = importlib.util.spec_from_file_location("argos_annular_post2_r22_for_r23", R22_PATH)
need(SPEC is not None and SPEC.loader is not None, f"Cannot load {R22_PATH}")
r22 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = r22
SPEC.loader.exec_module(r22)


def validate_frozen_inference(
    summary_path: Path,
    summary_sha256: str,
    gate_path: Path,
    gate_sha256: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    need(summary_sha256.upper() == R22_SUMMARY_SHA256, "R22 summary pin differs from R23")
    need(gate_sha256.upper() == R22_GATE_SHA256, "R22 gate pin differs from R23")
    summary = r22.load_json_pinned(summary_path, summary_sha256, "R22 inference summary")
    gate = r22.load_json_pinned(gate_path, gate_sha256, "R22 inference gate")
    need(
        summary.get("schema") == r22.INFERENCE_SCHEMA
        and summary.get("state") == "COMPLETE_DIAGNOSTIC_ONLY_R22_POST2_INFERENCE"
        and int(summary.get("requestedCount", -1)) == 3
        and int(summary.get("completedCount", -1)) == 3
        and int(summary.get("memberErrorCount", -1)) == 0
        and len(summary.get("sourceIntegrity", [])) == 6
        and len(summary.get("results", [])) == 3
        and not bool(summary.get("knownChipoutAngleConsumed"))
        and not bool(summary.get("chipoutLabelFileRead"))
        and not bool(summary.get("chipoutSelectionPerformed"))
        and not bool(summary.get("chipoutThresholdTuningPerformed"))
        and not bool(summary.get("postResultSelectorRelaxationPerformed")),
        "R22 inference is not the exact complete label-free diagnostic result",
    )
    need(
        str(summary.get("engine", {}).get("sha256", "")).upper() == R22_SHA256,
        "R22 inference source pin differs",
    )
    checks = gate.get("checks")
    need(isinstance(checks, dict), "R22 inference checks are missing")
    failed = sorted(key for key, value in checks.items() if not bool(value))
    need(
        gate.get("schema") == "argos_ocv03_annular_post2_r22_inference_gate_v1"
        and gate.get("state") == "HOLD_R22_POST2_INFERENCE_CONTRACT_FAILURE"
        and int(gate.get("memberErrorCount", -1)) == 0
        and failed == ["allNotchOwnershipUnambiguous"]
        and str(gate.get("summary", {}).get("sha256", "")).upper() == summary_sha256.upper()
        and Path(str(gate.get("summary", {}).get("path", ""))).resolve()
        == summary_path.resolve(),
        "R22 gate is not the exact sole-notch-ownership HOLD",
    )
    return summary, gate


def add_unresolved_hold_bar(
    overlay: np.ndarray, annotation: np.ndarray
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    held_overlay = overlay.copy()
    held_annotation = annotation.copy()
    hold_mask = np.zeros(annotation.shape, dtype=np.uint8)
    held_overlay[:HOLD_BAR_ROWS, :] = (255, 0, 255)
    held_annotation[:HOLD_BAR_ROWS, :] = 255
    hold_mask[:HOLD_BAR_ROWS, :] = 255
    return held_overlay, held_annotation, hold_mask


def run(args: argparse.Namespace) -> int:
    output = Path(args.output_root)
    need(
        output.is_absolute()
        and output.drive.upper() == "C:"
        and not output.exists()
        and len(str(output)) + 128 < 200,
        "R23 output must be a fresh short C: root",
    )
    summary_path = Path(args.inference_summary)
    gate_path = Path(args.inference_gate)
    labels_path = Path(args.scorer_labels)
    summary, inference_gate = validate_frozen_inference(
        summary_path,
        args.inference_summary_sha256,
        gate_path,
        args.inference_gate_sha256,
    )

    need(
        args.scorer_labels_sha256.upper() == SCORER_LABELS_SHA256,
        "Scorer-label pin differs from R23",
    )
    labels = r22.load_json_pinned(labels_path, args.scorer_labels_sha256, "scorer labels")
    identities = {str(result["identity"]) for result in summary["results"]}
    need(len(identities) == 3, "R22 inference identity cardinality differs")
    labeled_identity, center_degrees = r22.find_unique_chipout_angle(labels, identities)

    alias_access = summary.get("workspaceAccess", {})
    alias_sentinel = alias_access.get("aliasSentinel", {})
    sentinel_path = Path(str(alias_sentinel.get("path", "")))
    need(
        alias_access.get("aliasDrive") == "R:"
        and bool(alias_access.get("aliasByteIdentityVerified"))
        and sentinel_path.is_file()
        and sha256_file(sentinel_path) == str(alias_sentinel.get("sha256", "")).upper(),
        "R23 workspace alias is not the exact R22 byte-verified route",
    )

    source_rows: list[dict[str, Any]] = []
    for result in summary["results"]:
        for channel in ("BF", "DF"):
            source = result["channels"][channel]["source"]
            path = Path(source["path"])
            need(
                path.is_file() and path.stat().st_size == int(source["bytes"]),
                f"{result['identity']} {channel} source metadata changed",
            )
            actual = sha256_file(path)
            need(actual == str(source["sha256"]).upper(), "R23 source hash changed")
            source_rows.append({"identity": result["identity"], "channel": channel, **source})

    output.mkdir()
    cases_root = output / "cases"
    cases_root.mkdir()
    review_rows: list[dict[str, Any]] = []
    composed_panels: list[list[np.ndarray]] = []
    frontier_panels: list[list[np.ndarray]] = []
    for result in summary["results"]:
        identity = str(result["identity"])
        case_root = cases_root / f"C{int(result['ordinal']):04d}"
        case_root.mkdir()
        channel_rows: dict[str, Any] = {}
        composed_row: list[np.ndarray] = []
        frontier_row: list[np.ndarray] = []
        for channel in ("BF", "DF"):
            channel_result = result["channels"][channel]
            source = channel_result["source"]
            gray = cv2.imread(str(source["path"]), cv2.IMREAD_GRAYSCALE)
            need(gray is not None, f"{identity} {channel} OpenCV decode failed")
            fit = channel_result["seedFit"]
            raw_crop = r22.remap_review_window(gray, fit, center_degrees)
            del gray
            enhanced = r22.r18.shadow_lift(raw_crop)
            trace_record = channel_result["assets"]["r22_trace"]
            trace = r22.load_trace(Path(trace_record["path"]), str(trace_record["sha256"]))
            need(
                trace.get("notchOwnership", {}).get("state")
                == "HOLD_NO_UNIQUE_R21_CONTOUR_OWNERSHIP_METRICS"
                and not trace.get("notchOwnedIndices"),
                "R23 expected unresolved zero-column R22 notch ownership",
            )
            (
                composed,
                composed_annotation,
                frontier,
                frontier_annotation,
                ownership,
                metrics,
            ) = r22.overlay_review_window(enhanced, fit, center_degrees, trace)
            need(not bool(np.any(ownership)), "R23 refuses to treat nonzero ownership as unresolved")
            composed, composed_annotation, hold_mask = add_unresolved_hold_bar(
                composed, composed_annotation
            )
            frontier, frontier_annotation, frontier_hold_mask = add_unresolved_hold_bar(
                frontier, frontier_annotation
            )
            need(
                bool(np.array_equal(hold_mask, frontier_hold_mask)),
                "R23 hold masks differ between review layers",
            )
            stem = f"{r22.safe_stem(identity)}_{channel.lower()}_held_window"
            assets = {
                "raw": r22.write_png(case_root / f"{stem}_raw.png", raw_crop),
                "enhanced": r22.write_png(case_root / f"{stem}_enhanced.png", enhanced),
                "composedOverlay": r22.write_png(
                    case_root / f"{stem}_composed_overlay.png", composed
                ),
                "composedAnnotationMask": r22.write_png(
                    case_root / f"{stem}_composed_annotation_mask.png", composed_annotation
                ),
                "physicalFrontierOverlay": r22.write_png(
                    case_root / f"{stem}_physical_frontier_overlay.png", frontier
                ),
                "physicalFrontierAnnotationMask": r22.write_png(
                    case_root / f"{stem}_physical_frontier_annotation_mask.png",
                    frontier_annotation,
                ),
                "unresolvedNotchOwnershipHoldMask": r22.write_png(
                    case_root / f"{stem}_notch_hold_mask.png", hold_mask
                ),
                "resolvedNotchOwnershipMask": r22.write_png(
                    case_root / f"{stem}_resolved_notch_ownership_mask.png", ownership
                ),
            }
            metrics.update(
                {
                    "notchOwnershipState": trace["notchOwnership"]["state"],
                    "notchOwnershipResolved": False,
                    "zeroNotchOwnedColumnsMeansClear": False,
                    "unresolvedNotchHoldColor": "MAGENTA_FULL_WIDTH_TOP_BAR",
                    "unresolvedNotchHoldBarRows": HOLD_BAR_ROWS,
                    "chipoutSelectionPerformed": False,
                    "chipoutScoringPerformed": False,
                }
            )
            channel_rows[channel] = {"metrics": metrics, "assets": assets}
            composed_row.append(
                r22.labeled_panel(
                    composed,
                    f"{identity} {channel} | composed trace | MAGENTA full bar = notch HOLD",
                )
            )
            frontier_row.append(
                r22.labeled_panel(
                    frontier,
                    f"{identity} {channel} | RED physical frontier | MAGENTA full bar = notch HOLD",
                )
            )
        composed_panels.append(composed_row)
        frontier_panels.append(frontier_row)
        review_rows.append(
            {
                "ordinal": int(result["ordinal"]),
                "identity": identity,
                "state": "HOLD_R23_OPERATOR_VISUAL_COMPARISON_NOTCH_OWNERSHIP_UNRESOLVED",
                "channels": channel_rows,
            }
        )

    composed_sheet = cv2.vconcat([cv2.hconcat(row) for row in composed_panels])
    composed_sheet_asset = r22.write_png(
        output / "POST2_HELD_COMPOSED_TRACE_COMPARISON.png", composed_sheet
    )
    frontier_sheet = cv2.vconcat([cv2.hconcat(row) for row in frontier_panels])
    frontier_sheet_asset = r22.write_png(
        output / "POST2_HELD_PHYSICAL_FRONTIER_COMPARISON.png", frontier_sheet
    )
    result_summary = {
        "schema": SCHEMA,
        "state": "HOLD_R23_POST2_VISUAL_COMPARISON_NOTCH_OWNERSHIP_UNRESOLVED",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "engine": r22.file_record(Path(__file__).resolve()),
        "r22Engine": r22.file_record(R22_PATH, R22_SHA256),
        "r22InferenceSummary": r22.file_record(summary_path, args.inference_summary_sha256),
        "r22InferenceGate": r22.file_record(gate_path, args.inference_gate_sha256),
        "r22InferenceHoldPreserved": True,
        "r22SoleFailedCheck": "allNotchOwnershipUnambiguous",
        "scorerLabels": r22.file_record(labels_path, args.scorer_labels_sha256),
        "labeledPositiveIdentity": labeled_identity,
        "postInferenceReviewAngleDegrees": center_degrees,
        "reviewAngleConsumedByInference": False,
        "sourceIntegrity": source_rows,
        "cropContract": {
            "tangentialPixels": r22.REVIEW_TANGENTIAL_PX,
            "inwardPixels": r22.REVIEW_INWARD_PX,
            "outwardPixels": r22.REVIEW_OUTWARD_PX,
            "sourceInterpolation": "INTER_NEAREST",
            "polarRemapPerformed": True,
            "displayResizePerformed": False,
        },
        "composedTraceComparisonSheet": composed_sheet_asset,
        "physicalFrontierComparisonSheet": frontier_sheet_asset,
        "results": review_rows,
        "notchOwnershipResolved": False,
        "zeroNotchOwnedColumnsMeansClear": False,
        "chipoutSelectionPerformed": False,
        "chipoutScoringPerformed": False,
        "chipoutThresholdTuningPerformed": False,
        "candidateFilteringFromChipoutTruthPerformed": False,
        "sourceMutationPerformed": False,
        "existingTaskOrProcessActionPerformed": False,
        "providerActivated": False,
        "holdClearancePerformed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    summary_asset = r22.atomic_json(output / "SUMMARY.json", result_summary)
    checks = {
        "exactFrozenR22HoldConsumed": True,
        "soleR22FailureWasUnresolvedNotchOwnership": True,
        "allSixSourceHashesExact": len(source_rows) == 6,
        "threeSameAnglePairsRendered": len(review_rows) == 3,
        "allCrops1000By600": all(
            row["channels"][channel]["metrics"]["tangentialPixels"] == 1000
            and row["channels"][channel]["metrics"]["radialPixels"] == 600
            for row in review_rows
            for channel in ("BF", "DF")
        ),
        "allNotchHoldsVisiblyRetained": all(
            not row["channels"][channel]["metrics"]["notchOwnershipResolved"]
            and not row["channels"][channel]["metrics"]["zeroNotchOwnedColumnsMeansClear"]
            for row in review_rows
            for channel in ("BF", "DF")
        ),
        "physicalFrontierRenderedSeparately": True,
        "noChipoutSelectionOrScoring": True,
        "noHoldClearance": True,
    }
    need(all(checks.values()), "R23 held renderer contract failed")
    gate = {
        "schema": "argos_ocv03_annular_post2_r23_held_review_gate_v1",
        "state": "HOLD_R23_OPERATOR_VISUAL_REVIEW_READY_NOTCH_OWNERSHIP_UNRESOLVED",
        "summary": summary_asset,
        "rendererChecks": checks,
        "visualReviewReady": True,
        "notchPoseAuthorityGranted": False,
        "chipoutScoringEligible": False,
        "packageEligible": False,
        "operatorVisualReviewRequired": True,
        "reviewOnly": True,
        "productionEligible": False,
    }
    gate_asset = r22.atomic_json(output / "REVIEW_GATE.json", gate)
    print(
        json.dumps(
            {
                "state": gate["state"],
                "physicalFrontierComparisonPath": frontier_sheet_asset["path"],
                "physicalFrontierComparisonSha256": frontier_sheet_asset["sha256"],
                "composedTraceComparisonPath": composed_sheet_asset["path"],
                "composedTraceComparisonSha256": composed_sheet_asset["sha256"],
                "summaryPath": summary_asset["path"],
                "summarySha256": summary_asset["sha256"],
                "gatePath": gate_asset["path"],
                "gateSha256": gate_asset["sha256"],
            },
            separators=(",", ":"),
        )
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inference-summary", required=True)
    parser.add_argument("--inference-summary-sha256", required=True)
    parser.add_argument("--inference-gate", required=True)
    parser.add_argument("--inference-gate-sha256", required=True)
    parser.add_argument("--scorer-labels", required=True)
    parser.add_argument("--scorer-labels-sha256", required=True)
    parser.add_argument("--output-root", required=True)
    return run(parser.parse_args())


if __name__ == "__main__":
    raise SystemExit(main())
