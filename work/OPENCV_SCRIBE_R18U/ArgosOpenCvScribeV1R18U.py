#!/usr/bin/env python3
"""R18R plus generic dual-structure glyph consensus and full diagnostics.

The frozen appearance, topology, and ordered run-structure descriptors remain
unchanged.  A misleading appearance exemplar may be displaced only when the
independent topology and run-structure classifiers choose the same character
and pass one label-agnostic evidence envelope.  Checksum and known truth never
participate in glyph selection.
"""

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
R18R = _load("argos_scribe_r18r_for_r18u", ROOT / "OPENCV_SCRIBE_R18R/ArgosOpenCvScribeV1R18R.py")
R18Q = R18R.R18Q
R18H = R18R.R18H
R18F = R18R.R18F
R17E = R18R.R17E
R17D = R18R.R17D
MINIMUM_POST_GRID_IMAGE_SCORE = R18R.MINIMUM_POST_GRID_IMAGE_SCORE
load_run_structure_prototypes = R18R.load_run_structure_prototypes
_run_structure_context = R18R._run_structure_context

REVISION = "ARGOS_OPENCV_SCRIBE_V1R18U_DUAL_STRUCTURE_CONSENSUS_DIAGNOSTIC_20260905"
DUAL_STRUCTURE_MAXIMUM_APPEARANCE_DEFICIT = 0.40
DUAL_STRUCTURE_MINIMUM_TOPOLOGY_MARGIN = 0.03
DUAL_STRUCTURE_MINIMUM_RUN_MARGIN = 0.05
DUAL_STRUCTURE_MAXIMUM_RUN_DISTANCE = 1.00

_BASE_RANK = R18Q.rank_with_run_structure
_RUNTIME_PATCH_LOCK = threading.Lock()


def _finite(value: Any, default: float) -> float:
    return float(value) if isinstance(value, (int, float)) and math.isfinite(float(value)) else default


