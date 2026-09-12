#!/usr/bin/env python3
"""Record inherited whole-circle normal-trace references without run aborts."""
from __future__ import annotations
import argparse, ast, hashlib, importlib.util, json, sys
from pathlib import Path
from types import ModuleType
from typing import Any

HERE = Path(__file__).resolve().parent
R36_NAME = "AnnularUnwrapCandidateFirstOpenCvR36.py"
R36_SHA256 = "F2546537CD290EF7DB7B0B5812C9D1333EA1951FD698BC870C0D5C625C5F2C2C"
R18_NAME = "AnnularUnwrapDiagnosticOpenCvR18.py"; R18_SHA256 = "510F75463E8494A67442AEACBB7A16F71FE7B307EFEA9231F7CDD7FF6FE34317"
class R37Error(RuntimeError): pass
def need(value: Any, message: str) -> None:
    if not value: raise R37Error(message)
def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""): digest.update(block)
    return digest.hexdigest().upper()
def _function_source(path: Path, name: str) -> str:
    source = path.read_text(encoding="utf-8"); tree = ast.parse(source)
    nodes = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == name]
    need(len(nodes) == 1, f"Frozen function changed: {name}")
    value = ast.get_source_segment(source, nodes[0]); need(value is not None, f"Frozen function source absent: {name}")
    return value
def _load_r36() -> ModuleType:
    path = (HERE / R36_NAME).resolve()
    need(path.is_file() and sha256_file(path) == R36_SHA256, "Frozen R36 changed")
    spec = importlib.util.spec_from_file_location("argos_annular_r36_for_r37", path)
    need(spec is not None and spec.loader is not None, "Cannot load frozen R36")
    module = importlib.util.module_from_spec(spec); sys.modules[spec.name] = module
    spec.loader.exec_module(module); return module
r36 = _load_r36()
R27_SHA256 = r36.R27_SHA256; R30_SHA256 = r36.R30_SHA256
COMPACT_RUNNER_SHA256 = r36.COMPACT_RUNNER_SHA256
_OLD_GATES = '''    need(
        edge["normalObservedFraction"] >= r18.MINIMUM_BEVEL_TRACE_COVERAGE,
        "R27 normal brightness trace coverage is below the inherited gate",
    )
    need(
        edge["normalMaximumAdjacentStepPx"] is not None
        and edge["normalMaximumAdjacentStepPx"] <= r18.BEVEL_TRACE_MAX_ADJACENT_STEP_PX,
        "R27 normal brightness trace retains a discontinuity",
    )
'''
_NEW_GATES = '''    normal_coverage_reference_passed = bool(
        edge["normalObservedFraction"] >= r18.MINIMUM_BEVEL_TRACE_COVERAGE
    )
    normal_continuity_reference_passed = bool(
        edge["normalMaximumAdjacentStepPx"] is not None
        and edge["normalMaximumAdjacentStepPx"] <= r18.BEVEL_TRACE_MAX_ADJACENT_STEP_PX
    )
'''
_OLD_EVIDENCE = '''            "normalBrightnessTraceObservedFraction": edge["normalObservedFraction"],
'''
_NEW_EVIDENCE = '''            "normalBrightnessTraceObservedFraction": edge["normalObservedFraction"],
            "normalBrightnessTraceMinimumCoverageFraction": float(r18.MINIMUM_BEVEL_TRACE_COVERAGE),
            "normalBrightnessTraceCoverageReferencePassed": normal_coverage_reference_passed,
            "normalBrightnessTraceContinuityReferencePassed": normal_continuity_reference_passed,
            "normalBrightnessTraceSampleCount": int(edge["normalObserved"].size),
            "normalBrightnessTraceObservedCount": int(np.count_nonzero(edge["normalObserved"])),
            "normalBrightnessTraceMaximumMissingRunSamples": int(edge["normalMaximumMissingRunSamples"]),
            "normalBrightnessTraceDiscontinuityHeldColumnCount": int(edge["normalDiscontinuityHeldColumnCount"]),
            "normalBrightnessTraceMaximumAdjacentStepPx": edge["normalMaximumAdjacentStepPx"],
            "normalBrightnessTraceMaximumAdjacentStepPxAllowed": float(r18.BEVEL_TRACE_MAX_ADJACENT_STEP_PX),
            "normalBrightnessTraceCandidateFractionBeforeConsistency": edge["normalCandidateFractionBeforeConsistency"],
            "normalBrightnessTraceCalibratedCandidateFraction": edge["normalCalibratedCandidateFraction"],
'''
_ENGINE: ModuleType | None = None; _TRANSFORMED_SHA256: str | None = None
_LAST_DIAGNOSTIC: dict[str, dict[str, Any]] = {}
def engine() -> ModuleType:
    global _ENGINE, _TRANSFORMED_SHA256
    if _ENGINE is not None: return _ENGINE
    loaded = r36.engine(); path = Path(loaded.__file__).resolve()
    need(sha256_file(path) == R27_SHA256, "Frozen R27 changed")
    source = _function_source(path, "analyze_native_strip")
    need(source.count(_OLD_GATES) == 1 and source.count(_OLD_EVIDENCE) == 1, "Frozen R27 normal-trace gates changed")
    transformed = source.replace(_OLD_GATES, _NEW_GATES, 1).replace(_OLD_EVIDENCE, _NEW_EVIDENCE, 1)
    _TRANSFORMED_SHA256 = hashlib.sha256(transformed.encode()).hexdigest().upper()
    exec(compile(transformed, str(path), "exec"), loaded.__dict__)
    _ENGINE = loaded; return loaded
def _array_sha(value: Any) -> str:
    array = engine().np.ascontiguousarray(value)
    return hashlib.sha256(array.tobytes(order="C")).hexdigest().upper()
