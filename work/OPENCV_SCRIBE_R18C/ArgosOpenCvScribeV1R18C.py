#!/usr/bin/env python3
"""R18C review-only scribe provider with post-grid image presence gating.

R17E remains the frozen verifier-only baseline. R18C replaces the pre-grid
texture gate, which could accept periodic wafer patterns and reject a clear
scribe, with an image-only floor on the selected twelve-cell OCR grid.
Checksum remains strictly downstream and cannot select or rewrite glyphs.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Iterable


REVISION = "ARGOS_OPENCV_SCRIBE_V1R18C_20260903"
MINIMUM_POST_GRID_IMAGE_SCORE = 0.60


def _load_r17e() -> Any:
    path = Path(__file__).resolve().parents[1] / "OPENCV_SCRIBE_R17E" / "ArgosOpenCvScribeV1R17E.py"
    spec = importlib.util.spec_from_file_location("argos_scribe_r17e_for_r18c", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load frozen R17E provider: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


R17E = _load_r17e()


def run_job(job_path: Path, result_path: Path) -> int:
    r11 = R17E.R17D.R17C.R17B._load_r11()
    job = r11.read_json(job_path)
    r11.validate_job_shape(job)
    roots = {str(row["relativePrefix"]): Path(str(row["path"])) for row in job["references"]["roots"]}
    manifest_path = Path(str(job["references"]["manifestPath"]))
    manifest_sha256 = str(job["references"]["manifestSha256"])
    prototypes, reference_evidence = r11.load_reference_prototypes(manifest_path, manifest_sha256, roots)
    supplemental_text = str(job["references"].get("supplementalManifestPath", ""))
    supplemental_sha256 = str(job["references"].get("supplementalManifestSha256", ""))
    if bool(supplemental_text) != bool(supplemental_sha256):
        raise ValueError("Supplemental reference path and SHA-256 must be supplied together.")
    supplemental_path = Path(supplemental_text) if supplemental_text else None
    if supplemental_path is not None:
        loader = R17E.R17D.R17C.R17B._load_supplement_loader()
        prototypes, reference_evidence = loader.combine_reference_prototypes(
            r11, prototypes, reference_evidence, supplemental_path, supplemental_sha256,
        )
    topology = R17E.R17D.load_topology_prototypes(
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

    def gated_evaluate(gray: Any, active: list[Any], excluded: str, frozen_grid: Any = None) -> dict[str, Any]:
        evaluated = R17E.R17D.evaluate_detector_input_hybrid(
            r11, gray, active, topology, excluded, frozen_grid,
        )
        evaluated = R17E.enforce_grid_verifier_only(evaluated)
        score = float(evaluated["selectionScore"])
        if score < MINIMUM_POST_GRID_IMAGE_SCORE:
            raise ValueError("HOLD_SCRIBE_NOT_LOCALIZED")
        evaluated["scribePresence"] = {
            "schema": "argos_opencv_scribe_post_grid_presence_gate_v1",
            "passed": True,
            "decision": "SCRIBE_PRESENT_FOR_OCR",
            "selectionScore": score,
            "minimumSelectionScore": MINIMUM_POST_GRID_IMAGE_SCORE,
            "checksumUsed": False,
        }
        return evaluated

    r11.evaluate_detector_input = gated_evaluate
    result = r11.analyze_images(job, bf, df, prototypes, reference_evidence, {
        "bf": bf_evidence,
        "df": df_evidence,
        "jobSha256": r11.sha256_file(job_path),
    })
    if not result["hypotheses"]:
        direct = {
            "schema": "argos_opencv_scribe_post_grid_presence_gate_v1",
            "passed": False,
            "decision": "HOLD_SCRIBE_NOT_LOCALIZED",
            "minimumSelectionScore": MINIMUM_POST_GRID_IMAGE_SCORE,
            "detail": "No channel, polarity, and direction view produced a twelve-cell image score at or above the frozen presence floor.",
            "checksumUsed": False,
            "legacyTextureDiagnostic": R17E.paired_presence_evidence(bf, df),
        }
        R17E.R17D.R17C.R17B._apply_not_localized_hold(result, direct)
    R17E.enforce_result_verifier_only(result)
    result["revision"] = REVISION
    result["provenance"]["engineRevision"] = REVISION
    result["provenance"]["preOcrStructureGate"] = False
    result["provenance"]["postGridImagePresenceGate"] = True
    result["provenance"]["postGridMinimumSelectionScore"] = MINIMUM_POST_GRID_IMAGE_SCORE
    result["provenance"]["checksumRole"] = "VERIFY_IMAGE_FIRST_ONLY"
    result["provenance"]["checksumMayRewriteGlyphs"] = False
    result["provenance"]["checksumMaySelectHypothesis"] = False
    r11.write_json_new(result_path, result)
    print(json.dumps({"state": result["state"], "resultPath": str(result_path), "candidateCount": len(result["candidates"])}))
    return 0


def main(argv: Iterable[str]) -> int:
    r11 = R17E.R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as error:
        print(json.dumps({"state": "HOLD_OPENCV_SCRIBE_PROVIDER_ERROR", "errorType": type(error).__name__, "detail": str(error)}), file=sys.stderr)
        raise
