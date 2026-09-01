#!/usr/bin/env python3
"""Two-pair R28 rotation/holder ablation; every result is diagnostic-only."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

import cv2
import numpy as np


R28_SHA256 = "4F51BA7E8D261BF196CE559C420A4F511F0D06B39BE5F512D2E6ABF585681466"
CONFIG_SHA256 = "27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_r28(path: Path):
    spec = importlib.util.spec_from_file_location("argos_r28rot1_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"R28 could not be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def no_holder_mask(image, center_x, center_y, radius, angle_samples, parameters):
    del image, center_x, center_y, radius, parameters
    return np.zeros(angle_samples, dtype=bool), {
        "referenceMedianIntensity": 0.0,
        "referenceMadIntensity": 0.0,
        "brightThresholdIntensity": 0.0,
        "maximumRadialBrightSupportFraction": 0.0,
        "diagnosticAblation": "HOLDER_EXCLUSION_DISABLED_NO_AUTHORITY",
    }


def worker(args) -> int:
    detector = Path(args.detector)
    if sha256_file(detector) != R28_SHA256:
        raise RuntimeError("Frozen R28 detector hash changed.")
    r28 = load_r28(detector)
    if args.worker == "noholder":
        r28.R21.derive_holder_mask = no_holder_mask
    sys.argv = [str(detector), "--job", args.job]
    return int(r28.main())


def nearest_candidate(result: dict, channel: str, expected: float) -> dict | None:
    rows = result.get(channel, {}).get("candidates", [])
    if not rows:
        return None
    distance = lambda row: min(
        abs(float(row["centerAngleDegrees"]) - expected) % 360.0,
        360.0 - abs(float(row["centerAngleDegrees"]) - expected) % 360.0,
    )
    row = min(rows, key=distance)
    return {
        key: row.get(key) for key in (
            "centerAngleDegrees", "widthDegrees", "maximumDepthNativePx",
            "symmetryScore", "tipCenterOffsetFraction",
            "slopeConsistencyFraction", "manufacturedMorphologyPassed",
        )
    }


def validate_inputs(cases_path: Path, detector: Path, config_path: Path) -> tuple[dict, dict]:
    if sha256_file(detector) != R28_SHA256:
        raise RuntimeError("Frozen R28 detector hash changed.")
    if sha256_file(config_path) != CONFIG_SHA256:
        raise RuntimeError("Frozen R13 configuration hash changed.")
    manifest = json.loads(cases_path.read_text(encoding="utf-8"))
    if len(manifest.get("cases", [])) != 2:
        raise RuntimeError("R28ROT1 requires exactly two cases.")
    config = json.loads(config_path.read_text(encoding="utf-8"))
    return manifest, config


def main(args) -> int:
    cases_path, detector, config_path = map(Path, (args.cases, args.detector, args.config))
    manifest, config = validate_inputs(cases_path, detector, config_path)
    if args.preflight:
        print(json.dumps({"state": "PASS_R28ROT1_PREFLIGHT", "caseCount": 2}))
        return 0
    root = Path(args.output)
    if root.exists():
        raise RuntimeError(f"Create-new output already exists: {root}")
    root.mkdir(parents=False)
    jobs = root / "jobs"
    rotated = root / "rotated_inputs"
    jobs.mkdir()
    rotated.mkdir()
    rows = []
    source_hashes_after = []
    for case_index, case in enumerate(manifest["cases"]):
        source_paths = {ch: Path(case[ch]) for ch in ("bf", "df")}
        for ch, source in source_paths.items():
            if sha256_file(source) != case[f"{ch}Sha256"]:
                raise RuntimeError(f"Source hash changed: {source}")
        case_rotated = rotated / f"C{case_index}"
        case_rotated.mkdir()
        variants = {"original": source_paths}
        ccw = {}
        for ch, source in source_paths.items():
            image = cv2.imread(str(source), cv2.IMREAD_UNCHANGED)
            if image is None:
                raise RuntimeError(f"OpenCV decode failed: {source}")
            target = case_rotated / f"{ch.upper()}_CCW90.bmp"
            if not cv2.imwrite(str(target), cv2.rotate(image, cv2.ROTATE_90_COUNTERCLOCKWISE)):
                raise RuntimeError(f"Rotated image write failed: {target}")
            ccw[ch] = target
        variants["ccw90"] = ccw
        for orientation, paths in variants.items():
            expected = (float(case["expectedSourceAngleDegrees"]) - (90.0 if orientation == "ccw90" else 0.0)) % 360.0
            for mode in ("exact", "noholder"):
                output = root / f"C{case_index}_{orientation}_{mode}"
                job_path = jobs / f"C{case_index}_{orientation}_{mode}.json"
                job = {
                    "bf": str(paths["bf"]), "df": str(paths["df"]),
                    "bfSha256": sha256_file(paths["bf"]), "dfSha256": sha256_file(paths["df"]),
                    "output": str(output), "radialEngine": config["radialEngine"],
                    "radialEngineSha256": config["radialEngineSha256"],
                    "radialParameters": config["radialParameters"], "maximumDimension": 2400,
                }
                job_path.write_text(json.dumps(job, indent=2) + "\n", encoding="utf-8")
                try:
                    completed = subprocess.run(
                        [sys.executable, str(Path(__file__)), "--worker", mode,
                         "--detector", str(detector), "--job", str(job_path)],
                        check=False, text=True, capture_output=True, timeout=75,
                    )
                except subprocess.TimeoutExpired as exc:
                    raise RuntimeError(
                        f"{case['id']} {orientation} {mode}: exceeded 75 seconds"
                    ) from exc
                if completed.returncode != 0:
                    raise RuntimeError(f"{case['id']} {orientation} {mode}: {completed.stderr[-2000:]}")
                result = json.loads((output / "RESULT.json").read_text(encoding="utf-8"))
                rows.append({
                    "caseId": case["id"], "role": case["role"],
                    "orientation": orientation, "mode": mode,
                    "authority": "DIAGNOSTIC_ONLY_NO_HOLD_CLEARANCE",
                    "pairedCandidateCount": result.get("pairedCandidateCount"),
                    "pairedAnglesDegrees": [r["meanAngleDegrees"] for r in result.get("pairedCandidates", [])],
                    "expectedImageAngleDegrees": expected,
                    "nearestBfCandidate": nearest_candidate(result, "bf", expected),
                    "nearestDfCandidate": nearest_candidate(result, "df", expected),
                    "resultPath": str(output / "RESULT.json"),
                })
        source_hashes_after.append({
            "caseId": case["id"],
            "bfUnchanged": sha256_file(source_paths["bf"]) == case["bfSha256"],
            "dfUnchanged": sha256_file(source_paths["df"]) == case["dfSha256"],
        })
    summary = {
        "schema": "argos_o3b21_r28rot1_rotation_holder_ablation_result_v1",
        "state": "COMPLETE_DIAGNOSTIC_ONLY_NO_AUTOMATIC_DISPOSITION",
        "detectorSha256": R28_SHA256, "configSha256": CONFIG_SHA256,
        "executionCount": len(rows), "results": rows,
        "sourceHashesAfter": source_hashes_after,
        "sourceMutationPerformed": False, "reviewOnly": True,
        "trainingEligible": False, "xmlEligible": False, "productionEligible": False,
    }
    (root / "SUMMARY.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"state": summary["state"], "executionCount": len(rows), "summary": str(root / "SUMMARY.json")}))
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases")
    parser.add_argument("--detector", required=True)
    parser.add_argument("--config")
    parser.add_argument("--output")
    parser.add_argument("--preflight", action="store_true")
    parser.add_argument("--worker", choices=("exact", "noholder"))
    parser.add_argument("--job")
    parsed = parser.parse_args()
    raise SystemExit(worker(parsed) if parsed.worker else main(parsed))
