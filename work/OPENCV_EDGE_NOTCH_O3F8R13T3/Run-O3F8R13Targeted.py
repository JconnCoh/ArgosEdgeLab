#!/usr/bin/env python3
"""Run R13 once on the frozen hotspot ten plus all five R8 provider errors."""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
from typing import Any


HERE = Path(__file__).resolve().parent
L4_PATH = HERE / "Run-O3F15L4FrontReconcile.py"
if not L4_PATH.is_file():
    L4_PATH = HERE.parent / "OPENCV_EDGE_NOTCH_O3F15L4D3" / L4_PATH.name
R13_PATH = HERE / "FullPerimeterWaferTopologyOpenCvR13.py"
if not R13_PATH.is_file():
    R13_PATH = HERE.parent / "O3F8" / R13_PATH.name
R13_SHA256 = "507ED5B9DE13F9DF70AC65E9C714E5E89F52885AA9DF389076E93500E2123EE8"
L4_SHA256 = "3C403376521B74E3A6DB1C4E008CE8DB36D8D99AE9A0FD7C1FA51481024DBEF4"
RUN_ROOT = Path(r"D:\O3F8R13T3C")
MIRROR_ROOT = Path(r"D:\KLARFExport\_ArgosReview\F8R13T3S")
PROVIDER_ERROR_STATE = "HOLD_FRONT_NOTCH_PROVIDER_ERROR"
HOTSPOT = re.compile(r"62629-419.*(?:SLOT|Slot)(1[6-9]|2[0-5])(?:\D|$)")


class TargetedError(RuntimeError):
    pass


def need(value: Any, message: str) -> None:
    if not value:
        raise TargetedError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_l4() -> Any:
    need(L4_PATH.is_file() and sha256(L4_PATH) == L4_SHA256, "Frozen L4 runner changed")
    need(R13_PATH.is_file() and sha256(R13_PATH) == R13_SHA256, "R13 detector changed")
    spec = importlib.util.spec_from_file_location("argos_o3f8_r13_targeted_l4", L4_PATH)
    need(spec is not None and spec.loader is not None, "Cannot load frozen L4 runner")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    module.R11 = R13_PATH
    module.R11_SHA256 = R13_SHA256
    frozen = module.configure_frozen()
    return module, frozen


def select_targets(context: dict[str, Any]) -> list[tuple[int, dict[str, Any], dict[str, Any]]]:
    rows = context["cohorts"]["ordered978"]
    plans = context["plans"]
    provider = {str(row["identity"]) for row in rows if str(row["r8State"]) == PROVIDER_ERROR_STATE}
    hotspot = {str(row["identity"]) for row in rows if HOTSPOT.search(str(row["identity"]))}
    need(len(provider) == 5, f"Frozen provider-error count changed: {len(provider)}")
    need(len(hotspot) == 10, f"Frozen hotspot count changed: {len(hotspot)}")
    target_ids = provider | hotspot
    need(len(target_ids) == 11, f"Target union count changed: {len(target_ids)}")
    selected = [
        (ordinal, row, plan)
        for ordinal, (row, plan) in enumerate(zip(rows, plans), 1)
        if str(row["identity"]) in target_ids
    ]
    need(len(selected) == 11, "Target selection cardinality changed")
    return selected


def describe_targets(selected: list[tuple[int, dict[str, Any], dict[str, Any]]]) -> list[dict[str, Any]]:
    return [
        {
            "frozenOrdinal": ordinal,
            "identity": str(row["identity"]),
            "safeId": str(row["safeId"]),
            "priorR8State": str(row["r8State"]),
            "hotspot": bool(HOTSPOT.search(str(row["identity"]))),
            "providerError": str(row["r8State"]) == PROVIDER_ERROR_STATE,
        }
        for ordinal, row, _ in selected
    ]


def preflight() -> dict[str, Any]:
    l4, _ = load_l4()
    context = l4.preflight_context()
    selected = select_targets(context)
    return {
        "schema": "argos_ocv03_o3f8_r13_targeted_preflight_v1",
        "state": "PASS_O3F8_R13_TARGETED_PREFLIGHT",
        "scheduledCount": 11,
        "hotspotCount": 10,
        "providerErrorCount": 5,
        "unionCount": 11,
        "targets": describe_targets(selected),
        "r13Sha256": R13_SHA256,
        "sourceImageBytesRead": False,
        "mutationsPerformed": False,
        "reviewOnly": True,
    }


def atomic_json(module: Any, path: Path, value: dict[str, Any]) -> None:
    module.atomic_json(path, value)


def mirror_json(module: Any, output: Path, mirror: Path, name: str, value: dict[str, Any]) -> None:
    module.mirror_json(output, mirror, name, value, replace=(output / name).exists())


def progress(rows: list[dict[str, Any]], targets: list[dict[str, Any]], terminal: bool = False) -> dict[str, Any]:
    return {
        "schema": "argos_ocv03_o3f8_r13_targeted_progress_v1",
        "state": "COMPLETE_O3F8_R13_TARGETED" if terminal else "RUNNING_O3F8_R13_TARGETED",
        "scheduledCount": 11,
        "recordedCount": len(rows),
        "targets": targets,
        "rows": rows,
        "terminal": terminal,
        "retryAuthorized": False,
        "sourceMutation": False,
        "providerActivated": False,
        "reviewOnly": True,
    }


