#!/usr/bin/env python3
"""Focused regression tests for R14 perimeter-candidate admission."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROVIDER_PATH = Path(__file__).with_name("ArgosOpenCvScribeAlphabetCropR14.py")
R13B_BUNDLE = ROOT / "work" / "OPENCV_SCRIBE_R13B_RESPONSE" / "evidence" / "bundle"
CASE_IDS = ("K25V", "X18V", "JQ16D", "JQ20V")


def load_provider():
    spec = importlib.util.spec_from_file_location("argos_scribe_r14_test", PROVIDER_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load the R14 provider")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def read_case(case_id: str) -> dict:
    with (R13B_BUNDLE / case_id / "CASE_RESULT.json").open("r", encoding="utf-8") as stream:
        return json.load(stream)


def main() -> int:
    provider = load_provider()
    verified = []
    for case_id in CASE_IDS:
        case = read_case(case_id)
        rows = provider.perimeter_regions(case["r11Analysis"], 6)
        ids = {str(row["regionId"]) for row in rows}
        sources = [str(row["source"]) for row in rows]
        smooth = [source for source in sources if source.startswith("SMOOTH_")]
        paired = [source for source in sources if source.startswith("PAIRED_BF_DF_")]
        assert len(rows) == 6, (case_id, len(rows))
        assert len(smooth) == 3, (case_id, smooth)
        assert len(paired) == 3, (case_id, paired)
        assert all(source.endswith("_FULL_PERIMETER_REVIEW_ONLY_DEVELOPMENT") for source in sources)
        assert "PERIMETER_SMOOTH_DF_BRIGHT_00" in ids
        verified.append({
            "caseId": case_id,
            "perimeterRegionCount": len(rows),
            "smoothRegionCount": len(smooth),
            "pairedRegionCount": len(paired),
        })

    fixture = {
        "localization": {
            "exceptionDiagnostics": [
                {"regionId": "S", "source": "SMOOTH_BF_DARK_FULL_PERIMETER_REVIEW_ONLY_DEVELOPMENT", "score": 2.0},
                {"regionId": "P", "source": "PAIRED_BF_DF_FULL_PERIMETER_REVIEW_ONLY_DEVELOPMENT", "score": 1.0},
                {"regionId": "X", "source": "UNRELATED_DIAGNOSTIC", "score": 99.0},
            ]
        }
    }
    selected = provider.perimeter_regions(fixture, 2)
    assert [row["regionId"] for row in selected] == ["S", "P"]
    try:
        provider.perimeter_regions(fixture, 1)
    except provider.GateError:
        pass
    else:
        raise AssertionError("Perimeter-region bound did not fail closed")

    print(json.dumps({
        "state": "PASS_R14_PERIMETER_CANDIDATE_ADMISSION_TEST",
        "notchUsed": False,
        "cases": verified,
        "unrelatedCandidateRejected": True,
        "boundFailureVerified": True,
    }, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
