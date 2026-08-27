#!/usr/bin/env python3
"""Create a fresh, small BF/DF source-pair fixture for O3D3R4 endpoint rehearsal."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def load_r6(path: Path):
    name = "argos_o3d3r4_fixture_r6"
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load exact R6 fixture dependency: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def write_json_new(path: Path, value: dict) -> None:
    if path.exists():
        raise FileExistsError(f"Refusing existing fixture output: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--r6", required=True)
    parser.add_argument("--output-root", required=True)
    args = parser.parse_args()

    r6_path = Path(args.r6).resolve()
    output_root = Path(args.output_root).resolve()
    if output_root.exists():
        raise FileExistsError(f"O3D3R4 fixture root already exists: {output_root}")
    r6 = load_r6(r6_path)
    core = r6.core
    base = r6.base

    relative_bf = Path("fixture/Slot01/BrightfieldFrontsideWafer/resizedImage/FIXTURE_Slot01_BrightfieldFrontsideWafer.bmp")
    relative_df = Path("fixture/Slot01/DarkfieldFrontsideWafer/resizedImage/FIXTURE_Slot01_DarkfieldFrontsideWafer.bmp")
    bf_path = output_root / relative_bf
    df_path = output_root / relative_df
    bf_path.parent.mkdir(parents=True, exist_ok=False)
    df_path.parent.mkdir(parents=True, exist_ok=False)
    if not core.cv2.imwrite(str(bf_path), base.draw_channel(37.0, 420, 2.2, 34.0)):
        raise RuntimeError("OpenCV failed to write the BF rehearsal fixture.")
    if not core.cv2.imwrite(str(df_path), base.draw_channel(37.15, 438, 2.2, 34.0)):
        raise RuntimeError("OpenCV failed to write the DF rehearsal fixture.")

    parameters = {
        "coarseRadiusMinimumFraction": 0.28,
        "coarseRadiusMaximumFraction": 0.49,
        "coarseRadialStepPx": 2,
        "coarseAngleSamples": 1440,
        "refineRadialHalfWidthPx": 180,
        "refineAngleSamples": 3600,
        "radialContrastSpanPx": 10,
        "radialSmoothingWidthPx": 7,
        "minimumBoundaryContrast": 10.0,
        "outerEdgeRelativeContrast": 0.35,
        "fitMadMultiplier": 4.0,
        "fitResidualFloorPx": 2.0,
        "minimumFitInlierFraction": 0.80,
        "minimumAngularCoverageFraction": 0.90,
        "maximumFitRmsResidualPx": 4.0,
        "minimumCandidateDepthPx": 6.0,
        "candidateNoiseMultiplier": 6.0,
        "candidateGapAllowanceDegrees": 0.25,
        "candidateMinimumWidthDegrees": 0.4,
        "candidateMatchToleranceDegrees": 0.8,
        "manufacturedMinimumWidthDegrees": 0.9,
        "manufacturedMaximumWidthDegrees": 3.2,
        "manufacturedMinimumSymmetry": 0.72,
        "manufacturedMaximumTipOffsetFraction": 0.70,
        "manufacturedMinimumSlopeConsistency": 0.55,
        "manufacturedMinimumCrossChannelOverlap": 0.10,
        "maximumChannelCenterDifferencePx": 10.0,
        "maximumChannelRadiusDifferencePx": 32.0,
    }
    job = {
        "schema": "argos_native_frontside_wafer_pose_opencv_v2_job",
        "revision": "O3D3R4_ENDPOINT_REHEARSAL_FIXTURE_20260827",
        "inferenceScope": "FULL_360_PERIMETER_NO_LOCATION_PRIOR",
        "scorerInputsPresent": False,
        "developmentCohortUnlabeledGeometryUsedForGenericGateRevision": True,
        "historicalNotchLocationUsedToDeriveThreshold": False,
        "parameters": parameters,
        "inputs": [
            {
                "identity": "O3D3R4_REHEARSAL_SLOT01",
                "role": "SYNTHETIC_REHEARSAL_ONLY",
                "bfPath": "F:\\" + str(relative_bf).replace("/", "\\"),
                "bfBytes": bf_path.stat().st_size,
                "bfSha256": sha256_file(bf_path),
                "dfPath": "F:\\" + str(relative_df).replace("/", "\\"),
                "dfBytes": df_path.stat().st_size,
                "dfSha256": sha256_file(df_path),
            }
        ],
        "knownNotchLocationConsumed": False,
        "notchAnglePriorConsumed": False,
        "fixedAngularSearchWindowConsumed": False,
        "regressionLabelsConsumed": False,
        "frontsideFlipImageHorizontal": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
    }
    write_json_new(output_root / "JOB.json", job)
    gate = {
        "schema": "argos_o3d3r4_rehearsal_fixture_gate_v1",
        "state": "PASS_O3D3R4_REHEARSAL_FIXTURES_CREATED",
        "r6Path": str(r6_path),
        "r6Sha256": sha256_file(r6_path),
        "jobPath": str(output_root / "JOB.json"),
        "jobSha256": sha256_file(output_root / "JOB.json"),
        "sourceCount": 2,
        "knownLocationConsumed": False,
        "expectedAngleUsedByDetector": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    write_json_new(output_root / "FIXTURE_GATE.json", gate)
    print(json.dumps(gate, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