def run(output_root: Path, mirror_root: Path) -> dict[str, Any]:
    need(output_root == RUN_ROOT and mirror_root == MIRROR_ROOT, "Targeted output roots changed")
    need(output_root.parent.is_dir() and not output_root.exists(), "Targeted output root is not create-new")
    need(mirror_root.parent.is_dir() and not mirror_root.exists(), "Targeted mirror root is not create-new")
    need(len(str(output_root)) + 32 < 200 and len(str(mirror_root)) + 64 < 200, "Targeted output path budget failed")
    l4, frozen = load_l4()
    context = l4.preflight_context()
    selected = select_targets(context)
    targets = describe_targets(selected)
    output_root.mkdir()
    mirror_root.mkdir()
    jobs = output_root / "jobs"
    cases = output_root / "cases"
    jobs.mkdir()
    cases.mkdir()
    env = context["o3f14"].isolated_env()
    env.update({"TEMP": str(output_root), "TMP": str(output_root)})
    rows: list[dict[str, Any]] = []
    mirror_json(frozen, output_root, mirror_root, "PROGRESS.json", progress(rows, targets))
    for target_index, (frozen_ordinal, row, plan) in enumerate(selected, 1):
        try:
            compact = l4.run_one(target_index, row, plan, context, output_root, jobs, cases, env)
            manifest_path = Path(str(compact["manifestPath"]))
            manifest, manifest_sha = frozen.read_json_and_sha256(manifest_path)
            observed = manifest["results"][0]
            df = observed["df"]
            bf = observed["bf"]
            record = {
                "targetIndex": target_index,
                "frozenOrdinal": frozen_ordinal,
                "identity": str(row["identity"]),
                "priorR8State": str(row["r8State"]),
                "finalState": str(observed["state"]),
                "bfCandidateCount": int(bf["candidateCount"]),
                "dfCandidateCount": int(df["candidateCount"]),
                "dfCandidateResourceLimit": int(df["candidateResourceLimit"]),
                "dfCandidateResourceLimitSource": str(df["candidateResourceLimitSource"]),
                "physicalCandidateCount": len(observed["physicalIndentationCandidates"]),
                "eligiblePhysicalCandidateCount": len(observed["eligiblePhysicalCandidateIndices"]),
                "manifestPath": str(manifest_path),
                "manifestSha256": manifest_sha,
                "execution": "PASS_R13_FRESH",
                "error": None,
            }
        except Exception as exc:
            record = {
                "targetIndex": target_index,
                "frozenOrdinal": frozen_ordinal,
                "identity": str(row["identity"]),
                "priorR8State": str(row["r8State"]),
                "finalState": "HOLD_O3F8_R13_TARGET_EXECUTION_ERROR",
                "execution": "HOLD_TARGET_EXECUTION",
                "error": f"{type(exc).__name__}: {str(exc)[:1600]}",
            }
        rows.append(record)
        mirror_json(frozen, output_root, mirror_root, "PROGRESS.json", progress(rows, targets))
    passed = sum(row["execution"] == "PASS_R13_FRESH" for row in rows)
    complete = passed == 11
    result = {
        "schema": "argos_ocv03_o3f8_r13_targeted_results_v1",
        "state": "COMPLETE_O3F8_R13_TARGETED" if complete else "HOLD_O3F8_R13_TARGETED",
        "scheduledCount": 11,
        "executedPassCount": passed,
        "executionHoldCount": 11 - passed,
        "maximumDfCandidateCount": max((int(row.get("dfCandidateCount", -1)) for row in rows), default=-1),
        "stateCounts": dict(Counter(str(row["finalState"]) for row in rows)),
        "rows": rows,
        "r13Sha256": R13_SHA256,
        "numericThresholdRelaxationPerformed": False,
        "postResultSelectorRelaxationPerformed": False,
        "sourceMutation": False,
        "providerActivated": False,
        "holdsCleared": False,
        "retryAuthorized": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    mirror_json(frozen, output_root, mirror_root, "RESULTS.json", result)
    mirror_json(frozen, output_root, mirror_root, "PROGRESS.json", progress(rows, targets, terminal=True))
    return {key: result[key] for key in ("state", "scheduledCount", "executedPassCount", "executionHoldCount", "maximumDfCandidateCount")}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("SELF_TEST", "PREFLIGHT", "RUN"))
    parser.add_argument("--output-root")
    parser.add_argument("--mirror-root")
    args = parser.parse_args()
    if args.stage == "SELF_TEST":
        need(not args.output_root and not args.mirror_root, "SELF_TEST accepts no paths")
        load_l4()
        result = {
            "schema": "argos_ocv03_o3f8_r13_targeted_self_test_v1",
            "state": "PASS_O3F8_R13_TARGETED_SELF_TEST",
            "r13Sha256": R13_SHA256,
            "mutationsPerformed": False,
        }
    elif args.stage == "PREFLIGHT":
        need(not args.output_root and not args.mirror_root, "PREFLIGHT accepts no paths")
        result = preflight()
    else:
        need(args.output_root and args.mirror_root, "RUN requires both output roots")
        result = run(Path(args.output_root), Path(args.mirror_root))
    print(json.dumps(result, separators=(",", ":")))
    return 0 if str(result["state"]).startswith(("PASS_", "COMPLETE_")) else 2


if __name__ == "__main__":
    raise SystemExit(main())
