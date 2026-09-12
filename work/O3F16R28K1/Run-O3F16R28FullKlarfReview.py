#!/usr/bin/env python3
"""Run frozen R27 candidate-first semantics on the frozen FRONT24 cohort.

This is a review-only diagnostic runner.  It uses the qualified L4 Q: alias
one pair at a time, contours BF and DF independently before reading the R6
secondary angle, and emits compact scalar metrics plus hashes instead of the
R27 per-candidate raster/JSON expansion.  It never writes XML or grants notch,
fiducial, registration, training, provider, or production authority.
"""

from __future__ import annotations

import argparse
import ast
from collections import Counter
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path, PureWindowsPath
import shutil
import sys
import tempfile
from typing import Any, Iterable

import cv2
import numpy as np


HERE = Path(__file__).resolve().parent
ADAPTER_NAME = "R28.py"
ADAPTER_PATH = HERE / ADAPTER_NAME
if not ADAPTER_PATH.is_file():
    ADAPTER_PATH = HERE.parent / "O3F8" / ADAPTER_NAME
L4_PATH = HERE / "Run-O3F15L4FrontReconcile.py"
if not L4_PATH.is_file():
    L4_PATH = HERE.parent / "OPENCV_EDGE_NOTCH_O3F15L4D3" / L4_PATH.name

R27_SHA256 = "0D6037F2DABFD682D404246F451B617FAE8E132F0BE3D26127C8C670466B71C8"
R18_SHA256 = "510F75463E8494A67442AEACBB7A16F71FE7B307EFEA9231F7CDD7FF6FE34317"
L4_SHA256 = "3C403376521B74E3A6DB1C4E008CE8DB36D8D99AE9A0FD7C1FA51481024DBEF4"
R11_SHA256 = "B477C290EC9D3AE388BE4EE31049B2B8094F5F30FC6E0DD68AB4A03926EE4059"
RUN_ROOT = Path(r"D:\O3F16R28K1C")
MIRROR_ROOT = Path(r"D:\O3F16R28K1S")
LOCKED_SOURCE_ROOT = PureWindowsPath(r"D:\KLARFExport")
EXPECTED_PAIR_COUNT = 24
MAX_OVERVIEW_COLUMNS = 4096
NATIVE_CROP_COLUMNS = 1024
MAX_REVIEW_CROPS_PER_CHANNEL = 1
MAX_CASE_JSON_BYTES = 2 * 1024 * 1024
MAX_PROGRESS_JSON_BYTES = 2 * 1024 * 1024
MAX_RESULTS_JSON_BYTES = 8 * 1024 * 1024
MAX_SOURCE_POPULATION_GATE_JSON_BYTES = 2 * 1024 * 1024
MAX_OVERVIEW_PNG_BYTES = 20 * 1024 * 1024
MAX_CROP_PNG_BYTES = 4 * 1024 * 1024
MAXIMUM_CASE_OUTPUT_BYTES = (
    MAX_CASE_JSON_BYTES
    + MAX_OVERVIEW_PNG_BYTES
    + 2 * MAX_REVIEW_CROPS_PER_CHANNEL * MAX_CROP_PNG_BYTES
)
MAXIMUM_LOGICAL_OUTPUT_BYTES = (
    EXPECTED_PAIR_COUNT * MAXIMUM_CASE_OUTPUT_BYTES
    + 2 * MAX_RESULTS_JSON_BYTES
    + 2 * MAX_PROGRESS_JSON_BYTES
    + 2 * MAX_SOURCE_POPULATION_GATE_JSON_BYTES
)
OUTPUT_SAFETY_RESERVE_BYTES = 32 * 1024**3
PROGRESS_RECENT_ROW_LIMIT = 20

CYAN = (255, 255, 0)
YELLOW = (0, 255, 255)
LIME = (0, 255, 0)
ORANGE = (0, 128, 255)
RED = (0, 0, 255)
WHITE = (255, 255, 255)

AUTHORITY_HOLDS = (
    "FRONTSIDE_NOTCH_ALIGNMENT_HOLD_REVIEW_ONLY_UNQUALIFIED",
    "PATTERNED_WAFER_FIDUCIAL_DESIGNATION_AND_ALIGNMENT_TRANSFER_REQUIRED",
    "REGISTRATION_AUTHORITY_NOT_GRANTED",
    "XML_KLARF_EXPORT_NOT_AUTHORIZED",
    "PRODUCTION_ROUTING_NOT_AUTHORIZED",
)

SCALAR_CANDIDATE_KEYS = (
    "candidateId", "candidateIndex", "channel", "state", "classification",
    "candidateDiscovery", "broadHalfPerimeterResponse", "angleSampleCount",
    "startAngleDegrees", "endAngleDegrees", "centerAngleDegrees", "widthDegrees",
    "rawComponentStartAngleDegrees", "rawComponentEndAngleDegrees",
    "rawComponentWidthDegrees", "shoulderSpanWidthDegrees", "maximumInwardDepthPx",
    "medianInwardDepthPx", "apexCount", "apexOffsetFraction",
    "leftMonotonicSupportFraction", "rightMonotonicSupportFraction",
    "postContourSymmetryScore", "postContourShapeTipOffsetFraction",
    "postContourShapeSlopeConsistencyFraction", "curvatureReversalCount",
    "extraCurvatureReversalFraction", "secondDifferenceAbsoluteP90Px",
    "leftShoulderReturnResidualFromNormalTracePx",
    "rightShoulderReturnResidualFromNormalTracePx", "rawDepthThresholdPx",
    "rawSupportedColumnCount", "rawSupportedFraction", "unsupportedColumnCount",
    "maximumContiguousUnsupportedRun", "componentSampleCount", "coreSampleCount",
    "strictCoreSeedCount", "supportGraphNodeCount", "supportGraphBranchColumnCount",
    "parallelBandColumnCount", "completeSupportGraphNodeCount",
    "representativePathObservedCount", "representativeNativeRadialTravelPx",
    "representativeParallelBandSwitchCount", "postHocAdjacentParallelBandSwitchCount",
    "allSelectedPixelsNativeSupported", "allSelectedPixelsRawPolaritySupported",
    "allSelectedPixelsDirectUnblurredPolaritySupported", "completeNativeShoulderPath",
    "boundedGapNativeShoulderPath", "gapFreeNativeShoulderPath",
    "nativeContourEvidenceQualified", "nativeContourShapeCompatibleAfterContour",
    "manufacturedCompatibleAfterContour", "diagnosticPairingEligible",
    "candidateLocalAuthorityEligibleBeforeGlobalHold", "notchOwnershipGranted",
    "morphologyPerformed", "interpolationPerformed", "templateOrIdealCurveUsed",
    "crossChannelPixelCoordinateTransferPerformed",
    "completeSupportGraphNativeNodesOrderedEvidenceSha256",
)


