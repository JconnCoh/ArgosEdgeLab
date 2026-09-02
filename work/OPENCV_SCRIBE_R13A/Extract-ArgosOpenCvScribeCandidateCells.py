#!/usr/bin/env python3
"""Extract review-only candidate glyph cells from a pinned OpenCV blob grid."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

import cv2
import numpy as np


class GateError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise GateError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    require(isinstance(value, dict), f"JSON root is not an object: {path}")
    return value


def repo_path(repo_root: Path, relative_path: str) -> Path:
    path = (repo_root / Path(relative_path)).resolve()
    require(path.is_relative_to(repo_root), f"Repository path escapes root: {relative_path}")
    return path


def verify_authority(authority: dict[str, Any], context: str) -> None:
    require(authority.get("reviewOnly") is True, f"{context} is not review-only")
    for key in (
        "automaticIdentityAuthority",
        "trainingAuthorized",
        "trainingEligible",
        "trainingExecuted",
        "xmlEligible",
        "productionEligible",
        "mayClearHolds",
        "portalPublicationAuthorizedByThisInput",
        "jbodExecutionAuthorizedByThisInput",
    ):
        if key in authority:
            require(authority[key] is False, f"{context} enables forbidden authority: {key}")


def write_png(path: Path, image: np.ndarray) -> str:
    require(path.parent.is_dir(), f"Output parent is absent: {path.parent}")
    require(not path.exists(), f"Refusing to replace output: {path}")
    written = cv2.imwrite(str(path), image, [cv2.IMWRITE_PNG_COMPRESSION, 9])
    require(bool(written) and path.is_file(), f"OpenCV could not write: {path}")
    return sha256_file(path)


def normalized_cell(
    raw: np.ndarray,
    source_y: int,
    width: int = 96,
    height: int = 230,
) -> np.ndarray:
    require(raw.ndim == 2 and raw.dtype == np.uint8, "Raw cell is not 8-bit grayscale")
    if raw.shape[1] >= width:
        source_x = (raw.shape[1] - width) // 2
        content = raw[:, source_x:source_x + width]
    else:
        content = np.zeros((raw.shape[0], width), dtype=np.uint8)
        target_x = (width - raw.shape[1]) // 2
        content[:, target_x:target_x + raw.shape[1]] = raw
    if content.shape[0] >= height:
        source_y = (content.shape[0] - height) // 2
        normalized = content[source_y:source_y + height, :]
    else:
        normalized = np.zeros((height, width), dtype=np.uint8)
        target_y = (height - content.shape[0]) // 2
        if (target_y - source_y) % 2 and target_y > 0:
            target_y -= 1
        normalized[target_y:target_y + content.shape[0], :] = content
    polarity_corrected = cv2.bitwise_not(normalized)
    return cv2.cvtColor(polarity_corrected, cv2.COLOR_GRAY2BGR)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--input-sha256", required=True)
    parser.add_argument("--plan", required=True, type=Path)
    parser.add_argument("--plan-sha256", required=True)
    parser.add_argument("--case-id", required=True)
    parser.add_argument("--output-root", required=True, type=Path)
    parser.add_argument("--repo-root", type=Path)
    arguments = parser.parse_args()

    repo_root = arguments.repo_root.resolve() if arguments.repo_root else Path(__file__).resolve().parents[2]
    require(repo_root.is_dir(), f"Repository root is absent: {repo_root}")
    input_path = arguments.input.resolve()
    plan_path = arguments.plan.resolve()
    require(input_path.is_file(), f"Input is absent: {input_path}")
    require(plan_path.is_file(), f"Plan is absent: {plan_path}")
    require(sha256_file(input_path) == arguments.input_sha256.upper(), "Harvest input SHA-256 mismatch")
    require(sha256_file(plan_path) == arguments.plan_sha256.upper(), "Harvest plan SHA-256 mismatch")
    input_doc = read_json(input_path)
    plan = read_json(plan_path)
    require(input_doc.get("classification") == "LOCKED_INPUT", "Harvest input is not locked")
    require(plan.get("classification") == "PENDING_GATE", "Harvest plan classification mismatch")
    require(plan.get("disposition") == "HOLD_EXPLICIT_PUBLISH_FOR_BOUNDED_REMOTE_CROP_ACQUISITION", "Harvest plan disposition mismatch")
    verify_authority(input_doc["authority"], "Harvest input")
    verify_authority(plan["authority"], "Harvest plan")
    require(plan["admissionContract"].get("frozenReferenceManifestMutationAllowed") is False, "Plan permits frozen reference mutation")
    require(plan["admissionContract"].get("maximumActiveVariantsPerLabel") == 24, "Plan variant bound mismatch")

    fixtures = [row for row in input_doc["localDevelopmentFixtures"] if row.get("caseId") == arguments.case_id]
    require(len(fixtures) == 1, f"Expected one local fixture for {arguments.case_id}")
    fixture = fixtures[0]
    planned = [row for row in plan["development"]["localPinnedSources"] if row.get("caseId") == arguments.case_id]
    require(len(planned) == 1, f"Expected one planned local source for {arguments.case_id}")
    planned_source = planned[0]
    truth = fixture["truth"]
    require(re.fullmatch(r"[0-9A-Z]{12}", truth) is not None, "Fixture truth syntax mismatch")
    require(planned_source.get("confirmedScribe") == truth, "Plan/fixture truth mismatch")
    require(planned_source.get("physicalIdentity") == fixture["physicalIdentity"], "Plan/fixture identity mismatch")
    target_labels = sorted(planned_source["targetCharacters"])
    require(target_labels, "Fixture has no planned candidate labels")
    require(all(label in truth for label in target_labels), "Planned target label is absent from truth")

    truth_spec = fixture["truthRecord"]
    truth_path = repo_path(repo_root, truth_spec["path"])
    require(truth_path.is_file(), f"Truth record is absent: {truth_path}")
    require(sha256_file(truth_path) == truth_spec["sha256"], "Truth record SHA-256 mismatch")
    truth_record = read_json(truth_path)
    require(truth_record.get("operatorConfirmedString") == truth, "Operator-confirmed truth mismatch")
    require(truth_record.get("semiM12", {}).get("valid") is True, "Operator truth failed SEMI M12")
    verify_authority(truth_record["authority"], "Operator truth record")

    result_evidence = truth_record["detectorRegression"]
    result_path = Path(result_evidence["resultPath"])
    require(result_path.is_file(), f"Pinned detector result is absent: {result_path}")
    require(sha256_file(result_path) == result_evidence["resultSha256"], "Pinned detector result SHA-256 mismatch")
    result = read_json(result_path)
    require(result.get("schema") == "argos_opencv_scribe_blob_topology_diagnostic_v1", "Detector-result schema mismatch")
    verify_authority(result["authority"], "Detector result")
    require(result.get("state") == "SCRIBE_BLOB_TOPOLOGY_CHECKSUM_VALID_REVIEW_HOLD", "Detector-result state mismatch")
    require(result["referenceEvidence"].get("manifestSha256") == plan["evidence"]["frozenReferenceManifestSha256"], "Detector/plan reference manifest mismatch")
    best = result["bestDiagnostic"]
    require(best.get("checksumValid") is True, "Selected blob grid failed SEMI M12")
    require(best.get("proposedString") == truth, "Selected blob grid does not reproduce operator truth")
    require(best.get("imageFirstString") == truth, "Selected blob grid image-first string mismatch")

    blob_evidence = truth_record["sourceEvidence"]["blobRaster"]
    blob_path = Path(blob_evidence["path"])
    require(blob_path.is_file(), f"Pinned blob raster is absent: {blob_path}")
    require(sha256_file(blob_path) == blob_evidence["sha256"], "Pinned blob raster SHA-256 mismatch")
    expected_blob_name = f"{best['channel']}_{best['direction']}_blobs.png"
    require(blob_path.name == expected_blob_name, "Blob raster does not match selected channel/direction")

    for name, evidence_key in (("FRONTSIDE_BF", "bf"), ("FRONTSIDE_DF", "df")):
        planned_channel = planned_source["channels"][name]
        truth_channel = truth_record["sourceEvidence"][evidence_key]
        require(planned_channel["localPath"].replace("\\", "/") == truth_channel["path"].replace("\\", "/"), f"{name} local path mismatch")
        require(planned_channel["expectedSha256"] == truth_channel["sha256"], f"{name} source hash mismatch")

    blob = cv2.imread(str(blob_path), cv2.IMREAD_GRAYSCALE)
    require(blob is not None, "OpenCV could not decode the pinned blob raster")
    require(blob.dtype == np.uint8 and blob.ndim == 2, "Blob raster is not 8-bit grayscale")
    unique_values = np.unique(blob)
    require(set(int(value) for value in unique_values).issubset({0, 255}), "Blob raster contains non-binary pixels")
    require(int(np.count_nonzero(blob)) > 0, "Blob raster has no foreground pixels")

    grid_x = int(best["gridX"])
    grid_y = int(best["gridY"])
    pitch = int(best["cellWidth"])
    cell_height = int(best["cellHeight"])
    grid_width = 12 * pitch
    require(grid_x >= 0 and grid_y >= 0 and pitch > 0 and cell_height > 0, "Selected grid geometry is invalid")
    require(grid_x + grid_width <= blob.shape[1] and grid_y + cell_height <= blob.shape[0], "Selected grid escapes blob raster")
    grid = blob[grid_y:grid_y + cell_height, grid_x:grid_x + grid_width].copy()

    output_root = arguments.output_root.resolve()
    require(output_root.is_relative_to(repo_root), "Candidate output must remain inside the repository")
    partial_root = output_root.with_name(output_root.name + ".partial")
    require(not output_root.exists(), f"Refusing to replace candidate output: {output_root}")
    require(not partial_root.exists(), f"Prior partial candidate output exists: {partial_root}")
    require(len(output_root.name) <= 80, "Candidate output component exceeds path policy")
    planned_longest = partial_root / "candidate_manifest.json.partial"
    require(len(str(planned_longest)) + 32 < 200, "Candidate output exceeds the preflight path budget")
    cells_root = partial_root / "cells"
    cells_root.mkdir(parents=True)

    grid_path = partial_root / "selected_grid.png"
    grid_sha256 = write_png(grid_path, cv2.cvtColor(grid, cv2.COLOR_GRAY2BGR))
    cell_rows: list[dict[str, Any]] = []
    candidate_rows: list[dict[str, Any]] = []
    for index, label in enumerate(truth):
        position = index + 1
        source_x = grid_x + index * pitch
        raw = blob[grid_y:grid_y + cell_height, source_x:source_x + pitch]
        normalized = normalized_cell(raw, grid_y)
        relative_path = f"cells/P{position:02d}_{label}.png"
        output_path = partial_root / Path(relative_path)
        cell_sha256 = write_png(output_path, normalized)
        row = {
            "position": position,
            "label": label,
            "relativePath": relative_path,
            "sha256": cell_sha256,
            "sourceBounds": {
                "x": source_x,
                "y": grid_y,
                "width": pitch,
                "height": cell_height,
            },
            "outputWidth": int(normalized.shape[1]),
            "outputHeight": int(normalized.shape[0]),
            "outputChannels": int(normalized.shape[2]),
        }
        cell_rows.append(row)
        if label in target_labels:
            candidate_rows.append(
                {
                    **row,
                    "physicalIdentity": fixture["physicalIdentity"],
                    "source": "OPERATOR_CONFIRMED_R12B_BLOB_GRID_LOCAL_CANDIDATE",
                    "labelAuthority": "OPERATOR_CONFIRMED_VISIBLE_STRING",
                    "exactAcquisitionSelfExclusionRequired": True,
                    "referenceAdmissionEligible": False,
                    "trainingEligible": False,
                }
            )
    require(sorted({row["label"] for row in candidate_rows}) == target_labels, "Candidate extraction did not cover every planned label")

    manifest = {
        "schema": "argos_opencv_scribe_candidate_glyph_manifest_v1",
        "revision": input_doc["revision"] + "_POLARITY_CORRECT_CANDIDATES",
        "classification": "PENDING_GATE",
        "state": "LOCAL_CANDIDATES_EXTRACTED_AWAITING_INDEPENDENT_PHYSICAL_VALIDATION",
        "caseId": arguments.case_id,
        "physicalIdentity": fixture["physicalIdentity"],
        "operatorConfirmedString": truth,
        "targetLabels": target_labels,
        "candidateCount": len(candidate_rows),
        "inputEvidence": {
            "harvestInputPath": input_path.relative_to(repo_root).as_posix(),
            "harvestInputSha256": arguments.input_sha256.upper(),
            "harvestPlanPath": plan_path.relative_to(repo_root).as_posix(),
            "harvestPlanSha256": arguments.plan_sha256.upper(),
            "extractorPath": Path(__file__).resolve().relative_to(repo_root).as_posix(),
            "extractorSha256": sha256_file(Path(__file__).resolve()),
            "truthRecordPath": truth_path.relative_to(repo_root).as_posix(),
            "truthRecordSha256": truth_spec["sha256"],
            "detectorResultPath": str(result_path),
            "detectorResultSha256": result_evidence["resultSha256"],
            "blobRasterPath": str(blob_path),
            "blobRasterSha256": blob_evidence["sha256"],
            "sourceWaferImageBytesReadByExtractor": False,
            "blobRasterBytesReadByExtractor": True,
        },
        "sourceImageEvidence": {
            name: {
                "path": channel["localPath"],
                "sha256": channel["expectedSha256"],
                "byteState": "PINNED_NOT_REREAD_BY_CANDIDATE_EXTRACTOR",
            }
            for name, channel in planned_source["channels"].items()
        },
        "selectedGrid": {
            "channel": best["channel"],
            "direction": best["direction"],
            "x": grid_x,
            "y": grid_y,
            "cellWidth": pitch,
            "cellHeight": cell_height,
            "cellCount": 12,
            "relativePath": grid_path.relative_to(partial_root).as_posix(),
            "sha256": grid_sha256,
            "foregroundPixels": int(np.count_nonzero(grid)),
        },
        "normalization": {
            "implementation": "OPENCV_CENTER_CROP_OR_ZERO_PAD_NO_RESAMPLING_THEN_BITWISE_INVERT",
            "sourcePolarity": "WHITE_DOTS_ON_BLACK_RESIDUAL_BLOB_CANVAS",
            "outputPolarity": "BLACK_DOTS_ON_WHITE_R11_REFERENCE_RASTER",
            "consumerSemantics": "R11_DECODE_GRAY_THEN_DARK_RESIDUAL_EXACT",
            "verticalPlacement": "CENTER_PAD_ADJUSTED_UP_ONE_PIXEL_WHEN_NEEDED_TO_PRESERVE_SOURCE_Y_PARITY_FOR_ROUND_TO_EVEN",
            "sourceYParity": grid_y % 2,
            "outputWidth": 96,
            "outputHeight": 230,
            "outputChannels": 3,
            "opencvVersion": cv2.__version__,
            "numpyVersion": np.__version__,
        },
        "auditCells": cell_rows,
        "candidateReferences": candidate_rows,
        "admission": {
            "frozenReferenceManifestMutated": False,
            "candidateNamespaceOnly": True,
            "maximumActiveVariantsPerLabel": 24,
            "exactAcquisitionSelfExclusionRequired": True,
            "freshPhysicalWaferValidationRequired": True,
            "validationSourcesMayContributeReferences": False,
            "referenceAdmissionEligible": False,
            "operatorConfirmationRemainsRequired": True,
        },
        "authority": {
            "reviewOnly": True,
            "automaticIdentityAuthority": False,
            "trainingAuthorized": False,
            "trainingEligible": False,
            "trainingExecuted": False,
            "xmlEligible": False,
            "productionEligible": False,
            "mayClearHolds": False,
        },
        "nextAction": "ACQUIRE_PINNED_REMOTE_DEVELOPMENT_AND_WITHHELD_VALIDATION_CROPS_AFTER_EXPLICIT_PUBLISH",
    }
    manifest_path = partial_root / "candidate_manifest.json"
    require(not manifest_path.exists(), f"Refusing to replace manifest: {manifest_path}")
    with manifest_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(manifest, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    partial_root.rename(output_root)
    print(json.dumps({
        "state": manifest["state"],
        "outputRoot": str(output_root),
        "manifestSha256": sha256_file(output_root / "candidate_manifest.json"),
        "candidateLabels": target_labels,
        "candidateCount": len(candidate_rows),
    }, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (GateError, KeyError, TypeError, ValueError) as error:
        print(f"R13A_CANDIDATE_EXTRACTION_FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
