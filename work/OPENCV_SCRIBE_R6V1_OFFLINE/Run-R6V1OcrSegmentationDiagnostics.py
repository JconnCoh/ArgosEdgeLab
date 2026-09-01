#!/usr/bin/env python3
"""Measure diagnostic-only OCR cell expansion on the frozen 15 controls."""

from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np


ENGINE_SHA256 = "1E4C55AA4ECFB4DA3CEA9DF577DCFE86C4A2FADCB23D29F78719F3E0AC55E0E9"
FULL_GATE_SHA256 = "704EC0CB9303EA6DC74585A55213DD525773E44E77BBC8EE18DE203C2AF4789F"
HOLDOUT_SUMMARY_SHA256 = "9B06357632EC8DA3520265DBB8020D154012EE151A113193E906873FCA0A4A77"
HOLDOUT_RESULTS_SHA256 = "7BCA49CA6871615D1E84CAD0ED21F0577F93671AF0AB11043E089DF554F9B81B"
REFERENCE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
EXPANSIONS = (0, 2, 4, 6, 8, 12)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"JSON root is not an object: {path}")
    return value


def load_engine(path: Path):
    specification = importlib.util.spec_from_file_location("argos_opencv_scribe_r6_segmentation", path)
    if specification is None or specification.loader is None:
        raise RuntimeError("R6 engine module could not be loaded.")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


def resolve_control_input(repository: Path, recorded: str) -> Path:
    path = Path(recorded)
    if path.is_file():
        return path
    marker = "work\\SCRIBE_REVIEW_ONLY\\"
    normalized = recorded.replace("/", "\\")
    position = normalized.lower().find(marker.lower())
    if position >= 0:
        candidate = repository / Path(normalized[position:].replace("\\", "/"))
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(f"Frozen control input is absent: {recorded}")


def support_evidence(residual: np.ndarray, x: int, y: int, width: int, height: int) -> dict[str, Any]:
    image_height, image_width = residual.shape[:2]
    if x < 0 or y < 0 or x + width > image_width or y + height > image_height:
        return {"inBounds": False}
    cell = residual[y:y + height, x:x + width]
    threshold = max(8.0, float(np.percentile(cell, 90.0)))
    yy, xx = np.nonzero(cell >= threshold)
    if xx.size == 0:
        return {"inBounds": True, "threshold": threshold, "supportPixelCount": 0, "boundingBox": None}
    left = int(xx.min())
    right = int(xx.max())
    top = int(yy.min())
    bottom = int(yy.max())
    return {
        "inBounds": True,
        "threshold": threshold,
        "supportPixelCount": int(xx.size),
        "boundingBox": {"x": left, "y": top, "width": right - left + 1, "height": bottom - top + 1},
        "margins": {"left": left, "right": width - 1 - right, "top": top, "bottom": height - 1 - bottom},
        "touchesCellBoundary": left == 0 or right == width - 1 or top == 0 or bottom == height - 1,
    }


