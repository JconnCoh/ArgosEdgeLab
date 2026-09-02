#!/usr/bin/env python3
"""Run the exact 301-case union through R34's conservative ambiguity policy."""

from __future__ import annotations

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import subprocess
import time


R32_RESOLUTION_PASS = "PASS_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR"
R34_SCORE_HOLD = "HOLD_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR_NOT_SCORE_DOMINANT"


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(value: bool, message: str) -> None:
    if not value:
        raise RuntimeError(message)


def validate_case(case: dict, label: str) -> None:
    required = (
        "id", "group", "bf", "df", "bfSha256", "dfSha256",
        "expectedPairedCandidateCount",
    )
    for key in required:
        require(key in case, f"{label} missing {key}")
    require(str(case["id"]).strip() != "", f"{label} id is empty")
    require(str(case["group"]).strip() != "", f"{label} group is empty")
    for channel in ("bf", "df"):
        source = Path(case[channel])
        require(source.is_file(), f"{label} {channel} source absent: {source}")
        digest = str(case[f"{channel}Sha256"]).upper()
        require(len(digest) == 64 and all(c in "0123456789ABCDEF" for c in digest),
                f"{label} {channel} hash is invalid")
        case[f"{channel}Sha256"] = digest
    expected = int(case["expectedPairedCandidateCount"])
    require(expected >= 0, f"{label} expected count is negative")


