#!/usr/bin/env python3
"""Run the frozen O3F8 R9 draft in separately authorized stages on JBOD."""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any


HERE = Path(__file__).resolve().parent
R9 = HERE / "FullPerimeterWaferTopologyOpenCvR9.py"
R8 = HERE / "FullPerimeterWaferTopologyOpenCvR8.py"
O3P8 = HERE / "Detect-O3P8FrontSplitNotches.py"
LOCAL_GATE = HERE / "Test-O3F8DfSeededFallback.py"
O3P8_JOB = HERE / "O3P8_POST2_SHORT_ALIAS_JOB.json"
CANONICAL_JOB = HERE / "O3M9_SLOT16_JOB.json"
INSTALLED = Path(r"C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1")
SOURCE_RESULTS = Path(r"D:\O3F6R8M\RESULTS.json")
REVIEW_ORDER = Path(r"D:\O3F7SEL2\REVIEW_ORDER.json")
RUNTIME = Path(r"D:\AFCV1\rt\python.exe")
R9_SHA256 = "DB44AD35205AC088FE7E24C1CC8FA9291311922A7D31E0F1C055BA92EAFD2FC1"
R8_SHA256 = "068ECC0D4F547FCFD7A0A2AEDF673B71BB0C46207DE8EC0F47312A9030B0734B"
O3P8_SHA256 = "41F60AF393E0B2C752AF6B33BB6673145490AE2BB346A4DA8E59A2D42E383E36"
LOCAL_GATE_SHA256 = "BAEE06BF09694BD5BADA78F808D876906CD8D297CF518A7052183DEDE1F33D18"
O3P8_JOB_SHA256 = "2C2D656A879BBA1DEC6377D1855A949459C7AC6F50145761B8D283076FEAD1F9"
CANONICAL_JOB_SHA256 = "E384ABD12E9B77DB9B4492504A5D792E316C5396C3B0A3E1D2B1AB11BB4C7DD3"
R6_SHA256 = "90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30"
TOPOLOGY_SHA256 = "D8897C1A5B60CB5AA9B0343CF8C9E5A249CCC5DEF5FBCDFE645EC08C354EF3BD"
RESULTS_SHA256 = "A933227FE4F41259D53D586CBB5189E1B6542B96B7585B606207DAFD35326BD8"
REVIEW_SHA256 = "D57DFE4301FEE2144D18EF4DB2BFD0A323EB095C117BBF10A856A691A8E73BBA"
RUNTIME_SHA256 = "7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1"
EXPECTED_OPENCV_VERSION = "5.0.0"
EXPECTED_NUMPY_VERSION = "2.5.2"
EXPECTED_PROVIDER_ERROR_COUNT = 5


def need(value: Any, message: str) -> None:
    if not value:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def required_sha256(value: Any, label: str) -> str:
    text = str(value or "").upper()
    need(len(text) == 64 and all(character in "0123456789ABCDEF" for character in text), f"{label} is not an exact SHA-256")
    return text


def normalized(path: Path) -> str:
    return os.path.normcase(str(path.resolve(strict=False)))


def read_json_and_sha256(path: Path) -> tuple[dict[str, Any], str]:
    data = path.read_bytes()
    value = json.loads(data.decode("utf-8"))
    need(isinstance(value, dict), f"JSON root is not an object: {path}")
    return value, hashlib.sha256(data).hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    return read_json_and_sha256(path)[0]


def write_new(path: Path, value: Any) -> None:
    partial = path.with_name(path.name + ".partial")
    need(not path.exists() and not partial.exists(), f"Output collision: {path}")
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def isolated_env() -> dict[str, str]:
    blocked = {"PYTHONHOME", "PYTHONPATH", "PYTHONUSERBASE", "PYTHONSTARTUP", "PYTHONINSPECT"}
    env = {key: value for key, value in os.environ.items() if key.upper() not in blocked}
    env.update({"PYTHONNOUSERSITE": "1", "PYTHONDONTWRITEBYTECODE": "1", "PYTHONUTF8": "1", "ARGOS_O3F8_RUNTIME_ROOT": str(RUNTIME.parent)})
    return env


def fixed_job_projection(job: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in job.items() if key not in ("revision", "inputs")}


