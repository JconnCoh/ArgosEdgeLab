#!/usr/bin/env python3
"""Run the frozen R17E reader once on the four untouched R18A blind crops."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROVIDER_SHA256 = "A2E124FD794C1F97C4C202995DFAB09D4C984862C7E292C1D82034D487A901CA"
TERMINAL_GATE_SHA256 = "326029AFC10633010FA058F63B59D9E37C102B3B2EDEC9C648201C40D67AAB64"
BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
SUPPLEMENT_MANIFEST_SHA256 = "9F78AD34B8707DBB925AE5D569785FD5F67782B92E9FC35A664CD8887C63BBEC"
BLIND_CASES = (
    "62619-451-PRE_20260723105349_Slot05",
    "62624-855_20260721120719_Slot07",
    "62623-743_20260720111120_Slot04",
    "62618-252_20260715115352_Slot01",
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_module(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("argos_scribe_r18b_frozen_r17e", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load frozen provider: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def write_new(path: Path, value: Any) -> None:
    if path.exists():
        raise FileExistsError(path)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()

    project = args.project.resolve()
    provider_path = project / "work/OPENCV_SCRIBE_R17E/ArgosOpenCvScribeV1R17E.py"
    terminal_gate_path = project / "work/OPENCV_SCRIBE_R18A/R18A_TERMINAL_RESPONSE_GATE_R2.json"
    if sha256_file(provider_path) != PROVIDER_SHA256:
        raise ValueError("Frozen R17E provider SHA-256 mismatch.")
    terminal_gate_sha = sha256_file(terminal_gate_path)
    if terminal_gate_sha != TERMINAL_GATE_SHA256:
        raise ValueError("R18A terminal collection gate SHA-256 mismatch.")
    terminal_gate = json.loads(terminal_gate_path.read_text(encoding="utf-8-sig"))
    if terminal_gate.get("state") != "PASS_R18A_SIGNED_FRESH_LOT_EXISTING_CROPS_COLLECTED":
        raise ValueError("R18A terminal collection gate is not PASS.")
    if args.output_root.exists():
        raise FileExistsError(f"Blind result root already exists: {args.output_root}")

    evidence = {row["relativePath"]: row for row in terminal_gate["files"]}
    source_root = args.source_root.resolve()
    verified: dict[str, dict[str, Any]] = {}
    for case_id in BLIND_CASES:
        for relative in (
            f"identity/proposals/{case_id}/SCRIBE_PROPOSAL.json",
            f"identity/proposals/{case_id}/scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
            f"identity/proposals/{case_id}/scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
        ):
            row = evidence[relative]
            path = source_root / relative
            if path.stat().st_size != int(row["bytes"]) or sha256_file(path) != row["sha256"]:
                raise ValueError(f"Collected source mismatch: {relative}")
            verified[relative] = row

    base_manifest = project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    supplement = project / "work/OPENCV_SCRIBE_R16A_LOCAL_RESULT_R3/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    if sha256_file(base_manifest) != BASE_MANIFEST_SHA256 or sha256_file(supplement) != SUPPLEMENT_MANIFEST_SHA256:
        raise ValueError("Frozen reference manifest SHA-256 mismatch.")

    args.output_root.mkdir(parents=True)
    provider = load_module(provider_path)
    rows = []
    for case_id in BLIND_CASES:
        case_root = source_root / "identity/proposals" / case_id
        proposal_path = case_root / "SCRIBE_PROPOSAL.json"
        proposal = json.loads(proposal_path.read_text(encoding="utf-8-sig"))
        proposal_rel = f"identity/proposals/{case_id}/SCRIBE_PROPOSAL.json"
        image_rows = {
            channel: evidence[f"identity/proposals/{case_id}/scribe/{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"]
            for channel in ("BF", "DF")
        }
        slot_id = case_id.rsplit("_", 1)[1]
        acquisition_id = case_id.rsplit("_", 1)[0]
        lot_id = acquisition_id.rsplit("_", 1)[0]
        case_output = args.output_root / case_id
        case_output.mkdir()
        job = {
            "schema": "argos_opencv_scribe_job_v1",
            "revision": "OCV02_R18B_FROZEN_R17E_BLIND_20260903A",
            "jobId": f"R18B_FROZEN_R17E_{case_id}",
            "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "identity": {"lotId": lot_id, "acquisitionId": acquisition_id, "slotId": slot_id, "physicalIdentity": case_id},
            "inputMode": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
            "inputQualification": {
                "state": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
                "physicalIdentity": case_id,
                "proposalPath": str(proposal_path),
                "proposalSha256": evidence[proposal_rel]["sha256"],
                "multiChannelSummaryPath": str(proposal_path),
                "multiChannelSummarySha256": evidence[proposal_rel]["sha256"],
                "compatibilityNote": "The bounded R18A pull returned the signed proposal as the exact qualification artifact; legacy-required summary fields point to that same verified artifact and do not affect pixels or OCR.",
                "installedReaderState": proposal.get("state", ""),
            },
            "inputs": {
                channel.lower(): {
                    "path": str(case_root / "scribe" / f"{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"),
                    "canonicalProvenancePath": proposal[f"{channel.lower()}OrientedReviewPath"],
                    "ioPathClass": "INSTALLED_HASH_PINNED_REVIEW_ONLY",
                    "aliasName": "",
                    "sha256": image_rows[channel]["sha256"],
                    "bytes": image_rows[channel]["bytes"],
                    "coordinateFrameId": f"{case_id}_INSTALLED_SCRIBE_DETECTOR_INPUT",
                }
                for channel in ("BF", "DF")
            },
            "references": {
                "manifestPath": str(base_manifest),
                "manifestSha256": BASE_MANIFEST_SHA256,
                "supplementalManifestPath": str(supplement),
                "supplementalManifestSha256": SUPPLEMENT_MANIFEST_SHA256,
                "excludedPhysicalIdentity": case_id,
                "roots": [
                    {"relativePrefix": "glyphs", "path": str(base_manifest.parent / "glyphs")},
                    {"relativePrefix": "glyphs_v5_confirmed_20260806", "path": str(base_manifest.parent / "glyphs_v5_confirmed_20260806")},
                ],
            },
            "search": {"expectedRegions": [], "boundedExceptionSearch": False, "maximumWorkingDimension": 1600, "maximumCandidates": 64, "orientationStepDegrees": 15},
            "outputRoot": str(case_output),
            "authority": {"reviewOnly": True, "automaticIdentityAuthority": False, "trainingEligible": False, "xmlEligible": False, "productionEligible": False, "mayClearHolds": False},
        }
        job_path = case_output / "SCRIBE_JOB.json"
        result_path = case_output / "R17E_RESULT.json"
        write_new(job_path, job)
        provider.run_job(job_path, result_path)
        result = json.loads(result_path.read_text(encoding="utf-8-sig"))
        rows.append({
            "physicalIdentity": case_id,
            "state": result["state"],
            "imageFirstString": result["imageFirstString"],
            "proposedString": result["proposedString"],
            "checksumState": result["checksumState"],
            "hypothesisCount": len(result["hypotheses"]),
            "candidateCount": len(result["candidates"]),
            "resultSha256": sha256_file(result_path),
        })

    gate = {
        "schema": "argos_opencv_scribe_r18b_frozen_r17e_blind_gate_v1",
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "PASS_FROZEN_R17E_BLIND_EXECUTED_ONCE",
        "providerSha256": PROVIDER_SHA256,
        "terminalCollectionGateSha256": terminal_gate_sha,
        "blindCaseCount": len(rows),
        "rows": rows,
        "pixelsInspectedBeforeFrozenRun": False,
        "executionCount": 1,
        "reviewOnly": True,
        "identityAcceptanceAuthorized": False,
    }
    write_new(args.output_root / "R18B_FROZEN_R17E_BLIND_GATE.json", gate)
    print(json.dumps(gate, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
