#!/usr/bin/env python3
"""Cache exact corridor recurrence facts without changing detector decisions."""
from __future__ import annotations

import argparse
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import random
import sys
from types import ModuleType
from typing import Any

HERE = Path(__file__).resolve().parent
R45_NAME = "AnnularUnwrapCandidateFirstOpenCvR45.py"
R45_SHA256 = "4581921B174DCDBD3BE9FC7B4C3320C8EF8E9D996B7A5B804DE1D3A976D867CF"
R45_TRANSFORMED_CORRIDOR_SHA256 = (
    "6588F72500B9C196FAA0EF2AB45106928E2425DEADDA3C7C113934E39D59BAB0"
)


class R46Error(RuntimeError):
    pass


def need(value: Any, message: str) -> None:
    if not value:
        raise R46Error(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load(path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("argos_annular_r45_for_r46", path)
    need(spec is not None and spec.loader is not None, "Cannot load frozen R45")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


R45_PATH = (HERE / R45_NAME).resolve()
need(R45_PATH.is_file() and sha256_file(R45_PATH) == R45_SHA256, "Frozen R45 changed")
r45 = load(R45_PATH)
R27_SHA256 = r45.R27_SHA256
R30_SHA256 = r45.R30_SHA256
COMPACT_RUNNER_SHA256 = r45.COMPACT_RUNNER_SHA256

NEW_HELPERS = '''    all_seed_mask = (1 << len(seed_ids)) - 1
    required_seed_masks: list[int] = []
    band_seed_masks: list[list[int]] = []
    for position, bands in enumerate(coarse_bands):
        column = int(columns[position])
        required_mask = 0
        for seed_index, seed_id in enumerate(seed_ids):
            if seed_rows_by_id[seed_id].get(column, []):
                required_mask |= 1 << seed_index
        required_seed_masks.append(required_mask)
        position_masks: list[int] = []
        for band in bands:
            native_rows = {int(row) for row in band}
            support_mask = 0
            for seed_index, seed_id in enumerate(seed_ids):
                if any(
                    int(row) in native_rows
                    for row in seed_rows_by_id[seed_id].get(column, [])
                ):
                    support_mask |= 1 << seed_index
            position_masks.append(support_mask)
        band_seed_masks.append(position_masks)

    def band_intersects_seed(
        position: int, band: np.ndarray, seed_index: int
    ) -> bool:
        column = int(columns[position])
        rows = seed_rows_by_id[seed_ids[seed_index]].get(column, [])
        return any(int(row) in band for row in rows)

    def transition_connected(
        previous_band: np.ndarray,
        current_band: np.ndarray,
        maximum_change: float,
    ) -> bool:
        return any(
            abs(
                float(
                    search_offsets[int(current_row)]
                    - search_offsets[int(previous_row)]
                )
            )
            <= maximum_change + 1.0e-6
            for previous_row in previous_band
            for current_row in current_band
        )

    transition_edges: dict[tuple[int, int, int, int], bool] = {}
    zero_switch_edges: set[tuple[int, int, int, int]] = set()
    retention_masks: dict[tuple[int, int, int], int] = {}
    for position in range(1, len(columns)):
        for delta in (1, 2):
            previous_position = position - delta
            if previous_position < 0:
                continue
            skipped_required = (
                required_seed_masks[previous_position + 1] if delta == 2 else 0
            )
            for band_index in range(len(coarse_bands[position])):
                retention_masks[(previous_position, position, band_index)] = (
                    all_seed_mask
                    & ~skipped_required
                    & ~(
                        required_seed_masks[position]
                        & ~band_seed_masks[position][band_index]
                    )
                )
            for previous_band_index, previous_band in enumerate(
                coarse_bands[previous_position]
            ):
                connected_indices: list[int] = []
                for band_index, band in enumerate(coarse_bands[position]):
                    key = (
                        previous_position,
                        previous_band_index,
                        position,
                        band_index,
                    )
                    exists = transition_connected(
                        previous_band,
                        band,
                        MAXIMUM_RADIAL_CHANGE_PX_PER_SAMPLE * delta,
                    )
                    if exists and delta == 2:
                        middle_position = previous_position + 1
                        exists = not any(
                            transition_edges.get(
                                (
                                    previous_position,
                                    previous_band_index,
                                    middle_position,
                                    middle_band_index,
                                ),
                                False,
                            )
                            and transition_edges.get(
                                (
                                    middle_position,
                                    middle_band_index,
                                    position,
                                    band_index,
                                ),
                                False,
                            )
                            for middle_band_index in range(
                                len(coarse_bands[middle_position])
                            )
                        )
                    transition_edges[key] = bool(exists)
                    if exists:
                        connected_indices.append(band_index)
                closest = min(
                    (
                        native_band_separation_px(
                            previous_band,
                            coarse_bands[position][band_index],
                            search_offsets,
                        )
                        for band_index in connected_indices
                    ),
                    default=float("inf"),
                )
                for band_index in connected_indices:
                    selected = native_band_separation_px(
                        previous_band,
                        coarse_bands[position][band_index],
                        search_offsets,
                    )
                    if not selected > closest + 1.0e-6:
                        zero_switch_edges.add(
                            (
                                previous_position,
                                previous_band_index,
                                position,
                                band_index,
                            )
                        )

    def canonical_signature(
        signature: tuple[tuple[int, int], ...], seed_mask: int
    ) -> tuple[tuple[int, int], ...]:
        return tuple(
            token
            for token in signature
            if seed_mask & band_seed_masks[int(token[0])][int(token[1])]
        )

'''

NEW_STATES = '''    states: list[dict[tuple[int, int, int, int], dict[str, Any]]] = [
        {} for _ in columns
    ]
    left_band = containing_band(0, int(left_anchor["row"]))
    left_seed_mask = all_seed_mask & ~(
        required_seed_masks[0] & ~band_seed_masks[0][left_band]
    )
    left_signature_raw = (
        ((0, left_band),)
        if left_seed_mask & band_seed_masks[0][left_band]
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
                retained_here = retention_masks[
                    (previous_position, position, band_index)
                ]
                for previous_key, previous_state in states[
                    previous_position
                ].items():
                    (
                        previous_band_index,
                        previous_seed_mask,
                        previous_gaps,
                        previous_switches,
                    ) = previous_key
                    transition_key = (
                        previous_position,
                        previous_band_index,
                        position,
                        band_index,
                    )
                    if transition_key not in zero_switch_edges:
                        continue
                    next_seed_mask = int(previous_seed_mask) & retained_here
                    next_gaps = int(previous_gaps) + delta - 1
                    next_switches = int(previous_switches)
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
                    contribution = min(2, int(previous_state["count"]))
                    core_token = (
                        (position, band_index)
                        if next_seed_mask & band_seed_masks[position][band_index]
                        else None
                    )
                    contribution_signatures = {
                        (
                            signature
                            if next_seed_mask == int(previous_seed_mask)
                            else canonical_signature(signature, next_seed_mask)
                        )
                        + ((core_token,) if core_token is not None else ())
                        for signature in previous_state["coreSignatures"]
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
        if position >= 2:
            states[position - 2].clear()

'''

_ENGINE: ModuleType | None = None
_R45_RECOMPUTE: Any = None
_R46_RECOMPUTE: Any = None
_R46_SOURCE_SHA256: str | None = None
_HOOKED_RUNNERS: set[int] = set()


def replace_region(source: str, start: str, end: str, replacement: str) -> str:
    need(source.count(start) == 1 and source.count(end) == 1, "Frozen R45 region changed")
    left = source.index(start)
    right = source.index(end, left)
    return source[:left] + replacement + source[right:]


def exact_r45_recompute_source(loaded: ModuleType) -> str:
    r31 = r45.r44.r43.r42.r41.r40.r37.r36.r34.r32.r31
    source = r31._frozen_function_source(
        Path(loaded.__file__).resolve(), "recompute_coherent_core_corridors"
    )
    need(
        source.count(r45.OLD_STATE_KEY) == 1
        and source.count(r45.OLD_FINAL_LAYER) == 1,
        "Frozen R45 injection points changed",
    )
    source = source.replace(r45.OLD_STATE_KEY, r45.NEW_STATE_KEY, 1)
    source = source.replace(r45.OLD_FINAL_LAYER, r45.NEW_FINAL_LAYER, 1)
    for old, new, label in (
        (r31._RECOMPUTE_SIGNATURE_OLD, r31._RECOMPUTE_SIGNATURE_NEW, "signature"),
        (r31._RECOMPUTE_OLD, r31._RECOMPUTE_NEW, "resolution"),
        (r31._RECOMPUTE_DIAGNOSTIC_OLD, r31._RECOMPUTE_DIAGNOSTIC_NEW, "diagnostics"),
        (r31._RECOMPUTE_RULE_OLD, r31._RECOMPUTE_RULE_NEW, "rule"),
    ):
        need(source.count(old) == 1, f"Frozen R31 {label} transform changed")
        source = source.replace(old, new, 1)
    need(
        hashlib.sha256(source.encode("utf-8")).hexdigest().upper()
        == R45_TRANSFORMED_CORRIDOR_SHA256
        == str(loaded.R31_RECOMPUTE_SOURCE_SHA256),
        "Reconstructed R45 corridor source differs",
    )
    return source


def engine() -> ModuleType:
    global _ENGINE, _R45_RECOMPUTE, _R46_RECOMPUTE, _R46_SOURCE_SHA256
    if _ENGINE is not None:
        return _ENGINE
    loaded = r45.engine()
    _R45_RECOMPUTE = loaded.recompute_coherent_core_corridors
    source = exact_r45_recompute_source(loaded)
    source = replace_region(source, "    def band_edge_exists(\n", "    states:", NEW_HELPERS)
    source = replace_region(source, "    states:", "    right_band =", NEW_STATES)
    need(
        "retain_fully_covered_seeds(" not in source
        and "avoidable_band_switch(" not in source
        and source.count("def canonical_signature(") == 1,
        "R46 recurrence replacement is incomplete",
    )
    ast.parse(source)
    _R46_SOURCE_SHA256 = hashlib.sha256(source.encode("utf-8")).hexdigest().upper()
    exec(compile(source, str(loaded.__file__), "exec"), loaded.__dict__)
    _R46_RECOMPUTE = loaded.recompute_coherent_core_corridors
    need(_R46_RECOMPUTE is not _R45_RECOMPUTE, "R46 recurrence was not rebound")
    loaded.R46_RECOMPUTE_SOURCE_SHA256 = _R46_SOURCE_SHA256
    _ENGINE = loaded
    return loaded


def install_running_review_hook() -> None:
    candidates = [
        module for module in list(sys.modules.values())
        if isinstance(module, ModuleType)
        and Path(str(getattr(module, "__file__", ""))).name
        == "Run-O3F16R28FullKlarfReview.py"
        and hasattr(module, "render_bounded")
        and hasattr(module, "atomic_json")
        and Path(str(getattr(module, "ADAPTER_PATH", ""))).resolve()
        == Path(__file__).resolve()
    ]
    need(len(candidates) <= 1, "Multiple bound compact review runners are active")
    if candidates and id(candidates[0]) not in _HOOKED_RUNNERS:
        r45.r44.install_compact_review_hooks(candidates[0])
        _HOOKED_RUNNERS.add(id(candidates[0]))


def analyze_native_strip(*args: Any, **kwargs: Any) -> dict[str, Any]:
    engine()
    install_running_review_hook()
    return r45.analyze_native_strip(*args, **kwargs)


def pair_after_channel_contours(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return r45.pair_after_channel_contours(*args, **kwargs)


def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return r45.channel_summary(*args, **kwargs)


def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
    return r45.public_candidate_records(*args, **kwargs)


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        ensure_ascii=True,
        allow_nan=False,
        separators=(",", ":"),
    ).encode("ascii")


def synthetic_case(
    *,
    rows_by_position: list[list[int]],
    seed_nodes: list[list[tuple[int, int]]],
    left_row: int,
    right_row: int,
    representative_rows: list[int | None] | None = None,
    columns: list[int] | None = None,
    angle_sample_count: int | None = None,
    offsets: dict[int, float] | None = None,
    raw_unsupported_column_count: int = 0,
) -> dict[str, Any]:
    count = len(rows_by_position)
    native_columns = columns or list(range(count))
    angle_count = angle_sample_count or count
    need(count > 0 and len(native_columns) == count, "Synthetic span differs")
    complete = []
    for position, rows in enumerate(rows_by_position):
        for row in sorted(set(rows)):
            complete.append(
                {
                    "column": int(native_columns[position]),
                    "radialRow": int(row),
                    "offsetPx": float((offsets or {}).get(int(row), float(row))),
                }
            )
    strict = []
    ordinals = []
    for seed_index, nodes in enumerate(seed_nodes):
        for position, row in nodes:
            strict.append(
                {
                    "column": int(native_columns[position]),
                    "radialRow": int(row),
                }
            )
            ordinals.append(seed_index)
    chosen = representative_rows or [
        (None if not rows else int(rows[0])) for rows in rows_by_position
    ]
    representative = [
        {"column": int(native_columns[position]), "radialRow": int(row)}
        for position, row in enumerate(chosen)
        if row is not None
    ]
    return {
        "angle_sample_count": angle_count,
        "span_columns": native_columns,
        "complete_node_records": complete,
        "strict_core_node_records": strict,
        "strict_core_seed_ids": [f"S{index:03d}" for index in range(len(seed_nodes))],
        "strict_core_native_node_seed_ordinals": ordinals,
        "left_anchor": {"column": native_columns[0], "row": left_row},
        "right_anchor": {"column": native_columns[-1], "row": right_row},
        "representative_path": representative,
        "raw_unsupported_column_count": raw_unsupported_column_count,
    }


def equivalence_corpus() -> list[tuple[str, dict[str, Any]]]:
    cases: list[tuple[str, dict[str, Any]]] = []
    cases.append(("ONE_COLUMN", synthetic_case(
        rows_by_position=[[10]],
        seed_nodes=[[(0, 10)]],
        left_row=10, right_row=10,
    )))
    cases.append(("STRAIGHT", synthetic_case(
        rows_by_position=[[10]] * 5,
        seed_nodes=[[(position, 10) for position in range(5)]],
        left_row=10, right_row=10,
    )))
    cases.append(("EQUAL_SPLIT_REJOIN", synthetic_case(
        rows_by_position=[[10], [7, 13], [10]],
        seed_nodes=[[(0, 10), (1, 7), (1, 13), (2, 10)]],
        left_row=10, right_row=10, representative_rows=[10, 7, 10],
    )))
    gap_rows = [[10] for _ in range(10)]
    gap_rows[5] = []
    gap_seed = [[(position, 10) for position in range(10) if position != 5]]
    cases.append(("ONE_GAP_AT_COVERAGE_BOUNDARY", synthetic_case(
        rows_by_position=gap_rows, seed_nodes=gap_seed,
        left_row=10, right_row=10, raw_unsupported_column_count=1,
    )))
    cases.append(("SKIPPED_REQUIRED_SEED_LOSS", synthetic_case(
        rows_by_position=gap_rows,
        seed_nodes=[[(position, 10) for position in range(10)]],
        left_row=10, right_row=10, raw_unsupported_column_count=1,
    )))
    cases.append(("MASK_SHRINK", synthetic_case(
        rows_by_position=[[10, 20]] * 4,
        seed_nodes=[
            [(position, 10) for position in range(4)],
            [(0, 20), (1, 20)],
        ],
        left_row=10, right_row=10, representative_rows=[10] * 4,
    )))
    retroactive_rows = [[0, 1], [6], [], *([[0]] * 7)]
    cases.append(("RETROACTIVE_TOKEN_REMOVAL_AT_COVERAGE_BOUNDARY", synthetic_case(
        rows_by_position=retroactive_rows,
        seed_nodes=[
            [(0, 0), *[(position, 0) for position in range(3, 10)]],
            [(0, 1), (1, 6), (2, 6)],
        ],
        left_row=0,
        right_row=0,
        representative_rows=[0, 6, None, *([0] * 7)],
        raw_unsupported_column_count=1,
    )))
    cases.append(("WRAPPED_COLUMNS", synthetic_case(
        rows_by_position=[[10]] * 4,
        seed_nodes=[[(position, 10) for position in range(4)]],
        left_row=10, right_row=10,
        columns=[14, 15, 0, 1], angle_sample_count=16,
    )))
    cases.append(("FLOAT32_CONNECTIVITY_EDGE", synthetic_case(
        rows_by_position=[[0], [1], [0]],
        seed_nodes=[[(0, 0), (1, 1), (2, 0)]],
        left_row=0, right_row=0,
        offsets={0: 0.0, 1: 6.0000005},
    )))
    cases.append(("FLOAT32_CONNECTIVITY_JUST_INSIDE_EPSILON", synthetic_case(
        rows_by_position=[[0], [2]],
        seed_nodes=[[(0, 0), (1, 2)]],
        left_row=0, right_row=2,
        offsets={0: 0.0, 2: 6.000000953674316},
    )))
    cases.append(("FLOAT32_CONNECTIVITY_JUST_OUTSIDE_EPSILON", synthetic_case(
        rows_by_position=[[0], [2]],
        seed_nodes=[[(0, 0), (1, 2)]],
        left_row=0, right_row=2,
        offsets={0: 0.0, 2: 6.000001430511475},
    )))
    cases.append(("DELTA_TWO_BRIDGE_SUPPRESSES_SKIP", synthetic_case(
        rows_by_position=[[0], [2], [4]],
        seed_nodes=[[(0, 0), (1, 2), (2, 4)]],
        left_row=0, right_row=4,
        offsets={0: 0.0, 2: 6.0, 4: 12.0},
    )))
    cases.append(("THICK_PARALLEL_BANDS", synthetic_case(
        rows_by_position=[[0, 1, 2, 8, 9, 10]] * 4,
        seed_nodes=[
            [(position, 1) for position in range(4)],
            [(position, 9) for position in range(4)],
        ],
        left_row=1, right_row=1, representative_rows=[1] * 4,
    )))
    cases.append(("NONUNIT_POSITIVE_PITCH", synthetic_case(
        rows_by_position=[[0, 2], [0, 2], [0, 2]],
        seed_nodes=[[(0, 0), (1, 2), (2, 0)]],
        left_row=0, right_row=0,
        representative_rows=[0, 2, 0],
        offsets={0: 0.0, 2: 3.0},
    )))
    cases.append(("NONMONOTONE_SERIALIZED_OFFSETS", synthetic_case(
        rows_by_position=[[5], [0, 10], [5]],
        seed_nodes=[[(0, 5), (1, 0), (2, 5)]],
        left_row=5, right_row=5,
        representative_rows=[5, 0, 5],
        offsets={0: 0.0, 5: 100.0, 10: -100.0},
    )))
    wide_rows = list(range(65))
    cases.append(("PYTHON_INT_65_SEEDS", synthetic_case(
        rows_by_position=[wide_rows, wide_rows],
        seed_nodes=[[(0, row)] for row in wide_rows],
        left_row=0, right_row=0,
    )))
    for pattern in range(1, 64):
        nodes = []
        for position in range(3):
            support = (pattern >> (2 * position)) & 3
            if support & 1:
                nodes.append((position, 0))
            if support & 2:
                nodes.append((position, 2))
        for left_row in (0, 2):
            for right_row in (0, 2):
                name = f"MICRO_{pattern:02d}_{left_row}_{right_row}"
                cases.append((name, synthetic_case(
                    rows_by_position=[[0, 2], [0, 2], [0, 2]],
                    seed_nodes=[nodes], left_row=left_row, right_row=right_row,
                    representative_rows=[left_row, 0, right_row],
                    offsets={0: 0.0, 2: 6.0},
                )))
    generator = random.Random(0x46C0FFEE)
    for case_index in range(128):
        count = generator.randint(2, 8)
        rows_by_position = []
        for position in range(count):
            rows = [
                row for row in (0, 6, 12)
                if position in (0, count - 1) or generator.random() < 0.72
            ]
            rows_by_position.append(rows)
        coordinates = [
            (position, row)
            for position, rows in enumerate(rows_by_position)
            for row in rows
        ]
        generator.shuffle(coordinates)
        seed_count = min(generator.randint(1, 4), len(coordinates))
        seed_nodes = [[coordinates[index]] for index in range(seed_count)]
        for coordinate in coordinates[seed_count:]:
            if generator.random() < 0.38:
                seed_nodes[generator.randrange(seed_count)].append(coordinate)
        left_row = generator.choice(rows_by_position[0])
        right_row = generator.choice(rows_by_position[-1])
        representative_rows = [
            None if not rows else generator.choice(rows)
            for rows in rows_by_position
        ]
        representative_rows[0] = left_row
        representative_rows[-1] = right_row
        angle_count = count + generator.randint(0, 9)
        start = generator.randrange(angle_count)
        native_columns = [
            (start + position) % angle_count for position in range(count)
        ]
        cases.append((f"RANDOM_{case_index:03d}", synthetic_case(
            rows_by_position=rows_by_position,
            seed_nodes=seed_nodes,
            left_row=left_row,
            right_row=right_row,
            representative_rows=representative_rows,
            columns=native_columns,
            angle_sample_count=angle_count,
            offsets={0: 0.0, 6: 6.0, 12: 12.0},
            raw_unsupported_column_count=sum(not rows for rows in rows_by_position),
        )))
    return cases


def differential_test() -> dict[str, Any]:
    loaded = engine()
    need(callable(_R45_RECOMPUTE) and callable(_R46_RECOMPUTE), "Corridor functions absent")
    cases = equivalence_corpus()
    need(len(cases) == 396, "R46 equivalence corpus cardinality changed")
    corpus_digest = hashlib.sha256()
    for name, case in cases:
        spec = canonical_bytes(case)
        expected = canonical_bytes(_R45_RECOMPUTE(**case))
        actual = canonical_bytes(_R46_RECOMPUTE(**case))
        need(
            actual == expected,
            f"R46 differs from R45 for {name} spec "
            f"{hashlib.sha256(spec).hexdigest().upper()}",
        )
        corpus_digest.update(name.encode("ascii") + b"\0" + spec + b"\0" + expected)
    return {
        "caseCount": len(cases),
        "microExhaustiveCaseCount": 252,
        "deterministicRandomizedCaseCount": 128,
        "canonicalCorpusAndR45OutputSha256": corpus_digest.hexdigest().upper(),
        "entireReturnedObjectCompared": True,
    }


def adapter_evidence() -> dict[str, Any]:
    engine()
    return {
        "schema": "argos_ocv03_annular_candidate_first_r46_corridor_cache_v1",
        "state": "PASS_R46_EXACT_CORRIDOR_FACTS_CACHED",
        "frozenR45Sha256": R45_SHA256,
        "frozenR45TransformedCorridorSha256": R45_TRANSFORMED_CORRIDOR_SHA256,
        "r46TransformedCorridorSha256": _R46_SOURCE_SHA256,
        "finalCorridorPredicateChanged": False,
        "candidateOrCircleThresholdChanged": False,
        "pixelsContoursOrPairingChanged": False,
        "fullSignatureTokenHistoryRetained": True,
        "notchOwnershipGranted": False,
        "reviewOnly": True,
    }


def self_test() -> dict[str, Any]:
    engine()
    need(
        r45.self_test()["state"] == "PASS_R45_CORRIDOR_MEMORY_SELF_TEST",
        "R45 self-test changed",
    )
    comparison = differential_test()
    return {
        "schema": "argos_ocv03_annular_candidate_first_r46_self_test_v1",
        "state": "PASS_R46_FULL_OUTPUT_EQUIVALENCE_SELF_TEST",
        **comparison,
        "connectivityUsesFrozenAllPairsFloat32Predicate": True,
        "seedAndTransitionFactsPrecomputed": True,
        "redundantSignatureCanonicalizationRemoved": True,
        "detectorSemanticsChanged": False,
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
