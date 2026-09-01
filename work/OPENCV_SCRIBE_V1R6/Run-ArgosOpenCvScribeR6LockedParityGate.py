#!/usr/bin/env python3
"""Run locked recognition plus R6 automatic-localization geometry gates."""

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
    specification = importlib.util.spec_from_file_location("argos_opencv_scribe_r6", path)
    if specification is None or specification.loader is None:
        raise RuntimeError("R6 engine module could not be loaded.")
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
    engine_path = script_path.with_name("ArgosOpenCvScribeV1R6.py")
    engine = load_engine(engine_path)
    configuration_path = script_path.with_name("OCV02_R6_OFFLINE_CONFIGURATION.json")
    configuration = read_json(configuration_path)
    if configuration.get("providerId") != "ARGOS_OPENCV_SCRIBE_V1R6":
        raise RuntimeError("R6 provider selection mismatch.")
    if str(configuration.get("engine", {}).get("sha256", "")) != engine.sha256_file(engine_path):
        raise RuntimeError("R6 configuration engine hash mismatch.")
    if any(bool(configuration.get("authority", {}).get(name)) for name in (
        "automaticIdentityAuthority", "mayClearHolds", "trainingEligible", "xmlEligible", "productionEligible"
    )):
        raise RuntimeError("R6 offline authority contract widened.")
    automatic = configuration["automaticLocalization"]

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
        "jobId": "R6_NEGATIVE_UNQUALIFIED_EXCEPTION_TEXTURE",
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
    auto_job = {
        "schema": "argos_opencv_scribe_job_v1",
        "jobId": "R6_POSITIVE_REVIEW_ONLY_AUTO_LOCALIZED_DEVELOPMENT",
        "inputMode": "DEVELOPMENT_AUTO_LOCALIZED_WHOLE_IMAGE",
        "authority": {"reviewOnly": True},
        "search": {
            "expectedRegions": [],
            "boundedExceptionSearch": True,
            "maximumWorkingDimension": 1200,
            "maximumCandidates": 12,
            "orientationStepDegrees": 15,
            "developmentMaximumRegions": automatic["maximumRegions"],
            "developmentMinimumLocalizationScore": automatic["minimumLocalizationScore"],
            "developmentMinimumBandWidthPixels": automatic["minimumBandWidthPixels"],
            "developmentOcrRegionWidthPixels": automatic["ocrRegionWidthPixels"],
            "developmentOcrRegionHeightPixels": automatic["ocrRegionHeightPixels"],
            "developmentMinimumObservedHeightRatio": automatic["minimumObservedHeightRatio"],
            "developmentMinimumObservedWidthRatio": automatic["minimumObservedWidthRatio"],
            "developmentMaximumObservedWidthRatio": automatic["maximumObservedWidthRatio"],
        },
        "references": {"excludedPhysicalIdentity": "62607_215_SLOT25"},
    }
    auto_result = engine.analyze_images(
        auto_job,
        semantic_input,
        semantic_input.copy(),
        prototypes,
        reference_evidence,
        {"gateInput": "LOCKED_A01_DETECTOR_INPUT", "bfDfIndependent": True},
    )
    engine.validate_job_shape(auto_job)
    missing_geometry_job = json.loads(json.dumps(auto_job))
    del missing_geometry_job["search"]["developmentMinimumObservedHeightRatio"]
    missing_geometry_refused = False
    try:
        engine.validate_job_shape(missing_geometry_job)
    except ValueError:
        missing_geometry_refused = True
    widened_authority_job = json.loads(json.dumps(auto_job))
    widened_authority_job["authority"]["automaticIdentityAuthority"] = True
    widened_authority_refused = False
    try:
        engine.validate_job_shape(widened_authority_job)
    except ValueError:
        widened_authority_refused = True
    configuration_checks = {
        "selectedProviderExact": configuration["providerId"] == "ARGOS_OPENCV_SCRIBE_V1R6",
        "configuredEngineHashExact": configuration["engine"]["sha256"] == engine.sha256_file(engine_path),
        "completeConfiguredJobAccepted": True,
        "missingGeometryContractRefused": missing_geometry_refused,
        "widenedAuthorityRefused": widened_authority_refused,
    }
    auto_checks = {
        "modeExplicit": auto_result["localization"]["autoLocalizedDevelopmentMode"] is True,
        "diagnosticsPresent": auto_result["localization"]["exceptionDiagnosticCandidateCount"] > 0,
        "ocrScaleBandsPreferred": auto_result["localization"]["autoLocalizedEligibleBandCount"] >= auto_result["localization"]["autoLocalizedPromotedCandidateCount"] > 0,
        "boundedSubsetPromoted": 0 < auto_result["localization"]["autoLocalizedPromotedCandidateCount"] <= 2,
        "duplicateGeometryCollapsed": auto_result["localization"]["autoLocalizedUniqueGeometricCandidateCount"] <= auto_result["localization"]["exceptionDiagnosticCandidateCount"],
        "observedGeometryQualified": auto_result["localization"]["autoLocalizedGeometryQualifiedCount"] > 0,
        "geometryEvidenceRecorded": len(auto_result["localization"]["autoLocalizedGeometryEvidence"]) == auto_result["localization"]["autoLocalizedUniqueGeometricCandidateCount"],
        "configuredEnvelopeRecorded": auto_result["localization"]["autoLocalizedOcrRegionWidthPixels"] == 1600.0 and auto_result["localization"]["autoLocalizedOcrRegionHeightPixels"] == 400.0,
        "readerEvaluated": auto_result["checksumState"] != "NOT_EVALUATED",
        "identityIneligible": auto_result["eligibleIdentity"] is False,
        "automaticLocalizationHoldPresent": any(row["code"] == "SCRIBE_AUTO_LOCALIZATION_DEVELOPMENT_HOLD" for row in auto_result["holds"]),
        "referenceCoverageHoldPreserved": any(row["code"] == "SCRIBE_REFERENCE_COVERAGE_HOLD" for row in auto_result["holds"]),
        "exceptionDiagnosticsIdentityIneligible": all(row["identityEligible"] is False for row in auto_result["localization"]["exceptionDiagnostics"]),
        "productionAuthorityAbsent": auto_result["authority"]["productionEligible"] is False and auto_result["authority"]["automaticIdentityAuthority"] is False,
    }

    # Exact O2D20 signed stdout SHA-256 6A8F71C4141C31AA5EBA3956D8DB84A9C83D5CA069152854EA11FD398474FDCF
    # recorded this same thin line rectangle through four morphology angles.
    recorded_false_regions = [
        engine.Region(f"RECORDED_{name}", "SIGNED_O2D20_FALSE_TEXTURE", x, y, width, height, angle, score)
        for name, x, y, width, height, angle, score in (
            ("105", 12321.870076675415, 9244.873315887451, 1228.8895260810853, 42.15563077807427, 34.31509017944336, 0.5638074278831482),
            ("135", 12321.870076675415, 9244.873315887451, 1228.8895260810853, 42.15563077807427, 34.31509017944336, 0.5638074278831482),
            ("150", 12321.870076675415, 9244.873315887451, 1228.8895260810853, 42.15563077807427, 34.31509017944336, 0.5638074278831482),
            ("120", 12320.894844970704, 9244.208135299683, 1226.5278601264954, 42.15563077807427, 34.31509017944336, 0.54914790391922),
        )
    ]
    recorded_unique = engine.deduplicate_auto_regions(recorded_false_regions)
    recorded_geometry = [
        engine.automatic_region_geometry(
            region,
            float(automatic["ocrRegionWidthPixels"]),
            float(automatic["ocrRegionHeightPixels"]),
            float(automatic["minimumObservedHeightRatio"]),
            float(automatic["minimumObservedWidthRatio"]),
            float(automatic["maximumObservedWidthRatio"]),
        )
        for region in recorded_unique
    ]
    recorded_false_texture_checks = {
        "fourSignedDetectionsPresent": len(recorded_false_regions) == 4,
        "sameRectangleCollapsed": len(recorded_unique) == 1,
        "thinObservedHeightRejected": len(recorded_geometry) == 1 and recorded_geometry[0]["qualified"] is False,
        "rejectionExplicit": len(recorded_geometry) == 1 and recorded_geometry[0]["rejection"] == "OBSERVED_GEOMETRY_DOES_NOT_SUPPORT_OCR_ENVELOPE",
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
        and all(auto_checks.values())
        and all(recorded_false_texture_checks.values())
        and all(configuration_checks.values())
    )
    gate = {
        "schema": "argos_opencv_scribe_r6_locked_parity_gate_v1",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "state": "PASS_OCV02_R6_LOCKED_READER_AND_GEOMETRY_SEMANTICS" if passed else "FAIL_OCV02_R6_LOCKED_READER_AND_GEOMETRY_SEMANTICS",
        "engine": {
            "path": "work/OPENCV_SCRIBE_V1R6/ArgosOpenCvScribeV1R6.py",
            "sha256": engine.sha256_file(engine_path),
            "revision": engine.ENGINE_REVISION,
            "opencvVersion": engine.cv2.__version__,
            "numpyVersion": engine.np.__version__,
            "configurationPath": "work/OPENCV_SCRIBE_V1R6/OCV02_R6_OFFLINE_CONFIGURATION.json",
            "configurationSha256": engine.sha256_file(configuration_path),
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
        "autoLocalizedDevelopmentPositiveGate": {
            "diagnosticCandidateCount": auto_result["localization"]["exceptionDiagnosticCandidateCount"],
            "eligibleBandCount": auto_result["localization"]["autoLocalizedEligibleBandCount"],
            "promotedCandidateCount": auto_result["localization"]["autoLocalizedPromotedCandidateCount"],
            "resultState": auto_result["state"],
            "checksumState": auto_result["checksumState"],
            "candidateCount": len(auto_result["candidates"]),
            "checks": auto_checks,
        },
        "signedThinTextureRegressionGate": {
            "source": "O2D20_SIGNED_STDOUT_SHA256_6A8F71C4141C31AA5EBA3956D8DB84A9C83D5CA069152854EA11FD398474FDCF",
            "rawRegionCount": len(recorded_false_regions),
            "uniqueRegionCount": len(recorded_unique),
            "geometry": recorded_geometry,
            "checks": recorded_false_texture_checks,
        },
        "configurationSelectionGate": {
            "providerId": configuration["providerId"],
            "configurationSha256": engine.sha256_file(configuration_path),
            "checks": configuration_checks,
        },
        "evidencePartition": {
            "kind": "LOCKED_LOCAL_REGRESSION_CORPUS",
            "liveJbodImageRead": False,
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

