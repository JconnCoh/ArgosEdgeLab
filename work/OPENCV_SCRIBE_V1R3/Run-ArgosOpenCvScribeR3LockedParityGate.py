#!/usr/bin/env python3
"""Run locked, review-only R3 scribe recognition and semantic gates."""

from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


EXPECTED_HASHES = {
    "work/OPENCV_SCRIBE_V1/OCV02_SCRIBE_SEMANTIC_BASELINE.json": "14294BAB3C2B3CB1F9B7AF199F796BACD0BCE46BA555DCD772FC17ACF175F0CC",
    "work/SCRIBE_REVIEW_ONLY/tools/SemiM12DotMatrixImageReader.cs": "0E64D5FBE57556B7FC5A37D6764FDA65CBF780F96A3C994B73954CF985E67206",
    "work/SCRIBE_REVIEW_ONLY/tools/ScribeChannelPolarityVariants.cs": "94DFB1B7F38A1E5BF12C41F9D8FBEEDAFFDF888365E9646F1058C58A9F5DEF0C",
    "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json": "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229",
    "work/SCRIBE_REVIEW_ONLY/outputs/review_only/FS15_SCRIBE_READER_PHYSICAL_HOLDOUT_V4_20260804T204500Z/PHYSICAL_HOLDOUT_RESULTS.csv": "7BCA49CA6871615D1E84CAD0ED21F0577F93671AF0AB11043E089DF554F9B81B",
    "work/SCRIBE_REVIEW_ONLY/outputs/review_only/FS15_SCRIBE_READER_PHYSICAL_HOLDOUT_V4_20260804T204500Z/DUPLICATE_VIEW_AGREEMENT.csv": "BBADA2B29489487841E357D722D194034A19F5B411D9447C88DB3C1F5C60C468",
    "work/SCRIBE_REVIEW_ONLY/outputs/review_only/FS15_SCRIBE_READER_PHYSICAL_HOLDOUT_V4_20260804T204500Z/HOLDOUT_SUMMARY.json": "9B06357632EC8DA3520265DBB8020D154012EE151A113193E906873FCA0A4A77",
}


