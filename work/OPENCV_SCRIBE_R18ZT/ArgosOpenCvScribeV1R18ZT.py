#!/usr/bin/env python3
"""R18ZS plus a generic, evidence-frozen glyph-hold rescue.

The image-first ranking, eight-view hypothesis path, reciprocal hypothesis
resolver, and exact-lineage envelope remain unchanged.  This revision can
remove only two narrowly defined per-glyph holds when cross-modal appearance,
topology, run-structure, and covered-rival evidence satisfy the generic rule
frozen by the companion development gate.  It never changes a selected glyph,
raises a score, uses checksum/truth/lot/slot, or admits an unobserved or
one-lineage label.
"""

from __future__ import annotations

import hashlib
import importlib.util
import math
import sys
from pathlib import Path
from typing import Any, Iterable


EXPECTED_R18ZS_SHA256 = "FD46B5F91189691A469B72EC29D8C07FA7FE0119950D24AD8FFD549AE01FF094"
R18V_DENSE_DEVELOPMENT_GATE_SHA256 = "BEA75FAC417BEE9D0DB5B3302AEEAD15053C46A2AC434BBB7A49E04AADC437C9"
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18ZT_GENERIC_HOLD_RESCUE_DIAGNOSTIC_20260906"

# The 0.75 quantile of correct-label normalized distance in the frozen R18V
# 465-query exact-lineage development gate.  This is deliberately a covered-
# tail bound, not an enlargement of any class envelope.
COVERED_TAIL_MAXIMUM_NORMALIZED_DISTANCE = 1.3722590869023246


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
R18ZS_PATH = ROOT / "OPENCV_SCRIBE_R18ZS/ArgosOpenCvScribeV1R18ZS.py"
if _sha256_file(R18ZS_PATH) != EXPECTED_R18ZS_SHA256:
    raise ValueError("Frozen R18ZS provider SHA-256 mismatch.")
R18ZS = _load("argos_scribe_r18zs_for_r18zt", R18ZS_PATH)
R18ZR = R18ZS.R18ZR
R18Z = R18ZS.R18Z
R18ZV = R18ZS.R18ZV
R18V = R18Z.R18V
R18Q = R18ZS.R18Q
R18R = R18ZS.R18R
R18H = R18ZS.R18H
R18F = R18ZS.R18H.R18F
R17E = R18ZS.R17E
R17D = R18ZS.R17D
MINIMUM_POST_GRID_IMAGE_SCORE = R18ZS.R18H.MINIMUM_POST_GRID_IMAGE_SCORE
load_run_structure_prototypes = R18ZS.R18H.load_run_structure_prototypes
rank_with_dual_structure_consensus = R18ZS.rank_with_dual_structure_consensus
_RUNTIME_PATCH_LOCK = R18ZS._RUNTIME_PATCH_LOCK

# The acceptance seam reuses existing same-unit R18Q/R17D/R18H thresholds.
# The separate frozen 0.90 topology-score floor makes the existing R18Q 0.12
# topology-margin threshold zero-wrong across the 475-query development sweep.
APPEARANCE_DECISIVE_GAP = R18H.APPEARANCE_TIE_MAXIMUM_GAP
RUN_STRUCTURE_STRONG_MARGIN = R18H.RUN_STRUCTURE_MINIMUM_MARGIN
TOPOLOGY_SCORE_MINIMUM = R17D.TOPOLOGY_OVERRIDE_MINIMUM_SCORE
CROSS_MODAL_TOPOLOGY_MARGIN_MINIMUM = R18Q.TOPOLOGY_OVERRIDE_MINIMUM_MARGIN
MINIMUM_SPARSE_LINEAGES = 2
MAXIMUM_SPARSE_LINEAGES = R18V.MINIMUM_ENFORCEABLE_LINEAGES - 1


def _finite_float(value: Any, default: float = -math.inf) -> float:
    try:
        result = float(value)
    except (TypeError, ValueError):
        return default
    return result if math.isfinite(result) else default


