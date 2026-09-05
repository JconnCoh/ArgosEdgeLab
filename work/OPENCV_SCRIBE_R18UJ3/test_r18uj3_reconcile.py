#!/usr/bin/env python3
"""Focused R18UQ3 contract tests for R18UJ3."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path


HERE = Path(__file__).resolve().parent
WORKTREE = HERE.parents[1]
MODULE_PATH = HERE / "r18uj3_reconcile.py"
J2_TEST_PATH = HERE.parent / "OPENCV_SCRIBE_R18UJ2" / "test_r18uj2_reconcile.py"
CATALOG_PATH = WORKTREE / "work" / "OPENCV_SCRIBE_R18U" / "R18U_ROSTER_CATALOG_INPUT.json"
METADATA_PATH = WORKTREE / "work" / "OPENCV_SCRIBE_R18U" / "evidence" / "VERIFIED_METADATA_OVERLAY_20260814.json"
R18V_GATE_PATH = WORKTREE / "work" / "OPENCV_SCRIBE_R18V" / "R18V_GLYPH_ENVELOPE_GATE.json"


def load(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise AssertionError(f"could not load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def as_q3(roster: dict) -> dict:
    out = json.loads(json.dumps(roster))
    out["schema"] = "argos_r18uq3_exhaustive_lot_scribe_roster_v1"
    out["executionState"] = "PASS_R18UQ3_READ_ONLY_QUERY_EXECUTED"
    out["state"] = "PASS_R18UQ3_EXHAUSTIVE_ROSTER"
    out["counts"]["ignoredHistoricalRows"] = 1
    # Live-shaped counters are intentionally independent: one malformed or
    # irrelevant row is reported in the diagnostic array, while 253 valid
    # historical membership rows were bypassed because primary evidence won.
    out["counts"]["ignoredApplicableHistoricalMembershipRows"] = 253
    out["invariants"].pop("exactDatabaseParentEvidenceRequired", None)
    out["invariants"].update({
        "exactDatabaseParentOrIssuedUnitEvidenceRequired": True,
        "exactUnsuffixedIssuedUnitCatalogKeyEvidenceAccepted": True,
        "issueWaferSuffixIdentityAccepted": False,
    })
    out["ignoredHistoricalRows"] = [{
        "source": "ASSOCIATE_HISTORY",
        "childContainer": "NON_WAFER_DIAGNOSTIC_CHILD",
        "code": "NON_WAFER_HISTORICAL_CHILD_DIAGNOSTIC_ONLY",
    }]
    return out


def build(module, roster, metadata, metadata_identity, catalog, catalog_identity, gate, gate_identity):
    raw = (json.dumps(roster, sort_keys=True) + "\n").encode("utf-8")
    identity = {"path": "SYNTHETIC_R18UQ3", "bytes": len(raw), "sha256": module.BASE.sha256_hex(raw)}
    report = module.build_report(
        roster, identity, metadata, metadata_identity, catalog, catalog_identity,
        gate, gate_identity, allow_synthetic_roster=True,
    )
    return report, identity


def main() -> int:
    module = load(MODULE_PATH, "r18uj3_reconcile")
    helper = load(J2_TEST_PATH, "r18uj2_test_helpers")
    catalog, catalog_identity = module.read_json(CATALOG_PATH, module.MAX_CATALOG_BYTES)
    metadata, metadata_identity = module.read_json(METADATA_PATH, module.MAX_METADATA_BYTES)
    gate, gate_identity = module.read_json(R18V_GATE_PATH, module.MAX_R18V_GATE_BYTES)

    roster = as_q3(helper.make_roster(module.BASE, catalog, metadata))
    slot21 = next(row for row in roster["lots"] if row["queryLot"] == "62546-481")
    exact_issue_member = slot21["resolvedMembers"][0]
    assert exact_issue_member["unitContainer"] == "62546-481-010"
    assert exact_issue_member["resolvedScribe"] == "13HFX135SUE3"
    exact_issue_member["evidenceSources"] = ["ISSUE_ACTUALS_HISTORY"]
    exact_issue_member["evidence"] = [{
        "source": "ISSUE_ACTUALS_HISTORY",
        "unitContainer": "62546-481-010",
        "scribe": "13HFX135SUE3",
        "membershipEvidenceBasis": "EXACT_ISSUED_UNIT_CATALOG_KEY",
    }]

    historical_lot = roster["lots"][-1]
    historical_member = historical_lot["resolvedMembers"][0]
    historical_child = historical_lot["queryLot"] + "-040WAFER"
    historical_member["unitContainer"] = historical_child
    historical_member["resolutionBasis"] = "FALLBACK_EXACT_HISTORICAL_PARENT_CHILD"

    first, input_identity = build(
        module, roster, metadata, metadata_identity, catalog, catalog_identity, gate, gate_identity,
    )
    second, _ = build(
        module, roster, metadata, metadata_identity, catalog, catalog_identity, gate, gate_identity,
    )
    assert first == second, "R18UJ3 output is not deterministic"
    assert first["schema"] == "argos_opencv_scribe_r18uj3_roster_acquisition_reconciliation_v1"
    assert first["inputs"]["r18uq3Roster"]["sha256"] == input_identity["sha256"]
    assert first["inputs"]["frozenR18uj2Reconciler"]["sha256"] == module.EXPECTED_BASE_SHA256
    assert first["nextDataPullSelection"]["actionable"] is True
    exact_rows = [
        row for row in first["resolvedRosterToAcquisitionRows"]
        if row["queryLot"] == "62546-481"
        and row["scribe"] == "13HFX135SUE3"
        and row["issuedWaferContainer"] == "62546-481-010"
    ]
    assert len(exact_rows) == 16, "exact issue-unit triple did not join all frozen acquisitions"
    unresolved = first["unresolved"]["resolvedRosterMembersWithoutAcquisition"]
    historical_rows = [row for row in unresolved if row["databaseSourceContainerIdentity"] == historical_child]
    assert len(historical_rows) == 1
    assert historical_rows[0]["issuedWaferContainerMatched"] is False
    assert historical_rows[0]["databaseSourceContainerEndsWithWafer"] is True
    assert not any(
        row["databaseSourceContainerIdentity"] == historical_child[:-5]
        for row in first["resolvedRosterToAcquisitionRows"]
    ), "historical WAFER suffix was stripped or normalized into a metadata unit"
    assert first["r18uq3HistoricalDiagnostics"]["ignoredHistoricalRowCount"] == 1
    assert first["r18uq3HistoricalDiagnostics"]["ignoredApplicableHistoricalMembershipRowCount"] == 253
    assert first["invariants"]["ignoredHistoricalRowsExcludedFromJoinAndSelection"] is True
    serialized_report = json.dumps(first, sort_keys=True)
    assert (
        "R18UQ2" not in serialized_report and "r18uq2" not in serialized_report
    ), "emitted J3 report contains a stale R18UQ2 token"

    # R18UQ3 HOLD remains non-actionable.
    hold = json.loads(json.dumps(roster))
    hold["disposition"] = "HOLD"
    hold["state"] = "HOLD_R18UQ3_ROSTER_NOT_USABLE"
    hold["holds"] = [{"code": "SYNTHETIC_HOLD"}]
    hold_report, _ = build(module, hold, metadata, metadata_identity, catalog, catalog_identity, gate, gate_identity)
    assert hold_report["nextDataPullSelection"]["actionable"] is False
    assert hold_report["nextDataPullSelection"]["selected"] == []

    # An exact metadata-shaped identity isolated as held cannot join or select.
    usable = json.loads(json.dumps(roster))
    lot = next(row for row in usable["lots"] if row["queryLot"] == "62546-481")
    other = next(
        row for row in metadata["rows"]
        if row["historyBaseLot"] == "62546-481"
        and row["issuedWaferContainer"] != "62546-481-010"
    )
    lot["heldMembers"] = [{
        "queryLot": "62546-481",
        "unitContainer": other["issuedWaferContainer"],
        "resolvedScribe": None,
        "resolutionBasis": "PRIMARY_EXACT_DB_PARENT",
        "holdCodes": ["CURRENT_HISTORY_SCRIBE_DISAGREEMENT"],
        "sourceSeparatedCandidates": {
            "currentContainerSubstrate": [other["scribe"]],
            "issueActualsHistory": ["ZZZZZZZZZZZZ"],
        },
        "parentContainers": ["62546-481"],
        "sourceEpiContainers": [],
        "evidenceSources": ["DIRECT_CURRENT_CONTAINMENT", "ISSUE_ACTUALS_HISTORY"],
        "acquisitionTimestamps": [],
        "evidence": [],
    }]
    lot["heldMemberCount"] = 1
    lot["state"] = "PARTIAL_HOLD"
    usable["counts"]["heldMembers"] = 1
    usable["disposition"] = "USABLE_WITH_HOLDS"
    usable["state"] = "PASS_R18UQ3_USABLE_ROSTER_WITH_EXPLICIT_HELD_MEMBERS"
    usable["holds"] = [{"code": "ISOLATED_HELD_MEMBERS", "count": 1}]
    usable_report, _ = build(module, usable, metadata, metadata_identity, catalog, catalog_identity, gate, gate_identity)
    assert usable_report["nextDataPullSelection"]["actionable"] is True
    assert not any(
        row["scribe"] == other["scribe"] and row["issuedWaferContainer"] == other["issuedWaferContainer"]
        for row in usable_report["resolvedRosterToAcquisitionRows"]
    )

    bad_historical = json.loads(json.dumps(roster))
    bad_historical["lots"][-1]["resolvedMembers"][0]["unitContainer"] = "NON_WAFER_CHILD"
    try:
        build(module, bad_historical, metadata, metadata_identity, catalog, catalog_identity, gate, gate_identity)
    except module.ValidationError:
        pass
    else:
        raise AssertionError("non-WAFER historical child was admitted as a member")

    print(json.dumps({
        "schema": "argos_opencv_scribe_r18uj3_focused_test_v1",
        "state": "PASS_R18UJ3_FOCUSED_R18UQ3_CONTRACT_TEST",
        "exactIssueUnitJoinedAcquisitionRows": len(exact_rows),
        "historicalWaferSuffixPreservedWithoutNormalization": True,
        "ignoredHistoricalRowsExcluded": True,
        "independentIgnoredHistoricalCountersAccepted": "1_DIAGNOSTIC_253_APPLICABLE_BYPASSED",
        "heldMemberExcluded": True,
        "holdSelectionEmpty": True,
        "liveRosterHashHardcoded": False,
        "staleR18uq2TokensInOutput": 0,
        "imageBytesRead": False,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
