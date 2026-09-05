#!/usr/bin/env python3
"""R18V envelope science adapted to the hash-locked 475-reference R18Z bank."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import threading
from pathlib import Path
from typing import Any, Iterable

import numpy as np


EXPECTED_R18V_PROVIDER_SHA256 = "6DF8F25F4D56C8DBB0097C411053CE3DCD38D48A97E1DF88D18A5EA82A6E0D15"
EXPECTED_BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
EXPECTED_SUPPLEMENTAL_MANIFEST_SHA256 = "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD"
EXPECTED_SUPPLEMENT_LOADER_SHA256 = "6BDAE5B20C199D2E36AC1F88F69CB733ECE2F214D02ADFBB8763A08306136BB0"
EXPECTED_R18Z_LOO_GATE_SHA256 = "D8F0C0923BFDD6B82C4B0B0C57142825C08C0DB3F5395210A5DD7FE2E6E8DAD8"
EXPECTED_R18Z_LOO_TEST_SHA256 = "8538FC44915CF6E978C1AAED3FB14761A8C1896EC9802A1CBE372F718F25A788"
EXPECTED_COMBINED_REFERENCE_COUNT = 475
REVISION = "ARGOS_OPENCV_SCRIBE_V1R18Z_475_REFERENCE_LINEAGE_ENVELOPES_DIAGNOSTIC_20260905"


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
R18V_PATH = ROOT / "OPENCV_SCRIBE_R18V/ArgosOpenCvScribeV1R18V.py"
LOADER_PATH = Path(__file__).with_name("ArgosOpenCvScribeSupplementLoaderR18Z.py")
if _sha256_file(R18V_PATH) != EXPECTED_R18V_PROVIDER_SHA256:
    raise ValueError("Frozen R18V provider SHA-256 mismatch.")
if _sha256_file(LOADER_PATH) != EXPECTED_SUPPLEMENT_LOADER_SHA256:
    raise ValueError("R18Z supplement loader SHA-256 mismatch.")
R18V = _load("argos_scribe_r18v_for_r18zv", R18V_PATH)
R18Z_LOADER = _load("argos_scribe_r18z_supplement_loader", LOADER_PATH)
R18H = R18V.R18H
R18F = R18V.R18F
R17E = R18V.R17E
R17D = R18V.R17D
MINIMUM_POST_GRID_IMAGE_SCORE = R18V.MINIMUM_POST_GRID_IMAGE_SCORE
MINIMUM_ENFORCEABLE_LINEAGES = R18V.MINIMUM_ENFORCEABLE_LINEAGES
BODY_LABELS = R18V.BODY_LABELS
build_glyph_envelope_bank = R18V.build_glyph_envelope_bank
coverage_evidence = R18V.coverage_evidence
assess_glyph_envelope = R18V.assess_glyph_envelope
_RUNTIME_PATCH_LOCK = threading.Lock()


def assert_aligned_reference_banks(
    prototypes: list[Any],
    topology_prototypes: list[Any],
    run_structure_prototypes: list[Any],
) -> None:
    appearance_keys = [
        (str(item.label), str(item.physical_identity)) for item in prototypes
    ]
    topology_keys = [
        (str(item.label), str(item.physical_identity))
        for item in topology_prototypes
    ]
    run_structure_keys = [
        (str(item.label), str(item.physical_identity))
        for item in run_structure_prototypes
    ]
    if appearance_keys != topology_keys or appearance_keys != run_structure_keys:
        raise ValueError("R18Z appearance/topology/ordered-run reference banks are misaligned.")


def evaluate_detector_input_enveloped(
    r11: Any,
    gray: np.ndarray,
    prototypes: list[Any],
    topology_prototypes: list[Any],
    run_structure_prototypes: list[Any],
    excluded_identity: str,
    frozen_grid: tuple[int, int, int, int] | None = None,
) -> dict[str, Any]:
    if not (
        len(prototypes)
        == len(topology_prototypes)
        == len(run_structure_prototypes)
        == EXPECTED_COMBINED_REFERENCE_COUNT
    ):
        raise ValueError("The exact frozen 475-reference R18Z bank is required.")
    assert_aligned_reference_banks(
        prototypes, topology_prototypes, run_structure_prototypes
    )
    excluded = excluded_identity.casefold()
    indices = [
        index
        for index, item in enumerate(prototypes)
        if not excluded or item.physical_identity.casefold() != excluded
    ]
    active = [prototypes[index] for index in indices]
    active_topology = [topology_prototypes[index] for index in indices]
    active_structure = [run_structure_prototypes[index] for index in indices]
    appearance_bank = r11.PrototypeBank.from_prototypes(active)
    topology_matrix = np.vstack(
        [item.descriptor.astype(np.float64) for item in active_topology]
    )
    topology_labels = np.asarray([item.label for item in active_topology])
    topology_indices = R17D._label_indices(topology_labels)
    run_scaling, run_consensus = R18H._run_structure_context(active_structure)
    envelope_bank = build_glyph_envelope_bank(active_topology, active_structure)
    if frozen_grid is None:
        selected_grid = r11.find_best_grid(gray, appearance_bank)
        grid = (
            int(selected_grid["x"]),
            int(selected_grid["y"]),
            int(selected_grid["cellWidth"]),
            int(selected_grid["cellHeight"]),
        )
    else:
        grid = tuple(int(value) for value in frozen_grid)
    residual = r11.dark_residual_exact(gray, 12)
    positions: list[dict[str, Any]] = []
    top_scores: list[float] = []
    held_positions: list[dict[str, Any]] = []
    corrected_positions: list[dict[str, Any]] = []
    for position in range(12):
        cell_x = grid[0] + position * grid[2]
        appearance = r11.describe_exact(residual, cell_x, grid[1], grid[2], grid[3])
        topology = R17D.describe_topology_exact(
            residual, cell_x, grid[1], grid[2], grid[3]
        )
        run_structure = R18H.describe_run_structure_exact(
            residual, cell_x, grid[1], grid[2], grid[3]
        )
        if appearance is None or topology is None or run_structure is None:
            raise ValueError("Selected grid could not be evaluated by R18Z glyph-envelope OCR.")
        ranked, arbitration = R18H.rank_with_run_structure(
            r11,
            appearance,
            topology,
            run_structure,
            appearance_bank,
            topology_matrix,
            topology_indices,
            run_scaling,
            run_consensus,
            position,
        )
        upstream_label = str(ranked[0]["character"])
        assessment = assess_glyph_envelope(
            envelope_bank,
            topology,
            run_structure,
            r11.allowed_labels(position),
            upstream_label,
        )
        selected_label = str(assessment["selectedLabel"])
        selected_row = next(
            row for row in ranked if str(row["character"]) == selected_label
        )
        if selected_label != upstream_label:
            ranked = [selected_row] + [
                row for row in ranked if str(row["character"]) != selected_label
            ]
            corrected_positions.append(
                {
                    "position": position + 1,
                    "upstreamLabel": upstream_label,
                    "selectedLabel": selected_label,
                }
            )
        if not bool(assessment["accepted"]):
            held_positions.append(
                {
                    "position": position + 1,
                    "diagnosticLabel": upstream_label,
                    "decision": str(assessment["decision"]),
                }
            )
        upstream_score = float(
            next(
                row for row in ranked if str(row["character"]) == upstream_label
            )["score"]
        )
        selected_score = min(upstream_score, float(selected_row["score"]))
        positions.append(
            {
                "position": position + 1,
                "imageFirst": selected_label,
                "candidates": ranked[: 4 if position < 10 else 8],
                "allCandidates": ranked,
                "glyphArbitration": arbitration,
                "glyphEnvelope": assessment,
                "scoreUsedForGrid": selected_score,
            }
        )
        top_scores.append(selected_score)
    mean_score = float(sum(top_scores) / 12.0)
    evaluated = {
        "x": grid[0],
        "y": grid[1],
        "cellWidth": grid[2],
        "cellHeight": grid[3],
        "meanTopScore": mean_score,
        "selectionScore": (
            r11.GRID_MEAN_WEIGHT * mean_score
            + r11.GRID_LEADING_WEIGHT * top_scores[0]
            + r11.GRID_TRAILING_WEIGHT * top_scores[-1]
        ),
        "leadingBoundaryScore": top_scores[0],
        "trailingBoundaryScore": top_scores[-1],
        "positions": positions,
    }
    output = r11.finalize_grid(evaluated)
    output["glyphRanking"] = {
        "method": "R18Z_FROZEN_R18V_GENERIC_LINEAGE_GLYPH_ENVELOPE_ENFORCEMENT",
        "minimumEnforceableIndependentPhysicalLineages": MINIMUM_ENFORCEABLE_LINEAGES,
        "empiricalRadiusMultiplier": R18V.EMPIRICAL_RADIUS_MULTIPLIER,
        "robustRadiusMadMultiplier": R18V.ROBUST_RADIUS_MAD_MULTIPLIER,
        "queryRivalRatioMargin": R18V.QUERY_RIVAL_RATIO_MARGIN,
        "reciprocalCenterRatioMinimum": R18V.RECIPROCAL_CENTER_RATIO_MINIMUM,
        "alternativeLabelMaximumNormalizedDistance": R18V.ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE,
        "checksumUsedForImageFirst": False,
        "truthLotSlotAndNotchUsedForImageFirst": False,
        "syntheticDotsUsed": False,
    }
    output["ocrEnvelope"] = {
        "schema": "argos_opencv_scribe_glyph_envelope_evidence_v1",
        "passed": not held_positions,
        "decision": (
            "PASS_ALL_SELECTED_GLYPHS_ENVELOPED"
            if not held_positions
            else "HOLD_ONE_OR_MORE_SELECTED_GLYPHS_NOT_ENVELOPED"
        ),
        "diagnosticString": output["imageFirstString"],
        "heldPositions": held_positions,
        "correctedPositions": corrected_positions,
        "bankFingerprint": envelope_bank.fingerprint,
        "topologyScale": envelope_bank.topology_scale,
        "orderedRunStructureScale": envelope_bank.run_structure_scale,
        "coverage": coverage_evidence(envelope_bank),
        "checksumUsed": False,
    }
    return output


def _apply_result_envelope_state(result: dict[str, Any]) -> None:
    R18V._apply_result_envelope_state(result)
    result.setdefault("provenance", {}).update(
        {
            "engineRevision": REVISION,
            "combinedReferenceCount": EXPECTED_COMBINED_REFERENCE_COUNT,
            "supplementalManifestSha256": EXPECTED_SUPPLEMENTAL_MANIFEST_SHA256,
            "r18zExactLineageLooGateSha256": EXPECTED_R18Z_LOO_GATE_SHA256,
            "runtimeExpectedTruthUsedForGlyphSelection": False,
        }
    )
    result["revision"] = REVISION


def _validate_loo_gate(path: Path, expected_sha256: str) -> None:
    if (
        expected_sha256.upper() != EXPECTED_R18Z_LOO_GATE_SHA256
        or not path.is_file()
        or _sha256_file(path) != EXPECTED_R18Z_LOO_GATE_SHA256
    ):
        raise ValueError("R18Z exact-lineage LOO gate SHA-256 mismatch.")
    gate = json.loads(path.read_text(encoding="utf-8-sig"))
    if (
        gate.get("schema")
        != "argos_opencv_scribe_r18z_exact_scribe_lineage_loo_gate_v1"
        or gate.get("state")
        != "PASS_R18Z_ZERO_WRONG_ACCEPTED_EXACT_SCRIBE_LINEAGE_LOO"
        or gate.get("testSha256") != EXPECTED_R18Z_LOO_TEST_SHA256
        or int(gate.get("leaveOneExactScribeLineageOut", {}).get("referenceQueries", -1))
        != EXPECTED_COMBINED_REFERENCE_COUNT
        or int(gate.get("leaveOneExactScribeLineageOut", {}).get("acceptedWrong", -1))
        != 0
        or int(
            gate.get("predecessorAcceptedCorrectRegression", {}).get(
                "currentAcceptedCorrectCountForSame465Queries", -1
            )
        )
        != 273
        or gate.get("predecessorAcceptedCorrectRegression", {}).get("lostReferenceIndices")
        != []
    ):
        raise ValueError("R18Z exact-lineage LOO gate contract mismatch.")


def _run_job_locked(job_path: Path, result_path: Path) -> int:
    """Run with the caller already holding ``_RUNTIME_PATCH_LOCK``."""
    r11 = R17D.R17C.R17B._load_r11()
    job = r11.read_json(job_path)
    references = job.get("references", {})
    if str(references.get("manifestSha256", "")).upper() != EXPECTED_BASE_MANIFEST_SHA256:
        raise ValueError("R18Z requires the exact frozen base reference manifest.")
    if (
        str(references.get("supplementalManifestSha256", "")).upper()
        != EXPECTED_SUPPLEMENTAL_MANIFEST_SHA256
    ):
        raise ValueError("R18Z requires the exact 19-reference supplemental manifest.")
    loo_path = Path(str(references.get("r18zExactLineageLooGatePath", "")))
    loo_sha256 = str(references.get("r18zExactLineageLooGateSha256", ""))
    _validate_loo_gate(loo_path, loo_sha256)

    original_evaluate = R18H.evaluate_detector_input_structural
    original_apply = R17E.enforce_result_verifier_only
    original_revision = R18H.REVISION
    original_loader = R18F.R18F_LOADER

    def evaluate(
        r11: Any,
        gray: np.ndarray,
        prototypes: list[Any],
        topology: list[Any],
        structure: list[Any],
        excluded: str,
        frozen_grid: Any = None,
    ) -> dict[str, Any]:
        return evaluate_detector_input_enveloped(
            r11, gray, prototypes, topology, structure, excluded, frozen_grid
        )

    def enforce_result(result: dict[str, Any]) -> None:
        original_apply(result)
        _apply_result_envelope_state(result)

    R18H.evaluate_detector_input_structural = evaluate
    R17E.enforce_result_verifier_only = enforce_result
    R18H.REVISION = REVISION
    R18F.R18F_LOADER = R18Z_LOADER
    try:
        return R18H.run_job(job_path, result_path)
    finally:
        R18F.R18F_LOADER = original_loader
        R18H.REVISION = original_revision
        R17E.enforce_result_verifier_only = original_apply
        R18H.evaluate_detector_input_structural = original_evaluate


def run_job(job_path: Path, result_path: Path) -> int:
    if not _RUNTIME_PATCH_LOCK.acquire(blocking=False):
        raise RuntimeError("Concurrent R18ZV provider invocation is not allowed.")
    try:
        return _run_job_locked(job_path, result_path)
    finally:
        _RUNTIME_PATCH_LOCK.release()


def main(argv: Iterable[str]) -> int:
    r11 = R17D.R17C.R17B._load_r11()
    arguments = r11.parse_arguments(argv)
    return run_job(arguments.job, arguments.result)


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Exception as error:
        print(
            json.dumps(
                {
                    "state": "HOLD_OPENCV_SCRIBE_PROVIDER_ERROR",
                    "errorType": type(error).__name__,
                    "detail": str(error),
                }
            ),
            file=sys.stderr,
        )
        raise
