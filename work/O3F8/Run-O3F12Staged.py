#!/usr/bin/env python3
"""Run the frozen O3F8/R10 draft through the O3F12 GATE and aliased DEV6 stages."""

from __future__ import annotations

import argparse
from collections import Counter
from contextlib import contextmanager
import ctypes
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
SOURCE_ALIAS_PLAN = HERE / "O3F12_DEV6_SOURCE_ALIAS_PLAN.json"
INSTALLED = Path(r"C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1")
RUNTIME = Path(r"D:\AFCV1\rt\python.exe")
EXPORT_ROOT = Path(r"D:\KLARFExport")
PATTERNED_ROOT = EXPORT_ROOT / "PatternedFront"
SUBST_EXE = Path(r"C:\Windows\System32\subst.exe")
ALIAS_DRIVE = "Q:"
ALIAS_ROOT = Path("Q:\\")

BASE_RUNNER_SHA256 = "44B378616CCCFEB0C67DF09196D0B7CDD515DBE35CEA84F4DBEB69DE326AD8C7"
R10_SHA256 = "0EEEE7A396E918AF44082EC0930871A6A94C1FBB59D3F5CEF1AC34D1273745FA"
R9_SHA256 = "DB44AD35205AC088FE7E24C1CC8FA9291311922A7D31E0F1C055BA92EAFD2FC1"
R8_SHA256 = "068ECC0D4F547FCFD7A0A2AEDF673B71BB0C46207DE8EC0F47312A9030B0734B"
O3P8_SHA256 = "41F60AF393E0B2C752AF6B33BB6673145490AE2BB346A4DA8E59A2D42E383E36"
LOCAL_GATE_SHA256 = "7125CF87F9B094B23D77A4A8F9347FC0F95C9719FDCEA98CF33185A7B67E0092"
O3P8_JOB_SHA256 = "2C2D656A879BBA1DEC6377D1855A949459C7AC6F50145761B8D283076FEAD1F9"
CANONICAL_JOB_SHA256 = "E384ABD12E9B77DB9B4492504A5D792E316C5396C3B0A3E1D2B1AB11BB4C7DD3"
SOURCE_ALIAS_PLAN_SHA256 = "2ACA89A702CCC9E8B346EF2E31EF3C34382DF59D23D9DF3E5B431A4E37AD7D9C"
R6_SHA256 = "90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30"
TOPOLOGY_SHA256 = "D8897C1A5B60CB5AA9B0343CF8C9E5A249CCC5DEF5FBCDFE645EC08C354EF3BD"
RESULTS_SHA256 = "A933227FE4F41259D53D586CBB5189E1B6542B96B7585B606207DAFD35326BD8"
REVIEW_SHA256 = "D57DFE4301FEE2144D18EF4DB2BFD0A323EB095C117BBF10A856A691A8E73BBA"
RUNTIME_SHA256 = "7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1"
SUBST_SHA256 = "158598ED3D590937C964B43DD91546FFCABAB5636B6CE619B4FFC43224013BB6"
EXPECTED_OPENCV_VERSION = "5.0.0"
EXPECTED_NUMPY_VERSION = "2.5.2"
PATH_SUFFIX_RESERVE = 32
CANONICAL_EFFECTIVE_LIMIT = 230
ALIAS_EFFECTIVE_LIMIT = 200
MAX_COMPONENT_LENGTH = 80
SUBST_OUTPUT_BYTE_LIMIT = 32768
_BASE: Any | None = None


class AliasContractError(RuntimeError):
    """A Q: alias ownership, path-budget, or cleanup invariant failed."""


def need(value: Any, message: str) -> None:
    if not value:
        raise RuntimeError(message)


def alias_need(value: Any, message: str) -> None:
    if not value:
        raise AliasContractError(message)


def normalized_windows_path(value: Path | str) -> str:
    return os.path.normcase(os.path.normpath(str(value))).rstrip("\\/")


