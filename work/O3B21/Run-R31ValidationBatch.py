#!/usr/bin/env python3
"""Run frozen controls plus every current PatternedFront/UnpatternedFront pair under R31."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import time


R29_RUNNER_SHA256 = "F0296EDEC3845C1D4833DCA06588BA6D8D225CD907A1A12586E0DB08CDEF6F2B"


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_r29_runner():
    path = Path(__file__).with_name("Run-R29ValidationBatch.py")
    require(path.is_file() and sha(path) == R29_RUNNER_SHA256, "Frozen R29 batch runner changed")
    spec = importlib.util.spec_from_file_location("argos_r29_batch_frozen_for_r31", path)
    require(spec is not None and spec.loader is not None, "Frozen R29 batch runner could not be loaded")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


R29_RUNNER = load_r29_runner()


def build_cases(contract: dict, frozen_path: Path) -> list[dict]:
    frozen_root = Path(contract["frozenR20"]["root"])
    pins = {
        frozen_root / "SUMMARY.json": contract["frozenR20"]["summarySha256"],
        frozen_root / "RESULTS.csv": contract["frozenR20"]["resultsCsvSha256"],
        frozen_root / "FAILURES.json": contract["frozenR20"]["failuresSha256"],
    }
    for path, expected in pins.items():
        require(path.is_file() and sha(path) == expected, f"Frozen R20 evidence changed: {path}")
    cases = []
    seen = set()
    for source in read_json(frozen_path)["cases"]:
        cases.append({
            "id": source["id"], "group": "FROZEN_R20_CONTROL",
            "bf": source["bf"], "bfSha256": source["bfSha256"].upper(),
            "df": source["df"], "dfSha256": source["dfSha256"].upper(),
        })
        seen.add(source["id"])
    for failure in sorted(read_json(frozen_root / "FAILURES.json")["rows"], key=lambda row: row["identity"]):
        item = read_json(Path(failure["diagnosticRoot"]).parent / "result.json")
        identity = item["identity"]
        if identity in seen:
            continue
        cases.append({
            "id": identity, "group": "R20_CURRENT_HOLD",
            "bf": item["bf"]["path"], "bfSha256": item["bf"]["sha256"].upper(),
            "df": item["df"]["path"], "dfSha256": item["df"]["sha256"].upper(),
        })
        seen.add(identity)
    require(len(cases) == 32, f"Frozen batch cardinality changed: {len(cases)}")
    expected = contract["frozenR20"]["expectedPairedCandidateCounts"]
    require(len(expected) == 32, "Frozen expectation cardinality changed")
    for ordinal, case in enumerate(cases):
        case["expectedPairedCandidateCount"] = int(expected[ordinal])

    control = contract["sameScanControl"]
    cases.append({
        "id": control["id"], "group": "SAME_SCAN_PASS_CONTROL",
        "bf": control["bf"], "bfSha256": control["bfSha256"].upper(),
        "df": control["df"], "dfSha256": control["dfSha256"].upper(),
        "expectedPairedCandidateCount": int(control["expectedPairedCandidateCount"]),
    })

    inventory_contract = contract["currentInventory"]
    inventory_path = Path(inventory_contract["path"])
    require(inventory_path.is_file() and sha(inventory_path) == inventory_contract["sha256"],
            "Current inventory changed")
    inventory = read_json(inventory_path)
    require(int(inventory["pairCount"]) == int(inventory_contract["pairCount"]),
            "Current inventory cardinality changed")
    counts = {}
    current_rows = []
    for prefix in inventory_contract["prefixes"]:
        rows = sorted(
            (row for row in inventory["pairs"] if row["identity"].lower().startswith(prefix.lower())),
            key=lambda row: row["identity"],
        )
        require(rows, f"Current recipe prefix is empty: {prefix}")
        counts[prefix.rstrip("\\")] = len(rows)
        current_rows.extend(rows)
    require(len({row["identity"] for row in current_rows}) == len(current_rows),
            "Current recipe identities are not unique")
    require(int(inventory_contract["minimumCombinedCount"]) <= len(current_rows)
            <= int(inventory_contract["maximumCombinedCount"]),
            f"Current recipe combined cardinality outside frozen bound: {len(current_rows)}")
    require(33 + len(current_rows) <= int(contract["maximumTotalCaseCount"]),
            "R31 validation maximum total case count exceeded")
    for source in current_rows:
        prefix = "PATTERNEDFRONT" if source["identity"].lower().startswith("patternedfront\\") else "UNPATTERNEDFRONT"
        cases.append({
            "id": source["identity"], "group": "CURRENT_RECIPE_SMOKE_" + prefix,
            "bf": source["bf"], "df": source["df"],
            "bfSha256": sha(Path(source["bf"])), "dfSha256": sha(Path(source["df"])),
            "expectedPairedCandidateCount": int(inventory_contract["expectedPairedCandidateCount"]),
        })
    require(len({case["id"] for case in cases}) == len(cases), "Validation identities are not unique")
    for ordinal, case in enumerate(cases):
        case["ordinal"] = ordinal
    return cases, counts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", required=True)
    parser.add_argument("--frozen-cases", required=True)
    parser.add_argument("--detector", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--python", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--maximum-dimension", type=int, required=True)
    parser.add_argument("--maximum-per-case-seconds", type=int, required=True)
    args = parser.parse_args()
    contract = read_json(Path(args.contract))
    output = Path(args.output)
    require(not output.exists(), f"Create-new output exists: {output}")
    output.mkdir(parents=True)
    cases, counts = build_cases(contract, Path(args.frozen_cases))
    (output / "FROZEN_CASES.json").write_text(json.dumps(cases, indent=2), encoding="utf-8")
    config = read_json(Path(args.config))
    started = time.monotonic()
    results = []
    with ThreadPoolExecutor(max_workers=int(contract["maximumConcurrentChildren"])) as pool:
        futures = {pool.submit(R29_RUNNER.execute, case, args, config): case for case in cases}
        for future in as_completed(futures):
            results.append(future.result())
    results.sort(key=lambda row: row["ordinal"])
    mismatches = [{"ordinal": row["ordinal"], "id": row["id"],
                   "expected": row["expectedPairedCandidateCount"], "actual": row["pairedCandidateCount"]}
                  for row in results if not row["passedExpectedCardinality"]]
    summary = {
        "schema": "argos_o3b21_r31val1_batched_result_v1",
        "state": "PASS_R31VAL1_ALL_EXPECTED_OUTCOMES" if not mismatches else "HOLD_R31VAL1_OUTCOME_MISMATCH",
        "outputRoot": str(output), "caseCount": len(results), "frozenCaseCount": 32,
        "sameScanControlCount": 1, "currentPatternedFrontCount": counts["PatternedFront"],
        "currentUnpatternedFrontCount": counts["UnpatternedFront"],
        "currentRecipeCount": counts["PatternedFront"] + counts["UnpatternedFront"],
        "outcomeMismatchCount": len(mismatches), "outcomeMismatches": mismatches,
        "elapsedSeconds": round(time.monotonic() - started, 3), "results": results,
        "sourceMutationPerformed": False, "sourceDeletionPerformed": False,
        "existingTaskOrProcessActionPerformed": False, "providerActivationPerformed": False,
        "holdsAutomaticallyCleared": False, "reviewOnly": True, "trainingEligible": False,
        "xmlEligible": False, "productionEligible": False,
    }
    summary_path = output / "SUMMARY.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