def load_engine(path: Path):
    specification = importlib.util.spec_from_file_location("argos_opencv_scribe_r3", path)
    if specification is None or specification.loader is None:
        raise RuntimeError("R3 engine module could not be loaded.")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    script_path = Path(__file__).resolve()
    repository = script_path.parents[2]
    engine_path = script_path.with_name("ArgosOpenCvScribeV1R3.py")
    engine = load_engine(engine_path)

    dependency_rows = []
    for relative, expected in EXPECTED_HASHES.items():
        path = repository / relative
        actual = engine.sha256_file(path)
        dependency_rows.append({"path": relative, "sha256": actual, "passed": actual == expected})
    if not all(row["passed"] for row in dependency_rows):
        raise RuntimeError("Locked scribe dependency hash changed.")

    reference_root = repository / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z"
    reference_manifest = reference_root / "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    roots = {
        "glyphs": reference_root / "glyphs",
        "glyphs_v5_confirmed_20260806": reference_root / "glyphs_v5_confirmed_20260806",
    }
    prototypes, reference_evidence = engine.load_reference_prototypes(
        reference_manifest,
        EXPECTED_HASHES["work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json"],
        roots,
    )
    holdout_root = repository / "work/SCRIBE_REVIEW_ONLY/outputs/review_only/FS15_SCRIBE_READER_PHYSICAL_HOLDOUT_V4_20260804T204500Z"
    corpus_rows = list(csv.DictReader((holdout_root / "PHYSICAL_HOLDOUT_RESULTS.csv").open(encoding="utf-8-sig", newline="")))
    if len(corpus_rows) != 15:
        raise RuntimeError("Locked physical holdout cardinality changed.")

    results = []
    by_physical: dict[str, list[dict[str, Any]]] = {}
    for corpus in corpus_rows:
        alias = str(corpus["Alias"])
        accepted = read_json(holdout_root / f"{alias}.json")
        input_path = Path(str(accepted["inputPath"]))
        detector_input = engine.decode_gray_exact(input_path)
        grid = accepted["grid"]
        evaluated = engine.evaluate_detector_input(
            detector_input,
            prototypes,
            str(accepted["excludedReferenceIdentity"]),
            (int(grid["x"]), int(grid["y"]), int(grid["cellWidth"]), int(grid["cellHeight"])),
        )
        proposed = str(evaluated["proposedString"])
        truth = str(corpus["Truth"])
        row = {
            "alias": alias,
            "acquisitionKey": str(corpus["AcquisitionKey"]),
            "physicalWaferKey": str(corpus["PhysicalWaferKey"]),
            "inputSha256": engine.sha256_file(input_path),
            "excludedPhysicalIdentity": str(accepted["excludedReferenceIdentity"]),
            "grid": {
                "x": int(grid["x"]),
                "y": int(grid["y"]),
                "cellWidth": int(grid["cellWidth"]),
                "cellHeight": int(grid["cellHeight"]),
            },
            "imageFirstString": str(evaluated["imageFirstString"]),
            "proposedString": proposed,
            "truth": truth,
            "passed": proposed == truth,
        }
        results.append(row)
        by_physical.setdefault(row["physicalWaferKey"], []).append(row)

    duplicate_rows = []
    for physical, rows in sorted(by_physical.items()):
        if len(rows) < 2:
            continue
        proposals = sorted({str(row["proposedString"]) for row in rows})
        truths = sorted({str(row["truth"]) for row in rows})
        duplicate_rows.append({
            "physicalWaferKey": physical,
            "acquisitionCount": len(rows),
            "proposedStrings": proposals,
            "truths": truths,
            "passed": len(proposals) == 1 and len(truths) == 1 and proposals == truths,
        })

    semantic_input = engine.decode_gray_exact(Path(str(read_json(holdout_root / "A01.json")["inputPath"])))
    semantic_job = {
        "jobId": "R3_NEGATIVE_UNQUALIFIED_EXCEPTION_TEXTURE",
        "search": {
            "expectedRegions": [],
            "boundedExceptionSearch": True,
            "maximumWorkingDimension": 1200,
            "maximumCandidates": 12,
            "orientationStepDegrees": 15,
        },
        "references": {"excludedPhysicalIdentity": "62607_215_SLOT25"},
    }
    semantic_result = engine.analyze_images(
        semantic_job,
        semantic_input,
        semantic_input.copy(),
        prototypes,
        reference_evidence,
        {"gateInput": "LOCKED_A01_DETECTOR_INPUT", "bfDfIndependent": True},
    )
    semantic_checks = {
        "stateIsLocalizationHold": semantic_result["state"] == "SCRIBE_LOCALIZATION_HOLD",
        "imageFirstEmpty": semantic_result["imageFirstString"] == "",
        "proposedStringEmpty": semantic_result["proposedString"] == "",
        "checksumNotEvaluated": semantic_result["checksumState"] == "NOT_EVALUATED",
        "identityCandidateCountZero": len(semantic_result["candidates"]) == 0,
        "exceptionDiagnosticsIdentityIneligible": all(
            row["identityEligible"] is False
            for row in semantic_result["localization"]["exceptionDiagnostics"]
        ),
        "standardAndExceptionDistinct": semantic_result["provenance"]["standardAndExceptionResultsDistinct"] is True,
        "referenceCoverageHoldPreserved": any(row["code"] == "SCRIBE_REFERENCE_COVERAGE_HOLD" for row in semantic_result["holds"]),
    }

    pass_count = sum(1 for row in results if row["passed"])
    duplicate_pass_count = sum(1 for row in duplicate_rows if row["passed"])
    passed = (
        pass_count == 15
        and len(duplicate_rows) == 4
        and duplicate_pass_count == 4
        and not bool(reference_evidence["referenceCoverageComplete"])
        and str(reference_evidence["missingBodyReferenceLabels"]) == "IJKOQVWXYZ"
        and all(semantic_checks.values())
    )
    gate = {
        "schema": "argos_opencv_scribe_r3_locked_parity_gate_v1",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "state": "PASS_OCV02_R3_LOCKED_READER_AND_SEMANTIC_PARITY" if passed else "FAIL_OCV02_R3_LOCKED_READER_AND_SEMANTIC_PARITY",
        "engine": {
            "path": "work/OPENCV_SCRIBE_V1R3/ArgosOpenCvScribeV1R3.py",
            "sha256": engine.sha256_file(engine_path),
            "revision": engine.ENGINE_REVISION,
            "opencvVersion": engine.cv2.__version__,
            "numpyVersion": engine.np.__version__,
        },
        "dependencies": dependency_rows,
        "physicalHoldout": {
            "mode": "LOCKED_ACCEPTED_GRID_RECOGNITION_PARITY",
            "passCount": pass_count,
            "caseCount": len(results),
            "cases": results,
        },
        "duplicateViewAgreement": {
            "passCount": duplicate_pass_count,
            "groupCount": len(duplicate_rows),
            "groups": duplicate_rows,
        },
        "referenceCoverage": reference_evidence,
        "unqualifiedExceptionTextureNegativeGate": {
            "diagnosticCandidateCount": semantic_result["localization"]["exceptionDiagnosticCandidateCount"],
            "checks": semantic_checks,
        },
        "currentDevelopmentPartition": {
            "lotId": "62619-433",
            "slotsRead": [],
            "slots22Through25Exposed": False,
        },
        "providerActivated": False,
        "sourceMutationPerformed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    engine.write_json_new(arguments.output, gate)
    print(json.dumps({
        "state": gate["state"],
        "physicalHoldout": f"{pass_count}/{len(results)}",
        "duplicateAgreement": f"{duplicate_pass_count}/{len(duplicate_rows)}",
        "exceptionDiagnostics": semantic_result["localization"]["exceptionDiagnosticCandidateCount"],
        "output": str(arguments.output),
    }))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
