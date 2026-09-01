#!/usr/bin/env python3
"""Offline good/failure cases for the frozen R6V1 response adjudicator."""

from __future__ import annotations

import argparse
import importlib.util
import json
import shutil
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def load_module(path: Path):
    specification = importlib.util.spec_from_file_location("r6v1_adjudicator", path)
    if specification is None or specification.loader is None:
        raise RuntimeError("Adjudicator module could not be loaded.")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def authority() -> dict[str, bool]:
    return {
        "reviewOnly": True,
        "automaticIdentityAuthority": False,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "mayClearHolds": False,
    }


def build_result(job: dict[str, Any], job_sha: str, revision: str) -> dict[str, Any]:
    sources: dict[str, Any] = {"jobSha256": job_sha}
    for channel in ("bf", "df"):
        source = job["inputs"][channel]
        sources[channel] = {
            "path": source["path"],
            "canonicalProvenancePath": source["canonicalProvenancePath"],
            "ioPathClass": source["ioPathClass"],
            "aliasName": source["aliasName"],
            "bytes": source["bytes"],
            "sha256": source["sha256"],
            "width": 15400,
            "height": 10288,
        }
    localization = {
        "standardCandidateCount": 1,
        "qualifiedInstalledDetectorInputCount": 0,
        "exceptionDiagnosticCandidateCount": 3,
        "autoLocalizedDevelopmentMode": True,
        "autoLocalizedEligibleBandCount": 2,
        "autoLocalizedPromotedCandidateCount": 1,
        "autoLocalizedUniqueGeometricCandidateCount": 2,
        "autoLocalizedGeometryQualifiedCount": 1,
        "autoLocalizedGeometryRejectedCount": 1,
        "autoLocalizedGeometryEvidence": [
            {"regionId": "BF_1", "qualified": True},
            {"regionId": "DF_1", "qualified": False},
        ],
        "selectedRegionId": "BF_1",
    }
    return {
        "schema": "argos_opencv_scribe_result_v2",
        "revision": revision,
        "jobId": job["jobId"],
        "state": "SCRIBE_REFERENCE_COVERAGE_HOLD",
        "eligibleIdentity": False,
        "imageFirstString": "1234567890AB",
        "proposedString": "1234567890AB",
        "checksumState": "SCRIBE_M12_IMAGE_FIRST_CHECKSUM_VALID_REVIEW_ONLY",
        "localization": localization,
        "hypotheses": [],
        "candidates": [],
        "holds": [
            {"code": "SCRIBE_REFERENCE_COVERAGE_HOLD", "detail": "Frozen references are incomplete."},
            {"code": "SCRIBE_AUTO_LOCALIZATION_DEVELOPMENT_HOLD", "detail": "Development only."},
        ],
        "provenance": {
            "engineRevision": revision,
            "sources": sources,
            "references": {
                "manifestSha256": job["references"]["manifestSha256"],
                "referenceCount": 456,
                "prototypeLabels": "0123456789ABCDEFGHLMNPRSTU",
                "missingBodyReferenceLabels": "IJKOQVWXYZ",
                "referenceCoverageComplete": False,
            },
        },
        "authority": authority(),
    }


def refresh_response(module: Any, response: Path) -> None:
    gate_path = response / "BATCH_GATE.json"
    gate = read_json(gate_path)
    for row in gate["results"]:
        result_path = response / row["slot"] / "RESULT.json"
        row["resultSha256"] = module.sha256_file(result_path)
        result = read_json(result_path)
        row["eligibleIdentity"] = False
        row["state"] = result["state"]
        row["holds"] = result["holds"]
        row["localization"] = result["localization"]
    write_json(gate_path, gate)
    execution_path = response / "EXECUTION.json"
    execution = read_json(execution_path)
    execution["batchGateSha256"] = module.sha256_file(gate_path)
    write_json(execution_path, execution)