class R28CorpusError(RuntimeError):
    pass


def selected_population(context: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Bind all 24 pinned review-order cases to their frozen row and Q: plan."""
    ordered = context["cohorts"]["ordered978"]
    plans = context["plans"]
    need(len(ordered) == len(plans) == 978, "Frozen predecessor corpus cardinality changed")
    by_identity = {str(row["identity"]): (row, plan) for row, plan in zip(ordered, plans)}
    cases = context["cases"]
    need(len(cases) == EXPECTED_PAIR_COUNT, "Frozen FRONT24 review-order cardinality changed")
    selected = [by_identity[str(case["identity"])] for case in cases]
    rows = [item[0] for item in selected]
    selected_plans = [item[1] for item in selected]
    need(len({str(row["identity"]) for row in rows}) == EXPECTED_PAIR_COUNT, "Frozen FRONT24 identities changed")
    for case, row in zip(cases, rows):
        need(str(case["safeId"]) == str(row["safeId"]) and str(case["state"]) == str(row["r8State"]), "Frozen FRONT24 binding changed")
    return rows, selected_plans


def need(value: Any, message: str) -> None:
    if not value:
        raise R28CorpusError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def destination_outside_locked_source(path: Path) -> bool:
    candidate = PureWindowsPath(str(path))
    try:
        candidate.relative_to(LOCKED_SOURCE_ROOT)
        return False
    except ValueError:
        return candidate != LOCKED_SOURCE_ROOT


def canonical_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, allow_nan=False, ensure_ascii=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256_json(value: Any) -> str:
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest().upper()


def array_record(value: np.ndarray, population: str) -> dict[str, Any]:
    array = np.ascontiguousarray(value)
    return {
        "population": population,
        "dtype": str(array.dtype),
        "shape": [int(item) for item in array.shape],
        "sha256": hashlib.sha256(array.tobytes(order="C")).hexdigest().upper(),
    }


def import_path(path: Path, name: str) -> Any:
    need(path.is_file(), f"Missing dependency: {path}")
    spec = importlib.util.spec_from_file_location(name, path)
    need(spec is not None and spec.loader is not None, f"Cannot load dependency: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def require_post_write_reserve(path: Path, pending_bytes: int) -> None:
    need(pending_bytes >= 0, f"Negative pending write size: {path}")
    free = int(shutil.disk_usage(path.parent).free)
    need(
        free - pending_bytes >= OUTPUT_SAFETY_RESERVE_BYTES,
        f"R28 per-write 32 GiB reserve gate failed: {path}",
    )


def dependencies() -> tuple[Any, Any, Any, Any]:
    need(L4_PATH.is_file() and sha256_file(L4_PATH) == L4_SHA256, "Frozen L4 runner changed")
    adapter = import_path(ADAPTER_PATH, "argos_o3f16r28_portable_adapter")
    frozen = adapter.engine()
    need(adapter.R27_SHA256 == R27_SHA256, "R27 adapter binding changed")
    need(frozen.r18 is not None and sha256_file(Path(frozen.r18.__file__)) == R18_SHA256, "R18 binding changed")
    l4 = frozen.r18.r13.diagnostic.FRONT
    r11 = frozen.r18.r13.diagnostic.R11
    need(Path(l4.__file__).name == L4_PATH.name and sha256_file(Path(l4.__file__)) == L4_SHA256, "R18 did not bind frozen L4")
    need(sha256_file(Path(r11.__file__)) == R11_SHA256, "R18 did not bind frozen R11")
    return adapter, frozen, l4, r11


def atomic_json(path: Path, value: dict[str, Any], replace: bool = False) -> dict[str, Any]:
    data = canonical_json_bytes(value)
    maximum_bytes = {
        "PROGRESS.json": MAX_PROGRESS_JSON_BYTES,
        "RESULTS.json": MAX_RESULTS_JSON_BYTES,
        "SOURCE_POPULATION_GATE.json": MAX_SOURCE_POPULATION_GATE_JSON_BYTES,
    }.get(path.name, MAX_CASE_JSON_BYTES)
    need(len(data) <= maximum_bytes, f"Compact JSON cap exceeded: {path}")
    partial = path.with_name(path.name + ".partial")
    need(not partial.exists(), f"Partial JSON collision: {partial}")
    if not replace:
        need(not path.exists(), f"Create-new JSON collision: {path}")
    require_post_write_reserve(partial, len(data))
    partial.write_bytes(data)
    os.replace(partial, path)
    return {"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest().upper()}


def encode_png_new(path: Path, image: np.ndarray, maximum_bytes: int) -> dict[str, Any]:
    need(not path.exists(), f"Create-new PNG collision: {path}")
    ok, encoded = cv2.imencode(".png", image, [cv2.IMWRITE_PNG_COMPRESSION, 6])
    need(bool(ok), f"OpenCV PNG encoding failed: {path}")
    data = encoded.tobytes()
    need(len(data) <= maximum_bytes, f"Compact PNG cap exceeded: {path}")
    require_post_write_reserve(path, len(data))
    path.write_bytes(data)
    return {"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest().upper()}


def compact_candidate(trace: dict[str, Any]) -> dict[str, Any]:
    record = trace["record"]
    result = {key: record.get(key) for key in SCALAR_CANDIDATE_KEYS}
    result.update(
        {
            "classificationReasons": list(record.get("classificationReasons", [])),
            "evidenceHoldReasons": list(record.get("evidenceHoldReasons", [])),
            "authorityHoldReasons": list(record.get("authorityHoldReasons", [])),
            "postContourMorphologyReasons": list(record.get("postContourMorphologyReasons", [])),
            "representativePath": array_record(np.asarray(trace["path"]), "R27_NATIVE_REPRESENTATIVE_RADIAL_PATH"),
            "representativeObserved": array_record(np.asarray(trace["observed"], dtype=np.uint8), "R27_NATIVE_REPRESENTATIVE_OBSERVED_MAP"),
            "candidateSpan": array_record(np.asarray(trace["span"], dtype=np.int32), "R27_CANDIDATE_CIRCULAR_SPAN_COLUMNS"),
            "supportPointCount": len(trace.get("supportPoints", [])),
            "supportPointsCanonicalJsonSha256": sha256_json(trace.get("supportPoints", [])),
            "completeCandidateRecordCanonicalJsonSha256": sha256_json(record),
        }
    )
    need(result["notchOwnershipGranted"] is False, "R27 candidate improperly grants notch ownership")
    need(result["morphologyPerformed"] is False and result["interpolationPerformed"] is False, "R27 candidate processing contract changed")
    need(result["templateOrIdealCurveUsed"] is False and result["crossChannelPixelCoordinateTransferPerformed"] is False, "R27 native-pixel contract changed")
    if result["classification"] != "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE":
        need(result["diagnosticPairingEligible"] is False, "Chipout/unresolved candidate became pairing eligible")
    return result


def compact_channel(analysis: dict[str, Any], plan: dict[str, Any], channel: str) -> dict[str, Any]:
    candidates = [compact_candidate(trace) for trace in analysis["candidateTraces"]]
    evidence = analysis["evidence"]
    need(bool(evidence["candidateContouringCompletedBeforeNotchSelection"]), "Candidate contouring order changed")
    need(evidence["candidateDiscoveryMorphologyPerformed"] is False and evidence["interpolationPerformed"] is False, "Detector morphology/interpolation changed")
    need(evidence["templateOrIdealCurveUsed"] is False and evidence["crossChannelPixelCoordinateTransferPerformed"] is False, "Detector pixel contract changed")
    return {
        "channel": channel,
        "source": {
            "canonicalPath": str(plan[channel.lower()]["canonicalPath"]),
            "bytes": int(plan[channel.lower()]["bytes"]),
            "sha256": str(plan[channel.lower()]["sha256"]).upper(),
            "filesystemIoPathPersisted": False,
        },
        "baseFit": {key: float(analysis["baseFit"][key]) for key in ("centerX", "centerY", "radius")},
        "circleFit": analysis["circleFit"],
        "circleState": str(analysis["circleState"]),
        "circleQualified": bool(analysis["circleQualified"]),
        "cyanGeometryVerified": bool(analysis["cyanGeometryVerified"]),
        "cyanFixedOuterCircle": True,
        "yellowExactly20PxInward": float(evidence["yellowInwardPx"]) == 20.0,
        "candidateCount": len(candidates),
        "diagnosticManufacturedCandidateCount": sum(bool(row["diagnosticPairingEligible"]) for row in candidates),
        "candidates": candidates,
        "paths": {
            "outerCircle": array_record(np.asarray(analysis["outerPath"]), "FIXED_R18_OUTER_CIRCLE_CYAN"),
            "innerCircle": array_record(np.asarray(analysis["innerPath"]), "EXACT_20PX_INWARD_CIRCLE_YELLOW"),
            "normalBrightness": array_record(np.asarray(analysis["normalBrightnessPath"]), "CHANNEL_LOCAL_NATIVE_BRIGHTNESS_TRACE_LIME"),
            "normalBrightnessObserved": array_record(np.asarray(analysis["normalBrightnessObserved"], dtype=np.uint8), "CHANNEL_LOCAL_BRIGHTNESS_OBSERVED_MAP"),
            "predecessorHeld": array_record(np.asarray(analysis["predecessorHeldColumns"], dtype=np.uint8), "INHERITED_PREDECESSOR_HOLD_MAP"),
            "obstructionHeld": array_record(np.asarray(analysis["obstructionColumns"], dtype=np.uint8), "EXTERIOR_OBSTRUCTION_HOLD_MAP"),
        },
        "evidence": {
            "algorithm": evidence["algorithm"],
            "candidateDiscoveryPopulation": evidence["candidateDiscoveryPopulation"],
            "allStrictCoreNodesAccountedFor": bool(evidence["allStrictCoreNodesAccountedFor"]),
            "candidateContouringCompletedBeforeNotchSelection": True,
            "candidateDiscoverySmoothingPerformed": False,
            "candidateDiscoveryMorphologyPerformed": False,
            "candidateDiscoveryGapFillPerformed": False,
            "templateOrIdealCurveUsed": False,
            "interpolationPerformed": False,
            "crossChannelPixelCoordinateTransferPerformed": False,
            "predecessorHoldsCleared": False,
        },
    }


def draw_path(engine: Any, image: np.ndarray, path: np.ndarray, observed: np.ndarray, offsets: np.ndarray, color: tuple[int, int, int]) -> None:
    mask = np.zeros(image.shape[:2], dtype=np.uint8)
    engine.draw_native_points(image, mask, path, observed, offsets, color)


def channel_overlay(engine: Any, analysis: dict[str, Any]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    strip = np.asarray(analysis["strip"])
    offsets = np.asarray(analysis["offsets"])
    clean = cv2.cvtColor(engine.r18.shadow_lift(strip), cv2.COLOR_GRAY2BGR)
    image = clean.copy()
    mask = np.zeros(strip.shape, dtype=np.uint8)
    engine.r18.draw_circle_path(image, mask, analysis["outerPath"], offsets, CYAN)
    engine.r18.draw_circle_path(image, mask, analysis["innerPath"], offsets, YELLOW)
    draw_path(engine, image, analysis["normalBrightnessPath"], analysis["normalBrightnessObserved"], offsets, LIME)
    for trace in analysis["candidateTraces"]:
        record = trace["record"]
        color = RED if bool(record.get("diagnosticPairingEligible")) else ORANGE
        draw_path(engine, image, trace["path"], trace["observed"], offsets, color)
    changed = np.any(image != clean, axis=2)
    need(not bool(np.any(changed & (mask == 0))), "Annotated pixels escaped the exact contour mask")
    return clean, image, mask


def header(image: np.ndarray, text: str) -> np.ndarray:
    result = cv2.copyMakeBorder(image, 30, 0, 0, 0, cv2.BORDER_CONSTANT)
    cv2.putText(result, text, (7, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.42, WHITE, 1, cv2.LINE_8)
    return result


def decimate_columns(image: np.ndarray, maximum_columns: int) -> tuple[np.ndarray, int]:
    stride = max(1, int(math.ceil(image.shape[1] / maximum_columns)))
    return np.ascontiguousarray(image[:, ::stride]), stride


def candidate_crop(image: np.ndarray, record: dict[str, Any]) -> np.ndarray:
    width = image.shape[1]
    center = int(round(float(record["centerAngleDegrees"]) * width / 360.0)) % width
    half = NATIVE_CROP_COLUMNS // 2
    columns = np.arange(center - half, center + half, dtype=np.int64) % width
    return np.ascontiguousarray(image[:, columns])


def review_rank(trace: dict[str, Any]) -> tuple[int, float, str]:
    record = trace["record"]
    return (
        0 if bool(record.get("diagnosticPairingEligible")) else 1,
        -float(record.get("maximumInwardDepthPx") or 0.0),
        str(record.get("candidateId")),
    )


def render_bounded(case_root: Path, identity: str, engine: Any, analyses: dict[str, dict[str, Any]]) -> dict[str, Any]:
    full = {channel: channel_overlay(engine, analyses[channel]) for channel in ("BF", "DF")}
    decimated_clean: dict[str, np.ndarray] = {}
    decimated_overlay: dict[str, np.ndarray] = {}
    strides: dict[str, int] = {}
    for channel in ("BF", "DF"):
        decimated_clean[channel], strides[channel] = decimate_columns(full[channel][0], MAX_OVERVIEW_COLUMNS)
        decimated_overlay[channel], overlay_stride = decimate_columns(full[channel][1], MAX_OVERVIEW_COLUMNS)
        need(overlay_stride == strides[channel], "Clean/overlay decimation changed")
    common = min(decimated_clean["BF"].shape[1], decimated_clean["DF"].shape[1])
    overview = np.vstack(
        (
            header(decimated_clean["BF"][:, :common], "BF CLEAN: channel-local shadow-lift review pixels | no annotation"),
            header(decimated_overlay["BF"][:, :common], "BF OVERLAY: CYAN fixed outer | YELLOW -20 px | LIME brightness | RED manufactured | ORANGE held/non-notch"),
            header(decimated_clean["DF"][:, :common], "DF CLEAN: channel-local shadow-lift review pixels | no annotation"),
            header(decimated_overlay["DF"][:, :common], "DF OVERLAY: contours complete before pairing | same pixels/decimation as clean panel"),
        )
    )
    assets: dict[str, Any] = {
        "overview": encode_png_new(case_root / "PAIR_OVERVIEW.png", overview, MAX_OVERVIEW_PNG_BYTES),
        "overviewColumnDecimation": {"BF": strides["BF"], "DF": strides["DF"]},
        "overviewInterpolationPerformed": False,
        "overviewPanelOrder": ["BF_CLEAN", "BF_OVERLAY", "DF_CLEAN", "DF_OVERLAY"],
        "cleanReviewPixelLineage": "R18_CHANNEL_LOCAL_NATIVE_ANNULAR_STRIP_THEN_FIXED_SHADOW_LIFT",
        "overlayBasePixelLineage": "EXACT_SAME_CLEAN_REVIEW_PIXELS_AND_COLUMN_DECIMATION",
        "changedPixelsOutsideExactAnnotationMask": {channel: int(np.count_nonzero(np.any(full[channel][1] != full[channel][0], axis=2) & (full[channel][2] == 0))) for channel in ("BF", "DF")},
        "crops": [],
    }
    for channel in ("BF", "DF"):
        ranked = sorted(analyses[channel]["candidateTraces"], key=review_rank)
        for ordinal, trace in enumerate(ranked[:MAX_REVIEW_CROPS_PER_CHANNEL], 1):
            record = trace["record"]
            clean_crop = candidate_crop(full[channel][0], record)
            overlay_crop = candidate_crop(full[channel][1], record)
            crop = np.vstack(
                (
                    header(clean_crop, f"{channel} {record['candidateId']} CLEAN | exact native columns | no annotation"),
                    header(overlay_crop, f"{channel} {record['candidateId']} OVERLAY | CYAN/YELLOW/LIME geometry | RED manufactured | ORANGE held/non-notch"),
                )
            )
            asset = encode_png_new(case_root / f"{channel}_CROP_{ordinal}.png", crop, MAX_CROP_PNG_BYTES)
            asset.update({"channel": channel, "candidateId": record["candidateId"], "nativeColumns": NATIVE_CROP_COLUMNS, "panels": ["CLEAN", "OVERLAY"], "sameBasePixels": True, "interpolationPerformed": False})
            assets["crops"].append(asset)
    return assets


def r6_secondary_angle_after_contours(base: dict[str, Any]) -> float | None:
    selected = base.get("selectedReviewOnlyManufacturedNotch")
    if selected is None:
        return None
    need(isinstance(selected, dict), "R6 selected record changed")
    angle = float(selected["reviewAngleDegrees"])
    need(math.isfinite(angle), "R6 secondary angle is not finite")
    return angle


def validate_frozen_source_population(
    rows: list[dict[str, Any]],
    plans: list[dict[str, Any]],
    context: dict[str, Any],
) -> dict[str, Any]:
    """Hash-bind all 1,956 frozen leaves through Q: before the first decode."""
    need(len(rows) == len(plans) == EXPECTED_PAIR_COUNT, "Frozen source-validation cardinality changed")
    expected_records: list[dict[str, Any]] = []
    observed_records: list[dict[str, Any]] = []
    alias_lifecycle_records: list[dict[str, Any]] = []
    canonical_paths: set[str] = set()
    for ordinal, (row, plan) in enumerate(zip(rows, plans), 1):
        identity = str(row["identity"])
        need(identity == str(plan["identity"]) and ordinal == int(plan["ordinal"]), "Frozen source-validation order changed")
        for channel, key in (("BF", "bf"), ("DF", "df")):
            expected = row[key]
            record = {
                "ordinal": ordinal,
                "identity": identity,
                "channel": channel,
                "path": str(expected["path"]),
                "bytes": int(expected["bytes"]),
                "sha256": str(expected["sha256"]).upper(),
            }
            need(str(PureWindowsPath(record["path"])) == str(PureWindowsPath(str(plan[key]["canonicalPath"]))), f"{identity} {channel} frozen path changed")
            need(record["bytes"] == int(plan[key]["bytes"]), f"{identity} {channel} frozen byte count changed")
            need(record["sha256"] == str(plan[key]["sha256"]).upper(), f"{identity} {channel} frozen SHA-256 changed")
            canonical_key = str(PureWindowsPath(record["path"])).casefold()
            need(canonical_key not in canonical_paths, f"Duplicate frozen source path: {identity} {channel}")
            canonical_paths.add(canonical_key)
            expected_records.append(record)
        alias_evidence: dict[str, Any] = {}
        with context["o3f14"].owned_case_alias(plan, alias_evidence):
            for channel, key in (("BF", "bf"), ("DF", "df")):
                alias_path = Path(str(plan[key]["aliasPath"]))
                observed_bytes = alias_path.stat().st_size
                observed_sha256 = sha256_file(alias_path)
                need(observed_bytes == int(plan[key]["bytes"]), f"{identity} {channel} current byte count changed")
                need(observed_sha256 == str(plan[key]["sha256"]).upper(), f"{identity} {channel} current SHA-256 changed")
                observed_records.append(
                    {
                        "ordinal": ordinal,
                        "identity": identity,
                        "channel": channel,
                        "canonicalPath": str(plan[key]["canonicalPath"]),
                        "bytes": observed_bytes,
                        "sha256": observed_sha256,
                    }
                )
        need(bool(alias_evidence.get("ownedMappingRemoved")) and bool(alias_evidence.get("verifiedAbsentAfterRemove")), f"{identity} Q: lifecycle did not close")
        alias_lifecycle_records.append(
            {
                "ordinal": ordinal,
                "identity": identity,
                "exactTargetVerified": bool(alias_evidence.get("exactTargetVerified")),
                "aliasOnlyMetadataVerified": bool(alias_evidence.get("aliasOnlyMetadataVerified")),
                "ownedMappingRemoved": bool(alias_evidence.get("ownedMappingRemoved")),
                "verifiedAbsentAfterRemove": bool(alias_evidence.get("verifiedAbsentAfterRemove")),
            }
        )
    need(len(expected_records) == len(observed_records) == len(canonical_paths) == EXPECTED_PAIR_COUNT * 2, "Frozen FRONT24 leaf validation coverage changed")
    classification = context["actualFrozen978LexicalClassification"]
    return {
        "schema": "argos_ocv03_o3f16r28_frozen_source_population_gate_v1",
        "state": "PASS_O3F16R28_ALL_48_FRONT24_SOURCE_LEAVES_HASH_BOUND_BEFORE_DECODE",
        "pairCount": EXPECTED_PAIR_COUNT,
        "sourceLeafCount": len(observed_records),
        "uniqueCanonicalPathCount": len(canonical_paths),
        "orderedExpectedMetadataSha256": sha256_json(expected_records),
        "orderedObservedPathByteSha256": sha256_json(observed_records),
        "orderedAliasLifecycleSha256": sha256_json(alias_lifecycle_records),
        "frozenLexicalSourceRecordSha256": str(classification["orderedSourceLeafRecordSha256"]),
        "allCurrentPathsBytesAndSha256MatchedFrozenMetadataBeforeDecode": True,
        "sourceBytesReadForHashing": True,
        "imageDecodePerformedDuringValidation": False,
        "detectorExecutedDuringValidation": False,
        "sourceMutationPerformed": False,
    }


def process_one(ordinal: int, row: dict[str, Any], plan: dict[str, Any], context: dict[str, Any], case_root: Path, adapter: Any, engine: Any, l4: Any, r11: Any) -> dict[str, Any]:
    identity = str(row["identity"])
    safe_id = str(row["safeId"])
    alias_evidence: dict[str, Any] = {}
    params = r11.parameters_from_job(context["canonicalFixed"])
    crop = context["canonicalFixed"]["crop"]
    cfg = context["canonicalFixed"]["topologyConfig"]
    analyses: dict[str, dict[str, Any]] = {}
    with context["o3f14"].owned_case_alias(plan, alias_evidence):
        images: dict[str, np.ndarray] = {}
        for channel, key in (("BF", "bf"), ("DF", "df")):
            alias_path = Path(str(plan[key]["aliasPath"]))
            need(alias_path.is_file() and alias_path.stat().st_size == int(plan[key]["bytes"]), f"{identity} {channel} alias metadata changed")
            need(sha256_file(alias_path) == str(plan[key]["sha256"]).upper(), f"{identity} {channel} source hash changed")
            image = cv2.imread(str(alias_path), cv2.IMREAD_GRAYSCALE)
            need(image is not None, f"{identity} {channel} OpenCV decode failed")
            images[channel] = image
        base = r11.CORE.analyze_pair(safe_id, images["BF"], images["DF"], params)
        need("fit" in base.get("bf", {}) and "fit" in base.get("df", {}), f"{identity} independent channel fit failed")
        for channel, key in (("BF", "bf"), ("DF", "df")):
            fit = base[key]["fit"]
            measured = engine.r18.r13.unwrap(images[channel], fit, crop, params, cfg)
            analyses[channel] = adapter.analyze_native_strip(
                measured["strip"], measured["offsets"], fit, params, cfg,
                np.asarray(measured["pathMeasured"], dtype=bool), channel,
            )
        # First access to the R6 angle is after both complete candidate populations.
        r6_angle = r6_secondary_angle_after_contours(base)
        full_candidates = {
            channel: adapter.public_candidate_records(analyses[channel])
            for channel in ("BF", "DF")
        }
        pair = adapter.pair_after_channel_contours(
            full_candidates["BF"], full_candidates["DF"],
            analyses["BF"]["circleFit"], analyses["DF"]["circleFit"], params,
            r6_angle, analyses["BF"]["circleQualified"], analyses["DF"]["circleQualified"],
        )
        need(pair["channelContoursCompletedBeforePairing"] is True, "Pairing occurred before contours")
        need(pair["crossChannelPixelCoordinateTransferPerformed"] is False, "Pairing transferred pixels")
        need(pair["holdClearancePerformed"] is False and pair["productionSelectionPerformed"] is False, "Pairing widened authority")
        channels = {channel: compact_channel(analyses[channel], plan, channel) for channel in ("BF", "DF")}
        for resolved in pair["resolvedPairs"]:
            bf = channels["BF"]["candidates"][int(resolved["bfCandidateIndex"])]
            df = channels["DF"]["candidates"][int(resolved["dfCandidateIndex"])]
            need(bf["classification"] == df["classification"] == "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE", "Chipout was resolved as notch")
        assets = render_bounded(case_root, identity, engine, analyses)
    result = {
        "schema": "argos_ocv03_o3f16r28_compact_case_v1",
        "ordinal": ordinal,
        "identity": identity,
        "safeId": safe_id,
        "state": "COMPLETE_DIAGNOSTIC_ONLY_R28_CHANNEL_CONTOURS_AND_PAIRING",
        "priorR8State": str(row["r8State"]),
        "predecessorStateRetained": True,
        "channels": channels,
        "pairDiagnostic": pair,
        "r6SecondaryCorroboration": {
            "reviewAngleDegrees": r6_angle,
            "consumedOnlyAfterBothChannelCandidatePopulationsExisted": True,
            "primaryContourSelector": False,
            "candidatePairTieBreaker": False,
            "fixedSearchWindowDefined": False,
        },
        "notchOwnership": {
            "owned": False,
            "state": "HOLD_R28_REVIEW_ONLY_NOTCH_OWNERSHIP_NOT_GRANTED",
            "chipoutCanBeOwnedAsNotch": False,
            "diagnosticResolvedPairCount": int(pair["resolvedPairCount"]),
            "klarfExportAngleDegrees": None,
        },
        "aliasEvidence": alias_evidence,
        "assets": assets,
        "authorityHolds": list(AUTHORITY_HOLDS),
        "sourceMutationPerformed": False,
        "providerActivated": False,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
        "holdClearancePerformed": False,
        "reviewOnly": True,
    }
    case_record = atomic_json(case_root / "CASE.json", result)
    return {
        "ordinal": ordinal,
        "identity": identity,
        "safeId": safe_id,
        "state": result["state"],
        "priorR8State": result["priorR8State"],
        "bfCandidateCount": channels["BF"]["candidateCount"],
        "dfCandidateCount": channels["DF"]["candidateCount"],
        "diagnosticResolvedPairCount": int(pair["resolvedPairCount"]),
        "notchOwned": False,
        "case": case_record,
        "error": None,
    }


def progress(rows: list[dict[str, Any]], terminal: bool, state: str) -> dict[str, Any]:
    recent = rows[-PROGRESS_RECENT_ROW_LIMIT:]
    return {
        "schema": "argos_ocv03_o3f16r28_front24_progress_v1",
        "state": state,
        "scheduledCount": EXPECTED_PAIR_COUNT,
        "recordedCount": len(rows),
        "lastOrdinal": int(rows[-1]["ordinal"]) if rows else 0,
        "terminal": terminal,
        "recentRowLimit": PROGRESS_RECENT_ROW_LIMIT,
        "recentRows": recent,
        "resultPollingNotBeforeHoursAfterSubmission": 12,
        "immediateSignedLaunchResponseCollectionAllowed": True,
        "progressResultsProcessOrOcrObservationBeforeOwnTPlus12Allowed": False,
        "ownSubmissionTimestampRequiredToCalculateTPlus12": True,
        "ocrCompletionObserved": False,
        "executionSerializedBehindOcr": False,
        "retryAuthorized": False,
        "sourceMutationPerformed": False,
        "reviewOnly": True,
        "xmlEligible": False,
        "productionRoutingEnabled": False,
    }


def mirror_progress(output: Path, mirror: Path, value: dict[str, Any]) -> None:
    atomic_json(output / "PROGRESS.json", value, replace=(output / "PROGRESS.json").exists())
    atomic_json(mirror / "PROGRESS.json", value, replace=(mirror / "PROGRESS.json").exists())


def preflight() -> dict[str, Any]:
    adapter, engine, l4, r11 = dependencies()
    context = l4.preflight_context()
    rows, plans = selected_population(context)
    need(len(rows) == len(plans) == EXPECTED_PAIR_COUNT, "Frozen FRONT corpus cardinality changed")
    need(len({str(row["identity"]) for row in rows}) == EXPECTED_PAIR_COUNT, "Frozen FRONT identities changed")
    evidence = adapter.adapter_evidence()
    return {
        "schema": "argos_ocv03_o3f16r28_front24_preflight_v1",
        "state": "PASS_O3F16R28_FRONT24_PREFLIGHT",
        "scheduledCount": EXPECTED_PAIR_COUNT,
        "adapterState": evidence["state"],
        "r27Sha256": R27_SHA256,
        "r18Sha256": R18_SHA256,
        "l4Sha256": L4_SHA256,
        "r11Sha256": R11_SHA256,
        "sourceImageBytesRead": False,
        "existingTasksOrProcessesInspected": False,
        "mutationsPerformed": False,
        "ocrCompletionObserved": False,
        "executionSerializedBehindOcr": False,
        "reviewOnly": True,
    }


def run(output: Path, mirror: Path) -> dict[str, Any]:
    need(output == RUN_ROOT and mirror == MIRROR_ROOT, "R28 target roots changed")
    need(output != mirror, "R28 output and progress roots are not independent")
    need(destination_outside_locked_source(output) and destination_outside_locked_source(mirror), "R28 write destination enters locked KLARF source root")
    need(output.parent.is_dir() and not output.exists(), "R28 output root is not create-new")
    need(mirror.parent.is_dir() and not mirror.exists(), "R28 mirror root is not create-new")
    need(len(str(output)) + 80 < 200 and len(str(mirror)) + 80 < 200, "R28 output path budget failed")
    free = int(shutil.disk_usage(output.parent).free)
    need(free >= MAXIMUM_LOGICAL_OUTPUT_BYTES + OUTPUT_SAFETY_RESERVE_BYTES, "R28 output capacity/reserve gate failed")
    adapter, engine, l4, r11 = dependencies()
    context = l4.preflight_context()
    rows, plans = selected_population(context)
    need(len(rows) == len(plans) == EXPECTED_PAIR_COUNT, "Frozen FRONT corpus cardinality changed")
    output.mkdir()
    mirror.mkdir()
    cases = output / "cases"
    cases.mkdir()
    records: list[dict[str, Any]] = []
    mirror_progress(output, mirror, progress(records, False, "STARTED_O3F16R28_OWNED_WORKER_SOURCE_VALIDATION_PENDING"))
    blocker: str | None = None
    source_population_gate: dict[str, Any] | None = None
    source_population_gate_files: dict[str, Any] | None = None
    try:
        source_population_gate = validate_frozen_source_population(rows, plans, context)
        source_population_gate_files = {
            "output": atomic_json(output / "SOURCE_POPULATION_GATE.json", source_population_gate),
            "mirror": atomic_json(mirror / "SOURCE_POPULATION_GATE.json", source_population_gate),
        }
    except Exception as exc:
        blocker = f"{type(exc).__name__}: {str(exc)[:1600]}"
        mirror_progress(output, mirror, progress(records, False, "HOLD_O3F16R28_SOURCE_POPULATION_STOPPED_NO_RETRY"))
    if blocker is None:
        need(source_population_gate is not None, "Frozen source population gate is absent")
        mirror_progress(output, mirror, progress(records, False, "RUNNING_O3F16R28_FRONT24_AFTER_SOURCE_VALIDATION"))
    for ordinal, (row, plan) in enumerate(zip(rows, plans), 1) if blocker is None else ():
        case_root = cases / f"C{ordinal:04d}"
        case_root.mkdir()
        try:
            record = process_one(ordinal, row, plan, context, case_root, adapter, engine, l4, r11)
        except Exception as exc:
            blocker = f"{type(exc).__name__}: {str(exc)[:1600]}"
            record = {
                "ordinal": ordinal,
                "identity": str(row["identity"]),
                "safeId": str(row["safeId"]),
                "state": "HOLD_R28_ONE_UNCHANGED_ROUTE_OR_DETECTOR_FAILURE_STOPPED_EXECUTION",
                "notchOwned": False,
                "error": blocker,
            }
        records.append(record)
        mirror_progress(output, mirror, progress(records, False, "RUNNING_O3F16R28_FRONT24_AFTER_SOURCE_VALIDATION" if blocker is None else "HOLD_O3F16R28_FRONT24_STOPPED_NO_RETRY"))
        if blocker is not None:
            break
    complete = len(records) == EXPECTED_PAIR_COUNT and blocker is None
    result = {
        "schema": "argos_ocv03_o3f16r28_front24_results_v1",
        "state": "COMPLETE_O3F16R28_FRONT24_REVIEW_ONLY" if complete else "HOLD_O3F16R28_FRONT24_STOPPED_NO_RETRY",
        "scheduledCount": EXPECTED_PAIR_COUNT,
        "recordedCount": len(records),
        "unprocessedCount": EXPECTED_PAIR_COUNT - len(records),
        "stateCounts": dict(Counter(str(row["state"]) for row in records)),
        "blocker": blocker,
        "rows": records,
        "frozenSourcePopulationGate": source_population_gate,
        "frozenSourcePopulationGateFiles": source_population_gate_files,
        "all48SourceLeavesValidatedBeforeFirstDecode": bool(source_population_gate is not None),
        "r27Sha256": R27_SHA256,
        "compactOutput": {
            "maximumLogicalOutputBytes": MAXIMUM_LOGICAL_OUTPUT_BYTES,
            "safetyReserveBytes": OUTPUT_SAFETY_RESERVE_BYTES,
            "maximumOverviewColumns": MAX_OVERVIEW_COLUMNS,
            "maximumReviewCropsPerChannel": MAX_REVIEW_CROPS_PER_CHANNEL,
            "maximumSourcePopulationGateJsonBytes": MAX_SOURCE_POPULATION_GATE_JSON_BYTES,
            "perCandidateRasterWritten": False,
            "candidateMetricsAndNativePathHashesWritten": True,
        },
        "allNotchOwnershipHeld": all(row.get("notchOwned") is False for row in records),
        "authorityHolds": list(AUTHORITY_HOLDS),
        "resultPollingNotBeforeHoursAfterSubmission": 12,
        "immediateSignedLaunchResponseCollectionAllowed": True,
        "progressResultsProcessOrOcrObservationBeforeOwnTPlus12Allowed": False,
        "ownSubmissionTimestampRequiredToCalculateTPlus12": True,
        "ocrCompletionObserved": False,
        "executionSerializedBehindOcr": False,
        "automaticRetryAuthorized": False,
        "sourceMutationPerformed": False,
        "existingTasksOrProcessesInspected": False,
        "providerActivated": False,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
        "holdClearancePerformed": False,
        "reviewOnly": True,
    }
    atomic_json(output / "RESULTS.json", result)
    atomic_json(mirror / "RESULTS.json", result)
    mirror_progress(output, mirror, progress(records, True, result["state"]))
    return {key: result[key] for key in ("state", "scheduledCount", "recordedCount", "unprocessedCount", "blocker")}


def self_test() -> dict[str, Any]:
    synthetic = np.arange(12, dtype=np.float32).reshape(3, 4)
    record = array_record(synthetic, "SYNTHETIC")
    need(record["shape"] == [3, 4] and record["dtype"] == "float32", "Compact array record changed")
    image = np.zeros((5, 20, 3), dtype=np.uint8)
    decimated, stride = decimate_columns(image, 6)
    need(stride == 4 and decimated.shape == (5, 5, 3), "Decimation-only renderer changed")
    need(len(AUTHORITY_HOLDS) == 5 and "XML_KLARF_EXPORT_NOT_AUTHORIZED" in AUTHORITY_HOLDS, "Authority holds changed")
    theoretical = (
        EXPECTED_PAIR_COUNT * (20 + 2 * 4 + 2) * 1024**2
        + 2 * MAX_RESULTS_JSON_BYTES
        + 2 * MAX_PROGRESS_JSON_BYTES
        + 2 * MAX_SOURCE_POPULATION_GATE_JSON_BYTES
    )
    need(MAXIMUM_LOGICAL_OUTPUT_BYTES >= theoretical, "Declared output maximum is below per-file caps")
    sample_progress = progress([{"ordinal": index} for index in range(1, 25)], False, "SYNTHETIC")
    need(len(sample_progress["recentRows"]) == PROGRESS_RECENT_ROW_LIMIT and sample_progress["lastOrdinal"] == 24, "Progress mirror is not bounded")
    source_tree = ast.parse(Path(__file__).read_text(encoding="utf-8"))
    run_node = next(node for node in source_tree.body if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == "run")
    progress_calls = [
        node for node in ast.walk(run_node)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "mirror_progress"
    ]
    need(len(progress_calls) == 5, "Run progress-write call count changed")
    need(
        all(
            len(call.args) == 3
            and isinstance(call.args[0], ast.Name) and call.args[0].id == "output"
            and isinstance(call.args[1], ast.Name) and call.args[1].id == "mirror"
            for call in progress_calls
        ),
        "Run progress writes are not bound to both output roots",
    )
    with tempfile.TemporaryDirectory(prefix="argos_o3f16r28_progress_") as temporary:
        temporary_root = Path(temporary)
        test_output = temporary_root / "output"
        test_mirror = temporary_root / "mirror"
        test_output.mkdir()
        test_mirror.mkdir()
        mirror_progress(test_output, test_mirror, sample_progress)
        replacement_progress = progress([{"ordinal": 25}], True, "SYNTHETIC_COMPLETE")
        mirror_progress(test_output, test_mirror, replacement_progress)
        expected_progress_bytes = canonical_json_bytes(replacement_progress)
        need((test_output / "PROGRESS.json").read_bytes() == expected_progress_bytes, "Output progress atomic replacement failed")
        need((test_mirror / "PROGRESS.json").read_bytes() == expected_progress_bytes, "Mirror progress atomic replacement failed")
        need(not (test_output / "PROGRESS.json.partial").exists(), "Output progress partial remained")
        need(not (test_mirror / "PROGRESS.json.partial").exists(), "Mirror progress partial remained")
    return {
        "schema": "argos_ocv03_o3f16r28_full_front_self_test_v1",
        "state": "PASS_O3F16R28_COMPACT_RUNNER_SELF_TEST",
        "syntheticArraySha256": record["sha256"],
        "renderInterpolationPerformed": False,
        "maximumLogicalOutputBytes": MAXIMUM_LOGICAL_OUTPUT_BYTES,
        "theoreticalPerCaseCapBytes": theoretical,
        "perWritePostWriteReserveBytes": OUTPUT_SAFETY_RESERVE_BYTES,
        "runProgressCallCount": len(progress_calls),
        "dualRootAtomicProgressWriteExercised": True,
        "localEphemeralSelfTestWritesPerformed": True,
        "sourceImageBytesRead": False,
        "externalMutationsPerformed": False,
        "reviewOnly": True,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("SELF_TEST", "PREFLIGHT", "RUN"))
    parser.add_argument("--output-root")
    parser.add_argument("--mirror-root")
    args = parser.parse_args()
    if args.stage == "SELF_TEST":
        need(not args.output_root and not args.mirror_root, "SELF_TEST accepts no roots")
        result = self_test()
    elif args.stage == "PREFLIGHT":
        need(not args.output_root and not args.mirror_root, "PREFLIGHT accepts no roots")
        result = preflight()
    else:
        need(args.output_root and args.mirror_root, "RUN requires both roots")
        result = run(Path(args.output_root), Path(args.mirror_root))
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0 if str(result["state"]).startswith(("PASS_", "COMPLETE_")) else 2


if __name__ == "__main__":
    raise SystemExit(main())
