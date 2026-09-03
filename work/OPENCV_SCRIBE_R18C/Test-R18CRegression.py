#!/usr/bin/env python3
"""Regression gate R18C against five proven scribes and three proven blanks."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import cv2


R17E_GATE_SHA256 = "A2C1BC7D974670C481F4D510051AF2699080B20ECE93BE60536771F35E310DE2"
VISIBLE = (
    ("Lot-62546-481-POST2_20260713155808_Slot02", "DF", True, (367, 279, 98, 230), "1878P076FEE6"),
    ("62620-548_20260810154124_Slot01", "BF", False, (351, 193, 100, 230), "L0751043FEC4"),
    ("Lot-62546-481-POST2_20260713155808_Slot20", "DF", True, (362, 274, 98, 230), "8365N004FEC6"),
    ("62627-193_20260820124250_Slot01", "BF", False, (404, 260, 96, 230), "1484P068SUD6"),
    ("62625-956_20260729122701_Slot17", "BF", False, (419, 257, 96, 230), "147JQ121SUE7"),
)
BLANK = (
    "Lot-62546-481-POST2_20260713155808_Slot18",
    "dev-01-post-8-19_20260819164148_Slot01",
    "Lot-62546-481-POST2_20260713155808_Slot23",
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
        raise RuntimeError(f"Could not load module: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--provider", required=True, type=Path)
    parser.add_argument("--crop-root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise FileExistsError(args.output)
    r17e_gate = args.project / "work/OPENCV_SCRIBE_R17E/R17E_LOCAL_GATE.json"
    if sha256_file(r17e_gate) != R17E_GATE_SHA256:
        raise ValueError("Frozen R17E regression gate SHA-256 mismatch.")
    provider = load_module("argos_scribe_r18c_regression", args.provider.resolve())
    helper = load_module("argos_scribe_r17e_regression_helper", args.project / "work/OPENCV_SCRIBE_R17E/Test-ArgosOpenCvScribeR17E.py")
    r11, prototypes, topology = helper.load_banks(provider.R17E, args.project.resolve())
    visible_rows = []
    for case_id, channel, invert, grid, expected in VISIBLE:
        source = args.crop_root / case_id / "scribe" / f"{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise FileNotFoundError(source)
        if invert:
            gray = 255 - gray
        evaluated = provider.R17E.R17D.evaluate_detector_input_hybrid(r11, gray, prototypes, topology, "", grid)
        evaluated = provider.R17E.enforce_grid_verifier_only(evaluated)
        if evaluated["imageFirstString"] != expected or evaluated["proposedString"] != expected:
            raise AssertionError(f"Visible regression changed: {case_id}")
        if float(evaluated["selectionScore"]) < provider.MINIMUM_POST_GRID_IMAGE_SCORE:
            raise AssertionError(f"Visible regression fell below presence floor: {case_id}")
        visible_rows.append({"physicalIdentity": case_id, "imageFirstString": expected, "selectionScore": evaluated["selectionScore"], "sourceSha256": sha256_file(source)})

    blank_rows = []
    for case_id in BLANK:
        scores = []
        for channel in ("BF", "DF"):
            source = args.crop_root / case_id / "scribe" / f"{channel}_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
            gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
            if gray is None:
                raise FileNotFoundError(source)
            for polarity, view in (("DARK", gray), ("BRIGHT", 255 - gray)):
                for direction, oriented in (("FORWARD", view), ("REVERSE_180", cv2.rotate(view, cv2.ROTATE_180))):
                    evaluated = provider.R17E.R17D.evaluate_detector_input_hybrid(r11, oriented, prototypes, topology, "")
                    scores.append({"channel": channel, "polarity": polarity, "direction": direction, "imageFirstString": evaluated["imageFirstString"], "selectionScore": evaluated["selectionScore"]})
        maximum = max(float(row["selectionScore"]) for row in scores)
        if maximum >= provider.MINIMUM_POST_GRID_IMAGE_SCORE:
            raise AssertionError(f"Blank regression reached presence floor: {case_id} {maximum}")
        blank_rows.append({"physicalIdentity": case_id, "maximumSelectionScore": maximum, "decision": "HOLD_SCRIBE_NOT_LOCALIZED", "imageFirstString": "", "proposedString": "", "views": scores})

    gate = {
        "schema": "argos_opencv_scribe_r18c_regression_gate_v1",
        "state": "PASS_R18C_REGRESSION",
        "providerSha256": sha256_file(args.provider),
        "r17eGateSha256": R17E_GATE_SHA256,
        "minimumPostGridImageScore": provider.MINIMUM_POST_GRID_IMAGE_SCORE,
        "visibleExactCount": len(visible_rows),
        "blankHeldEmptyCount": len(blank_rows),
        "visible": visible_rows,
        "blank": blank_rows,
        "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
        "reviewOnly": True,
    }
    args.output.write_text(json.dumps(gate, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"state": gate["state"], "visibleExactCount": len(visible_rows), "blankHeldEmptyCount": len(blank_rows), "providerSha256": gate["providerSha256"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