def build_good_response(module: Any, package_root: Path, response: Path) -> None:
    batch = read_json(package_root / "BATCH.json")
    results = []
    for case in batch["cases"]:
        job_path = package_root / case["jobFile"]
        job = read_json(job_path)
        result_path = response / case["slot"] / "RESULT.json"
        write_json(result_path, build_result(job, module.sha256_file(job_path), batch["engine"]["revision"]))
        result = read_json(result_path)
        results.append({
            "slot": case["slot"],
            "physicalIdentity": case["physicalIdentity"],
            "state": result["state"],
            "eligibleIdentity": False,
            "imageFirstString": result["imageFirstString"],
            "proposedString": result["proposedString"],
            "checksumState": result["checksumState"],
            "resultPath": str(result_path),
            "resultSha256": module.sha256_file(result_path),
            "holds": result["holds"],
            "localization": result["localization"],
        })
    gate = {
        "schema": "argos_r6v1_scribe_batch_gate_v1",
        "state": "PASS_R6V1_REAL_IMAGE_REVIEW_ONLY_BATCH",
        "disposition": "PENDING_GATE",
        "revision": batch["revision"],
        "caseCount": 4,
        "identityEligibleCount": 0,
        "engineSha256": module.EXPECTED_ENGINE_SHA256,
        "batchSha256": module.EXPECTED_BATCH_SHA256,
        "referenceBundleSha256": module.EXPECTED_REFERENCE_SHA256,
        "results": results,
        "maximumConcurrentProviderChildren": 1,
        "automaticRetryAllowed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
    }
    write_json(response / "BATCH_GATE.json", gate)
    write_json(response / "EXECUTION.json", {
        "schema": "argos_r6v1_execution_v1",
        "state": "PASS_R6V1_EXECUTION",
        "batchGateSha256": module.sha256_file(response / "BATCH_GATE.json"),
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    })


def mutate_identity(result: dict[str, Any]) -> None:
    result["eligibleIdentity"] = True


def mutate_source(result: dict[str, Any]) -> None:
    result["provenance"]["sources"]["bf"]["sha256"] = "0" * 64


def mutate_duplicate(result: dict[str, Any]) -> None:
    result["localization"]["autoLocalizedGeometryEvidence"][1]["regionId"] = "BF_1"


def mutate_coverage(result: dict[str, Any]) -> None:
    result["holds"] = [row for row in result["holds"] if row["code"] != "SCRIBE_REFERENCE_COVERAGE_HOLD"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    script = Path(__file__).resolve()
    module = load_module(script.with_name("ArgosR6V1PostResponseAdjudicator.py"))
    repository = script.parents[2]
    package_root = repository / "work/OPENCV_SCRIBE_R6V1"
    cases = []
    with tempfile.TemporaryDirectory(prefix="argos-r6v1-adjudication-") as temporary:
        root = Path(temporary)
        good = root / "good"
        build_good_response(module, package_root, good)
        report, code = module.adjudicate(good, package_root)
        cases.append({"id": "GOOD", "exitCode": code, "state": report["state"], "failureCodes": [], "passed": code == 0 and report["passedCaseCount"] == 4})
        mutations = {
            "IDENTITY_ELIGIBLE": (mutate_identity, "Slot22_IDENTITY_ELIGIBLE"),
            "SOURCE_HASH": (mutate_source, "Slot22_BF_SOURCE_HASH_MISMATCH"),
            "DUPLICATE_GEOMETRY": (mutate_duplicate, "Slot22_DUPLICATE_GEOMETRY_REGION_ID"),
            "MISSING_COVERAGE_HOLD": (mutate_coverage, "Slot22_REFERENCE_COVERAGE_HOLD_MISMATCH"),
        }
        for case_id, (mutation, expected_code) in mutations.items():
            response = root / case_id
            shutil.copytree(good, response)
            result_path = response / "Slot22/RESULT.json"
            result = read_json(result_path)
            mutation(result)
            write_json(result_path, result)
            refresh_response(module, response)
            report, code = module.adjudicate(response, package_root)
            failure_codes = [row["code"] for row in report["failures"]]
            cases.append({
                "id": case_id,
                "exitCode": code,
                "state": report["state"],
                "failureCodes": failure_codes,
                "passed": code == 2 and expected_code in failure_codes and report["identityEligibleCount"] == 0,
            })
    output = {
        "schema": "argos_r6v1_post_response_adjudication_test_v1",
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "PASS_R6V1_POST_RESPONSE_ADJUDICATION_TEST" if all(row["passed"] for row in cases) else "FAIL_R6V1_POST_RESPONSE_ADJUDICATION_TEST",
        "caseCount": len(cases),
        "cases": cases,
        "frozenPackageChanged": False,
        "liveProviderRead": False,
        "identityEligibleCount": 0,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(output, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"state": output["state"], "output": str(args.output)}))
    return 0 if output["state"].startswith("PASS_") else 1


if __name__ == "__main__":
    raise SystemExit(main())
