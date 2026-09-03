#!/usr/bin/env python3
"""Exercise the exact frozen O3F9 runner output-root contract without writes."""

from __future__ import annotations

import argparse
import ast
import hashlib
import importlib.util
import inspect
import json
import os
import textwrap
from pathlib import Path, PureWindowsPath
from types import ModuleType


def need(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def load_runner(path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("argos_o3f14_exact_o3f9_runner", path)
    need(spec is not None and spec.loader is not None, "Exact runner import specification failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    need(callable(getattr(module, "validate_output_root", None)), "Exact runner output-root validator is absent")
    need(callable(getattr(module, "owned_case_alias", None)), "Exact runner owned alias context is absent")
    return module


def normalized(value: object) -> str:
    return str(value).replace("/", "\\").rstrip("\\").upper()


class SimulatedDriveParent:
    def __init__(self, anchor: str) -> None:
        self.anchor = anchor

    def is_dir(self) -> bool:
        return True

    def __eq__(self, other: object) -> bool:
        return normalized(self.anchor) == normalized(other)


class SimulatedCreateNewRoot:
    """Path-like input that preserves exact validator logic but performs no I/O."""

    def __init__(self, value: str) -> None:
        self.pure = PureWindowsPath(value.replace("/", "\\"))

    def is_absolute(self) -> bool:
        return self.pure.is_absolute()

    def resolve(self, strict: bool = False) -> "SimulatedCreateNewRoot":
        del strict
        return self

    @property
    def drive(self) -> str:
        return self.pure.drive

    @property
    def parent(self) -> SimulatedDriveParent:
        return SimulatedDriveParent(self.pure.anchor)

    @property
    def anchor(self) -> str:
        return self.pure.anchor

    @property
    def name(self) -> str:
        return self.pure.name

    def exists(self) -> bool:
        return False

    def __str__(self) -> str:
        return str(self.pure)


def validate(module: ModuleType, raw: str, simulate: bool) -> object:
    candidate: object = SimulatedCreateNewRoot(raw) if simulate else Path(raw)
    return module.validate_output_root(candidate)


def exact_return_dict_keys(function: object, label: str) -> list[str]:
    tree = ast.parse(textwrap.dedent(inspect.getsource(function)))
    candidates: list[list[str]] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Return) or not isinstance(node.value, ast.Dict):
            continue
        keys: list[str] = []
        for key in node.value.keys:
            need(isinstance(key, ast.Constant) and isinstance(key.value, str), f"{label} return has a non-literal key")
            keys.append(key.value)
        candidates.append(sorted(keys))
    need(len(candidates) == 1, f"{label} must have exactly one literal terminal return dictionary")
    return candidates[0]


def alias_contract(path: Path, expected_sha256: str) -> tuple[dict[str, object], dict[str, object]]:
    expected = expected_sha256.upper()
    need(len(expected) == 64 and sha256(path) == expected, "Frozen alias-plan hash changed")
    plan = json.loads(path.read_text(encoding="utf-8"))
    need(plan.get("schema") == "argos_ocv03_o3f12_dev6_source_alias_plan_v1", "Frozen alias-plan schema changed")
    need(plan.get("state") == "FROZEN_FOR_BUILD" and plan.get("aliasDrive") == "Q:", "Frozen alias-plan state/drive changed")
    need(plan.get("canonicalRoot") == "D:/KLARFExport", "Frozen alias-plan canonical root changed")
    need((plan.get("caseCount"), plan.get("sourceLeafCount")) == (6, 12) and len(plan.get("cases", [])) == 6, "Frozen alias-plan count changed")
    canonical: list[str] = []
    aliases: list[str] = []
    slot16_broad: list[int] = []
    reserve = int(plan["pathSuffixReserve"])
    for ordinal, case in enumerate(plan["cases"], 1):
        need(case.get("ordinal") == ordinal and len(case.get("sources", [])) == 2, "Frozen alias-plan case shape changed")
        need({row.get("channel") for row in case["sources"]} == {"BF", "DF"}, "Frozen alias-plan channels changed")
        for row in case["sources"]:
            source, alias = str(row["canonicalPath"]), str(row["aliasPath"])
            need(source.startswith(str(case["slotAnchor"]) + "/"), "Canonical source escaped its slot anchor")
            need(alias == "Q:/" + str(row["aliasRelativePath"]), "Frozen alias spelling changed")
            need(len(source) + reserve < 230 and len(alias) + reserve < 200, "Frozen canonical/alias path budget changed")
            need(max(map(len, source.split("/"))) <= 80 and max(map(len, alias.split("/"))) <= 80, "Frozen source component budget changed")
            canonical.append(source); aliases.append(alias)
            if "Slot16|FRONT" in str(case["identity"]):
                slot16_broad.append(len("Q:/" + source.removeprefix("D:/KLARFExport/")) + reserve)
    need(len(canonical) == len(set(canonical)) == len(aliases) == len(set(aliases)) == 12, "Frozen canonical/alias cardinality changed")
    canonical_effective = [len(path) + reserve for path in canonical]; alias_effective = [len(path) + reserve for path in aliases]
    need(min(canonical_effective) >= 200 and max(canonical_effective) < 230 and max(alias_effective) < 200, "Frozen alias-required length facts changed")
    need(len(slot16_broad) == 2 and min(slot16_broad) >= 200, "Broad-root Slot16 negative control no longer fails")
    facts = {"planSha256": expected, "schema": plan["schema"], "state": plan["state"], "aliasDrive": "Q:", "caseCount": 6,
             "canonicalLeafCount": 12, "aliasLeafCount": 12, "minimumCanonicalEffectiveLength": min(canonical_effective),
             "maximumCanonicalEffectiveLength": max(canonical_effective), "maximumAliasEffectiveLength": max(alias_effective), "slot16BroadRootMinimumEffectiveLength": min(slot16_broad),
             "broadRootSlot16Rejected": True, "sourceImageBytesRead": False}
    return plan, facts


def exercise_owned_alias(module: ModuleType, root: Path) -> dict[str, object]:
    need(root.is_absolute() and root.parent.is_dir() and not root.exists(), "Alias fixture root must be fresh under an existing parent")
    slot = root / "S"; bf = slot / "BrightfieldFrontsideWafer" / "resizedImage" / "bf.bmp"; df = slot / "DarkfieldFrontsideWafer" / "resizedImage" / "df.bmp"
    need(max(len(str(path)) + 32 for path in (bf, df)) < 200, "Alias fixture path budget failed")
    bf.parent.mkdir(parents=True); df.parent.mkdir(parents=True); bf.write_bytes(b"BF"); df.write_bytes(b"DF")
    plan = {"slotRoot": slot, "bf": {"canonicalPath": bf, "aliasPath": Path(r"Q:\BrightfieldFrontsideWafer\resizedImage\bf.bmp")},
            "df": {"canonicalPath": df, "aliasPath": Path(r"Q:\DarkfieldFrontsideWafer\resizedImage\df.bmp")}}
    before, before_snapshot = module.query_all_subst_mappings()
    need("Q:" not in before and not module.logical_drive_present("Q:"), "Q: is occupied before alias fixture")
    success: dict[str, object] = {}
    with module.owned_case_alias(plan, success):
        need(os.path.samefile(plan["bf"]["canonicalPath"], plan["bf"]["aliasPath"]), "Success alias samefile failed")
    after_success, _ = module.query_all_subst_mappings()
    need("Q:" not in after_success and not module.logical_drive_present("Q:"), "Q: remained after success fixture")
    injected: dict[str, object] = {}
    try:
        with module.owned_case_alias(plan, injected):
            raise RuntimeError("INJECTED_O3F14_ALIAS_FIXTURE_EXCEPTION")
    except RuntimeError as exc:
        need(str(exc) == "INJECTED_O3F14_ALIAS_FIXTURE_EXCEPTION", "Injected alias exception changed")
    after_failure, _ = module.query_all_subst_mappings()
    need("Q:" not in after_failure and not module.logical_drive_present("Q:"), "Q: remained after exception fixture")
    required = ("exactTargetVerified", "sameFileVerified", "ownedMappingRemoved", "verifiedAbsentAfterRemove")
    need(all(success.get(key) is True and injected.get(key) is True for key in required), "Owned alias lifecycle evidence changed")
    return {"exercised": True, "fixtureRoot": str(root), "fixtureFileCount": 2, "substZeroArgumentQueryUsed": True,
            "success": success, "injectedException": injected, "qAbsentAfterBoth": True, "beforeAllMappings": before_snapshot}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runner", required=True)
    parser.add_argument("--runner-sha256", required=True)
    parser.add_argument("--gate-root", required=True)
    parser.add_argument("--dev-root", required=True)
    parser.add_argument("--alias-plan", required=True)
    parser.add_argument("--alias-plan-sha256", required=True)
    parser.add_argument("--subst-path", required=True)
    parser.add_argument("--subst-sha256", required=True)
    parser.add_argument("--exercise-alias", action="store_true")
    parser.add_argument("--alias-fixture-root")
    parser.add_argument("--simulate-filesystem", action="store_true")
    args = parser.parse_args()

    runner = Path(args.runner).resolve(strict=True)
    expected_runner_sha256 = args.runner_sha256.upper()
    need(len(expected_runner_sha256) == 64 and sha256(runner) == expected_runner_sha256, "Exact runner hash changed")
    need(args.gate_root.replace("\\", "/") == "D:/O3F9G14", "O3F14 exact GATE contract root changed")
    need(args.dev_root.replace("\\", "/") == "D:/O3F9D14", "O3F14 exact DEV6 contract root changed")
    need(args.gate_root != args.dev_root, "O3F14 exact contract roots collapsed")
    plan_path = Path(args.alias_plan).resolve(strict=True)
    _, alias_facts = alias_contract(plan_path, args.alias_plan_sha256)
    subst_path = Path(args.subst_path).resolve(strict=True)
    need(subst_path.is_absolute() and sha256(subst_path) == args.subst_sha256.upper(), "Absolute subst.exe pin changed")

    module = load_runner(runner)
    need(Path(module.SUBST_EXE).resolve(strict=True) == subst_path, "Real runner subst.exe path changed")
    gate_terminal_keys = exact_return_dict_keys(module.run_gate, "GATE")
    dev6_terminal_keys = exact_return_dict_keys(module.run_dev6, "DEV6")
    need(gate_terminal_keys == sorted(["commands", "stage", "state", "summarySha256"]), "Exact runner GATE terminal schema changed")
    need(dev6_terminal_keys == sorted(["aliasEvidence", "executedCount", "newProviderHoldCount", "results", "selectedCount", "stage", "state", "stateCounts", "summarySha256"]), "Exact runner DEV6 terminal schema changed")
    gate = validate(module, args.gate_root, args.simulate_filesystem)
    dev = validate(module, args.dev_root, args.simulate_filesystem)

    rejected = False
    try:
        validate(module, "D:/O3F14_REJECT", True)
    except RuntimeError as exc:
        rejected = "D:\\O3F9*" in str(exc)
    need(rejected, "Exact runner did not reject the incompatible O3F14 root prefix")
    need(bool(args.exercise_alias) == bool(args.alias_fixture_root), "Alias exercise and fixture root must be supplied together")
    alias_facts["substPath"] = str(subst_path); alias_facts["substSha256"] = args.subst_sha256.upper()
    alias_facts["lifecycle"] = exercise_owned_alias(module, Path(args.alias_fixture_root).resolve(strict=False)) if args.exercise_alias else {"exercised": False, "metadataStaticChecksOnly": True}

    print(
        json.dumps(
            {
                "schema": "argos_ocv03_o3f14_exact_runner_root_contract_v1",
                "state": "PASS_O3F14_EXACT_REAL_RUNNER_ROOT_CONTRACT",
                "runnerSha256": expected_runner_sha256,
                "gateRoot": str(gate).replace("\\", "/"),
                "dev6Root": str(dev).replace("\\", "/"),
                "simulatedFilesystem": args.simulate_filesystem,
                "incompatibleO3F14PrefixRejected": True,
                "gateTerminalKeys": gate_terminal_keys,
                "dev6TerminalKeys": dev6_terminal_keys,
                "aliasContract": alias_facts,
                "sourceImageBytesRead": False,
                "outputCreated": bool(args.exercise_alias),
                "mutationsPerformed": bool(args.exercise_alias),
            },
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
