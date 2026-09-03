#!/usr/bin/env python3
"""Local reference, crop, and presence regression gate for R17D."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np


BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
SUPPLEMENT_MANIFEST_SHA256 = "9F78AD34B8707DBB925AE5D569785FD5F67782B92E9FC35A664CD8887C63BBEC"
CROP_CASES = (
    (
        "Lot-62546-481-POST2_20260713155808_Slot20", "DF", True,
        (362, 274, 98, 230), "8365N004FEC6",
    ),
    (
        "62627-193_20260820124250_Slot01", "BF", False,
        (404, 260, 96, 230), "1484P068SUD6",
    ),
    (
        "62625-956_20260729122701_Slot17", "BF", False,
        (419, 257, 96, 230), "147JQ121SUE7",
    ),
)
PRESENCE_EXPECTED = {
    "Lot-62546-481-POST2_20260713155808_Slot02": "SCRIBE_PRESENT_FOR_OCR",
    "Lot-62546-481-POST2_20260713155808_Slot18": "HOLD_SCRIBE_NOT_LOCALIZED",
    "62620-548_20260810154124_Slot01": "SCRIBE_PRESENT_FOR_OCR",
    "dev-01-post-8-19_20260819164148_Slot01": "HOLD_SCRIBE_NOT_LOCALIZED",
    "Lot-62546-481-POST2_20260713155808_Slot20": "SCRIBE_PRESENT_FOR_OCR",
    "Lot-62546-481-POST2_20260713155808_Slot23": "HOLD_SCRIBE_NOT_LOCALIZED",
    "62627-193_20260820124250_Slot01": "SCRIBE_PRESENT_FOR_OCR",
    "62625-956_20260729122701_Slot17": "SCRIBE_PRESENT_FOR_OCR",
}


def load_provider(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("argos_scribe_r17d_test_target", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load provider: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def load_banks(provider: Any, project: Path) -> tuple[Any, list[Any], list[Any]]:
    r11 = provider.R17C.R17B._load_r11()
    manifest = project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    roots = {
        "glyphs": manifest.parent / "glyphs",
        "glyphs_v5_confirmed_20260806": manifest.parent / "glyphs_v5_confirmed_20260806",
    }
    prototypes, evidence = r11.load_reference_prototypes(
        manifest, BASE_MANIFEST_SHA256, roots,
    )
    supplement = project / "work/OPENCV_SCRIBE_R16A_LOCAL_RESULT_R3/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    loader = provider.R17C.R17B._load_supplement_loader()
    prototypes, _ = loader.combine_reference_prototypes(
        r11, prototypes, evidence, supplement, SUPPLEMENT_MANIFEST_SHA256,
    )
    topology = provider.load_topology_prototypes(
        r11, manifest, BASE_MANIFEST_SHA256, roots,
        supplement, SUPPLEMENT_MANIFEST_SHA256,
    )
    if [(row.label, row.physical_identity) for row in prototypes] != [
        (row.label, row.physical_identity) for row in topology
    ]:
        raise AssertionError("Appearance and topology reference order differs.")
    return r11, prototypes, topology


def reference_gate(provider: Any, r11: Any, prototypes: list[Any], topology: list[Any]) -> dict[str, int]:
    baseline_correct = 0
    r17d_correct = 0
    changed = 0
    helped = 0
    hurt = 0
    for index, query in enumerate(prototypes[:456]):
        active_indices = [
            row_index for row_index, row in enumerate(prototypes)
            if row_index != index and row.physical_identity.casefold() != query.physical_identity.casefold()
        ]
        active = [prototypes[row_index] for row_index in active_indices]
        active_topology = [topology[row_index] for row_index in active_indices]
        appearance_bank = r11.PrototypeBank.from_prototypes(active)
        topology_matrix = np.vstack([row.descriptor.astype(np.float64) for row in active_topology])
        topology_indices = provider._label_indices(np.asarray([row.label for row in active_topology]))
        baseline = r11.rank_descriptor(query.descriptor, appearance_bank, 0)[0]["character"]
        ranked, _ = provider.rank_hybrid(
            r11, query.descriptor, topology[index].descriptor,
            appearance_bank, topology_matrix, topology_indices, 0,
        )
        actual = ranked[0]["character"]
        baseline_correct += baseline == query.label
        r17d_correct += actual == query.label
        changed += actual != baseline
        helped += actual == query.label and baseline != query.label
        hurt += actual != query.label and baseline == query.label
    if (baseline_correct, r17d_correct, changed, helped, hurt) != (375, 382, 9, 7, 0):
        raise AssertionError(
            "Reference arbitration changed: "
            f"{baseline_correct}, {r17d_correct}, {changed}, {helped}, {hurt}"
        )
    return {
        "referenceCount": 456,
        "baselineCorrect": baseline_correct,
        "r17dCorrect": r17d_correct,
        "changed": changed,
        "helped": helped,
        "hurt": hurt,
    }


def crop_gate(
    provider: Any,
    r11: Any,
    prototypes: list[Any],
    topology: list[Any],
    crop_root: Path,
) -> list[dict[str, Any]]:
    rows = []
    for case_id, channel, invert, grid, expected in CROP_CASES:
        path = crop_root / case_id / "scribe" / f"{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        gray = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise FileNotFoundError(path)
        if invert:
            gray = 255 - gray
        result = provider.evaluate_detector_input_hybrid(
            r11, gray, prototypes, topology, "", grid,
        )
        if result["imageFirstString"] != expected:
            raise AssertionError(f"Image-first OCR changed: {case_id}: {result['imageFirstString']} != {expected}")
        if result["proposedString"] != expected or result["checksumValid"] is not True:
            raise AssertionError(f"Checksum did not verify image-first OCR: {case_id}")
        overrides = [
            row["position"] for row in result["positions"]
            if bool(row["glyphArbitration"]["overrideApplied"])
        ]
        if case_id == "62627-193_20260820124250_Slot01" and overrides != [5]:
            raise AssertionError(f"Slot01 topology arbitration changed: {overrides}")
        if case_id != "62627-193_20260820124250_Slot01" and overrides:
            raise AssertionError(f"Unexpected topology arbitration: {case_id}: {overrides}")
        rows.append({
            "caseId": case_id,
            "imageFirstString": result["imageFirstString"],
            "checksumValid": result["checksumValid"],
            "topologyOverridePositions": overrides,
        })
    return rows


def presence_gate(provider: Any, crop_root: Path) -> list[dict[str, str]]:
    rows = []
    for case_id, expected in PRESENCE_EXPECTED.items():
        root = crop_root / case_id / "scribe"
        bf = cv2.imread(str(root / "BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"), cv2.IMREAD_GRAYSCALE)
        df = cv2.imread(str(root / "DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"), cv2.IMREAD_GRAYSCALE)
        if bf is None or df is None:
            raise FileNotFoundError(root)
        actual = str(provider.paired_presence_evidence(bf, df)["decision"])
        if actual != expected:
            raise AssertionError(f"Presence decision changed: {case_id}: {actual} != {expected}")
        rows.append({"caseId": case_id, "decision": actual})
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", required=True, type=Path)
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--crop-root", required=True, type=Path)
    arguments = parser.parse_args()
    provider = load_provider(arguments.provider)
    r11, prototypes, topology = load_banks(provider, arguments.project)
    result = {
        "state": "PASS_R17D_LOCAL",
        "referenceArbitration": reference_gate(provider, r11, prototypes, topology),
        "cropOcr": crop_gate(provider, r11, prototypes, topology, arguments.crop_root),
        "presence": presence_gate(provider, arguments.crop_root),
        "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
    }
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
