#!/usr/bin/env python3
"""Durable asynchronous envelope for the R18ZT existing-crop batch runner."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import traceback
import uuid


REVISION = "R18ZT_EXISTING_ORIENTED_CROPS_ASYNC_REVIEW_ONLY_20260906"
COMPLETE_STATE = "COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY"


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


def commit_failure(output_root: Path, value: dict[str, object]) -> None:
    final_path = output_root / "FAILURE.json"
    if final_path.exists():
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
            stage = "RUN_FROZEN_DELEGATE"
            completed = subprocess.run(
                [
                    sys.executable,
                    str(delegate),
                    "--mode",
                    "run",
                    "--configuration",
                    str(configuration),
                    "--output-root",
                    str(output_root),
                ],
                cwd=str(delegate.parent),
                stdin=subprocess.DEVNULL,
                stdout=stdout_log,
                stderr=stderr_log,
                check=False,
            )
            context["delegateExitCode"] = int(completed.returncode)
            if completed.returncode != 0:
                raise RuntimeError(f"Frozen delegate exited nonzero: {completed.returncode}")

            stage = "VERIFY_TERMINAL_COMPLETE"
            complete_path = output_root / "COMPLETE.json"
            if not complete_path.is_file():
                raise RuntimeError("Frozen delegate returned zero without COMPLETE.json.")
            complete = read_json(complete_path)
            if complete.get("schema") != "argos_opencv_scribe_r18zt_batch_complete_v1":
                raise RuntimeError("Frozen delegate terminal completion schema changed.")
            if complete.get("state") != COMPLETE_STATE:
                raise RuntimeError(
                    f"Frozen delegate returned zero without terminal completion: {complete.get('state')}"
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
        failure = {
            "schema": "argos_opencv_scribe_r18zt_batch_worker_failure_v1",
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
            "completePresent": (output_root / "COMPLETE.json").is_file()
            if output_root.is_dir()
            else False,
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
