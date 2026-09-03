#!/usr/bin/env python3
"""Fast frozen-grid and leave-one-identity-out gate for R18H."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np


BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
SUPPLEMENT_SHA256 = "FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114"
R18F_PROVIDER_SHA256 = "0E2CD994BB389F1DB5A50FCB2C5C9D0DD6C906925E206C913CB0FCEC1B1543B1"

OLDER_VISIBLE = (
    ("Lot-62546-481-POST2_20260713155808_Slot02", "DF", True, (367, 279, 98, 230), "1878P076FEE6"),
    ("62620-548_20260810154124_Slot01", "BF", False, (351, 193, 100, 230), "L0751043FEC4"),
    ("Lot-62546-481-POST2_20260713155808_Slot20", "DF", True, (362, 274, 98, 230), "8365N004FEC6"),
    ("62627-193_20260820124250_Slot01", "BF", False, (404, 260, 96, 230), "1484P068SUD6"),
    ("62625-956_20260729122701_Slot17", "BF", False, (419, 257, 96, 230), "147JQ121SUE7"),
)
OBSERVED = (
    (Path(r"C:\P2COHORT\results\R18C_DEVELOPMENT_GATE_20260903A\62625-957_20260729124737_Slot24\R18C_RESULT.json"), "1484P102SUC0"),
    (Path(r"C:\P2COHORT\results\R18A_FROZEN_R17E_BLIND_20260903A\62619-451-PRE_20260723105349_Slot05\R17E_RESULT.json"), "9508R043FED4"),
    (Path(r"C:\P2COHORT\results\R18A_FROZEN_R17E_BLIND_20260903A\62624-855_20260721120719_Slot07\R17E_RESULT.json"), "1478T158SUC5"),
    (Path(r"C:\P2COHORT\results\R18A_FROZEN_R17E_BLIND_20260903A\62618-252_20260715115352_Slot01\R17E_RESULT.json"), "146J7043SUE2"),
)
R18G_VISIBLE = (
    ("62620-548_20260810154124_Slot05", (361, 225, 98, 230), "L0751037FEA2"),
    ("62624-855_20260721120719_Slot08", (393, 273, 98, 230), "1478T161SUG7"),
    ("62625-907-POST-20260714155300_20260714155354_Slot22", (409, 290, 96, 230), "146XF113SUA5"),
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
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


def check_visible(provider: Any, r11: Any, prototypes: list[Any], topology: list[Any], structure: list[Any], gray: np.ndarray, grid: tuple[int, int, int, int], expected: str, identity: str) -> dict[str, Any]:
    checked = provider.evaluate_detector_input_structural(
        r11, gray, prototypes, topology, structure, "", grid,
    )
    checked = provider.R17E.enforce_grid_verifier_only(checked)
    if checked["imageFirstString"] != expected or checked["proposedString"] != expected:
        raise AssertionError(
            f"Frozen-grid result changed: {identity}: "
            f"{checked['imageFirstString']} / {checked['proposedString']} != {expected}"
        )
    if float(checked["selectionScore"]) < provider.MINIMUM_POST_GRID_IMAGE_SCORE:
        raise AssertionError(f"Frozen-grid result fell below presence floor: {identity}")
    applied = [
        {
            "position": row["position"],
            "appearanceFirst": row["glyphArbitration"]["appearanceFirst"],
            "appearanceGap": row["glyphArbitration"]["appearanceGap"],
            "runStructureFirst": row["glyphArbitration"]["runStructureFirst"],
            "runStructureFirstDistance": row["glyphArbitration"]["runStructureFirstDistance"],
            "runStructureMargin": row["glyphArbitration"]["runStructureMargin"],
        }
        for row in checked["positions"]
        if row["glyphArbitration"].get("runStructureApplied")
    ]
    return {
        "physicalIdentity": identity,
        "expectedString": expected,
        "imageFirstString": checked["imageFirstString"],
        "proposedString": checked["proposedString"],
        "selectionScore": checked["selectionScore"],
        "runStructurePositions": [row["position"] for row in applied],
        "runStructureArbitration": applied,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise FileExistsError(args.output)
    project = args.project.resolve()
    provider_path = project / "work/OPENCV_SCRIBE_R18H/ArgosOpenCvScribeV1R18H.py"
    r18f_path = project / "work/OPENCV_SCRIBE_R18F/ArgosOpenCvScribeV1R18F.py"
    supplement = project / "work/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    if sha256_file(r18f_path) != R18F_PROVIDER_SHA256 or sha256_file(supplement) != SUPPLEMENT_SHA256:
        raise ValueError("Frozen R18F dependency changed.")
    provider = load("argos_scribe_r18h_test", provider_path)
    r11 = provider.R17D.R17C.R17B._load_r11()
    manifest = project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    roots = {
        "glyphs": manifest.parent / "glyphs",
        "glyphs_v5_confirmed_20260806": manifest.parent / "glyphs_v5_confirmed_20260806",
    }
    prototypes, evidence = r11.load_reference_prototypes(manifest, BASE_MANIFEST_SHA256, roots)
    prototypes, _ = provider.R18F.R18F_LOADER.combine_reference_prototypes(
        r11, prototypes, evidence, supplement, SUPPLEMENT_SHA256,
    )
    topology = provider.R17D.load_topology_prototypes(
        r11, manifest, BASE_MANIFEST_SHA256, roots, supplement, SUPPLEMENT_SHA256,
    )
    structure = provider.load_run_structure_prototypes(
        r11, manifest, BASE_MANIFEST_SHA256, roots, supplement, SUPPLEMENT_SHA256,
    )
    keys = [(row.label, row.physical_identity) for row in prototypes]
    if keys != [(row.label, row.physical_identity) for row in topology] or keys != [
        (row.label, row.physical_identity) for row in structure
    ]:
        raise AssertionError("Reference banks are not aligned.")

    baseline_correct = 0
    successor_correct = 0
    changed: list[dict[str, Any]] = []
    harmed: list[dict[str, Any]] = []
    for index, query in enumerate(prototypes):
        excluded = query.physical_identity.casefold()
        active_indices = [
            row_index for row_index, row in enumerate(prototypes)
            if not excluded or row.physical_identity.casefold() != excluded
        ]
        active_appearance = [prototypes[row_index] for row_index in active_indices]
        active_topology = [topology[row_index] for row_index in active_indices]
        active_structure = [structure[row_index] for row_index in active_indices]
        appearance_bank = r11.PrototypeBank.from_prototypes(active_appearance)
        topology_matrix = np.vstack([row.descriptor.astype(np.float64) for row in active_topology])
        topology_indices = provider.R17D._label_indices(np.asarray([row.label for row in active_topology]))
        run_scaling, run_consensus = provider._run_structure_context(active_structure)
        baseline, _ = provider.R17D.rank_hybrid(
            r11, query.descriptor, topology[index].descriptor, appearance_bank,
            topology_matrix, topology_indices, 0,
        )
        successor, arbitration = provider.rank_with_run_structure(
            r11, query.descriptor, topology[index].descriptor, structure[index].descriptor,
            appearance_bank, topology_matrix, topology_indices, run_scaling, run_consensus, 0,
        )
        before = str(baseline[0]["character"])
        after = str(successor[0]["character"])
        baseline_correct += int(before == query.label)
        successor_correct += int(after == query.label)
        if float(successor[0]["score"]) > float(baseline[0]["score"]) + 1e-12:
            raise AssertionError("Run-structure arbitration increased a selected appearance score.")
        if before != after:
            row = {
                "referenceIndex": index, "truth": query.label, "before": before, "after": after,
                "appearanceGap": arbitration["appearanceGap"],
                "runStructureMargin": arbitration["runStructureMargin"],
            }
            changed.append(row)
            if before == query.label and after != query.label:
                harmed.append(row)
    if harmed:
        raise AssertionError(f"R18H harmed leave-one-identity-out references: {harmed}")

    visible: list[dict[str, Any]] = []
    old_root = Path(r"C:\R17A2\data\JBOD_PROCESSOR_REVIEW\identity\proposals")
    for identity, channel, invert, grid, expected in OLDER_VISIBLE:
        source = old_root / identity / "scribe" / f"{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise FileNotFoundError(source)
        visible.append(check_visible(provider, r11, prototypes, topology, structure, 255 - gray if invert else gray, grid, expected, identity))
    for result_path, expected in OBSERVED:
        frozen = json.loads(result_path.read_text(encoding="utf-8-sig"))
        selected = frozen["hypotheses"][0]
        channel = str(selected["channel"])
        source = Path(str(frozen["provenance"]["sources"][channel.lower()]["path"]))
        gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise FileNotFoundError(source)
        if selected["polarity"] == "BRIGHT":
            gray = 255 - gray
        if selected["direction"] == "REVERSE_180":
            gray = cv2.rotate(gray, cv2.ROTATE_180)
        grid = (selected["x"], selected["y"], selected["cellWidth"], selected["cellHeight"])
        visible.append(check_visible(provider, r11, prototypes, topology, structure, gray, grid, expected, result_path.parent.name))

    r18g: list[dict[str, Any]] = []
    r18g_root = Path(r"C:\R18G\data\JBOD_PROCESSOR_REVIEW\identity\proposals")
    for identity, grid, expected in R18G_VISIBLE:
        source = r18g_root / identity / "scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise FileNotFoundError(source)
        r18g.append(check_visible(provider, r11, prototypes, topology, structure, gray, grid, expected, identity))
    target = next(row for row in r18g if row["physicalIdentity"].endswith("Slot08"))
    if target["runStructurePositions"] != [5]:
        raise AssertionError(f"Slot08 was not corrected image-first at position 5: {target}")

    gate = {
        "schema": "argos_opencv_scribe_r18h_fast_gate_v1",
        "state": "PASS_R18H_GENERIC_RUN_STRUCTURE_ROOT_FIX",
        "providerSha256": sha256_file(provider_path),
        "r18fProviderSha256": R18F_PROVIDER_SHA256,
        "baseManifestSha256": BASE_MANIFEST_SHA256,
        "supplementalManifestSha256": SUPPLEMENT_SHA256,
        "referenceCount": len(prototypes),
        "leaveOneIdentityOut": {
            "r18fCorrect": baseline_correct,
            "r18hCorrect": successor_correct,
            "changedCount": len(changed),
            "harmedPreviouslyCorrectCount": len(harmed),
            "changes": changed,
        },
        "frozenVisibleRegression": visible,
        "frozenVisibleExactCount": len(visible),
        "r18gDevelopment": r18g,
        "r18gExactCount": len(r18g),
        "blankHoldPreservation": {
            "method": "SELECTED_SCORE_NONINCREASE_INVARIANT",
            "detail": "The tie-break can retain the existing winner or select only the other appearance-top-two label while preserving its lower appearance score; it cannot raise a grid or blank presence score.",
        },
        "rootCause": "A maximum single appearance exemplar is outlier-sensitive for sparse and visually similar classes.",
        "correctionScope": "ALL_BODY_LABELS_GENERIC_RUN_STRUCTURE_CONSENSUS",
        "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
        "reviewOnly": True,
        "activationAuthorized": False,
        "productionAuthorized": False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(gate, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "state": gate["state"], "referenceCount": len(prototypes),
        "r18fCorrect": baseline_correct, "r18hCorrect": successor_correct,
        "changed": len(changed), "harmed": len(harmed),
        "visibleExact": len(visible), "r18gExact": len(r18g),
        "gateSha256": sha256_file(args.output),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
