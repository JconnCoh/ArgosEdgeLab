#!/usr/bin/env python3
"""R18ZT plus conservative cross-hypothesis strong-structure promotion.

The selected hypothesis may move only inside the existing close-score window,
and only to an actual lower-scoring hypothesis whose disputed glyphs already
passed the frozen R18Q strong run-structure rule.  The score is never raised;
checksum, truth, identity, channel, polarity, and direction are not inputs to
the decision.
"""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import math
import sys
from pathlib import Path
from typing import Any, Iterable

import numpy as np


EXPECTED_R18ZT_SHA256 = "AEF048D3CCEAF378A9FF43D5844DD1A28431E662F5BC54AFF384C4DB73A2C793"
EXPECTED_CANONICAL_Z_DEVELOPMENT_GATE_SHA256 = "31C5AD7F7E2A20ACB7CD6542808375D537323247EF4A56DF81C6F92B92209470"
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18ZU_CANONICAL_Z_GEOMETRY_DIAGNOSTIC_20260908"


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
R18ZT_PATH = ROOT / "OPENCV_SCRIBE_R18ZT/ArgosOpenCvScribeV1R18ZT.py"
CANONICAL_Z_DEVELOPMENT_GATE_PATH = (
    ROOT / "OPENCV_SCRIBE_R18ZU/R18ZU_CANONICAL_Z_DEVELOPMENT_GATE_V2.json"
)
if _sha256_file(R18ZT_PATH) != EXPECTED_R18ZT_SHA256:
    raise ValueError("Frozen R18ZT provider SHA-256 mismatch.")
if (
    _sha256_file(CANONICAL_Z_DEVELOPMENT_GATE_PATH)
    != EXPECTED_CANONICAL_Z_DEVELOPMENT_GATE_SHA256
):
    raise ValueError("Frozen canonical-Z development gate SHA-256 mismatch.")
R18ZT = _load("argos_scribe_r18zt_for_r18zu", R18ZT_PATH)
R18ZS = R18ZT.R18ZS
R18Z = R18ZT.R18Z
R18ZV = R18ZT.R18ZV
R18ZR = R18ZT.R18ZR
R18R = R18ZT.R18R
R18Q = R18ZT.R18Q
R18H = R18ZT.R18H
R17E = R18ZT.R17E
R17D = R18ZT.R17D
_RUNTIME_PATCH_LOCK = R18ZT._RUNTIME_PATCH_LOCK

AMBIGUITY_SCORE_DELTA = 0.03
STRONG_STRUCTURE_MAXIMUM_DISTANCE = R18Q.STRONG_STRUCTURE_MAXIMUM_DISTANCE
STRONG_STRUCTURE_MINIMUM_MARGIN = R18Q.STRONG_STRUCTURE_MINIMUM_MARGIN
STRONG_STRUCTURE_MODE = "RUN_STRUCTURE_STRONG_CONSENSUS_OVERRIDE"
CANONICAL_Z_LABEL = "Z"
CANONICAL_Z_MODE = "CANONICAL_Z_RUN_GEOMETRY"
TOP_WIDTH_MINIMUM = 0.75
BOTTOM_WIDTH_MINIMUM = 0.75
MIDDLE_WIDTH_MAXIMUM = 0.45
SIGNED_CENTER_DRIFT_MINIMUM = 0.20
SIGNED_CENTER_CORRELATION_MAXIMUM = -0.55
SINGLE_RUN_BAND_FRACTION_MINIMUM = 0.75
INTERIOR_RUN_COUNT_MAXIMUM = 2
WIDE_MIDDLE_BAND_COUNT_MAXIMUM = 0
VERTICAL_STEM_BAND_COUNT_MAXIMUM = 2


def _finite(value: Any) -> float | None:
    if not isinstance(value, (int, float)):
        return None
    number = float(value)
    return number if math.isfinite(number) else None