def input_binding(job: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = job.get("inputs")
    need(isinstance(rows, list) and len(rows) == 2, "Job input cardinality changed")
    by_channel = {str(row["channel"]): row for row in rows}
    need(set(by_channel) == {"BF", "DF"}, "Job BF/DF channels changed")
    return by_channel


def assert_source_binding(actual: dict[str, Any], expected: dict[str, Any], safe_id: str, channel: str) -> None:
    need(str(actual.get("identity")) == f"{safe_id}-{channel}" and str(actual.get("pairId")) == safe_id, f"{channel} identity binding changed")
    need(str(actual.get("channel")) == channel, f"{channel} channel binding changed")
    need(Path(str(actual.get("path"))).resolve(strict=False) == Path(str(expected["path"])).resolve(strict=False), f"{channel} source path changed")
    need(int(actual.get("bytes", -1)) == int(expected["bytes"]), f"{channel} source byte count changed")
    need(str(actual.get("sha256", "")).upper() == str(expected["sha256"]).upper(), f"{channel} source hash changed")


def source_binding_projection(expected: dict[str, Any], safe_id: str, channel: str) -> dict[str, Any]:
    return {
        "identity": f"{safe_id}-{channel}",
        "pairId": safe_id,
        "channel": channel,
        "path": str(expected["path"]),
        "bytes": int(expected["bytes"]),
        "sha256": required_sha256(expected["sha256"], f"{channel} source"),
    }


def without_assets(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: without_assets(item) for key, item in value.items() if key not in ("assets", "overview")}
    if isinstance(value, list):
        return [without_assets(item) for item in value]
    return value


def r8_decision_projection(result: dict[str, Any]) -> dict[str, Any]:
    return without_assets(
        {
            "bfState": result["bf"]["state"],
            "dfState": result["df"]["state"],
            "bfCandidates": result["bf"]["candidates"],
            "dfCandidates": result["df"]["candidates"],
            "physicalIndentationCandidates": result["physicalIndentationCandidates"],
            "eligiblePhysicalCandidateIndices": result["eligiblePhysicalCandidateIndices"],
            "selectedReviewOnlyManufacturedNotch": result.get("selectedReviewOnlyManufacturedNotch"),
        }
    )


def validate_output_root(output_root: Path) -> Path:
    need(output_root.is_absolute(), "Output root must be absolute")
    resolved = output_root.resolve(strict=False)
    need(resolved.drive.upper() == "D:", "Output root must be on JBOD D:")
    need(resolved.parent == Path(resolved.anchor) and resolved.name.upper().startswith("O3F8"), "Output root must be a short D:\\O3F8* development root")
    need(resolved.parent.is_dir() and not resolved.exists(), "Output root parent must exist and root must be create-new")
    need(len(str(resolved)) + 96 < 200 and len(resolved.name) <= 80, "Output root is not path-safe")
    return resolved


def validate_new_paths(paths: list[Path]) -> dict[str, Any]:
    need(paths, "No planned output paths")
    longest = max(paths, key=lambda path: len(str(path)))
    longest_component = max((part for path in paths for part in path.parts), key=len)
    need(len(str(longest)) < 200, f"Planned output path is unsafe: {longest}")
    need(len(longest_component) <= 80, f"Planned output component is unsafe: {longest_component}")
    return {"plannedLeafCount": len(paths), "maximumPathLength": len(str(longest)), "maximumComponentLength": len(longest_component), "longestLeaf": str(longest)}


def validate_stage_path_plan(output_root: Path, selected: list[dict[str, Any]]) -> dict[str, Any]:
    leaves = [output_root / "SUMMARY.json.partial"]
    for ordinal, row in enumerate(selected, 1):
        safe_id = str(row["safeId"])
        need(not any(character in safe_id for character in '\\/:*?"<>|'), f"Unsafe safeId: {safe_id}")
        stem = safe_id.lower().replace("-", "")
        case_root = output_root / "cases" / f"C{ordinal:04d}"
        leaves.extend(
            [
                output_root / "jobs" / f"J{ordinal:04d}.json.partial",
                output_root / f"C{ordinal:04d}.stdout.txt",
                output_root / f"C{ordinal:04d}.stderr.txt",
                case_root / "MANIFEST.json.partial",
                case_root / f"{stem}_bf_c24_enhanced.png",
                case_root / f"{stem}_df_c24_enhanced.png",
                case_root / f"{hashlib.sha256(safe_id.encode('utf-8')).hexdigest()[:16]}_bf_o3p8_recovery_enhanced.png",
                case_root / f"{stem}_bf_overview.png",
                case_root / f"{stem}_df_overview.png",
            ]
        )
        for channel in ("bf", "df"):
            need(len(str(Path(str(row[channel]["path"])).resolve(strict=False))) < 200, f"Source path is unsafe: {row[channel]['path']}")
    return validate_new_paths(leaves)


def self_test() -> None:
    rows = [{"identity": "PatternedFront\\p"}, {"identity": "UnpatternedFront\\u"}, {"identity": "BackSide_BowComp\\b"}]
    current = [row for row in rows if row["identity"].startswith(("PatternedFront\\", "UnpatternedFront\\"))]
    need([row["identity"] for row in current] == ["PatternedFront\\p", "UnpatternedFront\\u"], "Current-recipe selector failed")
    print("PASS_O3F8_STAGED_RUNNER_SELF_TEST")


def frozen_inputs() -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    source, source_sha256 = read_json_and_sha256(SOURCE_RESULTS)
    review, review_sha256 = read_json_and_sha256(REVIEW_ORDER)
    need(source_sha256 == RESULTS_SHA256, "O3F6 results changed")
    need(review_sha256 == REVIEW_SHA256, "O3F7 review order changed")
    need(
        review.get("schema") == "argos_ocv03_o3f7_existing_crop_review_order_v1"
        and review.get("state") == "READY_FOR_OPERATOR_FILE_REVIEW"
        and int(review.get("caseCount", -1)) == 24,
        "Frozen O3F7 review header changed",
    )
    rows = list(source["rows"])
    cases = list(review["cases"])
    need(len(rows) == 978 and len(cases) == 24, "Frozen corpus or review cardinality changed")
    need(len({str(row["identity"]) for row in rows}) == 978, "Duplicate source identity")
    need(len({str(row["safeId"]) for row in rows}) == 978, "Duplicate safe pair identity")
    case_identities = [str(case["identity"]) for case in cases]
    need(len(set(case_identities)) == 24 and set(case_identities).issubset({str(row["identity"]) for row in rows}), "Review identities are not a unique corpus subset")
    need(set(case_identities[:6]).isdisjoint(case_identities[6:]), "Development and holdout partitions overlap")
    return rows, cases


def review_manifest_reference(row: dict[str, Any], case: dict[str, Any]) -> dict[str, str] | None:
    identity = str(row["identity"])
    safe_id = str(row["safeId"])
    state = str(row["r8State"])
    need(str(case.get("identity")) == identity, "O3F7 review identity changed")
    need(str(case.get("safeId")) == safe_id, f"O3F7 safe ID changed: {identity}")
    need(str(case.get("state")) == state, f"O3F7 state changed: {identity}")
    row_diagnostic = row.get("r7DiagnosticRoot")
    case_diagnostic = case.get("diagnosticRoot")
    if row_diagnostic is None or case_diagnostic is None:
        need(row_diagnostic is None and case_diagnostic is None, f"O3F7 diagnostic root changed: {identity}")
    else:
        need(normalized(Path(str(case_diagnostic))) == normalized(Path(str(row_diagnostic))), f"O3F7 diagnostic root changed: {identity}")
    if state == "HOLD_FRONT_NOTCH_PROVIDER_ERROR":
        need(
            not case.get("manifestPath")
            and not case.get("manifestSha256")
            and case.get("assetState") in ("NO_DIAGNOSTIC_ROOT_PROVIDER_ERROR", "NO_MANIFEST_PROVIDER_ERROR"),
            f"Provider-error review case unexpectedly has executable evidence: {identity}",
        )
        return None
    need(row_diagnostic is not None, f"Executable row lacks diagnostic root: {identity}")
    expected_path = Path(str(row_diagnostic)) / "MANIFEST.json"
    case_path = Path(str(case.get("manifestPath") or ""))
    need(case_path.is_absolute() and normalized(case_path) == normalized(expected_path), f"O3F7 manifest path changed: {identity}")
    need(case.get("assetState") == "EXISTING_DECLARED_ASSETS_READY", f"O3F7 manifest asset state changed: {identity}")
    expected_hash = required_sha256(case.get("manifestSha256"), f"O3F7 manifest {identity}")
    if row.get("r7ManifestSha256"):
        need(required_sha256(row["r7ManifestSha256"], f"O3F6 manifest {identity}") == expected_hash, f"O3F6/O3F7 manifest pins disagree: {identity}")
    return {"path": str(case_path), "sha256": expected_hash}


def select(stage: str, rows: list[dict[str, Any]], cases: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_identity = {str(row["identity"]): row for row in rows}
    if stage in ("DEV6", "HOLDOUT18"):
        chosen = cases[:6] if stage == "DEV6" else cases[6:]
        need(len(chosen) == (6 if stage == "DEV6" else 18), "Review slice changed")
        return [by_identity[str(case["identity"])] for case in chosen]
    if stage == "CURRENT265":
        chosen = [row for row in rows if str(row["identity"]).startswith(("PatternedFront\\", "UnpatternedFront\\"))]
        need(len(chosen) == 265, "Current-recipe count changed")
        return chosen
    need(stage == "FULL978", "Unknown stage")
    return rows


def load_prior_evidence(
    row: dict[str, Any], manifest_path: Path, expected_manifest_sha256: str | None, canonical_fixed: dict[str, Any]
) -> tuple[dict[str, Any], dict[str, Any], dict[str, str]]:
    identity = str(row["identity"])
    safe_id = str(row["safeId"])
    need(manifest_path.is_file(), f"Prior manifest is missing: {identity}")
    prior, actual_manifest_sha256 = read_json_and_sha256(manifest_path)
    if expected_manifest_sha256 is not None:
        need(actual_manifest_sha256 == required_sha256(expected_manifest_sha256, f"Prior manifest {identity}"), f"Prior manifest hash changed: {identity}")
    if row.get("r7ManifestSha256"):
        need(actual_manifest_sha256 == required_sha256(row["r7ManifestSha256"], f"O3F6 manifest {identity}"), f"O3F6 manifest hash changed: {identity}")
    need(isinstance(prior.get("results"), list) and len(prior["results"]) == 1, f"Prior manifest is not one pair: {identity}")
    prior_result = prior["results"][0]
    need(str(prior_result["pairId"]) == safe_id, f"Prior result pair identity changed: {identity}")
    prior_job_path = Path(str(prior.get("jobPath") or ""))
    need(prior_job_path.is_absolute() and prior_job_path.is_file(), f"Prior job is missing: {identity}")
    prior_job, actual_job_sha256 = read_json_and_sha256(prior_job_path)
    need(actual_job_sha256 == required_sha256(prior.get("jobSha256"), f"Prior job {identity}"), f"Prior job hash changed: {identity}")
    need(fixed_job_projection(prior_job) == canonical_fixed, f"Prior job fixed detector configuration changed: {identity}")
    prior_inputs = input_binding(prior_job)
    assert_source_binding(prior_inputs["BF"], row["bf"], safe_id, "BF")
    assert_source_binding(prior_inputs["DF"], row["df"], safe_id, "DF")
    return prior, prior_result, {
        "manifestPath": str(manifest_path.resolve(strict=True)),
        "manifestSha256": actual_manifest_sha256,
        "jobPath": str(prior_job_path.resolve(strict=True)),
        "jobSha256": actual_job_sha256,
    }


def build_manifest_freeze(rows: list[dict[str, Any]], canonical_fixed: dict[str, Any]) -> dict[str, Any]:
    entries: list[dict[str, Any]] = []
    for row in rows:
        identity = str(row["identity"])
        safe_id = str(row["safeId"])
        state = str(row["r8State"])
        if state == "HOLD_FRONT_NOTCH_PROVIDER_ERROR":
            entries.append(
                {
                    "identity": identity,
                    "safeId": safe_id,
                    "r8State": state,
                    "classification": "PRESERVED_PROVIDER_ERROR",
                    "diagnosticRoot": row.get("r7DiagnosticRoot"),
                }
            )
            continue
        diagnostic = row.get("r7DiagnosticRoot")
        need(diagnostic, f"Non-provider-error row lacks diagnostic root: {identity}")
        manifest_path = Path(str(diagnostic)) / "MANIFEST.json"
        _, _, evidence = load_prior_evidence(row, manifest_path, None, canonical_fixed)
        entries.append(
            {
                "identity": identity,
                "safeId": safe_id,
                "r8State": state,
                "classification": "PINNED_EXECUTABLE",
                **evidence,
                "sources": {
                    "BF": source_binding_projection(row["bf"], safe_id, "BF"),
                    "DF": source_binding_projection(row["df"], safe_id, "DF"),
                },
            }
        )
    need(len(entries) == 978, "Manifest-freeze cardinality changed")
    need(len({entry["identity"] for entry in entries}) == 978, "Manifest-freeze identity duplication")
    need(len({entry["safeId"] for entry in entries}) == 978, "Manifest-freeze safe-ID duplication")
    provider_count = sum(entry["classification"] == "PRESERVED_PROVIDER_ERROR" for entry in entries)
    need(provider_count == EXPECTED_PROVIDER_ERROR_COUNT, "Frozen provider-error count changed")
    return {
        "schema": "argos_ocv03_o3f8_manifest_freeze_v1",
        "state": "FROZEN_O3F8_PRIOR_MANIFESTS",
        "stage": "MANIFEST_FREEZE",
        "runnerSha256": sha256(Path(__file__).resolve()),
        "r9Sha256": R9_SHA256,
        "r8Sha256": R8_SHA256,
        "o3p8Sha256": O3P8_SHA256,
        "o3p8JobSha256": O3P8_JOB_SHA256,
        "localGateSourceSha256": LOCAL_GATE_SHA256,
        "canonicalJobSha256": CANONICAL_JOB_SHA256,
        "r6Sha256": R6_SHA256,
        "topologySha256": TOPOLOGY_SHA256,
        "runtimeSha256": RUNTIME_SHA256,
        "sourceResultsSha256": RESULTS_SHA256,
        "reviewOrderSha256": REVIEW_SHA256,
        "entryCount": len(entries),
        "pinnedExecutableCount": len(entries) - provider_count,
        "preservedProviderErrorCount": provider_count,
        "metadataOnly": True,
        "imageBytesRead": False,
        "imageDecode": False,
        "providerInvoked": False,
        "sourceMutation": False,
        "entries": entries,
    }


def validate_manifest_freeze(reference: dict[str, Any], rows: list[dict[str, Any]]) -> tuple[dict[str, dict[str, Any]], dict[str, Any]]:
    path = Path(str(reference.get("path") or ""))
    expected_hash = required_sha256(reference.get("sha256"), "Manifest-freeze registry")
    need(path.is_absolute() and path.is_file(), "Manifest-freeze registry is missing")
    freeze, actual_hash = read_json_and_sha256(path)
    need(actual_hash == expected_hash, "Manifest-freeze registry hash changed")
    need(
        freeze.get("schema") == "argos_ocv03_o3f8_manifest_freeze_v1"
        and freeze.get("state") == "FROZEN_O3F8_PRIOR_MANIFESTS"
        and freeze.get("stage") == "MANIFEST_FREEZE"
        and freeze.get("runnerSha256") == sha256(Path(__file__).resolve())
        and freeze.get("r9Sha256") == R9_SHA256
        and freeze.get("r8Sha256") == R8_SHA256
        and freeze.get("o3p8Sha256") == O3P8_SHA256
        and freeze.get("o3p8JobSha256") == O3P8_JOB_SHA256
        and freeze.get("localGateSourceSha256") == LOCAL_GATE_SHA256
        and freeze.get("canonicalJobSha256") == CANONICAL_JOB_SHA256
        and freeze.get("r6Sha256") == R6_SHA256
        and freeze.get("topologySha256") == TOPOLOGY_SHA256
        and freeze.get("runtimeSha256") == RUNTIME_SHA256
        and freeze.get("sourceResultsSha256") == RESULTS_SHA256
        and freeze.get("reviewOrderSha256") == REVIEW_SHA256
        and freeze.get("metadataOnly") is True
        and freeze.get("imageBytesRead") is False
        and freeze.get("imageDecode") is False
        and freeze.get("providerInvoked") is False
        and freeze.get("sourceMutation") is False,
        "Manifest-freeze provenance changed",
    )
    entries = freeze.get("entries")
    need(isinstance(entries, list) and len(entries) == len(rows) == 978, "Manifest-freeze entry count changed")
    by_identity = {str(entry.get("identity")): entry for entry in entries}
    need(len(by_identity) == 978 and set(by_identity) == {str(row["identity"]) for row in rows}, "Manifest-freeze identity coverage changed")
    need(len({str(entry.get("safeId")) for entry in entries}) == 978, "Manifest-freeze safe-ID coverage changed")
    provider_count = 0
    for row in rows:
        identity = str(row["identity"])
        safe_id = str(row["safeId"])
        state = str(row["r8State"])
        entry = by_identity[identity]
        need(str(entry.get("safeId")) == safe_id and str(entry.get("r8State")) == state, f"Manifest-freeze row binding changed: {identity}")
        if state == "HOLD_FRONT_NOTCH_PROVIDER_ERROR":
            provider_count += 1
            need(entry.get("classification") == "PRESERVED_PROVIDER_ERROR", f"Provider-error classification changed: {identity}")
            need(entry.get("diagnosticRoot") == row.get("r7DiagnosticRoot"), f"Provider-error diagnostic root changed: {identity}")
            continue
        need(entry.get("classification") == "PINNED_EXECUTABLE", f"Executable classification changed: {identity}")
        expected_manifest_path = Path(str(row.get("r7DiagnosticRoot") or "")) / "MANIFEST.json"
        need(normalized(Path(str(entry.get("manifestPath") or ""))) == normalized(expected_manifest_path), f"Frozen manifest path changed: {identity}")
        required_sha256(entry.get("manifestSha256"), f"Frozen manifest {identity}")
        required_sha256(entry.get("jobSha256"), f"Frozen job {identity}")
        sources = entry.get("sources")
        need(isinstance(sources, dict), f"Frozen sources missing: {identity}")
        for channel, key in (("BF", "bf"), ("DF", "df")):
            need(sources.get(channel) == source_binding_projection(row[key], safe_id, channel), f"Frozen {channel} source binding changed: {identity}")
    need(provider_count == EXPECTED_PROVIDER_ERROR_COUNT, "Manifest-freeze provider-error count changed")
    return by_identity, {"path": str(path.resolve(strict=True)), "sha256": actual_hash, "entryCount": len(entries)}


def prevalidate_stage_evidence(
    stage: str,
    selected: list[dict[str, Any]],
    cases: list[dict[str, Any]],
    freeze_by_identity: dict[str, dict[str, Any]],
    canonical_fixed: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    case_by_identity = {str(case["identity"]): case for case in cases}
    validated: dict[str, dict[str, Any]] = {}
    for row in selected:
        identity = str(row["identity"])
        if stage in ("DEV6", "HOLDOUT18"):
            need(identity in case_by_identity, f"Selected identity lacks its frozen O3F7 case: {identity}")
            manifest_reference = review_manifest_reference(row, case_by_identity[identity])
            freeze_entry = None
        else:
            need(identity in freeze_by_identity, f"Selected identity lacks its frozen manifest entry: {identity}")
            freeze_entry = freeze_by_identity[identity]
            manifest_reference = (
                None
                if freeze_entry["classification"] == "PRESERVED_PROVIDER_ERROR"
                else {"path": str(freeze_entry["manifestPath"]), "sha256": str(freeze_entry["manifestSha256"])}
            )
        if manifest_reference is None:
            need(str(row["r8State"]) == "HOLD_FRONT_NOTCH_PROVIDER_ERROR", f"Only a frozen provider error may be preserved: {identity}")
            validated[identity] = {"classification": "PRESERVED_PROVIDER_ERROR"}
            continue
        _, prior_result, prior_evidence = load_prior_evidence(
            row, Path(manifest_reference["path"]), manifest_reference["sha256"], canonical_fixed
        )
        if freeze_entry is not None:
            need(prior_evidence["jobPath"] == str(freeze_entry["jobPath"]), f"Frozen job path changed: {identity}")
            need(prior_evidence["jobSha256"] == str(freeze_entry["jobSha256"]), f"Frozen job hash changed: {identity}")
        validated[identity] = {
            "classification": "PINNED_EXECUTABLE",
            "priorResult": prior_result,
            "priorEvidence": prior_evidence,
        }
    need(len(validated) == len(selected), "Selected predecessor evidence coverage changed")
    if stage == "DEV6":
        need(len(validated) == 6 and all(item["classification"] == "PINNED_EXECUTABLE" for item in validated.values()), "DEV6 is not exactly six prevalidated executions")
    return validated


def preflight() -> None:
    pins = (
        (R9, R9_SHA256, "R9"),
        (R8, R8_SHA256, "R8"),
        (O3P8, O3P8_SHA256, "O3P8"),
        (LOCAL_GATE, LOCAL_GATE_SHA256, "local gate"),
        (O3P8_JOB, O3P8_JOB_SHA256, "O3P8 frozen job"),
        (CANONICAL_JOB, CANONICAL_JOB_SHA256, "canonical job"),
        (INSTALLED / "NativeFrontsideWaferPoseOpenCvV2R6.py", R6_SHA256, "R6"),
        (INSTALLED / "WaferTopologyAxisOpenCv.py", TOPOLOGY_SHA256, "topology"),
        (RUNTIME, RUNTIME_SHA256, "runtime"),
    )
    for path, expected, label in pins:
        need(path.is_file() and sha256(path) == expected, f"{label} pin changed: {path}")
    runtime_check = subprocess.run(
        [str(RUNTIME), "-I", "-c", "import json,sys,cv2,numpy as np;print(json.dumps({'executable':sys.executable,'cv2Path':cv2.__file__,'numpyPath':np.__file__,'opencvVersion':cv2.__version__,'numpyVersion':np.__version__},separators=(',',':')))"],
        capture_output=True,
        text=True,
        timeout=60,
        env=isolated_env(),
    )
    need(runtime_check.returncode == 0 and not runtime_check.stderr, "Pinned runtime import check failed")
    runtime = json.loads(runtime_check.stdout)
    runtime_root = RUNTIME.parent.resolve(strict=True)
    need(Path(runtime["executable"]).resolve(strict=True) == RUNTIME.resolve(strict=True), "Runtime executable path changed")
    for key in ("cv2Path", "numpyPath"):
        try:
            Path(runtime[key]).resolve(strict=True).relative_to(runtime_root)
        except ValueError as exc:
            raise RuntimeError(f"Runtime module escaped pinned root: {runtime[key]}") from exc
    need(runtime["opencvVersion"] == EXPECTED_OPENCV_VERSION and runtime["numpyVersion"] == EXPECTED_NUMPY_VERSION, "Runtime module version changed")
    frozen_inputs()


def run_gate(output_root: Path) -> dict[str, Any]:
    preflight()
    output_root = validate_output_root(output_root)
    path_plan = validate_new_paths(
        [
            output_root / "SUMMARY.json.partial",
            output_root / "DF_SEEDED_LOCAL_GATE.json",
            output_root / "LOCAL.stdout.txt",
            output_root / "LOCAL.stderr.txt",
            output_root / "INHERITED.stdout.txt",
            output_root / "INHERITED.stderr.txt",
            output_root / "R8_INHERITED_SYNTHETIC" / "upper_right_315_df_c01_enhanced.png",
            output_root / "R8_INHERITED_SYNTHETIC" / "SYNTHETIC_GATE.json.partial",
        ]
    )
    output_root.mkdir()
    env = isolated_env()
    env.update(
        {
            "ARGOS_O3M1_R6_ROOT": str(INSTALLED),
            "ARGOS_O3M1_TOPOLOGY_ROOT": str(INSTALLED),
            "ARGOS_O3P8_ROOT": str(HERE),
            "ARGOS_O3F8_DEPENDENCY_ROOT": str(INSTALLED),
            "TEMP": str(output_root),
            "TMP": str(output_root),
        }
    )
    local_output = output_root / "DF_SEEDED_LOCAL_GATE.json"
    synthetic_root = output_root / "R8_INHERITED_SYNTHETIC"
    commands = (
        ("LOCAL", [str(RUNTIME), "-I", "-B", str(LOCAL_GATE), "--output", str(local_output)], 180),
        ("INHERITED", [str(RUNTIME), "-I", "-B", str(R9), "--synthetic-gate", "--output-root", str(synthetic_root)], 300),
    )
    command_results = []
    for label, command, timeout in commands:
        try:
            child = subprocess.run(command, capture_output=True, text=True, timeout=timeout, env=env)
            return_code, stdout, stderr = child.returncode, child.stdout, child.stderr
        except Exception as exc:
            return_code, stdout, stderr = -1, "", str(exc)
        (output_root / f"{label}.stdout.txt").write_text(stdout, encoding="utf-8", newline="\n")
        (output_root / f"{label}.stderr.txt").write_text(stderr, encoding="utf-8", newline="\n")
        command_results.append({"label": label, "returnCode": return_code, "stderrBytes": len(stderr.encode("utf-8"))})
    local, local_sha256 = read_json_and_sha256(local_output) if local_output.is_file() else ({}, None)
    inherited_path = synthetic_root / "SYNTHETIC_GATE.json"
    inherited, inherited_sha256 = read_json_and_sha256(inherited_path) if inherited_path.is_file() else ({}, None)
    passed = (
        all(item["returnCode"] == 0 and item["stderrBytes"] == 0 for item in command_results)
        and local.get("state") == "PASS_O3F8_DF_SEEDED_FALLBACK_LOCAL_GATE"
        and inherited.get("state") == "PASS_O3M6_SPLIT_METHOD_FULL_PERIMETER_SYNTHETIC_GATE"
    )
    summary = {
        "schema": "argos_ocv03_o3f8_gate_result_v1",
        "state": "COMPLETE_O3F8_GATE" if passed else "HOLD_O3F8_GATE",
        "stage": "GATE",
        "runnerSha256": sha256(Path(__file__).resolve()),
        "r9Sha256": R9_SHA256,
        "r8Sha256": R8_SHA256,
        "o3p8Sha256": O3P8_SHA256,
        "o3p8JobSha256": O3P8_JOB_SHA256,
        "localGateSourceSha256": LOCAL_GATE_SHA256,
        "canonicalJobSha256": CANONICAL_JOB_SHA256,
        "r6Sha256": R6_SHA256,
        "topologySha256": TOPOLOGY_SHA256,
        "runtimeSha256": RUNTIME_SHA256,
        "sourceResultsSha256": RESULTS_SHA256,
        "reviewOrderSha256": REVIEW_SHA256,
        "pathPlan": path_plan,
        "newProviderHoldCount": 0 if passed else 1,
        "commands": command_results,
        "localGateResultSha256": local_sha256,
        "inheritedGateResultSha256": inherited_sha256,
        "sourceMutation": False,
        "providerActivated": False,
    }
    summary_path = output_root / "SUMMARY.json"
    write_new(summary_path, summary)
    return {"state": summary["state"], "stage": "GATE", "summarySha256": sha256(summary_path), "commands": command_results}


def project_recovery(result: dict[str, Any] | None) -> dict[str, Any] | None:
    if result is None:
        return None
    return {
        "state": result["state"],
        "seedCount": result["seedCount"],
        "eligibleSeedIndices": result["eligibleSeedIndices"],
        "selected": result.get("selected"),
    }


def validate_stage_prerequisite(stage: str, path: Path | None, expected_sha256: str | None) -> dict[str, Any] | None:
    expected = {
        "DEV6": "GATE",
        "HOLDOUT18": "DEV6",
        "MANIFEST_FREEZE": "HOLDOUT18",
        "CURRENT265": "MANIFEST_FREEZE",
        "FULL978": "CURRENT265",
    }.get(stage)
    if expected is None:
        need(path is None and expected_sha256 is None, f"{stage} does not accept a stage prerequisite")
        return None
    need(path is not None and path.is_file() and expected_sha256 is not None and len(expected_sha256) == 64, f"{stage} requires the exact {expected} summary and SHA-256")
    prior, actual_sha256 = read_json_and_sha256(path)
    need(actual_sha256 == expected_sha256.upper(), f"{expected} prerequisite summary hash changed")
    expected_schema = (
        "argos_ocv03_o3f8_gate_result_v1"
        if expected == "GATE"
        else "argos_ocv03_o3f8_manifest_freeze_result_v1"
        if expected == "MANIFEST_FREEZE"
        else "argos_ocv03_o3f8_staged_result_v1"
    )
    need(
        prior.get("schema") == expected_schema
        and prior.get("state") == f"COMPLETE_O3F8_{expected}"
        and prior.get("stage") == expected
        and prior.get("runnerSha256") == sha256(Path(__file__).resolve())
        and prior.get("r9Sha256") == R9_SHA256
        and prior.get("r8Sha256") == R8_SHA256
        and prior.get("o3p8Sha256") == O3P8_SHA256
        and prior.get("o3p8JobSha256") == O3P8_JOB_SHA256
        and prior.get("localGateSourceSha256") == LOCAL_GATE_SHA256
        and prior.get("canonicalJobSha256") == CANONICAL_JOB_SHA256
        and prior.get("r6Sha256") == R6_SHA256
        and prior.get("topologySha256") == TOPOLOGY_SHA256
        and prior.get("runtimeSha256") == RUNTIME_SHA256
        and prior.get("sourceResultsSha256") == RESULTS_SHA256
        and prior.get("reviewOrderSha256") == REVIEW_SHA256
        and int(prior.get("newProviderHoldCount", -1)) == 0,
        f"{expected} prerequisite is not a clean matching completion",
    )
    if expected == "GATE":
        local_path = path.parent / "DF_SEEDED_LOCAL_GATE.json"
        inherited_path = path.parent / "R8_INHERITED_SYNTHETIC" / "SYNTHETIC_GATE.json"
        local_result, local_sha256 = read_json_and_sha256(local_path) if local_path.is_file() else ({}, None)
        inherited_result, inherited_sha256 = read_json_and_sha256(inherited_path) if inherited_path.is_file() else ({}, None)
        need(
            local_path.is_file()
            and inherited_path.is_file()
            and local_sha256 == prior.get("localGateResultSha256")
            and inherited_sha256 == prior.get("inheritedGateResultSha256")
            and local_result.get("state") == "PASS_O3F8_DF_SEEDED_FALLBACK_LOCAL_GATE"
            and inherited_result.get("state") == "PASS_O3M6_SPLIT_METHOD_FULL_PERIMETER_SYNTHETIC_GATE"
            and prior.get("commands") == [
                {"label": "LOCAL", "returnCode": 0, "stderrBytes": 0},
                {"label": "INHERITED", "returnCode": 0, "stderrBytes": 0},
            ],
            "GATE result artifacts changed",
        )
    else:
        need(
            int(prior.get("selectedCount", -1)) == {"DEV6": 6, "HOLDOUT18": 18, "MANIFEST_FREEZE": 978, "CURRENT265": 265}[expected],
            f"{expected} prerequisite cardinality changed",
        )
    validated = {"path": str(path.resolve(strict=True)), "sha256": actual_sha256, "stage": expected}
    if expected in ("MANIFEST_FREEZE", "CURRENT265"):
        reference = prior.get("manifestFreeze")
        need(isinstance(reference, dict), f"{expected} prerequisite lost its manifest-freeze binding")
        validated["manifestFreeze"] = reference
    return validated


def run_manifest_freeze(output_root: Path, prerequisite_summary: Path | None, prerequisite_sha256: str | None) -> dict[str, Any]:
    preflight()
    prerequisite = validate_stage_prerequisite("MANIFEST_FREEZE", prerequisite_summary, prerequisite_sha256)
    output_root = validate_output_root(output_root)
    path_plan = validate_new_paths([output_root / "MANIFEST_FREEZE.json.partial", output_root / "SUMMARY.json.partial"])
    rows, _ = frozen_inputs()
    canonical, canonical_sha256 = read_json_and_sha256(CANONICAL_JOB)
    need(canonical_sha256 == CANONICAL_JOB_SHA256, "Canonical job changed before manifest freeze")
    canonical_fixed = fixed_job_projection(canonical)
    freeze = build_manifest_freeze(rows, canonical_fixed)
    output_root.mkdir()
    freeze_path = output_root / "MANIFEST_FREEZE.json"
    write_new(freeze_path, freeze)
    freeze_reference = {"path": str(freeze_path.resolve(strict=True)), "sha256": sha256(freeze_path), "entryCount": 978}
    summary = {
        "schema": "argos_ocv03_o3f8_manifest_freeze_result_v1",
        "state": "COMPLETE_O3F8_MANIFEST_FREEZE",
        "stage": "MANIFEST_FREEZE",
        "runnerSha256": sha256(Path(__file__).resolve()),
        "selectedCount": 978,
        "executedCount": 0,
        "preservedProviderHoldCount": EXPECTED_PROVIDER_ERROR_COUNT,
        "newProviderHoldCount": 0,
        "r9Sha256": R9_SHA256,
        "r8Sha256": R8_SHA256,
        "o3p8Sha256": O3P8_SHA256,
        "o3p8JobSha256": O3P8_JOB_SHA256,
        "localGateSourceSha256": LOCAL_GATE_SHA256,
        "canonicalJobSha256": CANONICAL_JOB_SHA256,
        "r6Sha256": R6_SHA256,
        "topologySha256": TOPOLOGY_SHA256,
        "runtimeSha256": RUNTIME_SHA256,
        "sourceResultsSha256": RESULTS_SHA256,
        "reviewOrderSha256": REVIEW_SHA256,
        "prerequisite": prerequisite,
        "manifestFreeze": freeze_reference,
        "pathPlan": path_plan,
        "metadataOnly": True,
        "imageBytesRead": False,
        "imageDecode": False,
        "providerInvoked": False,
        "sourceMutation": False,
        "providerActivated": False,
    }
    summary_path = output_root / "SUMMARY.json"
    write_new(summary_path, summary)
    return {"state": summary["state"], "stage": "MANIFEST_FREEZE", "selectedCount": 978, "summarySha256": sha256(summary_path), "manifestFreeze": freeze_reference}


def run_stage(stage: str, output_root: Path, prerequisite_summary: Path | None, prerequisite_sha256: str | None) -> dict[str, Any]:
    preflight()
    prerequisite = validate_stage_prerequisite(stage, prerequisite_summary, prerequisite_sha256)
    output_root = validate_output_root(output_root)
    rows, cases = frozen_inputs()
    selected = select(stage, rows, cases)
    freeze_by_identity: dict[str, dict[str, Any]] = {}
    freeze_reference: dict[str, Any] | None = None
    if stage in ("CURRENT265", "FULL978"):
        need(isinstance(prerequisite, dict) and isinstance(prerequisite.get("manifestFreeze"), dict), f"{stage} lacks its manifest-freeze prerequisite")
        freeze_by_identity, freeze_reference = validate_manifest_freeze(prerequisite["manifestFreeze"], rows)
    path_plan = validate_stage_path_plan(output_root, selected)
    canonical, canonical_sha256 = read_json_and_sha256(CANONICAL_JOB)
    need(canonical_sha256 == CANONICAL_JOB_SHA256, "Canonical job changed before staged execution")
    canonical_fixed = fixed_job_projection(canonical)
    prior_by_identity = prevalidate_stage_evidence(stage, selected, cases, freeze_by_identity, canonical_fixed)
    output_root.mkdir()
    jobs = output_root / "jobs"
    outputs = output_root / "cases"
    jobs.mkdir()
    outputs.mkdir()
    env = isolated_env()
    env["ARGOS_O3M1_R6_ROOT"] = str(INSTALLED)
    env["ARGOS_O3M1_TOPOLOGY_ROOT"] = str(INSTALLED)
    env["ARGOS_O3P8_ROOT"] = str(HERE)
    results: list[dict[str, Any]] = []
    for ordinal, row in enumerate(selected, 1):
        identity = str(row["identity"])
        safe_id = str(row["safeId"])
        prior_evidence = prior_by_identity[identity]
        if prior_evidence["classification"] == "PRESERVED_PROVIDER_ERROR":
            results.append({"identity": identity, "safeId": safe_id, "priorR8State": row["r8State"], "state": row["r8State"], "execution": "PRESERVED_NO_DIAGNOSTIC_PROVIDER_HOLD"})
            continue
        prior_result = prior_evidence["priorResult"]
        try:
            job = dict(canonical_fixed)
            job["revision"] = f"O3F8_R9_{stage}_{ordinal:04d}"
            job["inputs"] = [
                {"identity": f"{safe_id}-{channel}", "pairId": safe_id, "channel": channel, "path": str(row[key]["path"]), "bytes": int(row[key]["bytes"]), "sha256": str(row[key]["sha256"]).upper()}
                for channel, key in (("BF", "bf"), ("DF", "df"))
            ]
            job_path = jobs / f"J{ordinal:04d}.json"
            write_new(job_path, job)
            case_root = outputs / f"C{ordinal:04d}"
            child = subprocess.run(
                [str(RUNTIME), "-I", "-B", str(R9), "--run", "--job", str(job_path), "--output-root", str(case_root)],
                capture_output=True,
                text=True,
                timeout=600,
                env=env,
            )
            (output_root / f"C{ordinal:04d}.stdout.txt").write_text(child.stdout, encoding="utf-8", newline="\n")
            (output_root / f"C{ordinal:04d}.stderr.txt").write_text(child.stderr, encoding="utf-8", newline="\n")
            need(child.returncode == 0, f"R9 child exit {child.returncode}: {child.stderr[-1200:]}")
            manifest_path = case_root / "MANIFEST.json"
            manifest, manifest_sha256 = read_json_and_sha256(manifest_path)
            need(len(manifest["results"]) == 1, "R9 manifest is not one pair")
            observed = manifest["results"][0]
            need(str(observed["pairId"]) == safe_id, "R9 result pair identity changed")
            need(str(observed["baselineR8State"]) == str(row["r8State"]), "R9 baseline state differs from frozen R8 state")
            need(r8_decision_projection(observed) == r8_decision_projection(prior_result), "R9 changed inherited R8 decision evidence")
            need(str(manifest["revision"]) == job["revision"] and int(manifest["inputCount"]) == 2, "R9 manifest revision/input binding changed")
            need(
                manifest.get("engineProvenance")
                == {
                    "r9Sha256": R9_SHA256,
                    "r8PredecessorSha256": R8_SHA256,
                    "r6Sha256": R6_SHA256,
                    "topologySha256": TOPOLOGY_SHA256,
                    "o3p8Sha256": O3P8_SHA256,
                    "runtimeSha256": RUNTIME_SHA256,
                    "opencvVersion": EXPECTED_OPENCV_VERSION,
                    "numpyVersion": EXPECTED_NUMPY_VERSION,
                },
                "R9 engine provenance changed",
            )
            need(sha256(job_path) == str(manifest["jobSha256"]).upper(), "R9 manifest job hash changed")
            need(Path(str(manifest["jobPath"])).resolve(strict=False) == job_path.resolve(strict=False), "R9 manifest job path changed")
            results.append(
                {
                    "identity": identity,
                    "safeId": safe_id,
                    "priorR8State": row["r8State"],
                    "state": observed["state"],
                    "baselineR8State": observed["baselineR8State"],
                    "o3p8FallbackInvoked": observed["o3p8FallbackInvoked"],
                    "recovery": project_recovery(observed["o3p8DfSeededLocalBfRecovery"]),
                    "manifestPath": str(manifest_path),
                    "manifestSha256": manifest_sha256,
                    "execution": "PASS_R9_CHILD",
                }
            )
        except Exception as exc:
            results.append({"identity": identity, "safeId": safe_id, "priorR8State": row["r8State"], "state": "HOLD_O3F8_R9_PROVIDER_ERROR", "execution": "HOLD_R9_CHILD", "error": str(exc)[:1600]})
    counts = Counter(str(row["state"]) for row in results)
    executed_count = sum(row["execution"] == "PASS_R9_CHILD" for row in results)
    preserved_count = sum(row["execution"] == "PRESERVED_NO_DIAGNOSTIC_PROVIDER_HOLD" for row in results)
    new_hold_count = sum(row["execution"] == "HOLD_R9_CHILD" for row in results)
    clean_completion = (
        len(results) == len(selected)
        and executed_count + preserved_count + new_hold_count == len(selected)
        and new_hold_count == 0
        and (stage != "DEV6" or executed_count == 6)
    )
    summary = {
        "schema": "argos_ocv03_o3f8_staged_result_v1",
        "state": f"COMPLETE_O3F8_{stage}" if clean_completion else f"HOLD_O3F8_{stage}_EXECUTION",
        "stage": stage,
        "runnerSha256": sha256(Path(__file__).resolve()),
        "selectedCount": len(selected),
        "executedCount": executed_count,
        "preservedProviderHoldCount": preserved_count,
        "newProviderHoldCount": new_hold_count,
        "stateCounts": dict(counts),
        "r9Sha256": R9_SHA256,
        "r8Sha256": R8_SHA256,
        "o3p8Sha256": O3P8_SHA256,
        "o3p8JobSha256": O3P8_JOB_SHA256,
        "localGateSourceSha256": LOCAL_GATE_SHA256,
        "canonicalJobSha256": CANONICAL_JOB_SHA256,
        "r6Sha256": R6_SHA256,
        "topologySha256": TOPOLOGY_SHA256,
        "runtimeSha256": RUNTIME_SHA256,
        "sourceResultsSha256": RESULTS_SHA256,
        "reviewOrderSha256": REVIEW_SHA256,
        "prerequisite": prerequisite,
        "manifestFreeze": freeze_reference,
        "pathPlan": path_plan,
        "operatorFeedbackConsumedForInference": False,
        "thresholdChangedAfterResult": False,
        "results": results,
        "sourceMutation": False,
        "providerActivated": False,
        "sourceHoldRowsMutated": False,
        "successorResultsWrittenSeparately": True,
    }
    summary_path = output_root / "SUMMARY.json"
    write_new(summary_path, summary)
    return {**{key: summary[key] for key in ("state", "stage", "selectedCount", "executedCount", "preservedProviderHoldCount", "newProviderHoldCount", "stateCounts")}, "summarySha256": sha256(summary_path)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("SELF_TEST", "PREFLIGHT", "GATE", "DEV6", "HOLDOUT18", "MANIFEST_FREEZE", "CURRENT265", "FULL978"))
    parser.add_argument("--output-root")
    parser.add_argument("--prerequisite-summary")
    parser.add_argument("--prerequisite-sha256")
    args = parser.parse_args()
    if args.stage == "SELF_TEST":
        self_test()
        return 0
    if args.stage == "PREFLIGHT":
        preflight()
        print('{"state":"PASS_O3F8_STAGED_PREFLIGHT","mutationsPerformed":false}')
        return 0
    need(args.output_root, "--output-root is required")
    if args.stage == "GATE":
        need(not args.prerequisite_summary and not args.prerequisite_sha256, "GATE does not accept a stage prerequisite")
        result = run_gate(Path(args.output_root))
        print(json.dumps(result, separators=(",", ":")))
        return 0 if result["state"] == "COMPLETE_O3F8_GATE" else 2
    if args.stage == "MANIFEST_FREEZE":
        result = run_manifest_freeze(
            Path(args.output_root),
            None if not args.prerequisite_summary else Path(args.prerequisite_summary),
            args.prerequisite_sha256,
        )
        print(json.dumps(result, separators=(",", ":")))
        return 0 if result["state"] == "COMPLETE_O3F8_MANIFEST_FREEZE" else 2
    result = run_stage(
        args.stage,
        Path(args.output_root),
        None if not args.prerequisite_summary else Path(args.prerequisite_summary),
        args.prerequisite_sha256,
    )
    print(json.dumps(result, separators=(",", ":")))
    return 0 if str(result["state"]).startswith("COMPLETE_") else 2


if __name__ == "__main__":
    raise SystemExit(main())
