#!/usr/bin/env python3
"""Read-only R15D diagnostic for a pinned R11 perimeter region.

Returns the exact rectified BF/DF region and compact visual sheets for every
R12B grid hypothesis.  It does not select an identity, admit references, tune
OCR, write XML, clear holds, or mutate source images.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Iterable

import cv2
import numpy as np


sys.dont_write_bytecode = True
cv2.setNumThreads(1)
cv2.ocl.setUseOpenCL(False)

REVISION = "ARGOS_OPENCV_SCRIBE_GRID_DIAGNOSTIC_R15D_20260903"
JOB_SCHEMA = "argos_opencv_scribe_alphabet_crop_job_v1"
RESULT_SCHEMA = "argos_opencv_scribe_grid_diagnostic_case_result_v1"
SHA256_PATTERN = re.compile(r"^[0-9A-Fa-f]{64}$")
TOKEN_PATTERN = re.compile(r"^[A-Za-z0-9_.-]{1,80}$")
REGION_PATTERN = re.compile(r"^PERIMETER_(?:SMOOTH|PAIRED_BF_DF)_[A-Z0-9_]{1,64}$")
MAXIMUM_JOB_BYTES = 1024 * 1024
PATH_SUFFIX_RESERVE = 32
MAXIMUM_SAFE_EFFECTIVE_PATH = 199

DEPENDENCIES = {
    "r11": ("R11.py", "7C6632B2D1C56DA4CA565DAB5BF7D46A366BCAE6663793CE5AB1ABB4739F72C9"),
    "r12a": ("R12A.py", "F5EB8FB3281D7D55CDD9FA4A3530A32BD33BBA3B8DB69E0A247C20935F6AD429"),
    "r12b": ("R12B.py", "D670CFCE64BF5FDF5307E69ED69A05CB7B404A78B521AB889C7F35044D666FDC"),
}

SAFE_AUTHORITY = {
    "reviewOnly": True,
    "automaticIdentityAuthority": False,
    "automaticReferenceAdmissionAllowed": False,
    "trainingAuthorized": False,
    "trainingEligible": False,
    "trainingExecuted": False,
    "xmlEligible": False,
    "productionEligible": False,
    "productionRoutingEnabled": False,
    "mayClearHolds": False,
}


class GateError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise GateError(message)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def sha256_array(image: np.ndarray) -> str:
    return sha256_bytes(np.ascontiguousarray(image).tobytes())


def source_pair_sha256(bf_sha256: str, df_sha256: str) -> str:
    return sha256_bytes(f"BF={bf_sha256.upper()}\nDF={df_sha256.upper()}\n".encode("ascii"))


def import_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, f"Cannot import {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def load_dependencies() -> tuple[Any, Any, Any, dict[str, Any]]:
    base = Path(__file__).resolve().parent
    modules = []
    evidence: dict[str, Any] = {}
    for key in ("r11", "r12a", "r12b"):
        filename, expected = DEPENDENCIES[key]
        path = base / filename
        require(path.is_file(), f"Packaged dependency absent: {filename}")
        actual = sha256_file(path)
        require(actual == expected, f"Packaged dependency hash mismatch: {filename}")
        modules.append(import_module(f"argos_r15d_{key}", path))
        evidence[key] = {"filename": filename, "sha256": actual}
    return modules[0], modules[1], modules[2], evidence


def read_job(path: Path) -> tuple[dict[str, Any], str]:
    require(path.is_file(), f"Job absent: {path}")
    require(0 < path.stat().st_size <= MAXIMUM_JOB_BYTES, "Job size is invalid")
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    require(isinstance(value, dict), "Job root must be an object")
    return value, sha256_file(path)


def validate_job(job: dict[str, Any], r11: Any) -> str:
    require(job.get("schema") == JOB_SCHEMA, "R15D job schema mismatch")
    for field in ("jobId", "caseId"):
        require(isinstance(job.get(field), str) and TOKEN_PATTERN.fullmatch(job[field]) is not None, f"Invalid {field}")
    region_id = job.get("diagnosticRegionId")
    require(isinstance(region_id, str) and REGION_PATTERN.fullmatch(region_id) is not None, "Invalid diagnosticRegionId")
    authority = job.get("authority")
    require(isinstance(authority, dict), "Authority is absent")
    for key, expected in SAFE_AUTHORITY.items():
        require(authority.get(key) is expected, f"Authority mismatch: {key}")
    for key in ("sourceMutationAllowed", "sourceDeletionAllowed", "taskOrProcessRestartAllowed", "providerActivationAllowed", "retryAuthorized"):
        require(authority.get(key, False) is False, f"Forbidden authority enabled: {key}")
    for channel in ("bf", "df"):
        source = job.get("inputs", {}).get(channel, {})
        require(bool(str(source.get("path", ""))), f"inputs.{channel}.path absent")
        require(isinstance(source.get("bytes"), int) and source["bytes"] > 0, f"inputs.{channel}.bytes invalid")
        require(SHA256_PATTERN.fullmatch(str(source.get("sha256", ""))) is not None, f"inputs.{channel}.sha256 invalid")
    r11_job = copy.deepcopy(job)
    r11_job["schema"] = "argos_opencv_scribe_job_v1"
    r11.validate_job_shape(r11_job)
    return region_id


def encode_png(image: np.ndarray) -> bytes:
    success, encoded = cv2.imencode(".png", image, [cv2.IMWRITE_PNG_COMPRESSION, 9])
    require(bool(success), "OpenCV PNG encoding failed")
    return encoded.tobytes()


def visual_gray(image: np.ndarray) -> np.ndarray:
    return cv2.normalize(image, None, 0, 255, cv2.NORM_MINMAX).astype(np.uint8)


def contact_sheet(oriented: np.ndarray, grids: list[dict[str, Any]], channel: str, direction: str) -> np.ndarray:
    panel_w, panel_h, label_h, columns = 520, 120, 24, 2
    rows = max(1, (len(grids) + columns - 1) // columns)
    sheet = np.full((rows * (panel_h + label_h), columns * panel_w), 18, dtype=np.uint8)
    if not grids:
        cv2.putText(sheet, f"{channel} {direction}: NO EVALUABLE GRID", (12, 42), cv2.FONT_HERSHEY_SIMPLEX, 0.55, 230, 1, cv2.LINE_AA)
        return sheet
    for index, grid in enumerate(grids):
        x = int(grid["gridX"])
        y = int(grid["gridY"])
        width = int(grid["cellWidth"]) * 12
        height = int(grid["cellHeight"])
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(oriented.shape[1], x + width), min(oriented.shape[0], y + height)
        require(x1 > x0 and y1 > y0, f"Grid hypothesis {index} is outside the rectified patch")
        crop = visual_gray(oriented[y0:y1, x0:x1])
        scale = min(panel_w / crop.shape[1], panel_h / crop.shape[0])
        resized = cv2.resize(crop, (max(1, int(round(crop.shape[1] * scale))), max(1, int(round(crop.shape[0] * scale)))), interpolation=cv2.INTER_AREA)
        row, column = divmod(index, columns)
        top, left = row * (panel_h + label_h), column * panel_w
        oy = top + label_h + (panel_h - resized.shape[0]) // 2
        ox = left + (panel_w - resized.shape[1]) // 2
        sheet[oy:oy + resized.shape[0], ox:ox + resized.shape[1]] = resized
        label = f"G{index:02d} x{x} y{y} p{int(grid['cellWidth'])} h{height} {str(grid.get('imageFirstString',''))}"
        cv2.putText(sheet, label[:68], (left + 5, top + 17), cv2.FONT_HERSHEY_SIMPLEX, 0.38, 235, 1, cv2.LINE_AA)
    return sheet


def artifact_row(relative: str, kind: str, payload: bytes, channel: str, direction: str | None, source_sha256: str) -> dict[str, Any]:
    row = {"relativePath": relative, "kind": kind, "sha256": sha256_bytes(payload), "sourceChannel": channel, "sourceSha256": source_sha256}
    if direction is not None:
        row["direction"] = direction
    return row


def run_case(job: dict[str, Any], job_path: Path, job_sha256: str) -> tuple[dict[str, Any], dict[str, bytes]]:
    r11, r12a, r12b, dependencies = load_dependencies()
    region_id = validate_job(job, r11)
    roots = {str(row["relativePrefix"]): Path(str(row["path"])) for row in job["references"]["roots"]}
    prototypes, reference_evidence = r11.load_reference_prototypes(Path(str(job["references"]["manifestPath"])), str(job["references"]["manifestSha256"]), roots)
    bf, bf_evidence = r11.decode_source(job["inputs"]["bf"])
    df, df_evidence = r11.decode_source(job["inputs"]["df"])
    require(bf.shape == df.shape, "BF and DF dimensions differ")
    source_evidence = {"bf": bf_evidence, "df": df_evidence, "jobPath": str(job_path), "jobSha256": job_sha256, "sourceHashVerifiedBeforeDecode": True}
    r11_job = copy.deepcopy(job)
    r11_job["schema"] = "argos_opencv_scribe_job_v1"
    analysis = r11.analyze_images(r11_job, bf, df, prototypes, reference_evidence, source_evidence)
    regions = [row for row in analysis.get("localization", {}).get("exceptionDiagnostics", []) if isinstance(row, dict) and str(row.get("regionId", "")) == region_id]
    require(len(regions) == 1, f"Expected exactly one pinned diagnostic region {region_id}; found {len(regions)}")
    row = regions[0]
    region = r11.Region(str(row["regionId"]), str(row["source"]), float(row["x"]), float(row["y"]), float(row["width"]), float(row["height"]), float(row["angleDegrees"]), float(row["score"]))
    artifacts: dict[str, bytes] = {}
    artifact_rows: list[dict[str, Any]] = []
    evaluations: list[dict[str, Any]] = []
    source_hashes = {"BF": str(bf_evidence["sha256"]), "DF": str(df_evidence["sha256"])}
    for channel, gray in (("BF", bf), ("DF", df)):
        rectified = r11.rectify(gray, region)
        require(rectified is not None and rectified.shape == (400, 1600), f"{channel} rectified region is not 1600x400")
        rectified_payload = encode_png(rectified)
        rectified_name = f"rectified_{channel}.png"
        artifacts[rectified_name] = rectified_payload
        rectified_hash = sha256_array(rectified)
        artifact_rows.append(artifact_row(rectified_name, "RECTIFIED_REGION", rectified_payload, channel, None, source_hashes[channel]))
        for direction, oriented in (("FORWARD", rectified), ("REVERSE_180", cv2.rotate(rectified, cv2.ROTATE_180))):
            try:
                evaluated, _ = r12b.evaluate_patch(r11, r12a, oriented, prototypes, str(job["references"]["excludedPhysicalIdentity"]), float(job["blobGrid"]["minimumDotSize"]), float(job["blobGrid"]["maximumDotSize"]))
                grids = list(evaluated.get("gridDiagnostics", []))
                evaluation_state = "EVALUATED"
                detail = ""
            except (ValueError, cv2.error) as error:
                grids = []
                evaluation_state = "HOLD_NO_EVALUABLE_GRID"
                detail = str(error)
            sheet = contact_sheet(oriented, grids, channel, direction)
            name = f"hypotheses_{channel}_{direction}.png"
            payload = encode_png(sheet)
            artifacts[name] = payload
            artifact_rows.append(artifact_row(name, "GRID_HYPOTHESIS_CONTACT_SHEET", payload, channel, direction, rectified_hash))
            evaluations.append({"channel": channel, "direction": direction, "state": evaluation_state, "detail": detail, "gridCount": len(grids), "rectifiedPatchArraySha256": rectified_hash, "orientedPatchArraySha256": sha256_array(oriented), "gridDiagnostics": grids})
    require(len(artifacts) == 6, "R15D artifact cardinality changed")
    result = {
        "schema": RESULT_SCHEMA,
        "revision": REVISION,
        "classification": "DIAGNOSTIC_ONLY",
        "state": "HOLD_R15D_DIAGNOSTIC_EVIDENCE_RETURNED",
        "caseId": job["caseId"],
        "jobId": job["jobId"],
        "physicalIdentity": job["physicalIdentity"],
        "purpose": job["purpose"],
        "eligibleIdentity": False,
        "referenceAdmissionEligible": False,
        "diagnosticRegion": {"regionId": region_id, "source": region.source, "centerX": region.center_x, "centerY": region.center_y, "width": region.width, "height": region.height, "angleDegrees": region.angle_degrees, "localizationScore": region.localization_score},
        "provenance": {"sources": {"bf": {"sha256": source_hashes["BF"], "verified": True}, "df": {"sha256": source_hashes["DF"], "verified": True}}, "sourcePairSha256": source_pair_sha256(source_hashes["BF"], source_hashes["DF"])},
        "artifacts": artifact_rows,
        "gridHypothesisEvaluations": evaluations,
        "referenceEvidence": reference_evidence,
        "dependencyEvidence": dependencies,
        "providerEvidence": {"path": str(Path(__file__).resolve()), "sha256": sha256_file(Path(__file__).resolve()), "opencvVersion": cv2.__version__, "numpyVersion": np.__version__, "bytecodeWritesDisabled": bool(sys.dont_write_bytecode)},
        "holds": [{"code": "SCRIBE_GRID_DIAGNOSTIC_REVIEW_HOLD", "detail": "Pixels and every bounded internal grid hypothesis are returned for operator/developer diagnosis only."}],
        "invariants": {"sourceImagesMutated": False, "frozenReferenceManifestMutated": False, "automaticRetryPerformed": False, "identityAccepted": False, "referenceAdmitted": False, "trainingPerformed": False, "xmlWritten": False, "productionStateChanged": False, "holdCleared": False},
        "authority": dict(SAFE_AUTHORITY),
    }
    return result, artifacts


def validate_output_path(output_root: Path) -> tuple[Path, Path]:
    root = output_root.resolve()
    partial = root.with_name(root.name + ".partial")
    require(root.parent != root and len(root.name) <= 80, "Invalid output root")
    require(not root.exists() and not partial.exists(), "R15D output root already exists")
    require(root.parent.is_dir(), "R15D output parent is absent")
    planned = [partial / "CASE_RESULT.json", partial / "hypotheses_DF_REVERSE_180.png"]
    require(max(len(str(path)) + PATH_SUFFIX_RESERVE for path in planned) <= MAXIMUM_SAFE_EFFECTIVE_PATH, "R15D output path budget failed")
    return root, partial


def write_new(path: Path, payload: bytes) -> None:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    with os.fdopen(descriptor, "wb") as stream:
        stream.write(payload)
        stream.flush()
        os.fsync(stream.fileno())


def commit_output(output_root: Path, result: dict[str, Any], artifacts: dict[str, bytes]) -> str:
    root, partial = validate_output_path(output_root)
    partial.mkdir()
    for relative, payload in sorted(artifacts.items()):
        write_new(partial / relative, payload)
    result_payload = (json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8")
    write_new(partial / "CASE_RESULT.json", result_payload)
    partial.rename(root)
    return sha256_bytes(result_payload)


def failure_result(job: dict[str, Any] | None, error: Exception) -> dict[str, Any]:
    safe = job if isinstance(job, dict) else {}
    return {"schema": RESULT_SCHEMA, "revision": REVISION, "classification": "PENDING_GATE", "state": "HOLD_R15D_INPUT_OR_PROVIDER_GATE_FAILED", "caseId": safe.get("caseId"), "physicalIdentity": safe.get("physicalIdentity"), "eligibleIdentity": False, "referenceAdmissionEligible": False, "provenance": {"sources": {"bf": {"sha256": safe.get("inputs", {}).get("bf", {}).get("sha256"), "verified": False}, "df": {"sha256": safe.get("inputs", {}).get("df", {}).get("sha256"), "verified": False}}}, "artifacts": [], "failure": {"errorType": type(error).__name__, "detail": str(error)}, "holds": [{"code": "SCRIBE_GRID_DIAGNOSTIC_GATE_HOLD", "detail": "R15D failed closed and emitted no diagnostic raster."}], "authority": dict(SAFE_AUTHORITY)}


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    return parser.parse_args(list(argv))


def main(argv: Iterable[str]) -> int:
    args = parse_arguments(argv)
    job: dict[str, Any] | None = None
    try:
        job, job_sha256 = read_job(args.job.resolve())
        result, artifacts = run_case(job, args.job.resolve(), job_sha256)
        exit_code = 0
    except Exception as error:
        result, artifacts, exit_code = failure_result(job, error), {}, 2
    result_sha256 = commit_output(args.output_root.resolve(), result, artifacts)
    print(json.dumps({"state": result["state"], "caseId": result.get("caseId"), "caseResultSha256": result_sha256}))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
