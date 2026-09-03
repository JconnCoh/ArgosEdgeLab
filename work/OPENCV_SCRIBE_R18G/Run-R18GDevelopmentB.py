#!/usr/bin/env python3
"""Run frozen R18F on only the four frozen, still-unreviewed R18G development cases."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


DEVELOPMENT = (
    "Lot-62546-481-POST2_20260713155808_Slot17",
    "62620-548_20260810154124_Slot05",
    "62624-855_20260721120719_Slot08",
    "62625-907-POST-20260714155300_20260714155354_Slot22",
)
PROVIDER_SHA256 = "0E2CD994BB389F1DB5A50FCB2C5C9D0DD6C906925E206C913CB0FCEC1B1543B1"
R18F_LOCAL_GATE_SHA256 = "5D2C076F47F0555DE7C23EA049DF1C49B144096A85308153A7E173B9EED5BD76"
SUPPLEMENT_SHA256 = "FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114"
TERMINAL_GATE_SHA256 = "4ED056AD8B7A1FD4FEA3494E82FBCA8D324AB21E5629524B1A4745418C39E873"
COHORT_SHA256 = "91A367581F02709301A03D972E7A96C68FC1371A33DC7E13B02997442220E2BA"
BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json_new(path: Path, value: Any) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def load_provider(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("argos_scribe_r18f_development_b", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--payload-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    payload_root = args.payload_root.resolve()
    output_root = args.output_root.resolve()
    if output_root.exists():
        raise FileExistsError(output_root)

    provider_path = project / "work/OPENCV_SCRIBE_R18F/ArgosOpenCvScribeV1R18F.py"
    r18f_gate_path = project / "work/OPENCV_SCRIBE_R18F/R18F_LOCAL_GATE.json"
    supplement_path = project / "work/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    terminal_gate_path = project / "work/OPENCV_SCRIBE_R18G/R18G_TERMINAL_RESPONSE_GATE.json"
    cohort_path = project / "work/OPENCV_SCRIBE_R18G/R18G_COHORT.json"
    for path, expected in (
        (provider_path, PROVIDER_SHA256),
        (r18f_gate_path, R18F_LOCAL_GATE_SHA256),
        (supplement_path, SUPPLEMENT_SHA256),
        (terminal_gate_path, TERMINAL_GATE_SHA256),
        (cohort_path, COHORT_SHA256),
    ):
        if sha256_file(path) != expected:
            raise ValueError(f"Frozen dependency changed: {path}")
    cohort = read_json(cohort_path)
    declared_development = tuple(row["physicalIdentity"] for row in cohort["partitions"]["development"])
    if declared_development != DEVELOPMENT:
        raise ValueError("Frozen R18G development partition changed")
    if any(bool(row.get("visibleTruthKnownBeforePixelReview")) for row in cohort["partitions"]["development"]):
        raise ValueError("Development truth contract changed")

    terminal = read_json(terminal_gate_path)
    rows_by_relative = {str(row["relativePath"]): row for row in terminal["files"]}
    if len(rows_by_relative) != 24:
        raise ValueError("R18G terminal file set changed")
    base = project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z"
    base_manifest = base / "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    if sha256_file(base_manifest) != BASE_MANIFEST_SHA256:
        raise ValueError("Base reference manifest changed")
    provider = load_provider(provider_path)
    proposal_root = payload_root / "data/JBOD_PROCESSOR_REVIEW/identity/proposals"
    output_root.mkdir(parents=True)
    result_rows = []

    for identity in DEVELOPMENT:
        case_root = output_root / identity
        case_root.mkdir()
        proposal_relative = f"identity/proposals/{identity}/SCRIBE_PROPOSAL.json"
        bf_relative = f"identity/proposals/{identity}/scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        df_relative = f"identity/proposals/{identity}/scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        proposal_path = proposal_root / identity / "SCRIBE_PROPOSAL.json"
        bf_path = proposal_root / identity / "scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        df_path = proposal_root / identity / "scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        for relative, path in ((proposal_relative, proposal_path), (bf_relative, bf_path), (df_relative, df_path)):
            row = rows_by_relative[relative]
            if path.stat().st_size != int(row["bytes"]) or sha256_file(path) != str(row["sha256"]):
                raise ValueError(f"Returned development source changed: {relative}")
        proposal = read_json(proposal_path)
        if proposal.get("physicalIdentity") != identity:
            raise ValueError(f"Proposal identity changed: {identity}")
        acquisition_id, slot_id = identity.rsplit("_", 1)
        job = {
            "schema": "argos_opencv_scribe_job_v1",
            "revision": "OCV02_R18F_FROZEN_DEVELOPMENT_VALIDATION_20260903B",
            "jobId": f"R18F_DEVELOPMENT_{identity}",
            "createdUtc": "2026-09-03T21:30:00Z",
            "identity": {"physicalIdentity": identity, "acquisitionId": acquisition_id, "lotId": acquisition_id.split("_", 1)[0], "slotId": slot_id},
            "inputMode": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
            "inputQualification": {
                "state": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
                "physicalIdentity": identity,
                "installedReaderState": str(proposal["state"]),
                "proposalPath": str(proposal_path),
                "proposalSha256": rows_by_relative[proposal_relative]["sha256"],
                "multiChannelSummaryPath": str(proposal_path),
                "multiChannelSummarySha256": rows_by_relative[proposal_relative]["sha256"],
                "compatibilityNote": "The signed R18G proposal is exact installed qualification evidence; no identity truth is inferred from its diagnostic string.",
            },
            "inputs": {
                "bf": {"path": str(bf_path), "sha256": rows_by_relative[bf_relative]["sha256"], "bytes": rows_by_relative[bf_relative]["bytes"], "aliasName": "", "canonicalProvenancePath": str(proposal["bfOrientedReviewPath"]), "coordinateFrameId": f"{identity}_INSTALLED_SCRIBE_DETECTOR_INPUT", "ioPathClass": "INSTALLED_HASH_PINNED_REVIEW_ONLY"},
                "df": {"path": str(df_path), "sha256": rows_by_relative[df_relative]["sha256"], "bytes": rows_by_relative[df_relative]["bytes"], "aliasName": "", "canonicalProvenancePath": str(proposal["dfOrientedReviewPath"]), "coordinateFrameId": f"{identity}_INSTALLED_SCRIBE_DETECTOR_INPUT", "ioPathClass": "INSTALLED_HASH_PINNED_REVIEW_ONLY"},
            },
            "references": {
                "manifestPath": str(base_manifest), "manifestSha256": BASE_MANIFEST_SHA256,
                "roots": [{"relativePrefix": "glyphs", "path": str(base / "glyphs")}, {"relativePrefix": "glyphs_v5_confirmed_20260806", "path": str(base / "glyphs_v5_confirmed_20260806")}],
                "supplementalManifestPath": str(supplement_path), "supplementalManifestSha256": SUPPLEMENT_SHA256, "excludedPhysicalIdentity": "",
            },
            "search": {"expectedRegions": [], "orientationStepDegrees": 15, "maximumCandidates": 64, "maximumWorkingDimension": 1600, "boundedExceptionSearch": False},
            "authority": {"reviewOnly": True, "automaticIdentityAuthority": False, "mayClearHolds": False, "trainingEligible": False, "xmlEligible": False, "productionEligible": False},
            "outputRoot": str(case_root),
        }
        job_path = case_root / "SCRIBE_JOB.json"
        result_path = case_root / "R18F_RESULT.json"
        write_json_new(job_path, job)
        provider.run_job(job_path, result_path)
        result = read_json(result_path)
        if result.get("revision") != provider.REVISION:
            raise AssertionError(f"R18F revision mismatch: {identity}")
        first = result.get("hypotheses", [{}])[0] if result.get("hypotheses") else {}
        result_rows.append({
            "physicalIdentity": identity,
            "state": result.get("state", ""),
            "imageFirstString": result.get("imageFirstString", ""),
            "proposedString": result.get("proposedString", ""),
            "selectionScore": first.get("selectionScore"),
            "channel": first.get("channel", ""),
            "direction": first.get("direction", ""),
            "polarity": first.get("polarity", ""),
            "jobSha256": sha256_file(job_path),
            "resultSha256": sha256_file(result_path),
        })
    gate = {
        "schema": "argos_opencv_scribe_r18f_development_output_gate_v1",
        "state": "COMPLETE_R18F_DEVELOPMENT_B_OUTPUTS_FROZEN_UNREVIEWED",
        "providerSha256": PROVIDER_SHA256,
        "r18fLocalGateSha256": R18F_LOCAL_GATE_SHA256,
        "supplementalManifestSha256": SUPPLEMENT_SHA256,
        "terminalResponseGateSha256": TERMINAL_GATE_SHA256,
        "cohortSha256": COHORT_SHA256,
        "developmentAcquisitions": list(DEVELOPMENT),
        "blindAcquisitionsRead": 0,
        "rows": result_rows,
        "visualReviewPerformed": False,
        "visibleTruthUsedForInference": False,
        "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
        "reviewOnly": True,
        "identityAcceptanceAuthorized": False,
        "automaticReferenceAdmissionAuthorized": False,
        "trainingAuthorized": False,
        "activationAuthorized": False,
        "productionAuthorized": False,
    }
    write_json_new(output_root / "R18F_DEVELOPMENT_OUTPUT_GATE_B.json", gate)
    print(json.dumps(gate, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
