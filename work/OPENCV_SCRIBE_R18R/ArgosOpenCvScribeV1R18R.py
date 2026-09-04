#!/usr/bin/env python3
"""R18Q OCR plus label-agnostic reciprocal-margin ambiguity resolution."""

from __future__ import annotations

import importlib.util
import math
import sys
import threading
from pathlib import Path
from typing import Any, Iterable


def _load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


ROOT = Path(__file__).resolve().parents[1]
R18Q = _load("argos_scribe_r18q_for_r18r", ROOT / "OPENCV_SCRIBE_R18Q/ArgosOpenCvScribeV1R18Q.py")
R18H = R18Q.R18H
R18F = R18Q.R18F
R17E = R18Q.R17E
R17D = R18Q.R17D
MINIMUM_POST_GRID_IMAGE_SCORE = R18Q.MINIMUM_POST_GRID_IMAGE_SCORE
rank_with_run_structure = R18Q.rank_with_run_structure
load_run_structure_prototypes = R18Q.load_run_structure_prototypes
_run_structure_context = R18Q._run_structure_context

REVISION = "ARGOS_OPENCV_SCRIBE_V1R18R_RECIPROCAL_MARGIN_20260904"
RECIPROCAL_MARGIN_MINIMUM = R18H.APPEARANCE_TIE_MAXIMUM_GAP
TOP_SCORE_TIE_ABSOLUTE_TOLERANCE = 1e-12
_RUNTIME_PATCH_LOCK = threading.Lock()