def assess_canonical_z_run_geometry(descriptor: Any) -> dict[str, Any]:
    try:
        values = np.asarray(descriptor, dtype=np.float64)
    except (TypeError, ValueError):
        return {"passed": False, "complete": False, "reason": "INVALID_DESCRIPTOR"}
    if (
        values.shape != (189,)
        or not np.all(np.isfinite(values))
        or float(np.min(values)) < 0.0
        or float(np.max(values)) > 1.0
    ):
        return {"passed": False, "complete": False, "reason": "INVALID_DESCRIPTOR"}
    horizontal = values[:108].reshape(12, 9)
    vertical = values[108:].reshape(9, 9)
    horizontal_counts = np.rint(horizontal[:, 0] * 4.0).astype(np.int32)
    vertical_counts = np.rint(vertical[:, 0] * 4.0).astype(np.int32)
    widths = horizontal[:, 2]
    centers = horizontal[:, 1]
    center_window = centers[1:9]
    correlation = (
        float(np.corrcoef(np.arange(8, dtype=np.float64), center_window)[0, 1])
        if float(np.ptp(center_window)) > 1e-12
        else 1.0
    )
    evidence = {
        "complete": True,
        "topWidth": float(np.max(widths[:3])),
        "bottomWidth": float(np.max(widths[-3:])),
        "middleMaximumWidth": float(np.max(widths[3:7])),
        "signedCenterDrift": float(np.mean(centers[1:4]) - np.mean(centers[6:9])),
        "signedCenterCorrelation": correlation,
        "singleRunBandFraction": float(np.mean(horizontal_counts <= 1)),
        "maximumInteriorRunCount": int(np.max(horizontal_counts[1:9])),
        "wideMiddleBandCount": int(np.count_nonzero(widths[2:8] >= 0.48)),
        "verticalStemBandCount": int(np.count_nonzero(
            (vertical_counts == 1) & (vertical[:, 2] >= 0.80)
        )),
    }
    evidence["passed"] = bool(
        evidence["topWidth"] >= TOP_WIDTH_MINIMUM
        and evidence["bottomWidth"] >= BOTTOM_WIDTH_MINIMUM
        and evidence["middleMaximumWidth"] <= MIDDLE_WIDTH_MAXIMUM
        and evidence["signedCenterDrift"] >= SIGNED_CENTER_DRIFT_MINIMUM
        and evidence["signedCenterCorrelation"] <= SIGNED_CENTER_CORRELATION_MAXIMUM
        and evidence["singleRunBandFraction"] >= SINGLE_RUN_BAND_FRACTION_MINIMUM
        and evidence["maximumInteriorRunCount"] <= INTERIOR_RUN_COUNT_MAXIMUM
        and evidence["wideMiddleBandCount"] <= WIDE_MIDDLE_BAND_COUNT_MAXIMUM
        and evidence["verticalStemBandCount"] <= VERTICAL_STEM_BAND_COUNT_MAXIMUM
    )
    return evidence


