#!/usr/bin/env python3
"""Project O3L8 current contour annotations onto exact clean source pixels."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Any

import cv2
import numpy as np


def need(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    need(path.is_file() and path.stat().st_size <= 4 * 1024 * 1024, f"Invalid JSON path: {path}")
    value = json.loads(path.read_text(encoding="utf-8"))
    need(isinstance(value, dict), "JSON root must be an object.")
    return value


def inside(root: Path, path: Path) -> Path:
    resolved = path.resolve()
    need(os.path.commonpath([os.path.normcase(str(root.resolve())), os.path.normcase(str(resolved))]) == os.path.normcase(str(root.resolve())), f"Path escapes root: {path}")
    return resolved


def project_relative(project: Path, path: Path) -> str:
    return inside(project, path).relative_to(project.resolve()).as_posix()


def write_json(path: Path, value: dict[str, Any]) -> None:
    need(not path.exists(), f"Create-new collision: {path}")
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def validate(job_path: Path, review_manifest_path: Path, expected_hash: str, output_root: Path) -> tuple[Path, dict[str, Any], dict[str, Any]]:
    project = job_path.resolve().parents[2]
    inside(project, review_manifest_path)
    inside(project, output_root)
    need(len(str(output_root.resolve())) + 64 < 200, "Presentation output path budget changed.")
    need(sha256(review_manifest_path) == expected_hash.upper(), "O3L8 review manifest hash changed.")
    job = read_json(job_path)
    review = read_json(review_manifest_path)
    need(job.get("schema") == "argos_ocv03_wafer_topology_axis_job_v1", "Job schema changed.")
    need(review.get("state") == "PASS_O3L8_WAFER_TOPOLOGY_AXIS_REVIEW_RENDERED", "Review state changed.")
    need(review.get("revision") == job.get("revision") == "FMOCV03_O3L8_20260827T213900Z", "Revision changed.")
    need(review.get("notchShapeOverlay") == "CONTOUR_HUGGING_MOUTH_TO_MOUTH", "Notch overlay semantics changed.")
    need(review.get("fullHeightCenterLineRendered") is False, "Full-height center ray returned.")
    need(len(job.get("inputs", [])) == len(review.get("results", [])) == 6, "Input/result cardinality changed.")
    for field in ("trainingEligible", "xmlEligible", "productionEligible", "productionRoutingEnabled"):
        need(not bool(job.get(field)) and not bool(review.get(field)), f"Forbidden authority changed: {field}")
    return project, job, review


def build(job_path: Path, review_manifest_path: Path, expected_hash: str, output_root: Path) -> dict[str, Any]:
    project, job, review = validate(job_path, review_manifest_path, expected_hash, output_root)
    partial = output_root.with_name(output_root.name + ".partial")
    need(not output_root.exists() and not partial.exists(), "Presentation root is not create-new.")
    partial.mkdir(parents=False)
    source_root = inside(project, (job_path.parent / str(job["sourceRootRelativeToJob"])))
    source_rows = {str(row["id"]): row for row in job["inputs"]}
    presented = []
    for result in sorted(review["results"], key=lambda row: str(row["id"])):
        item_id = str(result["id"])
        source_row = source_rows[item_id]
        clean_path = inside(source_root, source_root / str(source_row["path"]))
        overlay_path = inside(project, review_manifest_path.parent / str(result["assets"]["overlay"]["path"]))
        mask_path = inside(project, review_manifest_path.parent / str(result["assets"]["mask"]["path"]))
        need(sha256(clean_path) == str(source_row["sha256"]).upper() == str(result["source"]["sha256"]).upper(), f"Clean source changed: {item_id}")
        need(sha256(overlay_path) == str(result["assets"]["overlay"]["sha256"]).upper(), f"Overlay changed: {item_id}")
        need(sha256(mask_path) == str(result["assets"]["mask"]["sha256"]).upper(), f"Mask changed: {item_id}")
        clean = cv2.imread(str(clean_path), cv2.IMREAD_COLOR)
        overlay = cv2.imread(str(overlay_path), cv2.IMREAD_COLOR)
        mask = cv2.imread(str(mask_path), cv2.IMREAD_GRAYSCALE)
        need(clean is not None and overlay is not None and mask is not None, f"Decode failed: {item_id}")
        need(clean.shape == overlay.shape == (600, 1000, 3) and mask.shape == (600, 1000), f"Dimensions changed: {item_id}")
        current = mask > 0
        composite = clean.copy()
        composite[current] = overlay[current]
        changed = np.any(composite != clean, axis=2)
        inside_count = int(np.count_nonzero(changed & current))
        outside_count = int(np.count_nonzero(changed & ~current))
        need(inside_count > 0 and outside_count == 0, f"Composite mask invariant failed: {item_id}")
        name = item_id.lower().replace("-", "") + "_clean_contour_overlay.png"
        output_path = partial / name
        need(bool(cv2.imwrite(str(output_path), composite, [cv2.IMWRITE_PNG_COMPRESSION, 6])), f"PNG write failed: {item_id}")
        presented.append({
            "id": item_id,
            "pairId": str(result["pairId"]),
            "channel": str(result["channel"]),
            "state": str(result["state"]),
            "candidateCount": int(result["candidateCount"]),
            "primary": result["primary"],
            "cleanSource": {"path": project_relative(project, clean_path), "sha256": sha256(clean_path)},
            "enhanced": {"path": project_relative(project, review_manifest_path.parent / str(result["assets"]["enhanced"]["path"])), "sha256": str(result["assets"]["enhanced"]["sha256"]).upper()},
            "composite": {"path": name, "sha256": sha256(output_path)},
            "currentMask": {"path": project_relative(project, mask_path), "sha256": sha256(mask_path)},
            "changedPixelsInsideCurrentMask": inside_count,
            "changedPixelsOutsideCurrentMask": outside_count,
            "operatorFeedbackRasterized": False,
            "inheritedReviewRasterUsed": False
        })
    manifest = {
        "schema": "argos_ocv03_o3l8_clean_presentation_manifest_v1",
        "revision": "FMOCV03_O3L8_20260827T213900Z",
        "state": "PASS_O3L8_CLEAN_BASE_CONTOUR_PRESENTATION",
        "sourceReviewManifest": {"path": project_relative(project, review_manifest_path), "sha256": expected_hash.upper()},
        "notchShapeOverlay": "CONTOUR_HUGGING_MOUTH_TO_MOUTH",
        "fullHeightCenterLineRendered": False,
        "entries": presented,
        "entryCount": len(presented),
        "sourceMutationPerformed": False,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False
    }
    write_json(partial / "MANIFEST.json", manifest)
    os.replace(partial, output_root)
    manifest_path = output_root / "MANIFEST.json"
    return {"state": manifest["state"], "manifest": str(manifest_path), "manifestSha256": sha256(manifest_path), "entryCount": len(presented), "imageBytesEmittedToStdout": False, "reviewOnly": True}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", required=True)
    parser.add_argument("--review-manifest", required=True)
    parser.add_argument("--expected-review-manifest-sha256", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    job_path = Path(args.job).resolve()
    review_path = Path(args.review_manifest).resolve()
    output_root = Path(args.output_root).resolve()
    if args.preflight:
        _, _, review = validate(job_path, review_path, args.expected_review_manifest_sha256, output_root)
        response = {"state": "PASS_O3L8_CLEAN_BASE_PRESENTATION_PREFLIGHT", "revision": str(review["revision"]), "sourceImageBytesRead": False, "pixelsDecoded": False, "outputCreated": False, "reviewOnly": True}
    else:
        response = build(job_path, review_path, args.expected_review_manifest_sha256, output_root)
    print(json.dumps(response, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
