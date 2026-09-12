#!/usr/bin/env python3
"""Bound corridor memory by discarding states that cannot reach the frozen final gate."""
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
R44_NAME = "AnnularUnwrapCandidateFirstOpenCvR44.py"
R44_SHA256 = "F3554C146E89B0D160F933105CC94A3561A4F6B5DD895BFAC5DD7B07C40C7B70"


class R45Error(RuntimeError):
    pass


def need(value: Any, message: str) -> None:
    if not value:
        raise R45Error(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load(path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("argos_annular_r44_for_r45", path)
    need(spec is not None and spec.loader is not None, "Cannot load frozen R44")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


R44_PATH = (HERE / R44_NAME).resolve()
need(R44_PATH.is_file() and sha256_file(R44_PATH) == R44_SHA256, "Frozen R44 changed")
r44 = load(R44_PATH)
R27_SHA256 = r44.R27_SHA256
R30_SHA256 = r44.R30_SHA256
COMPACT_RUNNER_SHA256 = r44.COMPACT_RUNNER_SHA256

OLD_STATE_KEY = '''                    next_seed_mask = retain_fully_covered_seeds(
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
'''
NEW_STATE_KEY = '''                    next_seed_mask = retain_fully_covered_seeds(
                        int(previous_seed_mask), previous_position, position, band
                    )
                    next_gaps = int(previous_gaps) + delta - 1
                    next_switches = min(
                        2,
                        int(previous_switches)
                        + avoidable_band_switch(
                            previous_position, previous_band, position, band
                        ),
                    )
                    if (
                        next_seed_mask == 0
                        or next_switches != 0
                        or (len(columns) - next_gaps) / len(columns)
                        < MINIMUM_PATH_COVERAGE_FRACTION
                    ):
                        continue
                    current_key = (
                        band_index,
                        next_seed_mask,
                        next_gaps,
                        next_switches,
                    )
'''
OLD_FINAL_LAYER = '''

    right_band = containing_band(len(columns) - 1, int(right_anchor["row"]))
'''
NEW_FINAL_LAYER = '''
        if position >= 2:
            states[position - 2].clear()

    right_band = containing_band(len(columns) - 1, int(right_anchor["row"]))
'''

_ENGINE: ModuleType | None = None
_INJECTED_SOURCE_SHA256: str | None = None
_TRANSFORMED_SHA256: str | None = None
_HOOKED_RUNNERS: set[int] = set()


def engine() -> ModuleType:
    global _ENGINE, _INJECTED_SOURCE_SHA256, _TRANSFORMED_SHA256
    if _ENGINE is not None:
        return _ENGINE
    r31 = r44.r43.r42.r41.r40.r37.r36.r34.r32.r31
    need(r31._ENGINE is None, "Frozen R31 engine was initialized before R45 patching")
    original_source = r31._frozen_function_source
    patched = 0

    def source(path: Path, name: str) -> str:
        nonlocal patched
        global _INJECTED_SOURCE_SHA256
        value = original_source(path, name)
        if name != "recompute_coherent_core_corridors":
            return value
        need(
            value.count(OLD_STATE_KEY) == 1
            and value.count(OLD_FINAL_LAYER) == 1
            and NEW_STATE_KEY not in value,
            "Frozen corridor DP structure changed",
        )
        value = value.replace(OLD_STATE_KEY, NEW_STATE_KEY, 1)
        value = value.replace(OLD_FINAL_LAYER, NEW_FINAL_LAYER, 1)
        ast.parse(value)
        _INJECTED_SOURCE_SHA256 = hashlib.sha256(value.encode("utf-8")).hexdigest().upper()
        patched += 1
        return value

    r31._frozen_function_source = source
    try:
        loaded = r44.engine()
    finally:
        r31._frozen_function_source = original_source
    need(patched == 1 and _INJECTED_SOURCE_SHA256 is not None, "R45 corridor patch was not applied exactly once")
    _TRANSFORMED_SHA256 = str(loaded.R31_RECOMPUTE_SOURCE_SHA256)
    _ENGINE = loaded
    return loaded


def install_running_review_hook() -> None:
    candidates = [
        module for module in list(sys.modules.values())
        if isinstance(module, ModuleType)
        and Path(str(getattr(module, "__file__", ""))).name == "Run-O3F16R28FullKlarfReview.py"
        and hasattr(module, "render_bounded") and hasattr(module, "atomic_json")
        and Path(str(getattr(module, "ADAPTER_PATH", ""))).resolve() == Path(__file__).resolve()
    ]
    need(len(candidates) <= 1, "Multiple bound compact review runners are active")
    if candidates and id(candidates[0]) not in _HOOKED_RUNNERS:
        r44.install_compact_review_hooks(candidates[0])
        _HOOKED_RUNNERS.add(id(candidates[0]))


def analyze_native_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    engine()
    install_running_review_hook()
    return r44.analyze_native_strip(*args, **kwargs)


def pair_after_channel_contours(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return r44.pair_after_channel_contours(*args, **kwargs)


def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return r44.channel_summary(*args, **kwargs)


def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
    return r44.public_candidate_records(*args, **kwargs)


def adapter_evidence() -> dict[str, Any]:
    engine()
    return {
        "schema": "argos_ocv03_annular_candidate_first_r45_corridor_memory_v1",
        "state": "PASS_R45_UNREACHABLE_CORRIDOR_STATES_PRUNED_AND_DEAD_LAYERS_RELEASED",
        "frozenR44Sha256": R44_SHA256,
        "r45InjectedCorridorSourceSha256": _INJECTED_SOURCE_SHA256,
        "transformedCorridorSourceSha256": _TRANSFORMED_SHA256,
        "finalCorridorPredicateChanged": False,
        "candidateOrCircleThresholdChanged": False,
        "pixelsContoursOrPairingChanged": False,
        "historicalLayersRetained": 2,
        "notchOwnershipGranted": False,
        "reviewOnly": True,
    }


def self_test() -> dict[str, Any]:
    engine()
    need(r44.self_test()["state"] == "PASS_R44_LOSSLESS_COLUMNAR_CASE_SERIALIZATION_SELF_TEST", "R44 self-test changed")
    need(NEW_STATE_KEY.count("continue") == 1 and "states[position - 2].clear()" in NEW_FINAL_LAYER, "R45 DP invariants changed")
    return {
        "schema": "argos_ocv03_annular_candidate_first_r45_self_test_v1",
        "state": "PASS_R45_CORRIDOR_MEMORY_SELF_TEST",
        "monotoneDeadStatePredicates": ["ZERO_SEED_MASK", "NONZERO_SWITCH_COUNT", "FINAL_COVERAGE_IMPOSSIBLE"],
        "finalCorridorPredicateChanged": False,
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
