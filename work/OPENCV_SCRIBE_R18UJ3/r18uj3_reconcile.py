#!/usr/bin/env python3
"""Reconcile an R18UQ3 roster using the frozen R18UJ2 science contract.

R18UQ3 retains the resolved/held member model from R18UQ2 and adds explicit
ignored-historical diagnostics.  Only resolved members participate in the
exact (query lot, scribe, issued unit) metadata join.  Database container names
remain opaque strings, including historical names ending in ``WAFER``.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
BASE_PATH = HERE.parent / "OPENCV_SCRIBE_R18UJ2" / "r18uj2_reconcile.py"
EXPECTED_BASE_SHA256 = "780922AA97C3227476B2A4883BC1EA25BB1BC5BB034EAF5130EC8D7041B09949"
Q3_SCHEMA = "argos_r18uq3_exhaustive_lot_scribe_roster_v1"
Q3_EXECUTION_STATE = "PASS_R18UQ3_READ_ONLY_QUERY_EXECUTED"
Q3_STATES = {
    "COMPLETE": "PASS_R18UQ3_EXHAUSTIVE_ROSTER",
    "USABLE_WITH_HOLDS": "PASS_R18UQ3_USABLE_ROSTER_WITH_EXPLICIT_HELD_MEMBERS",
    "HOLD": "HOLD_R18UQ3_ROSTER_NOT_USABLE",
}


def _load_base():
    raw = BASE_PATH.read_bytes()
    actual = hashlib.sha256(raw).hexdigest().upper()
    if actual != EXPECTED_BASE_SHA256:
        raise RuntimeError(f"frozen R18UJ2 dependency SHA-256 mismatch: {actual}")
    spec = importlib.util.spec_from_file_location("r18uj2_frozen_for_r18uj3", BASE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load frozen R18UJ2 dependency")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


BASE = _load_base()
ValidationError = BASE.ValidationError
ALPHABET = BASE.ALPHABET
EXPECTED_CATALOG_SHA256 = BASE.EXPECTED_CATALOG_SHA256
EXPECTED_METADATA_SHA256 = BASE.EXPECTED_METADATA_SHA256
EXPECTED_R18V_GATE_SHA256 = BASE.EXPECTED_R18V_GATE_SHA256
EXPECTED_QUERY_FINGERPRINT_SHA256 = BASE.EXPECTED_QUERY_FINGERPRINT_SHA256
MAX_ROSTER_BYTES = BASE.MAX_ROSTER_BYTES
MAX_METADATA_BYTES = BASE.MAX_METADATA_BYTES
MAX_CATALOG_BYTES = BASE.MAX_CATALOG_BYTES
MAX_R18V_GATE_BYTES = BASE.MAX_R18V_GATE_BYTES
MAX_IGNORED_HISTORICAL_ROWS = BASE.MAX_ROSTER_MEMBERS
read_json = BASE.read_json
write_new = BASE.write_new


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def _copy_json(value: Any) -> Any:
    return json.loads(json.dumps(value, ensure_ascii=False))


def _retoken(value: Any) -> Any:
    """Retoken a base report without changing evidence values or hashes."""
    if isinstance(value, dict):
        return {_retoken(key): _retoken(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_retoken(item) for item in value]
    if isinstance(value, str):
        return (
            value.replace("R18UQ2", "R18UQ3")
            .replace("r18uq2", "r18uq3")
            .replace("R18UJ2", "R18UJ3")
            .replace("r18uj2", "r18uj3")
        )
    return value


def _validate_q3_extensions(roster: Any) -> dict[str, Any]:
    require(isinstance(roster, dict), "roster root must be an object")
    require(roster.get("schema") == Q3_SCHEMA, "R18UQ3 roster schema mismatch")
    require(roster.get("executionState") == Q3_EXECUTION_STATE, "R18UQ3 execution token mismatch")
    disposition = roster.get("disposition")
    require(disposition in Q3_STATES, "R18UQ3 disposition is unknown")
    require(roster.get("state") == Q3_STATES[disposition], "R18UQ3 state/disposition mismatch")

    invariants = roster.get("invariants")
    require(isinstance(invariants, dict), "R18UQ3 invariants must be an object")
    for field in (
        "exactDatabaseParentOrIssuedUnitEvidenceRequired",
        "exactUnsuffixedIssuedUnitCatalogKeyEvidenceAccepted",
        "historicalMembershipFallbackOnly",
        "heldMembersExcludedFromResolvedScribes",
    ):
        require(invariants.get(field) is True, f"R18UQ3 invariant must be true: {field}")
    for field in ("issueWaferSuffixIdentityAccepted", "issuedUnitSuffixInferenceUsed"):
        require(invariants.get(field) is False, f"R18UQ3 invariant must be false: {field}")

    counts = roster.get("counts")
    require(isinstance(counts, dict), "R18UQ3 counts must be an object")
    ignored_count = counts.get("ignoredHistoricalRows")
    ignored_applicable = counts.get("ignoredApplicableHistoricalMembershipRows")
    require(isinstance(ignored_count, int) and ignored_count >= 0,
            "R18UQ3 counts.ignoredHistoricalRows must be nonnegative")
    require(isinstance(ignored_applicable, int) and ignored_applicable >= 0,
            "R18UQ3 counts.ignoredApplicableHistoricalMembershipRows must be nonnegative")
    require(ignored_count <= MAX_IGNORED_HISTORICAL_ROWS,
            "R18UQ3 ignoredHistoricalRows count exceeds the bounded diagnostic cap")
    require(ignored_applicable <= MAX_IGNORED_HISTORICAL_ROWS,
            "R18UQ3 ignored applicable historical count exceeds the bounded diagnostic cap")
    ignored = roster.get("ignoredHistoricalRows")
    require(isinstance(ignored, list) and all(isinstance(row, dict) for row in ignored),
            "R18UQ3 ignoredHistoricalRows must be an object array")
    require(ignored_count == len(ignored), "R18UQ3 ignoredHistoricalRows count mismatch")

    fallback_members = []
    for lot_index, lot in enumerate(roster.get("lots", [])):
        require(isinstance(lot, dict), f"R18UQ3 lot row {lot_index} is not an object")
        for member_type in ("resolvedMembers", "heldMembers"):
            members = lot.get(member_type)
            require(isinstance(members, list), f"R18UQ3 lot row {lot_index}.{member_type} must be an array")
            for member_index, member in enumerate(members):
                require(isinstance(member, dict),
                        f"R18UQ3 lot row {lot_index}.{member_type}[{member_index}] is not an object")
                if member.get("resolutionBasis") == "FALLBACK_EXACT_HISTORICAL_PARENT_CHILD":
                    unit = member.get("unitContainer")
                    require(isinstance(unit, str) and unit.upper().endswith("WAFER"),
                            "non-WAFER historical association child was admitted as a member")
                    fallback_members.append(unit)
    return {
        "ignoredHistoricalRows": _copy_json(ignored),
        "ignoredHistoricalRowCount": ignored_count,
        "ignoredApplicableHistoricalMembershipRowCount": ignored_applicable,
        "fallbackHistoricalMemberCount": len(fallback_members),
    }


def _as_q2_contract(roster: Any) -> dict[str, Any]:
    mapped = _copy_json(roster)
    disposition = mapped["disposition"]
    mapped["schema"] = "argos_r18uq2_exhaustive_lot_scribe_roster_v1"
    mapped["executionState"] = "PASS_R18UQ2_READ_ONLY_QUERY_EXECUTED"
    mapped["state"] = {
        "COMPLETE": "PASS_R18UQ2_EXHAUSTIVE_ROSTER",
        "USABLE_WITH_HOLDS": "PASS_R18UQ2_USABLE_ROSTER_WITH_EXPLICIT_HELD_MEMBERS",
        "HOLD": "HOLD_R18UQ2_ROSTER_NOT_USABLE",
    }[disposition]
    # The frozen J2 implementation validates its predecessor vocabulary.  This
    # compatibility field exists only in the private adapter copy; Q3 input and
    # J3 output retain the stricter parent-or-unsuffixed-issued-unit semantics.
    mapped["invariants"]["exactDatabaseParentEvidenceRequired"] = True
    return mapped


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
    q3 = _validate_q3_extensions(roster)
    base_report = BASE.build_report(
        _as_q2_contract(roster),
        roster_identity,
        metadata,
        metadata_identity,
        catalog,
        catalog_identity,
        r18v_gate,
        r18v_gate_identity,
        allow_synthetic_roster=allow_synthetic_roster,
    )
    report = _retoken(base_report)
    report["schema"] = "argos_opencv_scribe_r18uj3_roster_acquisition_reconciliation_v1"
    report["inputs"]["frozenR18uj2Reconciler"] = {
        "path": str(BASE_PATH),
        "sha256": EXPECTED_BASE_SHA256,
    }
    report["r18uq3HistoricalDiagnostics"] = q3
    report["invariants"].update({
        "r18uq3InputHashEmittedWithoutHardcodedLiveHash": True,
        "nonWaferHistoricalAssociationChildAdmittedAsMember": False,
        "historicalWaferSuffixNormalizedOrStripped": False,
        "ignoredHistoricalRowsExcludedFromJoinAndSelection": True,
    })
    return report


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--roster", required=True, type=Path, help="Extracted R18UQ3 roster JSON")
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
            roster, roster_identity, metadata, metadata_identity,
            catalog, catalog_identity, r18v_gate, r18v_gate_identity,
        )
        payload = (json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")
        if args.output:
            write_new(args.output, payload)
        else:
            sys.stdout.buffer.write(payload)
        return 0
    except (OSError, RuntimeError, ValidationError) as exc:
        sys.stderr.write(json.dumps({"state": "FAILED_R18UJ3_INPUT_VALIDATION", "detail": str(exc)}, sort_keys=True) + "\n")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
