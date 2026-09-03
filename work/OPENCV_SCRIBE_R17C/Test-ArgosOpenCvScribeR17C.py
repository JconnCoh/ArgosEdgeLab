#!/usr/bin/env python3
"""Eight-case normal-crop and frozen whole-wafer regression gate for R17C."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import cv2


EXPECTED = {
    "Lot-62546-481-POST2_20260713155808_Slot02": "SCRIBE_PRESENT_FOR_OCR",
    "Lot-62546-481-POST2_20260713155808_Slot18": "HOLD_SCRIBE_NOT_LOCALIZED",
    "62620-548_20260810154124_Slot01": "SCRIBE_PRESENT_FOR_OCR",
    "dev-01-post-8-19_20260819164148_Slot01": "HOLD_SCRIBE_NOT_LOCALIZED",
    "Lot-62546-481-POST2_20260713155808_Slot20": "SCRIBE_PRESENT_FOR_OCR",
    "Lot-62546-481-POST2_20260713155808_Slot23": "HOLD_SCRIBE_NOT_LOCALIZED",
    "62627-193_20260820124250_Slot01": "SCRIBE_PRESENT_FOR_OCR",
    "62625-956_20260729122701_Slot17": "SCRIBE_PRESENT_FOR_OCR",
}
BF_REQUIRED = {
    "62627-193_20260820124250_Slot01",
    "62625-956_20260729122701_Slot17",
}
CONTROL_STRINGS = {
    "S01_R11_R2.json": "3912P014FED2",
    "S03_R11.json": "2659P076FEF4",
}


def load_provider(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("argos_scribe_r17c_test_target", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load provider: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", required=True, type=Path)
    parser.add_argument("--crop-root", required=True, type=Path)
    parser.add_argument("--regression-root", required=True, type=Path)
    arguments = parser.parse_args()
    provider = load_provider(arguments.provider)
    decisions = []
    for case_id, expected in EXPECTED.items():
        root = arguments.crop_root / case_id / "scribe"
        bf = cv2.imread(str(root / "BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"), cv2.IMREAD_GRAYSCALE)
        df = cv2.imread(str(root / "DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"), cv2.IMREAD_GRAYSCALE)
        if bf is None or df is None:
            raise FileNotFoundError(f"Crop pair is absent: {case_id}")
        evidence = provider.paired_presence_evidence(bf, df)
        actual = str(evidence["decision"])
        if actual != expected:
            raise AssertionError(f"Presence decision changed: {case_id}: {actual} != {expected}")
        passing = [
            f"{row['channel']}_{row['polarity']}_{row['profile']}"
            for row in evidence["views"] if bool(row["passed"])
        ]
        if case_id in BF_REQUIRED and not any(row.startswith("BF_DARK_") for row in passing):
            raise AssertionError(f"Clear BF path was not retained: {case_id}")
        decisions.append({"caseId": case_id, "decision": actual, "passingViews": passing})

    for name, expected in CONTROL_STRINGS.items():
        result = read_json(arguments.regression_root / name)
        if result.get("imageFirstString") != expected or result.get("proposedString") != expected:
            raise AssertionError(f"Whole-wafer control changed: {name}")
    s17 = read_json(arguments.regression_root / "S17_R12B" / "result.json")
    if (s17.get("bestDiagnostic") or {}).get("proposedString") != "6KB71041XDE5":
        raise AssertionError("S17 misplaced-scribe recovery changed.")

    print(json.dumps({
        "state": "PASS_R17C_LOCAL",
        "presenceCases": decisions,
        "presentCount": sum(row["decision"] == "SCRIBE_PRESENT_FOR_OCR" for row in decisions),
        "notLocalizedCount": sum(row["decision"] == "HOLD_SCRIBE_NOT_LOCALIZED" for row in decisions),
        "wholeWaferControls": list(CONTROL_STRINGS.values()),
        "misplacedS17": "6KB71041XDE5",
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
