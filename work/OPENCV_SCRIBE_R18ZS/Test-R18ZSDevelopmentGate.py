#!/usr/bin/env python3
"""Freeze generic dual-structure consensus without Slot21 evidence."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


PINS = {
    "looTest": "8538FC44915CF6E978C1AAED3FB14761A8C1896EC9802A1CBE372F718F25A788",
    "looGate": "D8F0C0923BFDD6B82C4B0B0C57142825C08C0DB3F5395210A5DD7FE2E6E8DAD8",
    "qGate": "E080BDC20040973E6E9F533B2C650B60FFBD7BA939A375ABC9E33F6C4AE53111",
    "rGate": "566EB33649697713F5E0EFD3E0F04F9861333103BBBC1C1BACFEDE3CD184C82A",
    "base": "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229",
    "supplement": "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD",
    "crosswalk": "84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(path)
    return value


def require_pin(path: Path, expected: str) -> None:
    if not path.is_file() or sha256_file(path) != expected:
        raise ValueError(f"Pinned evidence mismatch: {path}")


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--provider", required=True, type=Path)
    parser.add_argument("--expected-provider-sha256", required=True)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    provider_path = args.provider.resolve()
    output_root = args.output_root.resolve()
    if output_root.exists() or not output_root.parent.is_dir():
        raise FileExistsError(f"Fresh development root required: {output_root}")
    if sha256_file(provider_path) != args.expected_provider_sha256.upper():
        raise ValueError("Candidate provider SHA-256 mismatch.")
    paths = {
        "looTest": project / "work/OPENCV_SCRIBE_R18Z/Test-R18ZExactLineage.py",
        "looGate": project / "work/OPENCV_SCRIBE_R18Z/evidence/R18Z_EXACT_LINEAGE_LOO_GATE.json",
        "qGate": project / "work/OPENCV_SCRIBE_R18Q/R18Q_LOCAL_GATE.json",
        "rGate": project / "work/OPENCV_SCRIBE_R18R/R18R_LOCAL_GATE.json",
        "base": project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json",
        "supplement": project / "work/OPENCV_SCRIBE_R18Z/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json",
        "crosswalk": project / "work/OPENCV_SCRIBE_R18Z/reference_bank/R18Z_EXACT_SCRIBE_LINEAGE_CROSSWALK.json",
    }
    for name, path in paths.items():
        require_pin(path, PINS[name])
    if read_json(paths["qGate"]).get("state") != "PASS_R18Q_GENERIC_STRUCTURE_LOCAL_GATE_FULL_SLOT25_CROP_REPLAY_PENDING":
        raise ValueError("Frozen R18Q gate changed.")
    if read_json(paths["rGate"]).get("state") != "PASS_R18R_LOCAL_SLOT24_RESOLUTION_REMOTE_AMBIGUITY_CONTROLS_PENDING":
        raise ValueError("Frozen R18R gate changed.")
    frozen_gate = read_json(paths["looGate"])

    provider = load("argos_scribe_r18zs_development_candidate", provider_path)
    loo_test = load("argos_scribe_r18z_loo_for_r18zs", paths["looTest"])
    r11 = provider.R17D.R17C.R17B._load_r11()
    roots = {
        "glyphs": paths["base"].parent / "glyphs",
        "glyphs_v5_confirmed_20260806": paths["base"].parent / "glyphs_v5_confirmed_20260806",
    }
    base_appearance, base_evidence = r11.load_reference_prototypes(
        paths["base"], PINS["base"], roots
    )
    appearance, _ = provider.R18ZV.R18Z_LOADER.combine_reference_prototypes(
        r11, base_appearance, base_evidence, paths["supplement"], PINS["supplement"]
    )
    topology = provider.R17D.load_topology_prototypes(
        r11, paths["base"], PINS["base"], roots,
        paths["supplement"], PINS["supplement"],
    )
    run_structure = provider.R18H.load_run_structure_prototypes(
        r11, paths["base"], PINS["base"], roots,
        paths["supplement"], PINS["supplement"],
    )
    mapping, mapping_fingerprint = provider.R18Z.load_lineage_mapping(
        paths["crosswalk"], PINS["crosswalk"]
    )
    appearance = provider.R18Z.rekey_prototypes(appearance, mapping)
    topology = provider.R18Z.rekey_prototypes(topology, mapping)
    run_structure = provider.R18Z.rekey_prototypes(run_structure, mapping)
    provider.R18Z.assert_aligned_reference_banks(appearance, topology, run_structure)

    old_rank = provider.R18H.rank_with_run_structure
    baseline = loo_test.run_loo(
        provider.R18Z, r11, appearance, topology, run_structure
    )
    frozen = frozen_gate["leaveOneExactScribeLineageOut"]
    if (
        baseline["queryResultFingerprint"] != frozen.get("queryResultFingerprint")
        or baseline["summary"]["acceptedCorrect"] != 273
        or baseline["summary"]["acceptedWrong"] != 0
    ):
        raise ValueError("Frozen R18Z LOO failed to reproduce.")
    try:
        provider.R18H.rank_with_run_structure = provider.rank_with_dual_structure_consensus
        candidate = loo_test.run_loo(
            provider.R18Z, r11, appearance, topology, run_structure
        )
    finally:
        provider.R18H.rank_with_run_structure = old_rank

    baseline_correct = {
        int(row["referenceIndex"])
        for row in baseline["queryResults"] if bool(row["acceptedCorrect"])
    }
    candidate_correct = {
        int(row["referenceIndex"])
        for row in candidate["queryResults"] if bool(row["acceptedCorrect"])
    }
    baseline_upstream_correct = {
        int(row["referenceIndex"])
        for row in baseline["queryResults"] if row["upstream"] == row["truth"]
    }
    candidate_upstream_correct = {
        int(row["referenceIndex"])
        for row in candidate["queryResults"] if row["upstream"] == row["truth"]
    }
    changed = [
        {
            "referenceIndex": int(before["referenceIndex"]),
            "truth": before["truth"],
            "before": before["upstream"],
            "after": after["upstream"],
            "improved": before["upstream"] != before["truth"] and after["upstream"] == after["truth"],
            "harmed": before["upstream"] == before["truth"] and after["upstream"] != after["truth"],
        }
        for before, after in zip(baseline["queryResults"], candidate["queryResults"])
        if before["upstream"] != after["upstream"]
    ]
    accepted_wrong = [row for row in candidate["queryResults"] if row["acceptedWrong"]]
    new_sparse_accepted = [row for row in candidate["queryResults"][465:] if row["accepted"]]
    lost_accepted = sorted(baseline_correct - candidate_correct)
    harmed_upstream = sorted(baseline_upstream_correct - candidate_upstream_correct)
    source_text = provider_path.read_text(encoding="utf-8")
    forbidden = [
        value for value in ("13HFX135SUE3", "Slot21", "62546-481", "expectedTruth")
        if value in source_text
    ]
    criteria = {
        "all475QueriesEvaluated": candidate["summary"]["referenceQueries"] == 475,
        "acceptedWrongCount": len(accepted_wrong),
        "lostFrozenAcceptedCorrectIndices": lost_accepted,
        "harmedPreviouslyUpstreamCorrectIndices": harmed_upstream,
        "changedUpstreamCount": len(changed),
        "improvedUpstreamCount": sum(int(row["improved"]) for row in changed),
        "newSparseReferenceAcceptedCount": len(new_sparse_accepted),
        "hardcodedValidationLiteralCount": len(forbidden),
    }
    passed = (
        criteria["all475QueriesEvaluated"]
        and criteria["acceptedWrongCount"] == 0
        and not lost_accepted
        and not harmed_upstream
        and criteria["newSparseReferenceAcceptedCount"] == 0
        and criteria["hardcodedValidationLiteralCount"] == 0
    )
    gate = {
        "schema": "argos_opencv_scribe_r18zs_dual_structure_development_gate_v1",
        "state": (
            "PASS_R18ZS_DUAL_STRUCTURE_FROZEN_BEFORE_SLOT21"
            if passed else "HOLD_R18ZS_DUAL_STRUCTURE_DEVELOPMENT_REGRESSION"
        ),
        "classification": "DIAGNOSTIC_ONLY",
        "provider": {
            "path": str(provider_path),
            "sha256": sha256_file(provider_path),
            "revision": provider.REVISION,
        },
        "test": {"path": str(Path(__file__).resolve()), "sha256": sha256_file(Path(__file__))},
        "genericRule": {
            "requiresTopologyAndRunStructureSameWinner": True,
            "topologyMinimumMargin": provider.R18Q.TOPOLOGY_OVERRIDE_MINIMUM_MARGIN,
            "runMinimumMargin": provider.R18R.RECIPROCAL_MARGIN_MINIMUM,
            "maximumAppearanceDeficit": provider.R18Q.STRONG_STRUCTURE_MAXIMUM_APPEARANCE_DEFICIT,
            "maximumAppearanceLeaderScore": provider.R18Q.STRONG_STRUCTURE_MAXIMUM_APPEARANCE_LEADER_SCORE,
            "newThresholdIntroduced": False,
        },
        "candidateLeaveOneExactLineageOut": {
            **candidate["summary"],
            "foldCount": candidate["foldCount"],
            "queryResultFingerprint": candidate["queryResultFingerprint"],
            "changedUpstreamRows": changed,
            "newReferenceQueries": candidate["queryResults"][465:],
        },
        "criteria": criteria,
        "mappingFingerprint": mapping_fingerprint,
        "invariants": {
            "frozenBeforeSlot21Evaluation": True,
            "truthComparedOnlyAfterRanking": True,
            "checksumUsedForSelection": False,
            "slotLotOrLabelExceptionUsed": False,
            "r18zEnvelopeThresholdChanged": False,
            "identityAccepted": False,
            "trainingEligible": False,
            "xmlEligible": False,
            "productionEligible": False,
            "publicationAuthorized": False,
        },
    }
    output_root.mkdir()
    output_path = output_root / "R18ZS_DUAL_STRUCTURE_DEVELOPMENT_GATE.json"
    with output_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(gate, stream, indent=2, sort_keys=True)
        stream.write("\n")
    print(json.dumps({
        "state": gate["state"],
        "gatePath": str(output_path),
        "gateSha256": sha256_file(output_path),
        "criteria": criteria,
    }, indent=2))
    return 0 if passed else 2


if __name__ == "__main__":
    raise SystemExit(main())
