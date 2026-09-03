#!/usr/bin/env python3
"""Render frozen R17E development results without rerunning OCR."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import cv2
import numpy as np


GATE_SHA256 = "29B9F3BE99F984AC72C44DB267389936F5C5C9E591111220FA5EC7277DE19FF8"
PROVIDER_SHA256 = "A2E124FD794C1F97C4C202995DFAB09D4C984862C7E292C1D82034D487A901CA"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def put_label(image: np.ndarray, text: str, origin: tuple[int, int], color: tuple[int, int, int]) -> None:
    cv2.putText(image, text, origin, cv2.FONT_HERSHEY_SIMPLEX, 0.62, color, 2, cv2.LINE_AA)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--result-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    gate_path = args.result_root / "R18B_FROZEN_R17E_DEVELOPMENT_GATE.json"
    if sha256_file(gate_path) != GATE_SHA256:
        raise ValueError("Frozen development gate SHA-256 mismatch.")
    gate = read_json(gate_path)
    if gate.get("state") != "PASS_FROZEN_R17E_DEVELOPMENT_TERMINAL" or gate.get("providerSha256") != PROVIDER_SHA256:
        raise ValueError("Frozen development gate is not PASS or provider differs.")
    if args.output_root.exists():
        raise FileExistsError(f"Review root already exists: {args.output_root}")
    args.output_root.mkdir(parents=True)
    rows = []

    for gate_row in gate["rows"]:
        case_id = str(gate_row["physicalIdentity"])
        result_path = args.result_root / case_id / "R17E_RESULT.json"
        if sha256_file(result_path) != gate_row["resultSha256"]:
            raise ValueError(f"Frozen result changed: {case_id}")
        result = read_json(result_path)
        selected = result["hypotheses"][0]
        channel = str(selected["channel"])
        source = Path(str(result["provenance"]["sources"][channel.lower()]["path"]))
        source_hash = str(result["provenance"]["sources"][channel.lower()]["sha256"])
        if sha256_file(source) != source_hash:
            raise ValueError(f"Frozen source changed: {case_id} {channel}")
        gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise ValueError(f"OpenCV could not decode: {source}")
        view = 255 - gray if selected["polarity"] == "BRIGHT" else gray
        if selected["direction"] == "REVERSE_180":
            view = cv2.rotate(view, cv2.ROTATE_180)
        x, y = int(selected["x"]), int(selected["y"])
        cell_width, cell_height = int(selected["cellWidth"]), int(selected["cellHeight"])
        case_root = args.output_root / case_id
        case_root.mkdir()

        tile_width, tile_height, header = 210, 300, 68
        sheet = np.full((3 * tile_height, 4 * tile_width, 3), 245, dtype=np.uint8)
        for index, position in enumerate(selected["positions"]):
            cell = view[y:y + cell_height, x + index * cell_width:x + (index + 1) * cell_width]
            scaled = cv2.resize(cv2.cvtColor(cell, cv2.COLOR_GRAY2BGR), (tile_width, tile_height - header), interpolation=cv2.INTER_NEAREST)
            row_index, column_index = divmod(index, 4)
            y0, x0 = row_index * tile_height, column_index * tile_width
            sheet[y0 + header:y0 + tile_height, x0:x0 + tile_width] = scaled
            top = position["candidates"][0]
            color = (180, 0, 180) if position["glyphArbitration"]["overrideApplied"] else (0, 110, 0)
            put_label(sheet, f"{index + 1:02d}: {position['imageFirst']}", (x0 + 8, y0 + 24), color)
            put_label(sheet, f"A {top['appearanceScore']:.3f}  T {top['topologyScore']:.3f}", (x0 + 8, y0 + 52), (50, 50, 50))
        if not cv2.imwrite(str(case_root / "CHARACTER_SHEET.png"), sheet):
            raise IOError("Could not write character sheet.")
        diagnostic = {
            "schema": "argos_opencv_scribe_r18b_development_case_diagnostic_v1",
            "physicalIdentity": case_id,
            "source": str(source),
            "sourceSha256": source_hash,
            "resultSha256": gate_row["resultSha256"],
            "state": result["state"],
            "imageFirstString": result["imageFirstString"],
            "proposedString": result["proposedString"],
            "checksumState": result["checksumState"],
            "selectedHypothesis": selected,
            "ocrRerunForRendering": False,
            "reviewOnly": True,
        }
        (case_root / "OCR_DIAGNOSTIC.json").write_text(json.dumps(diagnostic, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        rows.append({"physicalIdentity": case_id, "state": result["state"], "imageFirstString": result["imageFirstString"], "characterSheet": f"{case_id}/CHARACTER_SHEET.png"})

    summary = {"schema": "argos_opencv_scribe_r18b_development_review_v1", "state": "PASS_DIAGNOSTIC_ONLY", "gateSha256": GATE_SHA256, "providerSha256": PROVIDER_SHA256, "rows": rows, "ocrRerunForRendering": False, "operatorConfirmationRequired": True, "reviewOnly": True}
    (args.output_root / "SUMMARY.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"state": summary["state"], "caseCount": len(rows), "outputRoot": str(args.output_root)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