def path_components(path: Path) -> list[str]:
    return [part for part in path.parts if part != path.anchor]


def alias_path_budget(path: Path, effective_limit: int, label: str) -> dict[str, Any]:
    raw_length = len(str(path))
    effective_length = raw_length + PATH_SUFFIX_RESERVE
    components = path_components(path)
    maximum_component = max((len(part) for part in components), default=0)
    alias_need(effective_length < effective_limit, f"{label} effective path is unsafe: {path}")
    alias_need(maximum_component <= MAX_COMPONENT_LENGTH, f"{label} component is unsafe: {path}")
    return {
        "path": str(path),
        "rawPathLength": raw_length,
        "suffixReserve": PATH_SUFFIX_RESERVE,
        "effectivePathLength": effective_length,
        "effectiveLimitExclusive": effective_limit,
        "maximumComponentLength": maximum_component,
    }


def identity_slot_anchor(identity: str) -> str:
    marker = "|FRONT"
    offset = identity.find(marker)
    alias_need(offset > 0 and identity.find(marker, offset + len(marker)) < 0, f"Identity lacks one exact {marker} marker: {identity}")
    return identity[:offset]


def prevalidate_alias_plans(selected: list[dict[str, Any]]) -> list[dict[str, Any]]:
    alias_need(len(selected) == 6, "Alias planning requires exactly six DEV6 cases")
    plans: list[dict[str, Any]] = []
    for ordinal, row in enumerate(selected, 1):
        identity = str(row["identity"])
        identity_anchor = identity_slot_anchor(identity)
        channels: dict[str, dict[str, Any]] = {}
        for channel, key, channel_directory in (
            ("BF", "bf", "BrightfieldFrontsideWafer"),
            ("DF", "df", "DarkfieldFrontsideWafer"),
        ):
            source_row = row[key]
            canonical = Path(str(source_row["path"]))
            alias_need(canonical.is_absolute() and canonical.drive.upper() == "D:", f"{channel} canonical path is not absolute JBOD D:: {identity}")
            try:
                canonical.relative_to(PATTERNED_ROOT)
            except ValueError as exc:
                raise AliasContractError(f"{channel} canonical path escaped exact PatternedFront root: {identity}") from exc
            alias_need(
                canonical.parent.name == "resizedImage"
                and canonical.parent.parent.name == channel_directory,
                f"{channel} canonical suffix is not {channel_directory}\\resizedImage\\leaf: {identity}",
            )
            slot_root = canonical.parent.parent.parent
            expected_relative = (channel_directory, "resizedImage", canonical.name)
            alias_need(
                canonical.relative_to(slot_root).parts == expected_relative,
                f"{channel} canonical path does not have the exact channel suffix: {identity}",
            )
            try:
                relative_anchor = slot_root.relative_to(EXPORT_ROOT)
            except ValueError as exc:
                raise AliasContractError(f"{channel} slot root escaped exact KLARFExport root: {identity}") from exc
            alias_need(
                normalized_windows_path(relative_anchor) == normalized_windows_path(identity_anchor),
                f"{channel} slot root does not match identity before |FRONT: {identity}",
            )
            alias_need(canonical.is_file(), f"{channel} canonical source is missing: {canonical}")
            expected_bytes = int(source_row["bytes"])
            alias_need(expected_bytes >= 1 and canonical.stat().st_size == expected_bytes, f"{channel} canonical byte count changed: {identity}")
            pinned_sha256 = required_sha256(source_row["sha256"], f"{channel} canonical source {identity}")
            alias_path = ALIAS_ROOT / channel_directory / "resizedImage" / canonical.name
            channels[channel.lower()] = {
                "canonicalPath": canonical,
                "aliasPath": alias_path,
                "slotRoot": slot_root,
                "bytes": expected_bytes,
                "sha256": pinned_sha256,
                "canonicalBudget": alias_path_budget(canonical, CANONICAL_EFFECTIVE_LIMIT, f"{channel} canonical"),
                "aliasBudget": alias_path_budget(alias_path, ALIAS_EFFECTIVE_LIMIT, f"{channel} alias"),
            }
        bf_slot = channels["bf"]["slotRoot"]
        df_slot = channels["df"]["slotRoot"]
        alias_need(normalized_windows_path(bf_slot) == normalized_windows_path(df_slot), f"BF/DF slot roots differ: {identity}")
        try:
            same_slot = os.path.samefile(bf_slot, df_slot)
        except OSError as exc:
            raise AliasContractError(f"BF/DF slot-root identity could not be verified: {identity}") from exc
        alias_need(same_slot, f"BF/DF slot roots are not the same filesystem object: {identity}")
        alias_need(
            normalized_windows_path(channels["bf"]["aliasPath"]) != normalized_windows_path(channels["df"]["aliasPath"]),
            f"BF/DF alias paths collide: {identity}",
        )
        plans.append(
            {
                "ordinal": ordinal,
                "identity": identity,
                "safeId": str(row["safeId"]),
                "identityAnchor": identity_anchor,
                "slotRoot": bf_slot,
                "bf": channels["bf"],
                "df": channels["df"],
            }
        )
    alias_need(len({plan["identity"] for plan in plans}) == 6, "Alias plans do not cover six unique identities")
    return plans


