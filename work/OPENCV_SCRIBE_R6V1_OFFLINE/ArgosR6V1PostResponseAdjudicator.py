#!/usr/bin/env python3
"""Adjudicate an extracted R6V1 response without granting scribe authority."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


EXPECTED_BATCH_SHA256 = "7F77B8EFE0926E4AD37A737F07C98E1A3DF2E8F1392D0B47B886E05F9F52143B"
EXPECTED_ENGINE_SHA256 = "1E4C55AA4ECFB4DA3CEA9DF577DCFE86C4A2FADCB23D29F78719F3E0AC55E0E9"
EXPECTED_REFERENCE_SHA256 = "56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6"
EXPECTED_REFERENCE_COUNT = 456
EXPECTED_MISSING_LABELS = "IJKOQVWXYZ"
EXPECTED_CASES = {
    "Slot22": ("62619-433_20260824005735_Slot22", "CBE13E1B27C818E9B2FA610E1A01792991B371145AC6A4BE5C848078EECBCAA0"),
    "Slot23": ("62619-433_20260824005735_Slot23", "A05400FDC7E378205A0B6975626EECDDA1F1942AB4417AB1881DFA029C49F083"),
    "Slot24": ("62619-433_20260824005735_Slot24", "3315AFC2DC2B7674B2C9A0EFC799758A8D37E0726E34607580A5AD01A2A9E6C9"),
    "Slot25": ("62619-433_20260824005735_Slot25", "30D6AEC2A200772E0B1DE15E99261F9742CEA8A845A5B3A4D1113C2B18490442"),
}


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


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=False)
        stream.write("\n")


def require(errors: list[dict[str, str]], condition: bool, code: str, detail: str) -> None:
    if not condition:
        errors.append({"code": code, "detail": detail})


def hold_codes(result: dict[str, Any]) -> list[str]:
    return [str(row.get("code", "")) for row in result.get("holds", []) if isinstance(row, dict)]


def authority_is_review_only(authority: dict[str, Any]) -> bool:
    return (
        authority.get("reviewOnly") is True
        and authority.get("automaticIdentityAuthority") is False
        and authority.get("trainingEligible") is False
        and authority.get("xmlEligible") is False
        and authority.get("productionEligible") is False
        and authority.get("mayClearHolds") is False
    )


def adjudicate(response_root: Path, package_root: Path) -> tuple[dict[str, Any], int]:
    errors: list[dict[str, str]] = []
    case_reports: list[dict[str, Any]] = []
    response_root = response_root.resolve()
    package_root = package_root.resolve()
    batch_path = package_root / "BATCH.json"
    gate_path = response_root / "BATCH_GATE.json"
    execution_path = response_root / "EXECUTION.json"

    for path, code in ((batch_path, "BATCH_ABSENT"), (gate_path, "BATCH_GATE_ABSENT"), (execution_path, "EXECUTION_ABSENT")):
        require(errors, path.is_file(), code, str(path))
    if errors:
        return build_report(errors, case_reports), 2

    batch = read_json(batch_path)
    gate = read_json(gate_path)
    execution = read_json(execution_path)
    batch_sha = sha256_file(batch_path)
    gate_sha = sha256_file(gate_path)
    require(errors, batch_sha == EXPECTED_BATCH_SHA256, "BATCH_HASH_MISMATCH", batch_sha)
    require(errors, batch.get("schema") == "argos_opencv_scribe_batch_v1", "BATCH_SCHEMA_MISMATCH", str(batch.get("schema")))
    require(errors, batch.get("engine", {}).get("sha256") == EXPECTED_ENGINE_SHA256, "ENGINE_PIN_MISMATCH", str(batch.get("engine", {}).get("sha256")))
    require(errors, batch.get("referenceBundle", {}).get("sha256") == EXPECTED_REFERENCE_SHA256, "REFERENCE_PIN_MISMATCH", str(batch.get("referenceBundle", {}).get("sha256")))
    require(errors, authority_is_review_only(batch.get("authority", {})), "BATCH_AUTHORITY_WIDENED", "Batch authority is not review-only.")
    serialization = batch.get("serialization", {})
    require(errors, serialization.get("maximumConcurrentProviderChildren") == 1, "BATCH_NOT_SERIALIZED", str(serialization))
    require(errors, serialization.get("automaticRetryAllowed") is False, "BATCH_RETRY_WIDENED", str(serialization))

    cases = batch.get("cases", [])
    case_slots = [str(row.get("slot", "")) for row in cases if isinstance(row, dict)]
    require(errors, sorted(case_slots) == sorted(EXPECTED_CASES), "CASE_SET_MISMATCH", ",".join(case_slots))
    require(errors, gate.get("schema") == "argos_r6v1_scribe_batch_gate_v1", "GATE_SCHEMA_MISMATCH", str(gate.get("schema")))
    require(errors, gate.get("state") == "PASS_R6V1_REAL_IMAGE_REVIEW_ONLY_BATCH", "GATE_STATE_NOT_PASS", str(gate.get("state")))
    require(errors, gate.get("disposition") == "PENDING_GATE", "GATE_DISPOSITION_WIDENED", str(gate.get("disposition")))
    require(errors, gate.get("caseCount") == 4, "GATE_CASE_COUNT_MISMATCH", str(gate.get("caseCount")))
    require(errors, gate.get("identityEligibleCount") == 0, "GATE_IDENTITY_ELIGIBLE_NONZERO", str(gate.get("identityEligibleCount")))
    require(errors, gate.get("engineSha256") == EXPECTED_ENGINE_SHA256, "GATE_ENGINE_HASH_MISMATCH", str(gate.get("engineSha256")))
    require(errors, gate.get("batchSha256") == EXPECTED_BATCH_SHA256, "GATE_BATCH_HASH_MISMATCH", str(gate.get("batchSha256")))
    require(errors, gate.get("referenceBundleSha256") == EXPECTED_REFERENCE_SHA256, "GATE_REFERENCE_HASH_MISMATCH", str(gate.get("referenceBundleSha256")))
    require(errors, gate.get("maximumConcurrentProviderChildren") == 1 and gate.get("automaticRetryAllowed") is False, "GATE_EXECUTION_BOUNDARY_WIDENED", "Serialization/retry boundary changed.")
    require(errors, execution.get("schema") == "argos_r6v1_execution_v1" and execution.get("state") == "PASS_R6V1_EXECUTION", "EXECUTION_STATE_NOT_PASS", str(execution.get("state")))
    require(errors, execution.get("batchGateSha256") == gate_sha, "EXECUTION_GATE_HASH_MISMATCH", str(execution.get("batchGateSha256")))

    gate_rows = {str(row.get("slot", "")): row for row in gate.get("results", []) if isinstance(row, dict)}
    require(errors, sorted(gate_rows) == sorted(EXPECTED_CASES), "GATE_RESULT_SET_MISMATCH", ",".join(sorted(gate_rows)))
    for case in cases:
        if not isinstance(case, dict):
            continue
        slot = str(case.get("slot", ""))
        if slot not in EXPECTED_CASES:
            continue
        identity, job_sha = EXPECTED_CASES[slot]
        job_path = package_root / str(case.get("jobFile", ""))
        result_path = response_root / slot / "RESULT.json"
        row_errors: list[dict[str, str]] = []
        require(row_errors, case.get("physicalIdentity") == identity, "CASE_IDENTITY_MISMATCH", str(case.get("physicalIdentity")))
        require(row_errors, case.get("jobSha256") == job_sha, "CASE_JOB_PIN_MISMATCH", str(case.get("jobSha256")))
        require(row_errors, job_path.is_file() and sha256_file(job_path) == job_sha, "JOB_HASH_MISMATCH", str(job_path))
        require(row_errors, result_path.is_file(), "RESULT_ABSENT", str(result_path))
        if row_errors:
            errors.extend({"code": f"{slot}_{row['code']}", "detail": row["detail"]} for row in row_errors)
            case_reports.append({"slot": slot, "state": "HOLD", "errors": row_errors})
            continue
        job = read_json(job_path)
        result = read_json(result_path)
        result_sha = sha256_file(result_path)
        gate_row = gate_rows.get(slot, {})
        sources = result.get("provenance", {}).get("sources", {})
        references = result.get("provenance", {}).get("references", {})
        localization = result.get("localization", {})
        codes = hold_codes(result)
        require(row_errors, gate_row.get("physicalIdentity") == identity, "GATE_ROW_IDENTITY_MISMATCH", str(gate_row.get("physicalIdentity")))
        require(row_errors, gate_row.get("resultSha256") == result_sha, "RESULT_HASH_MISMATCH", result_sha)
        require(row_errors, result.get("schema") == "argos_opencv_scribe_result_v2", "RESULT_SCHEMA_MISMATCH", str(result.get("schema")))
        require(row_errors, result.get("jobId") == job.get("jobId"), "RESULT_JOB_ID_MISMATCH", str(result.get("jobId")))
        require(row_errors, result.get("eligibleIdentity") is False and gate_row.get("eligibleIdentity") is False, "IDENTITY_ELIGIBLE", "Result or gate row grants identity eligibility.")
        require(row_errors, authority_is_review_only(result.get("authority", {})), "RESULT_AUTHORITY_WIDENED", str(result.get("authority")))
        require(row_errors, sources.get("jobSha256") == job_sha, "RESULT_JOB_HASH_MISMATCH", str(sources.get("jobSha256")))
        for channel in ("bf", "df"):
            expected_source = job.get("inputs", {}).get(channel, {})
            actual_source = sources.get(channel, {})
            require(row_errors, actual_source.get("sha256") == expected_source.get("sha256"), f"{channel.upper()}_SOURCE_HASH_MISMATCH", str(actual_source.get("sha256")))
            require(row_errors, actual_source.get("bytes") == expected_source.get("bytes"), f"{channel.upper()}_SOURCE_BYTES_MISMATCH", str(actual_source.get("bytes")))
            require(row_errors, actual_source.get("canonicalProvenancePath") == expected_source.get("canonicalProvenancePath"), f"{channel.upper()}_SOURCE_PATH_MISMATCH", str(actual_source.get("canonicalProvenancePath")))
        require(row_errors, references.get("manifestSha256") == job.get("references", {}).get("manifestSha256"), "REFERENCE_MANIFEST_HASH_MISMATCH", str(references.get("manifestSha256")))
        require(row_errors, references.get("referenceCount") == EXPECTED_REFERENCE_COUNT, "REFERENCE_COUNT_MISMATCH", str(references.get("referenceCount")))
        require(row_errors, references.get("referenceCoverageComplete") is False and references.get("missingBodyReferenceLabels") == EXPECTED_MISSING_LABELS, "REFERENCE_COVERAGE_WIDENED", str(references))
        require(row_errors, codes.count("SCRIBE_REFERENCE_COVERAGE_HOLD") == 1, "REFERENCE_COVERAGE_HOLD_MISMATCH", ",".join(codes))
        require(row_errors, codes.count("SCRIBE_AUTO_LOCALIZATION_DEVELOPMENT_HOLD") == 1, "LOCALIZATION_HOLD_MISMATCH", ",".join(codes))
        require(row_errors, localization.get("autoLocalizedDevelopmentMode") is True, "LOCALIZATION_MODE_MISMATCH", str(localization.get("autoLocalizedDevelopmentMode")))
        unique_count = localization.get("autoLocalizedUniqueGeometricCandidateCount")
        diagnostic_count = localization.get("exceptionDiagnosticCandidateCount")
        promoted_count = localization.get("autoLocalizedPromotedCandidateCount")
        geometry = localization.get("autoLocalizedGeometryEvidence", [])
        require(row_errors, isinstance(unique_count, int) and isinstance(diagnostic_count, int) and 0 <= unique_count <= diagnostic_count, "DUPLICATE_COLLAPSE_INVALID", f"unique={unique_count};diagnostic={diagnostic_count}")
        require(row_errors, isinstance(promoted_count, int) and 0 <= promoted_count <= min(2, unique_count if isinstance(unique_count, int) else 0), "PROMOTED_COUNT_INVALID", str(promoted_count))
        require(row_errors, isinstance(geometry, list) and len(geometry) == unique_count, "GEOMETRY_EVIDENCE_COUNT_MISMATCH", str(len(geometry) if isinstance(geometry, list) else -1))
        region_ids = [str(item.get("regionId", "")) for item in geometry if isinstance(item, dict)]
        require(row_errors, len(region_ids) == len(set(region_ids)), "DUPLICATE_GEOMETRY_REGION_ID", ",".join(region_ids))
        require(row_errors, gate_row.get("localization", {}).get("autoLocalizedUniqueGeometricCandidateCount") == unique_count, "GATE_LOCALIZATION_COUNT_MISMATCH", str(gate_row.get("localization")))
        errors.extend({"code": f"{slot}_{row['code']}", "detail": row["detail"]} for row in row_errors)
        case_reports.append({
            "slot": slot,
            "physicalIdentity": identity,
            "state": "PASS" if not row_errors else "HOLD",
            "resultSha256": result_sha,
            "resultState": str(result.get("state", "")),
            "observedEligibleIdentity": bool(result.get("eligibleIdentity")),
            "observedGateEligibleIdentity": bool(gate_row.get("eligibleIdentity")),
            "identityEligible": False,
            "localization": {
                "diagnosticCandidateCount": diagnostic_count,
                "uniqueGeometricCandidateCount": unique_count,
                "promotedCandidateCount": promoted_count,
            },
            "holdCodes": codes,
            "errors": row_errors,
        })
    return build_report(errors, case_reports), 0 if not errors else 2


def build_report(errors: list[dict[str, str]], cases: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schema": "argos_r6v1_post_response_adjudication_v1",
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "PASS_R6V1_POST_RESPONSE_REVIEW_ONLY" if not errors else "HOLD_R6V1_POST_RESPONSE_ADJUDICATION",
        "disposition": "PENDING_GATE",
        "caseCount": len(cases),
        "passedCaseCount": sum(1 for row in cases if row.get("state") == "PASS"),
        "observedIdentityEligibleCount": sum(1 for row in cases if row.get("observedEligibleIdentity") or row.get("observedGateEligibleIdentity")),
        "identityEligibleCount": 0,
        "cases": cases,
        "failures": errors,
        "automaticRetryAllowed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "mayClearHolds": False,
        "providerActivated": False,
    }


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--response-root", type=Path, required=True)
    parser.add_argument("--package-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(list(argv))


def main(argv: Iterable[str]) -> int:
    arguments = parse_arguments(argv)
    report, exit_code = adjudicate(arguments.response_root, arguments.package_root)
    write_json_new(arguments.output, report)
    print(json.dumps({"state": report["state"], "output": str(arguments.output), "failureCount": len(report["failures"])}))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
