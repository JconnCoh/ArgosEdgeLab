#!/usr/bin/env python3
"""R18H plus a label-agnostic strong run-structure override.

The existing near-tie rule remains unchanged.  When appearance is not tied,
an independently strong run-structure consensus may still select its winner,
provided that winner is close to its class consensus, separated from the next
class, and remains within a bounded appearance deficit.  The selected score is
never increased, and checksum remains verify-only.
"""

from __future__ import annotations

import importlib.util
import sys
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
R18H = _load("argos_scribe_r18h_for_r18q", ROOT / "OPENCV_SCRIBE_R18H/ArgosOpenCvScribeV1R18H.py")
R18F = R18H.R18F
R17E = R18H.R17E
R17D = R18H.R17D
MINIMUM_POST_GRID_IMAGE_SCORE = R18H.MINIMUM_POST_GRID_IMAGE_SCORE
TOPOLOGY_OVERRIDE_MINIMUM_MARGIN = R18H.TOPOLOGY_OVERRIDE_MINIMUM_MARGIN
RunStructurePrototype = R18H.RunStructurePrototype
describe_run_structure_exact = R18H.describe_run_structure_exact
load_run_structure_prototypes = R18H.load_run_structure_prototypes
_run_structure_context = R18H._run_structure_context

REVISION = "ARGOS_OPENCV_SCRIBE_V1R18Q_STRONG_STRUCTURE_GENERALIZATION_20260904"
STRONG_STRUCTURE_MAXIMUM_DISTANCE = 0.50
STRONG_STRUCTURE_MINIMUM_MARGIN = 0.25
STRONG_STRUCTURE_MAXIMUM_APPEARANCE_DEFICIT = 0.22
STRONG_STRUCTURE_MAXIMUM_APPEARANCE_LEADER_SCORE = R17D.TOPOLOGY_OVERRIDE_MAXIMUM_APPEARANCE_SCORE

_BASE_RANK = R18H.rank_with_run_structure
_BASE_EVALUATE = R18H.evaluate_detector_input_structural


def rank_with_run_structure(*args: Any, **kwargs: Any) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    ranked, arbitration = _BASE_RANK(*args, **kwargs)
    appearance_ranked = sorted(
        ranked, key=lambda row: (-float(row["appearanceScore"]), str(row["character"]))
    )
    structure_first = str(arbitration["runStructureFirst"])
    structure_row = next(row for row in ranked if str(row["character"]) == structure_first)
    appearance_deficit = (
        float(appearance_ranked[0]["appearanceScore"])
        - float(structure_row["appearanceScore"])
    )
    appearance_rank = next(
        index for index, row in enumerate(appearance_ranked, 1)
        if str(row["character"]) == structure_first
    )
    strong_applied = (
        arbitration["mode"] == "APPEARANCE"
        and structure_first != str(appearance_ranked[0]["character"])
        and float(appearance_ranked[0]["appearanceScore"]) < STRONG_STRUCTURE_MAXIMUM_APPEARANCE_LEADER_SCORE
        and float(arbitration["runStructureFirstDistance"]) <= STRONG_STRUCTURE_MAXIMUM_DISTANCE
        and float(arbitration["runStructureMargin"]) >= STRONG_STRUCTURE_MINIMUM_MARGIN
        and appearance_deficit <= STRONG_STRUCTURE_MAXIMUM_APPEARANCE_DEFICIT
    )
    if strong_applied:
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
        "mode": "RUN_STRUCTURE_STRONG_CONSENSUS_OVERRIDE" if strong_applied else arbitration["mode"],
        "runStructureApplied": bool(arbitration.get("runStructureApplied")) or strong_applied,
        "strongStructureApplied": strong_applied,
        "strongStructureAppearanceDeficit": appearance_deficit,
        "strongStructureAppearanceRank": appearance_rank,
    })
    return ranked, arbitration


def _evaluate_with_active_rank(*args: Any, **kwargs: Any) -> dict[str, Any]:
    output = _BASE_EVALUATE(*args, **kwargs)
    output["glyphRanking"].update({
        "method": "APPEARANCE_WITH_BOUNDED_TOPOLOGY_AND_TWO_TIER_RUN_STRUCTURE_CONSENSUS",
        "strongStructureMaximumDistance": STRONG_STRUCTURE_MAXIMUM_DISTANCE,
        "strongStructureMinimumMargin": STRONG_STRUCTURE_MINIMUM_MARGIN,
        "strongStructureMaximumAppearanceDeficit": STRONG_STRUCTURE_MAXIMUM_APPEARANCE_DEFICIT,
        "strongStructureMaximumAppearanceLeaderScore": STRONG_STRUCTURE_MAXIMUM_APPEARANCE_LEADER_SCORE,
        "strongStructureLabelSpecific": False,
        "checksumUsedForImageFirst": False,
    })
    return output


def evaluate_detector_input_structural(*args: Any, **kwargs: Any) -> dict[str, Any]:
    original_rank = R18H.rank_with_run_structure
    R18H.rank_with_run_structure = rank_with_run_structure
    try:
        return _evaluate_with_active_rank(*args, **kwargs)
    finally:
        R18H.rank_with_run_structure = original_rank


def run_job(job_path: Path, result_path: Path) -> int:
    original_rank = R18H.rank_with_run_structure
    original_evaluate = R18H.evaluate_detector_input_structural
    original_revision = R18H.REVISION
    R18H.rank_with_run_structure = rank_with_run_structure
    R18H.evaluate_detector_input_structural = _evaluate_with_active_rank
    R18H.REVISION = REVISION
    try:
        return R18H.run_job(job_path, result_path)
    finally:
        R18H.REVISION = original_revision
        R18H.evaluate_detector_input_structural = original_evaluate
        R18H.rank_with_run_structure = original_rank


def main(argv: Iterable[str]) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