def alias_plan_projection(plans: list[dict[str, Any]]) -> dict[str, Any]:
    cases: list[dict[str, Any]] = []
    for plan in plans:
        cases.append(
            {
                "ordinal": plan["ordinal"],
                "identity": plan["identity"],
                "safeId": plan["safeId"],
                "identityAnchor": plan["identityAnchor"],
                "slotRoot": str(plan["slotRoot"]),
                "bf": {
                    "canonicalPath": str(plan["bf"]["canonicalPath"]),
                    "aliasPath": str(plan["bf"]["aliasPath"]),
                    "bytes": plan["bf"]["bytes"],
                    "sha256": plan["bf"]["sha256"],
                    "canonicalBudget": plan["bf"]["canonicalBudget"],
                    "aliasBudget": plan["bf"]["aliasBudget"],
                },
                "df": {
                    "canonicalPath": str(plan["df"]["canonicalPath"]),
                    "aliasPath": str(plan["df"]["aliasPath"]),
                    "bytes": plan["df"]["bytes"],
                    "sha256": plan["df"]["sha256"],
                    "canonicalBudget": plan["df"]["canonicalBudget"],
                    "aliasBudget": plan["df"]["aliasBudget"],
                },
            }
        )
    return {
        "state": "PASS_O3F12_ALL_SIX_ALIAS_PLANS_PREVALIDATED",
        "caseCount": len(cases),
        "allPlansValidatedBeforeImageRead": len(cases) == 6,
        "aliasDrive": ALIAS_DRIVE,
        "aliasAnchorKind": "CASE_SLOT_ROOT",
        "canonicalEffectiveLimitExclusive": CANONICAL_EFFECTIVE_LIMIT,
        "aliasEffectiveLimitExclusive": ALIAS_EFFECTIVE_LIMIT,
        "maximumComponentLength": MAX_COMPONENT_LENGTH,
        "suffixReserve": PATH_SUFFIX_RESERVE,
        "cases": cases,
    }


def portable_path(value: Path | str) -> str:
    return str(value).replace("\\", "/")


