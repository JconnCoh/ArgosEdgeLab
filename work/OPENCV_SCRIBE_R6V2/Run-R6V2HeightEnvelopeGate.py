#!/usr/bin/env python3
"""Calibrate and gate the configuration-only R6V2 scribe height envelope."""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path

ENGINE_SHA = "1E4C55AA4ECFB4DA3CEA9DF577DCFE86C4A2FADCB23D29F78719F3E0AC55E0E9"
MANIFEST_SHA = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
NEGATIVE_SOURCE = "O2D20_SIGNED_STDOUT_SHA256_6A8F71C4141C31AA5EBA3956D8DB84A9C83D5CA069152854EA11FD398474FDCF"
EXPECTED_POSITIVE = 0.3068176587422689
EXPECTED_NEGATIVE = 0.10538907694518568
EXPECTED_FLOOR = 0.2061033678437273


def load_engine(path: Path):
    spec = importlib.util.spec_from_file_location("argos_r6v2_height_gate", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("R6 provider module could not be loaded.")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def require(checks: dict[str, bool], name: str, value: bool) -> None:
    checks[name] = bool(value)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    engine_path = root / "work/OPENCV_SCRIBE_V1R6/ArgosOpenCvScribeV1R6.py"
    config_path = Path(__file__).with_name("R6V2_CONFIGURATION.json")
    engine = load_engine(engine_path)
    config = json.loads(config_path.read_text(encoding="utf-8-sig"))
    automatic = config["automaticLocalization"]
    checks: dict[str, bool] = {}
    require(checks, "providerBytesUnchanged", engine.sha256_file(engine_path) == ENGINE_SHA == config["engine"]["sha256"])
    require(checks, "configurationReviewOnly", config["authority"] == {
        "reviewOnly": True, "automaticIdentityAuthority": False, "mayClearHolds": False,
        "trainingEligible": False, "xmlEligible": False, "productionEligible": False,
    })

    reference_root = root / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z"
    prototypes, reference_evidence = engine.load_reference_prototypes(
        reference_root / "PORTABLE_GLYPH_REFERENCE_MANIFEST.json", MANIFEST_SHA,
        {"glyphs": reference_root / "glyphs", "glyphs_v5_confirmed_20260806": reference_root / "glyphs_v5_confirmed_20260806"},
    )
    holdout = root / "work/SCRIBE_REVIEW_ONLY/outputs/review_only/FS15_SCRIBE_READER_PHYSICAL_HOLDOUT_V4_20260804T204500Z"
    accepted = json.loads((holdout / "A01.json").read_text(encoding="utf-8-sig"))
    gray = engine.decode_gray_exact(Path(str(accepted["inputPath"])))
    job = {
        "schema": "argos_opencv_scribe_job_v1", "jobId": "R6V2_FROZEN_A01_HEIGHT_CALIBRATION",
        "inputMode": "DEVELOPMENT_AUTO_LOCALIZED_WHOLE_IMAGE", "authority": {"reviewOnly": True},
        "search": {
            "expectedRegions": [], "boundedExceptionSearch": True, "maximumWorkingDimension": 1200,
            "maximumCandidates": 12, "orientationStepDegrees": 15,
            "developmentMaximumRegions": automatic["maximumRegions"],
            "developmentMinimumLocalizationScore": automatic["minimumLocalizationScore"],
            "developmentMinimumBandWidthPixels": automatic["minimumBandWidthPixels"],
            "developmentOcrRegionWidthPixels": automatic["ocrRegionWidthPixels"],
            "developmentOcrRegionHeightPixels": automatic["ocrRegionHeightPixels"],
            "developmentMinimumObservedHeightRatio": automatic["minimumObservedHeightRatio"],
            "developmentMinimumObservedWidthRatio": automatic["minimumObservedWidthRatio"],
            "developmentMaximumObservedWidthRatio": automatic["maximumObservedWidthRatio"],
        },
        "references": {"excludedPhysicalIdentity": accepted["excludedReferenceIdentity"]},
    }
    positive = engine.analyze_images(job, gray, gray.copy(), prototypes, reference_evidence,
                                     {"gateInput": "LOCKED_A01_DETECTOR_INPUT", "bfDfIndependent": True})
    qualified = [row for row in positive["localization"]["autoLocalizedGeometryEvidence"] if row["qualified"]]
    positive_minimum = min(float(row["observedToOcrHeightRatio"]) for row in qualified)

    false_regions = [
        engine.Region(f"RECORDED_{name}", "SIGNED_O2D20_FALSE_TEXTURE", x, y, width, height, angle, score)
        for name, x, y, width, height, angle, score in (
            ("105", 12321.870076675415, 9244.873315887451, 1228.8895260810853, 42.15563077807427, 34.31509017944336, 0.5638074278831482),
            ("135", 12321.870076675415, 9244.873315887451, 1228.8895260810853, 42.15563077807427, 34.31509017944336, 0.5638074278831482),
            ("150", 12321.870076675415, 9244.873315887451, 1228.8895260810853, 42.15563077807427, 34.31509017944336, 0.5638074278831482),
            ("120", 12320.894844970704, 9244.208135299683, 1226.5278601264954, 42.15563077807427, 34.31509017944336, 0.54914790391922),
        )
    ]
    unique_false = engine.deduplicate_auto_regions(false_regions)
    false_geometry = [engine.automatic_region_geometry(
        row, float(automatic["ocrRegionWidthPixels"]), float(automatic["ocrRegionHeightPixels"]),
        float(automatic["minimumObservedHeightRatio"]), float(automatic["minimumObservedWidthRatio"]),
        float(automatic["maximumObservedWidthRatio"]),
    ) for row in unique_false]
    negative_maximum = max(float(row["observedToOcrHeightRatio"]) for row in false_geometry)
    derived = (positive_minimum + negative_maximum) / 2.0
    floor = float(automatic["minimumObservedHeightRatio"])

    below = engine.Region("INJECTED_BELOW", "INJECTED_GEOMETRY_NEGATIVE", 0, 0, 800, (floor - 1e-6) * 400, 0, 1)
    at_floor = engine.Region("INJECTED_AT", "INJECTED_GEOMETRY_BOUNDARY", 0, 0, 800, floor * 400, 0, 1)
    below_evidence = engine.automatic_region_geometry(below, 1600, 400, floor, 0.5, 1.25)
    at_evidence = engine.automatic_region_geometry(at_floor, 1600, 400, floor, 0.5, 1.25)
    widened = json.loads(json.dumps(job))
    widened["authority"]["automaticIdentityAuthority"] = True
    widened_refused = False
    try:
        engine.validate_job_shape(widened)
    except ValueError:
        widened_refused = True

    require(checks, "positiveControlRecomputed", math.isclose(positive_minimum, EXPECTED_POSITIVE, abs_tol=1e-12))
    require(checks, "negativeControlRecomputed", math.isclose(negative_maximum, EXPECTED_NEGATIVE, abs_tol=1e-12))
    require(checks, "midpointExact", math.isclose(derived, EXPECTED_FLOOR, abs_tol=1e-15) and floor == EXPECTED_FLOOR)
    require(checks, "positiveAccepted", len(qualified) == 1 and positive_minimum > floor)
    require(checks, "falseTextureRejected", len(false_regions) == 4 and len(unique_false) == 1 and not false_geometry[0]["qualified"])
    require(checks, "injectedBelowRejected", not below_evidence["qualified"])
    require(checks, "injectedBoundaryAccepted", at_evidence["qualified"])
    require(checks, "widthEnvelopeUnchanged", automatic["minimumObservedWidthRatio"] == 0.5 and automatic["maximumObservedWidthRatio"] == 1.25)
    require(checks, "duplicateCollapsePreserved", positive["localization"]["autoLocalizedUniqueGeometricCandidateCount"] <= positive["localization"]["exceptionDiagnosticCandidateCount"])
    require(checks, "referenceCoverageHoldPreserved", any(row["code"] == "SCRIBE_REFERENCE_COVERAGE_HOLD" for row in positive["holds"]))
    require(checks, "developmentHoldPreserved", any(row["code"] == "SCRIBE_AUTO_LOCALIZATION_DEVELOPMENT_HOLD" for row in positive["holds"]))
    require(checks, "identityIneligible", positive["eligibleIdentity"] is False)
    require(checks, "widenedAuthorityRefused", widened_refused)
    passed = all(checks.values())
    gate = {
        "schema": "argos_r6v2_height_envelope_gate_v1", "createdUtc": datetime.now(timezone.utc).isoformat(),
        "state": "PASS_R6V2_FROZEN_HEIGHT_ENVELOPE" if passed else "FAIL_R6V2_FROZEN_HEIGHT_ENVELOPE",
        "engineSha256": ENGINE_SHA, "configurationSha256": engine.sha256_file(config_path),
        "positive": {"source": "FROZEN_15_CONTROL_CORPUS_A01", "minimumQualifiedHeightRatio": positive_minimum},
        "negative": {"source": NEGATIVE_SOURCE, "maximumHeightRatio": negative_maximum, "geometry": false_geometry},
        "derivedFloor": floor, "positiveMargin": positive_minimum - floor, "negativeMargin": floor - negative_maximum,
        "checks": checks, "providerActivated": False, "reviewOnly": True, "trainingEligible": False,
        "xmlEligible": False, "productionEligible": False,
    }
    engine.write_json_new(args.output, gate)
    print(json.dumps({"state": gate["state"], "output": str(args.output), "checkCount": len(checks)}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
