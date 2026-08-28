#!/usr/bin/env python3
"""Validate and exercise the exact O3Q5 local package without image reads."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tempfile
from typing import Any
import zipfile


PACKAGE_SCHEMA = "argos_ocv03_o3q5_local_consumer_package_v1"
CONTRACT_TEST_SHA256 = "9E1B2C693ADF9B18ECCE302EF60FF7708B1EC73F7E680A03E48376039C585271"
ADAPTER_SHA256 = "4A641397B787767ECCAABF3345499AF0E9E5F0C26F7EE8498CF58319E07D85F3"
ENGINE_SHA256 = "41F60AF393E0B2C752AF6B33BB6673145490AE2BB346A4DA8E59A2D42E383E36"
GATE_SHA256 = "09DEEF0BC1C0DC9464F5BF5CE93EF590F2780F3123BB13AB6080358E562C68C4"
CONTRACT_SHA256 = "9BEE718266F63F4576AE3821E8A19548A285DF3BCFC62F5070532F4FAC9555A7"
EXPECTED_ROLE_HASHES = {
    "O3Q5_RUNTIME_GATE_ADAPTER": ADAPTER_SHA256,
    "FROZEN_O3P8_DETECTOR": ENGINE_SHA256,
    "EXACT_FILE_BACKED_RUNTIME_GATE": GATE_SHA256,
    "JOB_PINNED_RUNTIME_CONTRACT": CONTRACT_SHA256,
}
EXPECTED_CASE_IDS = {
    "EXACT_O3Q4_GATE",
    "WRONG_GATE_HASH",
    "WRONG_EXPECTED_STATE",
    "FAILED_GATE_STATE",
    "WRONG_GATE_NUMPY_VERSION",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def safe_member(raw: str) -> PurePosixPath:
    require(raw and "\\" not in raw and not raw.startswith("/"), f"Unsafe ZIP member: {raw}")
    require(all(part not in ("", ".", "..") for part in raw.split("/")), f"Unsafe ZIP member: {raw}")
    path = PurePosixPath(raw)
    require(not path.is_absolute(), f"Unsafe ZIP member: {raw}")
    return path


def read_object(value: bytes, label: str) -> dict[str, Any]:
    parsed = json.loads(value.decode("utf-8"))
    require(isinstance(parsed, dict), f"{label} root is not an object.")
    return parsed


def inspect(manifest_path: Path) -> dict[str, Any]:
    manifest_path = manifest_path.resolve(strict=True)
    repo_root = Path(__file__).resolve().parents[2]
    manifest_bytes = manifest_path.read_bytes()
    manifest = read_object(manifest_bytes, "Package manifest")
    require(manifest.get("schema") == PACKAGE_SCHEMA, "Local package schema changed.")
    output = (repo_root / str(manifest.get("outputRelativePath"))).resolve(strict=True)
    require(output.is_file(), "Local package output is absent.")
    manifest_member = str(safe_member(str(manifest.get("packageManifestPath"))))

    payload = manifest.get("payload")
    require(isinstance(payload, list) and len(payload) == 4, "Package payload set changed.")
    records: list[dict[str, str]] = []
    roles: set[str] = set()
    for raw_record in payload:
        require(isinstance(raw_record, dict), "Payload record is not an object.")
        role = str(raw_record.get("role"))
        require(role in EXPECTED_ROLE_HASHES and role not in roles, f"Unexpected or duplicate role: {role}")
        roles.add(role)
        member = str(safe_member(str(raw_record.get("packagePath"))))
        declared_hash = str(raw_record.get("sha256", "")).upper()
        require(declared_hash == EXPECTED_ROLE_HASHES[role], f"Pinned hash changed for {role}.")
        records.append({"role": role, "member": member, "sha256": declared_hash})
    require(roles == set(EXPECTED_ROLE_HASHES), "Package roles are incomplete.")

    with zipfile.ZipFile(output, "r") as archive:
        infos = archive.infolist()
        names = [info.filename for info in infos]
        expected_names = {manifest_member} | {record["member"] for record in records}
        require(len(names) == len(set(names)) and set(names) == expected_names, "Package member set changed.")
        for info in infos:
            safe_member(info.filename)
            require(not info.is_dir(), f"Unexpected package directory member: {info.filename}")
            require((info.external_attr >> 16) & 0o170000 == 0o100000, f"Package member is not a regular file: {info.filename}")
        require(archive.read(manifest_member) == manifest_bytes, "Packaged manifest bytes changed.")
        for record in records:
            require(sha256_bytes(archive.read(record["member"])) == record["sha256"], f"Packaged bytes changed for {record['role']}.")
        require(archive.testzip() is None, "Package failed its CRC test.")
        by_role = {record["role"]: record for record in records}
        gate = read_object(archive.read(by_role["EXACT_FILE_BACKED_RUNTIME_GATE"]["member"]), "Runtime gate")
        contract = read_object(archive.read(by_role["JOB_PINNED_RUNTIME_CONTRACT"]["member"]), "Job-runtime contract")

    binding = manifest.get("runtimeBinding", {})
    required = contract.get("requiredJobFields", {})
    require(contract.get("state") == "LOCKED_INPUT", "Packaged job-runtime contract is not locked.")
    require(contract.get("packagedRuntimeGateSha256") == GATE_SHA256, "Contract runtime-gate hash changed.")
    require(required.get("expectedRuntimeGateSchema") == binding.get("schema") == gate.get("schema"), "Runtime-gate schema binding changed.")
    require(required.get("expectedRuntimeGateState") == binding.get("state") == gate.get("state"), "Runtime-gate state binding changed.")
    require(required.get("expectedRuntimeTargetRole") == binding.get("targetRole") == gate.get("targetRole") == "JBOD", "Runtime target binding changed.")
    require(required.get("expectedPythonVersion") == binding.get("pythonVersion") == gate.get("python", {}).get("version"), "Python version binding changed.")
    require(required.get("expectedRuntimeSha256") == binding.get("pythonSha256") == str(gate.get("python", {}).get("sha256", "")).upper(), "Python hash binding changed.")
    require(required.get("expectedRuntimeInstallationSha256") == binding.get("installationSha256") == str(gate.get("installation", {}).get("sha256", "")).upper(), "Installation hash binding changed.")
    require(required.get("expectedOpenCvVersion") == binding.get("opencvVersion") == gate.get("opencvVersion"), "OpenCV binding changed.")
    require(required.get("expectedNumpyVersion") == binding.get("numpyVersion") == gate.get("numpyVersion"), "NumPy binding changed.")
    return {
        "manifestPath": manifest_path,
        "manifestSha256": sha256_bytes(manifest_bytes),
        "packagePath": output,
        "packageSha256": sha256_file(output),
        "manifestMember": manifest_member,
        "records": records,
    }


def run_contract_test(details: dict[str, Any], contract_test: Path, python_path: Path) -> dict[str, Any]:
    contract_test = contract_test.resolve(strict=True)
    python_path = python_path.resolve(strict=True)
    require(python_path.is_dir(), "Contract-test PYTHONPATH is not a directory.")
    require(sha256_file(contract_test) == CONTRACT_TEST_SHA256, "Runtime consumer contract test changed.")
    by_role = {record["role"]: record for record in details["records"]}
    package_path: Path = details["packagePath"]
    with tempfile.TemporaryDirectory(prefix="rehearsal_", dir=package_path.parent) as temporary:
        extraction_root = Path(temporary)
        with zipfile.ZipFile(package_path, "r") as archive:
            archive.extractall(extraction_root)
        candidate = extraction_root / Path(*PurePosixPath(by_role["O3Q5_RUNTIME_GATE_ADAPTER"]["member"]).parts)
        engine = extraction_root / Path(*PurePosixPath(by_role["FROZEN_O3P8_DETECTOR"]["member"]).parts)
        gate = extraction_root / Path(*PurePosixPath(by_role["EXACT_FILE_BACKED_RUNTIME_GATE"]["member"]).parts)
        require(sha256_file(candidate) == ADAPTER_SHA256, "Extracted adapter changed.")
        require(sha256_file(engine) == ENGINE_SHA256, "Extracted frozen engine changed.")
        require(sha256_file(gate) == GATE_SHA256, "Extracted runtime gate changed.")
        environment = dict(os.environ)
        environment["PYTHONPATH"] = str(python_path)
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        command = [
            sys.executable,
            "-B",
            str(contract_test),
            "--candidate",
            str(candidate),
            "--exact-runtime-gate",
            str(gate),
        ]
        completed = subprocess.run(
            command,
            cwd=extraction_root,
            env=environment,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        require(len(completed.stdout) <= 65536 and len(completed.stderr) <= 65536, "Contract-test output exceeded the bound.")
        require(completed.returncode == 0, f"Packaged consumer contract test failed: {completed.stderr.strip()}")
        lines = [line for line in completed.stdout.splitlines() if line.strip()]
        require(lines, "Packaged consumer contract test returned no JSON.")
        result = json.loads(lines[-1])
        require(result.get("state") == "PASS_O3Q5_EXACT_RUNTIME_GATE_CONSUMER", "Packaged consumer state is not PASS.")
        require(result.get("candidateSha256") == ADAPTER_SHA256, "Packaged consumer candidate hash changed.")
        require(result.get("exactRuntimeGateSha256") == GATE_SHA256, "Packaged consumer gate hash changed.")
        require(result.get("imageReadCount") == 0, "Packaged consumer test read image bytes.")
        cases = result.get("cases")
        require(isinstance(cases, list), "Packaged consumer cases are absent.")
        require({case.get("caseId") for case in cases} == EXPECTED_CASE_IDS, "Packaged consumer case set changed.")
        require(all(case.get("passed") is True for case in cases), "A packaged consumer case failed.")
        return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--contract-test", required=True)
    parser.add_argument("--python-path", required=True)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--preflight", action="store_true")
    action.add_argument("--test", action="store_true")
    arguments = parser.parse_args()
    details = inspect(Path(arguments.manifest))
    contract_test = Path(arguments.contract_test)
    python_path = Path(arguments.python_path)
    require(contract_test.resolve(strict=True).is_file(), "Contract test is absent.")
    require(sha256_file(contract_test.resolve()) == CONTRACT_TEST_SHA256, "Contract test changed.")
    require(python_path.resolve(strict=True).is_dir(), "Contract-test PYTHONPATH is absent.")
    if arguments.preflight:
        output = {
            "state": "PASS_O3Q5_LOCAL_PACKAGE_TEST_PREFLIGHT",
            "manifestSha256": details["manifestSha256"],
            "packageSha256": details["packageSha256"],
            "memberCount": len(details["records"]) + 1,
            "contractTestSha256": CONTRACT_TEST_SHA256,
        }
    else:
        result = run_contract_test(details, contract_test, python_path)
        output = {
            "state": "PASS_O3Q5_LOCAL_PACKAGE_CONSUMER_TEST",
            "manifestSha256": details["manifestSha256"],
            "packageSha256": details["packageSha256"],
            "adapterSha256": ADAPTER_SHA256,
            "frozenEngineSha256": ENGINE_SHA256,
            "runtimeGateSha256": GATE_SHA256,
            "jobRuntimeContractSha256": CONTRACT_SHA256,
            "contractTestSha256": CONTRACT_TEST_SHA256,
            "cases": result["cases"],
            "imageReadCount": result["imageReadCount"],
            "liveActionCount": 0,
        }
    print(json.dumps(output, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
