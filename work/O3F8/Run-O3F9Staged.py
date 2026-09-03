#!/usr/bin/env python3
"""Run the frozen O3F8/R10 draft through the O3F9 GATE and DEV6 stages."""

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
R10 = HERE / "FullPerimeterWaferTopologyOpenCvR10.py"
R9 = HERE / "FullPerimeterWaferTopologyOpenCvR9.py"
R8 = HERE / "FullPerimeterWaferTopologyOpenCvR8.py"
O3P8 = HERE / "Detect-O3P8FrontSplitNotches.py"
LOCAL_GATE = HERE / "Test-O3F8SymmetricRecovery.py"
O3P8_JOB = HERE / "O3P8_POST2_SHORT_ALIAS_JOB.json"
CANONICAL_JOB = HERE / "O3M9_SLOT16_JOB.json"
INSTALLED = Path(r"C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1")
RUNTIME = Path(r"D:\AFCV1\rt\python.exe")

BASE_RUNNER_SHA256 = "44B378616CCCFEB0C67DF09196D0B7CDD515DBE35CEA84F4DBEB69DE326AD8C7"
R10_SHA256 = "0EEEE7A396E918AF44082EC0930871A6A94C1FBB59D3F5CEF1AC34D1273745FA"
R9_SHA256 = "DB44AD35205AC088FE7E24C1CC8FA9291311922A7D31E0F1C055BA92EAFD2FC1"
R8_SHA256 = "068ECC0D4F547FCFD7A0A2AEDF673B71BB0C46207DE8EC0F47312A9030B0734B"
O3P8_SHA256 = "41F60AF393E0B2C752AF6B33BB6673145490AE2BB346A4DA8E59A2D42E383E36"
LOCAL_GATE_SHA256 = "7125CF87F9B094B23D77A4A8F9347FC0F95C9719FDCEA98CF33185A7B67E0092"
O3P8_JOB_SHA256 = "2C2D656A879BBA1DEC6377D1855A949459C7AC6F50145761B8D283076FEAD1F9"
CANONICAL_JOB_SHA256 = "E384ABD12E9B77DB9B4492504A5D792E316C5396C3B0A3E1D2B1AB11BB4C7DD3"
R6_SHA256 = "90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30"
TOPOLOGY_SHA256 = "D8897C1A5B60CB5AA9B0343CF8C9E5A249CCC5DEF5FBCDFE645EC08C354EF3BD"
RESULTS_SHA256 = "A933227FE4F41259D53D586CBB5189E1B6542B96B7585B606207DAFD35326BD8"
REVIEW_SHA256 = "D57DFE4301FEE2144D18EF4DB2BFD0A323EB095C117BBF10A856A691A8E73BBA"
RUNTIME_SHA256 = "7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1"
EXPECTED_OPENCV_VERSION = "5.0.0"
EXPECTED_NUMPY_VERSION = "2.5.2"
PATH_SUFFIX_RESERVE = 32
_BASE: Any | None = None


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
    need(len(text) == 64 and all(character in "0123456789ABCDEF" for character in text), f"{label} is not an exact SHA-256")
    return text


def read_json_and_sha256(path: Path) -> tuple[dict[str, Any], str]:
    data = path.read_bytes()
    value = json.loads(data.decode("utf-8"))
    need(isinstance(value, dict), f"JSON root is not an object: {path}")
    return value, hashlib.sha256(data).hexdigest().upper()


def write_new(path: Path, value: Any) -> None:
    partial = path.with_name(path.name + ".partial")
    need(not path.exists() and not partial.exists(), f"Output collision: {path}")
    partial.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")
    os.replace(partial, path)


def load_base() -> Any:
    global _BASE
    need(BASE_RUNNER.is_file() and sha256(BASE_RUNNER) == BASE_RUNNER_SHA256, "Frozen R9 staged-runner dependency changed")
    if _BASE is None:
        spec = importlib.util.spec_from_file_location("argos_o3f9_frozen_runner_base", BASE_RUNNER)
        need(spec is not None and spec.loader is not None, "Cannot load frozen staged-runner dependency")
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        _BASE = module
    return _BASE


