#!/usr/bin/env python3
"""Review-only BF-topology/DF-radial full-perimeter notch corroborator."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import gc
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


JOB_SCHEMA = "argos_ocv03_o3p9_front_split_notch_job_v1"
CANDIDATE_LOCAL_TOPOLOGY_ERRORS = frozenset(
    {
        "No top-connected wafer component qualified.",
        "Top-connected wafer component has no external contour.",
        "Wafer contour covers fewer than two columns.",
        "Lower-side contour-noise population is empty.",
    }
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, f"Cannot load dependency: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def module_under_root(module_file: str, root: Path, label: str) -> str:
    resolved = Path(module_file).resolve(strict=True)
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise ValueError(f"{label} did not load from the pinned runtime: {resolved}") from exc
    return str(resolved)


def circular_distance(a: float, b: float) -> float:
    return abs((a - b + 180.0) % 360.0 - 180.0)


def contour_angle(x: float, y: float, width: int, inward: float, radius: float, crop_center: float) -> float:
    return (crop_center + math.degrees(math.atan2(x - (width - 1.0) / 2.0, radius + y - inward))) % 360.0


def load_job(path: Path) -> tuple[dict[str, Any], Path, Path, Path, Path, Path]:
    job = json.loads(path.read_text(encoding="utf-8"))
    require(job.get("schema") == JOB_SCHEMA, "O3P9 job schema changed.")
    for field in (
        "trainingEligible",
        "xmlEligible",
        "productionEligible",
        "productionRoutingEnabled",
        "knownNotchLocationConsumed",
        "notchAnglePriorConsumed",
        "fixedAngularSearchWindowConsumed",
        "scorerInputsPresent",
        "sourceMutationAllowed",
        "rasterOutputAllowed",
        "liveProviderActivation",
        "backsidePixelsConsumed",
        "dfTopologyInvocationAllowed",
    ):
        require(job.get(field) is False, f"Forbidden O3P9 authority changed: {field}")
    require(job.get("reviewOnly") is True, "O3P9 must remain review-only.")
    require(
        job.get("channelMethods") == {
            "BF": "O3L8_TOP_CONNECTED_TOPOLOGY_MEASURED_CONTOUR",
            "DF": "FROZEN_R6_OUTER_EDGE_RADIAL_FULL_360",
        },
        "O3P9 channel-method split changed.",
    )
    require(
        job.get("candidateLocalTopologyErrors") == sorted(CANDIDATE_LOCAL_TOPOLOGY_ERRORS),
        "O3P9 candidate-local exception contract changed.",
    )
    runtime_root = Path(str(job["runtimeRoot"])).resolve(strict=True)
    runtime_gate = Path(str(job["runtimeGate"]["path"])).resolve(strict=True)
    topology_path = Path(str(job["topologyEngine"]["path"])).resolve(strict=True)
    renderer_path = Path(str(job["cropEngine"]["path"])).resolve(strict=True)
    output_path = Path(str(job["outputPath"])).resolve(strict=False)
    require(runtime_root.is_dir() and output_path.parent.is_dir(), "O3P9 runtime or output parent is absent.")
    require(
        not output_path.exists() and not output_path.with_name(output_path.name + ".partial").exists(),
        "O3P9 output must be create-new.",
    )
    for record, label in (
        (job["runtimeGate"], "runtime gate"),
        (job["topologyEngine"], "topology engine"),
        (job["cropEngine"], "crop engine"),
    ):
        resolved = Path(str(record["path"])).resolve(strict=True)
        require(sha256_file(resolved) == str(record["sha256"]).upper(), f"O3P9 {label} changed.")
    require(
        json.loads(runtime_gate.read_text(encoding="utf-8")).get("state") == "PASS_O3P2_LOCAL_RUNTIME_INSTALLED",
        "O3P9 runtime gate is not PASS.",
    )
    module_under_root(str(cv2.__file__), runtime_root, "OpenCV")
    module_under_root(str(np.__file__), runtime_root, "NumPy")
    require(cv2.__version__ == str(job["expectedOpenCvVersion"]), "O3P9 OpenCV version changed.")
    require(np.__version__ == str(job["expectedNumpyVersion"]), "O3P9 NumPy version changed.")
    return job, runtime_root, runtime_gate, topology_path, renderer_path, output_path


def candidate_seeds(result: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for index, physical in enumerate(result.get("physicalIndentationCandidates", []), start=1):
        rows.append(
            {
                "seedId": f"P{index:03d}",
                "seedClass": "R6_BF_DF_PHYSICAL",
                "seedAngleDegrees": float(physical["reviewAngleDegrees"]),
                "bfCandidate": dict(physical["bf"]),
                "dfCandidate": dict(physical["df"]),
            }
        )
    for index, candidate in enumerate(result.get("dfOnlyBoundaryCandidates", []), start=1):
        rows.append(
            {
                "seedId": f"D{index:03d}",
                "seedClass": "R6_DF_ONLY",
                "seedAngleDegrees": float(candidate["centerAngleDegrees"]),
                "bfCandidate": None,
                "dfCandidate": dict(candidate),
            }
        )
    rows.sort(key=lambda item: (float(item["seedAngleDegrees"]), str(item["seedId"])))
    return rows


def best_topology_feature(
    edge: np.ndarray,
    geometry: np.ndarray,
    support: np.ndarray,
    crop_center: float,
    inward: int,
    radius: float,
    allowed_center: float,
    allowed_half_width: float,
    job: dict[str, Any],
) -> dict[str, Any] | None:
    residual = cv2.GaussianBlur(
        (edge - geometry).reshape(1, -1),
        (0, 0),
        sigmaX=float(job["corroboration"]["contourSmoothingSigmaPx"]),
    ).reshape(-1)
    width = residual.size
    possible: list[dict[str, Any]] = []
    for span_value in job["corroboration"]["shoulderSpansPx"]:
        span = int(span_value)
        closing = cv2.morphologyEx(
            residual.astype(np.float32).reshape(1, -1),
            cv2.MORPH_CLOSE,
            cv2.getStructuringElement(cv2.MORPH_RECT, (2 * span + 1, 1)),
        ).reshape(-1)
        depth = cv2.GaussianBlur((closing - residual).reshape(1, -1), (0, 0), sigmaX=1.5).reshape(-1)
        suppression_width = int(job["corroboration"]["patternSuppressionWidthPx"])
        if suppression_width % 2 == 0:
            suppression_width += 1
        depth = cv2.morphologyEx(
            depth.astype(np.float32).reshape(1, -1),
            cv2.MORPH_OPEN,
            cv2.getStructuringElement(cv2.MORPH_RECT, (suppression_width, 1)),
        ).reshape(-1)
        depth = cv2.GaussianBlur(depth.reshape(1, -1), (0, 0), sigmaX=3.0).reshape(-1)
        guard = max(3, span // 16)
        for tip in range(span, width - span):
            if depth[tip] + 1.0e-6 < float(np.max(depth[tip - 2 : tip + 3])):
                continue
            tip_angle = contour_angle(float(tip), float(edge[tip]), width, float(inward), radius, crop_center)
            if circular_distance(tip_angle, allowed_center) > allowed_half_width:
                continue
            left_values = residual[tip - span : tip - guard]
            right_values = residual[tip + guard + 1 : tip + span + 1]
            if left_values.size == 0 or right_values.size == 0:
                continue
            left = tip - span + int(np.argmax(left_values))
            right = tip + guard + 1 + int(np.argmax(right_values))
            segment_support = support[left : right + 1]
            left_level = float(residual[left])
            right_level = float(residual[right])
            possible.append(
                {
                    "spanPx": span,
                    "tipX": tip,
                    "leftX": left,
                    "rightX": right,
                    "widthPx": right - left + 1,
                    "tipAngleDegrees": tip_angle,
                    "leftAngleDegrees": contour_angle(float(left), float(edge[left]), width, float(inward), radius, crop_center),
                    "rightAngleDegrees": contour_angle(float(right), float(edge[right]), width, float(inward), radius, crop_center),
                    "pairedShoulderProminencePx": min(left_level, right_level) - float(residual[tip]),
                    "closingDepthPx": float(depth[tip]),
                    "patternSuppressionWidthPx": suppression_width,
                    "shoulderLevelDifferencePx": abs(left_level - right_level),
                    "meanSupport": float(np.mean(segment_support)),
                    "minimumSupport": float(np.min(segment_support)),
                    "tipSupport": float(support[tip]),
                    "allowedCenterDegrees": allowed_center,
                    "allowedHalfWidthDegrees": allowed_half_width,
                }
            )
    if not possible:
        return None
    possible.sort(
        key=lambda item: (
            -float(item["pairedShoulderProminencePx"]),
            -float(item["closingDepthPx"]),
            int(item["tipX"]),
            int(item["spanPx"]),
        )
    )
    return possible[0]


def rejected_bf(seed: dict[str, Any], crop_center: float, message: str) -> dict[str, Any]:
    return {
        "channel": "BF",
        "cropCenterAngleDegrees": crop_center,
        "topologyObservationState": "REJECTED_CANDIDATE_LOCAL_TOPOLOGY_INSUFFICIENCY",
        "topologyInsufficiencyReason": message,
        "topologyEvidence": None,
        "contourComplete": False,
        "feature": None,
        "topologyToDfRadialDepthRatio": None,
        "topologyPassed": False,
        "cleanCropPersisted": False,
        "rasterOutputCreated": False,
    }


def refine_bf(
    image: np.ndarray,
    fit: dict[str, Any],
    seed: dict[str, Any],
    topology: Any,
    renderer: Any,
    job: dict[str, Any],
) -> dict[str, Any]:
    bf_candidate = seed["bfCandidate"]
    df_candidate = seed["dfCandidate"]
    crop_center = float(df_candidate["centerAngleDegrees"]) if bf_candidate is None else float(bf_candidate["centerAngleDegrees"])
    allowed_center = float(df_candidate["centerAngleDegrees"])
    allowed_half_width = float(job["corroboration"]["unseededSearchHalfWidthDegrees"])
    if bf_candidate is not None:
        allowed_half_width = max(
            allowed_half_width,
            0.5 * float(bf_candidate["widthDegrees"]) + float(job["corroboration"]["seedIntervalMarginDegrees"]),
        )
    crop = job["crop"]
    width = int(crop["widthPx"])
    inward = int(crop["inwardPx"])
    outward = int(crop["outwardPx"])
    radius = float(fit["radius"])
    map_x, map_y = renderer.local_grid_maps(
        float(fit["centerX"]),
        float(fit["centerY"]),
        radius,
        crop_center,
        width,
        inward,
        outward,
    )
    clean = cv2.remap(image, map_x, map_y, interpolation=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    require(clean.shape == (inward + outward, width), "O3P9 crop shape changed.")
    geometry = topology.circle_geometry(width, float(inward), radius)
    try:
        edge, support, _, _, evidence = topology.topology_edge(clean, geometry, dict(job["topologyConfig"]))
    except ValueError as exc:
        message = str(exc)
        if message not in CANDIDATE_LOCAL_TOPOLOGY_ERRORS:
            raise
        return rejected_bf(seed, crop_center, message)
    complete = (
        float(evidence["coverageFraction"]) >= float(job["topologyConfig"]["minimumContourCoverage"])
        and int(evidence["longestInterpolatedGapPx"]) <= int(job["topologyConfig"]["maximumInterpolatedGapPx"])
    )
    feature = best_topology_feature(edge, geometry, support, crop_center, inward, radius, allowed_center, allowed_half_width, job)
    df_depth = float(df_candidate["maximumDepthPx"])
    ratio = None if feature is None or df_depth <= 0.0 else float(feature["pairedShoulderProminencePx"]) / df_depth
    passed = (
        complete
        and feature is not None
        and float(feature["pairedShoulderProminencePx"]) >= float(job["corroboration"]["minimumContourProminencePx"])
        and float(feature["meanSupport"]) >= float(job["corroboration"]["minimumMeanSupport"])
        and float(feature["tipSupport"]) >= float(job["corroboration"]["minimumTipSupport"])
        and ratio is not None
        and ratio >= float(job["corroboration"]["minimumTopologyToDfRadialDepthRatio"])
    )
    return {
        "channel": "BF",
        "cropCenterAngleDegrees": crop_center,
        "topologyObservationState": "OBSERVED",
        "topologyInsufficiencyReason": None,
        "topologyEvidence": evidence,
        "contourComplete": complete,
        "feature": feature,
        "topologyToDfRadialDepthRatio": ratio,
        "topologyPassed": passed,
        "cleanCropPersisted": False,
        "rasterOutputCreated": False,
    }


def decision_for_count(count: int) -> str:
    if count == 1:
        return "PASS_REVIEW_ONLY_UNIQUE_BF_TOPOLOGY_DF_RADIAL_NOTCH"
    if count == 0:
        return "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH"
    return "HOLD_MULTIPLE_BF_TOPOLOGY_DF_RADIAL_NOTCHES"


def evaluate_candidate(
    bf: dict[str, Any],
    df: dict[str, Any],
    job: dict[str, Any],
) -> tuple[bool, float | None, bool]:
    width_passed = float(df["widthDegrees"]) >= float(job["corroboration"]["minimumDfRadialIntervalWidthDegrees"])
    angle_difference = None if bf["feature"] is None else circular_distance(
        float(bf["feature"]["tipAngleDegrees"]),
        float(df["centerAngleDegrees"]),
    )
    passed = (
        bool(bf["topologyPassed"])
        and width_passed
        and angle_difference is not None
        and angle_difference <= float(job["corroboration"]["maximumBfDfAngleDifferenceDegrees"])
    )
    return width_passed, angle_difference, passed


def process_identity(row: dict[str, Any], topology: Any, renderer: Any, job: dict[str, Any]) -> dict[str, Any]:
    seed_path = Path(str(row["r6SeedResult"]["path"])).resolve(strict=True)
    require(sha256_file(seed_path) == str(row["r6SeedResult"]["sha256"]).upper(), f"R6 seed result changed: {seed_path}")
    seed_result = json.loads(seed_path.read_text(encoding="utf-8"))
    require(
        seed_result.get("identity") == row["identity"] and seed_result.get("fullPerimeterInference") is True,
        "R6 seed identity/scope changed.",
    )
    require(
        seed_result.get("knownNotchLocationConsumed") is False and seed_result.get("notchAnglePriorConsumed") is False,
        "R6 seed consumed a forbidden prior.",
    )
    seeds = candidate_seeds(seed_result)
    require(1 <= len(seeds) <= int(job["corroboration"]["maximumSeedCountPerWafer"]), "O3P9 seed count is outside the bound.")
    for channel in ("bf", "df"):
        source = row[channel]
        source_path = Path(str(source["path"])).resolve(strict=True)
        require(source_path.stat().st_size == int(source["bytes"]), f"O3P9 {channel.upper()} byte count changed: {source_path}")
        require(sha256_file(source_path) == str(source["sha256"]).upper(), f"O3P9 {channel.upper()} source hash changed: {source_path}")
    bf_path = Path(str(row["bf"]["path"])).resolve(strict=True)
    bf_image = cv2.imread(str(bf_path), cv2.IMREAD_GRAYSCALE)
    require(bf_image is not None, f"O3P9 BF decode failed: {bf_path}")
    bf_fit = dict(seed_result["bf"]["fit"])
    require(
        bf_image.shape == (int(seed_result["bf"]["heightPx"]), int(seed_result["bf"]["widthPx"])),
        "O3P9 BF dimensions changed.",
    )
    output_rows: list[dict[str, Any]] = []
    eligible: list[dict[str, Any]] = []
    for seed in seeds:
        bf = refine_bf(bf_image, bf_fit, seed, topology, renderer, job)
        df = seed["dfCandidate"]
        width_passed, angle_difference, passed = evaluate_candidate(bf, df, job)
        result = {
            "seedId": seed["seedId"],
            "seedClass": seed["seedClass"],
            "seedAngleDegrees": seed["seedAngleDegrees"],
            "bf": bf,
            "dfRadial": df,
            "dfRadialIntervalWidthPassed": width_passed,
            "bfTopologyDfRadialAngleDifferenceDegrees": angle_difference,
            "eligible": passed,
            "dfTopologyInvoked": False,
            "bfOnlySeedConsumed": False,
        }
        output_rows.append(result)
        if passed:
            eligible.append(result)
    del bf_image
    gc.collect()
    return {
        "identity": row["identity"],
        "state": decision_for_count(len(eligible)),
        "r6SeedResult": {"path": str(seed_path), "sha256": str(row["r6SeedResult"]["sha256"]).upper()},
        "seedCount": len(seeds),
        "eligibleCount": len(eligible),
        "candidateLocalTopologyInsufficiencyCount": sum(
            1 for result in output_rows if result["bf"]["topologyObservationState"] == "REJECTED_CANDIDATE_LOCAL_TOPOLOGY_INSUFFICIENCY"
        ),
        "selected": eligible[0] if len(eligible) == 1 else None,
        "seeds": output_rows,
        "fullPerimeterSeedInference": True,
        "dfTopologyInvocationCount": 0,
        "knownNotchLocationConsumed": False,
        "rasterOutputCreated": False,
    }


def run(job_path: Path, job: dict[str, Any], runtime_root: Path, topology_path: Path, renderer_path: Path, output_path: Path) -> dict[str, Any]:
    topology = load_module("argos_o3p9_topology", topology_path)
    renderer = load_module("argos_o3p9_crop", renderer_path)
    rows = [process_identity(row, topology, renderer, job) for row in job["inputs"]]
    require(len(rows) == int(job["expectedInputCount"]), "O3P9 input count changed.")
    result = {
        "schema": "argos_ocv03_o3p9_front_split_notch_result_v1",
        "revision": str(job["revision"]),
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "COMPLETE_O3P9_POST2_BF_TOPOLOGY_DF_RADIAL_REVIEW_ONLY",
        "jobPath": str(job_path),
        "jobSha256": sha256_file(job_path),
        "runtime": {
            "root": str(runtime_root),
            "opencvVersion": cv2.__version__,
            "numpyVersion": np.__version__,
            "opencvModulePath": module_under_root(str(cv2.__file__), runtime_root, "OpenCV"),
            "numpyModulePath": module_under_root(str(np.__file__), runtime_root, "NumPy"),
        },
        "channelMethods": job["channelMethods"],
        "dfTopologyInvocationCount": 0,
        "maximumDfRadialIntervalWidthEnabled": False,
        "corroboration": job["corroboration"],
        "inputCount": len(rows),
        "rows": rows,
        "knownNotchLocationConsumed": False,
        "notchAnglePriorConsumed": False,
        "fixedAngularSearchWindowConsumed": False,
        "scorerInputsConsumed": False,
        "backsidePixelsConsumed": False,
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
    return {
        "state": result["state"],
        "outputPath": str(output_path),
        "outputSha256": sha256_file(output_path),
        "inputCount": len(rows),
        "states": [row["state"] for row in rows],
        "dfTopologyInvocationCount": 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", required=True)
    parser.add_argument("--preflight", action="store_true")
    arguments = parser.parse_args()
    job_path = Path(arguments.job).resolve(strict=True)
    job, runtime_root, _, topology_path, renderer_path, output_path = load_job(job_path)
    for row in job["inputs"]:
        seed = Path(str(row["r6SeedResult"]["path"])).resolve(strict=True)
        require(sha256_file(seed) == str(row["r6SeedResult"]["sha256"]).upper(), f"R6 seed changed: {seed}")
        for channel in ("bf", "df"):
            source = Path(str(row[channel]["path"])).resolve(strict=True)
            require(source.stat().st_size == int(row[channel]["bytes"]), f"O3P9 source byte count changed: {source}")
            require(sha256_file(source) == str(row[channel]["sha256"]).upper(), f"O3P9 source hash changed: {source}")
    if arguments.preflight:
        result = {
            "state": "PASS_O3P9_FRONT_SPLIT_NOTCH_PREFLIGHT",
            "jobSha256": sha256_file(job_path),
            "inputCount": len(job["inputs"]),
            "channelMethods": job["channelMethods"],
            "dfTopologyInvocationCount": 0,
            "sourceHashesVerified": True,
            "r6SeedHashesVerified": True,
            "imageBytesDecoded": False,
            "outputCreated": False,
            "knownNotchLocationConsumed": False,
            "reviewOnly": True,
        }
    else:
        result = run(job_path, job, runtime_root, topology_path, renderer_path, output_path)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

