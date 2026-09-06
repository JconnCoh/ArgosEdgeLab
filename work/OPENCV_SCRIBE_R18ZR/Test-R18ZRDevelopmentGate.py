#!/usr/bin/env python3
"""Freeze R18Q + R18R + R18Z composition before independent Slot21 use."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


EXPECTED = {
    "provider": None,
    "r18zLooTest": "8538FC44915CF6E978C1AAED3FB14761A8C1896EC9802A1CBE372F718F25A788",
    "r18zLooGate": "D8F0C0923BFDD6B82C4B0B0C57142825C08C0DB3F5395210A5DD7FE2E6E8DAD8",
    "r18qGate": "E080BDC20040973E6E9F533B2C650B60FFBD7BA939A375ABC9E33F6C4AE53111",
    "r18rGate": "566EB33649697713F5E0EFD3E0F04F9861333103BBBC1C1BACFEDE3CD184C82A",
    "canonicalChecksumGate": "BB0F36B38A7CB697087B324CDE2037E8F2B8ED184BCE8DB71EA1BCB3DB787407",
    "baseManifest": "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229",
    "supplementalManifest": "C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD",
    "crosswalk": "84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2",
    "cohort": "62A5E864C174A6E2C7F368E784E8DD0F86A11828036401351B2FCBB6336A2661",
    "truthRegrade": "14E3FF1434DB605886C1A7A7944538E39C7F8BE31004E90CE0EE0A7AB089FB26",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def sha256_json(value: Any) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def require_pin(path: Path, expected: str) -> None:
    if not path.is_file() or sha256_file(path) != expected:
        raise ValueError(f"Pinned development evidence mismatch: {path}")


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
        raise FileExistsError(f"Fresh development output root required: {output_root}")
    if sha256_file(provider_path) != args.expected_provider_sha256.upper():
        raise ValueError("Candidate provider SHA-256 mismatch.")
    paths = {
        "r18zLooTest": project / "work/OPENCV_SCRIBE_R18Z/Test-R18ZExactLineage.py",
        "r18zLooGate": project / "work/OPENCV_SCRIBE_R18Z/evidence/R18Z_EXACT_LINEAGE_LOO_GATE.json",
        "r18qGate": project / "work/OPENCV_SCRIBE_R18Q/R18Q_LOCAL_GATE.json",
        "r18rGate": project / "work/OPENCV_SCRIBE_R18R/R18R_LOCAL_GATE.json",
        "canonicalChecksumGate": project / "work/OPENCV_SCRIBE_R18T/R18T_CANONICAL_CHECKSUM_RERUN_GATE.json",
        "baseManifest": project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json",
        "supplementalManifest": project / "work/OPENCV_SCRIBE_R18Z/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json",
        "crosswalk": project / "work/OPENCV_SCRIBE_R18Z/reference_bank/R18Z_EXACT_SCRIBE_LINEAGE_CROSSWALK.json",
        "cohort": project / "work/OPENCV_SCRIBE_R18T/R18T_LIVE_REVIEW_COHORT.json",
        "truthRegrade": project / "work/OPENCV_SCRIBE_R18UR/R18UR_R18T1_EXACT_TRUTH_REGRADE.json",
    }
    for name, path in paths.items():
        require_pin(path, EXPECTED[name])

    r18q_gate = read_json(paths["r18qGate"])
    r18r_gate = read_json(paths["r18rGate"])
    checksum_gate = read_json(paths["canonicalChecksumGate"])
    frozen_loo_gate = read_json(paths["r18zLooGate"])
    if r18q_gate.get("state") != "PASS_R18Q_GENERIC_STRUCTURE_LOCAL_GATE_FULL_SLOT25_CROP_REPLAY_PENDING":
        raise ValueError("Frozen R18Q development gate state changed.")
    if r18r_gate.get("state") != "PASS_R18R_LOCAL_SLOT24_RESOLUTION_REMOTE_AMBIGUITY_CONTROLS_PENDING":
        raise ValueError("Frozen R18R development gate state changed.")
    if (
        r18r_gate.get("slot24", {}).get("state") != "PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE"
        or r18r_gate.get("slot24", {}).get("imageFirstString") != "143B0083SUE6"
    ):
        raise ValueError("Frozen R18R reciprocal-resolution control changed.")
    if checksum_gate.get("state") != "PASS_R18R_CANONICAL_CHECKSUM_GATE":
        raise ValueError("Later canonical checksum gate is not PASS.")
    if frozen_loo_gate.get("state") != "PASS_R18Z_ZERO_WRONG_ACCEPTED_EXACT_SCRIBE_LINEAGE_LOO":
        raise ValueError("Frozen R18Z LOO gate state changed.")

    provider = load("argos_scribe_r18zr_development_candidate", provider_path)
    loo_test = load("argos_scribe_r18z_loo_for_r18zr", paths["r18zLooTest"])
    if provider.R18H is not provider.R18Z.R18V.R18H:
        raise RuntimeError("Candidate and LOO rank bindings are not shared.")
    r11 = provider.R17D.R17C.R17B._load_r11()
    roots = {
        "glyphs": paths["baseManifest"].parent / "glyphs",
        "glyphs_v5_confirmed_20260806": paths["baseManifest"].parent / "glyphs_v5_confirmed_20260806",
    }
    base_appearance, base_evidence = r11.load_reference_prototypes(
        paths["baseManifest"], EXPECTED["baseManifest"], roots
    )
    appearance, _ = provider.R18ZV.R18Z_LOADER.combine_reference_prototypes(
        r11,
        base_appearance,
        base_evidence,
        paths["supplementalManifest"],
        EXPECTED["supplementalManifest"],
    )
    topology = provider.R17D.load_topology_prototypes(
        r11,
        paths["baseManifest"],
        EXPECTED["baseManifest"],
        roots,
        paths["supplementalManifest"],
        EXPECTED["supplementalManifest"],
    )
    run_structure = provider.R18H.load_run_structure_prototypes(
        r11,
        paths["baseManifest"],
        EXPECTED["baseManifest"],
        roots,
        paths["supplementalManifest"],
        EXPECTED["supplementalManifest"],
    )
    mapping, mapping_fingerprint = provider.R18Z.load_lineage_mapping(
        paths["crosswalk"], EXPECTED["crosswalk"]
    )
    appearance = provider.R18Z.rekey_prototypes(appearance, mapping)
    topology = provider.R18Z.rekey_prototypes(topology, mapping)
    run_structure = provider.R18Z.rekey_prototypes(run_structure, mapping)
    provider.R18Z.assert_aligned_reference_banks(appearance, topology, run_structure)

    old_rank = provider.R18H.rank_with_run_structure
    baseline = loo_test.run_loo(
        provider.R18Z, r11, appearance, topology, run_structure
    )
    frozen = frozen_loo_gate["leaveOneExactScribeLineageOut"]
    if (
        baseline["queryResultFingerprint"] != frozen.get("queryResultFingerprint")
        or baseline["summary"]["acceptedCorrect"] != 273
        or baseline["summary"]["acceptedWrong"] != 0
    ):
        raise ValueError("Frozen R18Z 475-query LOO did not reproduce.")
    try:
        provider.R18H.rank_with_run_structure = provider.R18Q.rank_with_run_structure
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
    lost = sorted(baseline_correct - candidate_correct)
    gained = sorted(candidate_correct - baseline_correct)
    accepted_wrong = [
        row for row in candidate["queryResults"] if bool(row["acceptedWrong"])
    ]
    new_rows = candidate["queryResults"][465:]
    new_sparse_accepted = [row for row in new_rows if bool(row["accepted"])]
    changed_upstream = [
        {
            "referenceIndex": int(before["referenceIndex"]),
            "truth": before["truth"],
            "before": before["upstream"],
            "after": after["upstream"],
            "candidateAccepted": after["accepted"],
            "candidateSelected": after["selected"],
        }
        for before, after in zip(baseline["queryResults"], candidate["queryResults"])
        if before["upstream"] != after["upstream"]
    ]

    regrade = read_json(paths["truthRegrade"])
    oracle_rows = sorted(
        [
            {
                "physicalIdentity": row["physicalIdentity"],
                "bfSha256": row["sources"]["BF"],
                "dfSha256": row["sources"]["DF"],
                "truth": row["truth"],
                "priorImageFirstString": row["imageFirstString"],
                "priorProposedString": row["proposedString"],
                "claimedReviewState": row["claimedReviewState"],
                "regradeState": row["regradeState"],
            }
            for row in regrade.get("results", [])
            if bool(row.get("imageFirstExact"))
        ],
        key=lambda row: row["physicalIdentity"],
    )
    if len(oracle_rows) != 19:
        raise ValueError("R18T exact-image-first oracle is not exactly 19 rows.")

    source_text = provider_path.read_text(encoding="utf-8")
    forbidden_literals = [
        value for value in ("13HFX135SUE3", "Slot21", "62546-481", "expectedTruth")
        if value in source_text
    ]
    criteria = {
        "all475QueriesEvaluated": candidate["summary"]["referenceQueries"] == 475,
        "acceptedWrongCount": len(accepted_wrong),
        "frozenAcceptedCorrectCount": len(baseline_correct),
        "candidateAcceptedCorrectCount": len(candidate_correct),
        "lostFrozenAcceptedCorrectIndices": lost,
        "newSparseReferenceAcceptedCount": len(new_sparse_accepted),
        "providerHardcodedValidationLiteralCount": len(forbidden_literals),
        "r18tExactOracleRowCount": len(oracle_rows),
    }
    passed = (
        criteria["all475QueriesEvaluated"]
        and criteria["acceptedWrongCount"] == 0
        and criteria["frozenAcceptedCorrectCount"] == 273
        and not lost
        and criteria["newSparseReferenceAcceptedCount"] == 0
        and criteria["providerHardcodedValidationLiteralCount"] == 0
        and criteria["r18tExactOracleRowCount"] == 19
    )
    gate = {
        "schema": "argos_opencv_scribe_r18zr_integrated_development_gate_v1",
        "state": (
            "PASS_R18ZR_GENERIC_COMPOSITION_FROZEN_BEFORE_SLOT21"
            if passed else "HOLD_R18ZR_GENERIC_COMPOSITION_REGRESSION"
        ),
        "classification": "DIAGNOSTIC_ONLY",
        "provider": {
            "path": str(provider_path),
            "sha256": sha256_file(provider_path),
            "revision": provider.REVISION,
        },
        "test": {"path": str(Path(__file__).resolve()), "sha256": sha256_file(Path(__file__))},
        "frozenInputGates": {
            "r18qLocalGateSha256": EXPECTED["r18qGate"],
            "r18rLocalGateSha256": EXPECTED["r18rGate"],
            "canonicalChecksumGateSha256": EXPECTED["canonicalChecksumGate"],
            "r18zLooGateSha256": EXPECTED["r18zLooGate"],
        },
        "candidateLeaveOneExactLineageOut": {
            **candidate["summary"],
            "foldCount": candidate["foldCount"],
            "queryResultFingerprint": candidate["queryResultFingerprint"],
            "lostFrozenAcceptedCorrectIndices": lost,
            "gainedAcceptedCorrectIndices": gained,
            "changedUpstreamRows": changed_upstream,
            "newReferenceQueries": new_rows,
        },
        "r18tExactOracle": {
            "sourceRegradeSha256": EXPECTED["truthRegrade"],
            "sourceCohortSha256": EXPECTED["cohort"],
            "rowCount": len(oracle_rows),
            "fingerprint": sha256_json(oracle_rows),
            "behaviorallyRevalidatedByThisDescriptorGate": False,
            "deferredImagePairRerunCount": 19,
        },
        "mappingFingerprint": mapping_fingerprint,
        "criteria": criteria,
        "invariants": {
            "strongStructureFrozenBeforeSlot21": True,
            "truthComparedOnlyAfterImageOnlySelection": True,
            "checksumUsedForGlyphSelection": False,
            "slotOrLotExceptionUsed": False,
            "r18zEnvelopeThresholdChanged": False,
            "identityAccepted": False,
            "referenceAdmissionPerformed": False,
            "trainingEligible": False,
            "xmlEligible": False,
            "productionEligible": False,
            "publicationAuthorized": False,
        },
    }
    output_root.mkdir()
    output_path = output_root / "R18ZR_INTEGRATED_DEVELOPMENT_GATE.json"
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
