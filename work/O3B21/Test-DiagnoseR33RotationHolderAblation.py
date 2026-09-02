#!/usr/bin/env python3
"""Construction tests for the R33 rotation/holder-ablation gate."""

from __future__ import annotations

from copy import deepcopy
import importlib.util
from pathlib import Path
import sys


RUNNER = Path(__file__).with_name("Diagnose-R33RotationHolderAblation.py")
spec = importlib.util.spec_from_file_location("r33rot1_gate_test", RUNNER)
if spec is None or spec.loader is None:
    raise RuntimeError("Unable to load R33ROT1 runner")
gate = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = gate
spec.loader.exec_module(gate)


MANIFEST = {
    "cases": [
        {"id": "62628-233_0527_SLOT20_LEFT_HOLD"},
        {"id": "62628-233_0527_SLOT16_LEFT_PASS"},
    ]
}


def pass_rows() -> list[dict]:
    angles = {
        ("62628-233_0527_SLOT20_LEFT_HOLD", "original", "exact"): 179.56643289647974,
        ("62628-233_0527_SLOT20_LEFT_HOLD", "original", "noholder"): 179.56643950268904,
        ("62628-233_0527_SLOT20_LEFT_HOLD", "ccw90", "exact"): 89.56643485994135,
        ("62628-233_0527_SLOT20_LEFT_HOLD", "ccw90", "noholder"): 89.56644036548528,
        ("62628-233_0527_SLOT16_LEFT_PASS", "original", "exact"): 180.17834723908112,
        ("62628-233_0527_SLOT16_LEFT_PASS", "original", "noholder"): 180.17834741464424,
        ("62628-233_0527_SLOT16_LEFT_PASS", "ccw90", "exact"): 90.17834725919339,
        ("62628-233_0527_SLOT16_LEFT_PASS", "ccw90", "noholder"): 90.17834778587279,
    }
    rows = []
    for (case_id, orientation, mode), angle in angles.items():
        rows.append({
            "caseId": case_id, "orientation": orientation, "mode": mode,
            "pairedCandidateCount": 1, "pairedAnglesDegrees": [angle],
            "pairedConfirmationModes": [
                gate.CONFIRMATION_MODE if "SLOT20" in case_id else "STRICT_BOTH_CHANNELS"
            ],
            "expectedImageAngleDegrees": 180.0 if orientation == "original" else 90.0,
            "knownNotchLocationConsumed": False,
            "resultSourceMutationPerformed": False,
        })
    return rows


def codes(result: dict) -> set[str]:
    return {row["code"] for row in result["violations"]}


def main() -> int:
    sources = [
        {"caseId": "62628-233_0527_SLOT20_LEFT_HOLD", "bfUnchanged": True, "dfUnchanged": True},
        {"caseId": "62628-233_0527_SLOT16_LEFT_PASS", "bfUnchanged": True, "dfUnchanged": True},
    ]
    passed = gate.evaluate_gate(pass_rows(), MANIFEST, sources, True)
    assert passed["state"] == "PASS_R33ROT1_8_OF_8"
    assert passed["violations"] == []
    assert len(passed["ablationComparisons"]) == 4
    assert len(passed["rotationComparisons"]) == 4
    assert all(row["passed"] for row in passed["ablationComparisons"])
    assert all(row["passed"] for row in passed["rotationComparisons"])

    broken = deepcopy(pass_rows())
    broken[0]["pairedCandidateCount"] = 0
    broken[0]["knownNotchLocationConsumed"] = True
    broken[0]["resultSourceMutationPerformed"] = True
    broken[0]["pairedAnglesDegrees"] = [170.0]
    broken[0]["pairedConfirmationModes"] = ["WRONG_MODE"]
    held_sources = deepcopy(sources)
    held_sources[0]["bfUnchanged"] = False
    held = gate.evaluate_gate(broken, MANIFEST, held_sources, False)
    assert held["state"] == "HOLD_R33ROT1_REGRESSION_GATE"
    expected_codes = {
        "PAIRED_CANDIDATE_COUNT_NOT_ONE",
        "KNOWN_NOTCH_LOCATION_CONSUMED_OR_UNDECLARED",
        "RESULT_SOURCE_MUTATION_NOT_FALSE",
        "POSE_OUTSIDE_ONE_DEGREE",
        "SLOT20_CONFIRMATION_MODE_MISMATCH",
        "EXACT_NOHOLDER_DELTA_EXCEEDS_0_01_DEGREES",
        "CCW90_SHIFT_OUTSIDE_90_PLUS_MINUS_0_01_DEGREES",
        "SOURCE_HASH_CHANGED_OR_UNDECLARED",
        "DETECTOR_HASH_CHANGED",
    }
    assert expected_codes <= codes(held)
    print("PASS_R33ROT1_CONSTRUCTION_2_OF_2")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
