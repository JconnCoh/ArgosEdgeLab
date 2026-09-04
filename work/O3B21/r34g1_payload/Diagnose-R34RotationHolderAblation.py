#!/usr/bin/env python3
"""R34 rotation/holder-ablation gate; all evidence remains review-only."""

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


R34_SHA256 = "3B3B9F6E461BC8F7C5498763A6ED9A46A404E55E5E3C69B10235C3489B3FF066"
CONFIG_SHA256 = "27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3"
CASES_SHA256 = "90D4DC156D85F2F684E616248E23729E3E0F0111D64E456891DDDB519F2AD6AB"
CONFIRMATION_MODE = "BF_NEAR_STRICT_SYMMETRY_CONFIRMED_BY_DF_BROAD_STRONG_APPEARANCE"
ORIENTATIONS = ("original", "ccw90")
MODES = ("exact", "noholder")
POSE_TOLERANCE_DEGREES = 1.0
ABLATION_TOLERANCE_DEGREES = 0.01
ROTATION_TOLERANCE_DEGREES = 0.01


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_r34(path: Path):
    spec = importlib.util.spec_from_file_location("argos_r34rot1_frozen", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"R34 could not be loaded: {path}")
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
    if sha256_file(detector) != R34_SHA256:
        raise RuntimeError("Frozen R34 detector hash changed.")
    r34 = load_r34(detector)
    if args.worker == "noholder":
        r34.R32.R21.derive_holder_mask = no_holder_mask
    sys.argv = [str(detector), "--job", args.job]
    return int(r34.main())


def circular_distance(left: float, right: float) -> float:
    delta = abs(float(left) - float(right)) % 360.0
    return min(delta, 360.0 - delta)


def nearest_candidate(result: dict, channel: str, expected: float) -> dict | None:
    candidates = result.get(channel, {}).get("candidates", [])
    if not candidates:
        return None
    row = min(candidates, key=lambda item: circular_distance(item["centerAngleDegrees"], expected))
    return {
        key: row.get(key) for key in (
            "centerAngleDegrees", "widthDegrees", "maximumDepthNativePx",
            "symmetryScore", "tipCenterOffsetFraction",
            "slopeConsistencyFraction", "manufacturedMorphologyPassed",
        )
    }


def validate_inputs(cases_path: Path, detector: Path, config_path: Path) -> tuple[dict, dict]:
    if sha256_file(cases_path) != CASES_SHA256:
        raise RuntimeError("Frozen R28ROT1 case-manifest hash changed.")
    if sha256_file(detector) != R34_SHA256:
        raise RuntimeError("Frozen R34 detector hash changed.")
    if sha256_file(config_path) != CONFIG_SHA256:
        raise RuntimeError("Frozen R13 configuration hash changed.")
    manifest = json.loads(cases_path.read_text(encoding="utf-8"))
    if len(manifest.get("cases", [])) != 2:
        raise RuntimeError("R34ROT1 requires exactly two frozen cases.")
    config = json.loads(config_path.read_text(encoding="utf-8"))
    for key in ("radialEngine", "radialEngineSha256", "radialParameters"):
        if key not in config:
            raise RuntimeError(f"Frozen R13 configuration is missing {key}.")
    return manifest, config


