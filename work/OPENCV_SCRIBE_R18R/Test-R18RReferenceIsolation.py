#!/usr/bin/env python3
"""Non-image gate for R18R reference isolation and cohort integrity."""

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


FORBIDDEN_ENGINE_LITERAL = re.compile(
    r"(?:\b[0-9]{5}[-_][0-9]{3}\b|\bslot[0-9]{1,3}\b|[A-Z]:\\)", re.IGNORECASE,
)


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_base_manifest(bundle: Path) -> dict[str, Any]:
    with zipfile.ZipFile(bundle) as archive:
        member = "refs/PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
        if member not in archive.namelist():
            raise AssertionError(f"Base reference bundle lacks {member}.")
        return json.loads(archive.read(member).decode("utf-8-sig"))


def load_runner(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("r18r_reference_isolation_gate", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runner", required=True, type=Path)
    parser.add_argument("--payload-manifest", required=True, type=Path)
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--cohort", required=True, type=Path)
    parser.add_argument("--base-bundle", required=True, type=Path)
    parser.add_argument("--base-bundle-sha256", required=True)
    parser.add_argument("--base-manifest-sha256", required=True)
    parser.add_argument("--supplemental-manifest", required=True, type=Path)
    parser.add_argument("--supplemental-manifest-sha256", required=True)
    arguments = parser.parse_args()

    if not sys.dont_write_bytecode:
        raise RuntimeError("Run this non-mutating gate with Python -B.")
    payload_manifest = read_json(arguments.payload_manifest)
    manifest_rows = list(payload_manifest.get("files", []))
    test_name = Path(__file__).name.casefold()
    if any(
        Path(str(row.get(field, ""))).name.casefold() == test_name
        for row in manifest_rows
        for field in ("sourcePath", "installRelativePath")
    ):
        raise AssertionError("The R18R reference-isolation test must remain package-excluded.")
    engine_rows = [
        row for row in manifest_rows
        if str(row.get("installRelativePath", "")).casefold().endswith(".py")
    ]
    engine_paths = [arguments.project_root / str(row["sourcePath"]) for row in engine_rows]
    expected_engine_hashes = [str(row["sha256"]).upper() for row in engine_rows]
    if arguments.runner.resolve() not in {path.resolve() for path in engine_paths}:
        raise AssertionError("Runner is absent from the packaged Python engine set.")
    if len(engine_paths) != 15:
        raise AssertionError("R18R packaged Python engine cardinality changed.")
    if len({path.resolve() for path in engine_paths}) != len(engine_paths):
        raise AssertionError("Engine scan list contains duplicates.")
    engine_sources: dict[Path, str] = {}
    forbidden = []
    for path, expected_sha256, row in zip(engine_paths, expected_engine_hashes, engine_rows):
        if sha256_file(path) != expected_sha256:
            raise AssertionError(f"Engine source hash changed: {path}")
        if path.stat().st_size != int(row["bytes"]):
            raise AssertionError(f"Engine source byte length changed: {path}")
        source = path.read_text(encoding="utf-8")
        engine_sources[path] = source
        forbidden.extend(f"{path}:{match.group(0)}" for match in FORBIDDEN_ENGINE_LITERAL.finditer(source))
    if forbidden:
        raise AssertionError(f"Engine contains production-shaped hard-coded literals: {forbidden}")
    if sha256_file(arguments.base_bundle) != arguments.base_bundle_sha256.upper():
        raise AssertionError("Base reference bundle hash changed.")
    if sha256_file(arguments.supplemental_manifest) != arguments.supplemental_manifest_sha256.upper():
        raise AssertionError("Supplemental reference manifest hash changed.")
    runner = load_runner(arguments.runner)
    cohort = read_json(arguments.cohort)
    base = read_base_manifest(arguments.base_bundle)
    # The pinned hash is over the exact ZIP member bytes, not normalized JSON.
    with zipfile.ZipFile(arguments.base_bundle) as archive:
        exact_base_manifest = archive.read("refs/PORTABLE_GLYPH_REFERENCE_MANIFEST.json")
    if hashlib.sha256(exact_base_manifest).hexdigest().upper() != arguments.base_manifest_sha256.upper():
        raise AssertionError("Base reference manifest hash changed.")
    supplemental = read_json(arguments.supplemental_manifest)
    cases = list(cohort["reviewCases"])
    if int(cohort["caseCount"]) != len(cases) or len(cases) != 21:
        raise AssertionError("R18R cohort cardinality changed.")
    identities = [str(row["physicalIdentity"]) for row in cases]
    pairs = [(str(row["bfSha256"]).upper(), str(row["dfSha256"]).upper()) for row in cases]
    if len(set(value.casefold() for value in identities)) != len(identities):
        raise AssertionError("Cohort contains duplicate physical identities.")
    if len(set(pairs)) != 21:
        raise AssertionError("R18R cohort source-image pair cardinality changed.")

    class Reference:
        def __init__(self, physical_identity: str) -> None:
            self.physical_identity = physical_identity

    reference_identities = sorted({
        str(row.get("physicalIdentity", ""))
        for row in list(base["references"]) + list(supplemental["references"])
        if row.get("physicalIdentity")
    }, key=str.casefold)
    bank = [Reference(value) for value in reference_identities]
    excluded_counts: list[int] = []
    for case, pair in zip(cases, pairs):
        filtered = runner.exclude_case_reference_lineage(
            bank, list(bank), list(bank), str(case["physicalIdentity"]), set(pair),
            list(supplemental["references"]),
        )
        case_lineage = runner.R18P.physical_lineage_key(str(case["physicalIdentity"]))
        retained_lineages = set()
        for reference in filtered[0]:
            try:
                retained_lineages.add(runner.R18P.physical_lineage_key(reference.physical_identity))
            except ValueError:
                pass
        if case_lineage in retained_lineages:
            raise AssertionError("A same-lineage reference survived exclusion.")
        excluded_counts.append(int(filtered[3]["excludedPrototypeCount"]))

    known_truth = [row for row in cases if row.get("expectedTruth")]
    if len(known_truth) != 2:
        raise AssertionError("Expected-truth control cardinality changed.")
    configured_literals = identities + [str(row["expectedTruth"]) for row in known_truth]
    leaked = [
        f"{path}:{literal}"
        for path, source in engine_sources.items()
        for literal in configured_literals
        if literal.casefold() in source.casefold()
    ]
    if leaked:
        raise AssertionError(f"Configuration-only identity/truth literal leaked into engine source: {leaked}")
    known_truth_indices = [index for index, row in enumerate(cases) if row.get("expectedTruth")]
    if min(excluded_counts[index] for index in known_truth_indices) < 1:
        raise AssertionError("A known-truth control did not exclude any reference prototype.")
    print(json.dumps({
        "schema": "argos_opencv_scribe_r18r_reference_isolation_local_gate_v1",
        "state": "PASS_R18R_REFERENCE_ISOLATION_LOCAL_GATE",
        "caseCount": len(cases),
        "uniqueSourcePairCount": len(set(pairs)),
        "knownTruthControlCount": len(known_truth),
        "knownTruthMinimumExcludedReferenceIdentityCount": min(
            excluded_counts[index] for index in known_truth_indices
        ),
        "minimumExcludedReferenceIdentityCount": min(excluded_counts),
        "maximumExcludedReferenceIdentityCount": max(excluded_counts),
        "engineSourceCount": len(engine_paths),
        "engineHashMismatchCount": 0,
        "hardCodedEngineLiteralCount": len(forbidden),
        "configurationLiteralLeakCount": len(leaked),
        "sameLineageReferenceSurvivorCount": 0,
        "packageExcluded": True,
        "imageBytesRead": False,
        "mutationsPerformed": False,
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
