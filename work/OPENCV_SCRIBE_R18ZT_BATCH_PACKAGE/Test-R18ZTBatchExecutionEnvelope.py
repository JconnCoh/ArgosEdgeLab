#!/usr/bin/env python3
"""Synthetic no-image gate for the R18ZT asynchronous execution envelope."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


COMPLETE_STATE = "COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def write_text(path: Path, value: str) -> None:
    path.write_text(value, encoding="utf-8", newline="\n")


def invoke(envelope: Path, delegate: Path, output_root: Path, configuration: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            sys.executable,
            "-B",
            str(envelope),
            "--delegate",
            str(delegate),
            "--delegate-sha256",
            sha256_file(delegate),
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--envelope", required=True, type=Path)
    args = parser.parse_args()
    envelope = args.envelope.resolve()
    if not envelope.is_file():
        raise FileNotFoundError(envelope)

    with tempfile.TemporaryDirectory(prefix="r18zt_env_") as temporary:
        root = Path(temporary)
        configuration = root / "configuration.json"
        write_text(configuration, "{}\n")

        success_delegate = root / "success.py"
        write_text(
            success_delegate,
            "import argparse, json\n"
            "from pathlib import Path\n"
            "p=argparse.ArgumentParser();p.add_argument('--mode',required=True);p.add_argument('--configuration',required=True);p.add_argument('--output-root',required=True);a=p.parse_args()\n"
            "assert a.mode == 'run'\n"
            "Path(a.output_root,'COMPLETE.json').write_text(json.dumps({'schema':'argos_opencv_scribe_r18zt_batch_complete_v1','state':'COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY'})+'\\n',encoding='utf-8')\n"
        )
        success_root = root / "success"
        success_root.mkdir()
        success = invoke(envelope, success_delegate, success_root, configuration)
        if success.returncode != 0:
            raise RuntimeError(f"Success case failed: {success.stderr}")
        complete = json.loads((success_root / "COMPLETE.json").read_text(encoding="utf-8"))
        if complete.get("state") != COMPLETE_STATE or (success_root / "FAILURE.json").exists():
            raise RuntimeError("Success case did not preserve exact terminal status.")
        if not (success_root / "WORKER.stdout.log").is_file() or not (success_root / "WORKER.stderr.log").is_file():
            raise RuntimeError("Success case did not create durable logs.")

        failure_delegate = root / "failure.py"
        write_text(failure_delegate, "import sys\nsys.stderr.write('synthetic failure\\n')\nraise SystemExit(7)\n")
        failure_root = root / "failure"
        failure_root.mkdir()
        failure = invoke(envelope, failure_delegate, failure_root, configuration)
        if failure.returncode == 0:
            raise RuntimeError("Injected failure returned zero.")
        failure_record = json.loads((failure_root / "FAILURE.json").read_text(encoding="utf-8"))
        if failure_record.get("state") != "HOLD_R18ZT_BATCH_WORKER_FAILURE":
            raise RuntimeError("Injected failure record state changed.")
        if failure_record.get("completionClaimed") is not False or (failure_root / "COMPLETE.json").exists():
            raise RuntimeError("Injected failure created a false completion claim.")

    print(
        json.dumps(
            {
                "schema": "argos_opencv_scribe_r18zt_batch_execution_envelope_gate_v1",
                "state": "PASS_R18ZT_BATCH_EXECUTION_ENVELOPE_GATE",
                "envelopeSha256": sha256_file(envelope),
                "successCase": True,
                "injectedFailureCase": True,
                "durableStdout": True,
                "durableStderr": True,
                "atomicFailureCommit": True,
                "falseCompletionCount": 0,
                "imageBytesRead": False,
                "externalMutationPerformed": False,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
