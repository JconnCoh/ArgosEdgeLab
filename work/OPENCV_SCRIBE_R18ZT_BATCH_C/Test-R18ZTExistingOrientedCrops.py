#!/usr/bin/env python3
"""Non-image tests for the R18ZT existing-oriented-crop batch runner."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from typing import Any
from unittest import mock


HERE = Path(__file__).resolve().parent
RUNNER_PATH = HERE / "Run-R18ZTExistingOrientedCrops.py"


def load_runner() -> Any:
    spec = importlib.util.spec_from_file_location("r18zt_batch_runner_tested", RUNNER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(RUNNER_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


RUNNER = load_runner()
FAKE_PROVIDER_REVISION = "FAKE_R18ZT_PUBLIC_PROVIDER_NON_IMAGE_TEST_V1"


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


FAKE_PROVIDER_SOURCE = r'''from __future__ import annotations
import hashlib
import json
from types import SimpleNamespace

REVISION = "FAKE_R18ZT_PUBLIC_PROVIDER_NON_IMAGE_TEST_V1"
CALL_COUNT = 0

def _sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

class FakeR11:
    def __init__(self):
        self.identity = ""
        self.evaluation_index = 0

    def evaluate_detector_input(self, _view):
        index = self.evaluation_index
        self.evaluation_index += 1
        if self.identity.endswith("_Slot08") and index == 7:
            raise ValueError("synthetic rejected eighth view")
        return {
            "selectionScore": 0.9,
            "imageFirstString": "13HFX135SUE3",
            "proposedString": "13HFX135SUE3",
            "ocrEnvelope": {"decision": "PASS_TEST", "heldPositions": []},
        }

    def analyze_images(self, job):
        self.identity = job["identity"]["physicalIdentity"]
        self.evaluation_index = 0
        hypotheses = []
        for channel in ("BF", "DF"):
            for polarity in ("DARK", "BRIGHT"):
                for direction in ("FORWARD", "REVERSE_180"):
                    try:
                        evaluated = self.evaluate_detector_input(None)
                    except ValueError:
                        continue
                    hypotheses.append({
                        "channel": channel,
                        "polarity": polarity,
                        "direction": direction,
                        **evaluated,
                    })
        return {
            "schema": "fake_argos_opencv_scribe_result_v1",
            "revision": REVISION,
            "jobId": job["jobId"],
            "state": "SCRIBE_UNCALIBRATED_CONFIDENCE_HOLD",
            "eligibleIdentity": False,
            "imageFirstString": "13HFX135SUE3",
            "proposedString": "13HFX135SUE3",
            "hypotheses": hypotheses,
            "selectedHypothesis": hypotheses[0],
            "holds": [{"code": "SCRIBE_UNCALIBRATED_CONFIDENCE_HOLD"}],
            "authority": {
                "reviewOnly": True,
                "automaticIdentityAuthority": False,
                "trainingEligible": False,
                "xmlEligible": False,
                "productionEligible": False,
                "mayClearHolds": False,
            },
        }

R11_INSTANCE = FakeR11()
R11_INSTANCE.__file__ = __file__
R17D = SimpleNamespace(
    R17C=SimpleNamespace(
        R17B=SimpleNamespace(_load_r11=lambda: R11_INSTANCE)
    )
)

def run_job(job_path, result_path):
    global CALL_COUNT
    CALL_COUNT += 1
    job = json.loads(job_path.read_text(encoding="utf-8"))
    result = R17D.R17C.R17B._load_r11().analyze_images(job)
    if job["identity"]["slotId"] == "Slot10":
        raise RuntimeError("synthetic provider failure after public run_job entry")
    if job["identity"]["slotId"] == "Slot09":
        result["hypotheses"].pop()
    sources = {
        channel: {"sha256": job["inputs"][channel]["sha256"]}
        for channel in ("bf", "df")
    }
    sources["jobSha256"] = _sha(job_path)
    result["provenance"] = {
        "sources": sources,
        "runtimeExpectedTruthUsedForGlyphSelection": False,
        "checksumMaySelectHypothesis": False,
        "checksumMayRewriteGlyphs": False,
    }
    result["fakePublicRunOrdinal"] = CALL_COUNT
    with result_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    return 0
'''


class R18ZTBatchRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.original_maximum_effective_path = RUNNER.MAXIMUM_EFFECTIVE_PATH
        RUNNER.MAXIMUM_EFFECTIVE_PATH = 1000
        self.temporary = tempfile.TemporaryDirectory(prefix="_r18zt_batch_test_", dir=HERE)
        self.root = Path(self.temporary.name)
        self.proposals = self.root / "proposals"
        self.proposals.mkdir()
        self.proposal_alias = self.root / "p"
        junction = subprocess.run(
            ["cmd.exe", "/d", "/c", "mklink", "/J", str(self.proposal_alias), str(self.proposals)],
            capture_output=True,
            text=True,
            check=False,
        )
        if junction.returncode != 0:
            raise RuntimeError(f"Could not create test junction: {junction.stdout} {junction.stderr}")
        self.provider = self.root / "FakeProvider.py"
        self.provider.write_text(FAKE_PROVIDER_SOURCE, encoding="utf-8")
        self.refs = self.root / "refs"
        (self.refs / "glyphs").mkdir(parents=True)
        (self.refs / "glyphs_v5_confirmed_20260806").mkdir()
        self.reference_files: dict[str, Path] = {}
        for name in ("base", "supplemental", "loo", "crosswalk"):
            path = self.refs / f"{name}.json"
            write_json(path, {"fixture": name})
            self.reference_files[name] = path

    def tearDown(self) -> None:
        try:
            self.temporary.cleanup()
        finally:
            RUNNER.MAXIMUM_EFFECTIVE_PATH = self.original_maximum_effective_path

    def make_case(
        self,
        identity: str,
        *,
        include_summary: bool = True,
        summary_identity: str | None = None,
    ) -> dict[str, str]:
        directory = self.proposals / identity
        scribe = directory / "scribe"
        bf = scribe / "BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        df = scribe / "DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png"
        scribe.mkdir(parents=True)
        bf.write_bytes(("BF NON IMAGE " + identity).encode("ascii"))
        df.write_bytes(("DF NON IMAGE " + identity).encode("ascii"))
        proposal = directory / "SCRIBE_PROPOSAL.json"
        write_json(proposal, {
            "schema": "argos_jbod_scribe_proposal_v1",
            "state": "SCRIBE_IDENTITY_CONFIRMATION_HOLD",
            "readerState": "SCRIBE_M12_CANDIDATES_REQUIRE_EXACT_MES_VERIFICATION",
            "physicalIdentity": identity,
            "bfOrientedReviewPath": str(bf),
            "dfOrientedReviewPath": str(df),
            "eligibleIdentity": True,
        })
        if include_summary:
            write_json(scribe / "multi_channel/MULTI_CHANNEL_READER_SUMMARY.json", {
                "schema": "argos_scribe_multi_channel_polarity_reader_v1",
                "state": "SCRIBE_M12_CANDIDATES_REQUIRE_EXACT_MES_VERIFICATION",
                "acquisitionKey": (summary_identity or identity).upper(),
                "consensusState": "MULTIPLE_IMAGE_SUPPORTED_M12_CANDIDATES",
            })
        return {
            "proposal": sha256_file(proposal),
            "bf": sha256_file(bf),
            "df": sha256_file(df),
        }

    def make_config(self, output_root: Path) -> dict[str, Any]:
        return {
            "schema": RUNNER.CONFIG_SCHEMA,
            "batchId": "R18ZT1_NON_IMAGE_TEST",
            "revision": RUNNER.REVISION,
            "canonicalProposalRoot": str(self.proposals),
            "proposalRoot": str(self.proposal_alias),
            "outputRoot": str(output_root),
            "provider": {
                "path": str(self.provider),
                "sha256": sha256_file(self.provider),
                "revision": FAKE_PROVIDER_REVISION,
                "r11AnalyzerPath": str(self.provider),
                "r11AnalyzerSha256": sha256_file(self.provider),
            },
            "references": {
                "manifestPath": str(self.reference_files["base"]),
                "manifestSha256": sha256_file(self.reference_files["base"]),
                "roots": [
                    {"relativePrefix": "glyphs", "path": str(self.refs / "glyphs")},
                    {
                        "relativePrefix": "glyphs_v5_confirmed_20260806",
                        "path": str(self.refs / "glyphs_v5_confirmed_20260806"),
                    },
                ],
                "supplementalManifestPath": str(self.reference_files["supplemental"]),
                "supplementalManifestSha256": sha256_file(self.reference_files["supplemental"]),
                "r18zExactLineageLooGatePath": str(self.reference_files["loo"]),
                "r18zExactLineageLooGateSha256": sha256_file(self.reference_files["loo"]),
                "exactScribeLineageCrosswalkPath": str(self.reference_files["crosswalk"]),
                "exactScribeLineageCrosswalkSha256": sha256_file(self.reference_files["crosswalk"]),
            },
            "limits": {
                "maximumDirectChildren": 100,
                "maximumIdentityCharacters": 80,
                "maximumJsonBytes": 1024 * 1024,
                "maximumOrientedInputBytes": 1024 * 1024,
                "maximumProviderResultBytes": 1024 * 1024,
            },
            "authority": {
                "reviewOnly": True,
                "automaticIdentityAuthority": False,
                "automaticReferenceAdmissionAuthorized": False,
                "trainingEligible": False,
                "activationAuthorized": False,
                "xmlEligible": False,
                "productionEligible": False,
                "mayClearHolds": False,
                "sourceMutationAllowed": False,
                "automaticRetryAllowed": False,
            },
        }

    def test_non_image_batch_has_atomic_bounded_pointer_contract(self) -> None:
        identities = (
            "62600-001_20260901010101_Slot01",
            "62600-001_20260901010101_Slot02",
        )
        before = {identity: self.make_case(identity) for identity in identities}
        self.make_case("62600-001_20260901010101_Slot03", include_summary=False)
        nested_parent = self.proposals / "NOT_A_DIRECT_CASE"
        nested_parent.mkdir()
        nested = nested_parent / "62600-001_20260901010101_Slot04"
        nested.mkdir()

        output = self.root / "output"
        output.mkdir()
        (output / "WORKER.stdout.log").write_text("", encoding="utf-8")
        (output / "WORKER.stderr.log").write_text("", encoding="utf-8")
        write_json(output / "LAUNCH.json", {"state": "PASS_TEST_LAUNCH"})
        complete = RUNNER.execute_batch(
            self.make_config(output),
            output,
            require_d_drive=False,
        )

        self.assertEqual(complete["state"], "COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY")
        self.assertEqual(complete["qualifiedCaseCount"], 2)
        self.assertEqual(complete["completedCount"], 2)
        self.assertEqual(complete["providerRunCount"], 2)
        self.assertEqual(complete["providerInvocationAttemptCount"], 2)
        self.assertEqual(complete["providerRunJobEnteredCount"], 2)
        self.assertEqual(complete["providerRunJobReturnedCount"], 2)
        self.assertEqual(complete["comparableResultCount"], 2)
        self.assertFalse((output / "FAILURE.json").exists())
        status = json.loads((output / "STATUS.json").read_text(encoding="utf-8"))
        running = json.loads((output / "RUNNING.json").read_text(encoding="utf-8"))
        terminal = json.loads((output / "COMPLETE.json").read_text(encoding="utf-8"))
        self.assertEqual(status["state"], "COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY")
        self.assertEqual(running["state"], status["state"])
        self.assertEqual(running["schema"], RUNNER.PROGRESS_SCHEMA)
        self.assertEqual(terminal["aggregate"]["sha256"], sha256_file(Path(terminal["aggregate"]["path"])))
        self.assertEqual(terminal["caseIndex"]["sha256"], sha256_file(Path(terminal["caseIndex"]["path"])))
        self.assertLess((output / "STATUS.json").stat().st_size, 16384)
        self.assertLess((output / "RUNNING.json").stat().st_size, 16384)

        inventory = json.loads((output / "INVENTORY.json").read_text(encoding="utf-8"))
        self.assertEqual(inventory["directChildCount"], 4)
        self.assertEqual(inventory["qualifiedCaseCount"], 2)
        self.assertEqual(inventory["inventoryHoldCount"], 2)
        self.assertFalse(inventory["recursiveEnumerationPerformed"])
        index = json.loads((output / "CASE_INDEX.json").read_text(encoding="utf-8"))
        self.assertEqual(len(index["rows"]), 2)
        for row in index["rows"]:
            self.assertEqual(row["providerRunCount"], 1)
            self.assertEqual(row["providerInvocationAttemptCount"], 1)
            self.assertEqual(row["providerRunJobEnteredCount"], 1)
            self.assertEqual(row["providerRunJobReturnedCount"], 1)
            self.assertTrue(row["providerResultComparable"])
            case_result = json.loads(Path(row["caseResultPath"]).read_text(encoding="utf-8"))
            self.assertTrue(case_result["allEightNormalHypothesesAttempted"])
            self.assertFalse(case_result["identityAccepted"])
            audit = case_result["normalHypothesisAttemptAudit"]
            self.assertTrue(audit["loaderRestored"])
            self.assertTrue(audit["analyzeImagesRestored"])
            self.assertTrue(audit["evaluateDetectorInputRestored"])
            self.assertTrue(audit["hypothesisOrderBoundToFrozenAnalyzerSource"])
            for source in case_result["sourcePins"].values():
                self.assertEqual(source["executionSha256"], source["canonicalSha256"])
                self.assertTrue(source["canonicalAndExecutionAreSameFile"])
                self.assertLess(
                    source["executionPathBudget"]["effectiveCharacters"],
                    RUNNER.MAXIMUM_EFFECTIVE_PATH,
                )
            job_text = Path(case_result["job"]["path"]).read_text(encoding="utf-8")
            self.assertNotIn("expectedTruth", job_text)
            self.assertNotIn("checksumMaySelect", job_text)

        for identity in identities:
            directory = self.proposals / identity
            self.assertEqual(before[identity]["proposal"], sha256_file(directory / "SCRIBE_PROPOSAL.json"))
            self.assertEqual(before[identity]["bf"], sha256_file(directory / RUNNER.BF_RELATIVE))
            self.assertEqual(before[identity]["df"], sha256_file(directory / RUNNER.DF_RELATIVE))

    def test_rejected_view_is_still_a_comparable_eight_attempt_run(self) -> None:
        self.make_case("62600-001_20260901010101_Slot08")
        output = self.root / "output"
        output.mkdir()
        complete = RUNNER.execute_batch(
            self.make_config(output),
            output,
            require_d_drive=False,
        )
        self.assertEqual(complete["comparableResultCount"], 1)
        index = json.loads((output / "CASE_INDEX.json").read_text(encoding="utf-8"))
        row = index["rows"][0]
        self.assertTrue(row["providerResultComparable"])
        result = json.loads(Path(row["providerResultPath"]).read_text(encoding="utf-8"))
        self.assertEqual(len(result["normalHypothesisAttempts"]), 8)
        self.assertEqual(len(result["hypotheses"]), 7)
        self.assertEqual(
            sum(item["state"] == "HOLD_EVALUATION_REJECTED" for item in result["normalHypothesisAttempts"]),
            1,
        )

    def test_retained_evaluated_mismatch_is_noncomparable_hold(self) -> None:
        self.make_case("62600-001_20260901010101_Slot09")
        output = self.root / "output"
        output.mkdir()
        complete = RUNNER.execute_batch(
            self.make_config(output),
            output,
            require_d_drive=False,
        )
        self.assertEqual(complete["completedCount"], 1)
        self.assertEqual(complete["comparableResultCount"], 0)
        self.assertEqual(complete["noncomparableOrFailedCount"], 1)
        index = json.loads((output / "CASE_INDEX.json").read_text(encoding="utf-8"))
        row = index["rows"][0]
        self.assertEqual(row["providerRunCount"], 1)
        self.assertEqual(row["state"], "HOLD_R18ZT_PROVIDER_RESULT_NOT_COMPARABLE")
        case_result = json.loads(Path(row["caseResultPath"]).read_text(encoding="utf-8"))
        self.assertIn("RETAINED_HYPOTHESES_DO_NOT_MATCH_EVALUATED_ATTEMPTS", case_result["comparisonFailures"])
        self.assertTrue(case_result["allEightNormalHypothesesAttempted"])

    def test_pre_call_seam_failure_does_not_claim_run_job_entry(self) -> None:
        self.make_case("62600-001_20260901010101_Slot11")
        self.provider.write_text(
            FAKE_PROVIDER_SOURCE + "\nR17D = SimpleNamespace()\n", encoding="utf-8"
        )
        output = self.root / "output"
        output.mkdir()
        complete = RUNNER.execute_batch(
            self.make_config(output),
            output,
            require_d_drive=False,
        )
        self.assertEqual(complete["providerInvocationAttemptCount"], 1)
        self.assertEqual(complete["providerRunJobEnteredCount"], 0)
        self.assertEqual(complete["providerRunJobReturnedCount"], 0)
        self.assertEqual(complete["providerRunCount"], 0)
        index = json.loads((output / "CASE_INDEX.json").read_text(encoding="utf-8"))
        row = index["rows"][0]
        self.assertEqual(row["state"], "HOLD_R18ZT_PUBLIC_PROVIDER_RUN_FAILED_NO_RETRY")
        self.assertEqual(row["providerInvocationAttemptCount"], 1)
        self.assertEqual(row["providerRunJobEnteredCount"], 0)

    def test_entered_provider_failure_records_entry_and_restoration(self) -> None:
        self.make_case("62600-001_20260901010101_Slot10")
        output = self.root / "output"
        output.mkdir()
        complete = RUNNER.execute_batch(
            self.make_config(output),
            output,
            require_d_drive=False,
        )
        self.assertEqual(complete["providerInvocationAttemptCount"], 1)
        self.assertEqual(complete["providerRunJobEnteredCount"], 1)
        self.assertEqual(complete["providerRunJobReturnedCount"], 0)
        index = json.loads((output / "CASE_INDEX.json").read_text(encoding="utf-8"))
        case_result = json.loads(Path(index["rows"][0]["caseResultPath"]).read_text(encoding="utf-8"))
        audit = case_result["normalHypothesisAttemptAudit"]
        self.assertEqual(audit["attemptCount"], 8)
        self.assertEqual(audit["providerRunJobEnteredCount"], 1)
        self.assertEqual(audit["providerRunJobReturnedCount"], 0)
        self.assertTrue(audit["loaderRestored"])
        self.assertTrue(audit["analyzeImagesRestored"])
        self.assertTrue(audit["evaluateDetectorInputRestored"])

    def test_live_output_must_be_d_drive_and_envelope_root_must_be_fresh(self) -> None:
        live_worst_case_leaf = (
            Path(r"D:\A2\w\ocv\R18ZT1\p")
            / ("X" * 80)
            / RUNNER.SUMMARY_RELATIVE
        )
        saved_path_limit = RUNNER.MAXIMUM_EFFECTIVE_PATH
        RUNNER.MAXIMUM_EFFECTIVE_PATH = 200
        try:
            live_path_budget = RUNNER.assert_execution_path_budget(
                live_worst_case_leaf,
                "live worst-case proposal summary",
            )
        finally:
            RUNNER.MAXIMUM_EFFECTIVE_PATH = saved_path_limit
        self.assertLess(live_path_budget["effectiveCharacters"], 200)
        canonical_worst_case_leaf = (
            Path(r"C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals")
            / ("X" * 80)
            / RUNNER.SUMMARY_RELATIVE
        )
        self.assertGreaterEqual(len(str(canonical_worst_case_leaf)), 200)
        self.assertGreaterEqual(
            len(str(canonical_worst_case_leaf)) + RUNNER.PATH_SUFFIX_RESERVE,
            200,
        )

        self.make_case("62600-001_20260901010101_Slot01")
        output = self.root / "output"
        output.mkdir()
        config = self.make_config(output)
        with self.assertRaisesRegex(ValueError, "must be on D"):
            RUNNER.validate_configuration(
                config,
                output,
                require_d_drive=True,
            )
        regular_root_config = self.make_config(output)
        regular_root_config["proposalRoot"] = str(self.proposals)
        with self.assertRaisesRegex(ValueError, "path-safe junction"):
            RUNNER.validate_configuration(
                regular_root_config,
                output,
                require_d_drive=False,
                require_proposal_alias=True,
            )
        (output / "unexpected.txt").write_text("not allowed", encoding="utf-8")
        with self.assertRaisesRegex(FileExistsError, "Unexpected pre-existing"):
            RUNNER.execute_batch(
                config,
                output,
                require_d_drive=False,
            )

    def test_canonical_leaf_paths_are_lexical_provenance_only(self) -> None:
        identity = "62600-001_20260901010101_Slot01"
        self.make_case(identity)
        output = self.root / "output"
        output.mkdir()
        canonical_root = os.path.normcase(os.path.abspath(str(self.proposals)))

        def canonical_leaf(value: object) -> bool:
            candidate = os.path.normcase(os.path.abspath(os.path.normpath(str(value))))
            return candidate.startswith(canonical_root + os.sep)

        path_class = type(self.proposals)
        original_methods = {
            name: getattr(path_class, name)
            for name in (
                "exists", "is_file", "is_dir", "is_symlink", "stat", "lstat",
                "open", "read_text", "read_bytes", "samefile", "resolve",
            )
        }

        def guarded_method(name: str):
            original = original_methods[name]

            def invoke(path: Path, *args: object, **kwargs: object):
                if canonical_leaf(path):
                    raise AssertionError(f"canonical leaf filesystem I/O attempted through {name}: {path}")
                return original(path, *args, **kwargs)

            return invoke

        original_samefile = os.path.samefile

        def guarded_samefile(first: object, second: object) -> bool:
            if canonical_leaf(first) or canonical_leaf(second):
                raise AssertionError("canonical leaf filesystem I/O attempted through os.path.samefile")
            return original_samefile(first, second)

        with ExitStack() as stack:
            for name in original_methods:
                stack.enter_context(mock.patch.object(path_class, name, guarded_method(name)))
            stack.enter_context(mock.patch.object(os.path, "samefile", guarded_samefile))
            complete = RUNNER.execute_batch(
                self.make_config(output),
                output,
                require_d_drive=False,
            )

        self.assertEqual(complete["completedCount"], 1)
        case_index = json.loads((output / "CASE_INDEX.json").read_text(encoding="utf-8"))
        case_result = json.loads(
            Path(case_index["rows"][0]["caseResultPath"]).read_text(encoding="utf-8")
        )
        for source in case_result["sourcePins"].values():
            self.assertTrue(source["canonicalProvenanceLexicalOnly"])
            self.assertFalse(source["canonicalLeafFilesystemIoPerformed"])
            self.assertEqual(
                source["canonicalBindingBasis"],
                "VERIFIED_ROOT_JUNCTION_TARGET_AND_EXACT_RELATIVE_MAPPING",
            )

    def test_nested_alias_side_reparse_ancestors_are_held(self) -> None:
        scribe_identity = "62600-001_20260901010101_Slot05"
        channel_identity = "62600-001_20260901010101_Slot06"
        self.make_case(scribe_identity)
        self.make_case(channel_identity)

        replacements = (
            (
                self.proposals / scribe_identity / "scribe",
                self.root / "outside_scribe",
            ),
            (
                self.proposals / channel_identity / "scribe" / "multi_channel",
                self.root / "outside_multi_channel",
            ),
        )
        for original, target in replacements:
            shutil.move(str(original), str(target))
            junction = subprocess.run(
                ["cmd.exe", "/d", "/c", "mklink", "/J", str(original), str(target)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(junction.returncode, 0, junction.stdout + junction.stderr)

        output = self.root / "output"
        output.mkdir()
        config = self.make_config(output)
        context = RUNNER.validate_configuration(
            config,
            output,
            require_d_drive=False,
        )
        inventory = RUNNER.inventory_cases(config, context)

        self.assertEqual(inventory["qualifiedCaseCount"], 0)
        self.assertEqual(inventory["inventoryHoldCount"], 2)
        self.assertEqual(
            {row["physicalIdentity"] for row in inventory["holds"]},
            {scribe_identity, channel_identity},
        )
        for hold in inventory["holds"]:
            self.assertEqual(
                hold["state"],
                "HOLD_INSTALLED_ORIENTED_INPUT_QUALIFICATION_FAILED",
            )
            self.assertIn("reparse component below the root alias", hold["detail"])

    def test_runner_has_no_direct_structural_or_image_execution_path(self) -> None:
        source = RUNNER_PATH.read_text(encoding="utf-8")
        self.assertNotIn("evaluate_detector_input_structural(", source)
        self.assertNotIn("import cv2", source)
        self.assertNotIn("os.walk(", source)
        self.assertNotIn(".rglob(", source)
        self.assertNotIn("subprocess", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
