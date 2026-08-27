#!/usr/bin/env python3
"""Score already-frozen O3D2 JSON outputs against isolated historical labels.

This utility does not import the detector, decode images, alter thresholds,
filter candidates, or select a candidate. Labels are read only after every
detector output hash has been verified against the supplied freeze manifest.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def circular_distance(left: float, right: float) -> float:
    return abs((left - right + 180.0) % 360.0 - 180.0)


def nearest(candidates: list[dict[str, Any]], expected: float) -> dict[str, Any] | None:
    if not candidates:
        return None
    candidate = min(candidates, key=lambda row: circular_distance(float(row["centerAngleDegrees"]), expected))
    return {
        "angleDegrees": float(candidate["centerAngleDegrees"]),
        "absoluteErrorDegrees": circular_distance(float(candidate["centerAngleDegrees"]), expected),
        "widthDegrees": float(candidate["widthDegrees"]),
        "symmetryScore": float(candidate["symmetryScore"]),
        "tipCenterOffsetFraction": float(candidate["tipCenterOffsetFraction"]),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--freeze", required=True)
    parser.add_argument("--labels", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    freeze_path = Path(args.freeze)
    labels_path = Path(args.labels)
    output_path = Path(args.output)
    if output_path.exists():
        raise FileExistsError(f"Scorer output already exists: {output_path}")
    freeze = json.loads(freeze_path.read_text(encoding="utf-8"))
    labels = json.loads(labels_path.read_text(encoding="utf-8"))
    if freeze["state"] != "FROZEN_DETECTOR_OUTPUTS_BEFORE_SCORING":
        raise ValueError("Detector outputs are not frozen for scoring.")
    if labels["detectorInputAllowed"] or labels["thresholdSourceAllowed"] or labels["candidateFilterAllowed"] or labels["tieBreakerAllowed"]:
        raise ValueError("Label isolation contract is not fail-closed.")

    result_by_identity: dict[str, dict[str, Any]] = {}
    for item in freeze["outputs"]:
        path = Path(item["path"])
        if sha256(path) != str(item["sha256"]).upper():
            raise ValueError(f"Frozen output hash mismatch: {path}")
        if path.name == "NATIVE_WAFER_POSE_OPENCV_V2.json":
            result = json.loads(path.read_text(encoding="utf-8"))
            result_by_identity[str(result["identity"])] = result

    rows: list[dict[str, Any]] = []
    for label in labels["members"]:
        identity = str(label["identity"])
        result = result_by_identity[identity]
        expected = float(label["expectedNotchAngleDegreesImage"])
        selected = result["selectedReviewOnlyManufacturedNotch"]
        selected_angle = None if selected is None else float(selected["bfAngleDegrees"])
        row: dict[str, Any] = {
            "identity": identity,
            "detectorState": result["state"],
            "expectedNotchAngleDegreesScorerOnly": expected,
            "maximumAbsoluteAngleErrorDegrees": float(label["maximumAbsoluteAngleErrorDegrees"]),
            "selectedAngleDegrees": selected_angle,
            "selectedCandidatePassed": selected_angle is not None and circular_distance(selected_angle, expected) <= float(label["maximumAbsoluteAngleErrorDegrees"]),
            "nearestFrozenBfCandidate": nearest(result["bf"].get("candidates", []), expected),
            "nearestFrozenDfCandidate": nearest(result["df"].get("candidates", []), expected),
        }
        if "knownChipoutAngleDegreesImage" in label:
            chipout = float(label["knownChipoutAngleDegreesImage"])
            row["knownChipoutAngleDegreesScorerOnly"] = chipout
            row["chipoutSelectedAsNotch"] = selected_angle is not None and circular_distance(selected_angle, chipout) <= float(label["maximumAbsoluteAngleErrorDegrees"])
        rows.append(row)

    gate = {
        "schema": "argos_ocv03_o3d2_post_inference_score_v1",
        "state": "PASS_POST_INFERENCE_REGRESSION_SCORE" if all(row["selectedCandidatePassed"] for row in rows) else "FAIL_POST_INFERENCE_SELECTION_WITH_LOCALIZATION_EVIDENCE",
        "freezePath": str(freeze_path).replace("\\", "/"),
        "freezeSha256": sha256(freeze_path),
        "labelsPath": str(labels_path).replace("\\", "/"),
        "labelsSha256": sha256(labels_path),
        "rows": rows,
        "detectorOutputsFrozenBeforeLabelsRead": True,
        "labelsProvidedToDetector": False,
        "labelsUsedAsThresholdSource": False,
        "labelsUsedAsCandidateFilter": False,
        "labelsUsedAsTieBreaker": False,
        "imageBytesDecoded": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(gate, stream, indent=2)
        stream.write("\n")
    print(json.dumps(gate, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
