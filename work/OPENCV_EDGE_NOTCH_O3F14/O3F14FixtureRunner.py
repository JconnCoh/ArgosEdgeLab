#!/usr/bin/env python3
"""No-image fixture for the exact O3F14 endpoint orchestration rehearsal."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time


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
    if os.environ.get("ARGOS_O3F14_FIXTURE_FAIL_STAGE", "").upper() == stage:
        raise RuntimeError(f"INJECTED_O3F14_{stage}_FAILURE")


def timeout_with_owned_alias() -> None:
    if os.environ.get("ARGOS_O3F14_FIXTURE_FAIL_STAGE", "").upper() != "DEV6_TIMEOUT_ALIAS":
        return
    subst_text = os.environ.get("ARGOS_O3F14_FIXTURE_SUBST_PATH", "")
    anchor_text = os.environ.get("ARGOS_O3F14_FIXTURE_ALIAS_ANCHOR", "")
    subst = Path(subst_text)
    anchor = Path(anchor_text)
    if not subst.is_absolute() or not subst.is_file() or not anchor.is_absolute() or not anchor.is_dir():
        raise RuntimeError("O3F14 timeout-alias fixture environment is invalid")

    def mappings() -> dict[str, str]:
        child = subprocess.run([str(subst)], capture_output=True, text=True, timeout=30)
        if child.returncode != 0 or child.stderr:
            raise RuntimeError("O3F14 timeout-alias subst query failed")
        result: dict[str, str] = {}
        for raw in child.stdout.splitlines():
            left, separator, right = raw.strip().partition("=>")
            if separator:
                result[left.strip()[:2].upper()] = right.strip()
        return result

    if "Q:" in mappings():
        raise RuntimeError("O3F14 timeout-alias Q: is already mapped")
    create = subprocess.run([str(subst), "Q:", str(anchor)], capture_output=True, text=True, timeout=30)
    if create.returncode != 0 or create.stderr:
        raise RuntimeError("O3F14 timeout-alias creation failed")
    target = mappings().get("Q:")
    if target is None or os.path.normcase(os.path.normpath(target)) != os.path.normcase(os.path.normpath(str(anchor))):
        raise RuntimeError("O3F14 timeout-alias target verification failed")
    time.sleep(3600)  # Endpoint timeout/backstop must own cleanup for this injected case.
    raise RuntimeError("O3F14 timeout-alias fixture unexpectedly resumed")


def gate(root: Path) -> dict[str, object]:
    fail_if("GATE")
    summary = {
        "schema": "argos_ocv03_o3f14_gate_result_v1",
        "state": "COMPLETE_O3F14_GATE",
        "stage": "GATE",
        "fixtureOnly": True,
        "imageBytesRead": False,
        "sourceMutation": False,
        "providerActivated": False,
        "commands": [],
    }
    target = root / "SUMMARY.json"
    write_new(target, summary)
    return {"state": "COMPLETE_O3F14_GATE", "stage": "GATE", "summarySha256": sha256(target), "commands": []}


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
    mode = os.environ.get("ARGOS_O3F14_FIXTURE_DEV6_MODE", "COMPLETE").upper()
    hold_result = mode in {"HOLD", "EXIT0_HOLD", "EXIT3_HOLD", "MALFORMED", "TWO_OBJECTS", "STDERR"}
    results: list[dict[str, object]] = []
    state_counts: dict[str, int] = {}
    for index in range(1, 7):
        if hold_result and index == 6:
            state = "HOLD_O3F14_R11_PROVIDER_ERROR"
            state_counts[state] = state_counts.get(state, 0) + 1
            results.append({"ordinal": index, "identity": f"fixture_identity_{index:02d}", "safeId": f"fixture_{index:02d}", "priorR8State": "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH", "baselineState": None, "inheritedR9State": None, "finalState": state, "r11Invoked": False, "physicalClusterCount": 0, "selectedClusterDirections": [], "dfSeedCount": 0, "dfSeedEligibleCount": 0, "bfSeedCount": 0, "bfHypothesisCount": 0, "bfHypothesisEligibleCount": 0, "eligibleHypotheses": [], "execution": "HOLD_R11_CHILD", "error": "INJECTED_O3F14_STRUCTURED_PROVIDER_HOLD"})
            continue
        observed = fixture_observation(index)
        manifest_path = root / "cases" / f"C{index:04d}" / "MANIFEST.json"
        manifest = {"schema": "argos_ocv03_full_perimeter_topology_manifest_v2", "revision": f"O3F14_FIXTURE_{index:04d}", "results": [observed]}
        write_new(manifest_path, manifest)
        state = str(observed["state"])
        state_counts[state] = state_counts.get(state, 0) + 1
        results.append({"identity": f"fixture_identity_{index:02d}", "safeId": f"fixture_{index:02d}", "priorR8State": "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH", "state": state, "manifestPath": str(manifest_path), "manifestSha256": sha256(manifest_path), "execution": "PASS_R11_CHILD", "error": ""})
    executed_count = 5 if hold_result else 6
    hold_count = 1 if hold_result else 0
    summary = {
        "schema": "argos_ocv03_o3f14_staged_result_v1",
        "state": "HOLD_O3F14_DEV6_EXECUTION" if hold_result else "COMPLETE_O3F14_DEV6",
        "stage": "DEV6",
        "selectedCount": 6,
        "executedCount": executed_count,
        "newProviderHoldCount": hold_count,
        "stateCounts": state_counts,
        "results": results,
        "fixtureOnly": True,
        "imageBytesRead": False,
        "sourceMutation": False,
        "providerActivated": False,
    }
    target = root / "SUMMARY.json"
    write_new(target, summary)
    alias_evidence = {"state": "NOT_APPLICABLE_IMAGE_FREE_FIXTURE", "aliasDrive": "Q:", "prevalidatedCaseCount": 6, "executedCaseCount": 0, "allMappingsRemovedAndVerifiedAbsent": True, "cases": []}
    summary["aliasEvidence"] = alias_evidence
    return {key: summary[key] for key in ("state", "stage", "selectedCount", "executedCount", "newProviderHoldCount", "stateCounts", "aliasEvidence", "results")} | {"summarySha256": sha256(target)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("SELF_TEST", "PREFLIGHT", "GATE", "DEV6"))
    parser.add_argument("--output-root")
    parser.add_argument("--prerequisite-summary")
    parser.add_argument("--prerequisite-sha256")
    args = parser.parse_args()
    fail_if(args.stage)
    if args.stage == "SELF_TEST":
        print(json.dumps({"state": "PASS_O3F14_STAGED_RUNNER_SELF_TEST", "mutationsPerformed": False}, separators=(",", ":")))
        return 0
    if args.stage == "PREFLIGHT":
        print('{"state":"PASS_O3F14_STAGED_PREFLIGHT","mutationsPerformed":false}')
        return 0
    if not args.output_root:
        raise RuntimeError("fixture output root is required")
    if args.stage == "GATE":
        result = gate(Path(args.output_root))
    else:
        if not args.prerequisite_summary or not args.prerequisite_sha256:
            raise RuntimeError("fixture DEV6 prerequisite is required")
        timeout_with_owned_alias()
        result = dev6(Path(args.output_root), Path(args.prerequisite_summary), args.prerequisite_sha256)
    mode = os.environ.get("ARGOS_O3F14_FIXTURE_DEV6_MODE", "COMPLETE").upper() if args.stage == "DEV6" else "COMPLETE"
    if mode == "MALFORMED":
        print('{not-json')
    elif mode == "TWO_OBJECTS":
        print(json.dumps(result, separators=(",", ":")) + "\n" + json.dumps(result, separators=(",", ":")))
    else:
        print(json.dumps(result, separators=(",", ":")))
    if mode == "STDERR":
        print("INJECTED_O3F14_STDERR", file=os.sys.stderr)
    if mode == "EXIT0_HOLD":
        return 0
    if mode == "EXIT2_COMPLETE":
        return 2
    if mode == "EXIT3_HOLD":
        return 3
    return 2 if mode in {"HOLD", "MALFORMED", "TWO_OBJECTS", "STDERR"} else 0


if __name__ == "__main__":
    raise SystemExit(main())
