#!/usr/bin/env python3
"""Hash-locked diagnostic loader for the 19-reference R18Z supplement."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


SCHEMA = "argos_opencv_scribe_supplemental_glyph_references_v1"
EXPECTED_COUNTS = {
    "D": 1,
    "H": 1,
    "J": 2,
    "K": 2,
    "L": 1,
    "M": 1,
    "N": 3,
    "Q": 2,
    "R": 1,
    "T": 1,
    "W": 1,
    "X": 2,
    "Z": 1,
}
EXPECTED_NEW_REFERENCES = {
    ("62627-140_20260802111846_Slot24", "147MH067SUD2", "D", 11),
    ("62627-140_20260802111846_Slot24", "147MH067SUD2", "H", 5),
    ("62627-140_20260802111846_Slot24", "147MH067SUD2", "M", 4),
    ("62625-907-POST-20260714155300_20260714155354_Slot14", "146XF109SUG7", "X", 4),
    ("62546-481-POST_20260708155428_Slot03", "0303N050FEE4", "N", 5),
    ("62546-481-POST_20260708155428_Slot04", "0303N049FEB3", "N", 5),
    ("62546-481_20260707164232_Slot05", "0303N047FEA2", "N", 5),
    ("62619-451-PRE_20260717143452_Slot01", "146AR068SUC7", "R", 5),
    ("62619-451-PRE_20260717143452_Slot09", "1478T059SUA3", "T", 5),
    ("62620-548_20260810154124_Slot02", "L0751042FEF5", "L", 1),
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def contained_path(root: Path, relative: str) -> Path:
    if not relative or Path(relative).is_absolute():
        raise ValueError(f"Supplement path must be relative: {relative}")
    resolved_root = root.resolve()
    path = (resolved_root / Path(relative.replace("/", "\\"))).resolve()
    if path != resolved_root and resolved_root not in path.parents:
        raise ValueError(f"Supplement path escaped its root: {relative}")
    return path


def load_supplemental_prototypes(
    r11: Any,
    manifest_path: Path,
    expected_sha256: str,
) -> tuple[list[Any], dict[str, Any]]:
    actual = sha256_file(manifest_path)
    if actual != expected_sha256.upper():
        raise ValueError("R18Z supplemental reference manifest SHA-256 mismatch.")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    if (
        manifest.get("schema") != SCHEMA
        or manifest.get("disposition") != "DIAGNOSTIC_ONLY"
        or manifest.get("remainingMissingLabelsAfterSupplement") != "IOVY"
    ):
        raise ValueError("R18Z supplemental manifest contract mismatch.")
    for field in (
        "identityAdmissionAuthorized",
        "activationAuthorized",
        "trainingAuthorized",
        "productionAuthorized",
    ):
        if manifest.get(field) is not False:
            raise ValueError(f"R18Z supplemental authority mismatch: {field}")
    references = list(manifest.get("references", []))
    if len(references) != 19:
        raise ValueError("R18Z requires exactly 19 supplemental reference rows.")
    declared = {
        str(key): int(value) for key, value in dict(manifest.get("labelCounts", {})).items()
    }
    if declared != EXPECTED_COUNTS:
        raise ValueError("R18Z supplemental declared label counts changed.")
    new_rows = [row for row in references if str(row.get("caseId", "")).startswith("R18Z_C")]
    observed_new = {
        (
            str(row.get("physicalIdentity", "")),
            str(row.get("truth", "")),
            str(row.get("label", "")),
            int(row.get("position", 0)),
        )
        for row in new_rows
    }
    if len(new_rows) != 10 or observed_new != EXPECTED_NEW_REFERENCES:
        raise ValueError("R18Z ten declared reference identities changed.")

    prototypes: list[Any] = []
    counts: dict[str, int] = {}
    seen: set[tuple[str, str, int]] = set()
    for row in references:
        label = str(row.get("label", ""))
        case_id = str(row.get("caseId", ""))
        position = int(row.get("position", 0))
        physical_identity = str(row.get("physicalIdentity", ""))
        key = (label, case_id, position)
        if len(label) != 1 or label not in r11.BODY_LABELS or key in seen:
            raise ValueError(f"Invalid or duplicate R18Z supplemental reference: {key}")
        seen.add(key)
        if case_id.startswith("R18Z_C"):
            truth = str(row.get("truth", ""))
            if (
                len(truth) != 12
                or position < 1
                or position > 12
                or truth[position - 1] != label
                or row.get("exactScribeLineage") != truth
                or row.get("declaredByR18W3Selection") is not True
                or row.get("exactMesTruthBound") is not True
                or row.get("incidentalGlyph") is not False
                or row.get("identityAccepted") is not False
                or row.get("operatorConfirmed") is not False
                or row.get("sourceDirection") != "FORWARD_ORIENTED_INPUT_CONTRACT"
            ):
                raise ValueError(f"R18Z declared-glyph authority mismatch: {key}")
        path = contained_path(manifest_path.parent, str(row.get("relativePath", "")))
        if not path.is_file() or sha256_file(path) != str(row.get("sha256", "")).upper():
            raise ValueError(f"R18Z supplemental glyph is absent or changed: {path}")
        if "bytes" in row and path.stat().st_size != int(row["bytes"]):
            raise ValueError(f"R18Z supplemental glyph byte count changed: {path}")
        gray = r11.decode_gray_exact(path)
        residual = r11.dark_residual_exact(gray, max(4, min(12, gray.shape[1] // 8)))
        descriptor = r11.describe_exact(residual, 0, 0, gray.shape[1], gray.shape[0])
        if descriptor is None:
            raise ValueError(f"R18Z supplemental glyph could not be described: {path}")
        prototypes.append(r11.Prototype(label, physical_identity, descriptor))
        counts[label] = counts.get(label, 0) + 1
    if counts != EXPECTED_COUNTS:
        raise ValueError(f"R18Z supplemental observed label counts changed: {counts}")
    return prototypes, {
        "manifestSha256": actual,
        "referenceCount": len(prototypes),
        "prototypeLabels": "DHJKLMNQRTWXZ",
        "labelCounts": counts,
        "newDeclaredReferenceCount": 10,
        "incidentalReferenceCount": 0,
        "reviewOnly": True,
        "identityAccepted": False,
    }


def combine_reference_prototypes(
    r11: Any,
    base_prototypes: list[Any],
    base_evidence: dict[str, Any],
    manifest_path: Path,
    expected_sha256: str,
) -> tuple[list[Any], dict[str, Any]]:
    supplements, evidence = load_supplemental_prototypes(
        r11, manifest_path, expected_sha256
    )
    combined = list(base_prototypes) + supplements
    labels = "".join(sorted({str(item.label) for item in combined}))
    missing = "".join(label for label in r11.BODY_LABELS if label not in labels)
    if len(combined) != 475 or missing != "IOVY":
        raise ValueError(
            f"R18Z combined reference contract changed: count={len(combined)}, missing={missing}"
        )
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
