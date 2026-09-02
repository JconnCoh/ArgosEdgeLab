#!/usr/bin/env python3
"""Run frozen R2 corpus semantics on the exact current 953-identity predecessor subset."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import sys


R2_SHA256 = "20102DD8502EEC798BE1199B1B074922D24A8AE8343A180762EA1CD78BB8EFF6"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_r2():
    path = Path(__file__).with_name("Run-OpenCvKlarfCorpusR2.py")
    require(path.is_file() and sha(path) == R2_SHA256, "Frozen R2 corpus runner changed")
    spec = importlib.util.spec_from_file_location("argos_corpus_r2_frozen_for_r32", path)
    require(spec is not None and spec.loader is not None, "Frozen R2 runner could not be loaded")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def normalized_path(value) -> str:
    return str(value).replace("/", "\\").rstrip("\\").lower()


def canonical(row: dict) -> tuple[str, str, str]:
    return (
        str(row["identity"]).upper(),
        normalized_path(row["bf"]),
        normalized_path(row["df"]),
    )


def backside_only(pairs: list[dict], problems: list[dict]) -> tuple[list[dict], list[dict]]:
    """Keep unrelated frontside arrivals outside the frozen backside gate."""
    return (
        [row for row in pairs if str(row.get("side", "")).upper() == "BACK"],
        [row for row in problems if str(row.get("side", "")).upper() == "BACK"],
    )


def select_exact(pairs: list[dict], problems: list, contract: dict, pinned_rows: list[tuple[str, str, str]]) -> list[dict]:
    """Return only the frozen 953 identities after exact current-inventory verification."""
    require(len(pairs) == int(contract["currentPairCount"]), "Current discovery count changed")
    require(len(problems) == int(contract["expectedSourceProblemCount"]), "Current discovery source problems changed")
    require(sorted(canonical(row) for row in pairs) == sorted(pinned_rows), "Current discovery no longer matches pinned inventory")
    excluded_values = [str(value).upper() for value in contract["excludedAddedIdentities"]]
    excluded = set(excluded_values)
    require(len(excluded_values) == 25 and len(excluded) == 25, "Excluded added-identity cardinality changed")
    observed_excluded = {str(row["identity"]).upper() for row in pairs if str(row["identity"]).upper() in excluded}
    require(observed_excluded == excluded, "Excluded added-identity set changed")
    selected = [row for row in pairs if str(row["identity"]).upper() not in excluded]
    require(len(selected) == int(contract["expectedBackPairCount"]), "Exact frozen-subset cardinality changed")
    return selected


def main() -> int:
    marker = "--selection-contract"
    require(marker in sys.argv, "Selection contract argument absent")
    index = sys.argv.index(marker)
    require(index + 1 < len(sys.argv), "Selection contract value absent")
    contract_path = Path(sys.argv[index + 1])
    del sys.argv[index:index + 2]
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    inventory_path = Path(contract["currentInventoryPath"])
    require(
        inventory_path.is_file() and sha(inventory_path) == contract["currentInventorySha256"],
        "Pinned current inventory changed",
    )
    pinned_inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
    require(int(pinned_inventory["pairCount"]) == int(contract["currentPairCount"]), "Pinned inventory count changed")
    require(len(pinned_inventory.get("sourceProblems", [])) == int(contract["expectedSourceProblemCount"]), "Pinned inventory source problems changed")
    pinned_rows = sorted(canonical(row) for row in pinned_inventory["pairs"])
    excluded = {str(value).upper() for value in contract["excludedAddedIdentities"]}
    require(len(excluded) == 25, "Excluded added-identity cardinality changed")

    r2 = load_r2()
    original_discover = r2.discover_pairs

    def discover_exact(root: Path, cap: int):
        pairs, problems = original_discover(root, cap)
        pairs, problems = backside_only(pairs, problems)
        return select_exact(pairs, problems, contract, pinned_rows), problems

    r2.discover_pairs = discover_exact
    return int(r2.main())


if __name__ == "__main__":
    raise SystemExit(main())
