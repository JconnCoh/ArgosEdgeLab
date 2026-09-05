#!/usr/bin/env python3
"""Deterministically join an R18UQ1 roster to frozen signed metadata.

The program reads JSON metadata only.  Path/hash values found in metadata are
reported as strings; the referenced files are never opened.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
EXPECTED_CATALOG_SHA256 = "89F37687D0E669A11671C2222CC495333C932C9CCCAA0BE277946AE30EBCDAB5"
EXPECTED_METADATA_SHA256 = "AB800600F24BC2163010580DB1E2D910CA42C882218F4CFC6D60C9371511D5D0"
EXPECTED_R18V_GATE_SHA256 = "BEA75FAC417BEE9D0DB5B3302AEEAD15053C46A2AC434BBB7A49E04AADC437C9"
EXPECTED_QUERY_FINGERPRINT_SHA256 = "8A4F3176D0169931A01B039DA340084697A7FBDE402D0889E23FB971BDEBCA12"
EXPECTED_QUERY_LOTS = 50
TARGET_LINEAGES_PER_CHARACTER = 4
MAX_ROSTER_BYTES = 32 * 1024 * 1024
MAX_METADATA_BYTES = 8 * 1024 * 1024
MAX_CATALOG_BYTES = 128 * 1024
MAX_R18V_GATE_BYTES = 1024 * 1024
MAX_ROSTER_IDENTITIES = 20_000
MAX_METADATA_ROWS = 5_000
SCRIBE_RE = re.compile(r"^[A-Z0-9]{12}$")
LOT_RE = re.compile(r"^\d{5}-\d{3}[A-Z]?$")
UNIT_RE = re.compile(r"^\d{5}-\d{3}[A-Z]?\-\d{3}$")
SHA256_RE = re.compile(r"^[A-Fa-f0-9]{64}$")


class ValidationError(RuntimeError):
    """An input failed a deterministic identity or schema check."""


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def read_json(path: Path, maximum_bytes: int) -> tuple[Any, dict[str, Any]]:
    resolved = path.resolve(strict=True)
    if resolved.is_symlink() or not resolved.is_file():
        raise ValidationError(f"refused non-regular or reparse input: {resolved}")
    size = resolved.stat().st_size
    if size <= 0 or size > maximum_bytes:
        raise ValidationError(f"JSON byte bound refused: {resolved} bytes={size}")
    raw = resolved.read_bytes()
    try:
        value = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValidationError(f"JSON parse failed: {resolved}") from exc
    return value, {
        "path": str(resolved),
        "bytes": len(raw),
        "sha256": sha256_hex(raw),
    }


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def exact_text(value: Any, name: str) -> str:
    require(isinstance(value, str) and bool(value), f"{name} must be a non-empty string")
    return value


def string_list(value: Any, name: str, *, allow_empty: bool = True) -> list[str]:
    require(isinstance(value, list), f"{name} must be an array")
    require(all(isinstance(item, str) and item for item in value), f"{name} contains a non-string or empty value")
    if not allow_empty:
        require(bool(value), f"{name} must not be empty")
    require(len(value) == len(set(value)), f"{name} contains a duplicate")
    return list(value)


def validate_catalog(catalog: Any, identity: dict[str, Any]) -> list[str]:
    require(identity["sha256"] == EXPECTED_CATALOG_SHA256, "frozen catalog SHA-256 mismatch")
    require(isinstance(catalog, dict), "catalog root must be an object")
    require(catalog.get("schema") == "argos_opencv_scribe_r18u_roster_catalog_input_v1", "catalog schema mismatch")
    keys = string_list(catalog.get("queryKeys"), "catalog.queryKeys", allow_empty=False)
    require(len(keys) == EXPECTED_QUERY_LOTS, "catalog must contain exactly 50 query lots")
    require(all(LOT_RE.fullmatch(key) for key in keys), "catalog contains a malformed query lot")
    fingerprint = sha256_hex("\n".join(keys).encode("utf-8"))
    require(fingerprint == EXPECTED_QUERY_FINGERPRINT_SHA256, "catalog ordered query-lot fingerprint mismatch")
    return keys


def validate_metadata(metadata: Any, identity: dict[str, Any]) -> list[dict[str, Any]]:
    require(identity["sha256"] == EXPECTED_METADATA_SHA256, "frozen metadata overlay SHA-256 mismatch")
    require(isinstance(metadata, dict), "metadata root must be an object")
    require(metadata.get("schema") == "argos_verified_scribe_mes_metadata_overlay_v1", "metadata schema mismatch")
    require(metadata.get("state") == "VERIFIED_REVIEW_ONLY", "metadata state mismatch")
    require(metadata.get("lookupAuthority") == "CONFIRMED_12_CHARACTER_SCRIBE_ONLY", "metadata lookup authority mismatch")
    rows = metadata.get("rows")
    require(isinstance(rows, list), "metadata.rows must be an array")
    require(len(rows) <= MAX_METADATA_ROWS, "metadata row cap exceeded")
    require(metadata.get("acquisitionRows") == len(rows), "metadata acquisitionRows count mismatch")
    acquisition_keys: set[str] = set()
    unique_scribes: set[str] = set()
    for index, row in enumerate(rows):
        require(isinstance(row, dict), f"metadata row {index} is not an object")
        acquisition = exact_text(row.get("acquisitionKey"), f"metadata row {index}.acquisitionKey")
        require(acquisition not in acquisition_keys, f"duplicate metadata acquisitionKey: {acquisition}")
        acquisition_keys.add(acquisition)
        scribe = exact_text(row.get("scribe"), f"metadata row {index}.scribe")
        require(bool(SCRIBE_RE.fullmatch(scribe)), f"invalid metadata scribe at row {index}")
        unique_scribes.add(scribe)
        lot = exact_text(row.get("historyBaseLot"), f"metadata row {index}.historyBaseLot")
        require(bool(LOT_RE.fullmatch(lot)), f"invalid metadata historyBaseLot at row {index}")
        unit = exact_text(row.get("issuedWaferContainer"), f"metadata row {index}.issuedWaferContainer")
        require(bool(UNIT_RE.fullmatch(unit)), f"invalid metadata issuedWaferContainer at row {index}")
        require(row.get("metadataState") == "SCRIBE_CONFIRMED_MES_SNAPSHOT", f"metadata state not exact at row {index}")
        require(row.get("mesLineageState") == "MES_SCRIBE_LINEAGE_EXACT", f"MES lineage not exact at row {index}")
    require(metadata.get("confirmedScribes") == len(unique_scribes), "metadata confirmedScribes count mismatch")
    return rows


def validate_r18v_gate(gate: Any, identity: dict[str, Any]) -> dict[str, dict[str, Any]]:
    require(identity["sha256"] == EXPECTED_R18V_GATE_SHA256, "frozen R18V glyph-envelope gate SHA-256 mismatch")
    require(isinstance(gate, dict), "R18V gate root must be an object")
    require(gate.get("schema") == "argos_opencv_scribe_r18v_glyph_envelope_gate_v1", "R18V gate schema mismatch")
    require(gate.get("state") == "PASS_R18V_ZERO_WRONG_ACCEPTED_LINEAGE_GLYPH_ENVELOPES", "R18V gate state mismatch")
    decision = gate.get("decisionInputs")
    require(isinstance(decision, dict), "R18V decisionInputs must be an object")
    require(decision.get("minimumIndependentPhysicalLineages") == TARGET_LINEAGES_PER_CHARACTER,
            "R18V minimum independent lineage threshold mismatch")
    require(decision.get("physicalLineageAware") is True, "R18V gate is not physical-lineage aware")
    coverage = gate.get("coverage")
    require(isinstance(coverage, dict) and set(coverage) == set(ALPHABET), "R18V coverage must contain exactly all 36 characters")
    normalized: dict[str, dict[str, Any]] = {}
    for char in ALPHABET:
        row = coverage[char]
        require(isinstance(row, dict), f"R18V coverage row {char} is not an object")
        count = row.get("independentPhysicalLineageCount")
        references = row.get("referenceCount")
        state = row.get("state")
        require(isinstance(count, int) and count >= 0, f"R18V lineage count invalid for {char}")
        require(isinstance(references, int) and references >= count, f"R18V reference count invalid for {char}")
        require(state in {"COVERED", "SPARSE", "UNOBSERVED"}, f"R18V coverage state invalid for {char}")
        expected_state = "COVERED" if count >= TARGET_LINEAGES_PER_CHARACTER else ("UNOBSERVED" if count == 0 else "SPARSE")
        require(state == expected_state, f"R18V state/count inconsistency for {char}")
        normalized[char] = {
            "state": state,
            "referenceCount": references,
            "independentPhysicalLineageCount": count,
        }
    return normalized


def validate_roster(roster: Any, catalog_keys: list[str], *, allow_synthetic: bool) -> dict[str, Any]:
    require(isinstance(roster, dict), "roster root must be an object")
    require(roster.get("schema") == "argos_r18uq1_exhaustive_lot_scribe_roster_v1", "roster schema mismatch")
    require(roster.get("executionState") == "PASS_R18UQ1_READ_ONLY_QUERY_EXECUTED", "roster execution token mismatch")
    expected_modes = {"FILE_BACKED_SYNTHETIC_SQL_ROW_REHEARSAL"} if allow_synthetic else {
        "LIVE_READ_ONLY_SQL", "LIVE_READ_ONLY_ODBC_DSN"
    }
    require(roster.get("executionMode") in expected_modes,
            f"roster executionMode must be one of {sorted(expected_modes)}")
    if roster.get("executionMode") == "LIVE_READ_ONLY_ODBC_DSN":
        provenance = roster.get("provenance")
        require(isinstance(provenance, dict), "ODBC roster provenance must be an object")
        require(provenance.get("credentialSource") == "CALLER_SUPPLIED_PSCREDENTIAL_NOT_RETURNED",
                "ODBC roster credential-source token mismatch")
        exact_text(provenance.get("odbcDsn"), "ODBC roster provenance.odbcDsn")
        require(provenance.get("database") == "Insite", "ODBC roster database must be Insite")
        require(not ({"userName", "username", "password"} & set(provenance)),
                "ODBC roster provenance contains credential identity or material")
    input_record = roster.get("input")
    require(isinstance(input_record, dict), "roster.input must be an object")
    require(input_record.get("sourceCatalogSha256") == EXPECTED_CATALOG_SHA256, "roster catalog hash binding mismatch")
    require(input_record.get("queryKeyFingerprintSha256") == EXPECTED_QUERY_FINGERPRINT_SHA256, "roster query fingerprint mismatch")
    require(input_record.get("queryKeyCount") == EXPECTED_QUERY_LOTS, "roster input query-lot count mismatch")
    counts = roster.get("counts")
    require(isinstance(counts, dict), "roster.counts must be an object")
    require(counts.get("queryLots") == EXPECTED_QUERY_LOTS, "roster count queryLots mismatch")
    lots = roster.get("lots")
    require(isinstance(lots, list) and len(lots) == EXPECTED_QUERY_LOTS, "roster must emit exactly 50 lot rows")
    roster_lots = [row.get("queryLot") if isinstance(row, dict) else None for row in lots]
    require(roster_lots == catalog_keys, "roster lot rows do not exactly match frozen catalog order")

    identities: list[dict[str, Any]] = []
    lot_states: list[dict[str, Any]] = []
    for lot_index, lot_row in enumerate(lots):
        require(isinstance(lot_row, dict), f"roster lot row {lot_index} is not an object")
        query_lot = catalog_keys[lot_index]
        state = exact_text(lot_row.get("state"), f"roster lot {query_lot}.state")
        scribes = lot_row.get("scribes")
        require(isinstance(scribes, list), f"roster lot {query_lot}.scribes must be an array")
        require(lot_row.get("validScribeCount") == len(scribes), f"roster lot {query_lot} validScribeCount mismatch")
        seen_scribes: set[str] = set()
        for scribe_index, record in enumerate(scribes):
            require(isinstance(record, dict), f"roster lot {query_lot} scribe row {scribe_index} is not an object")
            scribe = exact_text(record.get("scribe"), f"roster lot {query_lot} scribe")
            require(bool(SCRIBE_RE.fullmatch(scribe)), f"invalid roster scribe {scribe} in {query_lot}")
            require(scribe not in seen_scribes, f"duplicate roster scribe {scribe} in {query_lot}")
            seen_scribes.add(scribe)
            units = string_list(record.get("unitContainers"), f"roster {query_lot}/{scribe}.unitContainers", allow_empty=False)
            require(all(UNIT_RE.fullmatch(unit) for unit in units), f"invalid unit container in roster {query_lot}/{scribe}")
            require(all(unit.startswith(query_lot + "-") for unit in units), f"unit container is outside exact roster lot {query_lot}")
            sources = string_list(record.get("evidenceSources"), f"roster {query_lot}/{scribe}.evidenceSources", allow_empty=False)
            require(set(sources).issubset({"DIRECT_CURRENT_CONTAINMENT", "ISSUE_ACTUALS_HISTORY"}), "unknown roster evidence source")
            identities.append({
                "queryLot": query_lot,
                "scribe": scribe,
                "unitContainers": sorted(units),
                "evidenceSources": sorted(sources),
            })
        if state == "COMPLETE":
            require(bool(scribes), f"COMPLETE lot {query_lot} has no valid scribe")
            require(lot_row.get("conflictCount") == 0 and lot_row.get("invalidRowCount") == 0,
                    f"COMPLETE lot {query_lot} contains a conflict or invalid row")
        lot_states.append({"queryLot": query_lot, "state": state, "validScribeCount": len(scribes)})

    require(len(identities) <= MAX_ROSTER_IDENTITIES, "roster identity cap exceeded")
    unique_scribes = {row["scribe"] for row in identities}
    require(counts.get("uniqueValidScribes") == len(unique_scribes), "roster uniqueValidScribes count mismatch")
    conflicts = roster.get("conflicts")
    invalid_rows = roster.get("invalidOrNullRows")
    holds = roster.get("holds")
    unmatched = string_list(roster.get("unmatchedLots"), "roster.unmatchedLots")
    require(isinstance(conflicts, list) and counts.get("conflicts") == len(conflicts), "roster conflict count mismatch")
    require(isinstance(invalid_rows, list) and counts.get("invalidOrNullRows") == len(invalid_rows), "roster invalid-row count mismatch")
    require(isinstance(holds, list), "roster.holds must be an array")
    require(counts.get("unmatchedLots") == len(unmatched), "roster unmatched-lot count mismatch")
    expected_unmatched = [row["queryLot"] for row in lot_states if row["validScribeCount"] == 0]
    require(unmatched == expected_unmatched, "roster unmatchedLots does not equal empty lot rows in catalog order")
    invariants = roster.get("invariants")
    require(isinstance(invariants, dict), "roster.invariants must be an object")
    require(invariants.get("readOnlySql") is True, "roster did not assert read-only SQL")
    require(invariants.get("parameterizedLotKeys") is True, "roster did not assert parameterized lot keys")
    for field in ("lotSlotIdentityInferenceUsed", "imagesAccessed", "jbodAccessed", "credentialsReturned",
                  "tasksOrProcessesAccessed", "queuesAccessed", "sourceMutationPerformed", "productionRoutingEnabled"):
        require(invariants.get(field) is False, f"roster invariant must be false: {field}")

    disposition = roster.get("disposition")
    state = roster.get("state")
    require(disposition in {"COMPLETE", "HOLD"}, "roster disposition is unknown")
    if disposition == "HOLD":
        require(state == "HOLD_R18UQ1_ROSTER_NOT_EXHAUSTIVE", "HOLD roster state mismatch")
        require(bool(holds), "HOLD roster omitted hold reasons")
    exhaustive = (
        disposition == "COMPLETE"
        and state == "PASS_R18UQ1_EXHAUSTIVE_ROSTER"
        and not unmatched
        and not conflicts
        and not invalid_rows
        and all(row["state"] == "COMPLETE" for row in lot_states)
    )
    if disposition == "COMPLETE":
        require(exhaustive, "roster claimed COMPLETE without an exhaustive conflict-free 50-lot result")
    return {
        "exhaustive": exhaustive,
        "identities": sorted(identities, key=lambda row: (row["queryLot"], row["scribe"])),
        "lotStates": lot_states,
        "unmatchedLots": unmatched,
        "conflicts": conflicts,
        "invalidRows": invalid_rows,
    }


def _walk_scalars(value: Any, pointer: str = "") -> Iterable[tuple[str, Any]]:
    if isinstance(value, dict):
        for key in sorted(value):
            escaped = str(key).replace("~", "~0").replace("/", "~1")
            yield from _walk_scalars(value[key], pointer + "/" + escaped)
    elif isinstance(value, list):
        for index, item in enumerate(value):
            yield from _walk_scalars(item, pointer + f"/{index}")
    elif isinstance(value, (str, int, float, bool)) or value is None:
        yield pointer or "/", value


def extract_source_fields(row: dict[str, Any]) -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    paths: list[dict[str, str]] = []
    hashes: list[dict[str, str]] = []
    invalid_hashes: list[dict[str, str]] = []
    for pointer, value in _walk_scalars(row):
        if not isinstance(value, str) or not value:
            continue
        leaf = pointer.rsplit("/", 1)[-1].lower()
        if "path" in leaf:
            paths.append({"field": pointer, "value": value})
        if "sha256" in leaf or leaf.endswith("hash"):
            item = {"field": pointer, "value": value.upper()}
            if SHA256_RE.fullmatch(value):
                hashes.append(item)
            else:
                invalid_hashes.append(item)
    paths.sort(key=lambda item: (item["field"], item["value"]))
    hashes.sort(key=lambda item: (item["field"], item["value"]))
    invalid_hashes.sort(key=lambda item: (item["field"], item["value"]))
    return paths, hashes, invalid_hashes


def lineage_key(query_lot: str, unit: str, scribe: str) -> str:
    # Each component is an exact field from signed evidence; no slot is parsed.
    return f"{query_lot}|{unit}|{scribe}"


def select_data_pull(
    joined_rows: list[dict[str, Any]],
    character_rows: dict[str, dict[str, Any]],
    r18v_coverage: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    target_characters = [char for char in ALPHABET if r18v_coverage[char]["state"] in {"SPARSE", "UNOBSERVED"}]
    required_additions = {
        char: TARGET_LINEAGES_PER_CHARACTER - r18v_coverage[char]["independentPhysicalLineageCount"]
        for char in target_characters
    }
    by_lineage: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in joined_rows:
        by_lineage[row["independentLineageKey"]].append(row)

    candidates: dict[str, dict[str, Any]] = {}
    source_reference_candidates = 0
    for key in sorted(by_lineage):
        rows = sorted(by_lineage[key], key=lambda item: item["acquisitionKey"])
        exact_source_rows = [row for row in rows if row["sourcePaths"] and row["sourceHashes"]]
        representative = exact_source_rows[0] if exact_source_rows else rows[0]
        all_characters = sorted(set(representative["scribe"]), key=ALPHABET.index)
        target_coverage = [char for char in all_characters if char in required_additions]
        if not target_coverage:
            continue
        entry = {
            "independentLineageKey": key,
            "queryLot": representative["queryLot"],
            "scribe": representative["scribe"],
            "issuedWaferContainer": representative["issuedWaferContainer"],
            "acquisitionKey": representative["acquisitionKey"],
            "allScribeCharacters": all_characters,
            "candidateTargetCharactersPresent": target_coverage,
            "availableAcquisitionKeys": [row["acquisitionKey"] for row in rows],
            "sourcePaths": representative["sourcePaths"],
            "sourceHashes": representative["sourceHashes"],
            "selectionLocatorState": (
                "EXACT_SOURCE_PATH_AND_HASH_PRESENT"
                if representative["sourcePaths"] and representative["sourceHashes"]
                else "ACQUISITION_KEY_ONLY_SOURCE_LOOKUP_REQUIRED"
            ),
        }
        if exact_source_rows:
            source_reference_candidates += 1
        candidates[key] = entry

    possible_counts = Counter()
    for entry in candidates.values():
        possible_counts.update(entry["candidateTargetCharactersPresent"])
    goals = {char: min(required_additions[char], possible_counts[char]) for char in target_characters}
    current = Counter()
    remaining = dict(candidates)
    selected: list[dict[str, Any]] = []
    while any(current[char] < goals[char] for char in target_characters):
        ranked: list[tuple[int, str, dict[str, Any]]] = []
        for key, entry in remaining.items():
            score = sum(1 for char in entry["candidateTargetCharactersPresent"] if current[char] < goals[char])
            if score:
                ranked.append((-score, key, entry))
        if not ranked:
            break
        _, key, entry = min(ranked, key=lambda item: (item[0], item[1]))
        selected.append(entry)
        current.update(entry["candidateTargetCharactersPresent"])
        del remaining[key]

    # Make the deterministic greedy solution inclusion-minimal.  This does not
    # claim a global minimum-cardinality proof.
    changed = True
    while changed:
        changed = False
        for index in range(len(selected) - 1, -1, -1):
            trial = Counter()
            for selected_index, entry in enumerate(selected):
                if selected_index != index:
                    trial.update(entry["candidateTargetCharactersPresent"])
            if all(trial[char] >= goals[char] for char in target_characters):
                selected.pop(index)
                current = trial
                changed = True

    requested_counts = Counter()
    for entry in selected:
        requested = [
            char for char in entry["candidateTargetCharactersPresent"]
            if requested_counts[char] < goals[char]
        ]
        entry["requestedGlyphLabels"] = requested
        requested_counts.update(requested)

    goal_rows = []
    unresolved = []
    for char in ALPHABET:
        r18v = r18v_coverage[char]
        targeted = char in required_additions
        needed = required_additions.get(char, 0)
        selected_count = requested_counts[char] if targeted else 0
        selected_candidate_occurrences = sum(
            char in entry["candidateTargetCharactersPresent"] for entry in selected
        ) if targeted else 0
        possible = possible_counts[char] if targeted else 0
        if not targeted:
            goal_state = "NOT_TARGETED_R18V_ALREADY_COVERED"
        elif possible == 0:
            goal_state = "HOLD_NO_CANDIDATE_MES_UNIT_LINEAGE"
        elif possible < needed:
            goal_state = "HOLD_INSUFFICIENT_CANDIDATE_MES_UNIT_LINEAGES"
        else:
            goal_state = "CANDIDATE_SET_SELECTED_EXACT_REFERENCE_CROSSWALK_PENDING"
        goal_row = {
            "character": char,
            "r18vCoverageState": r18v["state"],
            "r18vIndependentPhysicalLineageCount": r18v["independentPhysicalLineageCount"],
            "targetedForDataPull": targeted,
            "additionalIndependentLineagesNeeded": needed,
            "availableCandidateMesUnitLineages": possible,
            "selectedCandidateMesUnitLineages": selected_count,
            "incidentalOccurrencesInOtherSelectedAcquisitions": selected_candidate_occurrences - selected_count,
            "potentialTotalIfEveryRequestedGlyphIsNew": r18v["independentPhysicalLineageCount"] + selected_count,
            "guaranteedTotalBeforeExactCrosswalk": r18v["independentPhysicalLineageCount"],
            "exactReferenceCrosswalkProven": False,
            "state": goal_state,
        }
        goal_rows.append(goal_row)
        if targeted:
            unresolved_row = dict(goal_row)
            unresolved_row["rosterOccurrenceCount"] = character_rows[char]["rosterOccurrenceCount"]
            unresolved.append(unresolved_row)

    return {
        "scope": "R18V_SPARSE_AND_UNOBSERVED_CLASSES_ONLY",
        "selectionMethod": "DETERMINISTIC_GREEDY_THEN_REDUNDANCY_PRUNE",
        "minimality": "INCLUSION_MINIMAL_NO_GLOBAL_CARDINALITY_CLAIM",
        "targetIndependentLineagesPerCharacter": TARGET_LINEAGES_PER_CHARACTER,
        "candidateLineageDefinition": "exact queryLot + issuedWaferContainer + scribe fields; distinct within this candidate set only",
        "referenceLineageDefinition": "R18V independent physical lineage; identities are not enumerated by the pinned gate",
        "crosswalkState": "UNPROVEN_R18V_GATE_EXPOSES_COUNTS_NOT_REFERENCE_LINEAGE_IDENTITIES",
        "candidateOverlapWithExistingReferencesCredited": 0,
        "coveredClassesRequestedAdditionalLineages": 0,
        "targetCharacters": target_characters,
        "candidateLineageCount": len(candidates),
        "candidateLineagesWithExactSourcePathAndHash": source_reference_candidates,
        "selectedLineageCount": len(selected),
        "selectedLineagesWithExactSourcePathAndHash": sum(
            entry["selectionLocatorState"] == "EXACT_SOURCE_PATH_AND_HASH_PRESENT" for entry in selected
        ),
        "selected": selected,
        "goals": goal_rows,
        "unresolvedCharacters": unresolved,
    }


def build_report(
    roster: Any,
    roster_identity: dict[str, Any],
    metadata: Any,
    metadata_identity: dict[str, Any],
    catalog: Any,
    catalog_identity: dict[str, Any],
    r18v_gate: Any,
    r18v_gate_identity: dict[str, Any],
    *,
    allow_synthetic_roster: bool = False,
) -> dict[str, Any]:
    catalog_keys = validate_catalog(catalog, catalog_identity)
    metadata_rows = validate_metadata(metadata, metadata_identity)
    r18v_coverage = validate_r18v_gate(r18v_gate, r18v_gate_identity)
    checked = validate_roster(roster, catalog_keys, allow_synthetic=allow_synthetic_roster)

    exact_triples: dict[tuple[str, str, str], dict[str, Any]] = {}
    lot_scribe_pairs: set[tuple[str, str]] = set()
    for identity in checked["identities"]:
        pair = (identity["queryLot"], identity["scribe"])
        lot_scribe_pairs.add(pair)
        for unit in identity["unitContainers"]:
            exact_triples[(identity["queryLot"], identity["scribe"], unit)] = identity

    joined_rows: list[dict[str, Any]] = []
    metadata_not_in_roster: list[dict[str, Any]] = []
    metadata_unit_mismatches: list[dict[str, Any]] = []
    joined_triples: set[tuple[str, str, str]] = set()
    catalog_set = set(catalog_keys)
    metadata_outside_catalog = 0
    for row in metadata_rows:
        lot = row["historyBaseLot"]
        if lot not in catalog_set:
            metadata_outside_catalog += 1
            continue
        scribe = row["scribe"]
        unit = row["issuedWaferContainer"]
        triple = (lot, scribe, unit)
        if triple not in exact_triples:
            unresolved = {
                "queryLot": lot,
                "scribe": scribe,
                "issuedWaferContainer": unit,
                "acquisitionKey": row["acquisitionKey"],
            }
            if (lot, scribe) in lot_scribe_pairs:
                unresolved["code"] = "EXACT_UNIT_CONTAINER_NOT_IN_R18UQ1_ROSTER"
                metadata_unit_mismatches.append(unresolved)
            else:
                unresolved["code"] = "EXACT_LOT_SCRIBE_NOT_IN_R18UQ1_ROSTER"
                metadata_not_in_roster.append(unresolved)
            continue
        paths, hashes, invalid_hashes = extract_source_fields(row)
        joined_rows.append({
            "queryLot": lot,
            "scribe": scribe,
            "issuedWaferContainer": unit,
            "independentLineageKey": lineage_key(lot, unit, scribe),
            "acquisitionKey": row["acquisitionKey"],
            "epiWaferNumber": row.get("epiWaferNumber"),
            "scanTimestampLocal": row.get("scanTimestampLocal"),
            "backsideRegimeState": row.get("backsideRegimeState"),
            "metadataState": row.get("metadataState"),
            "mesLineageState": row.get("mesLineageState"),
            "sourcePaths": paths,
            "sourceHashes": hashes,
            "invalidSourceHashFields": invalid_hashes,
        })
        joined_triples.add(triple)
    joined_rows.sort(key=lambda row: (row["queryLot"], row["scribe"], row["issuedWaferContainer"], row["acquisitionKey"]))
    metadata_not_in_roster.sort(key=lambda row: (row["queryLot"], row["scribe"], row["issuedWaferContainer"], row["acquisitionKey"]))
    metadata_unit_mismatches.sort(key=lambda row: (row["queryLot"], row["scribe"], row["issuedWaferContainer"], row["acquisitionKey"]))

    unresolved_roster = []
    for triple, identity in sorted(exact_triples.items()):
        if triple not in joined_triples:
            unresolved_roster.append({
                "code": "NO_EXACT_SIGNED_METADATA_ACQUISITION",
                "queryLot": triple[0],
                "scribe": triple[1],
                "issuedWaferContainer": triple[2],
                "evidenceSources": identity["evidenceSources"],
            })

    occurrence_counts = Counter()
    identity_counts = Counter()
    lot_lineages: dict[str, set[str]] = {char: set() for char in ALPHABET}
    for identity in checked["identities"]:
        occurrence_counts.update(identity["scribe"])
        for char in set(identity["scribe"]):
            identity_counts[char] += 1
            lot_lineages[char].add(identity["queryLot"])
    joined_lineages: dict[str, set[str]] = {char: set() for char in ALPHABET}
    for triple in joined_triples:
        key = lineage_key(triple[0], triple[2], triple[1])
        for char in set(triple[1]):
            joined_lineages[char].add(key)
    character_rows = {
        char: {
            "character": char,
            "rosterOccurrenceCount": occurrence_counts[char],
            "rosterIdentityCount": identity_counts[char],
            "exactRosterLotCount": len(lot_lineages[char]),
            "candidateMesUnitLineageCount": len(joined_lineages[char]),
            "r18vCoverageState": r18v_coverage[char]["state"],
            "r18vReferenceCount": r18v_coverage[char]["referenceCount"],
            "r18vIndependentPhysicalLineageCount": r18v_coverage[char]["independentPhysicalLineageCount"],
            "mesUnitToR18vReferenceLineageCrosswalkProven": False,
        }
        for char in ALPHABET
    }
    selection = select_data_pull(joined_rows, character_rows, r18v_coverage)

    holds = []
    if not checked["exhaustive"]:
        holds.append({"code": "R18UQ1_ROSTER_NOT_EXHAUSTIVE"})
    if unresolved_roster:
        holds.append({"code": "ROSTER_IDENTITIES_WITHOUT_EXACT_METADATA_ACQUISITION", "count": len(unresolved_roster)})
    if metadata_unit_mismatches:
        holds.append({"code": "SIGNED_METADATA_UNIT_MISMATCH", "count": len(metadata_unit_mismatches)})
    if selection["targetCharacters"]:
        holds.append({
            "code": "EXACT_R18V_REFERENCE_TO_MES_UNIT_CROSSWALK_REQUIRED",
            "count": len(selection["targetCharacters"]),
        })
    insufficient_candidates = [
        row for row in selection["goals"]
        if row["state"] in {"HOLD_NO_CANDIDATE_MES_UNIT_LINEAGE", "HOLD_INSUFFICIENT_CANDIDATE_MES_UNIT_LINEAGES"}
    ]
    if insufficient_candidates:
        holds.append({"code": "INSUFFICIENT_CANDIDATE_MES_UNIT_COVERAGE", "count": len(insufficient_candidates)})
    invalid_source_hash_count = sum(len(row["invalidSourceHashFields"]) for row in joined_rows)
    if invalid_source_hash_count:
        holds.append({"code": "INVALID_SOURCE_HASH_FIELD", "count": invalid_source_hash_count})

    return {
        "schema": "argos_opencv_scribe_r18uj1_roster_acquisition_reconciliation_v1",
        "state": "PASS_R18UJ1_RECONCILIATION_COMPLETE" if not holds else "HOLD_R18UJ1_RECONCILIATION_INCOMPLETE",
        "classification": "DIAGNOSTIC_ONLY",
        "inputs": {
            "r18uq1Roster": roster_identity,
            "frozenCatalog": catalog_identity,
            "frozenSignedMetadataOverlay": metadata_identity,
            "frozenR18vGlyphEnvelopeGate": r18v_gate_identity,
        },
        "rosterValidation": {
            "exactCatalogOrderMatched": True,
            "queryLotCount": len(catalog_keys),
            "queryKeyFingerprintSha256": EXPECTED_QUERY_FINGERPRINT_SHA256,
            "exhaustive": checked["exhaustive"],
            "lotStates": checked["lotStates"],
            "unmatchedLots": checked["unmatchedLots"],
            "conflictCount": len(checked["conflicts"]),
            "invalidRowCount": len(checked["invalidRows"]),
        },
        "counts": {
            "rosterIdentities": len(checked["identities"]),
            "rosterUnitIdentities": len(exact_triples),
            "signedMetadataRows": len(metadata_rows),
            "signedMetadataRowsOutside50LotCatalog": metadata_outside_catalog,
            "joinedAcquisitionRows": len(joined_rows),
            "joinedIndependentMesUnitLineages": len(joined_triples),
            "rosterUnitIdentitiesWithoutAcquisition": len(unresolved_roster),
            "metadataRowsWithLotScribeAbsentFromRoster": len(metadata_not_in_roster),
            "metadataRowsWithUnitMismatch": len(metadata_unit_mismatches),
            "joinedRowsWithSourcePathAndHash": sum(bool(row["sourcePaths"] and row["sourceHashes"]) for row in joined_rows),
        },
        "rosterToAcquisitionRows": joined_rows,
        "generalRosterCharacterCoverage": [character_rows[char] for char in ALPHABET],
        "unresolved": {
            "rosterUnitsWithoutAcquisition": unresolved_roster,
            "metadataRowsWithLotScribeAbsentFromRoster": metadata_not_in_roster,
            "metadataRowsWithExactUnitMismatch": metadata_unit_mismatches,
        },
        "nextDataPullSelection": selection,
        "holds": holds,
        "invariants": {
            "catalogIdentityFrozen": True,
            "metadataIdentityFrozen": True,
            "r18vGlyphEnvelopeGateIdentityFrozen": True,
            "joinUsesExactLotScribeAndIssuedWaferContainer": True,
            "candidateMesLineagesUseExactUnitIdentity": True,
            "mesUnitIdentityAssumedEqualToR18vReferenceLineage": False,
            "overlapWithExistingR18vReferencesCredited": False,
            "lotOrSlotIdentityInferred": False,
            "checksumUsedAsAuthority": False,
            "imageBytesRead": False,
            "referencedSourcePathsOpened": False,
            "jbodOrPortalAccessed": False,
            "tasksProcessesOrQueuesAccessed": False,
            "externalMutationPerformed": False,
            "productionRoutingEnabled": False,
        },
    }


def write_new(path: Path, payload: bytes) -> None:
    resolved = path.resolve()
    require(resolved.parent.is_dir(), f"output parent does not exist: {resolved.parent}")
    try:
        descriptor = os.open(str(resolved), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError as exc:
        raise ValidationError(f"output already exists; refusing overwrite: {resolved}") from exc
    with os.fdopen(descriptor, "wb") as stream:
        stream.write(payload)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--roster", required=True, type=Path, help="Extracted live R18UQ1 roster JSON")
    parser.add_argument("--metadata", required=True, type=Path, help="Frozen signed metadata overlay JSON")
    parser.add_argument("--catalog", required=True, type=Path, help="Frozen 50-lot catalog input JSON")
    parser.add_argument("--r18v-gate", required=True, type=Path, help="Frozen R18V glyph-envelope gate JSON")
    parser.add_argument("--output", type=Path, help="Create-new output JSON; stdout is used when omitted")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        roster, roster_identity = read_json(args.roster, MAX_ROSTER_BYTES)
        metadata, metadata_identity = read_json(args.metadata, MAX_METADATA_BYTES)
        catalog, catalog_identity = read_json(args.catalog, MAX_CATALOG_BYTES)
        r18v_gate, r18v_gate_identity = read_json(args.r18v_gate, MAX_R18V_GATE_BYTES)
        report = build_report(
            roster,
            roster_identity,
            metadata,
            metadata_identity,
            catalog,
            catalog_identity,
            r18v_gate,
            r18v_gate_identity,
        )
        payload = (json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")
        if args.output:
            write_new(args.output, payload)
        else:
            sys.stdout.buffer.write(payload)
        return 0
    except (OSError, ValidationError) as exc:
        sys.stderr.write(json.dumps({"state": "FAILED_R18UJ1_INPUT_VALIDATION", "detail": str(exc)}, sort_keys=True) + "\n")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