def isolated_env() -> dict[str, str]:
    blocked = {"PYTHONHOME", "PYTHONPATH", "PYTHONUSERBASE", "PYTHONSTARTUP", "PYTHONINSPECT"}
    env = {key: value for key, value in os.environ.items() if key.upper() not in blocked}
    env.update(
        {
            "PYTHONNOUSERSITE": "1",
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONUTF8": "1",
            "ARGOS_O3F8_RUNTIME_ROOT": str(RUNTIME.parent),
            "ARGOS_O3M1_R6_ROOT": str(INSTALLED),
            "ARGOS_O3M1_TOPOLOGY_ROOT": str(INSTALLED),
            "ARGOS_O3P8_ROOT": str(HERE),
            "ARGOS_O3F8_DEPENDENCY_ROOT": str(INSTALLED),
        }
    )
    return env


def assert_package_pins() -> None:
    for path, expected, label in (
        (BASE_RUNNER, BASE_RUNNER_SHA256, "frozen staged-runner base"),
        (R10, R10_SHA256, "R10"),
        (R9, R9_SHA256, "R9 predecessor"),
        (R8, R8_SHA256, "R8 predecessor"),
        (O3P8, O3P8_SHA256, "O3P8"),
        (LOCAL_GATE, LOCAL_GATE_SHA256, "R10 local gate"),
        (O3P8_JOB, O3P8_JOB_SHA256, "O3P8 frozen job"),
        (CANONICAL_JOB, CANONICAL_JOB_SHA256, "canonical job"),
    ):
        need(path.is_file() and sha256(path) == expected, f"{label} pin changed: {path}")


def self_test() -> None:
    base = load_base()
    rows = [{"identity": "PatternedFront\\p"}, {"identity": "UnpatternedFront\\u"}, {"identity": "BackSide_BowComp\\b"}]
    current = [row for row in rows if row["identity"].startswith(("PatternedFront\\", "UnpatternedFront\\"))]
    need([row["identity"] for row in current] == ["PatternedFront\\p", "UnpatternedFront\\u"], "Current-recipe selector changed")
    need(base.R9_SHA256 == R9_SHA256 and base.R8_SHA256 == R8_SHA256, "Frozen runner predecessor pins changed")
    print('{"state":"PASS_O3F9_STAGED_RUNNER_SELF_TEST","mutationsPerformed":false}')


def preflight() -> None:
    assert_package_pins()
    base = load_base()
    for path, expected, label in (
        (INSTALLED / "NativeFrontsideWaferPoseOpenCvV2R6.py", R6_SHA256, "R6"),
        (INSTALLED / "WaferTopologyAxisOpenCv.py", TOPOLOGY_SHA256, "topology"),
        (RUNTIME, RUNTIME_SHA256, "runtime"),
    ):
        need(path.is_file() and sha256(path) == expected, f"{label} pin changed: {path}")
    runtime_check = subprocess.run(
        [
            str(RUNTIME),
            "-I",
            "-B",
            "-c",
            "import json,sys,cv2,numpy as np;print(json.dumps({'executable':sys.executable,'cv2Path':cv2.__file__,'numpyPath':np.__file__,'opencvVersion':cv2.__version__,'numpyVersion':np.__version__},separators=(',',':')))",
        ],
        capture_output=True,
        text=True,
        timeout=60,
        env=isolated_env(),
    )
    need(runtime_check.returncode == 0 and not runtime_check.stderr, "Pinned runtime import check failed")
    runtime = json.loads(runtime_check.stdout)
    runtime_root = RUNTIME.parent.resolve(strict=True)
    need(Path(runtime["executable"]).resolve(strict=True) == RUNTIME.resolve(strict=True), "Runtime executable path changed")
    for key in ("cv2Path", "numpyPath"):
        try:
            Path(runtime[key]).resolve(strict=True).relative_to(runtime_root)
        except ValueError as exc:
            raise RuntimeError(f"Runtime module escaped pinned root: {runtime[key]}") from exc
    need(runtime["opencvVersion"] == EXPECTED_OPENCV_VERSION, "OpenCV version changed")
    need(runtime["numpyVersion"] == EXPECTED_NUMPY_VERSION, "NumPy version changed")
    rows, cases = base.frozen_inputs()
    need(len(rows) == 978 and len(cases) == 24, "Frozen source/review cardinality changed")


