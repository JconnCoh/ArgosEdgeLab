#!/usr/bin/env python3
"""Fixed process-isolated parent for the frozen oriented-crop runner."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import multiprocessing
from multiprocessing.connection import wait
import os
import sys
from pathlib import Path
from typing import Any, Iterable


REVISION = "R18ZV3_FIXED_PROCESS_ISOLATED_BATCH_20260911A"
BASE_RUNNER_REVISION = "R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260908D"
BASE_RUNNER_SHA256 = "F3B465F433ADB58F1C37C5673999FD03A4315EFA5A3128EFF8E192E9C3D58AE2"
STABLE_MODULE_NAME = "r18zv3_parallel_batch"
DEFAULT_WORKER_COUNT = 8
MAXIMUM_WORKER_COUNT = 16


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def bounded_text(value: object, limit: int = 2048) -> str:
    text = str(value).replace("\x00", "")
    return text if len(text) <= limit else text[:limit] + "...[TRUNCATED]"


def resolve_base_runner(explicit: Path | None = None) -> Path:
    here = Path(__file__).resolve().parent
    candidates = [explicit.resolve()] if explicit else [
        here / "Run-R18ZTExistingOrientedCropsV2.py",
        here.parent / "OPENCV_SCRIBE_R18ZT_BATCH_C" / "Run-R18ZTExistingOrientedCropsV2.py",
    ]
    matches = [path.resolve() for path in candidates if path.is_file()]
    if len(matches) != 1:
        raise RuntimeError("Exactly one deterministic frozen base-runner path is required.")
    if sha256_file(matches[0]) != BASE_RUNNER_SHA256:
        raise RuntimeError("Frozen base-runner hash mismatch.")
    return matches[0]


def load_base_runner(path: Path) -> Any:
    name = f"r18zv3_base_{BASE_RUNNER_SHA256[:16].lower()}_{os.getpid()}"
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load frozen base runner.")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    if getattr(module, "REVISION", "") != BASE_RUNNER_REVISION:
        raise RuntimeError("Frozen base-runner revision mismatch.")
    if not callable(getattr(module, "run_case", None)):
        raise RuntimeError("Frozen base-runner run_case seam is unavailable.")
    return module


def _prepare_spawn_import() -> None:
    directory = str(Path(__file__).resolve().parent)
    if directory not in sys.path:
        sys.path.insert(0, directory)
    sys.modules[STABLE_MODULE_NAME] = sys.modules[__name__]
    _worker_main.__module__ = STABLE_MODULE_NAME


def _worker_main(
    connection: Any,
    stop_event: Any,
    base_path: str,
    config: dict[str, Any],
    output_root: str,
    require_d_drive: bool,
    require_alias: bool,
    shard_index: int,
    shard: list[tuple[int, dict[str, Any]]],
) -> None:
    try:
        base = load_base_runner(Path(base_path))
        context = base.validate_configuration(
            config,
            Path(output_root),
            require_d_drive=require_d_drive,
            require_proposal_alias=require_alias,
        )
        provider = base.load_module(
            f"r18zv3_provider_{context['providerSha256'][:12].lower()}_{os.getpid()}",
            context["providerPath"],
        )
        if getattr(provider, "REVISION", "") != context["providerRevision"]:
            raise RuntimeError("Loaded provider revision mismatch in isolated worker.")
        if not callable(getattr(provider, "run_job", None)):
            raise RuntimeError("Frozen provider run_job is unavailable in isolated worker.")
        cache = base.ReferenceBankCache(config, context)
        for case_index, case in shard:
            if stop_event.is_set():
                break
            row = base.run_case(
                config, context, case, Path(output_root) / "cases", provider, cache
            )
            connection.send({"kind": "ROW", "index": case_index, "row": row})
        connection.send({
            "kind": "DONE", "shardIndex": shard_index, "cache": cache.snapshot()
        })
    except BaseException as error:
        stop_event.set()
        connection.send({
            "kind": (
                "FATAL_SOURCE_CHANGED"
                if type(error).__name__ == "SourceChangedError"
                else "FATAL_WORKER"
            ),
            "shardIndex": shard_index,
            "errorType": type(error).__name__,
            "detail": bounded_text(error),
        })
    finally:
        connection.close()


def _counts(rows: Iterable[dict[str, Any]]) -> dict[str, int]:
    values = list(rows)
    return {
        "providerInvocationAttemptCount": sum(int(r["providerInvocationAttemptCount"]) for r in values),
        "providerRunJobEnteredCount": sum(int(r["providerRunJobEnteredCount"]) for r in values),
        "providerRunJobReturnedCount": sum(int(r["providerRunJobReturnedCount"]) for r in values),
        "providerRunCount": sum(int(r["providerRunCount"]) for r in values),
    }


def _run_shards(
    base: Any,
    config: dict[str, Any],
    context: dict[str, Any],
    inventory: dict[str, Any],
    inventory_path: Path,
    inventory_sha: str,
    status_path: Path,
    running_path: Path,
    base_path: Path,
    worker_count: int,
    require_d_drive: bool,
    require_alias: bool,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    cases = list(inventory["cases"])
    worker_count = min(worker_count, len(cases))
    indexed = list(enumerate(cases))
    shards = [indexed[i::worker_count] for i in range(worker_count)]
    _prepare_spawn_import()
    spawn = multiprocessing.get_context("spawn")
    stop_event = spawn.Event()
    processes, receivers = [], []
    rows: list[dict[str, Any] | None] = [None] * len(cases)
    finished: set[int] = set()
    caches: dict[int, dict[str, Any]] = {}
    fatals: list[dict[str, Any]] = []
    receiver_index: dict[Any, int] = {}

    def fail(index: int, kind: str, message: dict[str, Any] | None = None) -> None:
        value = {"kind": kind, "shardIndex": index}
        if message:
            value.update({
                "errorType": bounded_text(message.get("errorType", ""), 128),
                "detail": bounded_text(message.get("detail", ""), 1024),
            })
        fatals.append(value)
        stop_event.set()
        finished.add(index)

    last_completed = -1
    try:
        for shard_index, shard in enumerate(shards):
            receiver, sender = spawn.Pipe(duplex=False)
            process = spawn.Process(
                target=_worker_main,
                args=(sender, stop_event, str(base_path), config, str(context["outputRoot"]),
                      require_d_drive, require_alias, shard_index, shard),
                name=f"R18ZV3-{shard_index:02d}",
            )
            try:
                process.start()
            except BaseException:
                receiver.close()
                raise
            finally:
                sender.close()
            processes.append(process)
            receivers.append(receiver)
            receiver_index[receiver] = shard_index
        while len(finished) < worker_count and not fatals:
            active = [receiver for receiver in receivers if receiver_index[receiver] not in finished]
            for receiver in wait(active, timeout=0.2):
                index = receiver_index[receiver]
                try:
                    message = receiver.recv()
                except EOFError:
                    fail(index, "FATAL_WORKER_EXIT_WITHOUT_TERMINAL_MESSAGE")
                    continue
                if not isinstance(message, dict):
                    fail(index, "FATAL_PARENT_PROTOCOL")
                    continue
                kind = str(message.get("kind", ""))
                if kind == "ROW":
                    position, row = message.get("index"), message.get("row")
                    valid = (
                        isinstance(position, int) and not isinstance(position, bool)
                        and 0 <= position < len(rows) and rows[position] is None
                        and isinstance(row, dict)
                        and row.get("caseId") == cases[position]["caseId"]
                    )
                    if not valid:
                        fail(index, "FATAL_PARENT_ROW_PROTOCOL")
                    else:
                        rows[position] = row
                elif kind == "DONE" and isinstance(message.get("cache"), dict):
                    caches[index] = message["cache"]
                    finished.add(index)
                elif kind in ("FATAL_SOURCE_CHANGED", "FATAL_WORKER"):
                    fail(index, kind, message)
                else:
                    fail(index, "FATAL_PARENT_MESSAGE_PROTOCOL")
            completed_rows = [row for row in rows if row is not None]
            if len(completed_rows) != last_completed:
                base.publish_progress(
                    context, status_path, running_path,
                    "RUNNING_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY",
                    phase="PARALLEL_PUBLIC_PROVIDER_RUN",
                    parallelCoordinatorRevision=REVISION,
                    parallelExecutionMode="FIXED_PROCESS_ISOLATED_SHARDS",
                    workerCount=worker_count,
                    qualifiedCaseCount=len(cases),
                    inventoryHoldCount=inventory["inventoryHoldCount"],
                    completedCount=len(completed_rows),
                    **_counts(completed_rows),
                    inventoryPath=str(inventory_path),
                    inventorySha256=inventory_sha,
                )
                last_completed = len(completed_rows)
    finally:
        aborted = bool(fatals) or len(processes) != worker_count
        if aborted:
            stop_event.set()
        for process in processes:
            process.join(0.25 if aborted else 5.0)
        for process in processes:
            if process.is_alive():
                process.terminate()
                process.join(5.0)
        for receiver in receivers:
            receiver.close()
    for index, process in enumerate(processes):
        if process.exitcode != 0 and not any(r["shardIndex"] == index for r in fatals):
            fatals.append({
                "kind": "FATAL_WORKER_NONZERO_EXIT", "shardIndex": index,
                "exitCode": process.exitcode,
            })
    if fatals:
        state = (
            "HOLD_R18ZV3_SOURCE_CHANGED_STOP_NO_RETRY"
            if any(row["kind"] == "FATAL_SOURCE_CHANGED" for row in fatals)
            else "HOLD_R18ZV3_PARALLEL_WORKER_FATAL_NO_RETRY"
        )
        completed_rows = [row for row in rows if row is not None]
        base.publish_progress(
            context, status_path, running_path, state,
            phase="TERMINAL_HOLD",
            parallelCoordinatorRevision=REVISION,
            workerCount=worker_count,
            qualifiedCaseCount=len(cases),
            inventoryHoldCount=inventory["inventoryHoldCount"],
            completedCount=len(completed_rows),
            fatalWorkers=fatals[:worker_count],
            automaticRetryPerformed=False,
        )
        raise RuntimeError(f"Parallel worker failure: {fatals[0]['kind']}")
    if any(row is None for row in rows) or len(caches) != worker_count:
        raise RuntimeError("Parallel workers returned an incomplete result set.")
    return [row for row in rows if row is not None], [caches[i] for i in range(worker_count)]


def _finalize(
    base: Any,
    context: dict[str, Any],
    inventory: dict[str, Any],
    inventory_path: Path,
    inventory_sha: str,
    rows: list[dict[str, Any]],
    cache_rows: list[dict[str, Any]],
    status_path: Path,
    running_path: Path,
) -> dict[str, Any]:
    total = len(rows)
    comparable = sum(bool(row["providerResultComparable"]) for row in rows)
    counts = _counts(rows)
    parallel = {
        "parallelCoordinatorRevision": REVISION,
        "parallelExecutionMode": "FIXED_PROCESS_ISOLATED_SHARDS",
        "workerCount": len(cache_rows),
        "referenceBankCache": {
            "state": "PASS_FIXED_PROCESS_ISOLATED_REFERENCE_BANK_CACHES",
            "parallelism": "FIXED_PROCESS_ISOLATED_SHARDS",
            "workerCount": len(cache_rows),
            "shards": cache_rows,
        },
    }
    summary = {
        "qualifiedCaseCount": total,
        "inventoryHoldCount": inventory["inventoryHoldCount"],
        "completedCount": total,
        **counts,
        "comparableResultCount": comparable,
        "noncomparableOrFailedCount": total - comparable,
        **parallel,
    }
    index_value = {
        "schema": base.INDEX_SCHEMA, "createdUtc": base.utc_now(),
        "state": "PASS_R18ZT_CASE_INDEX_COMPLETE", "revision": base.REVISION,
        "batchId": context["batchId"], "caseCount": total, "rows": rows,
        "identityAcceptedCount": 0, "sourceMutationPerformed": False,
        "automaticRetryPerformed": False, "reviewOnly": True,
        "parallelCoordinatorRevision": REVISION,
    }
    index_path = context["outputRoot"] / "CASE_INDEX.json"
    base.write_json_new_atomic(index_path, index_value)
    index_sha = base.sha256_file(index_path)
    disposition = (
        "COMPLETE_ALL_QUALIFIED_CASES_COMPARABLE"
        if comparable == total else "COMPLETE_WITH_NONCOMPARABLE_OR_FAILED_CASE_HOLDS"
    )
    pins = {
        "inventory": {"path": str(inventory_path), "sha256": inventory_sha},
        "caseIndex": {"path": str(index_path), "sha256": index_sha},
    }
    aggregate = {
        "schema": base.AGGREGATE_SCHEMA, "createdUtc": base.utc_now(),
        "state": "PASS_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY_AGGREGATE",
        "disposition": disposition, "revision": base.REVISION,
        "batchId": context["batchId"],
        "proposalRoot": str(context["proposalRoot"]),
        "canonicalProposalRoot": str(context["canonicalProposalRoot"]),
        "proposalAliasResolvedTarget": str(context["proposalAliasResolvedTarget"]),
        "outputRoot": str(context["outputRoot"]),
        "directChildCount": inventory["directChildCount"], **summary,
        "stateCounts": base.bounded_counter(row["state"] for row in rows),
        "providerStateCounts": base.bounded_counter(row["providerState"] for row in rows),
        "provider": {
            "path": str(context["providerPath"]), "sha256": context["providerSha256"],
            "revision": context["providerRevision"],
            "r11AnalyzerPath": str(context["r11AnalyzerPath"]),
            "r11AnalyzerSha256": context["r11AnalyzerSha256"],
        },
        **pins, "exactProgressPointer": str(running_path),
        "recursiveResultScanRequired": False, "wholeWaferImagesRead": False,
        "truthOrChecksumUsedByRunnerForSelection": False,
        "identityAcceptedCount": 0, "sourceMutationPerformed": False,
        "sourceDeletionPerformed": False, "referenceAdmissionPerformed": False,
        "automaticRetryPerformed": False, "providerActivated": False,
        "trainingEligible": False, "xmlEligible": False,
        "productionEligible": False, "reviewOnly": True,
    }
    aggregate_path = context["outputRoot"] / "AGGREGATE.json"
    base.write_json_new_atomic(aggregate_path, aggregate)
    aggregate_sha = base.sha256_file(aggregate_path)
    complete = {
        "schema": base.COMPLETE_SCHEMA, "createdUtc": base.utc_now(),
        "state": "COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY",
        "disposition": disposition, "revision": base.REVISION,
        "batchId": context["batchId"],
        "proposalRoot": str(context["proposalRoot"]),
        "canonicalProposalRoot": str(context["canonicalProposalRoot"]),
        "proposalAliasResolvedTarget": str(context["proposalAliasResolvedTarget"]),
        **summary,
        "aggregate": {"path": str(aggregate_path), "sha256": aggregate_sha},
        **pins, "exactProgressPointer": str(running_path),
        "recursiveResultScanRequired": False,
        "truthOrChecksumUsedByRunnerForSelection": False,
        "identityAcceptedCount": 0, "sourceMutationPerformed": False,
        "automaticRetryPerformed": False, "reviewOnly": True,
    }
    complete_path = context["outputRoot"] / "COMPLETE.json"
    base.write_json_new_atomic(complete_path, complete)
    complete_sha = base.sha256_file(complete_path)
    base.publish_progress(
        context, status_path, running_path, complete["state"],
        phase="TERMINAL", **summary,
        completePath=str(complete_path), completeSha256=complete_sha,
        aggregatePath=str(aggregate_path), aggregateSha256=aggregate_sha,
        inventoryPath=str(inventory_path), inventorySha256=inventory_sha,
        caseIndexPath=str(index_path), caseIndexSha256=index_sha,
    )
    return complete


def _worker_count(value: int) -> int:
    if isinstance(value, bool) or not 1 <= int(value) <= MAXIMUM_WORKER_COUNT:
        raise ValueError("Worker count is outside the fixed safe bound.")
    return int(value)


def execute_parallel(
    config: dict[str, Any],
    output_root: Path,
    *,
    worker_count: int = DEFAULT_WORKER_COUNT,
    base_runner_path: Path | None = None,
    require_d_drive: bool = True,
    require_proposal_alias: bool = True,
) -> dict[str, Any]:
    worker_count = _worker_count(worker_count)
    base_path = resolve_base_runner(base_runner_path)
    base = load_base_runner(base_path)
    context = base.validate_configuration(
        config, output_root, require_d_drive=require_d_drive,
        require_proposal_alias=require_proposal_alias,
    )
    base.validate_initial_output_root(context["outputRoot"])
    status_path = context["outputRoot"] / "STATUS.json"
    running_path = context["outputRoot"] / "RUNNING.json"
    base.publish_progress(
        context, status_path, running_path,
        "RUNNING_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY",
        phase="INVENTORY", parallelCoordinatorRevision=REVISION,
        parallelExecutionMode="FIXED_PROCESS_ISOLATED_SHARDS",
        workerCount=worker_count, completedCount=0,
        providerInvocationAttemptCount=0, providerRunJobEnteredCount=0,
        providerRunJobReturnedCount=0, providerRunCount=0,
    )
    try:
        inventory = base.inventory_cases(config, context)
        inventory_path = context["outputRoot"] / "INVENTORY.json"
        base.write_json_new_atomic(inventory_path, inventory)
        inventory_sha = base.sha256_file(inventory_path)
        if not inventory["cases"]:
            base.publish_progress(
                context, status_path, running_path,
                "HOLD_R18ZT_NO_QUALIFIED_EXISTING_ORIENTED_CROPS",
                phase="TERMINAL_HOLD", qualifiedCaseCount=0,
                inventoryHoldCount=inventory["inventoryHoldCount"],
                inventoryPath=str(inventory_path), inventorySha256=inventory_sha,
            )
            raise ValueError("No qualified oriented-input evidence.")
        (context["outputRoot"] / "cases").mkdir()
        rows, caches = _run_shards(
            base, config, context, inventory, inventory_path, inventory_sha,
            status_path, running_path, base_path, worker_count,
            require_d_drive, require_proposal_alias,
        )
        return _finalize(
            base, context, inventory, inventory_path, inventory_sha,
            rows, caches, status_path, running_path,
        )
    except Exception as error:
        if status_path.is_file():
            current = base.read_json_bounded(status_path, 1024 * 1024)
            if not str(current.get("state", "")).startswith("HOLD_"):
                base.publish_progress(
                    context, status_path, running_path,
                    "HOLD_R18ZV3_PARALLEL_BATCH_FATAL_NO_RETRY",
                    phase="TERMINAL_HOLD", errorType=type(error).__name__,
                    detail=bounded_text(error), automaticRetryPerformed=False,
                )
        raise


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("preflight", "run"), required=True)
    parser.add_argument("--configuration", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--worker-count", type=int, default=DEFAULT_WORKER_COUNT)
    parser.add_argument("--base-runner", type=Path)
    return parser.parse_args(list(argv))


def main(argv: Iterable[str]) -> int:
    arguments = parse_arguments(argv)
    try:
        worker_count = _worker_count(arguments.worker_count)
        base_path = resolve_base_runner(arguments.base_runner)
        base = load_base_runner(base_path)
        config = base.read_json_bounded(arguments.configuration.resolve(), 16 * 1024 * 1024)
        output_root = arguments.output_root.resolve()
        context = base.validate_configuration(config, output_root, require_d_drive=True)
        if arguments.mode == "preflight":
            print(json.dumps({
                "state": "PASS_R18ZV3_FIXED_PROCESS_ISOLATED_PREFLIGHT",
                "revision": REVISION, "baseRunnerSha256": BASE_RUNNER_SHA256,
                "batchId": context["batchId"], "workerCount": worker_count,
                "mutationsPerformed": False, "sourceImageBytesRead": False,
                "reviewOnly": True,
            }, sort_keys=True))
            return 0
        complete = execute_parallel(
            config, output_root, worker_count=worker_count,
            base_runner_path=base_path, require_d_drive=True,
        )
        print(json.dumps({
            "state": complete["state"],
            "qualifiedCaseCount": complete["qualifiedCaseCount"],
            "completedCount": complete["completedCount"],
            "comparableResultCount": complete["comparableResultCount"],
            "workerCount": complete["workerCount"],
            "statusPath": str(output_root / "STATUS.json"),
            "completePath": str(output_root / "COMPLETE.json"),
        }, sort_keys=True))
        return 0
    except Exception as error:
        print(json.dumps({
            "state": "HOLD_R18ZV3_PARALLEL_BATCH_RUNNER_ERROR_NO_RETRY",
            "errorType": type(error).__name__, "detail": bounded_text(error),
            "automaticRetryAllowed": False, "identityAccepted": False,
            "reviewOnly": True,
        }, sort_keys=True), file=sys.stderr)
        return 1


if __name__ == "__main__":
    multiprocessing.freeze_support()
    raise SystemExit(main(sys.argv[1:]))