def analyze_native_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    engine(); analysis = r36.analyze_native_strip(*args, **kwargs)
    channel = str(kwargs.get("channel", args[6] if len(args) > 6 else "")); need(channel in ("BF", "DF"), "Channel changed")
    if channel == "BF": _LAST_DIAGNOSTIC.clear()
    evidence = analysis["evidence"]; flags = []
    if not bool(evidence["normalBrightnessTraceCoverageReferencePassed"]): flags.append("GLOBAL_NORMAL_TRACE_COVERAGE_BELOW_INHERITED_REFERENCE")
    if not bool(evidence["normalBrightnessTraceContinuityReferencePassed"]): flags.append("GLOBAL_NORMAL_TRACE_CONTINUITY_BELOW_INHERITED_REFERENCE")
    diagnostic = {key: evidence[key] for key in (
        "normalBrightnessTraceObservedFraction", "normalBrightnessTraceMinimumCoverageFraction",
        "normalBrightnessTraceCoverageReferencePassed", "normalBrightnessTraceContinuityReferencePassed",
        "normalBrightnessTraceSampleCount", "normalBrightnessTraceObservedCount",
        "normalBrightnessTraceMaximumMissingRunSamples", "normalBrightnessTraceDiscontinuityHeldColumnCount",
        "normalBrightnessTraceMaximumAdjacentStepPx", "normalBrightnessTraceMaximumAdjacentStepPxAllowed", "normalBrightnessTraceCandidateFractionBeforeConsistency",
        "normalBrightnessTraceCalibratedCandidateFraction")}
    diagnostic.update({"channel": channel, "globalReferencePassed": not flags, "diagnosticFlags": flags,
                       "normalObservedMapSha256": _array_sha(analysis["normalBrightnessObserved"]),
                       "normalPathSha256": _array_sha(analysis["normalBrightnessPath"]),
                       "diagnosticOnly": True, "candidateEligibilityChanged": False,
                       "thresholdChanged": False, "hardFailurePerformed": False})
    analysis["normalBrightnessTraceDiagnostic"] = diagnostic; _LAST_DIAGNOSTIC[channel] = diagnostic
    return analysis
def pair_after_channel_contours(*args: Any, **kwargs: Any) -> dict[str, Any]:
    need(set(_LAST_DIAGNOSTIC) == {"BF", "DF"}, "Both channel diagnostics were not completed")
    result = r36.pair_after_channel_contours(*args, **kwargs)
    result["normalBrightnessTraceDiagnostics"] = {key: dict(_LAST_DIAGNOSTIC[key]) for key in ("BF", "DF")}
    result["normalBrightnessTraceBelowGlobalReferenceChannels"] = [key for key in ("BF", "DF") if not _LAST_DIAGNOSTIC[key]["globalReferencePassed"]]
    result["normalBrightnessTraceThresholdChanged"] = False; return result
def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]: return r36.channel_summary(*args, **kwargs)
def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]: return r36.public_candidate_records(*args, **kwargs)
def install_compact_review_hooks(runner: ModuleType) -> None: engine(); r36.install_compact_review_hooks(runner)
def adapter_evidence() -> dict[str, Any]:
    engine(); return {"schema": "argos_ocv03_annular_candidate_first_r37_global_trace_diagnostic_v1",
        "state": "PASS_R37_GLOBAL_NORMAL_TRACE_REFERENCE_RECORDED_DIAGNOSTIC_ONLY",
        "frozenR36Sha256": R36_SHA256, "transformedAnalyzeNativeStripSha256": _TRANSFORMED_SHA256,
        "minimumCoverageChanged": False, "selectedNativeContoursChanged": False,
        "pixelsChanged": False, "circleGeometryChanged": False,
        "candidateLocalQualificationChanged": False, "notchOwnershipGranted": False, "reviewOnly": True}
def self_test() -> dict[str, Any]:
    need(r36.self_test()["state"] == "PASS_R36_COMPLETE_NOMINAL_LANE_SELF_TEST", "R36 self-test changed")
    r27_path = HERE / "AnnularUnwrapCandidateFirstOpenCvR27.py"; need(sha256_file(r27_path) == R27_SHA256, "Frozen R27 changed")
    source = _function_source(r27_path, "analyze_native_strip"); need(source.count(_OLD_GATES) == 1 and source.count(_OLD_EVIDENCE) == 1, "Frozen R27 normal-trace gates changed")
    ast.parse(source.replace(_OLD_GATES, _NEW_GATES, 1).replace(_OLD_EVIDENCE, _NEW_EVIDENCE, 1))
    need("engine(); analysis = r36.analyze_native_strip" in Path(__file__).read_text(encoding="utf-8"), "Inherited R36 wrapper chain bypassed")
    r18_path = HERE / R18_NAME; need(sha256_file(r18_path) == R18_SHA256 and "MINIMUM_BEVEL_TRACE_COVERAGE = 0.85" in r18_path.read_text(encoding="utf-8"), "Inherited coverage threshold changed")
    return {"schema": "argos_ocv03_annular_candidate_first_r37_self_test_v1",
            "state": "PASS_R37_GLOBAL_NORMAL_TRACE_DIAGNOSTIC_ONLY_SELF_TEST",
            "inheritedCoverageThreshold": 0.85, "thresholdChanged": False,
            "candidateEligibilityChanged": False, "pixelsOrContoursChanged": False, "mutationsPerformed": False}
def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("stage", choices=("ADAPTER_CHECK", "EVIDENCE", "SELF_TEST"))
    args = parser.parse_args(); value = self_test() if args.stage == "SELF_TEST" else adapter_evidence()
    print(json.dumps(value, sort_keys=True, separators=(",", ":"))); return 0
if __name__ == "__main__": raise SystemExit(main())
