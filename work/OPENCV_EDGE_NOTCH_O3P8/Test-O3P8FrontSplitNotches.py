#!/usr/bin/env python3
"""Synthetic and structural controls for the O3P8 frontside channel split."""

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


SCHEMA = "argos_ocv03_o3p8_synthetic_invocation_v1"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, f"Cannot load dependency: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def synthetic_crop(topology: Any, depth: float, brightness: int) -> tuple[np.ndarray, np.ndarray]:
    width, height, inward, radius = 1000, 600, 420, 5150.0
    geometry = topology.circle_geometry(width, float(inward), radius)
    x = np.arange(width, dtype=np.float32)
    notch = depth * np.exp(-0.5 * np.square((x - 500.0) / 58.0))
    boundary = geometry - notch
    image = np.zeros((height, width), dtype=np.uint8)
    for column in range(width):
        bottom = max(0, min(height - 1, int(round(float(boundary[column])))))
        image[: bottom + 1, column] = brightness
    for street_x in range(28, width, 47):
        image[:390, street_x : street_x + 5] = 0
    for street_y in range(36, 390, 43):
        image[street_y : street_y + 5, :] = 0
    return image, geometry


def bf_measurement(engine: Any, topology: Any, job: dict[str, Any], depth: float, df_depth: float) -> dict[str, Any]:
    image, geometry = synthetic_crop(topology, depth, 185)
    edge, support, _, _, evidence = topology.topology_edge(image, geometry, dict(job["topologyConfig"]))
    complete = (
        float(evidence["coverageFraction"]) >= float(job["topologyConfig"]["minimumContourCoverage"])
        and int(evidence["longestInterpolatedGapPx"]) <= int(job["topologyConfig"]["maximumInterpolatedGapPx"])
    )
    feature = engine.best_topology_feature(edge, geometry, support, 120.0, 420, 5150.0, 120.0, 2.0, job)
    ratio = None if feature is None else float(feature["pairedShoulderProminencePx"]) / df_depth
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
        "topologyObservationState": "OBSERVED",
        "topologyEvidence": evidence,
        "contourComplete": complete,
        "feature": feature,
        "topologyToDfRadialDepthRatio": ratio,
        "topologyPassed": passed,
    }


class IdentityRenderer:
    @staticmethod
    def local_grid_maps(center_x: float, center_y: float, radius: float, angle: float, width: int, inward: int, outward: int) -> tuple[np.ndarray, np.ndarray]:
        del center_x, center_y, radius, angle
        map_x = np.tile(np.arange(width, dtype=np.float32), (inward + outward, 1))
        map_y = np.tile(np.arange(inward + outward, dtype=np.float32).reshape(-1, 1), (1, width))
        return map_x, map_y


class SequencedTopology:
    def __init__(self, messages: list[str | None]) -> None:
        self.messages = messages
        self.calls = 0

    @staticmethod
    def circle_geometry(width: int, inward: float, radius: float) -> np.ndarray:
        del radius
        return np.full(width, inward, dtype=np.float32)

    def topology_edge(self, clean: np.ndarray, geometry: np.ndarray, config: dict[str, Any]) -> tuple[np.ndarray, np.ndarray, None, None, dict[str, Any]]:
        del clean, config
        message = self.messages[self.calls] if self.calls < len(self.messages) else None
        self.calls += 1
        if message is not None:
            raise ValueError(message)
        x = np.arange(geometry.size, dtype=np.float32)
        edge = geometry - 12.0 * np.exp(-0.5 * np.square((x - 500.0) / 58.0))
        support = np.ones(geometry.size, dtype=np.float32)
        return edge, support, None, None, {"coverageFraction": 1.0, "longestInterpolatedGapPx": 0}


