#!/usr/bin/env python3
"""Synthetic no-image gate for the R18ZT asynchronous execution envelope."""

from __future__ import annotations

import argparse
import ast
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


def complete_delegate_source(exit_code: int) -> str:
    return (
        "import hashlib, json\n"
        "from pathlib import Path\n"
        "def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest().upper()\n"
        "def main(argv):\n"
        "    output=Path(argv[argv.index('--output-root')+1]).resolve()\n"
        "    config=json.loads(Path(argv[argv.index('--configuration')+1]).read_text(encoding='utf-8'))\n"
        "    revision='R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260906C'\n"
        "    proposal=str(Path(config['proposalRoot']).absolute())\n"
        "    canonical=str(Path(config['canonicalProposalRoot']).resolve())\n"
        "    inventory={'schema':'argos_opencv_scribe_r18zt_batch_inventory_v2','state':'PASS_R18ZT_BOUNDED_DIRECT_CHILD_INVENTORY','revision':revision,'proposalRoot':proposal,'canonicalProposalRoot':canonical,'proposalAliasResolvedTarget':canonical,'proposalRootIsRequiredAlias':True,'directChildCount':1,'ignoredNonDirectoryCount':0,'qualifiedCaseCount':1,'inventoryHoldCount':0,'cases':[{'caseId':'FIXTURE_CASE'}],'holds':[],'recursiveEnumerationPerformed':False,'wholeWaferImagesRead':False,'sourcePixelsDecodedByInventory':False,'sourceMutationPerformed':False,'identityAccepted':False,'reviewOnly':True}\n"
        "    inventory_path=output/'INVENTORY.json';inventory_path.write_text(json.dumps(inventory)+'\\n',encoding='utf-8')\n"
        "    row={'caseId':'FIXTURE_CASE','state':'PASS_R18ZT_COMPARABLE_REVIEW_ONLY_RESULT','providerState':'PASS_R18ZT_PROVIDER_RESULT_COMPARABLE','providerResultComparable':True,'providerInvocationAttemptCount':1,'providerRunJobEnteredCount':1,'providerRunJobReturnedCount':1,'providerRunCount':1,'automaticRetryPerformed':False}\n"
        "    case_index={'schema':'argos_opencv_scribe_r18zt_batch_case_index_v2','state':'PASS_R18ZT_CASE_INDEX_COMPLETE','revision':revision,'batchId':'R18ZT1','caseCount':1,'rows':[row],'identityAcceptedCount':0,'sourceMutationPerformed':False,'automaticRetryPerformed':False,'reviewOnly':True}\n"
        "    index_path=output/'CASE_INDEX.json';index_path.write_text(json.dumps(case_index)+'\\n',encoding='utf-8')\n"
        "    inventory_pin={'path':str(inventory_path),'sha256':sha(inventory_path)};index_pin={'path':str(index_path),'sha256':sha(index_path)}\n"
        "    aggregate={'schema':'argos_opencv_scribe_r18zt_batch_aggregate_v2','state':'PASS_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY_AGGREGATE','disposition':'COMPLETE_ALL_QUALIFIED_CASES_COMPARABLE','revision':revision,'batchId':'R18ZT1','proposalRoot':proposal,'canonicalProposalRoot':canonical,'proposalAliasResolvedTarget':canonical,'outputRoot':str(output),'directChildCount':1,'qualifiedCaseCount':1,'inventoryHoldCount':0,'completedCount':1,'providerInvocationAttemptCount':1,'providerRunJobEnteredCount':1,'providerRunJobReturnedCount':1,'providerRunCount':1,'comparableResultCount':1,'noncomparableOrFailedCount':0,'inventory':inventory_pin,'caseIndex':index_pin,'exactProgressPointer':str(output/'RUNNING.json'),'recursiveResultScanRequired':False,'wholeWaferImagesRead':False,'truthOrChecksumUsedByRunnerForSelection':False,'identityAcceptedCount':0,'sourceMutationPerformed':False,'automaticRetryPerformed':False,'reviewOnly':True}\n"
        "    aggregate_path=output/'AGGREGATE.json';aggregate_path.write_text(json.dumps(aggregate)+'\\n',encoding='utf-8');aggregate_pin={'path':str(aggregate_path),'sha256':sha(aggregate_path)}\n"
        "    complete={'schema':'argos_opencv_scribe_r18zt_batch_complete_v2','createdUtc':'2026-09-06T00:00:00Z','state':'COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY','disposition':'COMPLETE_ALL_QUALIFIED_CASES_COMPARABLE','revision':revision,'batchId':'R18ZT1','proposalRoot':proposal,'canonicalProposalRoot':canonical,'proposalAliasResolvedTarget':canonical,'qualifiedCaseCount':1,'inventoryHoldCount':0,'completedCount':1,'providerInvocationAttemptCount':1,'providerRunJobEnteredCount':1,'providerRunJobReturnedCount':1,'providerRunCount':1,'comparableResultCount':1,'noncomparableOrFailedCount':0,'aggregate':aggregate_pin,'inventory':inventory_pin,'caseIndex':index_pin,'exactProgressPointer':str(output/'RUNNING.json'),'recursiveResultScanRequired':False,'truthOrChecksumUsedByRunnerForSelection':False,'identityAcceptedCount':0,'sourceMutationPerformed':False,'automaticRetryPerformed':False,'reviewOnly':True}\n"
        "    (output/'COMPLETE.json').write_text(json.dumps(complete)+'\\n',encoding='utf-8')\n"
        f"    return {exit_code}\n"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--envelope", required=True, type=Path)
    args = parser.parse_args()
    envelope = args.envelope.resolve()
    if not envelope.is_file():
        raise FileNotFoundError(envelope)
    envelope_tree = ast.parse(envelope.read_text(encoding="utf-8"), filename=str(envelope))
    forbidden_subprocess_nodes = [
        node
        for node in ast.walk(envelope_tree)
        if (isinstance(node, ast.Import) and any(alias.name == "subprocess" for alias in node.names))
        or (isinstance(node, ast.ImportFrom) and node.module == "subprocess")
    ]
    if forbidden_subprocess_nodes:
        raise RuntimeError("Execution envelope imports subprocess; delegate must run in-process.")

    with tempfile.TemporaryDirectory(prefix="r18zt_env_") as temporary:
        root = Path(temporary)
        configuration = root / "configuration.json"
        write_text(
            configuration,
            json.dumps(
                {
                    "batchId": "R18ZT1",
                    "proposalRoot": str((root / "proposal_alias").resolve()),
                    "canonicalProposalRoot": str((root / "canonical").resolve()),
                }
            )
            + "\n",
        )

        success_delegate = root / "success.py"
        write_text(success_delegate, complete_delegate_source(0))
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

        post_complete_delegate = root / "post_complete_failure.py"
        write_text(post_complete_delegate, complete_delegate_source(9))
        post_complete_root = root / "post_complete"
        post_complete_root.mkdir()
        post_complete = invoke(envelope, post_complete_delegate, post_complete_root, configuration)
        if post_complete.returncode != 0:
            raise RuntimeError(f"Post-COMPLETE arbitration returned nonzero: {post_complete.stderr}")
        if (post_complete_root / "FAILURE.json").exists() or not (post_complete_root / "COMPLETE.json").is_file():
            raise RuntimeError("Post-COMPLETE arbitration created contradictory terminal leaves.")

        invalid_complete_delegate = root / "invalid_complete.py"
        write_text(
            invalid_complete_delegate,
            "import json\n"
            "from pathlib import Path\n"
            "def main(argv):\n"
            "    output=Path(argv[argv.index('--output-root')+1])\n"
            "    (output/'COMPLETE.json').write_text(json.dumps({'schema':'argos_opencv_scribe_r18zt_batch_complete_v2','state':'COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY'})+'\\n',encoding='utf-8')\n"
            "    return 9\n",
        )
        invalid_complete_root = root / "invalid_complete"
        invalid_complete_root.mkdir()
        invalid_complete = invoke(envelope, invalid_complete_delegate, invalid_complete_root, configuration)
        if invalid_complete.returncode == 0:
            raise RuntimeError("Invalid COMPLETE arbitration returned zero.")
        if (invalid_complete_root / "COMPLETE.json").exists():
            raise RuntimeError("Invalid COMPLETE remained at the terminal pointer.")
        if not (invalid_complete_root / "COMPLETE.invalid.json").is_file() or not (invalid_complete_root / "FAILURE.json").is_file():
            raise RuntimeError("Invalid COMPLETE was not quarantined before sole FAILURE.")

        failure_delegate = root / "failure.py"
        write_text(
            failure_delegate,
            "import sys\n"
            "def main(argv):\n"
            "    sys.stderr.write('synthetic failure\\n')\n"
            "    raise SystemExit(7)\n",
        )
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
        if failure_record.get("delegateExecutionMode") != "IN_PROCESS_PUBLIC_MAIN_NO_SUBPROCESS":
            raise RuntimeError("Injected failure did not prove in-process delegate execution.")

    print(
        json.dumps(
            {
                "schema": "argos_opencv_scribe_r18zt_batch_execution_envelope_gate_v2",
                "state": "PASS_R18ZT_BATCH_EXECUTION_ENVELOPE_GATE",
                "envelopeSha256": sha256_file(envelope),
                "successCase": True,
                "injectedFailureCase": True,
                "postCompleteFailureArbitrationCase": True,
                "invalidCompleteQuarantineCase": True,
                "completeFailureCoexistenceCount": 0,
                "delegateExecutionMode": "IN_PROCESS_PUBLIC_MAIN_NO_SUBPROCESS",
                "delegateSubprocessCount": 0,
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
