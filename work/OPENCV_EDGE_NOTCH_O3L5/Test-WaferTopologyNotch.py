#!/usr/bin/env python3
"""Synthetic controls for top-connected wafer topology notch localization."""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
from pathlib import Path

import cv2
import numpy as np


def check(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def engine_at(path: Path):
    spec = importlib.util.spec_from_file_location("o3l5", path)
    check(spec is not None and spec.loader is not None, "Cannot load engine.")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def synthetic(seed: int, channel: str, indentations: list[tuple[float, float, float]], phase: int) -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)
    h, w, radius = 600, 1000, 5150.0
    x = np.arange(w, dtype=np.float32)
    tangent = x - 499.5
    geometry = 420.0 + np.sqrt(np.maximum(radius * radius - tangent * tangent, 0.0)) - radius
    edge = geometry.copy()
    for center, depth, sigma in indentations:
        edge -= depth * np.exp(-0.5 * np.square((x - center) / sigma))
    inside, outside, noise = (150.0, 29.0, 7.0) if channel == "BF" else (70.0, 20.0, 5.0)
    image = np.full((h, w), outside, dtype=np.float32)
    for column in range(w):
        image[: max(0, min(h, int(round(float(edge[column]))))), column] = inside
    yy, xx = np.arange(h, dtype=np.float32)[:, None], np.arange(w, dtype=np.float32)[None, :]
    periodic = 24.0 * np.sin((xx + phase) * 2.0 * math.pi / 61.0) + 20.0 * np.sin((yy + 2 * phase) * 2.0 * math.pi / 49.0)
    wafer = yy < edge[None]
    image[wafer] += np.broadcast_to(periodic, image.shape)[wafer]
    for column in range(17 + phase % 43, w, 79):
        image[:390, max(0, column - 3) : min(w, column + 4)] -= 68.0
    for row in range(43 + phase % 29, 385, 57):
        image[max(0, row - 3) : min(h, row + 4)] -= 64.0
    image += rng.normal(0.0, noise, image.shape).astype(np.float32)
    return cv2.cvtColor(np.clip(image, 0, 255).astype(np.uint8), cv2.COLOR_GRAY2BGR), geometry.astype(np.float32)


def analyze(engine, image: np.ndarray, geometry: np.ndarray, cfg: dict):
    edge, support, _, _, evidence = engine.topology_edge(cv2.cvtColor(image, cv2.COLOR_BGR2GRAY), geometry, cfg)
    unindented = engine.baseline(edge, geometry)
    found, _, _ = engine.notches(edge, unindented, support, cfg)
    state = "NONE" if not found else ("AMBIGUOUS" if len(found) > 1 and found[1]["score"] >= cfg["ambiguityScoreRatio"] * found[0]["score"] else "PRIMARY")
    return found, state, evidence


def new_gate(path: Path, value: dict) -> None:
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
    engine = engine_at(Path(args.engine).resolve())
    cfg = engine.read_json(Path(args.job).resolve())["config"]
    cases = []
    for channel, seed, phase in (("BF", 9101, 13), ("DF", 9102, 39)):
        image, geometry = synthetic(seed, channel, [(441.0, 68.0, 36.0)], phase)
        found, state, evidence = analyze(engine, image, geometry, cfg)
        check(found and state == "PRIMARY", f"{channel} topology notch was not primary: count={len(found)} state={state}")
        error = abs(float(found[0]["mouthCenterX"]) - 441.0)
        check(error <= 12.0, f"{channel} topology center error exceeded 12 px: {error}")
        check(float(evidence["coverageFraction"]) >= 0.99, f"{channel} contour coverage failed.")
        cases.append({"caseId": f"{channel}_TOPOLOGY_PERIODIC_NOTCH", "state": "PASS", "centerErrorPx": error})
    image, geometry = synthetic(9201, "BF", [], 23)
    found, state, evidence = analyze(engine, image, geometry, cfg)
    check(not found and state == "NONE", f"No-notch topology control produced {len(found)} candidates.")
    check(float(evidence["coverageFraction"]) >= 0.99, "No-notch contour coverage failed.")
    cases.append({"caseId": "TOPOLOGY_NO_NOTCH_NEGATIVE", "state": "PASS"})
    image, geometry = synthetic(9301, "DF", [(305.0, 64.0, 34.0), (700.0, 64.0, 34.0)], 47)
    found, state, _ = analyze(engine, image, geometry, cfg)
    check(len(found) >= 2 and state == "AMBIGUOUS", f"Two-indentation topology control did not hold: count={len(found)} state={state}")
    cases.append({"caseId": "TOPOLOGY_TWO_INDENTATIONS_HOLD", "state": "PASS", "candidateCount": len(found)})
    gate = {
        "schema": "argos_ocv03_o3l5_synthetic_gate_v1",
        "state": "PASS_O3L5_WAFER_TOPOLOGY_SYNTHETIC_GATE",
        "caseCount": len(cases),
        "cases": cases,
        "topConnectedWaferComponentProved": True,
        "internalDieHolesFilled": True,
        "periodicDieStreetsRejected": True,
        "noNotchNegativePassed": True,
        "twoIndentationHoldPassed": True,
        "thresholdRelaxationPerformed": False,
        "imageBytesEmittedToStdout": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    new_gate(Path(args.gate).resolve(), gate)
    print(json.dumps({"state": gate["state"], "gate": str(Path(args.gate).resolve()), "caseCount": len(cases)}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
