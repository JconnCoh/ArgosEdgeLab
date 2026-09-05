#!/usr/bin/env python3
"""Package-excluded non-image tests for the exact R18T envelope worker."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(r"C:\R18TEW1")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def write_new(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(value)


def invoke(worker: Path, delegate: Path, configuration: Path, output_root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            sys.executable,
            str(worker),
            "--delegate",
            str(delegate),
            "--delegate-sha256",
            sha256(delegate),
            "--configuration",
            str(configuration),
            "--output-root",
            str(output_root),
        ],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--worker", default=str(Path(__file__).with_name("Run-R18TExecutionEnvelope.py")))
    arguments = parser.parse_args(argv)
    worker = Path(arguments.worker).resolve()
    if not worker.is_file():
        raise RuntimeError(f"Envelope worker is absent: {worker}")
    if ROOT.exists():
        raise RuntimeError(f"Fresh envelope gate root exists: {ROOT}")
    results: list[dict[str, object]] = []
    try:
        ROOT.mkdir()
        configuration = ROOT / "configuration.json"
        write_new(configuration, "{}\n")

        success_root = ROOT / "success"
        success_root.mkdir()
        success_delegate = ROOT / "delegate_success.py"
        write_new(
            success_delegate,
            "import argparse,json,pathlib\n"
            "p=argparse.ArgumentParser();p.add_argument('--configuration');p.add_argument('--output-root');a=p.parse_args()\n"
            "path=pathlib.Path(a.output_root)/'COMPLETE.json';path.write_text(json.dumps({'state':'PASS_SYNTHETIC_COMPLETE'})+'\\n',encoding='utf-8')\n",
        )
        success = invoke(worker, success_delegate, configuration, success_root)
        if success.returncode != 0 or not (success_root / "COMPLETE.json").is_file():
            raise RuntimeError(f"Success delegate failed: {success.stderr}")
        if (success_root / "FAILURE.json").exists():
            raise RuntimeError("Success delegate emitted false FAILURE.json.")
        for leaf in ("WORKER.stdout.log", "WORKER.stderr.log"):
            if not (success_root / leaf).is_file():
                raise RuntimeError(f"Success run omitted durable log: {leaf}")
        results.append({"caseId": "SUCCESS", "state": "PASS", "exitCode": success.returncode})

        failure_root = ROOT / "failure"
        failure_root.mkdir()
        failure_delegate = ROOT / "delegate_failure.py"
        write_new(failure_delegate, "raise RuntimeError('injected pre-inventory worker failure')\n")
        failure = invoke(worker, failure_delegate, configuration, failure_root)
        if failure.returncode == 0:
            raise RuntimeError("Injected failure returned zero.")
        failure_path = failure_root / "FAILURE.json"
        if not failure_path.is_file() or (failure_root / "COMPLETE.json").exists():
            raise RuntimeError("Injected failure did not leave exclusive terminal failure evidence.")
        record = json.loads(failure_path.read_text(encoding="utf-8"))
        if record.get("state") != "HOLD_R18T_WORKER_FAILURE" or record.get("completePresent") is not False:
            raise RuntimeError("Injected failure record changed.")
        partials = list(failure_root.glob("FAILURE.json.partial.*"))
        if partials:
            raise RuntimeError("Atomic failure commit left a partial file.")
        for leaf in ("WORKER.stdout.log", "WORKER.stderr.log"):
            if not (failure_root / leaf).is_file():
                raise RuntimeError(f"Failure run omitted durable log: {leaf}")
        results.append(
            {
                "caseId": "INJECTED_PRE_INVENTORY_FAILURE",
                "state": "PASS_DURABLE_FAILURE_NO_FALSE_COMPLETE",
                "exitCode": failure.returncode,
                "failureSha256": sha256(failure_path),
            }
        )

        print(
            json.dumps(
                {
                    "schema": "argos_opencv_scribe_r18t_execution_envelope_gate_v1",
                    "state": "PASS_R18T_EXECUTION_ENVELOPE_GATE",
                    "workerSha256": sha256(worker),
                    "caseResults": results,
                    "caseResultCount": len(results),
                    "exactWorkerBytesExercised": True,
                    "createNewDurableLogs": True,
                    "atomicFailureCommit": True,
                    "falseCompleteCount": 0,
                    "syntheticNonImageBytesOnly": True,
                    "imageBytesRead": False,
                    "externalAccess": False,
                    "sourceMutationPerformed": False,
                    "identityAccepted": False,
                    "reviewOnly": True,
                    "productionRoutingEnabled": False,
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 0
    finally:
        if ROOT.exists():
            resolved = ROOT.resolve()
            if str(resolved).casefold() != str(ROOT).casefold():
                raise RuntimeError(f"Unsafe envelope fixture cleanup target: {resolved}")
            shutil.rmtree(resolved)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
