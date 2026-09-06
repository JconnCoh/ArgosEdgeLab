#!/usr/bin/env python3
"""R27 review-only successor to the frozen R26 candidate-first detector.

Inference and post-label evaluation are deliberately separate commands.  The
inference command never parses the scorer-only label.  It enumerates every
measured normal-trace interruption containing strict native core support,
    traces every candidate from channel-local native transition support, keeps
    the representative trace on one continuity-ranked native radial branch,
    records irregular responses without coercing them into a manufactured
    curve, and freezes the complete neutral population.

This module grants no production, provider, fiducial, registration, training,
XML, task/process, source-mutation, or hold-clearance authority.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from typing import Any, Iterable

import cv2
import numpy as np


HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parent.parent

CHECKPOINT_SHA256 = "F335161BD260AC602AA6E78D8B180F0A61A64BDAA0CFD97456BEF419AF633619"
ROLLOVER_MANIFEST_SHA256 = "7B05BF8F710E6DC684F71D62E19661C6D85F417397B8271E74828E0618DF2A2C"
ROLLOVER_GATE_SHA256 = "A65140C99AE76019DE6B5556CA9EA661E7B1162268A17928E27F487C4A6D5FFA"
SOURCE_JOB_SHA256 = "2C2D656A879BBA1DEC6377D1855A949459C7AC6F50145761B8D283076FEAD1F9"
GEOMETRY_JOB_SHA256 = "E384ABD12E9B77DB9B4492504A5D792E316C5396C3B0A3E1D2B1AB11BB4C7DD3"
SCORER_LABELS_SHA256 = "F8337BB2DDA12DBBA5769677C5A1A31E54CDD54659E0137F2EB9694EC2CCA668"
HOTSPOT_INPUT_SHA256 = "9EB2D63E2F677177B35EE9AD0EF4A35B3379E2B6845025ABB7D549E4FF1AEEA9"
HOTSPOT_ORACLE_SHA256 = "FEE52EC0EDE95F1C359071E5742B4596FC750F6DCAC29871892DCF5DA9F2EF32"
HOTSPOT_ORACLE_GATE_SHA256 = "B78DE5AF8C3633161AF2B565083B2526062F27425696B1BF9A4A9B4E76EBF6C6"
R18_BASELINE_SUMMARY_SHA256 = "3B7C3E32307351453F4F0F8A9146703F203B21906D619FE48252E8CAF78709B5"
R20_BASELINE_SUMMARY_SHA256 = "90FDD521B6322836692754FD88670BB9275EBE12E34F376C0D4B9996382411E6"
R21_SHA256 = "794F750078F323B99AB17802549ACBBBF61973380982F2A4D53A20E1FCE2C3F4"
R22_SHA256 = "CEC62EEBBF71B633D3371BD6AA5372F49E430110F4382BAC568167A1DDAA5C07"
R23_SHA256 = "E21FA14B88248AE9F50A2022A53FF4F7C7201E8B6DF74B3FAB3FD2DC475B360B"
R26_SHA256 = "FF5F339408E4D33A9F685DF710BC53D7B066B3667357FD07AD3F9299611E1C0E"
RUNTIME_SHA256 = "D70FCED7F461F38F9F224D8673FB74E96E4FACB4283FF4E8697543B457FEA8A0"
COMPACT_PATH = Path(r"C:\Windows\System32\compact.exe")
COMPACT_SHA256 = "2814B34FD2DF2113774034460CBE6ED20DB59A0A0C0F47CAAEE6EF0FC948E00C"
R22_SUMMARY_SHA256 = "9818ADAC53A39E969F9A368098E5842083475BE990B8AFF6D3850BD8152E1564"
R22_GATE_SHA256 = "8262ED3CB363377828D1037008E920182E594F2282A07EAD08F95FBD55970BF2"
R23_SUMMARY_SHA256 = "6A7D841E390B67D764BAB01CB6C653493653AB3DE6EB47CB73C65D318CD9ADB2"
R23_GATE_SHA256 = "BE0922CC30DE828AED88C38FFA715DE633CA173F68E3BC44B52F387CE79A6CB8"

R21_PATH = HERE / "AnnularUnwrapDiagnosticOpenCvR21.py"
R22_PATH = HERE / "AnnularUnwrapPost2ComparisonOpenCvR22.py"
R23_PATH = HERE / "AnnularUnwrapPost2HeldReviewOpenCvR23.py"
R26_PATH = HERE / "AnnularUnwrapCandidateFirstOpenCvR26.py"
EXTERNAL_R18_PATH = Path(r"C:\O3F16U16PROBE2\engine\AnnularUnwrapDiagnosticOpenCvR18.py")
R18_BASELINE_SUMMARY = Path(r"C:\O3F16U18LAB_DRAFT1\SUMMARY.json")
R20_BASELINE_SUMMARY = Path(r"C:\O3F16U20LAB_DRAFT1\SUMMARY.json")
R22_SUMMARY = Path(r"C:\O3F16U22P2_INFER_DRAFT1\SUMMARY.json")
R22_GATE = Path(r"C:\O3F16U22P2_INFER_DRAFT1\INFERENCE_GATE.json")
R23_SUMMARY = Path(r"C:\O3F16U23P2_HELD_REVIEW_DRAFT1\SUMMARY.json")
R23_GATE = Path(r"C:\O3F16U23P2_HELD_REVIEW_DRAFT1\REVIEW_GATE.json")
EXPECTED_INFERENCE_ROOT = Path(r"C:\O3F16U27P2_CANDIDATE_DRAFT1")

TRACE_SCHEMA = "argos_ocv03_annular_candidate_first_r27_native_trace_v1"
POPULATION_SCHEMA = "argos_ocv03_annular_candidate_first_r27_neutral_population_v1"
SUMMARY_SCHEMA = "argos_ocv03_annular_candidate_first_r27_inference_v1"
FREEZE_SCHEMA = "argos_ocv03_annular_candidate_first_r27_freeze_manifest_v1"
GATE_SCHEMA = "argos_ocv03_annular_candidate_first_r27_inference_gate_v1"
EVALUATION_SCHEMA = "argos_ocv03_annular_candidate_first_r27_post_label_evaluation_v1"

POST2_SEMANTIC_CHECK_KEYS = frozenset(
    {
        "threePost2MembersComplete",
        "allSixChannelCirclesQualified",
        "cyanOuterGeometryUnchanged",
        "yellowExactly20PxInward",
        "everyRawCandidateContouredBeforePairing",
        "everyQualifiedInterruptionBasinAndBroadHoldContoured",
        "allStrictCoreNodesAccountedFor",
        "allSelectedCandidatePixelsNativeAndRawSupported",
        "completePerCandidateContourMetricSchema",
        "sustainedShoulderGapSemanticsExact",
        "slot01Smooth90SeparateFromIrregular86",
        "slot01ExactlyOneDiagnosticNotchPairRemainsUnowned",
        "slot03Df90AndBfWhenSupportedUseNativeBrightness",
        "slot03ExactlyOneDiagnosticNotchPairRemainsUnowned",
        "slot17Df89p64ContourUsesNativeBrightness",
        "slot17DfOnlyDiagnosticIntervalTransfersZeroPixels",
        "slot17BroadBfResponseHeldWhole",
        "allDiagnosticNotchTracesHaveZeroAvoidableNativeRadialBandSwitches",
        "diagnosticNotchNeverGrantsAuthority",
        "noCandidateMorphologyOrInterpolation",
        "brightnessTraceRenderedOnCircleAndCandidateViews",
        "noCrossChannelPixelTransfer",
        "r6NeverSelectsAmongCandidatePairs",
        "allPredecessorHoldsRetained",
        "everyPost2PairAuthorityStateExactlyR22Hold",
        "everyPost2ResolvedAuthorityPairPopulationEmpty",
        "diagnosticPairRecordsPreservedOnlyAsUnownedEvidence",
        "authorityHeldDiagnosticCandidatesRemainLocalAuthorityIneligible",
        "everyPost2PairForbidsHoldClearanceAndProductionSelection",
        "sameChuckTransferIsAngleIntervalOnlyAndZeroPixels",
    }
)
INFERENCE_SEMANTIC_CHECK_KEYS = POST2_SEMANTIC_CHECK_KEYS | {
    "hotspotRegressionPreservesGoodContoursAndAllHolds",
    "completePerCandidateContourMetricSchemaAcrossAllFourteenChannels",
}
INFERENCE_INTEGRITY_CHECK_KEYS = frozenset(
    {
        "checkpointAndRolloverClosureExact",
        "sixBmpSourcesExactThroughAlias",
        "threePost2MembersAndFourHotspotCasesComplete",
        "allFourteenChannelPopulationsPresent",
        "neutralPopulationWrittenBeforeFreezeManifest",
        "freshOutputRootNtfsCompressionEnabledBeforeChildWrites",
        "allNeutralFilesHashed",
        "scorerLabelJsonUnparsed",
        "noMorphInterpolationIdealCurveOrPixelTransfer",
        "noSourceRuntimeProviderTaskOrPackageMutation",
    }
)

HASH_CHUNK_BYTES = 8 * 1024 * 1024
SHOULDER_WINDOW_SAMPLES = 9
MINIMUM_SHOULDER_SUPPORT_SAMPLES = 7
MINIMUM_PATH_COVERAGE_FRACTION = 0.90
MAXIMUM_UNSUPPORTED_RUN_SAMPLES = 1
MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE = 6.0
MINIMUM_RAW_CANDIDATE_FLOOR_PX = 8.0
MAXIMUM_RETURN_RESIDUAL_FROM_NORMAL_TRACE_PX = 8.0
MAXIMUM_SMOOTH_SECOND_DIFFERENCE_P90_PX = 4.0
MAXIMUM_EXTRA_CURVATURE_REVERSAL_FRACTION = 0.08
PARALLEL_BAND_SEPARATION_PX = 3.0
MINIMUM_SUSTAINED_STRICT_CORE_FORK_RUN_SAMPLES = 7
MINIMUM_SUSTAINED_STRICT_CORE_FORK_SPAN_FRACTION = 0.20
R6_SECONDARY_TOLERANCE_DEGREES = 0.8
CANDIDATE_REVIEW_HALF_WIDTH_COLUMNS = 512
CANDIDATE_REVIEW_HEADER_PX = 34
HOLD_BAR_ROWS = 3
PATH_COUNT_SATURATION = 1_000_001
PINNED_MANUFACTURED_THRESHOLD_PROFILE = {
    "manufacturedMinimumWidthDegrees": 0.9,
    "manufacturedMaximumWidthDegrees": 3.2,
    "manufacturedMaximumTipOffsetFraction": 0.70,
    "manufacturedMinimumSlopeConsistency": 0.55,
    "manufacturedMinimumSymmetry": 0.72,
}
SELF_CHECK_MANUFACTURED_THRESHOLD_PROFILE = {
    "manufacturedMinimumWidthDegrees": 1.0,
    "manufacturedMaximumWidthDegrees": 90.0,
    "manufacturedMaximumTipOffsetFraction": 0.70,
    "manufacturedMinimumSlopeConsistency": 0.55,
    "manufacturedMinimumSymmetry": 0.50,
}
EXPECTED_MAXIMUM_LOGICAL_OUTPUT_BYTES = 4 * 1024 ** 3
OUTPUT_SAFETY_RESERVE_BYTES = 8 * 1024 ** 3
MINIMUM_OUTPUT_FREE_BYTES = EXPECTED_MAXIMUM_LOGICAL_OUTPUT_BYTES + OUTPUT_SAFETY_RESERVE_BYTES
JSON_STREAM_CHUNK_CHARACTERS = 1024 * 1024
FILE_ATTRIBUTE_COMPRESSED = 0x00000800
CAPACITY_OBSERVED_R25_TRACE_COUNT = 25_984
CAPACITY_OBSERVED_R25_GENERATED_LOGICAL_BYTES = 8_592_816_253
CAPACITY_OBSERVED_R26_INTERRUPTION_BASIN_COUNT = 1_163
CAPACITY_PROJECTED_R27_MAXIMUM_OUTPUT_BYTES = EXPECTED_MAXIMUM_LOGICAL_OUTPUT_BYTES

CYAN = (255, 255, 0)
YELLOW = (0, 255, 255)
LIME = (0, 255, 0)
ORANGE = (0, 128, 255)
RED = (0, 0, 255)
MAGENTA = (255, 0, 255)
OBSTRUCTION_BLUE = (255, 80, 0)
WHITE = (255, 255, 255)


def need(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while True:
            block = stream.read(HASH_CHUNK_BYTES)
            if not block:
                break
            digest.update(block)
    return digest.hexdigest().upper()


def require_exact_file(path: Path, expected_sha256: str, label: str, size: int | None = None) -> None:
    need(path.is_file(), f"Missing {label}: {path}")
    if size is not None:
        need(path.stat().st_size == int(size), f"{label} byte count changed: {path}")
    need(sha256_file(path) == expected_sha256.upper(), f"{label} hash changed: {path}")


def file_record(path: Path, known_sha256: str | None = None) -> dict[str, Any]:
    need(path.is_file(), f"Cannot record missing file: {path}")
    actual = sha256_file(path)
    if known_sha256 is not None:
        need(actual == known_sha256.upper(), f"Recorded file hash changed: {path}")
    return {"path": str(path), "bytes": path.stat().st_size, "sha256": actual}


def require_output_write_reserve(path: Path, planned_logical_bytes: int) -> None:
    available = int(shutil.disk_usage(path.parent).free)
    need(
        available - int(planned_logical_bytes) >= OUTPUT_SAFETY_RESERVE_BYTES,
        f"R27 output write would cross the 8 GiB safety reserve: {path}",
    )


def write_bytes_new(path: Path, data: bytes) -> dict[str, Any]:
    need(path.parent.is_dir(), f"Output parent is missing: {path.parent}")
    need(len(path.name) <= 80, f"Output path component exceeds 80 characters: {path.name}")
    need(len(str(path)) < 200, f"Output path reaches the 200-character safety stop: {path}")
    require_output_write_reserve(path, len(data))
    with path.open("xb") as stream:
        stream.write(data)
    return file_record(path)


def write_json_new(path: Path, payload: dict[str, Any]) -> dict[str, Any]:
    need(path.parent.is_dir(), f"Output parent is missing: {path.parent}")
    need(len(path.name) <= 80, f"Output path component exceeds 80 characters: {path.name}")
    need(len(str(path)) < 200, f"Output path reaches the 200-character safety stop: {path}")
    encoder = json.JSONEncoder(
        sort_keys=True,
        allow_nan=False,
        ensure_ascii=True,
        separators=(",", ":"),
    )
    # Preserve the prior fail-before-create behavior for invalid JSON values
    # without materializing a multi-gigabyte string and byte array.
    planned_logical_bytes = 1
    for validation_chunk in encoder.iterencode(payload):
        planned_logical_bytes += len(validation_chunk.encode("utf-8"))
    require_output_write_reserve(path, planned_logical_bytes)
    pending: list[str] = []
    pending_characters = 0
    with path.open("xb") as stream:
        for chunk in encoder.iterencode(payload):
            pending.append(chunk)
            pending_characters += len(chunk)
            if pending_characters >= JSON_STREAM_CHUNK_CHARACTERS:
                stream.write("".join(pending).encode("utf-8"))
                pending.clear()
                pending_characters = 0
        if pending:
            stream.write("".join(pending).encode("utf-8"))
        stream.write(b"\n")
    return file_record(path)


def directory_is_ntfs_compressed(path: Path) -> bool:
    return bool(
        path.is_dir()
        and int(getattr(path.stat(), "st_file_attributes", 0)) & FILE_ATTRIBUTE_COMPRESSED
    )


def enable_fresh_output_compression(root: Path, free_bytes_before: int) -> dict[str, Any]:
    need(root.is_dir() and not any(root.iterdir()), "R27 compression target is not a fresh empty directory")
    require_exact_file(COMPACT_PATH, COMPACT_SHA256, "pinned Windows compact utility")
    completed = subprocess.run(
        [str(COMPACT_PATH), "/C", "/Q", str(root)],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=30,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    need(
        completed.returncode == 0,
        "Pinned compact utility failed before R27 child output: "
        + completed.stderr[-512:].decode("utf-8", errors="replace"),
    )
    attributes = int(getattr(root.stat(), "st_file_attributes", 0))
    need(attributes & FILE_ATTRIBUTE_COMPRESSED, "Fresh R27 root lacks the required NTFS compressed attribute")
    need(not any(root.iterdir()), "Pinned compact utility created unexpected R27 root content")
    return {
        "state": "PASS_R27_FRESH_RESULT_ROOT_NTFS_COMPRESSION_ENABLED",
        "root": str(root),
        "freeBytesBeforeRootCreation": int(free_bytes_before),
        "minimumRequiredFreeBytes": MINIMUM_OUTPUT_FREE_BYTES,
        "expectedMaximumLogicalOutputBytes": EXPECTED_MAXIMUM_LOGICAL_OUTPUT_BYTES,
        "untouchableSafetyReserveBytes": OUTPUT_SAFETY_RESERVE_BYTES,
        "capacityProjection": {
            "basis": "EXACT_FROZEN_R25_GENERATED_BYTES_WITH_HASH_LOCKED_R26_INTERRUPTION_BASIN_COUNT",
            "observedR25TraceCount": CAPACITY_OBSERVED_R25_TRACE_COUNT,
            "observedR25GeneratedLogicalBytes": CAPACITY_OBSERVED_R25_GENERATED_LOGICAL_BYTES,
            "observedR26InterruptionBasinCount": CAPACITY_OBSERVED_R26_INTERRUPTION_BASIN_COUNT,
            "r27MaximumLogicalOutputAllowanceBytes": CAPACITY_PROJECTED_R27_MAXIMUM_OUTPUT_BYTES,
            "filesystemCompressionSavingsCreditedToLogicalCapacityProjection": False,
            "everyOutputFileCheckedBeforeCreateAgainstSafetyReserve": True,
        },
        "compactCommand": [str(COMPACT_PATH), "/C", "/Q", str(root)],
        "compactExitCode": int(completed.returncode),
        "directoryFileAttributes": attributes,
        "directoryCompressedAttributeVerifiedBeforeChildWrites": True,
        "compressionTool": file_record(COMPACT_PATH, COMPACT_SHA256),
        "boundedCompressionHelperProcessStarted": True,
        "existingTaskOrProcessActionPerformed": False,
        "logicalFileBytesAndSha256UnaffectedByFilesystemCompression": True,
        "jsonEncoding": "UTF8_COMPACT_SORTED_KEYS_STREAMED_FINAL_LF",
    }


def write_png_new(path: Path, image: np.ndarray) -> dict[str, Any]:
    ok, encoded = cv2.imencode(".png", image)
    need(bool(ok), f"OpenCV PNG encode failed: {path}")
    return write_bytes_new(path, encoded.tobytes())


def safe_stem(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("._")
    return (cleaned[:20] or "case") + "_" + hashlib.sha256(value.encode("utf-8")).hexdigest()[:10]


def same_windows_path(left: Path, right: Path) -> bool:
    return str(left.absolute()).replace("/", "\\").rstrip("\\").casefold() == str(
        right.absolute()
    ).replace("/", "\\").rstrip("\\").casefold()


def preflight_output_layout(root: Path, identities: Iterable[str], evaluation: bool = False) -> None:
    components = {
        "neutral",
        "post2",
        "hotspot",
        "evaluation",
        "POST2_R27_POSTFREEZE_SAME_ANGLE_NATIVE_COMPARISON.png",
        "NEUTRAL_CANDIDATE_POPULATION.json",
        "FREEZE_MANIFEST.json",
        "INFERENCE_GATE.json",
        "REVIEW_GATE.json",
        "SUMMARY.json",
    }
    suffixes = (
        "_full_enhanced_clean.png",
        "_circle_brightness_review.png",
        "_all_candidate_contours_review.png",
        "_candidate_support_graph_mask.png",
        "_candidate_trace_mask.png",
        "_diagnostic_notch_mask.png",
        "_predecessor_hold_mask.png",
        "_obstruction_hold_mask.png",
        "_bf_c9999_obstruction_hold_mask.png",
        "_df_c9999_support_graph_mask.png",
    )
    for identity in identities:
        stem = safe_stem(str(identity))
        for suffix in suffixes:
            components.add(stem + suffix)
    longest_component = max(components, key=len)
    need(len(longest_component) <= 80, f"Planned output component exceeds 80 characters: {longest_component}")
    deepest = (
        root / "cases" / "P0001" / longest_component
        if evaluation
        else root / "neutral" / "hotspot" / "H0001" / longest_component
    )
    need(len(str(deepest)) < 200, f"Planned output path reaches the 200-character safety stop: {deepest}")


def configure_pinned_dependency_paths() -> None:
    requested = {
        "ARGOS_R18_ENGINE_PATH": EXTERNAL_R18_PATH,
        "ARGOS_R18_BASELINE_SUMMARY": R18_BASELINE_SUMMARY,
        "ARGOS_R20_BASELINE_SUMMARY": R20_BASELINE_SUMMARY,
    }
    for name, path in requested.items():
        existing = os.environ.get(name)
        if existing:
            need(Path(existing).resolve() == path.resolve(), f"{name} differs from the frozen R27 dependency path")
        os.environ[name] = str(path)


configure_pinned_dependency_paths()
require_exact_file(R21_PATH, R21_SHA256, "R21 engine")
SPEC = importlib.util.spec_from_file_location("argos_annular_r21_for_r27", R21_PATH)
need(SPEC is not None and SPEC.loader is not None, f"Cannot load {R21_PATH}")
r21 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = r21
SPEC.loader.exec_module(r21)
r18 = r21.r19.r18


def load_json_pinned(path: Path, expected_sha256: str, label: str) -> dict[str, Any]:
    require_exact_file(path, expected_sha256, label)
    value = json.loads(path.read_text(encoding="utf-8"))
    need(isinstance(value, dict), f"{label} is not a JSON object")
    return value


def assert_review_only(document: dict[str, Any], label: str) -> None:
    need(bool(document.get("reviewOnly")), f"{label} is not review-only")
    for key in (
        "trainingEligible",
        "xmlEligible",
        "productionEligible",
        "productionRoutingEnabled",
        "liveProviderActivation",
        "sourceMutationAllowed",
        "providerActivationAllowed",
        "processorActionAllowed",
        "holdClearanceAllowed",
    ):
        need(not bool(document.get(key)), f"{label} authority forbids {key}")


def set_from_indices(size: int, indices: Iterable[int]) -> np.ndarray:
    result = np.zeros(size, dtype=bool)
    values = np.asarray(list(indices), dtype=np.int64)
    if values.size:
        need(bool(np.all((values >= 0) & (values < size))), "Index lies outside frozen trace width")
        result[values] = True
    return result


def index_list(values: np.ndarray) -> list[int]:
    return [int(value) for value in np.flatnonzero(np.asarray(values, dtype=bool))]


def numeric_path(values: np.ndarray) -> list[float | None]:
    flat = np.asarray(values).reshape(-1)
    return [float(value) if math.isfinite(float(value)) else None for value in flat]


def longest_false_run(values: np.ndarray) -> int:
    best = current = 0
    for value in np.asarray(values, dtype=bool):
        current = 0 if bool(value) else current + 1
        best = max(best, current)
    return best


def linear_true_runs(values: np.ndarray) -> list[np.ndarray]:
    indices = np.flatnonzero(np.asarray(values, dtype=bool))
    if indices.size == 0:
        return []
    breaks = np.flatnonzero(np.diff(indices) > 1) + 1
    return [part for part in np.split(indices, breaks) if part.size]


def circular_distance_degrees(left: float, right: float) -> float:
    return abs((float(left) - float(right) + 180.0) % 360.0 - 180.0)


def circular_weighted_degrees(columns: np.ndarray, weights: np.ndarray, width: int) -> float:
    angles = np.asarray(columns, dtype=np.float64) * (2.0 * math.pi / width)
    positive = np.maximum(np.asarray(weights, dtype=np.float64), 1.0e-6)
    vector = np.sum(positive * np.exp(1j * angles))
    need(abs(vector) > 0.0, "Circular center vector is zero")
    return float(math.degrees(np.angle(vector)) % 360.0)


def ordered_span(left: int, right: int, width: int) -> np.ndarray:
    count = (int(right) - int(left)) % width + 1
    need(count <= width // 2, "Candidate shoulder span reaches at least half the perimeter")
    return (int(left) + np.arange(count, dtype=np.int64)) % width


def normal_trace_shoulder_window(
    normal_path: np.ndarray,
    normal_observed: np.ndarray,
    transition: dict[str, Any],
    boundary: int,
    direction: int,
    obstruction: np.ndarray,
) -> dict[str, Any]:
    width = int(normal_path.size)
    offsets = transition["searchOffsets"]
    support = transition["nativeSupported"]
    need(direction in (-1, 1), "Shoulder search direction differs")

    def measured_window(start_distance: int) -> dict[str, Any]:
        entries: list[dict[str, Any]] = []
        for distance in range(start_distance, start_distance + SHOULDER_WINDOW_SAMPLES):
            column = (int(boundary) + direction * distance) % width
            row: int | None = None
            native_supported = False
            if bool(normal_observed[column]) and math.isfinite(float(normal_path[column])):
                proposed = int(np.argmin(np.abs(offsets - float(normal_path[column]))))
                if abs(float(offsets[proposed]) - float(normal_path[column])) <= 1.0e-6:
                    row = proposed
                    native_supported = bool(support[proposed, column]) and not bool(obstruction[column])
            entries.append(
                {
                    "column": int(column),
                    "row": row,
                    "offsetPx": None if row is None else float(offsets[row]),
                    "distanceFromRawComponentSamples": distance,
                    "nativeNormalTraceSupported": native_supported,
                    "obstructionColumn": bool(obstruction[column]),
                }
            )
        flags = np.asarray(
            [bool(entry["nativeNormalTraceSupported"]) for entry in entries], dtype=bool
        )
        supported_count = int(np.count_nonzero(flags))
        maximum_missing = longest_false_run(flags)
        passed = bool(
            supported_count >= MINIMUM_SHOULDER_SUPPORT_SAMPLES
            and maximum_missing <= MAXIMUM_UNSUPPORTED_RUN_SAMPLES
        )
        anchor_entry = next(
            (entry for entry in entries if bool(entry["nativeNormalTraceSupported"])), None
        )
        anchor = (
            None
            if not passed or anchor_entry is None or anchor_entry["row"] is None
            else {
                "column": int(anchor_entry["column"]),
                "row": int(anchor_entry["row"]),
                "offsetPx": float(anchor_entry["offsetPx"]),
                "distanceFromRawComponentSamples": int(
                    anchor_entry["distanceFromRawComponentSamples"]
                ),
            }
        )
        return {
            "entries": entries,
            "supportedSampleCount": supported_count,
            "maximumContiguousUnsupportedRun": maximum_missing,
            "passed": passed and anchor is not None,
            "anchor": anchor,
            "windowStartDistanceSamples": int(start_distance),
        }

    # The first passing measured window wins.  The search cannot reach half a
    # revolution; a response that needs a farther shoulder is a broad hold.
    maximum_start = max(1, width // 2 - SHOULDER_WINDOW_SAMPLES + 1)
    selected: dict[str, Any] | None = None
    best_failed: dict[str, Any] | None = None
    searched = 0
    for start_distance in range(1, maximum_start + 1):
        candidate = measured_window(start_distance)
        searched += 1
        failed_rank = (
            int(candidate["supportedSampleCount"]),
            -int(candidate["maximumContiguousUnsupportedRun"]),
            -int(start_distance),
        )
        if best_failed is None or failed_rank > best_failed["rank"]:
            best_failed = {"rank": failed_rank, "window": candidate}
        if bool(candidate["passed"]):
            selected = candidate
            break
    if selected is None:
        need(best_failed is not None, "Shoulder search did not evaluate a window")
        selected = best_failed["window"]
        selected["anchor"] = None
        selected["passed"] = False
    entries = selected["entries"]
    supported_count = int(selected["supportedSampleCount"])
    return {
        "population": "NEAREST_SUSTAINED_NINE_NATIVE_NORMAL_TRACE_COLUMNS_OUTSIDE_CANDIDATE_BASIN",
        "direction": int(direction),
        "expectedSampleCount": SHOULDER_WINDOW_SAMPLES,
        "minimumSupportedSampleCount": MINIMUM_SHOULDER_SUPPORT_SAMPLES,
        "maximumContiguousUnsupportedRunAllowed": MAXIMUM_UNSUPPORTED_RUN_SAMPLES,
        "supportedSampleCount": supported_count,
        "supportedFraction": float(supported_count / SHOULDER_WINDOW_SAMPLES),
        "maximumContiguousUnsupportedRun": int(
            selected["maximumContiguousUnsupportedRun"]
        ),
        "searchedWindowCount": searched,
        "windowStartDistanceSamples": int(selected["windowStartDistanceSamples"]),
        "passed": bool(selected["passed"]),
        "entries": entries,
        "anchor": selected["anchor"],
    }


def native_row_bands(rows: Iterable[int]) -> list[np.ndarray]:
    values = np.asarray(sorted(set(int(row) for row in rows)), dtype=np.int64)
    if values.size == 0:
        return []
    breaks = np.flatnonzero(np.diff(values) > 1) + 1
    return [part for part in np.split(values, breaks) if part.size]


def coarse_native_row_bands(
    rows: Iterable[int], search_offsets: np.ndarray
) -> list[np.ndarray]:
    """Collapse thickness, but retain physically separated native branches."""
    merged: list[np.ndarray] = []
    for band in native_row_bands(rows):
        if (
            merged
            and native_band_separation_px(merged[-1], band, search_offsets)
            < PARALLEL_BAND_SEPARATION_PX
        ):
            merged[-1] = np.concatenate((merged[-1], band))
        else:
            merged.append(band.copy())
    return merged


def native_band_separation_px(
    left: np.ndarray,
    right: np.ndarray,
    search_offsets: np.ndarray,
) -> float:
    if int(left[-1]) < int(right[0]):
        return float(search_offsets[int(right[0])] - search_offsets[int(left[-1])])
    if int(right[-1]) < int(left[0]):
        return float(search_offsets[int(left[0])] - search_offsets[int(right[-1])])
    return 0.0


def native_position_candidate_shape(
    depths: np.ndarray,
    positions: np.ndarray,
    span_count: int,
) -> tuple[float, float, float, int]:
    """Measure shape on exact observed angular positions without gap filling."""
    need(
        depths.ndim == positions.ndim == 1
        and depths.size == positions.size
        and depths.size >= 2,
        "Native-position shape population is invalid",
    )
    need(
        bool(np.all(np.diff(positions) > 0))
        and int(positions[0]) >= 0
        and int(positions[-1]) < span_count,
        "Native-position shape coordinates are invalid",
    )
    maximum = float(np.max(depths))
    tip_index = int(np.argmax(depths))
    tip_position = int(positions[tip_index])
    center = (span_count - 1) / 2.0
    tip_offset = abs(tip_position - center) / max(center, 1.0)
    by_position = {
        int(position): float(depth)
        for position, depth in zip(positions, depths)
    }
    pair_differences = [
        abs(by_position[tip_position - distance] - by_position[tip_position + distance])
        for distance in range(0, min(tip_position, span_count - 1 - tip_position) + 1)
        if tip_position - distance in by_position
        and tip_position + distance in by_position
    ]
    symmetry_pair_count = len(pair_differences)
    symmetry = (
        max(0.0, 1.0 - float(np.mean(pair_differences)) / maximum)
        if symmetry_pair_count >= 2 and maximum > 0.0
        else 0.0
    )
    deltas = np.diff(positions.astype(np.float64))
    slopes = np.diff(depths.astype(np.float64)) / deltas
    left = slopes[positions[1:] <= tip_position]
    right = slopes[positions[:-1] >= tip_position]
    consistent = int(np.count_nonzero(left >= -0.5)) + int(
        np.count_nonzero(right <= 0.5)
    )
    slope_count = int(left.size + right.size)
    slope_consistency = float(consistent / slope_count) if slope_count else 0.0
    return symmetry, float(tip_offset), slope_consistency, symmetry_pair_count


def candidate_decision_thresholds(params: Any) -> dict[str, float | int]:
    return {
        "manufacturedMinimumWidthDegrees": float(
            params.manufactured_minimum_width_degrees
        ),
        "manufacturedMaximumWidthDegrees": float(
            params.manufactured_maximum_width_degrees
        ),
        "manufacturedMaximumTipOffsetFraction": float(
            params.manufactured_maximum_tip_offset_fraction
        ),
        "manufacturedMinimumSlopeConsistency": float(
            params.manufactured_minimum_slope_consistency
        ),
        "manufacturedMinimumSymmetry": float(
            params.manufactured_minimum_symmetry
        ),
        "minimumPathCoverageFraction": MINIMUM_PATH_COVERAGE_FRACTION,
        "maximumUnsupportedRunSamples": MAXIMUM_UNSUPPORTED_RUN_SAMPLES,
        "maximumRadialChangePxPerSample": MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE,
        "minimumRawPolarity": float(r18.MINIMUM_RAW_POLARITY),
        "maximumSmoothSecondDifferenceP90Px": (
            MAXIMUM_SMOOTH_SECOND_DIFFERENCE_P90_PX
        ),
        "maximumExtraCurvatureReversalFraction": (
            MAXIMUM_EXTRA_CURVATURE_REVERSAL_FRACTION
        ),
        "maximumReturnResidualFromNormalTracePx": (
            MAXIMUM_RETURN_RESIDUAL_FROM_NORMAL_TRACE_PX
        ),
    }


def transition_witness_summary(
    population: str,
    raw_values: np.ndarray,
    direct_raw_values: np.ndarray,
    enhanced_values: np.ndarray,
) -> dict[str, Any]:
    raw = np.asarray(raw_values, dtype=np.float64)
    direct = np.asarray(direct_raw_values, dtype=np.float64)
    enhanced = np.asarray(enhanced_values, dtype=np.float64)
    need(
        raw.ndim == direct.ndim == enhanced.ndim == 1
        and raw.size > 0
        and raw.size == direct.size == enhanced.size
        and bool(np.all(np.isfinite(raw)))
        and bool(np.all(np.isfinite(direct)))
        and bool(np.all(np.isfinite(enhanced))),
        "Native transition witness population differs",
    )
    ordered_evidence = np.column_stack((raw, direct, enhanced)).astype(
        ">f8", copy=False
    )
    return {
        "population": population,
        "count": int(raw.size),
        "orderedEvidenceSha256": hashlib.sha256(
            ordered_evidence.tobytes(order="C")
        ).hexdigest().upper(),
        "rawOutsideInMinimum": float(np.min(raw)),
        "rawOutsideInP10": float(np.percentile(raw, 10.0)),
        "rawOutsideInMedian": float(np.median(raw)),
        "enhancedOutsideInMinimum": float(np.min(enhanced)),
        "enhancedOutsideInP10": float(np.percentile(enhanced, 10.0)),
        "enhancedOutsideInMedian": float(np.median(enhanced)),
        "directUnblurredRawOutsideInMinimum": float(np.min(direct)),
        "directUnblurredRawOutsideInP10": float(np.percentile(direct, 10.0)),
        "directUnblurredRawOutsideInMedian": float(np.median(direct)),
        "directUnblurredRawPolaritySupportedFraction": float(
            np.mean(direct >= float(r18.MINIMUM_RAW_POLARITY))
        ),
    }


def complete_graph_ordered_evidence_sha256(
    node_records: list[dict[str, Any]],
) -> str:
    ordered_matrix = np.asarray(
        [
            [
                float(node["column"]),
                float(node["radialRow"]),
                float(node["offsetPx"]),
                float(node["directUnblurredRawOutsideInContrast"]),
                float(node["proposalSmoothedRawOutsideInContrast"]),
                float(node["enhancedOutsideInContrast"]),
            ]
            for node in node_records
        ],
        dtype=np.float64,
    ).reshape((-1, 6)).astype(">f8", copy=False)
    digest = hashlib.sha256(b"R27_COMPLETE_SUPPORT_GRAPH_NATIVE_NODES_V1\0")
    digest.update(len(node_records).to_bytes(8, byteorder="big", signed=False))
    digest.update(ordered_matrix.tobytes(order="C"))
    return digest.hexdigest().upper()


def recompute_coherent_core_corridors(
    *,
    angle_sample_count: int,
    span_columns: list[int],
    complete_node_records: list[dict[str, Any]],
    strict_core_node_records: list[dict[str, Any]],
    strict_core_seed_ids: list[str],
    strict_core_native_node_seed_ordinals: list[int],
    left_anchor: dict[str, Any] | None,
    right_anchor: dict[str, Any] | None,
    representative_path: list[dict[str, Any]],
) -> dict[str, Any]:
    """Recompute every corridor decision from compact serialized evidence."""
    columns = np.asarray([int(value) for value in span_columns], dtype=np.int64)
    seed_ids = [str(value) for value in strict_core_seed_ids]
    strict_nodes = [
        (int(node["column"]), int(node["radialRow"]))
        for node in strict_core_node_records
    ]
    seed_ordinals = [int(value) for value in strict_core_native_node_seed_ordinals]
    need(
        int(angle_sample_count) > 0
        and columns.size > 0
        and len(set(int(value) for value in columns)) == int(columns.size)
        and all(
            (int(columns[index]) - int(columns[index - 1]))
            % int(angle_sample_count)
            == 1
            for index in range(1, int(columns.size))
        ),
        "Corridor evidence span is not one ordered native interval",
    )
    need(
        bool(seed_ids)
        and len(seed_ids) == len(set(seed_ids))
        and len(strict_nodes) == len(set(strict_nodes))
        and len(seed_ordinals) == len(strict_nodes)
        and all(0 <= value < len(seed_ids) for value in seed_ordinals),
        "Corridor strict-core seed evidence differs",
    )
    seed_rows_by_id: dict[str, dict[int, list[int]]] = {
        seed_id: {} for seed_id in seed_ids
    }
    for (column, row), ordinal in zip(strict_nodes, seed_ordinals):
        seed_rows_by_id[seed_ids[ordinal]].setdefault(column, []).append(row)
    need(
        all(seed_rows_by_id[seed_id] for seed_id in seed_ids),
        "Corridor strict-core seed has no serialized native node",
    )
    for rows_by_column in seed_rows_by_id.values():
        for column in rows_by_column:
            rows_by_column[column] = sorted(set(rows_by_column[column]))

    unresolved = not representative_path
    if unresolved:
        need(
            not complete_node_records,
            "Unresolved corridor unexpectedly serializes a complete graph",
        )
        return {
            "coherentCoreCorridorSignatureCountSaturated": 0,
            "coherentCoarseBandRouteCountSaturated": 0,
            "uniqueCoherentNativeCoreCorridorSignature": False,
            "strictCoreSeedIdsInUniqueCoherentCorridorSignature": [],
            "strictCoreSeedIdsNotResolvedToUniqueCoherentCorridor": list(seed_ids),
            "allStrictCoreSeedsShareUniqueCoherentBandCorridor": False,
            "resolvedPhysicalCoreCorridorCountSaturated": 0,
            "uniqueResolvedPhysicalCoreCorridor": False,
            "strictCoreSeedIdsOnRepresentativePhysicalCorridor": [],
            "strictCoreSeedIdsNotOnRepresentativePhysicalCorridor": list(seed_ids),
            "coherentCoreCorridorDiagnostics": {
                "state": "NOT_MEASURABLE_UNRESOLVED_NO_COMPLETE_NATIVE_SHOULDER_PATH",
                "population": "NO_COMPLETE_CORE_VISITING_SHOULDER_PATH",
                "signatureSummaries": [],
                "divergentPositionCount": 0,
                "commonStrictCorePositionDifferentBandCount": 0,
                "maximumContiguousDivergentPositionRun": 0,
                "maximumCommonPositionCoarseBandSeparationPx": 0.0,
            },
        }

    position_by_column = {
        int(column): position for position, column in enumerate(columns)
    }
    nodes: list[list[int]] = [[] for _ in columns]
    row_offsets: dict[int, float] = {}
    complete_coordinates: list[tuple[int, int]] = []
    for node in complete_node_records:
        column = int(node["column"])
        row = int(node["radialRow"])
        offset = float(node["offsetPx"])
        need(
            column in position_by_column and row >= 0 and math.isfinite(offset),
            "Complete corridor node lies outside serialized native evidence",
        )
        if row in row_offsets:
            need(
                math.isclose(
                    row_offsets[row], offset, rel_tol=0.0, abs_tol=1.0e-6
                ),
                "One native radial row has inconsistent serialized offsets",
            )
        else:
            row_offsets[row] = offset
        nodes[position_by_column[column]].append(row)
        complete_coordinates.append((column, row))
    need(
        len(complete_coordinates) == len(set(complete_coordinates))
        and bool(row_offsets),
        "Complete corridor graph contains duplicate or absent coordinates",
    )
    nodes = [sorted(set(rows)) for rows in nodes]
    search_offsets = np.full(max(row_offsets) + 1, np.nan, dtype=np.float32)
    for row, offset in row_offsets.items():
        search_offsets[row] = np.float32(offset)

    need(
        left_anchor is not None
        and right_anchor is not None
        and int(left_anchor["column"]) == int(columns[0])
        and int(right_anchor["column"]) == int(columns[-1])
        and int(left_anchor["row"]) in nodes[0]
        and int(right_anchor["row"]) in nodes[-1],
        "Corridor endpoint evidence differs from its native span",
    )
    strict_core_set = set(strict_nodes)

    def is_core(position: int, row: int) -> bool:
        return (int(columns[position]), int(row)) in strict_core_set

    coarse_bands = [
        coarse_native_row_bands(rows, search_offsets) for rows in nodes
    ]

    def containing_band(position: int, row: int) -> int:
        matches = [
            index
            for index, band in enumerate(coarse_bands[position])
            if int(row) in band
        ]
        need(len(matches) == 1, "Native endpoint does not belong to one coarse band")
        return matches[0]

    def band_edge_exists(
        previous_position: int,
        previous_band: np.ndarray,
        position: int,
        current_band: np.ndarray,
    ) -> bool:
        delta = position - previous_position

        def connected(
            left_band: np.ndarray,
            right_band: np.ndarray,
            maximum_change: float,
        ) -> bool:
            return any(
                abs(
                    float(
                        search_offsets[int(right_row)]
                        - search_offsets[int(left_row)]
                    )
                )
                <= maximum_change + 1.0e-6
                for left_row in left_band
                for right_row in right_band
            )

        if not connected(
            previous_band,
            current_band,
            MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE * delta,
        ):
            return False
        if delta == 2:
            middle_position = previous_position + 1
            if any(
                connected(
                    previous_band,
                    middle_band,
                    MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE,
                )
                and connected(
                    middle_band,
                    current_band,
                    MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE,
                )
                for middle_band in coarse_bands[middle_position]
            ):
                return False
        return True

    def avoidable_band_switch(
        previous_position: int,
        previous_band: np.ndarray,
        position: int,
        current_band: np.ndarray,
    ) -> int:
        connected = [
            band
            for band in coarse_bands[position]
            if band_edge_exists(previous_position, previous_band, position, band)
        ]
        selected = native_band_separation_px(
            previous_band, current_band, search_offsets
        )
        closest = min(
            (
                native_band_separation_px(previous_band, band, search_offsets)
                for band in connected
            ),
            default=float("inf"),
        )
        return int(selected > closest + 1.0e-6)

    def band_intersects_seed(
        position: int, band: np.ndarray, seed_index: int
    ) -> bool:
        column = int(columns[position])
        rows = seed_rows_by_id[seed_ids[seed_index]].get(column, [])
        return any(int(row) in band for row in rows)

    def retain_fully_covered_seeds(
        mask: int,
        previous_position: int,
        position: int,
        band: np.ndarray,
    ) -> int:
        retained = int(mask)
        for seed_index, seed_id in enumerate(seed_ids):
            bit = 1 << seed_index
            if not retained & bit:
                continue
            rows_by_column = seed_rows_by_id[seed_id]
            for skipped_position in range(previous_position + 1, position):
                if rows_by_column.get(int(columns[skipped_position]), []):
                    retained &= ~bit
                    break
            if retained & bit:
                required_here = rows_by_column.get(int(columns[position]), [])
                if required_here and not band_intersects_seed(
                    position, band, seed_index
                ):
                    retained &= ~bit
        return retained

    def canonical_signature(
        signature: tuple[tuple[int, int], ...], seed_mask: int
    ) -> tuple[tuple[int, int], ...]:
        return tuple(
            token
            for token in signature
            if any(
                seed_mask & (1 << seed_index)
                and band_intersects_seed(
                    int(token[0]),
                    coarse_bands[int(token[0])][int(token[1])],
                    seed_index,
                )
                for seed_index in range(len(seed_ids))
            )
        )

    states: list[dict[tuple[int, int, int, int], dict[str, Any]]] = [
        {} for _ in columns
    ]
    left_band = containing_band(0, int(left_anchor["row"]))
    left_seed_mask = retain_fully_covered_seeds(
        (1 << len(seed_ids)) - 1,
        -1,
        0,
        coarse_bands[0][left_band],
    )
    left_signature_raw = (
        ((0, left_band),)
        if any(
            left_seed_mask & (1 << seed_index)
            and band_intersects_seed(0, coarse_bands[0][left_band], seed_index)
            for seed_index in range(len(seed_ids))
        )
        else ()
    )
    left_signature = canonical_signature(left_signature_raw, left_seed_mask)
    states[0][(left_band, left_seed_mask, 0, 0)] = {
        "count": 1,
        "coreSignatures": {left_signature},
    }
    for position in range(1, len(columns)):
        for band_index, band in enumerate(coarse_bands[position]):
            for delta in (1, 2):
                previous_position = position - delta
                if previous_position < 0:
                    continue
                for previous_key, previous_state in states[
                    previous_position
                ].items():
                    (
                        previous_band_index,
                        previous_seed_mask,
                        previous_gaps,
                        previous_switches,
                    ) = previous_key
                    previous_band = coarse_bands[previous_position][
                        previous_band_index
                    ]
                    if not band_edge_exists(
                        previous_position, previous_band, position, band
                    ):
                        continue
                    next_seed_mask = retain_fully_covered_seeds(
                        int(previous_seed_mask), previous_position, position, band
                    )
                    current_key = (
                        band_index,
                        next_seed_mask,
                        int(previous_gaps) + delta - 1,
                        min(
                            2,
                            int(previous_switches)
                            + avoidable_band_switch(
                                previous_position, previous_band, position, band
                            ),
                        ),
                    )
                    contribution = min(2, int(previous_state["count"]))
                    core_token = (
                        (position, band_index)
                        if any(
                            next_seed_mask & (1 << seed_index)
                            and band_intersects_seed(position, band, seed_index)
                            for seed_index in range(len(seed_ids))
                        )
                        else None
                    )
                    contribution_signatures = {
                        canonical_signature(signature, next_seed_mask)
                        + ((core_token,) if core_token is not None else ())
                        for signature in previous_state["coreSignatures"]
                    }
                    contribution_signatures = {
                        canonical_signature(signature, next_seed_mask)
                        for signature in contribution_signatures
                    }
                    existing = states[position].get(current_key)
                    if existing is None:
                        states[position][current_key] = {
                            "count": contribution,
                            "coreSignatures": set(
                                sorted(contribution_signatures)[:2]
                            ),
                        }
                    else:
                        existing["count"] = min(
                            2, int(existing["count"]) + contribution
                        )
                        existing["coreSignatures"] = set(
                            sorted(
                                set(existing["coreSignatures"])
                                | contribution_signatures
                            )[:2]
                        )

    right_band = containing_band(len(columns) - 1, int(right_anchor["row"]))
    finals = [
        (key, state)
        for key, state in states[-1].items()
        if key[0] == right_band
        and key[1] != 0
        and key[3] == 0
        and (len(columns) - key[2]) / len(columns)
        >= MINIMUM_PATH_COVERAGE_FRACTION
    ]
    signature_masks: dict[tuple[tuple[int, int], ...], int] = {}
    for key, state in finals:
        surviving_seed_mask = int(key[1])
        for raw_signature in state["coreSignatures"]:
            signature = canonical_signature(raw_signature, surviving_seed_mask)
            if signature:
                signature_masks[signature] = (
                    signature_masks.get(signature, 0) | surviving_seed_mask
                )
    signatures = sorted(signature_masks)[:2]
    coarse_route_count = min(
        2, sum(int(state["count"]) for _, state in finals)
    )
    signature_count = min(2, len(signatures))
    unique_seed_mask = (
        int(signature_masks[signatures[0]]) if len(signatures) == 1 else 0
    )
    signature_summaries = [
        {
            "sha256": hashlib.sha256(
                json.dumps(signature, separators=(",", ":")).encode("ascii")
            ).hexdigest().upper(),
            "strictCoreTokenCount": len(signature),
            "firstPosition": None if not signature else int(signature[0][0]),
            "lastPosition": None if not signature else int(signature[-1][0]),
            "survivingStrictCoreSeedIds": [
                seed_ids[index]
                for index in range(len(seed_ids))
                if signature_masks[signature] & (1 << index)
            ],
        }
        for signature in signatures
    ]
    divergence_positions: list[int] = []
    common_different_positions: list[int] = []
    maximum_separation = 0.0
    if len(signatures) == 2:
        left_by_position = {
            int(position): int(band) for position, band in signatures[0]
        }
        right_by_position = {
            int(position): int(band) for position, band in signatures[1]
        }
        for position in sorted(set(left_by_position) | set(right_by_position)):
            left_index = left_by_position.get(position)
            right_index = right_by_position.get(position)
            if left_index == right_index:
                continue
            divergence_positions.append(position)
            if left_index is not None and right_index is not None:
                common_different_positions.append(position)
                maximum_separation = max(
                    maximum_separation,
                    native_band_separation_px(
                        coarse_bands[position][left_index],
                        coarse_bands[position][right_index],
                        search_offsets,
                    ),
                )
    divergence_flags = np.zeros(len(columns), dtype=bool)
    if divergence_positions:
        divergence_flags[np.asarray(divergence_positions, dtype=np.int64)] = True
    divergence_runs = [
        int(run.size) for run in r18.CORE.group_circular_true(divergence_flags)
    ]

    complete_strict_positions: list[int] = []
    strict_parallel_positions: list[int] = []
    for position, bands in enumerate(coarse_bands):
        strict_band_count = sum(
            any(is_core(position, int(row)) for row in band) for band in bands
        )
        if strict_band_count:
            complete_strict_positions.append(position)
        if strict_band_count >= 2:
            strict_parallel_positions.append(position)
    strict_parallel_flags = np.zeros(len(columns), dtype=bool)
    if strict_parallel_positions:
        strict_parallel_flags[
            np.asarray(strict_parallel_positions, dtype=np.int64)
        ] = True
    strict_parallel_runs: list[int] = []
    current_run = 0
    for value in strict_parallel_flags:
        if bool(value):
            current_run += 1
        elif current_run:
            strict_parallel_runs.append(current_run)
            current_run = 0
    if current_run:
        strict_parallel_runs.append(current_run)
    maximum_strict_parallel_run = max(strict_parallel_runs, default=0)
    strict_core_span_samples = (
        int(complete_strict_positions[-1] - complete_strict_positions[0] + 1)
        if complete_strict_positions
        else 0
    )
    strict_parallel_span_fraction = (
        float(maximum_strict_parallel_run / strict_core_span_samples)
        if strict_core_span_samples
        else 0.0
    )
    sustained_physical_fork = bool(
        maximum_strict_parallel_run
        >= MINIMUM_SUSTAINED_STRICT_CORE_FORK_RUN_SAMPLES
        and strict_parallel_span_fraction
        >= MINIMUM_SUSTAINED_STRICT_CORE_FORK_SPAN_FRACTION
    )
    resolved_physical_count = (
        0
        if signature_count == 0 or not complete_strict_positions
        else 2
        if sustained_physical_fork
        else 1
    )
    need(
        not finals or signature_count > 0,
        "A core-visiting complete coarse route lost its strict-core signature",
    )

    unique_seed_ids = [
        seed_id
        for index, seed_id in enumerate(seed_ids)
        if signature_count == 1 and unique_seed_mask & (1 << index)
    ]
    unique_seed_set = set(unique_seed_ids)
    representative_seed_set: set[str] = set()
    if resolved_physical_count >= 1:
        for node in representative_path:
            column = int(node["column"])
            row = int(node["radialRow"])
            need(column in position_by_column, "Representative corridor column differs")
            position = position_by_column[column]
            band_index = containing_band(position, row)
            band = coarse_bands[position][band_index]
            for seed_index, seed_id in enumerate(seed_ids):
                if band_intersects_seed(position, band, seed_index):
                    representative_seed_set.add(seed_id)
    representative_seed_ids = [
        seed_id for seed_id in seed_ids if seed_id in representative_seed_set
    ]
    diagnostics = {
        "population": "AT_MOST_TWO_CANONICAL_FULLY_COVERED_STRICT_CORE_NATIVE_POSITION_COARSE_BAND_SIGNATURES",
        "signatureSummaries": signature_summaries,
        "divergentPositionCount": len(divergence_positions),
        "commonStrictCorePositionDifferentBandCount": len(
            common_different_positions
        ),
        "maximumContiguousDivergentPositionRun": max(divergence_runs, default=0),
        "maximumCommonPositionCoarseBandSeparationPx": float(maximum_separation),
        "rawExactCanonicalSignatureCountSaturated": int(signature_count),
        "rawExactCoarseRouteCountSaturated": int(coarse_route_count),
        "completeStrictCorePositionCount": len(complete_strict_positions),
        "completeStrictCoreSpanSamples": strict_core_span_samples,
        "parallelStrictCorePositionCount": len(strict_parallel_positions),
        "maximumContiguousParallelStrictCoreRunSamples": (
            maximum_strict_parallel_run
        ),
        "parallelStrictCoreRunFractionOfCompleteCoreSpan": (
            strict_parallel_span_fraction
        ),
        "minimumSustainedForkRunSamples": (
            MINIMUM_SUSTAINED_STRICT_CORE_FORK_RUN_SAMPLES
        ),
        "minimumSustainedForkSpanFraction": (
            MINIMUM_SUSTAINED_STRICT_CORE_FORK_SPAN_FRACTION
        ),
        "sustainedPhysicalStrictCoreFork": sustained_physical_fork,
        "resolvedPhysicalCorridorCountSaturated": resolved_physical_count,
        "resolutionRule": (
            "ONE_PHYSICAL_CORRIDOR_UNLESS_TWO_OR_MORE_COMPLETE_STRICT_CORE_"
            "COARSE_BANDS_PERSIST_FOR_BOTH_FROZEN_RUN_AND_SPAN_FRACTION"
        ),
    }
    return {
        "coherentCoreCorridorSignatureCountSaturated": signature_count,
        "coherentCoarseBandRouteCountSaturated": coarse_route_count,
        "uniqueCoherentNativeCoreCorridorSignature": signature_count == 1,
        "strictCoreSeedIdsInUniqueCoherentCorridorSignature": unique_seed_ids,
        "strictCoreSeedIdsNotResolvedToUniqueCoherentCorridor": [
            seed_id for seed_id in seed_ids if seed_id not in unique_seed_set
        ],
        "allStrictCoreSeedsShareUniqueCoherentBandCorridor": bool(seed_ids)
        and signature_count == 1
        and len(unique_seed_ids) == len(seed_ids),
        "resolvedPhysicalCoreCorridorCountSaturated": resolved_physical_count,
        "uniqueResolvedPhysicalCoreCorridor": resolved_physical_count == 1,
        "strictCoreSeedIdsOnRepresentativePhysicalCorridor": (
            representative_seed_ids
        ),
        "strictCoreSeedIdsNotOnRepresentativePhysicalCorridor": [
            seed_id
            for seed_id in seed_ids
            if seed_id not in representative_seed_set
        ],
        "coherentCoreCorridorDiagnostics": diagnostics,
    }


def column_band_nodes(
    transition: dict[str, Any],
    column: int,
    forced_rows: set[int],
) -> tuple[list[int], dict[int, int]]:
    support = transition["nativeSupported"][:, column]
    direct_raw = transition["directRawContrast"][:, column]
    raw = transition["rawContrast"][:, column]
    enhanced = transition["enhancedContrast"][:, column]
    rows = np.flatnonzero(support)
    if rows.size == 0:
        return [], {}
    bands = native_row_bands(rows)
    selected: list[int] = []
    ordinals: dict[int, int] = {}
    for ordinal, band in enumerate(bands):
        forced = [value for value in forced_rows if int(band[0]) <= value <= int(band[-1])]
        if forced:
            row = int(sorted(forced)[0])
        else:
            row = max(
                (int(value) for value in band),
                key=lambda value: (
                    float(direct_raw[value]),
                    float(enhanced[value]),
                    float(raw[value]),
                    -value,
                ),
            )
        selected.append(row)
        ordinals[row] = ordinal
    return selected, ordinals


def candidate_graph_trace(
    strip: np.ndarray,
    offsets: np.ndarray,
    outer_path: np.ndarray,
    normal_path: np.ndarray,
    normal_observed: np.ndarray,
    transition: dict[str, Any],
    component_info: dict[str, Any],
    threshold: float,
    params: Any,
    candidate_index: int,
    channel: str,
    obstruction: np.ndarray,
    predecessor_held: np.ndarray,
) -> dict[str, Any]:
    width = int(outer_path.size)
    degrees_per_sample = 360.0 / width
    component = np.asarray(component_info["component"], dtype=np.int64)
    component_rows = {
        int(column): sorted(set(int(row) for row in rows))
        for column, rows in component_info["componentRows"].items()
    }
    core_rows = {
        int(column): set(int(row) for row in rows)
        for column, rows in component_info["coreRows"].items()
    }
    core_columns = sorted(core_rows)
    need(component.size > 0 and core_columns, "R27 candidate component is empty")
    left_window = normal_trace_shoulder_window(
        normal_path, normal_observed, transition, int(component[0]), -1, obstruction
    )
    right_window = normal_trace_shoulder_window(
        normal_path, normal_observed, transition, int(component[-1]), 1, obstruction
    )
    left_anchor = left_window["anchor"]
    right_anchor = right_window["anchor"]
    empty_path = np.full(width, np.nan, dtype=np.float32)
    empty_observed = np.zeros(width, dtype=bool)
    search_offsets = np.asarray(transition["searchOffsets"], dtype=np.float32)
    need(
        search_offsets.ndim == 1
        and search_offsets.size >= 2
        and bool(np.all(np.isfinite(search_offsets))),
        "R27 native search-offset geometry is invalid",
    )
    search_offset_pitch = float(search_offsets[1] - search_offsets[0])
    need(
        search_offset_pitch > 0.0
        and bool(
            np.allclose(
                np.diff(search_offsets.astype(np.float64)),
                search_offset_pitch,
                rtol=0.0,
                atol=1.0e-6,
            )
        ),
        "R27 native search offsets are not one uniform native grid",
    )
    raw_nodes = [
        {
            "column": column,
            "radialRow": row,
            "offsetPx": float(search_offsets[row]),
            "directUnblurredRawOutsideInContrast": float(
                transition["directRawContrast"][row, column]
            ),
            "proposalSmoothedRawOutsideInContrast": float(
                transition["rawContrast"][row, column]
            ),
            "enhancedOutsideInContrast": float(
                transition["enhancedContrast"][row, column]
            ),
        }
        for column in sorted(component_rows)
        for row in component_rows[column]
    ]
    component_native_points = [
        (int(node["column"]), int(node["radialRow"])) for node in raw_nodes
    ]
    seed_ids = [str(value) for value in component_info.get("strictCoreSeedIds", [])]
    seed_rows_by_id = component_info.get("strictCoreRowsBySeed", {})
    strict_core_node_records = [
        {"column": int(column), "radialRow": int(row)}
        for column in sorted(core_rows)
        for row in sorted(core_rows[column])
    ]
    strict_core_native_node_seed_ordinals: list[int] = []
    for node in strict_core_node_records:
        matching_ordinals = [
            index
            for index, seed_id in enumerate(seed_ids)
            if int(node["radialRow"])
            in {
                int(value)
                for value in seed_rows_by_id.get(seed_id, {}).get(
                    int(node["column"]), []
                )
            }
        ]
        need(
            len(matching_ordinals) == 1,
            "Strict-core native node does not belong to exactly one seed",
        )
        strict_core_native_node_seed_ordinals.append(matching_ordinals[0])
    raw_component_witness = transition_witness_summary(
        "ALL_RAW_COMPONENT_R18_NATIVE_TRANSITION_NODES",
        np.asarray(
            [node["proposalSmoothedRawOutsideInContrast"] for node in raw_nodes],
            dtype=np.float64,
        ),
        np.asarray(
            [node["directUnblurredRawOutsideInContrast"] for node in raw_nodes],
            dtype=np.float64,
        ),
        np.asarray(
            [node["enhancedOutsideInContrast"] for node in raw_nodes],
            dtype=np.float64,
        ),
    )
    broad_parent = bool(component_info.get("broadHalfPerimeterResponse"))
    reporting_center = (
        float(((int(component[0]) + (component.size - 1) / 2.0) % width) * degrees_per_sample)
        if broad_parent
        else circular_weighted_degrees(
            np.asarray(core_columns, dtype=np.int64),
            np.ones(len(core_columns), dtype=np.float64),
            width,
        )
    )
    base: dict[str, Any] = {
        "candidateIndex": candidate_index,
        "candidateId": f"{channel}_C{candidate_index + 1:04d}",
        "channel": channel,
        "angleSampleCount": width,
        "algorithm": "FULL_NATIVE_SUPPORT_GRAPH_WITH_CONTINUITY_FIRST_DIRECT_RAW_REPRESENTATIVE_PATH",
        "candidateDiscovery": str(
            component_info.get(
                "candidateDefinition",
                "UNSMOOTHED_UNMORPHED_STRICT_NATIVE_CORE_COMPONENT",
            )
        ),
        "normalTraceInterruptionBasinIndex": component_info.get(
            "normalTraceInterruptionBasinIndex"
        ),
        "normalTraceInterruptionBasinColumnIndices": list(
            component_info.get("normalTraceInterruptionBasinColumnIndices", [])
        ),
        "strictCoreSeedIds": seed_ids,
        "strictCoreSeedCount": len(seed_ids),
        "broadParentHoldIds": list(component_info.get("broadParentHoldIds", [])),
        "multiBasinStrictCoreSeedIds": list(
            component_info.get("multiBasinStrictCoreSeedIds", [])
        ),
        "componentColumnIndices": [int(value) for value in component],
        "coreColumnIndices": core_columns,
        "strictCoreNativeNodes": strict_core_node_records,
        "strictCoreNativeNodeSeedOrdinals": (
            strict_core_native_node_seed_ordinals
        ),
        "rawComponentNativeNodes": raw_nodes,
        "componentSampleCount": int(component.size),
        "coreSampleCount": sum(len(rows) for rows in core_rows.values()),
        "rawComponentStartAngleDegrees": float(component[0] * degrees_per_sample),
        "rawComponentEndAngleDegrees": float(component[-1] * degrees_per_sample),
        "rawComponentWidthDegrees": float(component.size * degrees_per_sample),
        "startAngleDegrees": float(component[0] * degrees_per_sample),
        "endAngleDegrees": float(component[-1] * degrees_per_sample),
        "widthDegrees": float(component.size * degrees_per_sample),
        "ownershipIntervalBasis": "RAW_COMPONENT_ONLY_UNTIL_NATIVE_SHOULDER_PATH_COMPLETES",
        "centerAngleDegrees": reporting_center,
        "centerAngleRole": "REPORTING_ONLY_NEVER_TRAVERSAL_OR_CANDIDATE_OWNERSHIP",
        "rawDepthThresholdPx": float(threshold),
        "candidateDecisionThresholds": candidate_decision_thresholds(params),
        "nativeSearchOffsetMinimumPx": float(search_offsets[0]),
        "nativeSearchOffsetMaximumPx": float(search_offsets[-1]),
        "nativeSearchOffsetPitchPx": search_offset_pitch,
        "nativeSearchOffsetRowCount": int(search_offsets.size),
        "leftShoulderWindow": left_window,
        "rightShoulderWindow": right_window,
        "leftAnchor": left_anchor,
        "rightAnchor": right_anchor,
        "broadHalfPerimeterResponse": broad_parent,
        "templateOrIdealCurveUsed": False,
        "candidateCenterUsedByTraversal": False,
        "monotonicityUsedByTraversal": False,
        "morphologyPerformed": False,
        "interpolationPerformed": False,
        "syntheticCoordinateCount": 0,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "manufacturedCompatibleAfterContour": False,
        "nativeContourShapeCompatibleAfterContour": False,
        "nativeContourEvidenceQualified": False,
        "gapFreeNativeShoulderPath": False,
        "boundedGapNativeShoulderPath": False,
        "diagnosticPairingEligible": False,
        "candidateLocalAuthorityEligibleBeforeGlobalHold": False,
        "notchOwnershipGranted": False,
    }

    def strict_core_bands_outside_complete_graph(
        full_points: Iterable[tuple[int, int]],
        complete_points: Iterable[tuple[int, int]],
    ) -> tuple[list[dict[str, Any]], list[str]]:
        full_rows_by_column: dict[int, set[int]] = {}
        complete_rows_by_column: dict[int, set[int]] = {}
        for column, row in full_points:
            full_rows_by_column.setdefault(int(column), set()).add(int(row))
        for column, row in complete_points:
            complete_rows_by_column.setdefault(int(column), set()).add(int(row))
        excluded: list[dict[str, Any]] = []
        implicated: set[str] = set()
        seed_rows = component_info.get("strictCoreRowsBySeed", {})
        for column in sorted(core_rows):
            complete_at_column = complete_rows_by_column.get(int(column), set())
            for band_index, band in enumerate(
                coarse_native_row_bands(
                    full_rows_by_column.get(int(column), set()), search_offsets
                )
            ):
                band_rows = {int(row) for row in band}
                strict_rows = sorted(band_rows & core_rows[int(column)])
                if not strict_rows or band_rows & complete_at_column:
                    continue
                band_seed_ids = sorted(
                    str(seed_id)
                    for seed_id, rows_by_column in seed_rows.items()
                    if band_rows
                    & {
                        int(row)
                        for row in rows_by_column.get(int(column), [])
                    }
                )
                implicated.update(band_seed_ids)
                excluded.append(
                    {
                        "column": int(column),
                        "coarseBandIndex": int(band_index),
                        "minimumRadialRow": int(band[0]),
                        "maximumRadialRow": int(band[-1]),
                        "strictCoreRadialRows": strict_rows,
                        "strictCoreSeedIds": band_seed_ids,
                    }
                )
        return excluded, sorted(implicated)

    def held_result(state: str, reasons: list[str], support_points: list[tuple[int, int]] | None = None,
                    span: np.ndarray | None = None) -> dict[str, Any]:
        points = sorted(set(component_native_points if support_points is None else support_points))
        selected_span = np.asarray(component.copy() if span is None else span, dtype=np.int64)
        need(bool(points) and selected_span.size > 0, "Held candidate lost its native component population")
        span_set = {int(column) for column in selected_span}
        need(
            all(int(column) in span_set for column, _ in points),
            "Held candidate support lies outside its declared metric/review span",
        )
        supported_columns = {int(column) for column, _ in points}
        span_supported = np.asarray(
            [int(column) in supported_columns for column in selected_span], dtype=bool
        )
        unsupported_columns = [
            int(selected_span[index]) for index in np.flatnonzero(~span_supported)
        ]
        point_depths = np.asarray(
            [float(outer_path[column] - search_offsets[row]) for column, row in points],
            dtype=np.float64,
        )
        point_native_raw = np.asarray(
            [float(transition["rawContrast"][row, column]) for column, row in points],
            dtype=np.float64,
        )
        point_direct_raw = np.asarray(
            [float(transition["directRawContrast"][row, column]) for column, row in points],
            dtype=np.float64,
        )
        point_enhanced = np.asarray(
            [float(transition["enhancedContrast"][row, column]) for column, row in points],
            dtype=np.float64,
        )
        excluded_core_bands, excluded_core_seed_ids = (
            strict_core_bands_outside_complete_graph(points, [])
        )

        def shoulder_measurement(anchor: dict[str, Any] | None) -> tuple[float | None, float | None, float | None, str]:
            if anchor is None:
                return None, None, None, "NOT_MEASURABLE_UNRESOLVED_MISSING_NATIVE_SHOULDER"
            column = int(anchor["column"])
            row = int(anchor["row"])
            if not bool(normal_observed[column]) or not math.isfinite(float(normal_path[column])):
                return None, None, None, "NOT_MEASURABLE_UNRESOLVED_NORMAL_TRACE_ABSENT"
            shoulder_depth = float(outer_path[column] - search_offsets[row])
            normal_depth = float(outer_path[column] - normal_path[column])
            return (
                shoulder_depth,
                normal_depth,
                abs(shoulder_depth - normal_depth),
                "MEASURED_NATIVE_SHOULDER_TO_SAME_FIXED_OUTER_CIRCLE",
            )

        left_depth, left_normal_depth, left_residual, left_state = shoulder_measurement(left_anchor)
        right_depth, right_normal_depth, right_residual, right_state = shoulder_measurement(right_anchor)
        obstruction_overlap_columns = [
            int(column) for column in selected_span if bool(obstruction[int(column)])
        ]
        inherited_overlap_columns = [
            int(column) for column in selected_span if bool(predecessor_held[int(column)])
        ]
        authority_reasons = list(component_info.get("discoveryAuthorityHoldReasons", []))
        if obstruction_overlap_columns:
            authority_reasons.append("EXTERIOR_OBSTRUCTION_OWNERSHIP_OVERLAP")
        if inherited_overlap_columns:
            authority_reasons.append("INHERITED_PREDECESSOR_HOLD_OVERLAP")
        authority_reasons = list(dict.fromkeys(authority_reasons))
        point_rows_by_column: dict[int, list[int]] = {}
        for column, row in points:
            point_rows_by_column.setdefault(int(column), []).append(int(row))
        for column in point_rows_by_column:
            point_rows_by_column[column] = sorted(set(point_rows_by_column[column]))
        band_counts: list[int] = []
        parallel_band_columns = 0
        for column in sorted(point_rows_by_column):
            rows = np.asarray(point_rows_by_column[column], dtype=np.int64)
            band_count = 0 if rows.size == 0 else int(np.count_nonzero(np.diff(rows) > 1) + 1)
            band_counts.append(band_count)
            if band_count >= 2:
                breaks = np.flatnonzero(np.diff(rows) > 1)
                separations = [
                    float(search_offsets[int(rows[index + 1])] - search_offsets[int(rows[index])])
                    for index in breaks
                ]
                if max(separations, default=0.0) >= PARALLEL_BAND_SEPARATION_PX:
                    parallel_band_columns += 1
        unresolved_path_state = "NOT_MEASURABLE_UNRESOLVED_NO_COMPLETE_NATIVE_SHOULDER_PATH"
        base.update(
            {
                "state": state,
                "classification": "UNRESOLVED_DEEP_EDGE_RESPONSE",
                "classificationReasons": reasons + authority_reasons,
                "evidenceHoldReasons": reasons,
                "authorityHoldReasons": authority_reasons,
                "postContourMorphologyReasons": [],
                "completeNativeShoulderPath": False,
                "gapFreeNativeShoulderPath": False,
                "boundedGapNativeShoulderPath": False,
                "nativeContourEvidenceQualified": False,
                "nativeContourShapeCompatibleAfterContour": False,
                "shoulderEndpointsConnectedByNativeGraph": False,
                "expectedSpanColumnCount": int(selected_span.size),
                "supportMetricPopulation": "DECLARED_NATIVE_CANDIDATE_SPAN_NO_FILL",
                "supportMetricSpanColumnIndices": [int(column) for column in selected_span],
                "tracedShoulderColumnIndices": [],
                "representativePathObservedCount": 0,
                "rawSupportedColumnCount": int(np.count_nonzero(span_supported)),
                "rawSupportedFraction": float(np.mean(span_supported)),
                "maximumContiguousUnsupportedRun": longest_false_run(span_supported),
                "unsupportedColumnCount": int(np.count_nonzero(~span_supported)),
                "unsupportedColumnIndices": unsupported_columns,
                "discoveredComponentNativeColumnCount": len(component_rows),
                "representativePathComponentColumnCount": 0,
                "discoveredComponentCoverageFraction": 0.0,
                "obstructionOverlapColumnIndices": obstruction_overlap_columns,
                "obstructionOverlapColumnCount": len(obstruction_overlap_columns),
                "inheritedPredecessorHoldOverlapColumnIndices": inherited_overlap_columns,
                "inheritedPredecessorHoldOverlapColumnCount": len(inherited_overlap_columns),
                "leftShoulderDepthFromFixedOuterCirclePx": left_depth,
                "rightShoulderDepthFromFixedOuterCirclePx": right_depth,
                "leftNormalBrightnessTraceDepthFromFixedOuterCirclePx": left_normal_depth,
                "rightNormalBrightnessTraceDepthFromFixedOuterCirclePx": right_normal_depth,
                "leftShoulderReturnResidualFromNormalTracePx": left_residual,
                "rightShoulderReturnResidualFromNormalTracePx": right_residual,
                "shoulderSpanWidthDegrees": (
                    float(selected_span.size * degrees_per_sample)
                    if left_anchor is not None and right_anchor is not None
                    else None
                ),
                "maximumInwardDepthPx": float(np.max(point_depths)),
                "medianInwardDepthPx": float(np.median(point_depths)),
                "apexCount": None,
                "apexBandMinimumDepthPx": None,
                "apexPopulation": unresolved_path_state,
                "apexOffsetFraction": None,
                "postContourShapeTipOffsetFraction": None,
                "leftMonotonicSupportFraction": None,
                "rightMonotonicSupportFraction": None,
                "postContourShapeSlopeConsistencyFraction": None,
                "postContourSymmetryScore": None,
                "postContourSymmetryExactNativePairCount": None,
                "maximumAdjacentRadialChangePxPerSample": None,
                "firstDifferenceAbsoluteMedianPx": None,
                "firstDifferenceAbsoluteP90Px": None,
                "firstDifferencePopulation": unresolved_path_state,
                "secondDifferenceAbsoluteMedianPx": None,
                "secondDifferenceAbsoluteP90Px": None,
                "secondDifferenceAbsoluteMaximumPx": None,
                "secondDifferencePopulation": unresolved_path_state,
                "slopeDirectionReversalCount": None,
                "curvatureReversalCount": None,
                "curvatureReversalPopulation": unresolved_path_state,
                "extraCurvatureReversalFraction": None,
                "supportGraphNodeCount": len(points),
                "fullCandidateNativeGraphNodeCount": len(points),
                "completeSupportGraphNodeCount": 0,
                "fullCandidateNativeGraphNodes": [
                    {"column": int(column), "radialRow": int(row)}
                    for column, row in points
                ],
                "strictCoreNodeCountOutsideCompleteShoulderGraph": len(
                    base["strictCoreNativeNodes"]
                ),
                "strictCoreNativeNodesOutsideCompleteShoulderGraph": list(
                    base["strictCoreNativeNodes"]
                ),
                "rawComponentNativeNodeCountOutsideCompleteShoulderGraph": len(
                    raw_nodes
                ),
                "rawComponentNativeNodesOutsideCompleteShoulderGraph": list(
                    {"column": int(column), "radialRow": int(row)}
                    for column, row in component_native_points
                ),
                "strictCoreOutsideCompleteShoulderGraphDisposition": (
                    "EXPLICIT_EVIDENCE_HOLD_NO_COMPLETE_CORE_VISITING_SHOULDER_PATH"
                ),
                "strictCoreCoarseBandCountOutsideCompleteShoulderGraph": len(
                    excluded_core_bands
                ),
                "strictCoreCoarseBandsOutsideCompleteShoulderGraph": excluded_core_bands,
                "strictCoreSeedIdsWithCoarseBandOutsideCompleteShoulderGraph": (
                    excluded_core_seed_ids
                ),
                "supportGraphBranchColumnCount": int(
                    sum(len(rows) > 1 for rows in point_rows_by_column.values())
                ),
                "parallelBandColumnCount": parallel_band_columns,
                "maximumCompleteBandCountPerColumn": max(band_counts, default=0),
                "representativeParallelBandSwitchCount": None,
                "postHocAdjacentParallelBandSwitchCount": None,
                "representativeNativeRadialTravelPx": None,
                "representativeSelectionRankOrder": (
                    "ZERO_AVOIDABLE_BAND_SWITCHES_THEN_SUPPORTED_COUNT_THEN_GAPS_"
                    "THEN_NATIVE_RADIAL_TRAVEL_THEN_DIRECT_RAW_THEN_ENHANCED_THEN_RAW"
                ),
                "reachableShoulderPathCountSaturated": 0,
                "reachableShoulderPathCountSaturationValue": PATH_COUNT_SATURATION,
                "coherentCoreCorridorSignatureCountSaturated": 0,
                "coherentCoreCorridorSignatureCountSaturationValue": 2,
                "coherentCoarseBandRouteCountSaturated": 0,
                "coherentCoarseBandRouteCountSaturationValue": 2,
                "uniqueCoherentNativeCoreCorridorSignature": False,
                "strictCoreSeedIdsInUniqueCoherentCorridorSignature": [],
                "strictCoreSeedIdsNotResolvedToUniqueCoherentCorridor": list(
                    base["strictCoreSeedIds"]
                ),
                "allStrictCoreSeedsShareUniqueCoherentBandCorridor": False,
                "resolvedPhysicalCoreCorridorCountSaturated": 0,
                "resolvedPhysicalCoreCorridorCountSaturationValue": 2,
                "uniqueResolvedPhysicalCoreCorridor": False,
                "strictCoreSeedIdsOnRepresentativePhysicalCorridor": [],
                "strictCoreSeedIdsNotOnRepresentativePhysicalCorridor": list(
                    base["strictCoreSeedIds"]
                ),
                "coherentCoreCorridorDiagnostics": {
                    "state": unresolved_path_state,
                    "population": "NO_COMPLETE_CORE_VISITING_SHOULDER_PATH",
                    "signatureSummaries": [],
                    "divergentPositionCount": 0,
                    "commonStrictCorePositionDifferentBandCount": 0,
                    "maximumContiguousDivergentPositionRun": 0,
                    "maximumCommonPositionCoarseBandSeparationPx": 0.0,
                },
                "selectedTransitionWitness": {
                    "state": unresolved_path_state,
                    "population": "NO_REPRESENTATIVE_PATH_SELECTED",
                    "count": 0,
                },
                "rawComponentTransitionWitness": dict(raw_component_witness),
                "gradientNormalAlignmentPostContourMeasurement": {
                    "state": "NOT_REQUIRED_FOR_R27_NATIVE_RAW_POLARITY_CONTOUR",
                    "selectionRole": False,
                },
                "allSelectedPixelsNativeSupported": bool(
                    all(transition["nativeSupported"][row, column] for column, row in points)
                ),
                "allSelectedPixelsRawPolaritySupported": bool(
                    np.all(point_native_raw >= float(r18.MINIMUM_RAW_POLARITY))
                ),
                "allSelectedPixelsDirectUnblurredPolaritySupported": bool(
                    np.all(point_direct_raw >= float(r18.MINIMUM_RAW_POLARITY))
                ),
                "inwardLimitTouchCount": int(
                    sum(
                        math.isclose(float(search_offsets[row]), float(search_offsets[0]), abs_tol=1.0e-6)
                        for _, row in points
                    )
                ),
                "representativePath": [],
                "completeSupportGraphNativeNodesOrderedEvidenceSha256": (
                    complete_graph_ordered_evidence_sha256([])
                ),
                "completeSupportGraphNativeNodes": [],
                "metricAvailability": {
                    "nativeSupport": "MEASURED_DECLARED_NATIVE_CANDIDATE_SPAN_NO_FILL",
                    "fullInwardDepth": "MEASURED_ALL_NATIVE_RAW_COMPONENT_NODES",
                    "leftReturnResidual": left_state,
                    "rightReturnResidual": right_state,
                    "apexAndOffset": unresolved_path_state,
                    "monotonicSides": unresolved_path_state,
                    "smoothnessJaggednessCurvature": unresolved_path_state,
                    "branchAndParallelBands": "MEASURED_ALL_NATIVE_RAW_COMPONENT_NODES",
                    "representativeParallelBandSwitches": unresolved_path_state,
                    "coherentCoreCorridorSignatures": unresolved_path_state,
                },
                "pairingEligible": False,
            }
        )
        base.update(
            recompute_coherent_core_corridors(
                angle_sample_count=width,
                span_columns=[int(column) for column in selected_span],
                complete_node_records=[],
                strict_core_node_records=base["strictCoreNativeNodes"],
                strict_core_seed_ids=base["strictCoreSeedIds"],
                strict_core_native_node_seed_ordinals=base[
                    "strictCoreNativeNodeSeedOrdinals"
                ],
                left_anchor=left_anchor,
                right_anchor=right_anchor,
                representative_path=[],
            )
        )
        return {
            "record": base,
            "path": empty_path,
            "observed": empty_observed,
            "supportPoints": points,
            "span": selected_span,
        }

    if bool(component_info.get("broadHalfPerimeterResponse")):
        return held_result(
            "HOLD_BROAD_RESPONSE_HAS_NO_UNIQUE_SHORT_SHOULDER_INTERVAL",
            ["RAW_COMPONENT_ENVELOPE_REACHES_MORE_THAN_HALF_PERIMETER"],
            span=component,
        )
    if not bool(left_window["passed"]) or not bool(right_window["passed"]):
        return held_result(
            "HOLD_MISSING_SUSTAINED_NATIVE_NORMAL_TRACE_SHOULDER",
            ["LEFT_OR_RIGHT_SHOULDER_LACKS_NEAREST_SEVEN_OF_NINE_NATIVE_WINDOW_WITH_MAXIMUM_ONE_SAMPLE_GAP"],
        )
    assert left_anchor is not None and right_anchor is not None
    unwrapped_span_count = (
        int(component.size)
        + int(left_anchor["distanceFromRawComponentSamples"])
        + int(right_anchor["distanceFromRawComponentSamples"])
    )
    if unwrapped_span_count > width:
        return held_result(
            "HOLD_SHOULDER_INTERVAL_EXCEEDS_FULL_PERIMETER",
            ["UNWRAPPED_SHOULDER_INTERVAL_EXCEEDS_ONE_REVOLUTION"],
            span=component,
        )
    if unwrapped_span_count > width // 2:
        return held_result(
            "HOLD_BROAD_RESPONSE_HAS_NO_UNIQUE_SHORT_SHOULDER_INTERVAL",
            ["SHOULDER_INTERVAL_REACHES_AT_LEAST_HALF_PERIMETER"],
            span=component,
        )

    columns = (
        int(left_anchor["column"])
        + np.arange(unwrapped_span_count, dtype=np.int64)
    ) % width
    need(
        int(columns[-1]) == int(right_anchor["column"]),
        "Unwrapped native shoulder span does not terminate at its right anchor",
    )
    nodes: list[list[int]] = []
    for position, column_value in enumerate(columns):
        column = int(column_value)
        if position == 0:
            rows = [int(left_anchor["row"])]
        elif position == len(columns) - 1:
            rows = [int(right_anchor["row"])]
        elif bool(obstruction[column]):
            rows = []
        else:
            # Discovery identifies the neutral basin and its exact strict core;
            # contouring must see every channel-local native brightness node
            # between the measured shoulders.  Collapsing a radial band to one
            # row can delete the only locally connected native path.
            rows = [
                int(row)
                for row in np.flatnonzero(transition["nativeSupported"][:, column])
            ]
        nodes.append(rows)
    full_candidate_native_points = sorted(
        set(component_native_points)
        | {
            (int(column_value), int(row))
            for column_value, rows in zip(columns, nodes)
            for row in rows
        }
    )
    def is_core(position: int, row: int) -> bool:
        return int(row) in core_rows.get(int(columns[position]), set())

    def native_bridge_exists(
        active_nodes: list[list[int]],
        previous_position: int,
        previous_row: int,
        position: int,
        row: int,
    ) -> bool:
        if position - previous_position != 2:
            return False
        middle_position = previous_position + 1
        return any(
            abs(float(search_offsets[middle_row] - search_offsets[previous_row]))
            <= MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE + 1.0e-6
            and abs(float(search_offsets[row] - search_offsets[middle_row]))
            <= MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE + 1.0e-6
            for middle_row in active_nodes[middle_position]
        )

    def rank_native_paths(
        active_nodes: list[list[int]],
    ) -> tuple[list[dict[tuple[int, bool], dict[str, Any]]], list[list[np.ndarray]]]:
        node_bands = [native_row_bands(rows) for rows in active_nodes]
        node_band_ordinals = [
            {
                int(row): ordinal
                for ordinal, band in enumerate(bands)
                for row in band
            }
            for bands in node_bands
        ]

        def transition_continuity(
            previous_position: int,
            previous_row: int,
            position: int,
            row: int,
        ) -> tuple[int, float]:
            previous_band = node_bands[previous_position][
                node_band_ordinals[previous_position][previous_row]
            ]
            current_bands = node_bands[position]
            selected_band = current_bands[node_band_ordinals[position][row]]
            selected_separation = native_band_separation_px(
                previous_band, selected_band, search_offsets
            )
            best_separation = min(
                (
                    native_band_separation_px(previous_band, band, search_offsets)
                    for band in current_bands
                ),
                default=float("inf"),
            )
            avoidable_switch = int(
                selected_separation >= PARALLEL_BAND_SEPARATION_PX
                and selected_separation > best_separation + 1.0e-6
            )
            return avoidable_switch, abs(
                float(search_offsets[row] - search_offsets[previous_row])
            )

        # Each state is keyed by (native row, has visited a raw-depth core).
        # Avoidable separated-band changes are ranked out before coverage and
        # the one-column no-fill allowance.  Coverage then precedes native
        # travel and every brightness witness.  Center, shape, R6, and ideal
        # curves are absent from traversal.
        ranked: list[dict[tuple[int, bool], dict[str, Any]]] = [
            {} for _ in columns
        ]
        if active_nodes and int(left_anchor["row"]) in active_nodes[0]:
            row = int(left_anchor["row"])
            seen = is_core(0, row)
            ranked[0][(row, seen)] = {
                "count": 1,
                "gaps": 0,
                "avoidableBandSwitches": 0,
                "radialTravel": 0.0,
                "directRaw": float(transition["directRawContrast"][row, columns[0]]),
                "enhanced": float(transition["enhancedContrast"][row, columns[0]]),
                "raw": float(transition["rawContrast"][row, columns[0]]),
                "previous": None,
                "pathCount": 1,
            }
        for position in range(1, len(columns)):
            for row in active_nodes[position]:
                choices: dict[bool, list[tuple[tuple[Any, ...], dict[str, Any]]]] = {
                    False: [],
                    True: [],
                }
                for delta in (1, 2):
                    previous_position = position - delta
                    if previous_position < 0:
                        continue
                    for (previous_row, previous_seen), previous in ranked[
                        previous_position
                    ].items():
                        if delta == 2 and native_bridge_exists(
                            active_nodes,
                            previous_position,
                            int(previous_row),
                            position,
                            int(row),
                        ):
                            continue
                        radial_change = abs(
                            float(search_offsets[row] - search_offsets[previous_row])
                        )
                        if (
                            radial_change
                            > MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE * delta + 1.0e-6
                        ):
                            continue
                        avoidable_switch, radial_travel = transition_continuity(
                            previous_position, int(previous_row), position, int(row)
                        )
                        seen = bool(previous_seen or is_core(position, row))
                        state = {
                            "count": int(previous["count"]) + 1,
                            "gaps": int(previous["gaps"]) + delta - 1,
                            "avoidableBandSwitches": int(
                                previous["avoidableBandSwitches"]
                            ) + avoidable_switch,
                            "radialTravel": float(previous["radialTravel"])
                            + radial_travel,
                            "directRaw": float(previous["directRaw"])
                            + float(
                                transition["directRawContrast"][row, columns[position]]
                            ),
                            "enhanced": float(previous["enhanced"])
                            + float(
                                transition["enhancedContrast"][row, columns[position]]
                            ),
                            "raw": float(previous["raw"])
                            + float(transition["rawContrast"][row, columns[position]]),
                            "previous": (
                                previous_position,
                                int(previous_row),
                                bool(previous_seen),
                            ),
                            "pathCount": int(previous["pathCount"]),
                        }
                        rank = (
                            -state["avoidableBandSwitches"],
                            state["count"],
                            -state["gaps"],
                            -state["radialTravel"],
                            state["directRaw"],
                            state["enhanced"],
                            state["raw"],
                            -row,
                        )
                        choices[seen].append((rank, state))
                for seen, entries in choices.items():
                    if not entries:
                        continue
                    entries.sort(key=lambda item: item[0], reverse=True)
                    best = entries[0][1]
                    best["pathCount"] = min(
                        PATH_COUNT_SATURATION,
                        sum(int(item[1]["pathCount"]) for item in entries),
                    )
                    ranked[position][(int(row), bool(seen))] = best
        return ranked, node_bands

    forward, _ = rank_native_paths(nodes)

    backward: list[dict[int, set[bool]]] = [dict() for _ in columns]
    if nodes and int(right_anchor["row"]) in nodes[-1]:
        row = int(right_anchor["row"])
        backward[-1][row] = {is_core(len(columns) - 1, row)}
    for position in range(len(columns) - 2, -1, -1):
        for row in nodes[position]:
            flags: set[bool] = set()
            for delta in (1, 2):
                next_position = position + delta
                if next_position >= len(columns):
                    continue
                for next_row, next_flags in backward[next_position].items():
                    if delta == 2 and native_bridge_exists(
                        nodes, position, int(row), next_position, int(next_row)
                    ):
                        continue
                    radial_change = abs(float(search_offsets[row] - search_offsets[next_row]))
                    if radial_change > MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE * delta + 1.0e-6:
                        continue
                    flags.update(bool(value or is_core(position, row)) for value in next_flags)
            if flags:
                backward[position][int(row)] = flags

    complete_nodes: list[list[int]] = [[] for _ in columns]
    support_points: list[tuple[int, int]] = []
    for position, column_value in enumerate(columns):
        for row in nodes[position]:
            forward_flags = {seen for candidate_row, seen in forward[position] if candidate_row == row}
            backward_flags = backward[position].get(int(row), set())
            if any(bool(left or right) for left in forward_flags for right in backward_flags):
                complete_nodes[position].append(int(row))
                support_points.append((int(column_value), int(row)))

    complete_support_set = set(support_points)
    strict_core_set = {
        (int(node["column"]), int(node["radialRow"]))
        for node in base["strictCoreNativeNodes"]
    }
    raw_component_set = set(component_native_points)
    strict_core_outside_complete = sorted(strict_core_set - complete_support_set)
    raw_component_outside_complete = sorted(raw_component_set - complete_support_set)
    full_graph_rows_by_column: dict[int, set[int]] = {}
    for column, row in full_candidate_native_points:
        full_graph_rows_by_column.setdefault(int(column), set()).add(int(row))
    excluded_strict_core_bands, excluded_strict_core_seed_ids = (
        strict_core_bands_outside_complete_graph(
            full_candidate_native_points, support_points
        )
    )

    endpoint_key = (int(right_anchor["row"]), True)
    endpoint = forward[-1].get(endpoint_key) if forward else None
    if endpoint is None:
        return held_result(
            "HOLD_NO_CORE_VISITING_NATIVE_SHOULDER_TO_SHOULDER_PATH",
            ["NO_COMPLETE_NATIVE_PATH_THROUGH_RAW_DEPTH_CORE"],
            support_points=full_candidate_native_points,
            span=columns,
        )

    # Dead-end and non-core-connected native bands remain in the raw candidate
    # record, but cannot bias branch-continuity ranking.  Re-rank only the exact
    # nodes mechanically proven to lie on a shoulder-to-shoulder, core-visiting
    # native path.  No node coordinate is changed or synthesized.
    forward, complete_bands = rank_native_paths(complete_nodes)
    endpoint = forward[-1].get(endpoint_key) if forward else None
    need(endpoint is not None, "Complete native support graph lost its endpoint during continuity re-rank")

    sequence: list[tuple[int, int, bool]] = []
    position = len(columns) - 1
    row = int(right_anchor["row"])
    seen = True
    while True:
        sequence.append((position, row, seen))
        state = forward[position][(row, seen)]
        previous = state["previous"]
        if previous is None:
            break
        position, row, seen = previous
    sequence.reverse()
    need(
        sequence[0][0] == 0 and sequence[-1][0] == len(columns) - 1,
        "Native path endpoints changed",
    )
    corridor_recomputation = recompute_coherent_core_corridors(
        angle_sample_count=width,
        span_columns=[int(value) for value in columns],
        complete_node_records=[
            {
                "column": int(column),
                "radialRow": int(row_value),
                "offsetPx": float(search_offsets[row_value]),
            }
            for column, row_value in support_points
        ],
        strict_core_node_records=base["strictCoreNativeNodes"],
        strict_core_seed_ids=base["strictCoreSeedIds"],
        strict_core_native_node_seed_ordinals=base[
            "strictCoreNativeNodeSeedOrdinals"
        ],
        left_anchor=left_anchor,
        right_anchor=right_anchor,
        representative_path=[
            {
                "column": int(columns[path_position]),
                "radialRow": int(path_row),
            }
            for path_position, path_row, _ in sequence
        ],
    )
    route_seed_ids = seed_ids if seed_ids else ["__COMBINED_STRICT_CORE__"]
    route_seed_rows_by_id = (
        seed_rows_by_id
        if seed_ids
        else {
            "__COMBINED_STRICT_CORE__": {
                int(column): sorted(int(row) for row in rows)
                for column, rows in core_rows.items()
            }
        }
    )

    def audit_coherent_band_routes() -> tuple[
        int, int, int, list[list[np.ndarray]], dict[str, Any]
    ]:
        coarse_bands = [
            coarse_native_row_bands(rows, search_offsets) for rows in complete_nodes
        ]
        unique_seed_ids = set(
            corridor_recomputation[
                "strictCoreSeedIdsInUniqueCoherentCorridorSignature"
            ]
        )
        unique_seed_mask = sum(
            1 << index
            for index, seed_id in enumerate(seed_ids)
            if seed_id in unique_seed_ids
        )
        return (
            int(
                corridor_recomputation[
                    "coherentCoarseBandRouteCountSaturated"
                ]
            ),
            int(
                corridor_recomputation[
                    "coherentCoreCorridorSignatureCountSaturated"
                ]
            ),
            unique_seed_mask,
            coarse_bands,
            dict(corridor_recomputation["coherentCoreCorridorDiagnostics"]),
        )

        def containing_band(position: int, row: int) -> int:
            matches = [
                index
                for index, band in enumerate(coarse_bands[position])
                if int(row) in band
            ]
            need(len(matches) == 1, "Native endpoint does not belong to one coarse band")
            return matches[0]

        def band_edge_exists(
            previous_position: int,
            previous_band: np.ndarray,
            position: int,
            current_band: np.ndarray,
        ) -> bool:
            delta = position - previous_position
            def connected(
                left_band: np.ndarray,
                right_band: np.ndarray,
                maximum_change: float,
            ) -> bool:
                return any(
                    abs(
                        float(
                            search_offsets[int(right_row)]
                            - search_offsets[int(left_row)]
                        )
                    )
                    <= maximum_change + 1.0e-6
                    for left_row in left_band
                    for right_row in right_band
                )

            if not connected(
                previous_band,
                current_band,
                MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE * delta,
            ):
                return False
            if delta == 2:
                # A gap edge is unavailable when any complete middle coarse
                # band connects the endpoint bands. This is band-level, so a
                # thick edge cannot manufacture skip routes from row pairs.
                middle_position = previous_position + 1
                if any(
                    connected(
                        previous_band,
                        middle_band,
                        MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE,
                    )
                    and connected(
                        middle_band,
                        current_band,
                        MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE,
                    )
                    for middle_band in coarse_bands[middle_position]
                ):
                    return False
            return True

        def avoidable_band_switch(
            previous_position: int,
            previous_band: np.ndarray,
            position: int,
            current_band: np.ndarray,
        ) -> int:
            connected = [
                band
                for band in coarse_bands[position]
                if band_edge_exists(previous_position, previous_band, position, band)
            ]
            selected = native_band_separation_px(
                previous_band, current_band, search_offsets
            )
            closest = min(
                (
                    native_band_separation_px(previous_band, band, search_offsets)
                    for band in connected
                ),
                default=float("inf"),
            )
            return int(
                selected > closest + 1.0e-6
            )

        def band_intersects_seed(
            position: int, band: np.ndarray, seed_index: int
        ) -> bool:
            column = int(columns[position])
            seed_id = route_seed_ids[seed_index]
            seed_rows = route_seed_rows_by_id.get(seed_id, {}).get(column, [])
            return any(int(row) in band for row in seed_rows)

        def retain_fully_covered_seeds(
            mask: int,
            previous_position: int,
            position: int,
            band: np.ndarray,
        ) -> int:
            retained = int(mask)
            for seed_index, seed_id in enumerate(route_seed_ids):
                bit = 1 << seed_index
                if not retained & bit:
                    continue
                rows_by_column = route_seed_rows_by_id.get(seed_id, {})
                for skipped_position in range(previous_position + 1, position):
                    if rows_by_column.get(int(columns[skipped_position]), []):
                        retained &= ~bit
                        break
                if retained & bit:
                    required_here = rows_by_column.get(int(columns[position]), [])
                    if required_here and not band_intersects_seed(
                        position, band, seed_index
                    ):
                        retained &= ~bit
            return retained

        def canonical_signature(
            signature: tuple[tuple[int, int], ...], seed_mask: int
        ) -> tuple[tuple[int, int], ...]:
            return tuple(
                token
                for token in signature
                if any(
                    seed_mask & (1 << seed_index)
                    and band_intersects_seed(
                        int(token[0]),
                        coarse_bands[int(token[0])][int(token[1])],
                        seed_index,
                    )
                    for seed_index in range(len(route_seed_ids))
                )
            )

        # One state represents one coarse-band route family, its still-fully-
        # covered strict-core seed set, and its canonical native-position band
        # signature.  Canonicalization occurs before the two-signature cap, so
        # discarded-seed differences cannot hide a later distinct corridor.
        states: list[dict[tuple[int, int, int, int], dict[str, Any]]] = [
            {} for _ in columns
        ]
        left_band = containing_band(0, int(left_anchor["row"]))
        left_seed_mask = retain_fully_covered_seeds(
            (1 << len(route_seed_ids)) - 1,
            -1,
            0,
            coarse_bands[0][left_band],
        )
        left_signature_raw = (
            ((0, left_band),)
            if any(
                left_seed_mask & (1 << seed_index)
                and band_intersects_seed(
                    0, coarse_bands[0][left_band], seed_index
                )
                for seed_index in range(len(route_seed_ids))
            )
            else ()
        )
        left_signature = canonical_signature(left_signature_raw, left_seed_mask)
        states[0][(left_band, left_seed_mask, 0, 0)] = {
            "count": 1,
            "previous": None,
            "coreSignatures": {left_signature},
        }
        for position in range(1, len(columns)):
            for band_index, band in enumerate(coarse_bands[position]):
                for delta in (1, 2):
                    previous_position = position - delta
                    if previous_position < 0:
                        continue
                    for previous_key, previous_state in states[previous_position].items():
                        previous_band_index, previous_seed_mask, previous_gaps, previous_switches = previous_key
                        previous_band = coarse_bands[previous_position][previous_band_index]
                        if not band_edge_exists(
                            previous_position, previous_band, position, band
                        ):
                            continue
                        next_seed_mask = retain_fully_covered_seeds(
                            int(previous_seed_mask),
                            previous_position,
                            position,
                            band,
                        )
                        current_key = (
                            band_index,
                            next_seed_mask,
                            int(previous_gaps) + delta - 1,
                            min(
                                2,
                                int(previous_switches)
                                + avoidable_band_switch(
                                    previous_position,
                                    previous_band,
                                    position,
                                    band,
                                ),
                            ),
                        )
                        contribution = min(2, int(previous_state["count"]))
                        core_token = (
                            (position, band_index)
                            if any(
                                next_seed_mask & (1 << seed_index)
                                and band_intersects_seed(position, band, seed_index)
                                for seed_index in range(len(route_seed_ids))
                            )
                            else None
                        )
                        contribution_signatures = {
                            canonical_signature(signature, next_seed_mask)
                            + ((core_token,) if core_token is not None else ())
                            for signature in previous_state["coreSignatures"]
                        }
                        contribution_signatures = {
                            canonical_signature(signature, next_seed_mask)
                            for signature in contribution_signatures
                        }
                        existing = states[position].get(current_key)
                        if existing is None:
                            states[position][current_key] = {
                                "count": contribution,
                                "previous": (
                                    previous_position,
                                    previous_key,
                                ) if contribution == 1 else None,
                                "coreSignatures": set(
                                    sorted(contribution_signatures)[:2]
                                ),
                            }
                        else:
                            existing["count"] = min(
                                2, int(existing["count"]) + contribution
                            )
                            existing["previous"] = None
                            existing["coreSignatures"] = set(
                                sorted(
                                    set(existing["coreSignatures"])
                                    | contribution_signatures
                                )[:2]
                            )

        right_band = containing_band(
            len(columns) - 1, int(right_anchor["row"])
        )
        finals = [
            (key, state)
            for key, state in states[-1].items()
            if key[0] == right_band
            and key[1] != 0
            and key[3] == 0
            and (len(columns) - key[2]) / len(columns)
            >= MINIMUM_PATH_COVERAGE_FRACTION
        ]
        signature_masks: dict[tuple[tuple[int, int], ...], int] = {}
        for key, state in finals:
            surviving_seed_mask = int(key[1])
            for raw_signature in state["coreSignatures"]:
                signature = canonical_signature(raw_signature, surviving_seed_mask)
                if signature:
                    signature_masks[signature] = (
                        signature_masks.get(signature, 0) | surviving_seed_mask
                    )
        signatures = sorted(signature_masks)[:2]
        route_count = min(2, sum(int(state["count"]) for _, state in finals))
        signature_count = min(2, len(signatures))
        unique_seed_mask = 0
        if len(signatures) == 1:
            unique_seed_mask = int(signature_masks[signatures[0]])
        signature_summaries = [
            {
                "sha256": hashlib.sha256(
                    json.dumps(signature, separators=(",", ":")).encode("ascii")
                ).hexdigest().upper(),
                "strictCoreTokenCount": len(signature),
                "firstPosition": None if not signature else int(signature[0][0]),
                "lastPosition": None if not signature else int(signature[-1][0]),
                "survivingStrictCoreSeedIds": [
                    route_seed_ids[index]
                    for index in range(len(route_seed_ids))
                    if signature_masks[signature] & (1 << index)
                ],
            }
            for signature in signatures
        ]
        divergence_positions: list[int] = []
        common_different_positions: list[int] = []
        maximum_separation = 0.0
        if len(signatures) == 2:
            left_by_position = {int(position): int(band) for position, band in signatures[0]}
            right_by_position = {int(position): int(band) for position, band in signatures[1]}
            for position in sorted(set(left_by_position) | set(right_by_position)):
                left_index = left_by_position.get(position)
                right_index = right_by_position.get(position)
                if left_index == right_index:
                    continue
                divergence_positions.append(position)
                if left_index is not None and right_index is not None:
                    common_different_positions.append(position)
                    maximum_separation = max(
                        maximum_separation,
                        native_band_separation_px(
                            coarse_bands[position][left_index],
                            coarse_bands[position][right_index],
                            search_offsets,
                        ),
                    )
        divergence_flags = np.zeros(len(columns), dtype=bool)
        if divergence_positions:
            divergence_flags[np.asarray(divergence_positions, dtype=np.int64)] = True
        divergence_runs = [
            int(run.size) for run in r18.CORE.group_circular_true(divergence_flags)
        ]
        diagnostics = {
            "population": "AT_MOST_TWO_CANONICAL_FULLY_COVERED_STRICT_CORE_NATIVE_POSITION_COARSE_BAND_SIGNATURES",
            "signatureSummaries": signature_summaries,
            "divergentPositionCount": len(divergence_positions),
            "commonStrictCorePositionDifferentBandCount": len(
                common_different_positions
            ),
            "maximumContiguousDivergentPositionRun": max(
                divergence_runs, default=0
            ),
            "maximumCommonPositionCoarseBandSeparationPx": float(
                maximum_separation
            ),
        }
        need(
            not finals or signature_count > 0,
            "A core-visiting complete coarse route lost its strict-core signature",
        )
        return (
            route_count,
            signature_count,
            unique_seed_mask,
            coarse_bands,
            diagnostics,
        )

    (
        raw_coherent_coarse_route_count,
        raw_exact_corridor_signature_count,
        _raw_unique_coherent_seed_mask,
        coarse_complete_bands,
        coherent_corridor_diagnostics,
    ) = audit_coherent_band_routes()
    complete_strict_positions: list[int] = []
    strict_parallel_positions: list[int] = []
    for position, bands in enumerate(coarse_complete_bands):
        strict_band_count = sum(
            any(is_core(position, int(row)) for row in band) for band in bands
        )
        if strict_band_count:
            complete_strict_positions.append(position)
        if strict_band_count >= 2:
            strict_parallel_positions.append(position)
    strict_parallel_flags = np.zeros(len(columns), dtype=bool)
    if strict_parallel_positions:
        strict_parallel_flags[
            np.asarray(strict_parallel_positions, dtype=np.int64)
        ] = True
    strict_parallel_runs: list[int] = []
    current_run = 0
    for value in strict_parallel_flags:
        if bool(value):
            current_run += 1
        elif current_run:
            strict_parallel_runs.append(current_run)
            current_run = 0
    if current_run:
        strict_parallel_runs.append(current_run)
    maximum_strict_parallel_run = max(strict_parallel_runs, default=0)
    strict_core_span_samples = (
        int(complete_strict_positions[-1] - complete_strict_positions[0] + 1)
        if complete_strict_positions
        else 0
    )
    strict_parallel_span_fraction = (
        float(maximum_strict_parallel_run / strict_core_span_samples)
        if strict_core_span_samples
        else 0.0
    )
    sustained_physical_fork = bool(
        maximum_strict_parallel_run
        >= MINIMUM_SUSTAINED_STRICT_CORE_FORK_RUN_SAMPLES
        and strict_parallel_span_fraction
        >= MINIMUM_SUSTAINED_STRICT_CORE_FORK_SPAN_FRACTION
    )
    resolved_physical_corridor_count = (
        0
        if raw_exact_corridor_signature_count == 0
        or not complete_strict_positions
        else 2
        if sustained_physical_fork
        else 1
    )
    coherent_corridor_count = raw_exact_corridor_signature_count
    coherent_coarse_route_count = raw_coherent_coarse_route_count
    coherent_corridor_diagnostics.update(
        {
            "rawExactCanonicalSignatureCountSaturated": int(
                raw_exact_corridor_signature_count
            ),
            "rawExactCoarseRouteCountSaturated": int(
                raw_coherent_coarse_route_count
            ),
            "completeStrictCorePositionCount": len(complete_strict_positions),
            "completeStrictCoreSpanSamples": strict_core_span_samples,
            "parallelStrictCorePositionCount": len(strict_parallel_positions),
            "maximumContiguousParallelStrictCoreRunSamples": (
                maximum_strict_parallel_run
            ),
            "parallelStrictCoreRunFractionOfCompleteCoreSpan": (
                strict_parallel_span_fraction
            ),
            "minimumSustainedForkRunSamples": (
                MINIMUM_SUSTAINED_STRICT_CORE_FORK_RUN_SAMPLES
            ),
            "minimumSustainedForkSpanFraction": (
                MINIMUM_SUSTAINED_STRICT_CORE_FORK_SPAN_FRACTION
            ),
            "sustainedPhysicalStrictCoreFork": sustained_physical_fork,
            "resolvedPhysicalCorridorCountSaturated": (
                resolved_physical_corridor_count
            ),
            "resolutionRule": (
                "ONE_PHYSICAL_CORRIDOR_UNLESS_TWO_OR_MORE_COMPLETE_STRICT_CORE_"
                "COARSE_BANDS_PERSIST_FOR_BOTH_FROZEN_RUN_AND_SPAN_FRACTION"
            ),
        }
    )

    selected_seed_ids: set[str] = set()
    if resolved_physical_corridor_count >= 1:
        for position, row, _ in sequence:
            band = next(
                band for band in coarse_complete_bands[position] if int(row) in band
            )
            column = int(columns[position])
            band_rows = {int(value) for value in band}
            for seed_id in seed_ids:
                if band_rows & {
                    int(value)
                    for value in seed_rows_by_id.get(seed_id, {}).get(column, [])
                }:
                    selected_seed_ids.add(seed_id)
    representative_physical_seed_ids = [
        seed_id for seed_id in seed_ids if seed_id in selected_seed_ids
    ]
    seed_ids_not_on_representative_physical_corridor = [
        seed_id for seed_id in seed_ids if seed_id not in selected_seed_ids
    ]
    seed_ids_on_unique_corridor = [
        seed_id
        for index, seed_id in enumerate(seed_ids)
        if coherent_corridor_count == 1
        and _raw_unique_coherent_seed_mask & (1 << index)
    ]
    seed_ids_not_on_unique_corridor = [
        seed_id for seed_id in seed_ids
        if seed_id not in set(seed_ids_on_unique_corridor)
    ]
    all_seeds_share_unique_corridor = bool(seed_ids) and bool(
        coherent_corridor_count == 1
        and len(seed_ids_on_unique_corridor) == len(seed_ids)
    )
    need(
        corridor_recomputation
        == {
            "coherentCoreCorridorSignatureCountSaturated": (
                coherent_corridor_count
            ),
            "coherentCoarseBandRouteCountSaturated": (
                coherent_coarse_route_count
            ),
            "uniqueCoherentNativeCoreCorridorSignature": (
                coherent_corridor_count == 1
            ),
            "strictCoreSeedIdsInUniqueCoherentCorridorSignature": (
                seed_ids_on_unique_corridor
            ),
            "strictCoreSeedIdsNotResolvedToUniqueCoherentCorridor": (
                seed_ids_not_on_unique_corridor
            ),
            "allStrictCoreSeedsShareUniqueCoherentBandCorridor": (
                all_seeds_share_unique_corridor
            ),
            "resolvedPhysicalCoreCorridorCountSaturated": (
                resolved_physical_corridor_count
            ),
            "uniqueResolvedPhysicalCoreCorridor": (
                resolved_physical_corridor_count == 1
            ),
            "strictCoreSeedIdsOnRepresentativePhysicalCorridor": (
                representative_physical_seed_ids
            ),
            "strictCoreSeedIdsNotOnRepresentativePhysicalCorridor": (
                seed_ids_not_on_representative_physical_corridor
            ),
            "coherentCoreCorridorDiagnostics": coherent_corridor_diagnostics,
        },
        "Generator corridor decisions differ from serialized-evidence recomputation",
    )

    path = empty_path.copy()
    observed = empty_observed.copy()
    span_observed = np.zeros(columns.size, dtype=bool)
    path_columns: list[int] = []
    path_rows: list[int] = []
    path_positions: list[int] = []
    for position, row, _ in sequence:
        column = int(columns[position])
        need(bool(transition["nativeSupported"][row, column]), "Representative trace contains unsupported coordinate")
        need(
            float(transition["rawContrast"][row, column])
            >= float(r18.MINIMUM_RAW_POLARITY),
            "Representative trace lost its accepted raw transition polarity",
        )
        path[column] = float(search_offsets[row])
        observed[column] = True
        span_observed[position] = True
        path_columns.append(column)
        path_rows.append(row)
        path_positions.append(position)

    selected_offsets = np.asarray([float(search_offsets[row]) for row in path_rows], dtype=np.float64)
    selected_depth = outer_path[np.asarray(path_columns, dtype=np.int64)].astype(np.float64) - selected_offsets
    selected_raw = np.asarray(
        [float(transition["rawContrast"][row, column]) for row, column in zip(path_rows, path_columns)],
        dtype=np.float64,
    )
    selected_direct_raw = np.asarray(
        [float(transition["directRawContrast"][row, column]) for row, column in zip(path_rows, path_columns)],
        dtype=np.float64,
    )
    selected_enhanced = np.asarray(
        [float(transition["enhancedContrast"][row, column]) for row, column in zip(path_rows, path_columns)],
        dtype=np.float64,
    )
    missing_run = longest_false_run(span_observed)
    coverage = float(np.mean(span_observed))
    adjacent_positions = np.diff(np.asarray(path_positions, dtype=np.int64))
    adjacent_offsets = np.diff(selected_offsets)
    maximum_adjacent_change = (
        float(np.max(np.abs(adjacent_offsets) / adjacent_positions)) if adjacent_offsets.size else 0.0
    )
    inward_limit_count = int(
        np.count_nonzero(np.isclose(selected_offsets, float(search_offsets[0]), rtol=0.0, atol=1.0e-6))
    )

    native_positions = np.asarray(path_positions, dtype=np.int64)
    apex_band_drop = max(3.0, 0.08 * float(np.ptp(selected_depth)))
    apex_level = max(float(threshold), float(np.max(selected_depth)) - apex_band_drop)
    apex_mask = selected_depth >= apex_level
    apex_native_positions = native_positions[apex_mask]
    apex_count = (
        int(np.count_nonzero(np.diff(apex_native_positions) > 1) + 1)
        if apex_native_positions.size
        else 0
    )
    apex_index = int(np.argmax(selected_depth))
    apex_position = int(native_positions[apex_index])
    position_deltas = np.diff(native_positions.astype(np.float64))
    first_difference = np.diff(selected_depth) / position_deltas
    left_steps = first_difference[native_positions[1:] <= apex_position]
    right_steps = first_difference[native_positions[:-1] >= apex_position]
    tolerance = 2.0
    left_monotonic = float(np.mean(left_steps >= -tolerance)) if left_steps.size else 0.0
    right_monotonic = float(np.mean(right_steps <= tolerance)) if right_steps.size else 0.0
    slope_midpoints = (
        native_positions[:-1].astype(np.float64)
        + native_positions[1:].astype(np.float64)
    ) / 2.0
    second_difference = (
        np.diff(first_difference) / np.diff(slope_midpoints)
        if first_difference.size >= 2
        else np.asarray([], dtype=np.float64)
    )
    slope_signs = np.sign(first_difference[np.abs(first_difference) > 1.0])
    slope_direction_reversals = (
        int(np.count_nonzero(slope_signs[1:] != slope_signs[:-1]))
        if slope_signs.size >= 2
        else 0
    )
    curvature_signs = np.sign(second_difference[np.abs(second_difference) > 1.0])
    curvature_reversals = (
        int(np.count_nonzero(curvature_signs[1:] != curvature_signs[:-1]))
        if curvature_signs.size >= 2
        else 0
    )
    extra_reversal_fraction = max(0, curvature_reversals - 1) / max(int(first_difference.size), 1)
    complete_bands = [native_row_bands(rows) for rows in complete_nodes]
    parallel_band_columns = 0
    maximum_complete_band_count = 0
    for bands in complete_bands:
        maximum_complete_band_count = max(maximum_complete_band_count, len(bands))
        if len(bands) >= 2:
            separations = [
                float(search_offsets[int(bands[index + 1][0])]
                      - search_offsets[int(bands[index][-1])])
                for index in range(len(bands) - 1)
            ]
            if max(separations, default=0.0) >= PARALLEL_BAND_SEPARATION_PX:
                parallel_band_columns += 1
    parallel_band_switch_count = 0
    for index in range(1, len(path_positions)):
        if path_positions[index] - path_positions[index - 1] != 1:
            continue
        previous_position = path_positions[index - 1]
        current_position = path_positions[index]
        previous_row = path_rows[index - 1]
        current_row = path_rows[index]
        previous_band = next(
            band for band in complete_bands[previous_position] if previous_row in band
        )
        current_bands = complete_bands[current_position]
        selected_band = next(band for band in current_bands if current_row in band)
        selected_separation = native_band_separation_px(
            previous_band, selected_band, search_offsets
        )
        best_continuation = min(
            (
                native_band_separation_px(previous_band, band, search_offsets)
                for band in current_bands
            ),
            default=float("inf"),
        )
        if (
            selected_separation >= PARALLEL_BAND_SEPARATION_PX
            and selected_separation > best_continuation + 1.0e-6
        ):
            parallel_band_switch_count += 1
    left_depth = float(selected_depth[0])
    right_depth = float(selected_depth[-1])
    left_column = int(left_anchor["column"])
    right_column = int(right_anchor["column"])
    left_normal_depth = float(outer_path[left_column] - normal_path[left_column])
    right_normal_depth = float(outer_path[right_column] - normal_path[right_column])
    left_return_residual = abs(left_depth - left_normal_depth)
    right_return_residual = abs(right_depth - right_normal_depth)
    center_weights = np.maximum(selected_depth - min(left_depth, right_depth), 0.001)
    center_degrees = circular_weighted_degrees(
        np.asarray(path_columns, dtype=np.int64), center_weights, width
    )
    path_width_degrees = float(columns.size * degrees_per_sample)
    symmetry, shape_tip_offset, shape_slope, symmetry_pair_count = (
        native_position_candidate_shape(
            selected_depth, native_positions, int(columns.size)
        )
    )
    apex_offset_fraction = shape_tip_offset
    component_columns = sorted(component_rows)
    selected_component_columns = sorted(set(path_columns) & set(component_columns))
    component_coverage = len(selected_component_columns) / max(len(component_columns), 1)
    obstruction_overlap = [int(column) for column in columns if bool(obstruction[int(column)])]
    inherited_hold_overlap = [int(column) for column in columns if bool(predecessor_held[int(column)])]
    evidence_reasons: list[str] = []
    if coverage < MINIMUM_PATH_COVERAGE_FRACTION:
        evidence_reasons.append("INSUFFICIENT_NATIVE_SUPPORT_FRACTION")
    if missing_run > MAXIMUM_UNSUPPORTED_RUN_SAMPLES:
        evidence_reasons.append("MAXIMUM_CONTIGUOUS_UNSUPPORTED_RUN_EXCEEDED")
    if component_coverage < MINIMUM_PATH_COVERAGE_FRACTION:
        evidence_reasons.append("INSUFFICIENT_DISCOVERED_COMPONENT_COVERAGE")
    if maximum_adjacent_change > MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE + 1.0e-6:
        evidence_reasons.append("LOCAL_NATIVE_CONNECTIVITY_LIMIT_EXCEEDED")
    if inward_limit_count:
        evidence_reasons.append("TRACE_TOUCHES_INWARD_SEARCH_LIMIT")
    if not bool(np.all(selected_raw >= float(r18.MINIMUM_RAW_POLARITY))):
        evidence_reasons.append("R18_RAW_NATIVE_TRANSITION_POLARITY_WITNESS_FAILED")
    authority_reasons = list(component_info.get("discoveryAuthorityHoldReasons", []))
    if obstruction_overlap:
        authority_reasons.append("EXTERIOR_OBSTRUCTION_OWNERSHIP_OVERLAP")
    if inherited_hold_overlap:
        authority_reasons.append("INHERITED_PREDECESSOR_HOLD_OVERLAP")
    if (
        resolved_physical_corridor_count >= 1
        and seed_ids_not_on_representative_physical_corridor
    ):
        authority_reasons.append(
            "ADDITIONAL_STRICT_CORE_SEEDS_OUTSIDE_UNIQUE_COHERENT_CORE_CORRIDOR_RETAINED"
        )
    if excluded_strict_core_bands:
        authority_reasons.append(
            "STRICT_CORE_COARSE_BAND_EVIDENCE_OUTSIDE_COMPLETE_SHOULDER_GRAPH_RETAINED"
        )
    if resolved_physical_corridor_count > 1:
        authority_reasons.append(
            "SUSTAINED_MULTIPLE_STRICT_CORE_CORRIDORS_RETAINED_AS_AUTHORITY_HOLD"
        )
    authority_reasons = list(dict.fromkeys(authority_reasons))
    morphology_reasons: list[str] = []
    if not (
        float(params.manufactured_minimum_width_degrees)
        <= path_width_degrees
        <= float(params.manufactured_maximum_width_degrees)
    ):
        morphology_reasons.append("TRACED_SHOULDER_WIDTH_OUTSIDE_MANUFACTURED_RANGE")
    if apex_count != 1:
        morphology_reasons.append("NOT_EXACTLY_ONE_NATIVE_APEX")
    if apex_offset_fraction > float(params.manufactured_maximum_tip_offset_fraction):
        morphology_reasons.append("APEX_OFFSET_EXCEEDS_FROZEN_LIMIT")
    if left_monotonic < float(params.manufactured_minimum_slope_consistency):
        morphology_reasons.append("LEFT_SIDE_NOT_MONOTONICALLY_INWARD")
    if right_monotonic < float(params.manufactured_minimum_slope_consistency):
        morphology_reasons.append("RIGHT_SIDE_NOT_MONOTONICALLY_OUTWARD")
    if float(symmetry) < float(params.manufactured_minimum_symmetry):
        morphology_reasons.append("POST_CONTOUR_SYMMETRY_BELOW_FROZEN_LIMIT")
    second_p90 = float(np.percentile(np.abs(second_difference), 90.0)) if second_difference.size else 0.0
    if second_p90 > MAXIMUM_SMOOTH_SECOND_DIFFERENCE_P90_PX:
        morphology_reasons.append("JAGGED_SECOND_DIFFERENCE")
    if extra_reversal_fraction > MAXIMUM_EXTRA_CURVATURE_REVERSAL_FRACTION:
        morphology_reasons.append("EXCESS_CURVATURE_REVERSALS")
    selected_avoidable_band_switches = int(endpoint["avoidableBandSwitches"])
    if selected_avoidable_band_switches:
        morphology_reasons.append("REPRESENTATIVE_NATIVE_RADIAL_BAND_JUMP")
    if resolved_physical_corridor_count == 0:
        morphology_reasons.append(
            "NO_COHERENT_STRICT_CORE_CORRIDOR_SIGNATURE"
        )
    if left_return_residual > MAXIMUM_RETURN_RESIDUAL_FROM_NORMAL_TRACE_PX:
        morphology_reasons.append("LEFT_SHOULDER_DOES_NOT_RETURN_TO_NORMAL_TRACE_DEPTH")
    if right_return_residual > MAXIMUM_RETURN_RESIDUAL_FROM_NORMAL_TRACE_PX:
        morphology_reasons.append("RIGHT_SHOULDER_DOES_NOT_RETURN_TO_NORMAL_TRACE_DEPTH")

    native_evidence_qualified = not evidence_reasons
    manufactured = bool(
        native_evidence_qualified
        and resolved_physical_corridor_count >= 1
        and not morphology_reasons
    )
    classification = (
        "UNRESOLVED_DEEP_EDGE_RESPONSE"
        if evidence_reasons
        else "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE"
        if manufactured
        else "NON_NOTCH_DEEP_EDGE_RESPONSE"
    )
    complete_support_graph_node_records = [
        {
            "column": int(column),
            "radialRow": int(row),
            "offsetPx": float(search_offsets[row]),
            "directUnblurredRawOutsideInContrast": float(
                transition["directRawContrast"][row, column]
            ),
            "proposalSmoothedRawOutsideInContrast": float(
                transition["rawContrast"][row, column]
            ),
            "enhancedOutsideInContrast": float(
                transition["enhancedContrast"][row, column]
            ),
        }
        for column, row in support_points
    ]
    record = {
        **base,
        "state": (
            "HOLD_UNRESOLVED_NATIVE_CANDIDATE_CONTOUR"
            if evidence_reasons
            else "HOLD_NATIVE_CONTOUR_AUTHORITY_RETAINED"
            if authority_reasons
            else "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE_AFTER_NATIVE_CONTOUR"
            if manufactured
            else "NON_NOTCH_DEEP_EDGE_RESPONSE"
        ),
        "classification": classification,
        "classificationReasons": evidence_reasons + morphology_reasons + authority_reasons,
        "evidenceHoldReasons": evidence_reasons,
        "authorityHoldReasons": authority_reasons,
        "postContourMorphologyReasons": morphology_reasons,
        "manufacturedCompatibleAfterContour": manufactured,
        "nativeContourShapeCompatibleAfterContour": manufactured,
        "nativeContourEvidenceQualified": native_evidence_qualified,
        "diagnosticPairingEligible": manufactured,
        "candidateLocalAuthorityEligibleBeforeGlobalHold": (
            manufactured and not authority_reasons
        ),
        "pairingEligible": manufactured,
        "notchOwnershipGranted": False,
        "completeNativeShoulderPath": native_evidence_qualified,
        "gapFreeNativeShoulderPath": native_evidence_qualified and missing_run == 0,
        "boundedGapNativeShoulderPath": native_evidence_qualified,
        "shoulderEndpointsConnectedByNativeGraph": True,
        "expectedSpanColumnCount": int(columns.size),
        "supportMetricPopulation": "TRACED_NATIVE_SHOULDER_SPAN_NO_FILL",
        "supportMetricSpanColumnIndices": [int(value) for value in columns],
        "tracedShoulderColumnIndices": [int(value) for value in columns],
        "representativePathObservedCount": len(sequence),
        "rawSupportedColumnCount": int(np.count_nonzero(span_observed)),
        "rawSupportedFraction": coverage,
        "maximumContiguousUnsupportedRun": missing_run,
        "unsupportedColumnCount": int(np.count_nonzero(~span_observed)),
        "unsupportedColumnIndices": [int(columns[value]) for value in np.flatnonzero(~span_observed)],
        "discoveredComponentNativeColumnCount": len(component_columns),
        "representativePathComponentColumnCount": len(selected_component_columns),
        "discoveredComponentCoverageFraction": float(component_coverage),
        "obstructionOverlapColumnIndices": obstruction_overlap,
        "obstructionOverlapColumnCount": len(obstruction_overlap),
        "inheritedPredecessorHoldOverlapColumnIndices": inherited_hold_overlap,
        "inheritedPredecessorHoldOverlapColumnCount": len(inherited_hold_overlap),
        "leftShoulderDepthFromFixedOuterCirclePx": left_depth,
        "rightShoulderDepthFromFixedOuterCirclePx": right_depth,
        "leftNormalBrightnessTraceDepthFromFixedOuterCirclePx": left_normal_depth,
        "rightNormalBrightnessTraceDepthFromFixedOuterCirclePx": right_normal_depth,
        "leftShoulderReturnResidualFromNormalTracePx": left_return_residual,
        "rightShoulderReturnResidualFromNormalTracePx": right_return_residual,
        "centerAngleDegrees": center_degrees,
        "startAngleDegrees": float(int(left_anchor["column"]) * degrees_per_sample),
        "endAngleDegrees": float(int(right_anchor["column"]) * degrees_per_sample),
        "widthDegrees": path_width_degrees,
        "ownershipIntervalBasis": "ACTUAL_TRACED_NATIVE_SHOULDER_ENDPOINTS",
        "shoulderSpanWidthDegrees": path_width_degrees,
        "maximumInwardDepthPx": float(np.max(selected_depth)),
        "medianInwardDepthPx": float(np.median(selected_depth)),
        "apexCount": apex_count,
        "apexBandMinimumDepthPx": float(apex_level),
        "apexPopulation": "UNSMOOTHED_REPRESENTATIVE_PATH_DEPTH_WITHIN_MAX_3PX_OR_8_PERCENT_RANGE",
        "apexOffsetFraction": float(apex_offset_fraction),
        "postContourShapeTipOffsetFraction": float(shape_tip_offset),
        "leftMonotonicSupportFraction": left_monotonic,
        "rightMonotonicSupportFraction": right_monotonic,
        "postContourShapeSlopeConsistencyFraction": float(shape_slope),
        "postContourSymmetryScore": float(symmetry),
        "postContourSymmetryExactNativePairCount": symmetry_pair_count,
        "maximumAdjacentRadialChangePxPerSample": maximum_adjacent_change,
        "firstDifferenceAbsoluteMedianPx": float(np.median(np.abs(first_difference))) if first_difference.size else 0.0,
        "firstDifferenceAbsoluteP90Px": float(np.percentile(np.abs(first_difference), 90.0)) if first_difference.size else 0.0,
        "firstDifferencePopulation": "DEPTH_SLOPE_PER_EXACT_NATIVE_ANGULAR_SAMPLE_DELTA_NO_FILL",
        "secondDifferenceAbsoluteMedianPx": float(np.median(np.abs(second_difference))) if second_difference.size else 0.0,
        "secondDifferenceAbsoluteP90Px": second_p90,
        "secondDifferenceAbsoluteMaximumPx": float(np.max(np.abs(second_difference))) if second_difference.size else 0.0,
        "secondDifferencePopulation": "ADJACENT_DEPTH_SLOPE_CHANGE_PER_NONUNIFORM_NATIVE_MIDPOINT_DELTA_NO_FILL",
        "slopeDirectionReversalCount": slope_direction_reversals,
        "curvatureReversalCount": curvature_reversals,
        "curvatureReversalPopulation": "SIGN_CHANGES_OF_SIGNIFICANT_UNSMOOTHED_SECOND_DIFFERENCES",
        "extraCurvatureReversalFraction": float(extra_reversal_fraction),
        "supportGraphNodeCount": len(full_candidate_native_points),
        "fullCandidateNativeGraphNodeCount": len(full_candidate_native_points),
        "completeSupportGraphNodeCount": len(support_points),
        "fullCandidateNativeGraphNodes": [
            {"column": int(column), "radialRow": int(row)}
            for column, row in full_candidate_native_points
        ],
        "strictCoreNodeCountOutsideCompleteShoulderGraph": len(
            strict_core_outside_complete
        ),
        "strictCoreNativeNodesOutsideCompleteShoulderGraph": [
            {"column": int(column), "radialRow": int(row)}
            for column, row in strict_core_outside_complete
        ],
        "rawComponentNativeNodeCountOutsideCompleteShoulderGraph": len(
            raw_component_outside_complete
        ),
        "rawComponentNativeNodesOutsideCompleteShoulderGraph": [
            {"column": int(column), "radialRow": int(row)}
            for column, row in raw_component_outside_complete
        ],
        "strictCoreOutsideCompleteShoulderGraphDisposition": (
            "RETAINED_AS_AUTHORITY_HOLD_AND_ORANGE_FULL_GRAPH_EVIDENCE"
            if excluded_strict_core_bands
            else "ROW_THICKNESS_ONLY_OUTSIDE_COMPLETE_GRAPH_NO_SEPARATE_COARSE_BAND"
            if strict_core_outside_complete
            else "NONE_ALL_STRICT_CORE_NODES_ON_COMPLETE_SHOULDER_GRAPH"
        ),
        "strictCoreCoarseBandCountOutsideCompleteShoulderGraph": len(
            excluded_strict_core_bands
        ),
        "strictCoreCoarseBandsOutsideCompleteShoulderGraph": excluded_strict_core_bands,
        "strictCoreSeedIdsWithCoarseBandOutsideCompleteShoulderGraph": (
            excluded_strict_core_seed_ids
        ),
        "supportGraphBranchColumnCount": int(
            sum(len(rows) > 1 for rows in full_graph_rows_by_column.values())
        ),
        "parallelBandColumnCount": parallel_band_columns,
        "maximumCompleteBandCountPerColumn": maximum_complete_band_count,
        "representativeParallelBandSwitchCount": selected_avoidable_band_switches,
        "postHocAdjacentParallelBandSwitchCount": parallel_band_switch_count,
        "representativeNativeRadialTravelPx": float(endpoint["radialTravel"]),
        "representativeSelectionRankOrder": (
            "ZERO_AVOIDABLE_BAND_SWITCHES_THEN_SUPPORTED_COUNT_THEN_GAPS_"
            "THEN_NATIVE_RADIAL_TRAVEL_THEN_DIRECT_RAW_THEN_ENHANCED_THEN_RAW"
        ),
        "reachableShoulderPathCountSaturated": int(endpoint["pathCount"]),
        "reachableShoulderPathCountSaturationValue": PATH_COUNT_SATURATION,
        "coherentCoreCorridorSignatureCountSaturated": coherent_corridor_count,
        "coherentCoreCorridorSignatureCountSaturationValue": 2,
        "coherentCoarseBandRouteCountSaturated": coherent_coarse_route_count,
        "coherentCoarseBandRouteCountSaturationValue": 2,
        "uniqueCoherentNativeCoreCorridorSignature": coherent_corridor_count == 1,
        "strictCoreSeedIdsInUniqueCoherentCorridorSignature": seed_ids_on_unique_corridor,
        "strictCoreSeedIdsNotResolvedToUniqueCoherentCorridor": (
            seed_ids_not_on_unique_corridor
        ),
        "allStrictCoreSeedsShareUniqueCoherentBandCorridor": all_seeds_share_unique_corridor,
        "resolvedPhysicalCoreCorridorCountSaturated": (
            resolved_physical_corridor_count
        ),
        "resolvedPhysicalCoreCorridorCountSaturationValue": 2,
        "uniqueResolvedPhysicalCoreCorridor": (
            resolved_physical_corridor_count == 1
        ),
        "strictCoreSeedIdsOnRepresentativePhysicalCorridor": (
            representative_physical_seed_ids
        ),
        "strictCoreSeedIdsNotOnRepresentativePhysicalCorridor": (
            seed_ids_not_on_representative_physical_corridor
        ),
        "coherentCoreCorridorDiagnostics": coherent_corridor_diagnostics,
        "selectedTransitionWitness": transition_witness_summary(
            "R18_RAW_AND_ENHANCED_NATIVE_TRANSITION_WITNESSES_WITH_DIRECT_UNBLURRED_DIAGNOSTIC",
            selected_raw,
            selected_direct_raw,
            selected_enhanced,
        ),
        "rawComponentTransitionWitness": dict(raw_component_witness),
        "gradientNormalAlignmentPostContourMeasurement": {
            "state": "NOT_REQUIRED_FOR_R27_NATIVE_RAW_POLARITY_CONTOUR",
            "selectionRole": False,
        },
        "allSelectedPixelsNativeSupported": True,
        "allSelectedPixelsRawPolaritySupported": bool(
            np.all(selected_raw >= float(r18.MINIMUM_RAW_POLARITY))
        ),
        "allSelectedPixelsDirectUnblurredPolaritySupported": bool(
            np.all(selected_direct_raw >= float(r18.MINIMUM_RAW_POLARITY))
        ),
        "inwardLimitTouchCount": inward_limit_count,
        "representativePath": [
            {
                "column": int(column),
                "radialRow": int(row),
                "offsetPx": float(search_offsets[row]),
                "fixedOuterPathOffsetPx": float(outer_path[column]),
                "directUnblurredRawOutsideInContrast": float(transition["directRawContrast"][row, column]),
                "proposalSmoothedRawOutsideInContrast": float(transition["rawContrast"][row, column]),
                "enhancedOutsideInContrast": float(transition["enhancedContrast"][row, column]),
            }
            for column, row in zip(path_columns, path_rows)
        ],
        "completeSupportGraphNativeNodesOrderedEvidenceSha256": (
            complete_graph_ordered_evidence_sha256(
                complete_support_graph_node_records
            )
        ),
        "completeSupportGraphNativeNodes": complete_support_graph_node_records,
        "metricAvailability": {
            "nativeSupport": "MEASURED_TRACED_NATIVE_SHOULDER_SPAN_NO_FILL",
            "fullInwardDepth": "MEASURED_CONTINUITY_FIRST_NATIVE_SHOULDER_PATH",
            "leftReturnResidual": "MEASURED_NATIVE_SHOULDER_TO_SAME_FIXED_OUTER_CIRCLE",
            "rightReturnResidual": "MEASURED_NATIVE_SHOULDER_TO_SAME_FIXED_OUTER_CIRCLE",
            "apexAndOffset": "MEASURED_CONTINUITY_FIRST_NATIVE_SHOULDER_PATH",
            "monotonicSides": "MEASURED_CONTINUITY_FIRST_NATIVE_SHOULDER_PATH",
            "smoothnessJaggednessCurvature": "MEASURED_UNSMOOTHED_CONTINUITY_FIRST_NATIVE_PATH",
            "branchAndParallelBands": "MEASURED_FULL_CANDIDATE_NATIVE_GRAPH_AND_COMPLETE_PATH_SUBGRAPH",
            "representativeParallelBandSwitches": "MEASURED_CONTINUITY_FIRST_NATIVE_SHOULDER_PATH",
            "coherentCoreCorridorSignatures": "MEASURED_EXACT_CANONICAL_FULLY_COVERED_STRICT_CORE_NATIVE_POSITION_COARSE_BAND_SIGNATURES_WITH_SEPARATE_PHYSICAL_FORK_RESOLUTION",
        },
    }
    return {
        "record": record,
        "path": path,
        "observed": observed,
        "supportPoints": full_candidate_native_points,
        "span": columns,
    }


def direct_native_raw_contrast(
    strip: np.ndarray,
    offsets: np.ndarray,
    search_offsets: np.ndarray,
) -> np.ndarray:
    """Witness each proposed coordinate against unblurred channel pixels."""
    rows = np.rint(search_offsets.astype(np.float64) - float(offsets[0])).astype(np.int64)
    need(
        bool(np.all(rows - (r18.RADIAL_INSIDE_SAMPLES - 1) >= 0))
        and bool(np.all(rows + r18.RADIAL_OUTSIDE_SAMPLES < strip.shape[0])),
        "Direct raw witness lacks its radial halo",
    )
    inside = sum(
        strip[rows - step].astype(np.float32)
        for step in range(r18.RADIAL_INSIDE_SAMPLES)
    ) / float(r18.RADIAL_INSIDE_SAMPLES)
    outside = sum(
        strip[rows + step].astype(np.float32)
        for step in range(1, r18.RADIAL_OUTSIDE_SAMPLES + 1)
    ) / float(r18.RADIAL_OUTSIDE_SAMPLES)
    return inside - outside


def shortest_circular_envelope(columns: Iterable[int], width: int) -> np.ndarray:
    values = np.asarray(sorted(set(int(value) % width for value in columns)), dtype=np.int64)
    need(values.size > 0, "Cannot form an envelope for an empty native component")
    if values.size == 1:
        return values.copy()
    gaps = (np.roll(values, -1) - values) % width
    cut = int(np.argmax(gaps))
    start = int(values[(cut + 1) % values.size])
    end = int(values[cut])
    count = (end - start) % width + 1
    return (start + np.arange(count, dtype=np.int64)) % width


def discover_raw_candidate_components(
    transition: dict[str, Any],
    normal_observed: np.ndarray,
    obstruction: np.ndarray,
    outer_path: np.ndarray,
    cfg: dict[str, Any],
) -> dict[str, Any]:
    """Enumerate measured normal-trace interruptions containing strict cores."""
    support = np.asarray(transition["nativeSupported"], dtype=bool)
    search_offsets = np.asarray(transition["searchOffsets"], dtype=np.float32)
    width = int(outer_path.size)
    need(support.shape == (search_offsets.size, width), "Native support-map geometry differs")
    need(np.asarray(normal_observed).shape == (width,), "Normal-trace observation width differs")
    unobstructed = ~np.asarray(obstruction, dtype=bool)

    # Threshold calibration uses the shallowest native-supported exterior
    # witness at each angle, but candidate enumeration below uses every 2-D
    # native-supported band.  A shallower parallel band therefore cannot hide
    # a deeper component.
    shallow_path, shallow_observed = r18.outermost_frontier(
        support, search_offsets
    )
    valid = shallow_observed & unobstructed
    shallow_depth = np.zeros(width, dtype=np.float64)
    shallow_depth[valid] = np.maximum(
        0.0,
        outer_path[valid].astype(np.float64) - shallow_path[valid].astype(np.float64),
    )
    population = shallow_depth[valid]
    need(population.size > 0, "Raw native candidate depth population is empty")
    ceiling = float(np.percentile(population, 80.0))
    baseline = population[population <= ceiling]
    need(baseline.size > 0, "Raw native candidate baseline population is empty")
    center = float(np.median(baseline))
    noise = float(1.4826 * np.median(np.abs(baseline - center)))
    threshold = max(
        float(cfg["minimumNotchDepthPx"]),
        center + float(cfg["noiseSigmaThreshold"]) * noise,
    )
    floor = max(MINIMUM_RAW_CANDIDATE_FLOOR_PX, center + 2.0 * noise)
    node_depth = outer_path[None, :].astype(np.float32) - search_offsets[:, None]
    # R25 used the lower floor as component ownership.  Ordinary radial bands
    # then connected unrelated strict cores across tens or hundreds of degrees.
    # R27 uses only the frozen strict threshold for seed lineage.  The lower
    # floor remains telemetry and never owns, joins, or expands a candidate.
    strict_core = support & (node_depth > threshold + 1.0e-6)

    parent: list[int] = []
    bands_by_column: list[list[dict[str, Any]]] = [[] for _ in range(width)]

    def add_node() -> int:
        value = len(parent)
        parent.append(value)
        return value

    def find(value: int) -> int:
        while parent[value] != value:
            parent[value] = parent[parent[value]]
            value = parent[value]
        return value

    def union(left: int, right: int) -> None:
        left_root = find(left)
        right_root = find(right)
        if left_root != right_root:
            parent[right_root] = left_root

    for column in range(width):
        rows = np.flatnonzero(strict_core[:, column])
        if rows.size == 0:
            continue
        breaks = np.flatnonzero(np.diff(rows) > 1) + 1
        for band_index, band in enumerate(part for part in np.split(rows, breaks) if part.size):
            bands_by_column[column].append(
                {
                    "id": add_node(),
                    "column": column,
                    "bandIndex": band_index,
                    "minimumRow": int(band[0]),
                    "maximumRow": int(band[-1]),
                    "rows": [int(value) for value in band],
                    "coreRows": [int(value) for value in band],
                }
            )

    def band_distance(left: dict[str, Any], right: dict[str, Any]) -> int:
        if left["maximumRow"] < right["minimumRow"]:
            return int(right["minimumRow"] - left["maximumRow"])
        if right["maximumRow"] < left["minimumRow"]:
            return int(left["minimumRow"] - right["maximumRow"])
        return 0

    # Seed identity is strict and adjacent-column only.  The later candidate
    # graph owns the declared one-column evidence-gap rule; discovery never
    # bridges or fills a core gap.
    for column in range(width):
        target = (column + 1) % width
        for left in bands_by_column[column]:
            for right in bands_by_column[target]:
                if band_distance(left, right) <= MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE:
                    union(int(left["id"]), int(right["id"]))

    grouped: dict[int, list[dict[str, Any]]] = {}
    for column_bands in bands_by_column:
        for band in column_bands:
            grouped.setdefault(find(int(band["id"])), []).append(band)
    strict_components: list[dict[str, Any]] = []
    for bands in grouped.values():
        envelope = shortest_circular_envelope(
            (int(band["column"]) for band in bands), width
        )
        broad = bool(envelope.size > width // 2)
        core_rows: dict[int, list[int]] = {}
        for band in bands:
            column = int(band["column"])
            core_rows.setdefault(column, []).extend(int(value) for value in band["coreRows"])
        for column in core_rows:
            core_rows[column] = sorted(set(core_rows[column]))
        strict_components.append(
            {
                "component": envelope,
                "coreRows": core_rows,
                "nativeBandNodeCount": len(bands),
                "broadHalfPerimeterResponse": broad,
            }
        )
    strict_components.sort(key=lambda item: (int(item["component"][0]), int(item["component"].size)))
    for index, item in enumerate(strict_components, 1):
        item["strictCoreSeedId"] = f"CORE{index:05d}"
    strict_by_id = {
        str(item["strictCoreSeedId"]): item for item in strict_components
    }

    interruption_mask = ~np.asarray(normal_observed, dtype=bool) | np.asarray(obstruction, dtype=bool)
    basins = [
        np.asarray(run, dtype=np.int64)
        for run in r18.CORE.group_circular_true(interruption_mask)
    ]
    basin_sets = [{int(column) for column in basin} for basin in basins]
    component_basin_ids: dict[str, list[int]] = {}
    for item in strict_components:
        columns = set(int(column) for column in item["coreRows"])
        component_basin_ids[item["strictCoreSeedId"]] = [
            index for index, basin in enumerate(basin_sets) if columns & basin
        ]

    components: list[dict[str, Any]] = []
    basin_accounted = np.zeros_like(strict_core)
    for basin_index, basin in enumerate(basins):
        core_rows = {
            int(column): [int(row) for row in np.flatnonzero(strict_core[:, int(column)])]
            for column in basin
            if bool(np.any(strict_core[:, int(column)]))
        }
        if not core_rows:
            continue
        component_rows = {
            int(column): [int(row) for row in np.flatnonzero(support[:, int(column)])]
            for column in basin
            if bool(np.any(support[:, int(column)]))
        }
        need(bool(component_rows), "Strict-core interruption basin lost native support")
        for column, rows in core_rows.items():
            basin_accounted[np.asarray(rows, dtype=np.int64), column] = True
        seed_ids = [
            item["strictCoreSeedId"]
            for item in strict_components
            if set(item["coreRows"]) & basin_sets[basin_index]
        ]
        broad_ids = [
            item["strictCoreSeedId"]
            for item in strict_components
            if item["broadHalfPerimeterResponse"]
            and item["strictCoreSeedId"] in seed_ids
        ]
        multi_ids = [
            seed_id for seed_id in seed_ids
            if len(component_basin_ids[seed_id]) > 1
        ]
        seed_rows = {
            seed_id: {
                int(column): list(strict_by_id[seed_id]["coreRows"][int(column)])
                for column in strict_by_id[seed_id]["coreRows"]
                if int(column) in basin_sets[basin_index]
            }
            for seed_id in seed_ids
        }
        discovery_authority: list[str] = []
        if broad_ids:
            discovery_authority.append("INTERSECTION_WITH_WHOLE_BROAD_STRICT_CORE_PARENT")
        if multi_ids:
            discovery_authority.append("STRICT_CORE_SEED_SPANS_MULTIPLE_NORMAL_TRACE_BASINS")
        if bool(np.any(obstruction[basin])):
            discovery_authority.append("NORMAL_TRACE_INTERRUPTION_INCLUDES_EXTERIOR_OBSTRUCTION")
        components.append(
            {
                "component": basin,
                "componentRows": component_rows,
                "coreRows": core_rows,
                "nativeSupportColumnCount": len(component_rows),
                "nativeBandNodeCount": sum(len(rows) for rows in component_rows.values()),
                "broadHalfPerimeterResponse": bool(basin.size > width // 2),
                "candidateDefinition": "MEASURED_NORMAL_TRACE_INTERRUPTION_BASIN_CONTAINING_STRICT_NATIVE_CORE",
                "normalTraceInterruptionBasinIndex": basin_index,
                "normalTraceInterruptionBasinColumnIndices": [int(value) for value in basin],
                "strictCoreSeedIds": seed_ids,
                "strictCoreRowsBySeed": seed_rows,
                "broadParentHoldIds": broad_ids,
                "multiBasinStrictCoreSeedIds": multi_ids,
                "discoveryAuthorityHoldReasons": discovery_authority,
                "obstructionOverlapColumnIndices": [
                    int(column) for column in basin if bool(obstruction[int(column)])
                ],
            }
        )

    # Broad strict-core parents are retained whole as independent immutable
    # holds.  Local interruption-basin traces may coexist but cannot partition,
    # clear, or acquire ownership of the parent.
    for item in strict_components:
        if not bool(item["broadHalfPerimeterResponse"]):
            continue
        components.append(
            {
                "component": np.asarray(item["component"], dtype=np.int64),
                "componentRows": {
                    int(column): list(rows) for column, rows in item["coreRows"].items()
                },
                "coreRows": {
                    int(column): list(rows) for column, rows in item["coreRows"].items()
                },
                "nativeSupportColumnCount": len(item["coreRows"]),
                "nativeBandNodeCount": int(item["nativeBandNodeCount"]),
                "broadHalfPerimeterResponse": True,
                "candidateDefinition": "WHOLE_BROAD_STRICT_NATIVE_CORE_PARENT_HOLD",
                "normalTraceInterruptionBasinIndex": None,
                "normalTraceInterruptionBasinColumnIndices": [],
                "strictCoreSeedIds": [item["strictCoreSeedId"]],
                "strictCoreRowsBySeed": {
                    str(item["strictCoreSeedId"]): {
                        int(column): list(rows)
                        for column, rows in item["coreRows"].items()
                    }
                },
                "broadParentHoldIds": [item["strictCoreSeedId"]],
                "multiBasinStrictCoreSeedIds": (
                    [item["strictCoreSeedId"]]
                    if len(component_basin_ids[item["strictCoreSeedId"]]) > 1
                    else []
                ),
                "discoveryAuthorityHoldReasons": ["WHOLE_BROAD_STRICT_CORE_PARENT_RETAINS_ZERO_OWNERSHIP"],
                "obstructionOverlapColumnIndices": sorted(
                    column for column in item["coreRows"] if bool(obstruction[column])
                ),
            }
        )

    components.sort(
        key=lambda item: (
            int(item["component"][0]),
            item["candidateDefinition"].startswith("WHOLE_BROAD"),
            int(item["component"].size),
        )
    )
    outside_core = strict_core & ~basin_accounted
    strict_bytes = np.ascontiguousarray(strict_core, dtype=np.uint8).tobytes()
    outside_bytes = np.ascontiguousarray(outside_core, dtype=np.uint8).tobytes()
    return {
        "valid": valid,
        "shallowRawDepth": shallow_depth.astype(np.float32),
        "thresholdPx": threshold,
        "candidateFloorPx": floor,
        "candidateFloorRole": "TELEMETRY_ONLY_NEVER_COMPONENT_OWNERSHIP",
        "baselineCenterPx": center,
        "baselineNoiseSigmaPx": noise,
        "components": components,
        "nativeCandidateBandCount": len(parent),
        "strictCoreComponentCount": len(strict_components),
        "strictCoreNodeCount": int(np.count_nonzero(strict_core)),
        "strictCoreBooleanMapSha256": hashlib.sha256(strict_bytes).hexdigest().upper(),
        "strictCoreHashPopulation": "C_ORDER_UINT8_BOOLEAN_MAP_RADIAL_ROWS_BY_ANGLE_COLUMNS",
        "normalTraceInterruptionBasinCount": len(basins),
        "qualifiedInterruptionBasinCount": sum(
            item["candidateDefinition"].startswith("MEASURED_NORMAL_TRACE") for item in components
        ),
        "broadHalfPerimeterResponseCount": sum(
            item["candidateDefinition"].startswith("WHOLE_BROAD") for item in components
        ),
        "strictCoreOutsideInterruptionNodeCount": int(np.count_nonzero(outside_core)),
        "strictCoreOutsideInterruptionBooleanMapSha256": hashlib.sha256(outside_bytes).hexdigest().upper(),
        "strictCoreOutsideInterruptionDisposition": "EXPLICIT_NONCANDIDATE_PARALLEL_CORE_UNDER_CONTINUOUS_MEASURED_NORMAL_TRACE",
        "allStrictCoreNodesAccountedFor": bool(np.array_equal(strict_core, basin_accounted | outside_core)),
        "candidateDiscoverySource": "EVERY_FULL_360_MEASURED_NORMAL_TRACE_INTERRUPTION_BASIN_CONTAINING_STRICT_NATIVE_CORE_PLUS_WHOLE_BROAD_PARENTS",
        "candidateDiscoverySmoothingPerformed": False,
        "candidateDiscoveryMorphologyPerformed": False,
        "candidateDiscoveryGapFillPerformed": False,
    }


def analyze_native_strip(
    strip: np.ndarray,
    offsets: np.ndarray,
    base_fit: dict[str, Any],
    params: Any,
    cfg: dict[str, Any],
    predecessor_measured: np.ndarray,
    channel: str,
) -> dict[str, Any]:
    """Preserve R18 fixed circles, replacing only its pre-contour selector."""
    need(strip.dtype == np.uint8 and strip.ndim == 2, "R27 strip must be uint8 grayscale")
    need(offsets.ndim == 1 and offsets.size == strip.shape[0], "R27 strip/offset geometry differs")
    need(predecessor_measured.shape == (strip.shape[1],), "R27 predecessor hold width differs")

    exterior = r18.exterior_connected_map(strip, offsets)
    circle_candidates = r18.outer_circle_candidates(exterior)
    circle = r18.fit_guarded_outer_circle(circle_candidates, base_fit)
    raw_witness = r18.raw_exterior_witness(exterior, circle["outerPath"])
    band_seed = circle["fit"]["outerBandSeedOffsetPx"]
    search_headroom = (
        None
        if band_seed is None
        else float(r18.EXTERIOR_SEARCH_MAX_OFFSET_PX - float(band_seed))
    )
    unsupported_runs = r18.CORE.group_circular_true(~circle["finalSupportColumns"])
    maximum_unsupported_samples = max((int(run.size) for run in unsupported_runs), default=0)
    cyan_verified = bool(
        circle["qualified"]
        and search_headroom is not None
        and search_headroom >= r18.MINIMUM_CYAN_SEARCH_HEADROOM_PX
        and float(circle["fit"]["angularCoverageFraction"])
        >= r18.MINIMUM_CYAN_ACCEPTED_COVERAGE
    )
    inner_circle = {
        "centerX": circle["fit"]["centerX"],
        "centerY": circle["fit"]["centerY"],
        "radius": circle["fit"]["radius"] - r18.EDGE_ZONE_INWARD_PX,
        "angleSampleCount": strip.shape[1],
    }
    need(inner_circle["radius"] > 0.0, "R27 inner circle radius is non-positive")
    inner_path = r18.circle_ray_offsets(base_fit, inner_circle)
    spacing_error = float(
        np.max(np.abs((circle["outerPath"] - inner_path) - r18.EDGE_ZONE_INWARD_PX))
    )
    need(spacing_error <= 1.0e-4, "R27 yellow circle is not exactly 20 px inward")

    exterior_frontier, exterior_observed = r18.outermost_frontier(
        exterior["supported"], exterior["searchOffsets"]
    )
    outward = np.zeros(strip.shape[1], dtype=np.float32)
    outward[exterior_observed] = (
        exterior_frontier[exterior_observed] - circle["outerPath"][exterior_observed]
    )
    obstruction = exterior_observed & (outward > r18.HOLDER_OUTWARD_RESIDUAL_PX)
    transition = r18.transition_map(strip, offsets)
    transition["directRawContrast"] = direct_native_raw_contrast(
        strip, offsets, transition["searchOffsets"]
    )
    # Preserve the accepted R18/R21 coordinate-support contract.  Every node
    # is a native-grid R18 frontier transition with positive raw (non-shadow-
    # lifted) and enhanced response.  The stricter unblurred statistic added in
    # R25 remains measured telemetry; it cannot erase an otherwise accepted
    # native transition coordinate.
    transition["nativeSupported"] = np.asarray(
        transition["frontierSupported"], dtype=bool
    )
    edge = r18.measure_pixel_edge_family(transition, circle["outerPath"])
    need(
        edge["normalObservedFraction"] >= r18.MINIMUM_BEVEL_TRACE_COVERAGE,
        "R27 normal brightness trace coverage is below the inherited gate",
    )
    need(
        edge["normalMaximumAdjacentStepPx"] is not None
        and edge["normalMaximumAdjacentStepPx"] <= r18.BEVEL_TRACE_MAX_ADJACENT_STEP_PX,
        "R27 normal brightness trace retains a discontinuity",
    )
    discovery = discover_raw_candidate_components(
        transition,
        edge["normalObserved"],
        obstruction,
        circle["outerPath"],
        cfg,
    )
    candidate_traces = [
        candidate_graph_trace(
            strip,
            offsets,
            circle["outerPath"],
            edge["normalPath"],
            edge["normalObserved"],
            transition,
            item,
            float(discovery["thresholdPx"]),
            params,
            index,
            channel,
            obstruction,
            ~predecessor_measured.astype(bool),
        )
        for index, item in enumerate(discovery["components"])
    ]
    return {
        "strip": strip,
        "offsets": offsets.astype(np.float32),
        "baseFit": {key: float(base_fit[key]) for key in ("centerX", "centerY", "radius")},
        "circleState": circle["state"],
        "circleQualified": bool(circle["qualified"]),
        "circleFit": circle["fit"],
        "cyanGeometryVerified": cyan_verified,
        "cyanGeometryVerificationState": (
            "PASS_DIAGNOSTIC_CYAN_GEOMETRY_SUPPORT_AND_HEADROOM"
            if cyan_verified
            else "HOLD_CYAN_GEOMETRY_UNVERIFIED"
        ),
        "outerPath": circle["outerPath"],
        "innerPath": inner_path,
        "transitionSearchOffsets": transition["searchOffsets"].astype(np.float32),
        "normalBrightnessPath": edge["normalPath"],
        "normalBrightnessObserved": edge["normalObserved"],
        "deepPath": edge["deepNotchPath"],
        "deepObserved": edge["deepNotchObserved"],
        "deepInwardLimit": edge["deepNotchTouchesInwardLimitColumns"],
        "predecessorHeldColumns": ~predecessor_measured.astype(bool),
        "obstructionColumns": obstruction,
        "candidateTraces": candidate_traces,
        "discovery": discovery,
        "evidence": {
            "algorithm": "R27_INTERRUPTION_BASIN_CONTINUITY_FIRST_CHANNEL_LOCAL_NATIVE_SUPPORT_GRAPH",
            "fixedOuterCircleSource": "UNCHANGED_R18_EXTERIOR_CONNECTED_CENTER_LOCKED_PHYSICAL_CIRCLE",
            "cyanGeometryChanged": False,
            "yellowInwardPx": float(r18.EDGE_ZONE_INWARD_PX),
            "maximumYellowSpacingErrorPx": spacing_error,
            "cyanSearchHeadroomPx": search_headroom,
            "cyanMaximumUnsupportedRunSamples": maximum_unsupported_samples,
            "rawExteriorWitnessObservedFraction": raw_witness["observedFraction"],
            "normalBrightnessTraceObservedFraction": edge["normalObservedFraction"],
            "candidateCount": len(candidate_traces),
            "candidateDiscoveryPopulation": "EVERY_FULL_360_MEASURED_NORMAL_TRACE_INTERRUPTION_BASIN_CONTAINING_STRICT_NATIVE_CORE_PLUS_WHOLE_BROAD_PARENTS",
            "nativeCoordinateSupport": "UNCHANGED_R18_FRONTIER_SUPPORTED_POSITIVE_RAW_AND_ENHANCED_TRANSITION",
            "directUnblurredRawContrastRole": "POST_CONTINUITY_REPRESENTATIVE_PATH_TIE_BREAK_NOT_COORDINATE_VETO",
            "strictCoreNodeCount": int(discovery["strictCoreNodeCount"]),
            "strictCoreComponentCount": int(discovery["strictCoreComponentCount"]),
            "normalTraceInterruptionBasinCount": int(discovery["normalTraceInterruptionBasinCount"]),
            "qualifiedInterruptionBasinCount": int(discovery["qualifiedInterruptionBasinCount"]),
            "broadStrictCoreParentCount": int(discovery["broadHalfPerimeterResponseCount"]),
            "strictCoreOutsideInterruptionNodeCount": int(discovery["strictCoreOutsideInterruptionNodeCount"]),
            "allStrictCoreNodesAccountedFor": bool(discovery["allStrictCoreNodesAccountedFor"]),
            "candidateDiscoverySmoothingPerformed": False,
            "candidateDiscoveryMorphologyPerformed": False,
            "candidateDiscoveryGapFillPerformed": False,
            "candidateContouringCompletedBeforeNotchSelection": True,
            "templateOrIdealCurveUsed": False,
            "interpolationPerformed": False,
            "pathCenteredWarpPerformed": False,
            "dynamicRecenteringPerformed": False,
            "crossChannelPixelCoordinateTransferPerformed": False,
            "predecessorHeldColumnCount": int(np.count_nonzero(~predecessor_measured)),
            "predecessorHoldsCleared": False,
        },
    }


def draw_native_points(
    image: np.ndarray,
    mask: np.ndarray,
    path: np.ndarray,
    observed: np.ndarray,
    offsets: np.ndarray,
    color: tuple[int, int, int],
) -> None:
    columns = np.flatnonzero(np.asarray(observed, dtype=bool) & np.isfinite(path))
    rows = np.rint(path[columns].astype(np.float64) - float(offsets[0])).astype(np.int64)
    valid = (rows >= 0) & (rows < image.shape[0])
    image[rows[valid], columns[valid]] = color
    mask[rows[valid], columns[valid]] = 255


def draw_support_points(
    image: np.ndarray,
    mask: np.ndarray,
    points: list[tuple[int, int]],
    search_offsets: np.ndarray,
    strip_offsets: np.ndarray,
    color: tuple[int, int, int],
) -> None:
    if not points:
        return
    columns = np.asarray([item[0] for item in points], dtype=np.int64)
    search_rows = np.asarray([item[1] for item in points], dtype=np.int64)
    rows = np.rint(search_offsets[search_rows] - float(strip_offsets[0])).astype(np.int64)
    valid = (rows >= 0) & (rows < image.shape[0]) & (columns >= 0) & (columns < image.shape[1])
    image[rows[valid], columns[valid]] = color
    mask[rows[valid], columns[valid]] = 255


def labeled_native_crop(image: np.ndarray, label: str) -> np.ndarray:
    result = cv2.copyMakeBorder(image, CANDIDATE_REVIEW_HEADER_PX, 0, 0, 0, cv2.BORDER_CONSTANT)
    cv2.putText(
        result,
        label,
        (7, 22),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.38,
        WHITE,
        1,
        cv2.LINE_8,
    )
    return result


def render_channel(
    root: Path,
    identity: str,
    channel: str,
    analysis: dict[str, Any],
    locked_clean_record: dict[str, Any] | None = None,
) -> dict[str, Any]:
    strip = analysis["strip"]
    offsets = analysis["offsets"]
    base = cv2.cvtColor(r18.shadow_lift(strip), cv2.COLOR_GRAY2BGR)
    geometry = base.copy()
    geometry_mask = np.zeros(strip.shape, dtype=np.uint8)
    r18.draw_circle_path(geometry, geometry_mask, analysis["outerPath"], offsets, CYAN)
    r18.draw_circle_path(geometry, geometry_mask, analysis["innerPath"], offsets, YELLOW)

    brightness = geometry.copy()
    normal_mask = np.zeros(strip.shape, dtype=np.uint8)
    draw_native_points(
        brightness,
        normal_mask,
        analysis["normalBrightnessPath"],
        analysis["normalBrightnessObserved"],
        offsets,
        LIME,
    )
    circle_brightness = brightness.copy()
    circle_changed = np.any(circle_brightness != base, axis=2)
    circle_declared = (geometry_mask > 0) | (normal_mask > 0)
    need(
        bool(np.all(~circle_changed | circle_declared)),
        "R27 circle-only review changed pixels outside fixed geometry and native brightness",
    )
    representative_mask = np.zeros(strip.shape, dtype=np.uint8)
    diagnostic_notch_mask = np.zeros(strip.shape, dtype=np.uint8)
    support_mask = np.zeros(strip.shape, dtype=np.uint8)
    for candidate in analysis["candidateTraces"]:
        draw_support_points(
            brightness,
            support_mask,
            candidate["supportPoints"],
            analysis["transitionSearchOffsets"],
            offsets,
            ORANGE,
        )
        candidate_path_mask = np.zeros(strip.shape, dtype=np.uint8)
        diagnostic_notch = bool(candidate["record"].get("diagnosticPairingEligible"))
        draw_native_points(
            brightness,
            candidate_path_mask,
            candidate["path"],
            candidate["observed"],
            offsets,
            RED if diagnostic_notch else LIME,
        )
        representative_mask = cv2.bitwise_or(representative_mask, candidate_path_mask)
        if diagnostic_notch:
            diagnostic_notch_mask = cv2.bitwise_or(
                diagnostic_notch_mask, candidate_path_mask
            )
    brightness[diagnostic_notch_mask > 0] = RED
    hold_mask = np.zeros(strip.shape, dtype=np.uint8)
    held = np.asarray(analysis["predecessorHeldColumns"], dtype=bool)
    if bool(np.any(held)):
        brightness[:HOLD_BAR_ROWS, held] = MAGENTA
        hold_mask[:HOLD_BAR_ROWS, held] = 255
    obstruction_mask = np.zeros(strip.shape, dtype=np.uint8)
    obstruction = np.asarray(analysis["obstructionColumns"], dtype=bool)
    if bool(np.any(obstruction)):
        brightness[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, obstruction] = OBSTRUCTION_BLUE
        obstruction_mask[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, obstruction] = 255

    changed = np.any(brightness != base, axis=2)
    declared = (
        (geometry_mask > 0)
        | (normal_mask > 0)
        | (representative_mask > 0)
        | (diagnostic_notch_mask > 0)
        | (support_mask > 0)
        | (hold_mask > 0)
        | (obstruction_mask > 0)
    )
    need(bool(np.all(~changed | declared)), "R27 full overlay changed pixels outside declared masks")
    need(int(np.count_nonzero(normal_mask)) > 0, "R27 normal brightness trace rendered empty")
    stem = safe_stem(identity) + "_" + channel.lower()
    trace_context_asset = write_json_new(
        root / f"{stem}_trace_context.json",
        {
            "schema": "argos_ocv03_annular_candidate_first_r27_channel_trace_context_v1",
            "identity": identity,
            "channel": channel,
            "angleSampleCount": int(strip.shape[1]),
            "degreesPerSample": 360.0 / int(strip.shape[1]),
            "radialOffsets": numeric_path(offsets),
            "outerCirclePath": numeric_path(analysis["outerPath"]),
            "innerCirclePath": numeric_path(analysis["innerPath"]),
            "normalBrightnessTracePath": numeric_path(analysis["normalBrightnessPath"]),
            "normalBrightnessObservedIndices": index_list(analysis["normalBrightnessObserved"]),
            "predecessorHeldIndices": index_list(analysis["predecessorHeldColumns"]),
            "obstructionIndices": index_list(analysis["obstructionColumns"]),
            "nativeCoordinatesOnly": True,
            "interpolationPerformed": False,
            "templateOrIdealCurveUsed": False,
            "crossChannelPixelCoordinateTransferPerformed": False,
        },
    )
    assets: dict[str, Any] = {
        "fullClean": (
            locked_clean_record
            if locked_clean_record is not None
            else write_png_new(root / f"{stem}_full_clean.png", strip)
        ),
        "fullEnhancedClean": write_png_new(root / f"{stem}_full_enhanced_clean.png", r18.shadow_lift(strip)),
        "circleAndBrightnessReview": write_png_new(
            root / f"{stem}_circle_brightness_review.png", circle_brightness
        ),
        "allCandidateContourReview": write_png_new(
            root / f"{stem}_all_candidate_contours_review.png", brightness
        ),
        "fixedCircleGeometryMask": write_png_new(root / f"{stem}_fixed_circle_geometry_mask.png", geometry_mask),
        "nativeBrightnessTraceMask": write_png_new(root / f"{stem}_native_brightness_trace_mask.png", normal_mask),
        "candidateRepresentativeTraceMask": write_png_new(root / f"{stem}_candidate_trace_mask.png", representative_mask),
        "diagnosticNotchCandidateMask": write_png_new(root / f"{stem}_diagnostic_notch_mask.png", diagnostic_notch_mask),
        "candidateSupportGraphMask": write_png_new(root / f"{stem}_candidate_support_graph_mask.png", support_mask),
        "predecessorHoldMask": write_png_new(root / f"{stem}_predecessor_hold_mask.png", hold_mask),
        "obstructionHoldMask": write_png_new(root / f"{stem}_obstruction_hold_mask.png", obstruction_mask),
        "traceContext": trace_context_asset,
        "renderSemantics": {
            "normalBrightnessPixelCount": int(np.count_nonzero(normal_mask)),
            "circleOnlyNormalBrightnessPixelCount": int(np.count_nonzero(normal_mask)),
            "candidateRepresentativePixelCount": int(np.count_nonzero(representative_mask)),
            "diagnosticNotchCandidatePixelCount": int(np.count_nonzero(diagnostic_notch_mask)),
            "candidateSupportGraphPixelCount": int(np.count_nonzero(support_mask)),
            "predecessorHoldPixelCount": int(np.count_nonzero(hold_mask)),
            "obstructionHoldPixelCount": int(np.count_nonzero(obstruction_mask)),
            "circleOnlyChangedPixelsInsideGeometryAndNormalMasks": True,
            "allCandidateChangedPixelsInsideDeclaredMasks": True,
            "allChangedPixelsInsideDeclaredMasks": True,
        },
        "candidateReviews": [],
    }
    width = strip.shape[1]
    for candidate in analysis["candidateTraces"]:
        record = candidate["record"]
        span = np.asarray(candidate["span"], dtype=np.int64)
        need(span.size > 0, f"{record['candidateId']} has an empty review span")
        padding = min(32, max(0, (width - int(span.size)) // 2))
        review_count = min(width, max(2 * CANDIDATE_REVIEW_HALF_WIDTH_COLUMNS + 1, int(span.size) + 2 * padding))
        review_start = (int(span[0]) - padding) % width
        columns = (review_start + np.arange(review_count, dtype=np.int64)) % width
        clean_crop = strip[:, columns].copy()
        candidate_canvas = geometry.copy()
        context_mask = np.zeros(strip.shape, dtype=np.uint8)
        candidate_trace_mask = np.zeros(strip.shape, dtype=np.uint8)
        candidate_diagnostic_notch_mask = np.zeros(strip.shape, dtype=np.uint8)
        candidate_support_mask = np.zeros(strip.shape, dtype=np.uint8)
        candidate_hold_mask = np.zeros(strip.shape, dtype=np.uint8)
        candidate_obstruction_mask = np.zeros(strip.shape, dtype=np.uint8)
        draw_native_points(
            candidate_canvas,
            context_mask,
            analysis["normalBrightnessPath"],
            analysis["normalBrightnessObserved"],
            offsets,
            LIME,
        )
        draw_support_points(
            candidate_canvas,
            candidate_support_mask,
            candidate["supportPoints"],
            analysis["transitionSearchOffsets"],
            offsets,
            ORANGE,
        )
        draw_native_points(
            candidate_canvas,
            candidate_trace_mask,
            candidate["path"],
            candidate["observed"],
            offsets,
            RED if bool(record.get("diagnosticPairingEligible")) else LIME,
        )
        if bool(record.get("diagnosticPairingEligible")):
            candidate_diagnostic_notch_mask = candidate_trace_mask.copy()
        candidate_scope = np.zeros(width, dtype=bool)
        candidate_scope[span] = True
        scoped_hold = held & candidate_scope
        scoped_obstruction = obstruction & candidate_scope
        if bool(np.any(scoped_hold)):
            candidate_canvas[:HOLD_BAR_ROWS, scoped_hold] = MAGENTA
            candidate_hold_mask[:HOLD_BAR_ROWS, scoped_hold] = 255
        if bool(np.any(scoped_obstruction)):
            candidate_canvas[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, scoped_obstruction] = OBSTRUCTION_BLUE
            candidate_obstruction_mask[HOLD_BAR_ROWS : 2 * HOLD_BAR_ROWS, scoped_obstruction] = 255
        candidate_changed = np.any(candidate_canvas != base, axis=2)
        candidate_declared = (
            (geometry_mask > 0)
            | (context_mask > 0)
            | (candidate_trace_mask > 0)
            | (candidate_diagnostic_notch_mask > 0)
            | (candidate_support_mask > 0)
            | (candidate_hold_mask > 0)
            | (candidate_obstruction_mask > 0)
        )
        need(bool(np.all(~candidate_changed | candidate_declared)), f"{record['candidateId']} changed pixels outside its masks")
        review_crop = candidate_canvas[:, columns].copy()
        context_crop = context_mask[:, columns].copy()
        trace_crop = candidate_trace_mask[:, columns].copy()
        support_crop = candidate_support_mask[:, columns].copy()
        hold_crop = candidate_hold_mask[:, columns].copy()
        obstruction_crop = candidate_obstruction_mask[:, columns].copy()
        expected_trace_pixels = int(np.count_nonzero(candidate["observed"]))
        expected_diagnostic_pixels = (
            expected_trace_pixels if bool(record.get("diagnosticPairingEligible")) else 0
        )
        expected_support_pixels = len(set(candidate["supportPoints"]))
        need(
            not record["rawComponentNativeNodes"] or expected_support_pixels > 0,
            f"{record['candidateId']} has native component evidence but no rendered candidate graph",
        )
        need(int(np.count_nonzero(trace_crop)) == expected_trace_pixels, f"{record['candidateId']} local trace mask count differs")
        need(
            int(np.count_nonzero(candidate_diagnostic_notch_mask[:, columns]))
            == expected_diagnostic_pixels,
            f"{record['candidateId']} diagnostic notch mask count differs",
        )
        need(int(np.count_nonzero(support_crop)) == expected_support_pixels, f"{record['candidateId']} local support mask count differs")
        label = (
            f"{identity} {channel} {record['candidateId']} {record['classification']} | "
            "CYAN fixed outer | YELLOW fixed -20px | LIME native brightness | "
            "ORANGE candidate graph | RED diagnostic notch-shaped trace, unowned | "
            "MAGENTA inherited hold | BLUE obstruction hold"
        )
        candidate_stem = f"{stem}_{record['candidateId'].lower()}"
        candidate_record_path = root / f"{candidate_stem}_trace.json"
        trace_payload = {
            "schema": TRACE_SCHEMA,
            "identity": identity,
            "channel": channel,
            "angleSampleCount": width,
            "degreesPerSample": 360.0 / width,
            "channelTraceContext": trace_context_asset,
            "candidate": record,
            "candidateCoordinateEncoding": (
                "SPARSE_REPRESENTATIVE_PATH_COMPLETE_SUPPORT_GRAPH_AND_FULL_CANDIDATE_NATIVE_GRAPH_NO_FILL"
            ),
            "channelContextStoredOncePerChannel": True,
            "nativeCoordinatesOnly": True,
            "interpolationPerformed": False,
            "templateOrIdealCurveUsed": False,
            "crossChannelPixelCoordinateTransferPerformed": False,
        }
        trace_asset = write_json_new(candidate_record_path, trace_payload)
        candidate_assets = {
            "candidateId": record["candidateId"],
            "centerAngleDegrees": record.get("centerAngleDegrees"),
            "diagnosticPairingEligible": bool(record.get("diagnosticPairingEligible")),
            "clean": write_png_new(root / f"{candidate_stem}_clean.png", clean_crop),
            "review": write_png_new(root / f"{candidate_stem}_review.png", labeled_native_crop(review_crop, label)),
            "normalTraceContextMask": write_png_new(root / f"{candidate_stem}_normal_context_mask.png", context_crop),
            "nativeTraceMask": write_png_new(root / f"{candidate_stem}_native_trace_mask.png", trace_crop),
            "diagnosticNotchMask": write_png_new(
                root / f"{candidate_stem}_diagnostic_notch_mask.png",
                candidate_diagnostic_notch_mask[:, columns].copy(),
            ),
            "supportGraphMask": write_png_new(root / f"{candidate_stem}_support_graph_mask.png", support_crop),
            "inheritedHoldMask": write_png_new(root / f"{candidate_stem}_inherited_hold_mask.png", hold_crop),
            "obstructionHoldMask": write_png_new(root / f"{candidate_stem}_obstruction_hold_mask.png", obstruction_crop),
            "renderSemantics": {
                "expectedRepresentativeNativePixelCount": expected_trace_pixels,
                "renderedRepresentativeNativePixelCount": int(np.count_nonzero(trace_crop)),
                "expectedDiagnosticNotchPixelCount": expected_diagnostic_pixels,
                "diagnosticNotchCandidatePixelCount": int(
                    np.count_nonzero(candidate_diagnostic_notch_mask[:, columns])
                ),
                "expectedCandidateGraphPixelCount": expected_support_pixels,
                "renderedCandidateGraphPixelCount": int(np.count_nonzero(support_crop)),
                "normalContextPixelCount": int(np.count_nonzero(context_crop)),
                "allChangedPixelsInsideDeclaredMasks": True,
                "candidateLocalOnly": True,
            },
            "trace": trace_asset,
            "sourceColumnStart": int(columns[0]),
            "sourceColumnEnd": int(columns[-1]),
            "cyclicWrapUsed": bool(columns[0] > columns[-1]),
            "sourceColumnCount": int(columns.size),
            "resamplingPerformed": False,
            "pathCenteredWarpPerformed": False,
        }
        assets["candidateReviews"].append(candidate_assets)
    return assets


def public_candidate_records(analysis: dict[str, Any]) -> list[dict[str, Any]]:
    return [candidate["record"] for candidate in analysis["candidateTraces"]]


def iter_hash_records(value: Any, pointer: str = "$") -> Iterable[tuple[str, dict[str, Any]]]:
    if isinstance(value, dict):
        path = value.get("path")
        digest = value.get("sha256")
        if isinstance(path, str) and isinstance(digest, str) and re.fullmatch(r"[0-9A-Fa-f]{64}", digest):
            yield pointer, value
        for key, child in value.items():
            yield from iter_hash_records(child, f"{pointer}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from iter_hash_records(child, f"{pointer}[{index}]")


def resolve_manifest_record_path(
    path_text: str,
    pointer: str,
    code_root: Path,
    workspace_io: Path,
) -> Path:
    normalized = path_text.replace("\\", "/")
    if normalized.upper().startswith("R:/"):
        return workspace_io / normalized[3:]
    path = Path(path_text)
    if path.is_absolute():
        return path
    if pointer.startswith("$.post2Inputs.rasters["):
        return workspace_io / normalized
    return code_root / normalized


def verify_rollover_closure(
    manifest_path: Path,
    manifest_sha256: str,
    gate_path: Path,
    gate_sha256: str,
    checkpoint_path: Path,
    checkpoint_sha256: str,
    code_root: Path,
    workspace_io: Path,
) -> dict[str, Any]:
    need(manifest_sha256.upper() == ROLLOVER_MANIFEST_SHA256, "Rollover-manifest pin differs from R24")
    need(gate_sha256.upper() == ROLLOVER_GATE_SHA256, "Rollover-gate pin differs from R24")
    need(checkpoint_sha256.upper() == CHECKPOINT_SHA256, "Checkpoint pin differs from R24")
    require_exact_file(checkpoint_path, checkpoint_sha256, "R24 checkpoint")
    manifest = load_json_pinned(manifest_path, manifest_sha256, "R24 rollover manifest")
    gate = load_json_pinned(gate_path, gate_sha256, "R24 rollover gate")
    need(
        manifest.get("revision")
        == "OCV03_O3F16R23_R24_CANDIDATE_FIRST_ROLLOVER_20260904",
        "Rollover revision differs",
    )
    need(
        gate.get("state") == "PASS_O3F16_R23_R24_FILE_BACKED_ROLLOVER_READY",
        "Rollover gate is not PASS",
    )
    checked: dict[str, dict[str, Any]] = {}
    pointers: dict[str, list[str]] = {}
    for pointer, record in iter_hash_records(manifest):
        path = resolve_manifest_record_path(str(record["path"]), pointer, code_root, workspace_io)
        key = str(path.absolute()).lower()
        expected = str(record["sha256"]).upper()
        size = int(record["bytes"]) if record.get("bytes") is not None else None
        if key in checked:
            need(checked[key]["sha256"] == expected, f"Conflicting manifest hashes for {path}")
            if size is not None and checked[key].get("bytes") is not None:
                need(int(checked[key]["bytes"]) == size, f"Conflicting manifest byte counts for {path}")
            pointers[key].append(pointer)
            continue
        require_exact_file(path, expected, f"rollover dependency {pointer}", size)
        checked[key] = {
            "path": str(path),
            "bytes": path.stat().st_size,
            "sha256": expected,
        }
        pointers[key] = [pointer]
    need(len(checked) == 64, f"Rollover closure count changed: expected 64, got {len(checked)}")
    post2_bmps = [
        row for key, row in checked.items()
        if any(pointer.startswith("$.post2Inputs.rasters[") for pointer in pointers[key])
    ]
    need(len(post2_bmps) == 6, "Rollover closure does not contain exactly six POST2 BMPs")
    need(
        all(Path(row["path"]).drive.upper() == workspace_io.drive.upper() for row in post2_bmps),
        "POST2 BMP closure did not resolve through the frozen workspace alias",
    )
    return {
        "checkpoint": file_record(checkpoint_path, checkpoint_sha256),
        "manifest": file_record(manifest_path, manifest_sha256),
        "gate": file_record(gate_path, gate_sha256),
        "uniquePinnedFileCount": len(checked),
        "post2BmpCount": len(post2_bmps),
        "post2BmpResolution": "R_ALIAS_BOUND_TO_MANIFEST_DESKTOP_AUTHORITY_ROOT",
        "records": sorted(checked.values(), key=lambda row: row["path"].lower()),
    }


def verify_engine_lineage() -> list[dict[str, Any]]:
    require_exact_file(R21_PATH, R21_SHA256, "R21 engine")
    require_exact_file(R22_PATH, R22_SHA256, "R22 engine")
    require_exact_file(R23_PATH, R23_SHA256, "R23 engine")
    require_exact_file(R26_PATH, R26_SHA256, "frozen R26 predecessor engine")
    require_exact_file(EXTERNAL_R18_PATH, r21.r19.R18_SHA256, "external R18 engine")
    require_exact_file(R18_BASELINE_SUMMARY, R18_BASELINE_SUMMARY_SHA256, "R18 baseline summary")
    require_exact_file(R20_BASELINE_SUMMARY, R20_BASELINE_SUMMARY_SHA256, "R20 baseline summary")
    r21.preflight_lineage()
    runtime = Path(sys.executable)
    require_exact_file(runtime, RUNTIME_SHA256, "pinned Python runtime")
    require_exact_file(COMPACT_PATH, COMPACT_SHA256, "pinned Windows compact utility")
    need(cv2.__version__ == "5.0.0", f"OpenCV version changed: {cv2.__version__}")
    need(np.__version__ == "2.5.2", f"NumPy version changed: {np.__version__}")
    loaded: list[Path] = []
    for module in sys.modules.values():
        source = getattr(module, "__file__", None)
        if not source:
            continue
        path = Path(source)
        if path.suffix.lower() == ".py" and (
            path.parent == HERE or path.parent == EXTERNAL_R18_PATH.parent
        ):
            loaded.append(path)
    records = [file_record(path) for path in sorted(set(loaded), key=lambda item: str(item).lower())]
    records.append(file_record(R26_PATH, R26_SHA256))
    records.append(file_record(COMPACT_PATH, COMPACT_SHA256))
    need(any(Path(row["path"]).resolve() == EXTERNAL_R18_PATH.resolve() for row in records), "External R18 was not loaded")
    return records


def load_r22_inherited_post2_authority() -> dict[str, Any]:
    r22_summary = load_json_pinned(R22_SUMMARY, R22_SUMMARY_SHA256, "R22 label-free inference summary")
    r22_gate = load_json_pinned(R22_GATE, R22_GATE_SHA256, "R22 label-free inference gate")
    require_exact_file(R23_SUMMARY, R23_SUMMARY_SHA256, "R23 post-freeze held-review summary")
    require_exact_file(R23_GATE, R23_GATE_SHA256, "R23 post-freeze held-review gate")
    need(
        r22_summary.get("state") == "COMPLETE_DIAGNOSTIC_ONLY_R22_POST2_INFERENCE"
        and r22_gate.get("state") == "HOLD_R22_POST2_INFERENCE_CONTRACT_FAILURE"
        and r22_gate.get("checks", {}).get("allNotchOwnershipUnambiguous") is False,
        "R22 inherited hold authority differs",
    )
    need(
        str(r22_gate.get("summary", {}).get("sha256", "")).upper() == R22_SUMMARY_SHA256,
        "R22 gate does not bind the inherited summary",
    )
    by_identity: dict[str, Any] = {}
    ownership_hold_count = 0
    cyan_hold_count = 0
    for result in r22_summary.get("results", []):
        identity = str(result.get("identity"))
        need(identity and identity not in by_identity, "R22 inherited identity is missing or duplicated")
        channels: dict[str, Any] = {}
        for channel in ("BF", "DF"):
            prior = result["channels"][channel]
            ownership = prior["notchOwnership"]
            need(
                ownership.get("state") == "HOLD_NO_UNIQUE_R21_CONTOUR_OWNERSHIP_METRICS"
                and int(ownership.get("notchOwnedColumnCount", -1)) == 0,
                f"{identity} {channel} R22 ownership hold differs",
            )
            ownership_hold_count += 1
            cyan_state = str(prior["cyanGeometryVerificationState"])
            cyan_verified = bool(prior["cyanGeometryVerified"])
            if cyan_state.startswith("HOLD_"):
                cyan_hold_count += 1
            r22_broad_response = None
            if identity.endswith("SLOT17") and channel == "BF":
                broad_rows = [
                    row for row in prior.get("prePairNotchCandidates", [])
                    if float(row.get("widthDegrees", 0.0)) >= 10.0
                    and row.get("startAngleDegrees") is not None
                    and (
                        (89.64 - float(row["startAngleDegrees"]) % 360.0) % 360.0
                        <= float(row["widthDegrees"]) + 1.0e-9
                    )
                ]
                need(len(broad_rows) == 1, "R22 SLOT17 BF broad response authority differs")
                broad = broad_rows[0]
                r22_broad_response = {
                    "sourceSummarySha256": R22_SUMMARY_SHA256,
                    "sourcePopulation": "prePairNotchCandidates",
                    "centerAngleDegrees": float(broad["centerAngleDegrees"]),
                    "startAngleDegrees": float(broad["startAngleDegrees"]),
                    "endAngleDegrees": float(broad["endAngleDegrees"]),
                    "widthDegrees": float(broad["widthDegrees"]),
                }
            channels[channel] = {
                "r22NotchOwnership": ownership,
                "r22CyanGeometryVerificationState": cyan_state,
                "r22CyanGeometryVerified": cyan_verified,
                "r22HoldClearancePerformed": False,
                "r23OverallHeldReviewState": "HOLD_R23_POST2_VISUAL_COMPARISON_NOTCH_OWNERSHIP_UNRESOLVED",
                "r22BroadResponse": r22_broad_response,
            }
        by_identity[identity] = {"channels": channels, "r22PairState": result["pairDiagnostic"]["state"]}
    need(len(by_identity) == 3, "R22 inherited POST2 cardinality differs")
    need(ownership_hold_count == 6 and cyan_hold_count == 5, "R22 inherited hold counts differ")
    return {
        "records": {
            "r22Summary": file_record(R22_SUMMARY, R22_SUMMARY_SHA256),
            "r22Gate": file_record(R22_GATE, R22_GATE_SHA256),
            "r23SummaryHashVerifiedWithoutJsonParse": file_record(R23_SUMMARY, R23_SUMMARY_SHA256),
            "r23GateHashVerifiedWithoutJsonParse": file_record(R23_GATE, R23_GATE_SHA256),
        },
        "byIdentity": by_identity,
        "r22OwnershipHoldCount": ownership_hold_count,
        "r22CyanHoldCount": cyan_hold_count,
        "r23JsonParsedBeforeNeutralFreeze": False,
    }


def resolve_alias_path(workspace_io: Path, value: str) -> Path:
    normalized = value.replace("\\", "/")
    need(normalized.upper().startswith("R:/"), f"Expected frozen R: path: {value}")
    result = workspace_io / normalized[3:]
    try:
        result.absolute().relative_to(workspace_io.absolute())
    except ValueError as exc:
        raise RuntimeError(f"Alias path escapes workspace: {value}") from exc
    return result


def verify_post2_sources(
    workspace_io: Path,
    source_job: dict[str, Any],
) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    members = source_job.get("inputs")
    need(
        isinstance(members, list)
        and len(members) == int(source_job.get("expectedInputCount", -1)) == 3,
        "POST2 source-job cardinality differs",
    )
    identities = [str(member.get("identity")) for member in members]
    need(len(set(identities)) == 3, "POST2 identities are not unique")
    source_rows: list[dict[str, Any]] = []
    seeds: dict[str, dict[str, Any]] = {}
    for member in members:
        identity = str(member["identity"])
        seed_record = member["r6SeedResult"]
        seed_path = resolve_alias_path(workspace_io, str(seed_record["path"]))
        seed = load_json_pinned(seed_path, str(seed_record["sha256"]), f"{identity} R6 seed")
        need(seed.get("identity") == identity and bool(seed.get("reviewOnly")), f"{identity} R6 seed authority differs")
        seeds[identity] = seed
        for channel, key in (("BF", "bf"), ("DF", "df")):
            record = member[key]
            path = resolve_alias_path(workspace_io, str(record["path"]))
            require_exact_file(path, str(record["sha256"]), f"{identity} {channel} source", int(record["bytes"]))
            actual = str(record["sha256"]).upper()
            need(
                str(seed["sources"][f"{key}Sha256"]).upper() == actual,
                f"{identity} {channel} R6/source hash differs",
            )
            source_rows.append(
                {
                    "identity": identity,
                    "channel": channel,
                    "path": str(path),
                    "bytes": path.stat().st_size,
                    "sha256": actual,
                    "seedPath": str(seed_path),
                    "seedSha256": str(seed_record["sha256"]).upper(),
                }
            )
    return source_rows, seeds


def candidate_interval_overlap(left: dict[str, Any], right: dict[str, Any]) -> float:
    left_indices = left.get("tracedShoulderColumnIndices") or left.get("componentColumnIndices") or []
    right_indices = right.get("tracedShoulderColumnIndices") or right.get("componentColumnIndices") or []
    left_samples = int(left.get("angleSampleCount", 0))
    right_samples = int(right.get("angleSampleCount", 0))
    if left_samples > 0 and left_samples == right_samples and left_indices and right_indices:
        left_set = {int(value) % left_samples for value in left_indices}
        right_set = {int(value) % right_samples for value in right_indices}
        return float(len(left_set & right_set) / max(1, min(len(left_set), len(right_set))))

    def segments(candidate: dict[str, Any]) -> list[tuple[float, float]]:
        start = float(candidate["startAngleDegrees"]) % 360.0
        width = min(max(float(candidate["widthDegrees"]), 0.0), 360.0)
        if width >= 360.0:
            return [(0.0, 360.0)]
        end = start + width
        if end <= 360.0:
            return [(start, end)]
        return [(start, 360.0), (0.0, end - 360.0)]

    left_segments = segments(left)
    right_segments = segments(right)
    overlap = sum(
        max(0.0, min(left_end, right_end) - max(left_start, right_start))
        for left_start, left_end in left_segments
        for right_start, right_end in right_segments
    )
    denominator = min(float(left["widthDegrees"]), float(right["widthDegrees"]))
    return 0.0 if denominator <= 0.0 else float(min(1.0, overlap / denominator))


def pair_after_channel_contours(
    bf_candidates: list[dict[str, Any]],
    df_candidates: list[dict[str, Any]],
    bf_circle: dict[str, Any],
    df_circle: dict[str, Any],
    params: Any,
    r6_angle: float | None,
    bf_circle_qualified: bool,
    df_circle_qualified: bool,
) -> dict[str, Any]:
    center_difference = math.hypot(
        float(bf_circle["centerX"]) - float(df_circle["centerX"]),
        float(bf_circle["centerY"]) - float(df_circle["centerY"]),
    )
    radius_difference = abs(float(bf_circle["radius"]) - float(df_circle["radius"]))
    circle_qualified = bool(
        bf_circle_qualified
        and df_circle_qualified
        and center_difference <= float(params.maximum_channel_center_difference_px)
        and radius_difference <= float(params.maximum_channel_radius_difference_px)
    )
    pairs: list[dict[str, Any]] = []
    eligible: list[dict[str, Any]] = []
    if circle_qualified:
        for bf_index, bf in enumerate(bf_candidates):
            if not bool(bf.get("diagnosticPairingEligible")):
                continue
            for df_index, df in enumerate(df_candidates):
                if not bool(df.get("diagnosticPairingEligible")):
                    continue
                difference = circular_distance_degrees(
                    float(bf["centerAngleDegrees"]), float(df["centerAngleDegrees"])
                )
                if difference > float(params.candidate_match_tolerance_degrees):
                    continue
                overlap = candidate_interval_overlap(bf, df)
                row = {
                    "bfCandidateIndex": bf_index,
                    "dfCandidateIndex": df_index,
                    "bfAngleDegrees": float(bf["centerAngleDegrees"]),
                    "dfAngleDegrees": float(df["centerAngleDegrees"]),
                    "channelAngleDifferenceDegrees": difference,
                    "crossChannelIntervalOverlapFraction": overlap,
                    "widthDifferenceDegrees": abs(float(bf["widthDegrees"]) - float(df["widthDegrees"])),
                    "depthDifferencePx": abs(float(bf.get("maximumInwardDepthPx", 0.0)) - float(df.get("maximumInwardDepthPx", 0.0))),
                    "apexCountAgreement": bf.get("apexCount") == df.get("apexCount"),
                    "leftMonotonicDifference": abs(float(bf.get("leftMonotonicSupportFraction", 0.0)) - float(df.get("leftMonotonicSupportFraction", 0.0))),
                    "rightMonotonicDifference": abs(float(bf.get("rightMonotonicSupportFraction", 0.0)) - float(df.get("rightMonotonicSupportFraction", 0.0))),
                    "bothManufacturedCompatibleAfterContour": bool(
                        bf.get("manufacturedCompatibleAfterContour")
                        and df.get("manufacturedCompatibleAfterContour")
                    ),
                    "r6SecondaryBfDistanceDegrees": (
                        None
                        if r6_angle is None
                        else circular_distance_degrees(float(bf["centerAngleDegrees"]), r6_angle)
                    ),
                    "r6SecondaryDfDistanceDegrees": (
                        None
                        if r6_angle is None
                        else circular_distance_degrees(float(df["centerAngleDegrees"]), r6_angle)
                    ),
                }
                row["r6SecondaryMaximumChannelDistanceDegrees"] = (
                    None
                    if r6_angle is None
                    else max(
                        float(row["r6SecondaryBfDistanceDegrees"]),
                        float(row["r6SecondaryDfDistanceDegrees"]),
                    )
                )
                row["eligibleAfterAllChannelLocalContours"] = bool(
                    row["bothManufacturedCompatibleAfterContour"]
                    and overlap >= float(params.manufactured_minimum_cross_channel_overlap)
                )
                pairs.append(row)
                if row["eligibleAfterAllChannelLocalContours"]:
                    eligible.append(row)

    corroborated = [
        row for row in eligible
        if r6_angle is not None
        and float(row["r6SecondaryMaximumChannelDistanceDegrees"])
        <= R6_SECONDARY_TOLERANCE_DEGREES
    ]
    resolved: list[dict[str, Any]] = []
    if len(eligible) == 1 and r6_angle is None:
        resolved = eligible
        state = "DIAGNOSTIC_UNIQUE_POST_CONTOUR_PAIR_NO_R6_SECONDARY"
    elif len(eligible) == 1 and len(corroborated) == 1:
        resolved = eligible
        state = "DIAGNOSTIC_UNIQUE_POST_CONTOUR_PAIR_R6_SECONDARY_CORROBORATED"
    elif len(eligible) == 1:
        state = "HOLD_UNIQUE_POST_CONTOUR_PAIR_CONFLICTS_WITH_R6_SECONDARY"
    elif not eligible:
        state = "HOLD_NO_BF_DF_MANUFACTURED_PAIR_AFTER_CONTOUR"
    else:
        state = "HOLD_AMBIGUOUS_BF_DF_MANUFACTURED_PAIR_AFTER_CONTOUR"

    bf_qualified = [row for row in bf_candidates if row.get("diagnosticPairingEligible")]
    df_qualified = [row for row in df_candidates if row.get("diagnosticPairingEligible")]
    same_chuck = None
    bf_local_holds = []
    bf_local_qualified: list[dict[str, Any]] = []
    if len(df_qualified) == 1:
        df_reference = df_qualified[0]
        bf_local_qualified = [
            row for row in bf_qualified if candidate_interval_overlap(row, df_reference) > 0.0
        ]
        bf_local_holds = [
            row for row in bf_candidates
            if not bool(row.get("diagnosticPairingEligible"))
            and (
                str(row.get("state", "")).startswith("HOLD_")
                or row.get("classification") == "NON_NOTCH_DEEP_EDGE_RESPONSE"
            )
            and row.get("startAngleDegrees") is not None
            and candidate_interval_overlap(row, df_reference) > 0.0
        ]
    if (
        circle_qualified
        and not bf_local_qualified
        and len(df_qualified) == 1
        and bf_local_holds
        and (
            r6_angle is None
            or circular_distance_degrees(
                float(df_qualified[0]["centerAngleDegrees"]), r6_angle
            ) <= R6_SECONDARY_TOLERANCE_DEGREES
        )
    ):
        df = df_qualified[0]
        same_chuck = {
            "state": "DIAGNOSTIC_DF_ONLY_SAME_CHUCK_ANGLE_INTERVAL_BF_LOCAL_CONTOUR_HOLD_RETAINED",
            "angleDegrees": float(df["centerAngleDegrees"]),
            "startAngleDegrees": float(df["startAngleDegrees"]),
            "endAngleDegrees": float(df["endAngleDegrees"]),
            "sourceChannel": "DF",
            "targetChannel": "BF",
            "transferredPixelCoordinateCount": 0,
            "bfContourHoldRetained": True,
            "futureRegistrationAuthorityGranted": False,
            "lawfulCircleComparisonRequiredAndPassed": True,
            "bfHeldLocalCandidateIds": [row["candidateId"] for row in bf_local_holds],
        }
    return {
        "state": state,
        "channelContoursCompletedBeforePairing": True,
        "circleComparison": {
            "centerDifferencePx": center_difference,
            "radiusDifferencePx": radius_difference,
            "qualified": circle_qualified,
            "bfQualified": bool(bf_circle_qualified),
            "dfQualified": bool(df_circle_qualified),
            "poseAveraged": False,
        },
        "physicalPairs": pairs,
        "bfDiagnosticPairingIneligibleCandidateIds": [
            row["candidateId"]
            for row in bf_candidates
            if not bool(row.get("diagnosticPairingEligible"))
        ],
        "dfDiagnosticPairingIneligibleCandidateIds": [
            row["candidateId"]
            for row in df_candidates
            if not bool(row.get("diagnosticPairingEligible"))
        ],
        "bfCandidateLocalAuthorityIneligibleBeforeGlobalHoldIds": [
            row["candidateId"]
            for row in bf_candidates
            if not bool(row.get("candidateLocalAuthorityEligibleBeforeGlobalHold"))
        ],
        "dfCandidateLocalAuthorityIneligibleBeforeGlobalHoldIds": [
            row["candidateId"]
            for row in df_candidates
            if not bool(row.get("candidateLocalAuthorityEligibleBeforeGlobalHold"))
        ],
        "eligiblePairCountBeforeR6Secondary": len(eligible),
        "r6SecondaryCorroboratedEligiblePairCount": len(corroborated),
        "resolvedPairCount": len(resolved),
        "resolvedPairs": resolved,
        "r6AngleConsumedAfterAllContours": r6_angle is not None,
        "r6SecondaryToleranceDegrees": R6_SECONDARY_TOLERANCE_DEGREES,
        "r6SecondaryTieBreakPerformed": False,
        "r6SecondarySelectionPerformed": False,
        "sameChuckAngleOnlyTransfer": same_chuck,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "holdClearancePerformed": False,
        "productionSelectionPerformed": False,
    }


def channel_summary(
    analysis: dict[str, Any],
    source: dict[str, Any],
    assets: dict[str, Any],
    seed_fit: dict[str, Any],
    inherited_authority: dict[str, Any] | None = None,
) -> dict[str, Any]:
    inherited_hold_retained = bool(
        inherited_authority is None
        or (
            inherited_authority["r22NotchOwnership"]["state"]
            == "HOLD_NO_UNIQUE_R21_CONTOUR_OWNERSHIP_METRICS"
            and int(inherited_authority["r22NotchOwnership"]["notchOwnedColumnCount"]) == 0
            and inherited_authority["r22HoldClearancePerformed"] is False
            and inherited_authority["r23OverallHeldReviewState"]
            == "HOLD_R23_POST2_VISUAL_COMPARISON_NOTCH_OWNERSHIP_UNRESOLVED"
        )
    )
    prior_cyan_state = (
        None if inherited_authority is None
        else str(inherited_authority["r22CyanGeometryVerificationState"])
    )
    cyan_authority_state = (
        analysis["cyanGeometryVerificationState"]
        if prior_cyan_state is None or not prior_cyan_state.startswith("HOLD_")
        else prior_cyan_state
    )
    inherited_cyan_hold_retained = bool(
        prior_cyan_state is None
        or not prior_cyan_state.startswith("HOLD_")
        or cyan_authority_state == prior_cyan_state
    )
    return {
        "source": source,
        "seedFit": seed_fit,
        "decodedAnnularGeometry": {
            "rows": int(analysis["strip"].shape[0]),
            "columns": int(analysis["strip"].shape[1]),
            "dtype": str(analysis["strip"].dtype),
            "radialPitchPx": 1.0,
        },
        "circleFit": analysis["circleFit"],
        "circleState": analysis["circleState"],
        "circleQualified": analysis["circleQualified"],
        "cyanGeometryVerified": analysis["cyanGeometryVerified"],
        "cyanGeometryVerificationState": analysis["cyanGeometryVerificationState"],
        "r27DiagnosticCyanGeometryVerified": analysis["cyanGeometryVerified"],
        "r27DiagnosticCyanGeometryVerificationState": analysis["cyanGeometryVerificationState"],
        "cyanGeometryAuthorityState": cyan_authority_state,
        "inheritedR22CyanHoldRetained": inherited_cyan_hold_retained,
        "edgeZoneInwardPx": float(r18.EDGE_ZONE_INWARD_PX),
        "maximumEdgeZoneSpacingErrorPx": float(analysis["evidence"]["maximumYellowSpacingErrorPx"]),
        "candidateDiscovery": {
            "population": analysis["evidence"]["candidateDiscoveryPopulation"],
            "thresholdPx": float(analysis["discovery"]["thresholdPx"]),
            "candidateFloorPx": float(analysis["discovery"]["candidateFloorPx"]),
            "candidateFloorRole": analysis["discovery"]["candidateFloorRole"],
            "baselineCenterPx": float(analysis["discovery"]["baselineCenterPx"]),
            "baselineNoiseSigmaPx": float(analysis["discovery"]["baselineNoiseSigmaPx"]),
            "candidateCount": len(analysis["candidateTraces"]),
            "strictCoreComponentCount": int(analysis["discovery"]["strictCoreComponentCount"]),
            "strictCoreNodeCount": int(analysis["discovery"]["strictCoreNodeCount"]),
            "strictCoreBooleanMapSha256": analysis["discovery"]["strictCoreBooleanMapSha256"],
            "normalTraceInterruptionBasinCount": int(
                analysis["discovery"]["normalTraceInterruptionBasinCount"]
            ),
            "qualifiedInterruptionBasinCount": int(
                analysis["discovery"]["qualifiedInterruptionBasinCount"]
            ),
            "broadStrictCoreParentCount": int(
                analysis["discovery"]["broadHalfPerimeterResponseCount"]
            ),
            "strictCoreOutsideInterruptionNodeCount": int(
                analysis["discovery"]["strictCoreOutsideInterruptionNodeCount"]
            ),
            "strictCoreOutsideInterruptionBooleanMapSha256": analysis["discovery"][
                "strictCoreOutsideInterruptionBooleanMapSha256"
            ],
            "strictCoreOutsideInterruptionDisposition": analysis["discovery"][
                "strictCoreOutsideInterruptionDisposition"
            ],
            "allStrictCoreNodesAccountedFor": bool(
                analysis["discovery"]["allStrictCoreNodesAccountedFor"]
            ),
            "smoothingPerformed": False,
            "morphologyPerformed": False,
            "gapFillPerformed": False,
            "fixedNotchWindowUsed": False,
        },
        "candidates": public_candidate_records(analysis),
        "candidateCount": len(analysis["candidateTraces"]),
        "diagnosticNotchCandidateCount": sum(
            bool(candidate["record"].get("diagnosticPairingEligible"))
            for candidate in analysis["candidateTraces"]
        ),
        "allCandidatesContouredBeforePairing": bool(
            len(analysis["candidateTraces"])
            == int(analysis["discovery"]["qualifiedInterruptionBasinCount"])
            + int(analysis["discovery"]["broadHalfPerimeterResponseCount"])
            and all(trace.get("record") for trace in analysis["candidateTraces"])
        ),
        "allAcceptedCoordinatesNativeSupported": all(
            bool(candidate["record"].get("allSelectedPixelsNativeSupported", True))
            for candidate in analysis["candidateTraces"]
        ),
        "allAcceptedCoordinatesRawPolaritySupported": all(
            bool(candidate["record"].get("allSelectedPixelsRawPolaritySupported", True))
            for candidate in analysis["candidateTraces"]
        ),
        "predecessorHeldColumnCount": int(np.count_nonzero(analysis["predecessorHeldColumns"])),
        "predecessorHeldColumnIndices": index_list(analysis["predecessorHeldColumns"]),
        "obstructionColumnCount": int(np.count_nonzero(analysis["obstructionColumns"])),
        "obstructionColumnIndices": index_list(analysis["obstructionColumns"]),
        "inheritedAuthority": inherited_authority,
        "inheritedR22R23HoldRetained": inherited_hold_retained,
        "predecessorHoldsCleared": False,
        "assets": assets,
        "evidence": analysis["evidence"],
    }


def post2_r6_angle_after_contours(seed: dict[str, Any]) -> float:
    selected = seed.get("selectedReviewOnlyManufacturedNotch")
    need(isinstance(selected, dict), "R6 secondary record is missing after candidate contouring")
    angle = float(selected["reviewAngleDegrees"])
    need(math.isfinite(angle), "R6 secondary angle is not finite")
    return angle


def process_post2(
    neutral_root: Path,
    source_job: dict[str, Any],
    source_rows: list[dict[str, Any]],
    seeds: dict[str, dict[str, Any]],
    geometry_job: dict[str, Any],
    inherited_authority: dict[str, Any],
) -> list[dict[str, Any]]:
    params = r18.diagnostic.R11.parameters_from_job(geometry_job)
    cfg = geometry_job["topologyConfig"]
    crop = geometry_job["crop"]
    by_source = {(row["identity"], row["channel"]): row for row in source_rows}
    post2_root = neutral_root / "post2"
    post2_root.mkdir()
    results: list[dict[str, Any]] = []
    for ordinal, member in enumerate(source_job["inputs"], 1):
        identity = str(member["identity"])
        need(identity in inherited_authority, f"{identity} is absent from inherited R22 authority")
        case_root = post2_root / f"P{ordinal:04d}"
        case_root.mkdir()
        rows: dict[str, Any] = {}
        for channel, key in (("BF", "bf"), ("DF", "df")):
            source = by_source[(identity, channel)]
            gray = cv2.imread(source["path"], cv2.IMREAD_GRAYSCALE)
            need(gray is not None, f"{identity} {channel} OpenCV decode failed")
            seed_channel = seeds[identity][key]
            need(
                gray.shape == (int(seed_channel["heightPx"]), int(seed_channel["widthPx"])),
                f"{identity} {channel} source geometry differs",
            )
            fit = seed_channel.get("fit")
            need(bool(seed_channel.get("qualified")) and isinstance(fit, dict), f"{identity} {channel} seed fit held")
            measured = r18.r13.unwrap(gray, fit, crop, params, cfg)
            del gray
            predecessor_measured = np.asarray(measured.get("pathMeasured"), dtype=bool)
            analysis = analyze_native_strip(
                measured["strip"], measured["offsets"], fit, params, cfg, predecessor_measured, channel
            )
            del measured
            assets = render_channel(case_root, identity, channel, analysis)
            rows[channel] = channel_summary(
                analysis, source, assets, fit, inherited_authority[identity]["channels"][channel]
            )
            del analysis
        # This is the first access to the R6 review angle.  Both channel-local
        # candidate populations and their rasters already exist at this point.
        r6_angle = post2_r6_angle_after_contours(seeds[identity])
        pair = pair_after_channel_contours(
            rows["BF"]["candidates"],
            rows["DF"]["candidates"],
            rows["BF"]["circleFit"],
            rows["DF"]["circleFit"],
            params,
            r6_angle,
            rows["BF"]["circleQualified"],
            rows["DF"]["circleQualified"],
        )
        pair["r27DiagnosticStateBeforeInheritedAuthority"] = pair["state"]
        pair["r27DiagnosticResolvedPairsRemainUnowned"] = pair["resolvedPairs"]
        pair["inheritedR22PairState"] = inherited_authority[identity]["r22PairState"]
        pair["inheritedR22OwnershipHoldCount"] = sum(
            row["inheritedAuthority"]["r22NotchOwnership"]["state"]
            == "HOLD_NO_UNIQUE_R21_CONTOUR_OWNERSHIP_METRICS"
            for row in rows.values()
        )
        pair["inheritedR22OwnershipHoldsRetained"] = pair["inheritedR22OwnershipHoldCount"] == 2
        pair["resolvedPairs"] = []
        pair["resolvedPairCount"] = 0
        pair["state"] = "HOLD_PREDECESSOR_R22_NOTCH_OWNERSHIP_AUTHORITY_RETAINED"
        results.append(
            {
                "ordinal": ordinal,
                "identity": identity,
                "state": "DIAGNOSTIC_ONLY_R27_POST2_CANDIDATE_FIRST_CONTOURS_COMPLETE",
                "channels": rows,
                "pairDiagnostic": pair,
                "r6SecondaryCorroboration": {
                    "reviewAngleDegrees": r6_angle,
                    "toleranceDegrees": R6_SECONDARY_TOLERANCE_DEGREES,
                    "consumedOnlyAfterBothChannelCandidatePopulationsExisted": True,
                    "primaryContourSelector": False,
                    "candidatePairTieBreaker": False,
                    "fixedSearchWindowDefined": False,
                },
            }
        )
    return results


def process_hotspot(
    neutral_root: Path,
    hotspot_input: dict[str, Any],
    geometry_job: dict[str, Any],
) -> list[dict[str, Any]]:
    assert_review_only(hotspot_input, "hotspot predecessor")
    need(len(hotspot_input.get("results", [])) == 4, "Hotspot predecessor does not contain four cases")
    params = r18.diagnostic.R11.parameters_from_job(geometry_job)
    cfg = geometry_job["topologyConfig"]
    offsets = np.arange(
        -int(cfg["maximumInwardPx"]),
        int(cfg["maximumOutwardPx"]) + 1,
        dtype=np.float32,
    )
    hotspot_root = neutral_root / "hotspot"
    hotspot_root.mkdir()
    results: list[dict[str, Any]] = []
    for ordinal, prior in enumerate(hotspot_input["results"], 1):
        identity = str(prior["safeId"])
        case_root = hotspot_root / f"H{ordinal:04d}"
        case_root.mkdir()
        rows: dict[str, Any] = {}
        for channel in ("BF", "DF"):
            prior_channel = prior["channels"][channel]
            source_record = prior_channel["sourceFullClean"]
            hold_record = prior_channel["assets"]["predecessor_hold_mask"]
            source_path = Path(str(source_record["path"]))
            hold_path = Path(str(hold_record["path"]))
            require_exact_file(source_path, str(source_record["sha256"]), f"hotspot {ordinal} {channel} clean source", int(source_record["bytes"]))
            require_exact_file(hold_path, str(hold_record["sha256"]), f"hotspot {ordinal} {channel} hold mask", int(hold_record["bytes"]))
            strip = cv2.imread(str(source_path), cv2.IMREAD_GRAYSCALE)
            hold_mask = cv2.imread(str(hold_path), cv2.IMREAD_GRAYSCALE)
            need(strip is not None and hold_mask is not None, f"hotspot {ordinal} {channel} OpenCV decode failed")
            need(strip.shape[0] == offsets.size and hold_mask.shape == strip.shape, f"hotspot {ordinal} {channel} annular geometry differs")
            predecessor_measured = ~np.any(hold_mask > 0, axis=0)
            fit = prior_channel["baseFit"]
            analysis = analyze_native_strip(strip, offsets, fit, params, cfg, predecessor_measured, channel)
            locked_clean = {
                "path": str(source_path),
                "bytes": source_path.stat().st_size,
                "sha256": str(source_record["sha256"]).upper(),
                "role": "HASH_LOCKED_PREDECESSOR_CLEAN_ANNULAR_SOURCE",
            }
            assets = render_channel(case_root, identity, channel, analysis, locked_clean)
            source = {
                "path": str(source_path),
                "bytes": source_path.stat().st_size,
                "sha256": str(source_record["sha256"]).upper(),
                "inputPredecessorHoldMask": file_record(hold_path, str(hold_record["sha256"])),
            }
            rows[channel] = channel_summary(analysis, source, assets, fit)
            del analysis, strip, hold_mask
        pair = pair_after_channel_contours(
            rows["BF"]["candidates"],
            rows["DF"]["candidates"],
            rows["BF"]["circleFit"],
            rows["DF"]["circleFit"],
            params,
            None,
            rows["BF"]["circleQualified"],
            rows["DF"]["circleQualified"],
        )
        results.append(
            {
                "ordinal": ordinal,
                "identity": prior["identity"],
                "safeId": identity,
                "state": "DIAGNOSTIC_ONLY_R27_HOTSPOT_CANDIDATE_FIRST_CONTOURS_COMPLETE",
                "channels": rows,
                "pairDiagnostic": pair,
            }
        )
    return results


def nearest_candidate(candidates: list[dict[str, Any]], angle: float) -> tuple[dict[str, Any] | None, float | None]:
    if not candidates:
        return None, None
    candidate = min(candidates, key=lambda row: circular_distance_degrees(float(row["centerAngleDegrees"]), angle))
    return candidate, circular_distance_degrees(float(candidate["centerAngleDegrees"]), angle)


def evaluate_hotspot_regression(
    results: list[dict[str, Any]],
    oracle: dict[str, Any],
    oracle_gate: dict[str, Any],
) -> dict[str, Any]:
    need(len(results) == len(oracle.get("results", [])) == 4, "Hotspot regression cardinality differs")
    need(
        oracle_gate.get("state") == "HOLD_R21_LOCAL_CYAN_AND_CHANNEL_CONTOUR_REVIEW_REQUIRED",
        "Hotspot oracle gate state differs",
    )
    rows: list[dict[str, Any]] = []
    for current, prior in zip(results, oracle["results"]):
        need(current["safeId"] == prior["safeId"], "Hotspot regression identity order differs")
        channel_rows: dict[str, Any] = {}
        prior_held_channels: list[str] = []
        for channel in ("BF", "DF"):
            old_channel = prior["channels"][channel]
            old_metrics = old_channel["physicalBoundary"]["pairedNotchNativeShoulderPath"]
            old_accepted = bool(old_metrics["orangeEligible"])
            if not old_accepted:
                prior_held_channels.append(channel)
            old_angle = float(
                prior["pairDiagnostic"]["eligiblePairs"][0][
                    "bfAngleDegrees" if channel == "BF" else "dfAngleDegrees"
                ]
            )
            new_channel = current["channels"][channel]
            prior_width = float(old_metrics["candidateWidthDegrees"])
            prior_span = int(old_metrics["expectedSpanColumnCount"])
            prior_selected = int(old_metrics["selectedNativePixelCount"])
            evidence_pool = [
                row for row in new_channel["candidates"]
                if bool(row.get("nativeContourEvidenceQualified"))
                and bool(row.get("boundedGapNativeShoulderPath"))
                and bool(row.get("allSelectedPixelsNativeSupported"))
                and bool(row.get("allSelectedPixelsRawPolaritySupported"))
            ]

            def compatible_regression_candidate(row: dict[str, Any]) -> bool:
                width_value = row.get("widthDegrees")
                span_value = row.get("expectedSpanColumnCount")
                selected_value = len(row.get("representativePath", []))
                return bool(
                    circular_distance_degrees(float(row["centerAngleDegrees"]), old_angle)
                    <= R6_SECONDARY_TOLERANCE_DEGREES
                    and width_value is not None
                    and 0.75 <= float(width_value) / prior_width <= 1.25
                    and span_value is not None
                    and 0.75 <= int(span_value) / prior_span <= 1.25
                    and 0.75 <= int(selected_value) / prior_selected <= 1.25
                )

            regression_matches = (
                [row for row in evidence_pool if compatible_regression_candidate(row)]
                if old_accepted
                else []
            )
            candidate, distance = (
                nearest_candidate(regression_matches, old_angle)
                if old_accepted
                else nearest_candidate(new_channel["candidates"], old_angle)
            )
            new_width = None if candidate is None else candidate.get("widthDegrees")
            new_span = None if candidate is None else candidate.get("expectedSpanColumnCount")
            new_selected = None if candidate is None else len(candidate.get("representativePath", []))
            width_compatible = bool(
                not old_accepted
                or (new_width is not None and 0.75 <= float(new_width) / prior_width <= 1.25)
            )
            span_compatible = bool(
                not old_accepted
                or (new_span is not None and 0.75 <= int(new_span) / prior_span <= 1.25)
            )
            selected_count_compatible = bool(
                not old_accepted
                or (new_selected is not None and 0.75 <= int(new_selected) / prior_selected <= 1.25)
            )
            geometry_delta = {
                key: abs(float(new_channel["circleFit"][key]) - float(old_channel["circleFit"][key]))
                for key in ("centerX", "centerY", "radius")
            }
            geometry_exact = all(value <= 1.0e-6 for value in geometry_delta.values())
            accepted_preserved = bool(
                not old_accepted
                or (
                    len(regression_matches) == 1
                    and candidate is not None
                    and distance is not None
                    and distance <= R6_SECONDARY_TOLERANCE_DEGREES
                    and bool(candidate.get("boundedGapNativeShoulderPath"))
                    and bool(candidate.get("nativeContourEvidenceQualified"))
                    and bool(candidate.get("allSelectedPixelsNativeSupported"))
                    and bool(candidate.get("allSelectedPixelsRawPolaritySupported"))
                    and width_compatible
                    and span_compatible
                    and selected_count_compatible
                )
            )
            selected_pixel_count = sum(
                len(candidate.get("representativePath", []))
                for candidate in new_channel["candidates"]
            )
            native_selected_pixel_count = sum(
                len(candidate.get("representativePath", []))
                for candidate in new_channel["candidates"]
                if bool(candidate.get("allSelectedPixelsNativeSupported", True))
                and bool(candidate.get("allSelectedPixelsRawPolaritySupported", True))
                and not bool(candidate.get("crossChannelPixelCoordinateTransferPerformed"))
            )
            fabricated_pixel_count = max(0, selected_pixel_count - native_selected_pixel_count)
            if old_accepted:
                new_channel["contourAuthorityState"] = "DIAGNOSTIC_ONLY_R27_NATIVE_CONTOUR_REGRESSION"
            else:
                new_channel["contourAuthorityState"] = "HOLD_PREDECESSOR_R21_CHANNEL_CONTOUR_AUTHORITY_RETAINED"
            new_channel["predecessorR21ContourHoldRetained"] = not old_accepted
            new_channel["r27MeasurementCannotClearPredecessorR21Hold"] = True
            held_preserved = bool(
                old_accepted
                or (
                    str(new_channel["contourAuthorityState"]).startswith("HOLD_PREDECESSOR_R21_")
                    and new_channel["predecessorHoldsCleared"] is False
                    and not current["pairDiagnostic"].get("holdClearancePerformed")
                )
            )
            channel_rows[channel] = {
                "priorAcceptedNativeContour": old_accepted,
                "priorContourAngleDegrees": old_angle,
                "matchingR27CandidateCount": len(regression_matches),
                "matchedR27CandidateId": None if candidate is None else candidate["candidateId"],
                "matchedR27CandidateDistanceDegrees": distance,
                "acceptedContourEvidencePreserved": accepted_preserved,
                "priorWidthDegrees": prior_width,
                "r27WidthDegrees": new_width,
                "widthRatioWithinFrozenRegressionBand": width_compatible,
                "priorExpectedSpanColumnCount": prior_span,
                "r27ExpectedSpanColumnCount": new_span,
                "spanRatioWithinFrozenRegressionBand": span_compatible,
                "priorSelectedNativePixelCount": prior_selected,
                "r27SelectedNativePixelCount": new_selected,
                "selectedPixelRatioWithinFrozenRegressionBand": selected_count_compatible,
                "r27NativeContourEvidenceQualified": bool(
                    candidate is not None and candidate.get("nativeContourEvidenceQualified")
                ),
                "predecessorContourHoldPreserved": held_preserved,
                "priorCyanGeometryVerified": bool(old_channel["cyanGeometryVerified"]),
                "r27CyanGeometryVerified": bool(new_channel["cyanGeometryVerified"]),
                "cyanStatePreserved": bool(old_channel["cyanGeometryVerified"]) == bool(new_channel["cyanGeometryVerified"]),
                "fixedCircleMaximumAbsoluteDeltaPx": max(geometry_delta.values()),
                "fixedCircleGeometryExact": geometry_exact,
                "yellowSpacingExact": float(new_channel["maximumEdgeZoneSpacingErrorPx"]) <= 1.0e-4,
                "selectedNativeCoordinateCount": selected_pixel_count,
                "nativeRawSupportedCoordinateCount": native_selected_pixel_count,
                "fabricatedPixelCount": fabricated_pixel_count,
            }
        if prior_held_channels:
            current["pairDiagnostic"]["predecessorR21HeldChannels"] = prior_held_channels
            current["pairDiagnostic"]["predecessorResolvedPairsRemainDiagnosticUnowned"] = current["pairDiagnostic"].get("resolvedPairs", [])
            current["pairDiagnostic"]["resolvedPairs"] = []
            current["pairDiagnostic"]["resolvedPairCount"] = 0
            current["pairDiagnostic"]["state"] = "HOLD_PREDECESSOR_R21_CHANNEL_CONTOUR_AUTHORITY_RETAINED"
            current["pairDiagnostic"]["crossChannelPixelCoordinateTransferPerformed"] = False
            current["pairDiagnostic"]["holdClearancePerformed"] = False
        rows.append({"safeId": current["safeId"], "channels": channel_rows})
    flat = [row["channels"][channel] for row in rows for channel in ("BF", "DF")]
    return {
        "state": (
            "PASS_R27_HOTSPOT_REGRESSION_WITH_EXISTING_HOLDS_RETAINED"
            if all(
                row["acceptedContourEvidencePreserved"]
                and row["predecessorContourHoldPreserved"]
                and row["cyanStatePreserved"]
                and row["fixedCircleGeometryExact"]
                and row["yellowSpacingExact"]
                for row in flat
            )
            else "HOLD_R27_HOTSPOT_REGRESSION_DIFFERENCE"
        ),
        "caseCount": len(rows),
        "channelCount": len(flat),
        "priorAcceptedNativeContourCount": sum(row["priorAcceptedNativeContour"] for row in flat),
        "priorBfContourHoldCount": sum(
            not row["channels"]["BF"]["priorAcceptedNativeContour"] for row in rows
        ),
        "allExistingContourHoldsRetained": all(row["predecessorContourHoldPreserved"] for row in flat),
        "allAcceptedCoordinatesNativeSupported": all(row["fabricatedPixelCount"] == 0 for row in flat),
        "crossChannelPixelCoordinateTransferPerformed": False,
        "rows": rows,
    }


def candidate_near(
    result: dict[str, Any], channel: str, angle: float, tolerance: float = 0.8
) -> dict[str, Any] | None:
    candidate, distance = nearest_candidate(result["channels"][channel]["candidates"], angle)
    return candidate if candidate is not None and distance is not None and distance <= tolerance else None


def candidates_near(
    result: dict[str, Any],
    channel: str,
    angle: float,
    tolerance: float = 0.8,
    predicate: Any | None = None,
) -> list[dict[str, Any]]:
    rows = [
        candidate for candidate in result["channels"][channel]["candidates"]
        if circular_distance_degrees(float(candidate["centerAngleDegrees"]), angle) <= tolerance
        and (predicate is None or bool(predicate(candidate)))
    ]
    return sorted(
        rows,
        key=lambda candidate: (
            circular_distance_degrees(float(candidate["centerAngleDegrees"]), angle),
            str(candidate["candidateId"]),
        ),
    )


def candidate_metric_schema_valid(candidate: dict[str, Any]) -> bool:
    required = {
        "algorithm",
        "angleSampleCount",
        "candidateId",
        "candidateIndex",
        "channel",
        "state",
        "classification",
        "classificationReasons",
        "evidenceHoldReasons",
        "postContourMorphologyReasons",
        "authorityHoldReasons",
        "candidateDiscovery",
        "candidateDecisionThresholds",
        "normalTraceInterruptionBasinIndex",
        "normalTraceInterruptionBasinColumnIndices",
        "strictCoreSeedIds",
        "multiBasinStrictCoreSeedIds",
        "strictCoreNativeNodes",
        "strictCoreNativeNodeSeedOrdinals",
        "coreColumnIndices",
        "rawComponentNativeNodes",
        "broadParentHoldIds",
        "broadHalfPerimeterResponse",
        "componentColumnIndices",
        "componentSampleCount",
        "coreSampleCount",
        "rawComponentStartAngleDegrees",
        "rawComponentEndAngleDegrees",
        "rawComponentWidthDegrees",
        "rawDepthThresholdPx",
        "nativeSearchOffsetMinimumPx",
        "nativeSearchOffsetMaximumPx",
        "nativeSearchOffsetPitchPx",
        "nativeSearchOffsetRowCount",
        "leftShoulderWindow",
        "rightShoulderWindow",
        "leftAnchor",
        "rightAnchor",
        "expectedSpanColumnCount",
        "supportMetricPopulation",
        "supportMetricSpanColumnIndices",
        "tracedShoulderColumnIndices",
        "rawSupportedColumnCount",
        "rawSupportedFraction",
        "maximumContiguousUnsupportedRun",
        "unsupportedColumnCount",
        "unsupportedColumnIndices",
        "discoveredComponentNativeColumnCount",
        "representativePathComponentColumnCount",
        "discoveredComponentCoverageFraction",
        "obstructionOverlapColumnIndices",
        "obstructionOverlapColumnCount",
        "inheritedPredecessorHoldOverlapColumnIndices",
        "inheritedPredecessorHoldOverlapColumnCount",
        "leftShoulderDepthFromFixedOuterCirclePx",
        "rightShoulderDepthFromFixedOuterCirclePx",
        "leftNormalBrightnessTraceDepthFromFixedOuterCirclePx",
        "rightNormalBrightnessTraceDepthFromFixedOuterCirclePx",
        "leftShoulderReturnResidualFromNormalTracePx",
        "rightShoulderReturnResidualFromNormalTracePx",
        "centerAngleDegrees",
        "centerAngleRole",
        "startAngleDegrees",
        "endAngleDegrees",
        "widthDegrees",
        "ownershipIntervalBasis",
        "shoulderSpanWidthDegrees",
        "maximumInwardDepthPx",
        "medianInwardDepthPx",
        "apexCount",
        "apexBandMinimumDepthPx",
        "apexPopulation",
        "apexOffsetFraction",
        "postContourShapeTipOffsetFraction",
        "leftMonotonicSupportFraction",
        "rightMonotonicSupportFraction",
        "postContourShapeSlopeConsistencyFraction",
        "postContourSymmetryScore",
        "firstDifferenceAbsoluteP90Px",
        "firstDifferenceAbsoluteMedianPx",
        "secondDifferenceAbsoluteP90Px",
        "secondDifferenceAbsoluteMedianPx",
        "secondDifferenceAbsoluteMaximumPx",
        "postContourSymmetryExactNativePairCount",
        "firstDifferencePopulation",
        "secondDifferencePopulation",
        "slopeDirectionReversalCount",
        "curvatureReversalCount",
        "curvatureReversalPopulation",
        "extraCurvatureReversalFraction",
        "maximumAdjacentRadialChangePxPerSample",
        "supportGraphNodeCount",
        "fullCandidateNativeGraphNodeCount",
        "completeSupportGraphNodeCount",
        "fullCandidateNativeGraphNodes",
        "completeSupportGraphNativeNodes",
        "completeSupportGraphNativeNodesOrderedEvidenceSha256",
        "strictCoreNodeCountOutsideCompleteShoulderGraph",
        "strictCoreNativeNodesOutsideCompleteShoulderGraph",
        "rawComponentNativeNodeCountOutsideCompleteShoulderGraph",
        "rawComponentNativeNodesOutsideCompleteShoulderGraph",
        "strictCoreOutsideCompleteShoulderGraphDisposition",
        "strictCoreCoarseBandCountOutsideCompleteShoulderGraph",
        "strictCoreCoarseBandsOutsideCompleteShoulderGraph",
        "strictCoreSeedIdsWithCoarseBandOutsideCompleteShoulderGraph",
        "supportGraphBranchColumnCount",
        "parallelBandColumnCount",
        "maximumCompleteBandCountPerColumn",
        "representativeParallelBandSwitchCount",
        "postHocAdjacentParallelBandSwitchCount",
        "representativeNativeRadialTravelPx",
        "representativeSelectionRankOrder",
        "reachableShoulderPathCountSaturated",
        "reachableShoulderPathCountSaturationValue",
        "coherentCoreCorridorSignatureCountSaturated",
        "coherentCoreCorridorSignatureCountSaturationValue",
        "coherentCoarseBandRouteCountSaturated",
        "coherentCoarseBandRouteCountSaturationValue",
        "uniqueCoherentNativeCoreCorridorSignature",
        "strictCoreSeedCount",
        "strictCoreSeedIdsInUniqueCoherentCorridorSignature",
        "strictCoreSeedIdsNotResolvedToUniqueCoherentCorridor",
        "allStrictCoreSeedsShareUniqueCoherentBandCorridor",
        "coherentCoreCorridorDiagnostics",
        "resolvedPhysicalCoreCorridorCountSaturated",
        "resolvedPhysicalCoreCorridorCountSaturationValue",
        "uniqueResolvedPhysicalCoreCorridor",
        "strictCoreSeedIdsOnRepresentativePhysicalCorridor",
        "strictCoreSeedIdsNotOnRepresentativePhysicalCorridor",
        "gapFreeNativeShoulderPath",
        "boundedGapNativeShoulderPath",
        "completeNativeShoulderPath",
        "nativeContourEvidenceQualified",
        "nativeContourShapeCompatibleAfterContour",
        "manufacturedCompatibleAfterContour",
        "diagnosticPairingEligible",
        "candidateLocalAuthorityEligibleBeforeGlobalHold",
        "pairingEligible",
        "notchOwnershipGranted",
        "allSelectedPixelsNativeSupported",
        "allSelectedPixelsRawPolaritySupported",
        "allSelectedPixelsDirectUnblurredPolaritySupported",
        "shoulderEndpointsConnectedByNativeGraph",
        "representativePathObservedCount",
        "representativePath",
        "selectedTransitionWitness",
        "rawComponentTransitionWitness",
        "gradientNormalAlignmentPostContourMeasurement",
        "inwardLimitTouchCount",
        "morphologyPerformed",
        "interpolationPerformed",
        "syntheticCoordinateCount",
        "templateOrIdealCurveUsed",
        "candidateCenterUsedByTraversal",
        "monotonicityUsedByTraversal",
        "crossChannelPixelCoordinateTransferPerformed",
        "metricAvailability",
    }
    if set(candidate) != required:
        return False
    try:
        boolean_keys = {
            "broadHalfPerimeterResponse",
            "gapFreeNativeShoulderPath",
            "boundedGapNativeShoulderPath",
            "completeNativeShoulderPath",
            "nativeContourEvidenceQualified",
            "nativeContourShapeCompatibleAfterContour",
            "manufacturedCompatibleAfterContour",
            "diagnosticPairingEligible",
            "candidateLocalAuthorityEligibleBeforeGlobalHold",
            "pairingEligible",
            "notchOwnershipGranted",
            "allSelectedPixelsNativeSupported",
            "allSelectedPixelsRawPolaritySupported",
            "allSelectedPixelsDirectUnblurredPolaritySupported",
            "shoulderEndpointsConnectedByNativeGraph",
            "morphologyPerformed",
            "interpolationPerformed",
            "templateOrIdealCurveUsed",
            "candidateCenterUsedByTraversal",
            "monotonicityUsedByTraversal",
            "crossChannelPixelCoordinateTransferPerformed",
            "uniqueCoherentNativeCoreCorridorSignature",
            "allStrictCoreSeedsShareUniqueCoherentBandCorridor",
            "uniqueResolvedPhysicalCoreCorridor",
        }
        if any(type(candidate[key]) is not bool for key in boolean_keys):
            return False
        integer_keys = {
            "angleSampleCount",
            "candidateIndex",
            "componentSampleCount",
            "coreSampleCount",
            "expectedSpanColumnCount",
            "rawSupportedColumnCount",
            "maximumContiguousUnsupportedRun",
            "unsupportedColumnCount",
            "discoveredComponentNativeColumnCount",
            "representativePathComponentColumnCount",
            "obstructionOverlapColumnCount",
            "inheritedPredecessorHoldOverlapColumnCount",
            "supportGraphNodeCount",
            "fullCandidateNativeGraphNodeCount",
            "completeSupportGraphNodeCount",
            "strictCoreNodeCountOutsideCompleteShoulderGraph",
            "rawComponentNativeNodeCountOutsideCompleteShoulderGraph",
            "strictCoreCoarseBandCountOutsideCompleteShoulderGraph",
            "supportGraphBranchColumnCount",
            "parallelBandColumnCount",
            "maximumCompleteBandCountPerColumn",
            "reachableShoulderPathCountSaturated",
            "reachableShoulderPathCountSaturationValue",
            "coherentCoreCorridorSignatureCountSaturated",
            "coherentCoreCorridorSignatureCountSaturationValue",
            "coherentCoarseBandRouteCountSaturated",
            "coherentCoarseBandRouteCountSaturationValue",
            "strictCoreSeedCount",
            "resolvedPhysicalCoreCorridorCountSaturated",
            "resolvedPhysicalCoreCorridorCountSaturationValue",
            "representativePathObservedCount",
            "inwardLimitTouchCount",
            "syntheticCoordinateCount",
            "nativeSearchOffsetRowCount",
        }
        nullable_integer_keys = {
            "normalTraceInterruptionBasinIndex",
            "apexCount",
            "postContourSymmetryExactNativePairCount",
            "slopeDirectionReversalCount",
            "curvatureReversalCount",
            "representativeParallelBandSwitchCount",
            "postHocAdjacentParallelBandSwitchCount",
        }
        if any(type(candidate[key]) is not int for key in integer_keys):
            return False
        if any(
            candidate[key] is not None and type(candidate[key]) is not int
            for key in nullable_integer_keys
        ):
            return False
        finite_float_keys = {
            "rawComponentStartAngleDegrees",
            "rawComponentEndAngleDegrees",
            "rawComponentWidthDegrees",
            "rawDepthThresholdPx",
            "rawSupportedFraction",
            "discoveredComponentCoverageFraction",
            "centerAngleDegrees",
            "startAngleDegrees",
            "endAngleDegrees",
            "widthDegrees",
            "maximumInwardDepthPx",
            "medianInwardDepthPx",
            "nativeSearchOffsetMinimumPx",
            "nativeSearchOffsetMaximumPx",
            "nativeSearchOffsetPitchPx",
        }
        nullable_float_keys = {
            "leftShoulderDepthFromFixedOuterCirclePx",
            "rightShoulderDepthFromFixedOuterCirclePx",
            "leftNormalBrightnessTraceDepthFromFixedOuterCirclePx",
            "rightNormalBrightnessTraceDepthFromFixedOuterCirclePx",
            "leftShoulderReturnResidualFromNormalTracePx",
            "rightShoulderReturnResidualFromNormalTracePx",
            "shoulderSpanWidthDegrees",
            "apexBandMinimumDepthPx",
            "apexOffsetFraction",
            "postContourShapeTipOffsetFraction",
            "leftMonotonicSupportFraction",
            "rightMonotonicSupportFraction",
            "postContourShapeSlopeConsistencyFraction",
            "postContourSymmetryScore",
            "maximumAdjacentRadialChangePxPerSample",
            "firstDifferenceAbsoluteMedianPx",
            "firstDifferenceAbsoluteP90Px",
            "secondDifferenceAbsoluteMedianPx",
            "secondDifferenceAbsoluteP90Px",
            "secondDifferenceAbsoluteMaximumPx",
            "extraCurvatureReversalFraction",
            "representativeNativeRadialTravelPx",
        }
        if any(
            type(candidate[key]) is not float or not math.isfinite(candidate[key])
            for key in finite_float_keys
        ):
            return False
        if any(
            candidate[key] is not None
            and (
                type(candidate[key]) is not float
                or not math.isfinite(candidate[key])
            )
            for key in nullable_float_keys
        ):
            return False
        string_keys = {
            "algorithm",
            "candidateId",
            "channel",
            "state",
            "classification",
            "candidateDiscovery",
            "supportMetricPopulation",
            "centerAngleRole",
            "ownershipIntervalBasis",
            "apexPopulation",
            "firstDifferencePopulation",
            "secondDifferencePopulation",
            "curvatureReversalPopulation",
            "strictCoreOutsideCompleteShoulderGraphDisposition",
            "representativeSelectionRankOrder",
            "completeSupportGraphNativeNodesOrderedEvidenceSha256",
        }
        if any(type(candidate[key]) is not str for key in string_keys):
            return False
        list_keys = (
            "classificationReasons",
            "evidenceHoldReasons",
            "postContourMorphologyReasons",
            "authorityHoldReasons",
            "strictCoreSeedIds",
            "strictCoreNativeNodeSeedOrdinals",
            "multiBasinStrictCoreSeedIds",
            "normalTraceInterruptionBasinColumnIndices",
            "componentColumnIndices",
            "coreColumnIndices",
            "broadParentHoldIds",
            "tracedShoulderColumnIndices",
            "supportMetricSpanColumnIndices",
            "unsupportedColumnIndices",
            "obstructionOverlapColumnIndices",
            "inheritedPredecessorHoldOverlapColumnIndices",
            "strictCoreSeedIdsInUniqueCoherentCorridorSignature",
            "strictCoreSeedIdsNotResolvedToUniqueCoherentCorridor",
            "strictCoreSeedIdsOnRepresentativePhysicalCorridor",
            "strictCoreSeedIdsNotOnRepresentativePhysicalCorridor",
            "strictCoreSeedIdsWithCoarseBandOutsideCompleteShoulderGraph",
            "strictCoreNativeNodes",
            "rawComponentNativeNodes",
            "fullCandidateNativeGraphNodes",
            "completeSupportGraphNativeNodes",
            "strictCoreNativeNodesOutsideCompleteShoulderGraph",
            "rawComponentNativeNodesOutsideCompleteShoulderGraph",
        )
        if any(type(candidate[key]) is not list for key in list_keys):
            return False
        for key in (
            "classificationReasons",
            "evidenceHoldReasons",
            "postContourMorphologyReasons",
            "authorityHoldReasons",
            "strictCoreSeedIds",
            "multiBasinStrictCoreSeedIds",
            "broadParentHoldIds",
            "strictCoreSeedIdsInUniqueCoherentCorridorSignature",
            "strictCoreSeedIdsNotResolvedToUniqueCoherentCorridor",
            "strictCoreSeedIdsOnRepresentativePhysicalCorridor",
            "strictCoreSeedIdsNotOnRepresentativePhysicalCorridor",
            "strictCoreSeedIdsWithCoarseBandOutsideCompleteShoulderGraph",
        ):
            if any(type(value) is not str for value in candidate[key]):
                return False
        for key in (
            "strictCoreNativeNodeSeedOrdinals",
            "normalTraceInterruptionBasinColumnIndices",
            "componentColumnIndices",
            "coreColumnIndices",
            "tracedShoulderColumnIndices",
            "supportMetricSpanColumnIndices",
            "unsupportedColumnIndices",
            "obstructionOverlapColumnIndices",
            "inheritedPredecessorHoldOverlapColumnIndices",
        ):
            if any(type(value) is not int for value in candidate[key]):
                return False
        angle_sample_count = int(candidate["angleSampleCount"])
        search_offset_minimum = float(candidate["nativeSearchOffsetMinimumPx"])
        search_offset_maximum = float(candidate["nativeSearchOffsetMaximumPx"])
        search_offset_pitch = float(candidate["nativeSearchOffsetPitchPx"])
        search_offset_row_count = int(candidate["nativeSearchOffsetRowCount"])
        if not (
            search_offset_row_count >= 2
            and search_offset_pitch > 0.0
            and math.isclose(
                search_offset_maximum,
                search_offset_minimum
                + search_offset_pitch * (search_offset_row_count - 1),
                rel_tol=0.0,
                abs_tol=1.0e-6,
            )
        ):
            return False
        reconstructed_search_offsets = (
            search_offset_minimum
            + search_offset_pitch
            * np.arange(search_offset_row_count, dtype=np.float64)
        ).astype(np.float32)
        thresholds = candidate["candidateDecisionThresholds"]
        threshold_keys = {
            "manufacturedMinimumWidthDegrees",
            "manufacturedMaximumWidthDegrees",
            "manufacturedMaximumTipOffsetFraction",
            "manufacturedMinimumSlopeConsistency",
            "manufacturedMinimumSymmetry",
            "minimumPathCoverageFraction",
            "maximumUnsupportedRunSamples",
            "maximumRadialChangePxPerSample",
            "minimumRawPolarity",
            "maximumSmoothSecondDifferenceP90Px",
            "maximumExtraCurvatureReversalFraction",
            "maximumReturnResidualFromNormalTracePx",
        }
        if not isinstance(thresholds, dict) or set(thresholds) != threshold_keys:
            return False
        if type(thresholds["maximumUnsupportedRunSamples"]) is not int:
            return False
        if any(
            type(thresholds[key]) is not float
            for key in threshold_keys - {"maximumUnsupportedRunSamples"}
        ):
            return False
        finite_thresholds = {
            key: float(value) for key, value in thresholds.items()
        }
        manufactured_profile = (
            SELF_CHECK_MANUFACTURED_THRESHOLD_PROFILE
            if angle_sample_count == 101
            else PINNED_MANUFACTURED_THRESHOLD_PROFILE
        )
        if not (
            all(math.isfinite(value) for value in finite_thresholds.values())
            and all(
                math.isclose(
                    finite_thresholds[key],
                    expected,
                    rel_tol=0.0,
                    abs_tol=1.0e-12,
                )
                for key, expected in manufactured_profile.items()
            )
            and 0.0 < finite_thresholds["manufacturedMinimumWidthDegrees"]
            <= finite_thresholds["manufacturedMaximumWidthDegrees"]
            <= 360.0
            and 0.0
            <= finite_thresholds["manufacturedMaximumTipOffsetFraction"]
            <= 1.0
            and 0.0
            <= finite_thresholds["manufacturedMinimumSlopeConsistency"]
            <= 1.0
            and 0.0 <= finite_thresholds["manufacturedMinimumSymmetry"] <= 1.0
            and math.isclose(
                finite_thresholds["minimumPathCoverageFraction"],
                MINIMUM_PATH_COVERAGE_FRACTION,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
            and int(thresholds["maximumUnsupportedRunSamples"])
            == MAXIMUM_UNSUPPORTED_RUN_SAMPLES
            and math.isclose(
                finite_thresholds["maximumRadialChangePxPerSample"],
                MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
            and math.isclose(
                finite_thresholds["minimumRawPolarity"],
                float(r18.MINIMUM_RAW_POLARITY),
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
            and math.isclose(
                finite_thresholds["maximumSmoothSecondDifferenceP90Px"],
                MAXIMUM_SMOOTH_SECOND_DIFFERENCE_P90_PX,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
            and math.isclose(
                finite_thresholds["maximumExtraCurvatureReversalFraction"],
                MAXIMUM_EXTRA_CURVATURE_REVERSAL_FRACTION,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
            and math.isclose(
                finite_thresholds["maximumReturnResidualFromNormalTracePx"],
                MAXIMUM_RETURN_RESIDUAL_FROM_NORMAL_TRACE_PX,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
        ):
            return False
        component_columns = [int(value) for value in candidate["componentColumnIndices"]]
        if not (
            candidate["algorithm"]
            == "FULL_NATIVE_SUPPORT_GRAPH_WITH_CONTINUITY_FIRST_DIRECT_RAW_REPRESENTATIVE_PATH"
            and candidate["channel"] in {"BF", "DF"}
            and int(candidate["candidateIndex"]) >= 0
            and candidate["candidateId"]
            == f"{candidate['channel']}_C{int(candidate['candidateIndex']) + 1:04d}"
            and angle_sample_count > 0
            and component_columns
            and len(component_columns) == len(set(component_columns))
            and all(0 <= column < angle_sample_count for column in component_columns)
            and int(candidate["componentSampleCount"]) == len(component_columns)
            and candidate["centerAngleRole"]
            == "REPORTING_ONLY_NEVER_TRAVERSAL_OR_CANDIDATE_OWNERSHIP"
            and math.isfinite(float(candidate["centerAngleDegrees"]))
            and candidate["candidateDiscovery"]
            in {
                "MEASURED_NORMAL_TRACE_INTERRUPTION_BASIN_CONTAINING_STRICT_NATIVE_CORE",
                "WHOLE_BROAD_STRICT_NATIVE_CORE_PARENT_HOLD",
            }
            and set(candidate["broadParentHoldIds"]).issubset(
                set(candidate["strictCoreSeedIds"])
            )
            and set(candidate["multiBasinStrictCoreSeedIds"]).issubset(
                set(candidate["strictCoreSeedIds"])
            )
        ):
            return False
        if not (
            candidate["morphologyPerformed"] is False
            and candidate["interpolationPerformed"] is False
            and int(candidate["syntheticCoordinateCount"]) == 0
            and candidate["templateOrIdealCurveUsed"] is False
            and candidate["candidateCenterUsedByTraversal"] is False
            and candidate["monotonicityUsedByTraversal"] is False
            and candidate["crossChannelPixelCoordinateTransferPerformed"] is False
            and candidate["notchOwnershipGranted"] is False
        ):
            return False
        if candidate["classificationReasons"] != (
            candidate["evidenceHoldReasons"]
            + candidate["postContourMorphologyReasons"]
            + candidate["authorityHoldReasons"]
        ):
            return False
        span = [int(value) for value in candidate["supportMetricSpanColumnIndices"]]
        expected = int(candidate["expectedSpanColumnCount"])
        supported = int(candidate["rawSupportedColumnCount"])
        unsupported = {int(value) for value in candidate["unsupportedColumnIndices"]}
        if (
            expected <= 0
            or len(span) != expected
            or len(set(span)) != expected
            or not all(0 <= column < angle_sample_count for column in span)
            or len(unsupported) != len(candidate["unsupportedColumnIndices"])
            or not unsupported.issubset(set(span))
        ):
            return False
        degrees_per_sample = 360.0 / angle_sample_count
        if not (
            math.isclose(
                float(candidate["rawComponentStartAngleDegrees"]),
                component_columns[0] * degrees_per_sample,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
            and math.isclose(
                float(candidate["rawComponentEndAngleDegrees"]),
                component_columns[-1] * degrees_per_sample,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
            and math.isclose(
                float(candidate["rawComponentWidthDegrees"]),
                len(component_columns) * degrees_per_sample,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
            and math.isfinite(float(candidate["rawDepthThresholdPx"]))
            and float(candidate["rawDepthThresholdPx"]) > 0.0
            and candidate["broadHalfPerimeterResponse"]
            is (len(component_columns) > angle_sample_count // 2)
        ):
            return False
        basin_columns = [
            int(value)
            for value in candidate["normalTraceInterruptionBasinColumnIndices"]
        ]
        if candidate["candidateDiscovery"].startswith("MEASURED_NORMAL_TRACE_"):
            if basin_columns != component_columns:
                return False
        elif basin_columns or candidate["normalTraceInterruptionBasinIndex"] is not None:
            return False
        for indices_key, count_key in (
            ("obstructionOverlapColumnIndices", "obstructionOverlapColumnCount"),
            (
                "inheritedPredecessorHoldOverlapColumnIndices",
                "inheritedPredecessorHoldOverlapColumnCount",
            ),
        ):
            indices = [int(value) for value in candidate[indices_key]]
            if (
                len(indices) != len(set(indices))
                or int(candidate[count_key]) != len(indices)
                or not set(indices).issubset(set(span))
            ):
                return False
        flags = np.asarray([column not in unsupported for column in span], dtype=bool)
        if supported != int(np.count_nonzero(flags)):
            return False
        if not math.isclose(
            float(candidate["rawSupportedFraction"]),
            float(np.mean(flags)),
            rel_tol=0.0,
            abs_tol=1.0e-12,
        ):
            return False
        if int(candidate["maximumContiguousUnsupportedRun"]) != longest_false_run(flags):
            return False
        if int(candidate["unsupportedColumnCount"]) != int(np.count_nonzero(~flags)):
            return False
        if int(candidate["supportGraphNodeCount"]) <= 0 or not candidate["rawComponentNativeNodes"]:
            return False
        for key in (
            "normalTraceInterruptionBasinColumnIndices",
            "componentColumnIndices",
            "coreColumnIndices",
            "tracedShoulderColumnIndices",
            "supportMetricSpanColumnIndices",
            "unsupportedColumnIndices",
            "obstructionOverlapColumnIndices",
            "inheritedPredecessorHoldOverlapColumnIndices",
        ):
            if any(type(value) is not int for value in candidate[key]):
                return False
        coordinate_keys = {"column", "radialRow"}
        for key in (
            "strictCoreNativeNodes",
            "fullCandidateNativeGraphNodes",
            "strictCoreNativeNodesOutsideCompleteShoulderGraph",
            "rawComponentNativeNodesOutsideCompleteShoulderGraph",
        ):
            if any(
                type(node) is not dict
                or set(node) != coordinate_keys
                or type(node["column"]) is not int
                or type(node["radialRow"]) is not int
                or not (0 <= node["column"] < angle_sample_count)
                or not (0 <= node["radialRow"] < search_offset_row_count)
                for node in candidate[key]
            ):
                return False
        transition_node_keys = {
            "column",
            "radialRow",
            "offsetPx",
            "directUnblurredRawOutsideInContrast",
            "proposalSmoothedRawOutsideInContrast",
            "enhancedOutsideInContrast",
        }
        for key in ("rawComponentNativeNodes", "completeSupportGraphNativeNodes"):
            for node in candidate[key]:
                if not (
                    type(node) is dict
                    and set(node) == transition_node_keys
                    and type(node["column"]) is int
                    and type(node["radialRow"]) is int
                    and 0 <= node["column"] < angle_sample_count
                    and 0 <= node["radialRow"] < search_offset_row_count
                    and all(
                        type(node[value_key]) is float
                        and math.isfinite(node[value_key])
                        for value_key in transition_node_keys
                        - {"column", "radialRow"}
                    )
                    and math.isclose(
                        node["offsetPx"],
                        float(reconstructed_search_offsets[node["radialRow"]]),
                        rel_tol=0.0,
                        abs_tol=1.0e-6,
                    )
                ):
                    return False
        if not (
            re.fullmatch(
                r"[0-9A-F]{64}",
                candidate[
                    "completeSupportGraphNativeNodesOrderedEvidenceSha256"
                ],
            )
            and candidate[
                "completeSupportGraphNativeNodesOrderedEvidenceSha256"
            ]
            == complete_graph_ordered_evidence_sha256(
                candidate["completeSupportGraphNativeNodes"]
            )
        ):
            return False
        strict_nodes = {
            (int(node["column"]), int(node["radialRow"]))
            for node in candidate["strictCoreNativeNodes"]
        }
        strict_seed_ids = candidate["strictCoreSeedIds"]
        strict_seed_ordinals = candidate["strictCoreNativeNodeSeedOrdinals"]
        if not (
            strict_seed_ids
            and all(type(value) is str and value for value in strict_seed_ids)
            and len(strict_seed_ids) == len(set(strict_seed_ids))
            and len(strict_seed_ordinals)
            == len(candidate["strictCoreNativeNodes"])
            and all(
                type(value) is int and 0 <= value < len(strict_seed_ids)
                for value in strict_seed_ordinals
            )
            and set(strict_seed_ordinals) == set(range(len(strict_seed_ids)))
        ):
            return False
        raw_nodes = {
            (int(node["column"]), int(node["radialRow"]))
            for node in candidate["rawComponentNativeNodes"]
        }
        full_nodes = {
            (int(node["column"]), int(node["radialRow"]))
            for node in candidate["fullCandidateNativeGraphNodes"]
        }
        complete_nodes = {
            (int(node["column"]), int(node["radialRow"]))
            for node in candidate["completeSupportGraphNativeNodes"]
        }
        strict_outside = {
            (int(node["column"]), int(node["radialRow"]))
            for node in candidate["strictCoreNativeNodesOutsideCompleteShoulderGraph"]
        }
        raw_outside = {
            (int(node["column"]), int(node["radialRow"]))
            for node in candidate["rawComponentNativeNodesOutsideCompleteShoulderGraph"]
        }
        if not (
            len(candidate["strictCoreNativeNodes"]) == len(strict_nodes)
            and len(candidate["rawComponentNativeNodes"]) == len(raw_nodes)
            and len(candidate["fullCandidateNativeGraphNodes"]) == len(full_nodes)
            and len(candidate["completeSupportGraphNativeNodes"]) == len(complete_nodes)
            and len(candidate["strictCoreNativeNodesOutsideCompleteShoulderGraph"])
            == len(strict_outside)
            and len(candidate["rawComponentNativeNodesOutsideCompleteShoulderGraph"])
            == len(raw_outside)
        ):
            return False
        if not strict_nodes or not strict_nodes.issubset(raw_nodes):
            return False
        if not raw_nodes.issubset(full_nodes) or not complete_nodes.issubset(full_nodes):
            return False
        raw_node_columns = {column for column, _ in raw_nodes}
        if not (
            int(candidate["coreSampleCount"]) == len(strict_nodes)
            and raw_node_columns.issubset(set(component_columns))
            and int(candidate["discoveredComponentNativeColumnCount"])
            == len(raw_node_columns)
        ):
            return False
        if not (
            int(candidate["supportGraphNodeCount"]) == len(full_nodes)
            and int(candidate["fullCandidateNativeGraphNodeCount"]) == len(full_nodes)
            and int(candidate["completeSupportGraphNodeCount"]) == len(complete_nodes)
            and strict_outside == strict_nodes - complete_nodes
            and raw_outside == raw_nodes - complete_nodes
            and int(candidate["strictCoreNodeCountOutsideCompleteShoulderGraph"])
            == len(strict_outside)
            and int(candidate["rawComponentNativeNodeCountOutsideCompleteShoulderGraph"])
            == len(raw_outside)
        ):
            return False
        full_rows_by_column: dict[int, list[int]] = {}
        complete_rows_by_column: dict[int, list[int]] = {}
        for column, row in full_nodes:
            full_rows_by_column.setdefault(column, []).append(row)
        for column, row in complete_nodes:
            complete_rows_by_column.setdefault(column, []).append(row)
        branch_metric_rows_by_column = (
            complete_rows_by_column if complete_rows_by_column else full_rows_by_column
        )
        maximum_complete_band_count = max(
            (
                len(native_row_bands(rows))
                for rows in branch_metric_rows_by_column.values()
            ),
            default=0,
        )
        if not (
            int(candidate["supportGraphBranchColumnCount"])
            == sum(len(rows) > 1 for rows in full_rows_by_column.values())
            and int(candidate["maximumCompleteBandCountPerColumn"])
            == maximum_complete_band_count
            and 0
            <= int(candidate["parallelBandColumnCount"])
            <= len(branch_metric_rows_by_column)
        ):
            return False
        excluded_bands = candidate[
            "strictCoreCoarseBandsOutsideCompleteShoulderGraph"
        ]
        excluded_band_count = int(
            candidate["strictCoreCoarseBandCountOutsideCompleteShoulderGraph"]
        )
        excluded_seed_ids = set(
            candidate["strictCoreSeedIdsWithCoarseBandOutsideCompleteShoulderGraph"]
        )
        if not isinstance(excluded_bands, list) or excluded_band_count != len(excluded_bands):
            return False
        if not excluded_seed_ids.issubset(set(candidate["strictCoreSeedIds"])):
            return False
        excluded_band_nodes: set[tuple[int, int]] = set()
        excluded_band_seed_union: set[str] = set()
        for band in excluded_bands:
            if set(band) != {
                "column",
                "coarseBandIndex",
                "minimumRadialRow",
                "maximumRadialRow",
                "strictCoreRadialRows",
                "strictCoreSeedIds",
            }:
                return False
            if not (
                all(
                    type(band[key]) is int
                    for key in (
                        "column",
                        "coarseBandIndex",
                        "minimumRadialRow",
                        "maximumRadialRow",
                    )
                )
                and type(band["strictCoreRadialRows"]) is list
                and all(
                    type(value) is int
                    for value in band["strictCoreRadialRows"]
                )
                and type(band["strictCoreSeedIds"]) is list
                and all(
                    type(value) is str and value
                    for value in band["strictCoreSeedIds"]
                )
            ):
                return False
            column = int(band["column"])
            minimum_row = int(band["minimumRadialRow"])
            maximum_row = int(band["maximumRadialRow"])
            strict_band_rows = [int(value) for value in band["strictCoreRadialRows"]]
            band_seed_ids = set(str(value) for value in band["strictCoreSeedIds"])
            if not (
                strict_band_rows
                and minimum_row <= maximum_row
                and all(minimum_row <= row <= maximum_row for row in strict_band_rows)
                and band_seed_ids.issubset(set(candidate["strictCoreSeedIds"]))
            ):
                return False
            excluded_band_nodes.update((column, row) for row in strict_band_rows)
            excluded_band_seed_union.update(band_seed_ids)
        if not excluded_band_nodes.issubset(strict_outside) or excluded_band_seed_union != excluded_seed_ids:
            return False
        disposition = str(candidate["strictCoreOutsideCompleteShoulderGraphDisposition"])
        if excluded_band_count:
            if not (
                disposition.startswith("EXPLICIT_")
                or disposition == "RETAINED_AS_AUTHORITY_HOLD_AND_ORANGE_FULL_GRAPH_EVIDENCE"
            ):
                return False
        elif strict_outside:
            if disposition != "ROW_THICKNESS_ONLY_OUTSIDE_COMPLETE_GRAPH_NO_SEPARATE_COARSE_BAND":
                return False
        elif disposition != "NONE_ALL_STRICT_CORE_NODES_ON_COMPLETE_SHOULDER_GRAPH":
            return False
        if set(int(value) for value in candidate["coreColumnIndices"]) != {
            column for column, _ in strict_nodes
        }:
            return False
        for window_key in ("leftShoulderWindow", "rightShoulderWindow"):
            window = candidate[window_key]
            if not (
                type(window) is dict
                and set(window)
                == {
                    "population",
                    "direction",
                    "expectedSampleCount",
                    "minimumSupportedSampleCount",
                    "maximumContiguousUnsupportedRunAllowed",
                    "supportedSampleCount",
                    "supportedFraction",
                    "maximumContiguousUnsupportedRun",
                    "searchedWindowCount",
                    "windowStartDistanceSamples",
                    "passed",
                    "entries",
                    "anchor",
                }
                and type(window["passed"]) is bool
                and all(
                    type(window[key]) is int
                    for key in (
                        "direction",
                        "expectedSampleCount",
                        "minimumSupportedSampleCount",
                        "maximumContiguousUnsupportedRunAllowed",
                        "supportedSampleCount",
                        "maximumContiguousUnsupportedRun",
                        "searchedWindowCount",
                        "windowStartDistanceSamples",
                    )
                )
                and type(window["supportedFraction"]) is float
                and math.isfinite(window["supportedFraction"])
                and type(window["entries"]) is list
            ):
                return False
            entries = window["entries"]
            if len(entries) != SHOULDER_WINDOW_SAMPLES:
                return False
            for entry in entries:
                if not (
                    type(entry) is dict
                    and set(entry)
                    == {
                        "column",
                        "row",
                        "offsetPx",
                        "distanceFromRawComponentSamples",
                        "nativeNormalTraceSupported",
                        "obstructionColumn",
                    }
                    and type(entry["column"]) is int
                    and 0 <= entry["column"] < angle_sample_count
                    and type(entry["distanceFromRawComponentSamples"]) is int
                    and type(entry["nativeNormalTraceSupported"]) is bool
                    and type(entry["obstructionColumn"]) is bool
                    and (
                        entry["row"] is None
                        and entry["offsetPx"] is None
                        or type(entry["row"]) is int
                        and 0 <= entry["row"] < search_offset_row_count
                        and type(entry["offsetPx"]) is float
                        and math.isfinite(entry["offsetPx"])
                        and math.isclose(
                            entry["offsetPx"],
                            float(reconstructed_search_offsets[entry["row"]]),
                            rel_tol=0.0,
                            abs_tol=1.0e-6,
                        )
                    )
                ):
                    return False
            anchor = window["anchor"]
            if anchor is not None and not (
                type(anchor) is dict
                and set(anchor)
                == {"column", "row", "offsetPx", "distanceFromRawComponentSamples"}
                and type(anchor["column"]) is int
                and 0 <= anchor["column"] < angle_sample_count
                and type(anchor["row"]) is int
                and 0 <= anchor["row"] < search_offset_row_count
                and type(anchor["offsetPx"]) is float
                and math.isfinite(anchor["offsetPx"])
                and type(anchor["distanceFromRawComponentSamples"]) is int
                and math.isclose(
                    anchor["offsetPx"],
                    float(reconstructed_search_offsets[anchor["row"]]),
                    rel_tol=0.0,
                    abs_tol=1.0e-6,
                )
            ):
                return False
            window_flags = np.asarray(
                [entry["nativeNormalTraceSupported"] for entry in entries],
                dtype=bool,
            )
            if int(window.get("supportedSampleCount", -1)) != int(np.count_nonzero(window_flags)):
                return False
            if int(window.get("maximumContiguousUnsupportedRun", -1)) != longest_false_run(window_flags):
                return False
            expected_window_pass = bool(
                np.count_nonzero(window_flags) >= MINIMUM_SHOULDER_SUPPORT_SAMPLES
                and longest_false_run(window_flags) <= MAXIMUM_UNSUPPORTED_RUN_SAMPLES
                and window.get("anchor") is not None
            )
            if window["passed"] != expected_window_pass:
                return False
        if not (
            candidate["leftAnchor"] == candidate["leftShoulderWindow"].get("anchor")
            and candidate["rightAnchor"]
            == candidate["rightShoulderWindow"].get("anchor")
            and math.isfinite(float(candidate["startAngleDegrees"]))
            and math.isfinite(float(candidate["endAngleDegrees"]))
            and candidate["ownershipIntervalBasis"]
            in {
                "RAW_COMPONENT_ONLY_UNTIL_NATIVE_SHOULDER_PATH_COMPLETES",
                "ACTUAL_TRACED_NATIVE_SHOULDER_ENDPOINTS",
            }
        ):
            return False
        if not (
            math.isfinite(float(candidate["widthDegrees"]))
            and float(candidate["widthDegrees"]) > 0.0
            and math.isfinite(float(candidate["maximumInwardDepthPx"]))
            and math.isfinite(float(candidate["medianInwardDepthPx"]))
        ):
            return False
        availability = candidate["metricAvailability"]
        availability_keys = {
            "nativeSupport",
            "fullInwardDepth",
            "leftReturnResidual",
            "rightReturnResidual",
            "apexAndOffset",
            "monotonicSides",
            "smoothnessJaggednessCurvature",
            "branchAndParallelBands",
            "representativeParallelBandSwitches",
            "coherentCoreCorridorSignatures",
        }
        if not isinstance(availability, dict) or set(availability) != availability_keys:
            return False
        if not (
            str(availability["nativeSupport"]).startswith("MEASURED_")
            and str(availability["fullInwardDepth"]).startswith("MEASURED_")
            and str(availability["branchAndParallelBands"]).startswith("MEASURED_")
        ):
            return False
        for side in ("left", "right"):
            value = candidate[f"{side}ShoulderReturnResidualFromNormalTracePx"]
            state = str(availability[f"{side}ReturnResidual"])
            if (value is None and not state.startswith("NOT_MEASURABLE_")) or (
                value is not None and (not math.isfinite(float(value)) or not state.startswith("MEASURED_"))
            ):
                return False
        has_representative_path = int(candidate.get("representativePathObservedCount", 0)) > 0
        representative_path = candidate["representativePath"]
        selected_witness = candidate["selectedTransitionWitness"]
        raw_witness = candidate["rawComponentTransitionWitness"]
        gradient_measurement = candidate[
            "gradientNormalAlignmentPostContourMeasurement"
        ]
        raw_node_records = candidate["rawComponentNativeNodes"]
        witness_keys = {
            "population",
            "count",
            "orderedEvidenceSha256",
            "rawOutsideInMinimum",
            "rawOutsideInP10",
            "rawOutsideInMedian",
            "enhancedOutsideInMinimum",
            "enhancedOutsideInP10",
            "enhancedOutsideInMedian",
            "directUnblurredRawOutsideInMinimum",
            "directUnblurredRawOutsideInP10",
            "directUnblurredRawOutsideInMedian",
            "directUnblurredRawPolaritySupportedFraction",
        }

        def exact_transition_witness_types(witness: dict[str, Any]) -> bool:
            return bool(
                type(witness) is dict
                and set(witness) == witness_keys
                and type(witness["population"]) is str
                and type(witness["count"]) is int
                and witness["count"] > 0
                and type(witness["orderedEvidenceSha256"]) is str
                and re.fullmatch(
                    r"[0-9A-F]{64}", witness["orderedEvidenceSha256"]
                )
                and all(
                    type(witness[key]) is float and math.isfinite(witness[key])
                    for key in witness_keys
                    - {"population", "count", "orderedEvidenceSha256"}
                )
            )

        expected_raw_witness = transition_witness_summary(
            "ALL_RAW_COMPONENT_R18_NATIVE_TRANSITION_NODES",
            np.asarray(
                [node["proposalSmoothedRawOutsideInContrast"] for node in raw_node_records],
                dtype=np.float64,
            ),
            np.asarray(
                [node["directUnblurredRawOutsideInContrast"] for node in raw_node_records],
                dtype=np.float64,
            ),
            np.asarray(
                [node["enhancedOutsideInContrast"] for node in raw_node_records],
                dtype=np.float64,
            ),
        )
        if not (
            type(representative_path) is list
            and len(representative_path)
            == int(candidate["representativePathObservedCount"])
            and candidate["shoulderEndpointsConnectedByNativeGraph"]
            == has_representative_path
            and type(selected_witness) is dict
            and exact_transition_witness_types(raw_witness)
            and raw_witness == expected_raw_witness
            and type(gradient_measurement) is dict
            and set(gradient_measurement) == {"state", "selectionRole"}
            and type(gradient_measurement["state"]) is str
            and gradient_measurement["selectionRole"] is False
        ):
            return False
        if has_representative_path:
            representative_keys = {
                "column",
                "radialRow",
                "offsetPx",
                "fixedOuterPathOffsetPx",
                "directUnblurredRawOutsideInContrast",
                "proposalSmoothedRawOutsideInContrast",
                "enhancedOutsideInContrast",
            }
            for row in representative_path:
                if not (
                    type(row) is dict
                    and set(row) == representative_keys
                    and type(row["column"]) is int
                    and type(row["radialRow"]) is int
                    and 0 <= row["column"] < angle_sample_count
                    and 0 <= row["radialRow"] < search_offset_row_count
                    and all(
                        type(row[key]) is float and math.isfinite(row[key])
                        for key in representative_keys - {"column", "radialRow"}
                    )
                    and math.isclose(
                        row["offsetPx"],
                        float(reconstructed_search_offsets[row["radialRow"]]),
                        rel_tol=0.0,
                        abs_tol=1.0e-6,
                    )
                ):
                    return False
            representative_nodes = {
                (int(row["column"]), int(row["radialRow"]))
                for row in representative_path
            }
            representative_columns = [
                int(row["column"]) for row in representative_path
            ]
            position_by_column = {
                int(column): position for position, column in enumerate(span)
            }
            native_positions = np.asarray(
                [position_by_column[column] for column in representative_columns],
                dtype=np.int64,
            )
            if not (
                native_positions.size >= 2
                and bool(np.all(np.diff(native_positions) > 0))
                and bool(np.all(np.isin(np.diff(native_positions), (1, 2))))
            ):
                return False
            selected_offsets = np.asarray(
                [row["offsetPx"] for row in representative_path], dtype=np.float64
            )
            selected_outer = np.asarray(
                [row["fixedOuterPathOffsetPx"] for row in representative_path],
                dtype=np.float64,
            )
            selected_depth = selected_outer - selected_offsets
            selected_raw = np.asarray(
                [
                    row["proposalSmoothedRawOutsideInContrast"]
                    for row in representative_path
                ],
                dtype=np.float64,
            )
            selected_direct_raw = np.asarray(
                [
                    row["directUnblurredRawOutsideInContrast"]
                    for row in representative_path
                ],
                dtype=np.float64,
            )
            selected_enhanced = np.asarray(
                [row["enhancedOutsideInContrast"] for row in representative_path],
                dtype=np.float64,
            )
            expected_selected_witness = transition_witness_summary(
                "R18_RAW_AND_ENHANCED_NATIVE_TRANSITION_WITNESSES_WITH_DIRECT_UNBLURRED_DIAGNOSTIC",
                selected_raw,
                selected_direct_raw,
                selected_enhanced,
            )
            if not exact_transition_witness_types(selected_witness):
                return False
            position_deltas = np.diff(native_positions.astype(np.float64))
            adjacent_offsets = np.diff(selected_offsets)
            expected_maximum_adjacent_change = float(
                np.max(np.abs(adjacent_offsets) / position_deltas)
            )
            expected_radial_travel = float(np.sum(np.abs(adjacent_offsets)))
            expected_inward_limit_count = int(
                np.count_nonzero(
                    np.isclose(
                        selected_offsets,
                        search_offset_minimum,
                        rtol=0.0,
                        atol=1.0e-6,
                    )
                )
            )

            apex_band_drop = max(3.0, 0.08 * float(np.ptp(selected_depth)))
            apex_level = max(
                float(candidate["rawDepthThresholdPx"]),
                float(np.max(selected_depth)) - apex_band_drop,
            )
            apex_native_positions = native_positions[selected_depth >= apex_level]
            apex_count = (
                int(np.count_nonzero(np.diff(apex_native_positions) > 1) + 1)
                if apex_native_positions.size
                else 0
            )
            apex_position = int(native_positions[int(np.argmax(selected_depth))])
            first_difference = np.diff(selected_depth) / position_deltas
            left_steps = first_difference[native_positions[1:] <= apex_position]
            right_steps = first_difference[native_positions[:-1] >= apex_position]
            left_monotonic = (
                float(np.mean(left_steps >= -2.0)) if left_steps.size else 0.0
            )
            right_monotonic = (
                float(np.mean(right_steps <= 2.0)) if right_steps.size else 0.0
            )
            slope_midpoints = (
                native_positions[:-1].astype(np.float64)
                + native_positions[1:].astype(np.float64)
            ) / 2.0
            second_difference = (
                np.diff(first_difference) / np.diff(slope_midpoints)
                if first_difference.size >= 2
                else np.asarray([], dtype=np.float64)
            )
            slope_signs = np.sign(first_difference[np.abs(first_difference) > 1.0])
            slope_reversals = (
                int(np.count_nonzero(slope_signs[1:] != slope_signs[:-1]))
                if slope_signs.size >= 2
                else 0
            )
            curvature_signs = np.sign(
                second_difference[np.abs(second_difference) > 1.0]
            )
            curvature_reversals = (
                int(
                    np.count_nonzero(
                        curvature_signs[1:] != curvature_signs[:-1]
                    )
                )
                if curvature_signs.size >= 2
                else 0
            )
            extra_reversal_fraction = max(0, curvature_reversals - 1) / max(
                int(first_difference.size), 1
            )
            symmetry, shape_tip_offset, shape_slope, symmetry_pair_count = (
                native_position_candidate_shape(
                    selected_depth, native_positions, len(span)
                )
            )
            if (
                candidate["leftNormalBrightnessTraceDepthFromFixedOuterCirclePx"]
                is None
                or candidate[
                    "rightNormalBrightnessTraceDepthFromFixedOuterCirclePx"
                ]
                is None
            ):
                return False
            left_normal_depth = float(
                candidate["leftNormalBrightnessTraceDepthFromFixedOuterCirclePx"]
            )
            right_normal_depth = float(
                candidate["rightNormalBrightnessTraceDepthFromFixedOuterCirclePx"]
            )
            center_weights = np.maximum(
                selected_depth
                - min(float(selected_depth[0]), float(selected_depth[-1])),
                0.001,
            )
            expected_float_metrics = {
                "maximumInwardDepthPx": float(np.max(selected_depth)),
                "medianInwardDepthPx": float(np.median(selected_depth)),
                "leftShoulderDepthFromFixedOuterCirclePx": float(selected_depth[0]),
                "rightShoulderDepthFromFixedOuterCirclePx": float(selected_depth[-1]),
                "leftShoulderReturnResidualFromNormalTracePx": abs(
                    float(selected_depth[0]) - left_normal_depth
                ),
                "rightShoulderReturnResidualFromNormalTracePx": abs(
                    float(selected_depth[-1]) - right_normal_depth
                ),
                "centerAngleDegrees": circular_weighted_degrees(
                    np.asarray(representative_columns, dtype=np.int64),
                    center_weights,
                    angle_sample_count,
                ),
                "apexBandMinimumDepthPx": float(apex_level),
                "apexOffsetFraction": float(shape_tip_offset),
                "postContourShapeTipOffsetFraction": float(shape_tip_offset),
                "leftMonotonicSupportFraction": left_monotonic,
                "rightMonotonicSupportFraction": right_monotonic,
                "postContourShapeSlopeConsistencyFraction": float(shape_slope),
                "postContourSymmetryScore": float(symmetry),
                "maximumAdjacentRadialChangePxPerSample": expected_maximum_adjacent_change,
                "firstDifferenceAbsoluteMedianPx": float(
                    np.median(np.abs(first_difference))
                ),
                "firstDifferenceAbsoluteP90Px": float(
                    np.percentile(np.abs(first_difference), 90.0)
                ),
                "secondDifferenceAbsoluteMedianPx": (
                    float(np.median(np.abs(second_difference)))
                    if second_difference.size
                    else 0.0
                ),
                "secondDifferenceAbsoluteP90Px": (
                    float(np.percentile(np.abs(second_difference), 90.0))
                    if second_difference.size
                    else 0.0
                ),
                "secondDifferenceAbsoluteMaximumPx": (
                    float(np.max(np.abs(second_difference)))
                    if second_difference.size
                    else 0.0
                ),
                "extraCurvatureReversalFraction": float(extra_reversal_fraction),
                "representativeNativeRadialTravelPx": expected_radial_travel,
            }
            if any(
                not math.isclose(
                    float(candidate[key]), value, rel_tol=0.0, abs_tol=1.0e-9
                )
                for key, value in expected_float_metrics.items()
            ):
                return False
            if not (
                candidate["apexCount"] == apex_count
                and candidate["postContourSymmetryExactNativePairCount"]
                == symmetry_pair_count
                and candidate["slopeDirectionReversalCount"] == slope_reversals
                and candidate["curvatureReversalCount"] == curvature_reversals
                and candidate["selectedTransitionWitness"]
                == expected_selected_witness
                and candidate["allSelectedPixelsRawPolaritySupported"]
                is bool(np.all(selected_raw >= float(r18.MINIMUM_RAW_POLARITY)))
                and candidate[
                    "allSelectedPixelsDirectUnblurredPolaritySupported"
                ]
                is bool(
                    np.all(
                        selected_direct_raw >= float(r18.MINIMUM_RAW_POLARITY)
                    )
                )
                and candidate["inwardLimitTouchCount"]
                == expected_inward_limit_count
            ):
                return False

            complete_rows_by_position: list[list[int]] = [[] for _ in span]
            for node in candidate["completeSupportGraphNativeNodes"]:
                complete_rows_by_position[position_by_column[node["column"]]].append(
                    node["radialRow"]
                )
            complete_bands = [
                native_row_bands(rows) for rows in complete_rows_by_position
            ]
            representative_switches = 0
            posthoc_switches = 0
            for index in range(1, len(representative_path)):
                previous_position = int(native_positions[index - 1])
                current_position = int(native_positions[index])
                previous_row = representative_path[index - 1]["radialRow"]
                current_row = representative_path[index]["radialRow"]
                previous_band = next(
                    band
                    for band in complete_bands[previous_position]
                    if previous_row in band
                )
                current_bands = complete_bands[current_position]
                selected_band = next(
                    band for band in current_bands if current_row in band
                )
                selected_separation = native_band_separation_px(
                    previous_band, selected_band, reconstructed_search_offsets
                )
                best_separation = min(
                    native_band_separation_px(
                        previous_band, band, reconstructed_search_offsets
                    )
                    for band in current_bands
                )
                switched = bool(
                    selected_separation >= PARALLEL_BAND_SEPARATION_PX
                    and selected_separation > best_separation + 1.0e-6
                )
                representative_switches += int(switched)
                if current_position - previous_position == 1:
                    posthoc_switches += int(switched)
            if not (
                candidate["allSelectedPixelsNativeSupported"] is True
                and len(representative_nodes) == len(representative_path)
                and representative_nodes.issubset(complete_nodes)
                and representative_columns
                == [column for column in span if column not in unsupported]
                and candidate["tracedShoulderColumnIndices"] == span
                and int(candidate["rawSupportedColumnCount"])
                == len(representative_path)
                and int(candidate["representativeParallelBandSwitchCount"])
                == representative_switches
                and int(candidate["postHocAdjacentParallelBandSwitchCount"])
                == posthoc_switches
                and int(candidate["reachableShoulderPathCountSaturationValue"])
                == PATH_COUNT_SATURATION
                and 1
                <= int(candidate["reachableShoulderPathCountSaturated"])
                <= PATH_COUNT_SATURATION
                and candidate["ownershipIntervalBasis"]
                == "ACTUAL_TRACED_NATIVE_SHOULDER_ENDPOINTS"
                and candidate["leftAnchor"] is not None
                and candidate["rightAnchor"] is not None
                and math.isclose(
                    float(candidate["shoulderSpanWidthDegrees"]),
                    float(candidate["widthDegrees"]),
                    rel_tol=0.0,
                    abs_tol=1.0e-12,
                )
            ):
                return False
            selected_component_columns = set(representative_columns) & raw_node_columns
            if not (
                int(candidate["representativePathComponentColumnCount"])
                == len(selected_component_columns)
                and math.isclose(
                    float(candidate["discoveredComponentCoverageFraction"]),
                    len(selected_component_columns) / len(raw_node_columns),
                    rel_tol=0.0,
                    abs_tol=1.0e-12,
                )
            ):
                return False
        else:
            if not (
                not representative_path
                and set(selected_witness) == {"state", "population", "count"}
                and type(selected_witness["state"]) is str
                and type(selected_witness["population"]) is str
                and type(selected_witness["count"]) is int
                and selected_witness
                == {
                    "state": "NOT_MEASURABLE_UNRESOLVED_NO_COMPLETE_NATIVE_SHOULDER_PATH",
                    "population": "NO_REPRESENTATIVE_PATH_SELECTED",
                    "count": 0,
                }
                and candidate["representativeParallelBandSwitchCount"] is None
                and candidate["postHocAdjacentParallelBandSwitchCount"] is None
                and candidate["representativeNativeRadialTravelPx"] is None
                and candidate["tracedShoulderColumnIndices"] == []
                and int(candidate["reachableShoulderPathCountSaturationValue"])
                == PATH_COUNT_SATURATION
                and int(candidate["reachableShoulderPathCountSaturated"]) == 0
                and candidate["ownershipIntervalBasis"]
                == "RAW_COMPONENT_ONLY_UNTIL_NATIVE_SHOULDER_PATH_COMPLETES"
                and int(candidate["representativePathComponentColumnCount"]) == 0
                and float(candidate["discoveredComponentCoverageFraction"]) == 0.0
            ):
                return False
        recomputed_corridor = recompute_coherent_core_corridors(
            angle_sample_count=angle_sample_count,
            span_columns=span,
            complete_node_records=candidate["completeSupportGraphNativeNodes"],
            strict_core_node_records=candidate["strictCoreNativeNodes"],
            strict_core_seed_ids=candidate["strictCoreSeedIds"],
            strict_core_native_node_seed_ordinals=candidate[
                "strictCoreNativeNodeSeedOrdinals"
            ],
            left_anchor=candidate["leftAnchor"],
            right_anchor=candidate["rightAnchor"],
            representative_path=representative_path,
        )
        if any(
            candidate[key] != value
            for key, value in recomputed_corridor.items()
        ):
            return False
        coherent_route_count = int(
            candidate["coherentCoreCorridorSignatureCountSaturated"]
        )
        coarse_route_count = int(candidate["coherentCoarseBandRouteCountSaturated"])
        resolved_physical_count = int(
            candidate["resolvedPhysicalCoreCorridorCountSaturated"]
        )
        if not (
            int(candidate["coherentCoreCorridorSignatureCountSaturationValue"]) == 2
            and 0 <= coherent_route_count <= 2
            and int(candidate["coherentCoarseBandRouteCountSaturationValue"]) == 2
            and 0 <= coarse_route_count <= 2
            and coherent_route_count <= coarse_route_count
            and bool(candidate["uniqueCoherentNativeCoreCorridorSignature"])
            == (coherent_route_count == 1)
            and int(candidate["strictCoreSeedCount"])
            == len(candidate.get("strictCoreSeedIds", []))
            and set(candidate["strictCoreSeedIdsInUniqueCoherentCorridorSignature"])
            .issubset(set(candidate.get("strictCoreSeedIds", [])))
            and int(candidate["resolvedPhysicalCoreCorridorCountSaturationValue"])
            == 2
            and 0 <= resolved_physical_count <= 2
            and bool(candidate["uniqueResolvedPhysicalCoreCorridor"])
            == (resolved_physical_count == 1)
        ):
            return False
        all_seed_ids = set(candidate["strictCoreSeedIds"])
        unique_seed_ids = set(
            candidate["strictCoreSeedIdsInUniqueCoherentCorridorSignature"]
        )
        unresolved_seed_ids = set(
            candidate["strictCoreSeedIdsNotResolvedToUniqueCoherentCorridor"]
        )
        if unique_seed_ids & unresolved_seed_ids or unique_seed_ids | unresolved_seed_ids != all_seed_ids:
            return False
        expected_all_seeds_share = bool(candidate.get("strictCoreSeedIds")) and bool(
            coherent_route_count == 1
            and set(candidate["strictCoreSeedIdsInUniqueCoherentCorridorSignature"])
            == set(candidate.get("strictCoreSeedIds", []))
        )
        if bool(candidate["allStrictCoreSeedsShareUniqueCoherentBandCorridor"]) != expected_all_seeds_share:
            return False
        representative_seed_ids = set(
            candidate["strictCoreSeedIdsOnRepresentativePhysicalCorridor"]
        )
        nonrepresentative_seed_ids = set(
            candidate["strictCoreSeedIdsNotOnRepresentativePhysicalCorridor"]
        )
        if (
            representative_seed_ids & nonrepresentative_seed_ids
            or representative_seed_ids | nonrepresentative_seed_ids != all_seed_ids
            or not representative_seed_ids.issubset(all_seed_ids)
        ):
            return False
        diagnostics = candidate["coherentCoreCorridorDiagnostics"]
        if not isinstance(diagnostics, dict):
            return False
        unresolved_diagnostic_keys = {
            "state",
            "population",
            "signatureSummaries",
            "divergentPositionCount",
            "commonStrictCorePositionDifferentBandCount",
            "maximumContiguousDivergentPositionRun",
            "maximumCommonPositionCoarseBandSeparationPx",
        }
        measured_diagnostic_keys = {
            "population",
            "signatureSummaries",
            "divergentPositionCount",
            "commonStrictCorePositionDifferentBandCount",
            "maximumContiguousDivergentPositionRun",
            "maximumCommonPositionCoarseBandSeparationPx",
            "rawExactCanonicalSignatureCountSaturated",
            "rawExactCoarseRouteCountSaturated",
            "completeStrictCorePositionCount",
            "completeStrictCoreSpanSamples",
            "parallelStrictCorePositionCount",
            "maximumContiguousParallelStrictCoreRunSamples",
            "parallelStrictCoreRunFractionOfCompleteCoreSpan",
            "minimumSustainedForkRunSamples",
            "minimumSustainedForkSpanFraction",
            "sustainedPhysicalStrictCoreFork",
            "resolvedPhysicalCorridorCountSaturated",
            "resolutionRule",
        }
        if has_representative_path:
            diagnostic_integer_keys = {
                "divergentPositionCount",
                "commonStrictCorePositionDifferentBandCount",
                "maximumContiguousDivergentPositionRun",
                "rawExactCanonicalSignatureCountSaturated",
                "rawExactCoarseRouteCountSaturated",
                "completeStrictCorePositionCount",
                "completeStrictCoreSpanSamples",
                "parallelStrictCorePositionCount",
                "maximumContiguousParallelStrictCoreRunSamples",
                "minimumSustainedForkRunSamples",
                "resolvedPhysicalCorridorCountSaturated",
            }
            diagnostic_float_keys = {
                "maximumCommonPositionCoarseBandSeparationPx",
                "parallelStrictCoreRunFractionOfCompleteCoreSpan",
                "minimumSustainedForkSpanFraction",
            }
            if not (
                set(diagnostics) == measured_diagnostic_keys
                and type(diagnostics["population"]) is str
                and type(diagnostics["resolutionRule"]) is str
                and type(diagnostics["signatureSummaries"]) is list
                and type(diagnostics["sustainedPhysicalStrictCoreFork"]) is bool
                and all(
                    type(diagnostics[key]) is int
                    for key in diagnostic_integer_keys
                )
                and all(
                    type(diagnostics[key]) is float
                    and math.isfinite(diagnostics[key])
                    for key in diagnostic_float_keys
                )
            ):
                return False
            signature_summaries = diagnostics["signatureSummaries"]
            if not (
                len(signature_summaries) == coherent_route_count
                and all(
                    type(summary) is dict
                    and set(summary) == {
                        "sha256",
                        "strictCoreTokenCount",
                        "firstPosition",
                        "lastPosition",
                        "survivingStrictCoreSeedIds",
                    }
                    and type(summary["sha256"]) is str
                    and re.fullmatch(r"[0-9A-F]{64}", summary["sha256"])
                    and type(summary["strictCoreTokenCount"]) is int
                    and summary["strictCoreTokenCount"] > 0
                    and type(summary["firstPosition"]) is int
                    and type(summary["lastPosition"]) is int
                    and type(summary["survivingStrictCoreSeedIds"]) is list
                    and all(
                        type(value) is str and value
                        for value in summary["survivingStrictCoreSeedIds"]
                    )
                    and set(summary["survivingStrictCoreSeedIds"]).issubset(
                        all_seed_ids
                    )
                    for summary in signature_summaries
                )
            ):
                return False
            if coherent_route_count == 1 and set(
                signature_summaries[0]["survivingStrictCoreSeedIds"]
            ) != unique_seed_ids:
                return False
            if not (
                int(diagnostics["rawExactCanonicalSignatureCountSaturated"])
                == coherent_route_count
                and int(diagnostics["rawExactCoarseRouteCountSaturated"])
                == coarse_route_count
                and int(diagnostics["resolvedPhysicalCorridorCountSaturated"])
                == resolved_physical_count
                and int(diagnostics["minimumSustainedForkRunSamples"])
                == MINIMUM_SUSTAINED_STRICT_CORE_FORK_RUN_SAMPLES
                and math.isclose(
                    float(diagnostics["minimumSustainedForkSpanFraction"]),
                    MINIMUM_SUSTAINED_STRICT_CORE_FORK_SPAN_FRACTION,
                    rel_tol=0.0,
                    abs_tol=1.0e-12,
                )
                and resolved_physical_count
                == (
                    0
                    if coherent_route_count == 0
                    else 2
                    if bool(diagnostics["sustainedPhysicalStrictCoreFork"])
                    else 1
                )
                and int(diagnostics["completeStrictCorePositionCount"]) > 0
                and int(diagnostics["completeStrictCoreSpanSamples"])
                >= int(diagnostics["completeStrictCorePositionCount"])
                and 0.0
                <= float(diagnostics["parallelStrictCoreRunFractionOfCompleteCoreSpan"])
                <= 1.0
            ):
                return False
        else:
            if not (
                set(diagnostics) == unresolved_diagnostic_keys
                and type(diagnostics["state"]) is str
                and type(diagnostics["population"]) is str
                and type(diagnostics["signatureSummaries"]) is list
                and all(
                    type(diagnostics[key]) is int
                    for key in (
                        "divergentPositionCount",
                        "commonStrictCorePositionDifferentBandCount",
                        "maximumContiguousDivergentPositionRun",
                    )
                )
                and type(diagnostics["maximumCommonPositionCoarseBandSeparationPx"])
                is float
                and math.isfinite(
                    diagnostics["maximumCommonPositionCoarseBandSeparationPx"]
                )
                and str(diagnostics["state"]).startswith("NOT_MEASURABLE_")
                and coherent_route_count == coarse_route_count == resolved_physical_count == 0
                and not diagnostics["signatureSummaries"]
            ):
                return False
        if resolved_physical_count == 0:
            if representative_seed_ids:
                return False
        elif not representative_seed_ids:
            return False
        if has_representative_path:
            expected_evidence_reasons: list[str] = []
            if (
                float(candidate["rawSupportedFraction"])
                < finite_thresholds["minimumPathCoverageFraction"]
            ):
                expected_evidence_reasons.append(
                    "INSUFFICIENT_NATIVE_SUPPORT_FRACTION"
                )
            if int(candidate["maximumContiguousUnsupportedRun"]) > int(
                thresholds["maximumUnsupportedRunSamples"]
            ):
                expected_evidence_reasons.append(
                    "MAXIMUM_CONTIGUOUS_UNSUPPORTED_RUN_EXCEEDED"
                )
            if (
                float(candidate["discoveredComponentCoverageFraction"])
                < finite_thresholds["minimumPathCoverageFraction"]
            ):
                expected_evidence_reasons.append(
                    "INSUFFICIENT_DISCOVERED_COMPONENT_COVERAGE"
                )
            if (
                float(candidate["maximumAdjacentRadialChangePxPerSample"])
                > finite_thresholds["maximumRadialChangePxPerSample"] + 1.0e-6
            ):
                expected_evidence_reasons.append(
                    "LOCAL_NATIVE_CONNECTIVITY_LIMIT_EXCEEDED"
                )
            if int(candidate["inwardLimitTouchCount"]):
                expected_evidence_reasons.append("TRACE_TOUCHES_INWARD_SEARCH_LIMIT")
            if candidate["allSelectedPixelsRawPolaritySupported"] is not True:
                expected_evidence_reasons.append(
                    "R18_RAW_NATIVE_TRANSITION_POLARITY_WITNESS_FAILED"
                )
        else:
            held_evidence_reasons = {
                "HOLD_MISSING_SUSTAINED_NATIVE_NORMAL_TRACE_SHOULDER": [
                    "LEFT_OR_RIGHT_SHOULDER_LACKS_NEAREST_SEVEN_OF_NINE_NATIVE_WINDOW_WITH_MAXIMUM_ONE_SAMPLE_GAP"
                ],
                "HOLD_SHOULDER_INTERVAL_EXCEEDS_FULL_PERIMETER": [
                    "UNWRAPPED_SHOULDER_INTERVAL_EXCEEDS_ONE_REVOLUTION"
                ],
                "HOLD_NO_CORE_VISITING_NATIVE_SHOULDER_TO_SHOULDER_PATH": [
                    "NO_COMPLETE_NATIVE_PATH_THROUGH_RAW_DEPTH_CORE"
                ],
            }
            if candidate["state"] == "HOLD_BROAD_RESPONSE_HAS_NO_UNIQUE_SHORT_SHOULDER_INTERVAL":
                expected_evidence_reasons = [
                    "RAW_COMPONENT_ENVELOPE_REACHES_MORE_THAN_HALF_PERIMETER"
                    if candidate["broadHalfPerimeterResponse"]
                    else "SHOULDER_INTERVAL_REACHES_AT_LEAST_HALF_PERIMETER"
                ]
            else:
                expected_evidence_reasons = held_evidence_reasons.get(
                    str(candidate["state"]), []
                )
        if candidate["evidenceHoldReasons"] != expected_evidence_reasons:
            return False

        expected_authority_reasons: list[str] = []
        obstruction_columns = set(candidate["obstructionOverlapColumnIndices"])
        if candidate["candidateDiscovery"] == "WHOLE_BROAD_STRICT_NATIVE_CORE_PARENT_HOLD":
            expected_authority_reasons.append(
                "WHOLE_BROAD_STRICT_CORE_PARENT_RETAINS_ZERO_OWNERSHIP"
            )
        else:
            if candidate["broadParentHoldIds"]:
                expected_authority_reasons.append(
                    "INTERSECTION_WITH_WHOLE_BROAD_STRICT_CORE_PARENT"
                )
            if candidate["multiBasinStrictCoreSeedIds"]:
                expected_authority_reasons.append(
                    "STRICT_CORE_SEED_SPANS_MULTIPLE_NORMAL_TRACE_BASINS"
                )
            if obstruction_columns & set(basin_columns):
                expected_authority_reasons.append(
                    "NORMAL_TRACE_INTERRUPTION_INCLUDES_EXTERIOR_OBSTRUCTION"
                )
        if obstruction_columns:
            expected_authority_reasons.append(
                "EXTERIOR_OBSTRUCTION_OWNERSHIP_OVERLAP"
            )
        if candidate["inheritedPredecessorHoldOverlapColumnIndices"]:
            expected_authority_reasons.append("INHERITED_PREDECESSOR_HOLD_OVERLAP")
        if (
            has_representative_path
            and resolved_physical_count >= 1
            and nonrepresentative_seed_ids
        ):
            expected_authority_reasons.append(
                "ADDITIONAL_STRICT_CORE_SEEDS_OUTSIDE_UNIQUE_COHERENT_CORE_CORRIDOR_RETAINED"
            )
        if has_representative_path and excluded_band_count:
            expected_authority_reasons.append(
                "STRICT_CORE_COARSE_BAND_EVIDENCE_OUTSIDE_COMPLETE_SHOULDER_GRAPH_RETAINED"
            )
        if has_representative_path and resolved_physical_count > 1:
            expected_authority_reasons.append(
                "SUSTAINED_MULTIPLE_STRICT_CORE_CORRIDORS_RETAINED_AS_AUTHORITY_HOLD"
            )
        expected_authority_reasons = list(
            dict.fromkeys(expected_authority_reasons)
        )
        if candidate["authorityHoldReasons"] != expected_authority_reasons:
            return False

        expected_morphology_reasons: list[str] = []
        if has_representative_path:
            if not (
                finite_thresholds["manufacturedMinimumWidthDegrees"]
                <= float(candidate["widthDegrees"])
                <= finite_thresholds["manufacturedMaximumWidthDegrees"]
            ):
                expected_morphology_reasons.append(
                    "TRACED_SHOULDER_WIDTH_OUTSIDE_MANUFACTURED_RANGE"
                )
            if int(candidate["apexCount"]) != 1:
                expected_morphology_reasons.append("NOT_EXACTLY_ONE_NATIVE_APEX")
            if (
                float(candidate["apexOffsetFraction"])
                > finite_thresholds["manufacturedMaximumTipOffsetFraction"]
            ):
                expected_morphology_reasons.append(
                    "APEX_OFFSET_EXCEEDS_FROZEN_LIMIT"
                )
            if (
                float(candidate["leftMonotonicSupportFraction"])
                < finite_thresholds["manufacturedMinimumSlopeConsistency"]
            ):
                expected_morphology_reasons.append(
                    "LEFT_SIDE_NOT_MONOTONICALLY_INWARD"
                )
            if (
                float(candidate["rightMonotonicSupportFraction"])
                < finite_thresholds["manufacturedMinimumSlopeConsistency"]
            ):
                expected_morphology_reasons.append(
                    "RIGHT_SIDE_NOT_MONOTONICALLY_OUTWARD"
                )
            if (
                float(candidate["postContourSymmetryScore"])
                < finite_thresholds["manufacturedMinimumSymmetry"]
            ):
                expected_morphology_reasons.append(
                    "POST_CONTOUR_SYMMETRY_BELOW_FROZEN_LIMIT"
                )
            if (
                float(candidate["secondDifferenceAbsoluteP90Px"])
                > finite_thresholds["maximumSmoothSecondDifferenceP90Px"]
            ):
                expected_morphology_reasons.append("JAGGED_SECOND_DIFFERENCE")
            if (
                float(candidate["extraCurvatureReversalFraction"])
                > finite_thresholds["maximumExtraCurvatureReversalFraction"]
            ):
                expected_morphology_reasons.append("EXCESS_CURVATURE_REVERSALS")
            if int(candidate["representativeParallelBandSwitchCount"]):
                expected_morphology_reasons.append(
                    "REPRESENTATIVE_NATIVE_RADIAL_BAND_JUMP"
                )
            if resolved_physical_count == 0:
                expected_morphology_reasons.append(
                    "NO_COHERENT_STRICT_CORE_CORRIDOR_SIGNATURE"
                )
            if (
                float(candidate["leftShoulderReturnResidualFromNormalTracePx"])
                > finite_thresholds["maximumReturnResidualFromNormalTracePx"]
            ):
                expected_morphology_reasons.append(
                    "LEFT_SHOULDER_DOES_NOT_RETURN_TO_NORMAL_TRACE_DEPTH"
                )
            if (
                float(candidate["rightShoulderReturnResidualFromNormalTracePx"])
                > finite_thresholds["maximumReturnResidualFromNormalTracePx"]
            ):
                expected_morphology_reasons.append(
                    "RIGHT_SHOULDER_DOES_NOT_RETURN_TO_NORMAL_TRACE_DEPTH"
                )
        if candidate["postContourMorphologyReasons"] != expected_morphology_reasons:
            return False
        evidence_qualified = bool(
            has_representative_path
            and float(candidate["rawSupportedFraction"])
            >= finite_thresholds["minimumPathCoverageFraction"]
            and int(candidate["maximumContiguousUnsupportedRun"])
            <= int(thresholds["maximumUnsupportedRunSamples"])
            and not candidate.get("evidenceHoldReasons")
        )
        gap_free = bool(evidence_qualified and int(candidate["unsupportedColumnCount"]) == 0)
        if not (
            bool(candidate["nativeContourEvidenceQualified"]) == evidence_qualified
            and bool(candidate["boundedGapNativeShoulderPath"]) == evidence_qualified
            and bool(candidate["completeNativeShoulderPath"]) == evidence_qualified
            and bool(candidate["gapFreeNativeShoulderPath"]) == gap_free
        ):
            return False
        manufactured = bool(candidate.get("manufacturedCompatibleAfterContour"))
        diagnostic_eligible = bool(candidate.get("diagnosticPairingEligible"))
        authority_eligible = bool(
            candidate.get("candidateLocalAuthorityEligibleBeforeGlobalHold")
        )
        if diagnostic_eligible != manufactured:
            return False
        if (diagnostic_eligible or manufactured) and resolved_physical_count < 1:
            return False
        if manufactured != bool(
            evidence_qualified
            and resolved_physical_count >= 1
            and not candidate["postContourMorphologyReasons"]
        ):
            return False
        if authority_eligible != bool(diagnostic_eligible and not candidate.get("authorityHoldReasons")):
            return False
        if (
            has_representative_path
            and excluded_band_count > 0
            and "STRICT_CORE_COARSE_BAND_EVIDENCE_OUTSIDE_COMPLETE_SHOULDER_GRAPH_RETAINED"
            not in candidate["authorityHoldReasons"]
        ):
            return False
        if (
            has_representative_path
            and resolved_physical_count > 1
            and "SUSTAINED_MULTIPLE_STRICT_CORE_CORRIDORS_RETAINED_AS_AUTHORITY_HOLD"
            not in candidate["authorityHoldReasons"]
        ):
            return False
        if (
            has_representative_path
            and resolved_physical_count >= 1
            and nonrepresentative_seed_ids
            and "ADDITIONAL_STRICT_CORE_SEEDS_OUTSIDE_UNIQUE_COHERENT_CORE_CORRIDOR_RETAINED"
            not in candidate["authorityHoldReasons"]
        ):
            return False
        if bool(candidate.get("pairingEligible")) != diagnostic_eligible:
            return False
        if bool(candidate.get("notchOwnershipGranted")):
            return False
        if bool(candidate.get("nativeContourShapeCompatibleAfterContour")) != bool(
            candidate.get("manufacturedCompatibleAfterContour")
        ):
            return False
        expected_classification = (
            "UNRESOLVED_DEEP_EDGE_RESPONSE"
            if candidate["evidenceHoldReasons"]
            else "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE"
            if manufactured
            else "NON_NOTCH_DEEP_EDGE_RESPONSE"
        )
        if (
            candidate["classification"] != expected_classification
            or (
                not has_representative_path
                and not str(candidate["state"]).startswith("HOLD_")
            )
            or (
                has_representative_path
                and candidate["state"]
                != (
                    "HOLD_UNRESOLVED_NATIVE_CANDIDATE_CONTOUR"
                    if candidate["evidenceHoldReasons"]
                    else "HOLD_NATIVE_CONTOUR_AUTHORITY_RETAINED"
                    if candidate["authorityHoldReasons"]
                    else "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE_AFTER_NATIVE_CONTOUR"
                    if manufactured
                    else "NON_NOTCH_DEEP_EDGE_RESPONSE"
                )
            )
        ):
            return False
        path_metrics = (
            "apexCount",
            "apexBandMinimumDepthPx",
            "apexOffsetFraction",
            "postContourShapeTipOffsetFraction",
            "leftMonotonicSupportFraction",
            "rightMonotonicSupportFraction",
            "postContourShapeSlopeConsistencyFraction",
            "postContourSymmetryScore",
            "firstDifferenceAbsoluteP90Px",
            "firstDifferenceAbsoluteMedianPx",
            "secondDifferenceAbsoluteP90Px",
            "secondDifferenceAbsoluteMedianPx",
            "secondDifferenceAbsoluteMaximumPx",
            "maximumAdjacentRadialChangePxPerSample",
            "slopeDirectionReversalCount",
            "curvatureReversalCount",
            "extraCurvatureReversalFraction",
            "representativeParallelBandSwitchCount",
            "postContourSymmetryExactNativePairCount",
        )
        path_states = (
            "apexAndOffset",
            "monotonicSides",
            "smoothnessJaggednessCurvature",
            "representativeParallelBandSwitches",
        )
        if has_representative_path:
            if any(candidate[key] is None for key in path_metrics):
                return False
            if not (
                candidate["apexPopulation"]
                == "UNSMOOTHED_REPRESENTATIVE_PATH_DEPTH_WITHIN_MAX_3PX_OR_8_PERCENT_RANGE"
                and candidate["firstDifferencePopulation"]
                == "DEPTH_SLOPE_PER_EXACT_NATIVE_ANGULAR_SAMPLE_DELTA_NO_FILL"
                and candidate["secondDifferencePopulation"]
                == "ADJACENT_DEPTH_SLOPE_CHANGE_PER_NONUNIFORM_NATIVE_MIDPOINT_DELTA_NO_FILL"
                and candidate["curvatureReversalPopulation"]
                == "SIGN_CHANGES_OF_SIGNIFICANT_UNSMOOTHED_SECOND_DIFFERENCES"
                and math.isclose(
                    float(candidate["postContourShapeTipOffsetFraction"]),
                    float(candidate["apexOffsetFraction"]),
                    rel_tol=0.0,
                    abs_tol=1.0e-12,
                )
                and 0.0 <= float(candidate["apexOffsetFraction"]) <= 1.0
                and 0.0
                <= float(candidate["leftMonotonicSupportFraction"])
                <= 1.0
                and 0.0
                <= float(candidate["rightMonotonicSupportFraction"])
                <= 1.0
                and 0.0
                <= float(candidate["postContourShapeSlopeConsistencyFraction"])
                <= 1.0
                and 0.0 <= float(candidate["postContourSymmetryScore"]) <= 1.0
                and int(candidate["postContourSymmetryExactNativePairCount"])
                >= 0
                and all(
                    math.isfinite(float(candidate[key]))
                    and float(candidate[key]) >= 0.0
                    for key in (
                        "apexBandMinimumDepthPx",
                        "firstDifferenceAbsoluteMedianPx",
                        "firstDifferenceAbsoluteP90Px",
                        "secondDifferenceAbsoluteMedianPx",
                        "secondDifferenceAbsoluteP90Px",
                        "secondDifferenceAbsoluteMaximumPx",
                        "maximumAdjacentRadialChangePxPerSample",
                        "extraCurvatureReversalFraction",
                    )
                )
                and int(candidate["apexCount"]) >= 0
                and int(candidate["slopeDirectionReversalCount"]) >= 0
                and int(candidate["curvatureReversalCount"]) >= 0
            ):
                return False
            if not (
                candidate["representativeNativeRadialTravelPx"] is not None
                and math.isfinite(float(candidate["representativeNativeRadialTravelPx"]))
                and float(candidate["representativeNativeRadialTravelPx"]) >= 0.0
            ):
                return False
            if any(not str(availability[key]).startswith("MEASURED_") for key in path_states):
                return False
            if not str(availability["coherentCoreCorridorSignatures"]).startswith("MEASURED_"):
                return False
        else:
            if not (
                str(candidate.get("state", "")).startswith("HOLD_")
                and candidate.get("classification") == "UNRESOLVED_DEEP_EDGE_RESPONSE"
                and all(candidate[key] is None for key in path_metrics)
                and str(candidate["apexPopulation"]).startswith("NOT_MEASURABLE_")
                and str(candidate["firstDifferencePopulation"]).startswith("NOT_MEASURABLE_")
                and str(candidate["secondDifferencePopulation"]).startswith("NOT_MEASURABLE_")
                and str(candidate["curvatureReversalPopulation"]).startswith(
                    "NOT_MEASURABLE_"
                )
                and candidate["representativeNativeRadialTravelPx"] is None
                and all(str(availability[key]).startswith("NOT_MEASURABLE_") for key in path_states)
                and str(availability["coherentCoreCorridorSignatures"]).startswith("NOT_MEASURABLE_")
            ):
                return False
        return bool(
            candidate.get("allSelectedPixelsNativeSupported")
            and candidate.get("allSelectedPixelsRawPolaritySupported")
        )
    except (KeyError, TypeError, ValueError, OverflowError, RuntimeError):
        return False


def post2_semantic_checks(results: list[dict[str, Any]]) -> dict[str, bool]:
    by_identity = {row["identity"]: row for row in results}
    need(len(by_identity) == 3, "POST2 semantic population does not contain three identities")
    slot01 = next(row for identity, row in by_identity.items() if identity.endswith("SLOT01"))
    slot03 = next(row for identity, row in by_identity.items() if identity.endswith("SLOT03"))
    slot17 = next(row for identity, row in by_identity.items() if identity.endswith("SLOT17"))

    def complete_native(candidate: dict[str, Any] | None) -> bool:
        return bool(
            candidate is not None
            and candidate.get("boundedGapNativeShoulderPath")
            and candidate.get("nativeContourEvidenceQualified")
            and candidate.get("allSelectedPixelsNativeSupported")
            and candidate.get("allSelectedPixelsRawPolaritySupported")
            and int(candidate.get("representativeParallelBandSwitchCount", 0)) == 0
            and not candidate.get("interpolationPerformed")
            and int(candidate.get("syntheticCoordinateCount", -1)) == 0
        )

    def interval_contains(candidate: dict[str, Any], angle: float) -> bool:
        start = float(candidate["startAngleDegrees"]) % 360.0
        width = float(candidate["widthDegrees"])
        return ((float(angle) % 360.0) - start) % 360.0 <= width + 1.0e-9

    def interval_covers(outer: dict[str, Any], inner: dict[str, Any]) -> bool:
        outer_start = float(outer["startAngleDegrees"]) % 360.0
        outer_width = min(max(float(outer["widthDegrees"]), 0.0), 360.0)
        inner_start = float(inner["startAngleDegrees"]) % 360.0
        inner_width = min(max(float(inner["widthDegrees"]), 0.0), 360.0)
        start_delta = (inner_start - outer_start) % 360.0
        return bool(
            outer_width + 1.0e-9 >= inner_width
            and start_delta + inner_width <= outer_width + 1.0e-9
        )

    def target_basins(result: dict[str, Any], channel: str, angle: float) -> list[dict[str, Any]]:
        return [
            candidate for candidate in result["channels"][channel]["candidates"]
            if candidate.get("candidateDiscovery")
            == "MEASURED_NORMAL_TRACE_INTERRUPTION_BASIN_CONTAINING_STRICT_NATIVE_CORE"
            and interval_contains(candidate, angle)
        ]

    slot01_channel_checks: list[bool] = []
    slot01_irregular_measured_nonshape = 0
    for channel in ("BF", "DF"):
        smooth_rows = target_basins(slot01, channel, 90.0)
        irregular_rows = target_basins(slot01, channel, 86.0)
        smooth = smooth_rows[0] if len(smooth_rows) == 1 else None
        irregular = irregular_rows[0] if len(irregular_rows) == 1 else None
        irregular_measured_nonshape = bool(
            complete_native(irregular)
            and irregular is not None
            and not irregular.get("nativeContourShapeCompatibleAfterContour")
            and not irregular.get("diagnosticPairingEligible")
            and any(
                reason not in {
                    "PARALLEL_NATIVE_BAND_BRANCH",
                    "REPRESENTATIVE_NATIVE_RADIAL_BAND_JUMP",
                }
                for reason in irregular.get("postContourMorphologyReasons", [])
            )
        )
        slot01_irregular_measured_nonshape += int(irregular_measured_nonshape)
        irregular_explicit_hold = bool(
            irregular is not None
            and str(irregular.get("state", "")).startswith("HOLD_")
            and not complete_native(irregular)
        )
        smooth_path_is_measured_and_smooth = bool(
            complete_native(smooth)
            and smooth is not None
            and int(smooth.get("apexCount", 0)) == 1
            and (channel == "BF" or bool(smooth.get("diagnosticPairingEligible")))
            and not bool(
                smooth.get("candidateLocalAuthorityEligibleBeforeGlobalHold")
            )
            and not bool(smooth.get("notchOwnershipGranted"))
            and int(smooth.get("representativeParallelBandSwitchCount", -1)) == 0
            and float(smooth.get("secondDifferenceAbsoluteP90Px", float("inf")))
            <= MAXIMUM_SMOOTH_SECOND_DIFFERENCE_P90_PX
            and "EXCESS_CURVATURE_REVERSALS"
            not in smooth.get("postContourMorphologyReasons", [])
        )
        slot01_channel_checks.append(
            bool(
                len(smooth_rows) == 1
                and len(irregular_rows) == 1
                and smooth_path_is_measured_and_smooth
                and (irregular_measured_nonshape or irregular_explicit_hold)
                and smooth is not None
                and irregular is not None
                and candidate_interval_overlap(smooth, irregular) == 0.0
                and circular_distance_degrees(
                    float(smooth["centerAngleDegrees"]), float(irregular["centerAngleDegrees"])
                ) > 2.0
            )
        )
    slot01_separate = bool(
        all(slot01_channel_checks) and slot01_irregular_measured_nonshape >= 1
    )
    slot01_diagnostic_pairs = slot01["pairDiagnostic"].get(
        "r27DiagnosticResolvedPairsRemainUnowned", []
    )
    slot01_df_only_interval = slot01["pairDiagnostic"].get("sameChuckAngleOnlyTransfer")
    slot01_diagnostic_counts = {
        channel: sum(
            bool(candidate.get("diagnosticPairingEligible"))
            for candidate in slot01["channels"][channel]["candidates"]
        )
        for channel in ("BF", "DF")
    }
    slot01_unique_unowned_notch = bool(
        (
            (
                len(slot01_diagnostic_pairs) == 1
                and slot01_diagnostic_counts == {"BF": 1, "DF": 1}
                and slot01["pairDiagnostic"].get("eligiblePairCountBeforeR6Secondary") == 1
                and slot01["pairDiagnostic"].get("r6SecondaryCorroboratedEligiblePairCount") == 1
            )
            or (
                not slot01_diagnostic_pairs
                and slot01_diagnostic_counts == {"BF": 0, "DF": 1}
                and isinstance(slot01_df_only_interval, dict)
                and slot01_df_only_interval.get("transferredPixelCoordinateCount") == 0
                and slot01_df_only_interval.get("bfContourHoldRetained") is True
            )
        )
        and slot01["pairDiagnostic"].get("r6SecondarySelectionPerformed") is False
    )

    slot03_df_rows = target_basins(slot03, "DF", 90.0)
    slot03_bf_rows = target_basins(slot03, "BF", 90.0)
    slot03_df_real = bool(
        len(slot03_df_rows) == 1
        and complete_native(slot03_df_rows[0])
        and slot03_df_rows[0].get("diagnosticPairingEligible")
    )
    slot03_bf_real = bool(
        len(slot03_bf_rows) == 1
        and complete_native(slot03_bf_rows[0])
        and slot03_bf_rows[0].get("diagnosticPairingEligible")
    )
    slot03_bf_explicit_hold = bool(
        len(slot03_bf_rows) == 1
        and str(slot03_bf_rows[0].get("state", "")).startswith("HOLD_")
    )
    slot03_real = bool(slot03_df_real and (slot03_bf_real or slot03_bf_explicit_hold))
    slot03_diagnostic_pairs = slot03["pairDiagnostic"].get(
        "r27DiagnosticResolvedPairsRemainUnowned", []
    )
    slot03_unique_unowned_notch = bool(
        len(slot03_diagnostic_pairs) == 1
        and slot03["pairDiagnostic"].get("eligiblePairCountBeforeR6Secondary") == 1
        and slot03["pairDiagnostic"].get("r6SecondaryCorroboratedEligiblePairCount") == 1
        and slot03["pairDiagnostic"].get("r6SecondarySelectionPerformed") is False
    )

    slot17_df_rows = target_basins(slot17, "DF", 89.64)
    slot17_df_real = bool(
        len(slot17_df_rows) == 1
        and complete_native(slot17_df_rows[0])
        and slot17_df_rows[0].get("diagnosticPairingEligible")
    )
    slot17_pinned_broad = slot17["channels"]["BF"]["inheritedAuthority"].get("r22BroadResponse")
    need(isinstance(slot17_pinned_broad, dict), "Pinned R22 SLOT17 BF broad response is absent")
    slot17_broad = [
        row for row in slot17["channels"]["BF"]["candidates"]
        if row.get("candidateDiscovery") == "WHOLE_BROAD_STRICT_NATIVE_CORE_PARENT_HOLD"
        and row.get("broadHalfPerimeterResponse")
        and row.get("state") == "HOLD_BROAD_RESPONSE_HAS_NO_UNIQUE_SHORT_SHOULDER_INTERVAL"
        and not row.get("pairingEligible")
        and row.get("broadParentHoldIds") == row.get("strictCoreSeedIds")
        and len(row.get("strictCoreNativeNodes", []))
        == len(row.get("rawComponentNativeNodes", []))
        and interval_covers(row, slot17_pinned_broad)
    ]
    slot17_broad_held = bool(
        len(slot17_broad) == 1
        and not slot17["pairDiagnostic"].get("r27DiagnosticResolvedPairsRemainUnowned")
        and slot17["pairDiagnostic"]["state"]
        == "HOLD_PREDECESSOR_R22_NOTCH_OWNERSHIP_AUTHORITY_RETAINED"
    )
    slot17_df_only_interval = slot17["pairDiagnostic"].get("sameChuckAngleOnlyTransfer")
    slot17_df_only_unowned_notch = bool(
        slot17_df_real
        and not slot17["pairDiagnostic"].get("r27DiagnosticResolvedPairsRemainUnowned")
        and isinstance(slot17_df_only_interval, dict)
        and slot17_df_only_interval.get("transferredPixelCoordinateCount") == 0
        and slot17_df_only_interval.get("bfContourHoldRetained") is True
        and slot17["pairDiagnostic"].get("r6SecondarySelectionPerformed") is False
    )

    channels = [row["channels"][channel] for row in results for channel in ("BF", "DF")]
    candidates = [candidate for channel in channels for candidate in channel["candidates"]]
    candidate_assets = [asset for channel in channels for asset in channel["assets"]["candidateReviews"]]
    candidate_accounting = bool(
        candidates
        and all(
            channel["candidateCount"]
            == channel["candidateDiscovery"]["qualifiedInterruptionBasinCount"]
            + channel["candidateDiscovery"]["broadStrictCoreParentCount"]
            and channel["candidateDiscovery"]["allStrictCoreNodesAccountedFor"]
            for channel in channels
        )
    )
    rendering_exact = bool(
        all(
            channel["assets"]["renderSemantics"]["normalBrightnessPixelCount"] > 0
            and channel["assets"]["renderSemantics"]["circleOnlyNormalBrightnessPixelCount"]
            == channel["assets"]["renderSemantics"]["normalBrightnessPixelCount"]
            and channel["assets"]["renderSemantics"][
                "circleOnlyChangedPixelsInsideGeometryAndNormalMasks"
            ]
            and channel["assets"]["renderSemantics"][
                "allCandidateChangedPixelsInsideDeclaredMasks"
            ]
            and channel["assets"]["circleAndBrightnessReview"]["path"]
            != channel["assets"]["allCandidateContourReview"]["path"]
            for channel in channels
        )
        and all(
            asset["renderSemantics"]["normalContextPixelCount"] > 0
            and asset["renderSemantics"]["expectedRepresentativeNativePixelCount"]
            == asset["renderSemantics"]["renderedRepresentativeNativePixelCount"]
            and asset["renderSemantics"]["expectedCandidateGraphPixelCount"] > 0
            and asset["renderSemantics"]["expectedCandidateGraphPixelCount"]
            == asset["renderSemantics"]["renderedCandidateGraphPixelCount"]
            and asset["renderSemantics"]["expectedDiagnosticNotchPixelCount"]
            == asset["renderSemantics"]["diagnosticNotchCandidatePixelCount"]
            and asset["renderSemantics"]["candidateLocalOnly"]
            for asset in candidate_assets
        )
        and all(
            not candidate.get("completeNativeShoulderPath")
            or len(candidate.get("representativePath", [])) > 0
            for candidate in candidates
        )
    )
    inherited_holds = bool(
        all(
            channel.get("inheritedR22R23HoldRetained")
            and channel.get("inheritedR22CyanHoldRetained")
            and channel.get("predecessorHoldsCleared") is False
            for channel in channels
        )
        and all(
            row["pairDiagnostic"].get("inheritedR22OwnershipHoldsRetained")
            and row["pairDiagnostic"].get("resolvedPairCount") == 0
            for row in results
        )
        and sum(
            str(channel["inheritedAuthority"]["r22CyanGeometryVerificationState"]).startswith("HOLD_")
            for channel in channels
        ) == 5
    )
    pair_diagnostics = [row["pairDiagnostic"] for row in results]
    exact_r22_pair_authority = all(
        pair.get("state")
        == "HOLD_PREDECESSOR_R22_NOTCH_OWNERSHIP_AUTHORITY_RETAINED"
        and pair.get("inheritedR22OwnershipHoldsRetained") is True
        and int(pair.get("inheritedR22OwnershipHoldCount", -1)) == 2
        for pair in pair_diagnostics
    )
    resolved_authority_pairs_empty = all(
        pair.get("resolvedPairCount") == 0 and pair.get("resolvedPairs") == []
        for pair in pair_diagnostics
    )
    diagnostic_pairs_unowned = True
    for result in results:
        pair = result["pairDiagnostic"]
        diagnostic_rows = pair.get("r27DiagnosticResolvedPairsRemainUnowned")
        if not isinstance(diagnostic_rows, list):
            diagnostic_pairs_unowned = False
            break
        for diagnostic in diagnostic_rows:
            try:
                bf = result["channels"]["BF"]["candidates"][
                    int(diagnostic["bfCandidateIndex"])
                ]
                df = result["channels"]["DF"]["candidates"][
                    int(diagnostic["dfCandidateIndex"])
                ]
            except (KeyError, IndexError, TypeError, ValueError):
                diagnostic_pairs_unowned = False
                break
            if not (
                diagnostic.get("eligibleAfterAllChannelLocalContours") is True
                and bf.get("diagnosticPairingEligible") is True
                and df.get("diagnosticPairingEligible") is True
                and bf.get("notchOwnershipGranted") is False
                and df.get("notchOwnershipGranted") is False
            ):
                diagnostic_pairs_unowned = False
                break
        if not diagnostic_pairs_unowned:
            break
    held_diagnostics_local_ineligible = all(
        not candidate.get("authorityHoldReasons")
        or not candidate.get("diagnosticPairingEligible")
        or candidate.get("candidateLocalAuthorityEligibleBeforeGlobalHold") is False
        for candidate in candidates
    )
    no_pair_authority_action = all(
        pair.get("holdClearancePerformed") is False
        and pair.get("productionSelectionPerformed") is False
        for pair in pair_diagnostics
    )
    same_chuck_angle_only = all(
        pair.get("sameChuckAngleOnlyTransfer") is None
        or (
            isinstance(pair.get("sameChuckAngleOnlyTransfer"), dict)
            and pair["sameChuckAngleOnlyTransfer"].get("sourceChannel") == "DF"
            and pair["sameChuckAngleOnlyTransfer"].get("targetChannel") == "BF"
            and pair["sameChuckAngleOnlyTransfer"].get(
                "transferredPixelCoordinateCount"
            )
            == 0
            and pair["sameChuckAngleOnlyTransfer"].get("bfContourHoldRetained")
            is True
            and pair["sameChuckAngleOnlyTransfer"].get(
                "futureRegistrationAuthorityGranted"
            )
            is False
            and pair.get("crossChannelPixelCoordinateTransferPerformed") is False
        )
        for pair in pair_diagnostics
    )
    checks = {
        "threePost2MembersComplete": len(results) == 3,
        "allSixChannelCirclesQualified": all(row["circleQualified"] for row in channels),
        "cyanOuterGeometryUnchanged": all(not row["evidence"]["cyanGeometryChanged"] for row in channels),
        "yellowExactly20PxInward": all(
            float(row["edgeZoneInwardPx"]) == 20.0
            and float(row["maximumEdgeZoneSpacingErrorPx"]) <= 1.0e-4
            for row in channels
        ),
        "everyRawCandidateContouredBeforePairing": all(row["allCandidatesContouredBeforePairing"] for row in channels),
        "everyQualifiedInterruptionBasinAndBroadHoldContoured": candidate_accounting,
        "allStrictCoreNodesAccountedFor": all(
            row["candidateDiscovery"]["allStrictCoreNodesAccountedFor"] for row in channels
        ),
        "allSelectedCandidatePixelsNativeAndRawSupported": all(
            row.get("allSelectedPixelsNativeSupported") is True
            and row.get("allSelectedPixelsRawPolaritySupported") is True
            for row in candidates
        ),
        "completePerCandidateContourMetricSchema": all(
            candidate_metric_schema_valid(row) for row in candidates
        ),
        "sustainedShoulderGapSemanticsExact": bool(
            candidates and all(candidate_metric_schema_valid(row) for row in candidates)
        ),
        "slot01Smooth90SeparateFromIrregular86": slot01_separate,
        "slot01ExactlyOneDiagnosticNotchPairRemainsUnowned": slot01_unique_unowned_notch,
        "slot03Df90AndBfWhenSupportedUseNativeBrightness": slot03_real,
        "slot03ExactlyOneDiagnosticNotchPairRemainsUnowned": slot03_unique_unowned_notch,
        "slot17Df89p64ContourUsesNativeBrightness": slot17_df_real,
        "slot17DfOnlyDiagnosticIntervalTransfersZeroPixels": slot17_df_only_unowned_notch,
        "slot17BroadBfResponseHeldWhole": slot17_broad_held,
        "allDiagnosticNotchTracesHaveZeroAvoidableNativeRadialBandSwitches": all(
            not row.get("diagnosticPairingEligible")
            or int(row.get("representativeParallelBandSwitchCount", -1)) == 0
            for row in candidates
        ),
        "diagnosticNotchNeverGrantsAuthority": all(
            not row.get("notchOwnershipGranted") for row in candidates
        ),
        "noCandidateMorphologyOrInterpolation": all(
            row.get("morphologyPerformed") is False
            and row.get("interpolationPerformed") is False
            and int(row.get("syntheticCoordinateCount", -1)) == 0
            and row.get("templateOrIdealCurveUsed") is False
            and row.get("candidateCenterUsedByTraversal") is False
            and row.get("monotonicityUsedByTraversal") is False
            for row in candidates
        ),
        "brightnessTraceRenderedOnCircleAndCandidateViews": rendering_exact,
        "noCrossChannelPixelTransfer": all(
            not row["pairDiagnostic"]["crossChannelPixelCoordinateTransferPerformed"]
            for row in results
        ),
        "r6NeverSelectsAmongCandidatePairs": all(
            row["pairDiagnostic"].get("r6SecondaryTieBreakPerformed") is False
            and row["pairDiagnostic"].get("r6SecondarySelectionPerformed") is False
            for row in results
        ),
        "allPredecessorHoldsRetained": inherited_holds,
        "everyPost2PairAuthorityStateExactlyR22Hold": exact_r22_pair_authority,
        "everyPost2ResolvedAuthorityPairPopulationEmpty": resolved_authority_pairs_empty,
        "diagnosticPairRecordsPreservedOnlyAsUnownedEvidence": diagnostic_pairs_unowned,
        "authorityHeldDiagnosticCandidatesRemainLocalAuthorityIneligible": (
            held_diagnostics_local_ineligible
        ),
        "everyPost2PairForbidsHoldClearanceAndProductionSelection": (
            no_pair_authority_action
        ),
        "sameChuckTransferIsAngleIntervalOnlyAndZeroPixels": same_chuck_angle_only,
    }
    need(
        set(checks) == POST2_SEMANTIC_CHECK_KEYS,
        "R27 POST2 semantic-check contract differs from its exact key set",
    )
    return checks


def generated_inventory(root: Path) -> list[dict[str, Any]]:
    return [
        file_record(path)
        for path in sorted(
            (candidate for candidate in root.rglob("*") if candidate.is_file()),
            key=lambda item: str(item).lower(),
        )
    ]


def exact_true_boolean_map(value: Any, expected_keys: frozenset[str]) -> bool:
    return bool(
        isinstance(value, dict)
        and set(value) == expected_keys
        and all(item is True for item in value.values())
    )


def frozen_prelabel_gate_maps_valid(
    summary: dict[str, Any], gate: dict[str, Any], population: dict[str, Any]
) -> bool:
    semantic_maps = [
        document.get("semanticChecksBeforeLabels")
        for document in (summary, gate, population)
    ]
    integrity_maps = [
        document.get("integrityChecksBeforeLabels")
        for document in (summary, gate, population)
    ]
    return bool(
        gate.get("state")
        == "PASS_R27_NEUTRAL_POPULATION_FROZEN_WITH_SEMANTIC_HOLDS_RETAINED"
        and all(
            exact_true_boolean_map(value, INFERENCE_SEMANTIC_CHECK_KEYS)
            for value in semantic_maps
        )
        and all(
            exact_true_boolean_map(value, INFERENCE_INTEGRITY_CHECK_KEYS)
            for value in integrity_maps
        )
        and semantic_maps[0] == semantic_maps[1] == semantic_maps[2]
        and integrity_maps[0] == integrity_maps[1] == integrity_maps[2]
        and gate.get("semanticCheckFailuresRemainOperatorVisibleHolds") == []
        and gate.get("allRequiredSemanticChecksPassedBeforeLabelRead") is True
        and gate.get("evaluationMayReadScorerLabelOnlyAfterRehashingFrozenPopulation")
        is True
    )


def exact_embedded_file_record(
    record: Any, expected_path: Path, expected_sha256: str
) -> bool:
    try:
        return bool(
            isinstance(record, dict)
            and set(record) == {"path", "bytes", "sha256"}
            and same_windows_path(Path(str(record["path"])), expected_path)
            and int(record["bytes"]) == expected_path.stat().st_size
            and str(record["sha256"]).upper() == expected_sha256.upper()
        )
    except (OSError, TypeError, ValueError):
        return False


def run_inference(args: argparse.Namespace) -> int:
    for supplied, expected, label in (
        (args.checkpoint_sha256, CHECKPOINT_SHA256, "checkpoint"),
        (args.rollover_manifest_sha256, ROLLOVER_MANIFEST_SHA256, "rollover manifest"),
        (args.rollover_gate_sha256, ROLLOVER_GATE_SHA256, "rollover gate"),
        (args.source_job_sha256, SOURCE_JOB_SHA256, "POST2 source job"),
        (args.geometry_job_sha256, GEOMETRY_JOB_SHA256, "geometry job"),
        (args.hotspot_input_sha256, HOTSPOT_INPUT_SHA256, "hotspot input"),
        (args.hotspot_oracle_sha256, HOTSPOT_ORACLE_SHA256, "hotspot oracle"),
        (args.hotspot_oracle_gate_sha256, HOTSPOT_ORACLE_GATE_SHA256, "hotspot oracle gate"),
    ):
        need(str(supplied).upper() == expected, f"Supplied {label} pin differs from R27")
    output = Path(args.output_root)
    workspace = Path(args.workspace_root).resolve()
    workspace_io = Path(args.workspace_io_root).absolute()
    code_root = Path(args.code_root).resolve()
    need(workspace.is_dir(), "Desktop authority workspace root is missing")
    need(workspace_io.is_absolute() and workspace_io.is_dir(), "R: workspace alias is missing")
    need(code_root == PROJECT_ROOT.resolve(), "R27 code root differs from its exact checkout")
    need(
        output.is_absolute()
        and output.drive.upper() == "C:"
        and same_windows_path(output, EXPECTED_INFERENCE_ROOT)
        and not output.exists()
        and len(str(output)) + 128 < 200,
        "R27 inference output must be a fresh short C: root",
    )
    source_job_path = Path(args.source_job)
    geometry_job_path = Path(args.geometry_job)
    closure = verify_rollover_closure(
        Path(args.rollover_manifest),
        args.rollover_manifest_sha256,
        Path(args.rollover_gate),
        args.rollover_gate_sha256,
        Path(args.checkpoint),
        args.checkpoint_sha256,
        code_root,
        workspace_io,
    )
    source_job = load_json_pinned(source_job_path, SOURCE_JOB_SHA256, "POST2 source job")
    geometry_job = load_json_pinned(geometry_job_path, GEOMETRY_JOB_SHA256, "geometry job")
    assert_review_only(source_job, "POST2 source job")
    assert_review_only(geometry_job, "geometry job")
    need(source_job.get("schema") == "argos_ocv03_o3p8_front_split_notch_job_v1", "POST2 source-job schema differs")
    need(geometry_job.get("schema") == "argos_ocv03_full_perimeter_topology_job_v1", "Geometry-job schema differs")
    need(Path(str(source_job["workspaceAlias"]["target"])).resolve() == workspace, "Manifest Desktop authority root differs")
    need(workspace_io.drive.upper() == str(source_job["workspaceAlias"]["drive"]).upper(), "R: alias drive differs")
    relative_job = source_job_path.resolve().relative_to(workspace)
    alias_sentinel = workspace_io / relative_job
    require_exact_file(alias_sentinel, SOURCE_JOB_SHA256, "R: source-job sentinel")
    loaded_dependencies = verify_engine_lineage()
    inherited_post2 = load_r22_inherited_post2_authority()
    hotspot_input_path = Path(args.hotspot_input)
    hotspot_oracle_path = Path(args.hotspot_oracle)
    hotspot_oracle_gate_path = Path(args.hotspot_oracle_gate)
    hotspot_input = load_json_pinned(hotspot_input_path, HOTSPOT_INPUT_SHA256, "hotspot input summary")
    require_exact_file(hotspot_oracle_path, HOTSPOT_ORACLE_SHA256, "hotspot R21 oracle")
    require_exact_file(hotspot_oracle_gate_path, HOTSPOT_ORACLE_GATE_SHA256, "hotspot R21 oracle gate")
    source_rows, seeds = verify_post2_sources(workspace_io, source_job)

    preflight_output_layout(
        output,
        [str(row["identity"]) for row in source_job["inputs"]]
        + [str(row["safeId"]) for row in hotspot_input["results"]],
    )
    free_bytes_before = int(shutil.disk_usage(output.parent).free)
    need(
        free_bytes_before >= MINIMUM_OUTPUT_FREE_BYTES,
        "Fresh R27 root lacks its 4 GiB logical-output allowance plus 8 GiB safety reserve",
    )
    output.mkdir()
    output_storage = enable_fresh_output_compression(output, free_bytes_before)
    neutral_root = output / "neutral"
    neutral_root.mkdir()
    need(directory_is_ntfs_compressed(neutral_root), "R27 neutral child did not inherit NTFS compression")
    post2_results = process_post2(
        neutral_root,
        source_job,
        source_rows,
        seeds,
        geometry_job,
        inherited_post2["byIdentity"],
    )
    hotspot_results = process_hotspot(neutral_root, hotspot_input, geometry_job)

    # The prior hotspot oracle is parsed only after all 14 independent channel
    # populations (six POST2, eight hotspot) have been contoured and rendered.
    hotspot_oracle = load_json_pinned(hotspot_oracle_path, args.hotspot_oracle_sha256, "hotspot R21 oracle")
    hotspot_oracle_gate = load_json_pinned(hotspot_oracle_gate_path, args.hotspot_oracle_gate_sha256, "hotspot R21 oracle gate")
    hotspot_regression = evaluate_hotspot_regression(
        hotspot_results, hotspot_oracle, hotspot_oracle_gate
    )
    semantic_checks = post2_semantic_checks(post2_results)
    semantic_checks["hotspotRegressionPreservesGoodContoursAndAllHolds"] = hotspot_regression["state"].startswith("PASS_")
    semantic_checks["completePerCandidateContourMetricSchemaAcrossAllFourteenChannels"] = all(
        candidate_metric_schema_valid(candidate)
        for cohort in (post2_results, hotspot_results)
        for result in cohort
        for channel in ("BF", "DF")
        for candidate in result["channels"][channel]["candidates"]
    )
    need(
        set(semantic_checks) == INFERENCE_SEMANTIC_CHECK_KEYS,
        "R27 inference semantic-check map differs from its exact key set",
    )
    integrity_checks = {
        "checkpointAndRolloverClosureExact": closure["uniquePinnedFileCount"] == 64,
        "sixBmpSourcesExactThroughAlias": len(source_rows) == 6,
        "threePost2MembersAndFourHotspotCasesComplete": len(post2_results) == 3
        and len(hotspot_results) == 4,
        "allFourteenChannelPopulationsPresent": len(post2_results) * 2
        + len(hotspot_results) * 2
        == 14,
        "neutralPopulationWrittenBeforeFreezeManifest": True,
        "freshOutputRootNtfsCompressionEnabledBeforeChildWrites": bool(
            output_storage["directoryCompressedAttributeVerifiedBeforeChildWrites"]
        ),
        "allNeutralFilesHashed": True,
        "scorerLabelJsonUnparsed": True,
        "noMorphInterpolationIdealCurveOrPixelTransfer": all(
            semantic_checks[key]
            for key in (
                "noCandidateMorphologyOrInterpolation",
                "noCrossChannelPixelTransfer",
            )
        ),
        "noSourceRuntimeProviderTaskOrPackageMutation": True,
    }
    need(
        set(integrity_checks) == INFERENCE_INTEGRITY_CHECK_KEYS,
        "R27 inference integrity-check map differs from its exact key set",
    )

    population = {
        "schema": POPULATION_SCHEMA,
        "state": "FROZEN_NEUTRAL_CANDIDATE_POPULATION_PENDING_POST_LABEL_EVALUATION",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "engine": file_record(Path(__file__).resolve()),
        "post2": post2_results,
        "hotspot": hotspot_results,
        "hotspotRegression": hotspot_regression,
        "inheritedPost2Authority": inherited_post2,
        "semanticChecksBeforeLabels": semantic_checks,
        "integrityChecksBeforeLabels": integrity_checks,
        "candidatePopulation": "ALL_FULL_360_MEASURED_NORMAL_TRACE_INTERRUPTION_BASINS_WITH_STRICT_CHANNEL_LOCAL_NATIVE_CORES_PLUS_WHOLE_BROAD_PARENTS_BEFORE_SCORER_LABEL",
        "candidatePopulationFrozenBeforeScorerLabelParse": True,
        "scorerLabelDigestVerifiedThroughRolloverClosure": True,
        "scorerLabelJsonParsed": False,
        "knownChipoutAngleUsedByCandidateSelection": False,
        "previouslyExposedDevelopmentRegionUsedOnlyByPostContourRegressionGate": True,
        "developmentCohortLabelPreviouslyExposed": True,
        "blindReliabilityEvidence": False,
        "chipoutThresholdTuningPerformed": False,
        "candidateFilteringFromChipoutTruthPerformed": False,
        "r6Role": "POST_CONTOUR_SECONDARY_CORROBORATION_ONLY_NEVER_TIE_BREAK_OR_SELECTION",
        "r6PrimaryContourSelectionPerformed": False,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "sourceMutationPerformed": False,
        "existingTaskOrProcessActionPerformed": False,
        "providerActivated": False,
        "holdClearancePerformed": False,
        "packageBuilt": False,
        "packageAttemptCount": 0,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    population_asset = write_json_new(neutral_root / "NEUTRAL_CANDIDATE_POPULATION.json", population)
    inventory_before_freeze = generated_inventory(neutral_root)
    freeze = {
        "schema": FREEZE_SCHEMA,
        "state": "PASS_R27_COMPLETE_NEUTRAL_POPULATION_FILESET_FROZEN",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "population": population_asset,
        "generatedFileCountBeforeFreezeManifest": len(inventory_before_freeze),
        "generatedFiles": inventory_before_freeze,
        "allGeneratedFilesHashed": True,
        "externalSourceAndDependencyRecordsRemainPinnedInPopulationAndSummary": True,
        "scorerLabelJsonParsed": False,
        "postFreezeWritesRestrictedToSummaryGateAndFreshEvaluationChild": True,
    }
    freeze_asset = write_json_new(neutral_root / "FREEZE_MANIFEST.json", freeze)
    total_candidates = sum(
        row["channels"][channel]["candidateCount"]
        for cohort in (post2_results, hotspot_results)
        for row in cohort
        for channel in ("BF", "DF")
    )
    summary = {
        "schema": SUMMARY_SCHEMA,
        "state": "COMPLETE_DIAGNOSTIC_ONLY_R27_NEUTRAL_POPULATION_FROZEN",
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "engine": file_record(Path(__file__).resolve()),
        "loadedDependencies": loaded_dependencies,
        "outputStorage": output_storage,
        "inheritedPost2AuthorityRecords": inherited_post2["records"],
        "checkpointAndRolloverClosure": closure,
        "sourceJob": file_record(source_job_path, SOURCE_JOB_SHA256),
        "geometryJob": file_record(geometry_job_path, GEOMETRY_JOB_SHA256),
        "aliasSentinel": file_record(alias_sentinel, SOURCE_JOB_SHA256),
        "sourceIntegrity": source_rows,
        "hotspotInput": file_record(hotspot_input_path, HOTSPOT_INPUT_SHA256),
        "hotspotOracle": file_record(hotspot_oracle_path, HOTSPOT_ORACLE_SHA256),
        "hotspotOracleGate": file_record(hotspot_oracle_gate_path, HOTSPOT_ORACLE_GATE_SHA256),
        "neutralPopulation": population_asset,
        "freezeManifest": freeze_asset,
        "post2MemberCount": len(post2_results),
        "post2ChannelCount": len(post2_results) * 2,
        "hotspotCaseCount": len(hotspot_results),
        "hotspotChannelCount": len(hotspot_results) * 2,
        "neutralCandidateCount": total_candidates,
        "semanticChecksBeforeLabels": semantic_checks,
        "integrityChecksBeforeLabels": integrity_checks,
        "workspaceAccess": {
            "authorityRoot": str(workspace),
            "ioAliasRoot": str(workspace_io),
            "aliasDrive": workspace_io.drive.upper(),
            "aliasByteIdentityVerified": True,
            "allSixFullResolutionBmpSourcesResolvedOnlyThroughAlias": True,
        },
        "scorerLabelDigestVerifiedOnly": True,
        "scorerLabelJsonParsed": False,
        "knownChipoutAngleUsedByCandidateSelection": False,
        "previouslyExposedDevelopmentRegionUsedOnlyByPostContourRegressionGate": True,
        "developmentCohortLabelPreviouslyExposed": True,
        "blindReliabilityEvidence": False,
        "candidatePopulationFrozenBeforeScorerLabelParse": True,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "sourceMutationPerformed": False,
        "existingTaskOrProcessActionPerformed": False,
        "providerActivated": False,
        "holdClearancePerformed": False,
        "packageBuilt": False,
        "packageAttemptCount": 0,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    summary_asset = write_json_new(output / "SUMMARY.json", summary)
    semantic_checks_pass = exact_true_boolean_map(
        semantic_checks, INFERENCE_SEMANTIC_CHECK_KEYS
    )
    evaluation_authorized = exact_true_boolean_map(
        integrity_checks, INFERENCE_INTEGRITY_CHECK_KEYS
    ) and semantic_checks_pass
    gate = {
        "schema": GATE_SCHEMA,
        "state": (
            "PASS_R27_NEUTRAL_POPULATION_FROZEN_WITH_SEMANTIC_HOLDS_RETAINED"
            if evaluation_authorized
            else "HOLD_R27_NEUTRAL_POPULATION_PRELABEL_GATE_FAILURE"
        ),
        "summary": summary_asset,
        "neutralPopulation": population_asset,
        "freezeManifest": freeze_asset,
        "integrityChecksBeforeLabels": integrity_checks,
        "semanticChecksBeforeLabels": semantic_checks,
        "semanticCheckFailuresRemainOperatorVisibleHolds": [
            key for key, value in semantic_checks.items() if not value
        ],
        "allRequiredSemanticChecksPassedBeforeLabelRead": semantic_checks_pass,
        "evaluationMayReadScorerLabelOnlyAfterRehashingFrozenPopulation": evaluation_authorized,
        "operatorVisualReviewRequired": True,
        "packageBuilt": False,
        "packageAttemptCount": 0,
        "reviewOnly": True,
        "productionEligible": False,
    }
    gate_asset = write_json_new(output / "INFERENCE_GATE.json", gate)
    print(
        json.dumps(
            {
                "state": gate["state"],
                "summaryPath": summary_asset["path"],
                "summarySha256": summary_asset["sha256"],
                "populationPath": population_asset["path"],
                "populationSha256": population_asset["sha256"],
                "freezePath": freeze_asset["path"],
                "freezeSha256": freeze_asset["sha256"],
                "gatePath": gate_asset["path"],
                "gateSha256": gate_asset["sha256"],
            },
            separators=(",", ":"),
        )
    )
    return 0


def verify_record_tree_before_label(*documents: dict[str, Any]) -> dict[str, Any]:
    records: dict[str, dict[str, Any]] = {}
    pointers: dict[str, list[str]] = {}
    for document_index, document in enumerate(documents):
        for pointer, record in iter_hash_records(document, f"$document[{document_index}]"):
            path = Path(str(record["path"]))
            key = str(path.absolute()).lower()
            expected = str(record["sha256"]).upper()
            size = int(record["bytes"]) if record.get("bytes") is not None else None
            if key in records:
                need(records[key]["sha256"] == expected, f"Frozen record hash conflict: {path}")
                if size is not None and records[key].get("bytes") is not None:
                    need(int(records[key]["bytes"]) == size, f"Frozen record size conflict: {path}")
                pointers[key].append(pointer)
                continue
            require_exact_file(path, expected, f"frozen pre-label record {pointer}", size)
            records[key] = {
                "path": str(path),
                "bytes": path.stat().st_size,
                "sha256": expected,
            }
            pointers[key] = [pointer]
    return {
        "uniqueFileCount": len(records),
        "records": sorted(records.values(), key=lambda row: row["path"].lower()),
        "allExactBeforeScorerLabelParse": True,
    }


def scorer_label_identity_angle(payload: dict[str, Any], identities: set[str]) -> tuple[str, float]:
    need(
        payload.get("schema") == "argos_ocv03_post2_scorer_only_labels_v1"
        and payload.get("state") == "FROZEN_POST_INFERENCE_SCORER_ONLY"
        and bool(payload.get("reviewOnly")),
        "Scorer-label schema, state, or authority differs",
    )
    for key in (
        "detectorInputAllowed",
        "thresholdSourceAllowed",
        "candidateFilterAllowed",
        "tieBreakerAllowed",
        "trainingEligible",
        "xmlEligible",
        "productionEligible",
    ):
        need(not bool(payload.get(key)), f"Scorer-label authority forbids {key}")
    members = payload.get("members")
    need(isinstance(members, list), "Scorer-label members are missing")
    labeled = [
        member for member in members
        if isinstance(member, dict) and "knownChipoutAngleDegreesImage" in member
    ]
    need(len(labeled) == 1, "Scorer labels do not contain exactly one chipout member")
    identity = str(labeled[0].get("identity"))
    need(identity in identities, "Scorer-label identity lies outside the frozen POST2 population")
    angle = float(labeled[0]["knownChipoutAngleDegreesImage"])
    need(math.isfinite(angle), "Scorer-label angle is not finite")
    return identity, angle


def native_cyclic_crop(image: np.ndarray, center_degrees: float, width: int) -> tuple[np.ndarray, np.ndarray]:
    center = int(round((center_degrees % 360.0) * width / 360.0)) % width
    relative = np.arange(
        -CANDIDATE_REVIEW_HALF_WIDTH_COLUMNS,
        CANDIDATE_REVIEW_HALF_WIDTH_COLUMNS + 1,
        dtype=np.int64,
    )
    columns = (center + relative) % width
    return image[:, columns].copy(), columns


def run_evaluation(args: argparse.Namespace) -> int:
    need(args.scorer_labels_sha256.upper() == SCORER_LABELS_SHA256, "Scorer-label pin differs from R27")
    output = Path(args.output_root)
    expected_output = EXPECTED_INFERENCE_ROOT / "evaluation"
    need(
        output.is_absolute()
        and output.drive.upper() == "C:"
        and same_windows_path(output, expected_output)
        and not output.exists()
        and len(str(output)) + 128 < 200,
        "R27 evaluation output must be a fresh short C: child/root",
    )
    need(args.engine_sha256.upper() == sha256_file(Path(__file__).resolve()), "R27 source changed after inference freeze")
    need(
        directory_is_ntfs_compressed(EXPECTED_INFERENCE_ROOT),
        "Frozen R27 inference root lost its verified NTFS compressed attribute",
    )
    summary_path = Path(args.inference_summary)
    gate_path = Path(args.inference_gate)
    population_path = Path(args.neutral_population)
    freeze_path = Path(args.freeze_manifest)
    need(same_windows_path(summary_path.parent, EXPECTED_INFERENCE_ROOT), "Inference summary root differs")
    need(same_windows_path(gate_path.parent, EXPECTED_INFERENCE_ROOT), "Inference gate root differs")
    need(
        same_windows_path(population_path.parent, EXPECTED_INFERENCE_ROOT / "neutral")
        and same_windows_path(freeze_path.parent, EXPECTED_INFERENCE_ROOT / "neutral"),
        "Frozen neutral root differs",
    )
    summary = load_json_pinned(summary_path, args.inference_summary_sha256, "R27 inference summary")
    gate = load_json_pinned(gate_path, args.inference_gate_sha256, "R27 inference gate")
    population = load_json_pinned(population_path, args.neutral_population_sha256, "R27 neutral population")
    freeze = load_json_pinned(freeze_path, args.freeze_manifest_sha256, "R27 freeze manifest")
    need(
        summary.get("schema") == SUMMARY_SCHEMA
        and summary.get("state") == "COMPLETE_DIAGNOSTIC_ONLY_R27_NEUTRAL_POPULATION_FROZEN"
        and summary.get("scorerLabelJsonParsed") is False
        and summary.get("candidatePopulationFrozenBeforeScorerLabelParse") is True,
        "R27 inference summary is not a clean pre-label freeze",
    )
    need(
        gate.get("schema") == GATE_SCHEMA
        and frozen_prelabel_gate_maps_valid(summary, gate, population),
        "R27 inference integrity gate does not authorize post-freeze evaluation",
    )
    need(
        population.get("schema") == POPULATION_SCHEMA
        and population.get("state")
        == "FROZEN_NEUTRAL_CANDIDATE_POPULATION_PENDING_POST_LABEL_EVALUATION"
        and population.get("scorerLabelJsonParsed") is False
        and population.get("candidatePopulationFrozenBeforeScorerLabelParse") is True,
        "R27 neutral population was not frozen before label evaluation",
    )
    need(
        freeze.get("schema") == FREEZE_SCHEMA
        and freeze.get("state") == "PASS_R27_COMPLETE_NEUTRAL_POPULATION_FILESET_FROZEN"
        and freeze.get("allGeneratedFilesHashed") is True
        and freeze.get("externalSourceAndDependencyRecordsRemainPinnedInPopulationAndSummary")
        is True
        and freeze.get("scorerLabelJsonParsed") is False
        and freeze.get("postFreezeWritesRestrictedToSummaryGateAndFreshEvaluationChild")
        is True
        and isinstance(freeze.get("generatedFiles"), list)
        and int(freeze.get("generatedFileCountBeforeFreezeManifest", -1))
        == len(freeze.get("generatedFiles", [])),
        "R27 freeze manifest is not PASS",
    )
    need(
        exact_embedded_file_record(
            gate.get("summary"), summary_path, args.inference_summary_sha256
        )
        and exact_embedded_file_record(
            gate.get("neutralPopulation"),
            population_path,
            args.neutral_population_sha256,
        )
        and exact_embedded_file_record(
            gate.get("freezeManifest"), freeze_path, args.freeze_manifest_sha256
        )
        and exact_embedded_file_record(
            summary.get("neutralPopulation"),
            population_path,
            args.neutral_population_sha256,
        )
        and exact_embedded_file_record(
            summary.get("freezeManifest"), freeze_path, args.freeze_manifest_sha256
        )
        and exact_embedded_file_record(
            freeze.get("population"),
            population_path,
            args.neutral_population_sha256,
        ),
        "R27 frozen documents do not cross-bind exact path, bytes, and hash",
    )

    neutral_root = population_path.parent
    actual_pre_freeze = [
        row for row in generated_inventory(neutral_root)
        if Path(row["path"]).resolve() != freeze_path.resolve()
    ]
    expected_pre_freeze = freeze.get("generatedFiles", [])
    need(actual_pre_freeze == expected_pre_freeze, "Neutral generated file inventory changed after freeze")
    rehash = verify_record_tree_before_label(summary, gate, population, freeze)
    current_lineage = verify_engine_lineage()
    need(current_lineage == summary.get("loadedDependencies"), "Loaded dependency lineage changed after freeze")
    need(
        sha256_file(Path(__file__).resolve()) == args.engine_sha256.upper(),
        "R27 source changed during frozen-population rehash",
    )

    # No scorer-label JSON is opened above this line.  The entire neutral
    # population, all nested assets/sources/dependencies, summary, and gate are
    # exact at this point.
    identities = {str(row["identity"]) for row in population["post2"]}
    need(len(identities) == 3, "Frozen POST2 identity cardinality changed")
    preflight_output_layout(output, identities, evaluation=True)
    all_existing_holds_retained = bool(
        population.get("semanticChecksBeforeLabels", {}).get("allPredecessorHoldsRetained")
        and population.get("hotspotRegression", {}).get("allExistingContourHoldsRetained")
        and all(
            row["pairDiagnostic"].get("inheritedR22OwnershipHoldsRetained")
            and row["pairDiagnostic"].get("resolvedPairCount") == 0
            for row in population["post2"]
        )
    )
    need(all_existing_holds_retained, "Frozen predecessor holds are not mechanically retained")
    labels_path = Path(args.scorer_labels)
    labels = load_json_pinned(labels_path, args.scorer_labels_sha256, "scorer-only labels")
    labeled_identity, chipout_angle = scorer_label_identity_angle(labels, identities)
    chipout_as_notch_rows: list[dict[str, Any]] = []
    for result in population["post2"]:
        if str(result["identity"]) != labeled_identity:
            continue
        for channel in ("BF", "DF"):
            for candidate in result["channels"][channel]["candidates"]:
                start = float(candidate["startAngleDegrees"]) % 360.0
                width_degrees = min(
                    max(float(candidate["widthDegrees"]), 0.0), 360.0
                )
                scorer_inside_interval = bool(
                    ((chipout_angle % 360.0) - start) % 360.0
                    <= width_degrees + 1.0e-9
                )
                if (
                    scorer_inside_interval
                    and bool(candidate.get("diagnosticPairingEligible"))
                ):
                    chipout_as_notch_rows.append(
                        {
                            "channel": channel,
                            "candidateId": candidate["candidateId"],
                            "classification": candidate["classification"],
                            "startAngleDegrees": float(candidate["startAngleDegrees"]),
                            "endAngleDegrees": float(candidate["endAngleDegrees"]),
                            "widthDegrees": width_degrees,
                        }
                    )
    chipout_as_notch_count = len(chipout_as_notch_rows)

    output.mkdir()
    need(directory_is_ntfs_compressed(output), "R27 evaluation child did not inherit NTFS compression")
    evaluation_storage = {
        "state": "PASS_R27_EVALUATION_CHILD_INHERITED_NTFS_COMPRESSION",
        "root": str(output),
        "directoryCompressedAttributeVerifiedBeforeChildWrites": True,
        "logicalFileBytesAndSha256UnaffectedByFilesystemCompression": True,
        "jsonEncoding": "UTF8_COMPACT_SORTED_KEYS_STREAMED_FINAL_LF",
    }
    cases_root = output / "cases"
    cases_root.mkdir()
    review_rows: list[dict[str, Any]] = []
    panel_rows: list[list[np.ndarray]] = []
    for result in population["post2"]:
        identity = str(result["identity"])
        case_root = cases_root / f"P{int(result['ordinal']):04d}"
        case_root.mkdir()
        panels: list[np.ndarray] = []
        channels: dict[str, Any] = {}
        for channel in ("BF", "DF"):
            frozen_channel = result["channels"][channel]
            clean_record = frozen_channel["assets"]["fullClean"]
            review_record = frozen_channel["assets"]["allCandidateContourReview"]
            clean = cv2.imread(str(clean_record["path"]), cv2.IMREAD_GRAYSCALE)
            review = cv2.imread(str(review_record["path"]), cv2.IMREAD_COLOR)
            need(clean is not None and review is not None and clean.shape == review.shape[:2], f"{identity} {channel} frozen review decode failed")
            clean_crop, columns = native_cyclic_crop(clean, chipout_angle, clean.shape[1])
            review_crop, review_columns = native_cyclic_crop(review, chipout_angle, review.shape[1])
            need(bool(np.array_equal(columns, review_columns)), "Evaluation crop columns differ")
            candidate_comparisons = [
                {
                    "candidateId": candidate["candidateId"],
                    "classification": candidate["classification"],
                    "centerAngleDegrees": candidate["centerAngleDegrees"],
                    "distanceFromPostFreezeScorerAngleDegrees": circular_distance_degrees(
                        float(candidate["centerAngleDegrees"]), chipout_angle
                    ),
                    "manufacturedCompatibleAfterContour": bool(
                        candidate.get("manufacturedCompatibleAfterContour")
                    ),
                    "diagnosticPairingEligible": bool(
                        candidate.get("diagnosticPairingEligible")
                    ),
                    "notchOwnershipGranted": bool(
                        candidate.get("notchOwnershipGranted")
                    ),
                }
                for candidate in frozen_channel["candidates"]
            ]
            stem = safe_stem(identity) + "_" + channel.lower() + "_postfreeze_chipout"
            label = (
                f"{identity} {channel} | POST-FREEZE scorer angle {chipout_angle:.6f} deg | "
                "CYAN fixed outer | YELLOW -20px | LIME native brightness | "
                "ORANGE native graph | RED diagnostic notch-shaped trace, unowned | MAGENTA hold"
            )
            labeled = labeled_native_crop(review_crop, label)
            assets = {
                "cleanNativeAnnularCrop": write_png_new(case_root / f"{stem}_clean.png", clean_crop),
                "reviewNativeAnnularCrop": write_png_new(case_root / f"{stem}_review.png", labeled),
            }
            channels[channel] = {
                "sourceColumnStart": int(columns[0]),
                "sourceColumnEnd": int(columns[-1]),
                "sourceColumnCount": int(columns.size),
                "cyclicWrapUsed": bool(columns[0] > columns[-1]),
                "nativeRadialPitchPx": 1.0,
                "resamplingPerformed": False,
                "pathCenteredWarpPerformed": False,
                "candidateComparisons": candidate_comparisons,
                "assets": assets,
            }
            panels.append(labeled)
        panel_rows.append(panels)
        review_rows.append(
            {
                "ordinal": int(result["ordinal"]),
                "identity": identity,
                "scorerRole": "POSITIVE_LABELED_MEMBER" if identity == labeled_identity else "SAME_ANGLE_CONTROL",
                "channels": channels,
            }
        )
    sheet = cv2.vconcat([cv2.hconcat(row) for row in panel_rows])
    sheet_asset = write_png_new(output / "POST2_R27_POSTFREEZE_SAME_ANGLE_NATIVE_COMPARISON.png", sheet)
    evaluation_state = (
        "HOLD_R27_POSTFREEZE_OPERATOR_VISUAL_REVIEW_REQUIRED"
        if chipout_as_notch_count == 0
        else "HOLD_R27_CHIPOUT_CLASSIFIED_AS_DIAGNOSTIC_NOTCH"
    )
    evaluation = {
        "schema": EVALUATION_SCHEMA,
        "state": evaluation_state,
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "engine": file_record(Path(__file__).resolve(), args.engine_sha256),
        "inferenceSummary": file_record(summary_path, args.inference_summary_sha256),
        "inferenceGate": file_record(gate_path, args.inference_gate_sha256),
        "neutralPopulation": file_record(population_path, args.neutral_population_sha256),
        "freezeManifest": file_record(freeze_path, args.freeze_manifest_sha256),
        "completeFrozenRecordRehashBeforeLabelParse": rehash,
        "outputStorage": evaluation_storage,
        "scorerLabels": file_record(labels_path, args.scorer_labels_sha256),
        "labeledPositiveIdentity": labeled_identity,
        "postFreezeScorerAngleDegrees": chipout_angle,
        "comparisonRole": "SLOT01_LARGE_FRONTSIDE_CHIPOUT_VERSUS_SLOT03_SLOT17_SAME_ANGLE_CONTROLS",
        "channelRoles": {"DF": "DETECTION_EVIDENCE", "BF": "CORROBORATING_EVIDENCE_ONLY"},
        "results": review_rows,
        "chipoutAsDiagnosticNotchCount": chipout_as_notch_count,
        "chipoutAsDiagnosticNotchRows": chipout_as_notch_rows,
        "chipoutAsNotchSelectionCount": 0,
        "comparisonSheet": sheet_asset,
        "reviewAngleConsumedByInference": False,
        "chipoutSelectionPerformed": False,
        "chipoutThresholdTuningPerformed": False,
        "candidateFilteringFromChipoutTruthPerformed": False,
        "developmentCohortLabelPreviouslyExposed": True,
        "blindReliabilityEvidence": False,
        "crossChannelPixelCoordinateTransferPerformed": False,
        "sourceMutationPerformed": False,
        "existingTaskOrProcessActionPerformed": False,
        "providerActivated": False,
        "holdClearancePerformed": False,
        "packageBuilt": False,
        "packageAttemptCount": 0,
        "operatorVisualReviewRequired": True,
        "reviewOnly": True,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "productionRoutingEnabled": False,
    }
    evaluation_asset = write_json_new(output / "SUMMARY.json", evaluation)
    gate_payload = {
        "schema": "argos_ocv03_annular_candidate_first_r27_post_label_evaluation_gate_v1",
        "state": (
            "HOLD_R27_OPERATOR_VISUAL_REVIEW_READY_NO_PACKAGE"
            if chipout_as_notch_count == 0
            else "HOLD_R27_CHIPOUT_CLASSIFIED_AS_DIAGNOSTIC_NOTCH"
        ),
        "summary": evaluation_asset,
        "comparisonSheet": sheet_asset,
        "allFrozenBytesRehashedBeforeLabelParse": True,
        "evaluationChildNtfsCompressionEnabledBeforeWrites": bool(
            evaluation_storage["directoryCompressedAttributeVerifiedBeforeChildWrites"]
        ),
        "threePost2PairsRenderedAtSamePostFreezeAngle": len(review_rows) == 3,
        "allSixNativeCropsRenderedWithoutResampling": all(
            not row["channels"][channel]["resamplingPerformed"]
            for row in review_rows for channel in ("BF", "DF")
        ),
        "candidateSelectionOrTuningFromScorerLabelPerformed": False,
        "chipoutAsDiagnosticNotchCountZero": chipout_as_notch_count == 0,
        "chipoutAsNotchSelectionCount": 0,
        "allExistingHoldsRetained": all_existing_holds_retained,
        "operatorVisualReviewRequired": True,
        "packageBuilt": False,
        "packageAttemptCount": 0,
        "reviewOnly": True,
        "productionEligible": False,
    }
    evaluation_gate_asset = write_json_new(output / "REVIEW_GATE.json", gate_payload)
    print(
        json.dumps(
            {
                "state": gate_payload["state"],
                "comparisonPath": sheet_asset["path"],
                "comparisonSha256": sheet_asset["sha256"],
                "summaryPath": evaluation_asset["path"],
                "summarySha256": evaluation_asset["sha256"],
                "gatePath": evaluation_gate_asset["path"],
                "gateSha256": evaluation_gate_asset["sha256"],
            },
            separators=(",", ":"),
        )
    )
    return 0


def run_self_check() -> int:
    source = Path(__file__).read_text(encoding="utf-8")
    need(
        CAPACITY_PROJECTED_R27_MAXIMUM_OUTPUT_BYTES
        == EXPECTED_MAXIMUM_LOGICAL_OUTPUT_BYTES
        and CAPACITY_OBSERVED_R26_INTERRUPTION_BASIN_COUNT
        < CAPACITY_OBSERVED_R25_TRACE_COUNT
        and MINIMUM_OUTPUT_FREE_BYTES
        == EXPECTED_MAXIMUM_LOGICAL_OUTPUT_BYTES + OUTPUT_SAFETY_RESERVE_BYTES,
        "R27 file-backed output-footprint allowance and reserve do not close",
    )
    json_probe = {"z": [1, {"b": False, "a": "native"}], "a": None}
    json_probe_encoder = json.JSONEncoder(
        sort_keys=True,
        allow_nan=False,
        ensure_ascii=True,
        separators=(",", ":"),
    )
    need(
        "".join(json_probe_encoder.iterencode(json_probe)) + "\n"
        == json.dumps(
            json_probe,
            sort_keys=True,
            allow_nan=False,
            ensure_ascii=True,
            separators=(",", ":"),
        ) + "\n",
        "R27 streamed compact JSON encoding differs from its exact logical byte contract",
    )
    semantic_probe = {key: True for key in INFERENCE_SEMANTIC_CHECK_KEYS}
    integrity_probe = {key: True for key in INFERENCE_INTEGRITY_CHECK_KEYS}
    summary_probe = {
        "semanticChecksBeforeLabels": dict(semantic_probe),
        "integrityChecksBeforeLabels": dict(integrity_probe),
    }
    population_probe = {
        "semanticChecksBeforeLabels": dict(semantic_probe),
        "integrityChecksBeforeLabels": dict(integrity_probe),
    }
    gate_probe = {
        "state": "PASS_R27_NEUTRAL_POPULATION_FROZEN_WITH_SEMANTIC_HOLDS_RETAINED",
        "semanticChecksBeforeLabels": dict(semantic_probe),
        "integrityChecksBeforeLabels": dict(integrity_probe),
        "semanticCheckFailuresRemainOperatorVisibleHolds": [],
        "allRequiredSemanticChecksPassedBeforeLabelRead": True,
        "evaluationMayReadScorerLabelOnlyAfterRehashingFrozenPopulation": True,
    }
    need(
        frozen_prelabel_gate_maps_valid(summary_probe, gate_probe, population_probe),
        "R27 exact frozen pre-label map contract rejects its complete true maps",
    )
    truncated_gate_probe = dict(gate_probe)
    truncated_gate_probe["semanticChecksBeforeLabels"] = {}
    nonboolean_gate_probe = dict(gate_probe)
    nonboolean_semantic_probe = dict(semantic_probe)
    nonboolean_semantic_probe[next(iter(sorted(nonboolean_semantic_probe)))] = 1
    nonboolean_gate_probe["semanticChecksBeforeLabels"] = nonboolean_semantic_probe
    extra_gate_probe = dict(gate_probe)
    extra_semantic_probe = dict(semantic_probe)
    extra_semantic_probe["unexpectedFailOpenKey"] = True
    extra_gate_probe["semanticChecksBeforeLabels"] = extra_semantic_probe
    mismatched_population_probe = dict(population_probe)
    mismatched_semantic_probe = dict(semantic_probe)
    mismatched_semantic_probe[next(iter(sorted(mismatched_semantic_probe)))] = False
    mismatched_population_probe["semanticChecksBeforeLabels"] = mismatched_semantic_probe
    truncated_integrity_gate_probe = dict(gate_probe)
    truncated_integrity_gate_probe["integrityChecksBeforeLabels"] = {}
    mismatched_integrity_population_probe = dict(population_probe)
    mismatched_integrity_probe = dict(integrity_probe)
    mismatched_integrity_probe[next(iter(sorted(mismatched_integrity_probe)))] = False
    mismatched_integrity_population_probe[
        "integrityChecksBeforeLabels"
    ] = mismatched_integrity_probe
    need(
        not frozen_prelabel_gate_maps_valid(
            summary_probe, truncated_gate_probe, population_probe
        )
        and not frozen_prelabel_gate_maps_valid(
            summary_probe, nonboolean_gate_probe, population_probe
        )
        and not frozen_prelabel_gate_maps_valid(
            summary_probe, extra_gate_probe, population_probe
        )
        and not frozen_prelabel_gate_maps_valid(
            summary_probe, gate_probe, mismatched_population_probe
        )
        and not frozen_prelabel_gate_maps_valid(
            summary_probe, truncated_integrity_gate_probe, population_probe
        )
        and not frozen_prelabel_gate_maps_valid(
            summary_probe, gate_probe, mismatched_integrity_population_probe
        ),
        "R27 frozen pre-label map contract accepted an empty, non-Boolean, extra, truncated, or mismatched map",
    )
    for forbidden in (
        "cyclic_" + "open_1d(",
        "close_small_" + "circular_gaps(",
        "cv2." + "morphologyEx(",
        "cv2." + "INTER_LINEAR",
        "cv2." + "INTER_CUBIC",
    ):
        need(forbidden not in source, f"Forbidden R27 candidate operation is present: {forbidden}")
    need(
        "r6_tie_" + "break = True" not in source
        and "resolved = " + "corroborated" not in source,
        "R6 is able to select among multiple post-contour candidates",
    )
    need("--scorer-labels" not in source.split("def run_inference", 1)[1].split("def run_evaluation", 1)[0], "Inference implementation exposes scorer labels")
    require_exact_file(
        PROJECT_ROOT / "work" / "FRONTSIDE_INSPECTION_REVIEW_ONLY"
        / "OCV03_O3F16R23_R24_ROLLOVER_20260904.md",
        CHECKPOINT_SHA256,
        "R24 checkpoint",
    )
    require_exact_file(PROJECT_ROOT / "work" / "O3F16R23_ROLLOVER.json", ROLLOVER_MANIFEST_SHA256, "R24 rollover manifest")
    require_exact_file(PROJECT_ROOT / "work" / "O3F16R23_ROLLOVER_GATE.json", ROLLOVER_GATE_SHA256, "R24 rollover gate")
    verify_engine_lineage()
    inherited = load_r22_inherited_post2_authority()
    need(
        inherited["r22OwnershipHoldCount"] == 6
        and inherited["r22CyanHoldCount"] == 5
        and inherited["r23JsonParsedBeforeNeutralFreeze"] is False,
        "Inherited R22/R23 hold contract differs",
    )

    width = 101
    search_offsets = np.arange(-50, 11, dtype=np.float32)
    strip = np.zeros((search_offsets.size, width), dtype=np.uint8)
    support = np.zeros((search_offsets.size, width), dtype=bool)
    raw = np.zeros_like(support, dtype=np.float32)
    enhanced = np.zeros_like(support, dtype=np.float32)
    outer = np.zeros(width, dtype=np.float32)
    normal = np.full(width, -20.0, dtype=np.float32)
    normal_observed = np.ones(width, dtype=bool)
    deep = np.full(width, -20.0, dtype=np.float32)
    component = np.arange(40, 61, dtype=np.int64)
    core = np.arange(48, 53, dtype=np.int64)
    curve: dict[int, float] = {}
    for column in range(39, 62):
        depth = 20.0 + max(0.0, 15.0 - 1.5 * abs(column - 50))
        curve[column] = -depth
        deep[column] = -depth
    for column in range(width):
        value = curve.get(column, -20.0)
        row = int(np.argmin(np.abs(search_offsets - value)))
        support[row, column] = True
        raw[row, column] = 12.0
        enhanced[row, column] = 24.0
        image_row = int(round(float(search_offsets[row] - search_offsets[0])))
        strip[: image_row + 1, column] = 180
        strip[image_row + 1 :, column] = 20
    normal_observed[component] = False
    transition = {
        "searchOffsets": search_offsets,
        "frontierSupported": support,
        "nativeSupported": support,
        "rawContrast": raw,
        "directRawContrast": raw,
        "enhancedContrast": enhanced,
    }
    params = argparse.Namespace(
        manufactured_maximum_width_degrees=90.0,
        manufactured_minimum_width_degrees=1.0,
        manufactured_maximum_tip_offset_fraction=0.7,
        manufactured_minimum_slope_consistency=0.55,
        manufactured_minimum_symmetry=0.5,
        candidate_match_tolerance_degrees=0.8,
        manufactured_minimum_cross_channel_overlap=0.1,
        maximum_channel_center_difference_px=10.0,
        maximum_channel_radius_difference_px=32.0,
    )
    synthetic_discovery = discover_raw_candidate_components(
        transition,
        normal_observed,
        np.zeros(width, dtype=bool),
        outer,
        {"minimumNotchDepthPx": 20.0, "noiseSigmaThreshold": 4.5},
    )
    need(len(synthetic_discovery["components"]) == 1, "Synthetic 2-D discovery did not retain one candidate")
    trace = candidate_graph_trace(
        strip,
        search_offsets,
        outer,
        normal,
        normal_observed,
        transition,
        synthetic_discovery["components"][0],
        float(synthetic_discovery["thresholdPx"]),
        params,
        0,
        "BF",
        np.zeros(width, dtype=bool),
        np.zeros(width, dtype=bool),
    )
    need(trace["record"].get("completeNativeShoulderPath"), "Synthetic native graph did not reach both shoulders")
    need(trace["record"].get("allSelectedPixelsNativeSupported"), "Synthetic trace selected unsupported coordinates")
    need(not trace["record"].get("interpolationPerformed"), "Synthetic trace interpolated coordinates")
    need(
        trace["record"].get("coherentCoarseBandRouteCountSaturated") == 1
        and trace["record"].get("coherentCoreCorridorSignatureCountSaturated") == 1
        and trace["record"].get("uniqueCoherentNativeCoreCorridorSignature")
        and trace["record"].get("allStrictCoreSeedsShareUniqueCoherentBandCorridor")
        and trace["record"].get("diagnosticPairingEligible"),
        "Synthetic single native corridor is not one diagnostic-eligible coarse-band route",
    )

    # Row thickness creates many row-level paths but remains exactly one coarse
    # physical branch; row permutations may not create a false ambiguity hold.
    thick_support = support.copy()
    thick_raw = raw.copy()
    thick_enhanced = enhanced.copy()
    for column in range(width):
        primary_row = int(np.flatnonzero(support[:, column])[0])
        thick_support[primary_row + 1, column] = True
        thick_raw[primary_row + 1, column] = 12.0
        thick_enhanced[primary_row + 1, column] = 24.0
    thick_transition = dict(transition)
    thick_transition["frontierSupported"] = thick_support
    thick_transition["nativeSupported"] = thick_support
    thick_transition["rawContrast"] = thick_raw
    thick_transition["directRawContrast"] = thick_raw
    thick_transition["enhancedContrast"] = thick_enhanced
    thick_discovery = discover_raw_candidate_components(
        thick_transition,
        normal_observed,
        np.zeros(width, dtype=bool),
        outer,
        {"minimumNotchDepthPx": 20.0, "noiseSigmaThreshold": 4.5},
    )
    need(len(thick_discovery["components"]) == 1, "Synthetic thick edge discovery changed candidate count")
    thick_trace = candidate_graph_trace(
        strip,
        search_offsets,
        outer,
        normal,
        normal_observed,
        thick_transition,
        thick_discovery["components"][0],
        float(thick_discovery["thresholdPx"]),
        params,
        0,
        "BF",
        np.zeros(width, dtype=bool),
        np.zeros(width, dtype=bool),
    )
    need(
        thick_trace["record"].get("reachableShoulderPathCountSaturated", 0) > 1
        and thick_trace["record"].get("coherentCoarseBandRouteCountSaturated") == 1
        and thick_trace["record"].get("coherentCoreCorridorSignatureCountSaturated") == 1
        and thick_trace["record"].get("diagnosticPairingEligible")
        and "AMBIGUOUS_MULTIPLE_COHERENT_STRICT_CORE_CORRIDOR_SIGNATURES"
        not in thick_trace["record"].get("postContourMorphologyReasons", []),
        "Synthetic native row thickness was mistaken for multiple physical branches",
    )

    # A brighter parallel radial band may remain visible as native evidence,
    # but it cannot pull the representative trace away from the more
    # continuous shoulder-to-shoulder branch.  Brightness ranks only after the
    # avoidable-switch and native-travel terms.
    parallel_support = support.copy()
    parallel_raw = raw.copy()
    parallel_direct = raw.copy()
    parallel_enhanced = enhanced.copy()
    support_only_row = int(np.argmin(np.abs(search_offsets - (-18.0))))
    for column in range(42, 59):
        alternate_row = support_only_row
        parallel_support[alternate_row, column] = True
        parallel_raw[alternate_row, column] = 80.0
        parallel_direct[alternate_row, column] = 100.0
        parallel_enhanced[alternate_row, column] = 160.0
    parallel_transition = dict(transition)
    parallel_transition["frontierSupported"] = parallel_support
    parallel_transition["nativeSupported"] = parallel_support
    parallel_transition["rawContrast"] = parallel_raw
    parallel_transition["directRawContrast"] = parallel_direct
    parallel_transition["enhancedContrast"] = parallel_enhanced
    parallel_discovery = discover_raw_candidate_components(
        parallel_transition,
        normal_observed,
        np.zeros(width, dtype=bool),
        outer,
        {"minimumNotchDepthPx": 20.0, "noiseSigmaThreshold": 4.5},
    )
    need(
        len(parallel_discovery["components"]) == 1,
        "Synthetic support-only parallel island changed strict-core candidate discovery",
    )
    parallel_trace = candidate_graph_trace(
        strip,
        search_offsets,
        outer,
        normal,
        normal_observed,
        parallel_transition,
        parallel_discovery["components"][0],
        float(parallel_discovery["thresholdPx"]),
        params,
        0,
        "BF",
        np.zeros(width, dtype=bool),
        np.zeros(width, dtype=bool),
    )
    need(
        parallel_trace["record"].get("completeNativeShoulderPath")
        and parallel_trace["record"].get("representativeParallelBandSwitchCount") == 0
        and parallel_trace["record"].get("coherentCoarseBandRouteCountSaturated") == 1
        and parallel_trace["record"].get("coherentCoreCorridorSignatureCountSaturated") == 1
        and parallel_trace["record"].get("parallelBandColumnCount", 0) > 0
        and [row["radialRow"] for row in parallel_trace["record"]["representativePath"]]
        == [row["radialRow"] for row in trace["record"]["representativePath"]],
        "Synthetic brighter parallel band stole or switched the continuous native branch",
    )
    need(
        "PARALLEL_NATIVE_BAND_BRANCH"
        not in parallel_trace["record"].get("postContourMorphologyReasons", []),
        "Synthetic unselected parallel evidence was treated as a notch-shape veto",
    )
    need(
        "AMBIGUOUS_MULTIPLE_COHERENT_STRICT_CORE_CORRIDOR_SIGNATURES"
        not in parallel_trace["record"].get("postContourMorphologyReasons", []),
        "Synthetic support-only island was mistaken for a second strict-core corridor",
    )

    # A true fork/rejoin with two sustained separated native corridors remains
    # explicit authority-held evidence even when one continuity-first
    # representative has a diagnostic manufactured-notch shape.
    fork_support = np.zeros_like(support)
    fork_raw = np.zeros_like(raw)
    fork_enhanced = np.zeros_like(enhanced)
    normal_row = int(np.argmin(np.abs(search_offsets - (-20.0))))
    fork_support[normal_row, :] = True
    fork_raw[normal_row, :] = 12.0
    fork_enhanced[normal_row, :] = 24.0
    trunk_offsets = {
        39: -20.0, 40: -22.0, 41: -24.0, 42: -26.0,
        43: -28.0, 44: -30.0, 45: -31.0, 55: -31.0,
        56: -30.0, 57: -28.0, 58: -26.0, 59: -24.0,
        60: -22.0, 61: -20.0,
    }
    for column, offset in trunk_offsets.items():
        fork_support[:, column] = False
        fork_raw[:, column] = 0.0
        fork_enhanced[:, column] = 0.0
        row = int(np.argmin(np.abs(search_offsets - offset)))
        fork_support[row, column] = True
        fork_raw[row, column] = 12.0
        fork_enhanced[row, column] = 24.0
    for column in range(46, 55):
        fork_support[:, column] = False
        fork_raw[:, column] = 0.0
        fork_enhanced[:, column] = 0.0
        deep_row = int(np.argmin(np.abs(search_offsets - (-34.0))))
        shallow_row = int(np.argmin(np.abs(search_offsets - (-28.0))))
        for row in (deep_row, shallow_row):
            fork_support[row, column] = True
            fork_raw[row, column] = 12.0
            fork_enhanced[row, column] = 24.0
    fork_transition = {
        "searchOffsets": search_offsets,
        "frontierSupported": fork_support,
        "nativeSupported": fork_support,
        "rawContrast": fork_raw,
        "directRawContrast": fork_raw,
        "enhancedContrast": fork_enhanced,
    }
    fork_discovery = discover_raw_candidate_components(
        fork_transition,
        normal_observed,
        np.zeros(width, dtype=bool),
        outer,
        {"minimumNotchDepthPx": 20.0, "noiseSigmaThreshold": 4.5},
    )
    need(len(fork_discovery["components"]) == 1, "Synthetic fork was not discovered once")
    fork_trace = candidate_graph_trace(
        strip,
        search_offsets,
        outer,
        normal,
        normal_observed,
        fork_transition,
        fork_discovery["components"][0],
        float(fork_discovery["thresholdPx"]),
        params,
        0,
        "BF",
        np.zeros(width, dtype=bool),
        np.zeros(width, dtype=bool),
    )
    need(
        fork_trace["record"].get("coherentCoarseBandRouteCountSaturated") == 2
        and fork_trace["record"].get("coherentCoreCorridorSignatureCountSaturated") == 2
        and not fork_trace["record"].get("uniqueCoherentNativeCoreCorridorSignature")
        and fork_trace["record"].get("strictCoreSeedCount") == 1
        and "SUSTAINED_MULTIPLE_STRICT_CORE_CORRIDORS_RETAINED_AS_AUTHORITY_HOLD"
        in fork_trace["record"].get("authorityHoldReasons", [])
        and fork_trace["record"].get("diagnosticPairingEligible")
        and fork_trace["record"].get("pairingEligible")
        and not fork_trace["record"].get(
            "candidateLocalAuthorityEligibleBeforeGlobalHold"
        )
        and not fork_trace["record"].get("notchOwnershipGranted"),
        "Synthetic two-corridor native fork lost its explicit authority hold",
    )

    # The single allowed missing angular sample stays absent.  It is not an
    # interpolation license and the path may not skip a compatible native
    # bridge merely because a two-column edge exists.
    one_gap_support = support.copy()
    one_gap_raw = raw.copy()
    one_gap_enhanced = enhanced.copy()
    one_gap_column = 43
    one_gap_support[:, one_gap_column] = False
    one_gap_raw[:, one_gap_column] = 0.0
    one_gap_enhanced[:, one_gap_column] = 0.0
    one_gap_transition = dict(transition)
    one_gap_transition["frontierSupported"] = one_gap_support
    one_gap_transition["nativeSupported"] = one_gap_support
    one_gap_transition["rawContrast"] = one_gap_raw
    one_gap_transition["directRawContrast"] = one_gap_raw
    one_gap_transition["enhancedContrast"] = one_gap_enhanced
    one_gap_discovery = discover_raw_candidate_components(
        one_gap_transition,
        normal_observed,
        np.zeros(width, dtype=bool),
        outer,
        {"minimumNotchDepthPx": 20.0, "noiseSigmaThreshold": 4.5},
    )
    need(len(one_gap_discovery["components"]) == 1, "Synthetic one-gap basin was not retained once")
    one_gap_seed_ids = set(
        one_gap_discovery["components"][0]["strictCoreSeedIds"]
    )
    one_gap_trace = candidate_graph_trace(
        strip,
        search_offsets,
        outer,
        normal,
        normal_observed,
        one_gap_transition,
        one_gap_discovery["components"][0],
        float(one_gap_discovery["thresholdPx"]),
        params,
        0,
        "BF",
        np.zeros(width, dtype=bool),
        np.zeros(width, dtype=bool),
    )
    need(
        one_gap_trace["record"].get("boundedGapNativeShoulderPath")
        and not one_gap_trace["record"].get("gapFreeNativeShoulderPath")
        and one_gap_trace["record"].get("maximumContiguousUnsupportedRun") == 1
        and one_gap_trace["record"].get("unsupportedColumnIndices") == [one_gap_column]
        and one_gap_trace["record"].get("syntheticCoordinateCount") == 0
        and one_gap_column
        not in [row["column"] for row in one_gap_trace["record"]["representativePath"]],
        "Synthetic one-column gap was filled, skipped incorrectly, or not retained as absent",
    )
    one_gap_path = one_gap_trace["record"]["representativePath"]
    one_gap_positions = np.asarray(
        [int(row["column"]) - int(one_gap_trace["span"][0]) for row in one_gap_path],
        dtype=np.float64,
    )
    one_gap_depths = np.asarray(
        [float(-row["offsetPx"]) for row in one_gap_path], dtype=np.float64
    )
    expected_first_slopes = np.diff(one_gap_depths) / np.diff(one_gap_positions)
    need(
        one_gap_trace["record"].get("diagnosticPairingEligible")
        and one_gap_discovery.get("strictCoreComponentCount") == 2
        and len(one_gap_seed_ids) == 2
        and one_gap_trace["record"].get("strictCoreSeedCount") == 2
        and one_gap_trace["record"].get("coherentCoreCorridorSignatureCountSaturated") == 1
        and set(
            one_gap_trace["record"].get(
                "strictCoreSeedIdsInUniqueCoherentCorridorSignature", []
            )
        )
        == one_gap_seed_ids
        and set(
            one_gap_trace["record"].get(
                "strictCoreSeedIdsOnRepresentativePhysicalCorridor", []
            )
        )
        == one_gap_seed_ids
        and one_gap_trace["record"].get(
            "allStrictCoreSeedsShareUniqueCoherentBandCorridor"
        )
        and math.isclose(
            float(one_gap_trace["record"]["firstDifferenceAbsoluteP90Px"]),
            float(np.percentile(np.abs(expected_first_slopes), 90.0)),
            rel_tol=0.0,
            abs_tol=1.0e-12,
        )
        and one_gap_trace["record"].get("firstDifferencePopulation")
        == "DEPTH_SLOPE_PER_EXACT_NATIVE_ANGULAR_SAMPLE_DELTA_NO_FILL",
        "Synthetic one-column allowance is illusory or its shape metrics ignore native positions",
    )
    need(
        candidate_metric_schema_valid(one_gap_trace["record"]),
        "Synthetic one-column native gap does not pass the exact production candidate schema",
    )

    # Two native apexes are retained as physical evidence but are not a
    # manufactured-notch proposal.
    irregular_support = support.copy()
    irregular_raw = raw.copy()
    irregular_enhanced = enhanced.copy()
    for column in range(39, 62):
        irregular_support[:, column] = False
        irregular_raw[:, column] = 0.0
        irregular_enhanced[:, column] = 0.0
        first_peak = max(0.0, 15.0 - 2.5 * abs(column - 44))
        second_peak = max(0.0, 15.0 - 2.5 * abs(column - 56))
        depth = 20.0 + max(first_peak, second_peak)
        row = int(np.argmin(np.abs(search_offsets - (-depth))))
        irregular_support[row, column] = True
        irregular_raw[row, column] = 12.0
        irregular_enhanced[row, column] = 24.0
    irregular_transition = dict(transition)
    irregular_transition["frontierSupported"] = irregular_support
    irregular_transition["nativeSupported"] = irregular_support
    irregular_transition["rawContrast"] = irregular_raw
    irregular_transition["directRawContrast"] = irregular_raw
    irregular_transition["enhancedContrast"] = irregular_enhanced
    irregular_discovery = discover_raw_candidate_components(
        irregular_transition,
        normal_observed,
        np.zeros(width, dtype=bool),
        outer,
        {"minimumNotchDepthPx": 20.0, "noiseSigmaThreshold": 4.5},
    )
    need(len(irregular_discovery["components"]) == 1, "Synthetic two-apex response was not retained once")
    irregular_trace = candidate_graph_trace(
        strip,
        search_offsets,
        outer,
        normal,
        normal_observed,
        irregular_transition,
        irregular_discovery["components"][0],
        float(irregular_discovery["thresholdPx"]),
        params,
        1,
        "BF",
        np.zeros(width, dtype=bool),
        np.zeros(width, dtype=bool),
    )
    need(
        irregular_trace["record"].get("completeNativeShoulderPath")
        and irregular_trace["record"].get("classification") == "NON_NOTCH_DEEP_EDGE_RESPONSE"
        and not irregular_trace["record"].get("diagnosticPairingEligible")
        and not irregular_trace["record"].get("notchOwnershipGranted")
        and "NOT_EXACTLY_ONE_NATIVE_APEX"
        in irregular_trace["record"].get("postContourMorphologyReasons", []),
        "Synthetic two-apex chipout-like response was mistaken for a manufactured notch",
    )

    # A connected native branch can terminate before the right shoulder.  It
    # remains in the orange full graph and creates an authority hold, while the
    # complete representative continues on the original measured branch.
    deadend_support = support.copy()
    deadend_raw = raw.copy()
    deadend_enhanced = enhanced.copy()
    for column, depth in ((47, 35.0), (48, 40.0), (49, 45.0), (50, 50.0)):
        deadend_row = int(np.argmin(np.abs(search_offsets - (-depth))))
        deadend_support[deadend_row, column] = True
        deadend_raw[deadend_row, column] = 12.0
        deadend_enhanced[deadend_row, column] = 24.0
    deadend_transition = dict(transition)
    deadend_transition["frontierSupported"] = deadend_support
    deadend_transition["nativeSupported"] = deadend_support
    deadend_transition["rawContrast"] = deadend_raw
    deadend_transition["directRawContrast"] = deadend_raw
    deadend_transition["enhancedContrast"] = deadend_enhanced
    deadend_discovery = discover_raw_candidate_components(
        deadend_transition,
        normal_observed,
        np.zeros(width, dtype=bool),
        outer,
        {"minimumNotchDepthPx": 20.0, "noiseSigmaThreshold": 4.5},
    )
    need(
        len(deadend_discovery["components"]) == 1,
        "Synthetic connected dead-end branch was not freshly discovered once",
    )
    deadend_trace = candidate_graph_trace(
        strip,
        search_offsets,
        outer,
        normal,
        normal_observed,
        deadend_transition,
        deadend_discovery["components"][0],
        float(deadend_discovery["thresholdPx"]),
        params,
        0,
        "BF",
        np.zeros(width, dtype=bool),
        np.zeros(width, dtype=bool),
    )
    need(
        deadend_trace["record"].get("completeNativeShoulderPath")
        and deadend_trace["record"].get("diagnosticPairingEligible")
        and deadend_trace["record"].get("state")
        == "HOLD_NATIVE_CONTOUR_AUTHORITY_RETAINED"
        and deadend_trace["record"].get(
            "candidateLocalAuthorityEligibleBeforeGlobalHold"
        )
        is False
        and deadend_trace["record"].get("notchOwnershipGranted") is False
        and deadend_trace["record"].get("fullCandidateNativeGraphNodeCount", 0)
        > deadend_trace["record"].get("completeSupportGraphNodeCount", 0)
        and deadend_trace["record"].get(
            "strictCoreCoarseBandCountOutsideCompleteShoulderGraph"
        )
        == 1
        and "STRICT_CORE_COARSE_BAND_EVIDENCE_OUTSIDE_COMPLETE_SHOULDER_GRAPH_RETAINED"
        in deadend_trace["record"].get("authorityHoldReasons", [])
        and [row["radialRow"] for row in deadend_trace["record"]["representativePath"]]
        == [row["radialRow"] for row in trace["record"]["representativePath"]],
        "Freshly discovered dead-end native branch was lost, selected, or granted authority",
    )
    need(
        candidate_metric_schema_valid(deadend_trace["record"]),
        "Synthetic dead-end authority-held component lacks its complete metric schema",
    )

    # A freshly discovered strict core that cannot survive on any exact
    # shoulder-to-shoulder canonical signature is fail-closed even though a
    # bounded-gap representative can still be measured.
    zero_signature_support = np.zeros_like(support)
    zero_signature_raw = np.zeros_like(raw)
    zero_signature_enhanced = np.zeros_like(enhanced)
    zero_signature_depths = {40: 21.0, 41: 24.0, 42: 27.0, 43: 33.0}
    for column in range(width):
        depth = zero_signature_depths.get(column, 20.0)
        row = int(np.argmin(np.abs(search_offsets - (-depth))))
        zero_signature_support[row, column] = True
        zero_signature_raw[row, column] = 12.0
        zero_signature_enhanced[row, column] = 24.0
    zero_signature_transition = {
        "searchOffsets": search_offsets,
        "frontierSupported": zero_signature_support,
        "nativeSupported": zero_signature_support,
        "rawContrast": zero_signature_raw,
        "directRawContrast": zero_signature_raw,
        "enhancedContrast": zero_signature_enhanced,
    }
    zero_signature_discovery = discover_raw_candidate_components(
        zero_signature_transition,
        normal_observed,
        np.zeros(width, dtype=bool),
        outer,
        {"minimumNotchDepthPx": 20.0, "noiseSigmaThreshold": 4.5},
    )
    need(
        len(zero_signature_discovery["components"]) == 1,
        "Synthetic zero-signature candidate was not freshly discovered once",
    )
    zero_signature_trace = candidate_graph_trace(
        strip,
        search_offsets,
        outer,
        normal,
        normal_observed,
        zero_signature_transition,
        zero_signature_discovery["components"][0],
        float(zero_signature_discovery["thresholdPx"]),
        params,
        0,
        "BF",
        np.zeros(width, dtype=bool),
        np.zeros(width, dtype=bool),
    )
    zero_signature_record = zero_signature_trace["record"]
    zero_signature_diagnostics = zero_signature_record[
        "coherentCoreCorridorDiagnostics"
    ]
    need(
        zero_signature_record.get("completeNativeShoulderPath")
        and zero_signature_record.get("boundedGapNativeShoulderPath")
        and zero_signature_record.get("coherentCoreCorridorSignatureCountSaturated")
        == 0
        and zero_signature_record.get("coherentCoarseBandRouteCountSaturated") == 0
        and zero_signature_record.get("resolvedPhysicalCoreCorridorCountSaturated")
        == 0
        and zero_signature_record.get("uniqueCoherentNativeCoreCorridorSignature")
        is False
        and zero_signature_record.get("uniqueResolvedPhysicalCoreCorridor") is False
        and zero_signature_record.get("diagnosticPairingEligible") is False
        and zero_signature_record.get(
            "candidateLocalAuthorityEligibleBeforeGlobalHold"
        )
        is False
        and zero_signature_record.get("notchOwnershipGranted") is False
        and zero_signature_record.get("classification")
        == "NON_NOTCH_DEEP_EDGE_RESPONSE"
        and zero_signature_record.get("state")
        == "HOLD_NATIVE_CONTOUR_AUTHORITY_RETAINED"
        and "NO_COHERENT_STRICT_CORE_CORRIDOR_SIGNATURE"
        in zero_signature_record.get("postContourMorphologyReasons", [])
        and "STRICT_CORE_COARSE_BAND_EVIDENCE_OUTSIDE_COMPLETE_SHOULDER_GRAPH_RETAINED"
        in zero_signature_record.get("authorityHoldReasons", [])
        and zero_signature_diagnostics.get(
            "rawExactCanonicalSignatureCountSaturated"
        )
        == 0
        and zero_signature_diagnostics.get("rawExactCoarseRouteCountSaturated")
        == 0
        and zero_signature_diagnostics.get("signatureSummaries") == [],
        "Freshly discovered zero-signature candidate failed open or lost its exact diagnostics",
    )
    need(
        candidate_metric_schema_valid(zero_signature_record),
        "Synthetic zero-signature authority-held component lacks its complete metric schema",
    )
    need(
        candidate_metric_schema_valid(trace["record"]),
        "Synthetic complete component lacks its complete metric schema",
    )
    invalid_candidate_records: list[dict[str, Any]] = []
    for missing_key in (
        "postContourSymmetryScore",
        "apexPopulation",
        "reachableShoulderPathCountSaturated",
    ):
        altered = json.loads(json.dumps(trace["record"]))
        del altered[missing_key]
        invalid_candidate_records.append(altered)
    for metric_key, invalid_value in (
        ("apexCount", 2),
        ("postContourSymmetryScore", 0.0),
        ("leftMonotonicSupportFraction", 0.0),
        ("rightMonotonicSupportFraction", 0.0),
        ("secondDifferenceAbsoluteP90Px", 999.0),
        ("widthDegrees", 999.0),
        ("extraCurvatureReversalFraction", 1.0),
        ("postContourShapeSlopeConsistencyFraction", -1.0),
    ):
        altered = json.loads(json.dumps(trace["record"]))
        altered[metric_key] = invalid_value
        invalid_candidate_records.append(altered)
    for mutation in (
        lambda row: row["representativePath"][0].__setitem__(
            "offsetPx", row["representativePath"][0]["offsetPx"] + 0.25
        ),
        lambda row: row["representativePath"][0].__setitem__(
            "fixedOuterPathOffsetPx",
            row["representativePath"][0]["fixedOuterPathOffsetPx"] + 0.25,
        ),
        lambda row: row["rawComponentNativeNodes"][0].__setitem__(
            "proposalSmoothedRawOutsideInContrast",
            -999.0,
        ),
        lambda row: row["representativePath"][len(row["representativePath"]) // 2].__setitem__(
            "proposalSmoothedRawOutsideInContrast",
            row["representativePath"][len(row["representativePath"]) // 2][
                "proposalSmoothedRawOutsideInContrast"
            ]
            + 0.03125,
        ),
        lambda row: row["rawComponentNativeNodes"][len(row["rawComponentNativeNodes"]) // 2].__setitem__(
            "enhancedOutsideInContrast",
            row["rawComponentNativeNodes"][len(row["rawComponentNativeNodes"]) // 2][
                "enhancedOutsideInContrast"
            ]
            + 0.03125,
        ),
        lambda row: row["completeSupportGraphNativeNodes"][
            len(row["completeSupportGraphNativeNodes"]) // 2
        ].__setitem__(
            "enhancedOutsideInContrast",
            row["completeSupportGraphNativeNodes"][
                len(row["completeSupportGraphNativeNodes"]) // 2
            ]["enhancedOutsideInContrast"]
            + 0.03125,
        ),
        lambda row: row["selectedTransitionWitness"].__setitem__(
            "rawOutsideInMedian",
            row["selectedTransitionWitness"]["rawOutsideInMedian"] + 1.0,
        ),
        lambda row: row.__setitem__(
            "representativeNativeRadialTravelPx",
            row["representativeNativeRadialTravelPx"] + 1.0,
        ),
        lambda row: row.__setitem__(
            "postHocAdjacentParallelBandSwitchCount",
            row["postHocAdjacentParallelBandSwitchCount"] + 1,
        ),
        lambda row: row["leftShoulderWindow"]["entries"][0].__setitem__(
            "nativeNormalTraceSupported", 1
        ),
        lambda row: row.__setitem__("candidateIndex", True),
    ):
        altered = json.loads(json.dumps(trace["record"]))
        mutation(altered)
        invalid_candidate_records.append(altered)
    missing_deadend_authority = json.loads(json.dumps(deadend_trace["record"]))
    missing_deadend_authority["authorityHoldReasons"] = []
    missing_deadend_authority["classificationReasons"] = (
        missing_deadend_authority["evidenceHoldReasons"]
        + missing_deadend_authority["postContourMorphologyReasons"]
    )
    missing_deadend_authority[
        "candidateLocalAuthorityEligibleBeforeGlobalHold"
    ] = True
    invalid_candidate_records.append(missing_deadend_authority)
    coordinated_zero_signature_fail_open = json.loads(
        json.dumps(zero_signature_record)
    )
    coordinated_seed_ids = coordinated_zero_signature_fail_open[
        "strictCoreSeedIds"
    ]
    coordinated_zero_signature_fail_open.update(
        {
            "coherentCoreCorridorSignatureCountSaturated": 1,
            "coherentCoarseBandRouteCountSaturated": 1,
            "uniqueCoherentNativeCoreCorridorSignature": True,
            "strictCoreSeedIdsInUniqueCoherentCorridorSignature": list(
                coordinated_seed_ids
            ),
            "strictCoreSeedIdsNotResolvedToUniqueCoherentCorridor": [],
            "allStrictCoreSeedsShareUniqueCoherentBandCorridor": True,
            "resolvedPhysicalCoreCorridorCountSaturated": 1,
            "uniqueResolvedPhysicalCoreCorridor": True,
            "strictCoreSeedIdsOnRepresentativePhysicalCorridor": list(
                coordinated_seed_ids
            ),
            "strictCoreSeedIdsNotOnRepresentativePhysicalCorridor": [],
        }
    )
    coordinated_diagnostics = coordinated_zero_signature_fail_open[
        "coherentCoreCorridorDiagnostics"
    ]
    coordinated_diagnostics.update(
        {
            "signatureSummaries": [
                {
                    "sha256": "A" * 64,
                    "strictCoreTokenCount": 1,
                    "firstPosition": 0,
                    "lastPosition": 0,
                    "survivingStrictCoreSeedIds": list(coordinated_seed_ids),
                }
            ],
            "rawExactCanonicalSignatureCountSaturated": 1,
            "rawExactCoarseRouteCountSaturated": 1,
            "sustainedPhysicalStrictCoreFork": False,
            "resolvedPhysicalCorridorCountSaturated": 1,
        }
    )
    coordinated_zero_signature_fail_open["postContourMorphologyReasons"] = [
        reason
        for reason in coordinated_zero_signature_fail_open[
            "postContourMorphologyReasons"
        ]
        if reason != "NO_COHERENT_STRICT_CORE_CORRIDOR_SIGNATURE"
    ]
    coordinated_manufactured = bool(
        not coordinated_zero_signature_fail_open["evidenceHoldReasons"]
        and not coordinated_zero_signature_fail_open[
            "postContourMorphologyReasons"
        ]
    )
    coordinated_zero_signature_fail_open.update(
        {
            "manufacturedCompatibleAfterContour": coordinated_manufactured,
            "nativeContourShapeCompatibleAfterContour": coordinated_manufactured,
            "diagnosticPairingEligible": coordinated_manufactured,
            "pairingEligible": coordinated_manufactured,
            "candidateLocalAuthorityEligibleBeforeGlobalHold": bool(
                coordinated_manufactured
                and not coordinated_zero_signature_fail_open[
                    "authorityHoldReasons"
                ]
            ),
            "classification": (
                "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE"
                if coordinated_manufactured
                else "NON_NOTCH_DEEP_EDGE_RESPONSE"
            ),
            "state": (
                "HOLD_NATIVE_CONTOUR_AUTHORITY_RETAINED"
                if coordinated_zero_signature_fail_open["authorityHoldReasons"]
                else "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE_AFTER_NATIVE_CONTOUR"
                if coordinated_manufactured
                else "NON_NOTCH_DEEP_EDGE_RESPONSE"
            ),
        }
    )
    coordinated_zero_signature_fail_open["classificationReasons"] = (
        coordinated_zero_signature_fail_open["evidenceHoldReasons"]
        + coordinated_zero_signature_fail_open["postContourMorphologyReasons"]
        + coordinated_zero_signature_fail_open["authorityHoldReasons"]
    )
    invalid_candidate_records.append(coordinated_zero_signature_fail_open)
    accepted_invalid_indices = [
        index
        for index, candidate in enumerate(invalid_candidate_records)
        if candidate_metric_schema_valid(candidate)
    ]
    need(
        invalid_candidate_records and not accepted_invalid_indices,
        "R27 candidate schema accepted invalid mutation indices "
        f"{accepted_invalid_indices}",
    )

    # R6 can corroborate a topology/morphology result, but it cannot choose one
    # of two plausible physical pairs.  Ambiguity therefore remains a hold even
    # when exactly one pair happens to lie inside the inherited R6 tolerance.
    def synthetic_pair_candidate(candidate_id: str, angle: float) -> dict[str, Any]:
        return {
            "candidateId": candidate_id,
            "centerAngleDegrees": angle,
            "startAngleDegrees": angle - 1.0,
            "endAngleDegrees": angle + 1.0,
            "widthDegrees": 2.0,
            "maximumInwardDepthPx": 80.0,
            "apexCount": 1,
            "leftMonotonicSupportFraction": 1.0,
            "rightMonotonicSupportFraction": 1.0,
            "manufacturedCompatibleAfterContour": True,
            "diagnosticPairingEligible": True,
            "candidateLocalAuthorityEligibleBeforeGlobalHold": False,
            "pairingEligible": True,
            "notchOwnershipGranted": False,
        }

    ambiguous_pair = pair_after_channel_contours(
        [
            synthetic_pair_candidate("BF_A", 10.0),
            synthetic_pair_candidate("BF_B", 20.0),
        ],
        [
            synthetic_pair_candidate("DF_A", 10.1),
            synthetic_pair_candidate("DF_B", 20.1),
        ],
        {"centerX": 0.0, "centerY": 0.0, "radius": 100.0},
        {"centerX": 0.0, "centerY": 0.0, "radius": 100.0},
        params,
        10.05,
        True,
        True,
    )
    need(
        ambiguous_pair["state"] == "HOLD_AMBIGUOUS_BF_DF_MANUFACTURED_PAIR_AFTER_CONTOUR"
        and ambiguous_pair["eligiblePairCountBeforeR6Secondary"] == 2
        and ambiguous_pair["r6SecondaryCorroboratedEligiblePairCount"] == 1
        and ambiguous_pair["resolvedPairCount"] == 0
        and not ambiguous_pair["resolvedPairs"]
        and ambiguous_pair["r6SecondaryTieBreakPerformed"] is False
        and ambiguous_pair["r6SecondarySelectionPerformed"] is False,
        "Synthetic R6 angle improperly selected one of two plausible notch pairs",
    )

    # Reproduce the R24 wrap alias exactly: this raw component covers almost
    # the full revolution, while both sustained shoulder windows first anchor
    # at column zero.  R24's modular count therefore collapsed the intended
    # 102-sample unwrapped interval to one column and excluded the raw nodes.
    broad_component_columns = np.arange(2, 100, dtype=np.int64)
    normal_row = int(np.argmin(np.abs(search_offsets - (-20.0))))
    broad_row = int(np.argmin(np.abs(search_offsets - (-30.0))))
    broad_support = np.zeros_like(support)
    broad_raw = np.zeros_like(raw)
    broad_enhanced = np.zeros_like(enhanced)
    broad_support[normal_row, :] = True
    broad_raw[normal_row, :] = 12.0
    broad_enhanced[normal_row, :] = 24.0
    for unsupported_shoulder_column in (1, 100):
        broad_support[normal_row, unsupported_shoulder_column] = False
        broad_raw[normal_row, unsupported_shoulder_column] = 0.0
        broad_enhanced[normal_row, unsupported_shoulder_column] = 0.0
    broad_support[broad_row, broad_component_columns] = True
    broad_raw[broad_row, broad_component_columns] = 12.0
    broad_enhanced[broad_row, broad_component_columns] = 24.0
    broad_transition = {
        "searchOffsets": search_offsets,
        "frontierSupported": broad_support,
        "nativeSupported": broad_support,
        "rawContrast": broad_raw,
        "directRawContrast": broad_raw,
        "enhancedContrast": broad_enhanced,
    }
    broad_component = {
        "component": broad_component_columns,
        "componentRows": {
            int(column): [broad_row] for column in broad_component_columns
        },
        "coreRows": {50: [broad_row]},
        "broadHalfPerimeterResponse": True,
        "candidateDefinition": "WHOLE_BROAD_STRICT_NATIVE_CORE_PARENT_HOLD",
        "normalTraceInterruptionBasinIndex": None,
        "normalTraceInterruptionBasinColumnIndices": [],
        "strictCoreSeedIds": ["CORE00001"],
        "strictCoreRowsBySeed": {"CORE00001": {50: [broad_row]}},
        "broadParentHoldIds": ["CORE00001"],
        "multiBasinStrictCoreSeedIds": [],
        "discoveryAuthorityHoldReasons": [
            "WHOLE_BROAD_STRICT_CORE_PARENT_RETAINS_ZERO_OWNERSHIP"
        ],
    }
    broad_left_window = normal_trace_shoulder_window(
        normal, normal_observed, broad_transition, int(broad_component_columns[0]), -1,
        np.zeros(width, dtype=bool),
    )
    broad_right_window = normal_trace_shoulder_window(
        normal, normal_observed, broad_transition, int(broad_component_columns[-1]), 1,
        np.zeros(width, dtype=bool),
    )
    need(
        broad_left_window["passed"]
        and broad_right_window["passed"]
        and broad_left_window["supportedSampleCount"] == 7
        and broad_right_window["supportedSampleCount"] == 7
        and broad_left_window["anchor"]["column"] == 0
        and broad_right_window["anchor"]["column"] == 0
        and broad_left_window["anchor"]["distanceFromRawComponentSamples"] == 2
        and broad_right_window["anchor"]["distanceFromRawComponentSamples"] == 2,
        "Synthetic near-full component did not reproduce the crossed R24 shoulder anchors",
    )
    legacy_modular_span = (
        int(broad_right_window["anchor"]["column"])
        - int(broad_left_window["anchor"]["column"])
    ) % width + 1
    intended_unwrapped_span = (
        int(broad_component_columns.size)
        + int(broad_left_window["anchor"]["distanceFromRawComponentSamples"])
        + int(broad_right_window["anchor"]["distanceFromRawComponentSamples"])
    )
    need(
        legacy_modular_span == 1
        and intended_unwrapped_span == 102
        and intended_unwrapped_span > width
        and not set(int(column) for column in broad_component_columns).issubset({0}),
        "Synthetic near-full component does not demonstrate R24 modular span aliasing",
    )
    broad_trace = candidate_graph_trace(
        strip,
        search_offsets,
        outer,
        normal,
        normal_observed,
        broad_transition,
        broad_component,
        float(synthetic_discovery["thresholdPx"]),
        params,
        1,
        "BF",
        np.zeros(width, dtype=bool),
        np.zeros(width, dtype=bool),
    )
    need(
        broad_trace["record"]["state"]
        == "HOLD_BROAD_RESPONSE_HAS_NO_UNIQUE_SHORT_SHOULDER_INTERVAL",
        "Synthetic near-full component did not take the broad-response hold before modulo span construction",
    )
    need(
        broad_trace["span"].tolist() == broad_component_columns.tolist()
        and len(broad_trace["supportPoints"]) == int(broad_component_columns.size)
        and set(broad_trace["record"]["supportMetricSpanColumnIndices"])
        == set(int(column) for column in broad_component_columns),
        "Synthetic broad-response hold discarded or aliased native component evidence",
    )
    need(
        candidate_metric_schema_valid(broad_trace["record"]),
        "Synthetic broad-response hold lacks its complete no-fill metric schema",
    )
    overflow_component = dict(broad_component)
    overflow_component["broadHalfPerimeterResponse"] = False
    overflow_trace = candidate_graph_trace(
        strip,
        search_offsets,
        outer,
        normal,
        normal_observed,
        broad_transition,
        overflow_component,
        float(synthetic_discovery["thresholdPx"]),
        params,
        2,
        "BF",
        np.zeros(width, dtype=bool),
        np.zeros(width, dtype=bool),
    )
    need(
        overflow_trace["record"]["state"]
        == "HOLD_SHOULDER_INTERVAL_EXCEEDS_FULL_PERIMETER"
        and overflow_trace["span"].tolist() == broad_component_columns.tolist()
        and len(overflow_trace["supportPoints"]) == int(broad_component_columns.size),
        "Synthetic unwrapped-overflow fallback did not preserve the full native component",
    )
    print(json.dumps({"state": "PASS_R27_MINIMAL_SOURCE_SELF_CHECK", "engineSha256": sha256_file(Path(__file__).resolve())}, separators=(",", ":")))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("self-check")

    infer = commands.add_parser("infer")
    infer.add_argument("--workspace-root", required=True)
    infer.add_argument("--workspace-io-root", required=True)
    infer.add_argument("--code-root", required=True)
    infer.add_argument("--checkpoint", required=True)
    infer.add_argument("--checkpoint-sha256", required=True)
    infer.add_argument("--rollover-manifest", required=True)
    infer.add_argument("--rollover-manifest-sha256", required=True)
    infer.add_argument("--rollover-gate", required=True)
    infer.add_argument("--rollover-gate-sha256", required=True)
    infer.add_argument("--source-job", required=True)
    infer.add_argument("--source-job-sha256", required=True)
    infer.add_argument("--geometry-job", required=True)
    infer.add_argument("--geometry-job-sha256", required=True)
    infer.add_argument("--hotspot-input", required=True)
    infer.add_argument("--hotspot-input-sha256", required=True)
    infer.add_argument("--hotspot-oracle", required=True)
    infer.add_argument("--hotspot-oracle-sha256", required=True)
    infer.add_argument("--hotspot-oracle-gate", required=True)
    infer.add_argument("--hotspot-oracle-gate-sha256", required=True)
    infer.add_argument("--output-root", required=True)

    evaluate = commands.add_parser("evaluate")
    evaluate.add_argument("--engine-sha256", required=True)
    evaluate.add_argument("--inference-summary", required=True)
    evaluate.add_argument("--inference-summary-sha256", required=True)
    evaluate.add_argument("--inference-gate", required=True)
    evaluate.add_argument("--inference-gate-sha256", required=True)
    evaluate.add_argument("--neutral-population", required=True)
    evaluate.add_argument("--neutral-population-sha256", required=True)
    evaluate.add_argument("--freeze-manifest", required=True)
    evaluate.add_argument("--freeze-manifest-sha256", required=True)
    evaluate.add_argument("--scorer-labels", required=True)
    evaluate.add_argument("--scorer-labels-sha256", required=True)
    evaluate.add_argument("--output-root", required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.command == "self-check":
        return run_self_check()
    if args.command == "infer":
        return run_inference(args)
    if args.command == "evaluate":
        return run_evaluation(args)
    raise RuntimeError(f"Unknown R27 command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