def rank_with_run_structure(*args: Any, **kwargs: Any) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Apply a label-agnostic topology/run-structure consensus override."""
    ranked, arbitration = _BASE_RANK(*args, **kwargs)
    ranked = list(ranked)
    arbitration = dict(arbitration)
    appearance_ranked = sorted(
        ranked, key=lambda row: (-float(row["appearanceScore"]), str(row["character"]))
    )
    leader = str(ranked[0]["character"]) if ranked else ""
    topology_first = str(arbitration.get("topologyFirst", ""))
    run_first = str(arbitration.get("runStructureFirst", ""))
    consensus = topology_first if topology_first and topology_first == run_first else ""
    by_character = {str(row["character"]): row for row in ranked}
    consensus_row = by_character.get(consensus)
    appearance_deficit = (
        float(appearance_ranked[0]["appearanceScore"])
        - float(consensus_row["appearanceScore"])
        if appearance_ranked and consensus_row is not None else math.inf
    )
    topology_margin = _finite(arbitration.get("topologyMargin"), -math.inf)
    run_margin = _finite(arbitration.get("runStructureMargin"), -math.inf)
    run_distance = _finite(arbitration.get("runStructureFirstDistance"), math.inf)

    predicates = {
        "baseAppearanceDecision": arbitration.get("mode") == "APPEARANCE",
        "topologyAndRunAgree": bool(consensus),
        "consensusDiffersFromLeader": bool(consensus) and consensus != leader,
        "consensusCandidatePresent": consensus_row is not None,
        "appearanceDeficitWithinMaximum": appearance_deficit <= DUAL_STRUCTURE_MAXIMUM_APPEARANCE_DEFICIT,
        "topologyMarginAtOrAboveMinimum": topology_margin >= DUAL_STRUCTURE_MINIMUM_TOPOLOGY_MARGIN,
        "runMarginAtOrAboveMinimum": run_margin >= DUAL_STRUCTURE_MINIMUM_RUN_MARGIN,
        "runDistanceWithinMaximum": run_distance <= DUAL_STRUCTURE_MAXIMUM_RUN_DISTANCE,
    }
    applied = all(predicates.values())
    if applied:
        ranked = sorted(
            ranked,
            key=lambda row: (
                0 if str(row["character"]) == consensus else 1,
                -float(row["appearanceScore"]),
                str(row["character"]),
            ),
        )

    arbitration.update({
        "mode": "DUAL_STRUCTURE_CONSENSUS_OVERRIDE" if applied else arbitration.get("mode"),
        "dualStructureAvailable": True,
        "dualStructureLabelSpecific": False,
        "dualStructureWinner": consensus,
        "dualStructureApplied": applied,
        "dualStructurePredicates": predicates,
        "dualStructureAppearanceDeficit": appearance_deficit,
        "dualStructureMaximumAppearanceDeficit": DUAL_STRUCTURE_MAXIMUM_APPEARANCE_DEFICIT,
        "dualStructureMinimumTopologyMargin": DUAL_STRUCTURE_MINIMUM_TOPOLOGY_MARGIN,
        "dualStructureMinimumRunMargin": DUAL_STRUCTURE_MINIMUM_RUN_MARGIN,
        "dualStructureMaximumRunDistance": DUAL_STRUCTURE_MAXIMUM_RUN_DISTANCE,
        "checksumUsed": False,
    })
    if len(args) >= 4:
        arbitration["observedRunStructureDescriptor"] = [float(value) for value in args[3].tolist()]
    return ranked, arbitration


class _DiagnosticFinalizeProxy:
    def __init__(self, base: Any):
        self._base = base

    def __getattr__(self, name: str) -> Any:
        return getattr(self._base, name)

    def finalize_grid(self, grid: dict[str, Any]) -> dict[str, Any]:
        positions: list[dict[str, Any]] = []
        for position in grid["positions"]:
            positions.append({
                "position": int(position["position"]),
                "imageFirst": str(position["imageFirst"]),
                "candidates": [dict(row) for row in position.get("allCandidates", [])],
                "glyphArbitration": dict(position.get("glyphArbitration", {})),
            })
        output = self._base.finalize_grid(grid)
        output["positionEvidence"] = positions
        return output


def evaluate_detector_input_structural(*args: Any, **kwargs: Any) -> dict[str, Any]:
    call_args = args
    call_kwargs = dict(kwargs)
    if args:
        call_args = (_DiagnosticFinalizeProxy(args[0]), *args[1:])
    else:
        call_kwargs["r11"] = _DiagnosticFinalizeProxy(call_kwargs["r11"])
    original_rank = R18Q.rank_with_run_structure
    R18Q.rank_with_run_structure = rank_with_run_structure
    try:
        output = R18Q.evaluate_detector_input_structural(*call_args, **call_kwargs)
    finally:
        R18Q.rank_with_run_structure = original_rank
    output["glyphRanking"].update({
        "method": "APPEARANCE_WITH_TOPOLOGY_RUN_STRUCTURE_DUAL_CONSENSUS",
        "dualStructureLabelSpecific": False,
        "dualStructureMaximumAppearanceDeficit": DUAL_STRUCTURE_MAXIMUM_APPEARANCE_DEFICIT,
        "dualStructureMinimumTopologyMargin": DUAL_STRUCTURE_MINIMUM_TOPOLOGY_MARGIN,
        "dualStructureMinimumRunMargin": DUAL_STRUCTURE_MINIMUM_RUN_MARGIN,
        "dualStructureMaximumRunDistance": DUAL_STRUCTURE_MAXIMUM_RUN_DISTANCE,
        "checksumUsedForImageFirst": False,
    })
    return output


def compact_position_evidence(result: dict[str, Any]) -> list[dict[str, Any]]:
    compact: list[dict[str, Any]] = []
    for position in result.get("positionEvidence", []):
        compact.append({
            "position": int(position["position"]),
            "imageFirst": str(position["imageFirst"]),
            "arbitrationMode": str(position.get("glyphArbitration", {}).get("mode", "")),
            "appearanceScores": {
                str(row["character"]): float(row["appearanceScore"])
                for row in position.get("candidates", [])
            },
        })
    return compact


def run_job(job_path: Path, result_path: Path) -> int:
    if not _RUNTIME_PATCH_LOCK.acquire(blocking=False):
        raise RuntimeError("Concurrent R18U provider invocation is not allowed.")
    original_rank = R18H.rank_with_run_structure
    original_evaluate = R18H.evaluate_detector_input_structural
    original_revision = R18H.REVISION
    try:
        R18H.rank_with_run_structure = rank_with_run_structure
        R18H.evaluate_detector_input_structural = evaluate_detector_input_structural
        R18H.REVISION = REVISION
        return R18H.run_job(job_path, result_path)
    finally:
        R18H.REVISION = original_revision
        R18H.evaluate_detector_input_structural = original_evaluate
        R18H.rank_with_run_structure = original_rank
        _RUNTIME_PATCH_LOCK.release()


def main(argv: Iterable[str]) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
