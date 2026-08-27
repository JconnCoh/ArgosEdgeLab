#!/usr/bin/env python3
"""Synthetic controls for topology notch axis and contour-hugging overlay."""

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
    spec = importlib.util.spec_from_file_location("o3l6", path)
    check(spec is not None and spec.loader is not None, "Cannot load engine.")
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
    wafer = yy < edge[None]
    image[wafer] += np.broadcast_to(periodic, image.shape)[wafer]
    for column in range(17 + phase % 43, width, 79):
        image[:390, max(0, column - 3) : min(width, column + 4)] -= 68.0
    for row in range(43 + phase % 29, 385, 57):
        image[max(0, row - 3) : min(height, row + 4)] -= 64.0
    image += rng.normal(0.0, noise, image.shape).astype(np.float32)
    return cv2.cvtColor(np.clip(image, 0, 255).astype(np.uint8), cv2.COLOR_GRAY2BGR), geometry.astype(np.float32)


def analyze(engine, image: np.ndarray, geometry: np.ndarray, cfg: dict):
    edge, support, enhanced, _, evidence = engine.topology_edge(cv2.cvtColor(image, cv2.COLOR_BGR2GRAY), geometry, cfg)
    unindented = engine.baseline(edge, geometry)
    found, _, _ = engine.notches(edge, unindented, support, cfg)
    state = "NONE" if not found else ("AMBIGUOUS" if len(found) > 1 and found[1]["score"] >= cfg["ambiguityScoreRatio"] * found[0]["score"] else "PRIMARY")
    return found, state, evidence, enhanced, edge, unindented


def assert_contour_overlay(engine, enhanced: np.ndarray, edge: np.ndarray, unindented: np.ndarray, found: list[dict]) -> dict:
    _, rendered, _ = engine.overlay(enhanced, edge, unindented, found, "SYNTHETIC_CONTOUR_CHECK")
    primary = found[0]
    left, right = int(primary["leftX"]), int(primary["rightX"])
    red = (rendered[:, :, 2] >= 220) & (rendered[:, :, 1] <= 60) & (rendered[:, :, 0] <= 60)
    hugging = []
    for x in range(left + 2, right - 1):
        y = int(round(float(edge[x])))
        hugging.append(bool(np.any(red[max(0, y - 5) : min(red.shape[0], y + 6), x])))
    coverage = float(np.mean(hugging)) if hugging else 0.0
    maximum_red_column = int(np.max(np.count_nonzero(red, axis=0)))
    check(coverage >= 0.90, f"Red contour did not hug the extracted notch across its mouth: {coverage}")
    check(maximum_red_column < 64, f"A full-height red center ray remains: {maximum_red_column} pixels")
    return {"redContourColumnCoverage": coverage, "maximumRedPixelsInOneColumn": maximum_red_column}


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
    overlay_gate = None
    for channel, seed, phase in (("BF", 9101, 13), ("DF", 9102, 39)):
        image, geometry = synthetic(seed, channel, [(441.0, 68.0, 36.0)], phase)
        found, state, evidence, enhanced, edge, unindented = analyze(engine, image, geometry, cfg)
        check(found and state == "PRIMARY", f"{channel} topology notch was not primary: count={len(found)} state={state}")
        axis_error = abs(float(found[0]["tipX"]) - 441.0)
        check(axis_error <= 12.0, f"{channel} deepest axis error exceeded 12 px: {axis_error}")
        check(float(evidence["coverageFraction"]) >= 0.99, f"{channel} contour coverage failed.")
        if channel == "BF":
            overlay_gate = assert_contour_overlay(engine, enhanced, edge, unindented, found)
        cases.append({"caseId": f"{channel}_TOPOLOGY_PERIODIC_NOTCH", "state": "PASS", "axisErrorPx": axis_error})
    image, geometry = synthetic(9201, "BF", [], 23)
    found, state, evidence, _, _, _ = analyze(engine, image, geometry, cfg)
    check(not found and state == "NONE", f"No-notch topology control produced {len(found)} candidates.")
    check(float(evidence["coverageFraction"]) >= 0.99, "No-notch contour coverage failed.")
    cases.append({"caseId": "TOPOLOGY_NO_NOTCH_NEGATIVE", "state": "PASS"})
    image, geometry = synthetic(9301, "DF", [(305.0, 64.0, 34.0), (700.0, 64.0, 34.0)], 47)
    found, state, _, _, _, _ = analyze(engine, image, geometry, cfg)
    check(len(found) >= 2 and state == "AMBIGUOUS", f"Two-indentation topology control did not hold: count={len(found)} state={state}")
    cases.append({"caseId": "TOPOLOGY_TWO_INDENTATIONS_HOLD", "state": "PASS", "candidateCount": len(found)})
    check(overlay_gate is not None, "Contour overlay gate was not executed.")
    gate = {
        "schema": "argos_ocv03_o3l6_synthetic_gate_v1",
        "state": "PASS_O3L6_WAFER_TOPOLOGY_AXIS_SYNTHETIC_GATE",
        "caseCount": len(cases),
        "cases": cases,
        "topConnectedWaferComponentProved": True,
        "deepestIndentationAxisPassed": True,
        "notchContourHuggingOverlayPassed": True,
        "fullHeightCenterLineAbsent": True,
        "overlayEvidence": overlay_gate,
        "periodicDieStreetsRejected": True,
        "noNotchNegativePassed": True,
        "twoIndentationHoldPassed": True,
        "thresholdRelaxationPerformed": False,
        "imageBytesEmittedToStdout": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False
    }
    new_gate(Path(args.gate).resolve(), gate)
    print(json.dumps({"state": gate["state"], "gate": str(Path(args.gate).resolve()), "caseCount": len(cases)}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
