#!/usr/bin/env python3
"""Bounded local regression gate for the R17B pre-OCR presence decision."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import cv2


DEVELOPMENT_CASES = {
    "Lot-62546-481-POST2_20260713155808_Slot02": "SCRIBE_PRESENT_FOR_OCR",
    "Lot-62546-481-POST2_20260713155808_Slot18": "HOLD_SCRIBE_NOT_LOCALIZED",
    "62620-548_20260810154124_Slot01": "SCRIBE_PRESENT_FOR_OCR",
    "dev-01-post-8-19_20260819164148_Slot01": "HOLD_SCRIBE_NOT_LOCALIZED",
}
BLIND_CASES = {
    "Lot-62546-481-POST2_20260713155808_Slot20",
    "Lot-62546-481-POST2_20260713155808_Slot23",
    "62627-193_20260820124250_Slot01",
    "62625-956_20260729122701_Slot17",
}
CONTROL_STRINGS = {
    "S01_R11_R2.json": "3912P014FED2",
    "S03_R11.json": "2659P076FEF4",
}


def load_provider(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("argos_scribe_r17b_test_target", path)
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
    parser.add_argument("--development-root", required=True, type=Path)
    parser.add_argument("--regression-root", required=True, type=Path)
    arguments = parser.parse_args()
    provider = load_provider(arguments.provider)

    observed = set(DEVELOPMENT_CASES)
    if observed & BLIND_CASES:
        raise AssertionError("Development and blind cohorts overlap.")
    decisions = []
    for case_id, expected in DEVELOPMENT_CASES.items():
        root = arguments.development_root / case_id / "scribe"
        bf = cv2.imread(str(root / "BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"), cv2.IMREAD_GRAYSCALE)
        df = cv2.imread(str(root / "DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"), cv2.IMREAD_GRAYSCALE)
        if bf is None or df is None:
            raise FileNotFoundError(f"Development pair is absent: {case_id}")
        evidence = provider.paired_presence_evidence(bf, df)
        actual = str(evidence["decision"])
        if actual != expected:
            raise AssertionError(f"Presence decision changed: {case_id}: {actual} != {expected}")
        decisions.append({"caseId": case_id, "decision": actual})

    cleared = {
        "revision": "PREDECESSOR",
        "state": "PREDECESSOR",
        "imageFirstString": "FALSESTRINGA0",
        "proposedString": "FALSESTRINGA0",
        "checksumState": "PREDECESSOR",
        "hypotheses": [{"false": True}],
        "candidates": [{"string": "FALSESTRINGA0"}],
        "holds": [],
        "localization": {},
        "provenance": {},
    }
    provider._apply_not_localized_hold(cleared, {"passed": False})
    if cleared["imageFirstString"] or cleared["proposedString"] or cleared["hypotheses"] or cleared["candidates"]:
        raise AssertionError("Not-localized hold retained OCR content.")

    controls = []
    for name, expected in CONTROL_STRINGS.items():
        result = read_json(arguments.regression_root / name)
        if result.get("imageFirstString") != expected or result.get("proposedString") != expected:
            raise AssertionError(f"Whole-wafer control string changed: {name}")
        if len(result.get("candidates", [])) != 1:
            raise AssertionError(f"Whole-wafer control candidate count changed: {name}")
        controls.append({"result": name, "string": expected})

    s17 = read_json(arguments.regression_root / "S17_R12B" / "result.json")
    best = dict(s17.get("bestDiagnostic") or {})
    if best.get("proposedString") != "6KB71041XDE5" or best.get("checksumValid") is not True:
        raise AssertionError("S17 misplaced-scribe recovery changed.")

    print(json.dumps({
        "state": "PASS_R17B_LOCAL",
        "developmentDecisions": decisions,
        "blankHoldClearsAllOcrContent": True,
        "wholeWaferControls": controls,
        "misplacedS17": {"string": "6KB71041XDE5", "checksumValid": True},
        "blindCasesRead": 0,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
