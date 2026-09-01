#!/usr/bin/env python3
"""Run bounded OCR expansion against the correct accepted-grid parity gate."""

from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PARITY_GATE_SHA256 = "267086773F7233246FE621EAA8824B495DD4CE4369CD95D92D29438D7B14DE8E"


def load_module(path: Path, name: str):
    specification = importlib.util.spec_from_file_location(name, path)
    if specification is None or specification.loader is None:
        raise RuntimeError(f"Module could not be loaded: {path}")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    script = Path(__file__).resolve()
    repository = script.parents[2]
    r1_path = script.with_name("Run-R6V1OcrSegmentationDiagnostics.py")
    r1 = load_module(r1_path, "argos_r6v1_ocr_expansion_r1")
    engine_path = repository / "work/OPENCV_SCRIBE_V1R6/ArgosOpenCvScribeV1R6.py"
    engine = r1.load_engine(engine_path)
    parity_gate_path = repository / "work/OPENCV_SCRIBE_V1R6/OCV02_R6_LOCKED_PARITY_GATE.json"
    holdout_root = repository / "work/SCRIBE_REVIEW_ONLY/outputs/review_only/FS15_SCRIBE_READER_PHYSICAL_HOLDOUT_V4_20260804T204500Z"
    results_path = holdout_root / "PHYSICAL_HOLDOUT_RESULTS.csv"
    reference_root = repository / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z"
    reference_manifest = reference_root / "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    dependencies = [
        {"id": "r1ExecutedProvider", "path": str(r1_path), "sha256": r1.sha256_file(r1_path)},
        {"id": "engine", "path": str(engine_path), "sha256": r1.sha256_file(engine_path), "expectedSha256": r1.ENGINE_SHA256},
        {"id": "acceptedGridParityGate", "path": str(parity_gate_path), "sha256": r1.sha256_file(parity_gate_path), "expectedSha256": PARITY_GATE_SHA256},
        {"id": "holdoutResults", "path": str(results_path), "sha256": r1.sha256_file(results_path), "expectedSha256": r1.HOLDOUT_RESULTS_SHA256},
        {"id": "referenceManifest", "path": str(reference_manifest), "sha256": r1.sha256_file(reference_manifest), "expectedSha256": r1.REFERENCE_MANIFEST_SHA256},
    ]
    if not all(row.get("expectedSha256", row["sha256"]) == row["sha256"] for row in dependencies):
        raise RuntimeError("R2 frozen dependency changed.")
    parity_gate = r1.read_json(parity_gate_path)
    if parity_gate.get("state") != "PASS_OCV02_R6_LOCKED_READER_AND_GEOMETRY_SEMANTICS":
        raise RuntimeError("Accepted-grid parity gate state changed.")
    locked_cases = {str(row["alias"]): row for row in parity_gate["physicalHoldout"]["cases"]}
    with results_path.open(encoding="utf-8-sig", newline="") as stream:
        corpus = list(csv.DictReader(stream))
    if len(corpus) != 15 or sorted(locked_cases) != sorted(str(row["Alias"]) for row in corpus):
        raise RuntimeError("Frozen R2 control identity set changed.")
    roots = {
        "glyphs": reference_root / "glyphs",
        "glyphs_v5_confirmed_20260806": reference_root / "glyphs_v5_confirmed_20260806",
    }
    prototypes, reference_evidence = engine.load_reference_prototypes(reference_manifest, r1.REFERENCE_MANIFEST_SHA256, roots)
    controls: list[dict[str, Any]] = []
    summaries = {
        expansion: {
            "expansionPixels": expansion,
            "exactProposalCount": 0,
            "characterCorrect": 0,
            "truthInBoundedCandidates": 0,
            "boundaryCompleteCount": 0,
        }
        for expansion in r1.EXPANSIONS
    }
    baseline_mismatches = []
    duplicate_groups: dict[str, list[dict[str, Any]]] = {}
    for corpus_row in corpus:
        alias = str(corpus_row["Alias"])
        truth = str(corpus_row["Truth"])
        accepted = r1.read_json(holdout_root / f"{alias}.json")
        input_path = r1.resolve_control_input(repository, str(accepted["inputPath"]))
        locked = locked_cases[alias]
        input_hash = r1.sha256_file(input_path)
        if input_hash != str(locked["inputSha256"]):
            raise RuntimeError(f"R2 frozen control hash changed: {alias}")
        gray = engine.decode_gray_exact(input_path)
        residual = engine.dark_residual_exact(gray, 12)
        active = engine.filtered_prototypes(prototypes, str(accepted["excludedReferenceIdentity"]))
        bank = engine.PrototypeBank.from_prototypes(active)
        expansion_rows = [
            r1.evaluate_expansion(engine, residual, bank, accepted["grid"], truth, expansion)
            for expansion in r1.EXPANSIONS
        ]
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
    for expansion in r1.EXPANSIONS:
        summary = summaries[expansion]
        duplicate_rows = []
        for physical, rows in sorted(duplicate_groups.items()):
            if len(rows) < 2:
                continue
            proposals = sorted({
                str(next(item for item in row["expansions"] if item["expansionPixels"] == expansion)["proposedString"])
                for row in rows
            })
            duplicate_rows.append({
                "physicalWaferKey": physical,
                "acquisitionCount": len(rows),
                "proposedStrings": proposals,
                "agreement": len(proposals) == 1,
            })
        summary.update({
            "characterTotal": 180,
            "controlCount": 15,
            "duplicateGroupCount": len(duplicate_rows),
            "duplicateAgreementCount": sum(1 for row in duplicate_rows if row["agreement"]),
            "duplicateGroups": duplicate_rows,
        })
        summary_rows.append(summary)
    baseline = summary_rows[0]
    baseline_pass = (
        not baseline_mismatches
        and baseline["exactProposalCount"] == 15
        and baseline["truthInBoundedCandidates"] == 180
        and baseline["duplicateAgreementCount"] == 4
    )
    report = {
        "schema": "argos_r6v1_ocr_segmentation_diagnostic_v2",
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "PASS_R6V1_DIAGNOSTIC_ACCEPTED_GRID_EXPANSION" if baseline_pass else "HOLD_R6V1_DIAGNOSTIC_ACCEPTED_GRID_BASELINE_MISMATCH",
        "disposition": "DIAGNOSTIC_ONLY",
        "method": {
            "provider": "ARGOS_OPENCV_SCRIBE_V1R6",
            "baselineComparator": "OCV02_R6_LOCKED_PARITY_GATE.physicalHoldout.cases",
            "cellExpansionPixels": list(r1.EXPANSIONS),
            "segmentationSupportThreshold": "MAX_8_OR_CELL_90TH_PERCENTILE",
            "selectionOrThresholdFrozen": False,
            "purpose": "Measure bounded accepted-cell-envelope sensitivity without selecting a live revision.",
        },
        "dependencies": dependencies,
        "runtime": {"python": sys.version, "opencv": engine.cv2.__version__, "numpy": r1.np.__version__},
        "referenceCoverage": reference_evidence,
        "controlCount": len(controls),
        "summaries": summary_rows,
        "controls": controls,
        "baselineReproduced": baseline_pass,
        "baselineMismatches": baseline_mismatches,
        "predecessorR1": {
            "state": "WITHDRAWN_COMPARATOR_MISMATCH",
            "reason": "R1 compared accepted-grid expansion zero against the independent full-localization refined grid.",
            "resultPath": "work/OPENCV_SCRIBE_R6V1_OFFLINE/R6V1_OCR_SEGMENTATION_DIAGNOSTIC.json",
        },
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
