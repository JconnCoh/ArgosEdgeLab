#!/usr/bin/env python3
"""Fresh, staged R11 reconciliation of the frozen 978-pair front corpus."""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any


HERE = Path(__file__).resolve().parent
BASE_RUNNER = HERE / "Run-O3F8Staged.py"
O3F14_RUNNER = HERE / "Run-O3F14Staged.py"
R11 = HERE / "FullPerimeterWaferTopologyOpenCvR11.py"
FOCUSED_TEST = HERE / "Test-O3F15FrontReconcile.py"
CANONICAL_JOB = HERE / "O3M9_SLOT16_JOB.json"
O3F14_SUMMARY = Path(r"D:\O3F9D14\SUMMARY.json")
GATE_ROOT = Path(r"D:\O3F15G")
RUN_ROOT = Path(r"D:\O3F15C")
MIRROR_ROOT = Path(r"D:\KLARFExport\_ArgosReview\F15S")
EXPORT_ROOT = Path(r"D:\KLARFExport")
RUNTIME = Path(r"D:\AFCV1\rt\python.exe")

BASE_RUNNER_SHA256 = "44B378616CCCFEB0C67DF09196D0B7CDD515DBE35CEA84F4DBEB69DE326AD8C7"
O3F14_RUNNER_SHA256 = "CAAFD1AC8C19E33D95BA8283963A4D0ED0189FF566C9923822BF3EC37956171E"
R11_SHA256 = "B477C290EC9D3AE388BE4EE31049B2B8094F5F30FC6E0DD68AB4A03926EE4059"
FOCUSED_TEST_SHA256 = "37F1D9980CA0635673D39B3E9B5EBC2BCF21021EB329ABD8C64820F518FC6C47"
CANONICAL_JOB_SHA256 = "E384ABD12E9B77DB9B4492504A5D792E316C5396C3B0A3E1D2B1AB11BB4C7DD3"
SOURCE_RESULTS_SHA256 = "A933227FE4F41259D53D586CBB5189E1B6542B96B7585B606207DAFD35326BD8"
REVIEW_ORDER_SHA256 = "D57DFE4301FEE2144D18EF4DB2BFD0A323EB095C117BBF10A856A691A8E73BBA"
O3F14_SUMMARY_SHA256 = "22B2CE0A05D2AD5802717CAE13F5E425DAB77D16B224CEE6FBBED3782E0050B3"
PASS_STATE = "PASS_REVIEW_ONLY_BF_TOPOLOGY_DF_RADIAL_NOTCH_CANDIDATE"
PROVIDER_ERROR_STATE = "HOLD_FRONT_NOTCH_PROVIDER_ERROR"
MAX_MIRROR_BYTES = 2 * 1024 * 1024
_BASE: Any | None = None
_O3F14: Any | None = None


class CaseExecutionError(RuntimeError):
    def __init__(self, message: str, *, child_launch_attempted: bool, child_exit_code: int | None, manifest_path: str | None, manifest_sha256: str | None, baseline_state: str | None, final_state: str | None, r11_invoked: bool | None) -> None:
        super().__init__(message)
        self.child_launch_attempted = child_launch_attempted
        self.child_exit_code = child_exit_code
        self.manifest_path = manifest_path
        self.manifest_sha256 = manifest_sha256
        self.baseline_state = baseline_state
        self.final_state = final_state
        self.r11_invoked = r11_invoked

O3F14_EXPECTED_FINAL = {
    "PatternedFront\\Lot_62615-962\\62615-962_20260830004716\\Slot01|FRONT": "PASS_REVIEW_ONLY_R10_SYMMETRIC_LOCAL_CROSS_CHANNEL_NOTCH_CANDIDATE",
    "PatternedFront\\Lot_62615-962\\62615-962_20260830004716\\Slot02|FRONT": "HOLD_MULTIPLE_R10_SYMMETRIC_LOCAL_CROSS_CHANNEL_NOTCHES",
    "PatternedFront\\Lot_62615-962\\62615-962_20260830004716\\Slot04|FRONT": "PASS_REVIEW_ONLY_R10_SYMMETRIC_LOCAL_CROSS_CHANNEL_NOTCH_CANDIDATE",
    "PatternedFront\\Lot_62615-962\\62615-962_20260830004716\\Slot08|FRONT": "PASS_REVIEW_ONLY_R10_SYMMETRIC_LOCAL_CROSS_CHANNEL_NOTCH_CANDIDATE",
    "PatternedFront\\Lot_62616-131\\62616-131_20260825233731\\Slot09|FRONT": "PASS_REVIEW_ONLY_R10_SYMMETRIC_LOCAL_CROSS_CHANNEL_NOTCH_CANDIDATE",
    "PatternedFront\\Lot_62629-419_NotchBad_Hotspot\\62629-419_20260824112405\\Slot16|FRONT": "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH",
}


def need(value: Any, message: str) -> None:
    if not value:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def required_sha256(value: Any, label: str) -> str:
    text = str(value or "").upper()
    need(len(text) == 64 and all(c in "0123456789ABCDEF" for c in text), f"{label} is not an exact SHA-256")
    return text


def read_json_and_sha256(path: Path) -> tuple[dict[str, Any], str]:
    data = path.read_bytes()
    value = json.loads(data.decode("utf-8"))
    need(isinstance(value, dict), f"JSON root is not an object: {path}")
    return value, hashlib.sha256(data).hexdigest().upper()


