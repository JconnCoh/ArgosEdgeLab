#!/usr/bin/env python3
"""Select native normal support by geometry, then resolve paired macro notches."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from types import ModuleType
from typing import Any

HERE = Path(__file__).resolve().parent
R40_NAME = "AnnularUnwrapCandidateFirstOpenCvR40.py"
R40_SHA256 = "F412D3564D93612405C1B3823CF93E2514ACB05F3A6F06A3BD4098B83CD6DC92"
R18_NAME = "AnnularUnwrapDiagnosticOpenCvR18.py"
R18_SHA256 = "510F75463E8494A67442AEACBB7A16F71FE7B307EFEA9231F7CDD7FF6FE34317"
MICRO_REASONS = frozenset(
    {"NOT_EXACTLY_ONE_NATIVE_APEX", "EXCESS_CURVATURE_REVERSALS"}
)


class R41Error(RuntimeError):
    pass


def need(value: Any, message: str) -> None:
    if not value:
        raise R41Error(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load(path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("argos_annular_r40_for_r41", path)
    need(spec is not None and spec.loader is not None, "Cannot load frozen R40")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


R40_PATH = (HERE / R40_NAME).resolve()
need(R40_PATH.is_file() and sha256_file(R40_PATH) == R40_SHA256, "Frozen R40 changed")
r40 = load(R40_PATH)
R27_SHA256 = r40.R27_SHA256
R30_SHA256 = r40.R30_SHA256
COMPACT_RUNNER_SHA256 = r40.COMPACT_RUNNER_SHA256

OLD_INITIAL = '''    initial_observed = np.any(supported & normal_lane, axis=0)
    initial_scores = np.where(supported & normal_lane, contrast, -np.inf)
    initial_rows = np.argmax(initial_scores, axis=0)
'''
NEW_INITIAL = '''    initial_candidates = supported & normal_lane
    initial_observed = np.any(initial_candidates, axis=0)
    initial_deviation = np.abs(search_offsets[:, None] - normal_model[None, :])
    initial_nearest = np.min(np.where(initial_candidates, initial_deviation, np.inf), axis=0)
    initial_geometry = initial_candidates & np.isclose(
        initial_deviation, initial_nearest[None, :], rtol=0.0, atol=1.0e-6
    )
    initial_scores = np.where(initial_geometry, contrast, -np.inf)
    initial_rows = np.argmax(initial_scores, axis=0)
'''
OLD_FINAL = '''    scores = np.where(normal_candidates, contrast, -np.inf)
    normal_rows = np.argmax(scores, axis=0)
    columns = np.arange(outer_path.size, dtype=np.int32)
    normal_path = search_offsets[normal_rows].astype(np.float32)
    normal_strength = scores[normal_rows, columns]
'''
NEW_FINAL = '''    radial_deviation = np.abs(search_offsets[:, None] - calibrated_model[None, :])
    nearest_deviation = np.min(np.where(normal_candidates, radial_deviation, np.inf), axis=0)
    nearest_candidates = normal_candidates & np.isclose(
        radial_deviation, nearest_deviation[None, :], rtol=0.0, atol=1.0e-6
    )
    scores = np.where(nearest_candidates, contrast, -np.inf)
    normal_rows = np.argmax(scores, axis=0)
    columns = np.arange(outer_path.size, dtype=np.int32)
    normal_path = search_offsets[normal_rows].astype(np.float32)
    normal_strength = scores[normal_rows, columns]
'''

_ENGINE: ModuleType | None = None
_MEASURE_SHA256: str | None = None
_ANALYSES: dict[str, dict[str, Any]] = {}
_SELECTED: dict[str, set[int]] = {"BF": set(), "DF": set()}
_HOOKED_RUNNERS: set[int] = set()


def engine() -> ModuleType:
    global _ENGINE, _MEASURE_SHA256
    if _ENGINE is not None:
        return _ENGINE
    loaded = r40.engine()
    path = Path(loaded.r18.__file__).resolve()
    need(path.name == R18_NAME and sha256_file(path) == R18_SHA256, "Frozen R18 changed")
    source = r40.function_source(path, "measure_pixel_edge_family")
    need(
        source.count(OLD_INITIAL) == source.count(OLD_FINAL) == 1
        and NEW_INITIAL not in source and NEW_FINAL not in source,
        "Frozen R18 normal selection changed",
    )
    corrected = source.replace(OLD_INITIAL, NEW_INITIAL, 1).replace(OLD_FINAL, NEW_FINAL, 1)
    r40.ast.parse(corrected)
    _MEASURE_SHA256 = hashlib.sha256(corrected.encode()).hexdigest().upper()
    exec(compile(corrected, str(path), "exec"), loaded.r18.__dict__)
    _ENGINE = loaded
    return loaded


def analyze_native_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    engine()
    install_running_review_hook()
    channel = str(kwargs.get("channel", args[6] if len(args) > 6 else ""))
    need(channel in ("BF", "DF"), "Channel changed")
    if channel == "BF":
        _ANALYSES.clear()
        _SELECTED.update({"BF": set(), "DF": set()})
    analysis = r40.analyze_native_strip(*args, **kwargs)
    analysis["evidence"].update(
        {
            "normalBrightnessSelectionRule": (
                "FIXED_CALIBRATED_LANE_NEAREST_NATIVE_SUPPORT_THEN_BRIGHTNESS_TIE_BREAK"
            ),
            "normalBrightnessSupportMapChanged": False,
        }
    )
    _ANALYSES[channel] = analysis
    return analysis


def macro_copy(row: dict[str, Any]) -> dict[str, Any]:
    result = dict(row)
    reasons = set(row.get("postContourMorphologyReasons", []))
    if row.get("nativeContourEvidenceQualified") and reasons and reasons <= MICRO_REASONS:
        result.update(
            {
                "classification": "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE",
                "manufacturedCompatibleAfterContour": True,
                "nativeContourShapeCompatibleAfterContour": True,
                "diagnosticPairingEligible": True,
                "pairingEligible": True,
            }
        )
    return result


def promote(record: dict[str, Any]) -> None:
    reasons = list(record.get("postContourMorphologyReasons", []))
    if not reasons or not set(reasons) <= MICRO_REASONS:
        return
    record["r41MicroTopologyTelemetry"] = {
        "retainedReasons": reasons,
        "apexCount": int(record.get("apexCount", 0)),
        "curvatureReversalCount": int(record.get("curvatureReversalCount", 0)),
        "selectionRole": "TELEMETRY_AFTER_UNIQUE_POST_CONTOUR_CORROBORATION",
    }
    record["postContourMorphologyReasons"] = []
    record["classificationReasons"] = [
        value for value in record.get("classificationReasons", [])
        if value not in MICRO_REASONS
    ]
    record.update(
        {
            "classification": "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE",
            "manufacturedCompatibleAfterContour": True,
            "nativeContourShapeCompatibleAfterContour": True,
            "diagnosticPairingEligible": True,
            "pairingEligible": True,
            "candidateLocalAuthorityEligibleBeforeGlobalHold": not bool(
                record.get("authorityHoldReasons")
            ),
            "state": (
                "HOLD_NATIVE_CONTOUR_AUTHORITY_RETAINED"
                if record.get("authorityHoldReasons")
                else "NEUTRAL_MANUFACTURED_NOTCH_CANDIDATE_AFTER_NATIVE_CONTOUR"
            ),
        }
    )


def unique_pair(result: dict[str, Any]) -> dict[str, Any] | None:
    rows = [
        row for row in result.get("physicalPairs", [])
        if row.get("eligibleAfterAllChannelLocalContours")
    ]
    if len(rows) == 1:
        return rows[0]
    if (
        rows and result.get("exactDuplicatePairRecordCoalescingPerformed")
        and int(result.get("eligiblePhysicalPairIdentityCountBeforeR6Secondary", 0)) == 1
    ):
        return min(rows, key=lambda row: (row["bfCandidateIndex"], row["dfCandidateIndex"]))
    return None


def df_only_transfer(
    result: dict[str, Any], bf: list[dict[str, Any]], df: list[dict[str, Any]],
    params: Any, r6_angle: float | None,
) -> int | None:
    qualified = [(index, row) for index, row in enumerate(df) if row.get("diagnosticPairingEligible")]
    if not result["circleComparison"]["qualified"] or len(qualified) != 1:
        return None
    index, source = qualified[0]
    bf_local_qualified = [
        row for row in bf
        if row.get("diagnosticPairingEligible")
        and row.get("startAngleDegrees") is not None
        and engine().candidate_interval_overlap(row, source) > 0.0
    ]
    held = [
        row for row in bf
        if not row.get("diagnosticPairingEligible")
        and (
            str(row.get("state", "")).startswith("HOLD_")
            or row.get("classification") == "NON_NOTCH_DEEP_EDGE_RESPONSE"
        )
        and row.get("startAngleDegrees") is not None
        and engine().candidate_interval_overlap(row, source) > 0.0
    ]
    if bf_local_qualified or not held:
        return None
    distance = None if r6_angle is None else engine().circular_distance_degrees(
        float(source["centerAngleDegrees"]), r6_angle
    )
    conflict = distance is not None and distance > engine().R6_SECONDARY_TOLERANCE_DEGREES
    result["sameChuckAngleOnlyTransfer"] = {
        "state": (
            "HOLD_R41_DF_ONLY_ANGLE_INTERVAL_R6_CONFLICT_RETAINED"
            if conflict else "DIAGNOSTIC_R41_DF_ONLY_SAME_CHUCK_ANGLE_INTERVAL"
        ),
        "angleDegrees": float(source["centerAngleDegrees"]),
        "startAngleDegrees": float(source["startAngleDegrees"]),
        "endAngleDegrees": float(source["endAngleDegrees"]),
        "sourceChannel": "DF", "targetChannel": "BF",
        "transferredPixelCoordinateCount": 0,
        "bfContourHoldRetained": True,
        "futureRegistrationAuthorityGranted": False,
        "lawfulCircleComparisonRequiredAndPassed": True,
        "bfHeldLocalCandidateIds": [row["candidateId"] for row in held],
        "r6SecondaryDistanceDegrees": distance,
        "r6ConflictHoldRetained": conflict,
    }
    return int(source.get("candidateIndex", index))


def pair_after_channel_contours(
    bf_candidates: list[dict[str, Any]], df_candidates: list[dict[str, Any]],
    bf_circle: dict[str, Any], df_circle: dict[str, Any], params: Any,
    r6_angle: float | None, bf_circle_qualified: bool, df_circle_qualified: bool,
) -> dict[str, Any]:
    need(set(_ANALYSES) == {"BF", "DF"}, "Both channel contours were not completed")
    shadow = {"BF": [macro_copy(row) for row in bf_candidates],
              "DF": [macro_copy(row) for row in df_candidates]}
    result = r40.pair_after_channel_contours(
        shadow["BF"], shadow["DF"], bf_circle, df_circle, params, r6_angle,
        bf_circle_qualified, df_circle_qualified,
    )
    _SELECTED.update({"BF": set(), "DF": set()})
    pair = unique_pair(result)
    if pair is not None:
        _SELECTED["BF"].add(int(pair["bfCandidateIndex"]))
        _SELECTED["DF"].add(int(pair["dfCandidateIndex"]))
    else:
        source = df_only_transfer(result, shadow["BF"], shadow["DF"], params, r6_angle)
        if source is not None:
            _SELECTED["DF"].add(source)
    promoted_telemetry: list[dict[str, Any]] = []
    for channel in ("BF", "DF"):
        for trace in _ANALYSES[channel]["candidateTraces"]:
            if int(trace["record"]["candidateIndex"]) in _SELECTED[channel]:
                promote(trace["record"])
                if trace["record"].get("r41MicroTopologyTelemetry"):
                    promoted_telemetry.append(
                        {
                            "channel": channel,
                            "candidateId": trace["record"]["candidateId"],
                            **trace["record"]["r41MicroTopologyTelemetry"],
                        }
                    )
    r40.r37.r36.r34.r32.r31._LAST_RENDERABLE_POSES = {
        key: set(value) for key, value in _SELECTED.items()
    }
    result.update(
        {
            "r41UniqueMacroPhysicalPairBeforeR6": pair is not None,
            "r41SelectedCandidateIndices": {key: sorted(value) for key, value in _SELECTED.items()},
            "r41SelectedMicroTopologyTelemetry": promoted_telemetry,
            "r41MicroTopologyUsedOnlyAfterBothContourPopulations": True,
            "r41R6PrimarySelectionPerformed": False,
            "crossChannelPixelCoordinateTransferPerformed": False,
        }
    )
    return result


def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return r40.channel_summary(*args, **kwargs)


def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
    return r40.public_candidate_records(*args, **kwargs)


def install_compact_review_hooks(runner: ModuleType) -> None:
    engine()
    r40.install_compact_review_hooks(runner)
    old_compact, old_rank, old_header = runner.compact_candidate, runner.review_rank, runner.header

    def compact(trace: dict[str, Any]) -> dict[str, Any]:
        value = old_compact(trace)
        record = trace["record"]
        value["r41SelectedForReview"] = int(record["candidateIndex"]) in _SELECTED[str(record["channel"])]
        value["r41MicroTopologyTelemetry"] = record.get("r41MicroTopologyTelemetry")
        return value

    def rank(trace: dict[str, Any]) -> tuple[Any, ...]:
        record = trace["record"]
        selected = int(record["candidateIndex"]) in _SELECTED[str(record["channel"])]
        return (0 if selected else 1, *old_rank(trace))

    def header(image: Any, label: str) -> Any:
        label = label.replace(
            "RED manufactured | ORANGE held/non-notch",
            "RED selected diagnostic candidate | ORANGE unselected/held response",
        )
        if " CLEAN:" in label:
            label += " | global preview point-decimated; use native crop for shape"
        return old_header(image, label)

    def channel_overlay(loaded: Any, analysis: dict[str, Any]) -> tuple[Any, Any, Any]:
        strip, offsets = loaded.np.asarray(analysis["strip"]), loaded.np.asarray(analysis["offsets"])
        clean = runner.cv2.cvtColor(loaded.r18.shadow_lift(strip), runner.cv2.COLOR_GRAY2BGR)
        image, mask = clean.copy(), loaded.np.zeros(strip.shape, dtype=loaded.np.uint8)
        loaded.r18.draw_circle_path(image, mask, analysis["outerPath"], offsets, runner.CYAN)
        loaded.r18.draw_circle_path(image, mask, analysis["innerPath"], offsets, runner.YELLOW)
        loaded.draw_native_points(image, mask, analysis["normalBrightnessPath"], analysis["normalBrightnessObserved"], offsets, runner.LIME)
        channel = str(analysis["candidateTraces"][0]["record"]["channel"]) if analysis["candidateTraces"] else ""
        for trace in analysis["candidateTraces"]:
            record = trace["record"]
            selected = int(record["candidateIndex"]) in _SELECTED[channel]
            loaded.draw_native_points(image, mask, trace["path"], trace["observed"], offsets, runner.RED if selected else runner.ORANGE)
        changed = loaded.np.any(image != clean, axis=2)
        need(not bool(loaded.np.any(changed & (mask == 0))), "Annotated pixels escaped the exact contour mask")
        return clean, image, mask

    runner.compact_candidate = compact
    runner.review_rank, runner.header, runner.channel_overlay = rank, header, channel_overlay


def install_running_review_hook() -> bool:
    candidates = [
        module for module in list(sys.modules.values())
        if isinstance(module, ModuleType)
        and Path(str(getattr(module, "__file__", ""))).name == "Run-O3F16R28FullKlarfReview.py"
        and hasattr(module, "render_bounded") and hasattr(module, "review_rank")
        and Path(str(getattr(module, "ADAPTER_PATH", ""))).resolve() == Path(__file__).resolve()
    ]
    need(len(candidates) <= 1, "Multiple bound compact review runners are active")
    if not candidates:
        return False
    runner = candidates[0]
    if id(runner) not in _HOOKED_RUNNERS:
        install_compact_review_hooks(runner)
        _HOOKED_RUNNERS.add(id(runner))
    return True


def adapter_evidence() -> dict[str, Any]:
    engine()
    return {
        "schema": "argos_ocv03_annular_candidate_first_r41_v1",
        "state": "PASS_R41_FIXED_LANE_GEOMETRY_FIRST_AND_UNIQUE_MACRO_PAIR_ENABLED",
        "frozenR40Sha256": R40_SHA256, "frozenR18Sha256": R18_SHA256,
        "transformedMeasurePixelEdgeFamilySha256": _MEASURE_SHA256,
        "normalSupportMapChanged": False,
        "normalSelectionRule": "NEAREST_FIXED_CALIBRATED_LANE_SUPPORT_THEN_BRIGHTNESS",
        "microTopologyReasons": sorted(MICRO_REASONS),
        "microTopologyRequiresUniquePhysicalCorroboration": True,
        "compactReviewHookInstallMode": "AUTO_WHEN_HASH_PINNED_RUNNER_IS_BOUND",
        "selectedContourColor": "RED", "unselectedContourColor": "ORANGE",
        "r6PrimarySelectionPerformed": False,
        "pixelsOrContoursCreated": False, "interpolationOrMorphologyPerformed": False,
        "notchOwnershipGranted": False, "reviewOnly": True,
    }


def self_test() -> dict[str, Any]:
    need(r40.self_test()["state"] == "PASS_R40_CANDIDATE_LOCAL_TRANSITION_SELF_TEST", "R40 self-test changed")
    loaded, np = engine(), engine().np
    offsets, width = np.arange(-30.0, 11.0, dtype=np.float32), 64
    supported = np.zeros((offsets.size, width), dtype=bool)
    true_row = int(np.flatnonzero(offsets == -20.0)[0])
    distractor = int(np.flatnonzero(offsets == -15.0)[0])
    supported[true_row, :], supported[distractor, ::2] = True, True
    contrast = np.zeros_like(supported, dtype=np.float32)
    contrast[true_row, :], contrast[distractor, ::2] = 20.0, 200.0
    measured = loaded.r18.measure_pixel_edge_family(
        {"searchOffsets": offsets, "frontierSupported": supported, "enhancedContrast": contrast},
        np.zeros(width, dtype=np.float32),
    )
    need(bool(np.all(measured["normalPath"] == -20.0)), "Pattern distractor displaced fixed-lane trace")
    candidate = {"nativeContourEvidenceQualified": True,
                 "postContourMorphologyReasons": list(MICRO_REASONS),
                 "diagnosticPairingEligible": False}
    need(macro_copy(candidate)["diagnosticPairingEligible"], "Micro topology hypothesis missing")
    candidate["postContourMorphologyReasons"].append("POST_CONTOUR_SYMMETRY_BELOW_FROZEN_LIMIT")
    need(not macro_copy(candidate)["diagnosticPairingEligible"], "Macro failure was relaxed")
    df = {"candidateId": "DF_C0001", "candidateIndex": 0, "diagnosticPairingEligible": True,
          "startAngleDegrees": 9.0, "endAngleDegrees": 11.0, "widthDegrees": 2.0,
          "centerAngleDegrees": 10.0}
    bf_qualified = dict(df, candidateId="BF_C0001")
    bf_held = dict(df, candidateId="BF_C0002", candidateIndex=1,
                   diagnosticPairingEligible=False, state="HOLD_NATIVE_CONTOUR")
    transfer_result = {"circleComparison": {"qualified": True}}
    need(df_only_transfer(transfer_result, [bf_qualified, bf_held], [df], None, None) is None,
         "DF-only transfer ignored an overlapping qualified BF contour")
    need(df_only_transfer(transfer_result, [bf_held], [df], None, None) == 0,
         "Lawful DF-only transfer with one BF held contour was lost")
    return {"schema": "argos_ocv03_annular_candidate_first_r41_self_test_v1",
            "state": "PASS_R41_FIXED_LANE_AND_MACRO_PAIR_SELF_TEST",
            "brighterIntermittentDistractorSelectedCount": 0,
            "macroShapeFailureRelaxed": False, "dfOnlyQualifiedBfExclusionPassed": True,
            "sourceImageBytesRead": False,
            "mutationsPerformed": False}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("ADAPTER_CHECK", "EVIDENCE", "SELF_TEST"))
    args = parser.parse_args()
    value = self_test() if args.stage == "SELF_TEST" else adapter_evidence()
    print(json.dumps(value, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
