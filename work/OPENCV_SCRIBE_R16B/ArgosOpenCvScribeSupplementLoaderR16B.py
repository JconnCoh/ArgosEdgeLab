#!/usr/bin/env python3
"""Hash-locked supplemental-reference loader for a fresh scribe provider."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


SCHEMA = "argos_opencv_scribe_supplemental_glyph_references_v1"
EXPECTED_AUTHORITY_FALSE = (
    "identityAdmissionAuthorized",
    "activationAuthorized",
    "trainingAuthorized",
    "productionAuthorized",
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


def contained_path(root: Path, relative: str) -> Path:
    if not relative or Path(relative).is_absolute():
        raise ValueError(f"Supplement path must be relative: {relative}")
    root = root.resolve()
    path = (root / Path(relative.replace("/", "\\"))).resolve()
    if root not in path.parents:
        raise ValueError(f"Supplement path escaped its root: {relative}")
    return path


def load_supplemental_prototypes(
    r11: Any,
    manifest_path: Path,
    expected_manifest_sha256: str,
) -> tuple[list[Any], dict[str, Any]]:
    actual_manifest_sha256 = sha256_file(manifest_path)
    if actual_manifest_sha256 != expected_manifest_sha256.upper():
        raise ValueError("Supplemental reference manifest SHA-256 mismatch.")
    manifest = read_json(manifest_path)
    if manifest.get("schema") != SCHEMA:
        raise ValueError("Supplemental reference manifest schema mismatch.")
    if manifest.get("disposition") != "DIAGNOSTIC_ONLY":
        raise ValueError("Supplemental reference disposition is not diagnostic-only.")
    for field in EXPECTED_AUTHORITY_FALSE:
        if manifest.get(field) is not False:
            raise ValueError(f"Supplemental reference authority mismatch: {field}")

    prototypes: list[Any] = []
    rows = manifest.get("references")
    if not isinstance(rows, list) or not rows:
        raise ValueError("Supplemental reference rows are absent.")
    seen: set[tuple[str, str, int]] = set()
    counts: dict[str, int] = {}
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("Supplemental reference row is not an object.")
        label = str(row.get("label", ""))
        case_id = str(row.get("caseId", ""))
        position = int(row.get("position", 0))
        if len(label) != 1 or label not in r11.BODY_LABELS:
            raise ValueError(f"Invalid supplemental label: {label}")
        key = (label, case_id, position)
        if key in seen:
            raise ValueError(f"Duplicate supplemental reference: {key}")
        seen.add(key)
        path = contained_path(manifest_path.parent, str(row.get("relativePath", "")))
        if not path.is_file() or sha256_file(path) != str(row.get("sha256", "")).upper():
            raise ValueError(f"Supplemental reference is absent or changed: {path}")
        gray = r11.decode_gray_exact(path)
        residual = r11.dark_residual_exact(gray, max(4, min(12, gray.shape[1] // 8)))
        descriptor = r11.describe_exact(residual, 0, 0, gray.shape[1], gray.shape[0])
        if descriptor is None:
            raise ValueError(f"Supplemental reference could not be described: {path}")
        prototypes.append(r11.Prototype(label, str(row.get("physicalIdentity", "")), descriptor))
        counts[label] = counts.get(label, 0) + 1

    declared_counts = {str(key): int(value) for key, value in dict(manifest.get("labelCounts", {})).items()}
    if counts != declared_counts:
        raise ValueError(f"Supplemental label counts changed: actual={counts}, declared={declared_counts}")
    labels = "".join(sorted(counts))
    if labels != "JKQX" or counts != {"J": 2, "K": 1, "Q": 2, "X": 1}:
        raise ValueError(f"R16A supplemental contract changed: {counts}")
    return prototypes, {
        "manifestSha256": actual_manifest_sha256,
        "referenceCount": len(prototypes),
        "prototypeLabels": labels,
        "labelCounts": counts,
        "independentlyValidatedLabels": str(manifest.get("independentlyValidatedLabels", "")),
        "singleExampleProvisionalLabels": str(manifest.get("singleExampleProvisionalLabels", "")),
    }


def combine_reference_prototypes(
    r11: Any,
    base_prototypes: list[Any],
    base_evidence: dict[str, Any],
    manifest_path: Path,
    expected_manifest_sha256: str,
) -> tuple[list[Any], dict[str, Any]]:
    supplements, supplemental_evidence = load_supplemental_prototypes(
        r11, manifest_path, expected_manifest_sha256
    )
    combined = list(base_prototypes) + supplements
    labels = "".join(sorted({str(item.label) for item in combined}))
    missing = "".join(label for label in r11.BODY_LABELS if label not in labels)
    return combined, {
        "base": dict(base_evidence),
        "supplement": supplemental_evidence,
        "combinedReferenceCount": len(combined),
        "combinedPrototypeLabels": labels,
        "missingBodyReferenceLabels": missing,
        "referenceCoverageComplete": not missing,
        "providerActivationAuthorized": False,
        "identityAdmissionAuthorized": False,
    }
