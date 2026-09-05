#!/usr/bin/env python3
"""Focused synthetic-roster test for the R18UJ1 reconciler."""

from __future__ import annotations

import importlib.util
import json
import tempfile
from pathlib import Path


HERE = Path(__file__).resolve().parent
WORKTREE = HERE.parents[1]
MODULE_PATH = HERE / "r18uj1_reconcile.py"
CATALOG_PATH = WORKTREE / "work" / "OPENCV_SCRIBE_R18U" / "R18U_ROSTER_CATALOG_INPUT.json"
METADATA_PATH = WORKTREE / "work" / "OPENCV_SCRIBE_R18U" / "evidence" / "VERIFIED_METADATA_OVERLAY_20260814.json"
R18V_GATE_PATH = WORKTREE / "work" / "OPENCV_SCRIBE_R18V" / "R18V_GLYPH_ENVELOPE_GATE.json"


def load_module():
    spec = importlib.util.spec_from_file_location("r18uj1_reconcile", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("could not load reconciler module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def make_roster(module, catalog: dict, metadata: dict) -> dict:
    rows_by_lot: dict[str, list[dict]] = {}
    for row in metadata["rows"]:
        rows_by_lot.setdefault(row["historyBaseLot"], []).append(row)
    lots = []
    all_scribes = set()
    valid_evidence_rows = 0
    for index, query_lot in enumerate(catalog["queryKeys"]):
        candidates = sorted(
            rows_by_lot.get(query_lot, []),
            key=lambda row: (row["scribe"], row["issuedWaferContainer"], row["acquisitionKey"]),
        )
        if query_lot == "62546-481":
            slot21 = [row for row in candidates if row["scribe"] == "13HFX135SUE3"]
            chosen = slot21[0] if slot21 else candidates[0]
        elif candidates:
            chosen = candidates[0]
        else:
            chosen = {
                "scribe": "Q" + str(index + 1).zfill(11),
                "issuedWaferContainer": query_lot + "-001",
            }
        scribe = chosen["scribe"]
        all_scribes.add(scribe)
        record = {
            "scribe": scribe,
            "unitContainers": [chosen["issuedWaferContainer"]],
            "parentContainers": [query_lot],
            "sourceEpiContainers": ["SYNTHETIC-EPI"],
            "evidenceSources": ["DIRECT_CURRENT_CONTAINMENT", "ISSUE_ACTUALS_HISTORY"],
            "directCurrentContainmentRowCount": 1,
            "issueActualsHistoryRowCount": 1,
        }
        valid_evidence_rows += 2
        lots.append({
            "queryLot": query_lot,
            "state": "COMPLETE",
            "validScribeCount": 1,
            "validEvidenceRowCount": 2,
            "conflictCount": 0,
            "invalidRowCount": 0,
            "scribes": [record],
        })
    return {
        "schema": "argos_r18uq1_exhaustive_lot_scribe_roster_v1",
        "createdUtc": "2026-09-05T00:00:00Z",
        "executionState": "PASS_R18UQ1_READ_ONLY_QUERY_EXECUTED",
        "disposition": "COMPLETE",
        "state": "PASS_R18UQ1_EXHAUSTIVE_ROSTER",
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
            "directCurrentContainmentRows": 50,
            "issueActualsHistoryRows": 50,
            "validEvidenceRows": valid_evidence_rows,
            "uniqueValidScribes": len(all_scribes),
            "unmatchedLots": 0,
            "conflicts": 0,
            "invalidOrNullRows": 0,
        },
        "lots": lots,
        "unmatchedLots": [],
        "conflicts": [],
        "invalidOrNullRows": [],
        "holds": [],
        "invariants": {
            "readOnlySql": True,
            "parameterizedLotKeys": True,
            "lotSlotIdentityInferenceUsed": False,
            "imagesAccessed": False,
            "jbodAccessed": False,
            "credentialsReturned": False,
            "tasksOrProcessesAccessed": False,
            "queuesAccessed": False,
            "sourceMutationPerformed": False,
            "productionRoutingEnabled": False,
        },
    }


def main() -> int:
    module = load_module()
    catalog, catalog_identity = module.read_json(CATALOG_PATH, module.MAX_CATALOG_BYTES)
    metadata, metadata_identity = module.read_json(METADATA_PATH, module.MAX_METADATA_BYTES)
    r18v_gate, r18v_gate_identity = module.read_json(R18V_GATE_PATH, module.MAX_R18V_GATE_BYTES)
    roster = make_roster(module, catalog, metadata)

    with tempfile.TemporaryDirectory(prefix="R18UJ1_") as temp:
        fixture_path = Path(temp) / "synthetic_r18uq1.json"
        fixture_path.write_text(json.dumps(roster, indent=2) + "\n", encoding="utf-8")
        loaded_roster, roster_identity = module.read_json(fixture_path, module.MAX_ROSTER_BYTES)
        first = module.build_report(
            loaded_roster,
            roster_identity,
            metadata,
            metadata_identity,
            catalog,
            catalog_identity,
            r18v_gate,
            r18v_gate_identity,
            allow_synthetic_roster=True,
        )
        second = module.build_report(
            loaded_roster,
            roster_identity,
            metadata,
            metadata_identity,
            catalog,
            catalog_identity,
            r18v_gate,
            r18v_gate_identity,
            allow_synthetic_roster=True,
        )
        assert first == second, "report is not deterministic"
        assert first["rosterValidation"]["queryLotCount"] == 50
        assert first["rosterValidation"]["exactCatalogOrderMatched"] is True
        assert first["rosterValidation"]["exhaustive"] is True
        assert first["inputs"]["frozenCatalog"]["sha256"] == module.EXPECTED_CATALOG_SHA256
        assert first["inputs"]["frozenSignedMetadataOverlay"]["sha256"] == module.EXPECTED_METADATA_SHA256
        assert first["inputs"]["frozenR18vGlyphEnvelopeGate"]["sha256"] == module.EXPECTED_R18V_GATE_SHA256
        assert first["invariants"]["lotOrSlotIdentityInferred"] is False
        assert first["invariants"]["imageBytesRead"] is False
        assert first["invariants"]["mesUnitIdentityAssumedEqualToR18vReferenceLineage"] is False
        assert first["invariants"]["overlapWithExistingR18vReferencesCredited"] is False
        assert first["counts"]["joinedAcquisitionRows"] > 0
        corrected_scribe_rows = [row for row in first["rosterToAcquisitionRows"] if row["scribe"] == "13HFX135SUE3"]
        # The frozen overlay has 16 exact MES rows.  Two acquisition keys use
        # non-production capture names; they remain evidence because this join
        # never parses an acquisition key to infer a lot or slot.
        assert len(corrected_scribe_rows) == 16, "exact corrected-scribe metadata join changed"
        assert all(row["queryLot"] == "62546-481" for row in corrected_scribe_rows)
        assert all(row["issuedWaferContainer"] == "62546-481-010" for row in corrected_scribe_rows)
        assert first["nextDataPullSelection"]["minimality"] == "INCLUSION_MINIMAL_NO_GLOBAL_CARDINALITY_CLAIM"
        assert first["nextDataPullSelection"]["scope"] == "R18V_SPARSE_AND_UNOBSERVED_CLASSES_ONLY"
        assert first["nextDataPullSelection"]["candidateOverlapWithExistingReferencesCredited"] == 0
        goals = {row["character"]: row for row in first["nextDataPullSelection"]["goals"]}
        assert goals["A"]["r18vCoverageState"] == "COVERED"
        assert goals["A"]["targetedForDataPull"] is False
        assert goals["A"]["additionalIndependentLineagesNeeded"] == 0
        assert goals["D"]["r18vCoverageState"] == "SPARSE"
        assert goals["D"]["additionalIndependentLineagesNeeded"] == 1
        assert goals["I"]["r18vCoverageState"] == "UNOBSERVED"
        assert goals["I"]["additionalIndependentLineagesNeeded"] == 4
        selected = first["nextDataPullSelection"]["selected"]
        assert len({row["independentLineageKey"] for row in selected}) == len(selected)

        fake_coverage = {
            char: {"state": "COVERED", "referenceCount": 4, "independentPhysicalLineageCount": 4}
            for char in module.ALPHABET
        }
        fake_coverage["D"] = {"state": "SPARSE", "referenceCount": 3, "independentPhysicalLineageCount": 3}
        fake_coverage["I"] = {"state": "UNOBSERVED", "referenceCount": 0, "independentPhysicalLineageCount": 0}
        fake_character_rows = {char: {"rosterOccurrenceCount": 1} for char in module.ALPHABET}
        fake_joined = []
        fake_scribes = ["DIA000000001", "IAA000000002", "IAA000000003", "IAA000000004"]
        for index, scribe in enumerate(fake_scribes, 1):
            lot = f"60000-{index:03d}"
            unit = lot + "-001"
            fake_joined.append({
                "queryLot": lot,
                "scribe": scribe,
                "issuedWaferContainer": unit,
                "independentLineageKey": module.lineage_key(lot, unit, scribe),
                "acquisitionKey": f"ACQ{index}",
                "sourcePaths": [],
                "sourceHashes": [],
            })
        focused_selection = module.select_data_pull(fake_joined, fake_character_rows, fake_coverage)
        focused_goals = {row["character"]: row for row in focused_selection["goals"]}
        assert focused_selection["selectedLineageCount"] == 4
        assert focused_goals["A"]["targetedForDataPull"] is False
        assert focused_goals["A"]["selectedCandidateMesUnitLineages"] == 0
        assert focused_goals["D"]["selectedCandidateMesUnitLineages"] == 1
        assert focused_goals["I"]["selectedCandidateMesUnitLineages"] == 4

        paths, hashes, invalid = module.extract_source_fields({
            "bfSourcePath": r"D:\locked\BF.bmp",
            "bfSourceSha256": "A" * 64,
            "otherHash": "not-a-sha256",
        })
        assert paths == [{"field": "/bfSourcePath", "value": r"D:\locked\BF.bmp"}]
        assert hashes == [{"field": "/bfSourceSha256", "value": "A" * 64}]
        assert invalid == [{"field": "/otherHash", "value": "NOT-A-SHA256"}]

        bad_roster = json.loads(json.dumps(roster))
        bad_roster["lots"].pop()
        try:
            module.build_report(
                bad_roster,
                roster_identity,
                metadata,
                metadata_identity,
                catalog,
                catalog_identity,
                r18v_gate,
                r18v_gate_identity,
                allow_synthetic_roster=True,
            )
        except module.ValidationError:
            pass
        else:
            raise AssertionError("49-lot roster was not rejected")

    print(json.dumps({
        "schema": "argos_opencv_scribe_r18uj1_focused_test_v1",
        "state": "PASS_R18UJ1_FOCUSED_SYNTHETIC_ROSTER_TEST",
        "exactQueryLots": 50,
        "correctedScribeJoinedAcquisitionRows": 16,
        "deterministicOutput": True,
        "coveredClassZeroAdditionalGoalTested": True,
        "sparseAndUnobservedDeficitGoalsTested": True,
        "unprovenCrosswalkOverlapCredited": False,
        "sourcePathOrHashDereferenced": False,
        "imageBytesRead": False,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
