#!/usr/bin/env python3
"""Run the exact one-case R32 residue-alignment validation."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time


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


def circular_distance(first: float, second: float) -> float:
    return abs((float(first) - float(second) + 180.0) % 360.0 - 180.0)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", required=True)
    parser.add_argument("--detector", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--python", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    contract = read_json(Path(args.contract))
    source = contract["source"]
    output = Path(args.output)
    require(str(output).replace("\\", "/").lower() == contract["outputRoot"].lower(), "Output root changed")
    require(not output.exists(), f"Create-new output exists: {output}")
    bf = Path(source["bf"])
    df = Path(source["df"])
    require(bf.is_file() and df.is_file(), "Pinned source pair absent")
    before_bf, before_df = sha(bf), sha(df)
    require(before_bf == source["bfSha256"] and before_df == source["dfSha256"], "Pinned source hash changed")

    output.mkdir(parents=True)
    case_root = output / "O00"
    job_path = output / "J00.json"
    config = read_json(Path(args.config))
    job = {
        "bf": str(bf), "df": str(df), "bfSha256": before_bf, "dfSha256": before_df,
        "output": str(case_root), "radialEngine": config["radialEngine"],
        "radialEngineSha256": config["radialEngineSha256"],
        "radialParameters": config["radialParameters"],
        "maximumDimension": int(contract["maximumDimension"]),
    }
    job_path.write_text(json.dumps(job, indent=2), encoding="utf-8")
    started = time.monotonic()
    completed = subprocess.run(
        [args.python, "-B", args.detector, "--job", str(job_path)],
        cwd=str(Path(args.detector).parent), capture_output=True, text=True,
        timeout=int(contract["maximumPerCaseSeconds"]), check=False,
    )
    require(completed.returncode == 0, f"R32 detector failed: {completed.stderr[-1000:]}")
    result_path = case_root / "RESULT.json"
    require(result_path.is_file(), "R32 result absent")
    result = read_json(result_path)
    after_bf, after_df = sha(bf), sha(df)
    require(after_bf == before_bf and after_df == before_df, "Source mutation detected")

    pairs = result.get("pairedCandidates", [])
    paired_count = int(result["pairedCandidateCount"])
    angle = float(pairs[0]["meanAngleDegrees"]) if paired_count == 1 else None
    angle_difference = (
        circular_distance(angle, float(source["frozenC15Run4NotchAngleDegrees"]))
        if angle is not None else None
    )
    diagnostic = result.get("bf", {}).get("multiPairExteriorCleanResolution", {})
    passed = bool(
        paired_count == int(source["expectedPairedCandidateCount"])
        and angle_difference is not None
        and angle_difference <= float(source["maximumAngleDifferenceDegrees"])
        and diagnostic.get("state") == "PASS_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR"
        and int(diagnostic.get("inputPairCount", -1)) == 2
        and int(diagnostic.get("retainedPairCount", -1)) == 1
    )
    summary = {
        "schema": "argos_o3b21_r32t1_targeted_result_v1",
        "state": "PASS_R32T1_RESIDUE_ALIGNMENT" if passed else "HOLD_R32T1_TARGET_OUTCOME",
        "id": source["id"], "pairedCandidateCount": paired_count,
        "pairedCandidates": pairs, "resolvedMeanAngleDegrees": angle,
        "frozenC15Run4NotchAngleDegrees": source["frozenC15Run4NotchAngleDegrees"],
        "angleDifferenceDegrees": angle_difference,
        "maximumAngleDifferenceDegrees": source["maximumAngleDifferenceDegrees"],
        "multiPairExteriorCleanResolution": diagnostic,
        "resultSha256": sha(result_path), "elapsedSeconds": round(time.monotonic() - started, 3),
        "bfSha256": before_bf, "dfSha256": before_df,
        "sourceMutationPerformed": False, "sourceDeletionPerformed": False,
        "existingTaskOrProcessActionPerformed": False, "providerActivationPerformed": False,
        "holdsAutomaticallyCleared": False, "reviewOnly": True,
        "trainingEligible": False, "xmlEligible": False, "productionEligible": False,
    }
    summary_path = output / "SUMMARY.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
