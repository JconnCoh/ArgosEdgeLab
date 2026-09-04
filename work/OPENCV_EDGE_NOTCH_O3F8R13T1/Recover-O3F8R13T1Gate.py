#!/usr/bin/env python3
"""Recover the two passed E1 gate components and run only the missing R10 seed gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


HERE = Path(__file__).resolve().parent
SOURCE_ROOT = Path(r"D:\O3F15L4G")
OUTPUT_ROOT = Path(r"D:\O3F8R13T1G")
SOURCE_SUMMARY_SHA256 = "D5B1FDD0D04EE14AA4FB7DFB90A4170BAF9A07AAEDFABB102B779FF64AD33CCF"
SOURCE_FOCUSED_SHA256 = "A6ACBAD28F17039F97DC211CAC4873ABB0E5B4AF93D6FF45CDD66930B7C6F929"
SOURCE_SYNTHETIC_SHA256 = "A4A85A46B61701EA9973DA768AF77D5240A682DBE4D1085FAF14BEAB21F8D937"
RUNNER_SHA256 = "3C403376521B74E3A6DB1C4E008CE8DB36D8D99AE9A0FD7C1FA51481024DBEF4"
R10_SHA256 = "0EEEE7A396E918AF44082EC0930871A6A94C1FBB59D3F5CEF1AC34D1273745FA"


def need(value: bool, message: str) -> None:
    if not value:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", required=True)
    args = parser.parse_args()
    output_root = Path(args.output_root)
    need(str(output_root).casefold() == str(OUTPUT_ROOT).casefold(), "E3 gate output root changed")
    need(not output_root.exists() and output_root.parent.is_dir(), "E3 gate output root is not fresh")

    source_summary = SOURCE_ROOT / "SUMMARY.json"
    source_focused = SOURCE_ROOT / "FOCUSED.json"
    source_synthetic = SOURCE_ROOT / "R11_SYNTHETIC" / "SYNTHETIC_GATE.json"
    need(sha256(source_summary) == SOURCE_SUMMARY_SHA256, "E1 summary changed")
    need(sha256(source_focused) == SOURCE_FOCUSED_SHA256, "E1 focused evidence changed")
    need(sha256(source_synthetic) == SOURCE_SYNTHETIC_SHA256, "E1 synthetic evidence changed")
    need(sha256(HERE / "Run-O3F15L4FrontReconcile.py") == RUNNER_SHA256, "original runner changed")
    need(sha256(HERE / "FullPerimeterWaferTopologyOpenCvR10.py") == R10_SHA256, "R10 dependency changed")

    summary = load_json(source_summary)
    focused = load_json(source_focused)
    synthetic = load_json(source_synthetic)
    need(summary.get("schema") == "argos_ocv03_o3f15l4_gate_result_v1", "E1 summary schema changed")
    need(summary.get("state") == "HOLD_O3F15L4_GATE", "E1 summary is not the pinned missing-seed hold")
    need(summary.get("runnerSha256") == RUNNER_SHA256, "E1 runner provenance changed")
    need(focused.get("state") == "PASS_O3F15L4_FOCUSED_IMAGE_FREE", "E1 focused gate did not pass")
    need(synthetic.get("state") == "PASS_O3M6_SPLIT_METHOD_FULL_PERIMETER_SYNTHETIC_GATE", "E1 synthetic gate did not pass")
    commands = summary.get("commands")
    need(isinstance(commands, list) and [row.get("label") for row in commands] == ["FOCUSED", "R11_SEED", "R11_SYNTHETIC"], "E1 command set changed")
    need(commands[0].get("returnCode") == 0 and commands[0].get("stderrBytes") == 0, "E1 focused command changed")
    need(commands[2].get("returnCode") == 0 and commands[2].get("stderrBytes") == 0, "E1 synthetic command changed")

    output_root.mkdir()
    (output_root / "R11_SYNTHETIC").mkdir()
    shutil.copyfile(source_focused, output_root / "FOCUSED.json")
    shutil.copyfile(source_synthetic, output_root / "R11_SYNTHETIC" / "SYNTHETIC_GATE.json")
    seed_path = output_root / "R11_SEED.json"
    env = dict(os.environ)
    env.update({
        "TEMP": str(output_root),
        "TMP": str(output_root),
        "ARGOS_O3F8_DEPENDENCY_ROOT": str(HERE),
        "ARGOS_O3P8_ROOT": str(HERE),
    })
    child = subprocess.run(
        [sys.executable, "-I", "-B", str(HERE / "Test-O3F14R11SeedAngles.py"), "--output", str(seed_path)],
        cwd=HERE,
        env=env,
        capture_output=True,
        timeout=240,
        check=False,
    )
    (output_root / "R11_SEED.stdout.txt").write_bytes(child.stdout)
    (output_root / "R11_SEED.stderr.txt").write_bytes(child.stderr)
    need(child.returncode == 0 and len(child.stderr) == 0, "E3 R10 seed gate failed")
    seed = load_json(seed_path)
    need(seed.get("schema") == "argos_ocv03_o3f14_r11_seed_angle_regression_v1", "E3 seed schema changed")
    need(seed.get("state") == "PASS_O3F14_R11_SEED_ANGLE_REGRESSION", "E3 seed gate did not pass")
    need(seed.get("r10Sha256") == R10_SHA256, "E3 seed R10 provenance changed")

    commands[1] = {"label": "R11_SEED", "returnCode": 0, "stderrBytes": 0}
    summary["state"] = "COMPLETE_O3F15L4_GATE"
    summary["commands"] = commands
    summary_path = output_root / "SUMMARY.json"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8", newline="\n")
    result = {
        "schema": "argos_ocv03_o3f8r13t1_gate_recovery_v1",
        "state": "COMPLETE_O3F15L4_GATE",
        "sourceGateRoot": str(SOURCE_ROOT),
        "outputRoot": str(output_root),
        "summarySha256": sha256(summary_path),
        "focusedEvidenceReused": True,
        "syntheticEvidenceReused": True,
        "seedExecutedFresh": True,
        "sourceImageBytesRead": False,
        "sourceMutation": False,
        "providerActivated": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    (output_root / "RECOVERY.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