def rank_with_canonical_z_geometry(
    r11: Any,
    appearance_descriptor: Any,
    topology_descriptor: Any,
    run_structure_descriptor: Any,
    appearance_bank: Any,
    topology_matrix: Any,
    topology_indices: dict[str, Any],
    run_structure_scaling: Any,
    run_structure_consensus: dict[str, Any],
    position: int,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    ranked, arbitration = R18ZT.rank_with_dual_structure_consensus(
        r11,
        appearance_descriptor,
        topology_descriptor,
        run_structure_descriptor,
        appearance_bank,
        topology_matrix,
        topology_indices,
        run_structure_scaling,
        run_structure_consensus,
        position,
    )
    appearance_count = int(len(appearance_bank.label_indices.get(CANONICAL_Z_LABEL, [])))
    topology_count = int(len(topology_indices.get(CANONICAL_Z_LABEL, [])))
    run_present = CANONICAL_Z_LABEL in run_structure_consensus
    originally_present = any(
        str(row.get("character", "")) == CANONICAL_Z_LABEL for row in ranked
    )
    geometry = assess_canonical_z_run_geometry(run_structure_descriptor)
    zero_bank_agreement = (
        appearance_count == 0 and topology_count == 0 and not run_present
    )
    insertion_allowed = (
        CANONICAL_Z_LABEL in r11.allowed_labels(position)
        and bool(geometry.get("passed"))
        and zero_bank_agreement
        and not originally_present
    )
    base_arbitration_mode = str(arbitration.get("mode", ""))
    inherited_score = None
    if insertion_allowed:
        inherited_score = float(ranked[0]["score"])
        ranked = [{
            "character": CANONICAL_Z_LABEL,
            "score": inherited_score,
            "candidateSource": CANONICAL_Z_MODE,
            "referencePrototypeBacked": False,
            "scoreInheritedAsCeiling": True,
        }] + ranked
    sparse_geometry_selected = (
        CANONICAL_Z_LABEL in r11.allowed_labels(position)
        and bool(geometry.get("passed"))
        and appearance_count == 1
        and topology_count == 1
        and run_present
        and originally_present
        and str(ranked[0].get("character", "")) == CANONICAL_Z_LABEL
    )
    canonical_geometry_selected = insertion_allowed or sparse_geometry_selected
    arbitration = dict(arbitration)
    if canonical_geometry_selected:
        arbitration["mode"] = CANONICAL_Z_MODE
    arbitration["canonicalZRunGeometry"] = {
        **geometry,
        "mode": CANONICAL_Z_MODE,
        "allowedAtPosition": CANONICAL_Z_LABEL in r11.allowed_labels(position),
        "appearanceBankCount": appearance_count,
        "topologyBankCount": topology_count,
        "runStructureBankPresent": run_present,
        "zeroBankAgreement": zero_bank_agreement,
        "candidateOriginallyPresent": originally_present,
        "candidateInserted": insertion_allowed,
        "canonicalGeometrySelected": canonical_geometry_selected,
        "baseArbitrationMode": base_arbitration_mode,
        "inheritedScore": inherited_score,
        "scoreIncreased": False,
    }
    return ranked, arbitration


def _compact_positions(positions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    compact: list[dict[str, Any]] = []
    for position in positions:
        arbitration = dict(position.get("glyphArbitration", {}))
        scores = {
            str(row["character"]): float(row["appearanceScore"])
            for row in position.get("allCandidates", [])
            if "character" in row and "appearanceScore" in row
        }
        compact.append({
            "position": int(position["position"]),
            "imageFirst": str(position["imageFirst"]),
            "arbitrationMode": str(arbitration.get("mode", "")),
            "appearanceScores": scores,
            "runStructureFirst": str(arbitration.get("runStructureFirst", "")),
            "runStructureFirstDistance": arbitration.get("runStructureFirstDistance"),
            "runStructureMargin": arbitration.get("runStructureMargin"),
            "strongStructureApplied": arbitration.get("strongStructureApplied") is True,
            "canonicalZRunGeometry": dict(
                arbitration.get("canonicalZRunGeometry", {})
            ),
        })
    return compact


class _FinalizeProxy:
    def __init__(self, base: Any):
        self._base = base

    def __getattr__(self, name: str) -> Any:
        return getattr(self._base, name)

    def finalize_grid(self, grid: dict[str, Any]) -> dict[str, Any]:
        evidence = _compact_positions(grid["positions"])
        output = self._base.finalize_grid(grid)
        output["positionEvidence"] = evidence
        return output


def compact_position_evidence(result: dict[str, Any]) -> list[dict[str, Any]]:
    """Return finalized evidence without reconstructing candidate order."""

    return list(result.get("positionEvidence", []))


def _coherent_positions(
    row: dict[str, Any], text: str,
) -> dict[int, dict[str, Any]] | None:
    return R18R._coherent_positions(row, text)


def _strong_metrics(position: dict[str, Any]) -> tuple[str, float, float] | None:
    label = str(position.get("runStructureFirst", ""))
    distance = _finite(position.get("runStructureFirstDistance"))
    margin = _finite(position.get("runStructureMargin"))
    if (
        not label
        or distance is None
        or margin is None
        or distance > STRONG_STRUCTURE_MAXIMUM_DISTANCE
        or margin < STRONG_STRUCTURE_MINIMUM_MARGIN
    ):
        return None
    return label, distance, margin


def _promotion_check(
    leader: dict[str, Any], rival: dict[str, Any],
) -> dict[str, Any]:
    leader_string = str(leader.get("imageFirstString", ""))
    rival_string = str(rival.get("imageFirstString", ""))
    left = _coherent_positions(leader, leader_string)
    right = _coherent_positions(rival, rival_string)
    passed = (
        left is not None
        and right is not None
        and len(leader_string) == 12
        and len(rival_string) == 12
        and leader_string != rival_string
    )
    evidence: list[dict[str, Any]] = []
    for index, (leader_char, rival_char) in enumerate(
        zip(leader_string, rival_string), 1
    ):
        if leader_char == rival_char:
            continue
        leader_position = (left or {}).get(index, {})
        rival_position = (right or {}).get(index, {})
        leader_metrics = _strong_metrics(leader_position)
        rival_metrics = _strong_metrics(rival_position)
        position_passed = bool(
            leader_position.get("arbitrationMode") == "APPEARANCE"
            and rival_position.get("arbitrationMode") == STRONG_STRUCTURE_MODE
            and rival_position.get("strongStructureApplied") is True
            and leader_metrics is not None
            and rival_metrics is not None
            and leader_metrics[0] == rival_char
            and rival_metrics[0] == rival_char
        )
        passed = passed and position_passed
        evidence.append({
            "position": index,
            "leaderCharacter": leader_char,
            "rivalCharacter": rival_char,
            "leaderArbitrationMode": leader_position.get("arbitrationMode"),
            "rivalArbitrationMode": rival_position.get("arbitrationMode"),
            "leaderRunStructureFirst": None if leader_metrics is None else leader_metrics[0],
            "rivalRunStructureFirst": None if rival_metrics is None else rival_metrics[0],
            "leaderRunStructureDistance": None if leader_metrics is None else leader_metrics[1],
            "rivalRunStructureDistance": None if rival_metrics is None else rival_metrics[1],
            "leaderRunStructureMargin": None if leader_metrics is None else leader_metrics[2],
            "rivalRunStructureMargin": None if rival_metrics is None else rival_metrics[2],
            "rivalStrongStructureApplied": rival_position.get("strongStructureApplied") is True,
            "passed": position_passed,
        })
    return {"promotable": passed and bool(evidence), "positions": evidence}


def _has_conflicting_strong_vote(
    rows: list[dict[str, Any]], leader: dict[str, Any], rival: dict[str, Any],
) -> bool:
    leader_string = str(leader["imageFirstString"])
    rival_string = str(rival["imageFirstString"])
    differing = {
        index: rival_char
        for index, (leader_char, rival_char) in enumerate(
            zip(leader_string, rival_string), 1
        )
        if leader_char != rival_char
    }
    for row in rows:
        positions = _coherent_positions(row, str(row.get("imageFirstString", "")))
        if positions is None:
            continue
        for index, promoted_char in differing.items():
            metrics = _strong_metrics(positions[index])
            if metrics is not None and metrics[0] != promoted_char:
                return True
    return False


def apply_canonical_z_admission(evaluated: dict[str, Any]) -> dict[str, Any]:
    """Admit only a geometry-selected Z with no covered-envelope conflict."""

    admitted: list[dict[str, Any]] = []
    envelope = dict(evaluated.get("ocrEnvelope", {}))
    original_held = list(envelope.get("heldPositions", []))
    admitted_held_indices: set[int] = set()
    for position in list(evaluated.get("positions", [])):
        assessment = dict(position.get("glyphEnvelope", {}))
        pre_admission_assessment = copy.deepcopy(assessment)
        arbitration = dict(position.get("glyphArbitration", {}))
        geometry = dict(arbitration.get("canonicalZRunGeometry", {}))
        decision = str(assessment.get("decision", ""))
        coverage = str(assessment.get("upstreamCoverageState", ""))
        lineage_count = int(
            assessment.get("upstreamIndependentPhysicalLineageCount", 0)
        )
        distances = [
            row for row in assessment.get("candidateEnvelopeDistances", [])
            if isinstance(row, dict)
        ]
        no_covered_rival = bool(distances) and not any(
            bool(row.get("insideOwnEnvelope")) for row in distances
        )
        score_used = _finite(position.get("scoreUsedForGrid"))
        exact_held_indices = [
            index for index, row in enumerate(original_held)
            if isinstance(row, dict)
            and int(row.get("position", 0)) == int(position.get("position", 0))
            and str(row.get("diagnosticLabel", "")) == CANONICAL_Z_LABEL
            and str(row.get("decision", "")) == decision
        ]
        unobserved = (
            decision == "HOLD_SELECTED_LABEL_UNOBSERVED"
            and coverage == "UNOBSERVED"
            and lineage_count == 0
            and int(geometry.get("appearanceBankCount", -1)) == 0
            and int(geometry.get("topologyBankCount", -1)) == 0
            and geometry.get("runStructureBankPresent") is False
            and geometry.get("zeroBankAgreement") is True
            and geometry.get("candidateInserted") is True
            and geometry.get("candidateOriginallyPresent") is False
            and _finite(geometry.get("inheritedScore")) is not None
            and score_used is not None
            and math.isclose(
                score_used,
                float(geometry["inheritedScore"]),
                rel_tol=0.0,
                abs_tol=1e-12,
            )
        )
        sparse_single_lineage = (
            decision == "HOLD_SELECTED_LABEL_SPARSE"
            and coverage == "SPARSE"
            and lineage_count == 1
            and int(geometry.get("appearanceBankCount", -1)) == 1
            and int(geometry.get("topologyBankCount", -1)) == 1
            and geometry.get("runStructureBankPresent") is True
            and geometry.get("candidateInserted") is False
            and geometry.get("candidateOriginallyPresent") is True
        )
        accepted = (
            not bool(assessment.get("accepted"))
            and str(position.get("imageFirst", "")) == CANONICAL_Z_LABEL
            and str(assessment.get("upstreamLabel", "")) == CANONICAL_Z_LABEL
            and str(assessment.get("selectedLabel", "")) == CANONICAL_Z_LABEL
            and geometry.get("complete") is True
            and geometry.get("passed") is True
            and geometry.get("allowedAtPosition") is True
            and geometry.get("canonicalGeometrySelected") is True
            and geometry.get("scoreIncreased") is False
            and no_covered_rival
            and len(exact_held_indices) == 1
            and (unobserved or sparse_single_lineage)
        )
        admission_mode = (
            "UNOBSERVED_ZERO_LINEAGE_CANONICAL_Z_RUN_GEOMETRY"
            if unobserved else
            "SPARSE_SINGLE_LINEAGE_CANONICAL_Z_RUN_GEOMETRY"
            if sparse_single_lineage else "NOT_APPLIED"
        )
        assessment["canonicalZAdmission"] = {
            "applied": accepted,
            "mode": admission_mode if accepted else "NOT_APPLIED",
            "originalDecision": decision,
            "selectedLabelChanged": False,
            "scoreIncreased": False,
            "coveredRivalEvidenceComplete": bool(distances),
            "coveredRivalInsideEnvelope": any(
                bool(row.get("insideOwnEnvelope")) for row in distances
            ),
            "developmentGateSha256": EXPECTED_CANONICAL_Z_DEVELOPMENT_GATE_SHA256,
            "externalMetadataUsed": False,
            "preAdmissionGlyphEnvelope": pre_admission_assessment,
        }
        if accepted:
            assessment["accepted"] = True
            assessment["decision"] = f"ACCEPT_{admission_mode}"
            assessment["changedByEnvelope"] = False
            admitted.append({
                "position": int(position.get("position", 0)),
                "label": CANONICAL_Z_LABEL,
                "mode": admission_mode,
                "originalDecision": decision,
            })
            admitted_held_indices.add(exact_held_indices[0])
        position["glyphEnvelope"] = assessment

    held = [
        row for index, row in enumerate(original_held)
        if index not in admitted_held_indices
    ]
    envelope.update({
        "passed": not held,
        "decision": (
            "PASS_ALL_SELECTED_GLYPHS_ENVELOPED_OR_GENERICALLY_SUPPORTED"
            if not held else "HOLD_ONE_OR_MORE_SELECTED_GLYPHS_NOT_ENVELOPED"
        ),
        "heldPositions": held,
        "canonicalZAdmissionRevision": REVISION,
        "canonicalZAdmissionPositions": admitted,
    })
    evaluated["ocrEnvelope"] = envelope
    evaluated.setdefault("glyphRanking", {}).update({
        "canonicalZRunGeometryEnabled": True,
        "canonicalZRunGeometryCanIncreaseScore": False,
        "canonicalZDevelopmentGateSha256": (
            EXPECTED_CANONICAL_Z_DEVELOPMENT_GATE_SHA256
        ),
    })
    return evaluated


def resolve_hypotheses(
    hypotheses: list[dict[str, Any]],
    any_structure_pass: bool,
    minimum_image_score: float = 0.60,
    ambiguity_score_delta: float = AMBIGUITY_SCORE_DELTA,
) -> dict[str, Any]:
    """Apply frozen R18R first, then one fail-closed structural promotion."""

    base = R18R.resolve_hypotheses(
        hypotheses,
        any_structure_pass,
        minimum_image_score,
        ambiguity_score_delta,
    )
    output = dict(base)
    output.update({
        "structuralPromotionApplied": False,
        "structuralPromotionMode": "NOT_APPLIED",
        "structuralPromotionMaximumDistance": STRONG_STRUCTURE_MAXIMUM_DISTANCE,
        "structuralPromotionMinimumMargin": STRONG_STRUCTURE_MINIMUM_MARGIN,
        "structuralPromotionComparisons": [],
        "selectionScoreIncreased": False,
    })
    if base.get("state") != "HOLD_SCRIBE_MULTIPLE_CLOSE_IMAGE_FIRST_STRINGS":
        return output
    leader = base.get("best")
    if not isinstance(leader, dict):
        return output
    leader_score = _finite(leader.get("selectionScore"))
    if leader_score is None:
        return output
    raw_rows = [
        row for row in hypotheses
        if bool(row.get("boundaryComplete"))
        and _finite(row.get("selectionScore")) is not None
        and float(row["selectionScore"]) >= leader_score - ambiguity_score_delta
    ]
    by_string: dict[str, list[tuple[dict[str, Any], dict[str, Any]]]] = {}
    comparisons: list[dict[str, Any]] = []
    leader_string = str(leader.get("imageFirstString", ""))
    for row in raw_rows:
        rival_string = str(row.get("imageFirstString", ""))
        if rival_string == leader_string:
            continue
        check = _promotion_check(leader, row)
        comparisons.append({"rivalString": rival_string, "check": check})
        if bool(check.get("promotable")):
            by_string.setdefault(rival_string, []).append((row, check))
    output["structuralPromotionComparisons"] = comparisons
    if len(by_string) != 1:
        return output
    rival_string, candidates = next(iter(by_string.items()))
    raw_close_strings = {
        str(row.get("imageFirstString", "")) for row in raw_rows
    }
    if raw_close_strings != {leader_string, rival_string}:
        output["structuralPromotionMode"] = "NOT_APPLIED_ADDITIONAL_RAW_CLOSE_STRING"
        return output
    candidates.sort(key=lambda item: -float(item[0]["selectionScore"]))
    top_score = float(candidates[0][0]["selectionScore"])
    top_candidates = [
        item for item in candidates
        if math.isclose(
            float(item[0]["selectionScore"]), top_score,
            rel_tol=0.0,
            abs_tol=R18R.TOP_SCORE_TIE_ABSOLUTE_TOLERANCE,
        )
    ]
    if len(top_candidates) != 1:
        return output
    rival = top_candidates[0][0]
    if _has_conflicting_strong_vote(raw_rows, leader, rival):
        output["structuralPromotionMode"] = "NOT_APPLIED_CONFLICTING_STRONG_VOTE"
        return output
    rival_score = float(rival["selectionScore"])
    if rival_score < minimum_image_score:
        output["structuralPromotionMode"] = "NOT_APPLIED_BELOW_FROZEN_MINIMUM"
        return output
    output.update({
        "state": "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE",
        "best": rival,
        "closeImageFirstStrings": [rival_string],
        "structuralPromotionApplied": True,
        "structuralPromotionMode": "CLOSE_RIVAL_RECIPROCAL_STRONG_RUN_STRUCTURE",
        "structuralPromotionLeaderString": leader_string,
        "structuralPromotionSelectedString": rival_string,
        "structuralPromotionOriginalLeaderScore": leader_score,
        "structuralPromotionSelectedScore": rival_score,
        "structuralPromotionScoreDelta": rival_score - leader_score,
        "selectionScoreIncreased": rival_score > leader_score,
    })
    if output["selectionScoreIncreased"]:
        raise AssertionError("Structural promotion increased the selected score.")
    return output


def _evaluate_exact_lineage(
    active_r11: Any,
    gray: Any,
    prototypes: list[Any],
    topology: list[Any],
    run_structure: list[Any],
    excluded: str,
    mapping: dict[str, str],
    frozen_grid: tuple[int, int, int, int] | None = None,
) -> dict[str, Any]:
    old_rank = R18H.rank_with_run_structure
    R18H.rank_with_run_structure = rank_with_canonical_z_geometry
    try:
        output = R18Z.evaluate_detector_input_exact_lineage(
            _FinalizeProxy(active_r11),
            gray,
            prototypes,
            topology,
            run_structure,
            excluded,
            mapping,
            frozen_grid,
        )
    finally:
        R18H.rank_with_run_structure = old_rank
    return apply_canonical_z_admission(R18ZT.apply_generic_hold_rescue(output))


def evaluate_detector_input_structural(
    active_r11: Any,
    gray: Any,
    prototypes: list[Any],
    topology: list[Any],
    run_structure: list[Any],
    excluded: str,
    frozen_grid: tuple[int, int, int, int] | None = None,
) -> dict[str, Any]:
    mapping, _ = R18Z.load_lineage_mapping(
        R18Z.DEFAULT_LINEAGE_CROSSWALK_PATH,
        R18Z.EXPECTED_LINEAGE_CROSSWALK_SHA256,
    )
    return _evaluate_exact_lineage(
        active_r11,
        gray,
        prototypes,
        topology,
        run_structure,
        excluded,
        mapping,
        frozen_grid,
    )


def run_job(job_path: Path, result_path: Path) -> int:
    if not _RUNTIME_PATCH_LOCK.acquire(blocking=False):
        raise RuntimeError("Concurrent R18ZU provider invocation is not allowed.")
    old_evaluate = R18ZV.evaluate_detector_input_enveloped
    old_enforce = R17E.enforce_result_verifier_only
    old_apply = R18ZV._apply_result_envelope_state
    old_pipeline_revision = R18ZV.REVISION
    try:
        r11 = R17D.R17C.R17B._load_r11()
        job = r11.read_json(job_path)
        references = job.get("references", {})
        crosswalk_path = Path(str(references.get("exactScribeLineageCrosswalkPath", "")))
        crosswalk_sha256 = str(
            references.get("exactScribeLineageCrosswalkSha256", "")
        ).upper()
        mapping, mapping_fingerprint = R18Z.load_lineage_mapping(
            crosswalk_path, crosswalk_sha256
        )

        def integrated_evaluate(
            active_r11: Any,
            gray: Any,
            prototypes: list[Any],
            topology: list[Any],
            run_structure: list[Any],
            excluded: str,
            frozen_grid: tuple[int, int, int, int] | None = None,
        ) -> dict[str, Any]:
            return _evaluate_exact_lineage(
                active_r11,
                gray,
                prototypes,
                topology,
                run_structure,
                excluded,
                mapping,
                frozen_grid,
            )

        def resolve_then_enforce(result: dict[str, Any]) -> None:
            hypotheses = list(result.get("hypotheses", []))
            resolution = resolve_hypotheses(
                hypotheses,
                any(
                    bool(row.get("scribePresence", {}).get("passed"))
                    for row in hypotheses
                ),
                minimum_image_score=0.60,
                ambiguity_score_delta=AMBIGUITY_SCORE_DELTA,
            )
            best = resolution.get("best")
            if (
                resolution.get("state") == "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"
                and isinstance(best, dict)
            ):
                result["hypotheses"] = [best] + [
                    row for row in hypotheses if row is not best
                ]
                result["imageFirstString"] = str(best.get("imageFirstString", ""))
            old_enforce(result)
            result["ambiguityResolution"] = R18ZR._bounded_resolution(resolution)
            result["selectedHypothesis"] = R18ZR._selected_summary(
                result["hypotheses"][0] if result.get("hypotheses") else None
            )
            if resolution.get("state") != "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE":
                state = str(
                    resolution.get("state", "HOLD_SCRIBE_RESOLUTION_FAILED")
                )
                result["state"] = state
                result["eligibleIdentity"] = False
                result["proposedString"] = ""
                result["candidates"] = []
                result.setdefault("holds", []).append({
                    "code": state,
                    "detail": (
                        "The image-first resolver did not select one uniquely "
                        "supported hypothesis."
                    ),
                })
                R18ZR._deduplicate_holds(result)

        def apply_result(result: dict[str, Any]) -> None:
            old_apply(result)
            result.setdefault("provenance", {}).update({
                "engineRevision": REVISION,
                "r18ztProviderSha256": EXPECTED_R18ZT_SHA256,
                "r18zsProviderSha256": R18ZT.EXPECTED_R18ZS_SHA256,
                "r18vDenseDevelopmentGateSha256": (
                    R18ZT.R18V_DENSE_DEVELOPMENT_GATE_SHA256
                ),
                "genericHoldRescue": True,
                "genericHoldRescueMayChangeSelectedLabel": False,
                "crossModalTopologyMarginMinimum": (
                    R18ZT.CROSS_MODAL_TOPOLOGY_MARGIN_MINIMUM
                ),
                "crossModalTopologyMarginIsNewThreshold": False,
                "topologyScoreMinimum": R18ZT.TOPOLOGY_SCORE_MINIMUM,
                "crossHypothesisStrongStructurePromotion": True,
                "crossHypothesisPromotionMaximumDistance": (
                    STRONG_STRUCTURE_MAXIMUM_DISTANCE
                ),
                "crossHypothesisPromotionMinimumMargin": (
                    STRONG_STRUCTURE_MINIMUM_MARGIN
                ),
                "crossHypothesisPromotionScoreMayIncrease": False,
                "canonicalZRunGeometry": True,
                "canonicalZRunGeometryMayIncreaseScore": False,
                "canonicalZDevelopmentGateSha256": (
                    EXPECTED_CANONICAL_Z_DEVELOPMENT_GATE_SHA256
                ),
                "runtimeExpectedTruthUsedForGlyphSelection": False,
                "checksumMayRewriteGlyphs": False,
                "checksumMaySelectHypothesis": False,
                "referencePhysicalLineageKey": (
                    "EXACT_HUMAN_CONFIRMED_12_CHARACTER_SCRIBE"
                ),
                "exactScribeLineageCrosswalkSha256": crosswalk_sha256,
                "exactScribeLineageMappingFingerprint": mapping_fingerprint,
            })
            result["revision"] = REVISION
            if (
                result.get("ambiguityResolution", {}).get("state")
                != "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"
            ):
                state = str(result["ambiguityResolution"].get("state"))
                result["state"] = state
                result["eligibleIdentity"] = False
                result["proposedString"] = ""
                result["candidates"] = []
                R18ZR._deduplicate_holds(result)

        R18ZV.evaluate_detector_input_enveloped = integrated_evaluate
        R17E.enforce_result_verifier_only = resolve_then_enforce
        R18ZV._apply_result_envelope_state = apply_result
        R18ZV.REVISION = REVISION
        return R18ZV._run_job_locked(job_path, result_path)
    finally:
        R18ZV.REVISION = old_pipeline_revision
        R18ZV._apply_result_envelope_state = old_apply
        R17E.enforce_result_verifier_only = old_enforce
        R18ZV.evaluate_detector_input_enveloped = old_evaluate
        _RUNTIME_PATCH_LOCK.release()


def main(argv: Iterable[str]) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
