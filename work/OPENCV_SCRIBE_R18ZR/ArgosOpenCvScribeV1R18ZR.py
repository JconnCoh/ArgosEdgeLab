#!/usr/bin/env python3
"""R18Z envelopes composed with frozen R18Q/R18R generic OCR science."""

from __future__ import annotations

import hashlib
import importlib.util
import sys
from pathlib import Path
from typing import Any, Iterable


EXPECTED = {
    "r18z": "54BB0152420B5F197C1F0B353AEDF021185BBBA2EBD415B05320CFF92DD02DA2",
    "r18zv": "BA85E9594562334C54A7CC7A0D7B2DDA3868714D8A87A223E2B2A04F589FDC0B",
    "r18q": "AB20CFB25D223D40D31237118436446018AE213F800ECF1652213EB942C40DC1",
    "r18r": "51C95B3279D253EF717F663F3860CC6B4CA38517706E08E9FE2302BE02CD2BB5",
}
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18ZR_QR_EXACT_LINEAGE_COMPOSITION_DIAGNOSTIC_20260906"


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
PATHS = {
    "r18z": ROOT / "OPENCV_SCRIBE_R18Z/ArgosOpenCvScribeV1R18Z.py",
    "r18zv": ROOT / "OPENCV_SCRIBE_R18Z/ArgosOpenCvScribeV1R18ZV.py",
    "r18q": ROOT / "OPENCV_SCRIBE_R18Q/ArgosOpenCvScribeV1R18Q.py",
    "r18r": ROOT / "OPENCV_SCRIBE_R18R/ArgosOpenCvScribeV1R18R.py",
}
for _name, _path in PATHS.items():
    if _sha256_file(_path) != EXPECTED[_name]:
        raise ValueError(f"Frozen {_name.upper()} provider SHA-256 mismatch.")

R18Z = _load("argos_scribe_r18z_for_r18zr", PATHS["r18z"])
R18Q = _load("argos_scribe_r18q_for_r18zr", PATHS["r18q"])
R18R = _load("argos_scribe_r18r_for_r18zr", PATHS["r18r"])
R18ZV = R18Z.R18ZV
R18H = R18Z.R18H
R17E = R18Z.R17E
R17D = R18Z.R17D
_RUNTIME_PATCH_LOCK = R18Z._RUNTIME_PATCH_LOCK

if R18H is not R18ZV.R18H or R17E is not R18ZV.R17E:
    raise RuntimeError("R18ZR requires shared R18Z nested provider bindings.")


def _deduplicate_holds(result: dict[str, Any]) -> None:
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    for row in result.get("holds", []):
        code = str(row.get("code", ""))
        if code and code not in seen:
            seen.add(code)
            rows.append(row)
    result["holds"] = rows


def _bounded_resolution(resolution: dict[str, Any]) -> dict[str, Any]:
    return {
        key: value
        for key, value in resolution.items()
        if key != "best"
    }


def _selected_summary(row: dict[str, Any] | None) -> dict[str, Any] | None:
    if row is None:
        return None
    envelope = row.get("ocrEnvelope", {})
    return {
        "channel": row.get("channel"),
        "polarity": row.get("polarity"),
        "direction": row.get("direction"),
        "imageFirstString": row.get("imageFirstString"),
        "selectionScore": row.get("selectionScore"),
        "boundaryComplete": row.get("boundaryComplete"),
        "checksumValid": row.get("checksumValid"),
        "envelopePassed": envelope.get("passed"),
        "envelopeDecision": envelope.get("decision"),
        "heldPositions": envelope.get("heldPositions", []),
        "correctedPositions": envelope.get("correctedPositions", []),
    }