def validate_frozen_alias_plan(plans: list[dict[str, Any]]) -> dict[str, Any]:
    try:
        frozen, actual_sha256 = read_json_and_sha256(SOURCE_ALIAS_PLAN)
    except Exception as exc:
        raise AliasContractError("Frozen O3F12 DEV6 source-alias plan could not be read") from exc
    alias_need(actual_sha256 == SOURCE_ALIAS_PLAN_SHA256, "Frozen O3F12 DEV6 source-alias plan hash changed")
    alias_need(
        frozen.get("schema") == "argos_ocv03_o3f12_dev6_source_alias_plan_v1"
        and frozen.get("state") == "FROZEN_FOR_BUILD"
        and frozen.get("aliasDrive") == ALIAS_DRIVE
        and frozen.get("canonicalRoot") == portable_path(EXPORT_ROOT)
        and int(frozen.get("pathSuffixReserve", -1)) == PATH_SUFFIX_RESERVE
        and int(frozen.get("canonicalHardStopEffectiveLength", -1)) == CANONICAL_EFFECTIVE_LIMIT
        and int(frozen.get("aliasRequiredEffectiveLength", -1)) == ALIAS_EFFECTIVE_LIMIT
        and int(frozen.get("caseCount", -1)) == len(plans) == 6
        and int(frozen.get("sourceLeafCount", -1)) == 12,
        "Frozen O3F12 DEV6 source-alias plan header changed",
    )
    expected_cases: list[dict[str, Any]] = []
    for plan in plans:
        sources: list[dict[str, str]] = []
        for channel, key in (("BF", "bf"), ("DF", "df")):
            alias_relative = plan[key]["aliasPath"].relative_to(ALIAS_ROOT)
            sources.append(
                {
                    "channel": channel,
                    "canonicalPath": portable_path(plan[key]["canonicalPath"]),
                    "aliasRelativePath": portable_path(alias_relative),
                    "aliasPath": portable_path(plan[key]["aliasPath"]),
                }
            )
        expected_cases.append(
            {
                "ordinal": plan["ordinal"],
                "identity": portable_path(plan["identity"]),
                "slotAnchor": portable_path(plan["slotRoot"]),
                "sources": sources,
            }
        )
    alias_need(frozen.get("cases") == expected_cases, "Frozen alias plan differs from the exact ordered six derived case plans")
    return {
        "path": str(SOURCE_ALIAS_PLAN.resolve(strict=True)),
        "sha256": actual_sha256,
        "schema": frozen["schema"],
        "revision": frozen.get("revision"),
        "state": frozen["state"],
        "aliasDrive": frozen["aliasDrive"],
        "caseCount": len(expected_cases),
        "sourceLeafCount": 12,
        "exactOrderedPlansMatched": True,
    }


def logical_drive_present(drive: str) -> bool:
    alias_need(len(drive) == 2 and drive[1] == ":" and drive[0].isalpha(), f"Invalid alias drive: {drive}")
    mask = int(ctypes.windll.kernel32.GetLogicalDrives())
    alias_need(mask != 0, "GetLogicalDrives failed while checking Q: ownership")
    return bool(mask & (1 << (ord(drive[0].upper()) - ord("A"))))


def subst_snapshot(mappings: dict[str, str], stdout: str) -> dict[str, Any]:
    encoded = stdout.encode("utf-8")
    return {
        "mappingCount": len(mappings),
        "mappedDrives": sorted(mappings),
        "stdoutBytes": len(encoded),
        "stdoutSha256": hashlib.sha256(encoded).hexdigest().upper(),
    }


def query_all_subst_mappings() -> tuple[dict[str, str], dict[str, Any]]:
    child = subprocess.run(
        [str(SUBST_EXE)],
        capture_output=True,
        text=True,
        timeout=30,
        env=isolated_env(),
    )
    alias_need(child.returncode == 0, f"Absolute subst.exe all-mapping query failed with exit {child.returncode}")
    alias_need(not child.stderr, "Absolute subst.exe all-mapping query wrote stderr")
    alias_need(len(child.stdout.encode("utf-8")) <= SUBST_OUTPUT_BYTE_LIMIT, "subst.exe all-mapping query exceeded bounded output")
    mappings: dict[str, str] = {}
    for raw_line in child.stdout.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        left, separator, right = line.partition("=>")
        alias_need(bool(separator), f"Unparseable subst.exe mapping row: {line[:200]}")
        left = left.strip()
        target = right.strip()
        alias_need(len(left) >= 2 and left[0].isalpha() and left[1] == ":" and target, f"Invalid subst.exe mapping row: {line[:200]}")
        drive = left[:2].upper()
        alias_need(drive not in mappings, f"Duplicate subst.exe drive row: {drive}")
        mappings[drive] = target
    return mappings, subst_snapshot(mappings, child.stdout)


