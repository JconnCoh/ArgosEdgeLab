#!/usr/bin/env python3
"""R18P cohort runner with R18R image-only ambiguity resolution."""

from __future__ import annotations

import importlib.util
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
R18P = _load("argos_scribe_r18p_for_r18r", ROOT / "OPENCV_SCRIBE_R18P/Run-R18PReferenceIsolatedCorpus.py")
REVISION = "ARGOS_OPENCV_SCRIBE_R18R_REFERENCE_ISOLATED_CORPUS_20260904"
exclude_case_reference_lineage = R18P.exclude_case_reference_lineage
_RUNTIME_PATCH_LOCK = threading.Lock()


def _public(row: dict[str, Any] | None) -> dict[str, Any] | None:
    if row is None:
        return None
    return {key: value for key, value in row.items() if key != "positionEvidence"}


def validated_result_fields(provider: Any, result: dict[str, Any]) -> dict[str, Any]:
    required = (
        "imageFirstString", "proposedString", "checksumValid", "expectedCheckCharacters",
        "observedCheckCharacters", "checksumAlternatives", "selectionScore", "boundaryComplete",
    )
    missing = [field for field in required if field not in result]
    if missing:
        raise ValueError(f"OCR verification output is incomplete: {missing}")
    if type(result["checksumValid"]) is not bool:
        raise ValueError("OCR checksumValid must be a Boolean verification result.")
    if not isinstance(result["proposedString"], str) or not isinstance(result["checksumAlternatives"], list):
        raise ValueError("OCR checksum proposal evidence has an invalid type.")
    if result.get("glyphRanking", {}).get("checksumUsedForImageFirst") is not False:
        raise ValueError("OCR must declare checksumUsedForImageFirst=false.")
    image_first = result["imageFirstString"]
    evidence = provider.compact_position_evidence(result)
    if not isinstance(image_first, str) or provider._coherent_positions(
        {"positionEvidence": evidence}, image_first,
    ) is None:
        raise ValueError("OCR image-first position evidence is incomplete or incoherent.")
    return {
        "imageFirstString": image_first, "proposedString": result["proposedString"],
        "selectionScore": float(result["selectionScore"]),
        "boundaryComplete": bool(result["boundaryComplete"]),
        "checksumValid": result["checksumValid"], "positionEvidence": evidence,
    }


def resolve_hypotheses_fail_closed(
    provider: Any, hypotheses: list[dict[str, Any]], any_structure_pass: bool,
) -> dict[str, Any]:
    resolution = provider.resolve_hypotheses(
        hypotheses, any_structure_pass, R18P.MINIMUM_IMAGE_SCORE, R18P.AMBIGUITY_SCORE_DELTA,
    )
    error_count = sum(row.get("state") == "HOLD_OCR_EVALUATION_ERROR" for row in hypotheses)
    resolution["evaluationErrorCount"] = error_count
    if error_count and resolution["state"] == "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE":
        resolution["state"] = "HOLD_SCRIBE_EVALUATION_INCOMPLETE"
    return resolution


