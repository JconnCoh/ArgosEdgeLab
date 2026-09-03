#!/usr/bin/env python3
"""Build a local draft J/K/Q/X reference supplement from frozen R15E rasters."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def load_module(path: Path, expected_sha256: str) -> Any:
    if sha256_file(path) != expected_sha256.upper():
        raise ValueError("Pinned R11 descriptor dependency changed.")
    spec = importlib.util.spec_from_file_location("argos_r16a_r11", path)
    if spec is None or spec.loader is None:
        raise ValueError("Could not load the pinned R11 descriptor dependency.")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def grouped_runs(indices: np.ndarray, maximum_gap: int = 5) -> list[tuple[int, int]]:
    if indices.size == 0:
        return []
    start = previous = int(indices[0])
    runs: list[tuple[int, int]] = []
    for value in indices[1:]:
        current = int(value)
        if current - previous > maximum_gap:
            runs.append((start, previous))
            start = current
        previous = current
    runs.append((start, previous))
    return runs


def segment_cells(gray: np.ndarray) -> tuple[list[tuple[int, int]], int, tuple[int, int]]:
    if gray.shape != (400, 1600):
        raise ValueError(f"Unexpected R15E raster shape: {gray.shape}")
    dark = gray < 80
    x_projection = dark[110:330, :].sum(axis=0)
    runs = grouped_runs(np.flatnonzero(x_projection >= 2))
    runs = [
        (start, end)
        for start, end in runs
        if 25 <= end - start + 1 <= 85
        and int(x_projection[start : end + 1].sum()) >= 200
    ]
    if len(runs) != 12:
        raise ValueError(f"Expected exactly 12 character runs, found {len(runs)}: {runs}")
    # Glyph widths differ (notably "1"), so cell pitch is measured from the
    # repeated run starts rather than from ink-bounding-box centers.
    pitches = np.diff(np.array([start for start, _ in runs], dtype=np.float64))
    if float(pitches.min()) < 94.0 or float(pitches.max()) > 100.0:
        raise ValueError(f"Twelve-run pitch is outside the frozen R15E range: {pitches}")

    x_mask = np.zeros(gray.shape[1], dtype=bool)
    for start, end in runs:
        x_mask[start : end + 1] = True
    y_projection = dark[:, x_mask].sum(axis=1)
    zones = [
        (start, end)
        for start, end in grouped_runs(np.flatnonzero(y_projection >= 2))
        if end >= 110 and start <= 340 and end - start >= 50
    ]
    if not zones:
        raise ValueError("No character-height zone was found.")
    zone = max(zones, key=lambda item: int(y_projection[item[0] : item[1] + 1].sum()))
    center_y = (zone[0] + min(zone[1], 360)) / 2.0
    cell_y = max(0, min(gray.shape[0] - 230, int(round(center_y - 115.0))))
    return runs, cell_y, zone


def descriptor(r11: Any, gray: np.ndarray) -> np.ndarray:
    residual = r11.dark_residual_exact(gray, 12)
    value = r11.describe_exact(residual, 0, 0, gray.shape[1], gray.shape[0])
    if value is None:
        raise ValueError("Cell could not be described.")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--inputs", required=True)
    parser.add_argument("--output-root", required=True)
    args = parser.parse_args()
    repo_root = Path(args.repo_root).resolve()
    inputs_path = Path(args.inputs).resolve()
    output_root = Path(args.output_root).resolve()
    if output_root.exists():
        raise ValueError(f"Fresh output root required: {output_root}")
    output_root.mkdir(parents=True)

    inputs = read_json(inputs_path)
    if inputs.get("schema") != "argos_opencv_scribe_r16a_inputs_v1":
        raise ValueError("R16A input schema mismatch.")
    dependency = inputs["r11Descriptor"]
    r11_path = repo_root / str(dependency["relativePath"])
    r11 = load_module(r11_path, str(dependency["sha256"]))

    target_labels = set(str(inputs["targetLabels"]))
    references: list[dict[str, Any]] = []
    descriptors: list[tuple[str, str, np.ndarray]] = []
    case_evidence: list[dict[str, Any]] = []
    for case in inputs["cases"]:
        source = repo_root / str(case["relativePath"])
        actual_sha256 = sha256_file(source)
        if actual_sha256 != str(case["sha256"]).upper():
            raise ValueError(f"Frozen R15E source changed: {source}")
        gray = cv2.imread(str(source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            raise ValueError(f"OpenCV could not decode: {source}")
        runs, cell_y, zone = segment_cells(gray)
        case_id = str(case["caseId"])
        truth = str(case["truth"])
        case_cells: list[dict[str, Any]] = []
        for position, ((run_start, run_end), label) in enumerate(zip(runs, truth), 1):
            center_x = int((run_start + run_end) // 2)
            cell = gray[cell_y : cell_y + 230, center_x - 48 : center_x + 48]
            if cell.shape != (230, 96):
                raise ValueError(f"Cell geometry escaped the raster: {case_id} P{position:02d}")
            relative = Path("cells") / case_id / f"P{position:02d}_{label}.png"
            destination = output_root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            if not cv2.imwrite(str(destination), cell):
                raise ValueError(f"OpenCV could not write: {destination}")
            cell_hash = sha256_file(destination)
            item = {
                "position": position,
                "label": label,
                "runX": [run_start, run_end],
                "cellX": center_x - 48,
                "cellY": cell_y,
                "relativePath": relative.as_posix(),
                "sha256": cell_hash,
            }
            case_cells.append(item)
            if label in target_labels:
                target_relative = Path("supplemental_refs") / f"{label}_{case_id}_P{position:02d}.png"
                target_destination = output_root / target_relative
                target_destination.parent.mkdir(parents=True, exist_ok=True)
                if not cv2.imwrite(str(target_destination), cell):
                    raise ValueError(f"OpenCV could not write: {target_destination}")
                target_hash = sha256_file(target_destination)
                references.append({
                    "label": label,
                    "caseId": case_id,
                    "physicalIdentity": str(case["physicalIdentity"]),
                    "truth": truth,
                    "position": position,
                    "relativePath": target_relative.as_posix(),
                    "sha256": target_hash,
                    "sourceRelativePath": str(case["relativePath"]),
                    "sourceSha256": actual_sha256,
                })
                descriptors.append((case_id, label, descriptor(r11, cell)))
        case_evidence.append({
            "caseId": case_id,
            "truth": truth,
            "sourceSha256": actual_sha256,
            "characterRunCount": len(runs),
            "cellY": cell_y,
            "characterZoneY": list(zone),
            "cells": case_cells,
        })

    classifications: list[dict[str, Any]] = []
    for query_case, query_label, query_descriptor in descriptors:
        candidates = [
            row for row in descriptors
            if not (query_label in {"J", "Q"} and row[0] == query_case)
        ]
        scores: dict[str, float] = {}
        for _, label, candidate_descriptor in candidates:
            scores[label] = max(scores.get(label, -1.0), float(query_descriptor @ candidate_descriptor))
        ranked = sorted(scores.items(), key=lambda row: (-row[1], row[0]))
        classifications.append({
            "caseId": query_case,
            "expected": query_label,
            "predicted": ranked[0][0],
            "topScore": ranked[0][1],
            "runnerUp": ranked[1][0],
            "runnerUpScore": ranked[1][1],
            "independentPeerUsed": query_label in {"J", "Q"},
        })
    if any(row["predicted"] != row["expected"] for row in classifications):
        raise ValueError("Target-only J/K/Q/X classification gate failed.")

    counts = {label: sum(row["label"] == label for row in references) for label in sorted(target_labels)}
    if counts != {"J": 2, "K": 1, "Q": 2, "X": 1}:
        raise ValueError(f"Unexpected supplemental reference counts: {counts}")
    s17_spec = inputs["confirmedRegression"]
    s17_path = repo_root / str(s17_spec["relativePath"])
    if sha256_file(s17_path) != str(s17_spec["sha256"]).upper():
        raise ValueError("Frozen S17 confirmation record changed.")
    s17 = read_json(s17_path)
    if str(s17.get("operatorConfirmedString")) != str(s17_spec["truth"]):
        raise ValueError("S17 operator-confirmed truth changed.")
    evidence = s17.get("detectorRegression", {})
    if str(evidence.get("topologyDirectString")) != str(s17_spec["expectedTopologyDirectString"]):
        raise ValueError("S17 topology regression changed.")

    remaining = "".join(
        label for label in str(inputs["frozenBaseMissingLabels"])
        if label not in target_labels
    )
    manifest = {
        "schema": "argos_opencv_scribe_supplemental_glyph_references_v1",
        "revision": str(inputs["revision"]),
        "disposition": "DIAGNOSTIC_ONLY",
        "references": references,
        "labelCounts": counts,
        "independentlyValidatedLabels": "JQ",
        "singleExampleProvisionalLabels": "KX",
        "frozenBaseMissingLabels": str(inputs["frozenBaseMissingLabels"]),
        "remainingMissingLabelsAfterSupplement": remaining,
        "identityAdmissionAuthorized": False,
        "activationAuthorized": False,
        "trainingAuthorized": False,
        "productionAuthorized": False,
    }
    manifest_path = output_root / "SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    write_json_new(manifest_path, manifest)
    gate = {
        "schema": "argos_opencv_scribe_r16a_local_gate_v1",
        "revision": str(inputs["revision"]),
        "state": "PASS_R16A_LOCAL_SUPPLEMENT_BUILT",
        "disposition": "DIAGNOSTIC_ONLY",
        "inputManifestSha256": sha256_file(inputs_path),
        "supplementalManifestSha256": sha256_file(manifest_path),
        "caseEvidence": case_evidence,
        "targetClassifications": classifications,
        "labelCounts": counts,
        "independentlyValidatedLabels": "JQ",
        "singleExampleProvisionalLabels": "KX",
        "remainingMissingLabels": remaining,
        "unchangedS17Regression": {
            "caseId": str(s17_spec["caseId"]),
            "truth": str(s17_spec["truth"]),
            "recordSha256": sha256_file(s17_path),
            "passed": True,
        },
        "pixelsDecodedAndProcessedByOpenCv": True,
        "sourceMutationPerformed": False,
        "providerActivated": False,
        "identityAdmissionAuthorized": False,
        "trainingAuthorized": False,
        "productionAuthorized": False,
    }
    write_json_new(output_root / "R16A_LOCAL_GATE.json", gate)
    print(json.dumps({
        "state": gate["state"],
        "caseCount": len(case_evidence),
        "cellCount": sum(len(row["cells"]) for row in case_evidence),
        "supplementalReferenceCount": len(references),
        "labelCounts": counts,
        "remainingMissingLabels": remaining,
        "s17": str(s17_spec["truth"]),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
