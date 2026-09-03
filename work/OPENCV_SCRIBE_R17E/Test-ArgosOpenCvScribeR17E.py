#!/usr/bin/env python3
"""Local verifier-only checksum contract gate for R17E."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import cv2


BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
SUPPLEMENT_MANIFEST_SHA256 = "9F78AD34B8707DBB925AE5D569785FD5F67782B92E9FC35A664CD8887C63BBEC"
CASES = (
    ("Lot-62546-481-POST2_20260713155808_Slot02", "DF", True, (367, 279, 98, 230), "1878P076FEE6"),
    ("62620-548_20260810154124_Slot01", "BF", False, (351, 193, 100, 230), "L0751043FEC4"),
    ("Lot-62546-481-POST2_20260713155808_Slot20", "DF", True, (362, 274, 98, 230), "8365N004FEC6"),
    ("62627-193_20260820124250_Slot01", "BF", False, (404, 260, 96, 230), "1484P068SUD6"),
    ("62625-956_20260729122701_Slot17", "BF", False, (419, 257, 96, 230), "147JQ121SUE7"),
)
BLANK_CASES = (
    "Lot-62546-481-POST2_20260713155808_Slot18",
    "dev-01-post-8-19_20260819164148_Slot01",
    "Lot-62546-481-POST2_20260713155808_Slot23",
)


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load module: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def load_banks(provider: Any, project: Path) -> tuple[Any, list[Any], list[Any]]:
    r11 = provider.R17D.R17C.R17B._load_r11()
    manifest = project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    roots = {
        "glyphs": manifest.parent / "glyphs",
        "glyphs_v5_confirmed_20260806": manifest.parent / "glyphs_v5_confirmed_20260806",
    }
    prototypes, evidence = r11.load_reference_prototypes(manifest, BASE_MANIFEST_SHA256, roots)
    supplement = project / "work/OPENCV_SCRIBE_R16A_LOCAL_RESULT_R3/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    loader = provider.R17D.R17C.R17B._load_supplement_loader()
    prototypes, _ = loader.combine_reference_prototypes(
        r11, prototypes, evidence, supplement, SUPPLEMENT_MANIFEST_SHA256,
    )
    topology = provider.R17D.load_topology_prototypes(
        r11, manifest, BASE_MANIFEST_SHA256, roots,
        supplement, SUPPLEMENT_MANIFEST_SHA256,
    )
    return r11, prototypes, topology


def exact_crop_gate(
    provider: Any,
    r11: Any,
    prototypes: list[Any],
    topology: list[Any],
    crop_root: Path,
) -> list[dict[str, Any]]:
    rows = []
    for case_id, channel, invert, grid, expected in CASES:
        path = crop_root / case_id / "scribe" / f"{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        gray = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise FileNotFoundError(path)
        if invert:
            gray = 255 - gray
        evaluated = provider.R17D.evaluate_detector_input_hybrid(
            r11, gray, prototypes, topology, "", grid,
        )
        evaluated = provider.enforce_grid_verifier_only(evaluated)
        if evaluated["imageFirstString"] != expected:
            raise AssertionError(f"Image-first OCR changed: {case_id}")
        if evaluated["proposedString"] != expected or evaluated["checksumValid"] is not True:
            raise AssertionError(f"Checksum did not only verify the image-first string: {case_id}")
        if evaluated["checksumUsedForGlyphSelection"] is not False:
            raise AssertionError(f"Checksum glyph-selection contract changed: {case_id}")
        rows.append({
            "caseId": case_id,
            "imageFirstString": evaluated["imageFirstString"],
            "proposedString": evaluated["proposedString"],
            "checksumValid": evaluated["checksumValid"],
        })
    return rows


def invalid_grid_gate(provider: Any) -> dict[str, Any]:
    source = {
        "imageFirstString": "1484B068SUD6",
        "proposedString": "1484P068SUD6",
        "checksumValid": False,
        "checksumAlternatives": [{"string": "1484P068SUD6", "scoreSum": 11.0}],
    }
    result = provider.enforce_grid_verifier_only(source)
    if result["proposedString"] or result["checksumUsedForGlyphSelection"] is not False:
        raise AssertionError("Invalid image-first OCR emitted a corrected proposal.")
    if result["checksumAlternatives"][0].get("diagnosticOnly") is not True:
        raise AssertionError("Checksum alternative was not marked diagnostic-only.")
    return {
        "imageFirstString": result["imageFirstString"],
        "proposedString": result["proposedString"],
        "checksumAlternativeDiagnosticOnly": True,
    }


def result_contract_gate(provider: Any) -> dict[str, Any]:
    invalid = {
        "revision": "PREDECESSOR",
        "state": "SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED",
        "imageFirstString": "1484B068SUD6",
        "proposedString": "1484P068SUD6",
        "checksumState": "SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED",
        "hypotheses": [{
            "imageFirstString": "1484B068SUD6",
            "proposedString": "1484P068SUD6",
            "checksumValid": False,
            "checksumAlternatives": [{"string": "1484P068SUD6", "scoreSum": 11.0}],
            "boundaryComplete": True,
            "channel": "BF",
            "polarity": "DARK",
            "direction": "FORWARD",
            "regionId": "TEST",
            "selectionScore": 0.94,
        }],
        "candidates": [{"string": "1484P068SUD6"}],
        "holds": [{"code": "SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED", "detail": "legacy"}],
        "localization": {"autoLocalizedDevelopmentMode": False},
        "provenance": {},
    }
    provider.enforce_result_verifier_only(invalid)
    if invalid["state"] != provider.INVALID_CHECKSUM_HOLD:
        raise AssertionError("Invalid image-first checksum did not create the exact hold.")
    if invalid["proposedString"] or invalid["candidates"]:
        raise AssertionError("Invalid image-first checksum retained an identity proposal.")
    if invalid["hypotheses"][0]["proposedString"]:
        raise AssertionError("Invalid hypothesis retained a corrected proposal.")
    if any(row["code"] == "SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED" for row in invalid["holds"]):
        raise AssertionError("Legacy checksum-correction hold remained in the result.")

    blank = {
        "revision": "PREDECESSOR",
        "state": "HOLD_SCRIBE_NOT_LOCALIZED",
        "imageFirstString": "",
        "proposedString": "",
        "hypotheses": [],
        "candidates": [],
        "holds": [{"code": "HOLD_SCRIBE_NOT_LOCALIZED", "detail": "test"}],
        "localization": {"autoLocalizedDevelopmentMode": False},
        "provenance": {},
    }
    provider.enforce_result_verifier_only(blank)
    if blank["imageFirstString"] or blank["proposedString"] or blank["candidates"]:
        raise AssertionError("Not-localized result produced a string.")
    if blank["state"] != "HOLD_SCRIBE_NOT_LOCALIZED":
        raise AssertionError("Not-localized state changed.")
    return {
        "invalidImageFirstState": invalid["state"],
        "invalidProposedString": invalid["proposedString"],
        "blankState": blank["state"],
        "blankProducedString": False,
    }


def blank_crop_gate(provider: Any, crop_root: Path) -> list[dict[str, Any]]:
    rows = []
    for case_id in BLANK_CASES:
        root = crop_root / case_id / "scribe"
        bf = cv2.imread(str(root / "BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"), cv2.IMREAD_GRAYSCALE)
        df = cv2.imread(str(root / "DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"), cv2.IMREAD_GRAYSCALE)
        if bf is None or df is None:
            raise FileNotFoundError(root)
        evidence = provider.paired_presence_evidence(bf, df)
        if evidence["decision"] != "HOLD_SCRIBE_NOT_LOCALIZED":
            raise AssertionError(f"Blank/wrong-location crop reached OCR: {case_id}")
        rows.append({
            "caseId": case_id,
            "decision": evidence["decision"],
            "imageFirstString": "",
            "proposedString": "",
        })
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", required=True, type=Path)
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--crop-root", required=True, type=Path)
    arguments = parser.parse_args()
    provider = load_module("argos_scribe_r17e_test_target", arguments.provider)
    r11, prototypes, topology = load_banks(provider, arguments.project)
    print(json.dumps({
        "state": "PASS_R17E_LOCAL",
        "exactCrops": exact_crop_gate(
            provider, r11, prototypes, topology, arguments.crop_root,
        ),
        "invalidGrid": invalid_grid_gate(provider),
        "resultContract": result_contract_gate(provider),
        "blankCrops": blank_crop_gate(provider, arguments.crop_root),
        "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
