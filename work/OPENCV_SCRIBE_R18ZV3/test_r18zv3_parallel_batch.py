#!/usr/bin/env python3
"""Non-image concurrency and equivalence tests for R18ZV3."""

from __future__ import annotations

import importlib.util, json, multiprocessing, os, subprocess, sys, tempfile, time, unittest
from unittest import mock
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent; REPO = HERE.parents[1]
BASE_DIR = HERE.parent / "OPENCV_SCRIBE_R18ZT_BATCH_C"; RUNNER_PATH = BASE_DIR / "Run-R18ZTExistingOrientedCropsV2.py"
BASE_TEST_PATH = BASE_DIR / "Test-R18ZTExistingOrientedCropsV2.py"; COORDINATOR_PATH = HERE / "r18zv3_parallel_batch.py"
ENVELOPE_PATH = HERE.parent / "OPENCV_SCRIBE_R18ZU_BATCH_PACKAGE_A" / "Run-R18ZUBatchExecutionEnvelopeV1.py"


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


BASE_TEST = load("r18zv3_base_test_support", BASE_TEST_PATH)
COORDINATOR = load("argos_r18zt_batch_delegate_spawn_test", COORDINATOR_PATH)
ENVELOPE = load("r18zv3_frozen_envelope_contract", ENVELOPE_PATH)


class Fixture:
    make_case = BASE_TEST.R18ZTBatchRunnerTests.make_case
    make_config = BASE_TEST.R18ZTBatchRunnerTests.make_config

    def __init__(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="_z3_", dir=REPO)
        self.root = Path(self.temporary.name)
        self.proposals = self.root / "q"
        self.proposals.mkdir()
        self.proposal_alias = self.root / "p"
        result = subprocess.run(
            ["cmd.exe", "/d", "/c", "mklink", "/J", str(self.proposal_alias), str(self.proposals)],
            capture_output=True, text=True, check=False,
        )
        if result.returncode:
            raise RuntimeError(result.stderr or result.stdout)
        source = BASE_TEST.FAKE_PROVIDER_SOURCE
        source = source.replace("import hashlib\n", "import hashlib\nimport os\nimport time\n")
        source = source.replace("    CALL_COUNT += 1\n", "    CALL_COUNT += 1\n    _started_ns = time.time_ns()\n    time.sleep(0.15)\n")
        source = source.replace('    if job["identity"]["slotId"] == "Slot10":\n', '    _marker = os.environ.get("R18ZV3_TEST_BLOCK_MARKER", "")\n    if job["identity"]["slotId"] == "Slot12" and _marker:\n        open(_marker, "wb").close()\n        time.sleep(30)\n    if job["identity"]["slotId"] == "Slot11":\n        _deadline = time.time() + 5\n        while not os.path.isfile(_marker):\n            if time.time() >= _deadline: raise RuntimeError("synthetic synchronization failure")\n            time.sleep(0.01)\n        raise SystemExit("synthetic isolated worker death")\n    if job["identity"]["slotId"] == "Slot10":\n')
        source = source.replace('    result["fakePublicRunOrdinal"] = CALL_COUNT\n', '    result["fakePublicRunOrdinal"] = CALL_COUNT\n    result["fakeWorkerPid"] = os.getpid()\n    result["fakeStartedNs"] = _started_ns\n    result["fakeEndedNs"] = time.time_ns()\n')
        self.provider = self.root / "f.py"
        self.provider.write_text(source, encoding="utf-8")
        self.refs = self.root / "r"
        (self.refs / "glyphs").mkdir(parents=True)
        (self.refs / "glyphs_v5_confirmed_20260806").mkdir()
        self.reference_files = {}
        for name in ("base", "supplemental", "loo", "crosswalk"):
            path = self.refs / f"{name}.json"
            BASE_TEST.write_json(path, {"fixture": name})
            self.reference_files[name] = path

    def close(self) -> None:
        if self.proposal_alias.exists():
            os.rmdir(self.proposal_alias)
        self.temporary.cleanup()


def projection(root: Path) -> list[dict[str, Any]]:
    rows = json.loads((root / "CASE_INDEX.json").read_text(encoding="utf-8"))["rows"]
    keys = ("caseId", "physicalIdentity", "state", "providerState", "imageFirstString",
            "selectedHypothesis", "providerResultComparable", "providerInvocationAttemptCount",
            "providerRunJobEnteredCount", "providerRunJobReturnedCount", "providerRunCount", "automaticRetryPerformed")
    return [{key: row[key] for key in keys} for row in rows]


class ParallelBatchTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = Fixture()

    def tearDown(self) -> None:
        self.fixture.close()

    def test_spawned_parallel_run_matches_serial_and_is_deterministic(self) -> None:
        identities = [f"L_A_Slot{slot:02d}" for slot in (1, 3, 8, 9, 10, 12, 14)]
        for identity in identities:
            self.fixture.make_case(identity)
        source_paths = [path for identity in identities for path in BASE_TEST.RUNNER.expected_case_paths(self.fixture.proposals / identity).values()]
        before = {str(path): BASE_TEST.sha256_file(path) for path in source_paths}
        outputs = [self.fixture.root / name for name in ("s", "a", "b")]
        for output in outputs:
            output.mkdir()
        BASE_TEST.RUNNER.execute_batch(self.fixture.make_config(outputs[0]), outputs[0], require_d_drive=False, require_proposal_alias=True)
        for output in outputs[1:]:
            config = self.fixture.make_config(output)
            COORDINATOR.execute_parallel(config, output, worker_count=2, base_runner_path=RUNNER_PATH,
                                         require_d_drive=False, require_proposal_alias=True)
        config_path = self.fixture.root / "parallel-config.json"
        BASE_TEST.write_json(config_path, self.fixture.make_config(outputs[1]))
        self.assertEqual(ENVELOPE.exact_complete_contract(outputs[1], config_path)[:2], (True, "EXACT_COMPLETE"))
        self.assertEqual(projection(outputs[0]), projection(outputs[1]))
        self.assertEqual(projection(outputs[1]), projection(outputs[2]))
        self.assertEqual([row["physicalIdentity"] for row in projection(outputs[1])], sorted(identities))
        self.assertEqual(before, {str(path): BASE_TEST.sha256_file(path) for path in source_paths})
        rows = json.loads((outputs[1] / "CASE_INDEX.json").read_text(encoding="utf-8"))["rows"]
        self.assertEqual(next(r for r in rows if r["physicalIdentity"].endswith("Slot10"))["state"],
                         "HOLD_R18ZT_PUBLIC_PROVIDER_RUN_FAILED_NO_RETRY")
        self.assertTrue(next(r for r in rows if r["physicalIdentity"].endswith("Slot14"))[
            "providerResultComparable"])
        result_values = [json.loads(Path(row["providerResultPath"]).read_text(encoding="utf-8"))
                         for row in rows if row["providerResultPath"]]
        self.assertGreaterEqual(len({value["fakeWorkerPid"] for value in result_values}), 2)
        intervals = [(value["fakeStartedNs"], value["fakeEndedNs"]) for value in result_values]
        self.assertTrue(any(max(a[0], b[0]) < min(a[1], b[1])
                            for i, a in enumerate(intervals) for b in intervals[i + 1:]))
        for row in rows:
            case = json.loads(Path(row["caseResultPath"]).read_text(encoding="utf-8"))
            self.assertEqual(case["providerInvocationAttemptCount"], 1)
            self.assertFalse(case["automaticRetryPerformed"])
            self.assertTrue(case["allEightNormalHypothesesAttempted"])

    def test_unexpected_worker_death_is_terminal_and_never_complete(self) -> None:
        for slot in (1, 11, 12):
            self.fixture.make_case(f"D_A_Slot{slot:02d}")
        output = self.fixture.root / "f"
        output.mkdir()
        marker, started = self.fixture.root / "blocked.entered", time.monotonic()
        with mock.patch.dict(os.environ, {"R18ZV3_TEST_BLOCK_MARKER": str(marker)}):
            with self.assertRaisesRegex(RuntimeError, "FATAL_WORKER"):
                COORDINATOR.execute_parallel(self.fixture.make_config(output), output, worker_count=2,
                                             base_runner_path=RUNNER_PATH, require_d_drive=False,
                                             require_proposal_alias=True)
        self.assertTrue(marker.is_file())
        self.assertLess(time.monotonic() - started, 5.0)
        self.assertFalse([p for p in multiprocessing.active_children() if p.name.startswith("R18ZV3-")])
        status = json.loads((output / "STATUS.json").read_text(encoding="utf-8"))
        self.assertEqual(status["state"], "HOLD_R18ZV3_PARALLEL_WORKER_FATAL_NO_RETRY")
        self.assertFalse((output / "COMPLETE.json").exists())
        self.assertFalse(status["automaticRetryPerformed"])

    def test_partial_start_failure_cleans_started_worker(self) -> None:
        for slot in (1, 2):
            self.fixture.make_case(f"S_A_Slot{slot:02d}")
        output = self.fixture.root / "x"
        output.mkdir()
        real, processes = multiprocessing.get_context("spawn"), []
        context = mock.Mock(wraps=real)
        def new_process(**kwargs: Any) -> Any:
            process = real.Process(**kwargs)
            processes.append(process)
            if len(processes) == 2:
                process.start = mock.Mock(side_effect=OSError("synthetic second start failure"))
            return process
        context.Process.side_effect = new_process
        with mock.patch.object(COORDINATOR.multiprocessing, "get_context", return_value=context):
            with self.assertRaisesRegex(OSError, "synthetic second start failure"):
                COORDINATOR.execute_parallel(
                    self.fixture.make_config(output), output, worker_count=2,
                    base_runner_path=RUNNER_PATH, require_d_drive=False,
                    require_proposal_alias=True)
        self.assertEqual(len(processes), 2)
        self.assertFalse(processes[0].is_alive())
        self.assertFalse((output / "COMPLETE.json").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
