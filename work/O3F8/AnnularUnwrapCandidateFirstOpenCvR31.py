#!/usr/bin/env python3
"""Review-only R31 corridor bookkeeping and native notch-pose overlay.

R31 preserves R30's selected native contours.  When raw seed identity is lost,
it recognizes one physical corridor only if the selected native-supported path
meets the frozen coverage and contiguous-gap limits, follows a sustained
strict-core run, and has no sustained physical fork.  Extra strict responses
remain authority-held telemetry; their count cannot veto an otherwise valid
manufactured contour.

For a morphology-compatible single-apex candidate, R31 also reports the
contour-wide weighted axis and one directly observed native apex-band sample.
The landmark is diagnostic and unowned; it never grants alignment authority.
No curve fitting, morphology, interpolation, cross-channel pixel transfer, or
production/provider action is performed here.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import sys
from types import ModuleType
from typing import Any


HERE = Path(__file__).resolve().parent
R30_NAME = "AnnularUnwrapCandidateFirstOpenCvR30.py"
R30_SHA256 = "B5A0F8B1E43D303A95628C0F62518A0359E2051C4AF4EAC05A080C84D3170C6A"
R27_SHA256 = "0D6037F2DABFD682D404246F451B617FAE8E132F0BE3D26127C8C670466B71C8"
COMPACT_RUNNER_SHA256 = "1F5D546AB8817632CFFBBCE965E8998A1A0B6BCD4734036399899515989FEF6E"

_RECOMPUTE_SIGNATURE_OLD = '''    representative_path: list[dict[str, Any]],
) -> dict[str, Any]:
'''
_RECOMPUTE_SIGNATURE_NEW = '''    representative_path: list[dict[str, Any]],
    raw_unsupported_column_count: int = 0,
) -> dict[str, Any]:
'''
_RECOMPUTE_OLD = '''    resolved_physical_count = (
        0
        if signature_count == 0 or not complete_strict_positions
        else 2
        if sustained_physical_fork
        else 1
    )
'''
_RECOMPUTE_NEW = '''    representative_sequence = [
        (position_by_column[int(point["column"])], int(point["radialRow"]))
        for point in representative_path
    ]
    representative_positions = [position for position, _ in representative_sequence]
    representative_position_set = set(representative_positions)
    representative_path_gap_free = representative_positions == list(range(len(columns)))
    representative_path_maximum_unsupported_run = longest_false_run(
        np.asarray(
            [position in representative_position_set for position in range(len(columns))],
            dtype=bool,
        )
    )
    representative_strict_core_flags = np.zeros(len(columns), dtype=bool)
    for position, row in representative_sequence:
        representative_strict_core_flags[position] = is_core(position, row)
    representative_path_maximum_strict_core_run = max(
        (int(run.size) for run in linear_true_runs(representative_strict_core_flags)),
        default=0,
    )
    representative_path_has_sustained_strict_core_run = bool(
        representative_path_maximum_strict_core_run
        >= MINIMUM_SHOULDER_SUPPORT_SAMPLES
    )
    representative_path_visits_strict_core = any(
        is_core(position, row) for position, row in representative_sequence
    )
    strict_core_on_complete_count = len(strict_core_set & set(complete_coordinates))
    strict_core_off_complete_count = len(strict_core_set - set(complete_coordinates))
    strict_core_complete_graph_majority = (
        strict_core_on_complete_count > strict_core_off_complete_count
    )
    raw_support_gap_free = raw_unsupported_column_count == 0
    bounded_gap_representative_core_witness = bool(
        signature_count == 0
        and len(representative_positions) / len(columns)
        >= MINIMUM_PATH_COVERAGE_FRACTION
        and representative_path_maximum_unsupported_run
        <= MAXIMUM_UNSUPPORTED_RUN_SAMPLES
        and representative_path_has_sustained_strict_core_run
        and not sustained_physical_fork
    )
    resolved_physical_count = (
        0
        if not complete_strict_positions
        or not (signature_count > 0 or bounded_gap_representative_core_witness)
        else 2
        if sustained_physical_fork
        else 1
    )
'''
_GENERATOR_OLD = '''    resolved_physical_corridor_count = (
        0
        if raw_exact_corridor_signature_count == 0
        or not complete_strict_positions
        else 2
        if sustained_physical_fork
        else 1
    )
'''
_GENERATOR_NEW = '''    representative_positions = [
        position for position, _, _ in sequence
    ]
    representative_position_set = set(representative_positions)
    representative_path_gap_free = representative_positions == list(range(len(columns)))
    representative_path_maximum_unsupported_run = longest_false_run(
        np.asarray(
            [position in representative_position_set for position in range(len(columns))],
            dtype=bool,
        )
    )
    representative_strict_core_flags = np.zeros(len(columns), dtype=bool)
    for position, row, _ in sequence:
        representative_strict_core_flags[position] = is_core(position, row)
    representative_path_maximum_strict_core_run = max(
        (int(run.size) for run in linear_true_runs(representative_strict_core_flags)),
        default=0,
    )
    representative_path_has_sustained_strict_core_run = bool(
        representative_path_maximum_strict_core_run
        >= MINIMUM_SHOULDER_SUPPORT_SAMPLES
    )
    representative_path_visits_strict_core = any(
        is_core(position, row) for position, row, _ in sequence
    )
    strict_core_on_complete_count = len(strict_core_set & complete_support_set)
    strict_core_off_complete_count = len(strict_core_set - complete_support_set)
    strict_core_complete_graph_majority = (
        strict_core_on_complete_count > strict_core_off_complete_count
    )
    raw_unsupported_column_count = len(columns) - len(sequence)
    raw_support_gap_free = raw_unsupported_column_count == 0
    bounded_gap_representative_core_witness = bool(
        raw_exact_corridor_signature_count == 0
        and len(representative_positions) / len(columns)
        >= MINIMUM_PATH_COVERAGE_FRACTION
        and representative_path_maximum_unsupported_run
        <= MAXIMUM_UNSUPPORTED_RUN_SAMPLES
        and representative_path_has_sustained_strict_core_run
        and not sustained_physical_fork
    )
    resolved_physical_corridor_count = (
        0
        if not complete_strict_positions
        or not (
            raw_exact_corridor_signature_count > 0
            or bounded_gap_representative_core_witness
        )
        else 2
        if sustained_physical_fork
        else 1
    )
'''
_RECOMPUTE_DIAGNOSTIC_OLD = '''        "sustainedPhysicalStrictCoreFork": sustained_physical_fork,
'''
_RECOMPUTE_DIAGNOSTIC_NEW = '''        "representativePathPositionCount": len(
            representative_positions
        ),
        "rawUnsupportedColumnCount": raw_unsupported_column_count,
        "rawSupportGapFree": raw_support_gap_free,
        "representativePathGapFree": representative_path_gap_free,
        "representativePathMaximumContiguousUnsupportedRunSamples": (
            representative_path_maximum_unsupported_run
        ),
        "representativePathMaximumContiguousStrictCoreRunSamples": (
            representative_path_maximum_strict_core_run
        ),
        "minimumRepresentativeStrictCoreRunSamples": MINIMUM_SHOULDER_SUPPORT_SAMPLES,
        "representativePathHasSustainedStrictCoreRun": (
            representative_path_has_sustained_strict_core_run
        ),
        "representativePathVisitsStrictCore": representative_path_visits_strict_core,
        "strictCoreNodeCountOnCompleteGraph": strict_core_on_complete_count,
        "strictCoreNodeCountOffCompleteGraph": strict_core_off_complete_count,
        "strictCoreCompleteGraphMajority": strict_core_complete_graph_majority,
        "boundedGapRepresentativeCoreWitness": bounded_gap_representative_core_witness,
        "boundedGapRepresentativeCoreWitnessRole": (
            "SECONDARY_NATIVE_SUPPORTED_BOUNDED_GAP_SUSTAINED_CORE_SINGLE_PATH_WITNESS_WHEN_RAW_SIGNATURE_IS_ZERO"
        ),
        "sustainedPhysicalStrictCoreFork": sustained_physical_fork,
'''
_GENERATOR_DIAGNOSTIC_OLD = '''            "sustainedPhysicalStrictCoreFork": sustained_physical_fork,
'''
_GENERATOR_DIAGNOSTIC_NEW = '''            "representativePathPositionCount": len(
                representative_positions
            ),
            "rawUnsupportedColumnCount": raw_unsupported_column_count,
            "rawSupportGapFree": raw_support_gap_free,
            "representativePathGapFree": representative_path_gap_free,
            "representativePathMaximumContiguousUnsupportedRunSamples": (
                representative_path_maximum_unsupported_run
            ),
            "representativePathMaximumContiguousStrictCoreRunSamples": (
                representative_path_maximum_strict_core_run
            ),
            "minimumRepresentativeStrictCoreRunSamples": (
                MINIMUM_SHOULDER_SUPPORT_SAMPLES
            ),
            "representativePathHasSustainedStrictCoreRun": (
                representative_path_has_sustained_strict_core_run
            ),
            "representativePathVisitsStrictCore": representative_path_visits_strict_core,
            "strictCoreNodeCountOnCompleteGraph": strict_core_on_complete_count,
            "strictCoreNodeCountOffCompleteGraph": strict_core_off_complete_count,
            "strictCoreCompleteGraphMajority": strict_core_complete_graph_majority,
            "boundedGapRepresentativeCoreWitness": bounded_gap_representative_core_witness,
            "boundedGapRepresentativeCoreWitnessRole": (
                "SECONDARY_NATIVE_SUPPORTED_BOUNDED_GAP_SUSTAINED_CORE_SINGLE_PATH_WITNESS_WHEN_RAW_SIGNATURE_IS_ZERO"
            ),
            "sustainedPhysicalStrictCoreFork": sustained_physical_fork,
'''
_SCHEMA_KEYS_OLD = '''            "minimumSustainedForkSpanFraction",
            "sustainedPhysicalStrictCoreFork",
'''
_SCHEMA_KEYS_NEW = '''            "minimumSustainedForkSpanFraction",
            "representativePathPositionCount",
            "rawUnsupportedColumnCount",
            "rawSupportGapFree",
            "representativePathGapFree",
            "representativePathMaximumContiguousUnsupportedRunSamples",
            "representativePathMaximumContiguousStrictCoreRunSamples",
            "minimumRepresentativeStrictCoreRunSamples",
            "representativePathHasSustainedStrictCoreRun",
            "representativePathVisitsStrictCore",
            "strictCoreNodeCountOnCompleteGraph",
            "strictCoreNodeCountOffCompleteGraph",
            "strictCoreCompleteGraphMajority",
            "boundedGapRepresentativeCoreWitness",
            "boundedGapRepresentativeCoreWitnessRole",
            "sustainedPhysicalStrictCoreFork",
'''
_SCHEMA_INTEGER_OLD = '''                "minimumSustainedForkRunSamples",
                "resolvedPhysicalCorridorCountSaturated",
'''
_SCHEMA_INTEGER_NEW = '''                "minimumSustainedForkRunSamples",
                "representativePathPositionCount",
                "rawUnsupportedColumnCount",
                "representativePathMaximumContiguousUnsupportedRunSamples",
                "representativePathMaximumContiguousStrictCoreRunSamples",
                "minimumRepresentativeStrictCoreRunSamples",
                "strictCoreNodeCountOnCompleteGraph",
                "strictCoreNodeCountOffCompleteGraph",
                "resolvedPhysicalCorridorCountSaturated",
'''
_SCHEMA_TYPES_OLD = '''                and type(diagnostics["resolutionRule"]) is str
                and type(diagnostics["signatureSummaries"]) is list
                and type(diagnostics["sustainedPhysicalStrictCoreFork"]) is bool
'''
_SCHEMA_TYPES_NEW = '''                and type(diagnostics["resolutionRule"]) is str
                and type(diagnostics["boundedGapRepresentativeCoreWitnessRole"]) is str
                and diagnostics["boundedGapRepresentativeCoreWitnessRole"]
                == "SECONDARY_NATIVE_SUPPORTED_BOUNDED_GAP_SUSTAINED_CORE_SINGLE_PATH_WITNESS_WHEN_RAW_SIGNATURE_IS_ZERO"
                and type(diagnostics["signatureSummaries"]) is list
                and type(diagnostics["rawSupportGapFree"]) is bool
                and type(diagnostics["representativePathGapFree"]) is bool
                and type(diagnostics["representativePathVisitsStrictCore"]) is bool
                and type(diagnostics["representativePathHasSustainedStrictCoreRun"]) is bool
                and type(diagnostics["strictCoreCompleteGraphMajority"]) is bool
                and type(diagnostics["boundedGapRepresentativeCoreWitness"]) is bool
                and type(diagnostics["sustainedPhysicalStrictCoreFork"]) is bool
'''
_SCHEMA_RESOLUTION_OLD = '''                and resolved_physical_count
                == (
                    0
                    if coherent_route_count == 0
                    else 2
                    if bool(diagnostics["sustainedPhysicalStrictCoreFork"])
                    else 1
                )
                and int(diagnostics["completeStrictCorePositionCount"]) > 0
'''
_SCHEMA_RESOLUTION_NEW = '''                and resolved_physical_count
                == (
                    0
                    if not (
                        coherent_route_count > 0
                        or bool(diagnostics["boundedGapRepresentativeCoreWitness"])
                    )
                    else 2
                    if bool(diagnostics["sustainedPhysicalStrictCoreFork"])
                    else 1
                )
                and int(diagnostics["completeStrictCorePositionCount"]) > 0
                and 0 < int(diagnostics["representativePathPositionCount"])
                <= len(span)
                and int(diagnostics["rawUnsupportedColumnCount"])
                == len(unsupported)
                and bool(diagnostics["rawSupportGapFree"])
                is (len(unsupported) == 0)
                and bool(diagnostics["representativePathGapFree"])
                is (int(diagnostics["representativePathPositionCount"]) == len(span))
                and int(
                    diagnostics[
                        "representativePathMaximumContiguousUnsupportedRunSamples"
                    ]
                )
                == longest_false_run(
                    np.asarray(
                        [column not in unsupported for column in span],
                        dtype=bool,
                    )
                )
                and bool(diagnostics["boundedGapRepresentativeCoreWitness"])
                is (
                    coherent_route_count == 0
                    and int(diagnostics["representativePathPositionCount"]) / len(span)
                    >= MINIMUM_PATH_COVERAGE_FRACTION
                    and int(
                        diagnostics[
                            "representativePathMaximumContiguousUnsupportedRunSamples"
                        ]
                    )
                    <= MAXIMUM_UNSUPPORTED_RUN_SAMPLES
                    and bool(diagnostics["representativePathHasSustainedStrictCoreRun"])
                    and not bool(diagnostics["sustainedPhysicalStrictCoreFork"])
                )
                and int(diagnostics["strictCoreNodeCountOnCompleteGraph"])
                + int(diagnostics["strictCoreNodeCountOffCompleteGraph"])
                == len(strict_nodes)
                and bool(diagnostics["strictCoreCompleteGraphMajority"])
                is (
                    int(diagnostics["strictCoreNodeCountOnCompleteGraph"])
                    > int(diagnostics["strictCoreNodeCountOffCompleteGraph"])
                )
                and int(diagnostics["minimumRepresentativeStrictCoreRunSamples"])
                == MINIMUM_SHOULDER_SUPPORT_SAMPLES
                and bool(diagnostics["representativePathHasSustainedStrictCoreRun"])
                is (
                    int(
                        diagnostics[
                            "representativePathMaximumContiguousStrictCoreRunSamples"
                        ]
                    )
                    >= MINIMUM_SHOULDER_SUPPORT_SAMPLES
                )
'''
_RECOMPUTE_RULE_OLD = '''        "resolutionRule": (
            "ONE_PHYSICAL_CORRIDOR_UNLESS_TWO_OR_MORE_COMPLETE_STRICT_CORE_"
            "COARSE_BANDS_PERSIST_FOR_BOTH_FROZEN_RUN_AND_SPAN_FRACTION"
        ),
'''
_RECOMPUTE_RULE_NEW = '''        "resolutionRule": (
            "BOUNDED_GAP_CORE_VISITING_SINGLE_PATH_PHYSICAL_CORRIDOR_FALLBACK_WITH_RAW_SIGNATURE_RETAINED"
            if signature_count == 0 and bounded_gap_representative_core_witness
            else "ONE_PHYSICAL_CORRIDOR_UNLESS_TWO_OR_MORE_COMPLETE_STRICT_CORE_"
            "COARSE_BANDS_PERSIST_FOR_BOTH_FROZEN_RUN_AND_SPAN_FRACTION"
        ),
'''
_GENERATOR_RULE_OLD = '''            "resolutionRule": (
                "ONE_PHYSICAL_CORRIDOR_UNLESS_TWO_OR_MORE_COMPLETE_STRICT_CORE_"
                "COARSE_BANDS_PERSIST_FOR_BOTH_FROZEN_RUN_AND_SPAN_FRACTION"
            ),
'''
_GENERATOR_RULE_NEW = '''            "resolutionRule": (
                "BOUNDED_GAP_CORE_VISITING_SINGLE_PATH_PHYSICAL_CORRIDOR_FALLBACK_WITH_RAW_SIGNATURE_RETAINED"
                if raw_exact_corridor_signature_count == 0
                and bounded_gap_representative_core_witness
                else "ONE_PHYSICAL_CORRIDOR_UNLESS_TWO_OR_MORE_COMPLETE_STRICT_CORE_"
                "COARSE_BANDS_PERSIST_FOR_BOTH_FROZEN_RUN_AND_SPAN_FRACTION"
            ),
'''

_GENERATOR_RECOMPUTE_ARGUMENT_OLD = '''        representative_path=[
            {
                "column": int(columns[path_position]),
                "radialRow": int(path_row),
            }
            for path_position, path_row, _ in sequence
        ],
    )
'''
_GENERATOR_RECOMPUTE_ARGUMENT_NEW = '''        representative_path=[
            {
                "column": int(columns[path_position]),
                "radialRow": int(path_row),
            }
            for path_position, path_row, _ in sequence
        ],
        raw_unsupported_column_count=len(columns) - len(sequence),
    )
'''
_VALIDATOR_RECOMPUTE_ARGUMENT_OLD = '''            representative_path=representative_path,
        )
'''
_VALIDATOR_RECOMPUTE_ARGUMENT_NEW = '''            representative_path=representative_path,
            raw_unsupported_column_count=len(unsupported),
        )
'''


class R31Error(RuntimeError):
    """Fail-closed R31 detector-overlay error."""


def need(value: Any, message: str) -> None:
    if not value:
        raise R31Error(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _load_r30(path: Path) -> ModuleType:
    need(path.is_file(), f"Missing frozen R30 dependency: {path}")
    need(sha256_file(path) == R30_SHA256, f"Frozen R30 dependency changed: {path}")
    spec = importlib.util.spec_from_file_location("argos_annular_r30_for_r31", path)
    need(spec is not None and spec.loader is not None, f"Cannot load frozen R30: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _replace_once(source: str, old: str, new: str, label: str) -> str:
    need(source.count(old) == 1, f"Frozen {label} structure changed")
    return source.replace(old, new, 1)


def _frozen_function_source(path: Path, name: str) -> str:
    source = path.read_text(encoding="utf-8")
    matches = [
        node for node in ast.parse(source).body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == name
    ]
    need(len(matches) == 1, f"Frozen function definition changed: {name}")
    node = matches[0]
    return "".join(source.splitlines(keepends=True)[node.lineno - 1 : node.end_lineno]) + "\n"


def _patch_engine(loaded: ModuleType, r30: ModuleType) -> None:
    frozen_path = Path(loaded.__file__).resolve()
    recompute = _frozen_function_source(frozen_path, "recompute_coherent_core_corridors")
    recompute = _replace_once(
        recompute, _RECOMPUTE_SIGNATURE_OLD, _RECOMPUTE_SIGNATURE_NEW,
        "corridor recomputation signature",
    )
    recompute = _replace_once(recompute, _RECOMPUTE_OLD, _RECOMPUTE_NEW, "corridor recomputation")
    recompute = _replace_once(
        recompute, _RECOMPUTE_DIAGNOSTIC_OLD, _RECOMPUTE_DIAGNOSTIC_NEW,
        "recomputation diagnostics",
    )
    recompute = _replace_once(recompute, _RECOMPUTE_RULE_OLD, _RECOMPUTE_RULE_NEW, "recomputation rule")
    exec(compile(recompute, str(loaded.__file__), "exec"), loaded.__dict__)

    candidate = _frozen_function_source(frozen_path, "candidate_graph_trace")
    candidate = _replace_once(candidate, r30._R27_SELECTOR_COMMENT, r30._R30_SELECTOR_COMMENT, "R30 selector comment")
    candidate = _replace_once(candidate, r30._R27_SELECTOR_RANK, r30._R30_SELECTOR_RANK, "R30 selector rank")
    need(candidate.count(r30._R27_RANK_LABEL) == 2, "Frozen R30 selector telemetry changed")
    candidate = candidate.replace(r30._R27_RANK_LABEL, r30._R30_RANK_LABEL, 2)
    candidate = _replace_once(
        candidate, _GENERATOR_RECOMPUTE_ARGUMENT_OLD,
        _GENERATOR_RECOMPUTE_ARGUMENT_NEW, "generator recomputation argument",
    )
    candidate = _replace_once(candidate, _GENERATOR_OLD, _GENERATOR_NEW, "corridor generator")
    candidate = _replace_once(
        candidate, _GENERATOR_DIAGNOSTIC_OLD, _GENERATOR_DIAGNOSTIC_NEW,
        "generator diagnostics",
    )
    candidate = _replace_once(candidate, _GENERATOR_RULE_OLD, _GENERATOR_RULE_NEW, "generator rule")
    exec(compile(candidate, str(loaded.__file__), "exec"), loaded.__dict__)

    validator = _frozen_function_source(frozen_path, "candidate_metric_schema_valid")
    validator = _replace_once(validator, _SCHEMA_KEYS_OLD, _SCHEMA_KEYS_NEW, "schema diagnostic keys")
    validator = _replace_once(validator, _SCHEMA_INTEGER_OLD, _SCHEMA_INTEGER_NEW, "schema integer keys")
    validator = _replace_once(validator, _SCHEMA_TYPES_OLD, _SCHEMA_TYPES_NEW, "schema diagnostic types")
    validator = _replace_once(validator, _SCHEMA_RESOLUTION_OLD, _SCHEMA_RESOLUTION_NEW, "schema corridor resolution")
    validator = _replace_once(
        validator, _VALIDATOR_RECOMPUTE_ARGUMENT_OLD,
        _VALIDATOR_RECOMPUTE_ARGUMENT_NEW, "validator recomputation argument",
    )
    exec(compile(validator, str(loaded.__file__), "exec"), loaded.__dict__)

    loaded.R31_RECOMPUTE_SOURCE_SHA256 = hashlib.sha256(recompute.encode("utf-8")).hexdigest().upper()
    loaded.R31_CANDIDATE_SOURCE_SHA256 = hashlib.sha256(candidate.encode("utf-8")).hexdigest().upper()
    loaded.R31_VALIDATOR_SOURCE_SHA256 = hashlib.sha256(validator.encode("utf-8")).hexdigest().upper()


def load_engine(
    r30_path: Path | None = None,
    r27_path: Path | None = None,
    r18_path: Path | None = None,
) -> ModuleType:
    r30_file = (r30_path or Path(os.environ.get("ARGOS_R30_ENGINE_PATH", HERE / R30_NAME))).resolve()
    r30 = _load_r30(r30_file)
    loaded = r30.load_engine(r27_path=r27_path, r18_path=r18_path)
    _patch_engine(loaded, r30)
    return loaded


_ENGINE: ModuleType | None = None
_LAST_RENDERABLE_POSES: dict[str, set[int]] = {"BF": set(), "DF": set()}


def engine() -> ModuleType:
    global _ENGINE
    if _ENGINE is None:
        _ENGINE = load_engine()
    return _ENGINE


def _circular_gap(left: float, right: float) -> float:
    return abs((left - right + 180.0) % 360.0 - 180.0)


def _diagnostic_pose(trace: dict[str, Any], analysis: dict[str, Any]) -> dict[str, Any] | None:
    record = trace["record"]
    points = list(record.get("representativePath", []))
    if not bool(record.get("manufacturedCompatibleAfterContour")) or record.get("apexCount") != 1 or not points:
        return None
    depths = [float(point["fixedOuterPathOffsetPx"] - point["offsetPx"]) for point in points]
    apex_minimum = float(record["apexBandMinimumDepthPx"])
    apex_band = [
        (point, depth) for point, depth in zip(points, depths)
        if depth + 1.0e-6 >= apex_minimum
    ]
    need(apex_band, "Qualified single-apex contour has no native apex-band sample")
    axis = float(record["centerAngleDegrees"])
    width = int(record["angleSampleCount"])
    point, depth = min(
        apex_band,
        key=lambda item: (
            _circular_gap(float(item[0]["column"]) * 360.0 / width, axis),
            -item[1],
            int(item[0]["column"]),
        ),
    )
    column = int(point["column"])
    angle = column * 360.0 / width
    radial_offset = float(point["offsetPx"])
    radius = float(analysis["baseFit"]["radius"]) + radial_offset
    theta = math.radians(angle)
    return {
        "schema": "argos_ocv03_r31_diagnostic_native_notch_pose_v1",
        "poseLandmarkState": "MEASURED_DIAGNOSTIC_UNOWNED_DO_NOT_ALIGN",
        "axisCenterAngleDegreesImageClockwise": axis,
        "axisMethod": "DEPTH_WEIGHTED_CIRCULAR_CENTER_OF_ACTUAL_NATIVE_REPRESENTATIVE_PATH",
        "tipLandmark": {
            "column": column,
            "radialRow": int(point["radialRow"]),
            "angleDegreesImageClockwise": angle,
            "depthFromFixedOuterCirclePx": depth,
            "radialOffsetFromBaseFitCirclePx": radial_offset,
            "radiusFromWaferCenterPx": radius,
            "xNativePx": float(analysis["baseFit"]["centerX"]) + radius * math.cos(theta),
            "yNativePx": float(analysis["baseFit"]["centerY"]) + radius * math.sin(theta),
            "apexBandMinimumDepthPx": apex_minimum,
            "apexBandNativeSampleCount": len(apex_band),
            "selectionMethod": "NEAREST_ROBUST_AXIS_DIRECT_NATIVE_APEX_BAND_SAMPLE_THEN_DEEPEST",
        },
        "coordinateConvention": "NATIVE_TOP_LEFT_ZERO_BASED_PIXEL_CENTER_X_RIGHT_Y_DOWN_ANGLE_CLOCKWISE_FROM_POSITIVE_X",
        "notchOwnershipGranted": False,
        "alignmentEligible": False,
        "interpolationPerformed": False,
        "crossChannelPixelCoordinateTransferPerformed": False,
    }


def analyze_native_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    analysis = engine().analyze_native_strip(*args, **kwargs)
    poses = []
    for trace in analysis["candidateTraces"]:
        trace["diagnosticNotchPose"] = _diagnostic_pose(trace, analysis)
        if trace["diagnosticNotchPose"] is not None:
            poses.append(trace["diagnosticNotchPose"])
    analysis["diagnosticNotchPoses"] = poses
    return analysis


def pair_after_channel_contours(*args: Any, **kwargs: Any) -> dict[str, Any]:
    global _LAST_RENDERABLE_POSES
    result = engine().pair_after_channel_contours(*args, **kwargs)
    _LAST_RENDERABLE_POSES = {"BF": set(), "DF": set()}
    if int(result.get("resolvedPairCount", 0)) == 1:
        pair = result["resolvedPairs"][0]
        _LAST_RENDERABLE_POSES = {
            "BF": {int(pair["bfCandidateIndex"])},
            "DF": {int(pair["dfCandidateIndex"])},
        }
    elif int(result.get("resolvedPairCount", 0)) == 0 and len(args) >= 2:
        source_only = {
            "BF": {
                int(row["candidateIndex"]) for row in args[0]
                if bool(row.get("diagnosticPairingEligible"))
            },
            "DF": {
                int(row["candidateIndex"]) for row in args[1]
                if bool(row.get("diagnosticPairingEligible"))
            },
        }
        if sum(len(values) for values in source_only.values()) == 1:
            _LAST_RENDERABLE_POSES = source_only
    return result


def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return engine().channel_summary(*args, **kwargs)


def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
    return engine().public_candidate_records(*args, **kwargs)


def install_compact_review_hooks(runner: ModuleType) -> None:
    runner_path = Path(runner.__file__).resolve()
    need(sha256_file(runner_path) == COMPACT_RUNNER_SHA256, "Compact review runner bytes changed")
    original_compact = runner.compact_candidate
    original_render = runner.render_bounded

    def compact(trace: dict[str, Any]) -> dict[str, Any]:
        value = original_compact(trace)
        value["diagnosticNotchPose"] = trace.get("diagnosticNotchPose")
        return value

    def render(case_root: Path, identity: str, loaded: Any, analyses: dict[str, dict[str, Any]]) -> dict[str, Any]:
        assets = original_render(case_root, identity, loaded, analyses)
        assets["diagnosticNotchPoseReviews"] = []
        for channel in ("BF", "DF"):
            for trace in analyses[channel]["candidateTraces"]:
                record = trace["record"]
                index = int(record["candidateIndex"])
                pose = trace.get("diagnosticNotchPose")
                if pose is None or index not in _LAST_RENDERABLE_POSES[channel]:
                    continue
                clean_full = runner.cv2.cvtColor(
                    loaded.r18.shadow_lift(analyses[channel]["strip"]),
                    runner.cv2.COLOR_GRAY2BGR,
                )
                clean = runner.candidate_crop(clean_full, record)
                review = clean.copy()
                mask = runner.np.zeros(clean.shape[:2], dtype=runner.np.uint8)
                point = pose["tipLandmark"]
                row = int(round(float(point["radialOffsetFromBaseFitCirclePx"]) - float(analyses[channel]["offsets"][0])))
                width = clean_full.shape[1]
                crop_center = int(round(float(record["centerAngleDegrees"]) * width / 360.0)) % width
                crop_columns = runner.np.arange(
                    crop_center - runner.NATIVE_CROP_COLUMNS // 2,
                    crop_center + runner.NATIVE_CROP_COLUMNS // 2,
                    dtype=runner.np.int64,
                ) % width
                local_columns = runner.np.flatnonzero(crop_columns == int(point["column"]))
                need(local_columns.size == 1, "Native pose sample escaped its circular candidate crop")
                center = (int(local_columns[0]), row)
                runner.cv2.drawMarker(review, center, (255, 0, 255), runner.cv2.MARKER_CROSS, 17, 2, runner.cv2.LINE_8)
                runner.cv2.drawMarker(mask, center, 255, runner.cv2.MARKER_CROSS, 17, 2, runner.cv2.LINE_8)
                changed = runner.np.any(review != clean, axis=2)
                need(bool(runner.np.any(changed)) and not bool(runner.np.any(changed & (mask == 0))), "Pose marker escaped its exact mask")
                stem = f"{channel}_POSE_{index + 1}"
                assets["diagnosticNotchPoseReviews"].append({
                    "channel": channel,
                    "candidateId": record["candidateId"],
                    "state": "MAGENTA_CROSS_MEASURED_NATIVE_TIP_UNOWNED_DO_NOT_ALIGN",
                    "review": runner.encode_png_new(case_root / f"{stem}.png", review, runner.MAX_CROP_PNG_BYTES),
                    "mask": runner.encode_png_new(case_root / f"{stem}_MASK.png", mask, runner.MAX_CROP_PNG_BYTES),
                    "changedPixelsOutsidePoseMask": int(runner.np.count_nonzero(changed & (mask == 0))),
                    "nativeColumns": runner.NATIVE_CROP_COLUMNS,
                    "interpolationPerformed": False,
                })
        return assets

    runner.compact_candidate = compact
    runner.render_bounded = render


def adapter_evidence(loaded: ModuleType | None = None) -> dict[str, Any]:
    loaded = loaded or engine()
    return {
        "schema": "argos_ocv03_annular_candidate_first_r31_overlay_v1",
        "state": "PASS_R31_BOUNDED_GAP_REPRESENTATIVE_STRICT_CORE_AND_DIAGNOSTIC_POSE_BOUND",
        "frozenR30Sha256": R30_SHA256,
        "frozenR27Sha256": R27_SHA256,
        "recomputeSourceSha256": loaded.R31_RECOMPUTE_SOURCE_SHA256,
        "candidateSourceSha256": loaded.R31_CANDIDATE_SOURCE_SHA256,
        "validatorSourceSha256": loaded.R31_VALIDATOR_SOURCE_SHA256,
        "selectedNativeContoursChanged": False,
        "rawSeedSignatureTelemetryPreserved": True,
        "excludedSupportAuthorityHoldsPreserved": True,
        "poseUsesDirectNativeRepresentativeSample": True,
        "poseAlignmentAuthorityGranted": False,
        "idealCurveUsed": False,
        "morphologyPerformed": False,
        "interpolationPerformed": False,
        "crossChannelPixelTransferPerformed": False,
        "reviewOnly": True,
        "productionEligible": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("ADAPTER_CHECK", "EVIDENCE"))
    parser.parse_args()
    print(json.dumps(adapter_evidence(), sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
