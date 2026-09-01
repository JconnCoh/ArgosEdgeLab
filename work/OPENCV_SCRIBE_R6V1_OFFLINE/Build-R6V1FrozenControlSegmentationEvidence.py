#!/usr/bin/env python3
"""Summarize frozen 15-control per-character segmentation evidence."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


FULL_GATE_SHA256 = "704EC0CB9303EA6DC74585A55213DD525773E44E77BBC8EE18DE203C2AF4789F"
HOLDOUT_SUMMARY_SHA256 = "9B06357632EC8DA3520265DBB8020D154012EE151A113193E906873FCA0A4A77"
HOLDOUT_RESULTS_SHA256 = "7BCA49CA6871615D1E84CAD0ED21F0577F93671AF0AB11043E089DF554F9B81B"
EXPANSION_MATRIX = (0, 2, 4, 6, 8, 12)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"JSON root is not an object: {path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    script = Path(__file__).resolve()
    repository = script.parents[2]
    holdout_root = repository / "work/SCRIBE_REVIEW_ONLY/outputs/review_only/FS15_SCRIBE_READER_PHYSICAL_HOLDOUT_V4_20260804T204500Z"
    full_gate_path = repository / "work/OPENCV_SCRIBE_V1R6/OCV02_R6_FULL_LOCALIZATION_GATE.json"
    summary_path = holdout_root / "HOLDOUT_SUMMARY.json"
    results_path = holdout_root / "PHYSICAL_HOLDOUT_RESULTS.csv"
    pins = [
        ("fullLocalizationGate", full_gate_path, FULL_GATE_SHA256),
        ("holdoutSummary", summary_path, HOLDOUT_SUMMARY_SHA256),
        ("holdoutResults", results_path, HOLDOUT_RESULTS_SHA256),
    ]
    dependencies = [
        {"id": identifier, "path": str(path), "sha256": sha256_file(path), "expectedSha256": expected}
        for identifier, path, expected in pins
    ]
    if not all(row["sha256"] == row["expectedSha256"] for row in dependencies):
        raise RuntimeError("Frozen segmentation evidence dependency changed.")
    full_gate = read_json(full_gate_path)
    locked = {str(row["alias"]): row for row in full_gate["cases"]}
    with results_path.open(encoding="utf-8-sig", newline="") as stream:
        corpus = list(csv.DictReader(stream))
    if len(corpus) != 15 or sorted(locked) != sorted(str(row["Alias"]) for row in corpus):
        raise RuntimeError("Frozen 15-control identity set changed.")

    controls = []
    character_correct = 0
    truth_in_candidates = 0
    truth_rank_counts: dict[str, int] = {}
    top_margins: list[float] = []
    truth_score_gaps: list[float] = []
    by_physical: dict[str, list[dict[str, Any]]] = {}
    for corpus_row in corpus:
        alias = str(corpus_row["Alias"])
        truth = str(corpus_row["Truth"])
        evidence_path = holdout_root / f"{alias}.json"
        evidence = read_json(evidence_path)
        positions = evidence.get("positions", [])
        if len(truth) != 12 or len(positions) != 12:
            raise RuntimeError(f"Frozen control position count changed: {alias}")
        position_rows = []
        control_correct = 0
        for index, position in enumerate(positions):
            candidates = position.get("candidates", [])
            if not candidates:
                raise RuntimeError(f"Frozen candidate list is empty: {alias}/{index + 1}")
            expected = truth[index]
            image_first = str(position.get("imageFirst", ""))
            rank = next((candidate_index + 1 for candidate_index, row in enumerate(candidates) if str(row.get("character", "")) == expected), None)
            if image_first == expected:
                character_correct += 1
                control_correct += 1
            if rank is not None:
                truth_in_candidates += 1
                truth_rank_counts[str(rank)] = truth_rank_counts.get(str(rank), 0) + 1
            top_score = float(candidates[0]["score"])
            runner_up = float(candidates[1]["score"]) if len(candidates) > 1 else None
            truth_score = next((float(row["score"]) for row in candidates if str(row.get("character", "")) == expected), None)
            margin = None if runner_up is None else top_score - runner_up
            truth_gap = None if truth_score is None else top_score - truth_score
            if margin is not None:
                top_margins.append(margin)
            if truth_gap is not None:
                truth_score_gaps.append(truth_gap)
            position_rows.append({
                "position": index + 1,
                "truth": expected,
                "imageFirst": image_first,
                "truthRankInReportedCandidates": rank,
                "topScore": top_score,
                "runnerUpScore": runner_up,
                "topMargin": margin,
                "truthScore": truth_score,
                "truthScoreGapFromTop": truth_gap,
                "reportedCandidateCount": len(candidates),
            })
        locked_row = locked[alias]
        if str(locked_row["proposedString"]) != truth or locked_row.get("passed") is not True:
            raise RuntimeError(f"Frozen R6 proposal gate changed: {alias}")
        control = {
            "alias": alias,
            "acquisitionKey": str(corpus_row["AcquisitionKey"]),
            "physicalWaferKey": str(corpus_row["PhysicalWaferKey"]),
            "evidencePath": str(evidence_path),
            "evidenceSha256": sha256_file(evidence_path),
            "inputSha256": str(locked_row["inputSha256"]),
            "truth": truth,
            "imageFirstString": str(evidence["imageFirstString"]),
            "v4TopChecksumAlternative": str(evidence.get("checksumValidImageSupportedAlternatives", [{}])[0].get("string", "")),
            "r6ProposedString": str(locked_row["proposedString"]),
            "characterCorrect": control_correct,
            "positionCount": 12,
            "grid": evidence["grid"],
            "positions": position_rows,
        }
        controls.append(control)
        by_physical.setdefault(control["physicalWaferKey"], []).append(control)
    duplicates = []
    for physical, rows in sorted(by_physical.items()):
        if len(rows) < 2:
            continue
        proposals = sorted({str(row["r6ProposedString"]) for row in rows})
        truths = sorted({str(row["truth"]) for row in rows})
        duplicates.append({
            "physicalWaferKey": physical,
            "acquisitionCount": len(rows),
            "proposedStrings": proposals,
            "truths": truths,
            "agreement": len(proposals) == 1 and proposals == truths,
        })
    baseline_pass = (
        len(controls) == 15
        and sum(1 for row in controls if row["r6ProposedString"] == row["truth"]) == 15
        and character_correct == 169
        and truth_in_candidates == 180
        and len(duplicates) == 4
        and all(row["agreement"] for row in duplicates)
    )
    report = {
        "schema": "argos_r6v1_frozen_control_segmentation_evidence_v1",
        "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "state": "PASS_R6V1_FROZEN_15_CONTROL_SEGMENTATION_BASELINE" if baseline_pass else "HOLD_R6V1_FROZEN_CONTROL_BASELINE_MISMATCH",
        "disposition": "DIAGNOSTIC_ONLY",
        "dependencies": dependencies,
        "baseline": {
            "controlCount": len(controls),
            "positionCount": 180,
            "exactProposalCount": sum(1 for row in controls if row["r6ProposedString"] == row["truth"]),
            "characterCorrect": character_correct,
            "truthInReportedCandidatePositions": truth_in_candidates,
            "truthRankCounts": truth_rank_counts,
            "minimumTopMargin": min(top_margins),
            "medianTopMargin": sorted(top_margins)[len(top_margins) // 2],
            "maximumTruthScoreGapFromTop": max(truth_score_gaps),
            "duplicateGroupCount": len(duplicates),
            "duplicateAgreementCount": sum(1 for row in duplicates if row["agreement"]),
        },
        "duplicateGroups": duplicates,
        "controls": controls,
        "expansionDevelopment": {
            "runnerPath": "work/OPENCV_SCRIBE_R6V1_OFFLINE/Run-R6V1OcrSegmentationDiagnostics.py",
            "plannedCellExpansionPixels": list(EXPANSION_MATRIX),
            "executionState": "PENDING_PINNED_LOCAL_OPENCV_RUNTIME",
            "observedExpansionRows": 0,
            "selectionOrThresholdFrozen": False,
            "activationAuthorized": False,
        },
        "identityEligibleCount": 0,
        "automaticIdentityAuthority": False,
        "mayClearHolds": False,
        "trainingEligible": False,
        "xmlEligible": False,
        "productionEligible": False,
        "providerActivated": False,
        "liveProviderRead": False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"state": report["state"], "output": str(args.output), "baseline": report["baseline"]}))
    return 0 if report["state"].startswith("PASS_") else 1


if __name__ == "__main__":
    raise SystemExit(main())
