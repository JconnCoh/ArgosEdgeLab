#!/usr/bin/env python3
"""Package-excluded, non-image reference-isolation gate for R18T bytes."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import sys
import zipfile
from pathlib import Path
from typing import Any


FORBIDDEN_EXECUTABLE_LITERAL = re.compile(
    r"(?:\b[0-9]{5,6}[-_][0-9]{3}\b|\bslot[0-9]{1,3}\b|[A-Z]:\\)", re.IGNORECASE
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_runner(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("r18t_reference_isolation_gate", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runner", required=True, type=Path)
    parser.add_argument("--payload-manifest", required=True, type=Path)
    parser.add_argument("--payload-files-root", required=True, type=Path)
    parser.add_argument("--cohort", required=True, type=Path)
    parser.add_argument("--base-bundle", required=True, type=Path)
    parser.add_argument("--base-bundle-sha256", required=True)
    parser.add_argument("--base-manifest-sha256", required=True)
    parser.add_argument("--supplemental-manifest", required=True, type=Path)
    parser.add_argument("--supplemental-manifest-sha256", required=True)
    arguments = parser.parse_args(argv)

    require(sys.dont_write_bytecode, "Run the R18T reference gate with Python -B.")
    manifest = read_json(arguments.payload_manifest)
    require(
        manifest.get("schema") == "argos_opencv_scribe_r18t_payload_manifest_v1",
        "R18T payload-manifest schema changed.",
    )
    rows = list(manifest.get("files", []))
    require(bool(rows), "R18T payload manifest is empty.")
    test_name = Path(__file__).name.casefold()
    require(
        not any(
            Path(str(row.get(field, ""))).name.casefold() == test_name
            for row in rows
            for field in ("sourcePath", "installRelativePath")
        ),
        "R18T reference-isolation test entered the runtime payload.",
    )

    python_rows = [row for row in rows if str(row.get("installRelativePath", "")).casefold().endswith(".py")]
    require(bool(python_rows), "R18T payload has no Python runtime sources.")
    engine_paths = [
        arguments.payload_files_root / str(row["installRelativePath"]).replace("/", "\\")
        for row in python_rows
    ]
    require(
        len({str(path.resolve()).casefold() for path in engine_paths}) == len(engine_paths),
        "R18T Python runtime source list contains duplicates.",
    )
    require(
        arguments.runner.resolve() in {path.resolve() for path in engine_paths},
        "Frozen R18R scientific wrapper is absent from the R18T Python runtime set.",
    )
    executable_sources: dict[Path, str] = {}
    forbidden_literals: list[str] = []
    for path, row in zip(engine_paths, python_rows):
        require(path.is_file(), f"R18T Python runtime source is absent: {path}")
        require(path.stat().st_size == int(row["bytes"]), f"R18T Python runtime length changed: {path}")
        require(sha256_file(path) == str(row["sha256"]).upper(), f"R18T Python runtime hash changed: {path}")
        source = path.read_text(encoding="utf-8")
        executable_sources[path] = source
        forbidden_literals.extend(f"{path}:{match.group(0)}" for match in FORBIDDEN_EXECUTABLE_LITERAL.finditer(source))
    require(not forbidden_literals, f"R18T executable contains a concrete production identity/root: {forbidden_literals}")

    require(
        sha256_file(arguments.base_bundle) == arguments.base_bundle_sha256.upper(),
        "R18T base reference bundle changed.",
    )
    require(
        sha256_file(arguments.supplemental_manifest) == arguments.supplemental_manifest_sha256.upper(),
        "R18T supplemental reference manifest changed.",
    )
    with zipfile.ZipFile(arguments.base_bundle) as archive:
        member = "refs/PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
        require(member in archive.namelist(), f"R18T base reference bundle lacks {member}.")
        exact_base_member = archive.read(member)
        base = json.loads(exact_base_member.decode("utf-8-sig"))
    require(
        hashlib.sha256(exact_base_member).hexdigest().upper() == arguments.base_manifest_sha256.upper(),
        "R18T embedded base reference manifest changed.",
    )
    supplemental = read_json(arguments.supplemental_manifest)
    cohort = read_json(arguments.cohort)
    cases = list(cohort.get("reviewCases", []))
    require(bool(cases), "R18T cohort is empty.")
    require(int(cohort.get("caseCount", -1)) == len(cases), "R18T cohort declared count changed.")
    identities = [str(row["physicalIdentity"]) for row in cases]
    pairs = [(str(row["bfSha256"]).upper(), str(row["dfSha256"]).upper()) for row in cases]
    require(len({value.casefold() for value in identities}) == len(identities), "R18T cohort identities are not unique.")
    require(len(set(pairs)) == len(pairs), "R18T cohort source pairs are not unique.")

    runner = load_runner(arguments.runner)

    class Reference:
        def __init__(self, physical_identity: str) -> None:
            self.physical_identity = physical_identity

    reference_identities = sorted(
        {
            str(row.get("physicalIdentity", ""))
            for row in list(base["references"]) + list(supplemental["references"])
            if row.get("physicalIdentity")
        },
        key=str.casefold,
    )
    bank = [Reference(value) for value in reference_identities]
    excluded_counts: list[int] = []
    for case, pair in zip(cases, pairs):
        filtered = runner.exclude_case_reference_lineage(
            bank,
            list(bank),
            list(bank),
            str(case["physicalIdentity"]),
            set(pair),
            list(supplemental["references"]),
        )
        case_lineage = runner.R18P.physical_lineage_key(str(case["physicalIdentity"]))
        retained_lineages: set[str] = set()
        for reference in filtered[0]:
            try:
                retained_lineages.add(runner.R18P.physical_lineage_key(reference.physical_identity))
            except ValueError:
                pass
        require(case_lineage not in retained_lineages, "A same-lineage reference survived R18T isolation.")
        excluded_counts.append(int(filtered[3]["excludedPrototypeCount"]))

    truth_rows = [row for row in cases if row.get("expectedTruth")]
    require(bool(truth_rows), "R18T cohort has no image-first verification controls.")
    configured_literals = identities + [str(row["expectedTruth"]) for row in truth_rows]
    leaks = [
        f"{path}:{literal}"
        for path, source in executable_sources.items()
        for literal in configured_literals
        if literal.casefold() in source.casefold()
    ]
    require(not leaks, f"R18T configuration identity/truth leaked into executable source: {leaks}")
    truth_indexes = [index for index, row in enumerate(cases) if row.get("expectedTruth")]
    require(
        min(excluded_counts[index] for index in truth_indexes) > 0,
        "An R18T image-first control excluded no same-lineage reference.",
    )

    print(
        json.dumps(
            {
                "schema": "argos_opencv_scribe_r18t_reference_isolation_gate_v1",
                "state": "PASS_R18T_REFERENCE_ISOLATION_GATE",
                "cohortCaseCount": len(cases),
                "uniqueSourcePairCount": len(set(pairs)),
                "imageFirstControlCount": len(truth_rows),
                "minimumExcludedReferenceIdentityCount": min(excluded_counts),
                "maximumExcludedReferenceIdentityCount": max(excluded_counts),
                "pythonRuntimeSourceCount": len(engine_paths),
                "engineHashMismatchCount": 0,
                "concreteExecutableLiteralCount": len(forbidden_literals),
                "configurationLiteralLeakCount": len(leaks),
                "sameLineageReferenceSurvivorCount": 0,
                "allCardinalitiesDerivedFromCollections": True,
                "packageExcluded": True,
                "imageBytesRead": False,
                "pixelsDecoded": False,
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
