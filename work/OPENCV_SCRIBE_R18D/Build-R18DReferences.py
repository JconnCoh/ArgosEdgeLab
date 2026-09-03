#!/usr/bin/env python3
"""Build the operator-confirmed W/Z diagnostic reference supplement."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

import cv2


BASE_SUPPLEMENT_SHA256 = "9F78AD34B8707DBB925AE5D569785FD5F67782B92E9FC35A664CD8887C63BBEC"
CASES = (
    {
        "label": "W", "caseId": "W19C", "position": 5,
        "physicalIdentity": "62633-726_20260818204139_Slot19",
        "truth": "148AW103SUD5", "x": 410, "y": 300, "width": 96, "height": 230,
        "source": r"C:\R18A2\data\JBOD_PROCESSOR_REVIEW\identity\proposals\62633-726_20260818204139_Slot19\scribe\BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
        "sourceSha256": "EF620DE8061FA1FD1585EC4CE39C95EAE2686E604ECF08D1E28F864BEF56F5AB",
    },
    {
        "label": "Z", "caseId": "Z04C", "position": 4,
        "physicalIdentity": "62623-743_20260720111120_Slot04",
        "truth": "147Z6157SUA5", "x": 409, "y": 271, "width": 96, "height": 230,
        "source": r"C:\R18A2\data\JBOD_PROCESSOR_REVIEW\identity\proposals\62623-743_20260720111120_Slot04\scribe\BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png",
        "sourceSha256": "DE2C242EB6AD0D188E071215D2065E44EDAE4DFE9B2FDD1FB21A03CB7BB77170",
    },
)


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
    refs = output / "supplemental_refs"
    refs.mkdir(parents=True)

    predecessor = project / "work/OPENCV_SCRIBE_R16A_LOCAL_RESULT_R3/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    if sha256_file(predecessor) != BASE_SUPPLEMENT_SHA256:
        raise ValueError("Frozen R16A supplement changed.")
    old = json.loads(predecessor.read_text(encoding="utf-8-sig"))
    rows = []
    for row in old["references"]:
        source = predecessor.parent / Path(row["relativePath"])
        if sha256_file(source) != row["sha256"]:
            raise ValueError(f"Frozen predecessor glyph changed: {source}")
        target = refs / source.name
        shutil.copyfile(source, target)
        if sha256_file(target) != row["sha256"]:
            raise ValueError(f"Copied predecessor glyph changed: {target}")
        rows.append(dict(row))

    confirmations = []
    for case in CASES:
        source = Path(case["source"])
        if sha256_file(source) != case["sourceSha256"]:
            raise ValueError(f"Confirmed source changed: {source}")
        gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise ValueError(f"OpenCV could not decode: {source}")
        cell_x = case["x"] + (case["position"] - 1) * case["width"]
        cell = gray[case["y"]:case["y"] + case["height"], cell_x:cell_x + case["width"]]
        if cell.shape != (case["height"], case["width"]):
            raise ValueError(f"Confirmed glyph crop is incomplete: {case['label']}")
        target = refs / f"{case['label']}_{case['caseId']}_P{case['position']:02d}.png"
        if not cv2.imwrite(str(target), cell):
            raise IOError(target)
        row = {
            "label": case["label"], "caseId": case["caseId"],
            "physicalIdentity": case["physicalIdentity"], "truth": case["truth"],
            "position": case["position"],
            "relativePath": f"supplemental_refs/{target.name}",
            "sha256": sha256_file(target), "sourcePath": str(source),
            "sourceSha256": case["sourceSha256"],
            "sourceGrid": {"x": case["x"], "y": case["y"], "cellWidth": case["width"], "cellHeight": case["height"]},
            "operatorConfirmed": True,
        }
        rows.append(row)
        confirmations.append({
            "label": case["label"], "physicalIdentity": case["physicalIdentity"],
            "position": case["position"], "truth": case["truth"],
            "glyphSha256": row["sha256"], "confirmation": "OPERATOR_CONFIRMED_CORRECT_2026-09-03",
            "scope": "GLYPH_REFERENCE_LABEL_ONLY",
        })

    counts: dict[str, int] = {}
    for row in rows:
        counts[row["label"]] = counts.get(row["label"], 0) + 1
    manifest = {
        "schema": "argos_opencv_scribe_supplemental_glyph_references_v1",
        "revision": "OCV02_R18D_SUPPLEMENTAL_WZ_LOCAL_DRAFT_20260903A",
        "disposition": "DIAGNOSTIC_ONLY", "references": rows, "labelCounts": counts,
        "independentlyValidatedLabels": "JQ", "singleExampleProvisionalLabels": "KWXZ",
        "operatorConfirmedLabels": "WZ", "frozenBaseMissingLabels": "IJKOQVWXYZ",
        "remainingMissingLabelsAfterSupplement": "IOVY",
        "identityAdmissionAuthorized": False, "activationAuthorized": False,
        "trainingAuthorized": False, "productionAuthorized": False,
    }
    manifest_path = output / "SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    write_json(manifest_path, manifest)
    confirmation = {
        "schema": "argos_opencv_scribe_r18d_operator_confirmation_v1",
        "state": "CONFIRMED_WZ_REFERENCE_LABELS",
        "rows": confirmations, "supplementalManifestSha256": sha256_file(manifest_path),
        "identityAcceptanceAuthorized": False, "trainingAuthorized": False,
        "activationAuthorized": False, "productionAuthorized": False,
    }
    write_json(output / "R18D_OPERATOR_CONFIRMED_REFERENCES.json", confirmation)
    print(json.dumps({"state": "BUILT_R18D_WZ_REFERENCES", "manifestSha256": sha256_file(manifest_path), "labelCounts": counts}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
