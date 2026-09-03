#!/usr/bin/env python3
"""R17E review-only scribe provider with verifier-only M12 semantics.

R17D supplies presence, grid selection, appearance ranking, and bounded glyph
topology arbitration.  R17E makes the canonical M12 checksum strictly
downstream: it verifies an image-first string but never rewrites a glyph,
selects another hypothesis, or emits a corrected proposal.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Iterable

import numpy as np


REVISION = "ARGOS_OPENCV_SCRIBE_V1R17E_20260903"
INVALID_CHECKSUM_HOLD = "SCRIBE_IMAGE_FIRST_CHECKSUM_HOLD"
AUTO_IDENTITY_MIN_SELECTION_SCORE = 0.60
LEGACY_CHECKSUM_HOLDS = {
    "SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID",
    "SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED",
    "SCRIBE_M12_CHECKSUM_FAILED",
}


def _load_r17d() -> Any:
    path = Path(__file__).resolve().parents[1] / "OPENCV_SCRIBE_R17D" / "ArgosOpenCvScribeV1R17D.py"
    spec = importlib.util.spec_from_file_location("argos_scribe_r17d_for_r17e", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load R17D provider: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


R17D = _load_r17d()


def enforce_grid_verifier_only(evaluated: dict[str, Any]) -> dict[str, Any]:
    output = dict(evaluated)
    output["checksumAlternatives"] = [
        {**dict(row), "diagnosticOnly": True}
        for row in evaluated.get("checksumAlternatives", [])
    ]
    output["checksumRole"] = "VERIFY_IMAGE_FIRST_ONLY"
    output["checksumUsedForGlyphSelection"] = False
    output["proposedString"] = (
        str(output.get("imageFirstString", ""))
        if bool(output.get("checksumValid")) else ""
    )
    return output


def _candidate_rows(
    hypotheses: list[dict[str, Any]],
    minimum_selection_score: float | None,
) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for row in hypotheses:
        if (
            bool(row.get("boundaryComplete"))
            and bool(row.get("checksumValid"))
            and (
                minimum_selection_score is None
                or float(row.get("selectionScore", -1.0)) >= minimum_selection_score
            )
        ):
            grouped.setdefault(str(row.get("imageFirstString", "")), []).append(row)
    candidates = [
        {
            "string": text,
            "channels": sorted({str(item["channel"]) for item in rows}),
            "polarities": sorted({str(item["polarity"]) for item in rows}),
            "directions": sorted({str(item["direction"]) for item in rows}),
            "regions": sorted({str(item["regionId"]) for item in rows}),
            "maximumSelectionScore": max(float(item["selectionScore"]) for item in rows),
            "checksumRole": "VERIFIED_IMAGE_FIRST_DIAGNOSTIC",
        }
        for text, rows in grouped.items() if text
    ]
    candidates.sort(key=lambda row: (-float(row["maximumSelectionScore"]), str(row["string"])))
    return candidates


def enforce_result_verifier_only(result: dict[str, Any]) -> None:
    hypotheses = list(result.get("hypotheses", []))
    for index, row in enumerate(hypotheses):
        hypotheses[index] = enforce_grid_verifier_only(row)
    result["hypotheses"] = hypotheses
    best = hypotheses[0] if hypotheses else None
    automatic = bool(result.get("localization", {}).get("autoLocalizedDevelopmentMode"))
    verified = _candidate_rows(
        hypotheses,
        AUTO_IDENTITY_MIN_SELECTION_SCORE if automatic else None,
    )
    result["checksumVerifiedHypotheses"] = verified
    result["proposedString"] = ""
    result["candidates"] = []

    if best is None:
        result["checksumState"] = "NOT_EVALUATED"
    elif not bool(best.get("boundaryComplete")):
        result["checksumState"] = "NOT_EVALUATED_SEGMENTATION_INCOMPLETE"
    elif not bool(best.get("checksumValid")):
        result["state"] = INVALID_CHECKSUM_HOLD
        result["checksumState"] = "SCRIBE_M12_IMAGE_FIRST_CHECKSUM_INVALID_HOLD"
        result.setdefault("holds", []).append({
            "code": INVALID_CHECKSUM_HOLD,
            "detail": "The highest-ranked image-first string failed M12 verification; checksum alternatives are diagnostic only and no proposal was emitted.",
        })
    else:
        result["checksumState"] = "SCRIBE_M12_IMAGE_FIRST_CHECKSUM_VALID_REVIEW_ONLY"
        matching = [row for row in verified if str(row["string"]) == str(best["imageFirstString"])]
        if len(verified) > 1:
            result["state"] = "SCRIBE_M12_AMBIGUOUS_MULTIPLE_IMAGE_FIRST_VALID"
            result.setdefault("holds", []).append({
                "code": "SCRIBE_M12_AMBIGUOUS_MULTIPLE_IMAGE_FIRST_VALID",
                "detail": "Independent image-first hypotheses produced multiple different checksum-valid strings; no proposal was emitted.",
            })
            result["candidates"] = verified
        elif matching:
            result["proposedString"] = str(best["imageFirstString"])
            result["candidates"] = matching

    deduplicated = []
    seen: set[str] = set()
    for hold in result.get("holds", []):
        code = str(hold.get("code", ""))
        if code and code not in LEGACY_CHECKSUM_HOLDS and code not in seen:
            seen.add(code)
            deduplicated.append(hold)
    result["holds"] = deduplicated
    result["revision"] = REVISION
    result.setdefault("provenance", {})["engineRevision"] = REVISION
    result["provenance"]["checksumRole"] = "VERIFY_IMAGE_FIRST_ONLY"
    result["provenance"]["checksumMayRewriteGlyphs"] = False
    result["provenance"]["checksumMaySelectHypothesis"] = False


def paired_presence_evidence(bf: np.ndarray, df: np.ndarray) -> dict[str, Any]:
    return R17D.paired_presence_evidence(bf, df)


def run_job(job_path: Path, result_path: Path) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    job = r11.read_json(job_path)
    r11.validate_job_shape(job)
    roots = {str(row["relativePrefix"]): Path(str(row["path"])) for row in job["references"]["roots"]}
    manifest_path = Path(str(job["references"]["manifestPath"]))
    manifest_sha256 = str(job["references"]["manifestSha256"])
    prototypes, reference_evidence = r11.load_reference_prototypes(
        manifest_path, manifest_sha256, roots,
    )
    supplemental_text = str(job["references"].get("supplementalManifestPath", ""))
    supplemental_sha256 = str(job["references"].get("supplementalManifestSha256", ""))
    if bool(supplemental_text) != bool(supplemental_sha256):
        raise ValueError("Supplemental reference path and SHA-256 must be supplied together.")
    supplemental_path = Path(supplemental_text) if supplemental_text else None
    if supplemental_path is not None:
        loader = R17D.R17C.R17B._load_supplement_loader()
        prototypes, reference_evidence = loader.combine_reference_prototypes(
            r11, prototypes, reference_evidence, supplemental_path, supplemental_sha256,
        )
    topology = R17D.load_topology_prototypes(
        r11, manifest_path, manifest_sha256, roots, supplemental_path, supplemental_sha256,
    )
    if [(row.label, row.physical_identity) for row in prototypes] != [
        (row.label, row.physical_identity) for row in topology
    ]:
        raise ValueError("Appearance and topology reference banks are not aligned.")

    bf, bf_evidence = r11.decode_source(job["inputs"]["bf"])
    df, df_evidence = r11.decode_source(job["inputs"]["df"])
    if str(job.get("inputMode", "POSE_BOUND_WHOLE_IMAGE")) != "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT" and bf.shape != df.shape:
        raise ValueError("BF and DF dimensions differ.")
    cache: dict[str, dict[str, Any]] = {}

    def gated_evaluate(gray: np.ndarray, active: list[Any], excluded: str, frozen_grid: Any = None) -> dict[str, Any]:
        key = hashlib.sha256(gray.tobytes()).hexdigest()
        evidence = cache.setdefault(key, R17D.R17C.measure_structure(gray))
        if not bool(evidence["passed"]):
            raise ValueError("HOLD_SCRIBE_NOT_LOCALIZED")
        evaluated = R17D.evaluate_detector_input_hybrid(
            r11, gray, active, topology, excluded, frozen_grid,
        )
        evaluated = enforce_grid_verifier_only(evaluated)
        evaluated["scribePresence"] = evidence
        return evaluated

    r11.evaluate_detector_input = gated_evaluate
    result = r11.analyze_images(job, bf, df, prototypes, reference_evidence, {
        "bf": bf_evidence,
        "df": df_evidence,
        "jobSha256": r11.sha256_file(job_path),
    })
    if not result["hypotheses"]:
        direct = paired_presence_evidence(bf, df) if str(job.get("inputMode")) == "QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT" else {
            "schema": R17D.R17C.R17B.SCHEMA,
            "passed": False,
            "decision": "HOLD_SCRIBE_NOT_LOCALIZED",
            "detail": "All image-localized candidate patches failed the pre-OCR structure gate.",
        }
        R17D.R17C.R17B.REVISION = REVISION
        R17D.R17C.R17B._apply_not_localized_hold(result, direct)
    enforce_result_verifier_only(result)
    result["provenance"]["preOcrStructureGate"] = True
    result["provenance"]["topologyAwareGlyphRanking"] = True
    r11.write_json_new(result_path, result)
    print(json.dumps({"state": result["state"], "resultPath": str(result_path), "candidateCount": len(result["candidates"])}))
    return 0


def main(argv: Iterable[str]) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as error:
        print(json.dumps({"state": "HOLD_OPENCV_SCRIBE_PROVIDER_ERROR", "errorType": type(error).__name__, "detail": str(error)}), file=sys.stderr)
        raise
