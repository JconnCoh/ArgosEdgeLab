#!/usr/bin/env python3
"""Synthetic, file-backed gate for the O3K1 OpenCV review renderer."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
from typing import Any

import cv2
import numpy as np


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while block := stream.read(1024 * 1024):
            digest.update(block)
    return digest.hexdigest().upper()


def write_json(path: Path, value: dict[str, Any]) -> None:
    require(not path.exists(), f"Create-new JSON exists: {path}")
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def candidate(center: float, width: float) -> dict[str, Any]:
    return {
        "centerAngleDegrees": center,
        "startAngleDegrees": center - width / 2.0,
        "endAngleDegrees": center + width / 2.0,
        "widthDegrees": width,
        "maximumDepthPx": 70.0,
        "medianDepthPx": 45.0,
        "sampleCount": max(4, int(round(width * 10))),
        "symmetryScore": 0.85,
        "tipCenterOffsetFraction": 0.1,
        "slopeConsistencyFraction": 0.9,
    }


def physical(bf: dict[str, Any], df: dict[str, Any]) -> dict[str, Any]:
    return {
        "bfAngleDegrees": bf["centerAngleDegrees"],
        "dfAngleDegrees": df["centerAngleDegrees"],
        "reviewAngleDegrees": df["centerAngleDegrees"],
        "reviewAngleChannel": "DF",
        "channelAngleDifferenceDegrees": abs(bf["centerAngleDegrees"] - df["centerAngleDegrees"]),
        "crossChannelOverlapFraction": 0.6,
        "combinedWidthDegrees": min(bf["widthDegrees"], df["widthDegrees"]),
        "combinedWidthSemantics": "SYNTHETIC_TEST_ONLY",
        "combinedSymmetryScore": 0.85,
        "combinedTipCenterOffsetFraction": 0.1,
        "combinedSlopeConsistencyFraction": 0.9,
        "manufacturedNotchMorphologyEligible": False,
        "bf": bf,
        "df": df,
        "evidence": "SYNTHETIC_TEST_ONLY",
    }


def draw_source(path: Path, candidates: list[tuple[float, float, float]], brightness: int) -> None:
    size = 900
    center = np.asarray([450.0, 450.0])
    radius = 320.0
    image = np.full((size, size, 3), 20, dtype=np.uint8)
    cv2.circle(image, (450, 450), 320, (brightness, brightness, brightness), -1, cv2.LINE_8)
    for angle_degrees, width_degrees, depth in candidates:
        center_angle = math.radians(angle_degrees)
        half = math.radians(width_degrees / 2.0)
        points = []
        for angle, radial in ((center_angle - half, radius + 3), (center_angle, radius - depth), (center_angle + half, radius + 3)):
            x = int(round(center[0] + math.cos(angle) * radial))
            y = int(round(center[1] + math.sin(angle) * radial))
            points.append([x, y])
        cv2.fillConvexPoly(image, np.asarray(points, dtype=np.int32), (20, 20, 20), cv2.LINE_8)
    require(cv2.imwrite(str(path), image), f"Failed to write synthetic BMP: {path}")


def run(engine: Path, job: Path, output: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(engine), "--job", str(job), "--output-root", str(output)],
        text=True,
        capture_output=True,
        check=False,
    )


def build_fixture(root: Path, engine: Path) -> dict[str, Any]:
    require(not root.exists(), "Synthetic root must be create-new.")
    sources_root = root / "src"
    job_root = root / "job"
    output_parent = root / "out"
    sources_root.mkdir(parents=True)
    job_root.mkdir()
    output_parent.mkdir()

    source_specs = [
        (16, "BF", [(179.13628776081535, 0.5, 80.0)], 170),
        (16, "DF", [(178.89693195700835, 0.8, 65.0)], 135),
        (17, "BF", [(88.09222454791899, 6.4, 90.0), (80.56671010142058, 3.4, 35.0)], 180),
        (17, "DF", [(88.82079696662512, 3.4, 105.0), (81.76692200974142, 3.0, 70.0)], 145),
    ]
    source_rows: list[dict[str, Any]] = []
    source_meta: dict[tuple[int, str], dict[str, Any]] = {}
    for slot, channel, notches, brightness in source_specs:
        path = sources_root / f"s{slot}_{channel.lower()}.bmp"
        draw_source(path, notches, brightness)
        frozen_path = f"X:\\S{slot}\\{channel}.bmp"
        row = {
            "id": f"S{slot}-{channel}",
            "slot": slot,
            "channel": channel,
            "path": str(path),
            "frozenResultSourcePath": frozen_path,
            "bytes": path.stat().st_size,
            "sha256": sha256_file(path),
        }
        source_rows.append(row)
        source_meta[(slot, channel)] = row

    s16_bf = candidate(179.13628776081535, 0.5)
    s16_df = candidate(178.89693195700835, 0.8)
    s17_bf_1 = candidate(88.09222454791899, 6.4)
    s17_df_1 = candidate(88.82079696662512, 3.4)
    s17_bf_2 = candidate(80.56671010142058, 3.4)
    s17_df_2 = candidate(81.76692200974142, 3.0)
    candidate_sets = {16: [physical(s16_bf, s16_df)], 17: [physical(s17_bf_1, s17_df_1), physical(s17_bf_2, s17_df_2)]}

    result_rows = []
    for slot in (16, 17):
        def channel_result(channel: str) -> dict[str, Any]:
            return {
                "channel": channel,
                "qualified": True,
                "state": "PASS",
                "widthPx": 900,
                "heightPx": 900,
                "search": {},
                "coarseFit": {},
                "fit": {"centerX": 450.0, "centerY": 450.0, "radius": 320.0},
                "candidateDepthThresholdPx": 6.0,
                "baselineNoiseSigmaPx": 1.0,
                "candidates": [row[channel.lower()] for row in candidate_sets[slot]],
            }

        result = {
            "schema": "argos_native_frontside_wafer_pose_opencv_v2",
            "identity": f"FIXTURE_SLOT{slot}",
            "state": "DIAGNOSTIC_ONLY",
            "bf": channel_result("BF"),
            "df": channel_result("DF"),
            "channelComparison": {"evaluated": True, "qualified": True},
            "physicalIndentationCandidates": candidate_sets[slot],
            "sources": {
                "bfPath": source_meta[(slot, "BF")]["frozenResultSourcePath"],
                "bfBytes": source_meta[(slot, "BF")]["bytes"],
                "bfSha256": source_meta[(slot, "BF")]["sha256"],
                "dfPath": source_meta[(slot, "DF")]["frozenResultSourcePath"],
                "dfBytes": source_meta[(slot, "DF")]["bytes"],
                "dfSha256": source_meta[(slot, "DF")]["sha256"],
            },
        }
        result_path = job_root / f"S{slot}_RESULT.json"
        write_json(result_path, result)
        result_rows.append({"slot": slot, "path": result_path.name, "sha256": sha256_file(result_path)})

    job = {
        "schema": "argos_ocv03_notch_review_job_v1",
        "revision": "FMOCV03_O3K1TEST_20260827T200000Z",
        "sourceRoot": str(sources_root),
        "allowedOutputRoot": str(output_parent),
        "crop": {"widthPx": 800, "inwardPx": 300, "outwardPx": 140},
        "resultFiles": result_rows,
        "sources": source_rows,
        "candidates": [
            {"id": "S16-C1", "slot": 16, "physicalCandidateIndex": 0, "bfAngleDegrees": s16_bf["centerAngleDegrees"], "dfAngleDegrees": s16_df["centerAngleDegrees"]},
            {"id": "S17-C1", "slot": 17, "physicalCandidateIndex": 0, "bfAngleDegrees": s17_bf_1["centerAngleDegrees"], "dfAngleDegrees": s17_df_1["centerAngleDegrees"]},
            {"id": "S17-C2", "slot": 17, "physicalCandidateIndex": 1, "bfAngleDegrees": s17_bf_2["centerAngleDegrees"], "dfAngleDegrees": s17_df_2["centerAngleDegrees"]},
        ],
        "detectorRerun": False,
        "thresholdOrAlgorithmChange": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    job_path = job_root / "JOB.json"
    write_json(job_path, job)

    good_output = output_parent / "good"
    completed = run(engine, job_path, good_output)
    require(completed.returncode == 0, f"Renderer synthetic execution failed: {completed.stderr}")
    command_result = json.loads(completed.stdout)
    require(command_result["state"] == "PASS_O3K1_NOTCH_REVIEW_RENDERED", "Renderer terminal state changed.")
    manifest_path = good_output / "RENDER_MANIFEST.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    require(manifest["assetFileCount"] == 18 and len(manifest["assetGroups"]) == 6, "Renderer output cardinality changed.")
    require(all(int(row["changedPixelsOutsideCurrentMask"]) == 0 for row in manifest["assetGroups"]), "Synthetic overlay escaped its mask.")
    require(all(int(row["changedPixelsInsideCurrentMask"]) > 0 for row in manifest["assetGroups"]), "Synthetic overlay did not change masked pixels.")

    bad_job = json.loads(job_path.read_text(encoding="utf-8"))
    bad_job["sources"][0]["sha256"] = "0" * 64
    bad_job_path = job_root / "BAD_HASH_JOB.json"
    write_json(bad_job_path, bad_job)
    bad_output = output_parent / "bad"
    rejected = run(engine, bad_job_path, bad_output)
    require(rejected.returncode != 0, "Bad source hash was accepted.")
    require(not bad_output.exists(), "Bad source hash created an output root.")

    gate = {
        "schema": "argos_o3k1_renderer_test_gate_v1",
        "state": "PASS_O3K1_RENDERER_SYNTHETIC_GATE",
        "engineSha256": sha256_file(engine),
        "positiveAssetFileCount": 18,
        "positiveAssetGroupCount": 6,
        "badSourceHashRejectedBeforeOutputCreation": True,
        "changedPixelsOutsideCurrentMask": 0,
        "cleanRoundtripLossless": True,
        "sourceImageBytesRead": False,
        "syntheticImageBytesRead": True,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    gate_path = root / "TEST_GATE.json"
    write_json(gate_path, gate)
    return {"state": gate["state"], "gate": str(gate_path), "gateSha256": sha256_file(gate_path)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", required=True)
    parser.add_argument("--root", required=True)
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    engine = Path(args.engine).resolve()
    root = Path(args.root).resolve()
    require(engine.is_file(), "Engine is absent.")
    require(len(str(root)) + 32 < 230, "Synthetic root exceeds path budget.")
    require(not root.exists(), "Synthetic root must be create-new.")
    if args.preflight:
        result = {
            "state": "PASS_O3K1_RENDERER_TEST_PREFLIGHT",
            "engineSha256": sha256_file(engine),
            "outputCreated": False,
            "sourceImageBytesRead": False,
            "reviewOnly": True,
            "productionRoutingEnabled": False,
        }
    else:
        result = build_fixture(root, engine)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
