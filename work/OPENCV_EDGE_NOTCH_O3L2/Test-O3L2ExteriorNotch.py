#!/usr/bin/env python3
"""Frozen synthetic controls for the O3L2 exterior-referenced localizer."""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
from pathlib import Path

import cv2
import numpy as np


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def module_from(path: Path):
    spec = importlib.util.spec_from_file_location("o3l2", path)
    check(spec is not None and spec.loader is not None, "Cannot load O3L2 engine.")
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def make_crop(seed: int, channel: str, notches: list[tuple[float, float, float]], phase: int) -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)
    height, width, radius = 600, 1000, 5150.0
    tangent = np.arange(width, dtype=np.float32) - 499.5
    geometry = 420.0 + np.sqrt(np.maximum(radius * radius - tangent * tangent, 0.0)) - radius
    boundary = geometry.copy()
    x_values = np.arange(width, dtype=np.float32)
    for center, depth, sigma in notches:
        boundary -= depth * np.exp(-0.5 * np.square((x_values - center) / sigma))
    inside, outside, noise = (148.0, 30.0, 7.0) if channel == "BF" else (69.0, 20.0, 5.0)
    raster = np.full((height, width), outside, dtype=np.float32)
    for x in range(width):
        raster[: max(0, min(height, int(round(float(boundary[x]))))), x] = inside
    yy = np.arange(height, dtype=np.float32)[:, None]
    xx = np.arange(width, dtype=np.float32)[None, :]
    pattern = 22.0 * np.sin((xx + phase) * 2.0 * math.pi / 61.0) + 18.0 * np.sin((yy + phase) * 2.0 * math.pi / 49.0)
    wafer = yy < boundary[None, :]
    raster[wafer] += np.broadcast_to(pattern, raster.shape)[wafer]
    for x in range(20 + phase % 37, width, 79):
        raster[:390, max(0, x - 3) : min(width, x + 4)] -= 58.0
    for y in range(45 + phase % 31, 385, 57):
        raster[max(0, y - 3) : min(height, y + 4), :] -= 54.0
    raster += rng.normal(0.0, noise, raster.shape).astype(np.float32)
    raster = np.clip(raster, 0, 255).astype(np.uint8)
    return cv2.cvtColor(raster, cv2.COLOR_GRAY2BGR), geometry.astype(np.float32)


def inspect(engine, image: np.ndarray, geometry: np.ndarray, settings: dict) -> tuple[list[dict], str]:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    score, _, valid, _ = engine.exterior_transition_score(gray, geometry, settings)
    boundary, support = engine.shortest_boundary(score, valid, geometry, settings)
    baseline = engine.unindented_baseline(boundary, geometry)
    _, candidates, _, _ = engine.indentation_candidates(boundary, baseline, support, settings)
    if not candidates:
        state = "NONE"
    elif len(candidates) > 1 and candidates[1]["score"] >= settings["ambiguityRatio"] * candidates[0]["score"]:
        state = "AMBIGUOUS"
    else:
        state = "PRIMARY"
    return candidates, state


def create_gate(path: Path, value: dict) -> None:
    partial = path.with_name(path.name + ".partial")
    check(not path.exists() and not partial.exists(), "Gate path is not create-new.")
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", required=True)
    parser.add_argument("--job", required=True)
    parser.add_argument("--gate", required=True)
    args = parser.parse_args()
    engine_path = Path(args.engine).resolve()
    job_path = Path(args.job).resolve()
    gate_path = Path(args.gate).resolve()
    engine = module_from(engine_path)
    settings = engine.read_object(job_path)["settings"]
    cases: list[dict] = []
    for channel, seed, phase in (("BF", 411, 9), ("DF", 412, 37)):
        image, geometry = make_crop(seed, channel, [(443.0, 67.0, 36.0)], phase)
        candidates, state = inspect(engine, image, geometry, settings)
        check(candidates and state == "PRIMARY", f"{channel} notch was not primary.")
        error = abs(float(candidates[0]["mouthCenterX"]) - 443.0)
        check(error <= 12.0, f"{channel} mouth center error is {error} px.")
        cases.append({"caseId": f"{channel}_EXTERIOR_PERIODIC_DIE_NOTCH", "state": "PASS", "centerErrorPx": error})
    image, geometry = make_crop(511, "BF", [], 21)
    candidates, state = inspect(engine, image, geometry, settings)
    check(not candidates and state == "NONE", "No-notch exterior control falsely localized.")
    cases.append({"caseId": "EXTERIOR_NO_NOTCH_NEGATIVE", "state": "PASS"})
    image, geometry = make_crop(611, "DF", [(300.0, 63.0, 34.0), (704.0, 63.0, 34.0)], 45)
    candidates, state = inspect(engine, image, geometry, settings)
    check(len(candidates) >= 2 and state == "AMBIGUOUS", "Two-indentation control did not hold.")
    cases.append({"caseId": "EXTERIOR_TWO_INDENTATIONS_HOLD", "state": "PASS", "candidateCount": len(candidates)})
    gate = {
        "schema": "argos_ocv03_o3l2_synthetic_gate_v1",
        "state": "PASS_O3L2_EXTERIOR_NOTCH_SYNTHETIC_GATE",
        "caseCount": len(cases),
        "cases": cases,
        "columnLocalExteriorReferenceProved": True,
        "periodicDieStreetsRejected": True,
        "noNotchNegativeControlPassed": True,
        "twoIndentationAmbiguityHoldPassed": True,
        "minimumDepthRelaxedFromO3L1": False,
        "bfDfIndependent": True,
        "imageBytesEmittedToStdout": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    create_gate(gate_path, gate)
    print(json.dumps({"state": gate["state"], "gate": str(gate_path), "caseCount": len(cases)}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
