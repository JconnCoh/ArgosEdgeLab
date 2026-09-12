#!/usr/bin/env python3
"""Render compact full-circle evidence at truthful equal-axis scale."""
from __future__ import annotations
import argparse, hashlib, importlib.util, json, math, sys
from pathlib import Path
from types import ModuleType
from typing import Any

HERE = Path(__file__).resolve().parent
R41_NAME = "AnnularUnwrapCandidateFirstOpenCvR41.py"
R41_SHA256 = "59B8057BCF0D1BE9ED9C4ADEA4B9A1C85EC8713C9E725DFF3BDAB19E405F7E74"
SEMANTIC_COLORS = ((255, 255, 0), (0, 255, 255), (0, 255, 0), (0, 128, 255), (0, 0, 255))

class R42Error(RuntimeError): pass
def need(value: Any, message: str) -> None:
    if not value: raise R42Error(message)
def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""): digest.update(block)
    return digest.hexdigest().upper()
def load(path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("argos_annular_r41_for_r42", path)
    need(spec is not None and spec.loader is not None, "Cannot load frozen R41")
    module = importlib.util.module_from_spec(spec); sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module

R41_PATH = (HERE / R41_NAME).resolve()
need(R41_PATH.is_file() and sha256_file(R41_PATH) == R41_SHA256, "Frozen R41 changed")
r41 = load(R41_PATH)
R27_SHA256 = r41.R27_SHA256; R30_SHA256 = r41.R30_SHA256
COMPACT_RUNNER_SHA256 = r41.COMPACT_RUNNER_SHA256
_HOOKED_RUNNERS: set[int] = set()

def engine() -> ModuleType: return r41.engine()
def sampling_plan(shape: tuple[int, ...], maximum_columns: int) -> dict[str, int]:
    height, width = int(shape[0]), int(shape[1])
    legacy_stride = max(1, math.ceil(width / maximum_columns))
    stride = max(1, math.ceil(math.sqrt(legacy_stride)))
    sampled_rows, sampled_columns = math.ceil(height / stride), math.ceil(width / stride)
    sectors = math.ceil(sampled_columns / maximum_columns)
    return {"stride": stride, "sampledRowsPerSector": sampled_rows,
            "sampledColumns": sampled_columns, "sectorCount": sectors,
            "outputColumns": min(maximum_columns, sampled_columns),
            "rightPaddingPixels": sectors * maximum_columns - sampled_columns if sectors > 1 else 0}
def isometric_decimate(image: Any, maximum_columns: int) -> tuple[Any, int]:
    np = engine().np; plan = sampling_plan(image.shape, maximum_columns); stride = plan["stride"]
    rows = np.arange(0, image.shape[0], stride); columns = np.arange(0, image.shape[1], stride)
    sampled = np.ascontiguousarray(image[::stride, ::stride]).copy()
    colors = () if np.array_equal(image[..., 0], image[..., 1]) and np.array_equal(image[..., 1], image[..., 2]) else SEMANTIC_COLORS
    for color in colors:  # Last is red, so selected evidence wins overlap.
        exact = np.all(image == np.asarray(color, dtype=image.dtype), axis=2)
        occupied = np.logical_or.reduceat(np.logical_or.reduceat(exact, rows, axis=0), columns, axis=1)
        sampled[occupied] = color
    if plan["sectorCount"] == 1: return sampled, stride
    result = np.zeros((plan["sampledRowsPerSector"] * plan["sectorCount"],
                       maximum_columns, image.shape[2]), dtype=image.dtype)
    for sector in range(plan["sectorCount"]):
        source = sampled[:, sector * maximum_columns:(sector + 1) * maximum_columns]
        start = sector * plan["sampledRowsPerSector"]
        result[start:start + plan["sampledRowsPerSector"], :source.shape[1]] = source
    return result, stride
def ordered_traces(analysis: dict[str, Any], channel: str) -> list[dict[str, Any]]:
    selected = r41._SELECTED[channel]
    return sorted(analysis["candidateTraces"],
                  key=lambda trace: int(trace["record"]["candidateIndex"]) in selected)

def analyze_native_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    engine(); install_running_review_hook()
    return r41.analyze_native_strip(*args, **kwargs)
def pair_after_channel_contours(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return r41.pair_after_channel_contours(*args, **kwargs)
def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return r41.channel_summary(*args, **kwargs)
def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
    return r41.public_candidate_records(*args, **kwargs)

def install_compact_review_hooks(runner: ModuleType) -> None:
    r41.install_compact_review_hooks(runner)
    old_overlay, old_header, old_render = runner.channel_overlay, runner.header, runner.render_bounded
    def overlay(loaded: Any, analysis: dict[str, Any]) -> tuple[Any, Any, Any]:
        traces = analysis["candidateTraces"]
        if not traces: return old_overlay(loaded, analysis)
        shadow = dict(analysis); channel = str(traces[0]["record"]["channel"])
        shadow["candidateTraces"] = ordered_traces(analysis, channel)
        return old_overlay(loaded, shadow)
    def header(image: Any, label: str) -> Any:
        label = label.replace("global preview point-decimated; use native crop for shape",
                              "global preview equal-scale sectors top-to-bottom; native crop preserves detail")
        return old_header(image, label)
    def render(*args: Any, **kwargs: Any) -> dict[str, Any]:
        assets = old_render(*args, **kwargs)
        analyses = args[3] if len(args) > 3 else kwargs["analyses"]
        plans = {channel: sampling_plan(analyses[channel]["strip"].shape,
                                        runner.MAX_OVERVIEW_COLUMNS) for channel in ("BF", "DF")}
        assets.update({"overviewRadialDecimation": {key: value["stride"] for key, value in plans.items()},
                       "overviewSequentialEqualScaleSectors": plans,
                       "overviewEqualAxisScalePreserved": True,
                       "overviewSemanticColorOccupancyPreservedForDisplay": True,
                       "nativeCandidateCropRemainsShapeAuthority": True})
        return assets
    runner.channel_overlay, runner.header = overlay, header
    runner.decimate_columns, runner.render_bounded = isometric_decimate, render

def install_running_review_hook() -> bool:
    candidates = [module for module in list(sys.modules.values()) if isinstance(module, ModuleType)
                  and Path(str(getattr(module, "__file__", ""))).name == "Run-O3F16R28FullKlarfReview.py"
                  and hasattr(module, "render_bounded")
                  and Path(str(getattr(module, "ADAPTER_PATH", ""))).resolve() == Path(__file__).resolve()]
    need(len(candidates) <= 1, "Multiple bound compact review runners are active")
    if not candidates: return False
    runner = candidates[0]
    if id(runner) not in _HOOKED_RUNNERS:
        install_compact_review_hooks(runner); _HOOKED_RUNNERS.add(id(runner))
    return True

def adapter_evidence() -> dict[str, Any]:
    engine()
    return {"schema": "argos_ocv03_annular_candidate_first_r42_review_geometry_v1",
            "state": "PASS_R42_EQUAL_AXIS_REVIEW_GEOMETRY_ENABLED", "frozenR41Sha256": R41_SHA256,
            "overviewSampling": "EQUAL_RADIAL_AND_ANGULAR_BLOCK_STRIDE_IN_SEQUENTIAL_SECTORS",
            "semanticColorOccupancyPreservedForDisplay": True, "selectedTraceDrawnLast": True,
            "candidatePixelsOrPairingChanged": False, "interpolationPerformed": False, "reviewOnly": True}
def self_test() -> dict[str, Any]:
    need(r41.self_test()["state"] == "PASS_R41_FIXED_LANE_AND_MACRO_PAIR_SELF_TEST", "R41 self-test changed")
    np = engine().np; sample = np.zeros((24, 20, 3), dtype=np.uint8)
    for point, color in zip(((1, 1), (1, 3), (3, 1)), SEMANTIC_COLORS): sample[point] = color
    sample[2, 2] = SEMANTIC_COLORS[3]; sample[3, 3] = SEMANTIC_COLORS[4]
    reduced, stride = isometric_decimate(sample, 6); plan = sampling_plan(sample.shape, 6)
    need(stride == 2 and reduced.shape == (24, 6, 3) and plan["sectorCount"] == 2,
         "Equal-axis sector geometry changed")
    for color in (*SEMANTIC_COLORS[:3], SEMANTIC_COLORS[4]):
        need(bool(np.any(np.all(reduced == color, axis=2))), f"Semantic color {color} disappeared")
    need(not bool(np.any(np.all(reduced == SEMANTIC_COLORS[3], axis=2))), "Red did not win shared block")
    traces = [{"record": {"candidateIndex": value}} for value in (1, 0, 2)]
    r41._SELECTED["BF"] = {1}
    need([row["record"]["candidateIndex"] for row in ordered_traces({"candidateTraces": traces}, "BF")]
         == [0, 2, 1], "Selected trace is not last")
    return {"schema": "argos_ocv03_annular_candidate_first_r42_self_test_v1",
            "state": "PASS_R42_REVIEW_GEOMETRY_SELF_TEST", "equalAxisShape": list(reduced.shape),
            "sectorCount": plan["sectorCount"], "semanticColorsRetained": 4,
            "redPriorityOnSharedDisplayBlock": True, "selectedTraceDrawnLast": True,
            "candidatePixelsOrPairingChanged": False, "sourceImageBytesRead": False,
            "mutationsPerformed": False}
def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("stage", choices=("ADAPTER_CHECK", "EVIDENCE", "SELF_TEST"))
    args = parser.parse_args(); value = self_test() if args.stage == "SELF_TEST" else adapter_evidence()
    print(json.dumps(value, sort_keys=True, separators=(",", ":"))); return 0
if __name__ == "__main__": raise SystemExit(main())
