#!/usr/bin/env python3
"""Pure focused gate for the O3F15 FULL978 orchestration contract."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from typing import Any


HERE = Path(__file__).resolve().parent
RUNNER = HERE / "Run-O3F15FrontReconcile.py"


def need(value: Any, message: str) -> None:
    if not value:
        raise RuntimeError(message)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def load_runner() -> Any:
    spec = importlib.util.spec_from_file_location("argos_o3f15_focused_runner", RUNNER)
    need(spec is not None and spec.loader is not None, "Cannot load O3F15 runner")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def attach_sources(rows: list[dict[str, Any]]) -> None:
    for index, row in enumerate(rows):
        anchor = str(row["identity"]).split("|FRONT", 1)[0]
        for channel, key, directory in (("BF", "bf", "BrightfieldFrontsideWafer"), ("DF", "df", "DarkfieldFrontsideWafer")):
            row[key] = {
                "path": rf"D:\KLARFExport\{anchor}\{directory}\resizedImage\source_{index:04d}_{channel.lower()}.png",
                "bytes": 1000 + index,
                "sha256": hashlib.sha256(f"{index}:{channel}".encode()).hexdigest().upper(),
            }


def synthetic_o3f14(runner: Any, rows: list[dict[str, Any]], cases: list[dict[str, Any]]) -> dict[str, Any]:
    frozen = {str(row["identity"]): row for row in rows}
    results = []
    for identity in [str(case["identity"]) for case in cases[:6]]:
        row = frozen[identity]
        results.append(
            {
                "identity": identity,
                "safeId": row["safeId"],
                "priorR8State": row["r8State"],
                "finalState": runner.O3F14_EXPECTED_FINAL[identity],
                "execution": "PASS_R11_CHILD",
                "error": None,
                "r11Invoked": True,
                "physicalClusterCount": 0 if identity.endswith("Slot16|FRONT") else (2 if identity.endswith("Slot02|FRONT") else 1),
                "selectedClusterDirections": [] if identity.endswith(("Slot02|FRONT", "Slot16|FRONT")) else ["BF_SEEDED_LOCAL_DF"],
                "dfSeedCount": 0,
                "bfSeedCount": 1,
                "bfHypothesisCount": 1,
            }
        )
    return {
        "schema": "argos_ocv03_o3f14_r11_dev6_result_v1",
        "state": "COMPLETE_O3F14_DEV6",
        "runnerSha256": runner.O3F14_RUNNER_SHA256,
        "r11Sha256": runner.R11_SHA256,
        "sourceResultsSha256": runner.SOURCE_RESULTS_SHA256,
        "reviewOrderSha256": runner.REVIEW_ORDER_SHA256,
        "selectedCount": 6,
        "executedCount": 6,
        "newProviderHoldCount": 0,
        "numericThresholdRelaxationPerformed": False,
        "postResultSelectorRelaxationPerformed": False,
        "results": results,
    }


def run_tests() -> dict[str, Any]:
    runner = load_runner()
    rows, cases = runner.synthetic_frozen_inputs()
    attach_sources(rows)
    cohorts = runner.partition(rows, cases)
    ordered = cohorts["ordered978"]
    partition_checks = {
        "exactCohorts": [len(cohorts[k]) for k in ("holdout18", "currentTail247", "fullTail713")] == [18, 247, 713],
        "fullUnionUnique": len(ordered) == len({str(row["identity"]) for row in ordered}) == 978,
        "stageBoundaries": {str(row["identity"]) for row in ordered[:18]} == {str(case["identity"]) for case in cases[6:]}
        and all(runner.is_current(str(row["identity"])) for row in ordered[:265])
        and not any(runner.is_current(str(row["identity"])) for row in ordered[265:]),
        "fiveProviderErrorsFresh": sum(str(row["r8State"]) == runner.PROVIDER_ERROR_STATE for row in ordered) == 5,
        "o3f14SixRemainFresh": set(cohorts["dev6Ids"]).issubset({str(row["identity"]) for row in ordered[18:265]}),
    }
    _, o3f14 = runner.dependencies()
    plans = runner.generalized_alias_plans(ordered, o3f14, check_files=False)
    alias_checks = {
        "all978Planned": len(plans) == 978,
        "oneSlotAliasPerCase": all(plan["bf"]["slotRoot"] == plan["df"]["slotRoot"] for plan in plans),
        "allUnderExactExportRoot": all(str(plan["bf"]["canonicalPath"]).lower().startswith("d:\\klarfexport\\") for plan in plans),
        "nonPatternedFamiliesAccepted": any(str(plan["identity"]).startswith("LegacyFront\\") for plan in plans),
    }
    comparison = runner.validate_o3f14(synthetic_o3f14(runner, rows, cases), rows, cases, check_files=False)
    o3f14_checks = {
        "exactSixCompared": len(comparison) == 6,
        "ambiguityPreserved": comparison[next(i for i in comparison if i.endswith("Slot02|FRONT"))]["finalState"].startswith("HOLD_MULTIPLE"),
        "hotspotPreserved": comparison[next(i for i in comparison if i.endswith("Slot16|FRONT"))]["finalState"] == "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH",
    }
    compact = [runner.compact_result(i, row, "PASS_R11_FRESH", str(row["r8State"]), str(row["r8State"]), False, "A" * 64, None) for i, row in enumerate(ordered, 1)]
    payload = {"schema": "argos_ocv03_o3f15_front_reconciliation_results_v1", "state": "COMPLETE_O3F15_FULL978", "rowCount": 978, "executedCount": 978, "rows": compact}
    path_plan = runner.output_path_gate(Path(r"D:\O3F15C"), Path(r"D:\KLARFExport\_ArgosReview\F15S"), ordered)
    size_checks = {
        "resultsUnder2MiB": len(runner.json_bytes(payload)) < runner.MAX_MIRROR_BYTES,
        "progressUnder2MiB": len(runner.json_bytes(runner.progress_value(compact, False, []))) < runner.MAX_MIRROR_BYTES,
        "allKnownOutputLeavesPathSafe": int(path_plan["maximumEffectivePathLength"]) < 200,
        "allKnownOutputComponentsSafe": int(path_plan["maximumComponentLength"]) <= 80,
        "fullCountNotTerminalBeforeCommit": runner.progress_value(compact, False, [])["state"] == "RUNNING_O3F15_FULL978",
        "terminalOnlyAfterCommit": runner.progress_value(compact, False, [], terminal=True)["state"] == "COMPLETE_O3F15_FULL978",
    }
    passed = all(partition_checks.values()) and all(alias_checks.values()) and all(o3f14_checks.values()) and all(size_checks.values())
    return {
        "schema": "argos_ocv03_o3f15_front_reconcile_focused_gate_v1",
        "state": "PASS_O3F15_FRONT_RECONCILE_FOCUSED_GATE" if passed else "FAIL_O3F15_FRONT_RECONCILE_FOCUSED_GATE",
        "runnerSha256": digest(RUNNER),
        "testSha256": digest(Path(__file__).resolve()),
        "partitionChecks": partition_checks,
        "aliasChecks": alias_checks,
        "o3f14Checks": o3f14_checks,
        "sizeChecks": size_checks,
        "sourceImageBytesRead": False,
        "sourceMutation": False,
        "providerActivated": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output")
    args = parser.parse_args()
    result = run_tests()
    if args.output:
        output = Path(args.output)
        need(not output.exists(), "Output already exists")
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(result, separators=(",", ":")))
    need(result["state"] == "PASS_O3F15_FRONT_RECONCILE_FOCUSED_GATE", "O3F15 focused gate failed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
