#!/usr/bin/env python3
"""Run frozen FRONT24 semantics with exact ordinal, mask, and JSON corrections.

Correct only the frozen runner's ordinal, contour-mask, and non-finite evidence
wiring defects in memory. Detector pixels, contours, thresholds, source images,
classifications, and authority holds remain unchanged.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path
import sys
from types import ModuleType
from typing import Any

RUNNER_NAME = "Run-O3F16R28FullKlarfReview.py"
RUNNER_SHA256 = "1F5D546AB8817632CFFBBCE965E8998A1A0B6BCD4734036399899515989FEF6E"
SOURCE_OLD = 'need(identity == str(plan["identity"]) and ordinal == int(plan["ordinal"]), "Frozen source-validation order changed")'
SOURCE_NEW = 'need(identity == str(plan["identity"]), "Frozen source-validation identity order changed")'
MASK_HELPER_OLD = '''def draw_path(engine: Any, image: np.ndarray, path: np.ndarray, observed: np.ndarray, offsets: np.ndarray, color: tuple[int, int, int]) -> None:
    mask = np.zeros(image.shape[:2], dtype=np.uint8)
    engine.draw_native_points(image, mask, path, observed, offsets, color)
'''
MASK_HELPER_NEW = '''def draw_path(engine: Any, image: np.ndarray, mask: np.ndarray, path: np.ndarray, observed: np.ndarray, offsets: np.ndarray, color: tuple[int, int, int]) -> None:
    engine.draw_native_points(image, mask, path, observed, offsets, color)
'''
NORMAL_DRAW_OLD = '    draw_path(engine, image, analysis["normalBrightnessPath"], analysis["normalBrightnessObserved"], offsets, LIME)'
NORMAL_DRAW_NEW = '    draw_path(engine, image, mask, analysis["normalBrightnessPath"], analysis["normalBrightnessObserved"], offsets, LIME)'
CANDIDATE_DRAW_OLD = '        draw_path(engine, image, trace["path"], trace["observed"], offsets, color)'
CANDIDATE_DRAW_NEW = '        draw_path(engine, image, mask, trace["path"], trace["observed"], offsets, color)'
JSON_HELPER_OLD = '''def canonical_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, allow_nan=False, ensure_ascii=True, separators=(",", ":")) + "\\n").encode("utf-8")
'''
JSON_HELPER_NEW = '''UNDEFINED_CIRCLE_RESIDUAL_KEYS = (
    "rmsResidualPx",
    "p90AbsoluteResidualPx",
    "finalSupportRmsResidualPx",
    "finalSupportP90AbsoluteResidualPx",
    "maximumSelectedToFinalCircleDifferencePx",
)
def require_json_finite(value: Any, pointer: str = "$") -> None:
    if isinstance(value, (float, np.floating)):
        need(math.isfinite(float(value)), f"Non-finite JSON scalar at {pointer}")
    elif isinstance(value, dict):
        for key, child in value.items():
            require_json_finite(child, f"{pointer}.{key}")
    elif isinstance(value, (list, tuple)):
        for index, child in enumerate(value):
            require_json_finite(child, f"{pointer}[{index}]")
def finite_circle_fit(value: dict[str, Any]) -> dict[str, Any]:
    result = dict(value)
    accepted = int(result["acceptedCount"])
    if accepted == 0:
        need(
            all(
                isinstance(result[key], (float, np.floating))
                and not math.isfinite(float(result[key]))
                for key in UNDEFINED_CIRCLE_RESIDUAL_KEYS
            ),
            "Frozen zero-population circle residual semantics changed",
        )
        for key in UNDEFINED_CIRCLE_RESIDUAL_KEYS:
            result[key] = None
        result["undefinedResidualMetricReason"] = "NO_ACCEPTED_CIRCLE_RESIDUAL_SAMPLES"
    else:
        need(
            all(math.isfinite(float(result[key])) for key in UNDEFINED_CIRCLE_RESIDUAL_KEYS),
            "Accepted circle residual metric is non-finite",
        )
        result["undefinedResidualMetricReason"] = None
    return result
def canonical_json_bytes(value: Any) -> bytes:
    require_json_finite(value)
    return (json.dumps(value, sort_keys=True, allow_nan=False, ensure_ascii=True, separators=(",", ":")) + "\\n").encode("utf-8")
'''
CIRCLE_FIT_OLD = '        "circleFit": analysis["circleFit"],'
CIRCLE_FIT_NEW = '        "circleFit": finite_circle_fit(analysis["circleFit"]),'
HERE = Path(__file__).resolve().parent
class Front24R39DriverError(RuntimeError):
    pass
def need(value: Any, message: str) -> None:
    if not value:
        raise Front24R39DriverError(message)
def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()
def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()
def canonical_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, allow_nan=False, separators=(",", ":")) + "\n").encode("utf-8")
def runner_path() -> Path:
    direct = HERE / RUNNER_NAME
    fallback = HERE.parent / "O3F16R28K1" / RUNNER_NAME
    return (direct if direct.is_file() else fallback).resolve()
def corrected_source(path: Path) -> tuple[str, str]:
    source_bytes = path.read_bytes()
    need(sha256_bytes(source_bytes) == RUNNER_SHA256, "Frozen FRONT24 runner changed")
    source = source_bytes.decode("utf-8")
    replacements = (
        (SOURCE_OLD, SOURCE_NEW, "ordinal correction"),
        (MASK_HELPER_OLD, MASK_HELPER_NEW, "shared-mask helper correction"),
        (NORMAL_DRAW_OLD, NORMAL_DRAW_NEW, "normal-trace mask correction"),
        (CANDIDATE_DRAW_OLD, CANDIDATE_DRAW_NEW, "candidate-trace mask correction"),
        (JSON_HELPER_OLD, JSON_HELPER_NEW, "finite-JSON helper correction"),
        (CIRCLE_FIT_OLD, CIRCLE_FIT_NEW, "circle-fit evidence correction"),
    )
    corrected = source
    for old, new, label in replacements:
        need(corrected.count(old) == 1 and new not in corrected, f"Frozen {label} target changed")
        corrected = corrected.replace(old, new, 1)
    ast.parse(corrected, filename=str(path))
    return corrected, sha256_bytes(corrected.encode("utf-8"))
def load_corrected_runner(path: Path) -> tuple[ModuleType, str]:
    source, corrected_sha256 = corrected_source(path)
    name = "argos_front24_r39_exact_evidence_correction"
    module = ModuleType(name)
    module.__file__ = str(path)
    module.__package__ = ""
    sys.modules[name] = module
    exec(compile(source, str(path), "exec"), module.__dict__)
    return module, corrected_sha256
def self_test() -> dict[str, Any]:
    path = runner_path()
    corrected, corrected_sha256 = corrected_source(path)
    for old, new in (
        (SOURCE_OLD, SOURCE_NEW),
        (MASK_HELPER_OLD, MASK_HELPER_NEW),
        (NORMAL_DRAW_OLD, NORMAL_DRAW_NEW),
        (CANDIDATE_DRAW_OLD, CANDIDATE_DRAW_NEW),
        (JSON_HELPER_OLD, JSON_HELPER_NEW),
        (CIRCLE_FIT_OLD, CIRCLE_FIT_NEW),
    ):
        need(old not in corrected and corrected.count(new) == 1, "R39 source correction was not exact")
    runner, loaded_sha256 = load_corrected_runner(path)
    need(loaded_sha256 == corrected_sha256, "R39 corrected runner hash changed during load")
    zero = {"acceptedCount": 0, **{key: float("inf") for key in runner.UNDEFINED_CIRCLE_RESIDUAL_KEYS}}
    zero_result = runner.finite_circle_fit(zero)
    need(
        all(zero_result[key] is None for key in runner.UNDEFINED_CIRCLE_RESIDUAL_KEYS)
        and zero_result["undefinedResidualMetricReason"] == "NO_ACCEPTED_CIRCLE_RESIDUAL_SAMPLES",
        "Zero-population circle residuals were not represented explicitly",
    )
    finite = {"acceptedCount": 1, **{key: 0.25 for key in runner.UNDEFINED_CIRCLE_RESIDUAL_KEYS}}
    finite_result = runner.finite_circle_fit(finite)
    need(
        all(finite_result[key] == 0.25 for key in runner.UNDEFINED_CIRCLE_RESIDUAL_KEYS)
        and finite_result["undefinedResidualMetricReason"] is None,
        "Finite circle residual evidence changed",
    )
    try:
        runner.canonical_json_bytes({"outer": {"bad": float("inf")}})
    except Exception as exc:
        need(str(exc) == "Non-finite JSON scalar at $.outer.bad", "Non-finite JSON path report changed")
    else:
        need(False, "Unexpected non-finite JSON scalar was accepted")
    return {
        "schema": "argos_ocv03_candidate_first_front24_r39_driver_self_test_v1",
        "state": "PASS_FRONT24_R39_FINITE_EVIDENCE_SELF_TEST",
        "frozenRunnerSha256": RUNNER_SHA256,
        "correctedRunnerSha256": corrected_sha256,
        "sourceReplacementCount": 6,
        "undefinedCircleResidualKeyCount": len(runner.UNDEFINED_CIRCLE_RESIDUAL_KEYS),
        "unexpectedNonFiniteJsonRejectedWithPath": True,
        "planOrdinalsMutated": False,
        "detectorPixelsOrContoursChanged": False,
        "sourceImageBytesRead": False,
        "mutationsPerformed": False,
        "reviewOnly": True,
    }
def bind(adapter_path: Path, adapter_sha256: str) -> tuple[ModuleType, dict[str, Any]]:
    expected = adapter_sha256.upper()
    need(len(expected) == 64 and all(char in "0123456789ABCDEF" for char in expected), "Adapter SHA-256 is invalid")
    adapter = adapter_path.resolve()
    need(adapter.is_file() and sha256_file(adapter) == expected, "Adapter bytes do not match the supplied SHA-256")
    frozen_path = runner_path()
    runner, corrected_sha256 = load_corrected_runner(frozen_path)
    runner.ADAPTER_PATH = adapter
    binding = {
        "frozenRunnerPath": str(frozen_path),
        "frozenRunnerSha256": RUNNER_SHA256,
        "correctedRunnerSha256": corrected_sha256,
        "adapterPath": str(adapter),
        "adapterSha256": expected,
        "corrections": [
            "REMOVE_INVALID_FRONT24_REVIEW_ORDINAL_EQUALS_FULL978_ORDINAL_COMPARISON",
            "ACCUMULATE_NATIVE_CONTOUR_PIXELS_IN_SHARED_EXACT_MASK",
            "REPRESENT_ZERO_POPULATION_CIRCLE_RESIDUALS_AS_NULL_WITH_EXPLICIT_REASON",
            "REJECT_ANY_OTHER_NONFINITE_JSON_SCALAR_WITH_EXACT_PATH",
        ],
        "planOrdinalsMutated": False,
        "detectorPixelsOrContoursChanged": False,
        "frozenRunnerBytesChanged": False,
        "reviewOnly": True,
    }
    return runner, binding
def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("SELF_TEST", "PREFLIGHT", "RUN"))
    parser.add_argument("--adapter-path")
    parser.add_argument("--adapter-sha256")
    parser.add_argument("--output-root")
    parser.add_argument("--mirror-root")
    args = parser.parse_args()
    if args.stage == "SELF_TEST":
        need(not any((args.adapter_path, args.adapter_sha256, args.output_root, args.mirror_root)), "SELF_TEST accepts no paths")
        result = self_test()
    else:
        need(args.adapter_path and args.adapter_sha256, "PREFLIGHT and RUN require an adapter path and SHA-256")
        runner, binding = bind(Path(args.adapter_path), args.adapter_sha256)
        if args.stage == "PREFLIGHT":
            need(not args.output_root and not args.mirror_root, "PREFLIGHT accepts no result roots")
            result = {"schema": "argos_ocv03_candidate_first_front24_driver_preflight_v1", "state": "PASS_FRONT24_DRIVER_PREFLIGHT", "binding": binding, "runner": runner.preflight()}
        else:
            need(args.output_root and args.mirror_root, "RUN requires both result roots")
            output, mirror = Path(args.output_root), Path(args.mirror_root)
            need(not output.exists() and not mirror.exists(), "RUN result root is not create-new")
            runner.RUN_ROOT, runner.MIRROR_ROOT = output, mirror
            binding_path = output.with_name(output.name + ".BINDING.json")
            need(not binding_path.exists(), "RUN binding evidence is not create-new")
            binding.update({"outputRoot": str(output), "mirrorRoot": str(mirror)})
            with binding_path.open("xb") as stream:
                stream.write(canonical_json_bytes(binding))
            result = {"schema": "argos_ocv03_candidate_first_front24_driver_result_v1", "state": "COMPLETE_FRONT24_DRIVER_RUN", "binding": binding, "runner": runner.run(output, mirror)}
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0 if str(result["state"]).startswith(("PASS_", "COMPLETE_")) else 2
if __name__ == "__main__":
    raise SystemExit(main())
