#!/usr/bin/env python3
"""Focused local tests for the R18X exact-scribe lineage crosswalk."""

from __future__ import annotations

import argparse
import copy
import importlib.util
import json
import sys
import tempfile
from pathlib import Path


def load_module(path: Path):
    spec = importlib.util.spec_from_file_location("r18x_crosswalk", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def expect_failure(action, expected_fragment: str) -> None:
    try:
        action()
    except ValueError as exc:
        if expected_fragment not in str(exc):
            raise AssertionError(f"Unexpected failure: {exc}") from exc
    else:
        raise AssertionError(f"Expected failure containing {expected_fragment!r}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--expected-output", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    module = load_module(project / "work/OPENCV_SCRIBE_R18X/Build-R18XLineageCrosswalk.py")
    result = module.build(project)
    assert result["state"] == "PASS_R18X_EXACT_SCRIBE_LINEAGE_REKEY_CARDINALITY_PRESERVED"
    summary = result["summary"]
    assert summary["baseReferenceRows"] == 456
    assert summary["supplementalReferenceRows"] == 9
    assert summary["verifiedReferenceRows"] == 465
    assert summary["baseExactScribeLineages"] == 34
    assert summary["supplementalExactScribeLineages"] == 7
    assert summary["combinedExactScribeLineages"] == 41
    assert summary["exactRosterMatchedLineages"] == 26
    assert summary["exactMetadataMatchedLineages"] == 21
    assert summary["exactRosterAndMetadataMatchedLineages"] == 18
    assert summary["coveredCharacters"] == "0123456789ABCEFGPSU"
    assert summary["sparseCharacters"] == "DHJKLMNQRTWXZ"
    assert summary["unobservedCharacters"] == "IOVY"
    assert result["currentSlot21Separation"] == {
        "legacyRawIdentity": "62546_481_SLOT21",
        "legacyHumanConfirmedTruth": "2969P012FEB0",
        "currentAcquisitionKey": "62546-481_20260707164232_SLOT21",
        "currentExactMesTruth": "13HFX135SUE3",
        "state": "PASS_DISTINCT_PHYSICAL_LINEAGES_NOT_ALIASED_BY_REUSED_LOT_SLOT",
    }
    assert all(
        row["legacyPhysicalIdentityLineageCount"] == row["exactScribeLineageCount"]
        for row in result["coverage"]
    )
    assert result["invariants"]["checksumUsedAsTruthOrDecisionAuthority"] is False
    assert result["invariants"]["trainingAuthorized"] is False

    base_path = project / module.BASE_RELATIVE
    base_manifest = module.load_json(base_path)
    bad_base = copy.deepcopy(base_manifest)
    repeated = [
        row for row in bad_base["references"]
        if row["physicalIdentity"] == "62627_140_SLOT21"
    ]
    assert len(repeated) == 24
    repeated[12]["label"] = "9"
    expect_failure(
        lambda: module.derive_base_lineages(bad_base, base_path),
        "Repeated base sequences disagree",
    )

    supplemental_path = project / module.SUPPLEMENTAL_RELATIVE
    supplemental_manifest = module.load_json(supplemental_path)
    bad_supplemental = copy.deepcopy(supplemental_manifest)
    bad_supplemental["references"][0]["position"] = 1
    expect_failure(
        lambda: module.derive_supplemental_lineages(bad_supplemental, supplemental_path),
        "Supplemental label/position mismatch",
    )

    with tempfile.TemporaryDirectory(prefix="r18x_crosswalk_") as temp_root:
        first = Path(temp_root) / "first.json"
        second = Path(temp_root) / "second.json"
        module.write_new(first, result)
        module.write_new(second, module.build(project))
        assert first.read_bytes() == second.read_bytes()
        try:
            module.write_new(first, result)
        except FileExistsError:
            pass
        else:
            raise AssertionError("R18X durable output must use create-new semantics.")

    if args.expected_output:
        expected = json.loads(args.expected_output.read_text(encoding="utf-8"))
        if expected != result:
            raise AssertionError("R18X output does not reproduce from frozen inputs.")
    print("PASS_R18X_FOCUSED_LOCAL_REHEARSAL assertions=30")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
