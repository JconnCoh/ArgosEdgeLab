#!/usr/bin/env python3
"""No-image fixture for the exact O3F9 endpoint orchestration rehearsal."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def write_new(path: Path, value: object) -> None:
    partial = path.with_name(path.name + ".partial")
    if path.exists() or partial.exists():
        raise RuntimeError(f"fixture output exists: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def fail_if(stage: str) -> None:
    if os.environ.get("ARGOS_O3F9_FIXTURE_FAIL_STAGE", "").upper() == stage:
        raise RuntimeError(f"INJECTED_O3F9_{stage}_FAILURE")


def gate(root: Path) -> dict[str, object]:
    fail_if("GATE")
    summary = {
        "schema": "argos_ocv03_o3f9_gate_result_v1",
        "state": "COMPLETE_O3F9_GATE",
        "stage": "GATE",
        "fixtureOnly": True,
        "imageBytesRead": False,
        "sourceMutation": False,
        "providerActivated": False,
    }
    target = root / "SUMMARY.json"
    write_new(target, summary)
    return {"state": "COMPLETE_O3F9_GATE", "stage": "GATE", "summarySha256": sha256(target)}


def fixture_observation(index: int) -> dict[str, object]:
    passing = index < 6
    correspondence = {
        "correspondenceMethod": "MOUTH_INTERVAL_OVERLAP" if index == 5 else "CENTER_TOLERANCE",
        "centerGapDegrees": 1.931 if index == 5 else 0.25,
        "mouthIntervalOverlapDegrees": 0.141 if index == 5 else 1.1,
    }
    hypothesis = {
        "hypothesisId": f"B{index:03d}-D001",
        "direction": "BF_SEEDED_LOCAL_DF",
        "correspondence": correspondence,
        "eligible": passing,
    }
    eligible = [hypothesis] if passing else []
    clusters = [{"clusterId": "R10C001", "hypothesisIndices": [0], "hypothesisIds": [hypothesis["hypothesisId"]], "directions": [hypothesis["direction"]]}] if passing else []
    return {
        "pairId": f"fixture_{index:02d}",
        "state": "PASS_REVIEW_ONLY_R10_SYMMETRIC_LOCAL_CROSS_CHANNEL_NOTCH_CANDIDATE" if passing else "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH",
        "baselineR8State": "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH",
        "inheritedR9State": "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH",
        "o3p8DfSeededLocalBfRecovery": {"seedCount": 1, "eligibleSeedIndices": [0] if passing else [], "seeds": [hypothesis]},
        "bfSeededLocalDfRecovery": {"seedCount": 1, "hypothesisCount": 1, "eligibleHypothesisIndices": [0] if passing else [], "hypotheses": [hypothesis]},
        "r10SymmetricRecovery": {"state": "FIXTURE", "invoked": True, "eligibleHypotheses": eligible, "physicalClusters": clusters, "selectedCluster": clusters[0] if passing else None},
    }


def dev6(root: Path, prerequisite: Path, expected_sha256: str) -> dict[str, object]:
    fail_if("DEV6")
    if not prerequisite.is_file() or sha256(prerequisite) != expected_sha256.upper():
        raise RuntimeError("fixture GATE prerequisite changed")
    results: list[dict[str, object]] = []
    state_counts: dict[str, int] = {}
    for index in range(1, 7):
        observed = fixture_observation(index)
        manifest_path = root / "cases" / f"C{index:04d}" / "MANIFEST.json"
        manifest = {"schema": "argos_ocv03_full_perimeter_topology_manifest_v2", "revision": f"O3F9_FIXTURE_{index:04d}", "results": [observed]}
        write_new(manifest_path, manifest)
        state = str(observed["state"])
        state_counts[state] = state_counts.get(state, 0) + 1
        results.append({"identity": f"fixture_identity_{index:02d}", "safeId": f"fixture_{index:02d}", "priorR8State": "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH", "state": state, "manifestPath": str(manifest_path), "manifestSha256": sha256(manifest_path), "execution": "PASS_R10_CHILD", "error": ""})
    summary = {
        "schema": "argos_ocv03_o3f9_staged_result_v1",
        "state": "COMPLETE_O3F9_DEV6",
        "stage": "DEV6",
        "selectedCount": 6,
        "executedCount": 6,
        "preservedProviderHoldCount": 0,
        "newProviderHoldCount": 0,
        "stateCounts": state_counts,
        "results": results,
        "fixtureOnly": True,
        "imageBytesRead": False,
        "sourceMutation": False,
        "providerActivated": False,
    }
    target = root / "SUMMARY.json"
    write_new(target, summary)
    return {key: summary[key] for key in ("state", "stage", "selectedCount", "executedCount", "preservedProviderHoldCount", "newProviderHoldCount", "stateCounts")} | {"summarySha256": sha256(target)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("SELF_TEST", "PREFLIGHT", "GATE", "DEV6"))
    parser.add_argument("--output-root")
    parser.add_argument("--prerequisite-summary")
    parser.add_argument("--prerequisite-sha256")
    args = parser.parse_args()
    fail_if(args.stage)
    if args.stage == "SELF_TEST":
        print("PASS_O3F9_STAGED_RUNNER_SELF_TEST")
        return 0
    if args.stage == "PREFLIGHT":
        print('{"state":"PASS_O3F9_STAGED_PREFLIGHT","mutationsPerformed":false}')
        return 0
    if not args.output_root:
        raise RuntimeError("fixture output root is required")
    if args.stage == "GATE":
        result = gate(Path(args.output_root))
    else:
        if not args.prerequisite_summary or not args.prerequisite_sha256:
            raise RuntimeError("fixture DEV6 prerequisite is required")
        result = dev6(Path(args.output_root), Path(args.prerequisite_summary), args.prerequisite_sha256)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