def structural_controls(engine: Any, engine_path: Path, job: dict[str, Any]) -> dict[str, Any]:
    source = engine_path.read_text(encoding="utf-8")
    topology_invocation_count = source.count("topology.topology_edge(")
    synthetic_seed_result = {
        "physicalIndentationCandidates": [
            {
                "reviewAngleDegrees": 120.0,
                "bf": {"centerAngleDegrees": 120.0},
                "df": {"centerAngleDegrees": 120.0},
            }
        ],
        "bfOnlyBoundaryCandidates": [{"centerAngleDegrees": 30.0}],
        "dfOnlyBoundaryCandidates": [{"centerAngleDegrees": 240.0}],
    }
    classes = [row["seedClass"] for row in engine.candidate_seeds(synthetic_seed_result)]
    passed = (
        topology_invocation_count == 1
        and job["dfTopologyInvocationAllowed"] is False
        and job["channelMethods"]["DF"] == "FROZEN_R6_OUTER_EDGE_RADIAL_FULL_360"
        and classes == ["R6_BF_DF_PHYSICAL", "R6_DF_ONLY"]
        and "R6_BF_ONLY" not in classes
    )
    return {
        "topologyEdgeSourceInvocationCount": topology_invocation_count,
        "onlyBfRefineFunctionInvokesTopology": topology_invocation_count == 1,
        "dfTopologyInvocationAllowed": job["dfTopologyInvocationAllowed"],
        "candidateSeedClasses": classes,
        "bfOnlySeedExcluded": "R6_BF_ONLY" not in classes,
        "passed": passed,
    }


