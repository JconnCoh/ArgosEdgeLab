#!/usr/bin/env python3
"""Focused, image-free O3F15L4 lexical-path and Q: lifecycle regression suite."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path, PureWindowsPath
import sys
import unittest
from typing import Any


HERE = Path(__file__).resolve().parent
RUNNER_PATH = HERE / "Run-O3F15L4FrontReconcile.py"


def dependency_path(name: str) -> Path:
    flat = HERE / name
    repository = HERE.parent / "O3F8" / name
    return flat if flat.is_file() else repository


R11_PATH = dependency_path("FullPerimeterWaferTopologyOpenCvR11.py")
R11_SHA256 = "B477C290EC9D3AE388BE4EE31049B2B8094F5F30FC6E0DD68AB4A03926EE4059"
SLOT19_IDENTITY = r"BackSide_BowComp\Lot_62627-198-POST-IVS\62627-198-POST-IVS_20260730103451\Slot19|FRONT"
SLOT19_BF = r"D:\KLARFExport\BackSide_BowComp\Lot_62627-198-POST-IVS\62627-198-POST-IVS_20260730103451\Slot19\BrightfieldFrontsideWafer\resizedImage\62627-198-POST-IVS_Slot19_BrightfieldFrontsideWafer_PM2_resizedImage.bmp"
SLOT19_ALIAS = r"Q:\BrightfieldFrontsideWafer\resizedImage\62627-198-POST-IVS_Slot19_BrightfieldFrontsideWafer_PM2_resizedImage.bmp"


def load_runner() -> Any:
    spec = importlib.util.spec_from_file_location("argos_o3f15l4_focused", RUNNER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("Cannot load O3F15L4 runner")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


L4 = load_runner()


def source(path: str, ordinal: int) -> dict[str, Any]:
    return {"path": path, "bytes": 1000 + ordinal, "sha256": f"{ordinal + 1:064X}"[-64:]}


def ordinary_row(ordinal: int, current: bool) -> dict[str, Any]:
    family = "PatternedFront" if current else "BackSide_BowComp"
    anchor = rf"{family}\Lot{ordinal:04d}\Scan{ordinal:04d}\Slot{ordinal % 25 + 1:02d}"
    identity = anchor + "|FRONT"
    slot = PureWindowsPath(r"D:\KLARFExport") / PureWindowsPath(anchor)
    bf = slot / "BrightfieldFrontsideWafer" / "resizedImage" / f"W{ordinal:04d}_BF.bmp"
    df = slot / "DarkfieldFrontsideWafer" / "resizedImage" / f"W{ordinal:04d}_DF.bmp"
    return {"identity": identity, "safeId": f"S{ordinal:04d}", "bf": source(str(bf), ordinal * 2), "df": source(str(df), ordinal * 2 + 1)}


def slot19_row() -> dict[str, Any]:
    slot = PureWindowsPath(SLOT19_BF).parent.parent.parent
    df = slot / "DarkfieldFrontsideWafer" / "resizedImage" / "62627-198-POST-IVS_Slot19_DarkfieldFrontsideWafer_PM2_resizedImage.bmp"
    return {"identity": SLOT19_IDENTITY, "safeId": "SLOT19", "bf": source(SLOT19_BF, 8001), "df": source(str(df), 8002)}


def full978() -> list[dict[str, Any]]:
    rows = [ordinary_row(i, i <= 265) for i in range(1, 979)]
    rows[265] = slot19_row()
    return rows


def path_with_raw_length(drive: str, length: int) -> str:
    prefix = drive + "\\"
    remaining = length - len(prefix)
    if remaining < 1:
        raise ValueError("requested path is too short")
    parts: list[str] = []
    while remaining > 80:
        take = min(60, remaining - 2)
        parts.append("x" * take)
        remaining -= take + 1
    parts.append("y" * remaining)
    value = prefix + "\\".join(parts)
    if len(value) != length:
        raise AssertionError((length, len(value), value))
    return value


class ForbiddenFilesystemPath:
    def __init__(self, *_args: Any, **_kwargs: Any) -> None:
        raise AssertionError("generalized planning attempted to construct a filesystem Path")


class FakeO3F14:
    def __init__(self, *, initial: dict[str, str] | None = None, logical_collision: bool = False, wrong_create_target: bool = False, fail_remove: bool = False) -> None:
        self.mappings = dict(initial or {"P:": r"D:\Preserved"})
        self.logical_collision = logical_collision
        self.wrong_create_target = wrong_create_target
        self.fail_remove = fail_remove
        self.query_count = 0
        self.actions: list[tuple[list[str], str]] = []

    def query_all_subst_mappings(self) -> tuple[dict[str, str], dict[str, Any]]:
        self.query_count += 1
        return dict(self.mappings), {"mappingCount": len(self.mappings), "mappedDrives": sorted(self.mappings)}

    def logical_drive_present(self, drive: str) -> bool:
        return drive in self.mappings or (drive == "Q:" and self.logical_collision)

    def subst_action(self, arguments: list[str], label: str) -> dict[str, Any]:
        self.actions.append((list(arguments), label))
        if arguments == ["Q:", "/D"]:
            if self.fail_remove:
                raise L4.L4AliasContractError("injected cleanup failure")
            self.mappings.pop("Q:", None)
        else:
            self.mappings["Q:"] = r"D:\WrongSlot" if self.wrong_create_target else arguments[1]
        return {"returnCode": 0, "stdoutBytes": 0}


class O3F15L4FocusedTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        rows = full978()
        original_path = L4.Path
        L4.Path = ForbiddenFilesystemPath
        try:
            cls.plans = L4.generalized_alias_plans(rows)
        finally:
            L4.Path = original_path
        cls.slot_plan = cls.plans[265]

    def probe(self, plan: dict[str, Any], seen: list[str] | None = None, missing: str | None = None, mismatch: str | None = None):
        by_path = {str(plan[key]["aliasPath"]): int(plan[key]["bytes"]) for key in ("bf", "df")}

        def inner(path: str) -> int | None:
            if seen is not None:
                seen.append(path)
            if path == missing:
                return None
            value = by_path[path]
            return value + 1 if path == mismatch else value

        return inner

    def test_exact_slot19_and_boundaries(self) -> None:
        bf = self.slot_plan["bf"]
        self.assertEqual(bf["canonicalPath"], SLOT19_BF)
        self.assertEqual(bf["aliasPath"], SLOT19_ALIAS)
        self.assertEqual((bf["canonicalClassification"]["rawPathLength"], bf["canonicalClassification"]["effectivePathLength"]), (207, 239))
        self.assertEqual((bf["aliasBudget"]["rawPathLength"], bf["aliasBudget"]["effectivePathLength"]), (114, 146))
        self.assertFalse(bf["canonicalClassification"]["directUseAllowed"])
        self.assertTrue(bf["canonicalClassification"]["directUseHardStop"])
        expected = {
            199: ("DIRECT_SAFE", True, False, False),
            200: ("VERIFIED_SHORT_ALIAS_REQUIRED", False, True, False),
            229: ("VERIFIED_SHORT_ALIAS_REQUIRED", False, True, False),
            230: ("DIRECT_USE_HARD_STOP_ALIAS_ONLY", False, True, True),
        }
        for effective, projection in expected.items():
            result = L4.classify_canonical(path_with_raw_length("D:", effective - 32))
            self.assertEqual((result["classification"], result["directUseAllowed"], result["verifiedShortAliasRequired"], result["directUseHardStop"]), projection)
            self.assertFalse(result["filesystemTouchAllowedByL4"])

    def test_alias_boundaries_and_pre_subst_slot_rejection(self) -> None:
        self.assertEqual(L4.require_short_path(path_with_raw_length("Q:", 167), "alias")["effectivePathLength"], 199)
        with self.assertRaises(L4.L4AliasContractError):
            L4.require_short_path(path_with_raw_length("Q:", 168), "alias")
        unsafe = copy.deepcopy(self.slot_plan)
        unsafe["slotRoot"] = path_with_raw_length("D:", 168)
        fake = FakeO3F14()
        with self.assertRaises(L4.L4AliasContractError):
            with L4.owned_case_alias(unsafe, {}, fake, self.probe(unsafe)):
                self.fail("unsafe slot root yielded")
        self.assertEqual((fake.query_count, fake.actions), (0, []))

    def test_exact_mapping_alias_only_metadata_and_cleanup(self) -> None:
        fake = FakeO3F14()
        evidence: dict[str, Any] = {}
        seen: list[str] = []
        child_count = 0
        with L4.owned_case_alias(self.slot_plan, evidence, fake, self.probe(self.slot_plan, seen)):
            child_count += 1
            self.assertEqual(L4.normalized_windows_path(fake.mappings["Q:"]), L4.normalized_windows_path(self.slot_plan["slotRoot"]))
        self.assertEqual(child_count, 1)
        self.assertEqual(set(seen), {self.slot_plan["bf"]["aliasPath"], self.slot_plan["df"]["aliasPath"]})
        self.assertTrue(all(PureWindowsPath(path).drive.upper() == "Q:" for path in seen))
        self.assertNotIn("Q:", fake.mappings)
        self.assertEqual(fake.mappings, {"P:": r"D:\Preserved"})
        for key in ("exactTargetVerified", "lexicalSuffixVerified", "aliasOnlyMetadataVerified", "ownedMappingRemoved", "verifiedAbsentAfterRemove", "unrelatedMappingsPreservedAfterRemove"):
            self.assertTrue(evidence[key])

    def test_collision_wrong_mapping_missing_and_size_mismatch_never_yield(self) -> None:
        scenarios = [
            (FakeO3F14(initial={"Q:": r"D:\Occupied"}), self.probe(self.slot_plan)),
            (FakeO3F14(logical_collision=True), self.probe(self.slot_plan)),
            (FakeO3F14(wrong_create_target=True), self.probe(self.slot_plan)),
            (FakeO3F14(), self.probe(self.slot_plan, missing=self.slot_plan["bf"]["aliasPath"])),
            (FakeO3F14(), self.probe(self.slot_plan, mismatch=self.slot_plan["df"]["aliasPath"])),
        ]
        for fake, probe in scenarios:
            child_count = 0
            with self.assertRaises(L4.L4AliasContractError):
                with L4.owned_case_alias(self.slot_plan, {}, fake, probe):
                    child_count += 1
            self.assertEqual(child_count, 0)

    def test_cleanup_on_body_failure_and_injected_cleanup_failure(self) -> None:
        fake = FakeO3F14()
        with self.assertRaisesRegex(RuntimeError, "injected body failure"):
            with L4.owned_case_alias(self.slot_plan, {}, fake, self.probe(self.slot_plan)):
                raise RuntimeError("injected body failure")
        self.assertNotIn("Q:", fake.mappings)
        self.assertEqual(fake.actions[-1][0], ["Q:", "/D"])

        cleanup = FakeO3F14(fail_remove=True)
        evidence: dict[str, Any] = {}
        yielded = 0
        with self.assertRaisesRegex(L4.L4AliasContractError, "injected cleanup failure"):
            with L4.owned_case_alias(self.slot_plan, evidence, cleanup, self.probe(self.slot_plan)):
                yielded += 1
        self.assertEqual(yielded, 1)
        self.assertEqual(cleanup.actions[-1][0], ["Q:", "/D"])
        self.assertIn("injected cleanup failure", evidence["cleanupError"])

    def test_canonical_never_enters_filesystem_api_child_or_job(self) -> None:
        runner_text = RUNNER_PATH.read_text(encoding="utf-8")
        for forbidden in ("canonical.is_file", "canonical.stat", "canonical.resolve", "canonical.open", "samefile(", "sha256(canonical"):
            self.assertNotIn(forbidden, runner_text)
        inputs = L4.alias_only_job_inputs(self.slot_plan, "SLOT19")
        self.assertEqual(len(inputs), 2)
        self.assertTrue(all("canonicalPath" not in row and PureWindowsPath(row["path"]).drive.upper() == "Q:" for row in inputs))
        self.assertNotIn(SLOT19_BF, json.dumps(inputs))
        self.assertLess(runner_text.index("flat = HERE / name"), runner_text.index("repository = HERE.parent / \"O3F8\" / name"))
        self.assertEqual(L4.FOCUSED_TEST, RUNNER_PATH.with_name("Test-O3F15L4PathHolds.py"))
        self.assertEqual((str(L4.GATE_ROOT), str(L4.RUN_ROOT), str(L4.MIRROR_ROOT)), (r"D:\O3F15L4G", r"D:\O3F15L4C", r"D:\KLARFExport\_ArgosReview\F15L4S"))
        for required in ("frozen.__file__ = str(RUNNER_PATH)", "FOCUSED_TEST_SHA256", "PASS_O3F15L4_FOCUSED_IMAGE_FREE", "COMPLETE_O3F15L4_GATE", "runnerSha256"):
            self.assertIn(required, runner_text)
        for recovery in ("recovery_errors", "TimeoutExpired", "MANIFEST.json.partial", "recovery-log-errors", "R11 job path changed"):
            self.assertIn(recovery, runner_text)
        test_text = Path(__file__).read_text(encoding="utf-8")
        self.assertLess(test_text.index("flat = HERE / name"), test_text.index("repository = HERE.parent / \"O3F8\" / name"))
        self.assertEqual(R11_PATH, (HERE / R11_PATH.name) if (HERE / R11_PATH.name).is_file() else HERE.parent / "O3F8" / R11_PATH.name)
        for envelope in ("PASS_O3F15L4_FRONT_RECONCILE_SELF_TEST", "PASS_O3F15L4_FRONT_RECONCILE_PREFLIGHT"):
            self.assertIn(envelope, runner_text)
        self.assertNotIn("return int(frozen.main())", runner_text)

    def test_full978_complete_and_later_control_scheduled(self) -> None:
        self.assertEqual(len(self.plans), 978)
        self.assertEqual([plan["ordinal"] for plan in self.plans], list(range(1, 979)))
        self.assertEqual(len({plan["identity"] for plan in self.plans}), 978)
        self.assertEqual(self.plans[265]["identity"], SLOT19_IDENTITY)
        self.assertEqual(self.plans[266]["identity"], r"BackSide_BowComp\Lot0267\Scan0267\Slot18|FRONT")
        self.assertEqual(self.plans[266]["ordinal"], 267)

    def test_r11_hash_mismatch_is_before_decode(self) -> None:
        data = R11_PATH.read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest().upper(), R11_SHA256)
        text = data.decode("utf-8")
        hash_at = text.index("actual = sha256_file(path)", text.index("for row in job[\"inputs\"]"))
        mismatch_at = text.index("require(actual == str(row[\"sha256\"]).upper()", hash_at)
        decode_at = text.index("bf_image = cv2.imread", mismatch_at)
        self.assertLess(hash_at, mismatch_at)
        self.assertLess(mismatch_at, decode_at)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output")
    args = parser.parse_args()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(O3F15L4FocusedTests)
    captured = io.StringIO()
    result = unittest.TextTestRunner(stream=captured if args.output else sys.stderr, verbosity=2).run(suite)
    summary = {"schema": "argos_ocv03_o3f15l4_focused_image_free_test_v1", "state": "PASS_O3F15L4_FOCUSED_IMAGE_FREE" if result.wasSuccessful() else "FAIL_O3F15L4_FOCUSED_IMAGE_FREE", "testsRun": result.testsRun, "failures": len(result.failures), "errors": len(result.errors), "plannedPairCount": 978, "complete978LexicalClassification": result.wasSuccessful(), "laterControlScheduled": result.wasSuccessful(), "sourceImageBytesRead": False, "sourceMutation": False, "childProcessLaunched": False, "substExecuted": False}
    if args.output:
        output = Path(args.output)
        partial = output.with_name(output.name + ".partial")
        if not output.parent.is_dir() or output.exists() or partial.exists():
            raise RuntimeError("Focused-test output must be create-new under an existing root")
        partial.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8", newline="\n")
        os.replace(partial, output)
    print(json.dumps(summary, separators=(",", ":")))
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