def validate_output_root(output_root: Path) -> Path:
    need(output_root.is_absolute(), "Output root must be absolute")
    resolved = output_root.resolve(strict=False)
    need(resolved.drive.upper() == "D:", "Output root must be on JBOD D:")
    need(
        resolved.parent == Path(resolved.anchor) and resolved.name.upper().startswith("O3F9"),
        "Output root must be a short create-new D:\\O3F9* development root",
    )
    need(resolved.parent.is_dir() and not resolved.exists(), "Output root parent must exist and root must be create-new")
    need(len(resolved.name) <= 80, "Output root component is too long")
    return resolved


def validate_new_paths(paths: list[Path]) -> dict[str, Any]:
    need(paths, "No planned output paths")
    longest = max(paths, key=lambda path: len(str(path)))
    components = [part for path in paths for part in path.parts]
    longest_component = max(components, key=len)
    effective = len(str(longest)) + PATH_SUFFIX_RESERVE
    need(effective < 200, f"Planned output path plus suffix reserve is unsafe: {longest}")
    need(len(longest_component) <= 80, f"Planned output component is unsafe: {longest_component}")
    return {
        "plannedLeafCount": len(paths),
        "maximumPathLength": len(str(longest)),
        "suffixReserve": PATH_SUFFIX_RESERVE,
        "maximumEffectivePathLength": effective,
        "maximumComponentLength": len(longest_component),
        "longestLeaf": str(longest),
    }


def validate_stage_path_plan(output_root: Path, selected: list[dict[str, Any]]) -> dict[str, Any]:
    leaves = [output_root / "SUMMARY.json.partial"]
    suffixes = ("clean.png", "enhanced.png", "overlay.png", "mask.png")
    for ordinal, row in enumerate(selected, 1):
        safe_id = str(row["safeId"])
        need(not any(character in safe_id for character in '\\/:*?"<>|'), f"Unsafe safeId: {safe_id}")
        stem = safe_id.lower().replace("-", "")
        digest = hashlib.sha256(safe_id.encode("utf-8")).hexdigest()[:16]
        case_root = output_root / "cases" / f"C{ordinal:04d}"
        leaves.extend(
            [
                output_root / "jobs" / f"J{ordinal:04d}.json.partial",
                output_root / f"C{ordinal:04d}.stdout.txt",
                output_root / f"C{ordinal:04d}.stderr.txt",
                case_root / "MANIFEST.json.partial",
                case_root / f"{stem}_bf_overview.png",
                case_root / f"{stem}_df_overview.png",
            ]
        )
        for suffix in suffixes:
            leaves.extend(
                [
                    case_root / f"{stem}_bf_c24_{suffix}",
                    case_root / f"{stem}_df_c24_{suffix}",
                    case_root / f"{digest}_bf_o3p8_recovery_{suffix}",
                    case_root / f"{digest}_df_r10_recovery_{suffix}",
                ]
            )
        for channel in ("bf", "df"):
            source = Path(str(row[channel]["path"])).resolve(strict=False)
            need(len(str(source)) + PATH_SUFFIX_RESERVE < 200, f"Source path plus suffix reserve is unsafe: {source}")
    return validate_new_paths(leaves)


