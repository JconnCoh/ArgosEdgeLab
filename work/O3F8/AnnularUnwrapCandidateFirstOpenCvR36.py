#!/usr/bin/env python3
"""Keep nominal reference selection inside its already-required full tracking lane.

R36 preserves R34 candidate, contour, pairing, and landmark semantics. It
restricts nominal-row selection to rows where the unchanged +/-12 px tracking
lane fits inside the unchanged fixed-fit core. No pixels are synthesized,
interpolated, morphed, or transferred between channels by this correction.
"""
from __future__ import annotations
import argparse, ast, hashlib, importlib.util, inspect, json
from pathlib import Path
import sys
from types import ModuleType
from typing import Any

HERE = Path(__file__).resolve().parent
R34_NAME = "AnnularUnwrapCandidateFirstOpenCvR34.py"
R34_SHA256 = "35B28C6CAE8EBB7DDFD8D75D73FDFD8D8A8F04739F56520B1F7CD4A10A58100B"
R10_NAME = "AnnularUnwrapDiagnosticOpenCvR10.py"
R10_SHA256 = "6B28925E04839D411838CB3D6C7D39E523AFC3AE89EDBAC83034351D27ED814C"
class R36Error(RuntimeError): pass
def need(value: Any, message: str) -> None:
    if not value: raise R36Error(message)
def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""): digest.update(block)
    return digest.hexdigest().upper()
def _load_r34() -> ModuleType:
    path = (HERE / R34_NAME).resolve()
    need(path.is_file() and sha256_file(path) == R34_SHA256, "Frozen R34 changed")
    spec = importlib.util.spec_from_file_location("argos_annular_r34_for_r36", path)
    need(spec is not None and spec.loader is not None, "Cannot load frozen R34")
    module = importlib.util.module_from_spec(spec); sys.modules[spec.name] = module
    spec.loader.exec_module(module); return module
r34 = _load_r34()
R27_SHA256 = r34.R27_SHA256; R30_SHA256 = r34.R30_SHA256
COMPACT_RUNNER_SHA256 = r34.COMPACT_RUNNER_SHA256
_OLD = """    row_scores = row_response + nominal_floor * row_support
    nominal_ties = np.flatnonzero(np.isclose(row_scores, np.max(row_scores)))
"""
_NEW = """    row_scores = row_response + nominal_floor * row_support
    full_lane_centers = (
        (core_offsets - REFERENCE_TRACK_RADIUS_PX >= -REFERENCE_CORE_INWARD_PX)
        & (core_offsets + REFERENCE_TRACK_RADIUS_PX <= REFERENCE_CORE_OUTWARD_PX)
    )
    need(bool(np.any(full_lane_centers)), "Fixed-fit core contains no complete tracking lane")
    nominal_scores = np.where(full_lane_centers, row_scores, -np.inf)
    nominal_ties = np.flatnonzero(np.isclose(nominal_scores, np.max(nominal_scores)))
"""
_ENGINE: ModuleType | None = None; _DIAGNOSTIC: ModuleType | None = None
_FROZEN_CYCLIC_PATH: Any = None; _TRANSFORMED_SHA256: str | None = None
def engine() -> ModuleType:
    global _ENGINE, _DIAGNOSTIC, _FROZEN_CYCLIC_PATH, _TRANSFORMED_SHA256
    if _ENGINE is not None: return _ENGINE
    loaded = r34.engine(); diagnostic = loaded.r18.diagnostic
    path = (HERE / R10_NAME).resolve()
    need(path.name == R10_NAME and sha256_file(path) == R10_SHA256, "Frozen R10 changed")
    source = inspect.getsource(diagnostic.cyclic_path)
    need(source.count(_OLD) == 1 and _NEW not in source, "Frozen R10 selector structure changed")
    _FROZEN_CYCLIC_PATH = diagnostic.cyclic_path
    transformed = source.replace(_OLD, _NEW, 1)
    _TRANSFORMED_SHA256 = hashlib.sha256(transformed.encode()).hexdigest().upper()
    exec(compile(transformed, str(path), "exec"), diagnostic.__dict__)
    need(diagnostic.cyclic_path is not _FROZEN_CYCLIC_PATH, "R36 correction was not installed")
    _ENGINE, _DIAGNOSTIC = loaded, diagnostic; return loaded
def analyze_native_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    engine(); return r34.analyze_native_strip(*args, **kwargs)
def pair_after_channel_contours(*args: Any, **kwargs: Any) -> dict[str, Any]:
    engine(); return r34.pair_after_channel_contours(*args, **kwargs)
def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]:
    engine(); return r34.channel_summary(*args, **kwargs)
