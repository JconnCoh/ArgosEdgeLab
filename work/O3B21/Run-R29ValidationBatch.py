#!/usr/bin/env python3
"""Run one frozen R29 validation batch without changing source or provider state."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import time


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


def compact_channel(channel: dict, full: bool) -> dict:
    row = {
        "candidateCount": channel.get("candidateCount"),
        "candidates": channel.get("candidates") if full else None,
        "holderExclusion": {
            "state": channel.get("holderExclusion", {}).get("state"),
            "maskSampleCount": channel.get("holderExclusion", {}).get("maskSampleCount"),
            "spans": channel.get("holderExclusion", {}).get("spans"),
        },
        "backsideTraceQualification": channel.get("backsideTraceQualification"),
    }
    for name in ("dfGeometryBfFullPerimeterCompensation", "bfNearStrictDfBroadCompensation",
                 "bfShallowDepthRatioNegativeControl"):
        if name in channel:
            row[name] = channel[name]
    return row


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
    for prefix in inventory_contract["prefixes"]:
        rows = sorted((row for row in inventory["pairs"] if row["identity"].lower().startswith(prefix.lower())),
                      key=lambda row: row["identity"])
        require(len(rows) >= 3, f"Current recipe prefix has fewer than three pairs: {prefix}")
        indices = (0, (len(rows) - 1) // 2, len(rows) - 1)
        require(len(set(indices)) == 3, f"Current recipe selection is not unique: {prefix}")
        for index in indices:
            source = rows[index]
            cases.append({
                "id": source["identity"], "group": "CURRENT_RECIPE_SMOKE_" + prefix.rstrip("\\").upper(),
                "bf": source["bf"], "df": source["df"],
                "bfSha256": sha(Path(source["bf"])), "dfSha256": sha(Path(source["df"])),
                "expectedPairedCandidateCount": int(inventory_contract["expectedPairedCandidateCount"]),
            })
    require(len(cases) == 39, f"Validation case cardinality changed: {len(cases)}")
    for ordinal, case in enumerate(cases):
        case["ordinal"] = ordinal
    return cases


def execute(case: dict, args, config: dict) -> dict:
    bf = Path(case["bf"])
    df = Path(case["df"])
    require(bf.is_file() and df.is_file(), f"Source absent: {case['id']}")
    before_bf, before_df = sha(bf), sha(df)
    require(before_bf == case["bfSha256"] and before_df == case["dfSha256"],
            f"Source hash changed: {case['id']}")
    case_root = Path(args.output) / f"O{case['ordinal']:02d}"
    job_path = Path(args.output) / f"J{case['ordinal']:02d}.json"
    job = {
        "bf": str(bf), "df": str(df), "bfSha256": before_bf, "dfSha256": before_df,
        "output": str(case_root), "radialEngine": config["radialEngine"],
        "radialEngineSha256": config["radialEngineSha256"],
        "radialParameters": config["radialParameters"], "maximumDimension": args.maximum_dimension,
    }
    job_path.write_text(json.dumps(job, indent=2), encoding="utf-8")
    started = time.monotonic()
    completed = subprocess.run(
        [args.python, "-B", args.detector, "--job", str(job_path)],
        cwd=str(Path(args.detector).parent), capture_output=True, text=True,
        timeout=args.maximum_per_case_seconds, check=False,
    )
    require(completed.returncode == 0, f"Detector failed {case['id']}: {completed.stderr[-1000:]}")
    result_path = case_root / "RESULT.json"
    require(result_path.is_file(), f"Result absent: {case['id']}")
    detector = read_json(result_path)
    after_bf, after_df = sha(bf), sha(df)
    require(after_bf == before_bf and after_df == before_df, f"Source mutation detected: {case['id']}")
    full = case["ordinal"] in (6, 32) or case["group"].startswith("CURRENT_RECIPE_SMOKE")
    actual = int(detector["pairedCandidateCount"])
    return {
        "ordinal": case["ordinal"], "id": case["id"], "group": case["group"],
        "expectedPairedCandidateCount": case["expectedPairedCandidateCount"],
        "pairedCandidateCount": actual, "passedExpectedCardinality": actual == case["expectedPairedCandidateCount"],
        "pairedCandidates": detector.get("pairedCandidates"),
        "bfSha256": before_bf, "dfSha256": before_df,
        "elapsedSeconds": round(time.monotonic() - started, 3),
        "bf": compact_channel(detector["bf"], full), "df": compact_channel(detector["df"], full),
        "knownNotchLocationConsumed": detector.get("knownNotchLocationConsumed"),
        "sourceMutationPerformed": detector.get("sourceMutationPerformed"),
    }


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
    cases = build_cases(contract, Path(args.frozen_cases))
    (output / "FROZEN_CASES.json").write_text(json.dumps(cases, indent=2), encoding="utf-8")
    config = read_json(Path(args.config))
    started = time.monotonic()
    results = []
    with ThreadPoolExecutor(max_workers=int(contract["maximumConcurrentChildren"])) as pool:
        futures = {pool.submit(execute, case, args, config): case for case in cases}
        for future in as_completed(futures):
            results.append(future.result())
    results.sort(key=lambda row: row["ordinal"])
    mismatches = [{"ordinal": row["ordinal"], "id": row["id"],
                   "expected": row["expectedPairedCandidateCount"], "actual": row["pairedCandidateCount"]}
                  for row in results if not row["passedExpectedCardinality"]]
    summary = {
        "schema": "argos_o3b21_r29val1_batched_result_v1",
        "state": "PASS_R29VAL1_ALL_EXPECTED_OUTCOMES" if not mismatches else "HOLD_R29VAL1_OUTCOME_MISMATCH",
        "outputRoot": str(output), "caseCount": len(results), "frozenCaseCount": 32,
        "sameScanControlCount": 1, "currentPatternedFrontSmokeCount": 3,
        "currentUnpatternedFrontSmokeCount": 3, "outcomeMismatchCount": len(mismatches),
        "outcomeMismatches": mismatches, "elapsedSeconds": round(time.monotonic() - started, 3),
        "results": results, "sourceMutationPerformed": False, "sourceDeletionPerformed": False,
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
