#!/usr/bin/env python3
"""Run one authenticated held-out Z crop through the public R18ZU job path."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


PROJECT = Path(r"C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab-scribe-opencv")
EXPECTED_OUTPUT_ROOT = Path(r"C:\R18ZUH1")
PHYSICAL_IDENTITY = "62623-743_20260720111120_Slot04"
REVISION = "R18ZU_HELD_OUT_Z_FULL_CHAIN_DIAGNOSTIC_20260908"
PROVIDER_REVISION = "ARGOS_OPENCV_SCRIBE_V1R18ZU_CANONICAL_Z_GEOMETRY_DIAGNOSTIC_20260908"
EXPECTED = {
    "provider": "935BAAE98331FF128D4204B6C8AB2E7EBEF8A38B2773F4ACCE59AE3A78C7FF87",
    "developmentGate": "31C5AD7F7E2A20ACB7CD6542808375D537323247EF4A56DF81C6F92B92209470",
    "baseManifest": "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229",
    "supplementalManifest": "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD",
    "crosswalk": "84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2",
    "looGate": "D8F0C0923BFDD6B82C4B0B0C57142825C08C0DB3F5395210A5DD7FE2E6E8DAD8",
    "terminalGate": "326029AFC10633010FA058F63B59D9E37C102B3B2EDEC9C648201C40D67AAB64",
    "adapter": "43367D6F468AA7022308D03DE08DFB98DDD8DDCDADFD2C8D94CEE508B54C6094",
    "bf": "DE2C242EB6AD0D188E071215D2065E44EDAE4DFE9B2FDD1FB21A03CB7BB77170",
    "df": "AB39CAE7C402F6294076F6809BC8A369074867EAC282303983E81BD39427197D",
}
EXPECTED_BYTES = {"bf": 2227346, "df": 1922542}
EXPECTED_REQUEST_ID = "REQ_20260903T171128612Z_R18A"
EXPECTED_RESPONSE_ID = "R_84B9CB78722E_20260903172040421_2b8e31ed"
EXPECTED_SIGNER = "DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC"
EXPECTED_HYPOTHESES = {
    (channel, polarity, direction)
    for channel in ("BF", "DF")
    for polarity in ("DARK", "BRIGHT")
    for direction in ("FORWARD", "REVERSE_180")
}
_ACTIVE_EXECUTION_GATE: Path | None = None
_ACTIVE_PROVIDER_RUN_COUNT = 0
_ACTIVE_RUNNER_SHA256 = ""
_ACTIVE_JOB_PATH: Path | None = None
_ACTIVE_JOB_SHA256 = ""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def require_pin(path: Path, expected: str) -> None:
    if not path.is_file() or sha256_file(path) != expected.upper():
        raise ValueError(f"Pinned file mismatch: {path}")


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def expected_paths(args: argparse.Namespace) -> dict[str, Path]:
    project = args.project.resolve()
    return {
        "project": project,
        "runner": Path(__file__).resolve(),
        "provider": project / "work/OPENCV_SCRIBE_R18ZU/ArgosOpenCvScribeV1R18ZU.py",
        "developmentGate": project / "work/OPENCV_SCRIBE_R18ZU/R18ZU_CANONICAL_Z_DEVELOPMENT_GATE_V2.json",
        "baseManifest": project / (
            "work/SCRIBE_REVIEW_ONLY/scratch/"
            "SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/"
            "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
        ),
        "supplementalManifest": project / (
            "work/OPENCV_SCRIBE_R18Z/reference_bank/"
            "SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
        ),
        "crosswalk": project / (
            "work/OPENCV_SCRIBE_R18Z/reference_bank/"
            "R18Z_EXACT_SCRIBE_LINEAGE_CROSSWALK.json"
        ),
        "looGate": project / (
            "work/OPENCV_SCRIBE_R18Z/evidence/"
            "R18Z_EXACT_LINEAGE_LOO_GATE.json"
        ),
        "terminalGate": project / (
            "work/OPENCV_SCRIBE_R18A/R18A_TERMINAL_RESPONSE_GATE_R2.json"
        ),
        "adapter": project / (
            "work/OPENCV_SCRIBE_R18ZU/"
            "R18ZU_Z04_SIGNED_PULL_QUALIFICATION_ADAPTER.json"
        ),
        "bf": args.bf.resolve(),
        "df": args.df.resolve(),
        "output": args.output_root.resolve(),
    }


def validate_adapter(paths: dict[str, Path]) -> None:
    adapter = read_json(paths["adapter"])
    if (
        adapter.get("schema")
        != "argos_opencv_scribe_authenticated_data_pull_qualification_adapter_v1"
        or adapter.get("state")
        != "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT"
        or adapter.get("physicalIdentity") != PHYSICAL_IDENTITY
        or adapter.get("truthIncluded") is not False
        or adapter.get("request", {}).get("requestId") != EXPECTED_REQUEST_ID
        or adapter.get("request", {}).get("retried") is not False
        or adapter.get("response", {}).get("responseId") != EXPECTED_RESPONSE_ID
        or adapter.get("response", {}).get("state") != "PASS_DATA_PULL"
        or adapter.get("response", {}).get("signedResponseVerified") is not True
        or adapter.get("response", {}).get("signerThumbprint") != EXPECTED_SIGNER
        or adapter.get("terminalResponseGate", {}).get("sha256")
        != EXPECTED["terminalGate"]
        or adapter.get("qualificationTranslation", {}).get("from")
        != "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT"
        or adapter.get("qualificationTranslation", {}).get("toInternalExecutionMode")
        != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT"
        or adapter.get("qualificationTranslation", {}).get(
            "changesDetectorPixelsOrHypothesisSelection"
        ) is not False
        or adapter.get("legacyProducerEvidence", {}).get(
            "proposalOrSummaryPathsSynthesized"
        ) is not False
        or adapter.get("legacyProducerEvidence", {}).get(
            "proposalOrSummaryHashesSynthesized"
        ) is not False
        or adapter.get("legacyProducerEvidence", {}).get(
            "extractedFilesRepresentedAsInstalledProvenance"
        ) is not False
    ):
        raise ValueError("Signed-pull qualification adapter contract mismatch.")
    rows = list(adapter.get("inputs", []))
    if len(rows) != 2:
        raise ValueError("Signed-pull adapter must bind exactly BF then DF.")
    for row, channel in zip(rows, ("BF", "DF")):
        key = channel.lower()
        if (
            row.get("channel") != channel
            or int(row.get("bytes", -1)) != EXPECTED_BYTES[key]
            or str(row.get("sha256", "")).upper() != EXPECTED[key]
            or PHYSICAL_IDENTITY not in str(row.get("entryPath", ""))
        ):
            raise ValueError(f"Signed-pull adapter {channel} row mismatch.")


def validate_terminal_gate(paths: dict[str, Path]) -> None:
    gate = read_json(paths["terminalGate"])
    if (
        gate.get("schema") != "argos_r18a_terminal_response_gate_v1"
        or gate.get("state") != "PASS_R18A_SIGNED_FRESH_LOT_EXISTING_CROPS_COLLECTED"
        or gate.get("requestId") != EXPECTED_REQUEST_ID
        or gate.get("responseId") != EXPECTED_RESPONSE_ID
        or gate.get("endpointState") != "PASS_DATA_PULL"
        or gate.get("signedResponseVerified") is not True
        or gate.get("signerThumbprint") != EXPECTED_SIGNER
        or int(gate.get("returnedFileCount", -1)) != 24
        or gate.get("requestRetried") is not False
        or gate.get("taskOrProcessActionPerformed") is not False
        or gate.get("sourceMutationPerformed") is not False
        or gate.get("pixelsDecodedDuringCollection") is not False
    ):
        raise ValueError("Authenticated terminal response gate mismatch.")
    target_rows = [
        row for row in gate.get("files", [])
        if PHYSICAL_IDENTITY in str(row.get("entryPath", ""))
    ]
    if len(target_rows) != 3:
        raise ValueError("Authenticated target inventory must contain proposal, BF, and DF.")
    by_name = {Path(str(row["entryPath"])).name: row for row in target_rows}
    expected_names = {
        "SCRIBE_PROPOSAL.json",
        "BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
        "DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
    }
    if set(by_name) != expected_names:
        raise ValueError("Authenticated target inventory membership mismatch.")
    if any("MULTI_CHANNEL_READER_SUMMARY" in str(row.get("entryPath", "")) for row in target_rows):
        raise ValueError("Unexpected multi-channel summary inventory row.")
    for channel in ("BF", "DF"):
        key = channel.lower()
        row = by_name[f"{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"]
        if (
            int(row.get("bytes", -1)) != EXPECTED_BYTES[key]
            or str(row.get("sha256", "")).upper() != EXPECTED[key]
        ):
            raise ValueError(f"Authenticated terminal {channel} row mismatch.")
        expected_local = Path(r"C:\R18A2") / Path(
            str(row["entryPath"]).replace("/", "\\")
        )
        if paths[key] != expected_local.resolve():
            raise ValueError(f"Local {channel} extraction path mismatch.")


def preflight(args: argparse.Namespace) -> dict[str, Path]:
    paths = expected_paths(args)
    if paths["project"] != PROJECT:
        raise ValueError("Sole authorized project mismatch.")
    if paths["output"] != EXPECTED_OUTPUT_ROOT:
        raise ValueError("Exact once-only held-out output root mismatch.")
    if paths["output"].exists() or not paths["output"].parent.is_dir():
        raise FileExistsError(f"Fresh output root required: {paths['output']}")
    if sha256_file(paths["runner"]) != args.expected_runner_sha256.upper():
        raise ValueError("Runner SHA-256 mismatch.")
    for key in (
        "provider", "developmentGate", "baseManifest", "supplementalManifest",
        "crosswalk", "looGate", "terminalGate", "adapter", "bf", "df",
    ):
        require_pin(paths[key], EXPECTED[key])
    if (
        paths["bf"].stat().st_size != EXPECTED_BYTES["bf"]
        or paths["df"].stat().st_size != EXPECTED_BYTES["df"]
    ):
        raise ValueError("Authenticated source byte count mismatch.")
    validate_adapter(paths)
    validate_terminal_gate(paths)
    return paths


def build_job(paths: dict[str, Path]) -> dict[str, Any]:
    base_root = paths["baseManifest"].parent
    qualification_sha = sha256_file(paths["adapter"])
    return {
        "schema": "argos_opencv_scribe_job_v1",
        "revision": REVISION,
        "jobId": "R18ZU_HELD_OUT_Z_FULL_CHAIN",
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "identity": {
            "lotId": "62623-743",
            "acquisitionId": "62623-743_20260720111120",
            "slotId": "Slot04",
            "physicalIdentity": PHYSICAL_IDENTITY,
        },
        "inputMode": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
        "inputQualification": {
            "state": "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT",
            "physicalIdentity": PHYSICAL_IDENTITY,
            "qualificationAdapterPath": str(paths["adapter"]),
            "qualificationAdapterSha256": qualification_sha,
            "terminalResponseGatePath": str(paths["terminalGate"]),
            "terminalResponseGateSha256": EXPECTED["terminalGate"],
            "qualificationEvidenceMode":
                "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT",
            "internalExecutionMode": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
            "legacyProposalOrSummaryEvidenceSynthesized": False,
            "installedProposalEligibleIdentity": False,
            "installedConsensusState": "NOT_REEVALUATED_BY_LOCAL_SIGNED_PULL",
        },
        "inputs": {
            channel: {
                "path": str(paths[channel]),
                "canonicalProvenancePath": str(paths[channel]),
                "signedPullSourceEntryPath": (
                    "data/JBOD_PROCESSOR_REVIEW/identity/proposals/"
                    f"{PHYSICAL_IDENTITY}/scribe/"
                    f"{channel.upper()}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
                ),
                "ioPathClass": "LOCAL_AUTHENTICATED_SIGNED_PULL_REVIEW_ONLY",
                "aliasName": "",
                "sha256": EXPECTED[channel],
                "bytes": EXPECTED_BYTES[channel],
                "coordinateFrameId": "R18A_SIGNED_PULL_ORIENTED_DETECTOR_INPUT",
            }
            for channel in ("bf", "df")
        },
        "references": {
            "manifestPath": str(paths["baseManifest"]),
            "manifestSha256": EXPECTED["baseManifest"],
            "roots": [
                {"relativePrefix": "glyphs", "path": str(base_root / "glyphs")},
                {
                    "relativePrefix": "glyphs_v5_confirmed_20260806",
                    "path": str(base_root / "glyphs_v5_confirmed_20260806"),
                },
            ],
            "supplementalManifestPath": str(paths["supplementalManifest"]),
            "supplementalManifestSha256": EXPECTED["supplementalManifest"],
            "r18zExactLineageLooGatePath": str(paths["looGate"]),
            "r18zExactLineageLooGateSha256": EXPECTED["looGate"],
            "exactScribeLineageCrosswalkPath": str(paths["crosswalk"]),
            "exactScribeLineageCrosswalkSha256": EXPECTED["crosswalk"],
            "excludedPhysicalIdentity": PHYSICAL_IDENTITY,
        },
        "search": {
            "expectedRegions": [],
            "boundedExceptionSearch": False,
            "maximumWorkingDimension": 1600,
            "maximumCandidates": 64,
            "orientationStepDegrees": 15,
        },
        "outputRoot": str(paths["output"]),
        "authority": {
            "reviewOnly": True,
            "automaticIdentityAuthority": False,
            "trainingEligible": False,
            "xmlEligible": False,
            "productionEligible": False,
            "mayClearHolds": False,
        },
    }


def validate_local_signed_pull_job_shape(
    original_validate: Any,
    job: dict[str, Any],
) -> None:
    qualification = job.get("inputQualification", {})
    if qualification.get("state") != "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT":
        original_validate(job)
        return
    if job.get("schema") != "argos_opencv_scribe_job_v1":
        raise ValueError("Scribe job schema mismatch.")
    authority = job.get("authority", {})
    if authority.get("reviewOnly") is not True:
        raise ValueError("Review-only authority is required.")
    for forbidden in (
        "automaticIdentityAuthority", "trainingEligible", "xmlEligible",
        "productionEligible", "mayClearHolds",
    ):
        if bool(authority.get(forbidden)):
            raise ValueError(f"Authority contract refused: {forbidden}")
    if job.get("inputMode") != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT":
        raise ValueError("Signed-pull translation requires the internal oriented mode.")
    search = job.get("search", {})
    if search.get("expectedRegions") or bool(search.get("boundedExceptionSearch")):
        raise ValueError("Signed-pull oriented inputs refuse localization search.")
    if qualification.get("physicalIdentity") != PHYSICAL_IDENTITY:
        raise ValueError("Signed-pull physical identity mismatch.")
    if (
        qualification.get("internalExecutionMode")
        != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT"
        or qualification.get("qualificationAdapterSha256") != EXPECTED["adapter"]
        or qualification.get("terminalResponseGateSha256") != EXPECTED["terminalGate"]
        or qualification.get("legacyProposalOrSummaryEvidenceSynthesized") is not False
    ):
        raise ValueError("Signed-pull qualification translation mismatch.")
    for forbidden in (
        "proposalPath", "proposalSha256", "multiChannelSummaryPath",
        "multiChannelSummarySha256",
    ):
        if forbidden in qualification:
            raise ValueError(f"Fabricated legacy qualification field refused: {forbidden}")
    for channel in ("bf", "df"):
        source = job.get("inputs", {}).get(channel, {})
        if source.get("ioPathClass") != "LOCAL_AUTHENTICATED_SIGNED_PULL_REVIEW_ONLY":
            raise ValueError(f"Signed-pull input path class mismatch: {channel}")
        if str(source.get("canonicalProvenancePath", "")) != str(source.get("path", "")):
            raise ValueError(f"Signed-pull local copy path mismatch: {channel}")


def compact_hypothesis(row: dict[str, Any]) -> dict[str, Any]:
    envelope = dict(row.get("ocrEnvelope", {}))
    return {
        "channel": row.get("channel"),
        "polarity": row.get("polarity"),
        "direction": row.get("direction"),
        "regionSource": row.get("regionSource"),
        "imageFirstString": row.get("imageFirstString"),
        "selectionScore": row.get("selectionScore"),
        "boundaryComplete": row.get("boundaryComplete"),
        "checksumValid": row.get("checksumValid"),
        "expectedCheckCharacters": row.get("expectedCheckCharacters"),
        "observedCheckCharacters": row.get("observedCheckCharacters"),
        "envelopePassed": envelope.get("passed"),
        "envelopeDecision": envelope.get("decision"),
        "heldPositions": envelope.get("heldPositions", []),
        "canonicalZAdmissionPositions": envelope.get(
            "canonicalZAdmissionPositions", []
        ),
    }


def truth_after_result(paths: dict[str, Path]) -> tuple[str, str, int]:
    manifest = read_json(paths["supplementalManifest"])
    rows = [
        row for row in manifest.get("references", [])
        if str(row.get("physicalIdentity", "")) == PHYSICAL_IDENTITY
    ]
    if len(rows) != 1:
        raise ValueError("Held-out truth binding is not unique.")
    row = rows[0]
    truth = str(row.get("truth", ""))
    label = str(row.get("label", ""))
    position = int(row.get("position", 0))
    if len(truth) != 12 or not truth.isalnum() or len(label) != 1:
        raise ValueError("Held-out truth binding is malformed.")
    return truth, label, position


def main(argv: Iterable[str]) -> int:
    global _ACTIVE_EXECUTION_GATE, _ACTIVE_PROVIDER_RUN_COUNT
    global _ACTIVE_RUNNER_SHA256, _ACTIVE_JOB_PATH, _ACTIVE_JOB_SHA256
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("preflight", "run"), required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--bf", type=Path, required=True)
    parser.add_argument("--df", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--expected-runner-sha256", required=True)
    args = parser.parse_args(list(argv))
    if not sys.dont_write_bytecode:
        raise RuntimeError("Run with Python bytecode writes disabled (-B).")
    paths = preflight(args)
    if args.mode == "preflight":
        print(json.dumps({
            "state": "PASS_R18ZU_HELD_OUT_Z_PREFLIGHT",
            "providerSha256": EXPECTED["provider"],
            "adapterSha256": EXPECTED["adapter"],
        }))
        return 0

    paths["output"].mkdir()
    job_path = paths["output"] / "JOB.json"
    result_path = paths["output"] / "RESULT.json"
    gate_path = paths["output"] / "GATE.json"
    _ACTIVE_EXECUTION_GATE = gate_path
    _ACTIVE_RUNNER_SHA256 = args.expected_runner_sha256.upper()
    job = build_job(paths)
    write_json_new(job_path, job)
    job_sha = sha256_file(job_path)
    _ACTIVE_JOB_PATH = job_path
    _ACTIVE_JOB_SHA256 = job_sha
    provider = load_module("argos_scribe_r18zu_held_out_provider", paths["provider"])
    original_loader = provider.R17D.R17C.R17B._load_r11
    r11 = original_loader()
    original_validate = r11.validate_job_shape
    qualification_boundary_calls = 0

    def adapted_validate(candidate: dict[str, Any]) -> None:
        nonlocal qualification_boundary_calls
        qualification_boundary_calls += 1
        validate_local_signed_pull_job_shape(original_validate, candidate)

    bindings = {
        "outerEvaluate": provider.R18ZV.evaluate_detector_input_enveloped,
        "outerApply": provider.R18ZV._apply_result_envelope_state,
        "resultEnforce": provider.R17E.enforce_result_verifier_only,
        "pipelineRevision": provider.R18ZV.REVISION,
        "rank": provider.R18H.rank_with_run_structure,
        "qualificationLoader": original_loader,
        "qualificationValidator": original_validate,
    }
    r11.validate_job_shape = adapted_validate
    provider.R17D.R17C.R17B._load_r11 = lambda: r11
    try:
        _ACTIVE_PROVIDER_RUN_COUNT = 1
        return_code = provider.run_job(job_path, result_path)
    finally:
        provider.R17D.R17C.R17B._load_r11 = original_loader
        r11.validate_job_shape = original_validate

    restored = {
        "outerEvaluate": provider.R18ZV.evaluate_detector_input_enveloped
        is bindings["outerEvaluate"],
        "outerApply": provider.R18ZV._apply_result_envelope_state
        is bindings["outerApply"],
        "resultEnforce": provider.R17E.enforce_result_verifier_only
        is bindings["resultEnforce"],
        "pipelineRevision": provider.R18ZV.REVISION == bindings["pipelineRevision"],
        "rank": provider.R18H.rank_with_run_structure is bindings["rank"],
        "qualificationLoader": provider.R17D.R17C.R17B._load_r11
        is bindings["qualificationLoader"],
        "qualificationValidator": r11.validate_job_shape
        is bindings["qualificationValidator"],
    }
    lock_available = provider._RUNTIME_PATCH_LOCK.acquire(blocking=False)
    if lock_available:
        provider._RUNTIME_PATCH_LOCK.release()
    if return_code != 0 or not all(restored.values()) or not lock_available:
        raise ValueError("R18ZU full-chain runtime restoration failed.")

    result = read_json(result_path)
    hypotheses = list(result.get("hypotheses", []))
    hypothesis_keys = {
        (
            str(row.get("channel", "")),
            str(row.get("polarity", "")),
            str(row.get("direction", "")),
        )
        for row in hypotheses
    }
    if (
        len(hypotheses) != 8
        or hypothesis_keys != EXPECTED_HYPOTHESES
    ):
        raise ValueError("Exact eight-hypothesis full-chain membership failed.")
    if any(
        not isinstance(row.get("scribePresence"), dict)
        or not isinstance(row.get("ocrEnvelope"), dict)
        or len(row.get("positions", [])) != 12
        for row in hypotheses
    ):
        raise ValueError("One or more returned hypotheses lack full evaluator evidence.")

    provenance = dict(result.get("provenance", {}))
    sources = dict(provenance.get("sources", {}))
    input_qualification = dict(provenance.get("inputQualification", {}))
    if (
        result.get("revision") != PROVIDER_REVISION
        or provenance.get("r18ztProviderSha256")
        != "AEF048D3CCEAF378A9FF43D5844DD1A28431E662F5BC54AFF384C4DB73A2C793"
        or provenance.get("canonicalZDevelopmentGateSha256")
        != EXPECTED["developmentGate"]
        or provenance.get("runtimeExpectedTruthUsedForGlyphSelection") is not False
        or provenance.get("checksumMayRewriteGlyphs") is not False
        or provenance.get("checksumMaySelectHypothesis") is not False
        or input_qualification.get("state")
        != "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT"
        or sources.get("jobSha256") != job_sha
        or sources.get("bf", {}).get("sha256") != EXPECTED["bf"]
        or sources.get("df", {}).get("sha256") != EXPECTED["df"]
        or result.get("eligibleIdentity") is not False
    ):
        raise ValueError("R18ZU result provenance or authority mismatch.")

    compact = [compact_hypothesis(row) for row in hypotheses]
    raw_region_sources = sorted({
        str(row.get("regionSource", "")) for row in hypotheses
    })
    internal_region_source_qualified = raw_region_sources == [
        "HASH_PINNED_INSTALLED_REVIEW_ONLY_PROCESSOR_OUTPUT"
    ]
    selected = hypotheses[0]
    selected_compact = compact[0]
    truth, expected_label, expected_position = truth_after_result(paths)
    position = selected["positions"][expected_position - 1]
    geometry = dict(position.get("glyphArbitration", {}).get("canonicalZRunGeometry", {}))
    admission = dict(position.get("glyphEnvelope", {}).get("canonicalZAdmission", {}))
    candidate = dict(position.get("candidates", [{}])[0])
    score_unchanged = (
        geometry.get("scoreIncreased") is False
        and isinstance(geometry.get("inheritedScore"), (int, float))
        and math.isclose(
            float(position.get("scoreUsedForGrid")),
            float(geometry["inheritedScore"]),
            rel_tol=0.0,
            abs_tol=1e-12,
        )
    )
    checksum_coherent = (
        selected.get("checksumValid") is True
        and selected.get("expectedCheckCharacters") == truth[-2:]
        and selected.get("observedCheckCharacters") == truth[-2:]
    )
    exact = (
        selected.get("imageFirstString") == truth
        and result.get("imageFirstString") == truth
        and position.get("imageFirst") == expected_label
    )
    envelope_passed = selected.get("ocrEnvelope", {}).get("passed") is True
    canonical_evidence_passed = (
        position.get("glyphArbitration", {}).get("mode")
        == provider.CANONICAL_Z_MODE
        and geometry.get("complete") is True
        and geometry.get("passed") is True
        and geometry.get("candidateInserted") is True
        and geometry.get("appearanceBankCount") == 0
        and geometry.get("topologyBankCount") == 0
        and geometry.get("runStructureBankPresent") is False
        and candidate.get("character") == expected_label
        and candidate.get("candidateSource") == provider.CANONICAL_Z_MODE
        and candidate.get("referencePrototypeBacked") is False
        and candidate.get("scoreInheritedAsCeiling") is True
        and admission.get("applied") is True
        and admission.get("originalDecision") == "HOLD_SELECTED_LABEL_UNOBSERVED"
        and admission.get("coveredRivalEvidenceComplete") is True
        and admission.get("coveredRivalInsideEnvelope") is False
        and admission.get("selectedLabelChanged") is False
        and admission.get("scoreIncreased") is False
        and isinstance(admission.get("preAdmissionGlyphEnvelope"), dict)
        and score_unchanged
    )
    resolution = dict(result.get("ambiguityResolution", {}))
    resolution_safe = (
        resolution.get("state") == "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"
        and resolution.get("selectionScoreIncreased") is False
    )
    passed = (
        exact
        and envelope_passed
        and canonical_evidence_passed
        and checksum_coherent
        and resolution_safe
        and qualification_boundary_calls == 1
        and internal_region_source_qualified
        and all(restored.values())
        and lock_available
    )
    gate = {
        "schema": "argos_opencv_scribe_r18zu_held_out_z_gate_v1",
        "state": (
            "PASS_R18ZU_HELD_OUT_Z_EXACT_FULL_CHAIN"
            if passed else "HOLD_R18ZU_HELD_OUT_Z_NOT_EXACT_OR_NOT_ADMISSIBLE"
        ),
        "disposition": "DIAGNOSTIC_ONLY",
        "providerRunCount": 1,
        "automaticRetryCount": 0,
        "directStructuralEvaluatorCallsByHarness": 0,
        "provider": {
            "path": str(paths["provider"]),
            "sha256": EXPECTED["provider"],
            "developmentGateSha256": EXPECTED["developmentGate"],
        },
        "runner": {
            "path": str(paths["runner"]),
            "sha256": args.expected_runner_sha256.upper(),
        },
        "job": {"path": str(job_path), "sha256": job_sha},
        "result": {"path": str(result_path), "sha256": sha256_file(result_path)},
        "qualification": {
            "state": "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT",
            "adapterSha256": EXPECTED["adapter"],
            "terminalGateSha256": EXPECTED["terminalGate"],
            "translatedInternalExecutionMode":
                "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
            "legacyProposalOrSummaryEvidenceSynthesized": False,
            "qualificationBoundaryValidationCalls": qualification_boundary_calls,
            "qualificationBoundaryCalledExactlyOnce": (
                qualification_boundary_calls == 1
            ),
            "rawProviderRegionSources": raw_region_sources,
            "rawProviderRegionSourceSemantics": (
                "UNCHANGED_INTERNAL_EXECUTION_MODE_TOKEN_NOT_INSTALLED_SOURCE_PROVENANCE"
            ),
            "rawProviderRegionSourceQualified": internal_region_source_qualified,
            "actualSourceProvenanceState": (
                "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT"
            ),
        },
        "normalHypothesisCount": len(hypotheses),
        "allEightNormalHypothesesPresent": hypothesis_keys == EXPECTED_HYPOTHESES,
        "hypotheses": compact,
        "selectedHypothesis": selected_compact,
        "truthComparedOnlyAfterProviderResult": truth,
        "selectedImageFirstExact": exact,
        "selectedEnvelopePassed": envelope_passed,
        "selectedChecksumCoherent": checksum_coherent,
        "canonicalZEvidencePassed": canonical_evidence_passed,
        "selectionScoreIncreased": not score_unchanged,
        "resultLevel": {
            "state": result.get("state"),
            "imageFirstString": result.get("imageFirstString"),
            "proposedString": result.get("proposedString"),
            "eligibleIdentity": result.get("eligibleIdentity"),
            "holds": result.get("holds", []),
        },
        "runtimeRestoration": {
            **restored,
            "sharedLockAvailableAfterRun": lock_available,
        },
        "identityAccepted": False,
        "referenceAdmissionPerformed": False,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "publicationAuthorized": False,
    }
    write_json_new(gate_path, gate)
    print(json.dumps({
        "state": gate["state"],
        "selectedImageFirst": selected.get("imageFirstString"),
        "selectedEnvelopePassed": envelope_passed,
        "selectedChecksumCoherent": checksum_coherent,
        "canonicalZEvidencePassed": canonical_evidence_passed,
        "normalHypothesisCount": len(hypotheses),
        "resultState": result.get("state"),
        "gatePath": str(gate_path),
        "gateSha256": sha256_file(gate_path),
    }, indent=2))
    return 0 if passed else 2


if __name__ == "__main__":
    try:
        exit_code = main(sys.argv[1:])
    except Exception as error:
        if (
            _ACTIVE_EXECUTION_GATE is not None
            and _ACTIVE_EXECUTION_GATE.parent.is_dir()
            and not _ACTIVE_EXECUTION_GATE.exists()
        ):
            write_json_new(_ACTIVE_EXECUTION_GATE, {
                "schema": "argos_opencv_scribe_r18zu_held_out_z_gate_v1",
                "state": "HOLD_R18ZU_EXECUTED_VALIDATION_FAILED_NO_RETRY",
                "disposition": "WITHDRAWN",
                "providerRunCount": _ACTIVE_PROVIDER_RUN_COUNT,
                "automaticRetryCount": 0,
                "runner": {
                    "path": str(Path(__file__).resolve()),
                    "sha256": _ACTIVE_RUNNER_SHA256,
                },
                "job": {
                    "path": (
                        None if _ACTIVE_JOB_PATH is None
                        else str(_ACTIVE_JOB_PATH)
                    ),
                    "sha256": _ACTIVE_JOB_SHA256,
                },
                "errorType": type(error).__name__,
                "detail": str(error),
                "identityAccepted": False,
                "publicationAuthorized": False,
            })
        raise
    raise SystemExit(exit_code)
