#!/usr/bin/env python3
"""Finish the three R18A blind cases that lack terminal R17E results."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROVIDER_SHA256 = "A2E124FD794C1F97C4C202995DFAB09D4C984862C7E292C1D82034D487A901CA"
TERMINAL_GATE_SHA256 = "326029AFC10633010FA058F63B59D9E37C102B3B2EDEC9C648201C40D67AAB64"
TEMPLATE_JOB_SHA256 = "2474E7C784F3FC2029CB88CE76A724FD9620CEA3E1DF97374EBF4EEAC201A99C"
REMAINING_CASES = (
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
    spec = importlib.util.spec_from_file_location("argos_scribe_r18b_remaining_r17e", path)
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
    parser.add_argument("--template-job", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()

    project = args.project.resolve()
    provider_path = project / "work/OPENCV_SCRIBE_R17E/ArgosOpenCvScribeV1R17E.py"
    gate_path = project / "work/OPENCV_SCRIBE_R18A/R18A_TERMINAL_RESPONSE_GATE_R2.json"
    if sha256_file(provider_path) != PROVIDER_SHA256:
        raise ValueError("Frozen R17E provider SHA-256 mismatch.")
    if sha256_file(gate_path) != TERMINAL_GATE_SHA256:
        raise ValueError("R18A terminal collection gate SHA-256 mismatch.")
    if sha256_file(args.template_job) != TEMPLATE_JOB_SHA256:
        raise ValueError("Preserved R1 template job SHA-256 mismatch.")
    if args.output_root.exists():
        raise FileExistsError(f"Fresh remaining-case root already exists: {args.output_root}")

    gate = json.loads(gate_path.read_text(encoding="utf-8-sig"))
    if gate.get("state") != "PASS_R18A_SIGNED_FRESH_LOT_EXISTING_CROPS_COLLECTED":
        raise ValueError("R18A terminal collection gate is not PASS.")
    evidence = {row["relativePath"]: row for row in gate["files"]}
    source_root = args.source_root.resolve()
    template = json.loads(args.template_job.read_text(encoding="utf-8-sig"))
    provider = load_module(provider_path)
    args.output_root.mkdir(parents=True)
    rows = []

    for case_id in REMAINING_CASES:
        case_root = source_root / "identity/proposals" / case_id
        proposal_path = case_root / "SCRIBE_PROPOSAL.json"
        proposal_rel = f"identity/proposals/{case_id}/SCRIBE_PROPOSAL.json"
        proposal_row = evidence[proposal_rel]
        proposal = json.loads(proposal_path.read_text(encoding="utf-8-sig"))
        if proposal_path.stat().st_size != int(proposal_row["bytes"]) or sha256_file(proposal_path) != proposal_row["sha256"]:
            raise ValueError(f"Collected proposal mismatch: {case_id}")

        job = copy.deepcopy(template)
        acquisition_id, slot_id = case_id.rsplit("_", 1)
        lot_id = acquisition_id.rsplit("_", 1)[0]
        case_output = args.output_root / case_id
        case_output.mkdir()
        job["jobId"] = f"R18B_FROZEN_R17E_REMAINING_{case_id}"
        job["createdUtc"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        job["identity"] = {"lotId": lot_id, "acquisitionId": acquisition_id, "slotId": slot_id, "physicalIdentity": case_id}
        job["inputQualification"].update({
            "physicalIdentity": case_id,
            "proposalPath": str(proposal_path),
            "proposalSha256": proposal_row["sha256"],
            "multiChannelSummaryPath": str(proposal_path),
            "multiChannelSummarySha256": proposal_row["sha256"],
            "installedReaderState": proposal.get("state", ""),
        })
        for channel in ("BF", "DF"):
            relative = f"identity/proposals/{case_id}/scribe/{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
            image_path = source_root / relative
            image_row = evidence[relative]
            if image_path.stat().st_size != int(image_row["bytes"]) or sha256_file(image_path) != image_row["sha256"]:
                raise ValueError(f"Collected source mismatch: {relative}")
            job["inputs"][channel.lower()].update({
                "path": str(image_path),
                "canonicalProvenancePath": proposal[f"{channel.lower()}OrientedReviewPath"],
                "sha256": image_row["sha256"],
                "bytes": image_row["bytes"],
                "coordinateFrameId": f"{case_id}_INSTALLED_SCRIBE_DETECTOR_INPUT",
            })
        job["references"]["excludedPhysicalIdentity"] = case_id
        job["outputRoot"] = str(case_output)
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

    result_gate = {
        "schema": "argos_opencv_scribe_r18b_frozen_r17e_remaining_gate_v1",
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "PASS_FROZEN_R17E_REMAINING_TERMINAL",
        "providerSha256": PROVIDER_SHA256,
        "terminalCollectionGateSha256": TERMINAL_GATE_SHA256,
        "r1IncompleteCaseRepeatedWithoutInspectionOrTuning": REMAINING_CASES[0],
        "r1CompletedCaseExcluded": "62619-451-PRE_20260723105349_Slot05",
        "rows": rows,
        "reviewOnly": True,
        "identityAcceptanceAuthorized": False,
    }
    write_new(args.output_root / "R18B_FROZEN_R17E_REMAINING_GATE.json", result_gate)
    print(json.dumps(result_gate, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