def evaluate_expansion(
    engine: Any,
    residual: np.ndarray,
    bank: Any,
    grid: dict[str, Any],
    truth: str,
    expansion: int,
) -> dict[str, Any]:
    positions = []
    top_scores = []
    character_correct = 0
    truth_in_candidates = 0
    for position in range(12):
        x = int(grid["x"]) + position * int(grid["cellWidth"]) - expansion
        y = int(grid["y"]) - expansion
        width = int(grid["cellWidth"]) + 2 * expansion
        height = int(grid["cellHeight"]) + 2 * expansion
        descriptor = engine.describe_exact(residual, x, y, width, height)
        if descriptor is None:
            return {"expansionPixels": expansion, "inBounds": False}
        ranked = engine.rank_descriptor(descriptor, bank, position)
        if not ranked:
            return {"expansionPixels": expansion, "inBounds": False}
        expected = truth[position]
        truth_rank = next((index + 1 for index, row in enumerate(ranked) if row["character"] == expected), None)
        if ranked[0]["character"] == expected:
            character_correct += 1
        if truth_rank is not None and truth_rank <= (4 if position < 10 else 8):
            truth_in_candidates += 1
        top_scores.append(float(ranked[0]["score"]))
        positions.append({
            "position": position + 1,
            "truth": expected,
            "imageFirst": ranked[0]["character"],
            "truthRank": truth_rank,
            "topScore": float(ranked[0]["score"]),
            "runnerUpScore": float(ranked[1]["score"]) if len(ranked) > 1 else None,
            "topMargin": float(ranked[0]["score"] - ranked[1]["score"]) if len(ranked) > 1 else None,
            "candidates": ranked[:4 if position < 10 else 8],
            "allCandidates": ranked,
            "segmentation": support_evidence(residual, x, y, width, height),
        })
    grid_result = {
        "x": int(grid["x"]) - expansion,
        "y": int(grid["y"]) - expansion,
        "cellWidth": int(grid["cellWidth"]) + 2 * expansion,
        "cellHeight": int(grid["cellHeight"]) + 2 * expansion,
        "meanTopScore": float(sum(top_scores) / len(top_scores)),
        "selectionScore": float(
            engine.GRID_MEAN_WEIGHT * (sum(top_scores) / len(top_scores))
            + engine.GRID_LEADING_WEIGHT * top_scores[0]
            + engine.GRID_TRAILING_WEIGHT * top_scores[-1]
        ),
        "leadingBoundaryScore": top_scores[0],
        "trailingBoundaryScore": top_scores[-1],
        "positions": positions,
    }
    finalized = engine.finalize_grid(grid_result)
    for position in positions:
        position.pop("allCandidates", None)
    return {
        "expansionPixels": expansion,
        "inBounds": True,
        "imageFirstString": finalized["imageFirstString"],
        "proposedString": finalized["proposedString"],
        "boundaryComplete": finalized["boundaryComplete"],
        "checksumValid": finalized["checksumValid"],
        "characterCorrect": character_correct,
        "truthInBoundedCandidates": truth_in_candidates,
        "meanTopScore": finalized["meanTopScore"],
        "positions": positions,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    script = Path(__file__).resolve()
    repository = script.parents[2]
    engine_path = repository / "work/OPENCV_SCRIBE_V1R6/ArgosOpenCvScribeV1R6.py"
    full_gate_path = repository / "work/OPENCV_SCRIBE_V1R6/OCV02_R6_FULL_LOCALIZATION_GATE.json"
    holdout_root = repository / "work/SCRIBE_REVIEW_ONLY/outputs/review_only/FS15_SCRIBE_READER_PHYSICAL_HOLDOUT_V4_20260804T204500Z"
    summary_path = holdout_root / "HOLDOUT_SUMMARY.json"
    results_path = holdout_root / "PHYSICAL_HOLDOUT_RESULTS.csv"
    reference_root = repository / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z"
    reference_manifest = reference_root / "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    pins = {
        "engine": (engine_path, ENGINE_SHA256),
        "fullLocalizationGate": (full_gate_path, FULL_GATE_SHA256),
        "holdoutSummary": (summary_path, HOLDOUT_SUMMARY_SHA256),
        "holdoutResults": (results_path, HOLDOUT_RESULTS_SHA256),
        "referenceManifest": (reference_manifest, REFERENCE_MANIFEST_SHA256),
    }
    dependency_rows = [
        {"id": name, "path": str(path), "sha256": sha256_file(path), "expectedSha256": expected}
        for name, (path, expected) in pins.items()
    ]
    if not all(row["sha256"] == row["expectedSha256"] for row in dependency_rows):
        raise RuntimeError("Frozen OCR diagnostic dependency changed.")
    engine = load_engine(engine_path)
    full_gate = read_json(full_gate_path)
    locked_cases = {str(row["alias"]): row for row in full_gate["cases"]}
    with results_path.open(encoding="utf-8-sig", newline="") as stream:
        corpus = list(csv.DictReader(stream))
    if len(corpus) != 15 or sorted(locked_cases) != sorted(str(row["Alias"]) for row in corpus):
        raise RuntimeError("Frozen 15-control set changed.")
    roots = {
        "glyphs": reference_root / "glyphs",
        "glyphs_v5_confirmed_20260806": reference_root / "glyphs_v5_confirmed_20260806",
    }
    prototypes, reference_evidence = engine.load_reference_prototypes(reference_manifest, REFERENCE_MANIFEST_SHA256, roots)
    controls = []
    baseline_mismatches = []
    summaries = {expansion: {"expansionPixels": expansion, "exactProposalCount": 0, "characterCorrect": 0, "truthInBoundedCandidates": 0, "boundaryCompleteCount": 0} for expansion in EXPANSIONS}
    duplicate_groups: dict[str, list[dict[str, Any]]] = {}
    for corpus_row in corpus:
        alias = str(corpus_row["Alias"])
        truth = str(corpus_row["Truth"])
        accepted = read_json(holdout_root / f"{alias}.json")
        input_path = resolve_control_input(repository, str(accepted["inputPath"]))
        input_hash = sha256_file(input_path)
        locked = locked_cases[alias]
        if input_hash != str(locked["inputSha256"]):
            raise RuntimeError(f"Frozen control hash changed: {alias}")
        gray = engine.decode_gray_exact(input_path)
        residual = engine.dark_residual_exact(gray, 12)
        active = engine.filtered_prototypes(prototypes, str(accepted["excludedReferenceIdentity"]))
        bank = engine.PrototypeBank.from_prototypes(active)
        expansion_rows = [evaluate_expansion(engine, residual, bank, accepted["grid"], truth, expansion) for expansion in EXPANSIONS]
        baseline = expansion_rows[0]
        if baseline.get("imageFirstString") != locked["imageFirstString"] or baseline.get("proposedString") != locked["proposedString"]:
            baseline_mismatches.append({
                "alias": alias,
                "lockedImageFirstString": str(locked["imageFirstString"]),
                "observedImageFirstString": str(baseline.get("imageFirstString", "")),
                "lockedProposedString": str(locked["proposedString"]),
                "observedProposedString": str(baseline.get("proposedString", "")),
            })
        for row in expansion_rows:
            if not row.get("inBounds"):
                continue
            summary = summaries[int(row["expansionPixels"])]
            summary["exactProposalCount"] += int(row["proposedString"] == truth)
            summary["characterCorrect"] += int(row["characterCorrect"])
            summary["truthInBoundedCandidates"] += int(row["truthInBoundedCandidates"])
            summary["boundaryCompleteCount"] += int(row["boundaryComplete"])
        control = {
            "alias": alias,
            "acquisitionKey": str(corpus_row["AcquisitionKey"]),
            "physicalWaferKey": str(corpus_row["PhysicalWaferKey"]),
            "inputPath": str(input_path),
            "inputSha256": input_hash,
            "truth": truth,
            "excludedPhysicalIdentity": str(accepted["excludedReferenceIdentity"]),
            "acceptedGrid": accepted["grid"],
            "expansions": expansion_rows,
        }
        controls.append(control)
        duplicate_groups.setdefault(control["physicalWaferKey"], []).append(control)
    summary_rows = []
    for expansion in EXPANSIONS:
        summary = summaries[expansion]
        duplicate_rows = []
        for physical, rows in sorted(duplicate_groups.items()):
            if len(rows) < 2:
                continue
            proposals = sorted({str(next(item for item in row["expansions"] if item["expansionPixels"] == expansion)["proposedString"]) for row in rows})
            duplicate_rows.append({"physicalWaferKey": physical, "acquisitionCount": len(rows), "proposedStrings": proposals, "agreement": len(proposals) == 1})
        summary["characterTotal"] = 180
        summary["controlCount"] = 15
        summary["duplicateGroupCount"] = len(duplicate_rows)
        summary["duplicateAgreementCount"] = sum(1 for row in duplicate_rows if row["agreement"])
        summary["duplicateGroups"] = duplicate_rows
        summary_rows.append(summary)
    baseline_summary = summary_rows[0]
    baseline_pass = not baseline_mismatches and baseline_summary["exactProposalCount"] == 15 and baseline_summary["characterCorrect"] == 169 and baseline_summary["truthInBoundedCandidates"] == 180
    report = {
        "schema": "argos_r6v1_ocr_segmentation_diagnostic_v1",
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "PASS_R6V1_DIAGNOSTIC_15_CONTROL_SEGMENTATION" if baseline_pass else "HOLD_R6V1_DIAGNOSTIC_RUNTIME_BASELINE_DRIFT",
        "disposition": "DIAGNOSTIC_ONLY",
        "method": {
            "provider": "ARGOS_OPENCV_SCRIBE_V1R6",
            "cellExpansionPixels": list(EXPANSIONS),
            "segmentationSupportThreshold": "MAX_8_OR_CELL_90TH_PERCENTILE",
            "selectionOrThresholdFrozen": False,
            "purpose": "Measure bounded cell-envelope sensitivity before any future OCR revision.",
        },
        "dependencies": dependency_rows,
        "runtime": {"python": sys.version, "opencv": engine.cv2.__version__, "numpy": np.__version__},
        "referenceCoverage": reference_evidence,
        "controlCount": len(controls),
        "summaries": summary_rows,
        "controls": controls,
        "baselineReproduced": baseline_pass,
        "baselineMismatches": baseline_mismatches,
        "identityEligibleCount": 0,
        "automaticIdentityAuthority": False,
        "mayClearHolds": False,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "providerActivated": False,
        "liveProviderRead": False,
        "frozenEngineChanged": False,
        "frozenPackageChanged": False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"state": report["state"], "output": str(args.output), "summary": summary_rows}))
    return 0 if report["state"].startswith("PASS_") else 1


if __name__ == "__main__":
    raise SystemExit(main())