def subst_action(arguments: list[str], label: str) -> dict[str, Any]:
    child = subprocess.run(
        [str(SUBST_EXE), *arguments],
        capture_output=True,
        text=True,
        timeout=30,
        env=isolated_env(),
    )
    alias_need(child.returncode == 0, f"{label} failed with exit {child.returncode}: {child.stderr[:400]}")
    alias_need(not child.stderr, f"{label} wrote stderr")
    alias_need(
        len(child.stdout.encode("utf-8")) <= 4096,
        f"{label} exceeded bounded output",
    )
    return {
        "returnCode": child.returncode,
        "stdoutBytes": len(child.stdout.encode("utf-8")),
        "stdoutSha256": hashlib.sha256(child.stdout.encode("utf-8")).hexdigest().upper(),
    }


def mappings_equal(left: dict[str, str], right: dict[str, str]) -> bool:
    return set(left) == set(right) and all(
        normalized_windows_path(left[drive]) == normalized_windows_path(right[drive]) for drive in left
    )


def verify_owned_alias_target(mappings: dict[str, str], slot_root: Path, label: str) -> None:
    target = mappings.get(ALIAS_DRIVE)
    alias_need(target is not None, f"{label}: owned Q: mapping is absent")
    alias_need(
        normalized_windows_path(target) == normalized_windows_path(slot_root),
        f"{label}: Q: target is not the exact planned slot root",
    )
    try:
        same_target = os.path.samefile(ALIAS_ROOT, slot_root)
    except OSError as exc:
        raise AliasContractError(f"{label}: Q: target samefile verification failed") from exc
    alias_need(same_target, f"{label}: Q: target is not the planned slot filesystem object")


@contextmanager
def owned_case_alias(plan: dict[str, Any], evidence: dict[str, Any]) -> Any:
    created = False
    before_mappings: dict[str, str] = {}
    try:
        before_mappings, before_snapshot = query_all_subst_mappings()
        evidence["beforeAllMappings"] = before_snapshot
        alias_need(ALIAS_DRIVE not in before_mappings, "Q: is already occupied by a subst mapping")
        alias_need(not logical_drive_present(ALIAS_DRIVE), "Q: is already occupied by a logical drive")
        evidence["create"] = subst_action([ALIAS_DRIVE, str(plan["slotRoot"])], "Q: alias creation")
        created = True
        created_mappings, created_snapshot = query_all_subst_mappings()
        evidence["afterCreateAllMappings"] = created_snapshot
        verify_owned_alias_target(created_mappings, plan["slotRoot"], "after create")
        alias_need(
            set(created_mappings) == set(before_mappings) | {ALIAS_DRIVE}
            and all(
                normalized_windows_path(created_mappings[drive]) == normalized_windows_path(target)
                for drive, target in before_mappings.items()
            ),
            "Q: creation changed an unrelated subst mapping",
        )
        alias_need(logical_drive_present(ALIAS_DRIVE), "Q: did not become a logical drive after creation")
        for channel in ("bf", "df"):
            try:
                same_source = os.path.samefile(plan[channel]["aliasPath"], plan[channel]["canonicalPath"])
            except OSError as exc:
                raise AliasContractError(f"{channel.upper()} alias-to-canonical samefile verification failed") from exc
            alias_need(same_source, f"{channel.upper()} alias does not resolve to its canonical source")
        evidence["exactTargetVerified"] = True
        evidence["sameFileVerified"] = True
        evidence["unrelatedMappingsPreservedOnCreate"] = True
        evidence["sourceImageReadWindow"] = "OWNED_EXACT_Q_MAPPING_ONLY"
        yield
    finally:
        if created:
            current_mappings, current_snapshot = query_all_subst_mappings()
            evidence["beforeRemoveAllMappings"] = current_snapshot
            verify_owned_alias_target(current_mappings, plan["slotRoot"], "before remove")
            alias_need(
                set(current_mappings) == set(before_mappings) | {ALIAS_DRIVE}
                and all(
                    normalized_windows_path(current_mappings[drive]) == normalized_windows_path(target)
                    for drive, target in before_mappings.items()
                ),
                "An unrelated subst mapping changed while Q: was owned",
            )
            evidence["remove"] = subst_action([ALIAS_DRIVE, "/D"], "owned Q: alias removal")
            after_mappings, after_snapshot = query_all_subst_mappings()
            evidence["afterRemoveAllMappings"] = after_snapshot
            alias_need(ALIAS_DRIVE not in after_mappings, "Owned Q: mapping remained after removal")
            alias_need(not logical_drive_present(ALIAS_DRIVE), "Q: logical drive remained after removal")
            alias_need(mappings_equal(after_mappings, before_mappings), "Unrelated subst mappings changed after Q: removal")
            evidence["ownedMappingRemoved"] = True
            evidence["verifiedAbsentAfterRemove"] = True
            evidence["unrelatedMappingsPreservedAfterRemove"] = True


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
        spec = importlib.util.spec_from_file_location("argos_o3f12_frozen_runner_base", BASE_RUNNER)
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
        (SOURCE_ALIAS_PLAN, SOURCE_ALIAS_PLAN_SHA256, "O3F12 frozen DEV6 source-alias plan"),
    ):
        need(path.is_file() and sha256(path) == expected, f"{label} pin changed: {path}")