def assess_generic_hold_rescue(
    assessment: dict[str, Any],
    arbitration: dict[str, Any],
) -> dict[str, Any]:
    """Return an assessment with at most a hold-to-accept transition.

    The selected label is immutable.  Candidate envelope rows enumerate every
    enforceable covered label allowed at the position, so requiring all rivals
    outside radius proves that no covered rival claims the query.
    """

    output = dict(assessment)
    upstream = str(output.get("upstreamLabel", ""))
    selected = str(output.get("selectedLabel", ""))
    decision = str(output.get("decision", ""))
    coverage = str(output.get("upstreamCoverageState", ""))
    distances = [
        dict(row) for row in output.get("candidateEnvelopeDistances", [])
        if isinstance(row, dict)
    ]
    ordered = sorted(
        distances,
        key=lambda row: (
            _finite_float(row.get("normalizedDistance"), math.inf),
            str(row.get("label", "")),
        ),
    )
    by_label = {str(row.get("label", "")): row for row in ordered}
    appearance_first = str(arbitration.get("appearanceFirst", ""))
    topology_first = str(arbitration.get("topologyFirst", ""))
    run_first = str(arbitration.get("runStructureFirst", ""))
    appearance_gap = _finite_float(arbitration.get("appearanceGap"))
    topology_margin = _finite_float(arbitration.get("topologyMargin"))
    topology_score = _finite_float(arbitration.get("topologyFirstScore"))
    run_margin = _finite_float(arbitration.get("runStructureMargin"))
    all_covered_rivals_outside = bool(distances) and all(
        _finite_float(row.get("normalizedDistance"), math.inf) > 1.0
        for row in distances
        if str(row.get("label", "")) != upstream
    )
    common = (
        bool(upstream)
        and selected == upstream
        and appearance_first == upstream
        and topology_first == upstream
        and appearance_gap > APPEARANCE_DECISIVE_GAP
        and topology_score >= TOPOLOGY_SCORE_MINIMUM
        and topology_margin >= CROSS_MODAL_TOPOLOGY_MARGIN_MINIMUM
        and all_covered_rivals_outside
    )

    upstream_distance = by_label.get(upstream)
    covered_tail = (
        not bool(output.get("accepted"))
        and decision == "HOLD_OUTSIDE_ALL_ENFORCEABLE_ENVELOPES"
        and coverage == "COVERED"
        and common
        and upstream_distance is not None
        and bool(ordered)
        and str(ordered[0].get("label", "")) == upstream
        and _finite_float(upstream_distance.get("normalizedDistance"), math.inf)
        <= COVERED_TAIL_MAXIMUM_NORMALIZED_DISTANCE
        and (
            run_first == upstream
            or run_margin < RUN_STRUCTURE_STRONG_MARGIN
        )
    )
    lineage_count = int(output.get("upstreamIndependentPhysicalLineageCount", 0))
    sparse_consensus = (
        not bool(output.get("accepted"))
        and decision == "HOLD_SELECTED_LABEL_SPARSE"
        and coverage == "SPARSE"
        and common
        and MINIMUM_SPARSE_LINEAGES <= lineage_count <= MAXIMUM_SPARSE_LINEAGES
        and run_first == upstream
        and run_margin >= RUN_STRUCTURE_STRONG_MARGIN
    )
    mode = (
        "COVERED_TAIL_CROSS_MODAL_RECIPROCAL_SUPPORT"
        if covered_tail else
        "SPARSE_MULTI_LINEAGE_THREE_MODAL_RECIPROCAL_SUPPORT"
        if sparse_consensus else "NOT_APPLIED"
    )
    evidence = {
        "applied": bool(covered_tail or sparse_consensus),
        "mode": mode,
        "originalDecision": decision,
        "selectedLabelChanged": False,
        "appearanceFirst": appearance_first,
        "topologyFirst": topology_first,
        "runStructureFirst": run_first,
        "appearanceGap": appearance_gap,
        "topologyMargin": topology_margin,
        "topologyFirstScore": topology_score,
        "runStructureMargin": run_margin,
        "allCoveredRivalsOutside": all_covered_rivals_outside,
        "upstreamIndependentPhysicalLineageCount": lineage_count,
        "coveredTailMaximumNormalizedDistance": COVERED_TAIL_MAXIMUM_NORMALIZED_DISTANCE,
        "crossModalTopologyMarginMinimum": CROSS_MODAL_TOPOLOGY_MARGIN_MINIMUM,
        "crossModalTopologyMarginIsNewThreshold": False,
        "topologyScoreMinimum": TOPOLOGY_SCORE_MINIMUM,
        "checksumTruthLotSlotUsed": False,
    }
    output["genericHoldRescue"] = evidence
    if covered_tail or sparse_consensus:
        output["accepted"] = True
        output["decision"] = f"ACCEPT_{mode}"
        output["selectedLabel"] = upstream
        output["changedByEnvelope"] = False
        output["checksumUsed"] = False
    return output


