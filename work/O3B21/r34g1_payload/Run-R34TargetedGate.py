#!/usr/bin/env python3
"""Run the exact nine-case R34 gate from the frozen R33U2 job set."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import subprocess
import time


ORDINALS = (5, 8, 92, 93, 236, 258, 298, 299, 300)
EXPECTED_COUNTS = {5: 2, 8: 0, 92: 1, 93: 1, 236: 1, 258: 1,
                   298: 1, 299: 1, 300: 1}
EXPECTED_GROUPS = {
    5: "FROZEN_R20_CONTROL",
    8: "FROZEN_R20_CONTROL",
    92: "CURRENT_RECIPE_SMOKE_PATTERNEDFRONT",
    93: "CURRENT_RECIPE_SMOKE_PATTERNEDFRONT",
    236: "CURRENT_RECIPE_SMOKE_PATTERNEDFRONT",
    258: "CURRENT_RECIPE_SMOKE_UNPATTERNEDFRONT",
    298: "R33_SENTINEL",
    299: "R33_SENTINEL",
    300: "R33_SENTINEL",
}
R32_PASS = "PASS_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR"
R34_HOLD = "HOLD_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR_NOT_SCORE_DOMINANT"
LOCAL_PROMINENCE = "DF_STRONG_MORPHOLOGY_ANCHORED_BF_LOCAL_PROMINENCE_APPEARANCE"
SENTINEL_ANGLES = {
    298: 89.73126526163422,
    299: 89.99985223452285,
    300: 89.6831921685261,
}
JOB_KEYS = {
    "bf", "df", "bfSha256", "dfSha256", "output", "maximumDimension",
    "radialEngine", "radialEngineSha256", "radialParameters",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def same_path(first, second) -> bool:
    return str(Path(first)).replace("/", "\\").casefold() == \
        str(Path(second)).replace("/", "\\").casefold()


def ratio_gate(result: dict):
    rows = list((result.get("bf", {}).get("bfShallowDepthRatioNegativeControl")
                 or {}).get("rows", []))
    return rows[0].get("shallowModeRatioGateApplies") if len(rows) == 1 else None


def validate_result(ordinal: int, result: dict) -> list[str]:
    failures = []
    pairs = list(result.get("pairedCandidates", []))
    actual = int(result.get("pairedCandidateCount", -1))
    if actual != len(pairs) or actual != EXPECTED_COUNTS[ordinal]:
        failures.append("paired-candidate count changed")
    if result.get("knownNotchLocationConsumed") is not False:
        failures.append("known-notch location was consumed")
    if result.get("sourceMutationPerformed") is not False:
        failures.append("detector reported source mutation")

    diagnostic = result.get("bf", {}).get("multiPairExteriorCleanResolution") or {}
    if ordinal == 5:
        if (diagnostic.get("state") != R34_HOLD
                or diagnostic.get("strictScoreDominancePassed") is not False
                or int(diagnostic.get("retainedPairCount", -1)) != 2):
            failures.append("O005 frozen ambiguity hold changed")
    if ordinal in (92, 93, 236, 258):
        if (diagnostic.get("state") != R32_PASS
                or diagnostic.get("requiresStrictScoreDominance") is not True
                or diagnostic.get("allComparedPairScoresFinite") is not True
                or diagnostic.get("strictScoreDominancePassed") is not True
                or int(diagnostic.get("retainedPairCount", -1)) != 1):
            failures.append("score-dominant R32 resolution changed")
    if ordinal == 8 and ratio_gate(result) is not True:
        failures.append("O008 shallow-depth ratio control changed")
    if ordinal in SENTINEL_ANGLES:
        if (len(pairs) != 1
                or float(pairs[0].get("meanAngleDegrees", float("nan")))
                != SENTINEL_ANGLES[ordinal]
                or pairs[0].get("confirmationMode") != LOCAL_PROMINENCE
                or ratio_gate(result) is not False):
            failures.append("R33 local-prominence sentinel changed")
    return failures


def execute(case: dict, source_job: dict, args, output: Path) -> dict:
    ordinal = int(case["ordinal"])
    bf, df = Path(source_job["bf"]), Path(source_job["df"])
    before_bf, before_df = sha(bf), sha(df)
    started = time.monotonic()
    row = {
        "ordinal": ordinal,
        "id": case["id"],
        "group": case["group"],
        "expectedPairedCandidateCount": EXPECTED_COUNTS[ordinal],
        "bfSha256Before": before_bf,
        "dfSha256Before": before_df,
        "sourceJobSha256": case["sourceJobSha256"],
    }
    try:
        require(before_bf == str(source_job["bfSha256"]).upper(),
                f"O{ordinal:03d} BF source hash changed")
        require(before_df == str(source_job["dfSha256"]).upper(),
                f"O{ordinal:03d} DF source hash changed")
        case_output = output / f"O{ordinal:03d}"
        derived_job_path = output / "jobs" / f"J{ordinal:03d}.json"
        derived_job = dict(source_job)
        derived_job["output"] = str(case_output)
        derived_job_path.write_text(json.dumps(derived_job, indent=2), encoding="utf-8")
        require(read_json(derived_job_path) == derived_job,
                f"O{ordinal:03d} derived job serialization changed")
        completed = subprocess.run(
            [args.python, "-B", args.detector, "--job", str(derived_job_path)],
            cwd=str(Path(args.detector).parent), stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE, text=True,
            timeout=args.maximum_per_case_seconds, check=False,
        )
        require(completed.returncode == 0,
                f"detector exit {completed.returncode}: {completed.stderr[-1000:]}")
        result_path = case_output / "RESULT.json"
        require(result_path.is_file(), f"O{ordinal:03d} result absent")
        result = read_json(result_path)
        after_bf, after_df = sha(bf), sha(df)
        failures = validate_result(ordinal, result)
        if after_bf != before_bf or after_df != before_df:
            failures.append("source hashes changed after execution")
        pairs = list(result.get("pairedCandidates", []))
        row.update({
            "pairedCandidateCount": int(result.get("pairedCandidateCount", -1)),
            "meanAnglesDegrees": [pair.get("meanAngleDegrees") for pair in pairs],
            "confirmationModes": [pair.get("confirmationMode") for pair in pairs],
            "shallowModeRatioGateApplies": ratio_gate(result),
            "multiPairExteriorCleanResolution":
                result.get("bf", {}).get("multiPairExteriorCleanResolution"),
            "knownNotchLocationConsumed": result.get("knownNotchLocationConsumed"),
            "detectorReportedSourceMutation": result.get("sourceMutationPerformed"),
            "bfSha256After": after_bf,
            "dfSha256After": after_df,
            "sourceHashesUnchanged": after_bf == before_bf and after_df == before_df,
            "derivedJobSha256": sha(derived_job_path),
            "resultSha256": sha(result_path),
            "invariantFailures": failures,
            "passed": not failures,
        })
    except Exception as exc:
        try:
            after_bf, after_df = sha(bf), sha(df)
            unchanged = after_bf == before_bf and after_df == before_df
        except Exception:
            after_bf = after_df = None
            unchanged = False
        row.update({
            "passed": False,
            "error": str(exc)[:1200],
            "bfSha256After": after_bf,
            "dfSha256After": after_df,
            "sourceHashesUnchanged": unchanged,
        })
    row["elapsedSeconds"] = round(time.monotonic() - started, 3)
    return row


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-jobs", required=True)
    parser.add_argument("--cases", required=True)
    parser.add_argument("--cases-sha256", required=True)
    parser.add_argument("--detector", required=True)
    parser.add_argument("--detector-sha256", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--config-sha256", required=True)
    parser.add_argument("--python", required=True)
    parser.add_argument("--python-sha256", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--maximum-per-case-seconds", type=int, default=180)
    args = parser.parse_args()
    require(args.workers == 4, f"workers must be exactly 4, received {args.workers}")
    require(args.maximum_per_case_seconds == 180, "per-case timeout changed")

    jobs_root, cases_path = Path(args.source_jobs), Path(args.cases)
    detector_path, config_path = Path(args.detector), Path(args.config)
    python_path, output = Path(args.python), Path(args.output)
    for dependency in (jobs_root, cases_path, detector_path, config_path, python_path):
        require(dependency.exists(), f"dependency absent: {dependency}")
    require(jobs_root.is_dir(), "source jobs root is not a directory")
    require(cases_path.is_file() and detector_path.is_file()
            and config_path.is_file() and python_path.is_file(),
            "file dependency type changed")
    require(sha(cases_path) == args.cases_sha256.upper(), "case lock changed")
    require(sha(detector_path) == args.detector_sha256.upper(), "R34 detector changed")
    require(sha(config_path) == args.config_sha256.upper(), "config lock changed")
    require(sha(python_path) == args.python_sha256.upper(), "Python runtime changed")
    require(not output.exists(), f"create-new output exists: {output}")

    cases = list(read_json(cases_path))
    require(len(cases) == 301, f"frozen case count changed: {len(cases)}")
    config = read_json(config_path)
    for key in ("radialEngine", "radialEngineSha256", "radialParameters"):
        require(key in config, f"config missing {key}")
    selected = []
    source_jobs = {}
    for ordinal in ORDINALS:
        case = dict(cases[ordinal])
        require(int(case.get("ordinal", -1)) == ordinal,
                f"case ordinal changed at O{ordinal:03d}")
        require(case.get("group") == EXPECTED_GROUPS[ordinal],
                f"case group changed at O{ordinal:03d}")
        require(int(case.get("expectedPairedCandidateCount", -1))
                == EXPECTED_COUNTS[ordinal],
                f"case expectation changed at O{ordinal:03d}")
        source_job_path = jobs_root / f"J{ordinal:03d}.json"
        require(source_job_path.is_file(), f"frozen source job absent: {source_job_path}")
        source_job = read_json(source_job_path)
        require(set(source_job) == JOB_KEYS, f"source job schema changed at O{ordinal:03d}")
        require(int(source_job["maximumDimension"]) == 2400,
                f"maximum dimension changed at O{ordinal:03d}")
        require(same_path(source_job["output"], jobs_root.parent / f"O{ordinal:03d}"),
                f"frozen source-job output identity changed at O{ordinal:03d}")
        for channel in ("bf", "df"):
            require(same_path(source_job[channel], case[channel]),
                    f"{channel.upper()} path differs from case lock at O{ordinal:03d}")
            require(str(source_job[f"{channel}Sha256"]).upper()
                    == str(case[f"{channel}Sha256"]).upper(),
                    f"{channel.upper()} hash differs from case lock at O{ordinal:03d}")
        require(str(source_job["radialEngine"]) == str(config["radialEngine"]),
                f"radial engine differs from config at O{ordinal:03d}")
        require(str(source_job["radialEngineSha256"]).upper()
                == str(config["radialEngineSha256"]).upper(),
                f"radial engine hash differs from config at O{ordinal:03d}")
        require(source_job["radialParameters"] == config["radialParameters"],
                f"radial parameters differ from config at O{ordinal:03d}")
        case["sourceJobSha256"] = sha(source_job_path)
        selected.append(case)
        source_jobs[ordinal] = source_job

    output.mkdir(parents=True)
    (output / "jobs").mkdir()
    started = time.monotonic()
    rows = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(execute, case, source_jobs[int(case["ordinal"])], args, output)
                   for case in selected]
        for future in as_completed(futures):
            rows.append(future.result())
    rows.sort(key=lambda row: row["ordinal"])
    failures = [row for row in rows if not row.get("passed")]
    summary = {
        "schema": "argos_r34_targeted_gate_result_v1",
        "state": "PASS_R34_TARGETED_GATE_9_OF_9" if not failures
                 else "HOLD_R34_TARGETED_GATE_MISMATCH",
        "caseCount": len(rows),
        "selectedOrdinals": list(ORDINALS),
        "outcomeMismatchCount": len(failures),
        "outcomeMismatches": failures,
        "results": rows,
        "sourceJobsRoot": str(jobs_root),
        "casesSha256": sha(cases_path),
        "detectorSha256": sha(detector_path),
        "configSha256": sha(config_path),
        "pythonSha256": sha(python_path),
        "sourceHashesUnchanged": all(row.get("sourceHashesUnchanged") is True for row in rows),
        "knownNotchLocationConsumed": any(
            row.get("knownNotchLocationConsumed") is not False for row in rows
        ),
        "sourceMutationPerformed": any(
            row.get("detectorReportedSourceMutation") is not False
            or row.get("sourceHashesUnchanged") is not True for row in rows
        ),
        "sourceDeletionPerformed": False,
        "existingTaskOrProcessActionPerformed": False,
        "providerActivationPerformed": False,
        "holdsAutomaticallyCleared": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "elapsedSeconds": round(time.monotonic() - started, 3),
    }
    summary_path = output / "SUMMARY.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps({
        "state": summary["state"], "caseCount": len(rows),
        "outcomeMismatchCount": len(failures), "summarySha256": sha(summary_path),
    }, separators=(",", ":")))
    return 0 if not failures else 2


if __name__ == "__main__":
    raise SystemExit(main())
