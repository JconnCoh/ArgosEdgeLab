#!/usr/bin/env python3
"""R17D review-only scribe provider with topology-aware glyph ranking.

R17C remains the localization/presence implementation.  R17D keeps R11's
appearance descriptor for grid selection, then checks low-confidence glyphs
with a second descriptor made from thresholded, edge-trimmed, glyph-bounded
dot topology.
This prevents acquisition/background similarity and neighboring-cell pixels
from outweighing the glyph shape.  M12 is evaluated only after image-first
ranking and never selects the image-first character.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import cv2
import numpy as np


REVISION = "ARGOS_OPENCV_SCRIBE_V1R17D_20260903"
TOPOLOGY_QUANTILE = 0.995
TOPOLOGY_THRESHOLD_FRACTION = 0.28
TOPOLOGY_MINIMUM_THRESHOLD = 12.0
TOPOLOGY_OVERRIDE_MINIMUM_SCORE = 0.90
TOPOLOGY_OVERRIDE_MINIMUM_MARGIN = 0.15
TOPOLOGY_OVERRIDE_MAXIMUM_APPEARANCE_SCORE = 0.85
TOPOLOGY_OVERRIDE_MAXIMUM_APPEARANCE_DEFICIT = 0.12


def _load_r17c() -> Any:
    path = Path(__file__).resolve().parents[1] / "OPENCV_SCRIBE_R17C" / "ArgosOpenCvScribeV1R17C.py"
    spec = importlib.util.spec_from_file_location("argos_scribe_r17c_for_r17d", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load R17C provider: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


R17C = _load_r17c()


@dataclass(frozen=True)
class TopologyPrototype:
    label: str
    physical_identity: str
    descriptor: np.ndarray


def _unit_descriptor(image: np.ndarray) -> np.ndarray:
    values = image.astype(np.float32).reshape(-1)
    values -= float(values.astype(np.float64).mean())
    norm = math.sqrt(float(np.dot(values.astype(np.float64), values.astype(np.float64))))
    if norm < 1e-8:
        norm = 1.0
    return (values.astype(np.float64) / norm).astype(np.float32)


def describe_topology_exact(
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
    interior = residual[
        y + margin_y:y + height - margin_y,
        x + margin_x:x + width - margin_x,
    ]
    if not interior.size:
        return None
    high = float(np.quantile(interior, TOPOLOGY_QUANTILE))
    threshold = max(TOPOLOGY_MINIMUM_THRESHOLD, high * TOPOLOGY_THRESHOLD_FRACTION)
    topology = (interior >= threshold).astype(np.float32)

    # Partial neighboring glyphs occur at the horizontal edges of legacy
    # reference cells.  They are not part of the centered target glyph.
    edge = max(2, int(topology.shape[1] * 0.05))
    topology[:, :edge] = 0.0
    topology[:, -edge:] = 0.0
    foreground_y, foreground_x = np.nonzero(topology)
    if foreground_x.size > 5:
        x0 = max(0, int(np.quantile(foreground_x, 0.01)) - 2)
        x1 = min(topology.shape[1], int(np.quantile(foreground_x, 0.99)) + 3)
        y0 = max(0, int(np.quantile(foreground_y, 0.01)) - 2)
        y1 = min(topology.shape[0], int(np.quantile(foreground_y, 0.99)) + 3)
        if x1 - x0 >= 20 and y1 - y0 >= 40:
            topology = topology[y0:y1, x0:x1]

    sampled = cv2.resize(topology, (24, 48), interpolation=cv2.INTER_AREA)
    sampled = cv2.GaussianBlur(sampled, (3, 3), 0.6)
    return _unit_descriptor(sampled)


def _topology_prototype(
    r11: Any,
    label: str,
    physical_identity: str,
    path: Path,
) -> TopologyPrototype:
    gray = r11.decode_gray_exact(path)
    residual = r11.dark_residual_exact(gray, max(4, min(12, gray.shape[1] // 8)))
    descriptor = describe_topology_exact(residual, 0, 0, gray.shape[1], gray.shape[0])
    if descriptor is None:
        raise ValueError(f"Reference glyph topology could not be described: {path}")
    return TopologyPrototype(label, physical_identity, descriptor)


def load_topology_prototypes(
    r11: Any,
    manifest_path: Path,
    expected_manifest_sha256: str,
    roots: dict[str, Path],
    supplemental_manifest_path: Path | None = None,
    supplemental_manifest_sha256: str = "",
) -> list[TopologyPrototype]:
    if r11.sha256_file(manifest_path) != expected_manifest_sha256.upper():
        raise ValueError("Reference manifest SHA-256 mismatch for topology bank.")
    manifest = r11.read_json(manifest_path)
    rows: list[TopologyPrototype] = []
    for row in manifest.get("references", []):
        label = str(row.get("label", "")).upper()[:1]
        if not label:
            continue
        path = r11.resolve_reference_path(str(row["relativePath"]), roots)
        if not path.is_file() or r11.sha256_file(path) != str(row["sha256"]).upper():
            raise ValueError(f"Reference glyph is missing or changed: {path}")
        rows.append(_topology_prototype(r11, label, str(row.get("physicalIdentity", "")), path))
    rows.sort(key=lambda item: item.label)

    if supplemental_manifest_path is not None:
        if r11.sha256_file(supplemental_manifest_path) != supplemental_manifest_sha256.upper():
            raise ValueError("Supplemental manifest SHA-256 mismatch for topology bank.")
        supplemental = r11.read_json(supplemental_manifest_path)
        for row in supplemental.get("references", []):
            relative = Path(str(row.get("relativePath", "")).replace("/", "\\"))
            if relative.is_absolute():
                raise ValueError("Supplemental topology reference path must be relative.")
            path = (supplemental_manifest_path.parent / relative).resolve()
            if supplemental_manifest_path.parent.resolve() not in path.parents:
                raise ValueError("Supplemental topology reference escaped its root.")
            if not path.is_file() or r11.sha256_file(path) != str(row.get("sha256", "")).upper():
                raise ValueError(f"Supplemental glyph is missing or changed: {path}")
            rows.append(_topology_prototype(
                r11,
                str(row.get("label", "")).upper()[:1],
                str(row.get("physicalIdentity", "")),
                path,
            ))
    return rows


def _label_indices(labels: np.ndarray) -> dict[str, np.ndarray]:
    return {label: np.flatnonzero(labels == label) for label in sorted(set(labels.tolist()))}


def rank_hybrid(
    r11: Any,
    appearance_descriptor: np.ndarray,
    topology_descriptor: np.ndarray,
    appearance_bank: Any,
    topology_matrix: np.ndarray,
    topology_indices: dict[str, np.ndarray],
    position: int,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    appearance_scores = appearance_bank.matrix @ appearance_descriptor.astype(np.float64)
    topology_scores = topology_matrix @ topology_descriptor.astype(np.float64)
    ranked: list[dict[str, Any]] = []
    for label in r11.allowed_labels(position):
        appearance_rows = appearance_bank.label_indices.get(label)
        topology_rows = topology_indices.get(label)
        if appearance_rows is None or topology_rows is None or not len(appearance_rows):
            continue
        take = min(1 if position < 10 else 3, int(len(appearance_rows)))
        appearance = float(np.sort(appearance_scores[appearance_rows])[::-1][:take].mean())
        topology = float(np.sort(topology_scores[topology_rows])[::-1][:take].mean())
        ranked.append({
            "character": label,
            "score": appearance,
            "appearanceScore": appearance,
            "topologyScore": topology,
        })
    appearance_ranked = sorted(
        ranked, key=lambda row: (-float(row["appearanceScore"]), str(row["character"]))
    )
    topology_ranked = sorted(
        ranked, key=lambda row: (-float(row["topologyScore"]), str(row["character"]))
    )
    appearance_top = appearance_ranked[0]
    topology_top = topology_ranked[0]
    topology_margin = (
        float(topology_top["topologyScore"]) - float(topology_ranked[1]["topologyScore"])
        if len(topology_ranked) > 1 else math.inf
    )
    appearance_deficit = (
        float(appearance_top["appearanceScore"]) - float(topology_top["appearanceScore"])
    )
    override = (
        str(topology_top["character"]) != str(appearance_top["character"])
        and float(topology_top["topologyScore"]) >= TOPOLOGY_OVERRIDE_MINIMUM_SCORE
        and topology_margin >= TOPOLOGY_OVERRIDE_MINIMUM_MARGIN
        and float(appearance_top["appearanceScore"]) < TOPOLOGY_OVERRIDE_MAXIMUM_APPEARANCE_SCORE
        and appearance_deficit <= TOPOLOGY_OVERRIDE_MAXIMUM_APPEARANCE_DEFICIT
    )
    if override:
        for row in ranked:
            row["score"] = float(row["topologyScore"])
        ranked.sort(key=lambda row: (-float(row["score"]), str(row["character"])))
    else:
        ranked = appearance_ranked
    return ranked, {
        "mode": "TOPOLOGY_OVERRIDE" if override else "APPEARANCE",
        "appearanceFirst": str(appearance_top["character"]),
        "topologyFirst": str(topology_top["character"]),
        "topologyFirstScore": float(topology_top["topologyScore"]),
        "topologyMargin": topology_margin,
        "appearanceDeficit": appearance_deficit,
        "overrideApplied": override,
    }


def evaluate_hybrid_grid(
    r11: Any,
    residual: np.ndarray,
    appearance_bank: Any,
    topology_matrix: np.ndarray,
    topology_indices: dict[str, np.ndarray],
    x: int,
    y: int,
    cell_width: int,
    cell_height: int,
) -> dict[str, Any] | None:
    positions: list[dict[str, Any]] = []
    top_scores: list[float] = []
    for position in range(12):
        cell_x = x + position * cell_width
        appearance = r11.describe_exact(residual, cell_x, y, cell_width, cell_height)
        topology = describe_topology_exact(residual, cell_x, y, cell_width, cell_height)
        if appearance is None or topology is None:
            return None
        ranked, arbitration = rank_hybrid(
            r11, appearance, topology, appearance_bank,
            topology_matrix, topology_indices, position,
        )
        if not ranked:
            return None
        positions.append({
            "position": position + 1,
            "imageFirst": ranked[0]["character"],
            "candidates": ranked[:4 if position < 10 else 8],
            "allCandidates": ranked,
            "glyphArbitration": arbitration,
        })
        top_scores.append(float(ranked[0]["score"]))
    mean_score = float(sum(top_scores) / 12.0)
    return {
        "x": x,
        "y": y,
        "cellWidth": cell_width,
        "cellHeight": cell_height,
        "meanTopScore": mean_score,
        "selectionScore": (
            r11.GRID_MEAN_WEIGHT * mean_score
            + r11.GRID_LEADING_WEIGHT * top_scores[0]
            + r11.GRID_TRAILING_WEIGHT * top_scores[-1]
        ),
        "leadingBoundaryScore": top_scores[0],
        "trailingBoundaryScore": top_scores[-1],
        "positions": positions,
    }


def evaluate_detector_input_hybrid(
    r11: Any,
    gray: np.ndarray,
    prototypes: list[Any],
    topology_prototypes: list[TopologyPrototype],
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
    appearance_bank = r11.PrototypeBank.from_prototypes(active)
    topology_matrix = np.vstack([item.descriptor.astype(np.float64) for item in active_topology])
    topology_labels = np.asarray([item.label for item in active_topology])
    topology_indices = _label_indices(topology_labels)

    if frozen_grid is None:
        selected = r11.find_best_grid(gray, appearance_bank)
        grid = (
            int(selected["x"]), int(selected["y"]),
            int(selected["cellWidth"]), int(selected["cellHeight"]),
        )
    else:
        grid = tuple(int(value) for value in frozen_grid)
    residual = r11.dark_residual_exact(gray, 12)
    evaluated = evaluate_hybrid_grid(
        r11, residual, appearance_bank, topology_matrix, topology_indices, *grid
    )
    if evaluated is None:
        raise ValueError("Selected grid could not be evaluated by topology-aware OCR.")
    output = r11.finalize_grid(evaluated)
    output["glyphRanking"] = {
        "method": "APPEARANCE_WITH_BOUNDED_GLYPH_TOPOLOGY_ARBITRATION",
        "topologyOverrideMinimumScore": TOPOLOGY_OVERRIDE_MINIMUM_SCORE,
        "topologyOverrideMinimumMargin": TOPOLOGY_OVERRIDE_MINIMUM_MARGIN,
        "topologyOverrideMaximumAppearanceScore": TOPOLOGY_OVERRIDE_MAXIMUM_APPEARANCE_SCORE,
        "topologyOverrideMaximumAppearanceDeficit": TOPOLOGY_OVERRIDE_MAXIMUM_APPEARANCE_DEFICIT,
        "checksumUsedForImageFirst": False,
    }
    return output


def paired_presence_evidence(bf: np.ndarray, df: np.ndarray) -> dict[str, Any]:
    return R17C.paired_presence_evidence(bf, df)


def run_job(job_path: Path, result_path: Path) -> int:
    r11 = R17C.R17B._load_r11()
    job = r11.read_json(job_path)
    r11.validate_job_shape(job)
    roots = {str(row["relativePrefix"]): Path(str(row["path"])) for row in job["references"]["roots"]}
    manifest_path = Path(str(job["references"]["manifestPath"]))
    manifest_sha256 = str(job["references"]["manifestSha256"])
    prototypes, reference_evidence = r11.load_reference_prototypes(
        manifest_path, manifest_sha256, roots,
    )
    supplemental_path_text = str(job["references"].get("supplementalManifestPath", ""))
    supplemental_sha256 = str(job["references"].get("supplementalManifestSha256", ""))
    if bool(supplemental_path_text) != bool(supplemental_sha256):
        raise ValueError("Supplemental reference path and SHA-256 must be supplied together.")
    supplemental_path = Path(supplemental_path_text) if supplemental_path_text else None
    if supplemental_path is not None:
        supplement_loader = R17C.R17B._load_supplement_loader()
        prototypes, reference_evidence = supplement_loader.combine_reference_prototypes(
            r11, prototypes, reference_evidence, supplemental_path, supplemental_sha256,
        )
    topology_prototypes = load_topology_prototypes(
        r11, manifest_path, manifest_sha256, roots, supplemental_path, supplemental_sha256,
    )
    expected_keys = [(item.label, item.physical_identity) for item in prototypes]
    topology_keys = [(item.label, item.physical_identity) for item in topology_prototypes]
    if topology_keys != expected_keys:
        raise ValueError("Appearance and topology reference banks are not aligned.")

    bf, bf_evidence = r11.decode_source(job["inputs"]["bf"])
    df, df_evidence = r11.decode_source(job["inputs"]["df"])
    if str(job.get("inputMode", "POSE_BOUND_WHOLE_IMAGE")) != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT" and bf.shape != df.shape:
        raise ValueError("BF and DF dimensions differ.")
    cache: dict[str, dict[str, Any]] = {}

    def gated_evaluate(gray: np.ndarray, active: list[Any], excluded: str, frozen_grid: Any = None) -> dict[str, Any]:
        key = hashlib.sha256(gray.tobytes()).hexdigest()
        evidence = cache.setdefault(key, R17C.measure_structure(gray))
        if not bool(evidence["passed"]):
            raise ValueError("HOLD_SCRIBE_NOT_LOCALIZED")
        evaluated = evaluate_detector_input_hybrid(
            r11, gray, active, topology_prototypes, excluded, frozen_grid,
        )
        evaluated["scribePresence"] = evidence
        return evaluated

    r11.evaluate_detector_input = gated_evaluate
    result = r11.analyze_images(job, bf, df, prototypes, reference_evidence, {
        "bf": bf_evidence,
        "df": df_evidence,
        "jobSha256": r11.sha256_file(job_path),
    })
    result["revision"] = REVISION
    result["provenance"]["engineRevision"] = REVISION
    result["provenance"]["preOcrStructureGate"] = True
    result["provenance"]["topologyAwareGlyphRanking"] = True
    result["provenance"]["checksumUsedForImageFirst"] = False
    if not result["hypotheses"]:
        direct = paired_presence_evidence(bf, df) if str(job.get("inputMode")) == "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT" else {
            "schema": R17C.R17B.SCHEMA,
            "passed": False,
            "decision": "HOLD_SCRIBE_NOT_LOCALIZED",
            "detail": "All image-localized candidate patches failed the pre-OCR structure gate.",
        }
        R17C.R17B.REVISION = REVISION
        R17C.R17B._apply_not_localized_hold(result, direct)
    r11.write_json_new(result_path, result)
    print(json.dumps({"state": result["state"], "resultPath": str(result_path), "candidateCount": len(result["candidates"])}))
    return 0


def main(argv: Iterable[str]) -> int:
    r11 = R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as error:
        print(json.dumps({"state": "HOLD_OPENCV_SCRIBE_PROVIDER_ERROR", "errorType": type(error).__name__, "detail": str(error)}), file=sys.stderr)
        raise
