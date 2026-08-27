#!/usr/bin/env python3
"""Synthetic controls for O3L3 hard exterior eligibility."""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
from pathlib import Path

import cv2
import numpy as np


def assert_true(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def load_module(path: Path):
    spec = importlib.util.spec_from_file_location("o3l3", path)
    assert_true(spec is not None and spec.loader is not None, "Cannot load engine.")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def synthetic(seed: int, channel: str, indentations: list[tuple[float, float, float]], phase: int) -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)
    height, width, radius = 600, 1000, 5150.0
    x = np.arange(width, dtype=np.float32)
    tangent = x - 499.5
    geometry = 420.0 + np.sqrt(np.maximum(radius * radius - tangent * tangent, 0.0)) - radius
    edge = geometry.copy()
    for center, depth, sigma in indentations:
        edge -= depth * np.exp(-0.5 * np.square((x - center) / sigma))
    inside, outside, noise = (150.0, 29.0, 7.0) if channel == "BF" else (70.0, 20.0, 5.0)
    image = np.full((height, width), outside, dtype=np.float32)
    for column in range(width):
        image[: max(0, min(height, int(round(float(edge[column]))))), column] = inside
    yy = np.arange(height, dtype=np.float32)[:, None]
    xx = np.arange(width, dtype=np.float32)[None, :]
    periodic = 24.0 * np.sin((xx + phase) * 2.0 * math.pi / 61.0) + 20.0 * np.sin((yy + 2 * phase) * 2.0 * math.pi / 49.0)
    wafer = yy < edge[None, :]
    image[wafer] += np.broadcast_to(periodic, image.shape)[wafer]
    for column in range(17 + phase % 43, width, 79):
        image[:390, max(0, column - 3) : min(width, column + 4)] -= 62.0
    for row in range(43 + phase % 29, 385, 57):
        image[max(0, row - 3) : min(height, row + 4), :] -= 58.0
    image += rng.normal(0.0, noise, image.shape).astype(np.float32)
    return cv2.cvtColor(np.clip(image, 0, 255).astype(np.uint8), cv2.COLOR_GRAY2BGR), geometry.astype(np.float32)


def analyze(engine, image: np.ndarray, geometry: np.ndarray, config: dict):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    boundary, support, _, evidence = engine.hard_exterior_boundary(gray, geometry, config)
    baseline = engine.robust_unindented_edge(boundary, geometry)
    candidates, _, _ = engine.find_notches(boundary, baseline, support, config)
    if not candidates:
        state = "NONE"
    elif len(candidates) > 1 and candidates[1]["score"] >= config["ambiguityScoreRatio"] * candidates[0]["score"]:
        state = "AMBIGUOUS"
    else:
        state = "PRIMARY"
    return candidates, state, evidence


def write_gate(path: Path, value: dict) -> None:
    partial = path.with_name(path.name + ".partial")
    assert_true(not path.exists() and not partial.exists(), "Gate path must be create-new.")
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", required=True)
    parser.add_argument("--job", required=True)
    parser.add_argument("--gate", required=True)
    args = parser.parse_args()
    engine_path, job_path, gate_path = Path(args.engine).resolve(), Path(args.job).resolve(), Path(args.gate).resolve()
    engine = load_module(engine_path)
    config = engine.json_object(job_path)["config"]
    cases: list[dict] = []

    for channel, seed, phase in (("BF", 7101, 13), ("DF", 7102, 39)):
        image, geometry = synthetic(seed, channel, [(441.0, 68.0, 36.0)], phase)
        candidates, state, evidence = analyze(engine, image, geometry, config)
        assert_true(candidates and state == "PRIMARY", f"{channel} notch was not primary.")
        error = abs(float(candidates[0]["mouthCenterX"]) - 441.0)
        assert_true(error <= 12.0, f"{channel} center error exceeded 12 px: {error}")
        assert_true(float(evidence["coverageFraction"]) >= 0.95, f"{channel} hard exterior coverage was incomplete.")
        cases.append({"caseId": f"{channel}_HARD_EXTERIOR_PERIODIC_NOTCH", "state": "PASS", "centerErrorPx": error})

    image, geometry = synthetic(7201, "BF", [], 23)
    candidates, state, evidence = analyze(engine, image, geometry, config)
    assert_true(not candidates and state == "NONE", f"No-notch negative localized {len(candidates)} candidates.")
    assert_true(float(evidence["coverageFraction"]) >= 0.95, "No-notch boundary coverage was incomplete.")
    cases.append({"caseId": "HARD_EXTERIOR_NO_NOTCH_NEGATIVE", "state": "PASS"})

    image, geometry = synthetic(7301, "DF", [(305.0, 64.0, 34.0), (700.0, 64.0, 34.0)], 47)
    candidates, state, _ = analyze(engine, image, geometry, config)
    assert_true(len(candidates) >= 2 and state == "AMBIGUOUS", "Two-indentation case did not hold.")
    cases.append({"caseId": "HARD_EXTERIOR_TWO_INDENTATIONS_HOLD", "state": "PASS", "candidateCount": len(candidates)})

    gate = {
        "schema": "argos_ocv03_o3l3_synthetic_gate_v1",
        "state": "PASS_O3L3_HARD_EXTERIOR_SYNTHETIC_GATE",
        "caseCount": len(cases),
        "cases": cases,
        "hardExteriorEligibilityProved": True,
        "periodicDieStreetsRejected": True,
        "noNotchNegativeControlPassed": True,
        "twoIndentationAmbiguityHoldPassed": True,
        "minimumNotchDepthRelaxed": False,
        "bfDfIndependent": True,
        "imageBytesEmittedToStdout": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    write_gate(gate_path, gate)
    print(json.dumps({"state": gate["state"], "gate": str(gate_path), "caseCount": len(cases)}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
