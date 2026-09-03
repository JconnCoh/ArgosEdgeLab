#!/usr/bin/env python3
"""Hash-locked loader for the R18F K/W/Z diagnostic supplement."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


SCHEMA = "argos_opencv_scribe_supplemental_glyph_references_v1"
EXPECTED_COUNTS = {"J": 2, "K": 2, "Q": 2, "W": 1, "X": 1, "Z": 1}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def contained_path(root: Path, relative: str) -> Path:
    if not relative or Path(relative).is_absolute():
        raise ValueError(f"Supplement path must be relative: {relative}")
    root = root.resolve()
    path = (root / Path(relative.replace("/", "\\"))).resolve()
    if root not in path.parents:
        raise ValueError(f"Supplement path escaped its root: {relative}")
    return path


def load_supplemental_prototypes(r11: Any, manifest_path: Path, expected_sha256: str) -> tuple[list[Any], dict[str, Any]]:
    actual = sha256_file(manifest_path)
    if actual != expected_sha256.upper():
        raise ValueError("Supplemental reference manifest SHA-256 mismatch")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    if manifest.get("schema") != SCHEMA or manifest.get("disposition") != "DIAGNOSTIC_ONLY":
        raise ValueError("R18F supplemental manifest contract mismatch")
    for field in ("identityAdmissionAuthorized", "activationAuthorized", "trainingAuthorized", "productionAuthorized"):
        if manifest.get(field) is not False:
            raise ValueError(f"Supplemental reference authority mismatch: {field}")
    if manifest.get("operatorConfirmedLabels") != "KWZ" or manifest.get("remainingMissingLabelsAfterSupplement") != "IOVY":
        raise ValueError("R18F confirmation or remaining-gap contract changed")

    prototypes = []
    counts: dict[str, int] = {}
    seen: set[tuple[str, str, int]] = set()
    for row in manifest.get("references", []):
        label = str(row.get("label", ""))
        case_id = str(row.get("caseId", ""))
        position = int(row.get("position", 0))
        key = (label, case_id, position)
        if len(label) != 1 or label not in r11.BODY_LABELS or key in seen:
            raise ValueError(f"Invalid or duplicate supplemental reference: {key}")
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
    declared = {str(key): int(value) for key, value in dict(manifest.get("labelCounts", {})).items()}
    if counts != EXPECTED_COUNTS or declared != EXPECTED_COUNTS:
        raise ValueError(f"R18F supplemental label counts changed: actual={counts}, declared={declared}")
    return prototypes, {
        "manifestSha256": actual,
        "referenceCount": len(prototypes),
        "prototypeLabels": "JKQWXZ",
        "labelCounts": counts,
        "operatorConfirmedLabels": "KWZ",
        "multiExampleProvisionalLabels": "K",
        "singleExampleProvisionalLabels": "WXZ",
    }


def combine_reference_prototypes(r11: Any, base_prototypes: list[Any], base_evidence: dict[str, Any], manifest_path: Path, expected_sha256: str) -> tuple[list[Any], dict[str, Any]]:
    supplements, evidence = load_supplemental_prototypes(r11, manifest_path, expected_sha256)
    combined = list(base_prototypes) + supplements
    labels = "".join(sorted({str(item.label) for item in combined}))
    missing = "".join(label for label in r11.BODY_LABELS if label not in labels)
    if missing != "IOVY":
        raise ValueError(f"R18F combined missing-label contract changed: {missing}")
    return combined, {
        "base": dict(base_evidence),
        "supplement": evidence,
        "combinedReferenceCount": len(combined),
        "combinedPrototypeLabels": labels,
        "missingBodyReferenceLabels": missing,
        "referenceCoverageComplete": False,
        "providerActivationAuthorized": False,
        "identityAdmissionAuthorized": False,
    }
