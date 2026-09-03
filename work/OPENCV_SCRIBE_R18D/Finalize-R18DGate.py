#!/usr/bin/env python3
"""Finalize R18D from completed W/Z runs plus frozen-grid regressions."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import cv2


WZ = {
    "62633-726_20260818204139_Slot19": ("148AW103SUD5", "51C90E2F048384E5E86838B2C82FCB7DC47CBBBA66B3635E82C3A563DA907463"),
    "62623-743_20260720111120_Slot04": ("147Z6157SUA5", "46B8C02DDECCAD4FDD3145170867354A083E4FB06EAFA5A39A01328CA2DE38CC"),
}
OBSERVED = (
    (r"C:\P2COHORT\results\R18C_DEVELOPMENT_GATE_20260903A\62625-957_20260729124737_Slot24\R18C_RESULT.json", "1484P102SUC0"),
    (r"C:\P2COHORT\results\R18A_FROZEN_R17E_BLIND_20260903A\62619-451-PRE_20260723105349_Slot05\R17E_RESULT.json", "9508R043FED4"),
    (r"C:\P2COHORT\results\R18A_FROZEN_R17E_BLIND_20260903A\62624-855_20260721120719_Slot07\R17E_RESULT.json", "1478T158SUC5"),
    (r"C:\P2COHORT\results\R18A_FROZEN_R17E_BLIND_20260903A\62618-252_20260715115352_Slot01\R17E_RESULT.json", "146J7043SUE2"),
)
OLDER_VISIBLE = (
    ("Lot-62546-481-POST2_20260713155808_Slot02", "DF", True, (367, 279, 98, 230), "1878P076FEE6"),
    ("62620-548_20260810154124_Slot01", "BF", False, (351, 193, 100, 230), "L0751043FEC4"),
    ("Lot-62546-481-POST2_20260713155808_Slot20", "DF", True, (362, 274, 98, 230), "8365N004FEC6"),
    ("62627-193_20260820124250_Slot01", "BF", False, (404, 260, 96, 230), "1484P068SUD6"),
    ("62625-956_20260729122701_Slot17", "BF", False, (419, 257, 96, 230), "147JQ121SUE7"),
)
BLANKS = (
    (Path(r"C:\R17A2\data\JBOD_PROCESSOR_REVIEW\identity\proposals"), "Lot-62546-481-POST2_20260713155808_Slot18"),
    (Path(r"C:\R17A2\data\JBOD_PROCESSOR_REVIEW\identity\proposals"), "dev-01-post-8-19_20260819164148_Slot01"),
    (Path(r"C:\R17A2\data\JBOD_PROCESSOR_REVIEW\identity\proposals"), "Lot-62546-481-POST2_20260713155808_Slot23"),
    (Path(r"C:\R18A2\data\JBOD_PROCESSOR_REVIEW\identity\proposals"), "62627-182_20260810050905_Slot23"),
    (Path(r"C:\R18A2\data\JBOD_PROCESSOR_REVIEW\identity\proposals"), "62613-842A-test_20260730053955_Slot25"),
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_module(name: str, path: Path) -> Any:
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
    parser.add_argument("--provider", required=True, type=Path)
    parser.add_argument("--supplement", required=True, type=Path)
    parser.add_argument("--wz-root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise FileExistsError(args.output)
    project = args.project.resolve()
    provider = load_module("argos_scribe_r18d_finalize", args.provider.resolve())
    chain = provider.R18C.R17E.R17D
    r11 = chain.R17C.R17B._load_r11()
    manifest = project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    roots = {"glyphs": manifest.parent / "glyphs", "glyphs_v5_confirmed_20260806": manifest.parent / "glyphs_v5_confirmed_20260806"}
    prototypes, evidence = r11.load_reference_prototypes(manifest, "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229", roots)
    supplement_sha = sha256_file(args.supplement)
    prototypes, combined = provider.R18D_LOADER.combine_reference_prototypes(r11, prototypes, evidence, args.supplement, supplement_sha)
    topology = chain.load_topology_prototypes(r11, manifest, "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229", roots, args.supplement, supplement_sha)
    if [(x.label, x.physical_identity) for x in prototypes] != [(x.label, x.physical_identity) for x in topology]:
        raise AssertionError("Appearance and topology banks differ.")

    wz_rows = []
    for identity, (expected, expected_sha) in WZ.items():
        path = args.wz_root / identity / "R18D_RESULT.json"
        if sha256_file(path) != expected_sha:
            raise ValueError(f"Completed W/Z result changed: {identity}")
        result = json.loads(path.read_text(encoding="utf-8-sig"))
        if result.get("imageFirstString") != expected or result.get("proposedString") != expected:
            raise AssertionError(f"W/Z integration failed: {identity}")
        wz_rows.append({"physicalIdentity": identity, "string": expected, "resultSha256": expected_sha, "validationClass": "OPERATOR_CONFIRMED_SELF_REFERENCE_INTEGRATION"})

    visible_rows = []
    for result_name, expected in OBSERVED:
        frozen = json.loads(Path(result_name).read_text(encoding="utf-8-sig"))
        selected = frozen["hypotheses"][0]
        channel = selected["channel"]
        source = Path(frozen["provenance"]["sources"][channel.lower()]["path"])
        gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise FileNotFoundError(source)
        view = 255 - gray if selected["polarity"] == "BRIGHT" else gray
        if selected["direction"] == "REVERSE_180":
            view = cv2.rotate(view, cv2.ROTATE_180)
        grid = (selected["x"], selected["y"], selected["cellWidth"], selected["cellHeight"])
        identity = Path(result_name).parent.name
        checked = chain.evaluate_detector_input_hybrid(r11, view, prototypes, topology, identity, grid)
        checked = provider.R18C.R17E.enforce_grid_verifier_only(checked)
        if checked["imageFirstString"] != expected or checked["proposedString"] != expected:
            raise AssertionError(f"Observed regression changed: {source}")
        visible_rows.append({"physicalIdentity": identity, "string": expected, "selectionScore": checked["selectionScore"], "sourceSha256": sha256_file(source)})

    old_root = Path(r"C:\R17A2\data\JBOD_PROCESSOR_REVIEW\identity\proposals")
    for identity, channel, invert, grid, expected in OLDER_VISIBLE:
        source = old_root / identity / "scribe" / f"{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise FileNotFoundError(source)
        checked = chain.evaluate_detector_input_hybrid(r11, 255 - gray if invert else gray, prototypes, topology, "", grid)
        checked = provider.R18C.R17E.enforce_grid_verifier_only(checked)
        if checked["imageFirstString"] != expected or checked["proposedString"] != expected:
            raise AssertionError(f"Older visible regression changed: {identity}")
        visible_rows.append({"physicalIdentity": identity, "string": expected, "selectionScore": checked["selectionScore"], "sourceSha256": sha256_file(source)})

    blank_rows = []
    for root, identity in BLANKS:
        maximum = -1.0
        for channel in ("BF", "DF"):
            source = root / identity / "scribe" / f"{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
            gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
            if gray is None:
                raise FileNotFoundError(source)
            for view in (gray, 255 - gray, cv2.rotate(gray, cv2.ROTATE_180), cv2.rotate(255 - gray, cv2.ROTATE_180)):
                checked = chain.evaluate_detector_input_hybrid(r11, view, prototypes, topology, "")
                maximum = max(maximum, float(checked["selectionScore"]))
        if maximum >= provider.MINIMUM_POST_GRID_IMAGE_SCORE:
            raise AssertionError(f"Blank regression reached presence floor: {identity} {maximum}")
        blank_rows.append({"physicalIdentity": identity, "maximumSelectionScore": maximum, "decision": "HOLD_SCRIBE_NOT_LOCALIZED", "producedString": False})

    gate = {
        "schema": "argos_opencv_scribe_r18d_local_gate_v1", "state": "PASS_R18D_WZ_REFERENCE_INTEGRATION_AND_REGRESSION",
        "providerSha256": sha256_file(args.provider), "r18cAlgorithmSha256": sha256_file(project / "work/OPENCV_SCRIBE_R18C/ArgosOpenCvScribeV1R18C.py"),
        "loaderSha256": sha256_file(project / "work/OPENCV_SCRIBE_R18D/ArgosOpenCvScribeSupplementLoaderR18D.py"), "supplementalManifestSha256": supplement_sha,
        "operatorConfirmedIntegration": wz_rows, "independentWzValidationCount": 0, "visibleRegression": visible_rows, "blankRegression": blank_rows,
        "remainingMissingLabels": combined["missingBodyReferenceLabels"], "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
        "reviewOnly": True, "identityAcceptanceAuthorized": False, "trainingAuthorized": False, "activationAuthorized": False, "productionAuthorized": False,
    }
    args.output.write_text(json.dumps(gate, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"state": gate["state"], "wzExact": len(wz_rows), "visibleExact": len(visible_rows), "blankHeld": len(blank_rows), "remainingMissingLabels": gate["remainingMissingLabels"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
