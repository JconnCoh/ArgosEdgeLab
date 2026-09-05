#!/usr/bin/env python3
"""Build a hash-locked exact-scribe lineage crosswalk for frozen glyph references."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import OrderedDict, defaultdict
from pathlib import Path
from typing import Any


BASE_RELATIVE = (
    "work/SCRIBE_REVIEW_ONLY/scratch/"
    "SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/"
    "PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
)
SUPPLEMENTAL_RELATIVE = (
    "work/OPENCV_SCRIBE_R18F/reference_bank/"
    "SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
)
ROSTER_RELATIVE = "work/OPENCV_SCRIBE_R18UQ3/R18UQ3_LIVE_INSITEREAD_ROSTER.json"
METADATA_RELATIVE = (
    "work/OPENCV_SCRIBE_R18U/evidence/VERIFIED_METADATA_OVERLAY_20260814.json"
)
R18V_GATE_RELATIVE = "work/OPENCV_SCRIBE_R18V/R18V_GLYPH_ENVELOPE_GATE.json"

EXPECTED_SHA256 = {
    BASE_RELATIVE: "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229",
    SUPPLEMENTAL_RELATIVE: "FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114",
    ROSTER_RELATIVE: "CE108A3726EFDD53651453CB3310E06051D6E53DDD3654A304446D9070C19DAB",
    METADATA_RELATIVE: "AB800600F24BC2163010580DB1E2D910CA42C882218F4CFC6D60C9371511D5D0",
    R18V_GATE_RELATIVE: "BEA75FAC417BEE9D0DB5B3302AEEAD15053C46A2AC434BBB7A49E04AADC437C9",
}
SCRIBE_PATTERN = re.compile(r"^[A-Z0-9]{12}$")
LEGACY_IDENTITY_PATTERN = re.compile(r"^(\d{5})_(\d{3})_SLOT(\d{2})$", re.IGNORECASE)
BODY_LABELS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
MINIMUM_ENFORCEABLE_LINEAGES = 4
CURRENT_SLOT21_ACQUISITION = "62546-481_20260707164232_SLOT21"
CURRENT_SLOT21_TRUTH = "13HFX135SUE3"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def require_scribe(value: Any, context: str) -> str:
    normalized = str(value).strip().upper()
    if not SCRIBE_PATTERN.fullmatch(normalized):
        raise ValueError(f"{context} is not an exact 12-character scribe: {value!r}")
    return normalized


def reference_path(manifest_path: Path, relative: Any) -> Path:
    parts = str(relative).replace("\\", "/").split("/")
    if not parts or any(part in ("", ".", "..") for part in parts):
        raise ValueError(f"Unsafe reference path: {relative!r}")
    return manifest_path.parent.joinpath(*parts)


def verify_reference(row: dict[str, Any], manifest_path: Path) -> dict[str, Any]:
    path = reference_path(manifest_path, row.get("relativePath"))
    actual = sha256_file(path)
    expected = str(row.get("sha256", "")).upper()
    if actual != expected:
        raise ValueError(f"Reference SHA-256 mismatch: {path}")
    return {
        "label": str(row.get("label", "")).upper(),
        "relativePath": str(row.get("relativePath", "")).replace("\\", "/"),
        "sha256": actual,
    }


def derive_base_lineages(
    manifest: dict[str, Any], manifest_path: Path
) -> list[dict[str, Any]]:
    if manifest.get("schema") != "argos_portable_scribe_glyph_references_v1":
        raise ValueError("Frozen base reference schema changed.")
    references = manifest.get("references")
    if not isinstance(references, list) or len(references) != int(manifest.get("count", -1)):
        raise ValueError("Frozen base reference count is inconsistent.")
    grouped: OrderedDict[str, list[dict[str, Any]]] = OrderedDict()
    for row in references:
        if not isinstance(row, dict):
            raise ValueError("Base reference row is not an object.")
        identity = str(row.get("physicalIdentity", "")).strip()
        if not identity:
            raise ValueError("Base reference lacks physicalIdentity.")
        grouped.setdefault(identity, []).append(row)
    output: list[dict[str, Any]] = []
    for identity, rows in grouped.items():
        if len(rows) < 12 or len(rows) % 12:
            raise ValueError(f"Base lineage {identity} is not complete 12-glyph sequence evidence.")
        variants: list[dict[str, Any]] = []
        variant_truths: list[str] = []
        for offset in range(0, len(rows), 12):
            chunk = rows[offset : offset + 12]
            truth = require_scribe("".join(str(row.get("label", "")) for row in chunk), identity)
            variant_truths.append(truth)
            references_out = []
            for position, row in enumerate(chunk, start=1):
                verified = verify_reference(row, manifest_path)
                if verified["label"] != truth[position - 1]:
                    raise ValueError(f"Base label/position mismatch for {identity} position {position}.")
                references_out.append({"position1Based": position, **verified})
            variants.append(
                {
                    "manifestSequenceVariant": len(variants) + 1,
                    "truth": truth,
                    "references": references_out,
                }
            )
        if len(set(variant_truths)) != 1:
            raise ValueError(f"Repeated base sequences disagree for {identity}: {variant_truths}")
        truth = variant_truths[0]
        output.append(
            {
                "sourceKind": "FROZEN_BASE_COMPLETE_SEQUENCE",
                "legacyPhysicalIdentity": identity,
                "exactScribeLineage": truth,
                "lineageKey": f"SCRIBE:{truth}",
                "sequenceVariantCount": len(variants),
                "referenceCount": len(rows),
                "variants": variants,
            }
        )
    truths = [row["exactScribeLineage"] for row in output]
    if len(truths) != len(set(truths)):
        raise ValueError("Two legacy base identities reconstruct to the same exact scribe lineage.")
    return output


def derive_supplemental_lineages(
    manifest: dict[str, Any], manifest_path: Path
) -> list[dict[str, Any]]:
    if manifest.get("schema") != "argos_opencv_scribe_supplemental_glyph_references_v1":
        raise ValueError("Frozen supplemental reference schema changed.")
    grouped: OrderedDict[str, list[dict[str, Any]]] = OrderedDict()
    identity_truth: dict[str, str] = {}
    for row in manifest.get("references", []):
        if not isinstance(row, dict):
            raise ValueError("Supplemental reference row is not an object.")
        truth = require_scribe(row.get("truth"), "supplemental truth")
        identity = str(row.get("physicalIdentity", "")).strip()
        if not identity:
            raise ValueError("Supplemental reference lacks physicalIdentity.")
        prior = identity_truth.setdefault(identity.casefold(), truth)
        if prior != truth:
            raise ValueError(f"Supplemental identity maps to multiple truths: {identity}")
        position = int(row.get("position", 0))
        label = str(row.get("label", "")).upper()
        if position < 1 or position > 12 or truth[position - 1] != label:
            raise ValueError(f"Supplemental label/position mismatch: {identity} position {position}")
        verified = verify_reference(row, manifest_path)
        grouped.setdefault(truth, []).append(
            {
                "position1Based": position,
                "physicalIdentity": identity,
                "caseId": str(row.get("caseId", "")),
                "operatorConfirmed": bool(row.get("operatorConfirmed", False)),
                **verified,
            }
        )
    output: list[dict[str, Any]] = []
    for truth, references in grouped.items():
        physical_identities = sorted({row["physicalIdentity"] for row in references}, key=str.casefold)
        if len(physical_identities) != 1:
            raise ValueError(f"One exact supplemental scribe has multiple acquisition identities: {truth}")
        keys = [(row["label"], row["position1Based"]) for row in references]
        if len(keys) != len(set(keys)):
            raise ValueError(f"Duplicate supplemental glyph position: {truth}")
        output.append(
            {
                "sourceKind": "FROZEN_SUPPLEMENTAL_SELECTED_GLYPHS",
                "physicalIdentity": physical_identities[0],
                "exactScribeLineage": truth,
                "lineageKey": f"SCRIBE:{truth}",
                "referenceCount": len(references),
                "references": sorted(references, key=lambda row: (row["position1Based"], row["label"])),
            }
        )
    return output


def roster_index(roster: dict[str, Any]) -> dict[str, list[dict[str, str]]]:
    output: dict[str, list[dict[str, str]]] = defaultdict(list)
    for lot in roster.get("lots", []):
        for member in lot.get("resolvedMembers", []):
            truth = require_scribe(member.get("resolvedScribe"), "resolved roster member")
            output[truth].append(
                {
                    "queryLot": str(member.get("queryLot", "")),
                    "unitContainer": str(member.get("unitContainer", "")),
                }
            )
    return dict(output)


def metadata_index(metadata: dict[str, Any]) -> dict[str, list[dict[str, str]]]:
    output: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in metadata.get("rows", []):
        truth = require_scribe(row.get("scribe"), "metadata row")
        output[truth].append(
            {
                "acquisitionKey": str(row.get("acquisitionKey", "")),
                "historyBaseLot": str(row.get("historyBaseLot", "")),
                "issuedWaferContainer": str(row.get("issuedWaferContainer", "")),
            }
        )
    return dict(output)


def legacy_reuse_summary(
    lineage: dict[str, Any], metadata: dict[str, Any]
) -> dict[str, Any]:
    identity = str(lineage["legacyPhysicalIdentity"])
    match = LEGACY_IDENTITY_PATTERN.fullmatch(identity)
    if match is None:
        raise ValueError(f"Unexpected legacy identity format: {identity}")
    lot = f"{match.group(1)}-{match.group(2)}"
    slot_suffix = f"_SLOT{match.group(3)}"
    candidates = [
        row
        for row in metadata.get("rows", [])
        if str(row.get("historyBaseLot", "")).upper() == lot
        and str(row.get("acquisitionKey", "")).upper().endswith(slot_suffix)
    ]
    truth = str(lineage["exactScribeLineage"])
    distinct = sorted({require_scribe(row.get("scribe"), identity) for row in candidates})
    exact_count = sum(require_scribe(row.get("scribe"), identity) == truth for row in candidates)
    return {
        "legacyLotSlotKey": f"{lot}{slot_suffix}",
        "metadataCandidateAcquisitionCount": len(candidates),
        "metadataDistinctScribes": distinct,
        "metadataExactTruthAcquisitionCount": exact_count,
        "metadataDifferentTruthAcquisitionCount": len(candidates) - exact_count,
        "state": (
            "NO_FROZEN_METADATA_CANDIDATE"
            if not candidates
            else "LEGACY_LOT_SLOT_REUSED_WITH_DIFFERENT_SCRIBE"
            if len(candidates) != exact_count
            else "ONLY_EXACT_TRUTH_OBSERVED_IN_FROZEN_METADATA"
        ),
    }


def build(project: Path) -> dict[str, Any]:
    project = project.resolve()
    paths = {relative: project / relative for relative in EXPECTED_SHA256}
    pins: dict[str, dict[str, Any]] = {}
    for relative, expected in EXPECTED_SHA256.items():
        actual = sha256_file(paths[relative])
        if actual != expected:
            raise ValueError(f"Frozen input SHA-256 mismatch: {relative}")
        pins[relative] = {
            "relativePath": relative,
            "bytes": paths[relative].stat().st_size,
            "sha256": actual,
        }
    base_manifest = load_json(paths[BASE_RELATIVE])
    supplemental_manifest = load_json(paths[SUPPLEMENTAL_RELATIVE])
    roster = load_json(paths[ROSTER_RELATIVE])
    metadata = load_json(paths[METADATA_RELATIVE])
    r18v_gate = load_json(paths[R18V_GATE_RELATIVE])
    if roster.get("state") != "PASS_R18UQ3_USABLE_ROSTER_WITH_EXPLICIT_HELD_MEMBERS":
        raise ValueError("R18UQ3 roster is not the usable exact roster.")
    if len(roster.get("invalidOrNullRows", [])) or len(roster.get("unresolvedLots", [])):
        raise ValueError("R18UQ3 contains unresolved lot-level roster defects.")

    base = derive_base_lineages(base_manifest, paths[BASE_RELATIVE])
    supplemental = derive_supplemental_lineages(supplemental_manifest, paths[SUPPLEMENTAL_RELATIVE])
    all_lineages = base + supplemental
    truths = [row["exactScribeLineage"] for row in all_lineages]
    if len(truths) != len(set(truths)):
        raise ValueError("Base and supplemental references contain a duplicate exact scribe lineage.")
    roster_by_truth = roster_index(roster)
    metadata_by_truth = metadata_index(metadata)

    for row in all_lineages:
        truth = str(row["exactScribeLineage"])
        row["rosterMatches"] = roster_by_truth.get(truth, [])
        row["metadataMatches"] = metadata_by_truth.get(truth, [])
        row["authorityCrosswalkState"] = (
            "EXACT_ROSTER_AND_METADATA_MATCH"
            if row["rosterMatches"] and row["metadataMatches"]
            else "EXACT_ROSTER_MATCH_ONLY"
            if row["rosterMatches"]
            else "EXACT_METADATA_MATCH_ONLY"
            if row["metadataMatches"]
            else "HUMAN_CONFIRMED_REFERENCE_ONLY"
        )
    for row in base:
        row["legacyLotSlotReuse"] = legacy_reuse_summary(row, metadata)

    references_by_label: dict[str, list[tuple[str, str]]] = defaultdict(list)
    old_lineages_by_label: dict[str, set[str]] = defaultdict(set)
    new_lineages_by_label: dict[str, set[str]] = defaultdict(set)
    for row in base:
        truth = str(row["exactScribeLineage"])
        raw = str(row["legacyPhysicalIdentity"])
        for variant in row["variants"]:
            for reference in variant["references"]:
                label = str(reference["label"])
                references_by_label[label].append((truth, str(reference["sha256"])))
                old_lineages_by_label[label].add(raw.casefold())
                new_lineages_by_label[label].add(truth)
    for row in supplemental:
        truth = str(row["exactScribeLineage"])
        raw = str(row["physicalIdentity"])
        for reference in row["references"]:
            label = str(reference["label"])
            references_by_label[label].append((truth, str(reference["sha256"])))
            old_lineages_by_label[label].add(raw.casefold())
            new_lineages_by_label[label].add(truth)

    coverage: list[dict[str, Any]] = []
    gate_coverage = r18v_gate.get("coverage", {})
    for label in BODY_LABELS:
        reference_count = len(references_by_label.get(label, []))
        old_count = len(old_lineages_by_label.get(label, set()))
        lineage_count = len(new_lineages_by_label.get(label, set()))
        state = "UNOBSERVED" if not lineage_count else "COVERED" if lineage_count >= 4 else "SPARSE"
        gate_row = gate_coverage.get(label, {})
        if (
            int(gate_row.get("referenceCount", -1)) != reference_count
            or int(gate_row.get("independentPhysicalLineageCount", -1)) != old_count
            or str(gate_row.get("state", "")) != state
        ):
            raise ValueError(f"R18V coverage binding changed for label {label}.")
        if old_count != lineage_count:
            raise ValueError(f"Exact-scribe re-key changes lineage cardinality for label {label}.")
        coverage.append(
            {
                "character": label,
                "state": state,
                "referenceCount": reference_count,
                "legacyPhysicalIdentityLineageCount": old_count,
                "exactScribeLineageCount": lineage_count,
                "minimumEnforceableLineages": MINIMUM_ENFORCEABLE_LINEAGES,
            }
        )

    current_rows = [
        row for row in metadata.get("rows", [])
        if str(row.get("acquisitionKey", "")).upper() == CURRENT_SLOT21_ACQUISITION
    ]
    if len(current_rows) != 1 or require_scribe(current_rows[0].get("scribe"), "current Slot21") != CURRENT_SLOT21_TRUTH:
        raise ValueError("Exact current Slot21 metadata truth changed.")
    legacy_slot21 = [row for row in base if row["legacyPhysicalIdentity"] == "62546_481_SLOT21"]
    if len(legacy_slot21) != 1 or legacy_slot21[0]["exactScribeLineage"] == CURRENT_SLOT21_TRUTH:
        raise ValueError("Legacy/current Slot21 separation is not proven.")

    state_counts: dict[str, int] = defaultdict(int)
    for row in all_lineages:
        state_counts[str(row["authorityCrosswalkState"])] += 1
    return {
        "schema": "argos_opencv_scribe_r18x_exact_scribe_lineage_crosswalk_v1",
        "revision": "OCV02_R18X_EXACT_SCRIBE_REFERENCE_LINEAGE_20260905",
        "classification": "DIAGNOSTIC_ONLY",
        "state": "PASS_R18X_EXACT_SCRIBE_LINEAGE_REKEY_CARDINALITY_PRESERVED",
        "inputPins": list(pins.values()),
        "builderSha256": sha256_file(Path(__file__)),
        "summary": {
            "baseReferenceRows": sum(row["referenceCount"] for row in base),
            "supplementalReferenceRows": sum(row["referenceCount"] for row in supplemental),
            "verifiedReferenceRows": sum(len(rows) for rows in references_by_label.values()),
            "baseExactScribeLineages": len(base),
            "supplementalExactScribeLineages": len(supplemental),
            "combinedExactScribeLineages": len(all_lineages),
            "exactRosterMatchedLineages": sum(bool(row["rosterMatches"]) for row in all_lineages),
            "exactMetadataMatchedLineages": sum(bool(row["metadataMatches"]) for row in all_lineages),
            "exactRosterAndMetadataMatchedLineages": sum(
                bool(row["rosterMatches"] and row["metadataMatches"]) for row in all_lineages
            ),
            "authorityCrosswalkStateCounts": dict(sorted(state_counts.items())),
            "coveredCharacters": "".join(row["character"] for row in coverage if row["state"] == "COVERED"),
            "sparseCharacters": "".join(row["character"] for row in coverage if row["state"] == "SPARSE"),
            "unobservedCharacters": "".join(row["character"] for row in coverage if row["state"] == "UNOBSERVED"),
        },
        "currentSlot21Separation": {
            "legacyRawIdentity": "62546_481_SLOT21",
            "legacyHumanConfirmedTruth": legacy_slot21[0]["exactScribeLineage"],
            "currentAcquisitionKey": CURRENT_SLOT21_ACQUISITION,
            "currentExactMesTruth": CURRENT_SLOT21_TRUTH,
            "state": "PASS_DISTINCT_PHYSICAL_LINEAGES_NOT_ALIASED_BY_REUSED_LOT_SLOT",
        },
        "coverage": coverage,
        "baseLineages": base,
        "supplementalLineages": supplemental,
        "holds": [
            {
                "character": row["character"],
                "code": "UNOBSERVED_EXACT_SCRIBE_LINEAGE" if row["state"] == "UNOBSERVED" else "FEWER_THAN_FOUR_EXACT_SCRIBE_LINEAGES",
                "exactScribeLineageCount": row["exactScribeLineageCount"],
            }
            for row in coverage
            if row["state"] != "COVERED"
        ],
        "invariants": {
            "referencePixelsModified": False,
            "imageBytesDecoded": False,
            "referenceBytesHashVerifiedOnly": True,
            "exactScribeTruthUsedAsLineage": True,
            "legacyLotSlotUsedAsLineageAuthority": False,
            "lotOrSlotInferenceUsed": False,
            "checksumUsedAsTruthOrDecisionAuthority": False,
            "syntheticGlyphsUsed": False,
            "notchUsed": False,
            "trainingAuthorized": False,
            "providerActivationAuthorized": False,
            "publicationAuthorized": False,
            "externalMutationPerformed": False,
        },
    }


def write_new(path: Path, value: dict[str, Any]) -> None:
    payload = json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True) + "\n"
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(payload)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    value = build(args.project)
    write_new(args.output, value)
    print("PASS_R18X_EXACT_SCRIBE_LINEAGE_CROSSWALK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
