#!/usr/bin/env python3
"""Review-only sparse-blob OCR diagnostic for failed R11 scribe results."""

from __future__ import annotations

import argparse
import collections
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np


REVISION = "ARGOS_OPENCV_SCRIBE_R12A_BLOB_DIAGNOSTIC_20260902"
SCHEMA = "argos_opencv_scribe_blob_diagnostic_v1"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def write_json_new(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise FileExistsError(f"Refusing to replace existing diagnostic: {path}")
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, ensure_ascii=False)
        stream.write("\n")


def load_r11() -> tuple[Any, Path]:
    path = Path(__file__).resolve().parents[1] / "OPENCV_SCRIBE_R11A" / "ArgosOpenCvScribeV1R11.py"
    spec = importlib.util.spec_from_file_location("argos_scribe_r11_blob_base", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load R11 provider: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module, path


def make_blob_detector() -> Any:
    params = cv2.SimpleBlobDetector_Params()
    params.minThreshold = 0
    params.maxThreshold = 250
    params.thresholdStep = 4
    params.filterByColor = True
    params.blobColor = 0
    params.filterByArea = True
    params.minArea = 5
    params.maxArea = 180
    params.filterByCircularity = True
    params.minCircularity = 0.45
    params.filterByInertia = True
    params.minInertiaRatio = 0.15
    params.filterByConvexity = True
    params.minConvexity = 0.45
    params.minDistBetweenBlobs = 3
    return cv2.SimpleBlobDetector_create(params)


def select_grids(points: np.ndarray, width: int, height: int) -> list[tuple[int, int, int, int]]:
    band_height = min(210, height)
    y_histogram = np.bincount(
        np.clip(points[:, 1].astype(np.int32), 0, height - 1), minlength=height
    ).astype(np.float32)
    y_sums = np.convolve(y_histogram, np.ones(band_height, np.float32), mode="valid")
    y = int(np.argmax(y_sums))
    band = points[(points[:, 1] >= y) & (points[:, 1] < y + band_height)]
    x_histogram = np.bincount(
        np.clip(band[:, 0].astype(np.int32), 0, width - 1), minlength=width
    ).astype(np.float32)
    smooth = np.convolve(x_histogram, np.ones(9, np.float32), mode="same")
    pitch_rows: list[tuple[float, int]] = []
    for pitch in range(90, 105):
        left = smooth[:-pitch] - float(smooth[:-pitch].mean())
        right = smooth[pitch:] - float(smooth[pitch:].mean())
        pitch_rows.append((float(np.dot(left, right)), pitch))
    rows: list[tuple[float, int, int]] = []
    for _, pitch in sorted(pitch_rows, reverse=True)[:4]:
        expected_x = (width - 12 * pitch) // 2
        for x in range(max(0, expected_x - 120), min(width - 12 * pitch, expected_x + 120) + 1):
            inside_band = band[(band[:, 0] >= x) & (band[:, 0] < x + 12 * pitch)]
            phase = (inside_band[:, 0] - x) % pitch
            inside = int(np.sum((phase >= 12) & (phase <= pitch - 12)))
            edge = int(np.sum((phase < 7) | (phase > pitch - 7)))
            rows.append((inside - 2.0 * edge + 0.2 * len(inside_band), x, pitch))
    selected: list[tuple[int, int, int, int]] = []
    for _, x, pitch in sorted(rows, reverse=True):
        if any(abs(x - old_x) <= 2 and pitch == old_pitch for old_x, _, old_pitch, _ in selected):
            continue
        selected.append((x, y, pitch, band_height))
        if len(selected) == 8:
            break
    return selected


def evaluate_patch(
    r11: Any,
    patch: np.ndarray,
    prototypes: list[Any],
    excluded_identity: str,
    minimum_dot_size: float,
    maximum_dot_size: float,
) -> tuple[dict[str, Any], np.ndarray]:
    keypoints = make_blob_detector().detect(patch)
    points = np.asarray(
        [
            (float(row.pt[0]), float(row.pt[1]), float(row.size))
            for row in keypoints
            if minimum_dot_size <= row.size <= maximum_dot_size
        ],
        dtype=np.float32,
    )
    if len(points) < 40:
        raise ValueError("Too few diameter-qualified blob points for a twelve-cell diagnostic.")
    grids = select_grids(points, patch.shape[1], patch.shape[0])
    _, y, _, cell_height = grids[0]
    canvas = np.zeros_like(patch, dtype=np.float32)
    for point_x, point_y, _ in points:
        if y <= point_y < y + cell_height:
            cv2.circle(canvas, (int(round(point_x)), int(round(point_y))), 2, 255, -1)
    bank = r11.PrototypeBank.from_prototypes(
        r11.filtered_prototypes(prototypes, excluded_identity)
    )
    evaluated_grids: list[dict[str, Any]] = []
    for x, grid_y, pitch, grid_height in grids:
        grid = r11.evaluate_grid(canvas, bank, x, grid_y, pitch, grid_height)
        if grid is not None:
            evaluated_grids.append(r11.finalize_grid(grid))
    if not evaluated_grids:
        raise ValueError("Diameter-qualified blob points did not form an evaluable grid.")
    result = max(
        evaluated_grids,
        key=lambda row: (float(row["selectionScore"]), float(row["meanTopScore"])),
    )
    weighted: collections.Counter[str] = collections.Counter()
    frequency: collections.Counter[str] = collections.Counter()
    for row in evaluated_grids:
        for rank, alternative in enumerate(row["checksumAlternatives"][:5]):
            candidate = str(alternative["string"])
            frequency[candidate] += 1
            weighted[candidate] += (5 - rank) * max(0.0, float(row["selectionScore"]))
    consensus = [
        {
            "string": candidate,
            "weightedScore": float(score),
            "gridCount": int(frequency[candidate]),
        }
        for candidate, score in weighted.most_common(10)
    ]
    result["singleGridProposedString"] = result["proposedString"]
    result["proposedString"] = consensus[0]["string"] if consensus else ""
    result["checksumConsensus"] = consensus
    result["gridDiagnostics"] = [
        {
            "gridX": row["x"], "gridY": row["y"],
            "cellWidth": row["cellWidth"], "cellHeight": row["cellHeight"],
            "selectionScore": row["selectionScore"],
            "imageFirstString": row["imageFirstString"],
            "proposedString": row["proposedString"],
            "checksumAlternatives": row["checksumAlternatives"][:5],
        }
        for row in evaluated_grids
    ]
    result["detectedBlobCount"] = len(keypoints)
    result["diameterQualifiedBlobCount"] = int(len(points))
    result["minimumDotSize"] = minimum_dot_size
    result["maximumDotSize"] = maximum_dot_size
    result["gridCandidatesEvaluated"] = len(grids)
    return result, np.clip(canvas, 0, 255).astype(np.uint8)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", required=True, type=Path)
    parser.add_argument("--legacy-result", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    parser.add_argument("--minimum-dot-size", type=float, default=2.0)
    parser.add_argument("--maximum-dot-size", type=float, default=4.5)
    args = parser.parse_args()
    if args.output_root.exists():
        raise FileExistsError(f"Output root already exists: {args.output_root}")

    r11, r11_path = load_r11()
    job = read_json(args.job)
    legacy = read_json(args.legacy_result)
    legacy_valid = [row for row in legacy.get("hypotheses", []) if row.get("checksumValid")]
    base: dict[str, Any] = {
        "schema": SCHEMA,
        "revision": REVISION,
        "jobId": job.get("jobId"),
        "legacyResultSha256": sha256_file(args.legacy_result),
        "r11ProviderSha256": sha256_file(r11_path),
        "authority": {
            "reviewOnly": True,
            "automaticIdentityAuthority": False,
            "trainingEligible": False,
            "xmlEligible": False,
            "productionEligible": False,
            "mayClearHolds": False,
        },
    }
    if legacy_valid:
        base.update({
            "state": "LEGACY_CHECKSUM_VALID_BLOB_FALLBACK_SKIPPED",
            "legacyImageFirstString": legacy.get("imageFirstString", ""),
            "legacyProposedString": legacy.get("proposedString", ""),
            "blobDiagnostics": [],
        })
        write_json_new(args.output_root / "result.json", base)
        return 0

    roots = {
        str(row["relativePrefix"]): Path(str(row["path"]))
        for row in job["references"]["roots"]
    }
    prototypes, reference_evidence = r11.load_reference_prototypes(
        Path(str(job["references"]["manifestPath"])),
        str(job["references"]["manifestSha256"]),
        roots,
    )
    bf, bf_evidence = r11.decode_source(job["inputs"]["bf"])
    df, df_evidence = r11.decode_source(job["inputs"]["df"])
    paired = [
        row for row in legacy["localization"]["exceptionDiagnostics"]
        if "PAIRED_BF_DF" in str(row.get("source", ""))
    ]
    if not paired:
        raise ValueError("Legacy result has no paired BF/DF localization candidate.")
    selected = max(paired, key=lambda row: (float(row["score"]), str(row["regionId"])))
    region = r11.Region(
        str(selected["regionId"]), str(selected["source"]),
        float(selected["x"]), float(selected["y"]),
        float(selected["width"]), float(selected["height"]),
        float(selected["angleDegrees"]), float(selected["score"]),
    )
    diagnostics: list[dict[str, Any]] = []
    canvases: list[tuple[str, np.ndarray]] = []
    for channel, patch in (("BF", r11.rectify(bf, region)), ("DF", r11.rectify(df, region))):
        if patch is None:
            continue
        for direction, oriented in (
            ("FORWARD", patch),
            ("REVERSE_180", cv2.rotate(patch, cv2.ROTATE_180)),
        ):
            try:
                evaluated, canvas = evaluate_patch(
                    r11, oriented, prototypes,
                    str(job["references"].get("excludedPhysicalIdentity", "")),
                    args.minimum_dot_size, args.maximum_dot_size,
                )
            except ValueError as error:
                diagnostics.append({"channel": channel, "direction": direction, "error": str(error)})
                continue
            diagnostics.append({
                "channel": channel,
                "direction": direction,
                "imageFirstString": evaluated["imageFirstString"],
                "proposedString": evaluated["proposedString"],
                "checksumValid": evaluated["checksumValid"],
                "checksumAlternatives": evaluated["checksumAlternatives"][:5],
                "checksumConsensus": evaluated["checksumConsensus"],
                "gridDiagnostics": evaluated["gridDiagnostics"],
                "selectionScore": evaluated["selectionScore"],
                "gridX": evaluated["x"], "gridY": evaluated["y"],
                "cellWidth": evaluated["cellWidth"], "cellHeight": evaluated["cellHeight"],
                "detectedBlobCount": evaluated["detectedBlobCount"],
                "diameterQualifiedBlobCount": evaluated["diameterQualifiedBlobCount"],
                "identityEligible": False,
            })
            canvases.append((f"{channel}_{direction}_blobs.png", canvas))

    successful = [row for row in diagnostics if "selectionScore" in row]
    best = max(successful, key=lambda row: (float(row["selectionScore"]), row["channel"], row["direction"])) if successful else None
    base.update({
        "state": "SCRIBE_BLOB_DIAGNOSTIC_CHECKSUM_ALTERNATIVE_HOLD" if best and best.get("proposedString") else "SCRIBE_BLOB_DIAGNOSTIC_NO_PROPOSAL_HOLD",
        "selectedLegacyRegion": selected,
        "minimumDotSize": args.minimum_dot_size,
        "maximumDotSize": args.maximum_dot_size,
        "referenceEvidence": reference_evidence,
        "sourceEvidence": {"bf": bf_evidence, "df": df_evidence},
        "bestDiagnostic": best,
        "blobDiagnostics": diagnostics,
    })
    args.output_root.mkdir(parents=True)
    for name, canvas in canvases:
        if not cv2.imwrite(str(args.output_root / name), canvas):
            raise RuntimeError(f"OpenCV could not write diagnostic raster: {name}")
    write_json_new(args.output_root / "result.json", base)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
