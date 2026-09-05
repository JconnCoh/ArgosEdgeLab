#!/usr/bin/env python3
"""Focused checks for the exact-truth R18T1 regrade."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
import tempfile
from pathlib import Path


def load_module(path: Path):
    spec = importlib.util.spec_from_file_location("r18ur_regrade", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def expect_value_error(action, expected_fragment: str) -> None:
    try:
        action()
    except ValueError as exc:
        if expected_fragment not in str(exc):
            raise AssertionError(f"Unexpected failure: {exc}") from exc
    else:
        raise AssertionError(f"Expected ValueError containing {expected_fragment!r}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--result-zip", required=True, type=Path)
    parser.add_argument("--expected-output", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    module = load_module(
        project / "work/OPENCV_SCRIBE_R18UR/Regrade-R18T1AgainstExactTruth.py"
    )
    result = module.build(project, args.result_zip)
    assert result["state"] == "FAIL_R18T1_ONE_WRONG_CLAIMED_PASS_19_EXACT_IMAGE_FIRST"
    summary = result["summary"]
    assert summary == {
        "configuredCases": 20,
        "exactTruthResolvedCases": 20,
        "metadataTruthCases": 19,
        "operatorConfirmedSourceHashBoundTruthCases": 1,
        "imageFirstExactCases": 19,
        "imageFirstWrongCases": 1,
        "proposedExactCases": 19,
        "proposedWrongCases": 1,
        "claimedPassCases": 18,
        "claimedHoldCases": 2,
        "claimedPassAndExactCases": 17,
        "claimedPassButWrongCases": 1,
        "exactButHeldCases": 2,
        "regradeStateCounts": {
            "OCR_EXACT_BUT_WORKFLOW_HELD": 2,
            "OCR_EXACT_REVIEW_ONLY": 17,
            "OCR_WRONG_DESPITE_CLAIMED_PASS": 1,
        },
    }
    slot21 = result["slot21RootFailureEvidence"]
    assert slot21["truth"] == "13HFX135SUE3"
    assert slot21["bfDarkForward"]["imageFirstString"] == "11HFX135SUE3"
    assert slot21["bfDarkForward"]["mismatches"] == [
        {"position1Based": 2, "truth": "3", "candidate": "1"}
    ]
    assert slot21["dfBrightForward"]["imageFirstString"] == "13HFX135SUE4"
    assert slot21["dfBrightForward"]["mismatches"] == [
        {"position1Based": 12, "truth": "3", "candidate": "4"}
    ]
    assert result["invariants"]["resultClaimedPassUsedAsTruth"] is False
    assert result["invariants"]["checksumUsedAsTruthAuthority"] is False
    assert result["invariants"]["imageBytesDecoded"] is False
    expect_value_error(
        lambda: module.operator_confirmed_source_hash_bound_truth(
            [
                {
                    "truth": "13DCK060SUF5",
                    "sourceSha256": "A" * 64,
                    "operatorConfirmed": False,
                }
            ],
            "A" * 64,
            "negative-control",
        ),
        "not explicitly operator-confirmed",
    )
    confirmed_truth, confirmed_evidence = module.operator_confirmed_source_hash_bound_truth(
        [
            {
                "truth": "13DCK060SUF5",
                "sourceSha256": "A" * 64,
                "operatorConfirmed": True,
            }
        ],
        "A" * 64,
        "positive-control",
    )
    assert confirmed_truth == "13DCK060SUF5"
    assert confirmed_evidence == {"supplementalReferenceCount": 1}

    with tempfile.TemporaryDirectory(prefix="r18ur_regrade_") as temp_root:
        first = Path(temp_root) / "first.json"
        second = Path(temp_root) / "second.json"
        module.write_new(first, result)
        module.write_new(second, module.build(project, args.result_zip))
        assert first.read_bytes() == second.read_bytes()
        try:
            module.write_new(first, result)
        except FileExistsError:
            pass
        else:
            raise AssertionError("R18UR durable output must use create-new semantics.")

    if args.expected_output:
        expected = json.loads(args.expected_output.read_text(encoding="utf-8"))
        if expected != result:
            raise AssertionError("R18UR output does not reproduce from frozen inputs.")
    print("PASS_R18UR_FOCUSED_EXACT_TRUTH_REGRADE assertions=35")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
