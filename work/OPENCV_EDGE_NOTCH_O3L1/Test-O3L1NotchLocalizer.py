#!/usr/bin/env python3
"""Synthetic, pixel-only tests for the O3L1 notch localizer."""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
from pathlib import Path

import cv2
import numpy as np


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_engine(path: Path):
    spec = importlib.util.spec_from_file_location("o3l1_engine", path)
    require(spec is not None and spec.loader is not None, "Cannot load engine module.")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def synthetic_crop(
    *,
    seed: int,
    contrast: str,
    notches: list[tuple[float, float, float]],
    die_phase: int,
) -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)
    height, width = 600, 1000
    radius = 5150.0
    tangent = np.arange(width, dtype=np.float32) - 499.5
    baseline = 420.0 + np.sqrt(np.maximum(radius * radius - tangent * tangent, 0.0)) - radius
    boundary = baseline.copy()
    for center_x, depth, sigma in notches:
        boundary -= depth * np.exp(-0.5 * np.square((np.arange(width, dtype=np.float32) - center_x) / sigma))

    if contrast == "BF":
        inside_base, outside_base, noise_sigma = 145.0, 28.0, 7.0
    else:
        inside_base, outside_base, noise_sigma = 72.0, 19.0, 5.0
    image = np.full((height, width), outside_base, dtype=np.float32)
    for x in range(width):
        y_end = max(0, min(height, int(round(float(boundary[x])))))
        image[:y_end, x] = inside_base

    xx = np.arange(width, dtype=np.float32)[None, :]
    yy = np.arange(height, dtype=np.float32)[:, None]
    die_pattern = 18.0 * np.sin((xx + die_phase) * (2.0 * math.pi / 63.0)) + 15.0 * np.sin((yy + 2 * die_phase) * (2.0 * math.pi / 47.0))
    wafer_mask = yy < boundary[None, :]
    image[wafer_mask] += np.broadcast_to(die_pattern, image.shape)[wafer_mask]
    # Strong internal die streets deliberately exceed some local edge
    # gradients, but they do not lead to a flat outside-wafer region.
    for x in range((die_phase % 41) + 15, width, 83):
        image[:390, max(0, x - 2) : min(width, x + 3)] -= 52.0
    for y in range((die_phase % 29) + 55, 380, 61):
        image[max(0, y - 2) : min(height, y + 3), :] -= 46.0
    image += rng.normal(0.0, noise_sigma, image.shape).astype(np.float32)
    image = np.clip(image, 0, 255).astype(np.uint8)
    return cv2.cvtColor(image, cv2.COLOR_GRAY2BGR), baseline.astype(np.float32)


def analyze(engine, image: np.ndarray, baseline_geometry: np.ndarray, config: dict) -> tuple[list[dict], str]:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    score, _, valid = engine.build_boundary_score(gray, baseline_geometry, config)
    seam, confidence = engine.trace_boundary(score, valid, baseline_geometry, config)
    baseline = engine.robust_baseline(seam, baseline_geometry)
    _, candidates, _, _ = engine.detect_indentations(seam, baseline, confidence, config)
    if not candidates:
        state = "HOLD_NO_IMAGE_DERIVED_NOTCH"
    elif len(candidates) > 1 and candidates[1]["score"] >= config["ambiguityScoreRatio"] * candidates[0]["score"]:
        state = "HOLD_MULTIPLE_IMAGE_DERIVED_INDENTATIONS"
    else:
        state = "IMAGE_DERIVED_NOTCH_PRIMARY_FOR_OPERATOR_REVIEW"
    return candidates, state


def atomic_write(path: Path, value: dict) -> None:
    partial = path.with_name(path.name + ".partial")
    require(not path.exists() and not partial.exists(), "Synthetic gate path must be create-new.")
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
    engine = load_engine(engine_path)
    job = engine.load_json(job_path)
    config = job["algorithm"]

    cases = []
    for channel, seed, phase in (("BF", 1001, 7), ("DF", 1002, 31)):
        image, geometry = synthetic_crop(seed=seed, contrast=channel, notches=[(438.0, 66.0, 36.0)], die_phase=phase)
        candidates, state = analyze(engine, image, geometry, config)
        require(candidates, f"{channel} single-notch case returned no candidate.")
        center_error = abs(float(candidates[0]["centerX"]) - 438.0)
        require(center_error <= 12.0, f"{channel} center error exceeded 12 px: {center_error}")
        require(state == "IMAGE_DERIVED_NOTCH_PRIMARY_FOR_OPERATOR_REVIEW", f"{channel} single-notch case was not primary.")
        cases.append({"caseId": f"{channel}_PERIODIC_DIE_SINGLE_NOTCH", "state": "PASS", "centerErrorPx": center_error})

    image, geometry = synthetic_crop(seed=2001, contrast="BF", notches=[], die_phase=19)
    candidates, state = analyze(engine, image, geometry, config)
    require(not candidates and state == "HOLD_NO_IMAGE_DERIVED_NOTCH", "No-notch negative control falsely localized a notch.")
    cases.append({"caseId": "NO_NOTCH_PERIODIC_DIE_NEGATIVE", "state": "PASS", "candidateCount": 0})

    image, geometry = synthetic_crop(seed=3001, contrast="DF", notches=[(315.0, 62.0, 33.0), (690.0, 61.0, 34.0)], die_phase=43)
    candidates, state = analyze(engine, image, geometry, config)
    require(len(candidates) >= 2, "Two-notch ambiguity control did not preserve both physical indentations.")
    require(state == "HOLD_MULTIPLE_IMAGE_DERIVED_INDENTATIONS", "Two-notch ambiguity control did not hold.")
    cases.append({"caseId": "TWO_PHYSICAL_INDENTATIONS_AMBIGUOUS", "state": "PASS", "candidateCount": len(candidates)})

    gate = {
        "schema": "argos_ocv03_o3l1_synthetic_gate_v1",
        "state": "PASS_O3L1_NOTCH_LOCALIZER_SYNTHETIC_GATE",
        "engine": str(engine_path),
        "job": str(job_path),
        "caseCount": len(cases),
        "cases": cases,
        "periodicDiePatternSuppressionProved": True,
        "bfDfIndependent": True,
        "noNotchNegativeControlPassed": True,
        "multiplePhysicalIndentationsHoldPassed": True,
        "imageBytesEmittedToStdout": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    atomic_write(gate_path, gate)
    print(json.dumps({"state": gate["state"], "gate": str(gate_path), "caseCount": len(cases)}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
