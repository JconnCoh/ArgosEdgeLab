#!/usr/bin/env python3
"""Synthetic contour, decision, and candidate-boundary controls for O3P6."""

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


SCHEMA = "argos_ocv03_o3p6_synthetic_invocation_v1"


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


def synthetic_crop(topology: Any, depth: float, brightness: int, missing: tuple[int, int] | None = None) -> tuple[np.ndarray, np.ndarray]:
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
    if missing is not None:
        image[:, missing[0] : missing[1]] = 0
    return image, geometry


def channel_measurement(
    engine: Any,
    topology: Any,
    job: dict[str, Any],
    depth: float,
    radial_depth: float,
    brightness: int,
    missing: tuple[int, int] | None = None,
) -> dict[str, Any]:
    image, geometry = synthetic_crop(topology, depth, brightness, missing)
    edge, support, _, _, evidence = topology.topology_edge(image, geometry, dict(job["topologyConfig"]))
    complete = (
        float(evidence["coverageFraction"]) >= float(job["topologyConfig"]["minimumContourCoverage"])
        and int(evidence["longestInterpolatedGapPx"]) <= int(job["topologyConfig"]["maximumInterpolatedGapPx"])
    )
    candidate = {"centerAngleDegrees": 120.0, "widthDegrees": 3.0, "maximumDepthPx": radial_depth}
    feature = engine.best_topology_feature(edge, geometry, support, 120.0, 420, 5150.0, candidate, job)
    passed, ratio = engine.corroborated_channel(complete, feature, radial_depth, job)
    return {
        "contourComplete": complete,
        "coverageFraction": float(evidence["coverageFraction"]),
        "longestInterpolatedGapPx": int(evidence["longestInterpolatedGapPx"]),
        "prominencePx": None if feature is None else float(feature["pairedShoulderProminencePx"]),
        "tipAngleDegrees": None if feature is None else float(feature["tipAngleDegrees"]),
        "meanSupport": None if feature is None else float(feature["meanSupport"]),
        "tipSupport": None if feature is None else float(feature["tipSupport"]),
        "topologyToRadialDepthRatio": ratio,
        "channelCorroborated": passed,
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
        evidence = {"coverageFraction": 1.0, "longestInterpolatedGapPx": 0}
        return edge, support, None, None, evidence


def candidate_boundary_controls(engine: Any, job: dict[str, Any]) -> dict[str, Any]:
    image = np.zeros((600, 1000), dtype=np.uint8)
    fit = {"centerX": 500.0, "centerY": 500.0, "radius": 5150.0}
    seed = {
        "seedId": "P001",
        "seedClass": "SYNTHETIC",
        "seedAngleDegrees": 120.0,
        "bfCandidate": {"centerAngleDegrees": 120.0, "widthDegrees": 3.0, "maximumDepthPx": 20.0},
        "dfCandidate": {"centerAngleDegrees": 120.0, "widthDegrees": 3.0, "maximumDepthPx": 20.0},
    }
    exact_message = "Wafer contour covers fewer than two columns."
    sequenced = SequencedTopology([exact_message, None, None])
    renderer = IdentityRenderer()
    rejected = engine.refine_channel(image, fit, seed, "BF", sequenced, renderer, job)
    later_candidate = engine.refine_channel(image, fit, seed, "DF", sequenced, renderer, job)
    later_wafer = engine.refine_channel(image, fit, seed, "BF", sequenced, renderer, job)
    unknown_propagated = False
    try:
        engine.refine_channel(image, fit, seed, "BF", SequencedTopology(["Unexpected topology fault."]), renderer, job)
    except ValueError as exc:
        unknown_propagated = str(exc) == "Unexpected topology fault."
    passed = (
        rejected["topologyObservationState"] == "REJECTED_CANDIDATE_LOCAL_TOPOLOGY_INSUFFICIENCY"
        and rejected["topologyInsufficiencyReason"] == exact_message
        and rejected["channelCorroborated"] is False
        and later_candidate["topologyObservationState"] == "OBSERVED"
        and later_candidate["channelCorroborated"] is True
        and later_wafer["topologyObservationState"] == "OBSERVED"
        and later_wafer["channelCorroborated"] is True
        and sequenced.calls == 3
        and unknown_propagated
    )
    return {
        "exactDelegatedException": exact_message,
        "rejectedCandidate": rejected,
        "laterCandidateContinued": later_candidate["channelCorroborated"],
        "laterWaferContinued": later_wafer["channelCorroborated"],
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
    require(invocation.get("schema") == SCHEMA, "O3P6 synthetic invocation schema changed.")
    require(invocation.get("reviewOnly") is True and invocation.get("productionRoutingEnabled") is False, "O3P6 synthetic authority widened.")
    output_path = Path(str(invocation["outputPath"])).resolve(strict=False)
    require(
        output_path.parent.is_dir() and not output_path.exists() and not output_path.with_name(output_path.name + ".partial").exists(),
        "O3P6 synthetic output must be create-new.",
    )
    engine_path = Path(str(invocation["engine"]["path"])).resolve(strict=True)
    topology_path = Path(str(invocation["topologyEngine"]["path"])).resolve(strict=True)
    job_path = Path(str(invocation["job"]["path"])).resolve(strict=True)
    for record, path in ((invocation["engine"], engine_path), (invocation["topologyEngine"], topology_path), (invocation["job"], job_path)):
        require(sha256_file(path) == str(record["sha256"]).upper(), f"Synthetic dependency changed: {path}")
    if arguments.preflight:
        result = {
            "state": "PASS_O3P6_SYNTHETIC_PREFLIGHT",
            "invocationSha256": sha256_file(invocation_path),
            "pixelsGenerated": False,
            "outputCreated": False,
            "reviewOnly": True,
        }
    else:
        engine = load_module("argos_o3p6_synthetic_engine", engine_path)
        topology = load_module("argos_o3p6_synthetic_topology", topology_path)
        job = json.loads(job_path.read_text(encoding="utf-8"))
        cases: list[dict[str, Any]] = []
        for case_id, bf_depth, df_depth, bf_radial, df_radial, expected in (
            ("DEEP_PAIRED_NOTCH", 64.0, 68.0, 90.0, 96.0, True),
            ("SHALLOW_PAIRED_NOTCH_BELOW_OLD_20PX_FLOOR", 6.0, 6.5, 10.0, 11.0, True),
            ("ONE_CHANNEL_RESPONSE", 24.0, 0.0, 32.0, 8.0, False),
            ("PATTERNED_NO_NOTCH", 0.0, 0.0, 8.0, 8.0, False),
        ):
            bf = channel_measurement(engine, topology, job, bf_depth, bf_radial, 185)
            df = channel_measurement(engine, topology, job, df_depth, df_radial, 118)
            difference = None if bf["tipAngleDegrees"] is None or df["tipAngleDegrees"] is None else engine.circular_distance(float(bf["tipAngleDegrees"]), float(df["tipAngleDegrees"]))
            observed = (
                bool(bf["channelCorroborated"])
                and bool(df["channelCorroborated"])
                and difference is not None
                and difference <= float(job["corroboration"]["maximumBfDfRefinedAngleDifferenceDegrees"])
            )
            cases.append(
                {
                    "caseId": case_id,
                    "bf": bf,
                    "df": df,
                    "refinedAngleDifferenceDegrees": difference,
                    "expectedCorroborated": expected,
                    "observedCorroborated": observed,
                    "passed": observed is expected,
                }
            )
        missing_bf = channel_measurement(engine, topology, job, 24.0, 32.0, 185, (430, 570))
        missing_df = channel_measurement(engine, topology, job, 24.0, 32.0, 118)
        missing_observed = bool(missing_bf["channelCorroborated"]) and bool(missing_df["channelCorroborated"])
        cases.append(
            {
                "caseId": "MISSING_CONTOUR_NEGATIVE",
                "bf": missing_bf,
                "df": missing_df,
                "expectedCorroborated": False,
                "observedCorroborated": missing_observed,
                "passed": not missing_observed,
            }
        )
        count_controls = {
            "zero": engine.decision_for_corroborated_count(0),
            "one": engine.decision_for_corroborated_count(1),
            "two": engine.decision_for_corroborated_count(2),
        }
        count_passed = count_controls == {
            "zero": "HOLD_NO_TOPOLOGY_CORROBORATED_NOTCH",
            "one": "PASS_REVIEW_ONLY_UNIQUE_TOPOLOGY_CORROBORATED_NOTCH",
            "two": "HOLD_MULTIPLE_TOPOLOGY_CORROBORATED_NOTCHES",
        }
        boundary = candidate_boundary_controls(engine, job)
        passed = all(bool(case["passed"]) for case in cases) and count_passed and bool(boundary["passed"])
        result = {
            "schema": "argos_ocv03_o3p6_front_notch_synthetic_gate_v1",
            "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "state": "PASS_O3P6_FRONT_NOTCH_SYNTHETIC_GATE" if passed else "FAIL_O3P6_FRONT_NOTCH_SYNTHETIC_GATE",
            "invocationPath": str(invocation_path),
            "invocationSha256": sha256_file(invocation_path),
            "cases": cases,
            "candidateBoundaryControl": boundary,
            "countDecisionControls": count_controls,
            "countDecisionControlsPassed": count_passed,
            "thresholdValuesChangedFromO3P4": False,
            "pairedShallowNotchControlIncluded": True,
            "oneChannelNegativeIncluded": True,
            "patternedNoNotchNegativeIncluded": True,
            "missingContourNegativeIncluded": True,
            "exactDelegatedExceptionContinuationIncluded": True,
            "unknownExceptionBatchFatalIncluded": True,
            "multipleCandidateHoldIncluded": True,
            "knownNotchLocationConsumed": False,
            "rasterOutputCreated": False,
            "sourceMutationPerformed": False,
            "reviewOnly": True,
            "productionRoutingEnabled": False,
        }
        partial = output_path.with_name(output_path.name + ".partial")
        partial.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
        os.replace(partial, output_path)
        print(
            json.dumps(
                {
                    "state": result["state"],
                    "outputPath": str(output_path),
                    "outputSha256": sha256_file(output_path),
                    "caseCount": len(cases),
                    "candidateBoundaryPassed": boundary["passed"],
                },
                separators=(",", ":"),
            )
        )
        return 0 if passed else 1
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
