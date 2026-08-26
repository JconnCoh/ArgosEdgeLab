#!/usr/bin/env python3
"""Run the locked 15-case full OpenCV grid-localization parity gate."""

from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


ENGINE_SHA256 = "95B10EB639C095ED82A6E167D658B12F7D6C08E0D6E18C359D494F3C08D134F8"
MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
HOLDOUT_CSV_SHA256 = "7BCA49CA6871615D1E84CAD0ED21F0577F93671AF0AB11043E089DF554F9B81B"


def load_engine(path: Path):
    specification = importlib.util.spec_from_file_location("argos_opencv_scribe_r4_full_gate", path)
    if specification is None or specification.loader is None:
        raise RuntimeError("R4 engine module could not be loaded.")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    script_path = Path(__file__).resolve()
    repository = script_path.parents[2]
    engine_path = script_path.with_name("ArgosOpenCvScribeV1R4.py")
    engine = load_engine(engine_path)
    if engine.sha256_file(engine_path) != ENGINE_SHA256:
        raise RuntimeError("R4 engine hash changed.")

    reference_root = repository / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z"
    manifest_path = reference_root / "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    roots = {
        "glyphs": reference_root / "glyphs",
        "glyphs_v5_confirmed_20260806": reference_root / "glyphs_v5_confirmed_20260806",
    }
    prototypes, reference_evidence = engine.load_reference_prototypes(
        manifest_path,
        MANIFEST_SHA256,
        roots,
    )
    holdout_root = repository / "work/SCRIBE_REVIEW_ONLY/outputs/review_only/FS15_SCRIBE_READER_PHYSICAL_HOLDOUT_V4_20260804T204500Z"
    csv_path = holdout_root / "PHYSICAL_HOLDOUT_RESULTS.csv"
    if engine.sha256_file(csv_path) != HOLDOUT_CSV_SHA256:
        raise RuntimeError("Locked physical holdout CSV changed.")
    corpus_rows = list(csv.DictReader(csv_path.open(encoding="utf-8-sig", newline="")))
    if len(corpus_rows) != 15:
        raise RuntimeError("Locked physical holdout cardinality changed.")

    cases = []
    by_physical: dict[str, list[dict]] = {}
    started = time.perf_counter()
    for index, corpus in enumerate(corpus_rows, start=1):
        alias = str(corpus["Alias"])
        accepted = json.loads((holdout_root / f"{alias}.json").read_text(encoding="utf-8-sig"))
        image_path = Path(str(accepted["inputPath"]))
        gray = engine.decode_gray_exact(image_path)
        case_started = time.perf_counter()
        evaluated = engine.evaluate_detector_input(
            gray,
            prototypes,
            str(accepted["excludedReferenceIdentity"]),
        )
        elapsed = time.perf_counter() - case_started
        accepted_grid = accepted["grid"]
        truth = str(corpus["Truth"])
        proposed = str(evaluated["proposedString"])
        delta_x = int(evaluated["x"]) - int(accepted_grid["x"])
        delta_y = int(evaluated["y"]) - int(accepted_grid["y"])
        row = {
            "alias": alias,
            "acquisitionKey": str(corpus["AcquisitionKey"]),
            "physicalWaferKey": str(corpus["PhysicalWaferKey"]),
            "inputSha256": engine.sha256_file(image_path),
            "excludedPhysicalIdentity": str(accepted["excludedReferenceIdentity"]),
            "acceptedGrid": {
                "x": int(accepted_grid["x"]),
                "y": int(accepted_grid["y"]),
            },
            "openCvGrid": {
                "x": int(evaluated["x"]),
                "y": int(evaluated["y"]),
                "deltaX": delta_x,
                "deltaY": delta_y,
            },
            "imageFirstString": str(evaluated["imageFirstString"]),
            "proposedString": proposed,
            "truth": truth,
            "gridWithinTenPixels": abs(delta_x) <= 10 and abs(delta_y) <= 10,
            "proposalExact": proposed == truth,
            "passed": proposed == truth and abs(delta_x) <= 10 and abs(delta_y) <= 10,
            "elapsedSeconds": elapsed,
        }
        cases.append(row)
        by_physical.setdefault(row["physicalWaferKey"], []).append(row)
        print(json.dumps({
            "progress": f"{index}/15",
            "alias": alias,
            "grid": [row["openCvGrid"]["x"], row["openCvGrid"]["y"]],
            "proposed": proposed,
            "truth": truth,
            "passed": row["passed"],
            "elapsedSeconds": round(elapsed, 3),
        }), flush=True)

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

    case_pass_count = sum(1 for row in cases if row["passed"])
    duplicate_pass_count = sum(1 for row in duplicate_rows if row["passed"])
    passed = case_pass_count == 15 and len(duplicate_rows) == 4 and duplicate_pass_count == 4
    gate = {
        "schema": "argos_opencv_scribe_r4_full_localization_gate_v1",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "state": "PASS_OCV02_R4_FULL_LOCALIZATION_AND_RECOGNITION_15_OF_15" if passed else "FAIL_OCV02_R4_FULL_LOCALIZATION_AND_RECOGNITION",
        "engine": {
            "path": "work/OPENCV_SCRIBE_V1R4/ArgosOpenCvScribeV1R4.py",
            "sha256": ENGINE_SHA256,
            "revision": engine.ENGINE_REVISION,
            "opencvVersion": engine.cv2.__version__,
            "numpyVersion": engine.np.__version__,
        },
        "method": {
            "localization": "LOCKED_READER_COARSE_PLUS_PIXEL_REFINEMENT",
            "gridTolerancePixels": 10,
            "recognition": "LOCKED_READER_V6_EXACT_PORT_WITH_V5_MERGED_REFERENCES",
            "physicalIdentityExclusion": True,
        },
        "casePassCount": case_pass_count,
        "caseCount": len(cases),
        "cases": cases,
        "duplicateViewAgreement": {
            "passCount": duplicate_pass_count,
            "groupCount": len(duplicate_rows),
            "groups": duplicate_rows,
        },
        "referenceCoverage": reference_evidence,
        "elapsedSeconds": time.perf_counter() - started,
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
        "cases": f"{case_pass_count}/{len(cases)}",
        "duplicates": f"{duplicate_pass_count}/{len(duplicate_rows)}",
        "elapsedSeconds": round(float(gate["elapsedSeconds"]), 3),
        "output": str(arguments.output),
    }), flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

