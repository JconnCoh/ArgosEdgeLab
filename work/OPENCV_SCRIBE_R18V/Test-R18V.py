#!/usr/bin/env python3
"""Reference-only gate for the R18V generic glyph envelopes."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import numpy as np


R18H_PROVIDER_SHA256 = "3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD"
BASE_MANIFEST_SHA256 = "AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229"
SUPPLEMENTAL_MANIFEST_SHA256 = "FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114"
EXPECTED_REFERENCE_COUNT = 465
EXPECTED_COVERAGE = {
    "0": ("COVERED", 54, 34), "1": ("COVERED", 40, 25),
    "2": ("COVERED", 29, 22), "3": ("COVERED", 20, 14),
    "4": ("COVERED", 32, 23), "5": ("COVERED", 19, 13),
    "6": ("COVERED", 25, 17), "7": ("COVERED", 28, 18),
    "8": ("COVERED", 20, 16), "9": ("COVERED", 30, 18),
    "A": ("COVERED", 4, 4), "B": ("COVERED", 6, 5),
    "C": ("COVERED", 7, 6), "D": ("SPARSE", 4, 3),
    "E": ("COVERED", 34, 25), "F": ("COVERED", 28, 22),
    "G": ("COVERED", 6, 6), "H": ("SPARSE", 5, 3),
    "I": ("UNOBSERVED", 0, 0), "J": ("SPARSE", 2, 2),
    "K": ("SPARSE", 2, 2), "L": ("SPARSE", 3, 3),
    "M": ("SPARSE", 4, 2), "N": ("SPARSE", 1, 1),
    "O": ("UNOBSERVED", 0, 0), "P": ("COVERED", 12, 12),
    "Q": ("SPARSE", 2, 2), "R": ("SPARSE", 4, 3),
    "S": ("COVERED", 24, 18), "T": ("SPARSE", 3, 3),
    "U": ("COVERED", 14, 12), "V": ("UNOBSERVED", 0, 0),
    "W": ("SPARSE", 1, 1), "X": ("SPARSE", 1, 1),
    "Y": ("UNOBSERVED", 0, 0), "Z": ("SPARSE", 1, 1),
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def reference_rows(base_path: Path, supplemental_path: Path) -> list[dict[str, Any]]:
    base = json.loads(base_path.read_text(encoding="utf-8-sig"))
    supplemental = json.loads(supplemental_path.read_text(encoding="utf-8-sig"))
    return list(base["references"]) + list(supplemental["references"])


def verify_reference_hashes(
    provider: Any,
    r11: Any,
    base_path: Path,
    supplemental_path: Path,
    roots: dict[str, Path],
) -> str:
    digest = hashlib.sha256()
    base = json.loads(base_path.read_text(encoding="utf-8-sig"))
    supplemental = json.loads(supplemental_path.read_text(encoding="utf-8-sig"))
    for row in base["references"]:
        path = r11.resolve_reference_path(str(row["relativePath"]), roots)
        actual = sha256_file(path)
        if actual != str(row["sha256"]).upper():
            raise AssertionError(f"Base reference changed: {path}")
        digest.update(f"{row['label']}\0{row['physicalIdentity']}\0{actual}\n".encode("utf-8"))
    for row in supplemental["references"]:
        relative = Path(str(row["relativePath"]).replace("/", "\\"))
        path = supplemental_path.parent / relative
        actual = sha256_file(path)
        if actual != str(row["sha256"]).upper():
            raise AssertionError(f"Supplemental reference changed: {path}")
        digest.update(f"{row['label']}\0{row['physicalIdentity']}\0{actual}\n".encode("utf-8"))
    return digest.hexdigest().upper()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--expected-gate", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    provider_path = project / "work/OPENCV_SCRIBE_R18V/ArgosOpenCvScribeV1R18V.py"
    r18h_path = project / "work/OPENCV_SCRIBE_R18H/ArgosOpenCvScribeV1R18H.py"
    base_path = project / "work/SCRIBE_REVIEW_ONLY/scratch/SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z/PORTABLE_GLYPH_REFERENCE_MANIFEST.json"
    supplemental_path = project / "work/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json"
    if sha256_file(r18h_path) != R18H_PROVIDER_SHA256:
        raise AssertionError("Frozen R18H provider changed.")
    if sha256_file(base_path) != BASE_MANIFEST_SHA256:
        raise AssertionError("Frozen base reference manifest changed.")
    if sha256_file(supplemental_path) != SUPPLEMENTAL_MANIFEST_SHA256:
        raise AssertionError("Frozen supplemental reference manifest changed.")
    provider = load("argos_scribe_r18v_gate", provider_path)
    r11 = provider.R17D.R17C.R17B._load_r11()
    roots = {
        "glyphs": base_path.parent / "glyphs",
        "glyphs_v5_confirmed_20260806": base_path.parent / "glyphs_v5_confirmed_20260806",
    }
    prototypes, base_evidence = r11.load_reference_prototypes(
        base_path, BASE_MANIFEST_SHA256, roots,
    )
    prototypes, _ = provider.R18F.R18F_LOADER.combine_reference_prototypes(
        r11, prototypes, base_evidence, supplemental_path, SUPPLEMENTAL_MANIFEST_SHA256,
    )
    topology = provider.R17D.load_topology_prototypes(
        r11, base_path, BASE_MANIFEST_SHA256, roots,
        supplemental_path, SUPPLEMENTAL_MANIFEST_SHA256,
    )
    run_structure = provider.R18H.load_run_structure_prototypes(
        r11, base_path, BASE_MANIFEST_SHA256, roots,
        supplemental_path, SUPPLEMENTAL_MANIFEST_SHA256,
    )
    keys = [(row.label, row.physical_identity) for row in prototypes]
    if keys != [(row.label, row.physical_identity) for row in topology]:
        raise AssertionError("Appearance/topology keys changed.")
    if keys != [(row.label, row.physical_identity) for row in run_structure]:
        raise AssertionError("Appearance/run-structure keys changed.")
    if len(keys) != EXPECTED_REFERENCE_COUNT:
        raise AssertionError(f"Expected {EXPECTED_REFERENCE_COUNT} references, found {len(keys)}.")
    aggregate_reference_sha256 = verify_reference_hashes(
        provider, r11, base_path, supplemental_path, roots,
    )

    full_bank = provider.build_glyph_envelope_bank(topology, run_structure)
    coverage = provider.coverage_evidence(full_bank)
    actual_coverage = {
        label: (
            str(row["state"]), int(row["referenceCount"]),
            int(row["independentPhysicalLineageCount"]),
        )
        for label, row in coverage.items()
    }
    if actual_coverage != EXPECTED_COVERAGE:
        raise AssertionError(f"Coverage enumeration changed: {actual_coverage}")

    labels = r11.BODY_LABELS
    matrix = {
        truth: {**{prediction: 0 for prediction in labels}, "HOLD": 0}
        for truth in labels
    }
    per_truth = {
        label: {
            "referenceCount": 0, "acceptedCorrect": 0,
            "acceptedWrong": 0, "held": 0, "holdDecisions": {},
        }
        for label in labels
    }
    wrong_accepted: list[dict[str, Any]] = []
    diagnostics_checked = 0
    upstream_correct = 0
    accepted = 0
    corrected = 0
    score_increases = 0
    hold_decisions: dict[str, int] = {}
    accepted_corrections: list[dict[str, Any]] = []
    held_upstream_confusions: dict[str, int] = {}
    truth_normalized_distances: list[float] = []
    nearest_rival_normalized_distances: list[float] = []
    fold_cache: dict[str, tuple[Any, ...]] = {}
    for index, query in enumerate(prototypes):
        excluded = str(query.physical_identity).casefold()
        cached = fold_cache.get(excluded)
        if cached is None:
            active_indices = [
                row_index for row_index, row in enumerate(prototypes)
                if str(row.physical_identity).casefold() != excluded
            ]
            active_appearance = [prototypes[row_index] for row_index in active_indices]
            active_topology = [topology[row_index] for row_index in active_indices]
            active_run = [run_structure[row_index] for row_index in active_indices]
            appearance_bank = r11.PrototypeBank.from_prototypes(active_appearance)
            topology_matrix = np.vstack([row.descriptor.astype(np.float64) for row in active_topology])
            topology_indices = provider.R17D._label_indices(
                np.asarray([row.label for row in active_topology]),
            )
            run_scaling, run_consensus = provider.R18H._run_structure_context(active_run)
            fold_bank = provider.build_glyph_envelope_bank(active_topology, active_run)
            cached = (
                appearance_bank, topology_matrix, topology_indices,
                run_scaling, run_consensus, fold_bank,
            )
            fold_cache[excluded] = cached
        appearance_bank, topology_matrix, topology_indices, run_scaling, run_consensus, fold_bank = cached
        ranked, _ = provider.R18H.rank_with_run_structure(
            r11, query.descriptor, topology[index].descriptor,
            run_structure[index].descriptor, appearance_bank, topology_matrix,
            topology_indices, run_scaling, run_consensus, 0,
        )
        upstream = str(ranked[0]["character"])
        upstream_correct += int(upstream == str(query.label))
        decision = provider.assess_glyph_envelope(
            fold_bank, topology[index].descriptor, run_structure[index].descriptor,
            labels, upstream,
        )
        required = {
            "accepted", "decision", "upstreamLabel", "selectedLabel",
            "changedByEnvelope", "upstreamCoverageState",
            "candidateEnvelopeDistances", "checksumUsed",
        }
        if not required.issubset(decision) or decision["checksumUsed"] is not False:
            raise AssertionError(f"Incomplete per-glyph diagnostic at reference {index}.")
        diagnostics_checked += 1
        truth = str(query.label)
        candidates_by_label = {
            str(row["label"]): row
            for row in decision["candidateEnvelopeDistances"]
        }
        if truth in candidates_by_label:
            truth_normalized_distances.append(float(candidates_by_label[truth]["normalizedDistance"]))
            rivals = [
                float(row["normalizedDistance"])
                for label, row in candidates_by_label.items() if label != truth
            ]
            if rivals:
                nearest_rival_normalized_distances.append(min(rivals))
        per_truth[truth]["referenceCount"] += 1
        upstream_score = float(ranked[0]["score"])
        selected_row = next(
            row for row in ranked if str(row["character"]) == str(decision["selectedLabel"])
        )
        used_score = provider._score_ceiling(upstream_score, float(selected_row["score"]))
        if used_score > upstream_score + 1e-12:
            score_increases += 1
        if bool(decision["accepted"]):
            prediction = str(decision["selectedLabel"])
            matrix[truth][prediction] += 1
            accepted += 1
            corrected += int(prediction != upstream)
            if prediction != upstream:
                accepted_corrections.append({
                    "referenceIndex": index,
                    "physicalIdentity": str(query.physical_identity),
                    "truth": truth,
                    "upstream": upstream,
                    "accepted": prediction,
                })
            if prediction == truth:
                per_truth[truth]["acceptedCorrect"] += 1
            else:
                per_truth[truth]["acceptedWrong"] += 1
                wrong_accepted.append({
                    "referenceIndex": index,
                    "physicalIdentity": str(query.physical_identity),
                    "truth": truth,
                    "upstream": upstream,
                    "accepted": prediction,
                    "decision": decision,
                })
        else:
            matrix[truth]["HOLD"] += 1
            per_truth[truth]["held"] += 1
            key = str(decision["decision"])
            hold_decisions[key] = hold_decisions.get(key, 0) + 1
            truth_holds = per_truth[truth]["holdDecisions"]
            truth_holds[key] = truth_holds.get(key, 0) + 1
            if upstream != truth:
                confusion = f"{truth}->{upstream}"
                held_upstream_confusions[confusion] = held_upstream_confusions.get(confusion, 0) + 1
    if wrong_accepted:
        raise AssertionError(f"Wrong accepted leave-one-lineage-out classifications: {wrong_accepted}")
    if score_increases:
        raise AssertionError(f"Envelope increased {score_increases} selected scores.")

    source = provider_path.read_text(encoding="utf-8")
    prohibited_tokens = ("m12_check_characters(", "m12_remainder(", "expectedTruth", "lotId", "slotNumber", "notch")
    algorithm_body = source[source.index("def build_glyph_envelope_bank"):source.index("def run_job")]
    found_prohibited = [token for token in prohibited_tokens if token in algorithm_body]
    if found_prohibited:
        raise AssertionError(f"Prohibited decision inputs found: {found_prohibited}")

    gate = {
        "schema": "argos_opencv_scribe_r18v_glyph_envelope_gate_v1",
        "state": "PASS_R18V_ZERO_WRONG_ACCEPTED_LINEAGE_GLYPH_ENVELOPES",
        "providerSha256": sha256_file(provider_path),
        "testSha256": sha256_file(Path(__file__)),
        "frozenR18hProviderSha256": R18H_PROVIDER_SHA256,
        "baseManifestSha256": BASE_MANIFEST_SHA256,
        "supplementalManifestSha256": SUPPLEMENTAL_MANIFEST_SHA256,
        "combinedReferenceCount": len(prototypes),
        "verifiedReferenceFileCount": len(prototypes),
        "aggregateOrderedReferenceSha256": aggregate_reference_sha256,
        "fullBankFingerprint": full_bank.fingerprint,
        "coverage": coverage,
        "leaveOnePhysicalLineageOut": {
            "referenceQueries": len(prototypes),
            "upstreamCorrect": upstream_correct,
            "accepted": accepted,
            "acceptedCorrect": accepted,
            "acceptedWrong": len(wrong_accepted),
            "held": len(prototypes) - accepted,
            "genericEnvelopeCorrections": corrected,
            "acceptedCorrections": accepted_corrections,
            "heldUpstreamConfusions": dict(sorted(held_upstream_confusions.items())),
            "holdDecisions": dict(sorted(hold_decisions.items())),
            "truthNormalizedDistanceQuantiles": {
                str(percentile): float(np.quantile(truth_normalized_distances, percentile))
                for percentile in (0.0, 0.25, 0.5, 0.75, 0.9, 0.95, 1.0)
            },
            "nearestRivalNormalizedDistanceQuantiles": {
                str(percentile): float(np.quantile(nearest_rival_normalized_distances, percentile))
                for percentile in (0.0, 0.25, 0.5, 0.75, 0.9, 0.95, 1.0)
            },
            "perTruth": per_truth,
            "fullConfusionMatrix": {
                "columns": [*labels, "HOLD"],
                "rows": [
                    {
                        "truth": truth,
                        "counts": [matrix[truth][prediction] for prediction in [*labels, "HOLD"]],
                    }
                    for truth in labels
                ],
            },
        },
        "fullPerGlyphDiagnostics": {
            "checked": diagnostics_checked,
            "requiredFields": sorted(required),
            "state": "PASS",
        },
        "presenceAndBlankSemantics": {
            "state": "PASS_UNCHANGED_AND_NONINCREASING",
            "frozenMinimumPostGridImageScore": provider.MINIMUM_POST_GRID_IMAGE_SCORE,
            "referenceQueriesWithScoreIncrease": score_increases,
            "gridSelection": "UNCHANGED_R18H_FIND_BEST_GRID_BEFORE_ENVELOPE",
            "envelopeCanCreateHypothesis": False,
            "envelopeCanRaisePresenceScore": False,
            "blankDecisionInputsUsed": False,
        },
        "decisionInputs": {
            "realHashLockedReferenceGlyphsOnly": True,
            "topology": True,
            "orderedRunStructure": True,
            "physicalLineageAware": True,
            "minimumIndependentPhysicalLineages": provider.MINIMUM_ENFORCEABLE_LINEAGES,
            "empiricalRadiusMultiplier": provider.EMPIRICAL_RADIUS_MULTIPLIER,
            "robustRadiusMadMultiplier": provider.ROBUST_RADIUS_MAD_MULTIPLIER,
            "queryRivalRatioMargin": provider.QUERY_RIVAL_RATIO_MARGIN,
            "reciprocalCenterRatioMinimum": provider.RECIPROCAL_CENTER_RATIO_MINIMUM,
            "alternativeLabelMaximumNormalizedDistance": provider.ALTERNATIVE_LABEL_MAXIMUM_NORMALIZED_DISTANCE,
            "syntheticDots": False,
            "truth": False,
            "checksum": False,
            "lot": False,
            "slot": False,
            "notch": False,
            "prohibitedDecisionTokensFound": found_prohibited,
        },
        "limitations": {
            "sparseOrUnobservedSelectedLabelsHold": True,
            "holdsAcceptableInThisGate": True,
            "liveImageValidationPerformed": False,
            "providerActivationAuthorized": False,
            "productionAuthorized": False,
        },
    }
    if args.expected_gate is not None:
        expected = json.loads(args.expected_gate.read_text(encoding="utf-8-sig"))
        if expected != gate:
            raise AssertionError("Checked-in R18V gate does not match a fresh deterministic run.")
    print(json.dumps(gate, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