def execute(label: str, command: list[str], timeout: int, output_root: Path, env: dict[str, str]) -> dict[str, Any]:
    try:
        child = subprocess.run(command, capture_output=True, text=True, timeout=timeout, env=env)
        return_code, stdout, stderr = child.returncode, child.stdout, child.stderr
    except Exception as exc:
        return_code, stdout, stderr = -1, "", str(exc)
    (output_root / f"{label}.stdout.txt").write_text(stdout, encoding="utf-8", newline="\n")
    (output_root / f"{label}.stderr.txt").write_text(stderr, encoding="utf-8", newline="\n")
    return {"label": label, "returnCode": return_code, "stderrBytes": len(stderr.encode("utf-8"))}


def run_gate(output_root: Path) -> dict[str, Any]:
    preflight()
    output_root = validate_output_root(output_root)
    local_output = output_root / "R10_SYMMETRIC_GATE.json"
    synthetic_root = output_root / "R10_INHERITED_SYNTHETIC"
    path_plan = validate_new_paths(
        [
            output_root / "SUMMARY.json.partial",
            local_output,
            output_root / "LOCAL.stdout.txt",
            output_root / "LOCAL.stderr.txt",
            output_root / "INHERITED.stdout.txt",
            output_root / "INHERITED.stderr.txt",
            synthetic_root / "upper_right_315_df_c01_enhanced.png",
            synthetic_root / "SYNTHETIC_GATE.json.partial",
        ]
    )
    output_root.mkdir()
    env = isolated_env()
    env["TEMP"] = str(output_root)
    env["TMP"] = str(output_root)
    commands = [
        execute(
            "LOCAL",
            [str(RUNTIME), "-I", "-B", str(LOCAL_GATE), "--output", str(local_output)],
            240,
            output_root,
            env,
        ),
        execute(
            "INHERITED",
            [str(RUNTIME), "-I", "-B", str(R10), "--synthetic-gate", "--output-root", str(synthetic_root)],
            360,
            output_root,
            env,
        ),
    ]
    local, local_sha = read_json_and_sha256(local_output) if local_output.is_file() else ({}, None)
    inherited_path = synthetic_root / "SYNTHETIC_GATE.json"
    inherited, inherited_sha = read_json_and_sha256(inherited_path) if inherited_path.is_file() else ({}, None)
    passed = (
        commands == [
            {"label": "LOCAL", "returnCode": 0, "stderrBytes": 0},
            {"label": "INHERITED", "returnCode": 0, "stderrBytes": 0},
        ]
        and local.get("state") == "PASS_O3F8_R10_SYMMETRIC_RECOVERY_LOCAL_GATE"
        and local.get("r9Sha256") == R9_SHA256
        and local.get("r10Sha256") == R10_SHA256
        and local.get("testSha256") == LOCAL_GATE_SHA256
        and local.get("numericThresholdRelaxationPerformed") is False
        and local.get("expectedAnglePriorConsumed") is False
        and local.get("bfDfFitAveragingPerformed") is False
        and inherited.get("state") == "PASS_O3M6_SPLIT_METHOD_FULL_PERIMETER_SYNTHETIC_GATE"
    )
    summary = {
        "schema": "argos_ocv03_o3f9_r10_gate_result_v1",
        "state": "COMPLETE_O3F9_GATE" if passed else "HOLD_O3F9_GATE",
        "stage": "GATE",
        "runnerSha256": sha256(Path(__file__).resolve()),
        "baseRunnerSha256": BASE_RUNNER_SHA256,
        "r10Sha256": R10_SHA256,
        "r9PredecessorSha256": R9_SHA256,
        "r8PredecessorSha256": R8_SHA256,
        "o3p8Sha256": O3P8_SHA256,
        "o3p8JobSha256": O3P8_JOB_SHA256,
        "localGateSourceSha256": LOCAL_GATE_SHA256,
        "canonicalJobSha256": CANONICAL_JOB_SHA256,
        "r6Sha256": R6_SHA256,
        "topologySha256": TOPOLOGY_SHA256,
        "runtimeSha256": RUNTIME_SHA256,
        "sourceResultsSha256": RESULTS_SHA256,
        "reviewOrderSha256": REVIEW_SHA256,
        "pathPlan": path_plan,
        "newProviderHoldCount": 0 if passed else 1,
        "commands": commands,
        "localGateResultSha256": local_sha,
        "inheritedGateResultSha256": inherited_sha,
        "numericThresholdRelaxationPerformed": False,
        "postResultSelectorRelaxationPerformed": False,
        "sourceMutation": False,
        "providerActivated": False,
    }
    summary_path = output_root / "SUMMARY.json"
    write_new(summary_path, summary)
    return {
        "state": summary["state"],
        "stage": "GATE",
        "summarySha256": sha256(summary_path),
        "commands": commands,
    }


