#!/usr/bin/env python3
"""Measure multiscale contour prominence on the six pinned O3L8 crops."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import sys
from typing import Any

import cv2
import numpy as np


SCHEMA = "argos_ocv03_o3p3_contour_feature_invocation_v1"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def module_under_root(module_file: str, root: Path, label: str) -> str:
    resolved = Path(module_file).resolve(strict=True)
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise ValueError(f"{label} did not load from the pinned runtime: {resolved}") from exc
    return str(resolved)


def load_module(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("argos_o3p3_locked_o3l8", path)
    require(spec is not None and spec.loader is not None, "Cannot load the pinned O3L8 engine.")
    module = importlib.util.module_from_spec(spec)
    sys.modules["argos_o3p3_locked_o3l8"] = module
    spec.loader.exec_module(module)
    return module


def angle(x: float, y: float, width: int, inward: float, radius: float, crop_center: float) -> float:
    return (crop_center + math.degrees(math.atan2(x - (width - 1.0) / 2.0, radius + y - inward))) % 360.0


def inventory_invocation(path: Path) -> tuple[dict[str, Any], Path, Path, Path, Path]:
    invocation = json.loads(path.read_text(encoding="utf-8"))
    require(invocation.get("schema") == SCHEMA, "Contour-feature invocation schema changed.")
    require(invocation.get("reviewOnly") is True and invocation.get("productionRoutingEnabled") is False, "Contour-feature authority widened.")
    require(invocation.get("knownNotchLocationAllowed") is False and invocation.get("sourceMutationAllowed") is False, "Contour-feature input authority widened.")
    root = Path(str(invocation["runtimeRoot"])).resolve(strict=True)
    gate = Path(str(invocation["runtimeGate"]["path"])).resolve(strict=True)
    engine = Path(str(invocation["engine"]["path"])).resolve(strict=True)
    job = Path(str(invocation["job"]["path"])).resolve(strict=True)
    output = Path(str(invocation["outputPath"])).resolve(strict=False)
    require(root.is_dir() and output.parent.is_dir(), "Runtime or output parent is absent.")
    require(not output.exists() and not output.with_name(output.name + ".partial").exists(), "Contour-feature output must be create-new.")
    require(sha256_file(gate) == str(invocation["runtimeGate"]["sha256"]).upper(), "Runtime gate changed.")
    require(json.loads(gate.read_text(encoding="utf-8")).get("state") == "PASS_O3P2_LOCAL_RUNTIME_INSTALLED", "Runtime gate is not PASS.")
    require(sha256_file(engine) == str(invocation["engine"]["sha256"]).upper(), "O3L8 engine changed.")
    require(sha256_file(job) == str(invocation["job"]["sha256"]).upper(), "O3L8 job changed.")
    module_under_root(str(cv2.__file__), root, "OpenCV")
    module_under_root(str(np.__file__), root, "NumPy")
    require(cv2.__version__ == str(invocation["expectedOpenCvVersion"]), "OpenCV version changed.")
    require(np.__version__ == str(invocation["expectedNumpyVersion"]), "NumPy version changed.")
    return invocation, root, engine, job, output


def multiscale_candidates(
    edge: np.ndarray,
    geometry: np.ndarray,
    support: np.ndarray,
    spans: list[int],
    sigma: float,
    row: dict[str, Any],
) -> list[dict[str, Any]]:
    residual = cv2.GaussianBlur((edge - geometry).reshape(1, -1), (0, 0), sigmaX=sigma).reshape(-1)
    width = residual.size
    scale_rows: list[dict[str, Any]] = []
    for span in spans:
        kernel = 2 * span + 1
        closing = cv2.morphologyEx(
            residual.astype(np.float32).reshape(1, -1),
            cv2.MORPH_CLOSE,
            cv2.getStructuringElement(cv2.MORPH_RECT, (kernel, 1)),
        ).reshape(-1)
        depth = cv2.GaussianBlur((closing - residual).reshape(1, -1), (0, 0), sigmaX=1.5).reshape(-1)
        possible: list[dict[str, Any]] = []
        shoulder_guard = max(3, span // 16)
        for tip in range(span, width - span):
            local = depth[tip - 2 : tip + 3]
            if depth[tip] + 1.0e-6 < float(np.max(local)):
                continue
            left_values = residual[tip - span : tip - shoulder_guard]
            right_values = residual[tip + shoulder_guard + 1 : tip + span + 1]
            if left_values.size == 0 or right_values.size == 0:
                continue
            left = tip - span + int(np.argmax(left_values))
            right = tip + shoulder_guard + 1 + int(np.argmax(right_values))
            left_level = float(residual[left])
            right_level = float(residual[right])
            prominence = min(left_level, right_level) - float(residual[tip])
            mouth_level = min(left_level, right_level)
            segment_support = support[left : right + 1]
            possible.append(
                {
                    "tipX": tip,
                    "leftShoulderX": left,
                    "rightShoulderX": right,
                    "widthPx": right - left + 1,
                    "tipAngleDegrees": angle(float(tip), float(edge[tip]), width, float(row["inwardY"]), float(row["radiusPx"]), float(row["cropCenterAngleDegrees"])),
                    "leftShoulderAngleDegrees": angle(float(left), float(edge[left]), width, float(row["inwardY"]), float(row["radiusPx"]), float(row["cropCenterAngleDegrees"])),
                    "rightShoulderAngleDegrees": angle(float(right), float(edge[right]), width, float(row["inwardY"]), float(row["radiusPx"]), float(row["cropCenterAngleDegrees"])),
                    "closingDepthPx": float(depth[tip]),
                    "pairedShoulderProminencePx": prominence,
                    "mouthLevelResidualPx": mouth_level,
                    "shoulderLevelDifferencePx": abs(left_level - right_level),
                    "meanSupport": float(np.mean(segment_support)),
                    "minimumSupport": float(np.min(segment_support)),
                    "tipSupport": float(support[tip]),
                }
            )
        possible.sort(key=lambda item: (-float(item["pairedShoulderProminencePx"]), -float(item["closingDepthPx"]), int(item["tipX"])))
        selected: list[dict[str, Any]] = []
        suppression = max(8, span // 3)
        for candidate in possible:
            if any(abs(int(candidate["tipX"]) - int(existing["tipX"])) <= suppression for existing in selected):
                continue
            selected.append(candidate)
            if len(selected) == 12:
                break
        scale_rows.append(
            {
                "shoulderSpanPx": span,
                "closingKernelPx": kernel,
                "depthMaximumPx": float(np.max(depth)),
                "depthP99Px": float(np.percentile(depth, 99.0)),
                "depthP995Px": float(np.percentile(depth, 99.5)),
                "topCandidates": selected,
            }
        )
    return scale_rows


def run(invocation_path: Path, invocation: dict[str, Any], runtime_root: Path, engine_path: Path, job_path: Path, output_path: Path) -> dict[str, Any]:
    engine = load_module(engine_path)
    job = json.loads(job_path.read_text(encoding="utf-8"))
    require(job.get("revision") == "FMOCV03_O3L8_20260827T213900Z", "O3L8 revision changed.")
    source_root = (job_path.parent / str(job["sourceRootRelativeToJob"])).resolve()
    rows: list[dict[str, Any]] = []
    for source in sorted(job["inputs"], key=lambda item: str(item["id"])):
        source_path = (source_root / str(source["path"])).resolve(strict=True)
        expected = str(source["sha256"]).upper()
        require(sha256_file(source_path) == expected, f"Source changed: {source_path}")
        clean = cv2.imread(str(source_path), cv2.IMREAD_GRAYSCALE)
        require(clean is not None and clean.shape == (600, 1000), f"Decode changed: {source_path}")
        geometry = engine.circle_geometry(1000, float(source["inwardY"]), float(source["radiusPx"]))
        edge, support, _, _, evidence = engine.topology_edge(clean, geometry, dict(job["config"]))
        scale_rows = multiscale_candidates(edge, geometry, support, [int(value) for value in invocation["shoulderSpansPx"]], float(invocation["contourSmoothingSigmaPx"]), source)
        rows.append(
            {
                "id": str(source["id"]),
                "pairId": str(source["pairId"]),
                "channel": str(source["channel"]),
                "source": {"path": str(source_path), "sha256": expected},
                "topologyEvidence": evidence,
                "contourComplete": float(evidence["coverageFraction"]) >= float(job["config"]["minimumContourCoverage"]) and int(evidence["longestInterpolatedGapPx"]) <= int(job["config"]["maximumInterpolatedGapPx"]),
                "scales": scale_rows,
            }
        )
    require(len(rows) == int(invocation["expectedInputCount"]), "Input count changed.")
    result = {
        "schema": "argos_ocv03_o3p3_contour_feature_measurement_v1",
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "PASS_O3P3_CONTOUR_FEATURE_MEASUREMENT",
        "invocationPath": str(invocation_path),
        "invocationSha256": sha256_file(invocation_path),
        "runtime": {
            "root": str(runtime_root),
            "gateSha256": str(invocation["runtimeGate"]["sha256"]).upper(),
            "opencvVersion": cv2.__version__,
            "numpyVersion": np.__version__,
            "opencvModulePath": module_under_root(str(cv2.__file__), runtime_root, "OpenCV"),
            "numpyModulePath": module_under_root(str(np.__file__), runtime_root, "NumPy"),
        },
        "inputCount": len(rows),
        "rows": rows,
        "operatorLabelsConsumedByMeasurement": False,
        "knownNotchLocationConsumed": False,
        "imageBytesEmittedToStdout": False,
        "rasterOutputCreated": False,
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
    arguments = parser.parse_args()
    invocation_path = Path(arguments.invocation).resolve(strict=True)
    invocation, runtime_root, engine_path, job_path, output_path = inventory_invocation(invocation_path)
    if arguments.preflight:
        job = json.loads(job_path.read_text(encoding="utf-8"))
        source_root = (job_path.parent / str(job["sourceRootRelativeToJob"])).resolve()
        source_count = 0
        for source in job["inputs"]:
            source_path = (source_root / str(source["path"])).resolve(strict=True)
            require(sha256_file(source_path) == str(source["sha256"]).upper(), f"Source changed: {source_path}")
            source_count += 1
        require(source_count == int(invocation["expectedInputCount"]), "Preflight input count changed.")
        result = {
            "state": "PASS_O3P3_CONTOUR_FEATURE_PREFLIGHT",
            "invocationSha256": sha256_file(invocation_path),
            "sourceCount": source_count,
            "sourceHashesVerified": True,
            "imageBytesDecoded": False,
            "outputCreated": False,
            "reviewOnly": True,
        }
    else:
        result = run(invocation_path, invocation, runtime_root, engine_path, job_path, output_path)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
