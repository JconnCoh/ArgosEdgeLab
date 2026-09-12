#!/usr/bin/env python3
"""Reseed a held channel circle, then require the unchanged R18 final gate."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys
from types import ModuleType
from typing import Any

HERE = Path(__file__).resolve().parent
R42_NAME = "AnnularUnwrapCandidateFirstOpenCvR42.py"
R42_SHA256 = "E8F1E20AC4EBD28D3A7D9A5C0E5CA1B8FA32BA645C36294C6D826DF216AF9195"
RESCUE_SEARCH_MIN_OFFSET_PX = -120.0
RESCUE_SEARCH_MAX_OFFSET_PX = 43.0
RESCUE_GUARD_MIN_OFFSET_PX = 47.0
RESCUE_GUARD_MAX_OFFSET_PX = 55.0
RESCUE_MINIMUM_CIRCLE_COVERAGE = 0.50


class R43Error(RuntimeError):
    pass


def need(value: Any, message: str) -> None:
    if not value:
        raise R43Error(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load(path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("argos_annular_r42_for_r43", path)
    need(spec is not None and spec.loader is not None, "Cannot load frozen R42")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


R42_PATH = (HERE / R42_NAME).resolve()
need(R42_PATH.is_file() and sha256_file(R42_PATH) == R42_SHA256, "Frozen R42 changed")
r42 = load(R42_PATH)
R27_SHA256 = r42.R27_SHA256
R30_SHA256 = r42.R30_SHA256
COMPACT_RUNNER_SHA256 = r42.COMPACT_RUNNER_SHA256
_ENGINE: ModuleType | None = None
_ORIGINAL_UNWRAP: Any = None
_RESCUE_EXTERIOR: Any = None
_RESCUE_FIT: Any = None
_PENDING: dict[int, tuple[Any, dict[str, Any], dict[str, Any]]] = {}
_HELD_REVIEW_IDS: set[str] = set()
_HOOKED_RUNNERS: set[int] = set()


def circle_check(r18: ModuleType, measured: dict[str, Any], fit: dict[str, Any]) -> dict[str, Any]:
    exterior = r18.exterior_connected_map(measured["strip"], measured["offsets"])
    circle = r18.fit_guarded_outer_circle(r18.outer_circle_candidates(exterior), fit)
    seed = circle["fit"]["outerBandSeedOffsetPx"]
    headroom = None if seed is None else float(r18.EXTERIOR_SEARCH_MAX_OFFSET_PX - seed)
    circle["cyanVerified"] = bool(
        circle["qualified"]
        and headroom is not None
        and headroom >= r18.MINIMUM_CYAN_SEARCH_HEADROOM_PX
        and float(circle["fit"]["angularCoverageFraction"])
        >= r18.MINIMUM_CYAN_ACCEPTED_COVERAGE
    )
    return circle


def rescue_seed(
    r18: ModuleType, measured: dict[str, Any], fit: dict[str, Any], params: Any
) -> dict[str, Any] | None:
    try:
        exterior = _RESCUE_EXTERIOR(measured["strip"], measured["offsets"])
    except (ValueError, RuntimeError):
        return None
    frontier, observed = r18.outermost_frontier(exterior["supported"], exterior["searchOffsets"])
    observed &= frontier < RESCUE_SEARCH_MAX_OFFSET_PX
    columns = r18.np.flatnonzero(observed)
    coverage = r18.angular_coverage(columns, r18.np.ones(columns.size, dtype=bool), frontier.size)
    if coverage < RESCUE_MINIMUM_CIRCLE_COVERAGE:
        return None
    ridge = float(r18.np.median(frontier[observed]))
    try:
        seeded = _RESCUE_FIT(
            exterior["supported"], exterior["searchOffsets"], fit, params, ridge
        )
    except (ValueError, RuntimeError):
        return None
    row = seeded["fit"]
    displacement = math.hypot(
        float(row["centerX"]) - float(fit["centerX"]),
        float(row["centerY"]) - float(fit["centerY"]),
    )
    radius_delta = float(row["radius"]) - float(fit["radius"])
    bounded = (
        seeded["qualified"]
        and math.isfinite(displacement)
        and displacement <= abs(RESCUE_SEARCH_MIN_OFFSET_PX)
        and math.isfinite(radius_delta)
        and abs(radius_delta) <= abs(RESCUE_SEARCH_MIN_OFFSET_PX)
    )
    if not bounded:
        return None
    return {
        "fit": {**fit, "centerX": float(row["centerX"]), "centerY": float(row["centerY"]),
                "radius": float(row["radius"])},
        "seedCoverageFraction": coverage,
        "seedCenterDisplacementPx": displacement,
        "seedRadiusDeltaPx": radius_delta,
        "seedFit": row,
    }


def engine() -> ModuleType:
    global _ENGINE, _ORIGINAL_UNWRAP, _RESCUE_EXTERIOR, _RESCUE_FIT
    if _ENGINE is not None:
        return _ENGINE
    loaded = r42.engine()
    r18 = loaded.r18
    _ORIGINAL_UNWRAP = r18.r13.unwrap
    path = Path(r18.__file__).resolve()
    exterior_scope = dict(r18.__dict__)
    exterior_scope.update({
        "EXTERIOR_SEARCH_MIN_OFFSET_PX": RESCUE_SEARCH_MIN_OFFSET_PX,
        "EXTERIOR_SEARCH_MAX_OFFSET_PX": RESCUE_SEARCH_MAX_OFFSET_PX,
        "EXTERIOR_GUARD_MIN_OFFSET_PX": RESCUE_GUARD_MIN_OFFSET_PX,
        "EXTERIOR_GUARD_MAX_OFFSET_PX": RESCUE_GUARD_MAX_OFFSET_PX,
    })
    fit_scope = dict(r18.__dict__)
    fit_scope["MINIMUM_CIRCLE_COVERAGE"] = RESCUE_MINIMUM_CIRCLE_COVERAGE
    for name, scope in (("exterior_connected_map", exterior_scope),
                        ("fit_physical_circle", fit_scope)):
        source = r42.r41.r40.function_source(path, name)
        exec(compile(source, str(path), "exec"), scope)
    _RESCUE_EXTERIOR = exterior_scope["exterior_connected_map"]
    _RESCUE_FIT = fit_scope["fit_physical_circle"]

    def unwrap(gray: Any, fit: dict[str, Any], crop: dict[str, Any], params: Any,
               cfg: dict[str, Any]) -> dict[str, Any]:
        measured = _ORIGINAL_UNWRAP(gray, fit, crop, params, cfg)
        legacy = circle_check(r18, measured, fit)
        if legacy["qualified"] and legacy["cyanVerified"]:
            return measured
        seed = rescue_seed(r18, measured, fit, params)
        if seed is None:
            return measured
        corrected = _ORIGINAL_UNWRAP(gray, seed["fit"], crop, params, cfg)
        final = circle_check(r18, corrected, seed["fit"])
        if not final["qualified"] or not final["cyanVerified"]:
            return measured
        evidence = {
            "state": "PASS_R43_CHANNEL_LOCAL_RESEED_AND_UNCHANGED_R18_FINAL_GATE",
            "legacyCircleQualified": bool(legacy["qualified"]),
            "legacyCyanGeometryVerified": bool(legacy["cyanVerified"]),
            "originalBaseFit": {key: float(fit[key]) for key in ("centerX", "centerY", "radius")},
            "correctedBaseFit": {key: float(seed["fit"][key]) for key in ("centerX", "centerY", "radius")},
            "seedCoverageFraction": seed["seedCoverageFraction"],
            "seedCenterDisplacementPx": seed["seedCenterDisplacementPx"],
            "seedRadiusDeltaPx": seed["seedRadiusDeltaPx"],
            "unchangedR18FinalCircleFit": final["fit"],
            "sourceChannelPixelsOnly": True,
            "crossChannelPixelCoordinateTransferPerformed": False,
        }
        _PENDING[id(corrected["strip"])] = (corrected["strip"], seed["fit"], evidence)
        return corrected

    unwrap.r43_channel_local_resample = True
    r18.r13.unwrap = unwrap
    _ENGINE = loaded
    return loaded


def install_compact_review_hooks(runner: ModuleType) -> None:
    r42.install_compact_review_hooks(runner)
    old_rank, old_compact = runner.review_rank, runner.compact_channel

    def rank(trace: dict[str, Any]) -> tuple[Any, ...]:
        record = trace["record"]
        channel = str(record["channel"])
        selected = int(record["candidateIndex"]) in r42.r41._SELECTED[channel]
        held_counterpart = str(record["candidateId"]) in _HELD_REVIEW_IDS
        return (0 if selected else 1 if held_counterpart else 2, *old_rank(trace))

    def compact(analysis: dict[str, Any], plan: dict[str, Any], channel: str) -> dict[str, Any]:
        value = old_compact(analysis, plan, channel)
        value["r43ChannelLocalCircleRescue"] = analysis["evidence"].get(
            "r43ChannelLocalCircleRescue"
        )
        return value

    runner.review_rank, runner.compact_channel = rank, compact


def install_running_review_hook() -> bool:
    candidates = [
        module for module in list(sys.modules.values())
        if isinstance(module, ModuleType)
        and Path(str(getattr(module, "__file__", ""))).name == "Run-O3F16R28FullKlarfReview.py"
        and hasattr(module, "render_bounded")
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


def analyze_native_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    engine()
    install_running_review_hook()
    strip = kwargs.get("strip", args[0] if args else None)
    pending = _PENDING.pop(id(strip), None)
    if pending is None:
        return r42.analyze_native_strip(*args, **kwargs)
    held_strip, corrected_fit, evidence = pending
    need(held_strip is strip, "R43 corrected-strip identity changed before analysis")
    if len(args) >= 3:
        values = list(args)
        values[2] = corrected_fit
        analysis = r42.analyze_native_strip(*values, **kwargs)
    else:
        values = dict(kwargs)
        values["base_fit"] = corrected_fit
        analysis = r42.analyze_native_strip(*args, **values)
    analysis["evidence"]["r43ChannelLocalCircleRescue"] = evidence
    return analysis


def pair_after_channel_contours(*args: Any, **kwargs: Any) -> dict[str, Any]:
    _HELD_REVIEW_IDS.clear()
    result = r42.pair_after_channel_contours(*args, **kwargs)
    transfer = result.get("sameChuckAngleOnlyTransfer")
    if transfer:
        _HELD_REVIEW_IDS.update(str(value) for value in transfer.get("bfHeldLocalCandidateIds", []))
    result["r43HeldCounterpartReviewCandidateIds"] = sorted(_HELD_REVIEW_IDS)
    return result


def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return r42.channel_summary(*args, **kwargs)


def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
    return r42.public_candidate_records(*args, **kwargs)


def adapter_evidence() -> dict[str, Any]:
    engine()
    return {
        "schema": "argos_ocv03_annular_candidate_first_r43_circle_reseed_v1",
        "state": "PASS_R43_FALLBACK_ONLY_CHANNEL_LOCAL_CIRCLE_RESEED_ENABLED",
        "frozenR42Sha256": R42_SHA256,
        "legacyQualifiedCirclePathChanged": False,
        "rescueSearchOffsetsPx": [RESCUE_SEARCH_MIN_OFFSET_PX, RESCUE_SEARCH_MAX_OFFSET_PX],
        "rescueExteriorGuardOffsetsPx": [RESCUE_GUARD_MIN_OFFSET_PX, RESCUE_GUARD_MAX_OFFSET_PX],
        "rescueMinimumCircleCoverageFraction": RESCUE_MINIMUM_CIRCLE_COVERAGE,
        "rescueRequiresUnchangedR18FinalQualificationAfterFreshResample": True,
        "heldBfCounterpartPrioritizedForReview": True,
        "crossChannelPixelsTransferred": 0,
        "notchOwnershipGranted": False,
        "reviewOnly": True,
    }


def self_test() -> dict[str, Any]:
    global _RESCUE_EXTERIOR
    need(r42.self_test()["state"] == "PASS_R42_REVIEW_GEOMETRY_SELF_TEST", "R42 self-test changed")
    loaded = engine()
    np, r18 = loaded.np, loaded.r18
    class Params:
        fit_residual_floor_px = 1.5
        fit_mad_multiplier = 3.0
    offsets = np.arange(RESCUE_SEARCH_MIN_OFFSET_PX, RESCUE_SEARCH_MAX_OFFSET_PX + 1, dtype=np.float32)
    base = {"centerX": 0.0, "centerY": 0.0, "radius": 1000.0}
    rows = []
    for center_x, radius_delta in ((0.0, 24.0), (60.0, 0.0), (75.0, 0.0)):
        circle = {"centerX": center_x, "centerY": 0.0, "radius": 1000.0 + radius_delta,
                  "angleSampleCount": 4096}
        model = r18.circle_ray_offsets(base, circle)
        supported = np.zeros((offsets.size, model.size), dtype=bool)
        for column in np.flatnonzero((model >= offsets[0]) & (model <= offsets[-1])):
            supported[int(np.argmin(np.abs(offsets - model[column]))), column] = True
        measured = {"strip": np.zeros((offsets.size, model.size), dtype=np.uint8), "offsets": offsets}
        original = _RESCUE_EXTERIOR
        try:
            _RESCUE_EXTERIOR = lambda _strip, _offsets, support=supported: {
                "supported": support, "searchOffsets": offsets
            }
            seeded = rescue_seed(r18, measured, base, Params())
        finally:
            _RESCUE_EXTERIOR = original
        need(seeded is not None, "Synthetic displaced circle was not reseeded")
        rows.append(round(float(seeded["seedCenterDisplacementPx"]), 3))
    sparse = np.zeros((offsets.size, 4096), dtype=bool)
    sparse[int(np.argmin(np.abs(offsets))), :1024] = True
    frontier, observed = r18.outermost_frontier(sparse, offsets)
    coverage = r18.angular_coverage(np.flatnonzero(observed), np.ones(np.count_nonzero(observed), bool), 4096)
    need(coverage < RESCUE_MINIMUM_CIRCLE_COVERAGE, "Sparse negative control changed")
    return {
        "schema": "argos_ocv03_annular_candidate_first_r43_self_test_v1",
        "state": "PASS_R43_FALLBACK_RESEED_SELF_TEST",
        "syntheticCenterDisplacementsPx": rows,
        "sparseCoverageRejected": True,
        "legacyQualifiedCirclePathChanged": False,
        "sourceImageBytesRead": False,
        "mutationsPerformed": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("ADAPTER_CHECK", "EVIDENCE", "SELF_TEST"))
    args = parser.parse_args()
    value = self_test() if args.stage == "SELF_TEST" else adapter_evidence()
    print(json.dumps(value, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
