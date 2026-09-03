#!/usr/bin/env python3
"""Run one unfinished R18G development case in a fresh local namespace."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path


B_SHA256 = "3D32E23FE501CB8363B2D46D1536967A113D7F74F3C1C33B4BA27AA43D1A0582"
ALLOWED = (
    "62624-855_20260721120719_Slot08",
    "62625-907-POST-20260714155300_20260714155354_Slot22",
)


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--payload-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    parser.add_argument("--identity", required=True, choices=ALLOWED)
    args = parser.parse_args()
    project = args.project.resolve()
    payload_root = args.payload_root.resolve()
    output_root = args.output_root.resolve()
    if output_root.exists():
        raise FileExistsError(output_root)

    b_path = project / "work/OPENCV_SCRIBE_R18G/Run-R18GDevelopmentB.py"
    bootstrap = load_module("argos_r18g_bootstrap", b_path)
    if bootstrap.sha256_file(b_path) != B_SHA256:
        raise ValueError("Frozen R18G bootstrap changed")
    if args.identity not in bootstrap.DEVELOPMENT:
        raise ValueError("Identity is outside frozen development partition")

    provider_path = project / "work/OPENCV_SCRIBE_R18F/ArgosOpenCvScribeV1R18F.py"
    terminal_path = project / "work/OPENCV_SCRIBE_R18G/R18G_TERMINAL_RESPONSE_GATE.json"
    cohort_path = project / "work/OPENCV_SCRIBE_R18G/R18G_COHORT.json"
    supplement_path = project / "work/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    base = project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z"
    base_manifest = base / "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    for path, expected in (
        (provider_path, bootstrap.PROVIDER_SHA256),
        (terminal_path, bootstrap.TERMINAL_GATE_SHA256),
        (cohort_path, bootstrap.COHORT_SHA256),
        (supplement_path, bootstrap.SUPPLEMENT_SHA256),
        (base_manifest, bootstrap.BASE_MANIFEST_SHA256),
    ):
        if bootstrap.sha256_file(path) != expected:
            raise ValueError(f"Frozen dependency changed: {path}")

    terminal = bootstrap.read_json(terminal_path)
    rows = {str(row["relativePath"]): row for row in terminal["files"]}
    identity = args.identity
    proposal_root = payload_root / "data/JBOD_PROCESSOR_REVIEW/identity/proposals"
    proposal_path = proposal_root / identity / "SCRIBE_PROPOSAL.json"
    bf_path = proposal_root / identity / "scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
    df_path = proposal_root / identity / "scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
    rels = {
        "proposal": f"identity/proposals/{identity}/SCRIBE_PROPOSAL.json",
        "bf": f"identity/proposals/{identity}/scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
        "df": f"identity/proposals/{identity}/scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
    }
    for key, path in (("proposal", proposal_path), ("bf", bf_path), ("df", df_path)):
        row = rows[rels[key]]
        if path.stat().st_size != int(row["bytes"]) or bootstrap.sha256_file(path) != str(row["sha256"]):
            raise ValueError(f"Returned development source changed: {rels[key]}")

    proposal = bootstrap.read_json(proposal_path)
    if proposal.get("physicalIdentity") != identity:
        raise ValueError("Proposal identity changed")
    acquisition_id, slot_id = identity.rsplit("_", 1)
    output_root.mkdir(parents=True)
    job = {
        "schema": "argos_opencv_scribe_job_v1", "revision": "OCV02_R18F_R18G_CASE_BOUNDED_20260903",
        "jobId": f"R18F_R18G_REMAINING_{identity}", "createdUtc": "2026-09-03T23:00:00Z",
        "identity": {"physicalIdentity": identity, "acquisitionId": acquisition_id, "lotId": acquisition_id.split("_", 1)[0], "slotId": slot_id},
        "inputMode": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT",
        "inputQualification": {"state": "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT", "physicalIdentity": identity,
            "installedReaderState": str(proposal["state"]), "proposalPath": str(proposal_path), "proposalSha256": rows[rels["proposal"]]["sha256"],
            "multiChannelSummaryPath": str(proposal_path), "multiChannelSummarySha256": rows[rels["proposal"]]["sha256"],
            "compatibilityNote": "Signed R18G proposal is qualification evidence only; no identity truth is inferred."},
        "inputs": {
            "bf": {"path": str(bf_path), "sha256": rows[rels["bf"]]["sha256"], "bytes": rows[rels["bf"]]["bytes"], "aliasName": "", "canonicalProvenancePath": str(proposal["bfOrientedReviewPath"]), "coordinateFrameId": f"{identity}_INSTALLED_SCRIBE_DETECTOR_INPUT", "ioPathClass": "INSTALLED_HASH_PINNED_REVIEW_ONLY"},
            "df": {"path": str(df_path), "sha256": rows[rels["df"]]["sha256"], "bytes": rows[rels["df"]]["bytes"], "aliasName": "", "canonicalProvenancePath": str(proposal["dfOrientedReviewPath"]), "coordinateFrameId": f"{identity}_INSTALLED_SCRIBE_DETECTOR_INPUT", "ioPathClass": "INSTALLED_HASH_PINNED_REVIEW_ONLY"}},
        "references": {"manifestPath": str(base_manifest), "manifestSha256": bootstrap.BASE_MANIFEST_SHA256,
            "roots": [{"relativePrefix": "glyphs", "path": str(base / "glyphs")}, {"relativePrefix": "glyphs_v5_confirmed_20260806", "path": str(base / "glyphs_v5_confirmed_20260806")}],
            "supplementalManifestPath": str(supplement_path), "supplementalManifestSha256": bootstrap.SUPPLEMENT_SHA256, "excludedPhysicalIdentity": ""},
        "search": {"expectedRegions": [], "orientationStepDegrees": 15, "maximumCandidates": 64, "maximumWorkingDimension": 1600, "boundedExceptionSearch": False},
        "authority": {"reviewOnly": True, "automaticIdentityAuthority": False, "mayClearHolds": False, "trainingEligible": False, "xmlEligible": False, "productionEligible": False},
        "outputRoot": str(output_root),
    }
    job_path = output_root / "SCRIBE_JOB.json"
    result_path = output_root / "R18F_RESULT.json"
    bootstrap.write_json_new(job_path, job)
    provider = bootstrap.load_provider(provider_path)
    provider.run_job(job_path, result_path)
    result = bootstrap.read_json(result_path)
    first = result.get("hypotheses", [{}])[0] if result.get("hypotheses") else {}
    gate = {"schema": "argos_opencv_scribe_r18g_case_output_gate_v1", "state": "COMPLETE_R18F_CASE_OUTPUT_FROZEN_UNREVIEWED",
        "physicalIdentity": identity, "providerSha256": bootstrap.PROVIDER_SHA256, "terminalResponseGateSha256": bootstrap.TERMINAL_GATE_SHA256,
        "cohortSha256": bootstrap.COHORT_SHA256, "jobSha256": bootstrap.sha256_file(job_path), "resultSha256": bootstrap.sha256_file(result_path),
        "imageFirstString": result.get("imageFirstString", ""), "proposedString": result.get("proposedString", ""), "selectionScore": first.get("selectionScore"),
        "blindAcquisitionsRead": 0, "visualReviewPerformed": False, "visibleTruthUsedForInference": False, "reviewOnly": True}
    bootstrap.write_json_new(output_root / "R18F_CASE_OUTPUT_GATE.json", gate)
    print(json.dumps(gate, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
