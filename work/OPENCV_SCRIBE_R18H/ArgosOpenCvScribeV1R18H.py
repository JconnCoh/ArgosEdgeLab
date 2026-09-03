#!/usr/bin/env python3
"""R18F plus a generic branch-structure consensus tie-break.

The frozen R18F appearance and topology rankers remain the primary rankers.
R18H intervenes only when the two best appearance labels are nearly tied and
the per-label consensus of a generic foreground-run descriptor separates those
same labels by a strong margin.  This addresses sparse/outlier exemplar
dominance without encoding a character-pair exception.  Checksum remains a
downstream verifier and never participates in glyph selection.
"""

from __future__ import annotations

import importlib.util
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import cv2
import numpy as np


def _load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


ROOT = Path(__file__).resolve().parents[1]
R18F = _load("argos_scribe_r18f_for_r18h", ROOT / "OPENCV_SCRIBE_R18F/ArgosOpenCvScribeV1R18F.py")
R18C = R18F.R18C
R17E = R18C.R17E
R17D = R17E.R17D
MINIMUM_POST_GRID_IMAGE_SCORE = R18F.MINIMUM_POST_GRID_IMAGE_SCORE
TOPOLOGY_OVERRIDE_MINIMUM_MARGIN = R18F.TOPOLOGY_OVERRIDE_MINIMUM_MARGIN
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18H_RUN_STRUCTURE_CONSENSUS_DIAGNOSTIC_20260903"

APPEARANCE_TIE_MAXIMUM_GAP = 0.02
RUN_STRUCTURE_MINIMUM_MARGIN = 0.20
RUN_STRUCTURE_STANDARD_DEVIATION_FLOOR = 0.05
RUN_STRUCTURE_HORIZONTAL_BANDS = 12
RUN_STRUCTURE_VERTICAL_BANDS = 9
RUN_STRUCTURE_MAXIMUM_RUNS = 4
RUN_STRUCTURE_THRESHOLD_FRACTION = 0.35


@dataclass(frozen=True)
class RunStructurePrototype:
    label: str
    physical_identity: str
    descriptor: np.ndarray


def _encode_runs(values: np.ndarray) -> np.ndarray:
    foreground = (values > 0.15).astype(np.uint8)
    foreground = cv2.morphologyEx(
        foreground.reshape(1, -1), cv2.MORPH_CLOSE, np.ones((1, 3), np.uint8)
    ).reshape(-1)
    padded = np.pad(foreground.astype(np.int16), (1, 1))
    starts = np.flatnonzero(np.diff(padded) == 1)
    ends = np.flatnonzero(np.diff(padded) == -1)
    # Preserve spatial order.  Branch position is part of the generic shape;
    # sorting by run width would erase which side of a glyph owns a branch.
    runs = [
        (int(end - start), float(start + end - 1) / 2.0)
        for start, end in zip(starts, ends)
    ][:RUN_STRUCTURE_MAXIMUM_RUNS]
    length = max(1, int(foreground.size))
    encoded = [min(len(starts), RUN_STRUCTURE_MAXIMUM_RUNS) / RUN_STRUCTURE_MAXIMUM_RUNS]
    for width, center in runs:
        encoded.extend((center / length, width / length))
    while len(encoded) < 1 + 2 * RUN_STRUCTURE_MAXIMUM_RUNS:
        encoded.extend((0.0, 0.0))
    return np.asarray(encoded, dtype=np.float32)


def _band_features(mask: np.ndarray, bands: int, horizontal: bool) -> list[np.ndarray]:
    extent = mask.shape[0] if horizontal else mask.shape[1]
    boundaries = np.linspace(0, extent, bands + 1, dtype=np.int32)
    rows: list[np.ndarray] = []
    for index in range(bands):
        start, end = int(boundaries[index]), int(boundaries[index + 1])
        if end <= start:
            end = min(extent, start + 1)
        section = mask[start:end, :] if horizontal else mask[:, start:end]
        projection = section.max(axis=0 if horizontal else 1)
        rows.append(_encode_runs(projection))
    return rows


