#!/usr/bin/env python3
"""Build OpenCV-only review evidence for the two R18D Slot22 glyph errors."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import cv2


IDENTITY = "62546-481-POST_20260713041740_Slot22"
RESULT_SHA256 = "9E961FB0B6C15EAFD78C1F6469C104E2352CC6DC47533FF15CA3C330D2541B27"
SOURCE_SHA256 = "3D41F41B0E6F99940ED8C7243DE665FC063EDB4A8408A442C3EDBDD844E40F18"
OBSERVED = "11DCR060SUF5"
VISIBLE_REVIEW_CANDIDATE = "13DCK060SUF5"
POSITIONS = ((2, "1", "3"), (5, "R", "K"))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_r11(project: Path) -> Any:
    path = project / "work/OPENCV_SCRIBE_R11A/ArgosOpenCvScribeV1R11.py"
    spec = importlib.util.spec_from_file_location("argos_scribe_r18e_slot22_checksum", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--result", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    if args.output_root.exists():
        raise FileExistsError(args.output_root)
    if sha256_file(args.result) != RESULT_SHA256:
        raise ValueError("Frozen Slot22 result changed")
    result = json.loads(args.result.read_text(encoding="utf-8-sig"))
    if result.get("imageFirstString") != OBSERVED:
        raise ValueError("Frozen Slot22 image-first string changed")
    selected = result["hypotheses"][0]
    if selected.get("channel") != "BF" or selected.get("direction") != "FORWARD" or selected.get("polarity") != "DARK":
        raise ValueError("Frozen Slot22 selected view changed")
    source = Path(result["provenance"]["sources"]["bf"]["path"])
    if sha256_file(source) != SOURCE_SHA256:
        raise ValueError("Frozen Slot22 BF source changed")
    gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
    if gray is None:
        raise ValueError(f"OpenCV could not decode {source}")

    x = int(selected["x"])
    y = int(selected["y"])
    width = int(selected["cellWidth"])
    height = int(selected["cellHeight"])
    left = max(0, x - 30)
    top = max(0, y - 40)
    right = min(gray.shape[1], x + 12 * width + 30)
    bottom = min(gray.shape[0], y + height + 40)
    context = cv2.cvtColor(gray[top:bottom, left:right], cv2.COLOR_GRAY2BGR)

    args.output_root.mkdir(parents=True)
    rows = []
    glyph_panels = []
    for position, observed, candidate in POSITIONS:
        cell_x = x + (position - 1) * width
        cell = gray[y:y + height, cell_x:cell_x + width]
        if cell.shape != (height, width):
            raise ValueError(f"Incomplete glyph cell at position {position}")
        glyph = cv2.resize(cell, (width * 3, height * 3), interpolation=cv2.INTER_NEAREST)
        glyph_path = args.output_root / f"POSITION_{position:02d}_{candidate}_CANDIDATE.png"
        if not cv2.imwrite(str(glyph_path), glyph):
            raise IOError(glyph_path)
        color = (255, 0, 255)
        cx = cell_x - left
        cy = y - top
        cv2.rectangle(context, (cx, cy), (cx + width, cy + height), color, 4)
        cv2.putText(context, f"P{position}: {observed} -> {candidate}", (max(0, cx - 10), max(25, cy - 8)), cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2, cv2.LINE_AA)
        glyph_panels.append((position, candidate, glyph))
        rows.append({
            "position": position,
            "readerCharacter": observed,
            "visibleCandidateCharacter": candidate,
            "nativeCell": {"x": cell_x, "y": y, "width": width, "height": height},
            "glyphPath": str(glyph_path),
            "glyphSha256": sha256_file(glyph_path),
            "operatorConfirmationRequired": candidate == "K",
            "referenceAdmitted": False,
        })

    context_path = args.output_root / "SCRIBE_CONTEXT_MARKED.png"
    if not cv2.imwrite(str(context_path), context):
        raise IOError(context_path)
    r11 = load_r11(args.project.resolve())
    expected_check = r11.m12_check_characters(VISIBLE_REVIEW_CANDIDATE[:10])
    checksum_valid = r11.m12_remainder(VISIBLE_REVIEW_CANDIDATE) == 0 and VISIBLE_REVIEW_CANDIDATE[10:] == expected_check
    if not checksum_valid:
        raise AssertionError("Visible review candidate failed M12 verification")
    manifest = {
        "schema": "argos_opencv_scribe_r18e_slot22_review_v1",
        "state": "PENDING_OPERATOR_CONFIRMATION_K_REFERENCE",
        "physicalIdentity": IDENTITY,
        "frozenResultPath": str(args.result),
        "frozenResultSha256": RESULT_SHA256,
        "sourcePath": str(source),
        "sourceSha256": SOURCE_SHA256,
        "selectedView": {"channel": "BF", "direction": "FORWARD", "polarity": "DARK"},
        "grid": {"x": x, "y": y, "cellWidth": width, "cellHeight": height},
        "readerString": OBSERVED,
        "visibleReviewCandidateString": VISIBLE_REVIEW_CANDIDATE,
        "visibleReviewCandidateChecksumValid": True,
        "checksumRole": "VERIFY_VISIBLE_CANDIDATE_ONLY",
        "contextPath": str(context_path),
        "contextSha256": sha256_file(context_path),
        "positions": rows,
        "automaticReferenceAdmissionAuthorized": False,
        "identityAcceptanceAuthorized": False,
        "trainingAuthorized": False,
        "activationAuthorized": False,
        "productionAuthorized": False,
        "reviewOnly": True,
    }
    manifest_path = args.output_root / "SLOT22_REVIEW_MANIFEST.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"state": manifest["state"], "manifest": str(manifest_path), "manifestSha256": sha256_file(manifest_path)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