def execute(case: dict, args, config: dict, output: Path) -> dict:
    ordinal = int(case["ordinal"])
    bf, df = Path(case["bf"]), Path(case["df"])
    case_output = output / f"O{ordinal:03d}"
    job_path = output / "jobs" / f"J{ordinal:03d}.json"
    before_bf, before_df = sha(bf), sha(df)
    require(before_bf == case["bfSha256"] and before_df == case["dfSha256"],
            f"source hash changed: {case['id']}")
    job = {
        "bf": str(bf), "df": str(df),
        "bfSha256": before_bf, "dfSha256": before_df,
        "output": str(case_output), "maximumDimension": args.maximum_dimension,
        "radialEngine": config["radialEngine"],
        "radialEngineSha256": config["radialEngineSha256"],
        "radialParameters": config["radialParameters"],
    }
    job_path.write_text(json.dumps(job, indent=2), encoding="utf-8")
    started = time.monotonic()
    try:
        process = subprocess.run(
            [args.python, "-B", args.detector, "--job", str(job_path)],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
            timeout=args.maximum_per_case_seconds, check=False,
        )
        require(process.returncode == 0, f"detector exit {process.returncode}: {process.stderr[-1000:]}")
        result_path = case_output / "RESULT.json"
        result = read_json(result_path)
        pairs = list(result.get("pairedCandidates", []))
        actual = int(result["pairedCandidateCount"])
        require(actual == len(pairs), f"result pair cardinality inconsistent: {case['id']}")
        after_bf, after_df = sha(bf), sha(df)
        require(after_bf == before_bf and after_df == before_df,
                f"source mutation detected: {case['id']}")
        expected = int(case["expectedPairedCandidateCount"])
        ratio_control = result.get("bf", {}).get("bfShallowDepthRatioNegativeControl")
        multi_pair = result.get("bf", {}).get("multiPairExteriorCleanResolution")
        invariant_failures = []
        if result.get("knownNotchLocationConsumed") is not False:
            invariant_failures.append("known-notch-location contract changed")
        if result.get("sourceMutationPerformed") is not False:
            invariant_failures.append("detector reported source mutation")
        if ordinal == 8:
            ratio_rows = list((ratio_control or {}).get("rows", []))
            if (actual != 0 or len(ratio_rows) != 1
                    or ratio_rows[0].get("shallowModeRatioGateApplies") is not True):
                invariant_failures.append("O008 shallow negative control changed")
        if ordinal == 5:
            if (actual != 2
                    or (multi_pair or {}).get("state") != R34_SCORE_HOLD
                    or (multi_pair or {}).get("strictScoreDominancePassed") is not False
                    or (multi_pair or {}).get("retainedPairCount") != 2):
                invariant_failures.append("O005 frozen ambiguity hold changed")
        if (multi_pair or {}).get("state") == R32_RESOLUTION_PASS:
            if ((multi_pair or {}).get("requiresStrictScoreDominance") is not True
                    or (multi_pair or {}).get("allComparedPairScoresFinite") is not True
                    or (multi_pair or {}).get("strictScoreDominancePassed") is not True
                    or (multi_pair or {}).get("retainedPairCount") != 1):
                invariant_failures.append("R34 score-dominant resolution contract changed")
        if ordinal == 92:
            angle_ok = (actual == 1 and len(pairs) == 1
                        and abs(float(pairs[0]["meanAngleDegrees"]) - 89.68278051376019) <= 1.5)
            if not angle_ok or (multi_pair or {}).get("state") != R32_RESOLUTION_PASS:
                invariant_failures.append("O092 residue-aligned unique-pair control changed")
        if "expectedMeanAngleDegrees" in case:
            angle_ok = (actual == 1 and len(pairs) == 1
                        and abs(float(pairs[0]["meanAngleDegrees"])
                                - float(case["expectedMeanAngleDegrees"]))
                        <= float(case["maximumAngleDeltaDegrees"]))
            mode_ok = (actual == 1 and len(pairs) == 1
                       and pairs[0].get("confirmationMode") == case["expectedConfirmationMode"])
            ratio_rows = list((ratio_control or {}).get("rows", []))
            ratio_ok = (len(ratio_rows) == 1
                        and ratio_rows[0].get("shallowModeRatioGateApplies")
                        is case["expectedShallowModeRatioGateApplies"])
            if not (angle_ok and mode_ok and ratio_ok):
                invariant_failures.append("R34 sentinel identity or mode changed")
        return {
            "ordinal": ordinal, "id": case["id"], "group": case["group"],
            "bfSha256": case["bfSha256"], "dfSha256": case["dfSha256"],
            "expectedPairedCandidateCount": expected,
            "pairedCandidateCount": actual,
            "passedExpectedCardinality": actual == expected and not invariant_failures,
            "invariantFailures": invariant_failures,
            "meanAnglesDegrees": [row.get("meanAngleDegrees") for row in pairs],
            "confirmationModes": [row.get("confirmationMode") for row in pairs],
            "bfShallowDepthRatioNegativeControl": ratio_control,
            "multiPairExteriorCleanResolution": multi_pair,
            "knownNotchLocationConsumed": result.get("knownNotchLocationConsumed"),
            "sourceMutationPerformed": bool(result.get("sourceMutationPerformed")),
            "resultSha256": sha(result_path),
            "elapsedSeconds": round(time.monotonic() - started, 3),
        }
    except Exception as exc:
        try:
            source_mutated = sha(bf) != before_bf or sha(df) != before_df
        except Exception:
            source_mutated = True
        return {
            "ordinal": ordinal, "id": case["id"], "group": case["group"],
            "bfSha256": case["bfSha256"], "dfSha256": case["dfSha256"],
            "expectedPairedCandidateCount": int(case["expectedPairedCandidateCount"]),
            "passedExpectedCardinality": False, "error": str(exc)[:1200],
            "sourceMutationPerformed": source_mutated,
            "elapsedSeconds": round(time.monotonic() - started, 3),
        }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases", required=True)
    parser.add_argument("--cases-sha256", required=True)
    parser.add_argument("--extra-cases", required=True)
    parser.add_argument("--extra-cases-sha256", required=True)
    parser.add_argument("--detector", required=True)
    parser.add_argument("--detector-sha256", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--config-sha256", required=True)
    parser.add_argument("--python", required=True)
    parser.add_argument("--python-sha256", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--workers", type=int, required=True)
    parser.add_argument("--maximum-dimension", type=int, default=2400)
    parser.add_argument("--maximum-per-case-seconds", type=int, default=180)
    args = parser.parse_args()
    require(args.workers == 4, f"workers must be exactly 4, received {args.workers}")
    require(args.maximum_dimension == 2400, "maximum dimension changed")
    require(args.maximum_per_case_seconds == 180, "per-case timeout changed")
    cases_path = Path(args.cases)
    extra_path = Path(args.extra_cases)
    detector_path = Path(args.detector)
    config_path = Path(args.config)
    for dependency in (cases_path, extra_path, detector_path, config_path, Path(args.python)):
        require(dependency.is_file(), f"dependency absent: {dependency}")
    require(sha(cases_path) == args.cases_sha256.upper(), "case manifest changed")
    require(sha(extra_path) == args.extra_cases_sha256.upper(), "extra case manifest changed")
    require(sha(detector_path) == args.detector_sha256.upper(), "detector changed")
    require(sha(config_path) == args.config_sha256.upper(), "config changed")
    require(sha(Path(args.python)) == args.python_sha256.upper(), "python runtime changed")
    base_cases, extra_cases = list(read_json(cases_path)), list(read_json(extra_path))
    require(len(base_cases) == 298, f"base case count changed: {len(base_cases)}")
    require(len(extra_cases) == 3, f"extra case count changed: {len(extra_cases)}")
    for index, case in enumerate(extra_cases):
        for key in ("expectedMeanAngleDegrees", "maximumAngleDeltaDegrees",
                    "expectedConfirmationMode", "expectedShallowModeRatioGateApplies"):
            require(key in case, f"extra case {index} missing {key}")
        require(case["expectedShallowModeRatioGateApplies"] is False,
                f"extra case {index} ratio expectation changed")
    cases = base_cases + extra_cases
    for index, case in enumerate(cases):
        validate_case(case, f"case {index}")
    identities = [str(row["id"]) for row in cases]
    require(len(set(identities)) == len(identities), "case identities are not unique")
    group_counts = Counter(str(row["group"]) for row in cases)
    expected_groups = {
        "FROZEN_R20_CONTROL": 10,
        "R20_CURRENT_HOLD": 22,
        "SAME_SCAN_PASS_CONTROL": 1,
        "CURRENT_RECIPE_SMOKE_PATTERNEDFRONT": 216,
        "CURRENT_RECIPE_SMOKE_UNPATTERNEDFRONT": 49,
        "R33_SENTINEL": 3,
    }
    require(dict(group_counts) == expected_groups,
            f"case groups changed: {dict(group_counts)}")
    for ordinal, case in enumerate(cases):
        case["ordinal"] = ordinal
    config = read_json(config_path)
    for key in ("radialEngine", "radialEngineSha256", "radialParameters"):
        require(key in config, f"config missing {key}")
    output = Path(args.output)
    require(not output.exists(), "create-new output exists")
    output.mkdir(parents=True)
    (output / "jobs").mkdir()
    frozen_path = output / "FROZEN_CASES.json"
    frozen_path.write_text(json.dumps(cases, indent=2), encoding="utf-8")
    started = time.monotonic()
    rows = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(execute, case, args, config, output) for case in cases]
        for future in as_completed(futures):
            rows.append(future.result())
    rows.sort(key=lambda row: row["ordinal"])
    mismatches = [row for row in rows if not row["passedExpectedCardinality"]]
    summary = {
        "schema": "argos_r34_union_result_v1",
        "state": "PASS_R34_UNION_301_OF_301" if not mismatches else "HOLD_R34_UNION_MISMATCH",
        "caseCount": len(rows), "outcomeMismatchCount": len(mismatches),
        "invariantMismatchCount": sum(bool(row.get("invariantFailures")) for row in rows),
        "outcomeMismatches": mismatches, "groupCounts": dict(group_counts), "results": rows,
        "casesSha256": sha(cases_path), "frozenCasesSha256": sha(frozen_path),
        "extraCasesSha256": sha(extra_path), "detectorSha256": sha(detector_path),
        "configSha256": sha(config_path), "pythonSha256": sha(Path(args.python)),
        "elapsedSeconds": round(time.monotonic() - started, 3),
        "scoreDominantResolutionCount": sum(
            (row.get("multiPairExteriorCleanResolution") or {}).get("state") == R32_RESOLUTION_PASS
            for row in rows
        ),
        "scoreDominanceHoldCount": sum(
            (row.get("multiPairExteriorCleanResolution") or {}).get("state") == R34_SCORE_HOLD
            for row in rows
        ),
        "sourceMutationPerformed": any(row.get("sourceMutationPerformed") is True for row in rows),
        "sourceDeletionPerformed": False,
        "existingTaskOrProcessActionPerformed": False,
        "providerActivationPerformed": False, "holdsAutomaticallyCleared": False,
        "reviewOnly": True, "trainingEligible": False,
        "xmlEligible": False, "productionEligible": False,
    }
    summary_path = output / "SUMMARY.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps({
        "state": summary["state"], "caseCount": len(rows),
        "outcomeMismatchCount": len(mismatches), "summarySha256": sha(summary_path),
    }, separators=(",", ":")))
    return 0 if not mismatches else 2


if __name__ == "__main__":
    raise SystemExit(main())
