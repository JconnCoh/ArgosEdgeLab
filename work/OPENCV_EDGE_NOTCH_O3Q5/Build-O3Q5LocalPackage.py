#!/usr/bin/env python3
"""Preflight and create the bounded O3Q5 local consumer package exactly once."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
from typing import Any
import zipfile


PACKAGE_SCHEMA = "argos_ocv03_o3q5_local_consumer_package_v1"
CONTRACT_SCHEMA = "argos_ocv03_o3q5_job_runtime_contract_v1"
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
EXPECTED_PACKAGE_PATHS = {
    "O3Q5_RUNTIME_GATE_ADAPTER": "payload/OPENCV_EDGE_NOTCH_O3Q5/Detect-O3Q5FrontSplitNotches.py",
    "FROZEN_O3P8_DETECTOR": "payload/OPENCV_EDGE_NOTCH_O3P8/Detect-O3P8FrontSplitNotches.py",
    "EXACT_FILE_BACKED_RUNTIME_GATE": "payload/runtime/O3Q4_RUNTIME_GATE.json",
    "JOB_PINNED_RUNTIME_CONTRACT": "payload/contracts/O3Q5_JOB_RUNTIME_CONTRACT.json",
}
ZIP_TIMESTAMP = (2026, 8, 28, 0, 0, 0)


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


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON root must be an object: {path}")
    return value


def safe_relative_path(raw: Any, label: str) -> PurePosixPath:
    value = str(raw)
    require(value and "\\" not in value and not value.startswith("/"), f"Unsafe {label}: {value}")
    raw_parts = value.split("/")
    require(all(part not in ("", ".", "..") for part in raw_parts), f"Unsafe {label}: {value}")
    path = PurePosixPath(value)
    require(not path.is_absolute(), f"Unsafe {label}: {value}")
    return path


def validate_authority(value: dict[str, Any]) -> None:
    require(value.get("reviewOnly") is True, "Package is not review-only.")
    for field in (
        "trainingEligible",
        "xmlEligible",
        "productionEligible",
        "productionRoutingEnabled",
        "liveRequestAuthorized",
        "providerActivationAllowed",
        "runtimeReobservationAllowed",
        "imageReadAllowed",
        "sourceMutationAllowed",
        "sourceDeletionAllowed",
        "taskActionAllowed",
        "processActionAllowed",
        "holdClearanceAllowed",
        "thresholdOrAlgorithmChangeAllowed",
    ):
        require(value.get(field) is False, f"Forbidden package authority changed: {field}")


def validate_runtime_contract(gate: dict[str, Any], contract: dict[str, Any], binding: dict[str, Any]) -> None:
    require(contract.get("schema") == CONTRACT_SCHEMA, "Job-runtime contract schema changed.")
    require(contract.get("state") == "LOCKED_INPUT", "Job-runtime contract state changed.")
    required = contract.get("requiredJobFields")
    require(isinstance(required, dict), "Job-runtime required fields are absent.")
    comparisons = {
        "expectedRuntimeGateSchema": binding.get("schema"),
        "expectedRuntimeGateState": binding.get("state"),
        "expectedRuntimeTargetRole": binding.get("targetRole"),
        "expectedPythonVersion": binding.get("pythonVersion"),
        "expectedRuntimeSha256": binding.get("pythonSha256"),
        "expectedRuntimeInstallationSha256": binding.get("installationSha256"),
        "expectedOpenCvVersion": binding.get("opencvVersion"),
        "expectedNumpyVersion": binding.get("numpyVersion"),
    }
    require(required == comparisons, "Job-runtime fields do not match the package runtime binding.")
    require(gate.get("schema") == binding.get("schema"), "Runtime-gate schema changed.")
    require(gate.get("state") == binding.get("state"), "Runtime-gate state changed.")
    require(gate.get("targetRole") == binding.get("targetRole") == "JBOD", "Runtime target role changed.")
    require(gate.get("python", {}).get("version") == binding.get("pythonVersion"), "Python version changed.")
    require(str(gate.get("python", {}).get("sha256", "")).upper() == binding.get("pythonSha256"), "Python hash changed.")
    require(str(gate.get("installation", {}).get("sha256", "")).upper() == binding.get("installationSha256"), "Installation hash changed.")
    require(gate.get("opencvVersion") == binding.get("opencvVersion"), "OpenCV version changed.")
    require(gate.get("numpyVersion") == binding.get("numpyVersion"), "NumPy version changed.")


def inspect(manifest_path: Path) -> dict[str, Any]:
    manifest_path = manifest_path.resolve(strict=True)
    repo_root = Path(__file__).resolve().parents[2]
    manifest = read_json(manifest_path)
    require(manifest.get("schema") == PACKAGE_SCHEMA, "Local package schema changed.")
    require(manifest.get("state") == "DRAFT_LOCAL_BUILD", "Local package is not an unbuilt draft.")
    validate_authority(manifest.get("authority", {}))

    path_gate = manifest.get("pathSafetyGate", {})
    path_gate_path = (repo_root / str(path_gate.get("path"))).resolve(strict=True)
    require(sha256_file(path_gate_path) == str(path_gate.get("sha256", "")).upper(), "Path gate changed.")
    preaction = manifest.get("preactionContract", {})
    preaction_path = (repo_root / str(preaction.get("path"))).resolve(strict=True)
    preaction_value = read_json(preaction_path)
    require(preaction_value.get("schema") == preaction.get("schema"), "Preaction schema changed.")
    require(preaction_value.get("revision") == preaction.get("revision"), "Preaction revision changed.")
    require(preaction_value.get("state") == preaction.get("requiredState"), "Preaction contract is not PASS.")

    manifest_member = safe_relative_path(manifest.get("packageManifestPath"), "package manifest path")
    payload = manifest.get("payload")
    require(isinstance(payload, list) and len(payload) == 4, "Package payload set changed.")
    records: list[dict[str, Any]] = []
    roles: set[str] = set()
    package_paths: set[str] = {str(manifest_member)}
    for raw_record in payload:
        require(isinstance(raw_record, dict), "Payload record is not an object.")
        role = str(raw_record.get("role"))
        require(role in EXPECTED_ROLE_HASHES and role not in roles, f"Unexpected or duplicate payload role: {role}")
        roles.add(role)
        source_relative = safe_relative_path(raw_record.get("sourcePath"), f"{role} source path")
        package_path = safe_relative_path(raw_record.get("packagePath"), f"{role} package path")
        require(str(package_path) == EXPECTED_PACKAGE_PATHS[role], f"Package layout changed for {role}.")
        require(str(package_path) not in package_paths, f"Duplicate package path: {package_path}")
        package_paths.add(str(package_path))
        source = (repo_root / Path(*source_relative.parts)).resolve(strict=True)
        declared_hash = str(raw_record.get("sha256", "")).upper()
        require(declared_hash == EXPECTED_ROLE_HASHES[role], f"Pinned hash changed for {role}.")
        require(sha256_file(source) == declared_hash, f"Source bytes changed for {role}.")
        records.append({"role": role, "source": source, "packagePath": str(package_path), "sha256": declared_hash})
    require(roles == set(EXPECTED_ROLE_HASHES), "Package roles are incomplete.")

    nested = manifest.get("requiredNestedRelationship", {})
    require(nested.get("adapterPackagePath") == EXPECTED_PACKAGE_PATHS["O3Q5_RUNTIME_GATE_ADAPTER"], "Adapter package path changed.")
    require(nested.get("frozenEnginePackagePath") == EXPECTED_PACKAGE_PATHS["FROZEN_O3P8_DETECTOR"], "Frozen-engine package path changed.")
    adapter_parent = PurePosixPath(str(nested["adapterPackagePath"])).parent.parent
    expected_engine = adapter_parent / "OPENCV_EDGE_NOTCH_O3P8" / "Detect-O3P8FrontSplitNotches.py"
    require(str(expected_engine) == nested["frozenEnginePackagePath"], "Adapter cannot resolve its packaged frozen engine.")

    by_role = {record["role"]: record for record in records}
    gate = read_json(by_role["EXACT_FILE_BACKED_RUNTIME_GATE"]["source"])
    contract = read_json(by_role["JOB_PINNED_RUNTIME_CONTRACT"]["source"])
    validate_runtime_contract(gate, contract, manifest.get("runtimeBinding", {}))

    withdrawn = manifest.get("withdrawnArtifactBoundary", {})
    require(withdrawn.get("withdrawnArtifactIds") == ["O3Q2", "O3Q4"], "Withdrawn-artifact set changed.")
    require(withdrawn.get("endpointOrExecutionParentInherited") is False, "Withdrawn endpoint parent was inherited.")
    require(withdrawn.get("exactRuntimeEvidenceRetainedAsLockedInput") is True, "Runtime evidence is not a locked input.")

    output_relative = safe_relative_path(manifest.get("outputRelativePath"), "output path")
    output = (repo_root / Path(*output_relative.parts)).resolve(strict=False)
    partial = output.with_name(output.name + ".partial")
    require(output.parent.parent.is_dir(), "Package output ancestor is absent.")
    require(not output.exists() and not partial.exists(), "Package output must be create-new.")

    reserve = int(path_gate.get("suffixReserve"))
    limit = int(path_gate.get("maximumEffectiveLengthExclusive"))
    component_limit = int(path_gate.get("maximumComponentLength"))
    test_root = output.parent / "rehearsal_extraction"
    evaluated = [output, partial, manifest_path]
    evaluated.extend(test_root / Path(*PurePosixPath(value).parts) for value in package_paths)
    maximum_effective_length = max(len(str(path)) + reserve for path in evaluated)
    maximum_component_length = max(len(part) for path in evaluated for part in path.parts)
    require(maximum_effective_length < limit, "Package path budget is unsafe.")
    require(maximum_component_length <= component_limit, "Package component length is unsafe.")
    return {
        "manifestPath": manifest_path,
        "manifest": manifest,
        "manifestMember": str(manifest_member),
        "records": records,
        "output": output,
        "partial": partial,
        "maximumEffectiveLength": maximum_effective_length,
        "maximumComponentLength": maximum_component_length,
    }


def zip_info(name: str) -> zipfile.ZipInfo:
    value = zipfile.ZipInfo(name, date_time=ZIP_TIMESTAMP)
    value.compress_type = zipfile.ZIP_DEFLATED
    value.create_system = 3
    value.external_attr = 0o100644 << 16
    return value


def build(details: dict[str, Any]) -> dict[str, Any]:
    output: Path = details["output"]
    partial: Path = details["partial"]
    output.parent.mkdir(parents=False, exist_ok=False)
    try:
        with zipfile.ZipFile(partial, "x") as archive:
            archive.writestr(zip_info(details["manifestMember"]), details["manifestPath"].read_bytes())
            for record in sorted(details["records"], key=lambda value: value["packagePath"]):
                archive.writestr(zip_info(record["packagePath"]), record["source"].read_bytes())
        with zipfile.ZipFile(partial, "r") as archive:
            expected_names = {details["manifestMember"]} | {record["packagePath"] for record in details["records"]}
            require(set(archive.namelist()) == expected_names, "Built package member set changed.")
            require(sha256_bytes(archive.read(details["manifestMember"])) == sha256_file(details["manifestPath"]), "Packaged manifest changed.")
            for record in details["records"]:
                require(sha256_bytes(archive.read(record["packagePath"])) == record["sha256"], f"Packaged bytes changed for {record['role']}.")
            require(archive.testzip() is None, "Built package failed its CRC test.")
        partial.replace(output)
    except Exception:
        if partial.exists():
            partial.unlink()
        if output.parent.exists() and not any(output.parent.iterdir()):
            output.parent.rmdir()
        raise
    return {
        "state": "PASS_O3Q5_LOCAL_PACKAGE_BUILD",
        "manifestSha256": sha256_file(details["manifestPath"]),
        "packagePath": str(output),
        "packageSha256": sha256_file(output),
        "payloadCount": len(details["records"]),
        "maximumEffectiveLength": details["maximumEffectiveLength"],
        "maximumComponentLength": details["maximumComponentLength"],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--preflight", action="store_true")
    action.add_argument("--build", action="store_true")
    arguments = parser.parse_args()
    details = inspect(Path(arguments.manifest))
    if arguments.preflight:
        result = {
            "state": "PASS_O3Q5_LOCAL_PACKAGE_PREFLIGHT",
            "manifestSha256": sha256_file(details["manifestPath"]),
            "payloadCount": len(details["records"]),
            "outputPath": str(details["output"]),
            "outputParentExists": details["output"].parent.exists(),
            "maximumEffectiveLength": details["maximumEffectiveLength"],
            "maximumComponentLength": details["maximumComponentLength"],
        }
    else:
        result = build(details)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
