#!/usr/bin/env python3
"""Persist complete candidate evidence without repeated JSON field-name bloat."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from types import ModuleType
from typing import Any, Callable

HERE = Path(__file__).resolve().parent
R43_NAME = "AnnularUnwrapCandidateFirstOpenCvR43.py"
R43_SHA256 = "D6FB064F67C59C03078638D8280B4670EAA676653580032E90B0C97C5A451188"
CASE_SCHEMA = "argos_ocv03_o3f16r28_compact_case_v1"
R44_CASE_SCHEMA = "argos_ocv03_o3f16r28_compact_case_r44_columnar_v1"


class R44Error(RuntimeError):
    pass


def need(value: Any, message: str) -> None:
    if not value:
        raise R44Error(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load(path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("argos_annular_r43_for_r44", path)
    need(spec is not None and spec.loader is not None, "Cannot load frozen R43")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


R43_PATH = (HERE / R43_NAME).resolve()
need(R43_PATH.is_file() and sha256_file(R43_PATH) == R43_SHA256, "Frozen R43 changed")
r43 = load(R43_PATH)
R27_SHA256 = r43.R27_SHA256
R30_SHA256 = r43.R30_SHA256
COMPACT_RUNNER_SHA256 = r43.COMPACT_RUNNER_SHA256
_HOOKED_RUNNERS: set[int] = set()


def engine() -> ModuleType:
    return r43.engine()


def columnar_candidates(rows: list[dict[str, Any]], sha256_json: Callable[[Any], str]) -> dict[str, Any]:
    fields = sorted(rows[0]) if rows else []
    expected = set(fields)
    need(all(set(row) == expected for row in rows), "Compact candidate field sets differ")
    encoded = {
        "schema": "argos_ocv03_r44_lossless_candidate_columns_v1",
        "fieldOrder": fields,
        "rows": [[row[field] for field in fields] for row in rows],
        "rowCount": len(rows),
        "rowOrderChanged": False,
        "valuesOmitted": False,
        "originalCandidateListCanonicalJsonSha256": sha256_json(rows),
    }
    need(len(encoded["rows"]) == len(rows), "Candidate cardinality changed during encoding")
    return encoded


def serialized_case(value: dict[str, Any], sha256_json: Callable[[Any], str]) -> dict[str, Any]:
    need(value.get("schema") == CASE_SCHEMA, "CASE schema changed before R44 serialization")
    channels: dict[str, Any] = {}
    evidence: dict[str, Any] = {}
    for channel in ("BF", "DF"):
        source = value["channels"][channel]
        candidates = source["candidates"]
        need(isinstance(candidates, list) and source["candidateCount"] == len(candidates),
             f"{channel} candidate cardinality changed")
        encoded = columnar_candidates(candidates, sha256_json)
        compact = dict(source)
        compact["candidates"] = encoded
        channels[channel] = compact
        evidence[channel] = {
            "candidateCount": len(candidates),
            "fieldCount": len(encoded["fieldOrder"]),
            "originalCandidateListCanonicalJsonSha256": encoded[
                "originalCandidateListCanonicalJsonSha256"
            ],
        }
    result = dict(value)
    result["schema"] = R44_CASE_SCHEMA
    result["channels"] = channels
    result["r44CandidateSerialization"] = {
        "state": "PASS_R44_LOSSLESS_COLUMNAR_CANDIDATE_EVIDENCE",
        "originalCaseSchema": CASE_SCHEMA,
        "detectorPopulationChanged": False,
        "candidateOrderChanged": False,
        "candidateValuesOmitted": False,
        "channels": evidence,
    }
    return result


def install_compact_review_hooks(runner: ModuleType) -> None:
    r43.install_compact_review_hooks(runner)
    old_atomic = runner.atomic_json

    def atomic_json(path: Path, value: dict[str, Any], replace: bool = False) -> dict[str, Any]:
        persisted = serialized_case(value, runner.sha256_json) if path.name == "CASE.json" else value
        return old_atomic(path, persisted, replace)

    runner.atomic_json = atomic_json


def install_running_review_hook() -> bool:
    candidates = [
        module for module in list(sys.modules.values())
        if isinstance(module, ModuleType)
        and Path(str(getattr(module, "__file__", ""))).name == "Run-O3F16R28FullKlarfReview.py"
        and hasattr(module, "render_bounded") and hasattr(module, "atomic_json")
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
    return r43.analyze_native_strip(*args, **kwargs)


def pair_after_channel_contours(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return r43.pair_after_channel_contours(*args, **kwargs)


def channel_summary(*args: Any, **kwargs: Any) -> dict[str, Any]:
    return r43.channel_summary(*args, **kwargs)


def public_candidate_records(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
    return r43.public_candidate_records(*args, **kwargs)


def adapter_evidence() -> dict[str, Any]:
    engine()
    return {
        "schema": "argos_ocv03_annular_candidate_first_r44_case_serialization_v1",
        "state": "PASS_R44_LOSSLESS_COLUMNAR_CASE_SERIALIZATION_ENABLED",
        "frozenR43Sha256": R43_SHA256,
        "detectorOrPairingSemanticsChanged": False,
        "candidatePopulationOrOrderChanged": False,
        "candidateValuesOmitted": False,
        "compactCaseCapChanged": False,
        "runnerOrWrapperChanged": False,
        "notchOwnershipGranted": False,
        "reviewOnly": True,
    }


def self_test() -> dict[str, Any]:
    need(r43.self_test()["state"] == "PASS_R43_FALLBACK_RESEED_SELF_TEST", "R43 self-test changed")
    canonical = lambda value: hashlib.sha256((json.dumps(
        value, sort_keys=True, allow_nan=False, ensure_ascii=True, separators=(",", ":")
    ) + "\n").encode("utf-8")).hexdigest().upper()
    rows = [
        {"candidateId": "BF_C0001", "candidateIndex": 0, "reasons": [], "score": 1.25},
        {"candidateId": "BF_C0002", "candidateIndex": 1, "reasons": ["HELD"], "score": None},
    ]
    encoded = columnar_candidates(rows, canonical)
    decoded = [dict(zip(encoded["fieldOrder"], row)) for row in encoded["rows"]]
    need(decoded == rows and canonical(decoded) == encoded["originalCandidateListCanonicalJsonSha256"],
         "Lossless candidate reconstruction changed")
    return {
        "schema": "argos_ocv03_annular_candidate_first_r44_self_test_v1",
        "state": "PASS_R44_LOSSLESS_COLUMNAR_CASE_SERIALIZATION_SELF_TEST",
        "candidateRowsPreserved": len(rows),
        "candidateValuesOmitted": False,
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