def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
    engine(); return r34.public_candidate_records(*args, **kwargs)
def install_compact_review_hooks(runner: ModuleType) -> None:
    engine(); r34.install_compact_review_hooks(runner)
def adapter_evidence() -> dict[str, Any]:
    engine()
    return {"schema": "argos_ocv03_annular_candidate_first_r36_complete_nominal_lane_v1",
            "state": "PASS_R36_NOMINAL_SELECTION_RESTRICTED_TO_COMPLETE_FIXED_CORE_LANE",
            "frozenR34Sha256": R34_SHA256, "frozenR10Sha256": R10_SHA256,
            "transformedCyclicPathSha256": _TRANSFORMED_SHA256,
            "fixedFitCoreChanged": False, "trackingRadiusChanged": False,
            "selectedNativeContoursOtherwiseChanged": False,
            "pixelsSynthesizedOrTransferred": False, "notchOwnershipGranted": False,
            "reviewOnly": True, "productionEligible": False}
def self_test() -> dict[str, Any]:
    import cv2, numpy as np
    source_bytes = (HERE / R10_NAME).read_bytes()
    need(hashlib.sha256(source_bytes).hexdigest().upper() == R10_SHA256, "Frozen R10 changed")
    source = source_bytes.decode("utf-8")
    tree = ast.parse(source); functions = {node.name: node for node in tree.body if isinstance(node, ast.FunctionDef)}
    assignments = [node for node in tree.body if isinstance(node, (ast.Assign, ast.AnnAssign))
                   and any(isinstance(name, ast.Name) and name.id.startswith("REFERENCE_")
                           for name in ([*node.targets] if isinstance(node, ast.Assign) else [node.target]))]
    scope = {"np": np, "cv2": cv2, "Any": Any}
    exec(compile(ast.Module(body=assignments + [functions["need"], functions["runs"]], type_ignores=[]), R10_NAME, "exec"), scope)
    cyclic_source = ast.get_source_segment(source, functions["cyclic_path"]); need(cyclic_source is not None, "R10 cyclic source absent")
    exec(compile(cyclic_source, R10_NAME, "exec"), scope); frozen_cyclic_path = scope["cyclic_path"]
    need(cyclic_source.count(_OLD) == 1, "Frozen R10 selector structure changed")
    exec(compile(cyclic_source.replace(_OLD, _NEW, 1), R10_NAME, "exec"), scope); corrected_cyclic_path = scope["cyclic_path"]
    offsets = np.arange(-40.0, 25.0, dtype=np.float32); columns = 96
    interior = np.zeros((offsets.size, columns), dtype=np.float32)
    interior[np.flatnonzero(offsets == 0.0)[0], :] = 100.0
    old_path, old_measured, old_evidence = frozen_cyclic_path(interior, offsets, 10.0, 0.35, 1.0)
    new_path, new_measured, new_evidence = corrected_cyclic_path(interior, offsets, 10.0, 0.35, 1.0)
    need(np.array_equal(old_path, new_path) and np.array_equal(old_measured, new_measured), "Valid-lane behavior changed")
    need(old_evidence == new_evidence, "Valid-lane evidence changed")
    boundary = interior.copy(); boundary[np.flatnonzero(offsets == 16.0)[0], :] = 200.0
    frozen_failed = False
    try: frozen_cyclic_path(boundary, offsets, 10.0, 0.35, 1.0)
    except RuntimeError as error:
        frozen_failed = str(error) == "Nominal reference tracking lane is truncated by the fixed-fit core"
    need(frozen_failed, "Synthetic boundary case did not reproduce frozen failure")
    path, measured, evidence = corrected_cyclic_path(boundary, offsets, 10.0, 0.35, 1.0)
    need(float(evidence["nominalReferenceOffsetPx"]) == 0.0, "Strongest complete-lane row not selected")
    need(bool(np.all(path == 0.0)) and bool(np.all(measured)), "Boundary reference was not directly measured")
    return {"schema": "argos_ocv03_annular_candidate_first_r36_self_test_v1",
            "state": "PASS_R36_COMPLETE_NOMINAL_LANE_SELF_TEST",
            "validLaneOutputAndEvidenceUnchanged": True,
            "frozenBoundaryFailureReproduced": True, "boundaryFallbackInterpolated": False,
            "mutationsPerformed": False}
def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("stage", choices=("ADAPTER_CHECK", "EVIDENCE", "SELF_TEST"))
    args = parser.parse_args(); value = self_test() if args.stage == "SELF_TEST" else adapter_evidence()
    print(json.dumps(value, sort_keys=True, separators=(",", ":"))); return 0
if __name__ == "__main__": raise SystemExit(main())