def apply_generic_hold_rescue(evaluated: dict[str, Any]) -> dict[str, Any]:
    """Apply the generic assessment rule without changing OCR ranking."""

    positions = list(evaluated.get("positions", []))
    rescued_positions: list[dict[str, Any]] = []
    for position in positions:
        original = dict(position.get("glyphEnvelope", {}))
        updated = assess_generic_hold_rescue(
            original, dict(position.get("glyphArbitration", {}))
        )
        position["glyphEnvelope"] = updated
        rescue = dict(updated.get("genericHoldRescue", {}))
        if bool(rescue.get("applied")):
            if str(position.get("imageFirst", "")) != str(updated.get("selectedLabel", "")):
                raise ValueError("Generic hold rescue attempted to change the selected glyph.")
            rescued_positions.append({
                "position": int(position.get("position", 0)),
                "label": str(updated.get("selectedLabel", "")),
                "mode": str(rescue.get("mode", "")),
                "originalDecision": str(rescue.get("originalDecision", "")),
            })
    evaluated["positions"] = positions
    envelope = dict(evaluated.get("ocrEnvelope", {}))
    rescued_indices = {int(row["position"]) for row in rescued_positions}
    held = [
        row for row in envelope.get("heldPositions", [])
        if int(row.get("position", 0)) not in rescued_indices
    ]
    envelope.update({
        "passed": not held,
        "decision": (
            "PASS_ALL_SELECTED_GLYPHS_ENVELOPED_OR_GENERICALLY_SUPPORTED"
            if not held else "HOLD_ONE_OR_MORE_SELECTED_GLYPHS_NOT_ENVELOPED"
        ),
        "heldPositions": held,
        "genericHoldRescueRevision": REVISION,
        "genericHoldRescuePositions": rescued_positions,
        "checksumUsed": False,
    })
    evaluated["ocrEnvelope"] = envelope
    evaluated.setdefault("glyphRanking", {}).update({
        "method": "R18ZS_DUAL_STRUCTURE_THEN_R18Z_ENVELOPE_THEN_R18ZT_GENERIC_HOLD_RESCUE",
        "genericHoldRescueEnabled": True,
        "genericHoldRescueCanChangeSelectedLabel": False,
        "coveredTailMaximumNormalizedDistance": COVERED_TAIL_MAXIMUM_NORMALIZED_DISTANCE,
        "appearanceDecisiveGap": APPEARANCE_DECISIVE_GAP,
        "crossModalTopologyMarginMinimum": CROSS_MODAL_TOPOLOGY_MARGIN_MINIMUM,
        "topologyScoreMinimum": TOPOLOGY_SCORE_MINIMUM,
        "runStructureStrongMargin": RUN_STRUCTURE_STRONG_MARGIN,
        "minimumSparseIndependentLineages": MINIMUM_SPARSE_LINEAGES,
        "maximumSparseIndependentLineages": MAXIMUM_SPARSE_LINEAGES,
        "checksumUsedForImageFirst": False,
    })
    return evaluated


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
    R18H.rank_with_run_structure = rank_with_dual_structure_consensus
    try:
        output = R18Z.evaluate_detector_input_exact_lineage(
            R18R._FinalizeProxy(active_r11),
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
    return apply_generic_hold_rescue(output)


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
        active_r11, gray, prototypes, topology, run_structure,
        excluded, mapping, frozen_grid,
    )


def run_job(job_path: Path, result_path: Path) -> int:
    if not _RUNTIME_PATCH_LOCK.acquire(blocking=False):
        raise RuntimeError("Concurrent R18ZT provider invocation is not allowed.")
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
                active_r11, gray, prototypes, topology, run_structure,
                excluded, mapping, frozen_grid,
            )

        def resolve_then_enforce(result: dict[str, Any]) -> None:
            hypotheses = list(result.get("hypotheses", []))
            resolution = R18R.resolve_hypotheses(
                hypotheses,
                any(bool(row.get("scribePresence", {}).get("passed")) for row in hypotheses),
                minimum_image_score=0.60,
                ambiguity_score_delta=0.03,
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
                state = str(resolution.get("state", "HOLD_SCRIBE_RESOLUTION_FAILED"))
                result["state"] = state
                result["eligibleIdentity"] = False
                result["proposedString"] = ""
                result["candidates"] = []
                result.setdefault("holds", []).append({
                    "code": state,
                    "detail": "The frozen reciprocal image-first resolver did not select a unique supported hypothesis.",
                })
                R18ZR._deduplicate_holds(result)

        def apply_result(result: dict[str, Any]) -> None:
            old_apply(result)
            result.setdefault("provenance", {}).update({
                "engineRevision": REVISION,
                "r18zsProviderSha256": EXPECTED_R18ZS_SHA256,
                "r18vDenseDevelopmentGateSha256": R18V_DENSE_DEVELOPMENT_GATE_SHA256,
                "genericHoldRescue": True,
                "genericHoldRescueMayChangeSelectedLabel": False,
                "crossModalTopologyMarginMinimum": CROSS_MODAL_TOPOLOGY_MARGIN_MINIMUM,
                "crossModalTopologyMarginIsNewThreshold": False,
                "topologyScoreMinimum": TOPOLOGY_SCORE_MINIMUM,
                "referencePhysicalLineageKey": "EXACT_HUMAN_CONFIRMED_12_CHARACTER_SCRIBE",
                "exactScribeLineageCrosswalkSha256": crosswalk_sha256,
                "exactScribeLineageMappingFingerprint": mapping_fingerprint,
                "runtimeExpectedTruthUsedForGlyphSelection": False,
                "checksumMayRewriteGlyphs": False,
                "checksumMaySelectHypothesis": False,
            })
            result["revision"] = REVISION
            if result.get("ambiguityResolution", {}).get("state") != "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE":
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