def validate_gate(path: Path | None, expected_sha256: str | None) -> dict[str, Any]:
    need(path is not None and path.is_file(), "DEV6 requires the exact GATE summary")
    expected = required_sha256(expected_sha256, "GATE prerequisite")
    gate, actual = read_json_and_sha256(path)
    need(actual == expected, "GATE prerequisite summary hash changed")
    need(
        gate.get("schema") == "argos_ocv03_o3f9_r10_gate_result_v1"
        and gate.get("state") == "COMPLETE_O3F9_GATE"
        and gate.get("stage") == "GATE"
        and gate.get("runnerSha256") == sha256(Path(__file__).resolve())
        and gate.get("baseRunnerSha256") == BASE_RUNNER_SHA256
        and gate.get("r10Sha256") == R10_SHA256
        and gate.get("r9PredecessorSha256") == R9_SHA256
        and gate.get("r8PredecessorSha256") == R8_SHA256
        and gate.get("o3p8Sha256") == O3P8_SHA256
        and gate.get("localGateSourceSha256") == LOCAL_GATE_SHA256
        and gate.get("runtimeSha256") == RUNTIME_SHA256
        and gate.get("sourceResultsSha256") == RESULTS_SHA256
        and gate.get("reviewOrderSha256") == REVIEW_SHA256
        and gate.get("newProviderHoldCount") == 0
        and gate.get("numericThresholdRelaxationPerformed") is False
        and gate.get("postResultSelectorRelaxationPerformed") is False,
        "GATE prerequisite is not an exact clean matching completion",
    )
    local_path = path.parent / "R10_SYMMETRIC_GATE.json"
    inherited_path = path.parent / "R10_INHERITED_SYNTHETIC" / "SYNTHETIC_GATE.json"
    local, local_sha = read_json_and_sha256(local_path) if local_path.is_file() else ({}, None)
    inherited, inherited_sha = read_json_and_sha256(inherited_path) if inherited_path.is_file() else ({}, None)
    need(
        local_sha == gate.get("localGateResultSha256")
        and inherited_sha == gate.get("inheritedGateResultSha256")
        and local.get("state") == "PASS_O3F8_R10_SYMMETRIC_RECOVERY_LOCAL_GATE"
        and local.get("r10Sha256") == R10_SHA256
        and inherited.get("state") == "PASS_O3M6_SPLIT_METHOD_FULL_PERIMETER_SYNTHETIC_GATE"
        and gate.get("commands")
        == [
            {"label": "LOCAL", "returnCode": 0, "stderrBytes": 0},
            {"label": "INHERITED", "returnCode": 0, "stderrBytes": 0},
        ],
        "GATE result artifacts changed",
    )
    return {"path": str(path.resolve(strict=True)), "sha256": actual, "stage": "GATE"}


def hypothesis_projection(row: dict[str, Any]) -> dict[str, Any]:
    direction = str(row["direction"])
    bf = row["bf"]["feature"] if direction == "DF_SEEDED_LOCAL_BF" else row["bfCandidate"]
    df = row["dfRadial"]
    correspondence = row["correspondence"]
    return {
        "hypothesisId": str(row["hypothesisId"]),
        "direction": direction,
        "bfAngleDegrees": bf.get("axisCenterAngleDegrees", bf.get("tipAngleDegrees")),
        "dfAngleDegrees": df.get("axisCenterAngleDegrees", df.get("centerAngleDegrees")),
        "correspondenceMethod": correspondence.get("correspondenceMethod"),
        "centerGapDegrees": correspondence.get("centerGapDegrees"),
        "mouthIntervalOverlapDegrees": correspondence.get("mouthIntervalOverlapDegrees"),
    }


