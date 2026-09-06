#!/usr/bin/env python3
"""R18ZR plus generic reciprocal topology/run-structure consensus."""

from __future__ import annotations

import hashlib
import importlib.util
import sys
from pathlib import Path
from typing import Any, Iterable


EXPECTED_R18ZR_SHA256 = "85E87B6CE50EB4D673EA99507AE457211135BDBA2342D12FE675939C6EE76921"
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18ZS_DUAL_STRUCTURE_CONSENSUS_DIAGNOSTIC_20260906"


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
R18ZR_PATH = ROOT / "OPENCV_SCRIBE_R18ZR/ArgosOpenCvScribeV1R18ZR.py"
if _sha256_file(R18ZR_PATH) != EXPECTED_R18ZR_SHA256:
    raise ValueError("Frozen R18ZR composition provider SHA-256 mismatch.")
R18ZR = _load("argos_scribe_r18zr_for_r18zs", R18ZR_PATH)
R18Z = R18ZR.R18Z
R18ZV = R18ZR.R18ZV
R18Q = R18ZR.R18Q
R18R = R18ZR.R18R
R18H = R18ZR.R18H
R17E = R18ZR.R17E
R17D = R18ZR.R17D
_RUNTIME_PATCH_LOCK = R18ZR._RUNTIME_PATCH_LOCK


def rank_with_dual_structure_consensus(
    *args: Any, **kwargs: Any
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    ranked, arbitration = R18Q.rank_with_run_structure(*args, **kwargs)
    appearance_ranked = sorted(
        ranked,
        key=lambda row: (-float(row["appearanceScore"]), str(row["character"])),
    )
    appearance_first = str(appearance_ranked[0]["character"])
    topology_first = str(arbitration["topologyFirst"])
    run_first = str(arbitration["runStructureFirst"])
    consensus_row = next(
        row for row in ranked if str(row["character"]) == run_first
    )
    appearance_deficit = (
        float(appearance_ranked[0]["appearanceScore"])
        - float(consensus_row["appearanceScore"])
    )
    appearance_rank = next(
        index for index, row in enumerate(appearance_ranked, 1)
        if str(row["character"]) == run_first
    )
    applied = (
        arbitration.get("mode") == "APPEARANCE"
        and topology_first == run_first
        and run_first != appearance_first
        and float(appearance_ranked[0]["appearanceScore"])
        < R18Q.STRONG_STRUCTURE_MAXIMUM_APPEARANCE_LEADER_SCORE
        and float(arbitration["topologyMargin"])
        >= R18Q.TOPOLOGY_OVERRIDE_MINIMUM_MARGIN
        and float(arbitration["runStructureMargin"])
        >= R18R.RECIPROCAL_MARGIN_MINIMUM
        and appearance_deficit
        <= R18Q.STRONG_STRUCTURE_MAXIMUM_APPEARANCE_DEFICIT
    )
    if applied:
        ranked = sorted(
            ranked,
            key=lambda row: (
                0 if str(row["character"]) == run_first else 1,
                -float(row["appearanceScore"]),
                str(row["character"]),
            ),
        )
    arbitration = dict(arbitration)
    arbitration.update({
        "mode": (
            "TOPOLOGY_RUN_STRUCTURE_RECIPROCAL_CONSENSUS_OVERRIDE"
            if applied else arbitration["mode"]
        ),
        "runStructureApplied": bool(arbitration.get("runStructureApplied")) or applied,
        "dualStructureApplied": applied,
        "dualStructureLabel": run_first if topology_first == run_first else "",
        "dualStructureAppearanceDeficit": appearance_deficit,
        "dualStructureAppearanceRank": appearance_rank,
        "dualStructureTopologyMinimumMargin": R18Q.TOPOLOGY_OVERRIDE_MINIMUM_MARGIN,
        "dualStructureRunMinimumMargin": R18R.RECIPROCAL_MARGIN_MINIMUM,
        "dualStructureUsesNewThreshold": False,
    })
    return ranked, arbitration


def run_job(job_path: Path, result_path: Path) -> int:
    if not _RUNTIME_PATCH_LOCK.acquire(blocking=False):
        raise RuntimeError("Concurrent R18ZS provider invocation is not allowed.")
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
            output["glyphRanking"].update({
                "method": "R18ZS_DUAL_STRUCTURE_THEN_R18Z_EXACT_LINEAGE_ENVELOPE",
                "strongStructureProviderRevision": R18Q.REVISION,
                "reciprocalResolverRevision": R18R.REVISION,
                "dualStructureConsensus": True,
                "dualStructureTopologyMinimumMargin": R18Q.TOPOLOGY_OVERRIDE_MINIMUM_MARGIN,
                "dualStructureRunMinimumMargin": R18R.RECIPROCAL_MARGIN_MINIMUM,
                "dualStructureMaximumAppearanceDeficit": R18Q.STRONG_STRUCTURE_MAXIMUM_APPEARANCE_DEFICIT,
                "dualStructureMaximumAppearanceLeaderScore": R18Q.STRONG_STRUCTURE_MAXIMUM_APPEARANCE_LEADER_SCORE,
                "dualStructureUsesNewThreshold": False,
                "checksumUsedForImageFirst": False,
            })
            return output

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
                "strongStructureProviderSha256": R18ZR.EXPECTED["r18q"],
                "reciprocalResolverProviderSha256": R18ZR.EXPECTED["r18r"],
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