def evaluate_gate(
    rows: list[dict], manifest: dict, source_hashes_after: list[dict], detector_unchanged: bool
) -> dict:
    violations: list[dict] = []
    expected_keys = {
        (case["id"], orientation, mode)
        for case in manifest["cases"] for orientation in ORIENTATIONS for mode in MODES
    }
    actual_keys = [(row["caseId"], row["orientation"], row["mode"]) for row in rows]
    if len(rows) != 8 or len(set(actual_keys)) != 8 or set(actual_keys) != expected_keys:
        violations.append({"code": "EXECUTION_IDENTITY_SET_NOT_EXACTLY_EIGHT"})

    evaluated_rows = []
    for source_row in rows:
        row = dict(source_row)
        row_violations = []
        pairs = row.get("pairedAnglesDegrees", [])
        pair_modes = row.get("pairedConfirmationModes", [])
        if row.get("pairedCandidateCount") != 1:
            row_violations.append("PAIRED_CANDIDATE_COUNT_NOT_ONE")
        if len(pairs) != 1:
            row_violations.append("PAIRED_CANDIDATE_PAYLOAD_NOT_ONE")
            angle = None
        else:
            angle = float(pairs[0])
        if row.get("knownNotchLocationConsumed") is not False:
            row_violations.append("KNOWN_NOTCH_LOCATION_CONSUMED_OR_UNDECLARED")
        if row.get("resultSourceMutationPerformed") is not False:
            row_violations.append("RESULT_SOURCE_MUTATION_NOT_FALSE")
        pose_error = None if angle is None else circular_distance(angle, row["expectedImageAngleDegrees"])
        if pose_error is None or pose_error > POSE_TOLERANCE_DEGREES:
            row_violations.append("POSE_OUTSIDE_ONE_DEGREE")
        if "SLOT20" in row["caseId"] and pair_modes != [CONFIRMATION_MODE]:
            row_violations.append("SLOT20_CONFIRMATION_MODE_MISMATCH")
        row["selectedAngleDegrees"] = angle
        row["poseErrorDegrees"] = pose_error
        row["gateViolations"] = row_violations
        evaluated_rows.append(row)
        violations.extend({"code": code, "execution": list(actual_keys[len(evaluated_rows) - 1])}
                          for code in row_violations)

    by_key = {(row["caseId"], row["orientation"], row["mode"]): row for row in evaluated_rows}
    ablation_comparisons = []
    rotation_comparisons = []
    for case in manifest["cases"]:
        case_id = case["id"]
        for orientation in ORIENTATIONS:
            exact = by_key.get((case_id, orientation, "exact"))
            noholder = by_key.get((case_id, orientation, "noholder"))
            exact_angle = None if exact is None else exact["selectedAngleDegrees"]
            noholder_angle = None if noholder is None else noholder["selectedAngleDegrees"]
            delta = None if exact_angle is None or noholder_angle is None else circular_distance(exact_angle, noholder_angle)
            passed = delta is not None and delta <= ABLATION_TOLERANCE_DEGREES
            comparison = {
                "caseId": case_id, "orientation": orientation,
                "exactAngleDegrees": exact_angle, "noholderAngleDegrees": noholder_angle,
                "deltaDegrees": delta, "passed": passed,
            }
            ablation_comparisons.append(comparison)
            if not passed:
                violations.append({"code": "EXACT_NOHOLDER_DELTA_EXCEEDS_0_01_DEGREES",
                                   "caseId": case_id, "orientation": orientation})
        for mode in MODES:
            original = by_key.get((case_id, "original", mode))
            ccw90 = by_key.get((case_id, "ccw90", mode))
            original_angle = None if original is None else original["selectedAngleDegrees"]
            ccw90_angle = None if ccw90 is None else ccw90["selectedAngleDegrees"]
            shift = None if original_angle is None or ccw90_angle is None else circular_distance(original_angle, ccw90_angle)
            error = None if shift is None else abs(shift - 90.0)
            passed = error is not None and error <= ROTATION_TOLERANCE_DEGREES
            comparison = {
                "caseId": case_id, "mode": mode,
                "originalAngleDegrees": original_angle, "ccw90AngleDegrees": ccw90_angle,
                "rotationShiftDegrees": shift, "rotationErrorDegrees": error, "passed": passed,
            }
            rotation_comparisons.append(comparison)
            if not passed:
                violations.append({"code": "CCW90_SHIFT_OUTSIDE_90_PLUS_MINUS_0_01_DEGREES",
                                   "caseId": case_id, "mode": mode})

    source_unchanged = bool(source_hashes_after) and all(
        row.get("bfUnchanged") is True and row.get("dfUnchanged") is True
        for row in source_hashes_after
    )
    if not source_unchanged:
        violations.append({"code": "SOURCE_HASH_CHANGED_OR_UNDECLARED"})
    if detector_unchanged is not True:
        violations.append({"code": "DETECTOR_HASH_CHANGED"})
    return {
        "state": "PASS_R34ROT1_8_OF_8" if not violations else "HOLD_R34ROT1_REGRESSION_GATE",
        "violations": violations,
        "results": evaluated_rows,
        "ablationComparisons": ablation_comparisons,
        "rotationComparisons": rotation_comparisons,
        "sourceHashesUnchanged": source_unchanged,
        "detectorHashUnchanged": detector_unchanged is True,
    }