def evaluate_existing_crops(
    provider: Any, r11: Any, prototypes: list[Any], topology: list[Any], structure: list[Any],
    physical_identity: str, paths: tuple[Path, Path], expected_hashes: dict[str, str],
    supplemental_references: list[dict[str, Any]],
) -> dict[str, Any]:
    hypotheses: list[dict[str, Any]] = []
    structure_rows: list[dict[str, Any]] = []
    sources: list[dict[str, Any]] = []
    present_crops: list[tuple[str, Path, str, Any]] = []
    for channel, path in zip(("BF", "DF"), paths):
        if not path.is_file():
            sources.append({"channel": channel, "path": str(path), "state": "ABSENT"})
            continue
        source_sha = R18P.sha256_file(path)
        if source_sha != expected_hashes[channel].upper():
            raise ValueError(f"Configured {channel} crop SHA-256 mismatch.")
        gray = r11.decode_gray_exact(path)
        sources.append({
            "channel": channel, "path": str(path), "state": "PRESENT", "bytes": path.stat().st_size,
            "sha256": source_sha, "width": int(gray.shape[1]), "height": int(gray.shape[0]),
        })
        present_crops.append((channel, path, source_sha, gray))
        for polarity, view in (("DARK", gray), ("BRIGHT", 255 - gray)):
            structure_rows.append({
                "channel": channel, "polarity": polarity,
                **provider.R17D.R17C.measure_structure(view),
            })
    active_a, active_t, active_s, exclusion = R18P.exclude_case_reference_lineage(
        prototypes, topology, structure, physical_identity,
        {row[2] for row in present_crops}, supplemental_references,
    )
    any_structure_pass = any(bool(row.get("passed")) for row in structure_rows)
    qualified_crops = present_crops if any_structure_pass else []
    resolution: dict[str, Any] = resolve_hypotheses_fail_closed(
        provider, hypotheses, any_structure_pass,
    )
    for direction in ("FORWARD", "REVERSE_180"):
        for channel, path, source_sha, gray in qualified_crops:
            for polarity, view in (("DARK", gray), ("BRIGHT", 255 - gray)):
                oriented = view if direction == "FORWARD" else R18P.cv2.rotate(view, R18P.cv2.ROTATE_180)
                try:
                    result = provider.evaluate_detector_input_structural(
                        r11, oriented, active_a, active_t, active_s, "",
                    )
                except ValueError as error:
                    hypotheses.append({
                        "channel": channel, "polarity": polarity, "direction": direction,
                        "state": "HOLD_OCR_EVALUATION_ERROR", "detail": str(error),
                    })
                    continue
                fields = validated_result_fields(provider, result)
                hypotheses.append({
                    "channel": channel, "polarity": polarity, "direction": direction,
                    "sourcePath": str(path), "sourceSha256": source_sha,
                    **fields,
                    "grid": {key: int(result[key]) for key in ("x", "y", "cellWidth", "cellHeight")},
                    "checksumUsedForImageFirst": False,
                })
        resolution = resolve_hypotheses_fail_closed(provider, hypotheses, any_structure_pass)
        # Preserve the established existing-crop orientation contract: a
        # unique image-first result stops after FORWARD only when checksum
        # verification succeeds.  A checksum-invalid unique read must still
        # expand to REVERSE_180; checksum never chooses or rewrites a glyph.
        if direction == "FORWARD" and (
            resolution["state"] in (
                "HOLD_SCRIBE_MULTIPLE_CLOSE_IMAGE_FIRST_STRINGS",
                "HOLD_SCRIBE_MULTIPLE_EQUAL_TOP_IMAGE_FIRST_STRINGS",
                "HOLD_SCRIBE_MULTIPLE_EQUAL_TOP_IMAGE_FIRST_HYPOTHESES",
            )
            or (
                resolution["state"] == "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"
                and resolution["best"] is not None
                and resolution["best"].get("checksumValid") is True
            )
        ):
            break
    best = resolution["best"]
    return {
        "mode": "EXISTING_PROCESSOR_SCRIBE_CROP",
        "state": resolution["state"],
        "imageFirstString": "" if best is None else str(best["imageFirstString"]),
        "proposedString": "" if best is None else str(best.get("proposedString", "")),
        "bestHypothesis": _public(best),
        "rawCloseImageFirstStrings": resolution["rawCloseImageFirstStrings"],
        "closeImageFirstStrings": resolution["closeImageFirstStrings"],
        "ambiguityResolution": {
            "method": "RECIPROCAL_DISPUTED_POSITION_APPEARANCE_MARGIN",
            "applied": resolution["reciprocalMarginApplied"],
            "minimumMargin": resolution["reciprocalMarginMinimum"],
            "comparisons": resolution["comparisons"],
            "checksumUsed": False,
        },
        "evaluationErrorCount": resolution["evaluationErrorCount"],
        "hypotheses": [_public(row) for row in hypotheses],
        "structure": structure_rows, "sources": sources,
        "referenceExclusion": exclusion, "identityAccepted": False,
    }


def main(argv: Iterable[str]) -> int:
    if not _RUNTIME_PATCH_LOCK.acquire(blocking=False):
        raise RuntimeError("Concurrent R18R corpus invocation is not allowed.")
    try:
        original_evaluate = R18P.evaluate_existing_crops
        original_revision = R18P.REVISION
        R18P.evaluate_existing_crops = evaluate_existing_crops
        R18P.REVISION = REVISION
        try:
            return R18P.main(argv)
        finally:
            R18P.REVISION = original_revision
            R18P.evaluate_existing_crops = original_evaluate
    finally:
        _RUNTIME_PATCH_LOCK.release()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