def _compact_positions(positions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    compact: list[dict[str, Any]] = []
    for position in positions:
        scores = {
            str(row["character"]): float(row["appearanceScore"])
            for row in position.get("allCandidates", [])
            if "character" in row and "appearanceScore" in row
        }
        compact.append({
            "position": int(position["position"]),
            "imageFirst": str(position["imageFirst"]),
            "arbitrationMode": str(position.get("glyphArbitration", {}).get("mode", "")),
            "appearanceScores": scores,
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


def evaluate_detector_input_structural(*args: Any, **kwargs: Any) -> dict[str, Any]:
    call_args = args
    call_kwargs = dict(kwargs)
    if args:
        call_args = (_FinalizeProxy(args[0]), *args[1:])
    else:
        call_kwargs["r11"] = _FinalizeProxy(call_kwargs["r11"])
    output = R18Q.evaluate_detector_input_structural(*call_args, **call_kwargs)
    output["glyphRanking"].update({
        "reciprocalMarginResolverAvailable": True,
        "reciprocalMarginMinimum": RECIPROCAL_MARGIN_MINIMUM,
        "checksumUsedForImageFirst": False,
    })
    return output


def compact_position_evidence(result: dict[str, Any]) -> list[dict[str, Any]]:
    """Return finalized compact evidence without reconstructing candidate ranks."""
    return list(result.get("positionEvidence", []))


def _coherent_positions(row: dict[str, Any], text: str) -> dict[int, dict[str, Any]] | None:
    if len(text) != 12:
        return None
    rows = row.get("positionEvidence", [])
    if not isinstance(rows, list) or len(rows) != 12:
        return None
    mapped: dict[int, dict[str, Any]] = {}
    for item in rows:
        if not isinstance(item, dict) or not isinstance(item.get("position"), int):
            return None
        position = int(item["position"])
        if position in mapped or position < 1 or position > 12:
            return None
        if str(item.get("imageFirst", "")) != text[position - 1]:
            return None
        mapped[position] = item
    return mapped if set(mapped) == set(range(1, 13)) else None


def _dominance(leader: dict[str, Any], rival: dict[str, Any]) -> dict[str, Any]:
    leader_string = str(leader["imageFirstString"])
    rival_string = str(rival["imageFirstString"])
    evidence: list[dict[str, Any]] = []
    leader_positions = _coherent_positions(leader, leader_string)
    rival_positions = _coherent_positions(rival, rival_string)
    passed = leader_positions is not None and rival_positions is not None and leader_string != rival_string
    leader_positions = leader_positions or {}
    rival_positions = rival_positions or {}
    for index, (leader_char, rival_char) in enumerate(zip(leader_string, rival_string), 1):
        if leader_char == rival_char:
            continue
        left = leader_positions.get(index, {})
        right = rival_positions.get(index, {})
        left_scores = left.get("appearanceScores", {})
        right_scores = right.get("appearanceScores", {})
        values = (
            left_scores.get(leader_char), left_scores.get(rival_char),
            right_scores.get(rival_char), right_scores.get(leader_char),
        )
        valid = (
            left.get("arbitrationMode") == "APPEARANCE"
            and right.get("arbitrationMode") == "APPEARANCE"
            and all(isinstance(value, (int, float)) and math.isfinite(float(value)) for value in values)
        )
        leader_margin = float(values[0]) - float(values[1]) if valid else None
        rival_margin = float(values[2]) - float(values[3]) if valid else None
        advantage = leader_margin - rival_margin if valid else None
        position_passed = bool(
            valid
            and leader_margin >= RECIPROCAL_MARGIN_MINIMUM
            and advantage >= RECIPROCAL_MARGIN_MINIMUM
        )
        passed = passed and position_passed
        evidence.append({
            "position": index,
            "leaderCharacter": leader_char,
            "rivalCharacter": rival_char,
            "leaderMargin": leader_margin,
            "rivalMargin": rival_margin,
            "leaderMarginAdvantage": advantage,
            "arbitrationModes": [left.get("arbitrationMode"), right.get("arbitrationMode")],
            "passed": position_passed,
        })
    return {"dominated": passed and bool(evidence), "positions": evidence}


def resolve_hypotheses(
    hypotheses: list[dict[str, Any]], any_structure_pass: bool,
    minimum_image_score: float = 0.60, ambiguity_score_delta: float = 0.03,
) -> dict[str, Any]:
    eligible = [
        row for row in hypotheses
        if isinstance(row.get("selectionScore"), (int, float))
        and math.isfinite(float(row["selectionScore"]))
    ]
    eligible.sort(key=lambda row: -float(row["selectionScore"]))
    leader = eligible[0] if eligible else None
    top_rows = [
        row for row in eligible
        if leader is not None and math.isclose(
            float(row["selectionScore"]), float(leader["selectionScore"]),
            rel_tol=0.0, abs_tol=TOP_SCORE_TIE_ABSOLUTE_TOLERANCE,
        )
    ]
    top_strings = sorted({str(row["imageFirstString"]) for row in top_rows})
    equal_top_string_tie = len(top_strings) > 1
    equal_top_hypothesis_tie = len(top_rows) > 1
    best = None if equal_top_hypothesis_tie else leader
    raw_rows = [
        row for row in eligible
        if leader is not None and bool(row.get("boundaryComplete"))
        and float(row["selectionScore"]) >= float(leader["selectionScore"]) - ambiguity_score_delta
    ]
    raw_close = sorted({str(row["imageFirstString"]) for row in raw_rows})
    decision_close = list(raw_close)
    comparisons: list[dict[str, Any]] = []
    if best is not None:
        for rival_string in raw_close:
            if rival_string == str(best["imageFirstString"]):
                continue
            rows = [row for row in raw_rows if str(row["imageFirstString"]) == rival_string]
            checks = [_dominance(best, row) for row in rows]
            comparisons.append({"rivalString": rival_string, "checks": checks})
            if checks and all(bool(check["dominated"]) for check in checks):
                decision_close.remove(rival_string)
    if leader is None or not any_structure_pass:
        state = "HOLD_SCRIBE_NOT_LOCALIZED"
    elif equal_top_string_tie:
        state = "HOLD_SCRIBE_MULTIPLE_EQUAL_TOP_IMAGE_FIRST_STRINGS"
    elif equal_top_hypothesis_tie:
        state = "HOLD_SCRIBE_MULTIPLE_EQUAL_TOP_IMAGE_FIRST_HYPOTHESES"
    elif not bool(leader.get("boundaryComplete")):
        state = "HOLD_SCRIBE_GRID_BOUNDARY_INCOMPLETE"
    elif float(leader["selectionScore"]) < minimum_image_score:
        state = "HOLD_SCRIBE_IMAGE_SCORE_BELOW_FROZEN_MINIMUM"
    elif _coherent_positions(leader, str(leader["imageFirstString"])) is None:
        state = "HOLD_SCRIBE_IMAGE_EVIDENCE_INCOMPLETE"
    elif len(decision_close) != 1:
        state = "HOLD_SCRIBE_MULTIPLE_CLOSE_IMAGE_FIRST_STRINGS"
    else:
        state = "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"
    return {
        "state": state, "best": best,
        "equalTopScoreStrings": top_strings if equal_top_hypothesis_tie else [],
        "equalTopHypothesisCount": len(top_rows) if equal_top_hypothesis_tie else 0,
        "topScoreTieAbsoluteTolerance": TOP_SCORE_TIE_ABSOLUTE_TOLERANCE,
        "rawCloseImageFirstStrings": raw_close,
        "closeImageFirstStrings": decision_close,
        "reciprocalMarginApplied": decision_close != raw_close,
        "reciprocalMarginMinimum": RECIPROCAL_MARGIN_MINIMUM,
        "comparisons": comparisons,
    }


def run_job(job_path: Path, result_path: Path) -> int:
    if not _RUNTIME_PATCH_LOCK.acquire(blocking=False):
        raise RuntimeError("Concurrent R18R provider invocation is not allowed.")
    try:
        original_rank = R18H.rank_with_run_structure
        original_evaluate = R18H.evaluate_detector_input_structural
        original_revision = R18H.REVISION
        R18H.rank_with_run_structure = rank_with_run_structure
        R18H.evaluate_detector_input_structural = evaluate_detector_input_structural
        R18H.REVISION = REVISION
        try:
            return R18H.run_job(job_path, result_path)
        finally:
            R18H.REVISION = original_revision
            R18H.evaluate_detector_input_structural = original_evaluate
            R18H.rank_with_run_structure = original_rank
    finally:
        _RUNTIME_PATCH_LOCK.release()


def main(argv: Iterable[str]) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
