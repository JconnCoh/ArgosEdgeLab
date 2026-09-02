#!/usr/bin/env python3
"""Focused fail-closed tests for the exact frozen-953 selection wrapper."""

from __future__ import annotations

import copy
import importlib.util
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("Run-R32Frozen953Corpus.py")
spec = importlib.util.spec_from_file_location("argos_r32_frozen_953", MODULE_PATH)
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def expect_failure(action, text: str) -> None:
    try:
        action()
    except RuntimeError as exc:
        assert text in str(exc), (text, str(exc))
    else:
        raise AssertionError(f"Expected failure containing: {text}")


def main() -> None:
    excluded = [f"PatternedFront\\Lot_New\\Scan\\Slot{i:02d}|BACK" for i in range(1, 26)]
    retained = [f"UnpatternedFront\\Lot_Frozen\\Scan\\Slot{i:04d}|BACK" for i in range(1, 954)]
    identities = retained + excluded
    pairs = [
        {"identity": identity, "bf": f"D:/KLARFExport/{index}/bf.bmp", "df": f"D:/KLARFExport/{index}/df.bmp"}
        for index, identity in enumerate(identities)
    ]
    contract = {
        "currentPairCount": 978,
        "expectedSourceProblemCount": 0,
        "expectedBackPairCount": 953,
        "excludedAddedIdentities": excluded,
    }
    pinned = [module.canonical(row) for row in pairs]

    selected = module.select_exact(copy.deepcopy(pairs), [], contract, pinned)
    assert len(selected) == 953
    assert {row["identity"] for row in selected} == set(retained)

    expect_failure(lambda: module.select_exact(pairs[:-1], [], contract, pinned), "Current discovery count changed")
    expect_failure(lambda: module.select_exact(pairs, ["problem"], contract, pinned), "source problems changed")
    changed = copy.deepcopy(pairs)
    changed[0]["bf"] = "D:/KLARFExport/changed/bf.bmp"
    expect_failure(lambda: module.select_exact(changed, [], contract, pinned), "no longer matches pinned inventory")
    missing_added = copy.deepcopy(pairs)
    missing_added[-1]["identity"] = "PatternedFront\\Lot_Other\\Scan\\Slot01|BACK"
    changed_pinned = [module.canonical(row) for row in missing_added]
    expect_failure(lambda: module.select_exact(missing_added, [], contract, changed_pinned), "Excluded added-identity set changed")
    duplicate_contract = copy.deepcopy(contract)
    duplicate_contract["excludedAddedIdentities"][-1] = duplicate_contract["excludedAddedIdentities"][0]
    expect_failure(lambda: module.select_exact(pairs, [], duplicate_contract, pinned), "cardinality changed")

    assert module.normalized_path("D:/A/B/") == "d:\\a\\b"
    print("PASS_R32_FROZEN_953_SELECTION_7_OF_7")


if __name__ == "__main__":
    main()