def result_projection(observed: dict[str, Any]) -> dict[str, Any]:
    symmetric = observed["r10SymmetricRecovery"]
    df_seeded = observed.get("o3p8DfSeededLocalBfRecovery")
    bf_seeded = observed.get("bfSeededLocalDfRecovery")
    selected = symmetric.get("selectedCluster")
    return {
        "priorState": observed["baselineR8State"],
        "baselineState": observed["baselineR8State"],
        "inheritedR9State": observed["inheritedR9State"],
        "finalState": observed["state"],
        "r10Invoked": bool(symmetric["invoked"]),
        "physicalClusterCount": len(symmetric["physicalClusters"]),
        "selectedClusterDirections": [] if selected is None else list(selected["directions"]),
        "dfSeedCount": 0 if df_seeded is None else int(df_seeded["seedCount"]),
        "dfSeedEligibleCount": 0 if df_seeded is None else len(df_seeded["eligibleSeedIndices"]),
        "bfSeedCount": 0 if bf_seeded is None else int(bf_seeded["seedCount"]),
        "bfHypothesisCount": 0 if bf_seeded is None else int(bf_seeded["hypothesisCount"]),
        "bfHypothesisEligibleCount": 0 if bf_seeded is None else len(bf_seeded["eligibleHypothesisIndices"]),
        "eligibleHypotheses": [hypothesis_projection(row) for row in symmetric["eligibleHypotheses"]],
    }


