#!/usr/bin/env python3
"""Run frozen R18D on only the four frozen R18E development acquisitions."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


DEVELOPMENT = (
    "62633-726_20260818204139_Slot20",
    "62546-481-POST_20260713041740_Slot22",
    "62625-907-PRE_20260709123021_Slot14",
    "62627-098_20260729105955_Slot16",
)
PROVIDER_SHA256 = "39E44AE48A76DA0BDF25490BD3EFE49EC98770B0B10BE6DF0FF57373951B95A1"
R18D_GATE_SHA256 = "0E3D94DBA81B37C83667FE7AE61E17D06476DDC4B466F86C58502EA52471609D"
SUPPLEMENT_SHA256 = "8B7F0BAC5892DA7BBB4D25CDD058CC995042A0C596F3790FE333AAAEEE43D60A"
TERMINAL_GATE_SHA256 = "9AD57983849DCBF7AAA3B021A9E5045C421456664A6A86E03EDE90AD6465B140"
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
    spec = importlib.util.spec_from_file_location("argos_scribe_r18d_r18e_development", path)
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

    provider_path = project / "work/OPENCV_SCRIBE_R18D/ArgosOpenCvScribeV1R18D.py"
    r18d_gate_path = project / "work/OPENCV_SCRIBE_R18D/R18D_LOCAL_GATE.json"
    supplement_path = project / "work/OPENCV_SCRIBE_R18D/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    terminal_gate_path = project / "work/OPENCV_SCRIBE_R18E/R18E_TERMINAL_RESPONSE_GATE.json"
    pins = (
        (provider_path, PROVIDER_SHA256),
        (r18d_gate_path, R18D_GATE_SHA256),
        (supplement_path, SUPPLEMENT_SHA256),
        (terminal_gate_path, TERMINAL_GATE_SHA256),
    )
    for path, expected in pins:
        if sha256_file(path) != expected:
            raise ValueError(f"Frozen dependency changed: {path}")

    terminal = read_json(terminal_gate_path)
    if terminal.get("state") != "PASS_R18E_SIGNED_FRESH_LOT_EXISTING_CROPS_COLLECTED":
        raise ValueError("R18E terminal collection gate changed")
    rows_by_relative = {str(row["relativePath"]): row for row in terminal["files"]}
    if len(rows_by_relative) != 24:
        raise ValueError("R18E terminal file set changed")

    base = project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z"
    base_manifest = base / "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    if sha256_file(base_manifest) != BASE_MANIFEST_SHA256:
        raise ValueError("Base reference manifest changed")
    provider = load_provider(provider_path)
    proposal_root = payload_root / "data/JBOD_PROCESSOR_REVIEW/identity/proposals"
    output_root.mkdir(parents=True)
    result_rows: list[dict[str, Any]] = []

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
            "revision": "OCV02_R18E_FROZEN_R18D_DEVELOPMENT_20260903A",
            "jobId": f"R18E_R18D_DEVELOPMENT_{identity}",
            "createdUtc": "2026-09-03T20:00:00Z",
            "identity": {
                "physicalIdentity": identity,
                "acquisitionId": acquisition_id,
                "lotId": acquisition_id.split("_", 1)[0],
                "slotId": slot_id,
            },
            "inputMode": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
            "inputQualification": {
                "state": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
                "physicalIdentity": identity,
                "installedReaderState": str(proposal["state"]),
                "proposalPath": str(proposal_path),
                "proposalSha256": rows_by_relative[proposal_relative]["sha256"],
                "multiChannelSummaryPath": str(proposal_path),
                "multiChannelSummarySha256": rows_by_relative[proposal_relative]["sha256"],
                "compatibilityNote": "The signed R18E proposal is the exact installed qualification artifact; no identity truth is inferred from its diagnostic string.",
            },
            "inputs": {
                "bf": {
                    "path": str(bf_path), "sha256": rows_by_relative[bf_relative]["sha256"],
                    "bytes": rows_by_relative[bf_relative]["bytes"], "aliasName": "",
                    "canonicalProvenancePath": str(proposal["bfOrientedReviewPath"]),
                    "coordinateFrameId": f"{identity}_INSTALLED_SCRIBE_DETECTOR_INPUT",
                    "ioPathClass": "INSTALLED_HASH_PINNED_REVIEW_ONLY",
                },
                "df": {
                    "path": str(df_path), "sha256": rows_by_relative[df_relative]["sha256"],
                    "bytes": rows_by_relative[df_relative]["bytes"], "aliasName": "",
                    "canonicalProvenancePath": str(proposal["dfOrientedReviewPath"]),
                    "coordinateFrameId": f"{identity}_INSTALLED_SCRIBE_DETECTOR_INPUT",
                    "ioPathClass": "INSTALLED_HASH_PINNED_REVIEW_ONLY",
                },
            },
            "references": {
                "manifestPath": str(base_manifest), "manifestSha256": BASE_MANIFEST_SHA256,
                "roots": [
                    {"relativePrefix": "glyphs", "path": str(base / "glyphs")},
                    {"relativePrefix": "glyphs_v5_confirmed_20260806", "path": str(base / "glyphs_v5_confirmed_20260806")},
                ],
                "supplementalManifestPath": str(supplement_path),
                "supplementalManifestSha256": SUPPLEMENT_SHA256,
                "excludedPhysicalIdentity": "",
            },
            "search": {"expectedRegions": [], "orientationStepDegrees": 15, "maximumCandidates": 64, "maximumWorkingDimension": 1600, "boundedExceptionSearch": False},
            "authority": {"reviewOnly": True, "automaticIdentityAuthority": False, "mayClearHolds": False, "trainingEligible": False, "xmlEligible": False, "productionEligible": False},
            "outputRoot": str(case_root),
        }
        job_path = case_root / "SCRIBE_JOB.json"
        result_path = case_root / "R18D_RESULT.json"
        write_json_new(job_path, job)
        provider.run_job(job_path, result_path)
        result = read_json(result_path)
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
        "schema": "argos_opencv_scribe_r18e_r18d_development_gate_v1",
        "state": "COMPLETE_R18E_R18D_DEVELOPMENT_OUTPUTS_FROZEN",
        "providerSha256": PROVIDER_SHA256,
        "r18dLocalGateSha256": R18D_GATE_SHA256,
        "supplementalManifestSha256": SUPPLEMENT_SHA256,
        "terminalResponseGateSha256": TERMINAL_GATE_SHA256,
        "developmentAcquisitions": list(DEVELOPMENT),
        "blindAcquisitionsRead": 0,
        "rows": result_rows,
        "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
        "reviewOnly": True,
        "identityAcceptanceAuthorized": False,
        "automaticReferenceAdmissionAuthorized": False,
        "trainingAuthorized": False,
        "productionEligible": False,
    }
    write_json_new(output_root / "R18E_R18D_DEVELOPMENT_GATE.json", gate)
    print(json.dumps(gate, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
