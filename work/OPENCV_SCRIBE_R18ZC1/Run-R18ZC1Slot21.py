#!/usr/bin/env python3
"""Run current Slot21 once through the frozen public R18Z full job path."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROJECT = Path(r"C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab-scribe-opencv")
PHYSICAL_IDENTITY = "62546-481_20260707164232_Slot21"
REVISION = "R18ZC1_CORRECTED_FULL_CHAIN_SLOT21_20260905"
PROVIDER_REVISION = "ARGOS_OPENCV_SCRIBE_V1R18Z_EXACT_SCRIBE_LINEAGE_ENVELOPES_DIAGNOSTIC_20260905"
EXPECTED = {
    "provider": "54BB0152420B5F197C1F0B353AEDF021185BBBA2EBD415B05320CFF92DD02DA2",
    "nestedProvider": "BA85E9594562334C54A7CC7A0D7B2DDA3868714D8A87A223E2B2A04F589FDC0B",
    "baseManifest": "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229",
    "supplementalManifest": "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD",
    "crosswalk": "84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2",
    "looGate": "D8F0C0923BFDD6B82C4B0B0C57142825C08C0DB3F5395210A5DD7FE2E6E8DAD8",
    "terminalCheckpointGate": "AFE5D75B4ED250C961961A756A52B0BA8D46E50B336E9B11924CBCD9F6E1F335",
    "terminalManifest": "EAA38E6AC485FCA533513687E0CF5094BC183AA0482CFE7AAD09B857CBC23543",
    "inventory": "24B2629838E774938CF69D69EE7DD863413E29136145B56A2734FCAB16113E8F",
    "binding": "11DDD4CCF3B05FA3EC061B9994586117E36ACC3C41C086F0117AD48CF7EE676E",
    "bf": "96046D91BBD6DF81E678224525560BD9C77C0DC09DD89A25992B07F8D1213B93",
    "df": "8DFD50AE1E0958CE01D7E32E0936978F157C2FECD0CB910BCC27DF9F7CE63CB8",
}
EXPECTED_BYTES = {"bf": 2298990, "df": 1785517}


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
    value = json.loads(path.read_text(encoding="utf-8-sig"))
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
        "provider": project / "work/OPENCV_SCRIBE_R18Z/ArgosOpenCvScribeV1R18Z.py",
        "nestedProvider": project / "work/OPENCV_SCRIBE_R18Z/ArgosOpenCvScribeV1R18ZV.py",
        "baseManifest": project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json",
        "supplementalManifest": project / "work/OPENCV_SCRIBE_R18Z/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json",
        "crosswalk": project / "work/OPENCV_SCRIBE_R18Z/reference_bank/R18Z_EXACT_SCRIBE_LINEAGE_CROSSWALK.json",
        "looGate": project / "work/OPENCV_SCRIBE_R18Z/evidence/R18Z_EXACT_LINEAGE_LOO_GATE.json",
        "adapter": project / "work/OPENCV_SCRIBE_R18ZC1/R18ZC1_SIGNED_PULL_QUALIFICATION_ADAPTER.json",
        "terminalCheckpointGate": project / "work/OPENCV_SCRIBE_R18W4S21/R18W4S21_SIGNED_TERMINAL_RESPONSE_CHECKPOINT_GATE.json",
        "terminalManifest": project / "work/OPENCV_SCRIBE_R18W4S21/R18W4S21_SIGNED_TERMINAL_RESPONSE_MANIFEST.json",
        "inventory": project / "work/OPENCV_SCRIBE_R18W4S21/R18W4S21_RETURNED_FILE_INVENTORY.json",
        "binding": project / "work/OPENCV_SCRIBE_R18W4S21/R18W4S21_SLOT21_BINDING.json",
        "bf": args.bf.resolve(),
        "df": args.df.resolve(),
        "output": args.output_root.resolve(),
    }


def preflight(args: argparse.Namespace) -> tuple[dict[str, Path], str]:
    paths = expected_paths(args)
    if paths["project"] != PROJECT:
        raise ValueError(f"Sole authorized project mismatch: {paths['project']}")
    if paths["output"].exists() or not paths["output"].parent.is_dir():
        raise FileExistsError(f"Fresh output root required: {paths['output']}")
    if sha256_file(paths["runner"]) != args.expected_runner_sha256.upper():
        raise ValueError("Runner SHA-256 mismatch.")
    for key in (
        "provider", "nestedProvider", "baseManifest", "supplementalManifest",
        "crosswalk", "looGate", "terminalCheckpointGate", "terminalManifest",
        "inventory", "bf", "df",
    ):
        require_pin(paths[key], EXPECTED[key])
    if paths["bf"].stat().st_size != EXPECTED_BYTES["bf"] or paths["df"].stat().st_size != EXPECTED_BYTES["df"]:
        raise ValueError("Authenticated source byte count mismatch.")
    adapter_sha = sha256_file(paths["adapter"])
    adapter = read_json(paths["adapter"])
    if (
        adapter.get("schema") != "argos_opencv_scribe_authenticated_data_pull_qualification_adapter_v1"
        or adapter.get("state") != "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT"
        or adapter.get("physicalIdentity") != PHYSICAL_IDENTITY
        or adapter.get("truthIncluded") is not False
        or adapter.get("response", {}).get("signedResponseVerified") is not True
        or adapter.get("request", {}).get("retried") is not False
        or int(adapter.get("inventory", {}).get("returnedFileCount", -1)) != 2
        or adapter.get("terminalResponseCheckpointGate", {}).get("sha256") != EXPECTED["terminalCheckpointGate"]
        or adapter.get("qualificationTranslation", {}).get("from") != "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT"
        or adapter.get("qualificationTranslation", {}).get("toInternalExecutionMode") != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT"
        or adapter.get("legacyProducerEvidence", {}).get("proposalMetadataIncluded") is not False
        or adapter.get("legacyProducerEvidence", {}).get("multiChannelSummaryIncluded") is not False
        or adapter.get("legacyProducerEvidence", {}).get("proposalOrSummaryPathsSynthesized") is not False
        or adapter.get("legacyProducerEvidence", {}).get("proposalOrSummaryHashesSynthesized") is not False
        or adapter.get("legacyProducerEvidence", {}).get("extractedFilesRepresentedAsInstalledProvenance") is not False
    ):
        raise ValueError("Signed-pull qualification adapter contract mismatch.")
    checkpoint_gate = read_json(paths["terminalCheckpointGate"])
    terminal = checkpoint_gate.get("terminalResponse", {})
    controls = checkpoint_gate.get("controls", {})
    if (
        checkpoint_gate.get("schema") != "argos_opencv_scribe_r18w4s21_signed_terminal_response_checkpoint_gate_v1"
        or checkpoint_gate.get("state") != "PASS_R18W4S21_SIGNED_TERMINAL_RESPONSE_CHECKPOINT_GATE"
        or checkpoint_gate.get("manifest", {}).get("sha256") != EXPECTED["terminalManifest"]
        or terminal.get("requestId") != "REQ_S21_20260905212322_S9RHWN0X00G4K59QB7Q1120VDR"
        or terminal.get("responseId") != "R_8C756EDA3176_20260905231521702_f4fecab3"
        or terminal.get("state") != "PASS_DATA_PULL"
        or terminal.get("signedResponseVerified") is not True
        or terminal.get("payloadSha256") != "11EFDC996334C4645F943AFE3DF3D6474FA7A2E6AE8827A0377F3BC153E3EACF"
        or int(terminal.get("returnedFileCount", -1)) != 2
        or terminal.get("slot21BindingMatched") is not True
        or controls.get("requestPublishedExactlyOnce") is not True
        or controls.get("requestRetried") is not False
        or int(controls.get("matchingAuthenticatedResponseCount", -1)) != 1
        or controls.get("identityAccepted") is not False
    ):
        raise ValueError("Authenticated terminal-response checkpoint gate mismatch.")
    inventory = read_json(paths["inventory"])
    rows = list(inventory.get("files", inventory.get("rows", [])))
    if (
        inventory.get("schema") != "argos_opencv_scribe_r18w4s21_returned_file_inventory_v1"
        or inventory.get("state") != "PASS_R18W4S21_EXACT_TWO_FILE_HASH_INVENTORY"
        or inventory.get("requestId") != terminal.get("requestId")
        or inventory.get("responseId") != terminal.get("responseId")
        or inventory.get("returnedFileCount") != 2
        or len(rows) != 2
    ):
        raise ValueError("Authenticated inventory is not exactly two files.")
    for row, channel in zip(rows, ("BF", "DF")):
        key = channel.lower()
        if (
            str(row.get("kind", "")).upper() != f"{channel}_ORIENTED_INPUT_PNG"
            or int(row.get("bytes", -1)) != EXPECTED_BYTES[key]
            or str(row.get("sha256", "")).upper() != EXPECTED[key]
            or Path(str(row.get("extractedPath", ""))).resolve() != paths[key]
            or PHYSICAL_IDENTITY not in str(row.get("relativePath", ""))
        ):
            raise ValueError(f"Authenticated {channel} inventory row mismatch.")
    adapter_inputs = list(adapter.get("inputs", []))
    if len(adapter_inputs) != 2:
        raise ValueError("Signed-pull adapter input count mismatch.")
    for row, channel in zip(adapter_inputs, ("BF", "DF")):
        key = channel.lower()
        if (
            row.get("channel") != channel
            or int(row.get("bytes", -1)) != EXPECTED_BYTES[key]
            or str(row.get("sha256", "")).upper() != EXPECTED[key]
            or PHYSICAL_IDENTITY not in str(row.get("relativePath", ""))
        ):
            raise ValueError(f"Signed-pull adapter {channel} row mismatch.")
    return paths, adapter_sha


def build_job(paths: dict[str, Path], adapter_sha: str) -> dict[str, Any]:
    base_root = paths["baseManifest"].parent
    return {
        "schema": "argos_opencv_scribe_job_v1",
        "revision": REVISION,
        "jobId": "R18ZC1_SLOT21_CORRECTED_FULL_CHAIN",
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "identity": {
            "lotId": "62546-481",
            "acquisitionId": "62546-481_20260707164232",
            "slotId": "Slot21",
            "physicalIdentity": PHYSICAL_IDENTITY,
        },
        "inputMode": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
        "inputQualification": {
            "state": "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT",
            "physicalIdentity": PHYSICAL_IDENTITY,
            "qualificationAdapterPath": str(paths["adapter"]),
            "qualificationAdapterSha256": adapter_sha,
            "terminalResponseCheckpointGatePath": str(paths["terminalCheckpointGate"]),
            "terminalResponseCheckpointGateSha256": EXPECTED["terminalCheckpointGate"],
            "returnedFileInventoryPath": str(paths["inventory"]),
            "returnedFileInventorySha256": EXPECTED["inventory"],
            "qualificationEvidenceMode": "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT",
            "internalExecutionMode": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
            "legacyProposalOrSummaryEvidenceSynthesized": False,
            "installedProposalEligibleIdentity": False,
            "installedConsensusState": "NOT_REEVALUATED_BY_LOCAL_TWO_FILE_PULL",
        },
        "inputs": {
            channel: {
                "path": str(paths[channel]),
                "canonicalProvenancePath": str(paths[channel]),
                "signedPullSourceRelativePath": f"identity/proposals/{PHYSICAL_IDENTITY}/scribe/{channel.upper()}_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
                "ioPathClass": "LOCAL_AUTHENTICATED_SIGNED_PULL_REVIEW_ONLY",
                "aliasName": "",
                "sha256": EXPECTED[channel],
                "bytes": EXPECTED_BYTES[channel],
                "coordinateFrameId": "CURRENT_SLOT21_SIGNED_PULL_ORIENTED_DETECTOR_INPUT",
            }
            for channel in ("bf", "df")
        },
        "references": {
            "manifestPath": str(paths["baseManifest"]),
            "manifestSha256": EXPECTED["baseManifest"],
            "roots": [
                {"relativePrefix": "glyphs", "path": str(base_root / "glyphs")},
                {"relativePrefix": "glyphs_v5_confirmed_20260806", "path": str(base_root / "glyphs_v5_confirmed_20260806")},
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
    """Admit one truthful local signed-pull state without fabricating legacy evidence."""
    qualification = job.get("inputQualification", {})
    if qualification.get("state") != "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT":
        original_validate(job)
        return
    if job.get("schema") != "argos_opencv_scribe_job_v1":
        raise ValueError("Scribe job schema mismatch.")
    authority = job.get("authority", {})
    if not bool(authority.get("reviewOnly")):
        raise ValueError("Review-only authority is required.")
    for forbidden in (
        "automaticIdentityAuthority", "trainingEligible", "xmlEligible",
        "productionEligible", "mayClearHolds",
    ):
        if bool(authority.get(forbidden)):
            raise ValueError(f"Authority contract refused: {forbidden}")
    if job.get("inputMode") != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT":
        raise ValueError("Local signed-pull translation requires the unchanged internal execution mode.")
    search = job.get("search", {})
    if search.get("expectedRegions") or bool(search.get("boundedExceptionSearch")):
        raise ValueError("Local signed-pull oriented inputs refuse localization search.")
    if qualification.get("physicalIdentity") != PHYSICAL_IDENTITY:
        raise ValueError("Local signed-pull physical identity mismatch.")
    if qualification.get("internalExecutionMode") != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT":
        raise ValueError("Local signed-pull internal execution translation mismatch.")
    if qualification.get("qualificationAdapterSha256") == "":
        raise ValueError("Local signed-pull qualification adapter is unbound.")
    if qualification.get("terminalResponseCheckpointGateSha256") != EXPECTED["terminalCheckpointGate"]:
        raise ValueError("Local signed-pull terminal checkpoint gate is unbound.")
    if qualification.get("returnedFileInventorySha256") != EXPECTED["inventory"]:
        raise ValueError("Local signed-pull returned inventory is unbound.")
    if qualification.get("legacyProposalOrSummaryEvidenceSynthesized") is not False:
        raise ValueError("Legacy proposal or summary evidence synthesis is forbidden.")
    for forbidden in (
        "proposalPath", "proposalSha256", "multiChannelSummaryPath",
        "multiChannelSummarySha256",
    ):
        if forbidden in qualification:
            raise ValueError(f"Legacy qualification field is forbidden: {forbidden}")
    for channel in ("bf", "df"):
        source = job.get("inputs", {}).get(channel, {})
        if source.get("ioPathClass") != "LOCAL_AUTHENTICATED_SIGNED_PULL_REVIEW_ONLY":
            raise ValueError(f"Local signed-pull input path class mismatch: {channel}")
        if str(source.get("canonicalProvenancePath", "")) != str(source.get("path", "")):
            raise ValueError(f"Local signed-pull canonical copy path mismatch: {channel}")


def compact_hypothesis(row: dict[str, Any]) -> dict[str, Any]:
    envelope = row.get("ocrEnvelope", {})
    return {
        "channel": row.get("channel"),
        "polarity": row.get("polarity"),
        "direction": row.get("direction"),
        "imageFirstString": row.get("imageFirstString"),
        "proposedString": row.get("proposedString"),
        "selectionScore": row.get("selectionScore"),
        "boundaryComplete": row.get("boundaryComplete"),
        "checksumValid": row.get("checksumValid"),
        "grid": {key: row.get(key) for key in ("x", "y", "cellWidth", "cellHeight")},
        "envelopePassed": envelope.get("passed"),
        "envelopeDecision": envelope.get("decision"),
        "heldPositions": envelope.get("heldPositions", []),
        "correctedPositions": envelope.get("correctedPositions", []),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("preflight", "run"), required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--bf", type=Path, required=True)
    parser.add_argument("--df", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--expected-runner-sha256", required=True)
    args = parser.parse_args()
    paths, adapter_sha = preflight(args)
    if args.mode == "preflight":
        print(json.dumps({"state": "PASS_R18ZC1_PREFLIGHT", "adapterSha256": adapter_sha}))
        return 0

    paths["output"].mkdir()
    job_path = paths["output"] / "R18ZC1_SLOT21_JOB.json"
    result_path = paths["output"] / "R18ZC1_SLOT21_PROVIDER_RESULT.json"
    gate_path = paths["output"] / "R18ZC1_SLOT21_COMPACT_GATE.json"
    job = build_job(paths, adapter_sha)
    write_json_new(job_path, job)
    job_sha = sha256_file(job_path)
    provider = load_module("argos_scribe_r18zc1_frozen_provider", paths["provider"])
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
        "nestedEvaluate": provider.R18H.evaluate_detector_input_structural,
        "nestedApply": provider.R17E.enforce_result_verifier_only,
        "nestedRevision": provider.R18H.REVISION,
        "supplementLoader": provider.R18ZV.R18F.R18F_LOADER,
        "qualificationLoader": original_loader,
        "qualificationValidator": original_validate,
    }
    r11.validate_job_shape = adapted_validate
    provider.R17D.R17C.R17B._load_r11 = lambda: r11
    try:
        try:
            return_code = provider.run_job(job_path, result_path)
        finally:
            provider.R17D.R17C.R17B._load_r11 = original_loader
            r11.validate_job_shape = original_validate
    except Exception as error:
        write_json_new(gate_path, {
            "schema": "argos_opencv_scribe_r18zc1_slot21_full_chain_gate_v1",
            "state": "HOLD_R18ZC1_PROVIDER_RUN_FAILED_NO_RETRY",
            "providerRunCount": 1,
            "errorType": type(error).__name__,
            "detail": str(error),
            "identityAccepted": False,
        })
        raise
    restored = {
        "outerEvaluate": provider.R18ZV.evaluate_detector_input_enveloped is bindings["outerEvaluate"],
        "outerApply": provider.R18ZV._apply_result_envelope_state is bindings["outerApply"],
        "nestedEvaluate": provider.R18H.evaluate_detector_input_structural is bindings["nestedEvaluate"],
        "nestedApply": provider.R17E.enforce_result_verifier_only is bindings["nestedApply"],
        "nestedRevision": provider.R18H.REVISION == bindings["nestedRevision"],
        "supplementLoader": provider.R18ZV.R18F.R18F_LOADER is bindings["supplementLoader"],
        "qualificationLoader": provider.R17D.R17C.R17B._load_r11 is bindings["qualificationLoader"],
        "qualificationValidator": r11.validate_job_shape is bindings["qualificationValidator"],
    }
    lock_available = provider._RUNTIME_PATCH_LOCK.acquire(blocking=False)
    if lock_available:
        provider._RUNTIME_PATCH_LOCK.release()
    if return_code != 0 or not all(restored.values()) or not lock_available:
        raise ValueError("R18Z full-chain runtime restoration failed.")
    result = read_json(result_path)
    hypotheses = list(result.get("hypotheses", []))
    compact = [compact_hypothesis(row) for row in hypotheses]
    actual_keys = {
        (str(row["channel"]), str(row["polarity"]), str(row["direction"]))
        for row in compact
    }
    expected_keys = {
        (channel, polarity, direction)
        for channel in ("BF", "DF")
        for polarity in ("DARK", "BRIGHT")
        for direction in ("FORWARD", "REVERSE_180")
    }
    if len(compact) != 8 or actual_keys != expected_keys:
        raise ValueError("R18Z did not return the exact eight normal hypotheses.")
    provenance = result.get("provenance", {})
    if (
        result.get("revision") != PROVIDER_REVISION
        or provenance.get("combinedReferenceCount") != 475
        or provenance.get("runtimeExpectedTruthUsedForGlyphSelection") is not False
        or provenance.get("exactScribeLineageCrosswalkSha256") != EXPECTED["crosswalk"]
        or result.get("eligibleIdentity") is not False
    ):
        raise ValueError("R18Z result provenance or authority mismatch.")
    source_evidence = provenance.get("sources", {})
    if (
        source_evidence.get("jobSha256") != job_sha
        or source_evidence.get("bf", {}).get("sha256") != EXPECTED["bf"]
        or source_evidence.get("df", {}).get("sha256") != EXPECTED["df"]
    ):
        raise ValueError("R18Z result source binding mismatch.")

    # The exact truth binding is opened only after the provider result exists.
    require_pin(paths["binding"], EXPECTED["binding"])
    truth_binding = read_json(paths["binding"])
    truth = str(truth_binding.get("exactTruth", ""))
    selected = compact[0]
    exact = selected["imageFirstString"] == truth
    envelope_passed = selected["envelopePassed"] is True
    gate = {
        "schema": "argos_opencv_scribe_r18zc1_slot21_full_chain_gate_v1",
        "state": (
            "PASS_R18ZC1_SLOT21_EXACT_IMAGE_FIRST"
            if exact else "HOLD_R18ZC1_SLOT21_IMAGE_FIRST_NOT_EXACT"
        ),
        "disposition": "DIAGNOSTIC_ONLY",
        "providerRunCount": 1,
        "directStructuralEvaluatorCallsByHarness": 0,
        "job": {"path": str(job_path), "sha256": job_sha},
        "result": {"path": str(result_path), "sha256": sha256_file(result_path)},
        "qualification": {
            "adapterPath": str(paths["adapter"]),
            "adapterSha256": adapter_sha,
            "state": "LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT",
            "translatedInternalExecutionMode": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
            "terminalResponseCheckpointGateSha256": EXPECTED["terminalCheckpointGate"],
            "returnedFileInventorySha256": EXPECTED["inventory"],
            "legacyProducerMetadataReturned": False,
            "legacyProposalOrSummaryEvidenceSynthesized": False,
            "signedTwoFileDataPullUsed": True,
            "qualificationBoundaryValidationCalls": qualification_boundary_calls,
        },
        "normalHypothesisKeyCount": len(actual_keys),
        "allEightNormalHypothesesPresent": actual_keys == expected_keys,
        "hypotheses": compact,
        "selectedHypothesis": selected,
        "resultLevel": {
            "state": result.get("state"),
            "imageFirstString": result.get("imageFirstString"),
            "proposedString": result.get("proposedString"),
            "eligibleIdentity": result.get("eligibleIdentity"),
            "holds": result.get("holds", []),
        },
        "truthComparedOnlyAfterProviderResult": truth,
        "selectedImageFirstExact": exact,
        "selectedEnvelopePassed": envelope_passed,
        "heldWrongIsSuccess": False,
        "runtimeRestoration": {**restored, "sharedLockAvailableAfterRun": lock_available},
        "identityAccepted": False,
        "referenceAdmissionPerformed": False,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
    }
    write_json_new(gate_path, gate)
    print(json.dumps({
        "state": gate["state"],
        "selectedHypothesis": selected,
        "resultState": result.get("state"),
        "resultHolds": [row.get("code") for row in result.get("holds", [])],
        "gatePath": str(gate_path),
        "gateSha256": sha256_file(gate_path),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