def run_job(job_path: Path, result_path: Path) -> int:
    if not _RUNTIME_PATCH_LOCK.acquire(blocking=False):
        raise RuntimeError("Concurrent R18ZR provider invocation is not allowed.")
    old_rank = R18H.rank_with_run_structure
    old_evaluate = R18ZV.evaluate_detector_input_enveloped
    old_enforce = R17E.enforce_result_verifier_only
    old_apply = R18ZV._apply_result_envelope_state
    try:
        r11 = R17D.R17C.R17B._load_r11()
        job = r11.read_json(job_path)
        references = job.get("references", {})
        crosswalk_path = Path(str(references.get("exactScribeLineageCrosswalkPath", "")))
        crosswalk_sha256 = str(
            references.get("exactScribeLineageCrosswalkSha256", "")
        ).upper()
        if not crosswalk_path.is_file():
            raise ValueError("R18ZR exact-scribe lineage crosswalk is missing.")
        mapping, mapping_fingerprint = R18Z.load_lineage_mapping(
            crosswalk_path, crosswalk_sha256
        )

        def integrated_evaluate(
            active_r11: Any,
            gray: Any,
            prototypes: list[Any],
            topology_prototypes: list[Any],
            run_structure_prototypes: list[Any],
            excluded_identity: str,
            frozen_grid: tuple[int, int, int, int] | None = None,
        ) -> dict[str, Any]:
            output = R18Z.evaluate_detector_input_exact_lineage(
                R18R._FinalizeProxy(active_r11),
                gray,
                prototypes,
                topology_prototypes,
                run_structure_prototypes,
                excluded_identity,
                mapping,
                frozen_grid,
            )
            output["glyphRanking"].update({
                "method": "R18Q_STRONG_STRUCTURE_THEN_R18Z_EXACT_LINEAGE_ENVELOPE",
                "strongStructureProviderRevision": R18Q.REVISION,
                "strongStructureMaximumDistance": R18Q.STRONG_STRUCTURE_MAXIMUM_DISTANCE,
                "strongStructureMinimumMargin": R18Q.STRONG_STRUCTURE_MINIMUM_MARGIN,
                "strongStructureMaximumAppearanceDeficit": R18Q.STRONG_STRUCTURE_MAXIMUM_APPEARANCE_DEFICIT,
                "strongStructureMaximumAppearanceLeaderScore": R18Q.STRONG_STRUCTURE_MAXIMUM_APPEARANCE_LEADER_SCORE,
                "reciprocalResolverRevision": R18R.REVISION,
                "reciprocalMarginMinimum": R18R.RECIPROCAL_MARGIN_MINIMUM,
                "componentOrder": [
                    "R18Q_GENERIC_STRONG_STRUCTURE_RANK",
                    "R18Z_EXACT_LINEAGE_GLYPH_ENVELOPE",
                    "R18R_RECIPROCAL_HYPOTHESIS_RESOLUTION",
                ],
                "checksumUsedForImageFirst": False,
            })
            return output

        def resolve_then_enforce(result: dict[str, Any]) -> None:
            hypotheses = list(result.get("hypotheses", []))
            any_structure_pass = any(
                bool(row.get("scribePresence", {}).get("passed"))
                for row in hypotheses
            )
            resolution = R18R.resolve_hypotheses(
                hypotheses,
                any_structure_pass,
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
            result["ambiguityResolution"] = _bounded_resolution(resolution)
            result["selectedHypothesis"] = _selected_summary(
                result.get("hypotheses", [None])[0]
                if result.get("hypotheses") else None
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
                _deduplicate_holds(result)

        def apply_result(result: dict[str, Any]) -> None:
            old_apply(result)
            result.setdefault("provenance", {}).update({
                "engineRevision": REVISION,
                "strongStructureProviderSha256": EXPECTED["r18q"],
                "reciprocalResolverProviderSha256": EXPECTED["r18r"],
                "referencePhysicalLineageKey": "EXACT_HUMAN_CONFIRMED_12_CHARACTER_SCRIBE",
                "exactScribeLineageCrosswalkSha256": crosswalk_sha256,
                "exactScribeLineageMappingFingerprint": mapping_fingerprint,
                "runtimeExpectedTruthUsedForGlyphSelection": False,
                "checksumMayRewriteGlyphs": False,
                "checksumMaySelectHypothesis": False,
            })
            result["revision"] = REVISION
            resolution = result.get("ambiguityResolution", {})
            if resolution.get("state") != "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE":
                state = str(resolution.get("state", "HOLD_SCRIBE_RESOLUTION_FAILED"))
                result["state"] = state
                result["eligibleIdentity"] = False
                result["proposedString"] = ""
                result["candidates"] = []
                _deduplicate_holds(result)

        R18H.rank_with_run_structure = R18Q.rank_with_run_structure
        R18ZV.evaluate_detector_input_enveloped = integrated_evaluate
        R17E.enforce_result_verifier_only = resolve_then_enforce
        R18ZV._apply_result_envelope_state = apply_result
        return R18ZV._run_job_locked(job_path, result_path)
    finally:
        R18ZV._apply_result_envelope_state = old_apply
        R17E.enforce_result_verifier_only = old_enforce
        R18ZV.evaluate_detector_input_enveloped = old_evaluate
        R18H.rank_with_run_structure = old_rank
        _RUNTIME_PATCH_LOCK.release()


def main(argv: Iterable[str]) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
