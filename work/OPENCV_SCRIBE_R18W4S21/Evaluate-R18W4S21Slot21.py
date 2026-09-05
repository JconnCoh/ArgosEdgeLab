#!/usr/bin/env python3
"""Evaluate authenticated current Slot21 BF/DF with the frozen R18Z provider."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

PROVIDER_SHA256 = "54BB0152420B5F197C1F0B353AEDF021185BBBA2EBD415B05320CFF92DD02DA2"
BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
SUPPLEMENTAL_MANIFEST_SHA256 = "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD"
CROSSWALK_SHA256 = "84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2"
LOO_GATE_SHA256 = "D8F0C0923BFDD6B82C4B0B0C57142825C08C0DB3F5395210A5DD7FE2E6E8DAD8"
BF_SHA256 = "96046D91BBD6DF81E678224525560BD9C77C0DC09DD89A25992B07F8D1213B93"
DF_SHA256 = "8DFD50AE1E0958CE01D7E32E0936978F157C2FECD0CB910BCC27DF9F7CE63CB8"
PHYSICAL_IDENTITY = "62546-481_20260707164232_Slot21"
TRUTH = "13HFX135SUE3"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def require_pin(path: Path, expected: str) -> None:
    if not path.is_file() or sha256_file(path) != expected:
        raise ValueError(f"Pinned dependency changed: {path}")


def summarize(channel: str, source: Path, evaluated: dict[str, Any]) -> dict[str, Any]:
    envelope = evaluated.get("ocrEnvelope", {})
    image_first = evaluated.get("imageFirstString")
    if not isinstance(image_first, str) or len(image_first) != 12:
        raise ValueError(f"{channel} did not produce a 12-character image-first string.")
    if len(evaluated.get("positions", [])) != 12:
        raise ValueError(f"{channel} did not produce 12 position rows.")
    if envelope.get("schema") != "argos_opencv_scribe_glyph_envelope_evidence_v1":
        raise ValueError(f"{channel} envelope schema changed.")
    if envelope.get("checksumUsed") is not False:
        raise ValueError(f"{channel} used checksum during selection.")
    ranking = evaluated.get("glyphRanking", {})
    if ranking.get("checksumUsedForImageFirst") is not False:
        raise ValueError(f"{channel} ranking used checksum during selection.")
    held = [
        {
            "position": int(row.get("position")),
            "diagnosticLabel": str(row.get("diagnosticLabel")),
            "decision": str(row.get("decision")),
        }
        for row in envelope.get("positions", [])
        if str(row.get("decision", "")).startswith("HOLD_")
    ]
    return {
        "channel": channel,
        "sourcePath": str(source),
        "sourceBytes": source.stat().st_size,
        "sourceSha256": sha256_file(source),
        "imageFirstString": image_first,
        "truthComparedOnlyAfterSelection": TRUTH,
        "imageFirstCorrect": image_first == TRUTH,
        "envelopePassed": bool(envelope.get("passed")),
        "envelopeDecision": envelope.get("decision"),
        "heldPositions": held,
        "acceptedWrong": bool(envelope.get("passed")) and image_first != TRUTH,
        "positions": evaluated.get("positions"),
        "glyphRanking": ranking,
        "ocrEnvelope": envelope,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--bf", required=True, type=Path)
    parser.add_argument("--df", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()

    project = args.project.resolve()
    bf = args.bf.resolve()
    df = args.df.resolve()
    output_root = args.output_root.resolve()
    provider_path = project / "work/OPENCV_SCRIBE_R18Z/ArgosOpenCvScribeV1R18Z.py"
    base_manifest = project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    supplemental = project / "work/OPENCV_SCRIBE_R18Z/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    crosswalk = project / "work/OPENCV_SCRIBE_R18Z/reference_bank/R18Z_EXACT_SCRIBE_LINEAGE_CROSSWALK.json"
    loo_gate = project / "work/OPENCV_SCRIBE_R18Z/evidence/R18Z_EXACT_LINEAGE_LOO_GATE.json"
    require_pin(provider_path, PROVIDER_SHA256)
    require_pin(base_manifest, BASE_MANIFEST_SHA256)
    require_pin(supplemental, SUPPLEMENTAL_MANIFEST_SHA256)
    require_pin(crosswalk, CROSSWALK_SHA256)
    require_pin(loo_gate, LOO_GATE_SHA256)
    require_pin(bf, BF_SHA256)
    require_pin(df, DF_SHA256)
    if output_root.exists() or not output_root.parent.is_dir():
        raise FileExistsError(f"Fresh output root required: {output_root}")

    provider = load("argos_r18w4s21_slot21_provider", provider_path)
    provider.R18ZV._validate_loo_gate(loo_gate, LOO_GATE_SHA256)
    mapping, _ = provider.load_lineage_mapping(crosswalk, CROSSWALK_SHA256)
    if provider.map_excluded_identity(PHYSICAL_IDENTITY, mapping) != PHYSICAL_IDENTITY:
        raise ValueError("Current Slot21 was aliased to a reference lineage.")
    r11 = provider.R17D.R17C.R17B._load_r11()
    roots = {
        "glyphs": base_manifest.parent / "glyphs",
        "glyphs_v5_confirmed_20260806": base_manifest.parent / "glyphs_v5_confirmed_20260806",
    }
    base_appearance, base_evidence = r11.load_reference_prototypes(
        base_manifest, BASE_MANIFEST_SHA256, roots
    )
    appearance, _ = provider.R18F.R18F_LOADER.combine_reference_prototypes(
        r11, base_appearance, base_evidence, supplemental, SUPPLEMENTAL_MANIFEST_SHA256
    )
    topology = provider.R17D.load_topology_prototypes(
        r11, base_manifest, BASE_MANIFEST_SHA256, roots, supplemental, SUPPLEMENTAL_MANIFEST_SHA256
    )
    run_structure = provider.load_run_structure_prototypes(
        r11, base_manifest, BASE_MANIFEST_SHA256, roots, supplemental, SUPPLEMENTAL_MANIFEST_SHA256
    )
    provider.assert_aligned_reference_banks(appearance, topology, run_structure)
    if len(appearance) != 475 or len(topology) != 475 or len(run_structure) != 475:
        raise ValueError("R18Z reference-bank cardinality changed.")

    results = []
    for channel, source in (("BF", bf), ("DF", df)):
        gray = r11.decode_gray_exact(source)
        evaluated = provider.evaluate_detector_input_structural(
            r11, gray, appearance, topology, run_structure, PHYSICAL_IDENTITY
        )
        results.append(summarize(channel, source, evaluated))
    if any(row["acceptedWrong"] for row in results):
        raise ValueError("R18Z accepted a wrong Slot21 image-first string.")

    payload = {
        "schema": "argos_opencv_scribe_r18w4s21_slot21_evaluation_v1",
        "state": "PASS_R18W4S21_SLOT21_R18Z_IMAGE_FIRST_EVALUATION",
        "disposition": "DIAGNOSTIC_ONLY",
        "physicalIdentity": PHYSICAL_IDENTITY,
        "truthComparedOnlyAfterSelection": TRUTH,
        "referenceCount": 475,
        "exactLineageFoldCount": 49,
        "channels": results,
        "identityAccepted": False,
        "referenceAdmissionPerformed": False,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    output_root.mkdir()
    output_path = output_root / "R18W4S21_SLOT21_R18Z_EVALUATION.json"
    with output_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(payload, stream, indent=2, sort_keys=True)
        stream.write("\n")
    print(json.dumps({"state": payload["state"], "output": str(output_path), "sha256": sha256_file(output_path), "channels": [{"channel": r["channel"], "imageFirstString": r["imageFirstString"], "imageFirstCorrect": r["imageFirstCorrect"], "envelopePassed": r["envelopePassed"], "envelopeDecision": r["envelopeDecision"], "heldPositions": r["heldPositions"]} for r in results]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
