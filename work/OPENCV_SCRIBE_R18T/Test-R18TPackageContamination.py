#!/usr/bin/env python3
"""Package-excluded contamination scan for an exact staged/extracted R18T payload."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


CONCRETE_IDENTITY = re.compile(r"(?:\b[0-9]{5,6}[-_][0-9]{3}\b|\bslot[0-9]{1,3}\b)", re.IGNORECASE)
FIXED_CORPUS_COUNT = re.compile(
    r"(?:"
    r"(?:case|payload|zip|path|member|python|sourcepair|identity)[A-Za-z0-9_]*count\s*-(?:eq|ne|gt|ge|lt|le)\s*\d+"
    r"|len\s*\([^\r\n]+\)\s*(?:==|!=|>=|<=|>|<)\s*\d+"
    r"|(?:expected|configured)(?:case|payload|zip|path|member|python|sourcepair|identity)[A-Za-z0-9_]*count\s*=\s*\d+"
    r")",
    re.IGNORECASE,
)
TEST_CONTROL = re.compile(r"(?:INJECTED_|MONKEYPATCH|MetadataProxy|SELECTIVE_MISSING_CHECKSUM)", re.IGNORECASE)
RUNTIME_OVERRIDE_ARGUMENT = re.compile(r"--[^\s\"']*(?:checksum|threshold|test|hook|override)", re.IGNORECASE)
RUNTIME_OVERRIDE_ASSIGNMENT = re.compile(
    r"(?:configuration|config)(?:\.[A-Za-z0-9_]+)*\.(?:checksum|threshold|test|hook|monkeypatch|override)[A-Za-z0-9_]*\s*=",
    re.IGNORECASE,
)
FORBIDDEN_LOCAL_TOKENS = (
    "62629-401_20260902002921_Slot24",
    "F67972F31B30C9BE42615DF7FBDC0E64D642F89860A38F4D8172365C7C261201",
    "2D4B7AC5861BE87B2876842C3010B15E268DC7150FFAF84B290EF01E9BFC1386",
    r"C:\R18J_CORPUS_FIXTURE",
    r"C:\R18IR8",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--payload-root", required=True, type=Path)
    parser.add_argument("--payload-manifest", required=True, type=Path)
    parser.add_argument("--launcher", required=True, type=Path)
    parser.add_argument("--launcher-sha256", required=True)
    arguments = parser.parse_args(argv)

    require(sys.dont_write_bytecode, "Run the R18T contamination gate with Python -B.")
    payload_root = arguments.payload_root.resolve()
    manifest = read_json(arguments.payload_manifest)
    require(manifest.get("schema") == "argos_opencv_scribe_r18t_payload_manifest_v1", "R18T manifest schema changed.")
    rows = list(manifest.get("files", []))
    require(bool(rows), "R18T payload manifest is empty.")
    require(arguments.launcher.is_file(), "R18T launcher is absent.")
    require(sha256_file(arguments.launcher) == arguments.launcher_sha256.upper(), "R18T launcher hash changed.")

    runtime_paths: list[tuple[str, Path]] = []
    member_names: list[str] = []
    for row in rows:
        member = str(row["installRelativePath"]).replace("\\", "/")
        require(not Path(member).is_absolute() and ".." not in Path(member).parts, f"Unsafe R18T payload member: {member}")
        path = payload_root / "files" / Path(member.replace("/", "\\"))
        require(path.is_file(), f"R18T payload member is absent: {member}")
        require(path.stat().st_size == int(row["bytes"]), f"R18T payload member length changed: {member}")
        require(sha256_file(path) == str(row["sha256"]).upper(), f"R18T payload member hash changed: {member}")
        runtime_paths.append((member, path))
        member_names.append(member)
    require(len({name.casefold() for name in member_names}) == len(member_names), "R18T payload member names are not unique.")

    forbidden_members = [
        member
        for member in member_names
        if re.search(r"(?:^|/)(?:Test[^/]*|fixtures?|[^/]*fixture[^/]*|hooks?|__pycache__)(?:/|$)|\.pyc$|LOCAL_GATE|SUPERSEDED", member, re.IGNORECASE)
    ]
    require(not forbidden_members, f"R18T package contains test/gate runtime members: {forbidden_members}")

    executable_paths = [
        (member, path)
        for member, path in runtime_paths
        if path.suffix.casefold() in {".py", ".ps1", ".psm1"}
    ]
    executable_paths.append(("Invoke-R18TLiveOnlyLaunch.ps1", arguments.launcher))
    concrete_literals: list[str] = []
    local_token_hits: list[str] = []
    for member, path in executable_paths:
        source = path.read_text(encoding="utf-8-sig")
        concrete_literals.extend(f"{member}:{match.group(0)}" for match in CONCRETE_IDENTITY.finditer(source))
        local_token_hits.extend(f"{member}:{token}" for token in FORBIDDEN_LOCAL_TOKENS if token.casefold() in source.casefold())
    require(not concrete_literals, f"R18T executable contains concrete identity literals: {concrete_literals}")
    require(not local_token_hits, f"R18T executable contains local Slot24/fixture contamination: {local_token_hits}")

    new_envelope = [
        (member, path)
        for member, path in executable_paths
        if member.replace("\\", "/").casefold().startswith("opencv_scribe_r18t/")
        or member.casefold() == "invoke-r18tliveonlylaunch.ps1"
    ]
    require(bool(new_envelope), "R18T package has no execution-envelope sources.")
    fixed_counts: list[str] = []
    test_controls: list[str] = []
    override_arguments: list[str] = []
    override_assignments: list[str] = []
    anonymous_pipe_redirects: list[str] = []
    enabled_forbidden_semantics: list[str] = []
    for member, path in new_envelope:
        source = path.read_text(encoding="utf-8-sig")
        fixed_counts.extend(f"{member}:{match.group(0)}" for match in FIXED_CORPUS_COUNT.finditer(source))
        test_controls.extend(f"{member}:{match.group(0)}" for match in TEST_CONTROL.finditer(source))
        override_arguments.extend(f"{member}:{match.group(0)}" for match in RUNTIME_OVERRIDE_ARGUMENT.finditer(source))
        override_assignments.extend(f"{member}:{match.group(0)}" for match in RUNTIME_OVERRIDE_ASSIGNMENT.finditer(source))
        if re.search(
            r"RedirectStandard(?:Output|Error)\s*=\s*\$true|subprocess\.(?:PIPE|Popen)|\bStart-Process\b",
            source,
            re.IGNORECASE,
        ):
            anonymous_pipe_redirects.append(member)
        if re.search(
            r"(?:wholeWaferFallbackAllowed|lineGridOrNotchAlignmentUsed|syntheticDotReconstructionAllowed)\s*[:=]\s*(?:\$true|true)",
            source,
            re.IGNORECASE,
        ):
            enabled_forbidden_semantics.append(member)
    require(not fixed_counts, f"R18T envelope encodes a fixed corpus count: {fixed_counts}")
    require(not test_controls, f"R18T envelope contains runtime test controls: {test_controls}")
    require(not override_arguments and not override_assignments, "R18T envelope contains a runtime override.")
    require(not anonymous_pipe_redirects, f"R18T envelope contains anonymous worker pipes: {anonymous_pipe_redirects}")
    require(not enabled_forbidden_semantics, f"R18T envelope enables a forbidden image semantic: {enabled_forbidden_semantics}")

    all_text_paths = [("R18T_PAYLOAD_MANIFEST.json", arguments.payload_manifest), ("Invoke-R18TLiveOnlyLaunch.ps1", arguments.launcher)] + [
        (member, path) for member, path in runtime_paths if path.suffix.casefold() in {".json", ".py", ".ps1", ".psm1", ".md", ".txt", ".csv"}
    ]
    package_local_hits: list[str] = []
    for member, path in all_text_paths:
        source = path.read_text(encoding="utf-8-sig")
        package_local_hits.extend(f"{member}:{token}" for token in FORBIDDEN_LOCAL_TOKENS if token.casefold() in source.casefold())
    require(not package_local_hits, f"R18T package contains Slot24/local-fixture bytes: {package_local_hits}")

    print(
        json.dumps(
            {
                "schema": "argos_opencv_scribe_r18t_package_contamination_gate_v1",
                "state": "PASS_R18T_PACKAGE_CONTAMINATION_GATE",
                "payloadFileCount": len(rows),
                "executableFileCount": len(executable_paths),
                "newEnvelopeExecutableCount": len(new_envelope),
                "runtimeTestArtifactCount": len(forbidden_members),
                "concreteExecutableIdentityLiteralCount": len(concrete_literals),
                "slot24OrLocalFixtureTokenCount": len(package_local_hits),
                "fixedExpectedCorpusCountTokenCount": len(fixed_counts),
                "runtimeTestControlCount": len(test_controls),
                "runtimeOverrideCount": len(override_arguments) + len(override_assignments),
                "anonymousPipeRedirectCount": len(anonymous_pipe_redirects),
                "enabledWholeWaferNotchOrSyntheticDotCount": len(enabled_forbidden_semantics),
                "allCardinalitiesDerivedFromCollections": True,
                "packageExcluded": True,
                "pixelsDecoded": False,
                "sourceWaferImagesRead": False,
                "externalAccess": False,
                "mutationsPerformed": False,
                "identityAccepted": False,
                "reviewOnly": True,
                "productionRoutingEnabled": False,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
