#!/usr/bin/env python3
"""Build the R18F supplement with the operator-confirmed Slot22 K glyph."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

import cv2


PREDECESSOR_MANIFEST_SHA256 = "8B7F0BAC5892DA7BBB4D25CDD058CC995042A0C596F3790FE333AAAEEE43D60A"
SOURCE = Path(r"C:\R18E\data\JBOD_PROCESSOR_REVIEW\identity\proposals\62546-481-POST_20260713041740_Slot22\scribe\BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png")
SOURCE_SHA256 = "3D41F41B0E6F99940ED8C7243DE665FC063EDB4A8408A442C3EDBDD844E40F18"
TRUTH = "13DCK060SUF5"
GRID = {"x": 411, "y": 268, "cellWidth": 96, "cellHeight": 230}
POSITION = 5


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    output = args.output_root.resolve()
    if output.exists():
        raise FileExistsError(output)
    references_root = output / "supplemental_refs"
    references_root.mkdir(parents=True)

    predecessor = project / "work/OPENCV_SCRIBE_R18D/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    if sha256_file(predecessor) != PREDECESSOR_MANIFEST_SHA256:
        raise ValueError("Frozen R18D supplement changed")
    old = json.loads(predecessor.read_text(encoding="utf-8-sig"))
    rows = []
    for row in old["references"]:
        source = predecessor.parent / Path(str(row["relativePath"]))
        if sha256_file(source) != str(row["sha256"]):
            raise ValueError(f"Frozen predecessor glyph changed: {source}")
        target = references_root / source.name
        shutil.copyfile(source, target)
        if sha256_file(target) != str(row["sha256"]):
            raise ValueError(f"Copied predecessor glyph changed: {target}")
        rows.append(dict(row))

    if sha256_file(SOURCE) != SOURCE_SHA256:
        raise ValueError("Operator-confirmed Slot22 source changed")
    gray = cv2.imread(str(SOURCE), cv2.IMREAD_GRAYSCALE)
    if gray is None:
        raise ValueError(f"OpenCV could not decode {SOURCE}")
    cell_x = GRID["x"] + (POSITION - 1) * GRID["cellWidth"]
    cell = gray[GRID["y"]:GRID["y"] + GRID["cellHeight"], cell_x:cell_x + GRID["cellWidth"]]
    if cell.shape != (GRID["cellHeight"], GRID["cellWidth"]):
        raise ValueError("Operator-confirmed K cell is incomplete")
    target = references_root / "K_K22C_P05.png"
    if not cv2.imwrite(str(target), cell):
        raise IOError(target)
    k_sha256 = sha256_file(target)
    rows.append({
        "label": "K",
        "caseId": "K22C",
        "physicalIdentity": "62546-481-POST_20260713041740_Slot22",
        "truth": TRUTH,
        "position": POSITION,
        "relativePath": "supplemental_refs/K_K22C_P05.png",
        "sha256": k_sha256,
        "sourcePath": str(SOURCE),
        "sourceSha256": SOURCE_SHA256,
        "sourceGrid": GRID,
        "operatorConfirmed": True,
    })
    counts: dict[str, int] = {}
    for row in rows:
        label = str(row["label"])
        counts[label] = counts.get(label, 0) + 1
    expected_counts = {"J": 2, "K": 2, "Q": 2, "W": 1, "X": 1, "Z": 1}
    if counts != expected_counts:
        raise ValueError(f"Unexpected R18F reference counts: {counts}")
    manifest = {
        "schema": "argos_opencv_scribe_supplemental_glyph_references_v1",
        "revision": "OCV02_R18F_SUPPLEMENTAL_K_LOCAL_DRAFT_20260903A",
        "disposition": "DIAGNOSTIC_ONLY",
        "references": rows,
        "labelCounts": counts,
        "independentlyValidatedLabels": "JQ",
        "multiExampleProvisionalLabels": "K",
        "singleExampleProvisionalLabels": "WXZ",
        "operatorConfirmedLabels": "KWZ",
        "frozenBaseMissingLabels": "IJKOQVWXYZ",
        "remainingMissingLabelsAfterSupplement": "IOVY",
        "identityAdmissionAuthorized": False,
        "activationAuthorized": False,
        "trainingAuthorized": False,
        "productionAuthorized": False,
    }
    manifest_path = output / "SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    write_json(manifest_path, manifest)
    confirmation = {
        "schema": "argos_opencv_scribe_r18f_operator_confirmation_v1",
        "state": "CONFIRMED_SLOT22_POSITION_2_IS_3_AND_POSITION_5_IS_K",
        "physicalIdentity": "62546-481-POST_20260713041740_Slot22",
        "confirmedString": TRUTH,
        "rows": [
            {"position": 2, "label": "3", "scope": "VISIBLE_GLYPH_CONFIRMATION_ONLY", "referenceAdmitted": False},
            {"position": 5, "label": "K", "scope": "GLYPH_REFERENCE_LABEL_ONLY", "glyphSha256": k_sha256, "referenceAdmitted": True},
        ],
        "supplementalManifestSha256": sha256_file(manifest_path),
        "identityAcceptanceAuthorized": False,
        "trainingAuthorized": False,
        "activationAuthorized": False,
        "productionAuthorized": False,
    }
    confirmation_path = output / "R18F_OPERATOR_CONFIRMED_REFERENCES.json"
    write_json(confirmation_path, confirmation)
    gate = {
        "schema": "argos_opencv_scribe_r18f_reference_build_gate_v1",
        "state": "PASS_R18F_OPERATOR_CONFIRMED_K_REFERENCE_BUILT",
        "predecessorManifestSha256": PREDECESSOR_MANIFEST_SHA256,
        "supplementalManifestSha256": sha256_file(manifest_path),
        "operatorConfirmationSha256": sha256_file(confirmation_path),
        "newKReferenceSha256": k_sha256,
        "labelCounts": counts,
        "sourceMutationPerformed": False,
        "reviewOnly": True,
        "identityAcceptanceAuthorized": False,
        "trainingAuthorized": False,
        "activationAuthorized": False,
        "productionAuthorized": False,
    }
    write_json(output / "R18F_REFERENCE_BUILD_GATE.json", gate)
    print(json.dumps(gate, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
