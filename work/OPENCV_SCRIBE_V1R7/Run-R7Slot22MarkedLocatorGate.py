#!/usr/bin/env python3
"""Development-only gate: marker supplies truth, never detector input."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path

import cv2
import numpy as np

import ArgosOpenCvScribeV1R7 as provider


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while block := stream.read(4 * 1024 * 1024):
            digest.update(block)
    return digest.hexdigest().upper()


def write_new(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--gate", type=Path, required=True)
    parser.add_argument("--overlay", type=Path, required=True)
    args = parser.parse_args()
    image = cv2.imread(str(args.image), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Marked Slot22 image did not decode.")
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    marker = (
        (hsv[:, :, 0] >= 160)
        & (hsv[:, :, 0] <= 178)
        & (hsv[:, :, 1] >= 45)
        & (hsv[:, :, 2] >= 70)
    )
    marker_y, marker_x = np.where(marker)
    if marker_x.size < 1000:
        raise ValueError("Development marker was not uniquely measurable.")
    truth_box = [
        int(marker_x.min()),
        int(marker_y.min()),
        int(marker_x.max()),
        int(marker_y.max()),
    ]
    truth_center = (
        (truth_box[0] + truth_box[2]) / 2.0,
        (truth_box[1] + truth_box[3]) / 2.0,
    )
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    candidates = provider.perimeter_scribe_regions(gray, gray, 1600, 16, 1600, 400)
    rows = []
    for rank, candidate in enumerate(candidates, 1):
        distance = math.hypot(
            candidate.center_x - truth_center[0],
            candidate.center_y - truth_center[1],
        )
        inside_truth_box = (
            truth_box[0] <= candidate.center_x <= truth_box[2]
            and truth_box[1] <= candidate.center_y <= truth_box[3]
        )
        rows.append(
            {
                "rank": rank,
                "regionId": candidate.region_id,
                "x": candidate.center_x,
                "y": candidate.center_y,
                "width": candidate.width,
                "height": candidate.height,
                "angleDegrees": candidate.angle_degrees,
                "score": candidate.localization_score,
                "truthCenterDistancePixels": distance,
                "centerInsideTruthBox": inside_truth_box,
            }
        )
    matching = [row for row in rows if row["centerInsideTruthBox"]]
    if not matching or int(matching[0]["rank"]) > 8:
        raise ValueError("Marked scribe was not present in the top-eight perimeter shortlist.")

    scale = min(1.0, 1800.0 / max(image.shape[:2]))
    overlay = cv2.resize(image, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    for row in rows:
        center = (int(round(row["x"] * scale)), int(round(row["y"] * scale)))
        color = (0, 255, 0) if row["centerInsideTruthBox"] else (255, 180, 0)
        cv2.circle(overlay, center, 11, color, 3, cv2.LINE_AA)
        cv2.putText(
            overlay,
            str(row["rank"]),
            (center[0] + 12, center[1] - 8),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            color,
            2,
            cv2.LINE_AA,
        )
    args.overlay.parent.mkdir(parents=True, exist_ok=True)
    if args.overlay.exists() or not cv2.imwrite(str(args.overlay), overlay):
        raise ValueError("Create-new overlay failed.")
    gate = {
        "schema": "argos_opencv_scribe_r7_marked_locator_gate_v1",
        "state": "PASS_R7_SLOT22_MARKED_LOCATION_IN_TOP_EIGHT",
        "engineRevision": provider.ENGINE_REVISION,
        "engineSha256": sha256_file(Path(provider.__file__)),
        "markedImageSha256": sha256_file(args.image),
        "truthBox": truth_box,
        "truthCenter": list(truth_center),
        "markerUsedByProvider": False,
        "fixedImageRectangleUsedByProvider": False,
        "candidateCount": len(rows),
        "firstMatchingRank": int(matching[0]["rank"]),
        "firstMatchingDistancePixels": float(matching[0]["truthCenterDistancePixels"]),
        "candidates": rows,
        "reviewOnly": True,
        "automaticIdentityAuthority": False,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
    }
    write_new(args.gate, gate)
    print(json.dumps(gate, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