def exception_controls(engine: Any, job: dict[str, Any]) -> dict[str, Any]:
    image = np.zeros((600, 1000), dtype=np.uint8)
    fit = {"centerX": 500.0, "centerY": 500.0, "radius": 5150.0}
    seed = {
        "seedId": "D001",
        "seedClass": "R6_DF_ONLY",
        "seedAngleDegrees": 120.0,
        "bfCandidate": None,
        "dfCandidate": {"centerAngleDegrees": 120.0, "widthDegrees": 2.0, "maximumDepthPx": 20.0},
    }
    exact_message = "Wafer contour covers fewer than two columns."
    topology = SequencedTopology([exact_message, None, None])
    renderer = IdentityRenderer()
    rejected = engine.refine_bf(image, fit, seed, topology, renderer, job)
    later_candidate = engine.refine_bf(image, fit, seed, topology, renderer, job)
    later_wafer = engine.refine_bf(image, fit, seed, topology, renderer, job)
    unknown_propagated = False
    try:
        engine.refine_bf(image, fit, seed, SequencedTopology(["Unexpected topology fault."]), renderer, job)
    except ValueError as exc:
        unknown_propagated = str(exc) == "Unexpected topology fault."
    passed = (
        rejected["topologyObservationState"] == "REJECTED_CANDIDATE_LOCAL_TOPOLOGY_INSUFFICIENCY"
        and later_candidate["topologyPassed"] is True
        and later_wafer["topologyPassed"] is True
        and topology.calls == 3
        and unknown_propagated
    )
    return {
        "exactDelegatedException": exact_message,
        "laterCandidateContinued": later_candidate["topologyPassed"],
        "laterWaferContinued": later_wafer["topologyPassed"],
        "unknownExceptionRemainedBatchFatal": unknown_propagated,
        "passed": passed,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--invocation", required=True)
    parser.add_argument("--preflight", action="store_true")
    arguments = parser.parse_args()
    invocation_path = Path(arguments.invocation).resolve(strict=True)
    invocation = json.loads(invocation_path.read_text(encoding="utf-8"))
    require(invocation.get("schema") == SCHEMA, "O3P8 synthetic invocation schema changed.")
    require(invocation.get("reviewOnly") is True and invocation.get("productionRoutingEnabled") is False, "O3P8 synthetic authority widened.")
    output_path = Path(str(invocation["outputPath"])).resolve(strict=False)
    require(
        output_path.parent.is_dir() and not output_path.exists() and not output_path.with_name(output_path.name + ".partial").exists(),
        "O3P8 synthetic output must be create-new.",
    )
    engine_path = Path(str(invocation["engine"]["path"])).resolve(strict=True)
    topology_path = Path(str(invocation["topologyEngine"]["path"])).resolve(strict=True)
    job_path = Path(str(invocation["job"]["path"])).resolve(strict=True)
    for record, path in ((invocation["engine"], engine_path), (invocation["topologyEngine"], topology_path), (invocation["job"], job_path)):
        require(sha256_file(path) == str(record["sha256"]).upper(), f"Synthetic dependency changed: {path}")
    if arguments.preflight:
        result = {
            "state": "PASS_O3P8_SYNTHETIC_PREFLIGHT",
            "invocationSha256": sha256_file(invocation_path),
            "pixelsGenerated": False,
            "outputCreated": False,
            "reviewOnly": True,
        }
    else:
        engine = load_module("argos_o3p8_synthetic_engine", engine_path)
        topology = load_module("argos_o3p8_synthetic_topology", topology_path)
        job = json.loads(job_path.read_text(encoding="utf-8"))
        cases: list[dict[str, Any]] = []
        for case_id, bf_depth, df_depth, df_width, df_angle, expected in (
            ("DEEP_PAIRED_NOTCH", 64.0, 70.0, 2.0, 120.0, True),
            ("SHALLOW_PAIRED_NOTCH", 6.0, 10.0, 1.2, 120.0, True),
            ("BROAD_PAIRED_NOTCH_NO_MAXIMUM_WIDTH", 8.0, 12.0, 5.8, 120.0, True),
            ("NARROW_PERIODIC_DF_RESPONSE", 12.0, 30.0, 0.4, 120.0, False),
            ("BF_NO_NOTCH", 0.0, 20.0, 2.0, 120.0, False),
            ("CROSS_METHOD_ANGLE_MISMATCH", 12.0, 20.0, 2.0, 124.0, False),
        ):
            bf = bf_measurement(engine, topology, job, bf_depth, df_depth)
            df = {"centerAngleDegrees": df_angle, "widthDegrees": df_width, "maximumDepthPx": df_depth}
            width_passed, difference, observed = engine.evaluate_candidate(bf, df, job)
            cases.append(
                {
                    "caseId": case_id,
                    "bf": bf,
                    "dfRadial": df,
                    "dfRadialIntervalWidthPassed": width_passed,
                    "angleDifferenceDegrees": difference,
                    "expectedEligible": expected,
                    "observedEligible": observed,
                    "passed": observed is expected,
                }
            )
        decisions = {"zero": engine.decision_for_count(0), "one": engine.decision_for_count(1), "two": engine.decision_for_count(2)}
        decision_passed = decisions == {
            "zero": "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH",
            "one": "PASS_REVIEW_ONLY_UNIQUE_BF_TOPOLOGY_DF_RADIAL_NOTCH",
            "two": "HOLD_MULTIPLE_BF_TOPOLOGY_DF_RADIAL_NOTCHES",
        }
        structural = structural_controls(engine, engine_path, job)
        exceptions = exception_controls(engine, job)
        passed = all(bool(case["passed"]) for case in cases) and decision_passed and bool(structural["passed"]) and bool(exceptions["passed"])
        result = {
            "schema": "argos_ocv03_o3p8_front_split_notch_synthetic_gate_v1",
            "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "state": "PASS_O3P8_FRONT_SPLIT_NOTCH_SYNTHETIC_GATE" if passed else "FAIL_O3P8_FRONT_SPLIT_NOTCH_SYNTHETIC_GATE",
            "invocationPath": str(invocation_path),
            "invocationSha256": sha256_file(invocation_path),
            "cases": cases,
            "decisionControls": decisions,
            "decisionControlsPassed": decision_passed,
            "structuralControls": structural,
            "exceptionControls": exceptions,
            "dfTopologyInvocationCount": 0,
            "broadNotchControlIncluded": True,
            "narrowPeriodicNegativeIncluded": True,
            "oneChannelSeedExclusionIncluded": True,
            "maximumDfRadialIntervalWidthEnabled": False,
            "knownNotchLocationConsumed": False,
            "rasterOutputCreated": False,
            "sourceMutationPerformed": False,
            "reviewOnly": True,
            "productionRoutingEnabled": False,
        }
        partial = output_path.with_name(output_path.name + ".partial")
        partial.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
        os.replace(partial, output_path)
        print(json.dumps({"state": result["state"], "outputPath": str(output_path), "outputSha256": sha256_file(output_path), "caseCount": len(cases)}, separators=(",", ":")))
        return 0 if passed else 1
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

