#!/usr/bin/env python3
"""R18H plus conservative, lineage-aware glyph-envelope enforcement.

The frozen R18H ranker still selects the grid and supplies the diagnostic
appearance/topology/run-structure ranking.  R18V derives one generic model per
body label from the real, hash-locked reference glyphs.  A glyph is accepted
only when it is inside exactly one enforceable class envelope and that class
is reciprocally separated from its nearest enforceable rival.  Sparse and
unobserved classes hold; checksum, lot, slot, truth, and notch never enter the
decision.
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

import numpy as np


EXPECTED_R18H_PROVIDER_SHA256 = "3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD"
EXPECTED_BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
EXPECTED_SUPPLEMENTAL_MANIFEST_SHA256 = "FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114"
EXPECTED_COMBINED_REFERENCE_COUNT = 465


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


ROOT = Path(__file__).resolve().parents[1]
R18H_PATH = ROOT / "OPENCV_SCRIBE_R18H/ArgosOpenCvScribeV1R18H.py"
if _sha256_file(R18H_PATH) != EXPECTED_R18H_PROVIDER_SHA256:
    raise ValueError("Frozen R18H provider SHA-256 mismatch.")
R18H = _load(
    "argos_scribe_r18h_for_r18v",
    R18H_PATH,
)
R18F = R18H.R18F
R17E = R18H.R17E
R17D = R18H.R17D
MINIMUM_POST_GRID_IMAGE_SCORE = R18H.MINIMUM_POST_GRID_IMAGE_SCORE
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18V_LINEAGE_GLYPH_ENVELOPES_DIAGNOSTIC_20260905"

MINIMUM_ENFORCEABLE_LINEAGES = 4
EMPIRICAL_RADIUS_MULTIPLIER = 0.65
EMPIRICAL_RADIUS_FLOOR = 0.08
ROBUST_RADIUS_MAD_MULTIPLIER = 3.0
QUERY_RIVAL_RATIO_MARGIN = 0.20
RECIPROCAL_CENTER_RATIO_MINIMUM = 0.50
ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE = 0.80
TOPOLOGY_SCALE_FLOOR = 0.01
RUN_STRUCTURE_SCALE_FLOOR = 0.05
BODY_LABELS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"


@dataclass(frozen=True)
class GlyphEnvelopeModel:
    label: str
    state: str
    reference_count: int
    lineage_count: int
    topology_center: np.ndarray | None
    run_structure_center: np.ndarray | None
    radius: float | None
    lineage_distances: tuple[float, ...]


@dataclass(frozen=True)
class GlyphEnvelopeBank:
    models: dict[str, GlyphEnvelopeModel]
    topology_scale: float
    run_structure_scale: float
    fingerprint: str


def _lineage(value: str) -> str:
    normalized = value.strip().casefold()
    if not normalized:
        raise ValueError("Every glyph reference requires a physical lineage identity.")
    return normalized


def _rms_delta(left: np.ndarray, right: np.ndarray) -> float:
    delta = left.astype(np.float64) - right.astype(np.float64)
    return float(math.sqrt(float(np.mean(np.square(delta)))))


def _distance(
    topology: np.ndarray,
    run_structure: np.ndarray,
    topology_center: np.ndarray,
    run_structure_center: np.ndarray,
    topology_scale: float,
    run_structure_scale: float,
) -> float:
    topology_distance = _rms_delta(topology, topology_center) / topology_scale
    run_distance = _rms_delta(run_structure, run_structure_center) / run_structure_scale
    return float(math.sqrt(0.5 * topology_distance**2 + 0.5 * run_distance**2))


def _median_center(rows: list[np.ndarray]) -> np.ndarray:
    return np.median(np.vstack(rows).astype(np.float64), axis=0).astype(np.float32)


def _robust_modality_scale(rows: list[np.ndarray], floor: float) -> float:
    center = _median_center(rows)
    distances = sorted(_rms_delta(row, center) for row in rows)
    return max(float(np.median(np.asarray(distances, dtype=np.float64))), floor)


def _collapse_lineages(
    topology_prototypes: list[Any],
    run_structure_prototypes: list[Any],
) -> tuple[dict[str, dict[str, tuple[np.ndarray, np.ndarray]]], dict[str, int]]:
    topology_keys = [(_lineage(str(row.physical_identity)), str(row.label)) for row in topology_prototypes]
    run_keys = [(_lineage(str(row.physical_identity)), str(row.label)) for row in run_structure_prototypes]
    if topology_keys != run_keys:
        raise ValueError("Topology and ordered-run reference banks are not aligned.")
    grouped: dict[tuple[str, str], tuple[list[np.ndarray], list[np.ndarray]]] = {}
    counts: dict[str, int] = {}
    for topology, run_structure in zip(topology_prototypes, run_structure_prototypes):
        label = str(topology.label).upper()
        lineage = _lineage(str(topology.physical_identity))
        topology_rows, run_rows = grouped.setdefault((label, lineage), ([], []))
        topology_rows.append(topology.descriptor)
        run_rows.append(run_structure.descriptor)
        counts[label] = counts.get(label, 0) + 1
    collapsed: dict[str, dict[str, tuple[np.ndarray, np.ndarray]]] = {}
    for (label, lineage), (topology_rows, run_rows) in grouped.items():
        collapsed.setdefault(label, {})[lineage] = (
            _median_center(topology_rows),
            _median_center(run_rows),
        )
    return collapsed, counts


def _empirical_radius(
    rows: list[tuple[np.ndarray, np.ndarray]],
    topology_scale: float,
    run_structure_scale: float,
) -> tuple[float, tuple[float, ...]]:
    distances: list[float] = []
    for index, (topology, run_structure) in enumerate(rows):
        others = [row for other_index, row in enumerate(rows) if other_index != index]
        topology_center = _median_center([row[0] for row in others])
        run_center = _median_center([row[1] for row in others])
        distances.append(_distance(
            topology, run_structure, topology_center, run_center,
            topology_scale, run_structure_scale,
        ))
    values = np.asarray(distances, dtype=np.float64)
    median = float(np.median(values))
    median_absolute_deviation = float(np.median(np.abs(values - median)))
    robust_upper = median + ROBUST_RADIUS_MAD_MULTIPLIER * 1.4826 * median_absolute_deviation
    outlier_capped_high = max(median, min(float(values.max()), robust_upper))
    radius = max(outlier_capped_high * EMPIRICAL_RADIUS_MULTIPLIER, EMPIRICAL_RADIUS_FLOOR)
    return float(radius), tuple(float(value) for value in sorted(distances))


def build_glyph_envelope_bank(
    topology_prototypes: list[Any],
    run_structure_prototypes: list[Any],
) -> GlyphEnvelopeBank:
    collapsed, reference_counts = _collapse_lineages(topology_prototypes, run_structure_prototypes)
    all_rows = [row for lineages in collapsed.values() for row in lineages.values()]
    if not all_rows:
        raise ValueError("The glyph-envelope bank is empty.")
    topology_scale = _robust_modality_scale([row[0] for row in all_rows], TOPOLOGY_SCALE_FLOOR)
    run_structure_scale = _robust_modality_scale([row[1] for row in all_rows], RUN_STRUCTURE_SCALE_FLOOR)
    models: dict[str, GlyphEnvelopeModel] = {}
    digest = hashlib.sha256()
    for label in BODY_LABELS:
        lineages = collapsed.get(label, {})
        ordered = [(lineage, lineages[lineage]) for lineage in sorted(lineages)]
        for lineage, (topology, run_structure) in ordered:
            digest.update(label.encode("ascii"))
            digest.update(b"\0")
            digest.update(lineage.encode("utf-8"))
            digest.update(b"\0")
            digest.update(topology.astype("<f4", copy=False).tobytes())
            digest.update(run_structure.astype("<f4", copy=False).tobytes())
        if not ordered:
            models[label] = GlyphEnvelopeModel(label, "UNOBSERVED", 0, 0, None, None, None, ())
            continue
        rows = [row for _, row in ordered]
        lineage_count = len(rows)
        if lineage_count < MINIMUM_ENFORCEABLE_LINEAGES:
            models[label] = GlyphEnvelopeModel(
                label, "SPARSE", reference_counts.get(label, 0), lineage_count,
                None, None, None, (),
            )
            continue
        topology_center = _median_center([row[0] for row in rows])
        run_center = _median_center([row[1] for row in rows])
        radius, distances = _empirical_radius(rows, topology_scale, run_structure_scale)
        models[label] = GlyphEnvelopeModel(
            label, "COVERED", reference_counts.get(label, 0), lineage_count,
            topology_center, run_center, radius, distances,
        )
    digest.update(np.asarray([topology_scale, run_structure_scale], dtype="<f8").tobytes())
    return GlyphEnvelopeBank(models, topology_scale, run_structure_scale, digest.hexdigest().upper())


def coverage_evidence(bank: GlyphEnvelopeBank) -> dict[str, dict[str, Any]]:
    return {
        label: {
            "state": model.state,
            "referenceCount": model.reference_count,
            "independentPhysicalLineageCount": model.lineage_count,
            "radius": model.radius,
        }
        for label, model in bank.models.items()
    }


def assess_glyph_envelope(
    bank: GlyphEnvelopeBank,
    topology: np.ndarray,
    run_structure: np.ndarray,
    allowed_labels: str,
    upstream_label: str,
) -> dict[str, Any]:
    upstream = bank.models[upstream_label]
    distances: list[dict[str, Any]] = []
    for label in allowed_labels:
        model = bank.models[label]
        if model.state != "COVERED":
            continue
        assert model.topology_center is not None
        assert model.run_structure_center is not None
        assert model.radius is not None
        distance = _distance(
            topology, run_structure, model.topology_center, model.run_structure_center,
            bank.topology_scale, bank.run_structure_scale,
        )
        distances.append({
            "label": label,
            "distance": distance,
            "radius": model.radius,
            "normalizedDistance": distance / model.radius,
            "insideOwnEnvelope": distance <= model.radius,
            "independentPhysicalLineageCount": model.lineage_count,
        })
    distances.sort(key=lambda row: (float(row["normalizedDistance"]), str(row["label"])))
    if upstream.state != "COVERED":
        return {
            "accepted": False,
            "decision": f"HOLD_SELECTED_LABEL_{upstream.state}",
            "upstreamLabel": upstream_label,
            "selectedLabel": upstream_label,
            "changedByEnvelope": False,
            "upstreamCoverageState": upstream.state,
            "upstreamIndependentPhysicalLineageCount": upstream.lineage_count,
            "candidateEnvelopeDistances": distances,
            "checksumUsed": False,
        }
    members = [row for row in distances if bool(row["insideOwnEnvelope"])]
    if len(members) != 1:
        decision = (
            "HOLD_OUTSIDE_ALL_ENFORCEABLE_ENVELOPES"
            if not members else
            "HOLD_MULTIPLE_ENVELOPE_MEMBERSHIPS"
        )
        return {
            "accepted": False,
            "decision": decision,
            "upstreamLabel": upstream_label,
            "selectedLabel": upstream_label,
            "changedByEnvelope": False,
            "upstreamCoverageState": upstream.state,
            "memberLabels": [str(row["label"]) for row in members],
            "candidateEnvelopeDistances": distances,
            "checksumUsed": False,
        }
    winner = members[0]
    winner_model = bank.models[str(winner["label"])]
    rivals = [row for row in distances if str(row["label"]) != str(winner["label"])]
    if not rivals:
        return {
            "accepted": True,
            "decision": "ACCEPT_UNIQUE_ENVELOPE_NO_RIVAL",
            "upstreamLabel": upstream_label,
            "selectedLabel": str(winner["label"]),
            "changedByEnvelope": str(winner["label"]) != upstream_label,
            "upstreamCoverageState": upstream.state,
            "candidateEnvelopeDistances": distances,
            "checksumUsed": False,
        }
    rival = rivals[0]
    rival_model = bank.models[str(rival["label"])]
    assert winner_model.topology_center is not None and winner_model.run_structure_center is not None
    assert rival_model.topology_center is not None and rival_model.run_structure_center is not None
    assert winner_model.radius is not None and rival_model.radius is not None
    center_distance = _distance(
        winner_model.topology_center, winner_model.run_structure_center,
        rival_model.topology_center, rival_model.run_structure_center,
        bank.topology_scale, bank.run_structure_scale,
    )
    query_margin = float(rival["normalizedDistance"]) - float(winner["normalizedDistance"])
    winner_center_ratio = center_distance / winner_model.radius
    rival_center_ratio = center_distance / rival_model.radius
    separated = (
        float(rival["normalizedDistance"]) > 1.0
        and query_margin >= QUERY_RIVAL_RATIO_MARGIN
        and winner_center_ratio >= RECIPROCAL_CENTER_RATIO_MINIMUM
        and rival_center_ratio >= RECIPROCAL_CENTER_RATIO_MINIMUM
    )
    alternative_is_deep = (
        str(winner["label"]) == upstream_label
        or float(winner["normalizedDistance"]) <= ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE
    )
    accepted = separated and alternative_is_deep
    if not separated:
        decision = "HOLD_NEAREST_RIVAL_NOT_RECIPROCALLY_SEPARATED"
    elif not alternative_is_deep:
        decision = "HOLD_ALTERNATIVE_LABEL_NOT_DEEP_INSIDE_ENVELOPE"
    else:
        decision = "ACCEPT_UNIQUE_RECIPROCALLY_SEPARATED_ENVELOPE"
    return {
        "accepted": accepted,
        "decision": decision,
        "upstreamLabel": upstream_label,
        "selectedLabel": str(winner["label"]) if accepted else upstream_label,
        "changedByEnvelope": accepted and str(winner["label"]) != upstream_label,
        "upstreamCoverageState": upstream.state,
        "nearestRivalLabel": str(rival["label"]),
        "queryRivalNormalizedMargin": query_margin,
        "alternativeLabelMaximumNormalizedDistance": ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE,
        "winnerCenterToRivalCenterInWinnerRadii": winner_center_ratio,
        "winnerCenterToRivalCenterInRivalRadii": rival_center_ratio,
        "candidateEnvelopeDistances": distances,
        "checksumUsed": False,
    }


def _score_ceiling(upstream_score: float, selected_score: float) -> float:
    return min(float(upstream_score), float(selected_score))


def evaluate_detector_input_enveloped(
    r11: Any,
    gray: np.ndarray,
    prototypes: list[Any],
    topology_prototypes: list[Any],
    run_structure_prototypes: list[Any],
    excluded_identity: str,
    frozen_grid: tuple[int, int, int, int] | None = None,
) -> dict[str, Any]:
    if not (
        len(prototypes) == len(topology_prototypes) == len(run_structure_prototypes)
        == EXPECTED_COMBINED_REFERENCE_COUNT
    ):
        raise ValueError("The exact frozen 465-reference bank is required.")
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
    run_scaling, run_consensus = R18H._run_structure_context(active_structure)
    envelope_bank = build_glyph_envelope_bank(active_topology, active_structure)
    if frozen_grid is None:
        selected_grid = r11.find_best_grid(gray, appearance_bank)
        grid = (
            int(selected_grid["x"]), int(selected_grid["y"]),
            int(selected_grid["cellWidth"]), int(selected_grid["cellHeight"]),
        )
    else:
        grid = tuple(int(value) for value in frozen_grid)
    residual = r11.dark_residual_exact(gray, 12)
    positions: list[dict[str, Any]] = []
    top_scores: list[float] = []
    held_positions: list[dict[str, Any]] = []
    corrected_positions: list[dict[str, Any]] = []
    for position in range(12):
        cell_x = grid[0] + position * grid[2]
        appearance = r11.describe_exact(residual, cell_x, grid[1], grid[2], grid[3])
        topology = R17D.describe_topology_exact(residual, cell_x, grid[1], grid[2], grid[3])
        run_structure = R18H.describe_run_structure_exact(residual, cell_x, grid[1], grid[2], grid[3])
        if appearance is None or topology is None or run_structure is None:
            raise ValueError("Selected grid could not be evaluated by glyph-envelope OCR.")
        ranked, arbitration = R18H.rank_with_run_structure(
            r11, appearance, topology, run_structure, appearance_bank,
            topology_matrix, topology_indices, run_scaling, run_consensus, position,
        )
        upstream_label = str(ranked[0]["character"])
        assessment = assess_glyph_envelope(
            envelope_bank, topology, run_structure,
            r11.allowed_labels(position), upstream_label,
        )
        selected_label = str(assessment["selectedLabel"])
        selected_row = next(row for row in ranked if str(row["character"]) == selected_label)
        if selected_label != upstream_label:
            ranked = [selected_row] + [row for row in ranked if str(row["character"]) != selected_label]
            corrected_positions.append({
                "position": position + 1,
                "upstreamLabel": upstream_label,
                "selectedLabel": selected_label,
            })
        if not bool(assessment["accepted"]):
            held_positions.append({
                "position": position + 1,
                "diagnosticLabel": upstream_label,
                "decision": str(assessment["decision"]),
            })
        upstream_score = float(next(row for row in ranked if str(row["character"]) == upstream_label)["score"])
        selected_score = _score_ceiling(upstream_score, float(selected_row["score"]))
        positions.append({
            "position": position + 1,
            "imageFirst": selected_label,
            "candidates": ranked[:4 if position < 10 else 8],
            "allCandidates": ranked,
            "glyphArbitration": arbitration,
            "glyphEnvelope": assessment,
            "scoreUsedForGrid": selected_score,
        })
        top_scores.append(selected_score)
    mean_score = float(sum(top_scores) / 12.0)
    evaluated = {
        "x": grid[0], "y": grid[1], "cellWidth": grid[2], "cellHeight": grid[3],
        "meanTopScore": mean_score,
        "selectionScore": r11.GRID_MEAN_WEIGHT * mean_score + r11.GRID_LEADING_WEIGHT * top_scores[0] + r11.GRID_TRAILING_WEIGHT * top_scores[-1],
        "leadingBoundaryScore": top_scores[0],
        "trailingBoundaryScore": top_scores[-1],
        "positions": positions,
    }
    output = r11.finalize_grid(evaluated)
    output["glyphRanking"] = {
        "method": "R18H_RANKING_WITH_GENERIC_LINEAGE_GLYPH_ENVELOPE_ENFORCEMENT",
        "minimumEnforceableIndependentPhysicalLineages": MINIMUM_ENFORCEABLE_LINEAGES,
        "empiricalRadiusMultiplier": EMPIRICAL_RADIUS_MULTIPLIER,
        "robustRadiusMadMultiplier": ROBUST_RADIUS_MAD_MULTIPLIER,
        "queryRivalRatioMargin": QUERY_RIVAL_RATIO_MARGIN,
        "reciprocalCenterRatioMinimum": RECIPROCAL_CENTER_RATIO_MINIMUM,
        "alternativeLabelMaximumNormalizedDistance": ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE,
        "checksumUsedForImageFirst": False,
        "truthLotSlotAndNotchUsedForImageFirst": False,
        "syntheticDotsUsed": False,
    }
    output["ocrEnvelope"] = {
        "schema": "argos_opencv_scribe_glyph_envelope_evidence_v1",
        "passed": not held_positions,
        "decision": "PASS_ALL_SELECTED_GLYPHS_ENVELOPED" if not held_positions else "HOLD_ONE_OR_MORE_SELECTED_GLYPHS_NOT_ENVELOPED",
        "diagnosticString": output["imageFirstString"],
        "heldPositions": held_positions,
        "correctedPositions": corrected_positions,
        "bankFingerprint": envelope_bank.fingerprint,
        "topologyScale": envelope_bank.topology_scale,
        "orderedRunStructureScale": envelope_bank.run_structure_scale,
        "coverage": coverage_evidence(envelope_bank),
        "checksumUsed": False,
    }
    return output


def _apply_result_envelope_state(result: dict[str, Any]) -> None:
    hypotheses = list(result.get("hypotheses", []))
    for row in hypotheses:
        row["identityEnvelopeEligible"] = bool(row.get("ocrEnvelope", {}).get("passed"))
    result["hypotheses"] = hypotheses
    best = hypotheses[0] if hypotheses else None
    result.setdefault("provenance", {}).update({
        "engineRevision": REVISION,
        "genericPerCharacterGlyphEnvelopes": True,
        "minimumEnforceableIndependentPhysicalLineages": MINIMUM_ENFORCEABLE_LINEAGES,
        "checksumRole": "VERIFY_IMAGE_FIRST_ONLY",
        "checksumMayRewriteGlyphs": False,
        "checksumMaySelectHypothesis": False,
        "truthLotSlotAndNotchUsedForGlyphSelection": False,
        "syntheticDotsUsed": False,
    })
    result["revision"] = REVISION
    if best is None or bool(best.get("ocrEnvelope", {}).get("passed")):
        return
    held = list(best.get("ocrEnvelope", {}).get("heldPositions", []))
    result["state"] = "SCRIBE_GLYPH_ENVELOPE_HOLD"
    result["eligibleIdentity"] = False
    result["proposedString"] = ""
    result["candidates"] = []
    result["diagnosticImageFirstString"] = str(best.get("imageFirstString", ""))
    result.setdefault("holds", []).append({
        "code": "SCRIBE_GLYPH_ENVELOPE_HOLD",
        "detail": f"The highest-ranked diagnostic hypothesis has {len(held)} glyph position(s) without unique, reciprocal generic envelope support.",
    })
    deduplicated: list[dict[str, Any]] = []
    seen: set[str] = set()
    for hold in result.get("holds", []):
        code = str(hold.get("code", ""))
        if code and code not in seen:
            seen.add(code)
            deduplicated.append(hold)
    result["holds"] = deduplicated


def run_job(job_path: Path, result_path: Path) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    job = r11.read_json(job_path)
    if str(job.get("references", {}).get("manifestSha256", "")).upper() != EXPECTED_BASE_MANIFEST_SHA256:
        raise ValueError("R18V requires the exact frozen base reference manifest.")
    if str(job.get("references", {}).get("supplementalManifestSha256", "")).upper() != EXPECTED_SUPPLEMENTAL_MANIFEST_SHA256:
        raise ValueError("R18V requires the exact frozen supplemental reference manifest.")
    original_evaluate = R18H.evaluate_detector_input_structural
    original_result_gate = R17E.enforce_result_verifier_only
    original_revision = R18H.REVISION

    def evaluate(
        r11: Any, gray: np.ndarray, prototypes: list[Any], topology: list[Any],
        structure: list[Any], excluded: str, frozen_grid: Any = None,
    ) -> dict[str, Any]:
        return evaluate_detector_input_enveloped(
            r11, gray, prototypes, topology, structure, excluded, frozen_grid,
        )

    def enforce_result(result: dict[str, Any]) -> None:
        original_result_gate(result)
        _apply_result_envelope_state(result)

    R18H.evaluate_detector_input_structural = evaluate
    R17E.enforce_result_verifier_only = enforce_result
    R18H.REVISION = REVISION
    try:
        return R18H.run_job(job_path, result_path)
    finally:
        R18H.REVISION = original_revision
        R17E.enforce_result_verifier_only = original_result_gate
        R18H.evaluate_detector_input_structural = original_evaluate


def main(argv: Iterable[str]) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as error:
        print(json.dumps({
            "state": "HOLD_OPENCV_SCRIBE_PROVIDER_ERROR",
            "errorType": type(error).__name__,
            "detail": str(error),
        }), file=sys.stderr)
        raise
