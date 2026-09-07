#!/usr/bin/env python3
"""Durable asynchronous envelope for the R18ZT existing-crop batch runner."""

from __future__ import annotations

import argparse
from contextlib import redirect_stderr, redirect_stdout
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import traceback
import uuid


REVISION = "R18ZT_EXISTING_ORIENTED_CROPS_ASYNC_REVIEW_ONLY_20260906C"
COMPLETE_STATE = "COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY"
RUNNER_REVISION = "R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260906C"
COMPLETE_SCHEMA = "argos_opencv_scribe_r18zt_batch_complete_v2"
SHA256_PATTERN = re.compile(r"^[A-F0-9]{64}$")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def bounded_text(value: object, limit: int = 1024) -> str:
    text = str(value).replace("\x00", "")
    return text if len(text) <= limit else text[:limit] + "...[TRUNCATED]"


def read_json(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def load_delegate(path: Path) -> object:
    module_name = f"argos_r18zt_batch_delegate_{sha256_file(path)[:16].lower()}"
    specification = importlib.util.spec_from_file_location(module_name, path)
    if specification is None or specification.loader is None:
        raise RuntimeError("Unable to load frozen batch delegate in-process.")
    module = importlib.util.module_from_spec(specification)
    sys.modules[module_name] = module
    specification.loader.exec_module(module)
    if not callable(getattr(module, "main", None)):
        raise RuntimeError("Frozen batch delegate has no callable public main entry point.")
    return module


def exact_complete_contract(
    output_root: Path, configuration: Path
) -> tuple[bool, str, dict[str, object] | None]:
    complete_path = output_root / "COMPLETE.json"
    if not complete_path.is_file():
        return False, "COMPLETE_ABSENT", None
    try:
        complete = read_json(complete_path)
        config = read_json(configuration)
    except BaseException as error:
        return False, f"COMPLETE_OR_CONFIGURATION_UNREADABLE:{bounded_text(error)}", None
    def same_path(actual: object, expected: object) -> bool:
        return os.path.normcase(os.path.abspath(str(actual))) == os.path.normcase(
            os.path.abspath(str(expected))
        )

    expected_scalars = {
        "schema": COMPLETE_SCHEMA,
        "state": COMPLETE_STATE,
        "revision": RUNNER_REVISION,
        "batchId": str(config.get("batchId", "")),
        "proposalRoot": os.path.abspath(str(config.get("proposalRoot", ""))),
        "canonicalProposalRoot": os.path.abspath(
            str(config.get("canonicalProposalRoot", ""))
        ),
        "proposalAliasResolvedTarget": str(
            Path(str(config.get("canonicalProposalRoot", ""))).resolve()
        ),
        "exactProgressPointer": str((output_root / "RUNNING.json").resolve()),
    }
    for field, expected in expected_scalars.items():
        actual = str(complete.get(field, ""))
        if field.endswith("Root") or field.endswith("Target") or field.endswith("Pointer"):
            if not same_path(actual, expected):
                return False, f"COMPLETE_FIELD_MISMATCH:{field}", complete
        elif actual != expected:
            return False, f"COMPLETE_FIELD_MISMATCH:{field}", complete
    for field, expected in {
        "recursiveResultScanRequired": False,
        "truthOrChecksumUsedByRunnerForSelection": False,
        "sourceMutationPerformed": False,
        "automaticRetryPerformed": False,
        "reviewOnly": True,
    }.items():
        if complete.get(field) is not expected:
            return False, f"COMPLETE_BOOLEAN_MISMATCH:{field}", complete
    integer_fields = (
        "qualifiedCaseCount",
        "inventoryHoldCount",
        "completedCount",
        "providerInvocationAttemptCount",
        "providerRunJobEnteredCount",
        "providerRunJobReturnedCount",
        "providerRunCount",
        "comparableResultCount",
        "noncomparableOrFailedCount",
        "identityAcceptedCount",
    )
    counts: dict[str, int] = {}
    for field in integer_fields:
        value = complete.get(field)
        if isinstance(value, bool) or not isinstance(value, int) or value < 0:
            return False, f"COMPLETE_COUNT_INVALID:{field}", complete
        counts[field] = value
    if (
        counts["qualifiedCaseCount"] < 1
        or counts["completedCount"] != counts["qualifiedCaseCount"]
        or counts["providerInvocationAttemptCount"] != counts["qualifiedCaseCount"]
        or counts["providerRunJobEnteredCount"] > counts["providerInvocationAttemptCount"]
        or counts["providerRunJobReturnedCount"] > counts["providerRunJobEnteredCount"]
        or counts["providerRunCount"] != counts["providerRunJobEnteredCount"]
        or counts["comparableResultCount"] + counts["noncomparableOrFailedCount"]
        != counts["qualifiedCaseCount"]
        or counts["identityAcceptedCount"] != 0
    ):
        return False, "COMPLETE_COUNT_RELATION_INVALID", complete
    expected_disposition = (
        "COMPLETE_ALL_QUALIFIED_CASES_COMPARABLE"
        if counts["comparableResultCount"] == counts["qualifiedCaseCount"]
        and counts["noncomparableOrFailedCount"] == 0
        else "COMPLETE_WITH_NONCOMPARABLE_OR_FAILED_CASE_HOLDS"
    )
    if complete.get("disposition") != expected_disposition:
        return False, "COMPLETE_DISPOSITION_INVALID", complete
    pinned_values: dict[str, dict[str, object]] = {}
    for field, leaf in (
        ("aggregate", "AGGREGATE.json"),
        ("inventory", "INVENTORY.json"),
        ("caseIndex", "CASE_INDEX.json"),
    ):
        pin = complete.get(field)
        if not isinstance(pin, dict) or set(pin) != {"path", "sha256"}:
            return False, f"COMPLETE_PIN_SHAPE_INVALID:{field}", complete
        pinned_path = Path(str(pin.get("path", "")))
        expected_path = output_root / leaf
        expected_sha = str(pin.get("sha256", ""))
        if (
            not same_path(pinned_path, expected_path)
            or not SHA256_PATTERN.fullmatch(expected_sha)
            or not expected_path.is_file()
            or sha256_file(expected_path) != expected_sha
        ):
            return False, f"COMPLETE_PIN_INVALID:{field}", complete
        try:
            pinned_values[field] = read_json(expected_path)
        except BaseException as error:
            return False, f"COMPLETE_PIN_UNREADABLE:{field}:{bounded_text(error)}", complete

    inventory = pinned_values["inventory"]
    for field, expected in {
        "schema": "argos_opencv_scribe_r18zt_batch_inventory_v2",
        "state": "PASS_R18ZT_BOUNDED_DIRECT_CHILD_INVENTORY",
        "revision": RUNNER_REVISION,
    }.items():
        if inventory.get(field) != expected:
            return False, f"INVENTORY_FIELD_MISMATCH:{field}", complete
    for field, expected in {
        "proposalRoot": config.get("proposalRoot", ""),
        "canonicalProposalRoot": config.get("canonicalProposalRoot", ""),
        "proposalAliasResolvedTarget": Path(
            str(config.get("canonicalProposalRoot", ""))
        ).resolve(),
    }.items():
        if not same_path(inventory.get(field, ""), expected):
            return False, f"INVENTORY_PATH_MISMATCH:{field}", complete
    for field, expected in {
        "proposalRootIsRequiredAlias": True,
        "recursiveEnumerationPerformed": False,
        "wholeWaferImagesRead": False,
        "sourcePixelsDecodedByInventory": False,
        "sourceMutationPerformed": False,
        "identityAccepted": False,
        "reviewOnly": True,
    }.items():
        if inventory.get(field) is not expected:
            return False, f"INVENTORY_BOOLEAN_MISMATCH:{field}", complete
    cases = inventory.get("cases")
    holds = inventory.get("holds")
    inventory_counts = {
        field: inventory.get(field)
        for field in (
            "directChildCount",
            "ignoredNonDirectoryCount",
            "qualifiedCaseCount",
            "inventoryHoldCount",
        )
    }
    if any(
        isinstance(value, bool) or not isinstance(value, int) or value < 0
        for value in inventory_counts.values()
    ):
        return False, "INVENTORY_COUNT_INVALID", complete
    if (
        not isinstance(cases, list)
        or not isinstance(holds, list)
        or inventory_counts["qualifiedCaseCount"] != counts["qualifiedCaseCount"]
        or inventory_counts["inventoryHoldCount"] != counts["inventoryHoldCount"]
        or len(cases) != counts["qualifiedCaseCount"]
        or len(holds) != counts["inventoryHoldCount"]
        or inventory_counts["directChildCount"]
        != counts["qualifiedCaseCount"]
        + counts["inventoryHoldCount"]
        + inventory_counts["ignoredNonDirectoryCount"]
    ):
        return False, "INVENTORY_COUNT_RELATION_INVALID", complete
    inventory_case_ids = [str(row.get("caseId", "")) for row in cases if isinstance(row, dict)]
    if (
        len(inventory_case_ids) != len(cases)
        or any(not case_id for case_id in inventory_case_ids)
        or len(set(inventory_case_ids)) != len(inventory_case_ids)
    ):
        return False, "INVENTORY_CASE_ID_SET_INVALID", complete

    case_index = pinned_values["caseIndex"]
    for field, expected in {
        "schema": "argos_opencv_scribe_r18zt_batch_case_index_v2",
        "state": "PASS_R18ZT_CASE_INDEX_COMPLETE",
        "revision": RUNNER_REVISION,
        "batchId": config.get("batchId", ""),
    }.items():
        if case_index.get(field) != expected:
            return False, f"CASE_INDEX_FIELD_MISMATCH:{field}", complete
    for field, expected in {
        "identityAcceptedCount": 0,
        "sourceMutationPerformed": False,
        "automaticRetryPerformed": False,
        "reviewOnly": True,
    }.items():
        if case_index.get(field) != expected or type(case_index.get(field)) is not type(expected):
            return False, f"CASE_INDEX_FIELD_MISMATCH:{field}", complete
    rows = case_index.get("rows")
    if (
        isinstance(case_index.get("caseCount"), bool)
        or not isinstance(case_index.get("caseCount"), int)
        or case_index.get("caseCount") != counts["qualifiedCaseCount"]
        or not isinstance(rows, list)
        or len(rows) != counts["qualifiedCaseCount"]
    ):
        return False, "CASE_INDEX_COUNT_RELATION_INVALID", complete
    row_counts = {
        "providerInvocationAttemptCount": 0,
        "providerRunJobEnteredCount": 0,
        "providerRunJobReturnedCount": 0,
        "providerRunCount": 0,
    }
    row_comparable = 0
    index_case_ids: list[str] = []
    for row in rows:
        if not isinstance(row, dict) or type(row.get("providerResultComparable")) is not bool:
            return False, "CASE_INDEX_COMPARABLE_FLAG_INVALID", complete
        case_id = str(row.get("caseId", ""))
        if not case_id:
            return False, "CASE_INDEX_CASE_ID_INVALID", complete
        index_case_ids.append(case_id)
        row_comparable += int(row["providerResultComparable"])
        for field in row_counts:
            value = row.get(field)
            if isinstance(value, bool) or not isinstance(value, int) or value < 0:
                return False, f"CASE_INDEX_ROW_COUNT_INVALID:{field}", complete
            row_counts[field] += value
        if row.get("automaticRetryPerformed") is not False:
            return False, "CASE_INDEX_ROW_RETRY_INVALID", complete
        if (
            row["providerInvocationAttemptCount"] != 1
            or row["providerRunJobEnteredCount"] not in (0, 1)
            or row["providerRunJobReturnedCount"] > row["providerRunJobEnteredCount"]
            or row["providerRunCount"] != row["providerRunJobEnteredCount"]
        ):
            return False, "CASE_INDEX_ROW_INVOCATION_RELATION_INVALID", complete
    if row_comparable != counts["comparableResultCount"] or any(
        row_counts[field] != counts[field] for field in row_counts
    ):
        return False, "CASE_INDEX_ROW_SUM_INVALID", complete
    if len(set(index_case_ids)) != len(index_case_ids) or sorted(index_case_ids) != sorted(
        inventory_case_ids
    ):
        return False, "CASE_INDEX_INVENTORY_CASE_ID_SET_MISMATCH", complete

    aggregate = pinned_values["aggregate"]
    for field, expected in {
        "schema": "argos_opencv_scribe_r18zt_batch_aggregate_v2",
        "state": "PASS_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY_AGGREGATE",
        "disposition": expected_disposition,
        "revision": RUNNER_REVISION,
        "batchId": config.get("batchId", ""),
    }.items():
        if aggregate.get(field) != expected:
            return False, f"AGGREGATE_FIELD_MISMATCH:{field}", complete
    for field, expected in {
        "proposalRoot": config.get("proposalRoot", ""),
        "canonicalProposalRoot": config.get("canonicalProposalRoot", ""),
        "proposalAliasResolvedTarget": Path(
            str(config.get("canonicalProposalRoot", ""))
        ).resolve(),
        "outputRoot": output_root,
        "exactProgressPointer": output_root / "RUNNING.json",
    }.items():
        if not same_path(aggregate.get(field, ""), expected):
            return False, f"AGGREGATE_PATH_MISMATCH:{field}", complete
    if any(
        isinstance(aggregate.get(field), bool)
        or not isinstance(aggregate.get(field), int)
        or aggregate.get(field) != value
        for field, value in counts.items()
    ):
        return False, "AGGREGATE_COUNT_MISMATCH", complete
    if (
        isinstance(aggregate.get("directChildCount"), bool)
        or not isinstance(aggregate.get("directChildCount"), int)
        or aggregate.get("directChildCount") != inventory_counts["directChildCount"]
    ):
        return False, "AGGREGATE_DIRECT_CHILD_COUNT_MISMATCH", complete
    for field, expected in {
        "recursiveResultScanRequired": False,
        "wholeWaferImagesRead": False,
        "truthOrChecksumUsedByRunnerForSelection": False,
        "sourceMutationPerformed": False,
        "automaticRetryPerformed": False,
        "reviewOnly": True,
    }.items():
        if aggregate.get(field) is not expected:
            return False, f"AGGREGATE_BOOLEAN_MISMATCH:{field}", complete
    for field in ("inventory", "caseIndex"):
        if aggregate.get(field) != complete.get(field):
            return False, f"AGGREGATE_PIN_MISMATCH:{field}", complete
    return True, "EXACT_COMPLETE", complete


def quarantine_invalid_complete(output_root: Path) -> dict[str, object]:
    complete_path = output_root / "COMPLETE.json"
    quarantine_path = output_root / "COMPLETE.invalid.json"
    if not complete_path.is_file() or quarantine_path.exists():
        raise RuntimeError("Invalid COMPLETE cannot be quarantined create-new.")
    invalid_sha = sha256_file(complete_path)
    os.replace(complete_path, quarantine_path)
    return {"path": str(quarantine_path), "sha256": invalid_sha}


def commit_failure(output_root: Path, value: dict[str, object]) -> None:
    final_path = output_root / "FAILURE.json"
    if final_path.exists() or (output_root / "COMPLETE.json").exists():
        return
    temporary = output_root / f"FAILURE.json.partial.{os.getpid()}.{uuid.uuid4().hex}"
    payload = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "wb", closefd=True) as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.link(temporary, final_path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--delegate", required=True)
    parser.add_argument("--delegate-sha256", required=True)
    parser.add_argument("--configuration", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def run(arguments: argparse.Namespace) -> int:
    stage = "VALIDATE_ARGUMENTS"
    output_root = Path(arguments.output_root).resolve()
    delegate = Path(arguments.delegate).resolve()
    configuration = Path(arguments.configuration).resolve()
    expected_delegate_hash = str(arguments.delegate_sha256).upper()
    context: dict[str, object] = {
        "delegatePath": str(delegate),
        "delegateSha256Expected": expected_delegate_hash,
        "configurationPath": str(configuration),
        "outputRoot": str(output_root),
    }
    try:
        if not output_root.is_dir():
            raise RuntimeError("Output root must exist before worker start.")
        if not delegate.is_file() or not configuration.is_file():
            raise RuntimeError("Delegate or configuration is absent.")
        actual_delegate_hash = sha256_file(delegate)
        context["delegateSha256Actual"] = actual_delegate_hash
        if actual_delegate_hash != expected_delegate_hash:
            raise RuntimeError("Frozen delegate hash mismatch.")
        for leaf in (
            "RUNNING.json",
            "COMPLETE.json",
            "STATUS.json",
            "FAILURE.json",
            "WORKER.stdout.log",
            "WORKER.stderr.log",
        ):
            if (output_root / leaf).exists():
                raise RuntimeError(f"Create-new worker output already exists: {leaf}")

        stage = "OPEN_DURABLE_LOGS"
        stdout_path = output_root / "WORKER.stdout.log"
        stderr_path = output_root / "WORKER.stderr.log"
        with stdout_path.open("x", encoding="utf-8", buffering=1) as stdout_log, stderr_path.open(
            "x", encoding="utf-8", buffering=1
        ) as stderr_log:
            stdout_log.write(json.dumps({"event": "R18ZT_BATCH_WORKER_START", "revision": REVISION}) + "\n")
            stage = "LOAD_FROZEN_DELEGATE_IN_PROCESS"
            delegate_module = load_delegate(delegate)
            stage = "RUN_FROZEN_DELEGATE_IN_PROCESS"
            delegate_arguments = [
                    "--mode",
                    "run",
                    "--configuration",
                    str(configuration),
                    "--output-root",
                    str(output_root),
                ]
            with redirect_stdout(stdout_log), redirect_stderr(stderr_log):
                try:
                    returned = delegate_module.main(delegate_arguments)
                    delegate_exit_code = 0 if returned is None else int(returned)
                except SystemExit as signal:
                    delegate_exit_code = 0 if signal.code is None else int(signal.code)
            context["delegateExitCode"] = delegate_exit_code
            context["delegateExecutionMode"] = "IN_PROCESS_PUBLIC_MAIN_NO_SUBPROCESS"
            if delegate_exit_code != 0:
                raise RuntimeError(f"Frozen delegate exited nonzero: {delegate_exit_code}")

            stage = "VERIFY_TERMINAL_COMPLETE"
            complete_path = output_root / "COMPLETE.json"
            if not complete_path.is_file():
                raise RuntimeError("Frozen delegate returned zero without COMPLETE.json.")
            complete = read_json(complete_path)
            exact_complete, complete_detail, complete = exact_complete_contract(
                output_root, configuration
            )
            if not exact_complete:
                raise RuntimeError(
                    f"Frozen delegate returned zero without exact terminal completion: {complete_detail}"
                )
            stdout_log.write(
                json.dumps(
                    {
                        "event": "R18ZT_BATCH_WORKER_COMPLETE",
                        "completeSha256": sha256_file(complete_path),
                        "completionState": COMPLETE_STATE,
                    }
                )
                + "\n"
            )
        return 0
    except BaseException as error:
        complete_path = output_root / "COMPLETE.json"
        exact_complete, complete_detail, _ = exact_complete_contract(output_root, configuration)
        if exact_complete:
            sys.stderr.write(
                "R18ZT delegate reported a post-COMPLETE error; exact COMPLETE is preserved "
                "without a contradictory FAILURE leaf.\n"
            )
            return 0
        invalid_complete_quarantine: dict[str, object] | None = None
        if complete_path.is_file():
            invalid_complete_quarantine = quarantine_invalid_complete(output_root)
        failure = {
            "schema": "argos_opencv_scribe_r18zt_batch_worker_failure_v2",
            "state": "HOLD_R18ZT_BATCH_WORKER_FAILURE",
            "revision": REVISION,
            "stage": stage,
            "exceptionClass": type(error).__name__,
            "detail": bounded_text(error),
            "traceback": bounded_text(
                "".join(traceback.format_exception(type(error), error, error.__traceback__)), 4096
            ),
            "exitCode": int(context.get("delegateExitCode", 1)),
            "automaticRetryAllowed": False,
            "completionClaimed": False,
            "completePresent": complete_path.is_file()
            if output_root.is_dir()
            else False,
            "completeValidation": complete_detail,
            "invalidCompleteQuarantine": invalid_complete_quarantine,
            "sourceMutationPerformed": False,
            "identityAccepted": False,
            "reviewOnly": True,
            "productionRoutingEnabled": False,
            **context,
        }
        if output_root.is_dir():
            try:
                commit_failure(output_root, failure)
            except BaseException as commit_error:
                sys.stderr.write(f"R18ZT failure commit failed: {bounded_text(commit_error)}\n")
        sys.stderr.write(f"R18ZT worker failed at {stage}: {bounded_text(error)}\n")
        return int(failure.get("exitCode", 1)) or 1


def main(argv: list[str]) -> int:
    return run(parse_args(argv))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
