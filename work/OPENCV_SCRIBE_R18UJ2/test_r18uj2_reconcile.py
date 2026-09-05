#!/usr/bin/env python3
"""Focused contract tests for the R18UJ2 roster reconciler."""

from __future__ import annotations

import importlib.util
import json
import tempfile
from pathlib import Path


HERE = Path(__file__).resolve().parent
WORKTREE = HERE.parents[1]
MODULE_PATH = HERE / "r18uj2_reconcile.py"
CATALOG_PATH = WORKTREE / "work" / "OPENCV_SCRIBE_R18U" / "R18U_ROSTER_CATALOG_INPUT.json"
METADATA_PATH = WORKTREE / "work" / "OPENCV_SCRIBE_R18U" / "evidence" / "VERIFIED_METADATA_OVERLAY_20260814.json"
R18V_GATE_PATH = WORKTREE / "work" / "OPENCV_SCRIBE_R18V" / "R18V_GLYPH_ENVELOPE_GATE.json"


def load_module():
    spec = importlib.util.spec_from_file_location("r18uj2_reconcile", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("could not load reconciler module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def resolved_member(query_lot: str, unit: str, scribe: str, *, basis: str = "PRIMARY_EXACT_DB_PARENT") -> dict:
    return {
        "queryLot": query_lot,
        "unitContainer": unit,
        "resolvedScribe": scribe,
        "resolutionBasis": basis,
        "parentContainers": [query_lot],
        "sourceEpiContainers": [],
        "evidenceSources": ["DIRECT_CURRENT_CONTAINMENT"],
        "acquisitionTimestamps": [],
        "evidence": [],
    }


def recount(roster: dict) -> None:
    resolved = sum(row["resolvedMemberCount"] for row in roster["lots"])
    held = sum(row["heldMemberCount"] for row in roster["lots"])
    unresolved = [row["queryLot"] for row in roster["lots"] if row["resolvedMemberCount"] == 0]
    roster["counts"]["representedLots"] = 50 - len(unresolved)
    roster["counts"]["resolvedMembers"] = resolved
    roster["counts"]["heldMembers"] = held
    roster["counts"]["unresolvedLots"] = len(unresolved)
    roster["unresolvedLots"] = unresolved


def make_roster(module, catalog: dict, metadata: dict) -> dict:
    rows_by_lot: dict[str, list[dict]] = {}
    for row in metadata["rows"]:
        rows_by_lot.setdefault(row["historyBaseLot"], []).append(row)
    lots = []
    for index, query_lot in enumerate(catalog["queryKeys"]):
        candidates = sorted(
            rows_by_lot.get(query_lot, []),
            key=lambda row: (row["scribe"], row["issuedWaferContainer"], row["acquisitionKey"]),
        )
        if query_lot == "62546-481":
            exact = [row for row in candidates if row["scribe"] == "13HFX135SUE3"]
            chosen = exact[0]
        elif candidates:
            chosen = candidates[0]
        else:
            chosen = {"scribe": "Q" + str(index + 1).zfill(11), "issuedWaferContainer": query_lot + "-001"}
        members = [resolved_member(query_lot, chosen["issuedWaferContainer"], chosen["scribe"])]
        lots.append({
            "queryLot": query_lot,
            "state": "COMPLETE",
            "resolvedMemberCount": 1,
            "heldMemberCount": 0,
            "resolvedMembers": members,
            "heldMembers": [],
        })
    return {
        "schema": "argos_r18uq2_exhaustive_lot_scribe_roster_v1",
        "createdUtc": "2026-09-05T00:00:00Z",
        "executionState": "PASS_R18UQ2_READ_ONLY_QUERY_EXECUTED",
        "disposition": "COMPLETE",
        "state": "PASS_R18UQ2_EXHAUSTIVE_ROSTER",
        "executionMode": "FILE_BACKED_SYNTHETIC_SQL_ROW_REHEARSAL",
        "input": {
            "path": "SYNTHETIC",
            "bytes": 1,
            "sha256": "0" * 64,
            "sourceCatalogSha256": module.EXPECTED_CATALOG_SHA256,
            "queryKeyFingerprintSha256": module.EXPECTED_QUERY_FINGERPRINT_SHA256,
            "queryKeyCount": 50,
        },
        "counts": {
            "queryLots": 50,
            "representedLots": 50,
            "resolvedMembers": 50,
            "heldMembers": 0,
            "invalidOrNullRows": 0,
            "unresolvedLots": 0,
            "unisolatedAmbiguities": 0,
        },
        "lots": lots,
        "invalidOrNullRows": [],
        "unresolvedLots": [],
        "unisolatedAmbiguities": [],
        "holds": [],
        "invariants": {
            "readOnlySql": True,
            "parameterizedLotKeys": True,
            "exactDatabaseParentEvidenceRequired": True,
            "issuedUnitSuffixInferenceUsed": False,
            "historicalMembershipFallbackOnly": True,
            "heldMembersExcludedFromResolvedScribes": True,
            "credentialsReturned": False,
            "imagesAccessed": False,
            "jbodAccessed": False,
            "tasksOrProcessesAccessed": False,
            "queuesAccessed": False,
            "sourceMutationPerformed": False,
            "productionRoutingEnabled": False,
        },
    }


def build(module, roster, metadata, metadata_identity, catalog, catalog_identity, gate, gate_identity):
    encoded = (json.dumps(roster, sort_keys=True) + "\n").encode("utf-8")
    roster_identity = {"path": "SYNTHETIC", "bytes": len(encoded), "sha256": module.sha256_hex(encoded)}
    return module.build_report(
        roster,
        roster_identity,
        metadata,
        metadata_identity,
        catalog,
        catalog_identity,
        gate,
        gate_identity,
        allow_synthetic_roster=True,
    )


def main() -> int:
    module = load_module()
    catalog, catalog_identity = module.read_json(CATALOG_PATH, module.MAX_CATALOG_BYTES)
    metadata, metadata_identity = module.read_json(METADATA_PATH, module.MAX_METADATA_BYTES)
    gate, gate_identity = module.read_json(R18V_GATE_PATH, module.MAX_R18V_GATE_BYTES)
    roster = make_roster(module, catalog, metadata)

    first = build(module, roster, metadata, metadata_identity, catalog, catalog_identity, gate, gate_identity)
    second = build(module, roster, metadata, metadata_identity, catalog, catalog_identity, gate, gate_identity)
    assert first == second, "report is not deterministic"
    assert first["rosterValidation"]["selectionPermitted"] is True
    assert first["nextDataPullSelection"]["actionable"] is True
    assert first["rosterValidation"]["queryLotCount"] == 50
    assert first["inputs"]["frozenR18vGlyphEnvelopeGate"]["sha256"] == module.EXPECTED_R18V_GATE_SHA256
    assert first["invariants"]["onlyResolvedRosterMembersJoinedOrSelected"] is True
    assert first["invariants"]["heldRosterMembersSurfacedAndExcluded"] is True
    assert first["invariants"]["historicalChildContainerNameParsedForIdentity"] is False
    corrected = [row for row in first["resolvedRosterToAcquisitionRows"] if row["scribe"] == "13HFX135SUE3"]
    assert len(corrected) == 16, "exact corrected-scribe metadata join changed"
    assert all(row["issuedWaferContainer"] == "62546-481-010" for row in corrected)
    goals = {row["character"]: row for row in first["nextDataPullSelection"]["goals"]}
    assert goals["A"]["targetedForDataPull"] is False
    assert goals["A"]["selectedCandidateMesUnitLineages"] == 0
    assert goals["D"]["r18vCoverageState"] == "SPARSE"
    assert goals["I"]["r18vCoverageState"] == "UNOBSERVED"

    # A top-level HOLD is valid diagnostic input, but it can never produce an
    # actionable data-pull selection, even though resolved members still join.
    hold_roster = json.loads(json.dumps(roster))
    hold_roster["disposition"] = "HOLD"
    hold_roster["state"] = "HOLD_R18UQ2_ROSTER_NOT_USABLE"
    hold_roster["holds"] = [{"code": "SYNTHETIC_NON_ACTIONABLE_HOLD"}]
    held_input_report = build(module, hold_roster, metadata, metadata_identity, catalog, catalog_identity, gate, gate_identity)
    assert held_input_report["counts"]["joinedAcquisitionRows"] > 0
    assert held_input_report["rosterValidation"]["selectionPermitted"] is False
    assert held_input_report["nextDataPullSelection"]["actionable"] is False
    assert held_input_report["nextDataPullSelection"]["selected"] == []
    assert held_input_report["nextDataPullSelection"]["selectedLineageCount"] == 0

    # Put an exact metadata identity only in heldMembers while retaining a
    # different resolved member for the lot.  The roster remains usable, but
    # that exact held identity must neither join nor become a candidate.
    usable = json.loads(json.dumps(roster))
    lot = next(row for row in usable["lots"] if row["queryLot"] == "62546-481")
    other = next(
        row for row in metadata["rows"]
        if row["historyBaseLot"] == "62546-481"
        and (row["scribe"], row["issuedWaferContainer"]) != ("13HFX135SUE3", "62546-481-010")
    )
    held_member = {
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
    }
    lot["heldMembers"].append(held_member)
    lot["heldMemberCount"] = 1
    lot["state"] = "PARTIAL_HOLD"
    usable["disposition"] = "USABLE_WITH_HOLDS"
    usable["state"] = "PASS_R18UQ2_USABLE_ROSTER_WITH_EXPLICIT_HELD_MEMBERS"
    usable["holds"] = [{"code": "ISOLATED_HELD_MEMBERS", "count": 1}]
    recount(usable)
    usable_report = build(module, usable, metadata, metadata_identity, catalog, catalog_identity, gate, gate_identity)
    assert usable_report["rosterValidation"]["selectionPermitted"] is True
    assert usable_report["nextDataPullSelection"]["actionable"] is True
    assert usable_report["counts"]["heldRosterMembers"] == 1
    assert len(usable_report["explicitHeldRosterMembers"]) == 1
    assert usable_report["explicitHeldRosterMembers"][0]["unitContainer"] == other["issuedWaferContainer"]
    assert not any(
        row["scribe"] == other["scribe"] and row["issuedWaferContainer"] == other["issuedWaferContainer"]
        for row in usable_report["resolvedRosterToAcquisitionRows"]
    ), "held member was joined as resolved"
    assert not any(
        row["scribe"] == other["scribe"] and row["databaseSourceContainerIdentity"] == other["issuedWaferContainer"]
        for row in usable_report["nextDataPullSelection"]["selected"]
    ), "held member was selected"

    # A historical child container remains an opaque exact DB identity.  It
    # cannot be converted to an issued-wafer unit by stripping WAFER.
    historical = json.loads(json.dumps(roster))
    historical_lot = historical["lots"][-1]
    historical_member = historical_lot["resolvedMembers"][0]
    exact_historical_child = historical_lot["queryLot"] + "-040WAFER"
    historical_member["unitContainer"] = exact_historical_child
    historical_member["resolutionBasis"] = "FALLBACK_EXACT_HISTORICAL_PARENT_CHILD"
    historical_report = build(module, historical, metadata, metadata_identity, catalog, catalog_identity, gate, gate_identity)
    unresolved = historical_report["unresolved"]["resolvedRosterMembersWithoutAcquisition"]
    exact_unresolved = [row for row in unresolved if row["databaseSourceContainerIdentity"] == exact_historical_child]
    assert len(exact_unresolved) == 1
    assert exact_unresolved[0]["databaseSourceContainerEndsWithWafer"] is True
    assert exact_unresolved[0]["issuedWaferContainerMatched"] is False

    with tempfile.TemporaryDirectory(prefix="R18UJ2_") as temp:
        output = Path(temp) / "out.json"
        module.write_new(output, (json.dumps(first) + "\n").encode("utf-8"))
        try:
            module.write_new(output, b"{}\n")
        except module.ValidationError:
            pass
        else:
            raise AssertionError("create-new output guard did not refuse overwrite")

    print(json.dumps({
        "schema": "argos_opencv_scribe_r18uj2_focused_test_v1",
        "state": "PASS_R18UJ2_FOCUSED_ROSTER_CONTRACT_TEST",
        "exactQueryLots": 50,
        "correctedScribeJoinedAcquisitionRows": 16,
        "holdSelectionEmpty": True,
        "usableHeldMemberExcludedFromJoinAndSelection": True,
        "historicalWaferChildPreservedWithoutInference": True,
        "r18vGatePinned": True,
        "sparseAndUnobservedOnly": True,
        "unprovenCrosswalkOverlapCredited": False,
        "imageBytesRead": False,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
