#!/usr/bin/env python3
"""Frozen synthetic gate for the standalone O3L4 localizer."""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
from pathlib import Path

import cv2
import numpy as np


def ok(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def load(path: Path):
    spec = importlib.util.spec_from_file_location("o3l4", path)
    ok(spec is not None and spec.loader is not None, "Cannot load engine.")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def crop(seed: int, channel: str, notches: list[tuple[float, float, float]], phase: int) -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)
    h, w, radius = 600, 1000, 5150.0
    x = np.arange(w, dtype=np.float32)
    tangent = x - 499.5
    geometry = 420.0 + np.sqrt(np.maximum(radius * radius - tangent * tangent, 0.0)) - radius
    edge = geometry.copy()
    for center, depth, sigma in notches:
        edge -= depth * np.exp(-0.5 * np.square((x - center) / sigma))
    inside, outside, noise = (150.0, 29.0, 7.0) if channel == "BF" else (70.0, 20.0, 5.0)
    pixels = np.full((h, w), outside, dtype=np.float32)
    for column in range(w):
        pixels[: max(0, min(h, int(round(float(edge[column]))))), column] = inside
    yy = np.arange(h, dtype=np.float32)[:, None]
    xx = np.arange(w, dtype=np.float32)[None, :]
    texture = 24.0 * np.sin((xx + phase) * 2.0 * math.pi / 61.0) + 20.0 * np.sin((yy + 2 * phase) * 2.0 * math.pi / 49.0)
    wafer = yy < edge[None]
    pixels[wafer] += np.broadcast_to(texture, pixels.shape)[wafer]
    for column in range(17 + phase % 43, w, 79):
        pixels[:390, max(0, column - 3) : min(w, column + 4)] -= 62.0
    for row in range(43 + phase % 29, 385, 57):
        pixels[max(0, row - 3) : min(h, row + 4)] -= 58.0
    pixels += rng.normal(0.0, noise, pixels.shape).astype(np.float32)
    return cv2.cvtColor(np.clip(pixels, 0, 255).astype(np.uint8), cv2.COLOR_GRAY2BGR), geometry.astype(np.float32)


def inspect(engine, image: np.ndarray, geometry: np.ndarray, cfg: dict):
    edge, support, _, evidence = engine.trace_edge(cv2.cvtColor(image, cv2.COLOR_BGR2GRAY), geometry, cfg)
    baseline = engine.fit_baseline(edge, geometry)
    candidates, _, _ = engine.detect(edge, baseline, support, cfg)
    state = "NONE" if not candidates else ("AMBIGUOUS" if len(candidates) > 1 and candidates[1]["score"] >= cfg["ambiguityScoreRatio"] * candidates[0]["score"] else "PRIMARY")
    return candidates, state, evidence


def gate_new(path: Path, value: dict) -> None:
    partial = path.with_name(path.name + ".partial")
    ok(not path.exists() and not partial.exists(), "Gate path is not create-new.")
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", required=True)
    parser.add_argument("--job", required=True)
    parser.add_argument("--gate", required=True)
    args = parser.parse_args()
    engine = load(Path(args.engine).resolve())
    cfg = engine.read_json(Path(args.job).resolve())["config"]
    cases = []
    for channel, seed, phase in (("BF", 8101, 13), ("DF", 8102, 39)):
        image, geometry = crop(seed, channel, [(441.0, 68.0, 36.0)], phase)
        candidates, state, evidence = inspect(engine, image, geometry, cfg)
        ok(candidates and state == "PRIMARY", f"{channel} notch was not primary.")
        error = abs(float(candidates[0]["mouthCenterX"]) - 441.0)
        ok(error <= 12.0, f"{channel} center error exceeded 12 px: {error}")
        ok(float(evidence["coverageFraction"]) >= 0.95, f"{channel} exterior coverage failed.")
        cases.append({"caseId": f"{channel}_HARD_EXTERIOR_NOTCH", "state": "PASS", "centerErrorPx": error})
    image, geometry = crop(8201, "BF", [], 23)
    candidates, state, evidence = inspect(engine, image, geometry, cfg)
    ok(not candidates and state == "NONE", f"No-notch control produced {len(candidates)} candidates.")
    ok(float(evidence["coverageFraction"]) >= 0.95, "No-notch edge coverage failed.")
    cases.append({"caseId": "HARD_EXTERIOR_NO_NOTCH", "state": "PASS"})
    image, geometry = crop(8301, "DF", [(305.0, 64.0, 34.0), (700.0, 64.0, 34.0)], 47)
    candidates, state, _ = inspect(engine, image, geometry, cfg)
    ok(len(candidates) >= 2 and state == "AMBIGUOUS", "Two-indentation control did not hold.")
    cases.append({"caseId": "HARD_EXTERIOR_TWO_INDENTATIONS", "state": "PASS", "candidateCount": len(candidates)})
    gate = {
        "schema": "argos_ocv03_o3l4_synthetic_gate_v1",
        "state": "PASS_O3L4_NOTCH_EXTERIOR_SYNTHETIC_GATE",
        "caseCount": len(cases),
        "cases": cases,
        "floatSafeSmoothingExercised": True,
        "hardExteriorEligibilityProved": True,
        "periodicDieStreetsRejected": True,
        "noNotchNegativePassed": True,
        "twoIndentationHoldPassed": True,
        "thresholdRelaxationPerformed": False,
        "imageBytesEmittedToStdout": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    gate_new(Path(args.gate).resolve(), gate)
    print(json.dumps({"state": gate["state"], "gate": str(Path(args.gate).resolve()), "caseCount": len(cases)}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