def describe_run_structure_exact(
    residual: np.ndarray,
    x: int,
    y: int,
    width: int,
    height: int,
) -> np.ndarray | None:
    image_height, image_width = residual.shape[:2]
    if x < 0 or y < 0 or x + width > image_width or y + height > image_height:
        return None
    margin_x = max(3, width // 16)
    margin_y = max(5, height // 18)
    interior = residual[y + margin_y:y + height - margin_y, x + margin_x:x + width - margin_x]
    if not interior.size:
        return None
    high = float(np.quantile(interior, R17D.TOPOLOGY_QUANTILE))
    threshold = max(R17D.TOPOLOGY_MINIMUM_THRESHOLD, high * RUN_STRUCTURE_THRESHOLD_FRACTION)
    mask = (interior >= threshold).astype(np.float32)
    edge = max(2, int(mask.shape[1] * 0.05))
    mask[:, :edge] = 0.0
    mask[:, -edge:] = 0.0
    foreground_y, foreground_x = np.nonzero(mask)
    if foreground_x.size > 5:
        x0 = max(0, int(np.quantile(foreground_x, 0.01)) - 2)
        x1 = min(mask.shape[1], int(np.quantile(foreground_x, 0.99)) + 3)
        y0 = max(0, int(np.quantile(foreground_y, 0.01)) - 2)
        y1 = min(mask.shape[0], int(np.quantile(foreground_y, 0.99)) + 3)
        if x1 - x0 >= 20 and y1 - y0 >= 40:
            mask = mask[y0:y1, x0:x1]
    sampled = cv2.resize(mask, (32, 64), interpolation=cv2.INTER_AREA)
    features = _band_features(sampled, RUN_STRUCTURE_HORIZONTAL_BANDS, True)
    features.extend(_band_features(sampled, RUN_STRUCTURE_VERTICAL_BANDS, False))
    return np.concatenate(features).astype(np.float32)


def _run_structure_prototype(r11: Any, label: str, physical_identity: str, path: Path) -> RunStructurePrototype:
    gray = r11.decode_gray_exact(path)
    residual = r11.dark_residual_exact(gray, max(4, min(12, gray.shape[1] // 8)))
    descriptor = describe_run_structure_exact(residual, 0, 0, gray.shape[1], gray.shape[0])
    if descriptor is None:
        raise ValueError(f"Reference glyph run structure could not be described: {path}")
    return RunStructurePrototype(label, physical_identity, descriptor)


def load_run_structure_prototypes(
    r11: Any,
    manifest_path: Path,
    expected_manifest_sha256: str,
    roots: dict[str, Path],
    supplemental_manifest_path: Path | None = None,
    supplemental_manifest_sha256: str = "",
) -> list[RunStructurePrototype]:
    if r11.sha256_file(manifest_path) != expected_manifest_sha256.upper():
        raise ValueError("Reference manifest SHA-256 mismatch for run-structure bank.")
    manifest = r11.read_json(manifest_path)
    rows: list[RunStructurePrototype] = []
    for row in manifest.get("references", []):
        label = str(row.get("label", "")).upper()[:1]
        if not label:
            continue
        path = r11.resolve_reference_path(str(row["relativePath"]), roots)
        if not path.is_file() or r11.sha256_file(path) != str(row["sha256"]).upper():
            raise ValueError(f"Reference glyph is missing or changed: {path}")
        rows.append(_run_structure_prototype(r11, label, str(row.get("physicalIdentity", "")), path))
    rows.sort(key=lambda item: item.label)
    if supplemental_manifest_path is not None:
        if r11.sha256_file(supplemental_manifest_path) != supplemental_manifest_sha256.upper():
            raise ValueError("Supplemental manifest SHA-256 mismatch for run-structure bank.")
        supplemental = r11.read_json(supplemental_manifest_path)
        for row in supplemental.get("references", []):
            relative = Path(str(row.get("relativePath", "")).replace("/", "\\"))
            if relative.is_absolute():
                raise ValueError("Supplemental run-structure reference path must be relative.")
            path = (supplemental_manifest_path.parent / relative).resolve()
            if supplemental_manifest_path.parent.resolve() not in path.parents:
                raise ValueError("Supplemental run-structure reference escaped its root.")
            if not path.is_file() or r11.sha256_file(path) != str(row.get("sha256", "")).upper():
                raise ValueError(f"Supplemental glyph is missing or changed: {path}")
            rows.append(_run_structure_prototype(
                r11,
                str(row.get("label", "")).upper()[:1],
                str(row.get("physicalIdentity", "")),
                path,
            ))
    return rows


def _run_structure_context(active: list[RunStructurePrototype]) -> tuple[np.ndarray, dict[str, np.ndarray]]:
    matrix = np.vstack([row.descriptor.astype(np.float64) for row in active])
    mean = matrix.mean(axis=0)
    standard_deviation = np.maximum(matrix.std(axis=0), RUN_STRUCTURE_STANDARD_DEVIATION_FLOOR)
    standardized = (matrix - mean) / standard_deviation
    labels = np.asarray([row.label for row in active])
    consensus = {
        label: np.median(standardized[labels == label], axis=0)
        for label in sorted(set(labels.tolist()))
    }
    return np.vstack((mean, standard_deviation)), consensus


def rank_with_run_structure(
    r11: Any,
    appearance_descriptor: np.ndarray,
    topology_descriptor: np.ndarray,
    run_structure_descriptor: np.ndarray,
    appearance_bank: Any,
    topology_matrix: np.ndarray,
    topology_indices: dict[str, np.ndarray],
    run_structure_scaling: np.ndarray,
    run_structure_consensus: dict[str, np.ndarray],
    position: int,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    ranked, arbitration = R17D.rank_hybrid(
        r11, appearance_descriptor, topology_descriptor, appearance_bank,
        topology_matrix, topology_indices, position,
    )
    mean, standard_deviation = run_structure_scaling
    query = (run_structure_descriptor.astype(np.float64) - mean) / standard_deviation
    distances = {
        label: float(np.sqrt(np.mean(np.square(query - prototype))))
        for label, prototype in run_structure_consensus.items()
        if label in r11.allowed_labels(position)
    }
    for row in ranked:
        row["runStructureDistance"] = distances.get(str(row["character"]), math.inf)
    appearance_ranked = sorted(
        ranked, key=lambda row: (-float(row["appearanceScore"]), str(row["character"]))
    )
    structure_ranked = sorted(distances.items(), key=lambda item: (item[1], item[0]))
    appearance_gap = (
        float(appearance_ranked[0]["appearanceScore"]) - float(appearance_ranked[1]["appearanceScore"])
        if len(appearance_ranked) > 1 else math.inf
    )
    structure_margin = (
        float(structure_ranked[1][1]) - float(structure_ranked[0][1])
        if len(structure_ranked) > 1 else math.inf
    )
    structure_first = structure_ranked[0][0]
    appearance_top_two = {str(row["character"]) for row in appearance_ranked[:2]}
    applied = (
        arbitration["mode"] == "APPEARANCE"
        and structure_first != str(appearance_ranked[0]["character"])
        and structure_first in appearance_top_two
        and appearance_gap <= APPEARANCE_TIE_MAXIMUM_GAP
        and structure_margin >= RUN_STRUCTURE_MINIMUM_MARGIN
    )
    if applied:
        ranked = sorted(
            ranked,
            key=lambda row: (
                0 if str(row["character"]) == structure_first else 1,
                -float(row["appearanceScore"]),
                str(row["character"]),
            ),
        )
    arbitration = dict(arbitration)
    arbitration.update({
        "mode": "RUN_STRUCTURE_CONSENSUS_TIE_BREAK" if applied else arbitration["mode"],
        "appearanceGap": appearance_gap,
        "runStructureFirst": structure_first,
        "runStructureFirstDistance": float(structure_ranked[0][1]),
        "runStructureMargin": structure_margin,
        "runStructureApplied": applied,
    })
    return ranked, arbitration


def evaluate_detector_input_structural(
    r11: Any,
    gray: np.ndarray,
    prototypes: list[Any],
    topology_prototypes: list[Any],
    run_structure_prototypes: list[RunStructurePrototype],
    excluded_identity: str,
    frozen_grid: tuple[int, int, int, int] | None = None,
) -> dict[str, Any]:
    excluded = excluded_identity.casefold()
    indices = [
        index for index, item in enumerate(prototypes)
        if not excluded or item.physical_identity.casefold() != excluded
    ]
    active = [prototypes[index] for index in indices]
    active_topology = [topology_prototypes[index] for index in indices]
    active_structure = [run_structure_prototypes[index] for index in indices]
    appearance_bank = r11.PrototypeBank.from_prototypes(active)
    topology_matrix = np.vstack([item.descriptor.astype(np.float64) for item in active_topology])
    topology_labels = np.asarray([item.label for item in active_topology])
    topology_indices = R17D._label_indices(topology_labels)
    run_scaling, run_consensus = _run_structure_context(active_structure)
    if frozen_grid is None:
        selected = r11.find_best_grid(gray, appearance_bank)
        grid = (int(selected["x"]), int(selected["y"]), int(selected["cellWidth"]), int(selected["cellHeight"]))
    else:
        grid = tuple(int(value) for value in frozen_grid)
    residual = r11.dark_residual_exact(gray, 12)
    positions: list[dict[str, Any]] = []
    top_scores: list[float] = []
    for position in range(12):
        cell_x = grid[0] + position * grid[2]
        appearance = r11.describe_exact(residual, cell_x, grid[1], grid[2], grid[3])
        topology = R17D.describe_topology_exact(residual, cell_x, grid[1], grid[2], grid[3])
        structure = describe_run_structure_exact(residual, cell_x, grid[1], grid[2], grid[3])
        if appearance is None or topology is None or structure is None:
            raise ValueError("Selected grid could not be evaluated by run-structure OCR.")
        ranked, arbitration = rank_with_run_structure(
            r11, appearance, topology, structure, appearance_bank, topology_matrix,
            topology_indices, run_scaling, run_consensus, position,
        )
        positions.append({
            "position": position + 1,
            "imageFirst": ranked[0]["character"],
            "candidates": ranked[:4 if position < 10 else 8],
            "allCandidates": ranked,
            "glyphArbitration": arbitration,
        })
        top_scores.append(float(ranked[0]["score"]))
    mean_score = float(sum(top_scores) / 12.0)
    evaluated = {
        "x": grid[0], "y": grid[1], "cellWidth": grid[2], "cellHeight": grid[3],
        "meanTopScore": mean_score,
        "selectionScore": r11.GRID_MEAN_WEIGHT * mean_score + r11.GRID_LEADING_WEIGHT * top_scores[0] + r11.GRID_TRAILING_WEIGHT * top_scores[-1],
        "leadingBoundaryScore": top_scores[0], "trailingBoundaryScore": top_scores[-1],
        "positions": positions,
    }
    output = r11.finalize_grid(evaluated)
    output["glyphRanking"] = {
        "method": "APPEARANCE_WITH_BOUNDED_TOPOLOGY_AND_RUN_STRUCTURE_CONSENSUS_ARBITRATION",
        "appearanceTieMaximumGap": APPEARANCE_TIE_MAXIMUM_GAP,
        "runStructureMinimumMargin": RUN_STRUCTURE_MINIMUM_MARGIN,
        "runStructureWinnerMustBeAppearanceTopTwo": True,
        "checksumUsedForImageFirst": False,
    }
    return output


_ACTIVE_RUN_STRUCTURE_PROTOTYPES: list[RunStructurePrototype] | None = None


def run_job(job_path: Path, result_path: Path) -> int:
    global _ACTIVE_RUN_STRUCTURE_PROTOTYPES
    original_load = R17D.load_topology_prototypes
    original_evaluate = R17D.evaluate_detector_input_hybrid
    original_revision = R18F.REVISION

    def load_banks(r11: Any, manifest: Path, manifest_sha: str, roots: dict[str, Path], supplemental: Path | None = None, supplemental_sha: str = "") -> list[Any]:
        global _ACTIVE_RUN_STRUCTURE_PROTOTYPES
        topology = original_load(r11, manifest, manifest_sha, roots, supplemental, supplemental_sha)
        structure = load_run_structure_prototypes(r11, manifest, manifest_sha, roots, supplemental, supplemental_sha)
        if [(row.label, row.physical_identity) for row in topology] != [(row.label, row.physical_identity) for row in structure]:
            raise ValueError("Topology and run-structure reference banks are not aligned.")
        _ACTIVE_RUN_STRUCTURE_PROTOTYPES = structure
        return topology

    def evaluate(r11: Any, gray: np.ndarray, prototypes: list[Any], topology: list[Any], excluded: str, frozen_grid: Any = None) -> dict[str, Any]:
        if _ACTIVE_RUN_STRUCTURE_PROTOTYPES is None:
            raise RuntimeError("Run-structure reference bank was not loaded.")
        return evaluate_detector_input_structural(
            r11, gray, prototypes, topology, _ACTIVE_RUN_STRUCTURE_PROTOTYPES, excluded, frozen_grid,
        )

    R17D.load_topology_prototypes = load_banks
    R17D.evaluate_detector_input_hybrid = evaluate
    R18F.REVISION = REVISION
    try:
        return R18F.run_job(job_path, result_path)
    finally:
        R18F.REVISION = original_revision
        R17D.evaluate_detector_input_hybrid = original_evaluate
        R17D.load_topology_prototypes = original_load
        _ACTIVE_RUN_STRUCTURE_PROTOTYPES = None


def main(argv: Iterable[str]) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
