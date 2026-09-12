#!/usr/bin/env python3
"""Keep native candidate support when the optional global R18 ridge is absent."""
from __future__ import annotations
import argparse
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from types import ModuleType
from typing import Any
HERE = Path(__file__).resolve().parent
R37_NAME = "AnnularUnwrapCandidateFirstOpenCvR37.py"
R37_SHA256 = "A73526B0483809553588E4472D3556CB363391A4CCFBFF05CC79295E4D24C86E"
R18_NAME = "AnnularUnwrapDiagnosticOpenCvR18.py"
R18_SHA256 = "510F75463E8494A67442AEACBB7A16F71FE7B307EFEA9231F7CDD7FF6FE34317"
class R40Error(RuntimeError):
    pass
def need(value: Any, message: str) -> None:
    if not value:
        raise R40Error(message)
def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()
def function_source(path: Path, name: str) -> str:
    source = path.read_text(encoding="utf-8")
    nodes = [node for node in ast.parse(source).body if isinstance(node, ast.FunctionDef) and node.name == name]
    need(len(nodes) == 1, f"Frozen function changed: {name}")
    value = ast.get_source_segment(source, nodes[0])
    need(value is not None, f"Frozen function source absent: {name}")
    return value
def load_module(path: Path, name: str) -> ModuleType:
    spec = importlib.util.spec_from_file_location(name, path)
    need(spec is not None and spec.loader is not None, f"Cannot load {path.name}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module
R37_PATH = (HERE / R37_NAME).resolve()
need(R37_PATH.is_file() and sha256_file(R37_PATH) == R37_SHA256, "Frozen R37 changed")
r37 = load_module(R37_PATH, "argos_annular_r37_for_r40")
R27_SHA256 = r37.R27_SHA256
R30_SHA256 = r37.R30_SHA256
COMPACT_RUNNER_SHA256 = r37.COMPACT_RUNNER_SHA256

OLD_INITIAL = '''    diagnostic.need(ridge_rows.size > 0, "R18 found no globally sustained outside-in transition ridge")
    ridge_row = int(ridge_rows[-1])
    search_offsets = offsets[search_indices].astype(np.float32)
    ridge_offset = float(search_offsets[ridge_row])
'''
NEW_INITIAL = '''    global _R40_LAST_TRANSITION_DIAGNOSTIC
    global_ridge_reference_passed = bool(ridge_rows.size > 0)
    ridge_row = int(ridge_rows[-1]) if global_ridge_reference_passed else None
    search_offsets = offsets[search_indices].astype(np.float32)
    ridge_offset = float(search_offsets[ridge_row]) if global_ridge_reference_passed else None
    _R40_LAST_TRANSITION_DIAGNOSTIC = {
        "globalReferencePassed": global_ridge_reference_passed,
        "minimumCoverageFraction": float(MINIMUM_GLOBAL_RIDGE_COVERAGE),
        "maximumObservedCoverageFraction": float(np.max(row_coverage)),
        "frontierSupportedCount": int(np.count_nonzero(absolute_supported)),
        "candidateLocalSupportRetained": True,
        "diagnosticOnly": True,
    }
'''
OLD_OUTER = '''    outer_lane = np.abs(search_offsets - ridge_offset) <= CIRCLE_TRACK_HALF_WIDTH_PX
    outer_peak = np.maximum(np.max(enhanced_contrast[outer_lane], axis=0), 0.0)
'''
NEW_OUTER = '''    outer_lane = (
        np.abs(search_offsets - ridge_offset) <= CIRCLE_TRACK_HALF_WIDTH_PX
        if global_ridge_reference_passed
        else np.zeros(search_offsets.shape, dtype=bool)
    )
    outer_peak = (
        np.maximum(np.max(enhanced_contrast[outer_lane], axis=0), 0.0)
        if global_ridge_reference_passed
        else np.zeros(enhanced_contrast.shape[1], dtype=np.float32)
    )
'''
OLD_RETURN = '''        "rowCoverage": row_coverage,
        "ridgeRow": ridge_row,
        "ridgeOffsetPx": ridge_offset,
'''
NEW_RETURN = '''        "rowCoverage": row_coverage,
        "globalRidgeReferencePassed": global_ridge_reference_passed,
        "globalRidgeMinimumCoverageFraction": float(MINIMUM_GLOBAL_RIDGE_COVERAGE),
        "globalRidgeMaximumObservedCoverageFraction": float(np.max(row_coverage)),
        "ridgeRow": ridge_row,
        "ridgeOffsetPx": ridge_offset,
'''
_ENGINE: ModuleType | None = None
_ORIGINAL_TRANSITION: Any = None
_TRANSFORMED_SHA256: str | None = None
_LAST_DIAGNOSTIC: dict[str, dict[str, Any]] = {}
def transformed_transition(path: Path) -> tuple[str, str]:
    source = function_source(path, "transition_map")
    corrected = source
    for old, new, label in ((OLD_INITIAL, NEW_INITIAL, "ridge gate"), (OLD_OUTER, NEW_OUTER, "outer lane"), (OLD_RETURN, NEW_RETURN, "ridge evidence")):
        need(corrected.count(old) == 1 and new not in corrected, f"Frozen R18 {label} changed")
        corrected = corrected.replace(old, new, 1)
    ast.parse(corrected)
    return corrected, hashlib.sha256(corrected.encode("utf-8")).hexdigest().upper()
def engine() -> ModuleType:
    global _ENGINE, _ORIGINAL_TRANSITION, _TRANSFORMED_SHA256
    if _ENGINE is not None:
        return _ENGINE
    loaded = r37.engine()
    r18 = loaded.r18
    path = Path(r18.__file__).resolve()
    need(path.name == R18_NAME and sha256_file(path) == R18_SHA256, "Loaded frozen R18 changed")
    corrected, _TRANSFORMED_SHA256 = transformed_transition(path)
    _ORIGINAL_TRANSITION = r18.transition_map
    exec(compile(corrected, str(path), "exec"), r18.__dict__)
    _ENGINE = loaded
    return loaded
def analyze_native_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    loaded = engine()
    channel = str(kwargs.get("channel", args[6] if len(args) > 6 else ""))
    need(channel in ("BF", "DF"), "Channel changed")
    if channel == "BF":
        _LAST_DIAGNOSTIC.clear()
    analysis = r37.analyze_native_strip(*args, **kwargs)
    diagnostic = dict(loaded.r18._R40_LAST_TRANSITION_DIAGNOSTIC)
    diagnostic["channel"] = channel
    analysis["candidateLocalTransitionDiagnostic"] = diagnostic
    _LAST_DIAGNOSTIC[channel] = diagnostic
    return analysis
def pair_after_channel_contours(*args: Any, **kwargs: Any) -> dict[str, Any]:
    need(set(_LAST_DIAGNOSTIC) == {"BF", "DF"}, "Both channel transition diagnostics were not completed")
    result = r37.pair_after_channel_contours(*args, **kwargs)
    result["candidateLocalTransitionDiagnostics"] = {key: dict(_LAST_DIAGNOSTIC[key]) for key in ("BF", "DF")}
    return result
def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return r37.channel_summary(*args, **kwargs)
def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
    return r37.public_candidate_records(*args, **kwargs)
def install_compact_review_hooks(runner: ModuleType) -> None:
    engine()
    r37.install_compact_review_hooks(runner)
def adapter_evidence() -> dict[str, Any]:
    engine()
    return {"schema": "argos_ocv03_annular_candidate_first_r40_local_transition_v1", "state": "PASS_R40_CANDIDATE_LOCAL_TRANSITION_ENABLED", "frozenR37Sha256": R37_SHA256, "frozenR18Sha256": R18_SHA256, "transformedTransitionMapSha256": _TRANSFORMED_SHA256, "globalRidgeThresholdChanged": False, "ridgePresentBehaviorChanged": False, "candidateLocalSupportRetainedWhenGlobalRidgeAbsent": True, "pixelsOrContoursCreated": False, "interpolationOrMorphologyPerformed": False, "reviewOnly": True}
def same_value(left: Any, right: Any, np: Any) -> bool:
    return bool(np.array_equal(left, right)) if isinstance(left, np.ndarray) else left == right
def self_test() -> dict[str, Any]:
    need(r37.self_test()["state"] == "PASS_R37_GLOBAL_NORMAL_TRACE_DIAGNOSTIC_ONLY_SELF_TEST", "R37 self-test changed")
    loaded = engine()
    np = loaded.np
    offsets = np.arange(-190.0, 61.0, dtype=np.float32)
    full = np.zeros((offsets.size, 256), dtype=np.uint8)
    full[offsets <= 0.0, :] = 220
    original = _ORIGINAL_TRANSITION(full, offsets)
    retained = loaded.r18.transition_map(full, offsets)
    need(retained["globalRidgeReferencePassed"] and all(same_value(value, retained[key], np) for key, value in original.items()), "Ridge-present behavior changed")
    partial = np.zeros_like(full)
    partial[offsets <= 0.0, :48] = 220
    try:
        _ORIGINAL_TRANSITION(partial, offsets)
    except Exception as exc:
        need("no globally sustained outside-in transition ridge" in str(exc), "Frozen no-ridge failure changed")
    else:
        need(False, "Synthetic local-only case unexpectedly met the frozen global ridge gate")
    local = loaded.r18.transition_map(partial, offsets)
    need(not local["globalRidgeReferencePassed"] and local["ridgeRow"] is None and local["ridgeOffsetPx"] is None, "No-ridge state changed")
    need(int(np.count_nonzero(local["frontierSupported"])) > 0 and not bool(np.any(local["outerSupported"])), "Local-only support was not retained exactly")
    return {"schema": "argos_ocv03_annular_candidate_first_r40_self_test_v1", "state": "PASS_R40_CANDIDATE_LOCAL_TRANSITION_SELF_TEST", "ridgePresentBehaviorExact": True, "localSupportRetainedBelowGlobalRidgeReference": True, "globalRidgeThresholdChanged": False, "pixelsOrContoursCreated": False, "mutationsPerformed": False}
def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("ADAPTER_CHECK", "EVIDENCE", "SELF_TEST"))
    args = parser.parse_args()
    value = self_test() if args.stage == "SELF_TEST" else adapter_evidence()
    print(json.dumps(value, sort_keys=True, separators=(",", ":")))
    return 0
if __name__ == "__main__":
    raise SystemExit(main())