def self_test() -> None:
    base = load_base()
    rows = [{"identity": "PatternedFront\\p"}, {"identity": "UnpatternedFront\\u"}, {"identity": "BackSide_BowComp\\b"}]
    current = [row for row in rows if row["identity"].startswith(("PatternedFront\\", "UnpatternedFront\\"))]
    need([row["identity"] for row in current] == ["PatternedFront\\p", "UnpatternedFront\\u"], "Current-recipe selector changed")
    need(base.R9_SHA256 == R9_SHA256 and base.R8_SHA256 == R8_SHA256, "Frozen runner predecessor pins changed")
    print('{"state":"PASS_O3F12_STAGED_RUNNER_SELF_TEST","mutationsPerformed":false}')


def preflight() -> None:
    assert_package_pins()
    base = load_base()
    need(
        SUBST_EXE.is_file() and sha256(SUBST_EXE) == SUBST_SHA256,
        f"Absolute subst.exe pin changed: {SUBST_EXE}",
    )
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


def validate_stage_path_plan(
    output_root: Path,
    selected: list[dict[str, Any]],
    alias_plans: list[dict[str, Any]],
) -> dict[str, Any]:
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
    need(
        [str(row["identity"]) for row in selected] == [str(plan["identity"]) for plan in alias_plans],
        "Output and alias plans do not cover the same ordered DEV6 identities",
    )
    output_plan = validate_new_paths(leaves)
    output_plan["sourceReadPathKind"] = "PER_CASE_Q_SLOT_ALIAS"
    output_plan["aliasInputLeafCount"] = 2 * len(alias_plans)
    output_plan["allCanonicalAndAliasInputsPrevalidated"] = len(alias_plans) == 6
    return output_plan


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
        "schema": "argos_ocv03_o3f12_r10_gate_result_v1",
        "state": "COMPLETE_O3F12_GATE" if passed else "HOLD_O3F12_GATE",
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
        "sourceAliasPlanSha256": SOURCE_ALIAS_PLAN_SHA256,
        "substSha256": SUBST_SHA256,
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
        gate.get("schema") == "argos_ocv03_o3f12_r10_gate_result_v1"
        and gate.get("state") == "COMPLETE_O3F12_GATE"
        and gate.get("stage") == "GATE"
        and gate.get("runnerSha256") == sha256(Path(__file__).resolve())
        and gate.get("baseRunnerSha256") == BASE_RUNNER_SHA256
        and gate.get("r10Sha256") == R10_SHA256
        and gate.get("r9PredecessorSha256") == R9_SHA256
        and gate.get("r8PredecessorSha256") == R8_SHA256
        and gate.get("o3p8Sha256") == O3P8_SHA256
        and gate.get("localGateSourceSha256") == LOCAL_GATE_SHA256
        and gate.get("sourceAliasPlanSha256") == SOURCE_ALIAS_PLAN_SHA256
        and gate.get("substSha256") == SUBST_SHA256
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


