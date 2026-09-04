#!/usr/bin/env python3
"""Package-excluded direct gate for the canonical SEMI M12 vectors."""

from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


METHOD_SHA256 = "E5B78AFBA2614A3D4186298C84CF8E46F4816B0A9F3B2BC3DE751E854C014C2C"
VECTOR_SHA256 = "6911A0E12E81AEFBF59D7EE4FCC99457362DE0834949431E26C27566F6E93F16"
PROVIDER_SHA256 = "51C95B3279D253EF717F663F3860CC6B4CA38517706E08E9FE2302BE02CD2BB5"
RUNNER_SHA256 = "B826767EA21BB148DD30A719595B23DD818FD9CFC08B347FEAFD9FD4959F4E3C"
LOCAL_GATE_SHA256 = "566EB33649697713F5E0EFD3E0F04F9861333103BBBC1C1BACFEDE3CD184C82A"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    project = arguments.project.resolve()
    output = arguments.output.resolve()
    require(sys.dont_write_bytecode, "Run the canonical checksum gate with Python -B.")
    require(not output.exists(), f"Create-new gate already exists: {output}")

    method_path = project / "work/SCRIBE_REVIEW_ONLY/SEMI_M12_SCRIBE_VALIDATION_METHOD.md"
    vector_path = project / "work/SCRIBE_REVIEW_ONLY/SEMI_M12_VERIFIED_TEST_VECTORS_20260730.csv"
    provider_path = project / "work/OPENCV_SCRIBE_R18R/ArgosOpenCvScribeV1R18R.py"
    runner_path = project / "work/OPENCV_SCRIBE_R18R/Run-R18RReferenceIsolatedCorpus.py"
    local_gate_path = project / "work/OPENCV_SCRIBE_R18R/R18R_LOCAL_GATE.json"
    pins = {
        method_path: METHOD_SHA256,
        vector_path: VECTOR_SHA256,
        provider_path: PROVIDER_SHA256,
        runner_path: RUNNER_SHA256,
        local_gate_path: LOCAL_GATE_SHA256,
    }
    for path, expected in pins.items():
        require(path.is_file(), f"Canonical checksum dependency absent: {path}")
        require(sha256_file(path) == expected, f"Canonical checksum dependency changed: {path}")

    method = method_path.read_text(encoding="utf-8")
    for statement in (
        "a_i = ASCII(A_i) - 32",
        "c_i = (8 * c_(i-1) + a_i) mod 59",
        "c_12 = 0",
        "The checksum must never invent a character",
        "Expected vectors: 19",
        "Required passes: 19",
        "Allowed failures: 0",
    ):
        require(statement in method, f"Canonical SEMI M12 method assertion absent: {statement}")

    provider = load("r18r_canonical_checksum_provider", provider_path)
    r11 = provider.R17D.R17C.R17B._load_r11()
    local_gate = json.loads(local_gate_path.read_text(encoding="utf-8"))
    slot24 = local_gate["slot24"]
    require(
        local_gate["state"] == "PASS_R18R_LOCAL_SLOT24_RESOLUTION_REMOTE_AMBIGUITY_CONTROLS_PENDING"
        and local_gate["provider"]["sha256"] == PROVIDER_SHA256
        and local_gate["runner"]["sha256"] == RUNNER_SHA256,
        "R18R image gate binding changed.",
    )
    require(
        slot24["checksumCannotSelectOrRewriteImageFirst"] is True
        and slot24["checksumInvalidForwardTriggersReverseVerification"] is True
        and slot24["checksumInversionForwardImageEvidenceExact"] is True
        and slot24["checksumMetadataAbsentResolverDecisionEqual"] is True
        and slot24["normalChecksumValid"] is True,
        "R18R checksum/image-first separation gate changed.",
    )
    require(
        set(slot24["missingChecksumEvidenceRejectedByRunner"])
        == {
            "checksumValid",
            "proposedString",
            "expectedCheckCharacters",
            "observedCheckCharacters",
            "checksumAlternatives",
        },
        "R18R runner no longer rejects every required checksum field.",
    )

    with vector_path.open("r", encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        expected_columns = [
            "Identity", "Scribe", "Body", "ObservedCheckCharacters",
            "ExpectedCheckCharacters", "ChecksumValid", "Authority",
        ]
        require(reader.fieldnames == expected_columns, "Canonical vector columns changed.")
        rows = list(reader)
    require(len(rows) == 19, "Canonical vector count changed.")
    require(len({row["Identity"] for row in rows}) == 19, "Canonical vector identities are not unique.")
    require(len({row["Scribe"] for row in rows}) == 19, "Canonical scribe strings are not unique.")

    passed: list[dict[str, Any]] = []
    invalid_controls: list[dict[str, Any]] = []
    for row in rows:
        scribe = row["Scribe"]
        body = row["Body"]
        observed = row["ObservedCheckCharacters"]
        expected = r11.m12_check_characters(body)
        remainder = r11.m12_remainder(scribe)
        valid = (
            len(scribe) == 12
            and len(body) == 10
            and scribe[:10] == body
            and scribe[10:] == observed
            and row["ExpectedCheckCharacters"] == expected
            and observed == expected
            and row["ChecksumValid"] == "1"
            and remainder == 0
        )
        require(valid, f"Canonical SEMI M12 vector failed: {row['Identity']}")
        passed.append({
            "identity": row["Identity"], "scribe": scribe, "body": body,
            "observedCheckCharacters": observed,
            "expectedCheckCharacters": expected, "remainder": remainder,
        })
        invalid = next(
            scribe[:-1] + character
            for character in r11.BODY_LABELS
            if character != scribe[-1] and r11.m12_remainder(scribe[:-1] + character) != 0
        )
        invalid_remainder = r11.m12_remainder(invalid)
        require(invalid_remainder != 0, f"Invalid checksum control unexpectedly passed: {row['Identity']}")
        invalid_controls.append({
            "identity": row["Identity"], "scribe": invalid,
            "remainder": invalid_remainder, "rejected": True,
        })

    require(r11.m12_remainder("8369N004FEC6") != 0, "Known incorrect scribe checksum unexpectedly passed.")
    require(r11.m12_remainder("8365N004FEC6") == 0, "Known corrected scribe checksum failed.")
    require(r11.m12_check_characters("8365N004FE") == "C6", "Known corrected check pair changed.")

    result = {
        "schema": "argos_opencv_scribe_r18r_canonical_checksum_gate_v1",
        "state": "PASS_R18R_CANONICAL_CHECKSUM_GATE",
        "classification": "PENDING_GATE",
        "artifactLifecycle": "FROZEN",
        "semiM12MethodPath": "work/SCRIBE_REVIEW_ONLY/SEMI_M12_SCRIBE_VALIDATION_METHOD.md",
        "semiM12MethodSha256": METHOD_SHA256,
        "canonicalVectorPath": "work/SCRIBE_REVIEW_ONLY/SEMI_M12_VERIFIED_TEST_VECTORS_20260730.csv",
        "canonicalVectorSha256": VECTOR_SHA256,
        "providerPath": "work/OPENCV_SCRIBE_R18R/ArgosOpenCvScribeV1R18R.py",
        "providerSha256": PROVIDER_SHA256,
        "runnerPath": "work/OPENCV_SCRIBE_R18R/Run-R18RReferenceIsolatedCorpus.py",
        "runnerSha256": RUNNER_SHA256,
        "localImageGatePath": "work/OPENCV_SCRIBE_R18R/R18R_LOCAL_GATE.json",
        "localImageGateSha256": LOCAL_GATE_SHA256,
        "testPath": "work/OPENCV_SCRIBE_R18R/Test-R18RCanonicalChecksum.py",
        "testSha256": sha256_file(Path(__file__).resolve()),
        "vectorCount": len(rows), "passCount": len(passed), "failureCount": 0,
        "invalidControlCount": len(invalid_controls),
        "invalidRejectedCount": sum(bool(row["rejected"]) for row in invalid_controls),
        "passedVectors": passed, "invalidControls": invalid_controls,
        "knownIncorrect8369Rejected": True, "knownCorrected8365Passed": True,
        "checksumVerificationRequired": True,
        "checksumUsedForImageFirst": False,
        "checksumMutationAllowed": False,
        "checksumMayInventUnsupportedCharacter": False,
        "packageExcluded": True,
        "imageBytesRead": False,
        "sourceImagesRead": False,
        "identityAccepted": False,
        "mutationsPerformed": False,
        "reviewOnly": True,
        "productionRoutingEnabled": False,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
