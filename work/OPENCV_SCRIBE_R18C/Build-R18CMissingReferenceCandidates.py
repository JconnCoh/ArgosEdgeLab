#!/usr/bin/env python3
"""Build operator-confirmation evidence for missing W and Z references."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import cv2


CASES = (
    {
        "label": "W",
        "position": 5,
        "physicalIdentity": "62633-726_20260818204139_Slot19",
        "observedString": "148AU103SUD5",
        "correctedString": "148AW103SUD5",
        "resultPath": "C:/P2COHORT/results/R18A_FROZEN_R17E_DEVELOPMENT_20260903A/62633-726_20260818204139_Slot19/R17E_RESULT.json",
        "resultSha256": "B22FE6F6798CE046D5E86B7D8622AB6A9A00C7FFE5D67E71A7D59E407EA9AEC4",
    },
    {
        "label": "Z",
        "position": 4,
        "physicalIdentity": "62623-743_20260720111120_Slot04",
        "observedString": "147E6157SUA5",
        "correctedString": "147Z6157SUA5",
        "resultPath": "C:/P2COHORT/results/R18A_FROZEN_R17E_BLIND_20260903A/62623-743_20260720111120_Slot04/R17E_RESULT.json",
        "resultSha256": "9079876167EBA9F3FE8F413372DA0848578BC02B179859FA6E8DCFBD24F649B4",
    },
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_r11(project: Path) -> Any:
    path = project / "work/OPENCV_SCRIBE_R11A/ArgosOpenCvScribeV1R11.py"
    spec = importlib.util.spec_from_file_location("argos_scribe_r18c_candidate_checksum", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load checksum implementation: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    if args.output_root.exists():
        raise FileExistsError(args.output_root)
    args.output_root.mkdir(parents=True)
    r11 = load_r11(args.project.resolve())
    rows = []
    for case in CASES:
        result_path = Path(case["resultPath"])
        if sha256_file(result_path) != case["resultSha256"]:
            raise ValueError(f"Frozen result changed: {case['physicalIdentity']}")
        result = json.loads(result_path.read_text(encoding="utf-8-sig"))
        if result["imageFirstString"] != case["observedString"]:
            raise ValueError(f"Observed string changed: {case['physicalIdentity']}")
        selected = result["hypotheses"][0]
        channel = str(selected["channel"])
        source_row = result["provenance"]["sources"][channel.lower()]
        source = Path(str(source_row["path"]))
        if sha256_file(source) != source_row["sha256"]:
            raise ValueError(f"Source changed: {case['physicalIdentity']}")
        gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise ValueError(f"OpenCV could not decode: {source}")
        view = 255 - gray if selected["polarity"] == "BRIGHT" else gray
        if selected["direction"] == "REVERSE_180":
            view = cv2.rotate(view, cv2.ROTATE_180)
        x, y = int(selected["x"]), int(selected["y"])
        width, height = int(selected["cellWidth"]), int(selected["cellHeight"])
        index = int(case["position"]) - 1
        cell_x = x + index * width
        cell = view[y:y + height, cell_x:cell_x + width]
        context = cv2.cvtColor(view[max(0, y - 35):min(view.shape[0], y + height + 35), max(0, x - 35):min(view.shape[1], x + 12 * width + 35)], cv2.COLOR_GRAY2BGR)
        offset_x = x - max(0, x - 35) + index * width
        offset_y = y - max(0, y - 35)
        cv2.rectangle(context, (offset_x, offset_y), (offset_x + width, offset_y + height), (255, 0, 255), 3)
        case_root = args.output_root / f"{case['label']}_{case['physicalIdentity']}"
        case_root.mkdir()
        glyph_path = case_root / "GLYPH_CANDIDATE.png"
        context_path = case_root / "SCRIBE_CONTEXT.png"
        if not cv2.imwrite(str(glyph_path), cv2.resize(cell, (width * 4, height * 4), interpolation=cv2.INTER_NEAREST)):
            raise IOError("Could not write glyph candidate.")
        if not cv2.imwrite(str(context_path), context):
            raise IOError("Could not write scribe context.")
        expected_check = r11.m12_check_characters(case["correctedString"][:10])
        corrected_valid = r11.m12_remainder(case["correctedString"]) == 0 and case["correctedString"][10:] == expected_check
        if not corrected_valid:
            raise AssertionError(f"Corrected visual string failed checksum: {case['physicalIdentity']}")
        rows.append({
            **case,
            "source": str(source),
            "sourceSha256": source_row["sha256"],
            "channel": channel,
            "polarity": selected["polarity"],
            "direction": selected["direction"],
            "grid": {"x": x, "y": y, "cellWidth": width, "cellHeight": height},
            "glyphCandidate": str(glyph_path),
            "glyphCandidateSha256": sha256_file(glyph_path),
            "scribeContext": str(context_path),
            "scribeContextSha256": sha256_file(context_path),
            "observedStringChecksumValid": False,
            "correctedStringChecksumValid": True,
            "operatorConfirmationRequired": True,
            "referenceAdmitted": False,
            "trainingEligible": False,
        })
    manifest = {
        "schema": "argos_opencv_scribe_r18c_missing_reference_candidates_v1",
        "state": "PENDING_OPERATOR_CONFIRMATION",
        "candidateLabels": [row["label"] for row in rows],
        "rows": rows,
        "referenceManifestModified": False,
        "trainingAuthorized": False,
        "identityAcceptanceAuthorized": False,
        "reviewOnly": True,
    }
    manifest_path = args.output_root / "MISSING_REFERENCE_CANDIDATES.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"state": manifest["state"], "candidateLabels": manifest["candidateLabels"], "outputRoot": str(args.output_root)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