def main(args) -> int:
    cases_path, detector, config_path = map(Path, (args.cases, args.detector, args.config))
    manifest, config = validate_inputs(cases_path, detector, config_path)
    source_inputs = []
    for case in manifest["cases"]:
        paths = {channel: Path(case[channel]) for channel in ("bf", "df")}
        for channel, source in paths.items():
            if sha256_file(source) != case[f"{channel}Sha256"]:
                raise RuntimeError(f"Frozen source hash changed: {source}")
        source_inputs.append((case, paths))
    if args.preflight:
        print(json.dumps({"state": "PASS_R34ROT1_PREFLIGHT", "caseCount": 2,
                          "executionCount": 8, "detectorSha256": R34_SHA256,
                          "configSha256": CONFIG_SHA256, "casesSha256": CASES_SHA256}))
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
    for case_index, (case, source_paths) in enumerate(source_inputs):
        case_rotated = rotated / f"C{case_index}"
        case_rotated.mkdir()
        variants = {"original": source_paths}
        ccw = {}
        for channel, source in source_paths.items():
            image = cv2.imread(str(source), cv2.IMREAD_UNCHANGED)
            if image is None:
                raise RuntimeError(f"OpenCV decode failed: {source}")
            target = case_rotated / f"{channel.upper()}_CCW90.bmp"
            if not cv2.imwrite(str(target), cv2.rotate(image, cv2.ROTATE_90_COUNTERCLOCKWISE)):
                raise RuntimeError(f"Rotated image write failed: {target}")
            ccw[channel] = target
        variants["ccw90"] = ccw
        for orientation, paths in variants.items():
            expected = (float(case["expectedSourceAngleDegrees"])
                        - (90.0 if orientation == "ccw90" else 0.0)) % 360.0
            for mode in MODES:
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
                        [sys.executable, "-B", str(Path(__file__)), "--worker", mode,
                         "--detector", str(detector), "--job", str(job_path)],
                        check=False, text=True, capture_output=True, timeout=75,
                    )
                except subprocess.TimeoutExpired as exc:
                    raise RuntimeError(f"{case['id']} {orientation} {mode}: exceeded 75 seconds") from exc
                if completed.returncode != 0:
                    raise RuntimeError(f"{case['id']} {orientation} {mode}: {completed.stderr[-2000:]}")
                result = json.loads((output / "RESULT.json").read_text(encoding="utf-8"))
                pairs = result.get("pairedCandidates", [])
                rows.append({
                    "caseId": case["id"], "role": case["role"],
                    "orientation": orientation, "mode": mode,
                    "authority": "DIAGNOSTIC_ONLY_NO_HOLD_CLEARANCE",
                    "pairedCandidateCount": result.get("pairedCandidateCount"),
                    "pairedAnglesDegrees": [row["meanAngleDegrees"] for row in pairs],
                    "pairedConfirmationModes": [row.get("confirmationMode") for row in pairs],
                    "expectedImageAngleDegrees": expected,
                    "knownNotchLocationConsumed": result.get("knownNotchLocationConsumed"),
                    "resultSourceMutationPerformed": result.get("sourceMutationPerformed"),
                    "nearestBfCandidate": nearest_candidate(result, "bf", expected),
                    "nearestDfCandidate": nearest_candidate(result, "df", expected),
                    "resultPath": str(output / "RESULT.json"),
                })
        source_hashes_after.append({
            "caseId": case["id"],
            "bfUnchanged": sha256_file(source_paths["bf"]) == case["bfSha256"],
            "dfUnchanged": sha256_file(source_paths["df"]) == case["dfSha256"],
        })

    gate = evaluate_gate(rows, manifest, source_hashes_after, sha256_file(detector) == R34_SHA256)
    summary = {
        "schema": "argos_o3b21_r34rot1_rotation_holder_ablation_gate_v1",
        "state": gate["state"],
        "detectorSha256": R34_SHA256, "configSha256": CONFIG_SHA256,
        "casesSha256": CASES_SHA256, "executionCount": len(rows),
        "poseToleranceDegrees": POSE_TOLERANCE_DEGREES,
        "exactNoHolderToleranceDegrees": ABLATION_TOLERANCE_DEGREES,
        "rotationShiftExpectedDegrees": 90.0,
        "rotationShiftToleranceDegrees": ROTATION_TOLERANCE_DEGREES,
        **gate,
        "sourceHashesAfter": source_hashes_after,
        "sourceMutationPerformed": not gate["sourceHashesUnchanged"],
        "detectorMutationPerformed": not gate["detectorHashUnchanged"],
        "reviewOnly": True, "trainingEligible": False,
        "xmlEligible": False, "productionEligible": False,
        "automaticHoldClearanceAllowed": False,
    }
    summary_path = root / "SUMMARY.json"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"state": summary["state"], "executionCount": len(rows),
                      "violationCount": len(gate["violations"]), "summary": str(summary_path)}))
    return 0 if summary["state"].startswith("PASS_") else 2


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases")
    parser.add_argument("--detector", required=True)
    parser.add_argument("--config")
    parser.add_argument("--output")
    parser.add_argument("--preflight", action="store_true")
    parser.add_argument("--worker", choices=MODES)
    parser.add_argument("--job")
    parsed = parser.parse_args()
    raise SystemExit(worker(parsed) if parsed.worker else main(parsed))



