#!/usr/bin/env python3
"""Bounded O3L8 development-crop profile measurement.

This tool decodes only the six already authorized O3L8 clean crops, reuses the
locked O3L8 contour extractor, and writes numeric contour/depth evidence.  It
does not render rasters, consume operator locations as detector inputs, or
modify the sources.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
from typing import Any

import cv2
import numpy as np


INVOCATION_SCHEMA = "argos_ocv03_o3p1_crop_profile_measurement_invocation_v1"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_module(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("argos_o3p1_locked_o3l8", path)
    require(spec is not None and spec.loader is not None, "Cannot load O3L8 dependency.")
    module = importlib.util.module_from_spec(spec)
    sys.modules["argos_o3p1_locked_o3l8"] = module
    spec.loader.exec_module(module)
    return module


def depth_profile(edge: np.ndarray, baseline: np.ndarray, config: dict[str, Any]) -> np.ndarray:
    depth = cv2.GaussianBlur((baseline - edge).reshape(1, -1), (0, 0), sigmaX=2.0).reshape(-1)
    kernel = int(config["patternSuppressionWidthPx"])
    if kernel % 2 == 0:
        kernel += 1
    depth = cv2.morphologyEx(
        depth.astype(np.float32).reshape(1, -1),
        cv2.MORPH_OPEN,
        cv2.getStructuringElement(cv2.MORPH_RECT, (kernel, 1)),
    ).reshape(-1)
    return cv2.GaussianBlur(depth.reshape(1, -1), (0, 0), sigmaX=3.0).reshape(-1)


def close_mask(mask: np.ndarray, width: int) -> np.ndarray:
    return cv2.morphologyEx(
        mask.astype(np.uint8).reshape(1, -1),
        cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_RECT, (width, 1)),
    ).reshape(-1).astype(bool)


def module_under_root(module_file: str, runtime_root: Path, label: str) -> str:
    resolved = Path(module_file).resolve(strict=True)
    try:
        resolved.relative_to(runtime_root)
    except ValueError as exc:
        raise ValueError(f"{label} did not load from the pinned runtime: {resolved}") from exc
    return str(resolved)


def validate_invocation(invocation_path: Path) -> tuple[dict[str, Any], Path, Path, Path, Path]:
    invocation = json.loads(invocation_path.read_text(encoding="utf-8"))
    require(invocation.get("schema") == INVOCATION_SCHEMA, "Measurement invocation schema changed.")
    require(invocation.get("reviewOnly") is True and invocation.get("productionRoutingEnabled") is False, "Measurement authority widened.")
    require(invocation.get("sourceMutationAllowed") is False and invocation.get("knownNotchLocationAllowed") is False, "Measurement input authority widened.")
    runtime_root = Path(str(invocation["runtimeRoot"])).resolve(strict=True)
    runtime_gate = Path(str(invocation["runtimeGate"]["path"])).resolve(strict=True)
    engine_path = Path(str(invocation["engine"]["path"])).resolve(strict=True)
    job_path = Path(str(invocation["job"]["path"])).resolve(strict=True)
    output_path = Path(str(invocation["outputPath"])).resolve(strict=False)
    require(runtime_root.is_dir(), "Pinned runtime root is absent.")
    require(sha256_file(runtime_gate) == str(invocation["runtimeGate"]["sha256"]).upper(), "Runtime gate changed.")
    runtime_value = json.loads(runtime_gate.read_text(encoding="utf-8"))
    require(runtime_value.get("state") == "PASS_O3P2_LOCAL_RUNTIME_INSTALLED", "Runtime gate is not PASS.")
    require(sha256_file(engine_path) == str(invocation["engine"]["sha256"]).upper(), "O3L8 engine hash changed.")
    require(sha256_file(job_path) == str(invocation["job"]["sha256"]).upper(), "O3L8 job hash changed.")
    require(output_path.parent.is_dir(), "Measurement output parent is absent.")
    require(not output_path.exists() and not output_path.with_name(output_path.name + ".partial").exists(), "Measurement output must be create-new.")
    module_under_root(str(cv2.__file__), runtime_root, "OpenCV")
    module_under_root(str(np.__file__), runtime_root, "NumPy")
    require(cv2.__version__ == str(invocation["expectedOpenCvVersion"]), "OpenCV version changed.")
    require(np.__version__ == str(invocation["expectedNumpyVersion"]), "NumPy version changed.")
    return invocation, runtime_root, engine_path, job_path, output_path


def validate_sources(job_path: Path, expected_count: int) -> list[dict[str, str]]:
    job = json.loads(job_path.read_text(encoding="utf-8"))
    require(job.get("revision") == "FMOCV03_O3L8_20260827T213900Z", "O3L8 revision changed.")
    source_root = (job_path.parent / str(job["sourceRootRelativeToJob"])).resolve()
    rows: list[dict[str, str]] = []
    for source in sorted(job["inputs"], key=lambda item: str(item["id"])):
        path = (source_root / str(source["path"])).resolve()
        expected = str(source["sha256"]).upper()
        require(path.is_file() and sha256_file(path) == expected, f"Source changed: {path}")
        rows.append({"id": str(source["id"]), "path": str(path), "sha256": expected})
    require(len(rows) == expected_count, "O3L8 input count changed.")
    return rows


def measure(invocation_path: Path, invocation: dict[str, Any], runtime_root: Path, engine_path: Path, job_path: Path, output_path: Path) -> dict[str, Any]:
    require(not output_path.exists() and not output_path.with_name(output_path.name + ".partial").exists(), "Output must be create-new.")
    engine = load_module(engine_path)
    job = json.loads(job_path.read_text(encoding="utf-8"))
    require(job.get("revision") == "FMOCV03_O3L8_20260827T213900Z", "O3L8 revision changed.")
    source_root = (job_path.parent / str(job["sourceRootRelativeToJob"])).resolve()
    config = dict(job["config"])
    rows: list[dict[str, Any]] = []
    for source in sorted(job["inputs"], key=lambda item: str(item["id"])):
        path = (source_root / str(source["path"])).resolve()
        require(path.is_file() and sha256_file(path) == str(source["sha256"]).upper(), f"Source changed: {path}")
        clean = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
        require(clean is not None and clean.shape == (600, 1000), f"Decode changed: {path}")
        geometry = engine.circle_geometry(1000, float(source["inwardY"]), float(source["radiusPx"]))
        edge, support, _, filled, evidence = engine.topology_edge(clean, geometry, config)
        unindented = engine.baseline(edge, geometry)
        depth = depth_profile(edge, unindented, config)
        center = float(np.median(depth))
        lower = depth[depth <= center]
        noise = max(1.4826 * float(np.median(np.abs(lower - center))), 0.5)
        sweeps: list[dict[str, Any]] = []
        for absolute in (4.0, 6.0, 8.0, 10.0, 12.0, 16.0, 20.0):
            threshold = max(absolute, center + 4.0 * noise)
            active = close_mask(depth >= threshold, int(config["candidateJoinWidthPx"]))
            segments: list[dict[str, Any]] = []
            for left, right in engine.runs(active):
                values = depth[left : right + 1]
                if values.size == 0:
                    continue
                tip = left + int(np.argmax(values))
                segments.append(
                    {
                        "leftX": int(left),
                        "rightX": int(right),
                        "widthPx": int(right - left + 1),
                        "tipX": int(tip),
                        "peakDepthPx": float(depth[tip]),
                        "meanSupport": float(np.mean(support[left : right + 1])),
                    }
                )
            segments.sort(key=lambda item: (-float(item["peakDepthPx"]), int(item["leftX"])))
            sweeps.append({"absoluteFloorPx": absolute, "effectiveThresholdPx": threshold, "segments": segments[:12]})
        rows.append(
            {
                "id": str(source["id"]),
                "pairId": str(source["pairId"]),
                "channel": str(source["channel"]),
                "source": {"path": str(path), "sha256": str(source["sha256"]).upper()},
                "topologyEvidence": evidence,
                "depthPopulation": {
                    "medianPx": center,
                    "lowerSideNoiseSigmaPx": noise,
                    "minimumPx": float(np.min(depth)),
                    "maximumPx": float(np.max(depth)),
                    "p95Px": float(np.percentile(depth, 95.0)),
                    "p99Px": float(np.percentile(depth, 99.0)),
                    "p995Px": float(np.percentile(depth, 99.5)),
                },
                "thresholdSweeps": sweeps,
            }
        )
    result = {
        "schema": "argos_ocv03_o3p1_crop_profile_measurement_v1",
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "PASS_O3P1_CROP_PROFILE_MEASUREMENT",
        "invocationPath": str(invocation_path),
        "invocationSha256": sha256_file(invocation_path),
        "runtime": {
            "root": str(runtime_root),
            "gatePath": str(Path(str(invocation["runtimeGate"]["path"])).resolve(strict=True)),
            "gateSha256": str(invocation["runtimeGate"]["sha256"]).upper(),
            "opencvVersion": cv2.__version__,
            "numpyVersion": np.__version__,
            "opencvModulePath": module_under_root(str(cv2.__file__), runtime_root, "OpenCV"),
            "numpyModulePath": module_under_root(str(np.__file__), runtime_root, "NumPy"),
        },
        "o3l8EngineSha256": sha256_file(engine_path),
        "o3l8JobSha256": sha256_file(job_path),
        "inputCount": len(rows),
        "rows": rows,
        "operatorLabelsConsumedByMeasurement": False,
        "knownNotchLocationConsumed": False,
        "imageBytesEmittedToStdout": False,
        "sourceMutationPerformed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    partial = output_path.with_name(output_path.name + ".partial")
    partial.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, output_path)
    return {"state": result["state"], "outputPath": str(output_path), "outputSha256": sha256_file(output_path), "inputCount": len(rows)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--invocation", required=True)
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    invocation_path = Path(args.invocation).resolve(strict=True)
    invocation, runtime_root, engine_path, job_path, output_path = validate_invocation(invocation_path)
    if args.preflight:
        source_rows = validate_sources(job_path, int(invocation["expectedInputCount"]))
        result = {
            "state": "PASS_O3P1_CROP_PROFILE_PREFLIGHT",
            "invocationSha256": sha256_file(invocation_path),
            "runtimeGateSha256": str(invocation["runtimeGate"]["sha256"]).upper(),
            "opencvModulePath": module_under_root(str(cv2.__file__), runtime_root, "OpenCV"),
            "numpyModulePath": module_under_root(str(np.__file__), runtime_root, "NumPy"),
            "sourceCount": len(source_rows),
            "sourceHashesVerified": True,
            "imageBytesDecoded": False,
            "outputCreated": False,
            "reviewOnly": True,
        }
    else:
        result = measure(invocation_path, invocation, runtime_root, engine_path, job_path, output_path)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