def json_bytes(value: Any) -> bytes:
    return (json.dumps(value, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")


def atomic_bytes(path: Path, data: bytes, replace: bool = False, bounded: bool = False) -> None:
    if bounded:
        need(len(data) < MAX_MIRROR_BYTES, f"Mirror leaf exceeds 2 MiB: {path.name}")
    partial = path.with_name(path.name + ".partial")
    need(not partial.exists(), f"Partial output collision: {partial}")
    if not replace:
        need(not path.exists(), f"Output collision: {path}")
    partial.write_bytes(data)
    os.replace(partial, path)


def atomic_json(path: Path, value: Any, replace: bool = False, bounded: bool = False) -> bytes:
    data = json_bytes(value)
    atomic_bytes(path, data, replace=replace, bounded=bounded)
    return data


def mirror_json(output_root: Path, mirror_root: Path, name: str, value: Any, replace: bool = False) -> bytes:
    data = json_bytes(value)
    need(len(data) < MAX_MIRROR_BYTES, f"Mirror leaf exceeds 2 MiB before write: {name}")
    atomic_bytes(output_root / name, data, replace=replace)
    atomic_bytes(mirror_root / name, data, replace=replace, bounded=True)
    return data


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    need(spec is not None and spec.loader is not None, f"Cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def dependencies() -> tuple[Any, Any]:
    global _BASE, _O3F14
    need(BASE_RUNNER.is_file() and sha256(BASE_RUNNER) == BASE_RUNNER_SHA256, "O3F8 base runner pin changed")
    need(O3F14_RUNNER.is_file() and sha256(O3F14_RUNNER) == O3F14_RUNNER_SHA256, "O3F14 runner pin changed")
    if _BASE is None:
        _BASE = load_module("argos_o3f15_o3f8_base", BASE_RUNNER)
    if _O3F14 is None:
        _O3F14 = load_module("argos_o3f15_o3f14_base", O3F14_RUNNER)
    return _BASE, _O3F14


def is_current(identity: str) -> bool:
    return identity.startswith(("PatternedFront\\", "UnpatternedFront\\"))


def partition(rows: list[dict[str, Any]], cases: list[dict[str, Any]]) -> dict[str, Any]:
    need(len(rows) == 978 and len(cases) == 24, "Frozen input cardinality changed")
    by_identity = {str(row["identity"]): row for row in rows}
    need(len(by_identity) == 978 and len({str(row["safeId"]) for row in rows}) == 978, "Frozen identities are not unique")
    case_ids = [str(case["identity"]) for case in cases]
    need(len(set(case_ids)) == 24 and set(case_ids).issubset(by_identity), "Frozen review identities changed")
    for case in cases:
        row = by_identity[str(case["identity"])]
        need(str(case["safeId"]) == str(row["safeId"]) and str(case["state"]) == str(row["r8State"]), "Review/source binding changed")
    counts = Counter(str(row["r8State"]) for row in rows)
    need(counts == Counter({PASS_STATE: 794, "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH": 129, "HOLD_DF_RADIAL_FULL_PERIMETER_NOT_QUALIFIED": 50, PROVIDER_ERROR_STATE: 5}), "Frozen R8 state counts changed")
    dev6_ids = case_ids[:6]
    need(set(dev6_ids) == set(O3F14_EXPECTED_FINAL), "O3F14 DEV6 identity set changed")
    holdout_ids = case_ids[6:]
    need(len(holdout_ids) == 18 and sum(str(by_identity[i]["r8State"]).startswith("HOLD") for i in holdout_ids) == 6, "HOLDOUT18 composition changed")
    need(sum(str(by_identity[i]["r8State"]) == PASS_STATE for i in holdout_ids) == 12, "HOLDOUT18 controls changed")
    current = [row for row in rows if is_current(str(row["identity"]))]
    need(len(current) == 265 and set(holdout_ids).issubset({str(row["identity"]) for row in current}), "CURRENT265 composition changed")
    holdout = [by_identity[i] for i in holdout_ids]
    current_tail = [row for row in current if str(row["identity"]) not in set(holdout_ids)]
    full_tail = [row for row in rows if not is_current(str(row["identity"]))]
    ordered = holdout + current_tail + full_tail
    need((len(holdout), len(current_tail), len(full_tail), len(ordered)) == (18, 247, 713, 978), "O3F15 cohort counts changed")
    need(len({str(row["identity"]) for row in ordered}) == 978, "O3F15 union duplicates or omits identities")
    need(sum(str(row["r8State"]) == PROVIDER_ERROR_STATE for row in ordered) == 5, "All five provider-error rows are not scheduled fresh")
    return {"holdout18": holdout, "currentTail247": current_tail, "fullTail713": full_tail, "ordered978": ordered, "dev6Ids": dev6_ids}


def validate_o3f14(summary: dict[str, Any], rows: list[dict[str, Any]], cases: list[dict[str, Any]], check_files: bool) -> dict[str, dict[str, Any]]:
    need(summary.get("schema") == "argos_ocv03_o3f14_r11_dev6_result_v1" and summary.get("state") == "COMPLETE_O3F14_DEV6", "O3F14 summary state changed")
    need(summary.get("runnerSha256") == O3F14_RUNNER_SHA256 and summary.get("r11Sha256") == R11_SHA256, "O3F14 engine pins changed")
    need(summary.get("sourceResultsSha256") == SOURCE_RESULTS_SHA256 and summary.get("reviewOrderSha256") == REVIEW_ORDER_SHA256, "O3F14 frozen inputs changed")
    need(summary.get("selectedCount") == 6 and summary.get("executedCount") == 6 and summary.get("newProviderHoldCount") == 0, "O3F14 execution counts changed")
    need(summary.get("numericThresholdRelaxationPerformed") is False and summary.get("postResultSelectorRelaxationPerformed") is False, "O3F14 relaxation flag changed")
    results = summary.get("results")
    need(isinstance(results, list) and len(results) == 6, "O3F14 result cardinality changed")
    expected_ids = [str(case["identity"]) for case in cases[:6]]
    need([str(row.get("identity")) for row in results] == expected_ids, "O3F14 result order changed")
    frozen = {str(row["identity"]): row for row in rows}
    by_identity: dict[str, dict[str, Any]] = {}
    for result in results:
        identity = str(result["identity"])
        source = frozen[identity]
        need(str(result["safeId"]) == str(source["safeId"]), f"O3F14 safeId changed: {identity}")
        need(str(result["priorR8State"]) == str(source["r8State"]), f"O3F14 prior state changed: {identity}")
        need(result.get("execution") == "PASS_R11_CHILD" and not result.get("error"), f"O3F14 execution evidence changed: {identity}")
        need(str(result["finalState"]) == O3F14_EXPECTED_FINAL[identity], f"O3F14 final state changed: {identity}")
        if check_files:
            manifest = Path(str(result.get("manifestPath") or ""))
            need(manifest.is_file() and sha256(manifest) == required_sha256(result.get("manifestSha256"), f"O3F14 manifest {identity}"), f"O3F14 manifest changed: {identity}")
        by_identity[identity] = result
    return by_identity


def generalized_alias_plans(selected: list[dict[str, Any]], o3f14: Any, check_files: bool = True) -> list[dict[str, Any]]:
    plans: list[dict[str, Any]] = []
    for ordinal, row in enumerate(selected, 1):
        identity = str(row["identity"])
        anchor = o3f14.identity_slot_anchor(identity)
        channels: dict[str, dict[str, Any]] = {}
        for channel, key, directory in (("BF", "bf", "BrightfieldFrontsideWafer"), ("DF", "df", "DarkfieldFrontsideWafer")):
            source = row[key]
            canonical = Path(str(source["path"]))
            need(canonical.is_absolute() and canonical.drive.upper() == "D:", f"{channel} source is not absolute JBOD D:: {identity}")
            try:
                canonical.relative_to(EXPORT_ROOT)
            except ValueError as exc:
                raise o3f14.AliasContractError(f"{channel} source escaped exact KLARFExport root: {identity}") from exc
            need(canonical.parent.name == "resizedImage" and canonical.parent.parent.name == directory, f"{channel} suffix changed: {identity}")
            slot_root = canonical.parent.parent.parent
            need(canonical.relative_to(slot_root).parts == (directory, "resizedImage", canonical.name), f"{channel} slot suffix changed: {identity}")
            relative_anchor = slot_root.relative_to(EXPORT_ROOT)
            need(o3f14.normalized_windows_path(relative_anchor) == o3f14.normalized_windows_path(anchor), f"{channel} identity/path binding changed:: {identity}")
            expected_bytes = int(source["bytes"])
            pinned = required_sha256(source["sha256"], f"{channel} source {identity}")
            if check_files:
                need(canonical.is_file() and canonical.stat().st_size == expected_bytes, f"{channel} source missing or byte count changed: {identity}")
            alias = o3f14.ALIAS_ROOT / directory / "resizedImage" / canonical.name
            channels[key] = {"canonicalPath": canonical, "aliasPath": alias, "slotRoot": slot_root, "bytes": expected_bytes, "sha256": pinned, "canonicalBudget": o3f14.alias_path_budget(canonical, o3f14.CANONICAL_EFFECTIVE_LIMIT, f"{channel} canonical"), "aliasBudget": o3f14.alias_path_budget(alias, o3f14.ALIAS_EFFECTIVE_LIMIT, f"{channel} alias")}
        need(o3f14.normalized_windows_path(channels["bf"]["slotRoot"]) == o3f14.normalized_windows_path(channels["df"]["slotRoot"]), f"BF/DF slot roots differ: {identity}")
        if check_files:
            need(os.path.samefile(channels["bf"]["slotRoot"], channels["df"]["slotRoot"]), f"BF/DF slot roots are not the same object: {identity}")
        plans.append({"ordinal": ordinal, "identity": identity, "safeId": str(row["safeId"]), "identityAnchor": anchor, "slotRoot": channels["bf"]["slotRoot"], "bf": channels["bf"], "df": channels["df"]})
    need(len(plans) == 978 and len({p["identity"] for p in plans}) == 978, "Alias plan does not cover exact FULL978")
    return plans


def preflight_context() -> dict[str, Any]:
    base, o3f14 = dependencies()
    need(R11.is_file() and sha256(R11) == R11_SHA256, "R11 pin changed")
    need(FOCUSED_TEST.is_file() and sha256(FOCUSED_TEST) == FOCUSED_TEST_SHA256, "O3F15 focused-test pin changed")
    need(CANONICAL_JOB.is_file() and sha256(CANONICAL_JOB) == CANONICAL_JOB_SHA256, "Canonical job pin changed")
    o3f14.preflight()
    rows, cases = base.frozen_inputs()
    cohorts = partition(rows, cases)
    summary, summary_sha = read_json_and_sha256(O3F14_SUMMARY)
    need(summary_sha == O3F14_SUMMARY_SHA256, "O3F14 summary hash changed")
    comparison = validate_o3f14(summary, rows, cases, check_files=True)
    canonical, canonical_sha = read_json_and_sha256(CANONICAL_JOB)
    need(canonical_sha == CANONICAL_JOB_SHA256, "Canonical job changed")
    fixed = base.fixed_job_projection(canonical)
    case_by_identity = {str(case["identity"]): case for case in cases}
    prior: dict[str, dict[str, Any]] = {}
    for row in cohorts["ordered978"]:
        identity = str(row["identity"])
        if str(row["r8State"]) == PROVIDER_ERROR_STATE:
            prior[identity] = {"classification": "FRESH_PRIOR_PROVIDER_ERROR"}
            continue
        expected_hash = None
        if identity in case_by_identity:
            reference = base.review_manifest_reference(row, case_by_identity[identity])
            need(reference is not None, f"Non-provider review row lacks manifest: {identity}")
            manifest_path, expected_hash = Path(reference["path"]), reference["sha256"]
        else:
            manifest_path = Path(str(row.get("r7DiagnosticRoot") or "")) / "MANIFEST.json"
            expected_hash = row.get("r7ManifestSha256")
        _, result, evidence = base.load_prior_evidence(row, manifest_path, expected_hash, fixed)
        prior[identity] = {"classification": "PINNED_EXECUTABLE", "priorResult": result, "priorEvidence": evidence}
    need(len(prior) == 978 and sum(v["classification"] == "FRESH_PRIOR_PROVIDER_ERROR" for v in prior.values()) == 5, "Prior evidence coverage changed")
    plans = generalized_alias_plans(cohorts["ordered978"], o3f14)
    return {"base": base, "o3f14": o3f14, "rows": rows, "cases": cases, "cohorts": cohorts, "comparison": comparison, "canonicalFixed": fixed, "prior": prior, "plans": plans}


def validate_exact_root(path: Path, expected: Path, label: str) -> Path:
    need(path.is_absolute() and os.path.normcase(os.path.normpath(str(path))) == os.path.normcase(os.path.normpath(str(expected))), f"{label} must be exactly {expected}")
    resolved = path.resolve(strict=False)
    need(resolved.parent.is_dir() and not resolved.exists(), f"{label} parent must exist and root must be create-new")
    return resolved


def output_path_gate(output_root: Path, mirror_root: Path, rows: list[dict[str, Any]]) -> dict[str, Any]:
    leaves = [output_root / name for name in ("PROGRESS.json.partial", "RESULTS.json.partial", "SUMMARY.json.partial", "TERMINAL_FAILURE.json.partial", "HOLDOUT18.json.partial", "CURRENT265.json.partial")]
    leaves += [mirror_root / name for name in ("PROGRESS.json.partial", "RESULTS.json.partial", "SUMMARY.json.partial", "TERMINAL_FAILURE.json.partial")]
    need(len(rows) == 978, "Output path gate requires exact FULL978")
    for ordinal, row in enumerate(rows, 1):
        case = output_root / "cases" / f"C{ordinal:04d}"
        leaves += [output_root / "jobs" / f"J{ordinal:04d}.json.partial", output_root / f"C{ordinal:04d}.stdout.txt", output_root / f"C{ordinal:04d}.stderr.txt", case / "MANIFEST.json.partial"]
        stem = str(row["safeId"]).lower().replace("-", "")
        for channel in ("bf", "df"):
            leaves += [case / f"{stem}_{channel}_overview.png", case / f"{stem}_{channel}_c24_clean.png", case / f"{stem}_{channel}_c24_enhanced.png", case / f"{stem}_{channel}_c24_overlay.png", case / f"{stem}_{channel}_c24_mask.png"]
        leaves += [case / "0123456789abcdef_bf_o3p8_recovery_enhanced.png", case / "0123456789abcdef_df_r10_recovery_enhanced.png"]
    longest = max(leaves, key=lambda p: len(str(p)))
    component = max((part for p in leaves for part in p.parts), key=len)
    need(len(str(longest)) + 32 < 200 and len(component) <= 80, f"O3F15 output path plan is unsafe: {longest}")
    return {"plannedLeafCount": len(leaves), "maximumPathLength": len(str(longest)), "suffixReserve": 32, "maximumEffectivePathLength": len(str(longest)) + 32, "maximumComponentLength": len(component), "longestLeaf": str(longest)}


def validate_gate(path: Path, expected_sha256: str) -> dict[str, Any]:
    gate, actual = read_json_and_sha256(path)
    need(actual == required_sha256(expected_sha256, "O3F15 GATE prerequisite"), "O3F15 GATE summary hash changed")
    need(gate.get("schema") == "argos_ocv03_o3f15_gate_result_v1" and gate.get("state") == "COMPLETE_O3F15_GATE", "O3F15 GATE did not pass")
    need(gate.get("runnerSha256") == sha256(Path(__file__).resolve()) and gate.get("r11Sha256") == R11_SHA256, "O3F15 GATE provenance changed")
    need(gate.get("sourceResultsSha256") == SOURCE_RESULTS_SHA256 and gate.get("reviewOrderSha256") == REVIEW_ORDER_SHA256 and gate.get("o3f14SummarySha256") == O3F14_SUMMARY_SHA256, "O3F15 GATE inputs changed")
    return {"path": str(path.resolve(strict=True)), "sha256": actual}


def execute(label: str, command: list[str], timeout: int, root: Path, env: dict[str, str]) -> dict[str, Any]:
    try:
        child = subprocess.run(command, capture_output=True, text=True, timeout=timeout, env=env)
        code, stdout, stderr = child.returncode, child.stdout, child.stderr
    except Exception as exc:
        code, stdout, stderr = -1, "", str(exc)
    (root / f"{label}.stdout.txt").write_text(stdout, encoding="utf-8", newline="\n")
    (root / f"{label}.stderr.txt").write_text(stderr, encoding="utf-8", newline="\n")
    return {"label": label, "returnCode": code, "stderrBytes": len(stderr.encode("utf-8"))}


def run_gate(output_root: Path) -> dict[str, Any]:
    context = preflight_context()
    output_root = validate_exact_root(output_root, GATE_ROOT, "GATE output root")
    output_root.mkdir()
    env = context["o3f14"].isolated_env()
    env.update({"TEMP": str(output_root), "TMP": str(output_root)})
    focused = output_root / "FOCUSED.json"
    seed = output_root / "R11_SEED.json"
    synthetic = output_root / "R11_SYNTHETIC"
    commands = [
        execute("FOCUSED", [str(RUNTIME), "-I", "-B", str(FOCUSED_TEST), "--output", str(focused)], 120, output_root, env),
        execute("R11_SEED", [str(RUNTIME), "-I", "-B", str(context["o3f14"].LOCAL_GATE), "--output", str(seed)], 240, output_root, env),
        execute("R11_SYNTHETIC", [str(RUNTIME), "-I", "-B", str(R11), "--synthetic-gate", "--output-root", str(synthetic)], 360, output_root, env),
    ]
    f = read_json_and_sha256(focused)[0] if focused.is_file() else {}
    s = read_json_and_sha256(seed)[0] if seed.is_file() else {}
    inherited_path = synthetic / "SYNTHETIC_GATE.json"
    i = read_json_and_sha256(inherited_path)[0] if inherited_path.is_file() else {}
    passed = all(c["returnCode"] == 0 and c["stderrBytes"] == 0 for c in commands) and f.get("state") == "PASS_O3F15_FRONT_RECONCILE_FOCUSED_GATE" and s.get("state") == "PASS_O3F14_R11_SEED_ANGLE_REGRESSION" and i.get("state") == "PASS_O3M6_SPLIT_METHOD_FULL_PERIMETER_SYNTHETIC_GATE"
    summary = {"schema": "argos_ocv03_o3f15_gate_result_v1", "state": "COMPLETE_O3F15_GATE" if passed else "HOLD_O3F15_GATE", "stage": "GATE", "runnerSha256": sha256(Path(__file__).resolve()), "focusedTestSha256": FOCUSED_TEST_SHA256, "r11Sha256": R11_SHA256, "sourceResultsSha256": SOURCE_RESULTS_SHA256, "reviewOrderSha256": REVIEW_ORDER_SHA256, "o3f14SummarySha256": O3F14_SUMMARY_SHA256, "cohortCounts": {"HOLDOUT18": 18, "CURRENT_TAIL": 247, "FULL_TAIL": 713, "FULL978": 978}, "commands": commands, "sourceImageBytesRead": False, "sourceMutation": False, "providerActivated": False}
    atomic_json(output_root / "SUMMARY.json", summary)
    return {"state": summary["state"], "stage": "GATE", "summarySha256": sha256(output_root / "SUMMARY.json"), "commands": commands}


def source_fields(row: dict[str, Any]) -> dict[str, Any]:
    return {"bfSha256": str(row["bf"]["sha256"]).upper(), "bfBytes": int(row["bf"]["bytes"]), "dfSha256": str(row["df"]["sha256"]).upper(), "dfBytes": int(row["df"]["bytes"])}


def compact_result(ordinal: int, row: dict[str, Any], execution: str, baseline: str | None, final: str, r11_invoked: bool | None, manifest_sha: str | None, error: str | None, *, child_launch_attempted: bool = False, child_exit_code: int | None = None, manifest_path: str | None = None) -> dict[str, Any]:
    return {"ordinal": ordinal, "identity": str(row["identity"]), "safeId": str(row["safeId"]), "priorR8State": str(row["r8State"]), "baselineR8State": baseline, "finalState": final, "execution": execution, "childLaunchAttempted": child_launch_attempted, "childExitCode": child_exit_code, "r11Invoked": r11_invoked, "manifestPath": manifest_path, "manifestSha256": manifest_sha, "error": error, **source_fields(row)}


def run_one(ordinal: int, row: dict[str, Any], plan: dict[str, Any], context: dict[str, Any], output_root: Path, jobs: Path, cases_root: Path, env: dict[str, str]) -> dict[str, Any]:
    identity, safe_id = str(row["identity"]), str(row["safeId"])
    job = dict(context["canonicalFixed"])
    job["revision"] = f"O3F15_R11_FULL978_{ordinal:04d}"
    job["inputs"] = [{"identity": f"{safe_id}-{channel}", "pairId": safe_id, "channel": channel, "path": str(plan[key]["aliasPath"]), "canonicalPath": str(plan[key]["canonicalPath"]), "bytes": int(plan[key]["bytes"]), "sha256": str(plan[key]["sha256"])} for channel, key in (("BF", "bf"), ("DF", "df"))]
    job_path, case_root = jobs / f"J{ordinal:04d}.json", cases_root / f"C{ordinal:04d}"
    manifest_path = case_root / "MANIFEST.json"
    stdout_path, stderr_path = output_root / f"C{ordinal:04d}.stdout.txt", output_root / f"C{ordinal:04d}.stderr.txt"
    alias_evidence: dict[str, Any] = {"ordinal": ordinal, "identity": identity, "aliasDrive": context["o3f14"].ALIAS_DRIVE, "slotRoot": str(plan["slotRoot"])}
    child: subprocess.CompletedProcess[str] | None = None
    child_launch_attempted = False
    manifest_sha: str | None = None
    observed: dict[str, Any] | None = None
    projection: dict[str, Any] | None = None
    try:
        with context["o3f14"].owned_case_alias(plan, alias_evidence):
            atomic_json(job_path, job)
            child_launch_attempted = True
            child = subprocess.run([str(RUNTIME), "-I", "-B", str(R11), "--run", "--job", str(job_path), "--output-root", str(case_root)], capture_output=True, text=True, timeout=600, env=env)
        stdout_path.write_text(child.stdout, encoding="utf-8", newline="\n")
        stderr_path.write_text(child.stderr, encoding="utf-8", newline="\n")
        need(child.returncode == 0 and not child.stderr, f"R11 child failed for {identity}: exit={child.returncode} {child.stderr[-800:]}")
        manifest, manifest_sha = read_json_and_sha256(manifest_path)
        need(isinstance(manifest.get("results"), list) and len(manifest["results"]) == 1, f"R11 manifest cardinality changed: {identity}")
        observed = manifest["results"][0]
        need(str(observed["pairId"]) == safe_id, f"R11 pair binding changed: {identity}")
        prior = context["prior"][identity]
        if prior["classification"] == "PINNED_EXECUTABLE":
            need(str(observed["baselineR8State"]) == str(row["r8State"]), f"R11 baseline state changed: {identity}")
            need(context["base"].r8_decision_projection(observed) == context["base"].r8_decision_projection(prior["priorResult"]), f"R11 changed inherited R8 evidence: {identity}")
        o3f14 = context["o3f14"]
        expected_provenance = {"r10Sha256": R11_SHA256, "r9PredecessorSha256": o3f14.R9_SHA256, "r8PredecessorSha256": o3f14.R8_SHA256, "r6Sha256": o3f14.R6_SHA256, "topologySha256": o3f14.TOPOLOGY_SHA256, "o3p8Sha256": o3f14.O3P8_SHA256, "runtimeSha256": o3f14.RUNTIME_SHA256, "opencvVersion": o3f14.EXPECTED_OPENCV_VERSION, "numpyVersion": o3f14.EXPECTED_NUMPY_VERSION}
        need(str(manifest["revision"]) == job["revision"] and int(manifest["inputCount"]) == 2, f"R11 manifest binding changed: {identity}")
        need(manifest.get("engineProvenance") == expected_provenance, f"R11 engine provenance changed: {identity}")
        need(sha256(job_path) == str(manifest["jobSha256"]).upper(), f"R11 job hash changed: {identity}")
        need(Path(str(manifest["jobPath"])).resolve(strict=False) == job_path.resolve(strict=False), f"R11 job path changed: {identity}")
        need(manifest.get("sourceMutationPerformed") is False and manifest.get("providerActivated") is False, f"R11 exceeded review-only authority: {identity}")
        projection = o3f14.result_projection(observed)
        if identity in context["comparison"]:
            expected = context["comparison"][identity]
            for key in ("priorState", "baselineState", "inheritedR9State", "finalState", "r11Invoked", "physicalClusterCount", "selectedClusterDirections", "dfSeedCount", "dfSeedEligibleCount", "bfSeedCount", "bfHypothesisCount", "bfHypothesisEligibleCount", "eligibleHypotheses"):
                need(projection.get(key) == expected.get(key), f"Fresh/O3F14 regression mismatch {key}: {identity}")
        need(alias_evidence.get("ownedMappingRemoved") is True and alias_evidence.get("verifiedAbsentAfterRemove") is True and alias_evidence.get("unrelatedMappingsPreservedAfterRemove") is True, f"Q: lifecycle incomplete: {identity}")
        return compact_result(ordinal, row, "PASS_R11_FRESH", str(observed["baselineR8State"]), str(observed["state"]), bool(projection["r11Invoked"]), manifest_sha, None, child_launch_attempted=True, child_exit_code=child.returncode, manifest_path=str(manifest_path))
    except Exception as exc:
        recovery_errors: list[str] = []
        if child is not None:
            for path, text in ((stdout_path, child.stdout), (stderr_path, child.stderr)):
                if not path.exists():
                    try:
                        path.write_text(text, encoding="utf-8", newline="\n")
                    except Exception as log_exc:
                        recovery_errors.append(f"{path.name}: {type(log_exc).__name__}: {str(log_exc)[:300]}")
        if manifest_path.is_file() and manifest_sha is None:
            try:
                manifest, manifest_sha = read_json_and_sha256(manifest_path)
                rows = manifest.get("results")
                if isinstance(rows, list) and len(rows) == 1 and isinstance(rows[0], dict):
                    observed = rows[0]
                    projection = context["o3f14"].result_projection(observed)
            except Exception:
                pass
        baseline_state = None if observed is None or observed.get("baselineR8State") is None else str(observed["baselineR8State"])
        final_state = None if observed is None or observed.get("state") is None else str(observed["state"])
        error = str(exc)
        if recovery_errors:
            error += " | recovery-log-errors=" + " ; ".join(recovery_errors)
        raise CaseExecutionError(error[:1600], child_launch_attempted=child_launch_attempted, child_exit_code=None if child is None else child.returncode, manifest_path=str(manifest_path) if manifest_path.is_file() else None, manifest_sha256=manifest_sha, baseline_state=baseline_state, final_state=final_state, r11_invoked=None if projection is None else bool(projection.get("r11Invoked"))) from exc


def progress_value(results: list[dict[str, Any]], stopped: bool, stage_gates: list[dict[str, Any]], terminal: bool = False) -> dict[str, Any]:
    state = "HOLD_O3F15_EXECUTION_STOPPED" if stopped else ("COMPLETE_O3F15_FULL978" if terminal and len(results) == 978 else "RUNNING_O3F15_FULL978")
    return {"schema": "argos_ocv03_o3f15_progress_v1", "state": state, "scheduledCount": 978, "executedCount": sum(r["execution"] == "PASS_R11_FRESH" for r in results), "recordedCount": len(results), "lastOrdinal": 0 if not results else results[-1]["ordinal"], "stageGates": stage_gates, "recent": results[-20:], "retryAuthorized": False, "sourceMutation": False, "providerActivated": False}


def stage_snapshot(name: str, results: list[dict[str, Any]]) -> dict[str, Any]:
    return {"schema": "argos_ocv03_o3f15_stage_snapshot_v1", "state": f"COMPLETE_O3F15_{name}", "stage": name, "executedCount": len(results), "stateCounts": dict(Counter(str(r["finalState"]) for r in results)), "rows": results}


def commit_terminal_failure(output_root: Path, mirror_root: Path, results: list[dict[str, Any]], stage_gates: list[dict[str, Any]], error: str) -> dict[str, Any]:
    value = {"schema": "argos_ocv03_o3f15_terminal_failure_v1", "state": "HOLD_O3F15_ARTIFACT_COMMIT_FAILURE", "scheduledCount": 978, "validatedExecutionCount": sum(r["execution"] == "PASS_R11_FRESH" for r in results), "childLaunchAttemptedCount": sum(bool(r.get("childLaunchAttempted")) for r in results), "recordedCount": len(results), "lastOrdinal": 0 if not results else int(results[-1]["ordinal"]), "stageGates": stage_gates, "error": error[:1600], "retryAuthorized": False, "sourceMutation": False, "providerActivated": False, "reviewOnly": True, "productionRoutingEnabled": False}
    committed: list[str] = []
    failures: list[str] = []
    for root, bounded in ((output_root, False), (mirror_root, True)):
        try:
            need(root.is_dir(), f"Terminal-failure root is absent: {root}")
            atomic_json(root / "TERMINAL_FAILURE.json", value, bounded=bounded)
            committed.append(str(root / "TERMINAL_FAILURE.json"))
        except Exception as exc:
            failures.append(f"{root}: {type(exc).__name__}: {str(exc)[:400]}")
    return {"state": value["state"], "stage": "FULL978", "executedCount": value["validatedExecutionCount"], "childLaunchAttemptedCount": value["childLaunchAttemptedCount"], "terminalFailureCommittedPaths": committed, "terminalFailureCommitErrors": failures, "mirrorRoot": str(mirror_root)}


def run_full(output_root: Path, mirror_root: Path, prerequisite_summary: Path, prerequisite_sha256: str) -> dict[str, Any]:
    context = preflight_context()
    prerequisite = validate_gate(prerequisite_summary, prerequisite_sha256)
    output_root = validate_exact_root(output_root, RUN_ROOT, "RUN output root")
    mirror_root = validate_exact_root(mirror_root, MIRROR_ROOT, "mirror root")
    path_plan = output_path_gate(output_root, mirror_root, context["cohorts"]["ordered978"])
    results: list[dict[str, Any]] = []
    stage_gates: list[dict[str, Any]] = []
    output_root.mkdir()
    try:
        mirror_root.mkdir()
        jobs, cases_root = output_root / "jobs", output_root / "cases"
        jobs.mkdir(); cases_root.mkdir()
        env = context["o3f14"].isolated_env(); env.update({"TEMP": str(output_root), "TMP": str(output_root)})
        mirror_json(output_root, mirror_root, "PROGRESS.json", progress_value(results, False, stage_gates))
        stop_error: str | None = None
        ordered = context["cohorts"]["ordered978"]
        for ordinal, (row, plan) in enumerate(zip(ordered, context["plans"]), 1):
            try:
                result = run_one(ordinal, row, plan, context, output_root, jobs, cases_root, env)
            except CaseExecutionError as exc:
                stop_error = f"{type(exc).__name__}: {str(exc)[:1200]}"
                execution = "HOLD_POST_EXECUTION_VALIDATION" if exc.manifest_sha256 else ("HOLD_CHILD_EXECUTION_OR_VALIDATION" if exc.child_launch_attempted else "HOLD_PRE_EXECUTION_VALIDATION")
                result = compact_result(ordinal, row, execution, exc.baseline_state, exc.final_state or "HOLD_O3F15_PROVIDER_SOURCE_ALIAS_OR_RESULT_ERROR", exc.r11_invoked, exc.manifest_sha256, stop_error, child_launch_attempted=exc.child_launch_attempted, child_exit_code=exc.child_exit_code, manifest_path=exc.manifest_path)
            results.append(result)
            if stop_error is None and ordinal in (18, 265):
                name = "HOLDOUT18" if ordinal == 18 else "CURRENT265"
                snapshot = stage_snapshot(name, list(results))
                atomic_json(output_root / f"{name}.json", snapshot)
                stage_gates.append({"stage": name, "state": snapshot["state"], "executedCount": ordinal, "sha256": sha256(output_root / f"{name}.json")})
            mirror_json(output_root, mirror_root, "PROGRESS.json", progress_value(results, stop_error is not None, stage_gates), replace=True)
            if stop_error is not None:
                break
        if stop_error is not None:
            for ordinal in range(len(results) + 1, 979):
                row = ordered[ordinal - 1]
                results.append(compact_result(ordinal, row, "NOT_EXECUTED_AFTER_TECHNICAL_STOP", None, "HOLD_O3F15_NOT_EXECUTED_AFTER_TECHNICAL_STOP", False, None, None))
        executed = sum(r["execution"] == "PASS_R11_FRESH" for r in results)
        child_launches = sum(bool(r.get("childLaunchAttempted")) for r in results)
        clean = stop_error is None and executed == 978 and child_launches == 978 and len(results) == 978 and [g["executedCount"] for g in stage_gates] == [18, 265]
        results_value = {"schema": "argos_ocv03_o3f15_front_reconciliation_results_v1", "state": "COMPLETE_O3F15_FULL978" if clean else "HOLD_O3F15_EXECUTION_STOPPED", "rowCount": len(results), "executedCount": executed, "childLaunchAttemptedCount": child_launches, "rows": results}
        results_data = mirror_json(output_root, mirror_root, "RESULTS.json", results_value)
        results_sha = hashlib.sha256(results_data).hexdigest().upper()
        transitions = Counter(f"{r['priorR8State']}->{r['finalState']}" for r in results)
        summary = {"schema": "argos_ocv03_o3f15_front_reconciliation_summary_v1", "state": results_value["state"], "stage": "FULL978", "runnerSha256": sha256(Path(__file__).resolve()), "r11Sha256": R11_SHA256, "sourceResultsSha256": SOURCE_RESULTS_SHA256, "reviewOrderSha256": REVIEW_ORDER_SHA256, "o3f14SummarySha256": O3F14_SUMMARY_SHA256, "prerequisite": prerequisite, "pathPlan": path_plan, "scheduledCount": 978, "executedCount": executed, "childLaunchAttemptedCount": child_launches, "providerErrorPriorRowsExecutedCount": sum(r["execution"] == "PASS_R11_FRESH" and r["priorR8State"] == PROVIDER_ERROR_STATE for r in results), "stateCounts": dict(Counter(str(r["finalState"]) for r in results)), "transitionCounts": dict(transitions), "stageGates": stage_gates + ([{"stage": "FULL978", "state": "COMPLETE_O3F15_FULL978", "executedCount": 978}] if clean else []), "resultsSha256": results_sha, "resultsBytes": len(results_data), "mirrorLeavesUnder2MiB": len(results_data) < MAX_MIRROR_BYTES, "stopError": stop_error, "ordinaryDetectorHoldsPreserved": True, "allPairsFreshlyExecutedOnce": clean, "retryAuthorized": False, "numericThresholdRelaxationPerformed": False, "postResultSelectorRelaxationPerformed": False, "sourceMutation": False, "providerActivated": False, "reviewOnly": True, "productionRoutingEnabled": False}
        summary_data = mirror_json(output_root, mirror_root, "SUMMARY.json", summary)
        mirror_json(output_root, mirror_root, "PROGRESS.json", progress_value(results if clean else results[:executed + 1], not clean, summary["stageGates"], terminal=clean), replace=True)
        return {"state": summary["state"], "stage": "FULL978", "executedCount": executed, "childLaunchAttemptedCount": child_launches, "resultsSha256": results_sha, "summarySha256": hashlib.sha256(summary_data).hexdigest().upper(), "mirrorRoot": str(mirror_root)}
    except Exception as exc:
        return commit_terminal_failure(output_root, mirror_root, results, stage_gates, f"{type(exc).__name__}: {str(exc)[:1500]}")


def synthetic_frozen_inputs() -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    rows: list[dict[str, Any]] = []
    dev_states = ["HOLD_DF_RADIAL_FULL_PERIMETER_NOT_QUALIFIED"] * 3 + ["HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH"] * 3
    for i, (identity, state) in enumerate(zip(O3F14_EXPECTED_FINAL, dev_states)):
        rows.append({"identity": identity, "safeId": f"D{i:03d}", "r8State": state})
    for i in range(253): rows.append({"identity": f"PatternedFront\\LotP\\ScanP\\Pass{i:03d}|FRONT", "safeId": f"CP{i:03d}", "r8State": PASS_STATE})
    for i in range(2): rows.append({"identity": f"PatternedFront\\LotH\\ScanH\\No{i}|FRONT", "safeId": f"CHN{i}", "r8State": "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH"})
    for i in range(4): rows.append({"identity": f"PatternedFront\\LotH\\ScanH\\Err{i}|FRONT", "safeId": f"CHE{i}", "r8State": PROVIDER_ERROR_STATE})
    for i in range(541): rows.append({"identity": f"LegacyFront\\LotP\\ScanP\\Pass{i:03d}|FRONT", "safeId": f"FP{i:03d}", "r8State": PASS_STATE})
    for i in range(124): rows.append({"identity": f"LegacyFront\\LotH\\ScanH\\No{i:03d}|FRONT", "safeId": f"FHN{i:03d}", "r8State": "HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH"})
    for i in range(47): rows.append({"identity": f"LegacyFront\\LotH\\ScanH\\Df{i:03d}|FRONT", "safeId": f"FHD{i:03d}", "r8State": "HOLD_DF_RADIAL_FULL_PERIMETER_NOT_QUALIFIED"})
    rows.append({"identity": "LegacyFront\\LotH\\ScanH\\Err000|FRONT", "safeId": "FHE000", "r8State": PROVIDER_ERROR_STATE})
    current_holds = rows[259:265]
    controls = rows[6:18]
    cases = [{"identity": r["identity"], "safeId": r["safeId"], "state": r["r8State"]} for r in rows[:6] + current_holds + controls]
    return rows, cases


def self_test() -> None:
    rows, cases = synthetic_frozen_inputs()
    cohorts = partition(rows, cases)
    need([len(cohorts[k]) for k in ("holdout18", "currentTail247", "fullTail713", "ordered978")] == [18, 247, 713, 978], "Synthetic cohort partition failed")
    print(json.dumps({"schema": "argos_ocv03_o3f15_self_test_v1", "state": "PASS_O3F15_FRONT_RECONCILE_SELF_TEST", "mutationsPerformed": False}, separators=(",", ":")))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("SELF_TEST", "PREFLIGHT", "GATE", "RUN"))
    parser.add_argument("--output-root")
    parser.add_argument("--mirror-root")
    parser.add_argument("--prerequisite-summary")
    parser.add_argument("--prerequisite-sha256")
    args = parser.parse_args()
    if args.stage == "SELF_TEST":
        need(not any((args.output_root, args.mirror_root, args.prerequisite_summary, args.prerequisite_sha256)), "SELF_TEST accepts no paths")
        self_test(); return 0
    if args.stage == "PREFLIGHT":
        need(not any((args.output_root, args.mirror_root, args.prerequisite_summary, args.prerequisite_sha256)), "PREFLIGHT accepts no paths")
        context = preflight_context()
        print(json.dumps({"schema": "argos_ocv03_o3f15_preflight_v1", "state": "PASS_O3F15_FRONT_RECONCILE_PREFLIGHT", "cohortCounts": {"HOLDOUT18": len(context["cohorts"]["holdout18"]), "CURRENT_TAIL": len(context["cohorts"]["currentTail247"]), "FULL_TAIL": len(context["cohorts"]["fullTail713"]), "FULL978": len(context["cohorts"]["ordered978"])}, "mutationsPerformed": False}, separators=(",", ":"))); return 0
    need(args.output_root, "--output-root is required")
    if args.stage == "GATE":
        need(not any((args.mirror_root, args.prerequisite_summary, args.prerequisite_sha256)), "GATE accepts only --output-root")
        result = run_gate(Path(args.output_root))
    else:
        need(args.mirror_root and args.prerequisite_summary and args.prerequisite_sha256, "RUN requires --mirror-root, --prerequisite-summary, and --prerequisite-sha256")
        result = run_full(Path(args.output_root), Path(args.mirror_root), Path(args.prerequisite_summary), args.prerequisite_sha256)
    print(json.dumps(result, separators=(",", ":")))
    return 0 if str(result["state"]).startswith("COMPLETE_") else 2


if __name__ == "__main__":
    raise SystemExit(main())