def run_aliased_r10_child(
    ordinal: int,
    row: dict[str, Any],
    canonical_fixed: dict[str, Any],
    jobs: Path,
    outputs: Path,
    output_root: Path,
    env: dict[str, str],
    plan: dict[str, Any],
    alias_evidence: dict[str, Any],
) -> tuple[dict[str, Any], Path, Path, subprocess.CompletedProcess[str]]:
    safe_id = str(row["safeId"])
    job = dict(canonical_fixed)
    job["revision"] = f"O3F12_R10_DEV6_{ordinal:04d}"
    job["inputs"] = [
        {
            "identity": f"{safe_id}-{channel}",
            "pairId": safe_id,
            "channel": channel,
            "path": str(plan[key]["aliasPath"]),
            "canonicalPath": str(plan[key]["canonicalPath"]),
            "bytes": int(plan[key]["bytes"]),
            "sha256": str(plan[key]["sha256"]).upper(),
        }
        for channel, key in (("BF", "bf"), ("DF", "df"))
    ]
    job_path = jobs / f"J{ordinal:04d}.json"
    case_root = outputs / f"C{ordinal:04d}"
    with owned_case_alias(plan, alias_evidence):
        write_new(job_path, job)
        child = subprocess.run(
            [str(RUNTIME), "-I", "-B", str(R10), "--run", "--job", str(job_path), "--output-root", str(case_root)],
            capture_output=True,
            text=True,
            timeout=600,
            env=env,
        )
    (output_root / f"C{ordinal:04d}.stdout.txt").write_text(child.stdout, encoding="utf-8", newline="\n")
    (output_root / f"C{ordinal:04d}.stderr.txt").write_text(child.stderr, encoding="utf-8", newline="\n")
    return job, job_path, case_root, child


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
    alias_plans = prevalidate_alias_plans(selected)
    frozen_alias_plan = validate_frozen_alias_plan(alias_plans)
    alias_plan_evidence = alias_plan_projection(alias_plans)
    alias_plan_evidence["frozenPlan"] = frozen_alias_plan
    path_plan = validate_stage_path_plan(output_root, selected, alias_plans)
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
    alias_executions: list[dict[str, Any]] = []
    alias_by_identity = {str(plan["identity"]): plan for plan in alias_plans}
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
        plan = alias_by_identity[identity]
        alias_evidence: dict[str, Any] = {
            "ordinal": ordinal,
            "identity": identity,
            "safeId": safe_id,
            "aliasDrive": ALIAS_DRIVE,
            "slotRoot": str(plan["slotRoot"]),
        }
        alias_executions.append(alias_evidence)
        try:
            need(prior["classification"] == "PINNED_EXECUTABLE", f"DEV6 predecessor is not executable: {identity}")
            job, job_path, case_root, child = run_aliased_r10_child(
                ordinal,
                row,
                canonical_fixed,
                jobs,
                outputs,
                output_root,
                env,
                plan,
                alias_evidence,
            )
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
        except AliasContractError:
            raise
        except Exception as exc:
            error = str(exc)[:1600]
            detailed = {
                "ordinal": ordinal,
                "identity": identity,
                "safeId": safe_id,
                "priorR8State": row["r8State"],
                "baselineState": None,
                "inheritedR9State": None,
                "finalState": "HOLD_O3F12_R10_PROVIDER_ERROR",
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
    alias_lifecycle_complete = len(alias_executions) == 6 and all(
        evidence.get("exactTargetVerified") is True
        and evidence.get("sameFileVerified") is True
        and evidence.get("ownedMappingRemoved") is True
        and evidence.get("verifiedAbsentAfterRemove") is True
        and evidence.get("unrelatedMappingsPreservedAfterRemove") is True
        for evidence in alias_executions
    )
    compact_alias_evidence = {
        "state": (
            "COMPLETE_O3F12_Q_ALIAS_LIFECYCLE"
            if alias_lifecycle_complete
            else "HOLD_O3F12_Q_ALIAS_LIFECYCLE_INCOMPLETE"
        ),
        "aliasDrive": ALIAS_DRIVE,
        "aliasAnchorKind": "CASE_SLOT_ROOT",
        "sourceAliasPlanSha256": SOURCE_ALIAS_PLAN_SHA256,
        "frozenPlanExactOrderedMatch": frozen_alias_plan["exactOrderedPlansMatched"],
        "prevalidatedCaseCount": len(alias_plans),
        "executedCaseCount": len(alias_executions),
        "allMappingsRemovedAndVerifiedAbsent": alias_lifecycle_complete,
        "cases": [
            {
                "ordinal": evidence["ordinal"],
                "identity": evidence["identity"],
                "exactTargetVerified": evidence.get("exactTargetVerified") is True,
                "sameFileVerified": evidence.get("sameFileVerified") is True,
                "ownedMappingRemoved": evidence.get("ownedMappingRemoved") is True,
                "verifiedAbsentAfterRemove": evidence.get("verifiedAbsentAfterRemove") is True,
            }
            for evidence in alias_executions
        ],
    }
    clean_completion = (
        len(results) == 6
        and executed_count == 6
        and new_hold_count == 0
        and alias_lifecycle_complete
    )
    summary = {
        "schema": "argos_ocv03_o3f12_r10_dev6_result_v1",
        "state": "COMPLETE_O3F12_DEV6" if clean_completion else "HOLD_O3F12_DEV6_EXECUTION",
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
        "sourceAliasPlanSha256": SOURCE_ALIAS_PLAN_SHA256,
        "substSha256": SUBST_SHA256,
        "r6Sha256": R6_SHA256,
        "topologySha256": TOPOLOGY_SHA256,
        "runtimeSha256": RUNTIME_SHA256,
        "sourceResultsSha256": RESULTS_SHA256,
        "reviewOrderSha256": REVIEW_SHA256,
        "prerequisite": prerequisite,
        "pathPlan": path_plan,
        "aliasPlan": alias_plan_evidence,
        "aliasExecutions": alias_executions,
        "aliasEvidence": compact_alias_evidence,
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
        "aliasEvidence": compact_alias_evidence,
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
        print('{"state":"PASS_O3F12_STAGED_PREFLIGHT","mutationsPerformed":false}')
        return 0
    need(args.output_root, "--output-root is required")
    if args.stage == "GATE":
        need(not args.prerequisite_summary and not args.prerequisite_sha256, "GATE accepts no prerequisite")
        result = run_gate(Path(args.output_root))
        print(json.dumps(result, separators=(",", ":")))
        return 0 if result["state"] == "COMPLETE_O3F12_GATE" else 2
    result = run_dev6(
        Path(args.output_root),
        None if not args.prerequisite_summary else Path(args.prerequisite_summary),
        args.prerequisite_sha256,
    )
    print(json.dumps(result, separators=(",", ":")))
    return 0 if result["state"] == "COMPLETE_O3F12_DEV6" else 2


if __name__ == "__main__":
    raise SystemExit(main())
