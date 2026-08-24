from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def load_engine(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("argos_opencv_scribe_v1", path)
    if spec is None or spec.loader is None:
        raise ValueError(f"Could not load provider engine: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def source_contract(engine: Any, path: Path, frame_id: str) -> dict[str, Any]:
    return {
        "path": str(path),
        "sha256": engine.sha256_file(path),
        "bytes": path.stat().st_size,
        "coordinateFrameId": frame_id,
    }


def run_case(
    engine: Any,
    case_root: Path,
    case_name: str,
    prototypes: dict[str, Any],
    reference_evidence: dict[str, Any],
) -> dict[str, Any]:
    root = (case_root / case_name).resolve()
    accepted_path = root / "IMAGE_FIRST_READER_RESULT.json"
    bf_path = root / "BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
    df_path = root / "DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
    for required in (accepted_path, bf_path, df_path):
        if not required.is_file():
            raise FileNotFoundError(f"Historical regression input is missing: {required}")

    accepted = read_json(accepted_path)
    expected = str(accepted["imageFirstString"])
    if not bool(accepted.get("checksumValid")):
        raise ValueError(f"Historical result is not checksum-valid: {accepted_path}")
    grid = accepted["grid"]
    width = int(grid["cellWidth"]) * 12
    height = int(grid["cellHeight"])
    bf_contract = source_contract(engine, bf_path, f"{case_name}_ORIENTED_NATIVE")
    df_contract = source_contract(engine, df_path, f"{case_name}_ORIENTED_NATIVE")
    bf, bf_evidence = engine.decode_source(bf_contract)
    df, df_evidence = engine.decode_source(df_contract)
    if bf.shape != df.shape:
        raise ValueError(f"Historical BF/DF dimensions differ: {case_name}")

    job = {
        "jobId": f"OCV02_REAL_REFERENCE_{case_name}",
        "search": {
            "expectedRegions": [
                {
                    "regionId": "FROZEN_ACCEPTED_GRID_PRIOR",
                    "source": "OPERATOR_DESIGNATED_REVIEW_ONLY",
                    "x": int(grid["x"]),
                    "y": int(grid["y"]),
                    "width": width,
                    "height": height,
                    "angleDegrees": 0.0,
                }
            ],
            "boundedExceptionSearch": True,
            "maximumWorkingDimension": 1600,
            "maximumCandidates": 32,
            "orientationStepDegrees": 15,
        },
    }
    result = engine.analyze_images(
        job,
        bf,
        df,
        prototypes,
        reference_evidence,
        {
            "bf": bf_evidence,
            "df": df_evidence,
            "historicalAcceptedResultPath": str(accepted_path),
            "historicalAcceptedResultSha256": engine.sha256_file(accepted_path),
        },
    )
    candidate_strings = [str(row["string"]) for row in result["candidates"]]
    expected_supported = expected == result["imageFirstString"] or expected in candidate_strings
    checks = {
        "expectedStringImageSupported": expected_supported,
        "preservedReferenceCoverageHold": result["state"] == "SCRIBE_REFERENCE_COVERAGE_HOLD",
        "referenceCountExact": int(result["provenance"]["references"]["referenceCount"]) == 456,
        "missingLabelsExact": result["provenance"]["references"]["missingBodyReferenceLabels"] == "IJKOQVWXYZ",
        "bfDfIndependent": bool(result["provenance"]["bfDfIndependent"]),
        "boundedExceptionSearchUsed": bool(result["provenance"]["boundedExceptionSearchUsed"]),
        "reviewOnly": bool(result["authority"]["reviewOnly"]),
        "automaticIdentityAuthorityDenied": not bool(result["authority"]["automaticIdentityAuthority"]),
        "productionEligibilityDenied": not bool(result["authority"]["productionEligible"]),
        "holdClearingDenied": not bool(result["authority"]["mayClearHolds"]),
    }
    return {
        "caseId": case_name,
        "passed": all(checks.values()),
        "expectedString": expected,
        "imageFirstString": result["imageFirstString"],
        "expectedStringInCandidates": expected in candidate_strings,
        "state": result["state"],
        "candidateCount": len(candidate_strings),
        "localizationCandidateCount": result["localization"]["candidateCount"],
        "selectedRegionId": result["localization"]["selectedRegionId"],
        "selectedRegionSource": result["localization"]["selectedRegionSource"],
        "checks": checks,
        "sources": {
            "bf": bf_evidence,
            "df": df_evidence,
            "historicalAcceptedResultPath": str(accepted_path),
            "historicalAcceptedResultSha256": engine.sha256_file(accepted_path),
        },
    }


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--manifest-sha256", required=True)
    parser.add_argument("--base-root", type=Path, required=True)
    parser.add_argument("--v5-root", type=Path, required=True)
    parser.add_argument("--case-root", type=Path, required=True)
    parser.add_argument("--case", action="append", required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    return parser.parse_args(list(argv))


def main(argv: Iterable[str]) -> int:
    args = parse_arguments(argv)
    if args.output_root.exists():
        raise FileExistsError(f"Output root already exists: {args.output_root}")
    engine = load_engine(args.engine.resolve())
    prototypes, reference_evidence = engine.load_reference_descriptors(
        args.manifest.resolve(),
        str(args.manifest_sha256),
        {
            "glyphs": args.base_root.resolve(),
            "glyphs_v5_confirmed_20260806": args.v5_root.resolve(),
        },
    )
    cases = [
        run_case(engine, args.case_root.resolve(), case_name, prototypes, reference_evidence)
        for case_name in args.case
    ]
    passed = all(row["passed"] for row in cases)
    gate = {
        "schema": "argos_opencv_scribe_real_reference_gate_v1",
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "PASS_OPENCV_SCRIBE_REAL_REFERENCE_GATE" if passed else "FAIL_OPENCV_SCRIBE_REAL_REFERENCE_GATE",
        "engineRevision": engine.ENGINE_REVISION,
        "enginePath": str(args.engine.resolve()),
        "engineSha256": engine.sha256_file(args.engine.resolve()),
        "providerRuntime": {
            "pythonVersion": sys.version.split()[0],
            "opencvVersion": engine.cv2.__version__,
            "numpyVersion": engine.np.__version__,
        },
        "referenceEvidence": reference_evidence,
        "caseCount": len(cases),
        "passCount": sum(1 for row in cases if row["passed"]),
        "cases": cases,
        "sourceClass": "LOCKED_HISTORICAL_ORIENTED_BF_DF_CROPS",
        "jbodProductionSourceRead": False,
        "reviewOnly": True,
        "automaticIdentityAuthority": False,
        "productionEligible": False,
        "mayClearHolds": False,
    }
    args.output_root.mkdir(parents=True, exist_ok=False)
    engine.write_json_new(args.output_root / "REAL_REFERENCE_GATE.json", gate)
    print(json.dumps({
        "state": gate["state"],
        "caseCount": gate["caseCount"],
        "passCount": gate["passCount"],
        "outputPath": str(args.output_root / "REAL_REFERENCE_GATE.json"),
    }))
    return 0 if passed else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as error:
        print(json.dumps({
            "state": "HOLD_OPENCV_SCRIBE_REAL_REFERENCE_GATE_ERROR",
            "errorType": type(error).__name__,
            "detail": str(error),
        }), file=sys.stderr)
        raise