def run_dev6(
    output_root: Path,
    prerequisite_summary: Path | None,
    prerequisite_sha256: str | None,
) -> dict[str, Any]:
    preflight()
    prerequisite = validate_gate(prerequisite_summary, prerequisite_sha256)
    output_root = validate_output_root(output_root)
    base = load_base()
    rows, cases = base.frozen_inputs()
    selected = base.select("DEV6", rows, cases)
    need(len(selected) == 6, "DEV6 selector is not exactly six frozen cases")
    path_plan = validate_stage_path_plan(output_root, selected)
    canonical, canonical_sha = read_json_and_sha256(CANONICAL_JOB)
    need(canonical_sha == CANONICAL_JOB_SHA256, "Canonical job changed before DEV6")
    canonical_fixed = base.fixed_job_projection(canonical)
    prior_by_identity = base.prevalidate_stage_evidence("DEV6", selected, cases, {}, canonical_fixed)
    output_root.mkdir()
    jobs = output_root / "jobs"
    outputs = output_root / "cases"
    jobs.mkdir()
    outputs.mkdir()
    env = isolated_env()
    results: list[dict[str, Any]] = []
    compact_results: list[dict[str, Any]] = []
    expected_provenance = {
        "r10Sha256": R10_SHA256,
        "r9PredecessorSha256": R9_SHA256,
        "r8PredecessorSha256": R8_SHA256,
        "r6Sha256": R6_SHA256,
        "topologySha256": TOPOLOGY_SHA256,
        "o3p8Sha256": O3P8_SHA256,
        "runtimeSha256": RUNTIME_SHA256,
        "opencvVersion": EXPECTED_OPENCV_VERSION,
        "numpyVersion": EXPECTED_NUMPY_VERSION,
    }
    for ordinal, row in enumerate(selected, 1):
        identity = str(row["identity"])
        safe_id = str(row["safeId"])
        prior = prior_by_identity[identity]
        try:
            need(prior["classification"] == "PINNED_EXECUTABLE", f"DEV6 predecessor is not executable: {identity}")
            job = dict(canonical_fixed)
            job["revision"] = f"O3F9_R10_DEV6_{ordinal:04d}"
            job["inputs"] = [
                {
                    "identity": f"{safe_id}-{channel}",
                    "pairId": safe_id,
                    "channel": channel,
                    "path": str(row[key]["path"]),
                    "bytes": int(row[key]["bytes"]),
                    "sha256": str(row[key]["sha256"]).upper(),
                }
                for channel, key in (("BF", "bf"), ("DF", "df"))
            ]
            job_path = jobs / f"J{ordinal:04d}.json"
            write_new(job_path, job)
            case_root = outputs / f"C{ordinal:04d}"
            child = subprocess.run(
                [str(RUNTIME), "-I", "-B", str(R10), "--run", "--job", str(job_path), "--output-root", str(case_root)],
                capture_output=True,
                text=True,
                timeout=600,
                env=env,
            )
            (output_root / f"C{ordinal:04d}.stdout.txt").write_text(child.stdout, encoding="utf-8", newline="\n")
            (output_root / f"C{ordinal:04d}.stderr.txt").write_text(child.stderr, encoding="utf-8", newline="\n")
            need(child.returncode == 0, f"R10 child exit {child.returncode}: {child.stderr[-1200:]}")
            manifest_path = case_root / "MANIFEST.json"
            manifest, manifest_sha = read_json_and_sha256(manifest_path)
            need(isinstance(manifest.get("results"), list) and len(manifest["results"]) == 1, "R10 manifest is not one pair")
            observed = manifest["results"][0]
            need(str(observed["pairId"]) == safe_id, "R10 result pair identity changed")
            need(str(observed["baselineR8State"]) == str(row["r8State"]), "R10 baseline state differs from frozen R8 state")
            need(
                base.r8_decision_projection(observed) == base.r8_decision_projection(prior["priorResult"]),
                "R10 changed inherited R8 decision evidence",
            )
            need(str(manifest["revision"]) == job["revision"] and int(manifest["inputCount"]) == 2, "R10 manifest binding changed")
            need(manifest.get("engineProvenance") == expected_provenance, "R10 engine provenance changed")
            need(sha256(job_path) == str(manifest["jobSha256"]).upper(), "R10 manifest job hash changed")
            need(Path(str(manifest["jobPath"])).resolve(strict=False) == job_path.resolve(strict=False), "R10 manifest job path changed")
            need(manifest.get("sourceMutationPerformed") is False and manifest.get("providerActivated") is False, "R10 exceeded review-only authority")
            projected = result_projection(observed)
            detailed = {
                "ordinal": ordinal,
                "identity": identity,
                "safeId": safe_id,
                "priorR8State": row["r8State"],
                **projected,
                "manifestPath": str(manifest_path),
                "manifestSha256": manifest_sha,
                "execution": "PASS_R10_CHILD",
                "error": None,
            }
            results.append(detailed)
            compact_results.append(
                {
                    key: detailed[key]
                    for key in (
                        "ordinal",
                        "identity",
                        "safeId",
                        "priorR8State",
                        "baselineState",
                        "inheritedR9State",
                        "finalState",
                        "r10Invoked",
                        "physicalClusterCount",
                        "selectedClusterDirections",
                        "dfSeedCount",
                        "dfSeedEligibleCount",
                        "bfSeedCount",
                        "bfHypothesisCount",
                        "bfHypothesisEligibleCount",
                        "eligibleHypotheses",
                        "error",
                    )
                }
            )
        except Exception as exc:
            error = str(exc)[:1600]
            detailed = {
                "ordinal": ordinal,
                "identity": identity,
                "safeId": safe_id,
                "priorR8State": row["r8State"],
                "baselineState": None,
                "inheritedR9State": None,
                "finalState": "HOLD_O3F9_R10_PROVIDER_ERROR",
                "r10Invoked": False,
                "physicalClusterCount": 0,
                "selectedClusterDirections": [],
                "dfSeedCount": 0,
                "dfSeedEligibleCount": 0,
                "bfSeedCount": 0,
                "bfHypothesisCount": 0,
                "bfHypothesisEligibleCount": 0,
                "eligibleHypotheses": [],
                "execution": "HOLD_R10_CHILD",
                "error": error,
            }
            results.append(detailed)
            compact_results.append(dict(detailed))
    counts = Counter(str(row["finalState"]) for row in results)
    executed_count = sum(row["execution"] == "PASS_R10_CHILD" for row in results)
    new_hold_count = sum(row["execution"] == "HOLD_R10_CHILD" for row in results)
    clean_completion = len(results) == 6 and executed_count == 6 and new_hold_count == 0
    summary = {
        "schema": "argos_ocv03_o3f9_r10_dev6_result_v1",
        "state": "COMPLETE_O3F9_DEV6" if clean_completion else "HOLD_O3F9_DEV6_EXECUTION",
        "stage": "DEV6",
        "runnerSha256": sha256(Path(__file__).resolve()),
        "selectedCount": 6,
        "executedCount": executed_count,
        "newProviderHoldCount": new_hold_count,
        "stateCounts": dict(counts),
        "baseRunnerSha256": BASE_RUNNER_SHA256,
        "r10Sha256": R10_SHA256,
        "r9PredecessorSha256": R9_SHA256,
        "r8PredecessorSha256": R8_SHA256,
        "o3p8Sha256": O3P8_SHA256,
        "localGateSourceSha256": LOCAL_GATE_SHA256,
        "canonicalJobSha256": CANONICAL_JOB_SHA256,
        "r6Sha256": R6_SHA256,
        "topologySha256": TOPOLOGY_SHA256,
        "runtimeSha256": RUNTIME_SHA256,
        "sourceResultsSha256": RESULTS_SHA256,
        "reviewOrderSha256": REVIEW_SHA256,
        "prerequisite": prerequisite,
        "pathPlan": path_plan,
        "operatorFeedbackConsumedForInference": False,
        "numericThresholdRelaxationPerformed": False,
        "postResultSelectorRelaxationPerformed": False,
        "sourceMutation": False,
        "providerActivated": False,
        "sourceHoldRowsMutated": False,
        "successorResultsWrittenSeparately": True,
        "results": results,
    }
    summary_path = output_root / "SUMMARY.json"
    write_new(summary_path, summary)
    return {
        "state": summary["state"],
        "stage": "DEV6",
        "selectedCount": 6,
        "executedCount": executed_count,
        "newProviderHoldCount": new_hold_count,
        "stateCounts": dict(counts),
        "summarySha256": sha256(summary_path),
        "results": compact_results,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("SELF_TEST", "PREFLIGHT", "GATE", "DEV6"))
    parser.add_argument("--output-root")
    parser.add_argument("--prerequisite-summary")
    parser.add_argument("--prerequisite-sha256")
    args = parser.parse_args()
    if args.stage == "SELF_TEST":
        need(not args.output_root and not args.prerequisite_summary and not args.prerequisite_sha256, "SELF_TEST accepts no paths")
        self_test()
        return 0
    if args.stage == "PREFLIGHT":
        need(not args.output_root and not args.prerequisite_summary and not args.prerequisite_sha256, "PREFLIGHT accepts no paths")
        preflight()
        print('{"state":"PASS_O3F9_STAGED_PREFLIGHT","mutationsPerformed":false}')
        return 0
    need(args.output_root, "--output-root is required")
    if args.stage == "GATE":
        need(not args.prerequisite_summary and not args.prerequisite_sha256, "GATE accepts no prerequisite")
        result = run_gate(Path(args.output_root))
        print(json.dumps(result, separators=(",", ":")))
        return 0 if result["state"] == "COMPLETE_O3F9_GATE" else 2
    result = run_dev6(
        Path(args.output_root),
        None if not args.prerequisite_summary else Path(args.prerequisite_summary),
        args.prerequisite_sha256,
    )
    print(json.dumps(result, separators=(",", ":")))
    return 0 if result["state"] == "COMPLETE_O3F9_DEV6" else 2


if __name__ == "__main__":
    raise SystemExit(main())
